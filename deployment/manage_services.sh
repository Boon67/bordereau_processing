#!/bin/bash

# ============================================
# Unified Service Management Script
# ============================================
# Manage both Backend and Frontend services
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load configuration
source "$SCRIPT_DIR/default.config" 2>/dev/null || true
[ -f "$SCRIPT_DIR/custom.config" ] && source "$SCRIPT_DIR/custom.config"

# Configuration defaults (can be overridden by config files or env vars)
SNOWFLAKE_CONNECTION="${SNOWFLAKE_CONNECTION:-}"
USE_DEFAULT_CONNECTION="${USE_DEFAULT_CONNECTION:-true}"
SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-}"  # Will be auto-detected if not set
SNOWFLAKE_USER="${SNOWFLAKE_USER:-DEMO_SVC}"
SNOWFLAKE_ROLE="${SNOWFLAKE_ROLE:-BORDEREAU_PROCESSING_PIPELINE_ADMIN}"
SNOWFLAKE_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH}"
DATABASE_NAME="${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
SCHEMA_NAME="${SCHEMA_NAME:-PUBLIC}"

# Service names - support both unified and separate services
UNIFIED_SERVICE_NAME="${UNIFIED_SERVICE_NAME:-BORDEREAU_APP}"
BACKEND_SERVICE_NAME="${BACKEND_SERVICE_NAME:-BORDEREAU_SERVICE}"
FRONTEND_SERVICE_NAME="${FRONTEND_SERVICE_NAME:-BORDEREAU_FRONTEND_SERVICE}"
COMPUTE_POOL_NAME="${COMPUTE_POOL_NAME:-BORDEREAU_COMPUTE_POOL}"

# Detect which deployment model is being used
USE_UNIFIED_SERVICE="${USE_UNIFIED_SERVICE:-auto}"

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Auto-detect Snowflake account and connection if not set
detect_snowflake_account() {
    if [ -n "$SNOWFLAKE_ACCOUNT" ]; then
        return 0
    fi
    
    # Get connection name to use
    local conn_name="$SNOWFLAKE_CONNECTION"
    
    # If no connection specified, get the default from snow CLI
    if [ -z "$conn_name" ]; then
        conn_name=$(snow connection list --format json 2>/dev/null | jq -r '.[] | select(.is_default == true) | .connection_name' 2>/dev/null)
        
        if [ -n "$conn_name" ]; then
            SNOWFLAKE_CONNECTION="$conn_name"
            echo "[INFO] Using default connection: $conn_name"
        else
            echo "[WARNING] Could not detect default connection from snow CLI"
        fi
    fi
    
    # Get account from the connection using snow CLI
    if [ -n "$conn_name" ]; then
        SNOWFLAKE_ACCOUNT=$(snow connection list --format json 2>/dev/null | jq -r ".[] | select(.connection_name == \"$conn_name\") | .parameters.account" 2>/dev/null)
        
        if [ -n "$SNOWFLAKE_ACCOUNT" ]; then
            echo "[INFO] Detected account: $SNOWFLAKE_ACCOUNT"
        fi
    fi
    
    # Fallback: try to detect from current session
    if [ -z "$SNOWFLAKE_ACCOUNT" ]; then
        SNOWFLAKE_ACCOUNT=$(snow sql -q "SELECT CURRENT_ACCOUNT()" --format json 2>/dev/null | jq -r '.[0].CURRENT_ACCOUNT' 2>/dev/null || echo "")
    fi
    
    if [ -z "$SNOWFLAKE_ACCOUNT" ]; then
        log_error "Could not detect Snowflake account"
        exit 1
    fi
}

detect_snowflake_account

execute_sql() {
    local sql_cmd="snow sql -q \"
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        $1
    \""
    
    if [ -n "$SNOWFLAKE_CONNECTION" ]; then
        sql_cmd="$sql_cmd --connection $SNOWFLAKE_CONNECTION"
    fi
    
    eval $sql_cmd
}

# Detect which service model is deployed
detect_service_model() {
    if [ "$USE_UNIFIED_SERVICE" != "auto" ]; then
        return
    fi
    
    # Check if unified service exists
    local unified_exists=$(execute_sql "SHOW SERVICES LIKE '${UNIFIED_SERVICE_NAME}'" 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")
    
    # Check if separate services exist
    local backend_exists=$(execute_sql "SHOW SERVICES LIKE '${BACKEND_SERVICE_NAME}'" 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")
    local frontend_exists=$(execute_sql "SHOW SERVICES LIKE '${FRONTEND_SERVICE_NAME}'" 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")
    
    if [ "$unified_exists" -gt 0 ]; then
        USE_UNIFIED_SERVICE="true"
    elif [ "$backend_exists" -gt 0 ] || [ "$frontend_exists" -gt 0 ]; then
        USE_UNIFIED_SERVICE="false"
    else
        # Default to unified if nothing exists
        USE_UNIFIED_SERVICE="true"
    fi
}

# Check if using unified service
is_unified_service() {
    detect_service_model
    [ "$USE_UNIFIED_SERVICE" = "true" ]
}

# ============================================
# Service Status Functions
# ============================================

get_service_endpoint() {
    local service_name=$1
    
    # Use snow spcs command to get endpoints directly
    local endpoint_output=$(snow spcs service list-endpoints "${service_name}" \
        --database "${DATABASE_NAME}" \
        --schema "${SCHEMA_NAME}" \
        --format json 2>/dev/null)
    
    # Extract ingress_url from the JSON array
    local endpoint=$(echo "$endpoint_output" | jq -r '.[0].ingress_url // empty' 2>/dev/null | tr -d '\n' | sed 's/ //g')
    
    if [ -n "$endpoint" ] && [ "$endpoint" != "null" ] && [ "$endpoint" != "" ] && [[ ! "$endpoint" =~ "provisioning" ]]; then
        # Add https:// prefix if not present
        if [[ "$endpoint" != http* ]]; then
            echo "https://${endpoint}"
        else
            echo "$endpoint"
        fi
    else
        echo "provisioning"
    fi
}

show_backend_status() {
    detect_service_model
    
    if [ "$USE_UNIFIED_SERVICE" == "true" ]; then
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}  🔧 Backend Container (Internal)${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        log_info "Service: $UNIFIED_SERVICE_NAME (backend container)"
        log_info "Backend runs internally on port 8000 (not publicly accessible)"
        log_info "Access via frontend proxy: /api/*"
        echo ""
        return 0
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  🔧 Backend Service (API)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    log_info "Service: $BACKEND_SERVICE_NAME"
    execute_sql "CALL SYSTEM\\\$GET_SERVICE_STATUS('${DATABASE_NAME}.${SCHEMA_NAME}.${BACKEND_SERVICE_NAME}')"
    
    echo ""
    log_info "Endpoint:"
    local endpoint=$(get_service_endpoint "$BACKEND_SERVICE_NAME")
    if [ "$endpoint" != "provisioning" ]; then
        echo -e "  ${GREEN}${endpoint}${NC}"
        echo -e "  ${BLUE}Test:${NC} curl ${endpoint}/api/health"
    else
        echo -e "  ${YELLOW}Endpoint provisioning in progress...${NC}"
    fi
    echo ""
}

show_frontend_status() {
    detect_service_model
    
    if [ "$USE_UNIFIED_SERVICE" == "true" ]; then
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${MAGENTA}  🎨 Unified Service (Frontend + Backend)${NC}"
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        log_info "Service: $UNIFIED_SERVICE_NAME"
        execute_sql "CALL SYSTEM\\\$GET_SERVICE_STATUS('${DATABASE_NAME}.${SCHEMA_NAME}.${UNIFIED_SERVICE_NAME}')"
        
        echo ""
        log_info "Public Endpoint (Frontend):"
        local endpoint=$(get_service_endpoint "$UNIFIED_SERVICE_NAME")
        if [ "$endpoint" != "provisioning" ]; then
            echo -e "  ${GREEN}${endpoint}${NC}"
            echo -e "  ${BLUE}Open:${NC} ${endpoint}"
            echo -e "  ${BLUE}API:${NC} ${endpoint}/api/health"
            echo ""
            log_info "Architecture:"
            echo -e "  • Frontend (nginx) on port 80 - ${GREEN}Public${NC}"
            echo -e "  • Backend (FastAPI) on port 8000 - ${YELLOW}Internal only${NC}"
            echo -e "  • Frontend proxies /api/* to backend"
        else
            echo -e "  ${YELLOW}Endpoint provisioning in progress...${NC}"
        fi
        echo ""
        return 0
    fi
    
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  🎨 Frontend Service (UI)${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    log_info "Service: $FRONTEND_SERVICE_NAME"
    execute_sql "CALL SYSTEM\\\$GET_SERVICE_STATUS('${DATABASE_NAME}.${SCHEMA_NAME}.${FRONTEND_SERVICE_NAME}')"
    
    echo ""
    log_info "Endpoint:"
    local endpoint=$(get_service_endpoint "$FRONTEND_SERVICE_NAME")
    if [ "$endpoint" != "provisioning" ]; then
        echo -e "  ${GREEN}${endpoint}${NC}"
        echo -e "  ${BLUE}Open:${NC} ${endpoint}"
    else
        echo -e "  ${YELLOW}Endpoint provisioning in progress...${NC}"
    fi
    echo ""
}

show_status() {
    local service="${1:-all}"
    
    case "$service" in
        backend)
            show_backend_status
            ;;
        frontend)
            show_frontend_status
            ;;
        all)
            echo ""
            show_backend_status
            show_frontend_status
            ;;
        *)
            log_error "Invalid service: $service (use: backend, frontend, or all)"
            exit 1
            ;;
    esac
}

# ============================================
# Logs Functions
# ============================================

show_logs() {
    local service="${1:-backend}"
    local lines="${2:-100}"
    
    detect_service_model
    
    if [ "$USE_UNIFIED_SERVICE" == "true" ]; then
        # Unified service - both containers in same service
        case "$service" in
            backend)
                log_info "Getting backend logs (last $lines lines)..."
                execute_sql "CALL SYSTEM\\\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${UNIFIED_SERVICE_NAME}', '0', 'backend', ${lines})"
                ;;
            frontend)
                log_info "Getting frontend logs (last $lines lines)..."
                execute_sql "CALL SYSTEM\\\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${UNIFIED_SERVICE_NAME}', '0', 'frontend', ${lines})"
                ;;
            all)
                echo ""
                echo -e "${CYAN}━━━━ Backend Container Logs (last $lines lines) ━━━━${NC}"
                execute_sql "CALL SYSTEM\\\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${UNIFIED_SERVICE_NAME}', '0', 'backend', ${lines})"
                echo ""
                echo -e "${MAGENTA}━━━━ Frontend Container Logs (last $lines lines) ━━━━${NC}"
                execute_sql "CALL SYSTEM\\\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${UNIFIED_SERVICE_NAME}', '0', 'frontend', ${lines})"
                ;;
            *)
                log_error "Invalid service: $service (use: backend, frontend, or all)"
                exit 1
                ;;
        esac
    else
        # Separate services
        case "$service" in
            backend)
                log_info "Getting backend logs (last $lines lines)..."
                execute_sql "CALL SYSTEM\\\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${BACKEND_SERVICE_NAME}', '0', 'backend', ${lines})"
                ;;
            frontend)
                log_info "Getting frontend logs (last $lines lines)..."
                execute_sql "CALL SYSTEM\\\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${FRONTEND_SERVICE_NAME}', '0', 'frontend', ${lines})"
                ;;
            all)
                echo ""
                echo -e "${CYAN}━━━━ Backend Logs (last $lines lines) ━━━━${NC}"
                execute_sql "CALL SYSTEM\\\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${BACKEND_SERVICE_NAME}', '0', 'backend', ${lines})"
                echo ""
                echo -e "${MAGENTA}━━━━ Frontend Logs (last $lines lines) ━━━━${NC}"
                execute_sql "CALL SYSTEM\\\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${FRONTEND_SERVICE_NAME}', '0', 'frontend', ${lines})"
                ;;
            *)
                log_error "Invalid service: $service (use: backend, frontend, or all)"
                exit 1
                ;;
        esac
    fi
}

# ============================================
# Endpoint Functions
# ============================================

show_endpoints() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📍 Service Endpoints"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    detect_service_model
    
    if [ "$USE_UNIFIED_SERVICE" == "true" ]; then
        local endpoint=$(get_service_endpoint "$UNIFIED_SERVICE_NAME")
        
        echo -e "${MAGENTA}Unified Service (Frontend + Backend):${NC}"
        if [ "$endpoint" != "provisioning" ]; then
            echo -e "  ${GREEN}${endpoint}${NC}"
            echo -e "  Open:     ${BLUE}${endpoint}${NC}"
            echo -e "  API Test: ${BLUE}curl ${endpoint}/api/health${NC}"
        else
            echo -e "  ${YELLOW}Provisioning in progress...${NC}"
        fi
    else
        local backend_endpoint=$(get_service_endpoint "$BACKEND_SERVICE_NAME")
        local frontend_endpoint=$(get_service_endpoint "$FRONTEND_SERVICE_NAME")
        
        echo -e "${CYAN}Backend (API):${NC}"
        if [ "$backend_endpoint" != "provisioning" ]; then
            echo -e "  ${GREEN}${backend_endpoint}${NC}"
            echo -e "  Test: ${BLUE}curl ${backend_endpoint}/api/health${NC}"
        else
            echo -e "  ${YELLOW}Provisioning in progress...${NC}"
        fi
        
        echo ""
        echo -e "${MAGENTA}Frontend (UI):${NC}"
        if [ "$frontend_endpoint" != "provisioning" ]; then
            echo -e "  ${GREEN}${frontend_endpoint}${NC}"
            echo -e "  Open: ${BLUE}${frontend_endpoint}${NC}"
        else
            echo -e "  ${YELLOW}Provisioning in progress...${NC}"
        fi
    fi
    echo ""
}

# ============================================
# Service Control Functions
# ============================================

suspend_service() {
    local service="${1:-all}"
    
    case "$service" in
        backend)
            log_info "Suspending backend service..."
            execute_sql "ALTER SERVICE ${BACKEND_SERVICE_NAME} SUSPEND"
            log_success "Backend service suspended"
            ;;
        frontend)
            log_info "Suspending frontend service..."
            execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} SUSPEND"
            log_success "Frontend service suspended"
            ;;
        all)
            log_info "Suspending both services..."
            execute_sql "ALTER SERVICE ${BACKEND_SERVICE_NAME} SUSPEND"
            execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} SUSPEND"
            log_success "Both services suspended"
            ;;
        *)
            log_error "Invalid service: $service (use: backend, frontend, or all)"
            exit 1
            ;;
    esac
}

resume_service() {
    local service="${1:-all}"
    
    case "$service" in
        backend)
            log_info "Resuming backend service..."
            execute_sql "ALTER SERVICE ${BACKEND_SERVICE_NAME} RESUME"
            log_success "Backend service resumed"
            ;;
        frontend)
            log_info "Resuming frontend service..."
            execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} RESUME"
            log_success "Frontend service resumed"
            ;;
        all)
            log_info "Resuming both services..."
            execute_sql "ALTER SERVICE ${BACKEND_SERVICE_NAME} RESUME"
            execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} RESUME"
            log_success "Both services resumed"
            ;;
        *)
            log_error "Invalid service: $service (use: backend, frontend, or all)"
            exit 1
            ;;
    esac
}

restart_service() {
    local service="${1:-all}"
    
    log_info "Restarting service(s)..."
    suspend_service "$service"
    sleep 5
    resume_service "$service"
}

restart_with_new_image() {
    local service="${1:-all}"
    
    # Check if using unified service
    if is_unified_service; then
        log_info "Restarting unified service with new image..."
        log_info "Service: $UNIFIED_SERVICE_NAME"
        
        # For unified service, we just restart it - it will pull the latest image
        log_info "Suspending service..."
        execute_sql "ALTER SERVICE ${UNIFIED_SERVICE_NAME} SUSPEND"
        
        log_info "Waiting for suspension..."
        sleep 10
        
        log_info "Resuming service (will pull latest images)..."
        execute_sql "ALTER SERVICE ${UNIFIED_SERVICE_NAME} RESUME"
        
        log_success "Unified service restarted - new images will be pulled on startup"
        
        echo ""
        log_info "The service will pull the latest images from the registry."
        log_info "This may take 1-2 minutes. Check status with:"
        echo -e "  ${BLUE}./manage_services.sh status${NC}"
        echo -e "  ${BLUE}./manage_services.sh logs backend 50${NC}"
        
        return 0
    fi
    
    # Legacy separate services
    case "$service" in
        backend)
            log_info "Restarting backend with new image..."
            execute_sql "ALTER SERVICE ${BACKEND_SERVICE_NAME} SUSPEND"
            sleep 5
            execute_sql "ALTER SERVICE ${BACKEND_SERVICE_NAME} FROM @SERVICE_SPECS SPECIFICATION_FILE = 'service_spec.yaml'"
            execute_sql "ALTER SERVICE ${BACKEND_SERVICE_NAME} RESUME"
            log_success "Backend restarted with new image"
            ;;
        frontend)
            log_info "Restarting frontend with new image..."
            execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} SUSPEND"
            sleep 5
            execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} FROM @SERVICE_SPECS SPECIFICATION_FILE = 'frontend_service_spec.yaml'"
            execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} RESUME"
            log_success "Frontend restarted with new image"
            ;;
        all)
            log_info "Restarting both services with new images..."
            execute_sql "ALTER SERVICE ${BACKEND_SERVICE_NAME} SUSPEND"
            execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} SUSPEND"
            sleep 5
            execute_sql "ALTER SERVICE ${BACKEND_SERVICE_NAME} FROM @SERVICE_SPECS SPECIFICATION_FILE = 'service_spec.yaml'"
            execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} FROM @SERVICE_SPECS SPECIFICATION_FILE = 'frontend_service_spec.yaml'"
            execute_sql "ALTER SERVICE ${BACKEND_SERVICE_NAME} RESUME"
            execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} RESUME"
            log_success "Both services restarted with new images"
            ;;
        *)
            log_error "Invalid service: $service (use: backend, frontend, or all)"
            exit 1
            ;;
    esac
    
    echo ""
    log_info "Check status in 30-60 seconds:"
    echo -e "  ${BLUE}./manage_services.sh status${NC}"
}

drop_service() {
    local service="${1:-}"
    
    if [ -z "$service" ]; then
        log_error "Service name required (backend, frontend, or all)"
        exit 1
    fi
    
    case "$service" in
        backend)
            log_warning "Dropping backend service: $BACKEND_SERVICE_NAME"
            read -p "Are you sure? This will delete the service (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                execute_sql "DROP SERVICE IF EXISTS ${BACKEND_SERVICE_NAME}"
                log_success "Backend service dropped"
            else
                log_info "Cancelled"
            fi
            ;;
        frontend)
            log_warning "Dropping frontend service: $FRONTEND_SERVICE_NAME"
            read -p "Are you sure? This will delete the service (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                execute_sql "DROP SERVICE IF EXISTS ${FRONTEND_SERVICE_NAME}"
                log_success "Frontend service dropped"
            else
                log_info "Cancelled"
            fi
            ;;
        all)
            log_warning "Dropping BOTH services!"
            read -p "Are you sure? This will delete BOTH services (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                execute_sql "DROP SERVICE IF EXISTS ${BACKEND_SERVICE_NAME}"
                execute_sql "DROP SERVICE IF EXISTS ${FRONTEND_SERVICE_NAME}"
                log_success "Both services dropped"
            else
                log_info "Cancelled"
            fi
            ;;
        *)
            log_error "Invalid service: $service (use: backend, frontend, or all)"
            exit 1
            ;;
    esac
}

# ============================================
# Compute Pool Functions
# ============================================

show_compute_pool() {
    log_info "Getting compute pool status..."
    execute_sql "DESCRIBE COMPUTE POOL ${COMPUTE_POOL_NAME}"
}

suspend_compute_pool() {
    log_info "Suspending compute pool: $COMPUTE_POOL_NAME"
    execute_sql "ALTER COMPUTE POOL ${COMPUTE_POOL_NAME} SUSPEND"
    log_success "Compute pool suspended"
}

resume_compute_pool() {
    log_info "Resuming compute pool: $COMPUTE_POOL_NAME"
    execute_sql "ALTER COMPUTE POOL ${COMPUTE_POOL_NAME} RESUME"
    log_success "Compute pool resumed"
}

# ============================================
# Images Function
# ============================================

list_images() {
    log_info "Listing container images..."
    execute_sql "SHOW IMAGES IN IMAGE REPOSITORY BORDEREAU_REPOSITORY"
}

# ============================================
# Show All Function
# ============================================

show_all() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📊 Full Stack Service Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    show_backend_status
    show_frontend_status
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  💻 Compute Pool"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    show_compute_pool
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📝 Recent Logs"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ "$USE_UNIFIED_SERVICE" == "true" ]; then
        echo -e "${CYAN}Backend (last 10 lines):${NC}"
        execute_sql "CALL SYSTEM\\\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${UNIFIED_SERVICE_NAME}', '0', 'backend', 10)"
        echo ""
        
        echo -e "${MAGENTA}Frontend (last 10 lines):${NC}"
        execute_sql "CALL SYSTEM\\\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${UNIFIED_SERVICE_NAME}', '0', 'frontend', 10)"
    else
        echo -e "${CYAN}Backend (last 10 lines):${NC}"
        execute_sql "CALL SYSTEM\\\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${BACKEND_SERVICE_NAME}', '0', 'backend', 10)"
        echo ""
        
        echo -e "${MAGENTA}Frontend (last 10 lines):${NC}"
        execute_sql "CALL SYSTEM\\\$GET_SERVICE_LOGS('${DATABASE_NAME}.${SCHEMA_NAME}.${FRONTEND_SERVICE_NAME}', '0', 'frontend', 10)"
    fi
    echo ""
}

# ============================================
# Health Check Function
# ============================================

health_check() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🏥 Health Check"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    detect_service_model
    
    if [ "$USE_UNIFIED_SERVICE" == "true" ]; then
        # Unified service - single endpoint serves both frontend and backend via proxy
        local endpoint=$(get_service_endpoint "$UNIFIED_SERVICE_NAME")
        
        echo -e "${CYAN}Backend Health (via API proxy):${NC}"
        if [ "$endpoint" != "provisioning" ]; then
            local response=$(curl -s -w "\n%{http_code}" "${endpoint}/api/health" 2>/dev/null || echo "000")
            local http_code=$(echo "$response" | tail -n1)
            local body=$(echo "$response" | head -n-1)
            
            if [ "$http_code" == "200" ]; then
                echo -e "  ${GREEN}✓ Healthy (HTTP $http_code)${NC}"
                echo -e "  Response: $body"
            else
                echo -e "  ${RED}✗ Unhealthy (HTTP $http_code)${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠ Endpoint not ready${NC}"
        fi
        
        echo ""
        
        echo -e "${MAGENTA}Frontend Health:${NC}"
        if [ "$endpoint" != "provisioning" ]; then
            local response=$(curl -s -w "\n%{http_code}" "${endpoint}/" 2>/dev/null || echo "000")
            local http_code=$(echo "$response" | tail -n1)
            
            if [ "$http_code" == "200" ]; then
                echo -e "  ${GREEN}✓ Accessible (HTTP $http_code)${NC}"
            else
                echo -e "  ${RED}✗ Not accessible (HTTP $http_code)${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠ Endpoint not ready${NC}"
        fi
    else
        # Separate services
        local backend_endpoint=$(get_service_endpoint "$BACKEND_SERVICE_NAME")
        local frontend_endpoint=$(get_service_endpoint "$FRONTEND_SERVICE_NAME")
        
        # Check backend
        echo -e "${CYAN}Backend Health:${NC}"
        if [ "$backend_endpoint" != "provisioning" ]; then
            local response=$(curl -s -w "\n%{http_code}" "${backend_endpoint}/api/health" 2>/dev/null || echo "000")
            local http_code=$(echo "$response" | tail -n1)
            local body=$(echo "$response" | head -n-1)
            
            if [ "$http_code" == "200" ]; then
                echo -e "  ${GREEN}✓ Healthy (HTTP $http_code)${NC}"
                echo -e "  Response: $body"
            else
                echo -e "  ${RED}✗ Unhealthy (HTTP $http_code)${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠ Endpoint not ready${NC}"
        fi
        
        echo ""
        
        # Check frontend
        echo -e "${MAGENTA}Frontend Health:${NC}"
        if [ "$frontend_endpoint" != "provisioning" ]; then
            local response=$(curl -s -w "\n%{http_code}" "${frontend_endpoint}/" 2>/dev/null || echo "000")
            local http_code=$(echo "$response" | tail -n1)
            
            if [ "$http_code" == "200" ]; then
                echo -e "  ${GREEN}✓ Accessible (HTTP $http_code)${NC}"
            else
                echo -e "  ${RED}✗ Not accessible (HTTP $http_code)${NC}"
            fi
            
            # Check API proxy
            echo ""
            echo -e "  ${BLUE}Testing API proxy...${NC}"
            local api_response=$(curl -s -w "\n%{http_code}" "${frontend_endpoint}/api/health" 2>/dev/null || echo "000")
            local api_http_code=$(echo "$api_response" | tail -n1)
            local api_body=$(echo "$api_response" | head -n-1)
            
            if [ "$api_http_code" == "200" ]; then
                echo -e "  ${GREEN}✓ API proxy working (HTTP $api_http_code)${NC}"
                echo -e "  Response: $api_body"
            else
                echo -e "  ${RED}✗ API proxy not working (HTTP $api_http_code)${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠ Endpoint not ready${NC}"
        fi
    fi
    
    echo ""
}

# ============================================
# Help Function
# ============================================

show_help() {
    cat << 'EOF'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🛠️  Unified Service Management
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Usage: ./manage_services.sh [COMMAND] [SERVICE] [OPTIONS]

COMMANDS:
  status [SERVICE]           Show service status and endpoint
  logs [SERVICE] [N]         Show service logs (default: 100 lines)
  endpoints                  Show all service endpoints
  health                     Run health checks on all services
  
  suspend [SERVICE]          Suspend service(s)
  resume [SERVICE]           Resume service(s)
  restart [SERVICE]          Restart service(s) (suspend + resume)
  restart-image [SERVICE]    Restart and pull new image
  drop [SERVICE]             Drop service(s) (with confirmation)
  
  pool-status                Show compute pool status
  pool-suspend               Suspend compute pool
  pool-resume                Resume compute pool
  
  images                     List container images
  all                        Show all status information
  help                       Show this help message

SERVICE OPTIONS:
  backend                    Backend service (API)
  frontend                   Frontend service (UI)
  all                        Both services (default)

EXAMPLES:
  # View status
  ./manage_services.sh status              # Both services
  ./manage_services.sh status backend      # Backend only
  ./manage_services.sh status frontend     # Frontend only
  
  # View logs
  ./manage_services.sh logs backend 50     # Backend logs (50 lines)
  ./manage_services.sh logs frontend       # Frontend logs (100 lines)
  ./manage_services.sh logs all 20         # Both services (20 lines each)
  
  # Endpoints and health
  ./manage_services.sh endpoints           # Show all endpoints
  ./manage_services.sh health              # Run health checks
  
  # Service control
  ./manage_services.sh restart backend     # Restart backend
  ./manage_services.sh restart all         # Restart both
  ./manage_services.sh suspend frontend    # Suspend frontend
  ./manage_services.sh resume frontend     # Resume frontend
  
  # Update with new image
  ./manage_services.sh restart-image backend   # Backend only
  ./manage_services.sh restart-image all       # Both services
  
  # Complete overview
  ./manage_services.sh all                 # Show everything

WORKFLOW FOR DEPLOYING NEW IMAGE:
  1. Deploy new image:
     ./deploy_full_stack.sh
  
  2. Or manually:
     # Backend
     docker build --platform linux/amd64 -f docker/Dockerfile.backend ...
     docker push ...
     ./manage_services.sh restart-image backend
     
     # Frontend
     docker build --platform linux/amd64 -f docker/Dockerfile.frontend ...
     docker push ...
     ./manage_services.sh restart-image frontend

ENVIRONMENT VARIABLES:
  SNOWFLAKE_ACCOUNT         Snowflake account
  DATABASE_NAME             Database name
  BACKEND_SERVICE_NAME      Backend service name
  FRONTEND_SERVICE_NAME     Frontend service name
  COMPUTE_POOL_NAME         Compute pool name

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
}

# ============================================
# Main
# ============================================

case "${1:-help}" in
    status)
        show_status "${2:-all}"
        ;;
    logs)
        show_logs "${2:-backend}" "${3:-100}"
        ;;
    endpoints)
        show_endpoints
        ;;
    health)
        health_check
        ;;
    suspend)
        suspend_service "${2:-all}"
        ;;
    resume)
        resume_service "${2:-all}"
        ;;
    restart)
        restart_service "${2:-all}"
        ;;
    restart-image)
        restart_with_new_image "${2:-all}"
        ;;
    drop)
        drop_service "${2:-}"
        ;;
    pool-status)
        show_compute_pool
        ;;
    pool-suspend)
        suspend_compute_pool
        ;;
    pool-resume)
        resume_compute_pool
        ;;
    images)
        list_images
        ;;
    all)
        show_all
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
