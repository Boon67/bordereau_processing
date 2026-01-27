-- ============================================
-- RESUME GOLD LAYER TASKS
-- ============================================
-- Purpose: Resume all Gold layer tasks after deployment
-- 
-- IMPORTANT: Tasks must be resumed in the correct order:
--   1. Resume child tasks first (bottom-up)
--   2. Resume root task last
-- 
-- This is because Snowflake requires all child tasks to be
-- in a consistent state before resuming the root task.
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET GOLD_SCHEMA_NAME = '$GOLD_SCHEMA_NAME';
SET WAREHOUSE_NAME = '$SNOWFLAKE_WAREHOUSE';
SET SNOWFLAKE_ROLE = '$SNOWFLAKE_ROLE';

USE ROLE IDENTIFIER($SNOWFLAKE_ROLE);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);
USE SCHEMA IDENTIFIER($GOLD_SCHEMA_NAME);

-- ============================================
-- RESUME TASKS (BOTTOM-UP ORDER)
-- ============================================

-- Resume child tasks first (if they exist)
ALTER TASK IF EXISTS task_refresh_member_360 RESUME;
ALTER TASK IF EXISTS task_refresh_provider_performance RESUME;
ALTER TASK IF EXISTS task_refresh_financial_summary RESUME;
ALTER TASK IF EXISTS task_run_quality_checks RESUME;

-- Resume root task last
ALTER TASK IF EXISTS task_refresh_claims_analytics RESUME;

-- ============================================
-- VERIFICATION
-- ============================================

-- Verify tasks are now started
SHOW TASKS IN SCHEMA IDENTIFIER($GOLD_SCHEMA_NAME);

SELECT 'All Gold layer tasks have been resumed!' AS status;
