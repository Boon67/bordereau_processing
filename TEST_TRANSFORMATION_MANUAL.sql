-- ============================================
-- MANUAL TRANSFORMATION TEST
-- Run this step by step to diagnose the issue
-- ============================================

-- Set your context
USE DATABASE BORDEREAU;
USE SCHEMA SILVER;

-- ============================================
-- STEP 1: Verify Prerequisites
-- ============================================

-- Check source data
SELECT 'Step 1: Source Data' as step;
SELECT COUNT(*) as source_record_count, TPA
FROM BRONZE.RAW_DATA_TABLE
WHERE TPA = 'provider_a'
GROUP BY TPA;
-- Expected: 5 records for provider_a

-- Check field mappings
SELECT 'Step 2: Field Mappings' as step;
SELECT 
    SOURCE_FIELD,
    TARGET_COLUMN,
    APPROVED,
    CONFIDENCE_SCORE
FROM SILVER.FIELD_MAPPINGS
WHERE TPA = 'provider_a'
  AND TARGET_TABLE = 'DENTAL_CLAIMS'
ORDER BY SOURCE_FIELD;
-- Expected: 7 mappings, check APPROVED column

-- ============================================
-- STEP 2: Approve Mappings (if needed)
-- ============================================

-- If APPROVED = FALSE for all mappings, run this:
/*
UPDATE SILVER.FIELD_MAPPINGS
SET APPROVED = TRUE,
    APPROVED_BY = CURRENT_USER(),
    APPROVED_TIMESTAMP = CURRENT_TIMESTAMP(),
    UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()
WHERE TPA = 'provider_a'
  AND TARGET_TABLE = 'DENTAL_CLAIMS'
  AND APPROVED = FALSE;
*/

-- Verify approvals
SELECT 'Step 3: Verify Approvals' as step;
SELECT 
    COUNT(*) as total_mappings,
    SUM(CASE WHEN APPROVED = TRUE THEN 1 ELSE 0 END) as approved_count,
    SUM(CASE WHEN APPROVED = FALSE THEN 1 ELSE 0 END) as pending_count
FROM SILVER.FIELD_MAPPINGS
WHERE TPA = 'provider_a'
  AND TARGET_TABLE = 'DENTAL_CLAIMS';
-- Expected: approved_count should be 7

-- ============================================
-- STEP 3: Check Target Table
-- ============================================

SELECT 'Step 4: Check Target Table' as step;
SHOW TABLES LIKE 'PROVIDER_A_DENTAL_CLAIMS' IN SCHEMA SILVER;
-- Expected: 1 row

-- If table doesn't exist, create it:
/*
CALL SILVER.CREATE_SILVER_TABLE('DENTAL_CLAIMS', 'provider_a');
*/

-- Check current records in target
SELECT 'Step 5: Current Target Records' as step;
SELECT COUNT(*) as current_record_count
FROM SILVER.PROVIDER_A_DENTAL_CLAIMS;

-- ============================================
-- STEP 4: Run Transformation
-- ============================================

SELECT 'Step 6: Running Transformation' as step;

-- Call the transformation procedure
CALL SILVER.TRANSFORM_BRONZE_TO_SILVER(
    'DENTAL_CLAIMS',    -- target_table
    'provider_a',       -- tpa
    'RAW_DATA_TABLE',   -- source_table
    'BRONZE',           -- source_schema
    10000,              -- batch_size
    TRUE,               -- apply_rules
    FALSE               -- incremental
);

-- The result should say: "SUCCESS: Transformed X records from RAW_DATA_TABLE to PROVIDER_A_DENTAL_CLAIMS"

-- ============================================
-- STEP 5: Verify Results
-- ============================================

SELECT 'Step 7: Verify Target Records' as step;
SELECT COUNT(*) as final_record_count
FROM SILVER.PROVIDER_A_DENTAL_CLAIMS;
-- Expected: Should match source count (5)

-- View sample data
SELECT 'Step 8: Sample Data' as step;
SELECT * 
FROM SILVER.PROVIDER_A_DENTAL_CLAIMS 
LIMIT 5;

-- Check processing log
SELECT 'Step 9: Processing Log' as step;
SELECT 
    BATCH_ID,
    STATUS,
    RECORDS_PROCESSED,
    RECORDS_SUCCESS,
    ERROR_MESSAGE,
    START_TIME,
    END_TIMESTAMP
FROM SILVER.SILVER_PROCESSING_LOG
WHERE TPA = 'provider_a'
  AND TARGET_TABLE = 'DENTAL_CLAIMS'
ORDER BY START_TIME DESC
LIMIT 3;

-- ============================================
-- DIAGNOSTIC SUMMARY
-- ============================================

SELECT 'Step 10: Diagnostic Summary' as step;

WITH source_check AS (
    SELECT COUNT(*) as source_count
    FROM BRONZE.RAW_DATA_TABLE
    WHERE TPA = 'provider_a'
),
mapping_check AS (
    SELECT 
        COUNT(*) as total_mappings,
        SUM(CASE WHEN APPROVED = TRUE THEN 1 ELSE 0 END) as approved_mappings
    FROM SILVER.FIELD_MAPPINGS
    WHERE TPA = 'provider_a' AND TARGET_TABLE = 'DENTAL_CLAIMS'
),
table_check AS (
    SELECT COUNT(*) as table_exists
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'SILVER'
      AND TABLE_NAME = 'PROVIDER_A_DENTAL_CLAIMS'
),
target_check AS (
    SELECT COUNT(*) as target_count
    FROM SILVER.PROVIDER_A_DENTAL_CLAIMS
),
log_check AS (
    SELECT 
        STATUS,
        RECORDS_PROCESSED,
        ERROR_MESSAGE
    FROM SILVER.SILVER_PROCESSING_LOG
    WHERE TPA = 'provider_a'
    ORDER BY START_TIME DESC
    LIMIT 1
)
SELECT 
    s.source_count as source_records,
    m.total_mappings,
    m.approved_mappings,
    t.table_exists as target_table_exists,
    tc.target_count as target_records,
    l.STATUS as last_status,
    l.RECORDS_PROCESSED as last_records_processed,
    l.ERROR_MESSAGE as last_error,
    CASE 
        WHEN s.source_count = 0 THEN '❌ No source data found'
        WHEN m.approved_mappings = 0 THEN '❌ No approved mappings'
        WHEN t.table_exists = 0 THEN '❌ Target table does not exist'
        WHEN l.STATUS = 'FAILED' THEN '❌ Last transformation failed: ' || COALESCE(l.ERROR_MESSAGE, 'Unknown error')
        WHEN tc.target_count = 0 THEN '⚠️ Transformation ran but no records inserted'
        WHEN tc.target_count = s.source_count THEN '✅ SUCCESS: All records transformed'
        ELSE '⚠️ Partial success: ' || tc.target_count || ' of ' || s.source_count || ' records'
    END as diagnosis
FROM source_check s, mapping_check m, table_check t, target_check tc, log_check l;
