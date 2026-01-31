# Logging System Implementation

**Status**: ✅ Complete  
**Date**: January 31, 2026

---

## Overview

Implemented a comprehensive logging system that writes application logs, API requests, and errors to Snowflake hybrid tables for centralized monitoring and debugging.

## Components Implemented

### 1. Snowflake Log Handler (`app/utils/snowflake_logger.py`)

**Purpose**: Custom Python logging handler that writes logs to Snowflake APPLICATION_LOGS table

**Features**:
- ✅ Batch processing (configurable batch size)
- ✅ Background thread to avoid blocking main application
- ✅ Automatic flushing at intervals
- ✅ Graceful error handling (logging failures don't crash app)
- ✅ Extracts exception info automatically

**Usage**:
```python
# Automatically added to root logger in main.py
logger.info("This will be written to Snowflake")
logger.error("Errors are logged with stack traces")
```

### 2. API Request Logging Middleware (`app/middleware/logging_middleware.py`)

**Purpose**: Captures all API requests and logs them to API_REQUEST_LOGS table

**What It Logs**:
- ✅ HTTP method, path, query parameters
- ✅ Request body (for POST/PUT/PATCH)
- ✅ Response status code
- ✅ Response time in milliseconds
- ✅ User name (from auth context)
- ✅ Client IP and User-Agent
- ✅ TPA code (if available)
- ✅ Error messages (if request failed)

**Exclusions**:
- Skips health check endpoints (`/api/health`, `/health`)
- Skips static files and root path
- Only logs `/api/*` paths

### 3. Error Logging Integration

**Enhanced Error Handling**:
- ✅ Transformation errors logged to ERROR_LOGS table
- ✅ Stack traces captured automatically
- ✅ Context information included (table names, TPA, etc.)
- ✅ User information tracked

**Example** (from `silver.py`):
```python
except Exception as e:
    logger.error(f"Transformation failed: {str(e)}", exc_info=True)
    
    await log_error(
        source="transform_bronze_to_silver",
        error_type=type(e).__name__,
        error_message=str(e),
        stack_trace=traceback.format_exc(),
        context={"target_table": ..., "tpa": ...},
        user_name=get_username_from_request(request),
        tpa_code=transform_request.tpa
    )
```

### 4. Existing Logging Utilities (`app/utils/logging_utils.py`)

**Already Implemented**:
- ✅ `SnowflakeLogger.log_application_event()` - General app logging
- ✅ `SnowflakeLogger.log_api_request()` - API request logging
- ✅ `SnowflakeLogger.log_error()` - Error logging
- ✅ Convenience functions: `log_info()`, `log_warning()`, `log_error()`, `log_exception()`

**Used In**:
- Bronze file upload endpoint (validation errors, upload events)
- Other endpoints throughout the application

## Snowflake Tables

All logs are written to hybrid tables in the `BRONZE` schema:

### APPLICATION_LOGS
- General application logs (INFO, WARNING, ERROR, CRITICAL)
- Includes source, message, details (JSON), user, TPA
- Indexed on timestamp, level, source

### API_REQUEST_LOGS
- All API requests and responses
- Includes method, path, params, body, status, response time
- Indexed on timestamp, path, status

### ERROR_LOGS
- Detailed error tracking
- Includes error type, message, stack trace, context (JSON)
- Tracks resolution status (UNRESOLVED, INVESTIGATING, RESOLVED)
- Indexed on timestamp, source, resolution status

### TASK_EXECUTION_LOGS
- Task execution tracking (for Snowflake tasks)
- Includes task name, status, duration, records processed/failed
- Indexed on task name, execution start, status

### FILE_PROCESSING_LOGS
- File upload and processing stages
- Includes file name, TPA, stage, status, rows processed/failed
- Indexed on queue ID, file name, stage, status

## Integration Points

### Main Application (`app/main.py`)

```python
# Snowflake logging handler added to root logger
from app.utils.snowflake_logger import SnowflakeLogHandler
snowflake_handler = SnowflakeLogHandler(batch_size=10, flush_interval=5)
logging.getLogger().addHandler(snowflake_handler)

# API logging middleware added
from app.middleware.logging_middleware import APILoggingMiddleware
app.add_middleware(APILoggingMiddleware)
```

### API Endpoints

**Silver Transform** (`app/api/silver.py`):
- Logs transformation start (INFO)
- Logs transformation completion (INFO)
- Logs transformation errors with full context (ERROR)

**Bronze Upload** (`app/api/bronze.py`):
- Already logs validation errors
- Already logs upload events
- Uses existing `SnowflakeLogger` utilities

## How It Works

### 1. Application Logs Flow

```
Python logger.info() 
  → SnowflakeLogHandler.emit()
  → Queue log entry
  → Background thread processes batch
  → INSERT INTO BRONZE.APPLICATION_LOGS
```

### 2. API Request Logs Flow

```
HTTP Request
  → APILoggingMiddleware.dispatch()
  → Extract request details
  → Process request (call_next)
  → Calculate response time
  → asyncio.create_task(log_api_request())
  → INSERT INTO BRONZE.API_REQUEST_LOGS (async, non-blocking)
```

### 3. Error Logs Flow

```
Exception raised
  → catch block
  → logger.error() with exc_info=True
  → await log_error() with context
  → INSERT INTO BRONZE.ERROR_LOGS
```

## Performance Considerations

✅ **Non-Blocking**: API request logging runs asynchronously  
✅ **Batch Processing**: Application logs written in batches  
✅ **Background Thread**: Log handler uses separate thread  
✅ **Graceful Degradation**: Logging failures don't crash the app  
✅ **Configurable**: Batch size and flush interval can be tuned  

## Testing

### Verify Logs Are Being Written

1. **Make API Requests**:
   - Navigate through the UI
   - Upload files, create mappings, run transformations
   - Trigger some errors (e.g., invalid data)

2. **Check System Logs Page**:
   - Go to Administration → System Logs
   - View different log types:
     - Application Logs (general app events)
     - API Requests (all API calls)
     - Errors (detailed error tracking)
     - Task Executions (Snowflake tasks)
     - File Processing (upload stages)

3. **Query Directly in Snowflake**:
   ```sql
   -- Recent application logs
   SELECT * FROM BRONZE.APPLICATION_LOGS 
   ORDER BY LOG_TIMESTAMP DESC LIMIT 100;
   
   -- Recent API requests
   SELECT * FROM BRONZE.API_REQUEST_LOGS 
   ORDER BY REQUEST_TIMESTAMP DESC LIMIT 100;
   
   -- Recent errors
   SELECT * FROM BRONZE.ERROR_LOGS 
   ORDER BY ERROR_TIMESTAMP DESC LIMIT 100;
   ```

## Benefits

✅ **Centralized Logging**: All logs in Snowflake, not scattered across containers  
✅ **Persistent**: Logs survive container restarts  
✅ **Queryable**: Use SQL to analyze logs  
✅ **Structured**: JSON details for complex data  
✅ **Audit Trail**: Track user actions and API calls  
✅ **Debugging**: Full stack traces and context for errors  
✅ **Monitoring**: Track API performance and error rates  
✅ **Compliance**: Meets audit trail requirements  

## Configuration

### Batch Size and Flush Interval

In `app/main.py`:
```python
snowflake_handler = SnowflakeLogHandler(
    batch_size=10,      # Write after 10 log entries
    flush_interval=5    # Or every 5 seconds
)
```

### Log Levels

Default: `INFO` and above (INFO, WARNING, ERROR, CRITICAL)

To change:
```python
snowflake_handler.setLevel(logging.DEBUG)  # Log everything
snowflake_handler.setLevel(logging.WARNING)  # Only warnings and errors
```

## Next Steps (Optional Enhancements)

1. **Add log rotation/cleanup** - Procedure to archive old logs
2. **Add log analytics** - Dashboard with log statistics
3. **Add alerting** - Notify on critical errors
4. **Add log search** - Full-text search across logs
5. **Add log export** - Export logs to external systems

## Files Modified

✅ `backend/app/main.py` - Added Snowflake log handler and middleware  
✅ `backend/app/api/silver.py` - Added transformation logging  
✅ `backend/app/api/logs.py` - Fixed empty data handling  

## Files Created

✅ `backend/app/utils/snowflake_logger.py` - Snowflake log handler  
✅ `backend/app/middleware/logging_middleware.py` - API request logging middleware  

## Files Already Existing

✅ `backend/app/utils/logging_utils.py` - Existing logging utilities  
✅ `bronze/0_Setup_Logging.sql` - Logging tables and procedures  

---

**Result**: Comprehensive logging system is now active and writing logs to Snowflake! 🎉
