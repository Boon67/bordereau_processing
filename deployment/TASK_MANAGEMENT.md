# Task Management Guide

## Overview

The Bordereau Processing Pipeline uses Snowflake Tasks to automate file processing and data transformations. This guide explains how tasks are managed during deployment and how to control them manually.

## Automatic Task Resumption

By default, tasks are **automatically resumed** after deployment. This behavior is controlled by the `AUTO_RESUME_TASKS` configuration variable.

### Configuration

In `deployment/default.config`:

```bash
AUTO_RESUME_TASKS="true"    # Automatically resume tasks after deployment
```

Set to `"false"` to disable automatic task resumption.

## Bronze Layer Tasks

The Bronze layer includes 5 tasks for automated file processing:

### Task Hierarchy

```
discover_files_task (root, runs every 60 minutes)
    ↓
process_files_task (runs after discovery)
    ↓
    ├─→ move_successful_files_task (parallel)
    └─→ move_failed_files_task (parallel)

archive_old_files_task (independent, runs daily at 2 AM)
```

### Task Functions

1. **discover_files_task** - Scans `@SRC` stage for new files every 60 minutes
2. **process_files_task** - Processes pending files from the queue (batch of 10)
3. **move_successful_files_task** - Moves successfully processed files to `@COMPLETED`
4. **move_failed_files_task** - Moves failed files to `@ERROR` (after 3 retries)
5. **archive_old_files_task** - Archives files older than 30 days

## Manual Task Management

### Resume All Bronze Tasks

```bash
snow sql -f deployment/resume_tasks.sql --connection <CONNECTION_NAME>
```

Or manually in SQL:

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;

-- Resume child tasks first
ALTER TASK move_successful_files_task RESUME;
ALTER TASK move_failed_files_task RESUME;
ALTER TASK process_files_task RESUME;
ALTER TASK archive_old_files_task RESUME;

-- Resume root task last
ALTER TASK discover_files_task RESUME;
```

### Suspend All Bronze Tasks

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;

-- Suspend in reverse order (root first, then children)
ALTER TASK discover_files_task SUSPEND;
ALTER TASK process_files_task SUSPEND;
ALTER TASK move_successful_files_task SUSPEND;
ALTER TASK move_failed_files_task SUSPEND;
ALTER TASK archive_old_files_task SUSPEND;
```

### Check Task Status

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;

SHOW TASKS;
```

Or with JSON output:

```bash
snow sql --connection <CONNECTION_NAME> --format json -q "USE DATABASE BORDEREAU_PROCESSING_PIPELINE; USE SCHEMA BRONZE; SHOW TASKS;"
```

### Manually Trigger File Processing

If you want to process files immediately without waiting for the scheduled task:

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;

-- Process pending files
CALL process_queued_files();

-- Move processed files
CALL move_processed_files();
```

## Gold Layer Tasks

The Gold layer includes tasks for refreshing analytical tables (when deployed):

1. **task_refresh_claims_analytics** - Daily at 2 AM
2. **task_refresh_member_360** - Daily at 3 AM
3. **task_refresh_provider_performance** - Weekly
4. **task_refresh_financial_summary** - Monthly
5. **task_run_quality_checks** - After transformations

### Resume Gold Tasks

```bash
snow sql -f deployment/resume_gold_tasks.sql --connection <CONNECTION_NAME>
```

## Important Notes

### Task Resumption Order

⚠️ **CRITICAL**: When resuming tasks with dependencies, you MUST resume them in the correct order:

1. **Resume child tasks first** (bottom-up)
2. **Resume root task last**

This is because Snowflake requires all child tasks to be in a consistent state before resuming the root task.

### Why Tasks Are Suspended by Default

Snowflake creates all tasks in a SUSPENDED state by default. This is a safety feature to prevent:
- Accidental execution before configuration is complete
- Unexpected costs from running tasks
- Processing before data is ready

### Task Execution Privileges

The deployment script automatically grants `EXECUTE TASK` privilege to the `SYSADMIN` role. If you encounter permission errors, ensure this privilege is granted:

```sql
USE ROLE ACCOUNTADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN WITH GRANT OPTION;
```

## Troubleshooting

### Tasks Not Processing Files

1. **Check if tasks are resumed**:
   ```sql
   SHOW TASKS IN SCHEMA BRONZE;
   ```
   Look for `state = 'started'`

2. **Check task history**:
   ```sql
   SELECT * 
   FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
   WHERE SCHEMA_NAME = 'BRONZE'
   ORDER BY SCHEDULED_TIME DESC
   LIMIT 10;
   ```

3. **Manually trigger processing**:
   ```sql
   CALL BRONZE.process_queued_files();
   ```

### Files Stuck in PENDING Status

This usually means tasks are suspended. Resume them using:
```bash
snow sql -f deployment/resume_tasks.sql --connection <CONNECTION_NAME>
```

Then manually process pending files:
```sql
CALL BRONZE.process_queued_files();
```

### Task Dependency Errors

If you get errors like "Unable to update graph with root task", it means you tried to resume child tasks while the root task was already running. Solution:

1. Suspend the root task first
2. Resume all child tasks
3. Resume the root task last

## Monitoring

### View Processing Queue

```sql
SELECT queue_id, file_name, tpa, status, discovered_timestamp, processed_timestamp
FROM BRONZE.file_processing_queue
ORDER BY discovered_timestamp DESC;
```

### View Task Execution History

```sql
SELECT name, state, scheduled_time, completed_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE SCHEMA_NAME = 'BRONZE'
  AND SCHEDULED_TIME > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY SCHEDULED_TIME DESC;
```

### View File Processing Logs

```sql
SELECT *
FROM BRONZE.FILE_PROCESSING_LOGS
WHERE file_name = 'your-file-name.csv'
ORDER BY stage_start DESC;
```

## Best Practices

1. **Always use the resume scripts** - They handle the correct task order automatically
2. **Monitor task execution** - Check task history regularly for errors
3. **Test with manual triggers** - Use `CALL process_queued_files()` to test before relying on scheduled tasks
4. **Configure appropriate schedules** - Adjust `BRONZE_DISCOVERY_SCHEDULE` based on your file upload frequency
5. **Keep AUTO_RESUME_TASKS enabled** - Unless you have a specific reason to disable it

## Related Files

- `deployment/resume_tasks.sql` - Resume Bronze layer tasks
- `deployment/resume_gold_tasks.sql` - Resume Gold layer tasks
- `deployment/default.config` - Configuration including `AUTO_RESUME_TASKS`
- `bronze/4_Bronze_Tasks.sql` - Bronze task definitions
- `gold/5_Gold_Tasks.sql` - Gold task definitions
