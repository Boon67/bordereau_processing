#!/bin/bash
# ============================================
# BRONZE LAYER DEPLOYMENT SCRIPT (Using Snow CLI)
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Connection name (optional argument)
CONNECTION_NAME="${1:-default}"

echo -e "${CYAN}Deploying Bronze Layer using connection: ${CONNECTION_NAME}${NC}"

# Use environment variables from deploy.sh if set, otherwise query snow CLI
if [[ -n "$DEPLOY_DATABASE" ]]; then
    DATABASE="$DEPLOY_DATABASE"
else
    DATABASE=$(snow connection list --format json | jq -r ".[] | select(.connection_name == \"$CONNECTION_NAME\") | .database // empty" 2>/dev/null)
    DATABASE=${DATABASE:-FILE_PROCESSING_PIPELINE}
fi

if [[ -n "$DEPLOY_WAREHOUSE" ]]; then
    WAREHOUSE="$DEPLOY_WAREHOUSE"
else
    WAREHOUSE=$(snow connection list --format json | jq -r ".[] | select(.connection_name == \"$CONNECTION_NAME\") | .warehouse // empty" 2>/dev/null)
    WAREHOUSE=${WAREHOUSE:-COMPUTE_WH}
fi

BRONZE_SCHEMA="${DEPLOY_BRONZE_SCHEMA:-BRONZE}"
SILVER_SCHEMA="${DEPLOY_SILVER_SCHEMA:-SILVER}"
BRONZE_DISCOVERY_SCHEDULE="${DEPLOY_DISCOVERY_SCHEDULE:-60 MINUTE}"
ROLE="${DEPLOY_ROLE:-SYSADMIN}"
AUTO_RESUME_TASKS="${DEPLOY_AUTO_RESUME_TASKS:-true}"

echo -e "${CYAN}  Database: ${DATABASE}${NC}"
echo -e "${CYAN}  Bronze Schema: ${BRONZE_SCHEMA}${NC}"
echo -e "${CYAN}  Warehouse: ${WAREHOUSE}${NC}"
echo -e "${CYAN}  Role: ${ROLE}${NC}"

# Function to execute SQL with variable substitution using snow CLI
execute_sql() {
    local sql_file="$1"
    echo "Executing: $sql_file"
    
    # Replace only SET placeholder values to preserve $VARIABLE references
    if [[ "$DEPLOY_VERBOSE" == "true" ]]; then
        # Verbose mode: show all output
        sed -e "s/^SET DATABASE_NAME = '.*';/SET DATABASE_NAME = '${DATABASE}';/" \
            -e "s/^SET BRONZE_SCHEMA_NAME = '.*';/SET BRONZE_SCHEMA_NAME = '${BRONZE_SCHEMA}';/" \
            -e "s/^SET SILVER_SCHEMA_NAME = '.*';/SET SILVER_SCHEMA_NAME = '${SILVER_SCHEMA}';/" \
            -e "s/^SET WAREHOUSE_NAME = '.*';/SET WAREHOUSE_NAME = '${WAREHOUSE}';/" \
            -e "s/^SET SNOWFLAKE_WAREHOUSE = '.*';/SET SNOWFLAKE_WAREHOUSE = '${WAREHOUSE}';/" \
            -e "s/^SET SNOWFLAKE_ROLE = '.*';/SET SNOWFLAKE_ROLE = '${ROLE}';/" \
            -e "s/^SET BRONZE_DISCOVERY_SCHEDULE = '.*';/SET BRONZE_DISCOVERY_SCHEDULE = '${BRONZE_DISCOVERY_SCHEDULE}';/" \
            -e "s/__BRONZE_DISCOVERY_SCHEDULE__/${BRONZE_DISCOVERY_SCHEDULE}/g" \
            "$sql_file" | snow sql --stdin --connection "$CONNECTION_NAME"
    else
        # Normal mode: suppress output, only show on error
        local sql_output
        if ! sql_output=$(sed -e "s/^SET DATABASE_NAME = '.*';/SET DATABASE_NAME = '${DATABASE}';/" \
            -e "s/^SET BRONZE_SCHEMA_NAME = '.*';/SET BRONZE_SCHEMA_NAME = '${BRONZE_SCHEMA}';/" \
            -e "s/^SET SILVER_SCHEMA_NAME = '.*';/SET SILVER_SCHEMA_NAME = '${SILVER_SCHEMA}';/" \
            -e "s/^SET WAREHOUSE_NAME = '.*';/SET WAREHOUSE_NAME = '${WAREHOUSE}';/" \
            -e "s/^SET SNOWFLAKE_WAREHOUSE = '.*';/SET SNOWFLAKE_WAREHOUSE = '${WAREHOUSE}';/" \
            -e "s/^SET SNOWFLAKE_ROLE = '.*';/SET SNOWFLAKE_ROLE = '${ROLE}';/" \
            -e "s/^SET BRONZE_DISCOVERY_SCHEDULE = '.*';/SET BRONZE_DISCOVERY_SCHEDULE = '${BRONZE_DISCOVERY_SCHEDULE}';/" \
            -e "s/__BRONZE_DISCOVERY_SCHEDULE__/${BRONZE_DISCOVERY_SCHEDULE}/g" \
            "$sql_file" | snow sql --stdin --connection "$CONNECTION_NAME" 2>&1); then
            echo "$sql_output"
            return 1
        fi
    fi
}

# Execute Bronze SQL scripts in order
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
execute_sql "${PROJECT_ROOT}/bronze/1_Setup_Database_Roles.sql"
execute_sql "${PROJECT_ROOT}/bronze/0_Setup_Logging.sql"
execute_sql "${PROJECT_ROOT}/bronze/2_Bronze_Schema_Tables.sql"
execute_sql "${PROJECT_ROOT}/bronze/3_Bronze_Setup_Logic.sql"
execute_sql "${PROJECT_ROOT}/bronze/4_Bronze_Tasks.sql"

# Resume tasks automatically after deployment (if enabled)
if [[ "$AUTO_RESUME_TASKS" == "true" ]]; then
    echo "Resuming Bronze tasks..."
    execute_sql "${SCRIPT_DIR}/resume_tasks.sql"
    echo -e "${GREEN}✓ Bronze tasks resumed automatically${NC}"
else
    echo -e "${YELLOW}⚠ Bronze tasks created in SUSPENDED state${NC}"
    echo -e "${YELLOW}  To resume tasks manually, run:${NC}"
    echo -e "${CYAN}  snow sql -f deployment/resume_tasks.sql --connection $CONNECTION_NAME${NC}"
fi

echo -e "${GREEN}✓ Bronze layer deployed successfully${NC}"
