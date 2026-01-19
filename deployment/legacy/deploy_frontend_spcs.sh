#!/bin/bash

# ============================================
# Frontend Snowpark Container Services Deployment
# ============================================
# Deploy React frontend to SPCS
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$PROJECT_ROOT"

# Configuration
SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-SFSENORTHAMERICA-TBOON_AWS2}"
SNOWFLAKE_USER="${SNOWFLAKE_USER:-DEMO_SVC}"
SNOWFLAKE_ROLE="${SNOWFLAKE_ROLE:-BORDEREAU_PROCESSING_PIPELINE_ADMIN}"
SNOWFLAKE_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH}"
DATABASE_NAME="${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
SCHEMA_NAME="${SCHEMA_NAME:-PUBLIC}"

# Frontend service configuration
FRONTEND_SERVICE_NAME="${FRONTEND_SERVICE_NAME:-BORDEREAU_FRONTEND_SERVICE}"
FRONTEND_IMAGE_NAME="${FRONTEND_IMAGE_NAME:-bordereau_frontend}"
FRONTEND_IMAGE_TAG="${FRONTEND_IMAGE_TAG:-latest}"

# Backend service configuration (for API proxy)
BACKEND_SERVICE_NAME="${BACKEND_SERVICE_NAME:-BORDEREAU_SERVICE}"

# Reuse existing infrastructure
COMPUTE_POOL_NAME="${COMPUTE_POOL_NAME:-BORDEREAU_COMPUTE_POOL}"
REPOSITORY_NAME="${REPOSITORY_NAME:-BORDEREAU_REPOSITORY}"

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

execute_sql() {
    local sql="$1"
    log_info "Executing SQL..."
    snow sql -q "$sql" --connection DEPLOYMENT
}

# ============================================
# Validation
# ============================================

validate_prerequisites() {
    log_info "Validating prerequisites..."
    
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
    
    # Check if backend service exists
    log_info "Checking if backend service exists..."
    local backend_exists=$(snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        SHOW SERVICES LIKE '${BACKEND_SERVICE_NAME}';
    " --connection DEPLOYMENT --format json 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")
    
    if [ "$backend_exists" -eq 0 ]; then
        log_error "Backend service ${BACKEND_SERVICE_NAME} not found!"
        log_error "Please deploy the backend first:"
        log_error "  cd deployment"
        log_error "  ./deploy_snowpark_container.sh"
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

# ============================================
# Get Backend Endpoint
# ============================================

get_backend_endpoint() {
    log_info "Getting backend service endpoint..."
    
    local endpoint_output=$(snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        SHOW ENDPOINTS IN SERVICE ${BACKEND_SERVICE_NAME};
    " --connection DEPLOYMENT --format json 2>/dev/null)
    
    # Extract ingress_url from the JSON output
    BACKEND_ENDPOINT=$(echo "$endpoint_output" | jq -r '.[2][0].ingress_url // empty' 2>/dev/null | tr -d '\n' | sed 's/ //g')
    
    if [ -z "$BACKEND_ENDPOINT" ] || [ "$BACKEND_ENDPOINT" == "null" ]; then
        log_error "Backend endpoint not available"
        log_error "Please ensure backend service is running:"
        log_error "  ./manage_snowpark_service.sh status"
        exit 1
    fi
    
    log_success "Backend endpoint: https://${BACKEND_ENDPOINT}"
}

# ============================================
# Get Repository URL
# ============================================

get_repository_url() {
    log_info "Getting repository URL..."
    
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
# Docker Login
# ============================================

docker_login() {
    log_info "Logging into Snowflake Docker registry..."
    
    snow spcs image-registry login --connection DEPLOYMENT || {
        log_error "Failed to login to Snowflake registry"
        exit 1
    }
    
    log_success "Docker login successful"
}

# ============================================
# Create Nginx Configuration for SPCS
# ============================================

create_nginx_config() {
    log_info "Creating nginx configuration for SPCS..."
    
    # Create temporary nginx config with backend endpoint
    cat > /tmp/nginx-spcs.conf << EOF
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # React Router support
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    # API proxy to backend SPCS service
    location /api/ {
        proxy_pass https://${BACKEND_ENDPOINT}/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host ${BACKEND_ENDPOINT};
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # SSL verification
        proxy_ssl_verify off;
        proxy_ssl_server_name on;
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
    
    log_success "Nginx configuration created"
}

# ============================================
# Build Docker Image
# ============================================

build_docker_image() {
    log_info "Building Docker image..."
    
    local full_image_name="${REPOSITORY_URL}/${FRONTEND_IMAGE_NAME}:${FRONTEND_IMAGE_TAG}"
    
    if [ ! -f "docker/Dockerfile.frontend" ]; then
        log_error "docker/Dockerfile.frontend not found"
        exit 1
    fi
    
    log_info "Building image: $full_image_name"
    
    # Create a temporary Dockerfile that uses the SPCS nginx config (in project root to avoid macOS /tmp permission issues)
    cat > Dockerfile.frontend.spcs << 'EOF'
# Multi-stage build for React frontend
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY frontend/package.json frontend/package-lock.json* ./

# Install dependencies
RUN npm ci

# Copy source code
COPY frontend/ .

# Build application (API calls will be proxied by nginx)
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built assets from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy SPCS-specific nginx configuration
COPY nginx-spcs.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
EOF
    
    # Copy nginx config to build context
    cp /tmp/nginx-spcs.conf nginx-spcs.conf
    
    docker build \
        --platform linux/amd64 \
        -f Dockerfile.frontend.spcs \
        -t "$full_image_name" \
        -t "${FRONTEND_IMAGE_NAME}:${FRONTEND_IMAGE_TAG}" \
        . || {
        log_error "Docker build failed"
        rm -f nginx-spcs.conf Dockerfile.frontend.spcs
        exit 1
    }
    
    # Cleanup
    rm -f nginx-spcs.conf Dockerfile.frontend.spcs
    
    log_success "Docker image built: $full_image_name"
}

# ============================================
# Push Docker Image
# ============================================

push_docker_image() {
    log_info "Pushing Docker image to Snowflake registry..."
    
    local full_image_name="${REPOSITORY_URL}/${FRONTEND_IMAGE_NAME}:${FRONTEND_IMAGE_TAG}"
    
    docker push "$full_image_name" || {
        log_error "Docker push failed"
        exit 1
    }
    
    log_success "Docker image pushed: $full_image_name"
}

# ============================================
# Create Service Specification
# ============================================

create_service_spec() {
    log_info "Creating service specification..."
    
    local full_image_name="${REPOSITORY_URL}/${FRONTEND_IMAGE_NAME}:${FRONTEND_IMAGE_TAG}"
    
    cat > /tmp/frontend_service_spec.yaml << EOF
spec:
  containers:
  - name: frontend
    image: /${DATABASE_NAME}/${SCHEMA_NAME}/${REPOSITORY_NAME}/${FRONTEND_IMAGE_NAME}:${FRONTEND_IMAGE_TAG}
    env:
      NGINX_WORKER_PROCESSES: "2"
    resources:
      requests:
        cpu: 0.5
        memory: 1Gi
      limits:
        cpu: 1
        memory: 2Gi
    readinessProbe:
      port: 80
      path: /
  endpoints:
  - name: frontend
    port: 80
    public: true
EOF
    
    log_success "Service specification created"
}

# ============================================
# Deploy Service
# ============================================

deploy_service() {
    log_info "Deploying frontend service: $FRONTEND_SERVICE_NAME"
    
    # Create stage if not exists
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
        PUT file:///tmp/frontend_service_spec.yaml @SERVICE_SPECS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
    " --connection DEPLOYMENT || {
        log_error "Failed to upload service specification"
        exit 1
    }
    
    # Check if service exists
    log_info "Checking if service exists..."
    SERVICE_EXISTS=$(snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        SHOW SERVICES LIKE '${FRONTEND_SERVICE_NAME}';
    " --connection DEPLOYMENT --format json 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")
    
    if [ "$SERVICE_EXISTS" -gt 0 ]; then
        log_info "Service exists - updating with new image..."
        
        snow sql -q "
            USE ROLE ${SNOWFLAKE_ROLE};
            USE DATABASE ${DATABASE_NAME};
            USE SCHEMA ${SCHEMA_NAME};
            
            -- Suspend the service
            ALTER SERVICE ${FRONTEND_SERVICE_NAME} SUSPEND;
            
            -- Wait for service to suspend
            CALL SYSTEM\$WAIT(5);
            
            -- Update the service with new specification
            ALTER SERVICE ${FRONTEND_SERVICE_NAME} FROM @SERVICE_SPECS
                SPECIFICATION_FILE = 'frontend_service_spec.yaml';
            
            -- Resume the service
            ALTER SERVICE ${FRONTEND_SERVICE_NAME} RESUME;
        " --connection DEPLOYMENT
        
        log_success "Service updated: $FRONTEND_SERVICE_NAME (endpoint preserved)"
    else
        log_info "Service does not exist - creating new service..."
        
        snow sql -q "
            USE ROLE ${SNOWFLAKE_ROLE};
            USE DATABASE ${DATABASE_NAME};
            USE SCHEMA ${SCHEMA_NAME};
            
            CREATE SERVICE ${FRONTEND_SERVICE_NAME}
                IN COMPUTE POOL ${COMPUTE_POOL_NAME}
                FROM @SERVICE_SPECS
                SPECIFICATION_FILE = 'frontend_service_spec.yaml'
                MIN_INSTANCES = 1
                MAX_INSTANCES = 3
                COMMENT = 'Bordereau Processing Pipeline Frontend Service';
        " --connection DEPLOYMENT
        
        log_success "Service created: $FRONTEND_SERVICE_NAME"
    fi
}

# ============================================
# Get Frontend Endpoint
# ============================================

get_frontend_endpoint() {
    log_info "Getting frontend service endpoint..."
    
    local endpoint_output=$(snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        SHOW ENDPOINTS IN SERVICE ${FRONTEND_SERVICE_NAME};
    " --connection DEPLOYMENT --format json 2>/dev/null)
    
    FRONTEND_ENDPOINT=$(echo "$endpoint_output" | jq -r '.[2][0].ingress_url // empty' 2>/dev/null | tr -d '\n' | sed 's/ //g')
    
    if [ -n "$FRONTEND_ENDPOINT" ] && [ "$FRONTEND_ENDPOINT" != "null" ] && [[ ! "$FRONTEND_ENDPOINT" =~ "provisioning" ]]; then
        FRONTEND_ENDPOINT="https://${FRONTEND_ENDPOINT}"
        log_success "Frontend endpoint: $FRONTEND_ENDPOINT"
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  🎉 FRONTEND DEPLOYMENT SUCCESSFUL!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  Frontend URL:    $FRONTEND_ENDPOINT"
        echo "  Backend URL:     https://${BACKEND_ENDPOINT}"
        echo ""
        echo "  Open in browser: $FRONTEND_ENDPOINT"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        log_warning "Frontend endpoint not yet available"
        log_info "Endpoint provisioning in progress (2-3 minutes)"
        log_info "Check status with:"
        echo "  cd deployment"
        echo "  ./manage_frontend_service.sh status"
    fi
}

# ============================================
# Cleanup
# ============================================

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f /tmp/nginx-spcs.conf
    rm -f Dockerfile.frontend.spcs
    rm -f nginx-spcs.conf
    rm -f /tmp/frontend_service_spec.yaml
}

# ============================================
# Main
# ============================================

main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🚀 Frontend Snowpark Container Services Deployment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Account:         $SNOWFLAKE_ACCOUNT"
    echo "  Database:        $DATABASE_NAME"
    echo "  Compute Pool:    $COMPUTE_POOL_NAME"
    echo "  Repository:      $REPOSITORY_NAME"
    echo "  Frontend Service: $FRONTEND_SERVICE_NAME"
    echo "  Backend Service:  $BACKEND_SERVICE_NAME"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    validate_prerequisites
    get_backend_endpoint
    get_repository_url
    docker_login
    create_nginx_config
    build_docker_image
    push_docker_image
    create_service_spec
    deploy_service
    sleep 10  # Wait for service to start
    get_frontend_endpoint
    cleanup
    
    echo ""
    log_success "Deployment complete!"
}

# Run main
main
