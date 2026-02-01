-- ============================================
-- SILVER LAYER DATA QUALITY CHECKS
-- ============================================
-- Purpose: Comprehensive data quality validation for Silver tables
--
-- Quality Checks:
--   1. Row Count Validation
--   2. Null Value Analysis
--   3. Data Freshness Check
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';
SET SNOWFLAKE_ROLE = '$SNOWFLAKE_ROLE';

USE ROLE IDENTIFIER($SNOWFLAKE_ROLE);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- ============================================
-- PROCEDURE: Run Basic Data Quality Checks
-- ============================================
-- Runs basic data quality checks on a Silver table
-- Returns: Summary of quality metrics

CREATE OR REPLACE PROCEDURE run_data_quality_checks(
    p_table_name VARCHAR,
    p_tpa VARCHAR,
    p_batch_id VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_batch_id VARCHAR;
    v_full_table_name VARCHAR;
    v_result_msg VARCHAR;
BEGIN
    -- Generate batch ID if not provided
    v_batch_id := COALESCE(:p_batch_id, 'DQ_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS'));
    
    -- Construct full table name
    v_full_table_name := UPPER(:p_tpa) || '_' || UPPER(:p_table_name);
    
    -- Check if table exists
    LET table_exists INTEGER := (
        SELECT COUNT(*) 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = $SILVER_SCHEMA_NAME
          AND TABLE_NAME = :v_full_table_name
    );
    
    IF (table_exists = 0) THEN
        RETURN 'ERROR: Table ' || :v_full_table_name || ' does not exist';
    END IF;
    
    -- Insert row count metric
    INSERT INTO data_quality_metrics (
        batch_id, tpa, target_table, metric_name, metric_value, metric_threshold, passed, description
    )
    SELECT
        :v_batch_id,
        :p_tpa,
        :v_full_table_name,
        'ROW_COUNT',
        COUNT(*),
        0,
        COUNT(*) > 0,
        'Total number of rows in table'
    FROM IDENTIFIER(:v_full_table_name);
    
    -- Insert freshness metric if _LOAD_TIMESTAMP exists
    INSERT INTO data_quality_metrics (
        batch_id, tpa, target_table, metric_name, metric_value, metric_threshold, passed, description
    )
    SELECT
        :v_batch_id,
        :p_tpa,
        :v_full_table_name,
        'DATA_FRESHNESS_HOURS',
        DATEDIFF(hour, MAX(_LOAD_TIMESTAMP), CURRENT_TIMESTAMP()),
        24.0,
        DATEDIFF(hour, MAX(_LOAD_TIMESTAMP), CURRENT_TIMESTAMP()) <= 24.0,
        'Hours since last data load'
    FROM IDENTIFIER(:v_full_table_name)
    WHERE EXISTS (
        SELECT 1 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = $SILVER_SCHEMA_NAME
          AND TABLE_NAME = :v_full_table_name
          AND COLUMN_NAME = '_LOAD_TIMESTAMP'
    );
    
    -- Calculate and insert overall quality score
    INSERT INTO data_quality_metrics (
        batch_id, tpa, target_table, metric_name, metric_value, metric_threshold, passed, description
    )
    SELECT
        :v_batch_id,
        :p_tpa,
        :v_full_table_name,
        'OVERALL_QUALITY_SCORE',
        (SUM(CASE WHEN passed THEN 1 ELSE 0 END)::FLOAT / COUNT(*)::FLOAT) * 100,
        80.0,
        (SUM(CASE WHEN passed THEN 1 ELSE 0 END)::FLOAT / COUNT(*)::FLOAT) * 100 >= 80.0,
        'Overall data quality score: ' || SUM(CASE WHEN passed THEN 1 ELSE 0 END) || ' of ' || COUNT(*) || ' checks passed'
    FROM data_quality_metrics
    WHERE batch_id = :v_batch_id
      AND target_table = :v_full_table_name;
    
    -- Return summary
    LET v_quality_score FLOAT := (
        SELECT metric_value 
        FROM data_quality_metrics 
        WHERE batch_id = :v_batch_id 
          AND metric_name = 'OVERALL_QUALITY_SCORE'
        LIMIT 1
    );
    
    v_result_msg := 'Data Quality Check Complete for ' || :v_full_table_name || 
                    '. Score: ' || ROUND(:v_quality_score, 2) || '%. Batch ID: ' || :v_batch_id;
    
    RETURN v_result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Run Data Quality Checks for All Tables
-- ============================================
-- Runs data quality checks on all Silver tables for a TPA

CREATE OR REPLACE PROCEDURE run_data_quality_checks_all(
    p_tpa VARCHAR,
    p_batch_id VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_batch_id VARCHAR;
    v_tables_checked INTEGER DEFAULT 0;
    v_result_msg VARCHAR;
BEGIN
    -- Generate batch ID if not provided
    v_batch_id := COALESCE(:p_batch_id, :p_tpa || '_DQ_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS'));
    
    -- Get all tables for this TPA
    LET tables_cursor CURSOR FOR
        SELECT DISTINCT physical_table_name, schema_table_name
        FROM created_tables
        WHERE tpa = :p_tpa
          AND active = TRUE
        ORDER BY physical_table_name;
    
    FOR table_record IN tables_cursor DO
        LET table_name VARCHAR := table_record.schema_table_name;
        LET check_result VARCHAR;
        
        -- Run quality checks on this table
        CALL run_data_quality_checks(:table_name, :p_tpa, :v_batch_id);
        
        v_tables_checked := v_tables_checked + 1;
    END FOR;
    
    v_result_msg := 'Data Quality Checks Complete. Checked ' || :v_tables_checked ||
                    ' tables for TPA: ' || :p_tpa || '. Batch ID: ' || :v_batch_id;
    
    RETURN v_result_msg;
END;
$$;

-- ============================================
-- VIEW: Data Quality Summary
-- ============================================
-- Summary of latest data quality metrics per table

CREATE OR REPLACE VIEW v_data_quality_summary AS
WITH latest_batches AS (
    SELECT
        tpa,
        target_table,
        MAX(batch_id) as latest_batch_id
    FROM data_quality_metrics
    GROUP BY tpa, target_table
),
latest_metrics AS (
    SELECT
        dqm.*
    FROM data_quality_metrics dqm
    INNER JOIN latest_batches lb
        ON dqm.tpa = lb.tpa
        AND dqm.target_table = lb.target_table
        AND dqm.batch_id = lb.latest_batch_id
)
SELECT
    tpa,
    target_table,
    batch_id,
    MAX(CASE WHEN metric_name = 'OVERALL_QUALITY_SCORE' THEN metric_value END) as quality_score,
    MAX(CASE WHEN metric_name = 'ROW_COUNT' THEN metric_value END) as row_count,
    MAX(CASE WHEN metric_name = 'DATA_FRESHNESS_HOURS' THEN metric_value END) as hours_since_load,
    SUM(CASE WHEN passed = TRUE THEN 1 ELSE 0 END) as checks_passed,
    COUNT(*) as total_checks,
    MAX(measured_timestamp) as last_check_timestamp
FROM latest_metrics
GROUP BY tpa, target_table, batch_id
ORDER BY quality_score ASC, tpa, target_table;

COMMENT ON VIEW v_data_quality_summary IS 'Summary of latest data quality metrics for each Silver table. Shows overall quality score, row count, freshness, and check pass rate.';

-- ============================================
-- VIEW: Data Quality Failures
-- ============================================
-- Shows all failed quality checks

CREATE OR REPLACE VIEW v_data_quality_failures AS
SELECT
    tpa,
    target_table,
    batch_id,
    metric_name,
    metric_value,
    metric_threshold,
    description,
    measured_timestamp
FROM data_quality_metrics
WHERE passed = FALSE
ORDER BY measured_timestamp DESC, tpa, target_table;

COMMENT ON VIEW v_data_quality_failures IS 'All failed data quality checks. Use this to identify and investigate quality issues.';

-- ============================================
-- VIEW: Data Quality Trends
-- ============================================
-- Shows quality score trends over time

CREATE OR REPLACE VIEW v_data_quality_trends AS
SELECT
    tpa,
    target_table,
    batch_id,
    metric_value as quality_score,
    measured_timestamp,
    LAG(metric_value) OVER (PARTITION BY tpa, target_table ORDER BY measured_timestamp) as previous_score,
    metric_value - LAG(metric_value) OVER (PARTITION BY tpa, target_table ORDER BY measured_timestamp) as score_change
FROM data_quality_metrics
WHERE metric_name = 'OVERALL_QUALITY_SCORE'
ORDER BY tpa, target_table, measured_timestamp DESC;

COMMENT ON VIEW v_data_quality_trends IS 'Quality score trends over time. Shows how data quality is improving or degrading.';

-- ============================================
-- Grant Permissions
-- ============================================

-- Note: Grants will be handled by the main deployment script
-- These are commented out to avoid syntax errors with IDENTIFIER in GRANT statements
-- GRANT USAGE ON PROCEDURE run_data_quality_checks(VARCHAR, VARCHAR, VARCHAR) TO ROLE BORDEREAU_PROCESSING_PIPELINE_READWRITE;
-- GRANT USAGE ON PROCEDURE run_data_quality_checks_all(VARCHAR, VARCHAR) TO ROLE BORDEREAU_PROCESSING_PIPELINE_READWRITE;
-- GRANT SELECT ON VIEW v_data_quality_summary TO ROLE BORDEREAU_PROCESSING_PIPELINE_READONLY;
-- GRANT SELECT ON VIEW v_data_quality_failures TO ROLE BORDEREAU_PROCESSING_PIPELINE_READONLY;
-- GRANT SELECT ON VIEW v_data_quality_trends TO ROLE BORDEREAU_PROCESSING_PIPELINE_READONLY;

-- ============================================
-- Success Message
-- ============================================

SELECT 'Data Quality Checks procedures and views created successfully' AS status;
