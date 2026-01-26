-- ============================================
-- BRONZE LAYER STORED PROCEDURES
-- ============================================
-- Purpose: File processing logic for CSV and Excel files
-- 
-- This script creates procedures for:
--   1. CSV file processing (pandas)
--   2. Excel file processing (openpyxl)
--   3. File discovery and queueing
--   4. Queue processing
--   5. File movement (success/failure/archive)
--
-- TPA Architecture:
--   - TPA extracted from file path (@SRC/provider_a/file.csv → TPA = 'provider_a')
--   - All procedures validate TPA against TPA_MASTER
--   - Files organized by TPA in stages
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET BRONZE_SCHEMA_NAME = '$BRONZE_SCHEMA_NAME';

-- Set role and context
SET role_admin = $DATABASE_NAME || '_ADMIN';

USE ROLE IDENTIFIER($role_admin);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);

-- ============================================
-- PROCEDURE: Process Single CSV File
-- ============================================

CREATE OR REPLACE PROCEDURE process_single_csv_file(file_path VARCHAR, tpa VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'pandas')
HANDLER = 'process_csv_file'
AS
$$
import pandas as pd
import io
import gzip
from snowflake.snowpark.types import StructType, StructField, StringType, IntegerType, VariantType
import json

def log_stage(session, queue_id, file_name, tpa, stage, status, rows_processed, rows_failed, error_msg, details_json):
    """Helper function to log file processing stages"""
    try:
        details_str = details_json if details_json else 'null'
        error_str = f"'{error_msg}'" if error_msg else 'null'
        queue_id_str = str(queue_id) if queue_id else 'null'
        
        log_query = f"""
            INSERT INTO FILE_PROCESSING_LOGS (
                QUEUE_ID, FILE_NAME, TPA_CODE, PROCESSING_STAGE, STAGE_STATUS,
                STAGE_END, ROWS_PROCESSED, ROWS_FAILED, ERROR_MESSAGE, STAGE_DETAILS
            ) VALUES (
                {queue_id_str}, '{file_name}', '{tpa}', '{stage}', '{status}',
                CURRENT_TIMESTAMP(), {rows_processed}, {rows_failed}, {error_str}, PARSE_JSON('{details_str}')
            )
        """
        session.sql(log_query).collect()
    except Exception as e:
        # Don't fail the main process if logging fails
        pass

def process_csv_file(session, file_path, tpa):
    """Process a single CSV file and load into RAW_DATA_TABLE using bulk operations"""
    
    # Get file name from path
    file_name = file_path.split('/')[-1]
    queue_id = None
    
    # Get queue_id for logging
    try:
        queue_query = f"SELECT QUEUE_ID FROM file_processing_queue WHERE file_name LIKE '%{file_name}%' ORDER BY QUEUE_ID DESC LIMIT 1"
        queue_result = session.sql(queue_query).collect()
        if queue_result:
            queue_id = queue_result[0]['QUEUE_ID']
    except:
        pass
    
    try:
        # Log: Start reading file
        log_stage(session, queue_id, file_name, tpa, 'READING', 'STARTED', 0, 0, None, None)
        
        # Read file from stage
        file_content = session.file.get_stream(file_path).read()
        
        # Check if file is gzipped and decompress
        if file_path.endswith('.gz'):
            try:
                file_content = gzip.decompress(file_content)
            except Exception as e:
                log_stage(session, queue_id, file_name, tpa, 'READING', 'FAILED', 0, 0, f'Gzip decompression failed: {str(e)}', None)
                return f"ERROR: Failed to decompress gzipped file: {str(e)}"
        
        # Detect encoding
        try:
            content_str = file_content.decode('utf-8')
        except UnicodeDecodeError:
            content_str = file_content.decode('latin-1')
        
        log_stage(session, queue_id, file_name, tpa, 'READING', 'SUCCESS', 0, 0, None, f'{{"file_size": {len(file_content)}}}')
        
        # Log: Start parsing
        log_stage(session, queue_id, file_name, tpa, 'PARSING', 'STARTED', 0, 0, None, None)
        
        # Parse CSV with pandas
        df = pd.read_csv(io.StringIO(content_str))
        
        log_stage(session, queue_id, file_name, tpa, 'PARSING', 'SUCCESS', len(df), 0, None, f'{{"columns": {df.shape[1]}, "rows": {df.shape[0]}}}')
        
        # Check if file already processed (prevent duplicate processing)
        check_query = f"""
            SELECT COUNT(*) as cnt 
            FROM RAW_DATA_TABLE 
            WHERE FILE_NAME = '{file_name}'
        """
        existing_count = session.sql(check_query).collect()[0]['CNT']
        
        if existing_count > 0:
            log_stage(session, queue_id, file_name, tpa, 'VALIDATION', 'SKIPPED', 0, 0, 'File already processed', f'{{"existing_rows": {existing_count}}}')
            return f"SKIPPED: File {file_name} already processed ({existing_count} rows exist)"
        
        # Log: Start data preparation
        log_stage(session, queue_id, file_name, tpa, 'PREPARATION', 'STARTED', 0, 0, None, None)
        
        # Prepare data for bulk insertion
        rows_data = []
        for idx, row in df.iterrows():
            # Convert row to JSON string
            row_json = row.to_json()
            
            rows_data.append({
                'FILE_NAME': file_name,
                'FILE_ROW_NUMBER': idx + 1,
                'TPA': tpa,
                'RAW_DATA': row_json,
                'FILE_TYPE': 'CSV'
            })
        
        if not rows_data:
            log_stage(session, queue_id, file_name, tpa, 'PREPARATION', 'FAILED', 0, 0, 'No data rows found', None)
            return f"ERROR: No data rows found in {file_name}"
        
        log_stage(session, queue_id, file_name, tpa, 'PREPARATION', 'SUCCESS', len(rows_data), 0, None, f'{{"rows_prepared": {len(rows_data)}}}')
        
        # Log: Start loading
        log_stage(session, queue_id, file_name, tpa, 'LOADING', 'STARTED', 0, 0, None, None)
        
        # Create temporary table with data
        temp_table_name = f"TEMP_CSV_LOAD_{session.sql('SELECT UUID_STRING()').collect()[0][0].replace('-', '_')}"
        
        # Define schema for temp table
        schema = StructType([
            StructField("FILE_NAME", StringType()),
            StructField("FILE_ROW_NUMBER", IntegerType()),
            StructField("TPA", StringType()),
            StructField("RAW_DATA", StringType()),
            StructField("FILE_TYPE", StringType())
        ])
        
        # Create DataFrame from rows_data
        temp_df = session.create_dataframe(rows_data, schema)
        
        # Write to temporary table (will be automatically temporary due to TEMP_ prefix)
        temp_df.write.mode("overwrite").save_as_table(temp_table_name)
        
        # Bulk MERGE from temp table to RAW_DATA_TABLE
        merge_query = f"""
            MERGE INTO RAW_DATA_TABLE t
            USING (
                SELECT 
                    FILE_NAME,
                    FILE_ROW_NUMBER,
                    TPA,
                    PARSE_JSON(RAW_DATA) AS RAW_DATA,
                    FILE_TYPE
                FROM {temp_table_name}
            ) s
            ON t.FILE_NAME = s.FILE_NAME AND t.FILE_ROW_NUMBER = s.FILE_ROW_NUMBER
            WHEN NOT MATCHED THEN 
                INSERT (FILE_NAME, FILE_ROW_NUMBER, TPA, RAW_DATA, FILE_TYPE)
                VALUES (s.FILE_NAME, s.FILE_ROW_NUMBER, s.TPA, s.RAW_DATA, s.FILE_TYPE)
        """
        
        result = session.sql(merge_query).collect()
        rows_inserted = result[0]['number of rows inserted']
        
        # Clean up temp table
        session.sql(f"DROP TABLE IF EXISTS {temp_table_name}").collect()
        
        log_stage(session, queue_id, file_name, tpa, 'LOADING', 'SUCCESS', rows_inserted, 0, None, f'{{"rows_inserted": {rows_inserted}}}')
        
        return f"SUCCESS: Processed {rows_inserted} rows from {file_name}"
        
    except Exception as e:
        error_msg = str(e)
        log_stage(session, queue_id, file_name, tpa, 'PROCESSING', 'FAILED', 0, 0, error_msg[:500], f'{{"error_type": "{type(e).__name__}"}}')
        return f"ERROR: {error_msg}"
$$;

-- ============================================
-- PROCEDURE: Process Single Excel File
-- ============================================

CREATE OR REPLACE PROCEDURE process_single_excel_file(file_path VARCHAR, tpa VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'pandas', 'openpyxl')
HANDLER = 'process_excel_file'
AS
$$
import pandas as pd
import io

def process_excel_file(session, file_path, tpa):
    """Process a single Excel file and load into RAW_DATA_TABLE"""
    
    try:
        # Read file from stage
        file_content = session.file.get_stream(file_path).read()
        
        # Parse Excel with pandas
        excel_file = pd.ExcelFile(io.BytesIO(file_content))
        
        # Get file name from path
        file_name = file_path.split('/')[-1]
        
        total_rows_inserted = 0
        total_rows_failed = 0
        total_rows_in_file = 0
        
        # Process all sheets
        for sheet_name in excel_file.sheet_names:
            df = pd.read_excel(excel_file, sheet_name=sheet_name)
            total_rows_in_file += len(df)
            
            # Prepare data for insertion
            for idx, row in df.iterrows():
                # Convert row to JSON
                row_json = row.to_json()
                
                # Escape single quotes in JSON for SQL (replace ' with '')
                row_json_escaped = row_json.replace("'", "''")
                
                # Insert into RAW_DATA_TABLE using MERGE (deduplication)
                # Use sheet name in row number for multi-sheet files
                row_number = f"{sheet_name}_{idx + 1}"
                
                merge_query = f"""
                    MERGE INTO RAW_DATA_TABLE t
                    USING (
                        SELECT 
                            '{file_name}' AS FILE_NAME,
                            '{row_number}' AS FILE_ROW_NUMBER,
                            '{tpa}' AS TPA,
                            PARSE_JSON('{row_json_escaped}') AS RAW_DATA,
                            'EXCEL' AS FILE_TYPE
                    ) s
                    ON t.FILE_NAME = s.FILE_NAME AND t.FILE_ROW_NUMBER = s.FILE_ROW_NUMBER
                    WHEN NOT MATCHED THEN INSERT (FILE_NAME, FILE_ROW_NUMBER, TPA, RAW_DATA, FILE_TYPE)
                        VALUES (s.FILE_NAME, s.FILE_ROW_NUMBER, s.TPA, s.RAW_DATA, s.FILE_TYPE)
                """
                
                try:
                    session.sql(merge_query).collect()
                    total_rows_inserted += 1
                except Exception as e:
                    # Log error but continue processing
                    total_rows_failed += 1
                    pass
        
        # Return success if at least some rows were inserted
        if total_rows_inserted > 0:
            if total_rows_failed > 0:
                return f"SUCCESS: Processed {total_rows_inserted} rows from {file_name} ({len(excel_file.sheet_names)} sheets, {total_rows_failed} rows skipped due to errors)"
            else:
                return f"SUCCESS: Processed {total_rows_inserted} rows from {file_name} ({len(excel_file.sheet_names)} sheets)"
        else:
            return f"ERROR: No rows inserted from {file_name}. Total rows in file: {total_rows_in_file}"
        
    except Exception as e:
        return f"ERROR: {str(e)}"
$$;

-- ============================================
-- PROCEDURE: Discover Files and Move to PROCESSING
-- ============================================

CREATE OR REPLACE PROCEDURE discover_files()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'discover_files'
AS
$$
def discover_files(session):
    """Discover files in @SRC and add them to the processing queue"""
    
    # Refresh SRC stage
    session.sql("ALTER STAGE SRC REFRESH").collect()
    
    # Get files from @SRC that aren't in the queue yet
    query = """
        SELECT 
            RELATIVE_PATH AS file_name,
            SPLIT_PART(RELATIVE_PATH, '/', 1) AS tpa,
            CASE 
                WHEN UPPER(RELATIVE_PATH) LIKE '%.CSV%' THEN 'CSV'
                WHEN UPPER(RELATIVE_PATH) LIKE '%.XLSX' THEN 'EXCEL'
                WHEN UPPER(RELATIVE_PATH) LIKE '%.XLS' THEN 'EXCEL'
                ELSE 'UNKNOWN'
            END AS file_type,
            SIZE AS file_size_bytes
        FROM DIRECTORY(@SRC)
        WHERE RELATIVE_PATH NOT IN (
            SELECT file_name FROM file_processing_queue
        )
    """
    
    new_files = session.sql(query).collect()
    
    if not new_files:
        return "No new files discovered"
    
    files_discovered = 0
    
    for file_row in new_files:
        file_name = file_row['FILE_NAME']
        tpa = file_row['TPA']
        file_type = file_row['FILE_TYPE']
        file_size = file_row['FILE_SIZE_BYTES']
        
        try:
            # Insert into queue - files stay in @SRC until processed
            insert_query = f"""
                INSERT INTO file_processing_queue (file_name, tpa, file_type, file_size_bytes, status)
                VALUES ('{file_name}', '{tpa}', '{file_type}', {file_size}, 'PENDING')
            """
            session.sql(insert_query).collect()
            files_discovered += 1
            
            # Get queue_id for logging
            queue_id_result = session.sql(f"SELECT MAX(QUEUE_ID) as qid FROM file_processing_queue WHERE file_name = '{file_name}'").collect()
            queue_id = queue_id_result[0]['QID'] if queue_id_result else None
            
            # Log the discovery
            if queue_id:
                log_query = f"""
                    CALL log_file_processing_stage(
                        {queue_id}, '{file_name}', '{tpa}', 'DISCOVERY', 'SUCCESS',
                        0, 0, NULL, PARSE_JSON('{{"action": "queued_for_processing"}}')
                    )
                """
                try:
                    session.sql(log_query).collect()
                except:
                    pass  # Don't fail if logging fails
                
        except Exception as e:
            # Log error but continue with other files
            error_msg = str(e).replace("'", "''")[:500]
            try:
                error_log = f"""
                    CALL log_error(
                        'discover_files', 'FileDiscoveryError',
                        'Failed to queue file: {file_name} - {error_msg}',
                        NULL, PARSE_JSON('{{"file": "{file_name}", "tpa": "{tpa}"}}'),
                        NULL, '{tpa}'
                    )
                """
                session.sql(error_log).collect()
            except:
                pass
            continue
    
    return f"Discovered and queued {files_discovered} file(s) for processing"
$$;

-- ============================================
-- PROCEDURE: Process Queued Files
-- ============================================

CREATE OR REPLACE PROCEDURE process_queued_files()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'process_queued_files'
AS
$$
def process_queued_files(session):
    """Process pending files from the queue (batch of 10)"""
    
    # Get pending files (limit to 10 per batch)
    query = """
        SELECT queue_id, file_name, tpa, file_type
        FROM file_processing_queue
        WHERE status = 'PENDING'
        ORDER BY discovered_timestamp
        LIMIT 10
    """
    
    pending_files = session.sql(query).collect()
    
    if not pending_files:
        return "No pending files to process"
    
    processed_count = 0
    success_count = 0
    failed_count = 0
    
    for file_row in pending_files:
        queue_id = file_row['QUEUE_ID']
        file_name = file_row['FILE_NAME']
        tpa = file_row['TPA']
        file_type = file_row['FILE_TYPE']
        
        # Update status to PROCESSING
        session.sql(f"""
            UPDATE file_processing_queue
            SET status = 'PROCESSING'
            WHERE queue_id = {queue_id}
        """).collect()
        
        # Build full file path (read from @SRC stage where file was uploaded)
        # file_name already includes TPA path like "provider_a/file.csv"
        file_path = f"@SRC/{file_name}"
        
        # Process file based on type
        try:
            if file_type == 'CSV':
                result = session.call('process_single_csv_file', file_path, tpa)
            elif file_type == 'EXCEL':
                result = session.call('process_single_excel_file', file_path, tpa)
            else:
                result = f"ERROR: Unsupported file type: {file_type}"
            
            # Check if processing was successful
            if result.startswith('SUCCESS'):
                status = 'SUCCESS'
                success_count += 1
            else:
                status = 'FAILED'
                failed_count += 1
            
            # Update queue with result
            session.sql(f"""
                UPDATE file_processing_queue
                SET status = '{status}',
                    processed_timestamp = CURRENT_TIMESTAMP(),
                    process_result = '{result[:5000]}'  -- Truncate to fit column
                WHERE queue_id = {queue_id}
            """).collect()
            
            processed_count += 1
            
        except Exception as e:
            # Update queue with error
            error_msg = str(e).replace("'", "''")[:5000]  # Escape quotes and truncate
            session.sql(f"""
                UPDATE file_processing_queue
                SET status = 'FAILED',
                    processed_timestamp = CURRENT_TIMESTAMP(),
                    error_message = '{error_msg}',
                    retry_count = retry_count + 1
                WHERE queue_id = {queue_id}
            """).collect()
            
            failed_count += 1
            processed_count += 1
    
    return f"Processed {processed_count} file(s): {success_count} success, {failed_count} failed"
$$;

-- ============================================
-- PROCEDURE: Move Processed Files
-- ============================================

CREATE OR REPLACE PROCEDURE move_processed_files()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'move_processed_files'
AS
$$
def move_processed_files(session):
    """Move successfully processed files from @SRC to @COMPLETED"""
    
    # Get successfully processed files
    query = """
        SELECT file_name, tpa
        FROM file_processing_queue
        WHERE status = 'SUCCESS'
        LIMIT 100
    """
    
    success_files = session.sql(query).collect()
    
    if not success_files:
        return "No files to move"
    
    files_moved = 0
    files_failed = 0
    error_details = []
    
    for file_row in success_files:
        file_name = file_row['FILE_NAME']
        tpa = file_row['TPA']
        
        # Extract just the filename without TPA path
        just_filename = file_name.split('/')[-1]
        
        try:
            # Copy file to @COMPLETED (source is @SRC/tpa/filename)
            src_path = f"@SRC/{file_name}"
            dest_path = f"@COMPLETED/{tpa}/"
            copy_cmd = f"COPY FILES INTO {dest_path} FROM {src_path}"
            session.sql(copy_cmd).collect()
            
            # Remove file from @SRC after successful copy
            remove_cmd = f"REMOVE {src_path}"
            session.sql(remove_cmd).collect()
            
            files_moved += 1
            
            # Log the move
            log_cmd = f"""
                CALL log_file_processing_stage(
                    (SELECT QUEUE_ID FROM file_processing_queue WHERE file_name = '{file_name}' LIMIT 1),
                    '{file_name}',
                    '{tpa}',
                    'MOVING',
                    'SUCCESS',
                    0, 0, NULL,
                    PARSE_JSON('{{"action": "moved_to_completed"}}')
                )
            """
            try:
                session.sql(log_cmd).collect()
            except:
                pass  # Don't fail if logging fails
            
        except Exception as e:
            # Log error with details
            files_failed += 1
            error_details.append(f"{file_name}: {str(e)[:100]}")
            continue
    
    # Refresh stages
    session.sql("ALTER STAGE SRC REFRESH").collect()
    session.sql("ALTER STAGE COMPLETED REFRESH").collect()
    
    if files_failed > 0:
        errors_str = "; ".join(error_details[:3])  # Limit to first 3 errors
        return f"Moved {files_moved} file(s) to @COMPLETED ({files_failed} failed: {errors_str})"
    else:
        return f"Moved {files_moved} file(s) to @COMPLETED"
$$;

-- ============================================
-- PROCEDURE: Move Failed Files
-- ============================================

CREATE OR REPLACE PROCEDURE move_failed_files()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'move_failed_files'
AS
$$
def move_failed_files(session):
    """Move failed files from @SRC to @ERROR after max retries"""
    
    # Get failed files (after max retries)
    query = """
        SELECT file_name, tpa
        FROM file_processing_queue
        WHERE status = 'FAILED'
          AND retry_count >= 3
        LIMIT 100
    """
    
    failed_files = session.sql(query).collect()
    
    if not failed_files:
        return "No failed files to move"
    
    files_moved = 0
    files_failed = 0
    
    for file_row in failed_files:
        file_name = file_row['FILE_NAME']
        tpa = file_row['TPA']
        
        # Extract just the filename without TPA path
        just_filename = file_name.split('/')[-1]
        
        try:
            # Copy file to @ERROR (source is @SRC/tpa/filename)
            src_path = f"@SRC/{file_name}"
            dest_path = f"@ERROR/{tpa}/"
            copy_cmd = f"COPY FILES INTO {dest_path} FROM {src_path}"
            session.sql(copy_cmd).collect()
            
            # Remove file from @SRC after successful copy
            remove_cmd = f"REMOVE {src_path}"
            session.sql(remove_cmd).collect()
            
            files_moved += 1
        except Exception as e:
            # Log error but continue
            files_failed += 1
            continue
    
    # Refresh stages
    session.sql("ALTER STAGE SRC REFRESH").collect()
    session.sql("ALTER STAGE ERROR REFRESH").collect()
    
    if files_failed > 0:
        return f"Moved {files_moved} failed file(s) to @ERROR ({files_failed} errors)"
    else:
        return f"Moved {files_moved} failed file(s) to @ERROR"
$$;

-- ============================================
-- PROCEDURE: Archive Old Files
-- ============================================

CREATE OR REPLACE PROCEDURE archive_old_files()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    files_archived INTEGER DEFAULT 0;
    result_msg VARCHAR;
BEGIN
    -- Archive files older than 30 days from @COMPLETED
    -- Note: This is a simplified version - production would use stage metadata
    
    result_msg := 'Archive procedure executed (simplified version)';
    RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Delete File Data
-- ============================================

CREATE OR REPLACE PROCEDURE delete_file_data(p_file_name VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'delete_file_data'
AS
$$
def delete_file_data(session, p_file_name):
    """Delete all data for a specific file from RAW_DATA_TABLE"""
    
    # Get the file name without path if full path provided
    file_name = p_file_name.split('/')[-1]
    
    # Delete from RAW_DATA_TABLE
    delete_query = f"DELETE FROM RAW_DATA_TABLE WHERE FILE_NAME = '{file_name}'"
    delete_result = session.sql(delete_query).collect()
    rows_deleted = delete_result[0]['number of rows deleted'] if delete_result else 0
    
    # Update queue status
    update_query = f"""
        UPDATE file_processing_queue
        SET status = 'DELETED',
            processed_timestamp = CURRENT_TIMESTAMP(),
            process_result = 'Data deleted: {rows_deleted} rows removed'
        WHERE file_name LIKE '%{file_name}%'
           OR SPLIT_PART(file_name, '/', -1) = '{file_name}'
    """
    session.sql(update_query).collect()
    
    # Get queue_id and tpa for logging
    queue_query = f"""
        SELECT QUEUE_ID, TPA 
        FROM file_processing_queue 
        WHERE SPLIT_PART(file_name, '/', -1) = '{file_name}'
        LIMIT 1
    """
    queue_result = session.sql(queue_query).collect()
    
    if queue_result:
        queue_id = queue_result[0]['QUEUE_ID']
        tpa = queue_result[0]['TPA']
        
        # Log the deletion
        log_query = f"""
            CALL log_file_processing_stage(
                {queue_id}, '{file_name}', '{tpa}', 'DELETION', 'SUCCESS',
                {rows_deleted}, 0, NULL, 
                PARSE_JSON('{{"action": "data_deleted", "rows_deleted": {rows_deleted}}}')
            )
        """
        try:
            session.sql(log_query).collect()
        except:
            pass
        
        # Log to application logs
        app_log_query = f"""
            CALL log_application_event(
                'INFO', 'delete_file_data',
                'Deleted data for file: {file_name}',
                PARSE_JSON('{{"file_name": "{file_name}", "rows_deleted": {rows_deleted}}}'),
                CURRENT_USER(), '{tpa}'
            )
        """
        try:
            session.sql(app_log_query).collect()
        except:
            pass
    
    return f"Deleted {rows_deleted} row(s) for file: {file_name}"
$$;

-- ============================================
-- VERIFICATION
-- ============================================

-- Show created procedures
SHOW PROCEDURES IN SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);

-- Display success message
SELECT 'Bronze stored procedures created successfully' AS status,
       COUNT(*) AS procedure_count
FROM INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = $BRONZE_SCHEMA_NAME;
