# Deployment and Operations Guide

**Complete guide for deploying and operating the Snowflake File Processing Pipeline.**

## Deployment

### Prerequisites

- Snowflake account with `SYSADMIN` or `ACCOUNTADMIN` privileges
- Snowflake CLI (`snow`) or SnowSQL installed
- Bash shell (macOS/Linux native, Windows Git Bash)
- Git installed

### Configuration

1. **Copy configuration template:**
   ```bash
   cp custom.config.example custom.config
   ```

2. **Edit `custom.config`:**
   ```bash
   SNOWFLAKE_ACCOUNT="abc12345.us-east-1"
   SNOWFLAKE_USER="your_username"
   SNOWFLAKE_PASSWORD="your_password"
   SNOWFLAKE_ROLE="SYSADMIN"
   SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
   
   DATABASE_NAME="FILE_PROCESSING_PIPELINE"
   BRONZE_SCHEMA_NAME="BRONZE"
   SILVER_SCHEMA_NAME="SILVER"
   ```

### Deployment Steps

1. **Deploy entire pipeline:**
   ```bash
./deploy.sh
   ```

2. **Or deploy layers individually:**
   ```bash
   # Bronze only
./deploy_bronze.sh
   
   # Silver only
./deploy_silver.sh
   ```

3. **Grant task execution privileges (requires ACCOUNTADMIN):**
   ```bash
   snowsql -f bronze/Fix_Task_Privileges.sql
   ```

4. **Verify deployment:**
   ```sql
   -- Check database and schemas
   SHOW DATABASES LIKE 'FILE_PROCESSING_PIPELINE';
   SHOW SCHEMAS IN DATABASE FILE_PROCESSING_PIPELINE;
   
   -- Check roles
   SHOW ROLES LIKE 'FILE_PROCESSING_PIPELINE%';
   
   -- Check tables
   SHOW TABLES IN SCHEMA BRONZE;
   SHOW TABLES IN SCHEMA SILVER;
   
   -- Check tasks
   SHOW TASKS IN SCHEMA BRONZE;
   ```

## Operations

### Starting the Pipeline

```sql
-- Resume Bronze tasks
USE ROLE FILE_PROCESSING_PIPELINE_ADMIN;
USE DATABASE FILE_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;

ALTER TASK discover_files_task RESUME;
ALTER TASK process_files_task RESUME;
ALTER TASK move_successful_files_task RESUME;
ALTER TASK move_failed_files_task RESUME;
ALTER TASK archive_old_files_task RESUME;
```

### Stopping the Pipeline

```sql
-- Suspend Bronze tasks
ALTER TASK discover_files_task SUSPEND;
-- Child tasks will automatically stop
```

### Monitoring

**Key Metrics:**
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

-- View processing status
SELECT * FROM v_processing_status_summary;
```

## Troubleshooting

### Issue: Tasks not running

**Symptoms:**
- Tasks show as RESUMED but not executing
- No task history

**Solutions:**
1. Check task privileges:
   ```sql
   SHOW GRANTS TO ROLE FILE_PROCESSING_PIPELINE_ADMIN;
   ```

2. Grant EXECUTE TASK privilege:
   ```bash
   snowsql -f bronze/Fix_Task_Privileges.sql
   ```

3. Check task dependencies:
   ```sql
   SHOW TASKS;
   ```

### Issue: File upload fails

**Symptoms:**
- Error uploading files via React UI
- Permission denied errors

**Solutions:**
1. Check stage permissions:
   ```sql
   SHOW GRANTS ON STAGE SRC;
   ```

2. Grant permissions:
   ```sql
   GRANT ALL ON STAGE SRC TO ROLE FILE_PROCESSING_PIPELINE_READWRITE;
   ```

### Issue: File processing fails

**Symptoms:**
- Files stuck in PENDING status
- Files marked as FAILED

**Solutions:**
1. Check error messages:
   ```sql
   SELECT * FROM v_failed_files;
   ```

2. Common errors and fixes:
   - **Invalid TPA**: Register TPA in `TPA_MASTER`
   - **Parsing error**: Check file format (encoding, delimiters)
   - **Permission denied**: Check role permissions

3. Reprocess failed file:
   ```sql
   UPDATE file_processing_queue
   SET status = 'PENDING', retry_count = 0, error_message = NULL
   WHERE file_name = 'problem-file.csv';
   
   CALL process_queued_files();
   ```

## Maintenance

### Regular Tasks

**Daily:**
- Monitor processing status
- Check for failed files
- Review error logs

**Weekly:**
- Review data quality metrics
- Check storage usage
- Archive old files

**Monthly:**
- Review and optimize queries
- Update transformation rules
- Clean up quarantine records

### Backup and Recovery

**Backup:**
```sql
-- Export metadata
CREATE TABLE metadata_backup AS
SELECT * FROM target_schemas;

-- Export mappings
CREATE TABLE mappings_backup AS
SELECT * FROM field_mappings;
```

**Recovery:**
```sql
-- Restore metadata
INSERT INTO target_schemas
SELECT * FROM metadata_backup;
```

## Performance Optimization

### Warehouse Sizing

- **Development**: X-Small
- **Production (< 1M records/day)**: Small
- **Production (1M-10M records/day)**: Medium
- **Production (> 10M records/day)**: Large

### Clustering

```sql
-- Check clustering
SELECT SYSTEM$CLUSTERING_INFORMATION('RAW_DATA_TABLE', '(TPA, FILE_NAME)');

-- Reclustering (if needed)
ALTER TABLE RAW_DATA_TABLE RECLUSTER;
```

### Query Optimization

```sql
-- Add indexes
CREATE INDEX idx_queue_status ON file_processing_queue(status, tpa);

-- Analyze query performance
SELECT * FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE QUERY_TEXT LIKE '%RAW_DATA_TABLE%'
ORDER BY START_TIME DESC
LIMIT 10;
```

## Logging

### Log Files

Deployment logs are stored in `logs/` directory:
```
logs/
├── deployment_20260115_143022.log
├── bronze_deployment_20260115_143025.log
└── silver_deployment_20260115_143045.log
```

### Viewing Logs

```bash
# View latest deployment log
tail -f logs/deployment_*.log | tail -1

# Search for errors
grep ERROR logs/*.log
```

## Undeployment

**WARNING: This will delete all data!**

```bash
./undeploy.sh
```

You will be prompted to:
1. Confirm with "yes"
2. Type the database name to confirm

---

**Version**: 1.0  
**Last Updated**: January 15, 2026
