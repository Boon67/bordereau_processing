-- ============================================
-- BRONZE LAYER TASKS
-- ============================================
-- Purpose: Task orchestration for automated file processing
-- 
-- This script creates 5 tasks:
--   1. discover_files_task - Scan @SRC for new files (every 60 minutes)
--   2. process_files_task - Process queued files (after discovery)
--   3. move_successful_files_task - Move SUCCESS files to @COMPLETED (parallel)
--   4. move_failed_files_task - Move FAILED files to @ERROR (parallel)
--   5. archive_old_files_task - Archive files older than 30 days (daily at 2 AM)
--
-- Task Dependencies:
--   discover_files_task (root)
--       ↓
--   process_files_task
--       ↓
--       ├─→ move_successful_files_task (parallel)
--       └─→ move_failed_files_task (parallel)
--   
--   archive_old_files_task (independent, daily)
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET BRONZE_SCHEMA_NAME = '$BRONZE_SCHEMA_NAME';
SET WAREHOUSE_NAME = '$SNOWFLAKE_WAREHOUSE';
SET SNOWFLAKE_ROLE = '$SNOWFLAKE_ROLE';

USE ROLE IDENTIFIER($SNOWFLAKE_ROLE);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);

-- ============================================
-- SUSPEND EXISTING TASKS (if any)
-- ============================================

-- Suspend root tasks first (required before modifying child tasks)
ALTER TASK IF EXISTS discover_files_task SUSPEND;
ALTER TASK IF EXISTS archive_old_files_task SUSPEND;

-- Then suspend child tasks
ALTER TASK IF EXISTS move_successful_files_task SUSPEND;
ALTER TASK IF EXISTS move_failed_files_task SUSPEND;
ALTER TASK IF EXISTS process_files_task SUSPEND;

-- ============================================
-- TASK 1: Discover Files (Root Task)
-- ============================================

CREATE OR REPLACE TASK discover_files_task
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    SCHEDULE = '__BRONZE_DISCOVERY_SCHEDULE__'
    COMMENT = 'Scan @SRC stage for new files and add to processing queue. Runs every 60 minutes (configurable).'
AS
CALL discover_files();

-- ============================================
-- TASK 2: Process Files (After Discovery)
-- ============================================

CREATE OR REPLACE TASK process_files_task
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    COMMENT = 'Process pending files from queue (batch of 10). Runs after file discovery.'
    AFTER discover_files_task
AS
CALL process_queued_files();

-- ============================================
-- TASK 3: Move Successful Files (Parallel)
-- ============================================

CREATE OR REPLACE TASK move_successful_files_task
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    COMMENT = 'Move successfully processed files from @PROCESSING to @COMPLETED. Runs after file processing.'
    AFTER process_files_task
AS
CALL move_processed_files();

-- ============================================
-- TASK 4: Move Failed Files (Parallel)
-- ============================================

CREATE OR REPLACE TASK move_failed_files_task
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    COMMENT = 'Move failed files from @PROCESSING to @ERROR. Runs after file processing (parallel with move_successful_files_task).'
    AFTER process_files_task
AS
CALL move_failed_files();

-- ============================================
-- TASK 5: Archive Old Files (Independent)
-- ============================================

CREATE OR REPLACE TASK archive_old_files_task
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    SCHEDULE = 'USING CRON 0 2 * * * America/New_York'
    COMMENT = 'Archive files older than 30 days from @COMPLETED and @ERROR to @ARCHIVE. Runs daily at 2 AM.'
AS
CALL archive_old_files();

-- ============================================
-- RESUME TASKS (in dependency order)
-- ============================================

-- Note: Tasks are created in SUSPENDED state by default
-- The deployment script (deploy_bronze.sh) will automatically resume
-- these tasks after deployment by running deployment/resume_tasks.sql
--
-- To manually resume tasks, run:
--   snow sql -f deployment/resume_tasks.sql --connection <CONNECTION_NAME>
--
-- Or manually resume in correct order (child tasks first, then root):
--   ALTER TASK move_successful_files_task RESUME;
--   ALTER TASK move_failed_files_task RESUME;
--   ALTER TASK process_files_task RESUME;
--   ALTER TASK archive_old_files_task RESUME;
--   ALTER TASK discover_files_task RESUME;

-- ============================================
-- VERIFICATION
-- ============================================

-- Show created tasks
SHOW TASKS IN SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);

-- Display success message
SELECT 'Bronze tasks created successfully' AS status,
       'Tasks are in SUSPENDED state. Use ALTER TASK ... RESUME to start.' AS note;
