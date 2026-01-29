-- ============================================
-- GOLD LAYER AUTOMATED TASKS
-- ============================================
-- Purpose: Create automated tasks for Gold layer processing
-- 
-- This script creates tasks for:
--   1. Daily claims analytics refresh
--   2. Daily member 360 refresh
--   3. Weekly provider performance refresh
--   4. Monthly financial summary refresh
--   5. Quality checks execution
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

-- SET DATABASE_NAME (passed via -D parameter)
-- SET GOLD_SCHEMA_NAME (passed via -D parameter)

-- Using SYSADMIN role

USE ROLE SYSADMIN;
USE DATABASE &{DATABASE_NAME};
USE SCHEMA &{GOLD_SCHEMA_NAME};

-- ============================================
-- SUSPEND EXISTING TASKS (if any)
-- ============================================

-- Suspend root tasks first (required before modifying child tasks)
ALTER TASK IF EXISTS task_refresh_claims_analytics SUSPEND;
ALTER TASK IF EXISTS task_master_gold_refresh SUSPEND;

-- Then suspend child tasks
ALTER TASK IF EXISTS task_quality_checks SUSPEND;
ALTER TASK IF EXISTS task_refresh_member_360 SUSPEND;

-- ============================================
-- TASK 1: Daily Claims Analytics Refresh
-- ============================================

CREATE OR REPLACE TASK task_refresh_claims_analytics
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 2 * * * America/New_York'  -- Daily at 2 AM EST
    COMMENT = 'Refresh Claims Analytics Gold table daily'
AS
    CALL transform_claims_analytics('ALL');

-- ============================================
-- TASK 2: Daily Member 360 Refresh
-- ============================================

CREATE OR REPLACE TASK task_refresh_member_360
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 3 * * * America/New_York'  -- Daily at 3 AM EST
    AFTER task_refresh_claims_analytics
    COMMENT = 'Refresh Member 360 Gold table daily'
AS
    CALL transform_member_360('ALL');

-- ============================================
-- TASK 3: Daily Quality Checks
-- ============================================

CREATE OR REPLACE TASK task_quality_checks
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 4 * * * America/New_York'  -- Daily at 4 AM EST
    AFTER task_refresh_member_360
    COMMENT = 'Execute quality checks on Gold tables'
AS
BEGIN
    CALL execute_quality_checks('CLAIMS_ANALYTICS_ALL', 'ALL');
    CALL execute_quality_checks('MEMBER_360_ALL', 'ALL');
END;

-- ============================================
-- TASK 4: Master Gold Refresh (All Transformations)
-- ============================================

CREATE OR REPLACE TASK task_master_gold_refresh
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 1 * * * America/New_York'  -- Daily at 1 AM EST
    COMMENT = 'Master task to run all Gold transformations'
AS
    CALL run_gold_transformations('ALL');

-- ============================================
-- ENABLE TASKS
-- ============================================
-- Note: Tasks are created in SUSPENDED state by default
-- Uncomment the following to enable them

-- ALTER TASK task_refresh_claims_analytics RESUME;
-- ALTER TASK task_refresh_member_360 RESUME;
-- ALTER TASK task_quality_checks RESUME;
-- ALTER TASK task_master_gold_refresh RESUME;

-- ============================================
-- GRANT PERMISSIONS ON TASKS
-- ============================================

GRANT OPERATE ON TASK task_refresh_claims_analytics TO ROLE SYSADMIN;
GRANT OPERATE ON TASK task_refresh_member_360 TO ROLE SYSADMIN;
GRANT OPERATE ON TASK task_quality_checks TO ROLE SYSADMIN;
GRANT OPERATE ON TASK task_master_gold_refresh TO ROLE SYSADMIN;

-- ============================================
-- TASK MONITORING VIEWS
-- ============================================

CREATE OR REPLACE VIEW v_task_history AS
SELECT
    name AS task_name,
    database_name,
    schema_name,
    state,
    scheduled_time,
    completed_time,
    DATEDIFF(SECOND, scheduled_time, completed_time) AS duration_seconds,
    return_value,
    error_code,
    error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE schema_name = $GOLD_SCHEMA_NAME
ORDER BY scheduled_time DESC;

CREATE OR REPLACE VIEW v_gold_processing_summary AS
SELECT
    table_name,
    tpa,
    process_type,
    status,
    COUNT(*) AS run_count,
    SUM(records_processed) AS total_records,
    AVG(duration_seconds) AS avg_duration_seconds,
    MAX(end_time) AS last_run_time
FROM processing_log
WHERE table_name LIKE '%_ALL'
GROUP BY table_name, tpa, process_type, status
ORDER BY last_run_time DESC;

CREATE OR REPLACE VIEW v_quality_check_summary AS
SELECT
    qr.rule_name,
    qr.table_name,
    qr.tpa,
    qr.rule_type,
    qr.severity,
    COUNT(*) AS check_count,
    SUM(CASE WHEN qcr.status = 'PASSED' THEN 1 ELSE 0 END) AS passed_count,
    SUM(CASE WHEN qcr.status = 'FAILED' THEN 1 ELSE 0 END) AS failed_count,
    MAX(qcr.check_timestamp) AS last_check_time
FROM quality_rules qr
LEFT JOIN quality_check_results qcr ON qr.quality_rule_id = qcr.quality_rule_id
WHERE qr.is_active = TRUE
GROUP BY qr.rule_name, qr.table_name, qr.tpa, qr.rule_type, qr.severity
ORDER BY last_check_time DESC;

-- ============================================
-- COMPLETION MESSAGE
-- ============================================

SELECT 'Gold Layer Tasks Created' AS status,
       'Tasks are in SUSPENDED state. Use ALTER TASK ... RESUME to enable.' AS note,
       CURRENT_TIMESTAMP() AS completed_at;

-- Show created tasks
SHOW TASKS IN SCHEMA &{GOLD_SCHEMA_NAME};
