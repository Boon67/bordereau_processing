-- ============================================
-- TRANSFORMATION DEBUG SCRIPT
-- Run these queries to diagnose the issue
-- ============================================

-- Step 1: Check if source data exists
SELECT 
    'Source Data Check' as check_type,
    COUNT(*) as record_count,
    TPA
FROM BRONZE.RAW_DATA_TABLE
WHERE TPA = 'provider_a'
GROUP BY TPA;

-- Expected: Should return 5 rows for provider_a

-- Step 2: Check if field mappings exist
SELECT 
    'Field Mappings Check' as check_type,
    COUNT(*) as total_mappings,
    SUM(CASE WHEN APPROVED = TRUE THEN 1 ELSE 0 END) as approved_mappings,
    SUM(CASE WHEN APPROVED = FALSE THEN 1 ELSE 0 END) as pending_mappings
FROM SILVER.FIELD_MAPPINGS
WHERE TPA = 'provider_a'
  AND TARGET_TABLE = 'DENTAL_CLAIMS';

-- Expected: Should show 7 total mappings, and how many are approved

-- Step 3: View all mappings in detail
SELECT 
    MAPPING_ID,
    SOURCE_FIELD,
    TARGET_COLUMN,
    APPROVED,
    CONFIDENCE_SCORE,
    MAPPING_METHOD,
    CREATED_TIMESTAMP
FROM SILVER.FIELD_MAPPINGS
WHERE TPA = 'provider_a'
  AND TARGET_TABLE = 'DENTAL_CLAIMS'
ORDER BY SOURCE_FIELD;

-- Step 4: Check if target table exists
SHOW TABLES LIKE 'PROVIDER_A_DENTAL_CLAIMS' IN SCHEMA SILVER;

-- Expected: Should return 1 row if table exists

-- Step 5: Check current data in target table
SELECT 
    'Target Table Check' as check_type,
    COUNT(*) as record_count
FROM SILVER.PROVIDER_A_DENTAL_CLAIMS;

-- Expected: Should show how many records are currently in the table

-- Step 6: Check processing log for errors
SELECT 
    BATCH_ID,
    TPA,
    SOURCE_TABLE,
    TARGET_TABLE,
    STATUS,
    RECORDS_PROCESSED,
    RECORDS_SUCCESS,
    ERROR_MESSAGE,
    START_TIME,
    END_TIMESTAMP
FROM SILVER.SILVER_PROCESSING_LOG
WHERE TPA = 'provider_a'
ORDER BY START_TIME DESC
LIMIT 5;

-- This will show recent transformation attempts and any error messages

-- Step 7: Manually test the transformation procedure
CALL SILVER.TRANSFORM_BRONZE_TO_SILVER(
    'DENTAL_CLAIMS',    -- target_table
    'provider_a',       -- tpa
    'RAW_DATA_TABLE',   -- source_table
    'BRONZE',           -- source_schema
    10000,              -- batch_size
    TRUE,               -- apply_rules
    FALSE               -- incremental
);

-- This will show the exact error message if transformation fails

-- Step 8: Check what fields are available in source data
SELECT DISTINCT
    f.key as field_name
FROM BRONZE.RAW_DATA_TABLE,
LATERAL FLATTEN(input => RAW_DATA) f
WHERE TPA = 'provider_a'
  AND RAW_DATA IS NOT NULL
ORDER BY field_name;

-- This shows what fields are actually in your source data
