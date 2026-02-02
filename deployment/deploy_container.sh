#!/bin/bash

# ============================================
# Container Services Deployment Script
# ============================================
# Deploy Frontend + Backend to Snowpark Container Services
# Backend is internal-only (no public endpoint)
# Frontend proxies API requests to backend
# ============================================
clear
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

# Configuration defaults (can be overridden by config files or env vars)
SNOWFLAKE_CONNECTION="${SNOWFLAKE_CONNECTION:-}"
USE_DEFAULT_CONNECTION="${USE_DEFAULT_CONNECTION:-true}"
SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-SFSENORTHAMERICA-TBOON_AWS2}"
SNOWFLAKE_USER="${SNOWFLAKE_USER:-DEMO_SVC}"
SNOWFLAKE_ROLE="${SNOWFLAKE_ROLE:-BORDEREAU_PROCESSING_PIPELINE_ADMIN}"
CONTAINER_ROLE="${CONTAINER_ROLE:-${SNOWFLAKE_ROLE}}"  # Use SNOWFLAKE_ROLE if not specified
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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_privileges() {
    log_info "Checking role privileges..."
    
    # SYSADMIN and ACCOUNTADMIN have all privileges by default
    if [[ "${CONTAINER_ROLE}" == "SYSADMIN" ]] || [[ "${CONTAINER_ROLE}" == "ACCOUNTADMIN" ]]; then
        log_success "Using ${CONTAINER_ROLE} - has all required privileges"
        return 0
    fi
    
    # For custom roles, try to create a test stage to verify permissions
    log_info "Testing CREATE STAGE privilege for role ${CONTAINER_ROLE}..."
    local test_result=$(execute_sql "
        USE ROLE ${CONTAINER_ROLE};
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        CREATE OR REPLACE STAGE PRIVILEGE_TEST_STAGE COMMENT = 'Temporary stage for privilege check';
        DROP STAGE IF EXISTS PRIVILEGE_TEST_STAGE;
        SELECT 'SUCCESS' as result;
    " 2>&1)
    
    if echo "$test_result" | grep -q "SUCCESS"; then
        log_success "Role ${CONTAINER_ROLE} has required privileges"
    else
        log_warning "Role ${CONTAINER_ROLE} may not have sufficient privileges"
        log_warning "If deployment fails with stage creation errors, try one of these solutions:"
        log_warning ""
        log_warning "Option 1: Use SYSADMIN for container operations (recommended):"
        log_warning "  Set CONTAINER_ROLE=\"SYSADMIN\" in deployment/custom.config"
        log_warning ""
        log_warning "Option 2: Grant privileges to your current role (run as SYSADMIN):"
        log_warning "  GRANT CREATE STAGE ON SCHEMA ${DATABASE_NAME}.${SCHEMA_NAME} TO ROLE ${CONTAINER_ROLE};"
        log_warning "  GRANT ALL PRIVILEGES ON SCHEMA ${DATABASE_NAME}.${SCHEMA_NAME} TO ROLE ${CONTAINER_ROLE};"
        log_warning ""
    fi
}

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

# ============================================
# Print Header
# ============================================

print_header() {
    # clear  # Commented out for CI/CD compatibility
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🚀 Unified Service Deployment (Frontend + Backend)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Service:         $SERVICE_NAME"
    echo "  Account:         $SNOWFLAKE_ACCOUNT"
    echo "  Database:        $DATABASE_NAME"
    echo "  Role:            $SNOWFLAKE_ROLE"
    echo "  Container Role:  $CONTAINER_ROLE"
    echo "  Compute Pool:    $COMPUTE_POOL_NAME"
    echo "  Repository:      $REPOSITORY_NAME"
    echo ""
    echo "  Architecture:"
    echo "    • Frontend (nginx) - Public endpoint on port 80"
    echo "    • Backend (FastAPI) - Internal only on port 8000"
    echo "    • Frontend proxies /api/* to backend"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# ============================================
# Validation
# ============================================

validate_prerequisites() {
    log_step "1/11: Validating prerequisites..."
    
    local missing_commands=()
    
    if ! command_exists snow; then
        missing_commands+=("snow (Snowflake CLI)")
    fi
    
    if ! command_exists docker; then
        missing_commands+=("docker")
    fi
    
    if ! command_exists jq; then
        missing_commands+=("jq")
    fi
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "Missing required commands:"
        for cmd in "${missing_commands[@]}"; do
            echo "  - $cmd"
        done
        exit 1
    fi
    
    # Test Snowflake connection
    local test_cmd="snow connection test"
    if [ -n "$SNOWFLAKE_CONNECTION" ]; then
        test_cmd="$test_cmd --connection $SNOWFLAKE_CONNECTION"
    fi
    
    if ! $test_cmd >/dev/null 2>&1; then
        log_error "Snowflake connection test failed"
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

# ============================================
# Grant Container Service Privileges
# ============================================

grant_container_privileges() {
    log_step "2/11: Granting container service privileges..."
    
    log_info "Granting CREATE SERVICE privileges to ${SNOWFLAKE_ROLE}..."
    
    cat > ${TMP_DIR}/grant_container_privs.sql << EOF
-- Use SYSADMIN to grant container service privileges
USE ROLE SYSADMIN;

-- Grant CREATE SERVICE privilege on the schema
GRANT CREATE SERVICE ON SCHEMA ${DATABASE_NAME}.${SCHEMA_NAME} TO ROLE ${SNOWFLAKE_ROLE};

-- Note: BIND SERVICE ENDPOINT and CREATE COMPUTE POOL must be granted by ACCOUNTADMIN
-- These should be granted once during initial setup via bronze/1_Setup_Database_Roles.sql
EOF
    
    execute_sql_file ${TMP_DIR}/grant_container_privs.sql || {
        log_warning "Some privileges may already be granted (this is OK)"
    }
    
    log_success "Container service privileges granted"
}

# ============================================
# Create Compute Pool
# ============================================

create_compute_pool() {
    log_step "3/11: Creating compute pool..."
    
    # Check if compute pool exists
    local pool_exists
    if [ -n "$SNOWFLAKE_CONNECTION" ]; then
        pool_exists=$(snow sql -q "SHOW COMPUTE POOLS LIKE '${COMPUTE_POOL_NAME}'" --format json --connection "$SNOWFLAKE_CONNECTION" 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")
    else
        pool_exists=$(snow sql -q "SHOW COMPUTE POOLS LIKE '${COMPUTE_POOL_NAME}'" --format json 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")
    fi
    
    # Ensure pool_exists is a number
    pool_exists=${pool_exists:-0}
    
    if [ "$pool_exists" -gt 0 ]; then
        log_info "Compute pool already exists: $COMPUTE_POOL_NAME"
        
        # Ensure permissions are granted even if pool exists
        log_info "Granting permissions on existing compute pool..."
        cat > ${TMP_DIR}/grant_pool_perms.sql << EOF
USE ROLE SYSADMIN;

-- Grant permissions on compute pool to admin role
GRANT USAGE ON COMPUTE POOL ${COMPUTE_POOL_NAME} TO ROLE ${SNOWFLAKE_ROLE};
GRANT MONITOR ON COMPUTE POOL ${COMPUTE_POOL_NAME} TO ROLE ${SNOWFLAKE_ROLE};
GRANT OPERATE ON COMPUTE POOL ${COMPUTE_POOL_NAME} TO ROLE ${SNOWFLAKE_ROLE};
EOF
        execute_sql_file ${TMP_DIR}/grant_pool_perms.sql || {
            log_warning "Failed to grant permissions (may already exist)"
        }
        
        return 0
    fi
    
    log_info "Creating compute pool: $COMPUTE_POOL_NAME"
    
    cat > ${TMP_DIR}/create_pool.sql << EOF
-- Create compute pool with SYSADMIN
USE ROLE SYSADMIN;

CREATE COMPUTE POOL ${COMPUTE_POOL_NAME}
    MIN_NODES = 1
    MAX_NODES = 3
    INSTANCE_FAMILY = CPU_X64_XS
    AUTO_RESUME = TRUE
    AUTO_SUSPEND_SECS = 3600
    COMMENT = 'Compute pool for Bordereau unified service';

-- Grant permissions to admin role
GRANT USAGE ON COMPUTE POOL ${COMPUTE_POOL_NAME} TO ROLE ${SNOWFLAKE_ROLE};
GRANT MONITOR ON COMPUTE POOL ${COMPUTE_POOL_NAME} TO ROLE ${SNOWFLAKE_ROLE};
GRANT OPERATE ON COMPUTE POOL ${COMPUTE_POOL_NAME} TO ROLE ${SNOWFLAKE_ROLE};

-- Switch back to admin role
USE ROLE ${SNOWFLAKE_ROLE};
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SCHEMA_NAME};
EOF
    
    execute_sql_file ${TMP_DIR}/create_pool.sql || {
        log_error "Failed to create compute pool"
        exit 1
    }
    
    log_success "Compute pool created and permissions granted: $COMPUTE_POOL_NAME"
}

# ============================================
# Create Image Repository
# ============================================

create_image_repository() {
    log_step "4/11: Creating image repository..."
    
    # Check if repository exists
    local repo_exists
    if [ -n "$SNOWFLAKE_CONNECTION" ]; then
        repo_exists=$(snow sql -q "SHOW IMAGE REPOSITORIES LIKE '${REPOSITORY_NAME}'" --format json --connection "$SNOWFLAKE_CONNECTION" 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")
    else
        repo_exists=$(snow sql -q "SHOW IMAGE REPOSITORIES LIKE '${REPOSITORY_NAME}'" --format json 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")
    fi
    
    # Ensure repo_exists is a number
    repo_exists=${repo_exists:-0}
    
    if [ "$repo_exists" -gt 0 ]; then
        log_info "Image repository already exists: $REPOSITORY_NAME"
        
        # Ensure permissions are granted even if repository exists
        log_info "Granting permissions on existing image repository..."
        cat > ${TMP_DIR}/grant_repo_perms.sql << EOF
USE ROLE SYSADMIN;
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SCHEMA_NAME};

-- Grant permissions on image repository to admin role
GRANT READ, WRITE ON IMAGE REPOSITORY ${REPOSITORY_NAME} TO ROLE ${SNOWFLAKE_ROLE};
EOF
        execute_sql_file ${TMP_DIR}/grant_repo_perms.sql || {
            log_warning "Failed to grant permissions (may already exist)"
        }
        
        return 0
    fi
    
    log_info "Creating image repository: $REPOSITORY_NAME"
    
    cat > ${TMP_DIR}/create_repo.sql << EOF
-- Use SYSADMIN to create image repository
USE ROLE SYSADMIN;
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SCHEMA_NAME};

CREATE IMAGE REPOSITORY ${REPOSITORY_NAME}
    COMMENT = 'Container images for Bordereau unified service';

-- Grant permissions to admin role
GRANT READ, WRITE ON IMAGE REPOSITORY ${REPOSITORY_NAME} TO ROLE ${SNOWFLAKE_ROLE};

-- Switch back to admin role
USE ROLE ${SNOWFLAKE_ROLE};
EOF
    
    execute_sql_file ${TMP_DIR}/create_repo.sql || {
        log_error "Failed to create image repository"
        exit 1
    }
    
    log_success "Image repository created and permissions granted: $REPOSITORY_NAME"
}

# ============================================
# Get Repository URL
# ============================================

get_repository_url() {
    log_step "5/11: Getting repository URL..."
    
    local url_cmd="snow spcs image-repository url \"${REPOSITORY_NAME}\" --database \"${DATABASE_NAME}\" --schema \"${SCHEMA_NAME}\""
    if [ -n "$SNOWFLAKE_CONNECTION" ]; then
        url_cmd="$url_cmd --connection $SNOWFLAKE_CONNECTION"
    fi
    
    local repo_url=$(eval $url_cmd 2>/dev/null | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$repo_url" ]; then
        log_error "Failed to get repository URL"
        exit 1
    fi
    
    REPOSITORY_URL="$repo_url"
    log_success "Repository URL: $REPOSITORY_URL"
}

# ============================================
# Docker Login
# ============================================

docker_login() {
    log_step "6/11: Logging into Docker registry..."
    
    local login_cmd="snow spcs image-registry login"
    if [ -n "$SNOWFLAKE_CONNECTION" ]; then
        login_cmd="$login_cmd --connection $SNOWFLAKE_CONNECTION"
    fi
    
    $login_cmd || {
        log_error "Docker login failed"
        exit 1
    }
    
    log_success "Docker login successful"
}

# ============================================
# Build Backend Image
# ============================================

build_backend_image() {
    log_step "7/11: Building backend Docker image..."
    
    local full_image_name="${REPOSITORY_URL}/${BACKEND_IMAGE_NAME}:${IMAGE_TAG}"
    
    cd "$PROJECT_ROOT"
    
    if [ ! -f "docker/Dockerfile.backend" ]; then
        log_error "docker/Dockerfile.backend not found"
        exit 1
    fi
    
    log_info "Building backend image: $full_image_name"
    log_info "Build context: $PROJECT_ROOT"
    
    docker build \
        --platform linux/amd64 \
        --build-arg APP_NAME="${APP_NAME}" \
        --build-arg ALLOWED_LLM_MODELS="${ALLOWED_LLM_MODELS}" \
        -f docker/Dockerfile.backend \
        -t "$full_image_name" \
        -t "${BACKEND_IMAGE_NAME}:${IMAGE_TAG}" \
        . || {
        log_error "Backend Docker build failed"
        exit 1
    }
    
    log_success "Backend image built"
}

# ============================================
# Build Frontend Image
# ============================================

build_frontend_image() {
    log_step "8/11: Building frontend Docker image..."
    
    local full_image_name="${REPOSITORY_URL}/${FRONTEND_IMAGE_NAME}:${IMAGE_TAG}"
    
    # Create nginx config that proxies to backend on localhost:8000
    log_info "Creating nginx configuration..."
    cat > ${TMP_DIR}/nginx-unified.conf << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Root directory for static files
    root /usr/share/nginx/html;
    index index.html;
    
    # Serve static files
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Proxy API requests to backend (same pod, localhost:8000)
    location /api/ {
        proxy_pass http://localhost:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    # Create Dockerfile for frontend (in project root to avoid macOS /tmp permission issues)
    cat > "$PROJECT_ROOT/Dockerfile.frontend.unified" << 'EOF'
# Multi-stage build for React frontend
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY frontend/package.json frontend/package-lock.json* ./

# Install dependencies
RUN npm ci

# Copy source code
COPY frontend/ .

# Build application (API calls will be proxied by nginx to localhost:8000)
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built assets from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx-unified.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
EOF
    
    # Copy nginx config to build context (project root)
    cp ${TMP_DIR}/nginx-unified.conf "$PROJECT_ROOT/nginx-unified.conf"
    
    log_info "Building frontend image: $full_image_name"
    log_info "Build context: $PROJECT_ROOT"
    
    cd "$PROJECT_ROOT"
    
    docker build \
        --platform linux/amd64 \
        --build-arg APP_NAME="${APP_NAME}" \
        -f Dockerfile.frontend.unified \
        -t "$full_image_name" \
        -t "${FRONTEND_IMAGE_NAME}:${IMAGE_TAG}" \
        . || {
        log_error "Frontend Docker build failed"
        rm -f "$PROJECT_ROOT/nginx-unified.conf" "$PROJECT_ROOT/Dockerfile.frontend.unified"
        exit 1
    }
    
    # Cleanup
    rm -f "$PROJECT_ROOT/nginx-unified.conf" "$PROJECT_ROOT/Dockerfile.frontend.unified"
    
    log_success "Frontend image built"
}

# ============================================
# Push Images
# ============================================

push_images() {
    log_step "9/11: Pushing Docker images..."
    
    local backend_image="${REPOSITORY_URL}/${BACKEND_IMAGE_NAME}:${IMAGE_TAG}"
    local frontend_image="${REPOSITORY_URL}/${FRONTEND_IMAGE_NAME}:${IMAGE_TAG}"
    
    log_info "Pushing backend image..."
    docker push "$backend_image" || {
        log_error "Backend image push failed"
        exit 1
    }
    
    log_info "Pushing frontend image..."
    docker push "$frontend_image" || {
        log_error "Frontend image push failed"
        exit 1
    }
    
    log_success "Images pushed successfully"
}

# ============================================
# Create Service Specification
# ============================================

create_service_spec() {
    log_step "10/11: Creating unified service specification..."
    
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
    else
        log_error "Failed to create service specification file"
        log_error "Expected location: ${SPEC_FILE}"
        log_error "Temp directory: ${TEMP_DIR}"
        exit 1
    fi
}

# ============================================
# Deploy Service
# ============================================

deploy_service() {
    log_step "11/11: Deploying unified service..."
    
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
    
    # Convert path for Snowflake PUT command (handle Windows paths)
    SPEC_FILE_UPLOAD=$(echo "${SPEC_FILE}" | sed 's|\\|/|g')
    
    execute_sql "
        USE ROLE ${CONTAINER_ROLE};
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        PUT file://${SPEC_FILE_UPLOAD} @SERVICE_SPECS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
    " "true" || {
        log_error "Failed to upload service specification"
        log_error "File: ${SPEC_FILE}"
        log_error "Please ensure role ${CONTAINER_ROLE} has WRITE privilege on stage SERVICE_SPECS"
        exit 1
    }
    
    # Check if service exists using snow CLI
    log_info "Checking if service exists..."
    SERVICE_EXISTS=$(snow spcs service list \
        --database "${DATABASE_NAME}" \
        --schema "${SCHEMA_NAME}" \
        --format json 2>/dev/null | \
        jq -r ".[] | select(.name == \"${SERVICE_NAME}\") | .name" || echo "")
    
    if [ -n "$SERVICE_EXISTS" ]; then
        log_info "Service '$SERVICE_NAME' already exists. Using suspend/upgrade/resume workflow..."
        
        # Step 1: Suspend the service
        log_info "Suspending service..."
        snow spcs service suspend "${SERVICE_NAME}" \
            --database "${DATABASE_NAME}" \
            --schema "${SCHEMA_NAME}" || {
            log_error "Failed to suspend service"
            exit 1
        }
        log_success "Service suspended"
        
        # Wait for suspension to complete
        log_info "Waiting for service to suspend..."
        sleep 5
        
        # Step 2: Upgrade the service
        log_info "Upgrading service with new images..."
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
        
        # Wait for service to be ready
        log_info "Waiting for service to be ready..."
        sleep 10
        
    else
        # Create new service
        log_info "Creating new service '$SERVICE_NAME'..."
        
        cat > ${TMP_DIR}/create_service.sql << EOF
USE ROLE ${SNOWFLAKE_ROLE};
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
            log_error "Failed to create service. Error details:"
            cat ${TMP_DIR}/create_service_error.log | grep -i "error\|failed" || cat ${TMP_DIR}/create_service_error.log | tail -20
            exit 1
        fi
        log_success "Service created: $SERVICE_NAME"
    fi
}

# ============================================
# Get Service Endpoint
# ============================================

get_service_endpoint() {
    echo ""
    log_info "Getting service endpoint..."
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        # Use snow CLI to get service endpoints (this returns public ingress URLs)
        local endpoints=$(snow spcs service list-endpoints "${SERVICE_NAME}" \
            --database "${DATABASE_NAME}" \
            --schema "${SCHEMA_NAME}" \
            --format json 2>/dev/null)
        
        if [ -n "$endpoints" ] && [ "$endpoints" != "[]" ]; then
            # Extract the public ingress URL for the 'app' endpoint
            local ingress_url=$(echo "$endpoints" | jq -r '.[] | select(.name == "app") | .ingress_url // empty' 2>/dev/null)
            
            if [ -n "$ingress_url" ] && [ "$ingress_url" != "null" ] && [ "$ingress_url" != "" ]; then
                SERVICE_ENDPOINT="$ingress_url"
                log_success "Public endpoint URL obtained: $SERVICE_ENDPOINT"
                
                # Also get internal DNS name for reference
                local service_info=$(snow spcs service list \
                    --database "${DATABASE_NAME}" \
                    --schema "${SCHEMA_NAME}" \
                    --format json 2>/dev/null | \
                    jq -r ".[] | select(.name == \"${SERVICE_NAME}\")" 2>/dev/null)
                local dns_name=$(echo "$service_info" | jq -r '.dns_name // empty' 2>/dev/null)
                
                if [ -n "$dns_name" ] && [ "$dns_name" != "null" ]; then
                    SERVICE_INTERNAL_ENDPOINT="https://${dns_name}"
                    log_info "Internal endpoint: $SERVICE_INTERNAL_ENDPOINT"
                fi
                
                return 0
            fi
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_info "Endpoint not ready, waiting... (attempt $attempt/$max_attempts)"
            sleep 10
        fi
        
        ((attempt++))
    done
    
    log_warning "Endpoint not available yet. Service may still be starting."
    log_info "Check status with: cd deployment && ./manage_services.sh status"
    log_info "Or use: snow spcs service list-endpoints ${SERVICE_NAME} --database ${DATABASE_NAME} --schema ${SCHEMA_NAME}"
}

# ============================================
# Wait for Service to be Accessible
# ============================================

wait_for_service_ready() {
    echo ""
    log_info "Waiting for service to be accessible..."
    
    if [ -z "$SERVICE_ENDPOINT" ]; then
        log_warning "No service endpoint available to test"
        return 1
    fi
    
    local max_attempts=30
    local attempt=1
    local wait_seconds=10
    
    log_info "Testing URL: ${SERVICE_ENDPOINT}"
    log_info "This may take several minutes as the service initializes..."
    
    while [ $attempt -le $max_attempts ]; do
        # Try to access the root endpoint
        if command_exists curl; then
            local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${SERVICE_ENDPOINT}" 2>/dev/null || echo "000")
            
            if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
                log_success "Service is accessible! (HTTP $http_code)"
                
                # Try API health check
                log_info "Testing API health endpoint..."
                local api_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${SERVICE_ENDPOINT}/api/health" 2>/dev/null || echo "000")
                
                if [ "$api_code" = "200" ]; then
                    log_success "API health check passed! (HTTP $api_code)"
                else
                    log_warning "Frontend is accessible but API may still be starting (HTTP $api_code)"
                fi
                
                return 0
            elif [ "$http_code" = "000" ]; then
                log_info "Connection timeout or network error (attempt $attempt/$max_attempts)"
            else
                log_info "Service returned HTTP $http_code (attempt $attempt/$max_attempts)"
            fi
        elif command_exists wget; then
            if wget --spider --timeout=10 --tries=1 "${SERVICE_ENDPOINT}" >/dev/null 2>&1; then
                log_success "Service is accessible!"
                return 0
            else
                log_info "Service not yet accessible (attempt $attempt/$max_attempts)"
            fi
        else
            log_warning "Neither curl nor wget available, skipping accessibility check"
            return 1
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_info "Waiting ${wait_seconds} seconds before next attempt..."
            sleep $wait_seconds
        fi
        
        ((attempt++))
    done
    
    log_warning "Service endpoint is published but not yet accessible after $((max_attempts * wait_seconds)) seconds"
    log_info "The service may still be initializing. This is normal for first deployment."
    log_info "You can check status with: cd deployment && ./manage_services.sh status"
    log_info "Or manually test: curl ${SERVICE_ENDPOINT}"
    
    return 1
}

# ============================================
# Print Summary
# ============================================

print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🎉 DEPLOYMENT COMPLETE!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  ✅ Unified Service Deployed"
    echo "     • Frontend + Backend in single service"
    echo "     • Backend is internal-only (no public endpoint)"
    echo "     • Frontend proxies /api/* to backend"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📍 ENDPOINTS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    if [ -n "$SERVICE_ENDPOINT" ]; then
        echo "  🌐 Public URL (Internet-accessible):"
        echo -e "    ${GREEN}${SERVICE_ENDPOINT}${NC}"
        echo ""
        
        # Check if service was verified as accessible
        if command_exists curl; then
            local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${SERVICE_ENDPOINT}" 2>/dev/null || echo "000")
            if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
                echo -e "  ${GREEN}✓ Service is accessible and responding${NC}"
            else
                echo -e "  ${YELLOW}⚠ Service URL published but may still be initializing${NC}"
                echo "    (This is normal for first deployment - may take a few minutes)"
            fi
        fi
        echo ""
        
        echo "  API Health Check:"
        echo -e "    ${BLUE}${SERVICE_ENDPOINT}/api/health${NC}"
        echo ""
        if [ -n "$SERVICE_INTERNAL_ENDPOINT" ]; then
            echo "  🔒 Internal URL (SPCS only):"
            echo -e "    ${CYAN}${SERVICE_INTERNAL_ENDPOINT}${NC}"
            echo ""
        fi
        echo "  Test from anywhere:"
        echo -e "    ${CYAN}curl ${SERVICE_ENDPOINT}${NC}"
        echo -e "    ${CYAN}curl ${SERVICE_ENDPOINT}/api/health${NC}"
    else
        echo -e "  ${YELLOW}Endpoint provisioning in progress...${NC}"
        echo "  Check status: ./manage_services.sh status"
        echo "  Or run: snow spcs service list-endpoints ${SERVICE_NAME}"
    fi
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🛠️  MANAGEMENT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Check status:"
    echo -e "    ${CYAN}cd deployment${NC}"
    echo -e "    ${CYAN}./manage_services.sh status${NC}"
    echo ""
    echo "  View logs:"
    echo -e "    ${CYAN}./manage_services.sh logs backend 100${NC}"
    echo -e "    ${CYAN}./manage_services.sh logs frontend 100${NC}"
    echo ""
    echo "  Run health check:"
    echo -e "    ${CYAN}./manage_services.sh health${NC}"
    echo ""
    echo "  If service is not accessible yet, wait a few minutes and check:"
    echo -e "    ${CYAN}curl ${SERVICE_ENDPOINT}${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# ============================================
# Main
# ============================================

main() {
    print_header
    validate_prerequisites
    check_privileges
    grant_container_privileges
    create_compute_pool
    create_image_repository
    get_repository_url
    docker_login
    build_backend_image
    build_frontend_image
    push_images
    create_service_spec
    deploy_service
    get_service_endpoint
    wait_for_service_ready
    print_summary
}

# Run main
main "$@"
