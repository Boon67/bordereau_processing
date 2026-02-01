-- Check Bronze layer task status
-- Run this to see if tasks are suspended

SET ADMIN_ROLE_NAME = $DATABASE_NAME || '_ADMIN';

USE ROLE IDENTIFIER($ADMIN_ROLE_NAME);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE WAREHOUSE IDENTIFIER($WAREHOUSE_NAME);
USE SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);

-- Show all tasks and their status
SELECT 
    name AS task_name,
    state AS task_state,
    schedule,
    predecessor,
    warehouse,
    created_on,
    last_committed_on
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE database_name = $DATABASE_NAME
    AND schema_name = $BRONZE_SCHEMA_NAME
ORDER BY created_on DESC
LIMIT 20;

-- Show current task definitions
SHOW TASKS IN SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);

-- Check if tasks are started or suspended
SELECT 
    'Task Status Check' AS section,
    'If state = SUSPENDED, tasks need to be resumed' AS note;
