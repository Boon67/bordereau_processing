-- Quick Diagnostic Query
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA SILVER;

-- Single comprehensive check
WITH source_check AS (
    SELECT COUNT(*) as source_count
    FROM BRONZE.RAW_DATA_TABLE
    WHERE TPA = 'provider_a'
),
mapping_check AS (
    SELECT 
        COUNT(*) as total_mappings,
        SUM(CASE WHEN APPROVED = TRUE THEN 1 ELSE 0 END) as approved_mappings,
        SUM(CASE WHEN APPROVED = FALSE THEN 1 ELSE 0 END) as pending_mappings
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
    '=== DIAGNOSTIC RESULTS ===' as section,
    s.source_count as "Source_Records",
    m.total_mappings as "Total_Mappings",
    m.approved_mappings as "Approved_Mappings",
    m.pending_mappings as "Pending_Mappings",
    t.table_exists as "Target_Table_Exists",
    tc.target_count as "Target_Records",
    l.STATUS as "Last_Status",
    l.RECORDS_PROCESSED as "Last_Records_Processed",
    CASE 
        WHEN s.source_count = 0 THEN 'ERROR: No source data'
        WHEN m.approved_mappings = 0 THEN 'ERROR: No approved mappings - NEED TO APPROVE'
        WHEN t.table_exists = 0 THEN 'ERROR: Target table missing'
        WHEN l.STATUS = 'FAILED' THEN 'ERROR: Last run failed'
        WHEN tc.target_count = 0 THEN 'WARNING: No records in target'
        WHEN tc.target_count = s.source_count THEN 'SUCCESS: All records loaded'
        ELSE 'PARTIAL: ' || tc.target_count || ' of ' || s.source_count
    END as "Diagnosis"
FROM source_check s, mapping_check m, table_check t, target_check tc, log_check l;
