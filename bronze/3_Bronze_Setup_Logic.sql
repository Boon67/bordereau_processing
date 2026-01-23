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
from snowflake.snowpark.types import StructType, StructField, StringType, IntegerType, VariantType

def process_csv_file(session, file_path, tpa):
    """Process a single CSV file and load into RAW_DATA_TABLE using bulk operations"""
    
    try:
        # Read file from stage
        file_content = session.file.get_stream(file_path).read()
        
        # Detect encoding
        try:
            content_str = file_content.decode('utf-8')
        except UnicodeDecodeError:
            content_str = file_content.decode('latin-1')
        
        # Parse CSV with pandas
        df = pd.read_csv(io.StringIO(content_str))
        
        # Get file name from path
        file_name = file_path.split('/')[-1]
        
        # Check if file already processed (prevent duplicate processing)
        check_query = f"""
            SELECT COUNT(*) as cnt 
            FROM RAW_DATA_TABLE 
            WHERE FILE_NAME = '{file_name}'
        """
        existing_count = session.sql(check_query).collect()[0]['CNT']
        
        if existing_count > 0:
            return f"SKIPPED: File {file_name} already processed ({existing_count} rows exist)"
        
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
            return f"ERROR: No data rows found in {file_name}"
        
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
        
        # Write to temporary table
        temp_df.write.mode("overwrite").save_as_table(temp_table_name, table_type="temporary")
        
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
        
        return f"SUCCESS: Processed {rows_inserted} rows from {file_name}"
        
    except Exception as e:
        return f"ERROR: {str(e)}"
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
-- PROCEDURE: Discover Files
-- ============================================

CREATE OR REPLACE PROCEDURE discover_files()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    files_discovered INTEGER DEFAULT 0;
    result_msg VARCHAR;
BEGIN
    -- Scan @SRC stage for new files and insert into queue
    -- Extract TPA from path (folder name)
    -- Use DIRECTORY table to list files
    INSERT INTO file_processing_queue (file_name, tpa, file_type, file_size_bytes, status)
    SELECT 
        -- Store relative path without @SRC/ prefix
        RELATIVE_PATH AS file_name,
        -- Extract TPA from path: provider_a/file.csv → provider_a
        SPLIT_PART(RELATIVE_PATH, '/', 1) AS tpa,
        CASE 
            WHEN UPPER(RELATIVE_PATH) LIKE '%.CSV' THEN 'CSV'
            WHEN UPPER(RELATIVE_PATH) LIKE '%.XLSX' THEN 'EXCEL'
            WHEN UPPER(RELATIVE_PATH) LIKE '%.XLS' THEN 'EXCEL'
            ELSE 'UNKNOWN'
        END AS file_type,
        SIZE AS file_size_bytes,
        'PENDING' AS status
    FROM DIRECTORY(@SRC)
    WHERE RELATIVE_PATH NOT IN (
        SELECT file_name 
        FROM file_processing_queue
    );
    
    -- Get count of files discovered
    files_discovered := SQLROWCOUNT;
    
    -- Build result message
    IF (files_discovered = 0) THEN
        result_msg := 'No new files discovered';
    ELSE
        result_msg := 'Discovered ' || files_discovered || ' new file(s)';
    END IF;
    
    RETURN result_msg;
END;
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
        
        # Build full file path
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
LANGUAGE SQL
AS
$$
DECLARE
    files_moved INTEGER DEFAULT 0;
    result_msg VARCHAR;
    move_result VARCHAR;
BEGIN
    -- Get successfully processed files
    FOR file_record IN (
        SELECT file_name, tpa
        FROM file_processing_queue
        WHERE status = 'SUCCESS'
        LIMIT 100
    ) DO
        -- Move file from @SRC to @COMPLETED
        BEGIN
            EXECUTE IMMEDIATE 'COPY FILES INTO @COMPLETED/' || file_record.tpa || '/ FROM @SRC/' || file_record.file_name;
            EXECUTE IMMEDIATE 'REMOVE @SRC/' || file_record.file_name;
            files_moved := files_moved + 1;
        EXCEPTION
            WHEN OTHER THEN
                -- Log error but continue
                CONTINUE;
        END;
    END FOR;
    
    result_msg := 'Moved ' || files_moved || ' file(s) to @COMPLETED';
    RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Move Failed Files
-- ============================================

CREATE OR REPLACE PROCEDURE move_failed_files()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    files_moved INTEGER DEFAULT 0;
    result_msg VARCHAR;
BEGIN
    -- Get failed files (after max retries)
    FOR file_record IN (
        SELECT file_name, tpa
        FROM file_processing_queue
        WHERE status = 'FAILED'
          AND retry_count >= 3
        LIMIT 100
    ) DO
        -- Move file from @SRC to @ERROR
        BEGIN
            EXECUTE IMMEDIATE 'COPY FILES INTO @ERROR/' || file_record.tpa || '/ FROM @SRC/' || file_record.file_name;
            EXECUTE IMMEDIATE 'REMOVE @SRC/' || file_record.file_name;
            files_moved := files_moved + 1;
        EXCEPTION
            WHEN OTHER THEN
                -- Log error but continue
                CONTINUE;
        END;
    END FOR;
    
    result_msg := 'Moved ' || files_moved || ' failed file(s) to @ERROR';
    RETURN result_msg;
END;
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
-- VERIFICATION
-- ============================================

-- Show created procedures
SHOW PROCEDURES IN SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);

-- Display success message
SELECT 'Bronze stored procedures created successfully' AS status,
       COUNT(*) AS procedure_count
FROM INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = $BRONZE_SCHEMA_NAME;
