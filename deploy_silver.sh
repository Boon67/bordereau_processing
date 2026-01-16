#!/bin/bash
# ============================================
# SILVER LAYER DEPLOYMENT SCRIPT (Using Snow CLI)
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Connection name (optional argument)
CONNECTION_NAME="${1:-default}"

echo -e "${CYAN}Deploying Silver Layer using connection: ${CONNECTION_NAME}${NC}"

# Use environment variables from deploy.sh if set, otherwise query snow CLI
if [[ -n "$DEPLOY_DATABASE" ]]; then
    DATABASE="$DEPLOY_DATABASE"
else
    DATABASE=$(snow connection list --format json | jq -r ".[] | select(.connection_name == \"$CONNECTION_NAME\") | .database // empty" 2>/dev/null)
    DATABASE=${DATABASE:-FILE_PROCESSING_PIPELINE}
fi

BRONZE_SCHEMA="${DEPLOY_BRONZE_SCHEMA:-BRONZE}"
SILVER_SCHEMA="${DEPLOY_SILVER_SCHEMA:-SILVER}"

echo -e "${CYAN}  Database: ${DATABASE}${NC}"
echo -e "${CYAN}  Silver Schema: ${SILVER_SCHEMA}${NC}"

# Function to execute SQL with variable substitution using snow CLI
execute_sql() {
    local sql_file="$1"
    echo "Executing: $sql_file"
    
    if [[ "$DEPLOY_VERBOSE" == "true" ]]; then
        # Verbose mode: show all output
        sed -e "s/^SET DATABASE_NAME = '.*';/SET DATABASE_NAME = '${DATABASE}';/" \
            -e "s/^SET BRONZE_SCHEMA_NAME = '.*';/SET BRONZE_SCHEMA_NAME = '${BRONZE_SCHEMA}';/" \
            -e "s/^SET SILVER_SCHEMA_NAME = '.*';/SET SILVER_SCHEMA_NAME = '${SILVER_SCHEMA}';/" \
            "$sql_file" | snow sql --stdin --connection "$CONNECTION_NAME"
    else
        # Normal mode: suppress output, only show on error
        local sql_output
        if ! sql_output=$(sed -e "s/^SET DATABASE_NAME = '.*';/SET DATABASE_NAME = '${DATABASE}';/" \
            -e "s/^SET BRONZE_SCHEMA_NAME = '.*';/SET BRONZE_SCHEMA_NAME = '${BRONZE_SCHEMA}';/" \
            -e "s/^SET SILVER_SCHEMA_NAME = '.*';/SET SILVER_SCHEMA_NAME = '${SILVER_SCHEMA}';/" \
            "$sql_file" | snow sql --stdin --connection "$CONNECTION_NAME" 2>&1); then
            echo "$sql_output"
            return 1
        fi
    fi
}

# Execute Silver SQL scripts in order
execute_sql "${SCRIPT_DIR}/silver/1_Silver_Schema_Setup.sql"
execute_sql "${SCRIPT_DIR}/silver/2_Silver_Target_Schemas.sql"
execute_sql "${SCRIPT_DIR}/silver/3_Silver_Mapping_Procedures.sql"
execute_sql "${SCRIPT_DIR}/silver/4_Silver_Rules_Engine.sql"
execute_sql "${SCRIPT_DIR}/silver/5_Silver_Transformation_Logic.sql"
execute_sql "${SCRIPT_DIR}/silver/6_Silver_Tasks.sql"

echo -e "${GREEN}✓ Silver layer deployed successfully${NC}"
