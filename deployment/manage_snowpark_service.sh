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
    snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        $1
    " --connection DEPLOYMENT
}

# ============================================
# Service Management Commands
# ============================================

show_status() {
    log_info "Getting service status..."
    execute_sql "SELECT SYSTEM\$GET_SERVICE_STATUS('${SERVICE_NAME}')"
    
    # Also show endpoint
    echo ""
    log_info "Service endpoint:"
    local endpoint_output=$(snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        SHOW ENDPOINTS IN SERVICE ${SERVICE_NAME};
    " --connection DEPLOYMENT --format json 2>/dev/null)
    
    # Extract ingress_url from the JSON output (it's in the third array [2][0])
    local endpoint=$(echo "$endpoint_output" | jq -r '.[2][0].ingress_url // empty' 2>/dev/null | tr -d '\n' | sed 's/ //g')
    
    if [ -n "$endpoint" ] && [ "$endpoint" != "null" ] && [[ ! "$endpoint" =~ "provisioning" ]]; then
        echo -e "${GREEN}https://${endpoint}${NC}"
        echo -e "${BLUE}Test:${NC} curl https://${endpoint}/api/health"
    else
        echo -e "${YELLOW}Endpoint provisioning in progress...${NC}"
        echo -e "${BLUE}Check again in a few minutes:${NC} ./manage_snowpark_service.sh endpoint"
    fi
}

show_logs() {
    local lines="${1:-100}"
    log_info "Getting service logs (last $lines lines)..."
    execute_sql "SELECT SYSTEM\$GET_SERVICE_LOGS('${SERVICE_NAME}', 0, 'backend', ${lines})"
}

get_endpoint() {
    log_info "Getting service endpoint..."
    execute_sql "SHOW ENDPOINTS IN SERVICE ${SERVICE_NAME}"
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

restart_with_new_image() {
    log_info "Restarting service with new image: $SERVICE_NAME"
    log_info "This will pull the latest image from the repository"
    echo ""
    
    # Suspend service
    log_info "Suspending service..."
    execute_sql "ALTER SERVICE ${SERVICE_NAME} SUSPEND"
    
    # Wait for service to suspend
    log_info "Waiting for service to suspend..."
    sleep 5
    
    # Update service specification (forces image pull)
    log_info "Updating service specification (pulling new image)..."
    execute_sql "ALTER SERVICE ${SERVICE_NAME} FROM @SERVICE_SPECS SPECIFICATION_FILE = 'service_spec.yaml'"
    
    # Resume service
    log_info "Resuming service..."
    execute_sql "ALTER SERVICE ${SERVICE_NAME} RESUME"
    
    echo ""
    log_success "Service restarted with new image"
    log_info "The service will pull the latest image and restart"
    log_info "Check status in 30-60 seconds:"
    echo -e "  ${BLUE}./manage_snowpark_service.sh status${NC}"
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
  status              Show service status and endpoint URL
  logs [N]            Show service logs (default: 100 lines)
  endpoint            Get service endpoint URL
  suspend             Suspend the service
  resume              Resume the service
  restart             Restart the service (suspend + resume)
  restart-image       Restart and pull new image (use after pushing new image)
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
  $0 status                    # Show service status and endpoint
  $0 logs 50                   # Show last 50 log lines
  $0 restart                   # Restart the service
  $0 restart-image             # Restart and pull new image
  $0 all                       # Show all information

Workflow for deploying new image:
  1. Build and push new image:
     cd deployment
     ./deploy_snowpark_container.sh
  
  2. Or manually:
     docker build --platform linux/amd64 -f docker/Dockerfile.backend -t <repo>/<image>:latest .
     docker push <repo>/<image>:latest
     ./manage_snowpark_service.sh restart-image

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
    restart-image)
        restart_with_new_image
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
