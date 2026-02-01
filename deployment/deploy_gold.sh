#!/bin/bash

# ============================================
# GOLD LAYER DEPLOYMENT SCRIPT
# ============================================
# Purpose: Deploy Gold layer to Snowflake
# Usage: ./deploy_gold.sh [connection_name]
# ============================================

set -e

# Script directory - Handle Windows paths in Git Bash
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W 2>/dev/null || pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -W 2>/dev/null || pwd)"
    SCRIPT_DIR="${SCRIPT_DIR//\\//}"
    PROJECT_ROOT="${PROJECT_ROOT//\\//}"
else
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
fi

# Load configuration files
if [ -f "$SCRIPT_DIR/default.config" ]; then
    source "$SCRIPT_DIR/default.config"
fi

if [ -f "$SCRIPT_DIR/custom.config" ]; then
    source "$SCRIPT_DIR/custom.config"
fi

# Load custom config file if passed from parent deploy.sh
if [ -n "$DEPLOY_CONFIG_FILE" ] && [ -f "$DEPLOY_CONFIG_FILE" ]; then
    source "$DEPLOY_CONFIG_FILE"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration with fallbacks
if [[ -n "${1}" ]]; then
    CONNECTION_NAME="${1}"
elif [[ -n "${SNOWFLAKE_CONNECTION}" ]]; then
    CONNECTION_NAME="${SNOWFLAKE_CONNECTION}"
else
    # Get the default connection from snow CLI
    CONNECTION_NAME=$(snow connection list --format json 2>/dev/null | jq -r '.[] | select(.is_default == true) | .connection_name // empty' 2>/dev/null)
    if [[ -z "$CONNECTION_NAME" ]]; then
        CONNECTION_NAME="DEPLOYMENT"
    fi
fi

DATABASE_NAME="${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
SILVER_SCHEMA_NAME="${SILVER_SCHEMA_NAME:-SILVER}"
GOLD_SCHEMA_NAME="${GOLD_SCHEMA_NAME:-GOLD}"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}GOLD LAYER DEPLOYMENT${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "Connection: ${GREEN}$CONNECTION_NAME${NC}"
echo -e "Database: ${GREEN}$DATABASE_NAME${NC}"
echo -e "Silver Schema: ${GREEN}$SILVER_SCHEMA_NAME${NC}"
echo -e "Gold Schema: ${GREEN}$GOLD_SCHEMA_NAME${NC}"
echo ""

# Check if snow CLI is available
if ! command -v snow &> /dev/null; then
    echo -e "${RED}Error: snow CLI not found${NC}"
    echo "Please install Snowflake CLI: https://docs.snowflake.com/en/developer-guide/snowflake-cli/index"
    exit 1
fi

# Test connection
echo -e "${BLUE}Testing Snowflake connection...${NC}"
if ! snow connection test --connection "$CONNECTION_NAME" &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Snowflake${NC}"
    echo "Please check your connection: snow connection test --connection $CONNECTION_NAME"
    exit 1
fi
echo -e "${GREEN}✓ Connection successful${NC}"
echo ""

# Deploy Gold Layer
cd "$PROJECT_ROOT"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}DEPLOYING GOLD LAYER${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Helper function to execute SQL with variable substitution
execute_sql() {
    local sql_file="$1"
    sed "s/&{DATABASE_NAME}/$DATABASE_NAME/g; \
         s/&{SILVER_SCHEMA_NAME}/$SILVER_SCHEMA_NAME/g; \
         s/&{GOLD_SCHEMA_NAME}/$GOLD_SCHEMA_NAME/g" "$sql_file" | \
    snow sql --stdin --connection "$CONNECTION_NAME" --enable-templating NONE
}

# 1. Gold Schema Setup
echo -e "${YELLOW}[1/5]${NC} Creating Gold schema and metadata tables..."
execute_sql "gold/1_Gold_Schema_Setup.sql"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Gold schema created${NC}"
else
    echo -e "${RED}✗ Failed to create Gold schema${NC}"
    exit 1
fi
echo ""

# 2. Gold Target Schemas (Using BULK optimized version)
echo -e "${YELLOW}[2/5]${NC} Creating Gold target schemas (bulk optimized - 88% faster)..."
execute_sql "$PROJECT_ROOT/gold/2_Gold_Target_Schemas_BULK.sql"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Gold target schemas created (8 operations vs 69)${NC}"
else
    echo -e "${RED}✗ Failed to create Gold target schemas${NC}"
    exit 1
fi
echo ""

# 3. Gold Transformation Rules
echo -e "${YELLOW}[3/5]${NC} Creating Gold transformation rules..."
execute_sql "$PROJECT_ROOT/gold/3_Gold_Transformation_Rules.sql"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Gold transformation rules created${NC}"
else
    echo -e "${RED}✗ Failed to create Gold transformation rules${NC}"
    exit 1
fi
echo ""

# 4. Gold Transformation Procedures
echo -e "${YELLOW}[4/6]${NC} Creating Gold transformation procedures..."
execute_sql "$PROJECT_ROOT/gold/4_Gold_Transformation_Procedures.sql"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Gold transformation procedures created${NC}"
else
    echo -e "${RED}✗ Failed to create Gold transformation procedures${NC}"
    exit 1
fi
echo ""

# 5. Gold Tasks
echo -e "${YELLOW}[5/6]${NC} Creating Gold tasks..."
execute_sql "$PROJECT_ROOT/gold/5_Gold_Tasks.sql"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Gold tasks created${NC}"
else
    echo -e "${RED}✗ Failed to create Gold tasks${NC}"
    exit 1
fi
echo ""

# 6. Member Journeys
echo -e "${YELLOW}[6/6]${NC} Creating Member Journeys tables..."
execute_sql "$PROJECT_ROOT/gold/6_Member_Journeys.sql"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Member Journeys tables created${NC}"
else
    echo -e "${RED}✗ Failed to create Member Journeys tables${NC}"
    exit 1
fi
echo ""

# Summary
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✓ GOLD LAYER DEPLOYMENT COMPLETE${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "Gold layer deployed successfully!"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Run transformations: ${BLUE}CALL GOLD.run_gold_transformations('ALL');${NC}"
echo -e "2. Enable tasks: ${BLUE}ALTER TASK GOLD.task_master_gold_refresh RESUME;${NC}"
echo -e "3. Monitor: ${BLUE}SELECT * FROM GOLD.v_gold_processing_summary;${NC}"
echo ""
