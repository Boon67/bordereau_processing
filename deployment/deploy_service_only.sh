#!/bin/bash

# ============================================
# Deploy Service Only (Steps 10-11)
# ============================================
# Creates service specification and deploys to SPCS
# Use this to redeploy without rebuilding images
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$PROJECT_ROOT"

# Create tmp directory in project root
TMP_DIR="${PROJECT_ROOT}/tmp"
mkdir -p "${TMP_DIR}"

# Load configuration
source "$SCRIPT_DIR/default.config" 2>/dev/null || true
[ -f "$SCRIPT_DIR/custom.config" ] && source "$SCRIPT_DIR/custom.config"

# Configuration defaults
SNOWFLAKE_CONNECTION="${SNOWFLAKE_CONNECTION:-}"
USE_DEFAULT_CONNECTION="${USE_DEFAULT_CONNECTION:-true}"
SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-SFSENORTHAMERICA-TBOON_AWS2}"
SNOWFLAKE_USER="${SNOWFLAKE_USER:-DEMO_SVC}"
SNOWFLAKE_ROLE="${SNOWFLAKE_ROLE:-SYSADMIN}"
CONTAINER_ROLE="${CONTAINER_ROLE:-${SNOWFLAKE_ROLE}}"
SNOWFLAKE_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH}"
DATABASE_NAME="${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
SCHEMA_NAME="${SCHEMA_NAME:-PUBLIC}"

# Service configuration
SERVICE_NAME="${SERVICE_NAME:-BORDEREAU_APP}"
COMPUTE_POOL_NAME="${COMPUTE_POOL_NAME:-BORDEREAU_COMPUTE_POOL}"
REPOSITORY_NAME="${REPOSITORY_NAME:-BORDEREAU_REPOSITORY}"

# Image configuration
BACKEND_IMAGE_NAME="${BACKEND_IMAGE_NAME:-bordereau_backend}"
FRONTEND_IMAGE_NAME="${FRONTEND_IMAGE_NAME:-bordereau_frontend}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

execute_sql() {
    local sql="$1"
    local show_errors="${2:-false}"
    
    if [ "$show_errors" = "true" ]; then
        # Show errors for debugging
        if [ -n "$SNOWFLAKE_CONNECTION" ]; then
            snow sql -q "$sql" --connection "$SNOWFLAKE_CONNECTION"
        elif [ "$USE_DEFAULT_CONNECTION" = "true" ]; then
            snow sql -q "$sql"
        else
            snow sql -q "$sql"
        fi
    else
        # Suppress errors (default behavior)
        if [ -n "$SNOWFLAKE_CONNECTION" ]; then
            snow sql -q "$sql" --connection "$SNOWFLAKE_CONNECTION" 2>/dev/null
        elif [ "$USE_DEFAULT_CONNECTION" = "true" ]; then
            snow sql -q "$sql" 2>/dev/null
        else
            snow sql -q "$sql" 2>/dev/null
        fi
    fi
}

execute_sql_file() {
    local file="$1"
    if [ -n "$SNOWFLAKE_CONNECTION" ]; then
        snow sql -f "$file" --connection "$SNOWFLAKE_CONNECTION" 2>/dev/null
    elif [ "$USE_DEFAULT_CONNECTION" = "true" ]; then
        snow sql -f "$file" 2>/dev/null
    else
        snow sql -f "$file" 2>/dev/null
    fi
}

# Print header
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 Deploy Service Only (Steps 10-11)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Service:         $SERVICE_NAME"
echo "  Database:        $DATABASE_NAME"
echo "  Schema:          $SCHEMA_NAME"
echo "  Container Role:  $CONTAINER_ROLE"
echo "  Compute Pool:    $COMPUTE_POOL_NAME"
echo "  Repository:      $REPOSITORY_NAME"
echo ""
echo "  Images:"
echo "    Backend:  ${BACKEND_IMAGE_NAME}:${IMAGE_TAG}"
echo "    Frontend: ${FRONTEND_IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================
# STEP 10: Create Service Specification
# ============================================

create_service_spec() {
    log_step "Step 10: Creating unified service specification..."
    
    # Use the project's tmp directory
    SPEC_FILE="${TMP_DIR}/unified_service_spec.yaml"
    
    log_info "Creating service specification at: ${SPEC_FILE}"
    
    cat > "${SPEC_FILE}" << EOF
spec:
  containers:
  # Backend container (internal only, no public endpoint)
  - name: backend
    image: /${DATABASE_NAME}/${SCHEMA_NAME}/${REPOSITORY_NAME}/${BACKEND_IMAGE_NAME}:${IMAGE_TAG}
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
        cpu: 0.6
        memory: 2Gi
      limits:
        cpu: "2"
        memory: 4Gi
    readinessProbe:
      port: 8000
      path: /api/health
  
  # Frontend container (public endpoint, proxies to backend)
  - name: frontend
    image: /${DATABASE_NAME}/${SCHEMA_NAME}/${REPOSITORY_NAME}/${FRONTEND_IMAGE_NAME}:${IMAGE_TAG}
    env:
      NGINX_WORKER_PROCESSES: "2"
    resources:
      requests:
        cpu: 0.4
        memory: 1Gi
      limits:
        cpu: 1
        memory: 2Gi
    readinessProbe:
      port: 80
      path: /

  # Only frontend is publicly accessible
  endpoints:
  - name: app
    port: 80
    public: true
EOF

    # Verify file was created
    if [ -f "${SPEC_FILE}" ]; then
        log_success "Service specification created: ${SPEC_FILE}"
        log_info "File size: $(wc -c < "${SPEC_FILE}") bytes"
        echo ""
        log_info "File contents:"
        cat "${SPEC_FILE}"
        echo ""
    else
        log_error "Failed to create service specification file"
        log_error "Expected location: ${SPEC_FILE}"
        log_error "Temp directory: ${TMP_DIR}"
        exit 1
    fi
}

# ============================================
# STEP 11: Deploy Service
# ============================================

deploy_service() {
    log_step "Step 11: Deploying unified service..."
    
    # Create stage (using CONTAINER_ROLE which may be SYSADMIN)
    log_info "Creating stage for service specifications (using role: ${CONTAINER_ROLE})..."
    execute_sql "
        USE ROLE ${CONTAINER_ROLE};
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        CREATE STAGE IF NOT EXISTS SERVICE_SPECS
            COMMENT = 'Stage for Snowpark Container Service specifications';
    " "true" || {
        log_error "Failed to create stage"
        log_error "Please ensure role ${CONTAINER_ROLE} has CREATE STAGE privilege on schema ${DATABASE_NAME}.${SCHEMA_NAME}"
        log_error ""
        log_error "Solutions:"
        log_error "1. Grant privilege: GRANT CREATE STAGE ON SCHEMA ${DATABASE_NAME}.${SCHEMA_NAME} TO ROLE ${CONTAINER_ROLE};"
        log_error "2. Or set CONTAINER_ROLE=\"SYSADMIN\" in deployment/custom.config"
        exit 1
    }
    
    # Upload spec file (using CONTAINER_ROLE)
    log_info "Uploading service specification..."
    
    # Verify file exists before uploading
    if [ ! -f "${SPEC_FILE}" ]; then
        log_error "Service specification file not found: ${SPEC_FILE}"
        log_error "The create_service_spec step may have failed"
        exit 1
    fi
    
    # Convert path for Snowflake PUT command (handle Windows Git Bash paths)
    # Git Bash uses /c/, /d/, /z/ etc. for drive letters
    # Snowflake needs C:/, D:/, Z:/ format
    SPEC_FILE_UPLOAD="${SPEC_FILE}"
    
    # Convert Git Bash path to Windows path if needed
    if [[ "$SPEC_FILE_UPLOAD" =~ ^/([a-z])/ ]]; then
        # Extract drive letter and convert to Windows format
        DRIVE_LETTER="${BASH_REMATCH[1]}"
        SPEC_FILE_UPLOAD=$(echo "${SPEC_FILE}" | sed "s|^/${DRIVE_LETTER}/|${DRIVE_LETTER}:/|")
    fi
    
    # Replace backslashes with forward slashes
    SPEC_FILE_UPLOAD=$(echo "${SPEC_FILE_UPLOAD}" | sed 's|\\|/|g')
    
    log_info "Original path: ${SPEC_FILE}"
    log_info "Upload path: ${SPEC_FILE_UPLOAD}"
    
    execute_sql "
        USE ROLE ${CONTAINER_ROLE};
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        PUT file://${SPEC_FILE_UPLOAD} @SERVICE_SPECS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
    " "true" || {
        log_error "Failed to upload service specification"
        log_error "File: ${SPEC_FILE}"
        log_error "Upload path: ${SPEC_FILE_UPLOAD}"
        log_error "Please ensure role ${CONTAINER_ROLE} has WRITE privilege on stage SERVICE_SPECS"
        exit 1
    }
    
    log_success "Service specification uploaded to @SERVICE_SPECS"
    
    # Check if service exists using snow CLI
    log_info "Checking if service exists..."
    SERVICE_EXISTS=$(snow spcs service list \
        --database "${DATABASE_NAME}" \
        --schema "${SCHEMA_NAME}" \
        --format json 2>/dev/null | jq -r ".[] | select(.name == \"${SERVICE_NAME}\") | .name" || echo "")
    
    if [ -n "$SERVICE_EXISTS" ]; then
        log_info "Service ${SERVICE_NAME} already exists - will upgrade"
        
        # Step 1: Suspend the service
        log_info "Suspending service..."
        snow spcs service suspend "${SERVICE_NAME}" \
            --database "${DATABASE_NAME}" \
            --schema "${SCHEMA_NAME}" || {
            log_warning "Failed to suspend service (may already be suspended)"
        }
        
        sleep 5
        
        # Step 2: Upgrade the service
        log_info "Upgrading service with new specification..."
        snow spcs service upgrade "${SERVICE_NAME}" \
            --database "${DATABASE_NAME}" \
            --schema "${SCHEMA_NAME}" \
            --spec-path "${SPEC_FILE}" || {
            log_error "Failed to upgrade service"
            exit 1
        }
        log_success "Service upgraded"
        
        # Step 3: Resume the service
        log_info "Resuming service..."
        snow spcs service resume "${SERVICE_NAME}" \
            --database "${DATABASE_NAME}" \
            --schema "${SCHEMA_NAME}" || {
            log_error "Failed to resume service"
            exit 1
        }
        log_success "Service resumed"
        
    else
        log_info "Creating new service..."
        
        # Create service using SQL
        cat > ${TMP_DIR}/create_service.sql << EOF
USE ROLE ${CONTAINER_ROLE};
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SCHEMA_NAME};

CREATE SERVICE ${SERVICE_NAME}
    IN COMPUTE POOL ${COMPUTE_POOL_NAME}
    FROM @SERVICE_SPECS
    SPECIFICATION_FILE = 'unified_service_spec.yaml'
    MIN_INSTANCES = 1
    MAX_INSTANCES = 3
    COMMENT = 'Bordereau unified service (Frontend + Backend)';
EOF
        
        # Execute with error output visible
        local create_cmd="snow sql -f ${TMP_DIR}/create_service.sql"
        if [ -n "$SNOWFLAKE_CONNECTION" ]; then
            create_cmd="$create_cmd --connection $SNOWFLAKE_CONNECTION"
        fi
        
        if ! $create_cmd 2>&1 | tee ${TMP_DIR}/create_service_error.log; then
            log_error "Failed to create service. Error log:"
            cat ${TMP_DIR}/create_service_error.log | grep -i "error\|failed" || cat ${TMP_DIR}/create_service_error.log | tail -20
            exit 1
        fi
        
        log_success "Service created successfully"
    fi
    
    echo ""
    log_success "Service deployment completed!"
    echo ""
    log_info "To check service status:"
    echo "  snow spcs service status ${SERVICE_NAME} --database ${DATABASE_NAME} --schema ${SCHEMA_NAME}"
    echo ""
    log_info "To view logs:"
    echo "  snow spcs service logs ${SERVICE_NAME} --database ${DATABASE_NAME} --schema ${SCHEMA_NAME} --container-name frontend"
    echo ""
    log_info "To get endpoint URL:"
    echo "  snow spcs service describe ${SERVICE_NAME} --database ${DATABASE_NAME} --schema ${SCHEMA_NAME}"
    echo ""
}

# ============================================
# Main Execution
# ============================================

main() {
    create_service_spec
    deploy_service
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ Service Deployment Complete"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Run main
main "$@"
