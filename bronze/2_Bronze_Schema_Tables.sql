-- ============================================
-- BRONZE LAYER SCHEMA AND TABLES
-- ============================================
-- Purpose: Create Bronze layer stages and tables
-- 
-- This script creates:
--   1. Stages (4): @SRC, @COMPLETED, @ERROR, @ARCHIVE
--   2. Tables (3): TPA_MASTER, RAW_DATA_TABLE, file_processing_queue
--
-- TPA Architecture:
--   - Files organized by TPA in @SRC stage (@SRC/provider_a/, @SRC/provider_b/)
--   - TPA extracted from file path during processing
--   - All tables include TPA dimension
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
-- CREATE STAGES
-- ============================================

-- Stage 1: Source stage for incoming files (organized by TPA folders)
CREATE OR REPLACE STAGE SRC
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Landing zone for incoming CSV and Excel files. Organize files by TPA: @SRC/provider_a/, @SRC/provider_b/';

-- Stage 2: Processing stage (files being actively processed)
CREATE OR REPLACE STAGE PROCESSING
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Files currently being processed. Moved here from @SRC during discovery.';

-- Stage 3: Completed files (30-day retention)
CREATE OR REPLACE STAGE COMPLETED
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Successfully processed files (30-day retention before archival)';

-- Stage 4: Error files (30-day retention)
CREATE OR REPLACE STAGE ERROR
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Failed files with processing errors (30-day retention before archival)';

-- Stage 5: Archive (long-term storage)
CREATE OR REPLACE STAGE ARCHIVE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Long-term archive for files older than 30 days';


-- ============================================
-- CREATE TPA MASTER TABLE (HYBRID)
-- ============================================
-- Using HYBRID TABLE for fast lookups by TPA_CODE and ACTIVE status
-- Hybrid tables support indexes for point queries and frequent updates

CREATE HYBRID TABLE IF NOT EXISTS TPA_MASTER (
    TPA_CODE VARCHAR(500) PRIMARY KEY,
    TPA_NAME VARCHAR(500) NOT NULL,
    TPA_DESCRIPTION VARCHAR(5000),
    ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CREATED_BY VARCHAR(500) DEFAULT CURRENT_USER(),
    INDEX idx_tpa_active (ACTIVE),
    INDEX idx_tpa_name (TPA_NAME)
)
COMMENT = 'Master reference table for valid TPAs (Third Party Administrators). All TPAs must be registered here before processing files. HYBRID TABLE for fast lookups.';

-- Insert default TPAs
MERGE INTO TPA_MASTER t
USING (
    SELECT 'provider_a' AS TPA_CODE, 'Provider A Healthcare' AS TPA_NAME, 'Dental claims provider' AS TPA_DESCRIPTION
    UNION ALL
    SELECT 'provider_b', 'Provider B Insurance', 'Medical claims provider'
    UNION ALL
    SELECT 'provider_c', 'Provider C Medical', 'Medical claims provider'
    UNION ALL
    SELECT 'provider_d', 'Provider D Dental', 'Medical claims provider'
    UNION ALL
    SELECT 'provider_e', 'Provider E Pharmacy', 'Pharmacy claims provider'
) s
ON t.TPA_CODE = s.TPA_CODE
WHEN NOT MATCHED THEN INSERT (TPA_CODE, TPA_NAME, TPA_DESCRIPTION)
    VALUES (s.TPA_CODE, s.TPA_NAME, s.TPA_DESCRIPTION);

-- ============================================
-- CREATE RAW DATA TABLE (STANDARD WITH CLUSTERING)
-- ============================================
-- Using STANDARD TABLE with clustering for large-scale data storage
-- This table will grow to millions of rows, so standard table with clustering is optimal

CREATE TABLE IF NOT EXISTS RAW_DATA_TABLE (
    RECORD_ID NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    FILE_NAME VARCHAR(500) NOT NULL,
    FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
    TPA VARCHAR(500) NOT NULL,  -- REQUIRED: Extracted from file path
    RAW_DATA VARIANT NOT NULL,
    FILE_TYPE VARCHAR(50),
    LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    LOADED_BY VARCHAR(500) DEFAULT CURRENT_USER(),
    CONSTRAINT uk_file_row UNIQUE (FILE_NAME, FILE_ROW_NUMBER)
)
CLUSTER BY (TPA, FILE_NAME, LOAD_TIMESTAMP)
COMMENT = 'Raw data storage table. Each row represents one record from a source file, stored as VARIANT (JSON). TPA is extracted from file path during ingestion. STANDARD TABLE with clustering for large-scale storage.';

-- ============================================
-- CREATE FILE PROCESSING QUEUE (HYBRID)
-- ============================================
-- Using HYBRID TABLE for fast status lookups and frequent updates
-- Hybrid tables support indexes for efficient filtering by status, TPA, and file_name

CREATE HYBRID TABLE IF NOT EXISTS file_processing_queue (
    queue_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    file_name VARCHAR(500) NOT NULL UNIQUE,
    tpa VARCHAR(500) NOT NULL,  -- TPA from file path
    file_type VARCHAR(50),
    file_size_bytes NUMBER(38,0),
    status VARCHAR(50) DEFAULT 'PENDING',  -- PENDING, PROCESSING, SUCCESS, FAILED
    discovered_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    processed_timestamp TIMESTAMP_NTZ,
    error_message VARCHAR(5000),
    process_result VARCHAR(5000),
    retry_count NUMBER(38,0) DEFAULT 0,
    INDEX idx_queue_status (status),
    INDEX idx_queue_tpa (tpa),
    INDEX idx_queue_status_tpa (status, tpa),
    INDEX idx_queue_discovered (discovered_timestamp)
)
COMMENT = 'File processing queue. Tracks status of each file from discovery to completion. Status values: PENDING, PROCESSING, SUCCESS, FAILED. HYBRID TABLE for fast status queries and updates.';

-- ============================================
-- CREATE VIEWS FOR MONITORING
-- ============================================

-- View: Processing Status Summary
CREATE OR REPLACE VIEW v_processing_status_summary AS
SELECT 
    status,
    tpa,
    COUNT(*) as file_count,
    SUM(file_size_bytes) as total_bytes,
    MIN(discovered_timestamp) as oldest_file,
    MAX(discovered_timestamp) as newest_file
FROM file_processing_queue
GROUP BY status, tpa
ORDER BY status, tpa;

COMMENT ON VIEW v_processing_status_summary IS 'Summary of file processing status by TPA. Shows file counts, total bytes, and timestamp ranges for each status.';

-- View: Recent Processing Activity
CREATE OR REPLACE VIEW v_recent_processing_activity AS
SELECT 
    queue_id,
    file_name,
    tpa,
    file_type,
    status,
    discovered_timestamp,
    processed_timestamp,
    DATEDIFF('second', discovered_timestamp, COALESCE(processed_timestamp, CURRENT_TIMESTAMP())) as processing_duration_seconds,
    error_message,
    retry_count
FROM file_processing_queue
ORDER BY discovered_timestamp DESC
LIMIT 100;

COMMENT ON VIEW v_recent_processing_activity IS 'Recent file processing activity (last 100 files). Shows processing duration, status, and errors.';

-- View: Failed Files
CREATE OR REPLACE VIEW v_failed_files AS
SELECT 
    queue_id,
    file_name,
    tpa,
    file_type,
    discovered_timestamp,
    processed_timestamp,
    error_message,
    retry_count
FROM file_processing_queue
WHERE status = 'FAILED'
ORDER BY processed_timestamp DESC;

COMMENT ON VIEW v_failed_files IS 'All failed files with error messages. Use for troubleshooting and reprocessing.';

-- View: Raw Data Statistics
CREATE OR REPLACE VIEW v_raw_data_statistics AS
SELECT 
    TPA,
    FILE_TYPE,
    COUNT(*) as record_count,
    COUNT(DISTINCT FILE_NAME) as file_count,
    MIN(LOAD_TIMESTAMP) as first_load,
    MAX(LOAD_TIMESTAMP) as last_load
FROM RAW_DATA_TABLE
GROUP BY TPA, FILE_TYPE
ORDER BY TPA, FILE_TYPE;

COMMENT ON VIEW v_raw_data_statistics IS 'Statistics on raw data by TPA and file type. Shows record counts, file counts, and load timestamps.';

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

-- Grant permissions on stages
GRANT ALL ON STAGE SRC TO ROLE IDENTIFIER($role_admin);
GRANT ALL ON STAGE COMPLETED TO ROLE IDENTIFIER($role_admin);
GRANT ALL ON STAGE ERROR TO ROLE IDENTIFIER($role_admin);
GRANT ALL ON STAGE ARCHIVE TO ROLE IDENTIFIER($role_admin);

-- Grant permissions on tables
GRANT ALL ON TABLE TPA_MASTER TO ROLE IDENTIFIER($role_admin);
GRANT ALL ON TABLE RAW_DATA_TABLE TO ROLE IDENTIFIER($role_admin);
GRANT ALL ON TABLE file_processing_queue TO ROLE IDENTIFIER($role_admin);

-- Grant permissions on views
GRANT SELECT ON VIEW v_processing_status_summary TO ROLE IDENTIFIER($role_admin);
GRANT SELECT ON VIEW v_recent_processing_activity TO ROLE IDENTIFIER($role_admin);
GRANT SELECT ON VIEW v_failed_files TO ROLE IDENTIFIER($role_admin);
GRANT SELECT ON VIEW v_raw_data_statistics TO ROLE IDENTIFIER($role_admin);

-- ============================================
-- VERIFICATION
-- ============================================

-- Show created objects
SHOW STAGES IN SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);
SHOW TABLES IN SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);
SHOW VIEWS IN SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);

-- Display success message
SELECT 'Bronze schema and tables created successfully' AS status,
       (SELECT COUNT(*) FROM TPA_MASTER) AS tpa_count,
       (SELECT COUNT(*) FROM RAW_DATA_TABLE) AS raw_data_count,
       (SELECT COUNT(*) FROM file_processing_queue) AS queue_count;
