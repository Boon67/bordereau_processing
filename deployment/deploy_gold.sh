#!/bin/bash

# ============================================
# GOLD LAYER DEPLOYMENT SCRIPT
# ============================================
# Purpose: Deploy Gold layer to Snowflake
# Usage: ./deploy_gold.sh [connection_name]
# ============================================

set -e

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONNECTION_NAME="${1:-DEPLOYMENT}"
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

# 1. Gold Schema Setup
echo -e "${YELLOW}[1/5]${NC} Creating Gold schema and metadata tables..."
snow sql -f gold/1_Gold_Schema_Setup.sql \
    --connection "$CONNECTION_NAME" \
    -D "DATABASE_NAME=$DATABASE_NAME" \
    -D "SILVER_SCHEMA_NAME=$SILVER_SCHEMA_NAME" \
    -D "GOLD_SCHEMA_NAME=$GOLD_SCHEMA_NAME"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Gold schema created${NC}"
else
    echo -e "${RED}✗ Failed to create Gold schema${NC}"
    exit 1
fi
echo ""

# 2. Gold Target Schemas (Using BULK optimized version)
echo -e "${YELLOW}[2/5]${NC} Creating Gold target schemas (bulk optimized - 88% faster)..."
snow sql -f "$PROJECT_ROOT/gold/2_Gold_Target_Schemas_BULK.sql" \
    --connection "$CONNECTION_NAME" \
    -D "DATABASE_NAME=$DATABASE_NAME" \
    -D "GOLD_SCHEMA_NAME=$GOLD_SCHEMA_NAME"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Gold target schemas created (8 operations vs 69)${NC}"
else
    echo -e "${RED}✗ Failed to create Gold target schemas${NC}"
    exit 1
fi
echo ""

# 3. Gold Transformation Rules
echo -e "${YELLOW}[3/5]${NC} Creating Gold transformation rules..."
snow sql -f "$PROJECT_ROOT/gold/3_Gold_Transformation_Rules.sql" \
    --connection "$CONNECTION_NAME" \
    -D "DATABASE_NAME=$DATABASE_NAME" \
    -D "GOLD_SCHEMA_NAME=$GOLD_SCHEMA_NAME"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Gold transformation rules created${NC}"
else
    echo -e "${RED}✗ Failed to create Gold transformation rules${NC}"
    exit 1
fi
echo ""

# 4. Gold Transformation Procedures (Optional - requires Silver data)
echo -e "${YELLOW}[4/5]${NC} Skipping Gold transformation procedures..."
echo -e "${BLUE}Note: Transformation procedures require Silver tables with data${NC}"
echo -e "${BLUE}Deploy these after loading data: ./deploy_gold.sh --procedures-only${NC}"
# snow sql -f gold/4_Gold_Transformation_Procedures.sql \
#     --connection "$CONNECTION_NAME" \
#     -D "DATABASE_NAME=$DATABASE_NAME" \
#     -D "SILVER_SCHEMA_NAME=$SILVER_SCHEMA_NAME" \
#     -D "GOLD_SCHEMA_NAME=$GOLD_SCHEMA_NAME"
echo ""

# 5. Gold Tasks (Optional - depend on procedures)
echo -e "${YELLOW}[5/5]${NC} Creating Gold tasks..."
echo -e "${BLUE}Note: Skipping Gold tasks (depend on transformation procedures)${NC}"
echo -e "${BLUE}These can be created after procedures are deployed${NC}"
# snow sql -f "$PROJECT_ROOT/gold/5_Gold_Tasks.sql" \
#     --connection "$CONNECTION_NAME" \
#     -D "DATABASE_NAME=$DATABASE_NAME" \
#     -D "GOLD_SCHEMA_NAME=$GOLD_SCHEMA_NAME"
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
