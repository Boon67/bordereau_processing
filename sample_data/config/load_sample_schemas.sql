-- Load Sample Silver Target Schemas
-- This script loads sample schema definitions for demonstration

USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA SILVER;

-- Create stage for config files if not exists
CREATE STAGE IF NOT EXISTS SILVER_CONFIG;

-- Upload the CSV file first:
-- snow stage put sample_data/config/silver_target_schemas.csv @SILVER_CONFIG/ --connection DEPLOYMENT

-- Clear existing data to avoid duplicate key violations
-- (target_schemas has a unique key on TABLE_NAME, COLUMN_NAME, TPA)
TRUNCATE TABLE target_schemas;

-- Load schemas from CSV
-- Note: Hybrid tables require ON_ERROR = ABORT_STATEMENT (not CONTINUE)
COPY INTO target_schemas (
    TABLE_NAME,
    TPA,
    COLUMN_NAME,
    DATA_TYPE,
    NULLABLE,
    DEFAULT_VALUE,
    DESCRIPTION
)
FROM (
    SELECT 
        $1::VARCHAR as TABLE_NAME,
        $2::VARCHAR as TPA,
        $3::VARCHAR as COLUMN_NAME,
        $4::VARCHAR as DATA_TYPE,
        CASE WHEN $5 = 'Y' THEN TRUE ELSE FALSE END as NULLABLE,
        NULLIF($6, '')::VARCHAR as DEFAULT_VALUE,
        $7::VARCHAR as DESCRIPTION
    FROM @SILVER_CONFIG/silver_target_schemas.csv
)
FILE_FORMAT = (
    TYPE = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
)
ON_ERROR = ABORT_STATEMENT;

-- Verify loaded schemas
SELECT 
    TPA,
    TABLE_NAME,
    COUNT(*) as COLUMN_COUNT
FROM target_schemas
GROUP BY TPA, TABLE_NAME
ORDER BY TPA, TABLE_NAME;

-- Show sample
SELECT * FROM target_schemas LIMIT 10;
