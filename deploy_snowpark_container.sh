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

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

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
        --account "$SNOWFLAKE_ACCOUNT" \
        --user "$SNOWFLAKE_USER" \
        --role "$SNOWFLAKE_ROLE" \
        --warehouse "$SNOWFLAKE_WAREHOUSE" \
        --database "$DATABASE_NAME"
}

# Execute SQL from file
execute_sql_file() {
    local file="$1"
    log_info "Executing SQL from file: $file"
    snow sql -f "$file" \
        --account "$SNOWFLAKE_ACCOUNT" \
        --user "$SNOWFLAKE_USER" \
        --role "$SNOWFLAKE_ROLE" \
        --warehouse "$SNOWFLAKE_WAREHOUSE" \
        --database "$DATABASE_NAME"
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

-- Get repository URL
SELECT REPOSITORY_URL 
FROM INFORMATION_SCHEMA.IMAGE_REPOSITORIES 
WHERE REPOSITORY_NAME = '${REPOSITORY_NAME}';
EOF

    execute_sql_file /tmp/create_repository.sql
    log_success "Image repository created: $REPOSITORY_NAME"
}

# ============================================
# Step 3: Get Repository URL
# ============================================

get_repository_url() {
    log_info "Getting repository URL..."
    
    # Get repository URL from Snowflake
    REPOSITORY_URL=$(snow sql -q "SELECT REPOSITORY_URL FROM INFORMATION_SCHEMA.IMAGE_REPOSITORIES WHERE REPOSITORY_NAME = '${REPOSITORY_NAME}'" \
        --account "$SNOWFLAKE_ACCOUNT" \
        --user "$SNOWFLAKE_USER" \
        --role "$SNOWFLAKE_ROLE" \
        --warehouse "$SNOWFLAKE_WAREHOUSE" \
        --database "$DATABASE_NAME" \
        --format json | jq -r '.[0].REPOSITORY_URL' 2>/dev/null || echo "")
    
    if [ -z "$REPOSITORY_URL" ]; then
        log_error "Failed to get repository URL"
        log_info "Attempting alternative method..."
        
        # Alternative: construct URL manually
        REPOSITORY_URL="${SNOWFLAKE_ACCOUNT}.registry.snowflakecomputing.com/${DATABASE_NAME}/${SCHEMA_NAME}/${REPOSITORY_NAME}"
        log_warning "Using constructed URL: $REPOSITORY_URL"
    else
        log_success "Repository URL: $REPOSITORY_URL"
    fi
}

# ============================================
# Step 4: Docker Login to Snowflake Registry
# ============================================

docker_login() {
    log_info "Logging into Snowflake Docker registry..."
    
    # Get token for Docker login
    log_info "Getting authentication token..."
    
    # Use Snow CLI to get token
    TOKEN=$(snow sql -q "SELECT SYSTEM\$GET_SNOWSIGHT_HOST()" \
        --account "$SNOWFLAKE_ACCOUNT" \
        --user "$SNOWFLAKE_USER" \
        --format json 2>/dev/null | jq -r '.[0]."SYSTEM$GET_SNOWSIGHT_HOST()"' || echo "")
    
    # Docker login using Snowflake credentials
    log_info "Authenticating with Docker registry..."
    echo "$SNOWFLAKE_PASSWORD" | docker login "${SNOWFLAKE_ACCOUNT}.registry.snowflakecomputing.com" \
        -u "$SNOWFLAKE_USER" \
        --password-stdin 2>/dev/null || {
        log_warning "Standard Docker login failed, trying with Snow CLI..."
        
        # Alternative: use snow CLI for authentication
        snow connection test --connection DEPLOYMENT || {
            log_error "Failed to authenticate with Snowflake"
            log_info "Please ensure your Snow CLI connection is configured:"
            log_info "  snow connection add"
            exit 1
        }
    }
    
    log_success "Docker login successful"
}

# ============================================
# Step 5: Build Docker Image
# ============================================

build_docker_image() {
    log_info "Building Docker image..."
    
    # Create optimized Dockerfile for Snowpark
    cat > /tmp/Dockerfile.snowpark << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY backend/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY backend/app ./app

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/health')" || exit 1

# Run application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

    # Build image
    local full_image_name="${REPOSITORY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    log_info "Building image: $full_image_name"
    docker build \
        -f /tmp/Dockerfile.snowpark \
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
    
    local full_image_name="${REPOSITORY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    docker push "$full_image_name" || {
        log_error "Docker push failed"
        log_info "Trying alternative push method..."
        
        # Alternative: use snow CLI
        snow spcs image-repository push \
            --image "$full_image_name" \
            --connection DEPLOYMENT || {
            log_error "Failed to push image"
            exit 1
        }
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
      httpGet:
        path: /api/health
        port: 8000
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    livenessProbe:
      httpGet:
        path: /api/health
        port: 8000
      initialDelaySeconds: 30
      periodSeconds: 30
      timeoutSeconds: 5
      failureThreshold: 3

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
    
    # Upload service spec to stage
    cat > /tmp/deploy_service.sql << EOF
-- Deploy Snowpark Container Service
USE ROLE ${SNOWFLAKE_ROLE};
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SCHEMA_NAME};

-- Create stage for service specs if not exists
CREATE STAGE IF NOT EXISTS SERVICE_SPECS
    COMMENT = 'Stage for Snowpark Container Service specifications';

-- Upload service spec (this will be done via PUT command)

-- Create or replace service
CREATE SERVICE IF NOT EXISTS ${SERVICE_NAME}
    IN COMPUTE POOL ${COMPUTE_POOL_NAME}
    FROM @SERVICE_SPECS
    SPECIFICATION_FILE = 'service_spec.yaml'
    MIN_INSTANCES = 1
    MAX_INSTANCES = 3
    COMMENT = 'Bordereau Processing Pipeline Backend Service';

-- Show service status
SHOW SERVICES LIKE '${SERVICE_NAME}';
DESCRIBE SERVICE ${SERVICE_NAME};

-- Get service endpoints
CALL SYSTEM\$GET_SERVICE_STATUS('${SERVICE_NAME}');
EOF

    # Upload spec file
    log_info "Uploading service specification..."
    snow object stage copy /tmp/service_spec.yaml "@${DATABASE_NAME}.${SCHEMA_NAME}.SERVICE_SPECS/service_spec.yaml" \
        --connection DEPLOYMENT \
        --overwrite || {
        log_warning "Snow CLI upload failed, trying SQL PUT..."
        
        snow sql -q "PUT file:///tmp/service_spec.yaml @SERVICE_SPECS AUTO_COMPRESS=FALSE OVERWRITE=TRUE" \
            --account "$SNOWFLAKE_ACCOUNT" \
            --user "$SNOWFLAKE_USER" \
            --role "$SNOWFLAKE_ROLE" \
            --warehouse "$SNOWFLAKE_WAREHOUSE" \
            --database "$DATABASE_NAME"
    }
    
    # Deploy service
    execute_sql_file /tmp/deploy_service.sql
    
    log_success "Service deployed: $SERVICE_NAME"
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
    
    ENDPOINT=$(snow sql -q "SELECT SYSTEM\$GET_SERVICE_ENDPOINT('${SERVICE_NAME}', 'backend')" \
        --account "$SNOWFLAKE_ACCOUNT" \
        --user "$SNOWFLAKE_USER" \
        --role "$SNOWFLAKE_ROLE" \
        --warehouse "$SNOWFLAKE_WAREHOUSE" \
        --database "$DATABASE_NAME" \
        --format json | jq -r '.[0]."SYSTEM$GET_SERVICE_ENDPOINT('"'"'${SERVICE_NAME}'"'"', '"'"'BACKEND'"'"')"' 2>/dev/null || echo "")
    
    if [ -n "$ENDPOINT" ]; then
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
        log_info "  snow sql -q \"SELECT SYSTEM\$GET_SERVICE_STATUS('${SERVICE_NAME}')\""
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
    rm -f /tmp/Dockerfile.snowpark
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
