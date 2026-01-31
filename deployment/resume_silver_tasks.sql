-- ============================================
-- RESUME SILVER LAYER TASKS
-- ============================================
-- Purpose: Resume all Silver layer tasks after deployment
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
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';
SET WAREHOUSE_NAME = '$SNOWFLAKE_WAREHOUSE';
SET SNOWFLAKE_ROLE = '$SNOWFLAKE_ROLE';

USE ROLE IDENTIFIER($SNOWFLAKE_ROLE);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- ============================================
-- RESUME TASKS
-- ============================================

-- Resume the auto-transform task (root task, no dependencies)
ALTER TASK auto_transform_mappings_task RESUME;

-- ============================================
-- VERIFICATION
-- ============================================

-- Verify tasks are now started
SHOW TASKS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

SELECT 'All Silver layer tasks have been resumed!' AS status,
       'auto_transform_mappings_task will run daily at 2 AM' AS schedule_info;
