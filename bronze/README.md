# Bronze Layer - Raw Data Ingestion

**Automated file discovery, processing, and archival with complete TPA isolation.**

## Overview

The Bronze layer is responsible for:
- Discovering CSV and Excel files from Snowflake stages
- Parsing and loading raw data into `RAW_DATA_TABLE`
- Tracking processing status in `file_processing_queue`
- Moving files between stages based on processing results
- Archiving old files for long-term storage

## Architecture

### Stages (5)

| Stage | Purpose | Retention |
|-------|---------|-----------|
| `@SRC` | Landing zone for incoming files | Until processed |
| `@COMPLETED` | Successfully processed files | 30 days |
| `@ERROR` | Failed files | 30 days |
| `@ARCHIVE` | Long-term archive | Indefinite |

### Tables (3)

1. **`TPA_MASTER`** - Master reference table for valid TPAs
   - Primary key: `TPA_CODE`
   - Tracks active/inactive TPAs
   - All TPAs must be registered before processing

2. **`RAW_DATA_TABLE`** - Stores ingested data as VARIANT (JSON)
   - Primary key: `RECORD_ID` (autoincrement)
   - Unique constraint: `(FILE_NAME, FILE_ROW_NUMBER)`
   - Clustered by: `(TPA, FILE_NAME)` for performance
   - Each row = one record from source file

3. **`file_processing_queue`** - Tracks file processing status
   - Primary key: `queue_id` (autoincrement)
   - Unique constraint: `file_name`
   - Status values: `PENDING`, `PROCESSING`, `SUCCESS`, `FAILED`
   - Tracks retry count and error messages

### Stored Procedures (7)

| Procedure | Purpose | Language |
|-----------|---------|----------|
| `process_single_csv_file(file_path, tpa)` | Parse CSV files with pandas | Python |
| `process_single_excel_file(file_path, tpa)` | Parse Excel files with openpyxl | Python |
| `discover_files()` | Scan @SRC stage, extract TPA, add to queue | SQL |
| `process_queued_files()` | Process PENDING files (batch of 10) | Python |
| `move_processed_files()` | Move SUCCESS files to @COMPLETED | SQL |
| `move_failed_files()` | Move FAILED files to @ERROR | SQL |
| `archive_old_files()` | Move files older than 30 days to @ARCHIVE | SQL |

### Task Pipeline (5 tasks)

```
discover_files_task (Every 60 minutes - configurable)
    ↓
process_files_task (After discovery)
    ↓
    ├─→ move_successful_files_task (Parallel)
    └─→ move_failed_files_task (Parallel)
    
archive_old_files_task (Daily at 2 AM - independent)
```

## TPA Architecture

### File Organization

Files must be organized by TPA in the `@SRC` stage:

```mermaid
graph TD
    SRC[@SRC/] --> PA[provider_a/]
    PA --> PA1[claims-20240301.csv]
    PA --> PA2[members-20240301.csv]
    
    SRC --> PB[provider_b/]
    PB --> PB1[claims-20240115.csv]
    PB --> PB2[eligibility-20240115.xlsx]
    
    SRC --> PC[provider_c/]
    PC --> PC1[claims-20240215.xlsx]
    
    style SRC fill:#cd7f32,stroke:#333,stroke-width:3px,color:#fff
    style PA fill:#4caf50,stroke:#333,stroke-width:2px,color:#fff
    style PB fill:#2196f3,stroke:#333,stroke-width:2px,color:#fff
    style PC fill:#ff9800,stroke:#333,stroke-width:2px,color:#fff
```

### TPA Extraction

The `discover_files()` procedure automatically extracts TPA from the file path:

- `@SRC/provider_a/claims.csv` → TPA = `provider_a`
- `@SRC/provider_b/data.xlsx` → TPA = `provider_b`

### TPA Validation

All TPAs must be registered in `TPA_MASTER` before processing:

```sql
-- Add new TPA
CALL add_tpa('provider_f', 'Provider F Healthcare', 'Vision claims');

-- View all TPAs
SELECT * FROM TPA_MASTER;
```

## Deployment

### Prerequisites

- Snowflake account with `SYSADMIN` or higher privileges
- Snowflake CLI (`snow`) installed
- Bash shell (macOS/Linux native, Windows Git Bash)

### Deploy Bronze Layer

```bash
# Deploy Bronze layer only
./deploy_bronze.sh

# Or deploy entire pipeline (Bronze + Silver)
./deploy.sh
```

### Deployment Steps

1. **Database and RBAC Setup** (`1_Setup_Database_Roles.sql`)
   - Creates database and schemas
   - Sets up three-tier role hierarchy
   - Grants permissions

2. **Schema and Tables** (`2_Bronze_Schema_Tables.sql`)
   - Creates stages
   - Creates tables
   - Creates views
   - Inserts default TPAs

3. **Stored Procedures** (`3_Bronze_Setup_Logic.sql`)
   - Creates file processing procedures
   - Python procedures for CSV/Excel parsing
   - SQL procedures for file management

4. **Tasks** (`4_Bronze_Tasks.sql`)
   - Creates task pipeline
   - Sets up dependencies
   - Configures schedules

5. **Task Privileges** (`Fix_Task_Privileges.sql`)
   - Grants EXECUTE TASK privilege (requires ACCOUNTADMIN)

## Usage

### Upload Files

**Option 1: Via React UI**
1. Open Bronze Ingestion Pipeline app
2. Select TPA from dropdown
3. Drag and drop files
4. Click Upload

**Option 2: Via SnowSQL/CLI**
```sql
-- Upload file to @SRC stage
PUT file:///path/to/claims.csv @SRC/provider_a/ AUTO_COMPRESS=FALSE;
```

### Monitor Processing

```sql
-- View processing status
SELECT * FROM v_processing_status_summary;

-- View recent activity
SELECT * FROM v_recent_processing_activity;

-- View failed files
SELECT * FROM v_failed_files;

-- View raw data statistics
SELECT * FROM v_raw_data_statistics;
```

### Manual Processing

```sql
-- Manually trigger file discovery
EXECUTE TASK discover_files_task;

-- Manually process queued files
CALL process_queued_files();

-- View queue
SELECT * FROM file_processing_queue ORDER BY discovered_timestamp DESC;
```

### Task Management

```sql
-- Resume tasks (start processing)
ALTER TASK discover_files_task RESUME;
ALTER TASK process_files_task RESUME;
ALTER TASK move_successful_files_task RESUME;
ALTER TASK move_failed_files_task RESUME;
ALTER TASK archive_old_files_task RESUME;

-- Suspend tasks (stop processing)
ALTER TASK discover_files_task SUSPEND;

-- View task status
SHOW TASKS;

-- View task history
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE DATABASE_NAME = 'FILE_PROCESSING_PIPELINE'
  AND SCHEMA_NAME = 'BRONZE'
ORDER BY SCHEDULED_TIME DESC
LIMIT 100;
```

## File Processing Flow

1. **Discovery**
   - `discover_files_task` runs every 60 minutes (configurable)
   - Lists files in `@SRC` stage
   - Extracts TPA from path
   - Adds new files to `file_processing_queue` with status `PENDING`

2. **Processing**
   - `process_files_task` runs after discovery
   - Processes up to 10 `PENDING` files per batch
   - Updates status to `PROCESSING`
   - Calls appropriate parser (CSV or Excel)
   - Inserts data into `RAW_DATA_TABLE` using MERGE (deduplication)
   - Updates status to `SUCCESS` or `FAILED`

3. **File Movement**
   - `move_successful_files_task` moves `SUCCESS` files to `@COMPLETED`
   - `move_failed_files_task` moves `FAILED` files (after 3 retries) to `@ERROR`
   - Both tasks run in parallel after processing

4. **Archival**
   - `archive_old_files_task` runs daily at 2 AM
   - Moves files older than 30 days from `@COMPLETED` and `@ERROR` to `@ARCHIVE`

## Error Handling

### Failed Files

Files fail processing for various reasons:
- Corrupt file format
- Invalid TPA (not in `TPA_MASTER`)
- Parsing errors
- Network issues

Failed files are:
1. Marked as `FAILED` in queue
2. Retried up to 3 times
3. Moved to `@ERROR` stage after max retries
4. Error message stored in `file_processing_queue.error_message`

### Troubleshooting

```sql
-- View failed files with errors
SELECT 
    file_name,
    tpa,
    error_message,
    retry_count,
    processed_timestamp
FROM file_processing_queue
WHERE status = 'FAILED'
ORDER BY processed_timestamp DESC;

-- Reprocess a failed file (after fixing issue)
UPDATE file_processing_queue
SET status = 'PENDING',
    retry_count = 0,
    error_message = NULL
WHERE file_name = 'problem-file.csv';

-- Then manually trigger processing
CALL process_queued_files();
```

## TPA Management

### Add New TPA

```sql
-- Add new TPA
CALL add_tpa('provider_f', 'Provider F Healthcare', 'Vision claims provider');

-- Verify
SELECT * FROM TPA_MASTER WHERE TPA_CODE = 'provider_f';
```

### Deactivate TPA

```sql
-- Deactivate TPA (stops processing new files)
CALL deactivate_tpa('provider_f');

-- Reactivate TPA
CALL reactivate_tpa('provider_f');
```

### View TPA Statistics

```sql
-- View comprehensive TPA statistics
SELECT * FROM v_tpa_statistics;
```

## Performance Optimization

### Clustering

`RAW_DATA_TABLE` is clustered by `(TPA, FILE_NAME)` for optimal query performance:

```sql
-- Check clustering information
SELECT SYSTEM$CLUSTERING_INFORMATION('RAW_DATA_TABLE', '(TPA, FILE_NAME)');
```

### Batch Size

Processing batch size is configurable (default: 10 files per batch):

```python
# In process_queued_files() procedure
LIMIT 10  # Adjust as needed
```

### Warehouse Sizing

Recommended warehouse sizes:
- **Development**: X-Small
- **Production**: Small to Medium (depending on file volume)

## Security

### RBAC Roles

- **`<DATABASE>_ADMIN`**: Full access (create, alter, drop)
- **`<DATABASE>_READWRITE`**: Execute procedures, operate tasks, read/write data
- **`<DATABASE>_READONLY`**: Read-only access

### Stage Permissions

All stages use Snowflake-managed encryption (SSE) by default.

## Monitoring

### Key Metrics

```sql
-- Files processed today
SELECT COUNT(*) 
FROM file_processing_queue
WHERE DATE(processed_timestamp) = CURRENT_DATE()
  AND status = 'SUCCESS';

-- Processing success rate
SELECT 
    status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM file_processing_queue
WHERE processed_timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY status;

-- Average processing time
SELECT 
    AVG(DATEDIFF('second', discovered_timestamp, processed_timestamp)) as avg_seconds
FROM file_processing_queue
WHERE status = 'SUCCESS'
  AND processed_timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP());
```

## Cleanup

### Reset Bronze Layer

```bash
# WARNING: This deletes all data!
snowsql -f bronze/Reset.sql
```

### Remove Files from Stages

```sql
-- Remove all files from @SRC (use with caution!)
REMOVE @SRC;

-- Remove specific TPA files
REMOVE @SRC/provider_a/;
```

## Related Documentation

- [TPA Upload Guide](TPA_UPLOAD_GUIDE.md) - Detailed file upload instructions
- [User Guide](../docs/USER_GUIDE.md) - Complete usage guide
- [Documentation Hub](../docs/README.md) - Complete documentation

## Support

For issues or questions:
1. Check [Deployment & Operations](../docs/DEPLOYMENT_AND_OPERATIONS.md) for troubleshooting
2. Review task history and error messages
3. Examine logs in `logs/` directory

---

**Version**: 1.0  
**Last Updated**: January 15, 2026  
**Status**: ✅ Production Ready
