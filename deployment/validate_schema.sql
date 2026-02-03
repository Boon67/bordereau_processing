-- ============================================
-- SCHEMA VALIDATION SCRIPT
-- ============================================
-- Purpose: Validate that all required tables, views, and procedures exist
-- Usage: Run after deployment to ensure schema is complete
-- Date: 2026-02-03

USE DATABASE BORDEREAU_PROCESSING_PIPELINE;

-- ============================================
-- BRONZE SCHEMA VALIDATION
-- ============================================

USE SCHEMA BRONZE;

SELECT 'BRONZE SCHEMA VALIDATION' as validation_section;

-- Check required tables
WITH required_tables AS (
    SELECT 'RAW_DATA_TABLE' as table_name UNION ALL
    SELECT 'TPA_MASTER' UNION ALL
    SELECT 'FILE_PROCESSING_LOGS' UNION ALL
    SELECT 'FILE_PROCESSING_QUEUE' UNION ALL
    SELECT 'API_REQUEST_LOGS' UNION ALL
    SELECT 'APPLICATION_LOGS' UNION ALL
    SELECT 'ERROR_LOGS' UNION ALL
    SELECT 'TASK_EXECUTION_LOGS'
),
existing_tables AS (
    SELECT table_name
    FROM INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'BRONZE'
      AND table_type = 'BASE TABLE'
)
SELECT 
    'Bronze Tables' as check_type,
    COUNT(DISTINCT rt.table_name) as required_count,
    COUNT(DISTINCT et.table_name) as existing_count,
    CASE 
        WHEN COUNT(DISTINCT rt.table_name) = COUNT(DISTINCT et.table_name) THEN '✅ PASS'
        ELSE '❌ FAIL: Missing ' || (COUNT(DISTINCT rt.table_name) - COUNT(DISTINCT et.table_name)) || ' tables'
    END as status
FROM required_tables rt
LEFT JOIN existing_tables et ON rt.table_name = et.table_name;

-- List missing Bronze tables
WITH required_tables AS (
    SELECT 'RAW_DATA_TABLE' as table_name UNION ALL
    SELECT 'TPA_MASTER' UNION ALL
    SELECT 'FILE_PROCESSING_LOGS' UNION ALL
    SELECT 'FILE_PROCESSING_QUEUE' UNION ALL
    SELECT 'API_REQUEST_LOGS' UNION ALL
    SELECT 'APPLICATION_LOGS' UNION ALL
    SELECT 'ERROR_LOGS' UNION ALL
    SELECT 'TASK_EXECUTION_LOGS'
),
existing_tables AS (
    SELECT table_name
    FROM INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'BRONZE'
      AND table_type = 'BASE TABLE'
)
SELECT 
    'Missing Bronze Table' as issue_type,
    rt.table_name as missing_table
FROM required_tables rt
LEFT JOIN existing_tables et ON rt.table_name = et.table_name
WHERE et.table_name IS NULL;

-- ============================================
-- SILVER SCHEMA VALIDATION
-- ============================================

USE SCHEMA SILVER;

SELECT 'SILVER SCHEMA VALIDATION' as validation_section;

-- Check required tables
WITH required_tables AS (
    SELECT 'TARGET_SCHEMAS' as table_name UNION ALL
    SELECT 'FIELD_MAPPINGS' UNION ALL
    SELECT 'TRANSFORMATION_RULES' UNION ALL
    SELECT 'CREATED_TABLES' UNION ALL
    SELECT 'LLM_PROMPT_TEMPLATES' UNION ALL
    SELECT 'SILVER_PROCESSING_LOG' UNION ALL
    SELECT 'DATA_QUALITY_METRICS' UNION ALL
    SELECT 'QUARANTINE_RECORDS' UNION ALL
    SELECT 'PROCESSING_WATERMARKS'
),
existing_tables AS (
    SELECT table_name
    FROM INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'SILVER'
      AND table_type IN ('BASE TABLE', 'HYBRID')
)
SELECT 
    'Silver Tables' as check_type,
    COUNT(DISTINCT rt.table_name) as required_count,
    COUNT(DISTINCT et.table_name) as existing_count,
    CASE 
        WHEN COUNT(DISTINCT rt.table_name) = COUNT(DISTINCT et.table_name) THEN '✅ PASS'
        ELSE '❌ FAIL: Missing ' || (COUNT(DISTINCT rt.table_name) - COUNT(DISTINCT et.table_name)) || ' tables'
    END as status
FROM required_tables rt
LEFT JOIN existing_tables et ON rt.table_name = et.table_name;

-- List missing Silver tables
WITH required_tables AS (
    SELECT 'TARGET_SCHEMAS' as table_name UNION ALL
    SELECT 'FIELD_MAPPINGS' UNION ALL
    SELECT 'TRANSFORMATION_RULES' UNION ALL
    SELECT 'CREATED_TABLES' UNION ALL
    SELECT 'LLM_PROMPT_TEMPLATES' UNION ALL
    SELECT 'SILVER_PROCESSING_LOG' UNION ALL
    SELECT 'DATA_QUALITY_METRICS' UNION ALL
    SELECT 'QUARANTINE_RECORDS' UNION ALL
    SELECT 'PROCESSING_WATERMARKS'
),
existing_tables AS (
    SELECT table_name
    FROM INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'SILVER'
      AND table_type IN ('BASE TABLE', 'HYBRID')
)
SELECT 
    'Missing Silver Table' as issue_type,
    rt.table_name as missing_table
FROM required_tables rt
LEFT JOIN existing_tables et ON rt.table_name = et.table_name
WHERE et.table_name IS NULL;

-- Check critical Silver procedures
WITH required_procedures AS (
    SELECT 'TRANSFORM_BRONZE_TO_SILVER' as procedure_name UNION ALL
    SELECT 'AUTO_MAP_FIELDS_ML' UNION ALL
    SELECT 'AUTO_MAP_FIELDS_LLM' UNION ALL
    SELECT 'APPROVE_FIELD_MAPPING' UNION ALL
    SELECT 'CREATE_SILVER_TABLE'
),
existing_procedures AS (
    SELECT procedure_name
    FROM INFORMATION_SCHEMA.PROCEDURES
    WHERE procedure_schema = 'SILVER'
)
SELECT 
    'Silver Procedures' as check_type,
    COUNT(DISTINCT rp.procedure_name) as required_count,
    COUNT(DISTINCT ep.procedure_name) as existing_count,
    CASE 
        WHEN COUNT(DISTINCT rp.procedure_name) = COUNT(DISTINCT ep.procedure_name) THEN '✅ PASS'
        ELSE '❌ FAIL: Missing ' || (COUNT(DISTINCT rp.procedure_name) - COUNT(DISTINCT ep.procedure_name)) || ' procedures'
    END as status
FROM required_procedures rp
LEFT JOIN existing_procedures ep ON rp.procedure_name = ep.procedure_name;

-- ============================================
-- GOLD SCHEMA VALIDATION
-- ============================================

USE SCHEMA GOLD;

SELECT 'GOLD SCHEMA VALIDATION' as validation_section;

-- Check required tables
WITH required_tables AS (
    SELECT 'PROCESSING_LOG' as table_name UNION ALL
    SELECT 'QUALITY_CHECK_RESULTS' UNION ALL
    SELECT 'FIELD_MAPPINGS' UNION ALL
    SELECT 'TRANSFORMATION_RULES' UNION ALL
    SELECT 'TARGET_SCHEMAS' UNION ALL
    SELECT 'TARGET_FIELDS' UNION ALL
    SELECT 'QUALITY_RULES' UNION ALL
    SELECT 'MEMBER_JOURNEYS' UNION ALL
    SELECT 'JOURNEY_EVENTS' UNION ALL
    SELECT 'BUSINESS_METRICS'
),
existing_tables AS (
    SELECT table_name
    FROM INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'GOLD'
      AND table_type = 'BASE TABLE'
)
SELECT 
    'Gold Tables' as check_type,
    COUNT(DISTINCT rt.table_name) as required_count,
    COUNT(DISTINCT et.table_name) as existing_count,
    CASE 
        WHEN COUNT(DISTINCT rt.table_name) = COUNT(DISTINCT et.table_name) THEN '✅ PASS'
        ELSE '❌ FAIL: Missing ' || (COUNT(DISTINCT rt.table_name) - COUNT(DISTINCT et.table_name)) || ' tables'
    END as status
FROM required_tables rt
LEFT JOIN existing_tables et ON rt.table_name = et.table_name;

-- ============================================
-- OVERALL SUMMARY
-- ============================================

SELECT 'VALIDATION SUMMARY' as validation_section;

WITH bronze_tables AS (
    SELECT COUNT(*) as cnt FROM INFORMATION_SCHEMA.TABLES 
    WHERE table_schema = 'BRONZE' AND table_type = 'BASE TABLE'
),
silver_tables AS (
    SELECT COUNT(*) as cnt FROM INFORMATION_SCHEMA.TABLES 
    WHERE table_schema = 'SILVER' AND table_type IN ('BASE TABLE', 'HYBRID')
),
gold_tables AS (
    SELECT COUNT(*) as cnt FROM INFORMATION_SCHEMA.TABLES 
    WHERE table_schema = 'GOLD' AND table_type = 'BASE TABLE'
),
silver_procedures AS (
    SELECT COUNT(*) as cnt FROM INFORMATION_SCHEMA.PROCEDURES 
    WHERE procedure_schema = 'SILVER'
)
SELECT 
    'Database Schema' as component,
    (SELECT cnt FROM bronze_tables) as bronze_tables,
    (SELECT cnt FROM silver_tables) as silver_tables,
    (SELECT cnt FROM gold_tables) as gold_tables,
    (SELECT cnt FROM silver_procedures) as silver_procedures,
    CASE 
        WHEN (SELECT cnt FROM bronze_tables) >= 8 
         AND (SELECT cnt FROM silver_tables) >= 9
         AND (SELECT cnt FROM gold_tables) >= 10
         AND (SELECT cnt FROM silver_procedures) >= 5
        THEN '✅ SCHEMA COMPLETE'
        ELSE '❌ SCHEMA INCOMPLETE'
    END as overall_status;

-- ============================================
-- CRITICAL CHECKS
-- ============================================

SELECT 'CRITICAL CHECKS' as validation_section;

-- Check if transform can run
SELECT 
    'Transform Readiness' as check_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE table_schema = 'SILVER' AND table_name = 'SILVER_PROCESSING_LOG')
         AND EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.PROCEDURES WHERE procedure_schema = 'SILVER' AND procedure_name = 'TRANSFORM_BRONZE_TO_SILVER')
        THEN '✅ READY'
        ELSE '❌ NOT READY'
    END as status,
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE table_schema = 'SILVER' AND table_name = 'SILVER_PROCESSING_LOG')
        THEN 'Missing: silver_processing_log table'
        WHEN NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.PROCEDURES WHERE procedure_schema = 'SILVER' AND procedure_name = 'TRANSFORM_BRONZE_TO_SILVER')
        THEN 'Missing: transform_bronze_to_silver procedure'
        ELSE 'All components present'
    END as details;

-- Check if auto-mapping can run
SELECT 
    'Auto-Mapping Readiness' as check_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE table_schema = 'SILVER' AND table_name = 'LLM_PROMPT_TEMPLATES')
         AND EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.PROCEDURES WHERE procedure_schema = 'SILVER' AND procedure_name = 'AUTO_MAP_FIELDS_LLM')
         AND EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.PROCEDURES WHERE procedure_schema = 'SILVER' AND procedure_name = 'AUTO_MAP_FIELDS_ML')
        THEN '✅ READY'
        ELSE '❌ NOT READY'
    END as status,
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE table_schema = 'SILVER' AND table_name = 'LLM_PROMPT_TEMPLATES')
        THEN 'Missing: llm_prompt_templates table'
        WHEN NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.PROCEDURES WHERE procedure_schema = 'SILVER' AND procedure_name = 'AUTO_MAP_FIELDS_LLM')
        THEN 'Missing: auto_map_fields_llm procedure'
        WHEN NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.PROCEDURES WHERE procedure_schema = 'SILVER' AND procedure_name = 'AUTO_MAP_FIELDS_ML')
        THEN 'Missing: auto_map_fields_ml procedure'
        ELSE 'All components present'
    END as details;

SELECT '✅ VALIDATION COMPLETE' as final_status;
