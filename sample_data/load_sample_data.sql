-- ============================================
-- LOAD SAMPLE DATA INTO BORDEREAU PIPELINE
-- ============================================
-- Purpose: Load generated sample data into all layers
-- 
-- Prerequisites:
--   1. Run generate_sample_data.py to create CSV files
--   2. Ensure all schemas and tables are created
-- 
-- This script loads:
--   - Members
--   - Providers
--   - Claims (Bronze layer)
--   - Member Journeys (Gold layer)
--   - Journey Events (Gold layer)
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

USE ROLE SYSADMIN;
USE DATABASE &{DATABASE_NAME};

-- ============================================
-- CREATE SAMPLE DATA STAGE
-- ============================================

USE SCHEMA BRONZE;

CREATE STAGE IF NOT EXISTS SAMPLE_DATA
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for sample data CSV files';

-- ============================================
-- UPLOAD SAMPLE DATA FILES
-- ============================================
-- Note: PUT commands need absolute paths
-- __PROJECT_ROOT__ will be replaced by deployment script

PUT file://__PROJECT_ROOT__/sample_data/output/members.csv @SAMPLE_DATA AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://__PROJECT_ROOT__/sample_data/output/providers.csv @SAMPLE_DATA AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://__PROJECT_ROOT__/sample_data/output/claims.csv @SAMPLE_DATA AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://__PROJECT_ROOT__/sample_data/output/member_journeys.csv @SAMPLE_DATA AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://__PROJECT_ROOT__/sample_data/output/journey_events.csv @SAMPLE_DATA AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- ============================================
-- LOAD MEMBERS (if member table exists)
-- ============================================
-- Note: Adjust table name and schema based on your setup

/*
-- Example: Load into a members staging table
CREATE OR REPLACE TABLE bronze.members_staging (
    member_id VARCHAR(100),
    tpa VARCHAR(100),
    first_name VARCHAR(200),
    last_name VARCHAR(200),
    date_of_birth DATE,
    gender VARCHAR(10),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    enrollment_date DATE,
    is_active BOOLEAN,
    created_at TIMESTAMP_NTZ
);

COPY INTO bronze.members_staging
FROM @SAMPLE_DATA/members.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';
*/

-- ============================================
-- LOAD PROVIDERS (if provider table exists)
-- ============================================

/*
CREATE OR REPLACE TABLE bronze.providers_staging (
    provider_id VARCHAR(100),
    tpa VARCHAR(100),
    provider_name VARCHAR(500),
    provider_type VARCHAR(100),
    specialty VARCHAR(200),
    claim_type VARCHAR(50),
    npi VARCHAR(20),
    tax_id VARCHAR(20),
    address VARCHAR(500),
    city VARCHAR(200),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    is_active BOOLEAN,
    created_at TIMESTAMP_NTZ
);

COPY INTO bronze.providers_staging
FROM @SAMPLE_DATA/providers.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';
*/

-- ============================================
-- LOAD CLAIMS INTO RAW_DATA_TABLE
-- ============================================
-- This is the main entry point for claims data

COPY INTO bronze.raw_data_table (
    tpa,
    file_name,
    file_row_number,
    raw_json,
    loaded_at
)
FROM (
    SELECT 
        $1::VARCHAR as tpa,
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

-- ============================================
-- LOAD MEMBER JOURNEYS (Gold Layer)
-- ============================================

USE SCHEMA &{GOLD_SCHEMA_NAME};

-- Clear existing sample data (optional)
-- DELETE FROM member_journeys WHERE journey_id LIKE 'JRN%';
-- DELETE FROM journey_events WHERE event_id LIKE 'EVT%';

COPY INTO member_journeys (
    journey_id,
    member_id,
    tpa,
    journey_type,
    start_date,
    end_date,
    current_stage,
    primary_diagnosis,
    primary_provider_id,
    total_cost,
    num_visits,
    num_providers,
    is_active,
    quality_score,
    patient_satisfaction,
    created_at,
    updated_at
)
FROM (
    SELECT 
        $1::VARCHAR,
        $2::VARCHAR,
        $3::VARCHAR,
        $4::VARCHAR,
        $5::DATE,
        TRY_TO_DATE($6),
        $7::VARCHAR,
        $8::VARCHAR,
        $9::VARCHAR,
        $10::NUMBER(18,2),
        $11::NUMBER(10,0),
        $12::NUMBER(10,0),
        $13::BOOLEAN,
        TRY_TO_NUMBER($14, 5, 2),
        TRY_TO_NUMBER($15, 5, 2),
        $16::TIMESTAMP_NTZ,
        $17::TIMESTAMP_NTZ
    FROM @BRONZE.SAMPLE_DATA/member_journeys.csv
)
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

-- ============================================
-- LOAD JOURNEY EVENTS (Gold Layer)
-- ============================================

COPY INTO journey_events (
    event_id,
    journey_id,
    event_date,
    event_type,
    event_stage,
    provider_id,
    diagnosis_code,
    procedure_code,
    cost,
    notes,
    created_at
)
FROM (
    SELECT 
        $1::VARCHAR,
        $2::VARCHAR,
        $3::DATE,
        $4::VARCHAR,
        $5::VARCHAR,
        $6::VARCHAR,
        $7::VARCHAR,
        $8::VARCHAR,
        $9::NUMBER(18,2),
        $10::VARCHAR,
        $11::TIMESTAMP_NTZ
    FROM @BRONZE.SAMPLE_DATA/journey_events.csv
)
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

-- ============================================
-- VERIFICATION
-- ============================================

-- Check loaded data
USE SCHEMA BRONZE;

SELECT 'Bronze - Raw Data' AS layer, COUNT(*) AS record_count
FROM raw_data_table
WHERE file_name = 'sample_claims.csv';

USE SCHEMA &{GOLD_SCHEMA_NAME};

SELECT 'Gold - Member Journeys' AS layer, COUNT(*) AS record_count
FROM member_journeys;

SELECT 'Gold - Journey Events' AS layer, COUNT(*) AS record_count
FROM journey_events;

-- Journey statistics
SELECT 
    'Journey Statistics' AS report,
    tpa,
    journey_type,
    COUNT(*) AS journey_count,
    SUM(CASE WHEN is_active THEN 1 ELSE 0 END) AS active_count,
    AVG(total_cost) AS avg_cost,
    AVG(num_visits) AS avg_visits
FROM member_journeys
GROUP BY tpa, journey_type
ORDER BY tpa, journey_type;

-- Event statistics
SELECT 
    'Event Statistics' AS report,
    event_type,
    COUNT(*) AS event_count,
    AVG(cost) AS avg_cost
FROM journey_events
GROUP BY event_type
ORDER BY event_count DESC;

-- ============================================
-- SAMPLE QUERIES
-- ============================================

-- Active journeys by TPA
SELECT 
    tpa,
    COUNT(*) AS active_journeys,
    SUM(total_cost) AS total_cost,
    AVG(num_visits) AS avg_visits
FROM member_journeys
WHERE is_active = TRUE
GROUP BY tpa
ORDER BY total_cost DESC;

-- High-cost journeys
SELECT 
    journey_id,
    member_id,
    tpa,
    journey_type,
    total_cost,
    num_visits,
    num_providers,
    DATEDIFF(day, start_date, COALESCE(end_date, CURRENT_DATE())) AS duration_days
FROM member_journeys
WHERE total_cost > 5000
ORDER BY total_cost DESC
LIMIT 10;

-- Journey event timeline (sample)
SELECT 
    j.journey_id,
    j.member_id,
    j.journey_type,
    e.event_date,
    e.event_type,
    e.event_stage,
    e.cost
FROM member_journeys j
JOIN journey_events e ON j.journey_id = e.journey_id
WHERE j.journey_id = (SELECT journey_id FROM member_journeys LIMIT 1)
ORDER BY e.event_date;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================

SELECT '✅ Sample data loaded successfully!' AS status;
SELECT 'Run queries above to explore the data' AS next_step;
