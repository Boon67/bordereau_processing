-- ============================================
-- FIX TASK EXECUTION PRIVILEGES
-- ============================================
-- Purpose: Grant EXECUTE TASK privilege to roles
-- 
-- IMPORTANT: This script must be run by ACCOUNTADMIN
-- 
-- Task execution requires special privileges that can only be
-- granted by ACCOUNTADMIN. This script sets up the delegation
-- chain so that SYSADMIN can manage tasks.
--
-- Privilege Delegation Chain:
--   ACCOUNTADMIN (one-time grant)
--       ↓ WITH GRANT OPTION
--   SYSADMIN (can delegate to other roles)
--       ↓
--   <DATABASE>_ADMIN (project role)
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';

-- ============================================
-- GRANT EXECUTE TASK PRIVILEGE
-- ============================================

-- Step 1: ACCOUNTADMIN grants to SYSADMIN with grant option
USE ROLE ACCOUNTADMIN;

GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN WITH GRANT OPTION;

-- Step 2: SYSADMIN grants to project admin role
USE ROLE SYSADMIN;

GRANT EXECUTE TASK ON ACCOUNT TO ROLE IDENTIFIER($DATABASE_NAME || '_ADMIN');

-- ============================================
-- VERIFICATION
-- ============================================

-- Show grants to project admin role
SHOW GRANTS TO ROLE IDENTIFIER($DATABASE_NAME || '_ADMIN');

-- Display success message
SELECT 'Task execution privileges granted successfully' AS status,
       'Tasks can now be resumed by ' || $DATABASE_NAME || '_ADMIN role' AS note;

-- ============================================
-- USAGE INSTRUCTIONS
-- ============================================

/*
To resume Bronze tasks after granting privileges:

USE ROLE IDENTIFIER($DATABASE_NAME || '_ADMIN');
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA BRONZE;

ALTER TASK discover_files_task RESUME;
ALTER TASK process_files_task RESUME;
ALTER TASK move_successful_files_task RESUME;
ALTER TASK move_failed_files_task RESUME;
ALTER TASK archive_old_files_task RESUME;

-- Verify tasks are running
SHOW TASKS;
*/
