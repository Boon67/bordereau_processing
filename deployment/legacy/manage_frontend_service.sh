#!/bin/bash

# ============================================
# Frontend Service Management Script
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DATABASE_NAME="${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
SCHEMA_NAME="${SCHEMA_NAME:-PUBLIC}"
FRONTEND_SERVICE_NAME="${FRONTEND_SERVICE_NAME:-BORDEREAU_FRONTEND_SERVICE}"
COMPUTE_POOL_NAME="${COMPUTE_POOL_NAME:-BORDEREAU_COMPUTE_POOL}"

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

execute_sql() {
    snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        $1
    " --connection DEPLOYMENT
}

show_status() {
    log_info "Getting frontend service status..."
    execute_sql "SELECT SYSTEM\$GET_SERVICE_STATUS('${FRONTEND_SERVICE_NAME}')"
    
    # Also show endpoint
    echo ""
    log_info "Frontend endpoint:"
    local endpoint_output=$(snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        SHOW ENDPOINTS IN SERVICE ${FRONTEND_SERVICE_NAME};
    " --connection DEPLOYMENT --format json 2>/dev/null)
    
    local endpoint=$(echo "$endpoint_output" | jq -r '.[2][0].ingress_url // empty' 2>/dev/null | tr -d '\n' | sed 's/ //g')
    
    if [ -n "$endpoint" ] && [ "$endpoint" != "null" ] && [[ ! "$endpoint" =~ "provisioning" ]]; then
        echo -e "${GREEN}https://${endpoint}${NC}"
        echo -e "${BLUE}Open in browser:${NC} https://${endpoint}"
    else
        echo -e "${YELLOW}Endpoint provisioning in progress...${NC}"
        echo -e "${BLUE}Check again in a few minutes:${NC} ./manage_frontend_service.sh endpoint"
    fi
}

show_logs() {
    local lines="${1:-100}"
    log_info "Getting frontend service logs (last $lines lines)..."
    execute_sql "SELECT SYSTEM\$GET_SERVICE_LOGS('${FRONTEND_SERVICE_NAME}', 0, 'frontend', ${lines})"
}

get_endpoint() {
    log_info "Getting frontend endpoint..."
    execute_sql "SHOW ENDPOINTS IN SERVICE ${FRONTEND_SERVICE_NAME}"
}

suspend_service() {
    log_info "Suspending frontend service: $FRONTEND_SERVICE_NAME"
    execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} SUSPEND"
    log_success "Service suspended"
}

resume_service() {
    log_info "Resuming frontend service: $FRONTEND_SERVICE_NAME"
    execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} RESUME"
    log_success "Service resumed"
}

restart_service() {
    log_info "Restarting frontend service: $FRONTEND_SERVICE_NAME"
    suspend_service
    sleep 5
    resume_service
}

restart_with_new_image() {
    log_info "Restarting frontend service with new image: $FRONTEND_SERVICE_NAME"
    log_info "This will pull the latest image from the repository"
    echo ""
    
    execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} SUSPEND"
    log_info "Waiting for service to suspend..."
    sleep 5
    
    log_info "Updating service specification (pulling new image)..."
    execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} FROM @SERVICE_SPECS SPECIFICATION_FILE = 'frontend_service_spec.yaml'"
    
    log_info "Resuming service..."
    execute_sql "ALTER SERVICE ${FRONTEND_SERVICE_NAME} RESUME"
    
    echo ""
    log_success "Service restarted with new image"
    log_info "Check status in 30-60 seconds:"
    echo -e "  ${BLUE}./manage_frontend_service.sh status${NC}"
}

drop_service() {
    log_warning "Dropping frontend service: $FRONTEND_SERVICE_NAME"
    read -p "Are you sure? This will delete the service (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        execute_sql "DROP SERVICE IF EXISTS ${FRONTEND_SERVICE_NAME}"
        log_success "Service dropped"
    else
        log_info "Cancelled"
    fi
}

show_all() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📊 Frontend Service Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "🔹 Service Status:"
    show_status
    echo ""
    
    echo "🔹 Recent Logs (last 20 lines):"
    show_logs 20
    echo ""
}

show_help() {
    cat << HELP

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  status              Show frontend service status and endpoint URL
  logs [N]            Show service logs (default: 100 lines)
  endpoint            Get service endpoint URL
  suspend             Suspend the service
  resume              Resume the service
  restart             Restart the service (suspend + resume)
  restart-image       Restart and pull new image (use after pushing new image)
  drop                Drop the service (with confirmation)
  all                 Show all status information
  help                Show this help message

Examples:
  $0 status                    # Show service status and endpoint
  $0 logs 50                   # Show last 50 log lines
  $0 restart                   # Restart the service
  $0 restart-image             # Restart and pull new image

HELP
}

# Main
case "${1:-help}" in
    status) show_status ;;
    logs) show_logs "${2:-100}" ;;
    endpoint) get_endpoint ;;
    suspend) suspend_service ;;
    resume) resume_service ;;
    restart) restart_service ;;
    restart-image) restart_with_new_image ;;
    drop) drop_service ;;
    all) show_all ;;
    help|--help|-h) show_help ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
