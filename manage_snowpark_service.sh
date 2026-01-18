#!/bin/bash

# ============================================
# Snowpark Container Service Management Script
# ============================================
# Manage deployed Snowpark Container Services
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-SFSENORTHAMERICA-TBOON_AWS2}"
SNOWFLAKE_USER="${SNOWFLAKE_USER:-DEMO_SVC}"
SNOWFLAKE_ROLE="${SNOWFLAKE_ROLE:-BORDEREAU_PROCESSING_PIPELINE_ADMIN}"
SNOWFLAKE_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH}"
DATABASE_NAME="${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
SCHEMA_NAME="${SCHEMA_NAME:-PUBLIC}"
SERVICE_NAME="${SERVICE_NAME:-BORDEREAU_SERVICE}"
COMPUTE_POOL_NAME="${COMPUTE_POOL_NAME:-BORDEREAU_COMPUTE_POOL}"

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

execute_sql() {
    snow sql -q "$1" \
        --account "$SNOWFLAKE_ACCOUNT" \
        --user "$SNOWFLAKE_USER" \
        --role "$SNOWFLAKE_ROLE" \
        --warehouse "$SNOWFLAKE_WAREHOUSE" \
        --database "$DATABASE_NAME"
}

# ============================================
# Service Management Commands
# ============================================

show_status() {
    log_info "Getting service status..."
    execute_sql "SELECT SYSTEM\$GET_SERVICE_STATUS('${SERVICE_NAME}')"
}

show_logs() {
    local lines="${1:-100}"
    log_info "Getting service logs (last $lines lines)..."
    execute_sql "SELECT SYSTEM\$GET_SERVICE_LOGS('${SERVICE_NAME}', 0, 'backend', ${lines})"
}

get_endpoint() {
    log_info "Getting service endpoint..."
    execute_sql "SELECT SYSTEM\$GET_SERVICE_ENDPOINT('${SERVICE_NAME}', 'backend')"
}

suspend_service() {
    log_info "Suspending service: $SERVICE_NAME"
    execute_sql "ALTER SERVICE ${SERVICE_NAME} SUSPEND"
    log_success "Service suspended"
}

resume_service() {
    log_info "Resuming service: $SERVICE_NAME"
    execute_sql "ALTER SERVICE ${SERVICE_NAME} RESUME"
    log_success "Service resumed"
}

restart_service() {
    log_info "Restarting service: $SERVICE_NAME"
    suspend_service
    sleep 5
    resume_service
}

drop_service() {
    log_warning "Dropping service: $SERVICE_NAME"
    read -p "Are you sure? This will delete the service (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        execute_sql "DROP SERVICE IF EXISTS ${SERVICE_NAME}"
        log_success "Service dropped"
    else
        log_info "Cancelled"
    fi
}

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

list_images() {
    log_info "Listing container images..."
    execute_sql "SHOW IMAGES IN IMAGE REPOSITORY BORDEREAU_REPOSITORY"
}

show_all() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📊 Snowpark Container Service Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "🔹 Service Status:"
    show_status
    echo ""
    
    echo "🔹 Service Endpoint:"
    get_endpoint
    echo ""
    
    echo "🔹 Compute Pool:"
    show_compute_pool
    echo ""
    
    echo "🔹 Recent Logs (last 20 lines):"
    show_logs 20
    echo ""
}

# ============================================
# Main Menu
# ============================================

show_help() {
    cat << EOF

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  status              Show service status
  logs [N]            Show service logs (default: 100 lines)
  endpoint            Get service endpoint URL
  suspend             Suspend the service
  resume              Resume the service
  restart             Restart the service (suspend + resume)
  drop                Drop the service (with confirmation)
  
  pool-status         Show compute pool status
  pool-suspend        Suspend compute pool
  pool-resume         Resume compute pool
  
  images              List container images
  all                 Show all status information
  
  help                Show this help message

Environment Variables:
  SNOWFLAKE_ACCOUNT   Snowflake account (default: SFSENORTHAMERICA-TBOON_AWS2)
  SNOWFLAKE_USER      Snowflake user (default: DEMO_SVC)
  SNOWFLAKE_ROLE      Snowflake role (default: BORDEREAU_PROCESSING_PIPELINE_ADMIN)
  DATABASE_NAME       Database name (default: BORDEREAU_PROCESSING_PIPELINE)
  SERVICE_NAME        Service name (default: BORDEREAU_SERVICE)
  COMPUTE_POOL_NAME   Compute pool name (default: BORDEREAU_COMPUTE_POOL)

Examples:
  $0 status                    # Show service status
  $0 logs 50                   # Show last 50 log lines
  $0 restart                   # Restart the service
  $0 all                       # Show all information

EOF
}

# ============================================
# Main
# ============================================

case "${1:-help}" in
    status)
        show_status
        ;;
    logs)
        show_logs "${2:-100}"
        ;;
    endpoint)
        get_endpoint
        ;;
    suspend)
        suspend_service
        ;;
    resume)
        resume_service
        ;;
    restart)
        restart_service
        ;;
    drop)
        drop_service
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
        show_help
        exit 1
        ;;
esac
