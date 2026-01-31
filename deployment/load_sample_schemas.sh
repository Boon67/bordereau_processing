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

# Handle Windows paths in Git Bash
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W 2>/dev/null || pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -W 2>/dev/null || pwd)"
    SCRIPT_DIR="${SCRIPT_DIR//\\//}"
    PROJECT_ROOT="${PROJECT_ROOT//\\//}"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# Load config if available
if [[ -f "${SCRIPT_DIR}/custom.config" ]]; then
    source "${SCRIPT_DIR}/custom.config"
elif [[ -f "${SCRIPT_DIR}/default.config" ]]; then
    source "${SCRIPT_DIR}/default.config"
fi

# Set defaults if not in config
DATABASE_NAME="${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
SILVER_SCHEMA_NAME="${SILVER_SCHEMA_NAME:-SILVER}"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}LOAD SAMPLE SILVER TARGET SCHEMAS${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Step 1: Use existing TPA-agnostic schemas (no generation needed)
echo -e "${YELLOW}[1/3]${NC} Using existing TPA-agnostic schemas..."
if [[ -f "${PROJECT_ROOT}/sample_data/config/silver_target_schemas.csv" ]]; then
    SCHEMA_COUNT=$(wc -l < "${PROJECT_ROOT}/sample_data/config/silver_target_schemas.csv")
    echo -e "${GREEN}✓ Found TPA-agnostic schemas (${SCHEMA_COUNT} rows)${NC}"
else
    echo -e "${RED}✗ Schema file not found${NC}"
    exit 1
fi
echo ""

# Step 2: Upload to Snowflake
echo -e "${YELLOW}[2/3]${NC} Uploading schemas to Snowflake..."
UPLOAD_OUTPUT=$(snow sql -q "
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SILVER_SCHEMA_NAME};
CREATE STAGE IF NOT EXISTS SILVER_CONFIG;
PUT file://${PROJECT_ROOT}/sample_data/config/silver_target_schemas.csv @SILVER_CONFIG/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
" --connection "$CONNECTION_NAME" 2>&1)
UPLOAD_EXIT_CODE=$?

if [[ $UPLOAD_EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}✓ Schemas uploaded to @SILVER_CONFIG/${NC}"
else
    echo -e "${RED}✗ Failed to upload schemas${NC}"
    echo -e "${RED}Error output:${NC}"
    echo "$UPLOAD_OUTPUT"
    exit 1
fi
echo ""

# Step 3: Load into target_schemas table
echo -e "${YELLOW}[3/3]${NC} Loading schemas into database..."
LOAD_OUTPUT=$(snow sql --connection "$CONNECTION_NAME" -q "
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SILVER_SCHEMA_NAME};

-- Load schemas from CSV (TPA-agnostic)
COPY INTO target_schemas (
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    NULLABLE,
    DEFAULT_VALUE,
    DESCRIPTION
)
FROM (
    SELECT 
        \$1::VARCHAR as TABLE_NAME,
        \$2::VARCHAR as COLUMN_NAME,
        \$3::VARCHAR as DATA_TYPE,
        CASE WHEN \$4 = 'Y' THEN TRUE ELSE FALSE END as NULLABLE,
        NULLIF(\$5, '')::VARCHAR as DEFAULT_VALUE,
        \$6::VARCHAR as DESCRIPTION
    FROM @SILVER_CONFIG/silver_target_schemas.csv
)
FILE_FORMAT = (
    TYPE = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '\"'
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
)
ON_ERROR = ABORT_STATEMENT;
" 2>&1)
LOAD_EXIT_CODE=$?

if [[ $LOAD_EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}✓ Schemas loaded successfully${NC}"
else
    echo -e "${RED}✗ Failed to load schemas${NC}"
    echo -e "${RED}Error output:${NC}"
    echo "$LOAD_OUTPUT"
    exit 1
fi
echo ""

# Verify
echo -e "${BLUE}Verifying loaded schemas...${NC}"
snow sql -q "
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SILVER_SCHEMA_NAME};
SELECT 
    TABLE_NAME,
    COUNT(*) as COLUMN_COUNT
FROM target_schemas
WHERE active = TRUE
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;
" --connection "$CONNECTION_NAME"

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✓ SAMPLE SCHEMAS LOADED SUCCESSFULLY${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo -e "  • TPA-agnostic schema definitions"
echo -e "  • 4 table types (DENTAL_CLAIMS, MEDICAL_CLAIMS, MEMBER_ELIGIBILITY, PHARMACY_CLAIMS)"
echo -e "  • 62 total column definitions"
echo -e "  • Shared across all TPAs"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. View schemas in UI: Navigate to Silver Schemas page"
echo -e "  2. Create tables: Use 'Create Table' button for each table"
echo -e "  3. Define mappings: Map Bronze fields to Silver columns"
echo -e "  4. Upload sample data: Upload claim files to test"
echo ""
