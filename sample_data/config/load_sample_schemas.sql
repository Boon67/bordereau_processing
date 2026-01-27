-- Load Sample Silver Target Schemas (TPA-Agnostic)
-- This script loads TPA-agnostic schema definitions

SET DATABASE_NAME = '$DATABASE_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';

USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- Create stage for config files if not exists
CREATE STAGE IF NOT EXISTS SILVER_CONFIG;

-- Clear existing data to avoid duplicate key violations
-- (target_schemas has a unique key on TABLE_NAME, COLUMN_NAME)
TRUNCATE TABLE target_schemas;

-- Load schemas from CSV (TPA-agnostic)
-- Note: Hybrid tables require ON_ERROR = ABORT_STATEMENT (not CONTINUE)
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
        $1::VARCHAR as TABLE_NAME,
        $2::VARCHAR as COLUMN_NAME,
        $3::VARCHAR as DATA_TYPE,
        CASE WHEN $4 = 'Y' THEN TRUE ELSE FALSE END as NULLABLE,
        NULLIF($5, '')::VARCHAR as DEFAULT_VALUE,
        $6::VARCHAR as DESCRIPTION
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

-- Verify loaded schemas (TPA-agnostic)
SELECT 
    TABLE_NAME,
    COUNT(*) as COLUMN_COUNT
FROM target_schemas
WHERE active = TRUE
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;

-- Show sample
SELECT * FROM target_schemas LIMIT 10;
