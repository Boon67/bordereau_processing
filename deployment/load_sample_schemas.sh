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
CONNECTION_NAME="${1:-}"

# If no connection specified, check if DEPLOYMENT exists, otherwise use default
if [[ -z "$CONNECTION_NAME" ]]; then
    if snow connection list 2>/dev/null | grep -q "DEPLOYMENT"; then
        CONNECTION_NAME="DEPLOYMENT"
    else
        # Use the default connection
        CONNECTION_NAME=$(snow connection list 2>/dev/null | grep "True" | awk '{print $2}' | head -1)
        if [[ -z "$CONNECTION_NAME" ]]; then
            echo -e "${RED}✗ No Snowflake connection found${NC}"
            echo -e "${YELLOW}Please configure a connection using: snow connection add${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Using default connection: ${CONNECTION_NAME}${NC}"
        echo ""
    fi
fi

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

# Convert path for Windows if needed (Git Bash drive notation like /z/ to Z:/)
SCHEMA_FILE="${PROJECT_ROOT}/sample_data/config/silver_target_schemas.csv"
SCHEMA_FILE_UPLOAD="${SCHEMA_FILE}"
if [[ "$SCHEMA_FILE_UPLOAD" =~ ^/([a-z])/ ]]; then
    DRIVE_LETTER="${BASH_REMATCH[1]}"
    SCHEMA_FILE_UPLOAD=$(echo "${SCHEMA_FILE}" | sed "s|^/${DRIVE_LETTER}/|${DRIVE_LETTER}:/|")
fi
SCHEMA_FILE_UPLOAD=$(echo "${SCHEMA_FILE_UPLOAD}" | sed 's|\\|/|g')

echo -e "${BLUE}   Schema file: ${SCHEMA_FILE}${NC}"
echo -e "${BLUE}   Upload path: ${SCHEMA_FILE_UPLOAD}${NC}"

UPLOAD_OUTPUT=$(snow sql -q "
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SILVER_SCHEMA_NAME};
CREATE STAGE IF NOT EXISTS SILVER_CONFIG;
PUT file://${SCHEMA_FILE_UPLOAD} @SILVER_CONFIG/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
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

# Create a temporary staging table and merge
echo -e "${BLUE}   Merging schemas (upsert)...${NC}"
LOAD_OUTPUT=$(snow sql --connection "$CONNECTION_NAME" -q "
USE DATABASE ${DATABASE_NAME};
USE SCHEMA ${SILVER_SCHEMA_NAME};

-- Create temporary staging table
CREATE OR REPLACE TEMPORARY TABLE target_schemas_staging (
    TABLE_NAME VARCHAR(500),
    COLUMN_NAME VARCHAR(500),
    DATA_TYPE VARCHAR(200),
    NULLABLE BOOLEAN,
    DEFAULT_VALUE VARCHAR(1000),
    DESCRIPTION VARCHAR(5000)
);

-- Load CSV data into staging table
COPY INTO target_schemas_staging (
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

-- Merge staging data into target_schemas
MERGE INTO target_schemas AS target
USING target_schemas_staging AS source
ON target.TABLE_NAME = source.TABLE_NAME 
   AND target.COLUMN_NAME = source.COLUMN_NAME
WHEN MATCHED THEN
    UPDATE SET
        DATA_TYPE = source.DATA_TYPE,
        NULLABLE = source.NULLABLE,
        DEFAULT_VALUE = source.DEFAULT_VALUE,
        DESCRIPTION = source.DESCRIPTION,
        UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (
        TABLE_NAME,
        COLUMN_NAME,
        DATA_TYPE,
        NULLABLE,
        DEFAULT_VALUE,
        DESCRIPTION
    )
    VALUES (
        source.TABLE_NAME,
        source.COLUMN_NAME,
        source.DATA_TYPE,
        source.NULLABLE,
        source.DEFAULT_VALUE,
        source.DESCRIPTION
    );

-- Drop staging table
DROP TABLE target_schemas_staging;
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
