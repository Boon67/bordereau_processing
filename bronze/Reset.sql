-- ============================================
-- BRONZE LAYER RESET
-- ============================================
-- Purpose: Reset Bronze layer for redeployment
-- 
-- WARNING: This will delete all data and objects in Bronze schema
-- 
-- Use this script to:
--   - Clean up before redeployment
--   - Reset to initial state for testing
--   - Clear all data and start fresh
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET BRONZE_SCHEMA_NAME = '$BRONZE_SCHEMA_NAME';

-- Set role and context
SET role_admin = $DATABASE_NAME || '_ADMIN';

USE ROLE IDENTIFIER($role_admin);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);

-- ============================================
-- SUSPEND AND DROP TASKS
-- ============================================

-- Suspend tasks first (in reverse dependency order)
ALTER TASK IF EXISTS move_successful_files_task SUSPEND;
ALTER TASK IF EXISTS move_failed_files_task SUSPEND;
ALTER TASK IF EXISTS process_files_task SUSPEND;
ALTER TASK IF EXISTS discover_files_task SUSPEND;
ALTER TASK IF EXISTS archive_old_files_task SUSPEND;

-- Drop tasks
DROP TASK IF EXISTS move_successful_files_task;
DROP TASK IF EXISTS move_failed_files_task;
DROP TASK IF EXISTS process_files_task;
DROP TASK IF EXISTS discover_files_task;
DROP TASK IF EXISTS archive_old_files_task;

-- ============================================
-- DROP PROCEDURES
-- ============================================

DROP PROCEDURE IF EXISTS process_single_csv_file(VARCHAR, VARCHAR);
DROP PROCEDURE IF EXISTS process_single_excel_file(VARCHAR, VARCHAR);
DROP PROCEDURE IF EXISTS discover_files();
DROP PROCEDURE IF EXISTS process_queued_files();
DROP PROCEDURE IF EXISTS move_processed_files();
DROP PROCEDURE IF EXISTS move_failed_files();
DROP PROCEDURE IF EXISTS archive_old_files();

-- ============================================
-- DROP VIEWS
-- ============================================

DROP VIEW IF EXISTS v_processing_status_summary;
DROP VIEW IF EXISTS v_recent_processing_activity;
DROP VIEW IF EXISTS v_failed_files;
DROP VIEW IF EXISTS v_raw_data_statistics;

-- ============================================
-- TRUNCATE TABLES (preserve structure)
-- ============================================

TRUNCATE TABLE IF EXISTS RAW_DATA_TABLE;
TRUNCATE TABLE IF EXISTS file_processing_queue;
-- Don't truncate TPA_MASTER (preserve reference data)

-- ============================================
-- CLEAR STAGES (optional - uncomment to clear)
-- ============================================

-- REMOVE @SRC;
-- REMOVE @COMPLETED;
-- REMOVE @ERROR;
-- REMOVE @ARCHIVE;

-- ============================================
-- VERIFICATION
-- ============================================

-- Show remaining objects
SHOW TASKS IN SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);
SHOW PROCEDURES IN SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);
SHOW VIEWS IN SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);
SHOW TABLES IN SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);

-- Display success message
SELECT 'Bronze layer reset completed' AS status,
       'Tables truncated, tasks and procedures dropped' AS note,
       'Stages preserved (files not removed)' AS stage_note;
