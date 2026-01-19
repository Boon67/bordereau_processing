-- ============================================
-- LOAD SAMPLE SILVER TARGET SCHEMAS
-- ============================================
-- Purpose: Load sample target schemas for providers
-- 
-- This script loads sample schemas from CSV files for:
--   - Provider A, B, C, D, E
--   - Claims, Members, and Providers tables
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

-- Use SYSADMIN role
USE ROLE SYSADMIN;
USE DATABASE &{DATABASE_NAME};
USE SCHEMA &{SILVER_SCHEMA_NAME};

-- ============================================
-- UPLOAD SAMPLE SCHEMA FILES
-- ============================================

-- Note: PUT commands need absolute paths
-- __PROJECT_ROOT__ will be replaced by deployment script

-- Upload target schemas CSV
PUT file://__PROJECT_ROOT__/sample_data/config/silver_target_schemas_samples.csv @SILVER_CONFIG AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Upload target fields CSV
PUT file://__PROJECT_ROOT__/sample_data/config/silver_target_fields_samples.csv @SILVER_CONFIG AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- ============================================
-- LOAD SAMPLE TARGET SCHEMAS
-- ============================================

COPY INTO target_schemas (table_name, tpa, description, data_owner, refresh_frequency, retention_days, is_active)
FROM (
    SELECT 
        $1::VARCHAR AS table_name,
        $2::VARCHAR AS tpa,
        $3::VARCHAR AS description,
        $4::VARCHAR AS data_owner,
        $5::VARCHAR AS refresh_frequency,
        $6::NUMBER AS retention_days,
        TRUE AS is_active
    FROM @SILVER_CONFIG/silver_target_schemas_samples.csv
)
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

-- ============================================
-- LOAD SAMPLE TARGET FIELDS
-- ============================================

COPY INTO target_fields (schema_id, field_name, data_type, field_order, is_nullable, description)
FROM (
    SELECT 
        ts.schema_id,
        $3::VARCHAR AS field_name,
        $4::VARCHAR AS data_type,
        $5::NUMBER AS field_order,
        $6::BOOLEAN AS is_nullable,
        $7::VARCHAR AS description
    FROM @SILVER_CONFIG/silver_target_fields_samples.csv
    JOIN target_schemas ts ON ts.table_name = $1::VARCHAR AND ts.tpa = $2::VARCHAR
)
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

-- ============================================
-- CREATE SAMPLE TARGET TABLES
-- ============================================

-- Create tables for each provider
CALL create_silver_target_table('CLAIMS_PROVIDER_A', 'PROVIDER_A');
CALL create_silver_target_table('CLAIMS_PROVIDER_B', 'PROVIDER_B');
CALL create_silver_target_table('CLAIMS_PROVIDER_E', 'PROVIDER_E');

-- ============================================
-- VERIFICATION
-- ============================================

SELECT 'Sample Schemas Loaded' AS status,
       COUNT(*) AS schema_count
FROM target_schemas
WHERE table_name LIKE '%PROVIDER%';

SELECT 'Sample Fields Loaded' AS status,
       COUNT(*) AS field_count
FROM target_fields tf
JOIN target_schemas ts ON tf.schema_id = ts.schema_id
WHERE ts.table_name LIKE '%PROVIDER%';

SELECT 'Sample Tables Created' AS status,
       table_name,
       tpa
FROM target_schemas
WHERE table_name LIKE '%PROVIDER%'
ORDER BY tpa, table_name;
