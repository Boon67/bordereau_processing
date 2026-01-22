# File Processing "SQL Execution Canceled" Fix

**Date**: January 21, 2026  
**Error**: 000604 (57014): SQL execution canceled  
**Status**: 🔍 Investigating

---

## Problem

When uploading files to the Bronze layer, they show as FAILED with the error:

```
000604 (57014): 01c1e383-0107-8721-0005-fa6b04a3b9c6: SQL execution canceled
```

**Example:**
- File: `src/provider_a/dental-claims-20240301.csv`
- Status: FAILED
- Error: SQL execution canceled

---

## Root Causes

This error typically occurs due to one or more of the following:

### 1. **Warehouse Not Set (Most Likely)**

The Bronze layer tasks may not have an active warehouse context, causing queries to be canceled.

**Related Fix:** [WAREHOUSE_FIX.md](WAREHOUSE_FIX.md)

### 2. **Tasks Not Running**

Bronze layer tasks (file discovery, processing) may be suspended.

### 3. **Query Timeout**

Long-running queries may exceed the default timeout.

### 4. **Warehouse Suspended**

The warehouse may have auto-suspended during processing.

---

## Diagnosis Steps

### Step 1: Check Task Status

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;

-- Check if tasks are running
SHOW TASKS;

-- Check task history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME LIKE '%discover%' OR NAME LIKE '%process%'
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;
```

**Expected:** Tasks should be in `started` state

### Step 2: Check Warehouse Assignment

```sql
-- Check if tasks have warehouse assigned
SHOW TASKS;
-- Look for WAREHOUSE column
```

**Expected:** Tasks should have `COMPUTE_WH` or another warehouse assigned

### Step 3: Check File Processing Queue

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;

SELECT 
    file_name,
    tpa,
    status,
    error_message,
    discovered_timestamp,
    processed_timestamp
FROM file_processing_queue
WHERE status = 'FAILED'
ORDER BY discovered_timestamp DESC
LIMIT 5;
```

### Step 4: Check Warehouse Status

```sql
SHOW WAREHOUSES LIKE 'COMPUTE_WH';
```

**Expected:** Warehouse should exist and be accessible

---

## Solutions

### Solution 1: Resume Tasks with Warehouse

```bash
cd /Users/tboon/code/bordereau

# Resume Bronze tasks
snow sql --connection DEPLOYMENT -q "
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;

-- Set warehouse for session
USE WAREHOUSE COMPUTE_WH;

-- Resume tasks
ALTER TASK IF EXISTS discover_files_task RESUME;
ALTER TASK IF EXISTS process_files_task RESUME;
ALTER TASK IF EXISTS move_completed_files_task RESUME;
ALTER TASK IF EXISTS archive_old_files_task RESUME;
"
```

### Solution 2: Manually Reprocess Failed Files

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;
USE WAREHOUSE COMPUTE_WH;

-- Reset failed file status
UPDATE file_processing_queue
SET status = 'PENDING',
    error_message = NULL,
    retry_count = 0
WHERE status = 'FAILED'
  AND file_name = 'src/provider_a/dental-claims-20240301.csv';
```

Then wait for the task to pick it up, or trigger manually:

```sql
-- Trigger file discovery task
EXECUTE TASK discover_files_task;
```

### Solution 3: Redeploy Bronze Layer with Warehouse Fix

If the issue persists, redeploy the Bronze layer with the warehouse fix:

```bash
cd /Users/tboon/code/bordereau/deployment

# Redeploy Bronze layer
./deploy_bronze.sh DEPLOYMENT
```

This will ensure all tasks and procedures have proper warehouse context.

---

## Prevention

### 1. Ensure Warehouse is Always Set

Update Bronze procedures to explicitly set warehouse:

```sql
CREATE OR REPLACE PROCEDURE process_file(...)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Explicitly set warehouse
    USE WAREHOUSE COMPUTE_WH;
    
    -- Rest of procedure logic
    ...
END;
$$;
```

### 2. Set Warehouse in Task Definitions

```sql
CREATE OR REPLACE TASK discover_files_task
    WAREHOUSE = COMPUTE_WH  -- Explicitly set warehouse
    SCHEDULE = '60 MINUTE'
AS
    CALL discover_files();
```

### 3. Monitor Task Execution

Set up monitoring for task failures:

```sql
-- Create alert for failed tasks
CREATE OR REPLACE ALERT bronze_task_failures
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '10 MINUTE'
    IF (EXISTS (
        SELECT 1
        FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
        WHERE STATE = 'FAILED'
          AND SCHEDULED_TIME > DATEADD(MINUTE, -10, CURRENT_TIMESTAMP())
    ))
THEN
    -- Send notification (configure as needed)
    CALL SYSTEM$SEND_EMAIL(...);
```

---

## Verification

After applying fixes, verify file processing works:

### 1. Upload Test File

```bash
cd /Users/tboon/code/bordereau

# Upload a small test file
snow stage put sample_data/claims_data/provider_a/dental-claims-20240301.csv \
    @BRONZE.SRC/provider_a/ \
    --connection DEPLOYMENT
```

### 2. Check Processing Status

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;

-- Wait a few minutes for task to run, then check
SELECT 
    file_name,
    status,
    error_message,
    discovered_timestamp,
    processed_timestamp
FROM file_processing_queue
WHERE file_name LIKE '%dental-claims-20240301%'
ORDER BY discovered_timestamp DESC;
```

**Expected:** Status should be `COMPLETED` or `PROCESSING`

### 3. Check Task History

```sql
SELECT 
    name,
    state,
    scheduled_time,
    completed_time,
    error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE name LIKE '%discover%' OR name LIKE '%process%'
ORDER BY scheduled_time DESC
LIMIT 10;
```

**Expected:** Tasks should show `SUCCEEDED` state

---

## Related Issues

- [WAREHOUSE_FIX.md](WAREHOUSE_FIX.md) - Warehouse context for SPCS OAuth
- [TROUBLESHOOTING_500_ERRORS.md](TROUBLESHOOTING_500_ERRORS.md) - Related warehouse issues
- [FILE_PROCESSING_FIX.md](FILE_PROCESSING_FIX.md) - File processing improvements

---

## Quick Fix Commands

```bash
cd /Users/tboon/code/bordereau

# 1. Check task status
snow sql --connection DEPLOYMENT -q "
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;
SHOW TASKS;
"

# 2. Resume all tasks
snow sql --connection DEPLOYMENT -q "
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;
USE WAREHOUSE COMPUTE_WH;
ALTER TASK IF EXISTS discover_files_task RESUME;
ALTER TASK IF EXISTS process_files_task RESUME;
ALTER TASK IF EXISTS move_completed_files_task RESUME;
ALTER TASK IF EXISTS archive_old_files_task RESUME;
"

# 3. Reset failed files
snow sql --connection DEPLOYMENT -q "
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;
UPDATE file_processing_queue
SET status = 'PENDING', error_message = NULL, retry_count = 0
WHERE status = 'FAILED';
"

# 4. Trigger discovery task
snow sql --connection DEPLOYMENT -q "
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;
EXECUTE TASK discover_files_task;
"
```

---

## Status

**Current Status:** 🔍 Investigating  
**Next Steps:**
1. Check if Bronze tasks are running
2. Verify warehouse assignment on tasks
3. Resume tasks if suspended
4. Reprocess failed files

**Last Updated:** January 21, 2026
