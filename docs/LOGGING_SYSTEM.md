# Logging System Documentation

## Overview

The Bordereau Processing Pipeline includes a comprehensive logging system that captures all operations across the application using Snowflake hybrid tables for fast transactional access and querying.

## Architecture

### Log Tables (Hybrid Tables)

All log tables are created as hybrid tables for optimal performance:

1. **APPLICATION_LOGS** - General application events
2. **TASK_EXECUTION_LOGS** - Snowflake task execution tracking
3. **FILE_PROCESSING_LOGS** - Detailed file processing pipeline stages
4. **API_REQUEST_LOGS** - API endpoint request/response logging
5. **ERROR_LOGS** - Detailed error tracking and resolution management

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                     Frontend (React)                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │          Admin > System Logs Page                     │   │
│  │  - Application Logs  - Task Executions               │   │
│  │  - File Processing   - Errors                        │   │
│  │  - API Requests                                      │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Backend (FastAPI)                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Logging Middleware (Automatic API Logging)          │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Logging Utilities (SnowflakeLogger)                 │   │
│  │  - log_application_event()                           │   │
│  │  - log_api_request()                                 │   │
│  │  - log_error()                                       │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Logs API Endpoints (/api/logs/*)                    │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  Snowflake (Hybrid Tables)                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  APPLICATION_LOGS                                    │   │
│  │  TASK_EXECUTION_LOGS                                 │   │
│  │  FILE_PROCESSING_LOGS                                │   │
│  │  API_REQUEST_LOGS                                    │   │
│  │  ERROR_LOGS                                          │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Stored Procedures (Logging from SQL)               │   │
│  │  - log_application_event()                           │   │
│  │  - log_task_start() / log_task_end()                │   │
│  │  - log_file_processing_stage()                       │   │
│  │  - log_error()                                       │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Tasks (Automatic Logging Wrappers)                  │   │
│  │  - discover_files_task                               │   │
│  │  - process_files_task                                │   │
│  │  - move_successful_files_task                        │   │
│  │  - move_failed_files_task                            │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Log Tables Schema

### 1. APPLICATION_LOGS

General application logging for all components.

```sql
CREATE TABLE APPLICATION_LOGS (
    LOG_ID INTEGER AUTOINCREMENT PRIMARY KEY,
    LOG_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    LOG_LEVEL VARCHAR(20) NOT NULL,  -- DEBUG, INFO, WARNING, ERROR, CRITICAL
    LOG_SOURCE VARCHAR(100) NOT NULL,
    LOG_MESSAGE TEXT NOT NULL,
    LOG_DETAILS VARIANT,
    USER_NAME VARCHAR(100),
    SESSION_ID VARCHAR(100),
    TPA_CODE VARCHAR(50),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    INDEX idx_timestamp (LOG_TIMESTAMP),
    INDEX idx_level (LOG_LEVEL),
    INDEX idx_source (LOG_SOURCE)
);
```

### 2. TASK_EXECUTION_LOGS

Tracks all Snowflake task executions.

```sql
CREATE TABLE TASK_EXECUTION_LOGS (
    EXECUTION_ID INTEGER AUTOINCREMENT PRIMARY KEY,
    TASK_NAME VARCHAR(200) NOT NULL,
    EXECUTION_START TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    EXECUTION_END TIMESTAMP_NTZ,
    EXECUTION_STATUS VARCHAR(50),  -- STARTED, RUNNING, SUCCESS, FAILED, SKIPPED
    EXECUTION_DURATION_MS INTEGER,
    RECORDS_PROCESSED INTEGER DEFAULT 0,
    RECORDS_FAILED INTEGER DEFAULT 0,
    ERROR_MESSAGE TEXT,
    EXECUTION_DETAILS VARIANT,
    WAREHOUSE_USED VARCHAR(100),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    INDEX idx_task_name (TASK_NAME),
    INDEX idx_execution_start (EXECUTION_START),
    INDEX idx_status (EXECUTION_STATUS)
);
```

### 3. FILE_PROCESSING_LOGS

Detailed logging for each file processing stage.

```sql
CREATE TABLE FILE_PROCESSING_LOGS (
    PROCESSING_LOG_ID INTEGER AUTOINCREMENT PRIMARY KEY,
    QUEUE_ID INTEGER,
    FILE_NAME VARCHAR(500) NOT NULL,
    TPA_CODE VARCHAR(50),
    PROCESSING_STAGE VARCHAR(50) NOT NULL,  -- READING, PARSING, VALIDATION, PREPARATION, LOADING, MOVING
    STAGE_STATUS VARCHAR(50) NOT NULL,  -- STARTED, SUCCESS, FAILED, SKIPPED
    STAGE_START TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    STAGE_END TIMESTAMP_NTZ,
    STAGE_DURATION_MS INTEGER,
    ROWS_PROCESSED INTEGER DEFAULT 0,
    ROWS_FAILED INTEGER DEFAULT 0,
    ERROR_MESSAGE TEXT,
    STAGE_DETAILS VARIANT,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    INDEX idx_queue_id (QUEUE_ID),
    INDEX idx_file_name (FILE_NAME),
    INDEX idx_stage (PROCESSING_STAGE),
    INDEX idx_status (STAGE_STATUS)
);
```

### 4. API_REQUEST_LOGS

Logs all API requests and responses.

```sql
CREATE TABLE API_REQUEST_LOGS (
    REQUEST_ID INTEGER AUTOINCREMENT PRIMARY KEY,
    REQUEST_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    REQUEST_METHOD VARCHAR(10) NOT NULL,
    REQUEST_PATH VARCHAR(500) NOT NULL,
    REQUEST_PARAMS VARIANT,
    REQUEST_BODY VARIANT,
    RESPONSE_STATUS INTEGER,
    RESPONSE_TIME_MS INTEGER,
    RESPONSE_BODY VARIANT,
    ERROR_MESSAGE TEXT,
    USER_NAME VARCHAR(100),
    CLIENT_IP VARCHAR(50),
    USER_AGENT VARCHAR(500),
    TPA_CODE VARCHAR(50),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    INDEX idx_timestamp (REQUEST_TIMESTAMP),
    INDEX idx_path (REQUEST_PATH),
    INDEX idx_status (RESPONSE_STATUS)
);
```

### 5. ERROR_LOGS

Detailed error tracking with resolution management.

```sql
CREATE TABLE ERROR_LOGS (
    ERROR_ID INTEGER AUTOINCREMENT PRIMARY KEY,
    ERROR_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    ERROR_LEVEL VARCHAR(20) NOT NULL,
    ERROR_SOURCE VARCHAR(100) NOT NULL,
    ERROR_TYPE VARCHAR(100),
    ERROR_MESSAGE TEXT NOT NULL,
    ERROR_STACK_TRACE TEXT,
    ERROR_CONTEXT VARIANT,
    USER_NAME VARCHAR(100),
    SESSION_ID VARCHAR(100),
    TPA_CODE VARCHAR(50),
    RESOLUTION_STATUS VARCHAR(50) DEFAULT 'UNRESOLVED',  -- UNRESOLVED, INVESTIGATING, RESOLVED
    RESOLUTION_NOTES TEXT,
    RESOLVED_BY VARCHAR(100),
    RESOLVED_AT TIMESTAMP_NTZ,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    INDEX idx_timestamp (ERROR_TIMESTAMP),
    INDEX idx_source (ERROR_SOURCE),
    INDEX idx_resolution (RESOLUTION_STATUS)
);
```

## Usage

### Backend (Python)

```python
from app.utils.logging_utils import log_info, log_warning, log_error, log_exception

# Log informational event
log_info('bronze_upload', 'File uploaded successfully', 
         details={'file_name': 'data.csv', 'size': 1024}, 
         tpa_code='provider_a')

# Log warning
log_warning('silver_transform', 'Missing column in source data',
            details={'column': 'member_id'},
            tpa_code='provider_a')

# Log error
log_error('gold_analytics', 'Query timeout',
          details={'query': 'SELECT ...'},
          user_name='admin')

# Log exception with full stack trace
try:
    # ... code ...
except Exception as e:
    log_exception('bronze_processing', e,
                  context={'file': 'data.csv'},
                  tpa_code='provider_a')
```

### Snowflake SQL Procedures

```sql
-- Log application event
CALL log_application_event(
    'INFO',
    'discover_files',
    'Found 5 new files',
    PARSE_JSON('{"count": 5}'),
    NULL,
    'provider_a'
);

-- Log file processing stage
CALL log_file_processing_stage(
    101,  -- queue_id
    'provider_a/data.csv',
    'provider_a',
    'LOADING',
    'SUCCESS',
    1000,  -- rows_processed
    0,     -- rows_failed
    NULL,  -- error_message
    PARSE_JSON('{"duration_ms": 5000}')
);
```

### Task Logging (Automatic)

All Snowflake tasks are automatically wrapped with logging:

```sql
CREATE OR REPLACE TASK discover_files_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '60 MINUTE'
AS
BEGIN
    DECLARE
        v_execution_id INTEGER;
        v_result VARCHAR;
    BEGIN
        -- Log task start
        v_execution_id := (SELECT MAX(EXECUTION_ID) + 1 FROM TASK_EXECUTION_LOGS);
        INSERT INTO TASK_EXECUTION_LOGS (...)
        VALUES (v_execution_id, 'discover_files_task', 'STARTED', ...);
        
        -- Execute task
        CALL discover_files() INTO v_result;
        
        -- Log task success
        UPDATE TASK_EXECUTION_LOGS
        SET EXECUTION_STATUS = 'SUCCESS', ...
        WHERE EXECUTION_ID = v_execution_id;
    EXCEPTION
        WHEN OTHER THEN
            -- Log task failure
            UPDATE TASK_EXECUTION_LOGS
            SET EXECUTION_STATUS = 'FAILED', ...
            WHERE EXECUTION_ID = v_execution_id;
    END;
END;
```

## Viewing Logs

### Frontend UI

Navigate to **Admin > System Logs** to view all logs in a tabbed interface:

- **Application Logs**: General application events
- **Task Executions**: Task execution history with duration and status
- **File Processing**: Detailed file processing stages
- **Errors**: Error tracking with resolution status
- **API Requests**: API endpoint usage and performance

### API Endpoints

```bash
# Get application logs
GET /api/logs/application?limit=100&level=ERROR&days=7

# Get task execution logs
GET /api/logs/tasks?task_name=discover_files_task&status=FAILED

# Get file processing logs
GET /api/logs/file-processing?file_name=data.csv&tpa=provider_a

# Get error logs
GET /api/logs/errors?resolution_status=UNRESOLVED

# Get API request logs
GET /api/logs/api-requests?method=POST&min_response_time=1000

# Get statistics
GET /api/logs/stats?days=7
```

### SQL Queries

```sql
-- View recent errors
SELECT * FROM V_RECENT_ERRORS
WHERE ERROR_TIMESTAMP >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
ORDER BY ERROR_TIMESTAMP DESC;

-- View task execution summary
SELECT 
    TASK_NAME,
    COUNT(*) as executions,
    AVG(EXECUTION_DURATION_MS) as avg_duration_ms,
    SUM(CASE WHEN EXECUTION_STATUS = 'SUCCESS' THEN 1 ELSE 0 END) as successes,
    SUM(CASE WHEN EXECUTION_STATUS = 'FAILED' THEN 1 ELSE 0 END) as failures
FROM TASK_EXECUTION_LOGS
WHERE EXECUTION_START >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
GROUP BY TASK_NAME;

-- View file processing summary
SELECT * FROM V_FILE_PROCESSING_SUMMARY
WHERE LAST_STAGE_TIME >= DATEADD(DAY, -1, CURRENT_TIMESTAMP());

-- View slow API requests
SELECT 
    REQUEST_PATH,
    AVG(RESPONSE_TIME_MS) as avg_response_time,
    MAX(RESPONSE_TIME_MS) as max_response_time,
    COUNT(*) as request_count
FROM API_REQUEST_LOGS
WHERE REQUEST_TIMESTAMP >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
GROUP BY REQUEST_PATH
HAVING AVG(RESPONSE_TIME_MS) > 1000
ORDER BY avg_response_time DESC;
```

## Best Practices

1. **Log Levels**:
   - `DEBUG`: Detailed diagnostic information
   - `INFO`: General informational messages
   - `WARNING`: Warning messages for potentially harmful situations
   - `ERROR`: Error events that might still allow the application to continue
   - `CRITICAL`: Very severe error events that might cause the application to abort

2. **Include Context**: Always include relevant context (TPA, file name, user, etc.) in log details

3. **Use Structured Data**: Store complex data in the `VARIANT` fields (LOG_DETAILS, EXECUTION_DETAILS, etc.)

4. **Error Resolution**: Update ERROR_LOGS with resolution status and notes when investigating/fixing issues

5. **Performance Monitoring**: Use API_REQUEST_LOGS to identify slow endpoints and optimize

6. **Retention**: Configure appropriate retention policies for log tables based on compliance requirements

## Maintenance

### Log Cleanup

```sql
-- Archive old logs (example: move to archive table or delete)
DELETE FROM APPLICATION_LOGS
WHERE LOG_TIMESTAMP < DATEADD(DAY, -90, CURRENT_TIMESTAMP());

DELETE FROM API_REQUEST_LOGS
WHERE REQUEST_TIMESTAMP < DATEADD(DAY, -30, CURRENT_TIMESTAMP());
```

### Performance Tuning

All log tables have indexes on key columns for fast querying:
- Timestamp columns for time-range queries
- Status/level columns for filtering
- Source/task name columns for grouping

Monitor query performance and add additional indexes if needed.

## Troubleshooting

### Logs Not Appearing

1. Check if logging tables exist:
   ```sql
   SHOW TABLES LIKE '%LOGS';
   ```

2. Verify logging procedures exist:
   ```sql
   SHOW PROCEDURES LIKE 'log_%';
   ```

3. Check for errors in application logs:
   ```sql
   SELECT * FROM APPLICATION_LOGS 
   WHERE LOG_LEVEL = 'ERROR' 
   AND LOG_SOURCE LIKE '%logging%'
   ORDER BY LOG_TIMESTAMP DESC;
   ```

### High Log Volume

If log tables grow too large:

1. Increase retention period cleanup frequency
2. Add more aggressive filtering in queries
3. Consider partitioning large tables
4. Archive old logs to external storage

### Missing Task Logs

If task execution logs are missing:

1. Verify tasks are running:
   ```sql
   SHOW TASKS;
   ```

2. Check task history:
   ```sql
   SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
       SCHEDULED_TIME_RANGE_START => DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
   ));
   ```

3. Ensure logging wrapper code is present in task definitions
