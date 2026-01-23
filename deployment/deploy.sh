#!/bin/bash
# ============================================
# SNOWFLAKE FILE PROCESSING PIPELINE
# Master Deployment Script (Using Snow CLI)
# ============================================
# Purpose: Deploy both Bronze and Silver layers using Snow CLI
# Usage: ./deploy.sh [options] [connection_name] [config_file]
#   Options:
#     -v, --verbose    Enable verbose logging (shows all SQL output)
#     -h, --help       Show this help message
#   connection_name: Name of the Snowflake CLI connection (default: uses default connection)
#   config_file: Path to config file (default: default.config, custom.config if exists)
# ============================================
clear
set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Function to show help
show_help() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗"
    echo -e "║  SNOWFLAKE FILE PROCESSING PIPELINE DEPLOYMENT SCRIPT     ║"
    echo -e "╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}USAGE:${NC}"
    echo "    ./deploy.sh [OPTIONS] [CONNECTION_NAME] [CONFIG_FILE]"
    echo ""
    echo -e "${YELLOW}OPTIONS:${NC}"
    echo -e "    ${GREEN}-v, --verbose${NC}"
    echo "        Enable verbose logging. Shows all SQL statements and their output"
    echo "        during deployment. Useful for debugging deployment issues."
    echo ""
    echo -e "    ${GREEN}-h, --help${NC}"
    echo "        Display this help message and exit."
    echo ""
    echo -e "    ${GREEN}-u, --undeploy${NC}"
    echo "        Undeploy (remove) the database and all associated resources."
    echo "        ${RED}WARNING: This will delete all data!${NC}"
    echo ""
    echo -e "${YELLOW}ARGUMENTS:${NC}"
    echo -e "    ${GREEN}CONNECTION_NAME${NC}"
    echo "        Name of the Snowflake CLI connection to use for deployment."
    echo "        If not specified, uses the default connection configured in"
    echo "        ~/.snowflake/connections.toml"
    echo ""
    echo -e "    ${GREEN}CONFIG_FILE${NC}"
    echo "        Path to a custom configuration file. The script loads configuration"
    echo "        in the following order (later files override earlier ones):"
    echo "          1. default.config (always loaded if exists)"
    echo "          2. custom.config (loaded if exists)"
    echo "          3. CONFIG_FILE (loaded if specified)"
    echo ""
    echo -e "${YELLOW}CONFIGURATION:${NC}"
    echo "    Configuration files should define the following variables:"
    echo "        SNOWFLAKE_CONNECTION       - Connection name (empty = prompt user)"
    echo "        USE_DEFAULT_CONNECTION     - Set to 'true' to use default connection"
    echo "        AUTO_APPROVE               - Set to 'true' to skip confirmation prompts"
    echo "        DATABASE_NAME              - Target database name"
    echo "        SNOWFLAKE_WAREHOUSE        - Warehouse to use for deployment"
    echo "        SNOWFLAKE_ROLE             - Role to use (default: SYSADMIN)"
    echo "        BRONZE_SCHEMA_NAME         - Bronze layer schema name"
    echo "        SILVER_SCHEMA_NAME         - Silver layer schema name"
    echo "        BRONZE_DISCOVERY_SCHEDULE  - Task schedule for file discovery"
    echo "        DEPLOY_CONTAINERS          - Set to 'true' to automatically deploy to SPCS"
    echo ""
    echo "    Note: Container deployment to SPCS is optional. Set DEPLOY_CONTAINERS=true"
    echo "          in your config file to deploy automatically, or you will be prompted"
    echo "          after database layers are deployed."
    echo ""
    echo -e "${YELLOW}EXAMPLES:${NC}"
    echo -e "    ${CYAN}# Deploy using default connection and default.config${NC}"
    echo "    ./deploy.sh"
    echo ""
    echo -e "    ${CYAN}# Deploy with verbose logging${NC}"
    echo "    ./deploy.sh -v"
    echo ""
    echo -e "    ${CYAN}# Deploy using specific connection${NC}"
    echo "    ./deploy.sh PRODUCTION"
    echo ""
    echo -e "    ${CYAN}# Deploy with custom config file${NC}"
    echo "    ./deploy.sh PRODUCTION /path/to/prod.config"
    echo ""
    echo -e "    ${CYAN}# Verbose deployment with custom config${NC}"
    echo "    ./deploy.sh -v PRODUCTION /path/to/prod.config"
    echo ""
    echo -e "${YELLOW}PREREQUISITES:${NC}"
    echo "    - Snowflake CLI (snow) must be installed and configured"
    echo "    - Connection must have SYSADMIN and SECURITYADMIN roles"
    echo "    - EXECUTE TASK privilege on SYSADMIN (script will attempt to grant)"
    echo "    - Warehouse must exist and be accessible"
    echo "    - For containers: CREATE COMPUTE POOL and BIND SERVICE ENDPOINT (script will check)"
    echo ""
    echo -e "${YELLOW}DEPLOYMENT PROCESS:${NC}"
    echo "    1. Validates Snowflake CLI connection"
    echo "    2. Checks required roles (SYSADMIN, SECURITYADMIN)"
    echo "    3. Verifies warehouse exists"
    echo "    4. Checks/grants EXECUTE TASK privilege"
    echo "    5. Checks container service privileges (for SPCS deployment)"
    echo "    6. Displays configuration and prompts for confirmation"
    echo "    7. Deploys Bronze layer (schemas, tables, procedures, tasks)"
    echo "    8. Deploys Silver layer (schemas, tables, procedures, tasks)"
    echo "    9. Deploys Gold layer (schemas, tables, procedures, tasks)"
    echo "    10. Optionally deploys to Snowpark Container Services (SPCS)"
    echo ""
    echo -e "${YELLOW}OUTPUT:${NC}"
    echo "    Deployment logs are saved to: logs/deployment_YYYYMMDD_HHMMSS.log"
    echo ""
    echo "For more information, see: DEPLOYMENT_SNOW_CLI.md"
}

# Parse options
VERBOSE=false
UNDEPLOY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--undeploy)
            UNDEPLOY=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Arguments
CONNECTION_NAME="${1:-}"
CONFIG_FILE="${2:-}"

# Export verbose flag for child scripts
export DEPLOY_VERBOSE="$VERBOSE"

# Load configuration files in order (later files override earlier ones)
# 1. Load default.config
if [[ -f "${SCRIPT_DIR}/default.config" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/default.config"
fi

# 2. Load custom.config if it exists (overrides default.config)
if [[ -f "${SCRIPT_DIR}/custom.config" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/custom.config"
fi

# 3. Load specified config file if provided (overrides all)
if [[ -n "$CONFIG_FILE" ]]; then
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    else
        echo -e "${RED}✗${NC} Config file not found: $CONFIG_FILE"
        exit 1
    fi
fi

# Create logs directory
mkdir -p "${PROJECT_ROOT}/logs"

# Log file
LOG_FILE="${PROJECT_ROOT}/logs/deployment_$(date +%Y%m%d_%H%M%S).log"

# Function to print header
print_header() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║     SNOWFLAKE FILE PROCESSING PIPELINE DEPLOYMENT         ║"
    echo "║              Using Snowflake CLI (snow)                   ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
}

# Function to log message
log_message() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case $level in
        INFO)
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}✓${NC} $message"
            ;;
        WARNING)
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        ERROR)
            echo -e "${RED}✗${NC} $message"
            ;;
        DEBUG)
            if [[ "$VERBOSE" == "true" ]]; then
                echo -e "${CYAN}[DEBUG]${NC} $message"
            fi
            ;;
    esac
}

# Function to log verbose
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}$@${NC}"
    fi
    echo "$@" >> "$LOG_FILE"
}

# Start deployment
START_TIME=$(date +%s)

print_header

# Handle undeploy mode
if [[ "$UNDEPLOY" == "true" ]]; then
    log_message INFO "UNDEPLOY MODE ACTIVATED"
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                  ⚠️  WARNING  ⚠️                           ║${NC}"
    echo -e "${RED}╠═══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║  This will DELETE the following:                         ║${NC}"
    echo -e "${RED}║  - Database: ${DATABASE_NAME:-FILE_PROCESSING_PIPELINE}  ║${NC}"
    echo -e "${RED}║  - All data in Bronze and Silver layers                  ║${NC}"
    echo -e "${RED}║  - All roles, tasks, and procedures                      ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        log_message INFO "Undeploy cancelled by user"
        exit 0
    fi
    
    DATABASE="${DATABASE_NAME:-FILE_PROCESSING_PIPELINE}"
    
    echo ""
    read -p "Type the database name to confirm: " db_confirmation
    
    if [[ "$db_confirmation" != "$DATABASE" ]]; then
        log_message ERROR "Database name does not match. Undeploy cancelled."
        exit 1
    fi
    
    # Get connection details
    if [[ -z "$CONNECTION_NAME" ]]; then
        CONNECTION_NAME=$(snow connection list --format json | jq -r '.[] | select(.is_default == true) | .connection_name // empty' 2>/dev/null)
    fi
    
    if [[ -z "$CONNECTION_NAME" ]]; then
        CONNECTION_NAME="default"
    fi
    
    log_message INFO "Undeploying from connection: $CONNECTION_NAME"
    log_message INFO "Dropping database: $DATABASE"
    
    # Drop database
    if snow sql --connection "$CONNECTION_NAME" -q "USE ROLE SYSADMIN; DROP DATABASE IF EXISTS ${DATABASE};" >/dev/null 2>&1; then
        log_message SUCCESS "Database ${DATABASE} dropped"
    else
        log_message WARNING "Failed to drop database or database does not exist"
    fi
    
    # Drop roles (requires SECURITYADMIN)
    log_message INFO "Dropping roles..."
    
    if snow sql --connection "$CONNECTION_NAME" -q "USE ROLE SECURITYADMIN; DROP ROLE IF EXISTS ${DATABASE}_ADMIN;" >/dev/null 2>&1; then
        log_message SUCCESS "Role ${DATABASE}_ADMIN dropped"
    else
        log_message WARNING "Failed to drop role ${DATABASE}_ADMIN or role does not exist"
    fi
    
    if snow sql --connection "$CONNECTION_NAME" -q "USE ROLE SECURITYADMIN; DROP ROLE IF EXISTS ${DATABASE}_READWRITE;" >/dev/null 2>&1; then
        log_message SUCCESS "Role ${DATABASE}_READWRITE dropped"
    else
        log_message WARNING "Failed to drop role ${DATABASE}_READWRITE or role does not exist"
    fi
    
    if snow sql --connection "$CONNECTION_NAME" -q "USE ROLE SECURITYADMIN; DROP ROLE IF EXISTS ${DATABASE}_READONLY;" >/dev/null 2>&1; then
        log_message SUCCESS "Role ${DATABASE}_READONLY dropped"
    else
        log_message WARNING "Failed to drop role ${DATABASE}_READONLY or role does not exist"
    fi
    
    echo ""
    log_message SUCCESS "Undeploy completed successfully"
    echo -e "${YELLOW}Database and all associated resources have been removed.${NC}"
    exit 0
fi

# Check and setup Snowflake CLI connection
log_message INFO "Checking Snowflake CLI configuration..."

if ! bash "${SCRIPT_DIR}/check_snow_connection.sh"; then
    log_message ERROR "Failed to setup Snowflake connection"
    exit 1
fi

# Get connection details from snow CLI
if [[ -z "$CONNECTION_NAME" ]]; then
    # Check if config specifies to use default connection
    if [[ "${USE_DEFAULT_CONNECTION}" == "true" ]]; then
        CONNECTION_NAME=$(snow connection list --format json | jq -r '.[] | select(.is_default == true) | .connection_name // empty' 2>/dev/null)
        if [[ -z "$CONNECTION_NAME" ]]; then
            CONNECTION_NAME="default"
        fi
        log_message INFO "Using default connection: $CONNECTION_NAME"
    elif [[ -n "${SNOWFLAKE_CONNECTION}" ]]; then
        # Use connection specified in config
        CONNECTION_NAME="${SNOWFLAKE_CONNECTION}"
        log_message INFO "Using connection from config: $CONNECTION_NAME"
    else
        # Prompt user to select connection
        echo ""
        echo -e "${CYAN}Available Snowflake Connections:${NC}"
        echo ""
        
        # Get list of connections
        connections=()
        while IFS= read -r conn; do
            connections+=("$conn")
        done < <(snow connection list --format json 2>/dev/null | jq -r '.[].connection_name' 2>/dev/null)
        
        if [[ ${#connections[@]} -eq 0 ]]; then
            log_message ERROR "No Snowflake connections found. Please configure a connection first."
            exit 1
        fi
        
        # Display connections with numbers
        for i in "${!connections[@]}"; do
            default_marker=""
            if snow connection list --format json 2>/dev/null | jq -r ".[] | select(.connection_name == \"${connections[$i]}\") | .is_default" | grep -q "true"; then
                default_marker=" ${GREEN}(default)${NC}"
            fi
            echo -e "  ${YELLOW}$((i+1))${NC}) ${connections[$i]}${default_marker}"
        done
        
        echo ""
        read -p "Select connection number [1-${#connections[@]}]: " selection
        
        # Validate selection
        if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt ${#connections[@]} ]]; then
            log_message ERROR "Invalid selection"
            exit 1
        fi
        
        CONNECTION_NAME="${connections[$((selection-1))]}"
        log_message INFO "Selected connection: $CONNECTION_NAME"
    fi
else
    log_message INFO "Using connection: $CONNECTION_NAME"
fi

# Get account from snow CLI connection
ACCOUNT=$(snow connection list --format json | jq -r ".[] | select(.connection_name == \"$CONNECTION_NAME\") | .account // empty" 2>/dev/null)

# Use config file values, fall back to hardcoded defaults
# DATABASE_NAME, BRONZE_SCHEMA_NAME, SILVER_SCHEMA_NAME come from config file
DATABASE="${DATABASE_NAME:-FILE_PROCESSING_PIPELINE}"
WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH}"
ROLE="${SNOWFLAKE_ROLE:-SYSADMIN}"
BRONZE_SCHEMA="${BRONZE_SCHEMA_NAME:-BRONZE}"
SILVER_SCHEMA="${SILVER_SCHEMA_NAME:-SILVER}"
DISCOVERY_SCHEDULE="${BRONZE_DISCOVERY_SCHEDULE:-60 MINUTE}"

# Export for use by deploy_bronze.sh and deploy_silver.sh
export DEPLOY_DATABASE="$DATABASE"
export DEPLOY_WAREHOUSE="$WAREHOUSE"
export DEPLOY_BRONZE_SCHEMA="$BRONZE_SCHEMA"
export DEPLOY_SILVER_SCHEMA="$SILVER_SCHEMA"
export DEPLOY_DISCOVERY_SCHEDULE="$DISCOVERY_SCHEDULE"

log_message INFO "Account: $ACCOUNT"
log_message INFO "Database: $DATABASE"
log_message INFO "Warehouse: $WAREHOUSE"
log_message INFO "Role: $ROLE"
log_message INFO "Bronze Schema: $BRONZE_SCHEMA"
log_message INFO "Silver Schema: $SILVER_SCHEMA"
log_message INFO "Log file: $LOG_FILE"
if [[ "$VERBOSE" == "true" ]]; then
    log_message INFO "Verbose logging: ENABLED"
fi

# Display deployment configuration
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}DEPLOYMENT CONFIGURATION${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Connection:        ${CYAN}$CONNECTION_NAME${NC}"
echo -e "  Database:          ${CYAN}$DATABASE${NC}"
echo -e "  Warehouse:         ${CYAN}$WAREHOUSE${NC}"
echo -e "  Bronze Schema:     ${CYAN}$BRONZE_SCHEMA${NC}"
echo -e "  Silver Schema:     ${CYAN}$SILVER_SCHEMA${NC}"
echo -e "  Deploy Containers: ${CYAN}${DEPLOY_CONTAINERS:-false}${NC}"
echo ""
echo -e "  ${YELLOW}Objects to be created:${NC}"
echo -e "    ${GREEN}Database:${NC}"
echo -e "      - ${CYAN}${DATABASE}${NC}"
echo -e "    ${GREEN}Schemas:${NC}"
echo -e "      - ${CYAN}${DATABASE}.${BRONZE_SCHEMA}${NC}"
echo -e "      - ${CYAN}${DATABASE}.${SILVER_SCHEMA}${NC}"
echo -e "      - ${CYAN}${DATABASE}.GOLD${NC}"
echo -e "    ${GREEN}Roles:${NC}"
echo -e "      - ${CYAN}${DATABASE}_ADMIN${NC} (full admin access)"
echo -e "      - ${CYAN}${DATABASE}_READWRITE${NC} (read/write + execute procedures)"
echo -e "      - ${CYAN}${DATABASE}_READONLY${NC} (read-only access)"
echo -e "    ${GREEN}Bronze Layer:${NC}"
echo -e "      - Stages: @SRC, @COMPLETED, @ERROR, @ARCHIVE"
echo -e "      - Tables: TPA_MASTER, RAW_DATA_TABLE, file_processing_queue"
echo -e "      - Procedures: process_csv_file, process_excel_file, discover_files, etc."
echo -e "      - Tasks: File discovery, processing, movement, archival"
echo -e "    ${GREEN}Silver Layer:${NC}"
echo -e "      - Tables: target_schemas, field_mappings, transformation_rules"
echo -e "      - Procedures: create_silver_table, transform_bronze_to_silver, etc."
echo -e "      - Tasks: Bronze to Silver transformation"
echo -e "    ${GREEN}Gold Layer:${NC}"
echo -e "      - Analytics Tables: CLAIMS_ANALYTICS_ALL, MEMBER_360_ALL, etc."
echo -e "      - Metadata: target_schemas, quality_rules, business_metrics"
echo -e "      - Procedures: transform_claims_analytics, run_gold_transformations, etc."
echo -e "      - Tasks: Daily/weekly/monthly analytics refresh"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Confirm deployment (skip if AUTO_APPROVE is true)
if [[ "${AUTO_APPROVE}" == "true" ]]; then
    log_message INFO "AUTO_APPROVE enabled - proceeding with deployment"
else
    read -p "Continue with deployment? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_message INFO "Deployment cancelled by user"
        exit 0
    fi
    echo ""
fi

# Verify required roles are available for this connection.
check_role() {
    local role_name=$1
    local connection_name=$2
    local current_role

    current_role=$(snow sql --connection "$connection_name" --format json -q "SELECT CURRENT_ROLE() AS role" | jq -r '.[0].ROLE // empty' 2>/dev/null)

    if ! snow sql --connection "$connection_name" -q "USE ROLE $role_name;" >/dev/null 2>&1; then
        log_message ERROR "Missing required role or insufficient privileges: $role_name"
        exit 1
    fi

    if [[ -n "$current_role" ]]; then
        snow sql --connection "$connection_name" -q "USE ROLE $current_role;" >/dev/null 2>&1 || true
    fi
}

log_message INFO "Checking required roles: SYSADMIN, SECURITYADMIN"
check_role "SYSADMIN" "$CONNECTION_NAME"
check_role "SECURITYADMIN" "$CONNECTION_NAME"

# Verify warehouse exists
if ! snow sql --connection "$CONNECTION_NAME" -q "SHOW WAREHOUSES LIKE '$WAREHOUSE';" >/dev/null 2>&1; then
    log_message ERROR "Warehouse does not exist or is not accessible: $WAREHOUSE"
    exit 1
fi

# Check EXECUTE TASK privilege for SYSADMIN
log_message INFO "Checking EXECUTE TASK privilege for SYSADMIN..."

EXECUTE_TASK_GRANTED=$(snow sql --connection "$CONNECTION_NAME" --format json -q "SHOW GRANTS TO ROLE SYSADMIN" 2>/dev/null | jq -r '.[] | select(.privilege == "EXECUTE TASK" and .granted_on == "ACCOUNT") | .privilege' 2>/dev/null || echo "")

if [[ -z "$EXECUTE_TASK_GRANTED" ]]; then
    log_message WARNING "EXECUTE TASK privilege not granted to SYSADMIN"
    log_message INFO "Attempting to grant via ACCOUNTADMIN..."
    
    # Check if we can use ACCOUNTADMIN
    if snow sql --connection "$CONNECTION_NAME" -q "USE ROLE ACCOUNTADMIN;" >/dev/null 2>&1; then
        # Grant EXECUTE TASK to SYSADMIN
        if snow sql --connection "$CONNECTION_NAME" -q "USE ROLE ACCOUNTADMIN; GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN WITH GRANT OPTION;" >/dev/null 2>&1; then
            log_message SUCCESS "EXECUTE TASK privilege granted to SYSADMIN"
        else
            log_message ERROR "Failed to grant EXECUTE TASK privilege"
            log_message ERROR "Please run as ACCOUNTADMIN: GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN WITH GRANT OPTION;"
            exit 1
        fi
        # Switch back to SYSADMIN
        snow sql --connection "$CONNECTION_NAME" -q "USE ROLE SYSADMIN;" >/dev/null 2>&1 || true
    else
        log_message ERROR "ACCOUNTADMIN role not available"
        log_message ERROR "Please have an ACCOUNTADMIN run: GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN WITH GRANT OPTION;"
        exit 1
    fi
else
    log_message SUCCESS "EXECUTE TASK privilege verified for SYSADMIN"
fi

# Check Container Service privileges for admin role (if deploying containers)
log_message INFO "Checking container service privileges..."

ADMIN_ROLE_NAME="${DATABASE_NAME}_ADMIN"

# Check if CREATE COMPUTE POOL is granted
CREATE_COMPUTE_POOL_GRANTED=$(snow sql --connection "$CONNECTION_NAME" --format json -q "SHOW GRANTS TO ROLE ${ADMIN_ROLE_NAME}" 2>/dev/null | jq -r '.[] | select(.privilege == "CREATE COMPUTE POOL" and .granted_on == "ACCOUNT") | .privilege' 2>/dev/null || echo "")

# Check if BIND SERVICE ENDPOINT is granted
BIND_ENDPOINT_GRANTED=$(snow sql --connection "$CONNECTION_NAME" --format json -q "SHOW GRANTS TO ROLE ${ADMIN_ROLE_NAME}" 2>/dev/null | jq -r '.[] | select(.privilege == "BIND SERVICE ENDPOINT" and .granted_on == "ACCOUNT") | .privilege' 2>/dev/null || echo "")

if [[ -z "$CREATE_COMPUTE_POOL_GRANTED" ]] || [[ -z "$BIND_ENDPOINT_GRANTED" ]]; then
    log_message WARNING "Container service privileges not fully granted to ${ADMIN_ROLE_NAME}"
    
    if [[ -z "$CREATE_COMPUTE_POOL_GRANTED" ]]; then
        log_message WARNING "  Missing: CREATE COMPUTE POOL ON ACCOUNT"
    fi
    
    if [[ -z "$BIND_ENDPOINT_GRANTED" ]]; then
        log_message WARNING "  Missing: BIND SERVICE ENDPOINT ON ACCOUNT"
    fi
    
    log_message INFO "These privileges are required for Snowpark Container Services deployment"
    log_message INFO "To grant these privileges, run the following SQL as ACCOUNTADMIN:"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}USE ROLE ACCOUNTADMIN;${NC}"
    
    if [[ -z "$CREATE_COMPUTE_POOL_GRANTED" ]]; then
        echo -e "${CYAN}GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE SYSADMIN;${NC}"
    fi
    
    if [[ -z "$BIND_ENDPOINT_GRANTED" ]]; then
        echo -e "${CYAN}GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE SYSADMIN;${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}-- Then SYSADMIN can grant to admin role:${NC}"
    echo -e "${CYAN}USE ROLE SYSADMIN;${NC}"
    
    if [[ -z "$CREATE_COMPUTE_POOL_GRANTED" ]]; then
        echo -e "${CYAN}GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE ${ADMIN_ROLE_NAME};${NC}"
    fi
    
    if [[ -z "$BIND_ENDPOINT_GRANTED" ]]; then
        echo -e "${CYAN}GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE ${ADMIN_ROLE_NAME};${NC}"
    fi
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log_message INFO "Or run: snow sql -f bronze/0_Setup_Container_Privileges.sql --connection $CONNECTION_NAME -D DATABASE_NAME=$DATABASE_NAME"
    echo ""
    log_message WARNING "Container deployment will be skipped if these privileges are not granted"
    log_message INFO "You can continue with Bronze/Silver/Gold deployment and add containers later"
    echo ""
else
    log_message SUCCESS "Container service privileges verified for ${ADMIN_ROLE_NAME}"
fi

# Deploy Bronze Layer
echo ""
echo -e "${CYAN}🥉 Deploying Bronze Layer...${NC}"

if bash "${SCRIPT_DIR}/deploy_bronze.sh" "$CONNECTION_NAME"; then
    log_message SUCCESS "Bronze layer deployed successfully"
else
    log_message ERROR "Bronze layer deployment failed"
    exit 1
fi

# Deploy Silver Layer
echo ""
echo -e "${CYAN}🥈 Deploying Silver Layer...${NC}"

if bash "${SCRIPT_DIR}/deploy_silver.sh" "$CONNECTION_NAME"; then
    log_message SUCCESS "Silver layer deployed successfully"
else
    log_message ERROR "Silver layer deployment failed"
    exit 1
fi

# Load Sample Silver Schemas (Optional)
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}OPTIONAL: LOAD SAMPLE SILVER TARGET SCHEMAS${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Would you like to load sample Silver target schemas?"
echo "This will:"
echo "  • Generate schema definitions for 5 TPAs"
echo "  • Create 4 table types (Medical, Dental, Pharmacy, Eligibility)"
echo "  • Load 310 column definitions"
echo ""

# Default to 'yes' if AUTO_APPROVE is enabled
LOAD_SCHEMAS="y"
if [[ "${AUTO_APPROVE}" != "true" ]]; then
    read -p "Load sample schemas? (y/n) [y]: " -n 1 -r
    echo ""
    LOAD_SCHEMAS=$REPLY
fi

if [[ $LOAD_SCHEMAS =~ ^[Yy]$ ]] || [[ -z $LOAD_SCHEMAS ]]; then
    echo ""
    echo -e "${CYAN}📋 Loading sample Silver target schemas...${NC}"
    
    if bash "${SCRIPT_DIR}/load_sample_schemas.sh" "$CONNECTION_NAME"; then
        log_message SUCCESS "Sample schemas loaded successfully"
        SCHEMAS_LOADED=true
    else
        log_message WARNING "Sample schema loading failed or was skipped"
        SCHEMAS_LOADED=false
    fi
else
    log_message INFO "Skipping sample schema loading"
    SCHEMAS_LOADED=false
fi

# Deploy Gold Layer
echo ""
echo -e "${CYAN}🥇 Deploying Gold Layer...${NC}"

if bash "${SCRIPT_DIR}/deploy_gold.sh" "$CONNECTION_NAME"; then
    log_message SUCCESS "Gold layer deployed successfully"
else
    log_message ERROR "Gold layer deployment failed"
    exit 1
fi

# Optional: Deploy to Snowpark Container Services
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}OPTIONAL: SNOWPARK CONTAINER SERVICES DEPLOYMENT${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if DEPLOY_CONTAINERS is set in config
if [[ "${DEPLOY_CONTAINERS}" == "true" ]]; then
    log_message INFO "DEPLOY_CONTAINERS=true in config - deploying containers automatically"
    DEPLOY_CONTAINERS_DECISION="y"
else
    # Check if container privileges are available before prompting
    if [[ -z "$CREATE_COMPUTE_POOL_GRANTED" ]] || [[ -z "$BIND_ENDPOINT_GRANTED" ]]; then
        log_message INFO "Skipping container deployment prompt (privileges not granted)"
        log_message INFO "Run bronze/0_Setup_Container_Privileges.sql to enable container deployment"
        DEPLOY_CONTAINERS_DECISION="n"
    else
        echo "Would you like to deploy the application to Snowpark Container Services?"
        echo "This will:"
        echo "  • Build Docker images for backend and frontend"
        echo "  • Push images to Snowflake image repository"
        echo "  • Create compute pool (if needed)"
        echo "  • Deploy unified service with health checks"
        echo ""
        
        # Default to 'no' if AUTO_APPROVE is enabled (containers are optional)
        DEPLOY_CONTAINERS_DECISION="n"
        if [[ "${AUTO_APPROVE}" != "true" ]]; then
            read -p "Deploy to Snowpark Container Services? (y/n) [n]: " -n 1 -r
            echo ""
            DEPLOY_CONTAINERS_DECISION=$REPLY
        fi
    fi
fi

if [[ $DEPLOY_CONTAINERS_DECISION =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${CYAN}🐳 Deploying to Snowpark Container Services...${NC}"
    
    if bash "${SCRIPT_DIR}/deploy_container.sh"; then
        log_message SUCCESS "Container deployment completed successfully"
        CONTAINERS_DEPLOYED=true
    else
        log_message WARNING "Container deployment failed or was skipped"
        CONTAINERS_DEPLOYED=false
    fi
else
    log_message INFO "Skipping Snowpark Container Services deployment"
    CONTAINERS_DEPLOYED=false
fi

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Print summary
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                  DEPLOYMENT SUMMARY                       ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║  Connection: $CONNECTION_NAME"
echo "║  Database: $DATABASE"
echo "║  Bronze Schema: $BRONZE_SCHEMA"
echo "║  Silver Schema: $SILVER_SCHEMA"
echo "║  Gold Schema: GOLD"
echo "║  Bronze Layer: ✓ Deployed"
echo "║  Silver Layer: ✓ Deployed"
if [[ "$SCHEMAS_LOADED" == "true" ]]; then
echo "║  Sample Schemas: ✓ Loaded (310 definitions)"
else
echo "║  Sample Schemas: ⊘ Not loaded"
fi
echo "║  Gold Layer: ✓ Deployed"
if [[ "$CONTAINERS_DEPLOYED" == "true" ]]; then
echo "║  Containers: ✓ Deployed to SPCS"
else
echo "║  Containers: ⊘ Not deployed"
fi
echo "║  Duration: ${MINUTES}m ${SECONDS}s"
echo "║  Log: $LOG_FILE"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

log_message SUCCESS "Deployment completed successfully in ${MINUTES}m ${SECONDS}s"

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo ""

if [[ "$CONTAINERS_DEPLOYED" == "true" ]]; then
    echo "Next steps:"
    echo "1. Check service status:"
    echo "   snow spcs service status BORDEREAU_APP --connection $CONNECTION_NAME"
    echo ""
    echo "2. Get service endpoint:"
    echo "   snow spcs service list-endpoints BORDEREAU_APP --connection $CONNECTION_NAME"
    echo ""
    echo "3. Upload sample data:"
    echo "   snow stage put sample_data/claims_data/provider_a/*.csv @BRONZE.SRC/provider_a/ --connection $CONNECTION_NAME"
    echo ""
else
    echo "Next steps:"
    echo "1. Start containerized apps locally (React + FastAPI):"
    echo "   docker-compose up -d"
    echo ""
    echo "   OR deploy to Snowpark Container Services:"
    echo "   cd deployment && ./deploy_container.sh"
    echo ""
    echo "2. Upload sample data:"
    echo "   snow stage put sample_data/claims_data/provider_a/*.csv @BRONZE.SRC/provider_a/ --connection $CONNECTION_NAME"
    echo ""
    echo "3. Resume tasks (optional - tasks are created in SUSPENDED state):"
    echo "   snow sql --connection $CONNECTION_NAME -q \"USE DATABASE $DATABASE; USE SCHEMA $BRONZE_SCHEMA; ALTER TASK discover_files_task RESUME;\""
    echo ""
fi
