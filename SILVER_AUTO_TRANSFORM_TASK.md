# Silver Layer Auto-Transform Task

## Overview
The Silver layer includes an automated task that runs all approved field mappings on a scheduled basis, transforming Bronze data into structured Silver tables.

## Task Details

### `auto_transform_mappings_task`
- **Schedule**: Daily at 2 AM (configurable via CRON expression)
- **Default CRON**: `USING CRON 0 2 * * * America/New_York`
- **Purpose**: Automatically iterate through all approved mappings and run transformations for each TPA + target_table combination
- **Warehouse**: Uses the configured Snowflake warehouse

## How It Works

### 1. **Discovery Phase**
The task queries the `field_mappings` table to find all unique combinations of:
- `TPA` (Third Party Administrator)
- `target_table` (Target Silver table)

Where:
- `approved = TRUE`
- `active = TRUE`

### 2. **Transformation Phase**
For each TPA + target_table combination:
1. Calls `transform_bronze_to_silver()` procedure
2. Transforms up to 10,000 records per run (configurable)
3. Uses MERGE logic to prevent duplicates
4. Logs results to `silver_processing_log`

### 3. **Logging Phase**
- Records overall run statistics
- Tracks successful and failed transformations
- Stores detailed results for each combination

## Supporting Procedures

### `run_all_approved_mappings()`
Main procedure that executes all approved mappings.

**Returns**: Summary string with run statistics

**Example Output**:
```
Run ID: AUTO_TRANSFORM_20240131_020000_a1b2c3d4 | Total: 5 | Success: 5 | Failed: 0
```

### `run_transformations_manual(tpa_filter, table_filter)`
Manually trigger transformations with optional filters.

**Parameters**:
- `tpa_filter` (VARCHAR): Filter by TPA code, or 'ALL' for all TPAs
- `table_filter` (VARCHAR): Filter by table name, or 'ALL' for all tables

**Usage Examples**:
```sql
-- Run all transformations manually
CALL run_transformations_manual('ALL', 'ALL');

-- Run transformations for specific TPA
CALL run_transformations_manual('provider_a', 'ALL');

-- Run transformations for specific table across all TPAs
CALL run_transformations_manual('ALL', 'CLAIMS');

-- Run transformations for specific TPA and table
CALL run_transformations_manual('provider_a', 'CLAIMS');
```

### `get_auto_transform_status()`
View historical status of automated transformations.

**Returns**: Table with daily statistics for the last 30 days

**Usage**:
```sql
CALL get_auto_transform_status();
```

**Output Columns**:
- `run_date`: Date of the run
- `total_runs`: Number of runs on that date
- `successful_runs`: Number of successful runs
- `failed_runs`: Number of failed runs
- `last_run_time`: Timestamp of the last run

## Configuration

### Changing the Schedule

The default schedule runs daily at 2 AM. To change it:

1. **Via SQL**:
```sql
-- Suspend the task
ALTER TASK SILVER.auto_transform_mappings_task SUSPEND;

-- Update the schedule (example: every 12 hours)
ALTER TASK SILVER.auto_transform_mappings_task 
SET SCHEDULE = 'USING CRON 0 */12 * * * America/New_York';

-- Resume the task
ALTER TASK SILVER.auto_transform_mappings_task RESUME;
```

2. **Via UI**: Use the Task Management page in the Administration section

### Common Schedule Examples

```sql
-- Every hour
'USING CRON 0 * * * * America/New_York'

-- Every 6 hours
'USING CRON 0 */6 * * * America/New_York'

-- Every 12 hours
'USING CRON 0 */12 * * * America/New_York'

-- Daily at 2 AM (default)
'USING CRON 0 2 * * * America/New_York'

-- Daily at midnight
'USING CRON 0 0 * * * America/New_York'

-- Twice daily (6 AM and 6 PM)
'USING CRON 0 6,18 * * * America/New_York'

-- Simple interval syntax (every 24 hours)
'1440 MINUTE'
```

## Monitoring

### View Recent Transformation Logs

```sql
SELECT 
    batch_id,
    tpa,
    target_table,
    processing_type,
    status,
    records_processed,
    error_message,
    end_timestamp
FROM SILVER.silver_processing_log
WHERE processing_type = 'AUTO_TRANSFORMATION'
ORDER BY end_timestamp DESC
LIMIT 20;
```

### View Detailed Transformation Results

```sql
SELECT 
    batch_id,
    tpa,
    target_table,
    status,
    records_processed,
    records_success,
    records_failed,
    DATEDIFF(SECOND, start_timestamp, end_timestamp) as duration_seconds,
    error_message
FROM SILVER.silver_processing_log
WHERE processing_type = 'TRANSFORMATION'
  AND end_timestamp >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY end_timestamp DESC;
```

### Check Task Status

```sql
SHOW TASKS IN SCHEMA SILVER;
```

Look for `auto_transform_mappings_task` and check the `state` column:
- `started`: Task is running
- `suspended`: Task is paused

## Deployment

### Initial Deployment

The task is deployed as part of the Silver layer deployment:

```bash
# Deploy Silver layer (tasks created in SUSPENDED state)
./deployment/deploy_silver.sh

# Resume tasks
snow sql -f deployment/resume_silver_tasks.sql --connection default
```

### Resume Tasks After Deployment

```bash
# Option 1: Using deployment script with auto-resume
DEPLOY_RESUME_TASKS=true ./deployment/deploy_silver.sh

# Option 2: Manual resume
snow sql -f deployment/resume_silver_tasks.sql --connection default
```

### Suspend All Tasks

```sql
ALTER TASK SILVER.auto_transform_mappings_task SUSPEND;
```

## Workflow Integration

### Typical Data Flow

1. **Bronze Layer**: Files are uploaded and processed into `RAW_DATA_TABLE`
2. **Field Mappings**: Mappings are created (manually or via AI) and approved
3. **Silver Tables**: Target tables are created from schemas
4. **Auto-Transform**: Task runs daily, transforming all approved mappings
5. **Gold Layer**: Gold tasks consume Silver data for analytics

### Prerequisites

Before the auto-transform task can run successfully:

1. ✅ **Bronze data exists**: `RAW_DATA_TABLE` has records for the TPA
2. ✅ **Schemas defined**: Target table schemas exist in `target_schemas`
3. ✅ **Tables created**: Physical Silver tables created via `create_silver_table()`
4. ✅ **Mappings approved**: Field mappings exist with `approved = TRUE`

## Troubleshooting

### Task Not Running

**Check task state**:
```sql
SHOW TASKS IN SCHEMA SILVER;
```

**Resume if suspended**:
```sql
ALTER TASK SILVER.auto_transform_mappings_task RESUME;
```

### No Transformations Occurring

**Check for approved mappings**:
```sql
SELECT tpa, target_table, COUNT(*) as mapping_count
FROM SILVER.field_mappings
WHERE approved = TRUE AND active = TRUE
GROUP BY tpa, target_table;
```

If no results, you need to:
1. Create field mappings
2. Approve them

### Transformations Failing

**Check error logs**:
```sql
SELECT 
    batch_id,
    tpa,
    target_table,
    error_message,
    end_timestamp
FROM SILVER.silver_processing_log
WHERE status = 'FAILED'
  AND processing_type IN ('TRANSFORMATION', 'AUTO_TRANSFORMATION')
ORDER BY end_timestamp DESC
LIMIT 10;
```

**Common issues**:
- Target table doesn't exist → Run `create_silver_table()`
- No Bronze data → Check `RAW_DATA_TABLE` for TPA
- Invalid mappings → Review field mapping definitions

### Manual Trigger for Testing

```sql
-- Test with a specific TPA
CALL SILVER.run_transformations_manual('provider_a', 'ALL');

-- Test with a specific table
CALL SILVER.run_transformations_manual('ALL', 'CLAIMS');
```

## Performance Considerations

### Batch Size
Default: 10,000 records per transformation run

To modify, update the procedure call in the task definition:
```sql
CALL transform_bronze_to_silver(
    target_table,
    tpa,
    'RAW_DATA_TABLE',
    'BRONZE',
    50000,  -- Change batch size here
    TRUE,
    FALSE
)
```

### Warehouse Sizing
- **Small warehouse**: Suitable for < 100K records per run
- **Medium warehouse**: Suitable for 100K - 1M records per run
- **Large warehouse**: Suitable for > 1M records per run

Configure warehouse in deployment:
```bash
DEPLOY_WAREHOUSE=LARGE_WH ./deployment/deploy_silver.sh
```

## Best Practices

1. **Start Small**: Begin with a conservative schedule (daily) and adjust based on data volume
2. **Monitor First Runs**: Watch the first few automated runs to ensure they complete successfully
3. **Review Logs Regularly**: Check `silver_processing_log` for failures
4. **Test Manually**: Use `run_transformations_manual()` to test before relying on automation
5. **Approve Carefully**: Only approve mappings that have been validated
6. **Use Appropriate Warehouse**: Size warehouse based on data volume

## Related Documentation

- `MERGE_TRANSFORMATION_UPDATE.md` - Details on MERGE logic to prevent duplicates
- `SILVER_METADATA_COLUMNS.md` - Metadata columns added to Silver tables
- `silver/6_Silver_Tasks.sql` - Task definition and procedures
- `deployment/resume_silver_tasks.sql` - Task resume script
