# File Processing Error Investigation

**Date**: January 21, 2026  
**Status**: 🔍 Investigating

---

## Problem Report

User reported: "When uploading a file it had an error trying to process the files"

---

## File Upload Flow

### 1. Upload Phase
```
Frontend (BronzeUpload.tsx) 
  → POST /api/bronze/upload
  → Saves file to temp directory
  → Uploads to Snowflake stage @BRONZE.SRC/{tpa}/
  → Returns success
```

### 2. Discovery Phase (if "Process immediately" checked)
```
Frontend
  → POST /api/bronze/discover
  → Lists files in @BRONZE.SRC
  → Inserts new files into file_processing_queue
  → Returns count of discovered files
```

### 3. Processing Phase
```
Frontend
  → POST /api/bronze/process
  → Gets PENDING files from queue (limit 10)
  → For each file:
      - Update status to PROCESSING
      - Call stored procedure (process_single_csv_file or process_single_excel_file)
      - Update status to SUCCESS or FAILED
  → Returns count of processed files
```

---

## Potential Issues Found

### Issue 1: SQL String Escaping (Lines 417, 427)

**Location**: `backend/app/api/bronze.py`

**Problem**: Using simple string replacement for quote escaping

```python
# Line 417 - Success message
result_msg.replace("'", "''")

# Line 427 - Error message  
error_msg = str(proc_error).replace("'", "''")
```

**Risk**: 
- If result message contains special characters or complex SQL, escaping might fail
- Error messages with quotes, backslashes, or newlines could break the UPDATE query
- Potential SQL injection if error messages contain malicious content

**Example Failure**:
```python
error_msg = "File contains invalid data: can't parse row 'test'"
# After escape: "File contains invalid data: can''t parse row ''test''"
# In SQL: SET error_message = 'File contains invalid data: can''t parse row ''test'''
# This could still break if there are other special characters
```

### Issue 2: Long Error Messages (Line 431)

```python
error_message = '{error_msg[:500]}'  # Truncated to 500 chars
```

**Risk**: Truncation might cut in the middle of an escaped quote sequence

### Issue 3: No Error Details Returned

When processing fails, the endpoint returns:
```python
{
  "message": "Queue processing completed. Processed 0 files.",
  "files_processed": 0
}
```

**Problem**: Doesn't indicate that files FAILED, only that 0 were successful

### Issue 4: Stored Procedure Error Format

Line 410 checks:
```python
if result_msg.startswith("ERROR:"):
    raise Exception(result_msg)
```

**Question**: Do the stored procedures actually return "ERROR:" prefix?

---

## Recommended Fixes

### Fix 1: Use Parameterized Queries

Instead of string concatenation, use Snowflake's parameterized queries:

```python
# CURRENT (vulnerable)
success_query = f"""
    UPDATE {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
    SET status = 'SUCCESS',
        process_result = '{result_msg.replace("'", "''")}',
        processed_timestamp = CURRENT_TIMESTAMP()
    WHERE queue_id = {queue_id}
"""
sf_service.execute_query(success_query)

# BETTER (but still not ideal)
# Snowflake Python connector doesn't support parameterized UPDATE well

# BEST (use stored procedure)
sf_service.execute_procedure(
    f"{settings.BRONZE_SCHEMA_NAME}.update_queue_status",
    queue_id,
    'SUCCESS',
    result_msg,
    None  # error_message
)
```

### Fix 2: Return Detailed Error Information

```python
return {
    "message": f"Queue processing completed. Processed {files_processed} files.",
    "files_processed": files_processed,
    "files_attempted": len(pending_files),
    "files_failed": len(pending_files) - files_processed,
    "errors": failed_files  # List of {file_name, error} objects
}
```

### Fix 3: Better Error Handling

```python
try:
    # Process file
    result = sf_service.execute_query(proc_query, timeout=600)
    result_msg = result[0][0] if result and len(result) > 0 else "No result returned"
    
    # Check for errors in result
    if "ERROR" in result_msg.upper() or "FAILED" in result_msg.upper():
        raise Exception(result_msg)
    
    # Update to SUCCESS
    # ... (use stored procedure for update)
    
except Exception as proc_error:
    logger.error(f"Error processing file {file_name}: {str(proc_error)}")
    
    # Sanitize error message
    error_msg = str(proc_error)
    # Remove any potential SQL injection characters
    error_msg = error_msg.replace("\\", "\\\\").replace("'", "''")
    # Truncate safely (not in middle of escape sequence)
    if len(error_msg) > 500:
        error_msg = error_msg[:497] + "..."
    
    # Update to FAILED (use stored procedure)
    # ...
```

### Fix 4: Add Logging

```python
# Before processing
logger.info(f"Starting to process {len(pending_files)} pending files")

# For each file
logger.info(f"Processing file {file_name} (queue_id={queue_id}, type={file_type})")

# After procedure call
logger.info(f"Procedure result: {result_msg}")

# On success
logger.info(f"Successfully processed {file_name}")

# On failure
logger.error(f"Failed to process {file_name}: {proc_error}", exc_info=True)
```

---

## Debugging Steps

### Step 1: Check Backend Logs

```bash
snow spcs service logs BORDEREAU_APP \
  --connection DEPLOYMENT \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --container-name backend \
  --num-lines 500 | grep -A 10 -B 10 "process"
```

### Step 2: Check Processing Queue

```sql
SELECT 
    queue_id,
    file_name,
    tpa,
    status,
    error_message,
    process_result,
    retry_count,
    processed_timestamp
FROM BRONZE.file_processing_queue
WHERE status IN ('FAILED', 'PROCESSING')
ORDER BY discovered_timestamp DESC
LIMIT 20;
```

### Step 3: Check Stage Files

```sql
LIST @BRONZE.SRC;
```

### Step 4: Test Stored Procedure Manually

```sql
-- Test CSV processing
CALL BRONZE.process_single_csv_file('@SRC/provider_a/test.csv', 'provider_a');

-- Test Excel processing  
CALL BRONZE.process_single_excel_file('@SRC/provider_a/test.xlsx', 'provider_a');
```

### Step 5: Check Stored Procedure Definition

```sql
SHOW PROCEDURES LIKE 'process_single_%' IN SCHEMA BRONZE;

DESC PROCEDURE BRONZE.process_single_csv_file(VARCHAR, VARCHAR);
```

---

## Quick Fix (Immediate)

If the issue is urgent, add better error handling:

```python
# In /bronze/process endpoint, around line 424
except Exception as proc_error:
    error_str = str(proc_error)
    logger.error(f"Error processing file {file_name} (queue_id={queue_id}): {error_str}")
    logger.error(f"Full traceback:", exc_info=True)
    
    # Sanitize error message for SQL
    error_msg = error_str.replace("'", "''")[:500]
    
    # Try to update queue status
    try:
        fail_query = f"""
            UPDATE {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
            SET status = 'FAILED', 
                error_message = '{error_msg}',
                processed_timestamp = CURRENT_TIMESTAMP(),
                retry_count = COALESCE(retry_count, 0) + 1
            WHERE queue_id = {queue_id}
        """
        sf_service.execute_query(fail_query)
    except Exception as update_error:
        logger.error(f"Failed to update queue status for {file_name}: {update_error}")
        # Continue processing other files even if update fails
```

---

## Next Steps

1. **Get Error Details**: Need actual error message from logs or database
2. **Test Stored Procedures**: Verify they work correctly with sample data
3. **Implement Fixes**: Based on root cause analysis
4. **Add Monitoring**: Better logging and error reporting

---

## Questions for User

1. What was the exact error message shown in the UI?
2. What type of file was uploaded (CSV or Excel)?
3. What TPA was selected?
4. Can you check the Processing Status page to see if the file appears as FAILED?

---

**Status**: Awaiting more details to identify root cause
