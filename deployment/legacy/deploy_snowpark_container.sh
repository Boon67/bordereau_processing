#!/bin/bash

# ============================================
# Snowpark Container Services Deployment Script
# ============================================
# This script deploys the Bordereau Processing Pipeline
# to Snowpark Container Services
# ============================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$PROJECT_ROOT"

# ============================================
# Configuration
# ============================================

# Default values
SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-SFSENORTHAMERICA-TBOON_AWS2}"
SNOWFLAKE_USER="${SNOWFLAKE_USER:-DEMO_SVC}"
SNOWFLAKE_ROLE="${SNOWFLAKE_ROLE:-BORDEREAU_PROCESSING_PIPELINE_ADMIN}"
SNOWFLAKE_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH}"
DATABASE_NAME="${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
SCHEMA_NAME="${SCHEMA_NAME:-PUBLIC}"

# Container configuration
COMPUTE_POOL_NAME="${COMPUTE_POOL_NAME:-BORDEREAU_COMPUTE_POOL}"
REPOSITORY_NAME="${REPOSITORY_NAME:-BORDEREAU_REPOSITORY}"
IMAGE_NAME="${IMAGE_NAME:-bordereau_backend}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
SERVICE_NAME="${SERVICE_NAME:-BORDEREAU_SERVICE}"

# Compute pool configuration
COMPUTE_POOL_MIN_NODES="${COMPUTE_POOL_MIN_NODES:-1}"
COMPUTE_POOL_MAX_NODES="${COMPUTE_POOL_MAX_NODES:-3}"
COMPUTE_POOL_INSTANCE_FAMILY="${COMPUTE_POOL_INSTANCE_FAMILY:-CPU_X64_XS}"

# ============================================
# Helper Functions
# ============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Execute SQL via Snow CLI
execute_sql() {
    local sql="$1"
    log_info "Executing SQL..."
    snow sql -q "$sql" \
        --connection DEPLOYMENT
}

# Execute SQL from file
execute_sql_file() {
    local file="$1"
    log_info "Executing SQL from file: $file"
    snow sql -f "$file" \
        --connection DEPLOYMENT
}

# ============================================
# Validation
# ============================================

validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check for required commands
    local missing_commands=()
    
    if ! command_exists snow; then
        missing_commands+=("snow (Snowflake CLI)")
    fi
    
    if ! command_exists docker; then
        missing_commands+=("docker")
    fi
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        log_error "Missing required commands:"
        for cmd in "${missing_commands[@]}"; do
            echo "  - $cmd"
        done
        echo ""
        echo "Please install missing dependencies:"
        echo "  - Snowflake CLI: pip install snowflake-cli-labs"
        echo "  - Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check for required files
    if [ ! -f "backend/requirements.txt" ]; then
        log_error "backend/requirements.txt not found"
        exit 1
    fi
    
    if [ ! -d "backend/app" ]; then
        log_error "backend/app directory not found"
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

# ============================================
# Step 1: Create Compute Pool
# ============================================

create_compute_pool() {
    log_info "Creating compute pool: $COMPUTE_POOL_NAME"
    
    cat > /tmp/create_compute_pool.sql << EOF
-- Create compute pool for Snowpark Container Services
USE ROLE ${SNOWFLAKE_ROLE};
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SCHEMA_NAME};

-- Drop existing pool if exists (optional)
-- DROP COMPUTE POOL IF EXISTS ${COMPUTE_POOL_NAME};

-- Create compute pool
CREATE COMPUTE POOL IF NOT EXISTS ${COMPUTE_POOL_NAME}
    MIN_NODES = ${COMPUTE_POOL_MIN_NODES}
    MAX_NODES = ${COMPUTE_POOL_MAX_NODES}
    INSTANCE_FAMILY = ${COMPUTE_POOL_INSTANCE_FAMILY}
    AUTO_RESUME = TRUE
    AUTO_SUSPEND_SECS = 3600
    COMMENT = 'Compute pool for Bordereau Processing Pipeline';

-- Show compute pool status
SHOW COMPUTE POOLS LIKE '${COMPUTE_POOL_NAME}';
DESCRIBE COMPUTE POOL ${COMPUTE_POOL_NAME};
EOF

    execute_sql_file /tmp/create_compute_pool.sql
    log_success "Compute pool created: $COMPUTE_POOL_NAME"
}

# ============================================
# Step 2: Create Image Repository
# ============================================

create_image_repository() {
    log_info "Creating image repository: $REPOSITORY_NAME"
    
    cat > /tmp/create_repository.sql << EOF
-- Create image repository for container images
USE ROLE ${SNOWFLAKE_ROLE};
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SCHEMA_NAME};

-- Create image repository
CREATE IMAGE REPOSITORY IF NOT EXISTS ${REPOSITORY_NAME}
    COMMENT = 'Container image repository for Bordereau Processing Pipeline';

-- Show repository details
SHOW IMAGE REPOSITORIES LIKE '${REPOSITORY_NAME}';
EOF

    execute_sql_file /tmp/create_repository.sql
    log_success "Image repository created: $REPOSITORY_NAME"
}

# ============================================
# Step 3: Get Repository URL
# ============================================

get_repository_url() {
    log_info "Getting repository URL..."
    
    # Use Snow CLI to get repository URL
    REPOSITORY_URL=$(snow spcs image-repository url "$REPOSITORY_NAME" \
        --connection DEPLOYMENT \
        --database "$DATABASE_NAME" \
        --schema "$SCHEMA_NAME" 2>/dev/null || echo "")
    
    if [ -z "$REPOSITORY_URL" ]; then
        log_error "Failed to get repository URL"
        exit 1
    fi
    
    # Convert to lowercase for Docker compatibility
    REPOSITORY_URL=$(echo "$REPOSITORY_URL" | tr '[:upper:]' '[:lower:]')
    
    log_success "Repository URL: $REPOSITORY_URL"
}

# ============================================
# Step 4: Docker Login to Snowflake Registry
# ============================================

docker_login() {
    log_info "Logging into Snowflake Docker registry..."
    
    # Use Snow CLI's built-in image registry login
    snow spcs image-registry login --connection DEPLOYMENT || {
        log_error "Failed to login to Snowflake registry"
        log_info "Please ensure your Snow CLI connection is configured:"
        log_info "  snow connection test --connection DEPLOYMENT"
        exit 1
    }
    
    log_success "Docker login successful"
}

# ============================================
# Step 5: Build Docker Image
# ============================================

build_docker_image() {
    log_info "Building Docker image..."
    
    # Build image
    local full_image_name="${REPOSITORY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    # Check if Dockerfile exists
    if [ ! -f "docker/Dockerfile.backend" ]; then
        log_error "docker/Dockerfile.backend not found"
        exit 1
    fi
    
    log_info "Building image: $full_image_name"
    log_info "Using docker/Dockerfile.backend"
    log_info "Building for linux/amd64 platform (required by Snowflake)"
    
    docker build \
        --platform linux/amd64 \
        -f docker/Dockerfile.backend \
        -t "$full_image_name" \
        -t "${IMAGE_NAME}:${IMAGE_TAG}" \
        . || {
        log_error "Docker build failed"
        exit 1
    }
    
    log_success "Docker image built: $full_image_name"
}

# ============================================
# Step 6: Push Docker Image
# ============================================

push_docker_image() {
    log_info "Pushing Docker image to Snowflake registry..."
    log_info "This may take several minutes..."
    
    local full_image_name="${REPOSITORY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    docker push "$full_image_name" || {
        log_error "Docker push failed"
        exit 1
    }
    
    log_success "Docker image pushed: $full_image_name"
}

# ============================================
# Step 7: Create Service Specification
# ============================================

create_service_spec() {
    log_info "Creating service specification..."
    
    local full_image_name="${REPOSITORY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    cat > /tmp/service_spec.yaml << EOF
spec:
  containers:
  - name: backend
    image: ${full_image_name}
    env:
      ENVIRONMENT: production
      SNOWFLAKE_ACCOUNT: ${SNOWFLAKE_ACCOUNT}
      SNOWFLAKE_USER: ${SNOWFLAKE_USER}
      SNOWFLAKE_ROLE: ${SNOWFLAKE_ROLE}
      SNOWFLAKE_WAREHOUSE: ${SNOWFLAKE_WAREHOUSE}
      DATABASE_NAME: ${DATABASE_NAME}
      BRONZE_SCHEMA_NAME: BRONZE
      SILVER_SCHEMA_NAME: SILVER
    resources:
      requests:
        cpu: "1"
        memory: 2Gi
      limits:
        cpu: "2"
        memory: 4Gi
    readinessProbe:
      port: 8000
      path: /api/health

  endpoints:
  - name: backend
    port: 8000
    public: true
EOF

    log_success "Service specification created"
}

# ============================================
# Step 8: Deploy Service
# ============================================

deploy_service() {
    log_info "Deploying service: $SERVICE_NAME"
    
    # First, create the stage
    log_info "Creating stage for service specifications..."
    snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        CREATE STAGE IF NOT EXISTS SERVICE_SPECS
            COMMENT = 'Stage for Snowpark Container Service specifications';
    " --connection DEPLOYMENT || {
        log_error "Failed to create stage"
        exit 1
    }
    
    # Upload spec file
    log_info "Uploading service specification..."
    snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        PUT file:///tmp/service_spec.yaml @SERVICE_SPECS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
    " --connection DEPLOYMENT || {
        log_error "Failed to upload service specification"
        exit 1
    }
    
    # Check if service exists
    log_info "Checking if service exists..."
    SERVICE_EXISTS=$(snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        SHOW SERVICES LIKE '${SERVICE_NAME}';
    " --connection DEPLOYMENT --format json 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")
    
    if [ "$SERVICE_EXISTS" -gt 0 ]; then
        log_info "Service exists - updating with new image..."
        log_info "Suspending service to update specification..."
        
        # Suspend, update spec, and resume
        cat > /tmp/deploy_service.sql << EOF
-- Update existing Snowpark Container Service
USE ROLE ${SNOWFLAKE_ROLE};
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SCHEMA_NAME};

-- Suspend the service
ALTER SERVICE ${SERVICE_NAME} SUSPEND;

-- Wait for service to suspend
CALL SYSTEM\$WAIT(5);

-- Update the service with new specification (pulls new image)
ALTER SERVICE ${SERVICE_NAME} FROM @SERVICE_SPECS
    SPECIFICATION_FILE = 'service_spec.yaml';

-- Resume the service
ALTER SERVICE ${SERVICE_NAME} RESUME;

-- Show service status
SHOW SERVICES LIKE '${SERVICE_NAME}';
DESCRIBE SERVICE ${SERVICE_NAME};
EOF
        
        log_info "Updating service specification and restarting..."
        execute_sql_file /tmp/deploy_service.sql
        log_success "Service updated: $SERVICE_NAME (endpoint preserved)"
        
    else
        log_info "Service does not exist - creating new service..."
        
        # Create new service
        cat > /tmp/deploy_service.sql << EOF
-- Deploy Snowpark Container Service
USE ROLE ${SNOWFLAKE_ROLE};
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SCHEMA_NAME};

-- Create service
CREATE SERVICE ${SERVICE_NAME}
    IN COMPUTE POOL ${COMPUTE_POOL_NAME}
    FROM @SERVICE_SPECS
    SPECIFICATION_FILE = 'service_spec.yaml'
    MIN_INSTANCES = 1
    MAX_INSTANCES = 3
    COMMENT = 'Bordereau Processing Pipeline Backend Service';

-- Show service status
SHOW SERVICES LIKE '${SERVICE_NAME}';
DESCRIBE SERVICE ${SERVICE_NAME};
EOF

        execute_sql_file /tmp/deploy_service.sql
        log_success "Service created: $SERVICE_NAME"
    fi
    
    # Get service status
    log_info "Checking service status..."
    snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        SELECT SYSTEM\$GET_SERVICE_STATUS('${SERVICE_NAME}');
    " --connection DEPLOYMENT
}

# ============================================
# Step 9: Monitor Service Status
# ============================================

monitor_service() {
    log_info "Monitoring service status..."
    
    cat > /tmp/monitor_service.sql << EOF
-- Monitor service status
USE ROLE ${SNOWFLAKE_ROLE};
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SCHEMA_NAME};

-- Service status
SELECT SYSTEM\$GET_SERVICE_STATUS('${SERVICE_NAME}');

-- Service logs (last 100 lines)
SELECT SYSTEM\$GET_SERVICE_LOGS('${SERVICE_NAME}', 0, 'backend', 100);

-- Compute pool status
DESCRIBE COMPUTE POOL ${COMPUTE_POOL_NAME};
EOF

    execute_sql_file /tmp/monitor_service.sql
    
    log_info "Service monitoring commands available in /tmp/monitor_service.sql"
}

# ============================================
# Step 10: Get Service Endpoint
# ============================================

get_service_endpoint() {
    log_info "Getting service endpoint..."
    
    ENDPOINT=$(snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        SHOW ENDPOINTS IN SERVICE ${SERVICE_NAME};
    " --connection DEPLOYMENT --format json 2>/dev/null | jq -r '.[2].ingress_url' 2>/dev/null || echo "")
    
    if [ -n "$ENDPOINT" ] && [ "$ENDPOINT" != "null" ]; then
        # Add https:// prefix
        ENDPOINT="https://${ENDPOINT}"
        log_success "Service endpoint: $ENDPOINT"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  🎉 DEPLOYMENT SUCCESSFUL!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  Service Name:    $SERVICE_NAME"
        echo "  Compute Pool:    $COMPUTE_POOL_NAME"
        echo "  Image:           $REPOSITORY_URL/$IMAGE_NAME:$IMAGE_TAG"
        echo "  Endpoint:        $ENDPOINT"
        echo ""
        echo "  Test the service:"
        echo "    curl $ENDPOINT/api/health"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        log_warning "Service endpoint not yet available"
        log_info "Service may still be starting. Check status with:"
        log_info "  ./manage_snowpark_service.sh status"
        log_info "  ./manage_snowpark_service.sh endpoint"
    fi
}

# ============================================
# Cleanup Function
# ============================================

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f /tmp/create_compute_pool.sql
    rm -f /tmp/create_repository.sql
    rm -f /tmp/deploy_service.sql
    rm -f /tmp/monitor_service.sql
    # Keep service_spec.yaml for reference
}

# ============================================
# Main Deployment Flow
# ============================================

main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🚀 Snowpark Container Services Deployment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Account:         $SNOWFLAKE_ACCOUNT"
    echo "  Database:        $DATABASE_NAME"
    echo "  Compute Pool:    $COMPUTE_POOL_NAME"
    echo "  Repository:      $REPOSITORY_NAME"
    echo "  Service:         $SERVICE_NAME"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Validate prerequisites
    validate_prerequisites
    
    # Step 1: Create compute pool
    create_compute_pool
    
    # Step 2: Create image repository
    create_image_repository
    
    # Step 3: Get repository URL
    get_repository_url
    
    # Step 4: Docker login
    docker_login
    
    # Step 5: Build Docker image
    build_docker_image
    
    # Step 6: Push Docker image
    push_docker_image
    
    # Step 7: Create service specification
    create_service_spec
    
    # Step 8: Deploy service
    deploy_service
    
    # Step 9: Monitor service
    monitor_service
    
    # Step 10: Get service endpoint
    get_service_endpoint
    
    # Cleanup
    cleanup
    
    echo ""
    log_success "Deployment complete!"
}

# ============================================
# Script Entry Point
# ============================================

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --account)
            SNOWFLAKE_ACCOUNT="$2"
            shift 2
            ;;
        --user)
            SNOWFLAKE_USER="$2"
            shift 2
            ;;
        --role)
            SNOWFLAKE_ROLE="$2"
            shift 2
            ;;
        --database)
            DATABASE_NAME="$2"
            shift 2
            ;;
        --compute-pool)
            COMPUTE_POOL_NAME="$2"
            shift 2
            ;;
        --repository)
            REPOSITORY_NAME="$2"
            shift 2
            ;;
        --service)
            SERVICE_NAME="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --account ACCOUNT          Snowflake account (default: SFSENORTHAMERICA-TBOON_AWS2)"
            echo "  --user USER                Snowflake user (default: DEMO_SVC)"
            echo "  --role ROLE                Snowflake role (default: BORDEREAU_PROCESSING_PIPELINE_ADMIN)"
            echo "  --database DATABASE        Database name (default: BORDEREAU_PROCESSING_PIPELINE)"
            echo "  --compute-pool NAME        Compute pool name (default: BORDEREAU_COMPUTE_POOL)"
            echo "  --repository NAME          Repository name (default: BORDEREAU_REPOSITORY)"
            echo "  --service NAME             Service name (default: BORDEREAU_SERVICE)"
            echo "  --help                     Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main deployment
main
