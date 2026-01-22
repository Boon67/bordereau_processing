#!/bin/bash
# ============================================
# Load Sample Silver Target Schemas
# ============================================
# Purpose: Load sample schema definitions for all TPAs
# Usage: ./load_sample_schemas.sh [connection_name]
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CONNECTION_NAME="${1:-DEPLOYMENT}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}LOAD SAMPLE SILVER TARGET SCHEMAS${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Step 1: Generate sample schemas
echo -e "${YELLOW}[1/3]${NC} Generating sample schemas..."
if python3 "${PROJECT_ROOT}/sample_data/generate_sample_schemas.py"; then
    echo -e "${GREEN}✓ Sample schemas generated${NC}"
else
    echo -e "${RED}✗ Failed to generate sample schemas${NC}"
    exit 1
fi
echo ""

# Step 2: Upload to Snowflake
echo -e "${YELLOW}[2/3]${NC} Uploading schemas to Snowflake..."
if snow sql -q "
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA SILVER;
CREATE STAGE IF NOT EXISTS SILVER_CONFIG;
PUT file://${PROJECT_ROOT}/sample_data/config/silver_target_schemas.csv @SILVER_CONFIG/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
" --connection "$CONNECTION_NAME" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Schemas uploaded to @SILVER_CONFIG/${NC}"
else
    echo -e "${RED}✗ Failed to upload schemas${NC}"
    exit 1
fi
echo ""

# Step 3: Load into target_schemas table
echo -e "${YELLOW}[3/3]${NC} Loading schemas into database..."
if snow sql -f "${PROJECT_ROOT}/sample_data/config/load_sample_schemas.sql" --connection "$CONNECTION_NAME" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Schemas loaded successfully${NC}"
else
    echo -e "${RED}✗ Failed to load schemas${NC}"
    exit 1
fi
echo ""

# Verify
echo -e "${BLUE}Verifying loaded schemas...${NC}"
snow sql -q "
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA SILVER;
SELECT 
    TPA,
    TABLE_NAME,
    COUNT(*) as COLUMN_COUNT
FROM target_schemas
GROUP BY TPA, TABLE_NAME
ORDER BY TPA, TABLE_NAME;
" --connection "$CONNECTION_NAME"

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✓ SAMPLE SCHEMAS LOADED SUCCESSFULLY${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo -e "  • 5 TPAs (provider_a through provider_e)"
echo -e "  • 4 table types per TPA"
echo -e "  • 62 columns per TPA"
echo -e "  • 310 total schema definitions"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. View schemas in UI: Navigate to Silver Schemas page"
echo -e "  2. Create tables: Use 'Create Table' button for each table"
echo -e "  3. Define mappings: Map Bronze fields to Silver columns"
echo -e "  4. Upload sample data: Upload claim files to test"
echo ""
