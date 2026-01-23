-- Resume all Bronze layer tasks
-- Run this if tasks are suspended and not processing files

USE ROLE IDENTIFIER($DATABASE_NAME || '_ADMIN');
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);
USE SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);

-- Resume root task first (discover_files_task)
ALTER TASK discover_files_task RESUME;

-- Resume dependent tasks
ALTER TASK process_files_task RESUME;
ALTER TASK move_successful_files_task RESUME;
ALTER TASK move_failed_files_task RESUME;
ALTER TASK archive_old_files_task RESUME;

-- Verify tasks are now started
SHOW TASKS IN SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);

SELECT 'All Bronze layer tasks have been resumed!' AS status;
