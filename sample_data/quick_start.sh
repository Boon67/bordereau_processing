#!/bin/bash
# ============================================
# Quick Start: Generate and Load Sample Data
# ============================================
# This script generates sample data and loads it into Snowflake
# ============================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"
NUM_CLAIMS=${1:-1000}  # Default 1000 claims
CONNECTION=${2:-DEPLOYMENT}  # Default connection

# Load configuration from default.config
if [ -f "${PROJECT_ROOT}/deployment/default.config" ]; then
    source "${PROJECT_ROOT}/deployment/default.config"
fi

# Database configuration (with fallback defaults)
DATABASE_NAME="${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
GOLD_SCHEMA_NAME="${GOLD_SCHEMA_NAME:-GOLD}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  🎲 Bordereau Sample Data Generator - Quick Start${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  • Claims to generate: ${NUM_CLAIMS}"
echo "  • Output directory:   ${OUTPUT_DIR}"
echo "  • Snowflake connection: ${CONNECTION}"
echo "  • Database:           ${DATABASE_NAME}"
echo "  • Gold schema:        ${GOLD_SCHEMA_NAME}"
echo ""

# ============================================
# STEP 1: Generate Sample Data
# ============================================

echo -e "${YELLOW}[1/4]${NC} Generating sample data..."
python3 "${SCRIPT_DIR}/generate_sample_data.py" \
    --output-dir "${OUTPUT_DIR}" \
    --num-claims "${NUM_CLAIMS}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Sample data generated successfully${NC}"
else
    echo -e "${RED}✗ Failed to generate sample data${NC}"
    exit 1
fi

# ============================================
# STEP 2: Create Journey Tables
# ============================================

echo ""
echo -e "${YELLOW}[2/4]${NC} Creating member journey tables in Gold layer..."

# Check if journey tables already exist
TABLES_EXIST=$(snow sql -c "${CONNECTION}" -q "
    USE DATABASE ${DATABASE_NAME};
    USE SCHEMA ${GOLD_SCHEMA_NAME};
    SHOW TABLES LIKE 'MEMBER_JOURNEYS';
" --format json 2>/dev/null | jq -r 'length' 2>/dev/null || echo "0")

if [ "$TABLES_EXIST" -gt 0 ]; then
    echo -e "${BLUE}ℹ Journey tables already exist, skipping creation${NC}"
else
    snow sql -c "${CONNECTION}" \
        -f "${PROJECT_ROOT}/gold/6_Member_Journeys.sql" \
        -D DATABASE_NAME="${DATABASE_NAME}" \
        -D GOLD_SCHEMA_NAME="${GOLD_SCHEMA_NAME}" \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Journey tables created successfully${NC}"
    else
        echo -e "${RED}✗ Failed to create journey tables${NC}"
        exit 1
    fi
fi

# ============================================
# STEP 3: Upload Files to Snowflake
# ============================================

echo ""
echo -e "${YELLOW}[3/4]${NC} Uploading CSV files to Snowflake..."

# Create temporary SQL file with correct paths
TEMP_UPLOAD_SQL="/tmp/upload_sample_data_$$.sql"
cat > "${TEMP_UPLOAD_SQL}" << EOF
USE ROLE SYSADMIN;
USE DATABASE ${DATABASE_NAME};
USE SCHEMA BRONZE;

-- Create sample data stage
CREATE STAGE IF NOT EXISTS SAMPLE_DATA
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for sample data CSV files';

-- Upload files
PUT file://${OUTPUT_DIR}/members.csv @SAMPLE_DATA AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://${OUTPUT_DIR}/providers.csv @SAMPLE_DATA AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://${OUTPUT_DIR}/claims.csv @SAMPLE_DATA AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://${OUTPUT_DIR}/member_journeys.csv @SAMPLE_DATA AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://${OUTPUT_DIR}/journey_events.csv @SAMPLE_DATA AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Verify uploads
LIST @SAMPLE_DATA;
EOF

snow sql -c "${CONNECTION}" -f "${TEMP_UPLOAD_SQL}" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Files uploaded successfully${NC}"
else
    echo -e "${RED}✗ Failed to upload files${NC}"
    rm -f "${TEMP_UPLOAD_SQL}"
    exit 1
fi

rm -f "${TEMP_UPLOAD_SQL}"

# ============================================
# STEP 4: Load Data into Tables
# ============================================

echo ""
echo -e "${YELLOW}[4/4]${NC} Loading data into Snowflake tables..."

# Create temporary SQL file for loading
TEMP_LOAD_SQL="/tmp/load_sample_data_$$.sql"
cat > "${TEMP_LOAD_SQL}" << 'EOF'
USE ROLE SYSADMIN;
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;

-- Load claims into Bronze layer
USE SCHEMA BRONZE;

COPY INTO raw_data_table (
    tpa,
    file_name,
    file_row_number,
    raw_json,
    loaded_at
)
FROM (
    SELECT 
        $2::VARCHAR as tpa,
        'sample_claims.csv' as file_name,
        ROW_NUMBER() OVER (ORDER BY $1) as file_row_number,
        OBJECT_CONSTRUCT(
            'claim_id', $1,
            'tpa', $2,
            'member_id', $3,
            'provider_id', $4,
            'claim_type', $5,
            'service_date', $6,
            'received_date', $7,
            'diagnosis_code', $8,
            'procedure_code', $9,
            'drug_name', $10,
            'billed_amount', $11,
            'allowed_amount', $12,
            'paid_amount', $13,
            'member_responsibility', $14,
            'claim_status', $15,
            'denial_reason', $16
        ) as raw_json,
        CURRENT_TIMESTAMP() as loaded_at
    FROM @SAMPLE_DATA/claims.csv
)
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

-- Load journeys into Gold layer
USE SCHEMA GOLD;

COPY INTO member_journeys (
    journey_id, member_id, tpa, journey_type, start_date, end_date,
    current_stage, primary_diagnosis, primary_provider_id, total_cost,
    num_visits, num_providers, is_active, quality_score, patient_satisfaction,
    created_at, updated_at
)
FROM (
    SELECT 
        $1::VARCHAR, $2::VARCHAR, $3::VARCHAR, $4::VARCHAR, $5::DATE,
        TRY_TO_DATE($6), $7::VARCHAR, $8::VARCHAR, $9::VARCHAR,
        $10::NUMBER(18,2), $11::NUMBER(10,0), $12::NUMBER(10,0),
        $13::BOOLEAN, TRY_TO_NUMBER($14, 5, 2), TRY_TO_NUMBER($15, 5, 2),
        $16::TIMESTAMP_NTZ, $17::TIMESTAMP_NTZ
    FROM @BRONZE.SAMPLE_DATA/member_journeys.csv
)
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

-- Load journey events
COPY INTO journey_events (
    event_id, journey_id, event_date, event_type, event_stage,
    provider_id, diagnosis_code, procedure_code, cost, notes, created_at
)
FROM (
    SELECT 
        $1::VARCHAR, $2::VARCHAR, $3::DATE, $4::VARCHAR, $5::VARCHAR,
        $6::VARCHAR, $7::VARCHAR, $8::VARCHAR, $9::NUMBER(18,2),
        $10::VARCHAR, $11::TIMESTAMP_NTZ
    FROM @BRONZE.SAMPLE_DATA/journey_events.csv
)
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

-- Verification
SELECT 'Bronze Claims' AS layer, COUNT(*) AS records FROM BRONZE.raw_data_table WHERE file_name = 'sample_claims.csv';
SELECT 'Gold Journeys' AS layer, COUNT(*) AS records FROM GOLD.member_journeys;
SELECT 'Gold Events' AS layer, COUNT(*) AS records FROM GOLD.journey_events;
EOF

snow sql -c "${CONNECTION}" -f "${TEMP_LOAD_SQL}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Data loaded successfully${NC}"
else
    echo -e "${RED}✗ Failed to load data${NC}"
    rm -f "${TEMP_LOAD_SQL}"
    exit 1
fi

rm -f "${TEMP_LOAD_SQL}"

# ============================================
# SUMMARY
# ============================================

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ Sample Data Loaded Successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}📊 Data Summary:${NC}"
echo "  • Claims loaded into Bronze layer"
echo "  • Member journeys loaded into Gold layer"
echo "  • Journey events loaded into Gold layer"
echo ""
echo -e "${GREEN}🔍 Sample Queries:${NC}"
echo ""
echo "  # View active journeys"
echo "  snow sql -c ${CONNECTION} -q \"SELECT * FROM ${DATABASE_NAME}.${GOLD_SCHEMA_NAME}.v_active_journeys LIMIT 10;\""
echo ""
echo "  # Journey summary by type"
echo "  snow sql -c ${CONNECTION} -q \"SELECT * FROM ${DATABASE_NAME}.${GOLD_SCHEMA_NAME}.v_journey_summary_by_type;\""
echo ""
echo "  # High-cost journeys"
echo "  snow sql -c ${CONNECTION} -q \"SELECT * FROM ${DATABASE_NAME}.${GOLD_SCHEMA_NAME}.v_high_cost_journeys LIMIT 10;\""
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
