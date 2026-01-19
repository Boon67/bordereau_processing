#!/bin/bash

# ============================================
# Full Stack Snowpark Container Services Deployment
# ============================================
# Deploy both Backend and Frontend to SPCS
# Includes health checks and connectivity verification
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

# Configuration
SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-SFSENORTHAMERICA-TBOON_AWS2}"
SNOWFLAKE_USER="${SNOWFLAKE_USER:-DEMO_SVC}"
SNOWFLAKE_ROLE="${SNOWFLAKE_ROLE:-BORDEREAU_PROCESSING_PIPELINE_ADMIN}"
SNOWFLAKE_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH}"
DATABASE_NAME="${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
SCHEMA_NAME="${SCHEMA_NAME:-PUBLIC}"

# Service configuration
BACKEND_SERVICE_NAME="${BACKEND_SERVICE_NAME:-BORDEREAU_SERVICE}"
FRONTEND_SERVICE_NAME="${FRONTEND_SERVICE_NAME:-BORDEREAU_FRONTEND_SERVICE}"
COMPUTE_POOL_NAME="${COMPUTE_POOL_NAME:-BORDEREAU_COMPUTE_POOL}"
REPOSITORY_NAME="${REPOSITORY_NAME:-BORDEREAU_REPOSITORY}"

# Image configuration
BACKEND_IMAGE_NAME="${BACKEND_IMAGE_NAME:-bordereau_backend}"
FRONTEND_IMAGE_NAME="${FRONTEND_IMAGE_NAME:-bordereau_frontend}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Deployment options
SKIP_BACKEND="${SKIP_BACKEND:-false}"
SKIP_FRONTEND="${SKIP_FRONTEND:-false}"
SKIP_HEALTH_CHECKS="${SKIP_HEALTH_CHECKS:-false}"

# Global variables
BACKEND_ENDPOINT=""
FRONTEND_ENDPOINT=""
DEPLOYMENT_START_TIME=$(date +%s)

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

execute_sql() {
    local sql="$1"
    snow sql -q "$sql" --connection DEPLOYMENT 2>/dev/null
}

# ============================================
# Print Header
# ============================================

print_header() {
    clear
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🚀 Full Stack Snowpark Container Services Deployment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Account:         $SNOWFLAKE_ACCOUNT"
    echo "  Database:        $DATABASE_NAME"
    echo "  Compute Pool:    $COMPUTE_POOL_NAME"
    echo "  Repository:      $REPOSITORY_NAME"
    echo ""
    echo "  Backend Service:  $BACKEND_SERVICE_NAME"
    echo "  Frontend Service: $FRONTEND_SERVICE_NAME"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# ============================================
# Validation
# ============================================

validate_prerequisites() {
    log_step "1/8: Validating prerequisites..."
    
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
    
    if ! command_exists curl; then
        missing_commands+=("curl")
    fi
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "Missing required commands:"
        for cmd in "${missing_commands[@]}"; do
            echo "  - $cmd"
        done
        exit 1
    fi
    
    # Test Snowflake connection
    if ! snow connection test --connection DEPLOYMENT >/dev/null 2>&1; then
        log_error "Snowflake connection test failed"
        log_error "Please verify: snow connection test --connection DEPLOYMENT"
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

# ============================================
# Deploy Backend
# ============================================

deploy_backend() {
    if [ "$SKIP_BACKEND" == "true" ]; then
        log_warning "Skipping backend deployment (SKIP_BACKEND=true)"
        return 0
    fi
    
    log_step "2/8: Deploying backend service..."
    echo ""
    
    if [ ! -f "$SCRIPT_DIR/deploy_snowpark_container.sh" ]; then
        log_error "Backend deployment script not found: deploy_snowpark_container.sh"
        exit 1
    fi
    
    # Run backend deployment script
    if bash "$SCRIPT_DIR/deploy_snowpark_container.sh"; then
        log_success "Backend deployed successfully"
    else
        log_error "Backend deployment failed"
        exit 1
    fi
    
    echo ""
}

# ============================================
# Get Backend Endpoint
# ============================================

get_backend_endpoint() {
    log_step "3/8: Getting backend endpoint..."
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local endpoint_output=$(snow sql -q "
            USE DATABASE ${DATABASE_NAME};
            USE SCHEMA ${SCHEMA_NAME};
            SHOW ENDPOINTS IN SERVICE ${BACKEND_SERVICE_NAME};
        " --connection DEPLOYMENT --format json 2>/dev/null)
        
        BACKEND_ENDPOINT=$(echo "$endpoint_output" | jq -r '.[2][0].ingress_url // empty' 2>/dev/null | tr -d '\n' | sed 's/ //g')
        
        if [ -n "$BACKEND_ENDPOINT" ] && [ "$BACKEND_ENDPOINT" != "null" ] && [[ ! "$BACKEND_ENDPOINT" =~ "provisioning" ]]; then
            BACKEND_ENDPOINT="https://${BACKEND_ENDPOINT}"
            log_success "Backend endpoint: $BACKEND_ENDPOINT"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_info "Endpoint not ready, waiting... (attempt $attempt/$max_attempts)"
            sleep 10
        fi
        
        ((attempt++))
    done
    
    log_error "Backend endpoint not available after $max_attempts attempts"
    log_error "Check backend service status:"
    echo "  cd deployment"
    echo "  ./manage_snowpark_service.sh status"
    exit 1
}

# ============================================
# Test Backend Health
# ============================================

test_backend_health() {
    log_step "4/8: Testing backend health..."
    
    local max_attempts=20
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Testing backend health endpoint (attempt $attempt/$max_attempts)..."
        
        local response=$(curl -s -w "\n%{http_code}" -L "$BACKEND_ENDPOINT/api/health" 2>/dev/null || echo "000")
        local http_code=$(echo "$response" | tail -n1)
        local body=$(echo "$response" | head -n-1)
        
        if [ "$http_code" == "200" ]; then
            log_success "Backend is healthy!"
            log_info "Response: $body"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_warning "Backend not ready (HTTP $http_code), waiting..."
            sleep 15
        fi
        
        ((attempt++))
    done
    
    log_error "Backend health check failed after $max_attempts attempts"
    log_error "Check backend logs:"
    echo "  cd deployment"
    echo "  ./manage_services.sh logs backend 100"
    exit 1
}

# ============================================
# Deploy Frontend
# ============================================

deploy_frontend() {
    if [ "$SKIP_FRONTEND" == "true" ]; then
        log_warning "Skipping frontend deployment (SKIP_FRONTEND=true)"
        return 0
    fi
    
    log_step "5/8: Deploying frontend service..."
    echo ""
    
    if [ ! -f "$SCRIPT_DIR/deploy_frontend_spcs.sh" ]; then
        log_error "Frontend deployment script not found: deploy_frontend_spcs.sh"
        exit 1
    fi
    
    # Run frontend deployment script
    if bash "$SCRIPT_DIR/deploy_frontend_spcs.sh"; then
        log_success "Frontend deployed successfully"
    else
        log_error "Frontend deployment failed"
        exit 1
    fi
    
    echo ""
}

# ============================================
# Get Frontend Endpoint
# ============================================

get_frontend_endpoint() {
    log_step "6/8: Getting frontend endpoint..."
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local endpoint_output=$(snow sql -q "
            USE DATABASE ${DATABASE_NAME};
            USE SCHEMA ${SCHEMA_NAME};
            SHOW ENDPOINTS IN SERVICE ${FRONTEND_SERVICE_NAME};
        " --connection DEPLOYMENT --format json 2>/dev/null)
        
        FRONTEND_ENDPOINT=$(echo "$endpoint_output" | jq -r '.[2][0].ingress_url // empty' 2>/dev/null | tr -d '\n' | sed 's/ //g')
        
        if [ -n "$FRONTEND_ENDPOINT" ] && [ "$FRONTEND_ENDPOINT" != "null" ] && [[ ! "$FRONTEND_ENDPOINT" =~ "provisioning" ]]; then
            FRONTEND_ENDPOINT="https://${FRONTEND_ENDPOINT}"
            log_success "Frontend endpoint: $FRONTEND_ENDPOINT"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_info "Endpoint not ready, waiting... (attempt $attempt/$max_attempts)"
            sleep 10
        fi
        
        ((attempt++))
    done
    
    log_error "Frontend endpoint not available after $max_attempts attempts"
    log_error "Check frontend service status:"
    echo "  cd deployment"
    echo "  ./manage_frontend_service.sh status"
    exit 1
}

# ============================================
# Test Frontend Health
# ============================================

test_frontend_health() {
    log_step "7/8: Testing frontend health..."
    
    local max_attempts=20
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Testing frontend endpoint (attempt $attempt/$max_attempts)..."
        
        local response=$(curl -s -w "\n%{http_code}" -L "$FRONTEND_ENDPOINT/" 2>/dev/null || echo "000")
        local http_code=$(echo "$response" | tail -n1)
        
        if [ "$http_code" == "200" ]; then
            log_success "Frontend is accessible!"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_warning "Frontend not ready (HTTP $http_code), waiting..."
            sleep 15
        fi
        
        ((attempt++))
    done
    
    log_error "Frontend health check failed after $max_attempts attempts"
    log_error "Check frontend logs:"
    echo "  cd deployment"
    echo "  ./manage_services.sh logs frontend 100"
    exit 1
}

# ============================================
# Test Frontend-Backend Communication
# ============================================

test_frontend_backend_communication() {
    log_step "8/8: Testing frontend-backend communication..."
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Testing API proxy through frontend (attempt $attempt/$max_attempts)..."
        
        # Test API call through frontend's nginx proxy
        local response=$(curl -s -w "\n%{http_code}" -L "$FRONTEND_ENDPOINT/api/health" 2>/dev/null || echo "000")
        local http_code=$(echo "$response" | tail -n1)
        local body=$(echo "$response" | head -n-1)
        
        if [ "$http_code" == "200" ]; then
            log_success "Frontend-backend communication working!"
            log_info "API Response: $body"
            
            # Verify it's actually JSON from the backend
            if echo "$body" | jq . >/dev/null 2>&1; then
                local status=$(echo "$body" | jq -r '.status // empty' 2>/dev/null)
                if [ "$status" == "healthy" ]; then
                    log_success "Backend API responding correctly through frontend proxy"
                    return 0
                fi
            fi
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_warning "API proxy not working yet (HTTP $http_code), waiting..."
            sleep 15
        fi
        
        ((attempt++))
    done
    
    log_error "Frontend-backend communication test failed after $max_attempts attempts"
    log_error "Troubleshooting steps:"
    echo "  1. Check frontend logs: ./manage_services.sh logs frontend 100"
    echo "  2. Check backend logs: ./manage_services.sh logs backend 100"
    echo "  3. Run health check: ./manage_services.sh health"
    echo "  4. Verify backend endpoint in nginx config"
    exit 1
}

# ============================================
# Run All Health Checks
# ============================================

run_health_checks() {
    if [ "$SKIP_HEALTH_CHECKS" == "true" ]; then
        log_warning "Skipping health checks (SKIP_HEALTH_CHECKS=true)"
        return 0
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🏥 Running Health Checks"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Get endpoints if not already set
    if [ -z "$BACKEND_ENDPOINT" ]; then
        get_backend_endpoint
    fi
    
    if [ -z "$FRONTEND_ENDPOINT" ]; then
        get_frontend_endpoint
    fi
    
    # Run health checks
    test_backend_health
    test_frontend_health
    test_frontend_backend_communication
    
    echo ""
}

# ============================================
# Print Deployment Summary
# ============================================

print_summary() {
    local deployment_end_time=$(date +%s)
    local duration=$((deployment_end_time - DEPLOYMENT_START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🎉 DEPLOYMENT SUCCESSFUL!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  ✅ Backend Service:  DEPLOYED & HEALTHY"
    echo "  ✅ Frontend Service: DEPLOYED & HEALTHY"
    echo "  ✅ Communication:    VERIFIED"
    echo ""
    echo "  ⏱️  Deployment Time:  ${minutes}m ${seconds}s"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📍 ENDPOINTS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Frontend (UI):"
    echo "    ${GREEN}${FRONTEND_ENDPOINT}${NC}"
    echo ""
    echo "  Backend (API):"
    echo "    ${BLUE}${BACKEND_ENDPOINT}${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🚀 QUICK START"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. Open the application:"
    echo "     ${CYAN}${FRONTEND_ENDPOINT}${NC}"
    echo ""
    echo "  2. Test the API:"
    echo "     ${CYAN}curl ${BACKEND_ENDPOINT}/api/health${NC}"
    echo ""
    echo "  3. View logs:"
    echo "     ${CYAN}cd deployment${NC}"
    echo "     ${CYAN}./manage_services.sh logs backend 50${NC}"
    echo "     ${CYAN}./manage_services.sh logs frontend 50${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📊 SERVICE STATUS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Check status:"
    echo "    ${CYAN}./manage_services.sh status${NC}"
    echo "    ${CYAN}./manage_services.sh health${NC}"
    echo ""
    echo "  Update services:"
    echo "    ${CYAN}./deploy_full_stack.sh${NC}  (redeploy with endpoint preservation)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# ============================================
# Show Help
# ============================================

show_help() {
    cat << EOF

Usage: $0 [OPTIONS]

Deploy both backend and frontend services to Snowpark Container Services
with comprehensive health checks and connectivity verification.

Options:
  --skip-backend          Skip backend deployment (use existing backend)
  --skip-frontend         Skip frontend deployment (use existing frontend)
  --skip-health-checks    Skip health checks (faster, but no verification)
  --help                  Show this help message

Environment Variables:
  SNOWFLAKE_ACCOUNT       Snowflake account (default: SFSENORTHAMERICA-TBOON_AWS2)
  DATABASE_NAME           Database name (default: BORDEREAU_PROCESSING_PIPELINE)
  BACKEND_SERVICE_NAME    Backend service name (default: BORDEREAU_SERVICE)
  FRONTEND_SERVICE_NAME   Frontend service name (default: BORDEREAU_FRONTEND_SERVICE)
  COMPUTE_POOL_NAME       Compute pool name (default: BORDEREAU_COMPUTE_POOL)
  REPOSITORY_NAME         Repository name (default: BORDEREAU_REPOSITORY)

Examples:
  # Full deployment with health checks
  $0

  # Update frontend only
  $0 --skip-backend

  # Update backend only
  $0 --skip-frontend

  # Quick deployment without health checks
  $0 --skip-health-checks

Deployment Steps:
  1. Validate prerequisites (Snow CLI, Docker, jq, curl)
  2. Deploy backend service
  3. Get backend endpoint
  4. Test backend health (/api/health)
  5. Deploy frontend service
  6. Get frontend endpoint
  7. Test frontend accessibility
  8. Test frontend-backend communication (nginx proxy)

Health Checks:
  ✅ Backend health endpoint responds with 200 OK
  ✅ Frontend serves static files (200 OK)
  ✅ Frontend can proxy API requests to backend
  ✅ API returns valid JSON through proxy

EOF
}

# ============================================
# Parse Arguments
# ============================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-backend)
                SKIP_BACKEND="true"
                shift
                ;;
            --skip-frontend)
                SKIP_FRONTEND="true"
                shift
                ;;
            --skip-health-checks)
                SKIP_HEALTH_CHECKS="true"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ============================================
# Main
# ============================================

main() {
    parse_arguments "$@"
    
    print_header
    validate_prerequisites
    
    # Deploy services
    deploy_backend
    deploy_frontend
    
    # Run health checks
    run_health_checks
    
    # Print summary
    print_summary
}

# Run main
main "$@"
