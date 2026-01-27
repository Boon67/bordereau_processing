-- ============================================
-- LOGGING SYSTEM SETUP
-- ============================================
-- Purpose: Create hybrid tables for application-wide logging
-- 
-- This script creates:
--   1. APPLICATION_LOGS - General application logs
--   2. TASK_EXECUTION_LOGS - Task-specific execution logs
--   3. FILE_PROCESSING_LOGS - Detailed file processing logs
--   4. API_REQUEST_LOGS - API endpoint request/response logs
--   5. ERROR_LOGS - Detailed error tracking
--
-- All tables use hybrid table format for fast transactional access
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET BRONZE_SCHEMA_NAME = '$BRONZE_SCHEMA_NAME';
SET SNOWFLAKE_ROLE = '$SNOWFLAKE_ROLE';

USE ROLE IDENTIFIER($SNOWFLAKE_ROLE);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($BRONZE_SCHEMA_NAME);

-- ============================================
-- TABLE 1: APPLICATION_LOGS (General Logging)
-- ============================================

CREATE HYBRID TABLE IF NOT EXISTS APPLICATION_LOGS (
    LOG_ID INTEGER AUTOINCREMENT PRIMARY KEY,
    LOG_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    LOG_LEVEL VARCHAR(20) NOT NULL,  -- DEBUG, INFO, WARNING, ERROR, CRITICAL
    LOG_SOURCE VARCHAR(100) NOT NULL,  -- Component/module name
    LOG_MESSAGE TEXT NOT NULL,
    LOG_DETAILS VARIANT,  -- JSON details
    USER_NAME VARCHAR(100),
    SESSION_ID VARCHAR(100),
    TPA_CODE VARCHAR(50),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    INDEX idx_timestamp (LOG_TIMESTAMP),
    INDEX idx_level (LOG_LEVEL),
    INDEX idx_source (LOG_SOURCE)
) COMMENT = 'General application logs for all components';

-- ============================================
-- TABLE 2: TASK_EXECUTION_LOGS
-- ============================================

CREATE HYBRID TABLE IF NOT EXISTS TASK_EXECUTION_LOGS (
    EXECUTION_ID INTEGER AUTOINCREMENT PRIMARY KEY,
    TASK_NAME VARCHAR(200) NOT NULL,
    EXECUTION_START TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    EXECUTION_END TIMESTAMP_NTZ,
    EXECUTION_STATUS VARCHAR(50),  -- STARTED, RUNNING, SUCCESS, FAILED, SKIPPED
    EXECUTION_DURATION_MS INTEGER,
    RECORDS_PROCESSED INTEGER DEFAULT 0,
    RECORDS_FAILED INTEGER DEFAULT 0,
    ERROR_MESSAGE TEXT,
    EXECUTION_DETAILS VARIANT,  -- JSON with additional context
    WAREHOUSE_USED VARCHAR(100),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    INDEX idx_task_name (TASK_NAME),
    INDEX idx_execution_start (EXECUTION_START),
    INDEX idx_status (EXECUTION_STATUS)
) COMMENT = 'Logs for Snowflake task executions';

-- ============================================
-- TABLE 3: FILE_PROCESSING_LOGS
-- ============================================

CREATE HYBRID TABLE IF NOT EXISTS FILE_PROCESSING_LOGS (
    PROCESSING_LOG_ID INTEGER AUTOINCREMENT PRIMARY KEY,
    QUEUE_ID INTEGER,  -- FK to file_processing_queue
    FILE_NAME VARCHAR(500) NOT NULL,
    TPA_CODE VARCHAR(50),
    PROCESSING_STAGE VARCHAR(50) NOT NULL,  -- DISCOVERY, VALIDATION, PARSING, LOADING, MOVING
    STAGE_STATUS VARCHAR(50) NOT NULL,  -- STARTED, SUCCESS, FAILED, SKIPPED
    STAGE_START TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    STAGE_END TIMESTAMP_NTZ,
    STAGE_DURATION_MS INTEGER,
    ROWS_PROCESSED INTEGER DEFAULT 0,
    ROWS_FAILED INTEGER DEFAULT 0,
    ERROR_MESSAGE TEXT,
    STAGE_DETAILS VARIANT,  -- JSON with stage-specific details
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    INDEX idx_queue_id (QUEUE_ID),
    INDEX idx_file_name (FILE_NAME),
    INDEX idx_stage (PROCESSING_STAGE),
    INDEX idx_status (STAGE_STATUS)
) COMMENT = 'Detailed logs for file processing pipeline stages';

-- ============================================
-- TABLE 4: API_REQUEST_LOGS
-- ============================================

CREATE HYBRID TABLE IF NOT EXISTS API_REQUEST_LOGS (
    REQUEST_ID INTEGER AUTOINCREMENT PRIMARY KEY,
    REQUEST_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    REQUEST_METHOD VARCHAR(10) NOT NULL,  -- GET, POST, PUT, DELETE
    REQUEST_PATH VARCHAR(500) NOT NULL,
    REQUEST_PARAMS VARIANT,  -- JSON query parameters
    REQUEST_BODY VARIANT,  -- JSON request body
    RESPONSE_STATUS INTEGER,  -- HTTP status code
    RESPONSE_TIME_MS INTEGER,
    RESPONSE_BODY VARIANT,  -- JSON response (truncated if large)
    ERROR_MESSAGE TEXT,
    USER_NAME VARCHAR(100),
    CLIENT_IP VARCHAR(50),
    USER_AGENT VARCHAR(500),
    TPA_CODE VARCHAR(50),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    INDEX idx_timestamp (REQUEST_TIMESTAMP),
    INDEX idx_path (REQUEST_PATH),
    INDEX idx_status (RESPONSE_STATUS)
) COMMENT = 'Logs for API endpoint requests and responses';

-- ============================================
-- TABLE 5: ERROR_LOGS (Detailed Error Tracking)
-- ============================================

CREATE HYBRID TABLE IF NOT EXISTS ERROR_LOGS (
    ERROR_ID INTEGER AUTOINCREMENT PRIMARY KEY,
    ERROR_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    ERROR_LEVEL VARCHAR(20) NOT NULL,  -- ERROR, CRITICAL
    ERROR_SOURCE VARCHAR(100) NOT NULL,  -- Component/module
    ERROR_TYPE VARCHAR(100),  -- Exception type
    ERROR_MESSAGE TEXT NOT NULL,
    ERROR_STACK_TRACE TEXT,
    ERROR_CONTEXT VARIANT,  -- JSON with context (file, line, function, etc.)
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
) COMMENT = 'Detailed error tracking and resolution management';

-- ============================================
-- LOGGING PROCEDURES
-- ============================================

-- Procedure: Log Application Event
CREATE OR REPLACE PROCEDURE log_application_event(
    p_level VARCHAR,
    p_source VARCHAR,
    p_message TEXT,
    p_details VARIANT,
    p_user_name VARCHAR,
    p_tpa_code VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO APPLICATION_LOGS (
        LOG_LEVEL,
        LOG_SOURCE,
        LOG_MESSAGE,
        LOG_DETAILS,
        USER_NAME,
        TPA_CODE
    ) VALUES (
        p_level,
        p_source,
        p_message,
        p_details,
        p_user_name,
        p_tpa_code
    );
    
    RETURN 'Log entry created';
END;
$$;

-- Procedure: Log Task Execution Start
CREATE OR REPLACE PROCEDURE log_task_start(
    p_task_name VARCHAR,
    p_warehouse VARCHAR
)
RETURNS INTEGER
LANGUAGE SQL
AS
$$
DECLARE
    v_execution_id INTEGER;
BEGIN
    INSERT INTO TASK_EXECUTION_LOGS (
        TASK_NAME,
        EXECUTION_STATUS,
        WAREHOUSE_USED
    ) VALUES (
        p_task_name,
        'STARTED',
        p_warehouse
    );
    
    v_execution_id := (SELECT MAX(EXECUTION_ID) FROM TASK_EXECUTION_LOGS WHERE TASK_NAME = p_task_name);
    
    RETURN v_execution_id;
END;
$$;

-- Procedure: Log Task Execution End
CREATE OR REPLACE PROCEDURE log_task_end(
    p_execution_id INTEGER,
    p_status VARCHAR,
    p_records_processed INTEGER,
    p_records_failed INTEGER,
    p_error_message TEXT,
    p_details VARIANT
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_duration INTEGER;
BEGIN
    UPDATE TASK_EXECUTION_LOGS
    SET 
        EXECUTION_END = CURRENT_TIMESTAMP(),
        EXECUTION_STATUS = p_status,
        EXECUTION_DURATION_MS = DATEDIFF(MILLISECOND, EXECUTION_START, CURRENT_TIMESTAMP()),
        RECORDS_PROCESSED = p_records_processed,
        RECORDS_FAILED = p_records_failed,
        ERROR_MESSAGE = p_error_message,
        EXECUTION_DETAILS = p_details
    WHERE EXECUTION_ID = p_execution_id;
    
    RETURN 'Task execution logged';
END;
$$;

-- Procedure: Log File Processing Stage
CREATE OR REPLACE PROCEDURE log_file_processing_stage(
    p_queue_id INTEGER,
    p_file_name VARCHAR,
    p_tpa_code VARCHAR,
    p_stage VARCHAR,
    p_status VARCHAR,
    p_rows_processed INTEGER,
    p_rows_failed INTEGER,
    p_error_message TEXT,
    p_details VARIANT
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO FILE_PROCESSING_LOGS (
        QUEUE_ID,
        FILE_NAME,
        TPA_CODE,
        PROCESSING_STAGE,
        STAGE_STATUS,
        STAGE_END,
        ROWS_PROCESSED,
        ROWS_FAILED,
        ERROR_MESSAGE,
        STAGE_DETAILS
    ) VALUES (
        p_queue_id,
        p_file_name,
        p_tpa_code,
        p_stage,
        p_status,
        CURRENT_TIMESTAMP(),
        p_rows_processed,
        p_rows_failed,
        p_error_message,
        p_details
    );
    
    RETURN 'File processing stage logged';
END;
$$;

-- Procedure: Log Error
CREATE OR REPLACE PROCEDURE log_error(
    p_source VARCHAR,
    p_error_type VARCHAR,
    p_error_message TEXT,
    p_stack_trace TEXT,
    p_context VARIANT,
    p_user_name VARCHAR,
    p_tpa_code VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO ERROR_LOGS (
        ERROR_LEVEL,
        ERROR_SOURCE,
        ERROR_TYPE,
        ERROR_MESSAGE,
        ERROR_STACK_TRACE,
        ERROR_CONTEXT,
        USER_NAME,
        TPA_CODE
    ) VALUES (
        'ERROR',
        p_source,
        p_error_type,
        p_error_message,
        p_stack_trace,
        p_context,
        p_user_name,
        p_tpa_code
    );
    
    RETURN 'Error logged';
END;
$$;

-- ============================================
-- VIEWS FOR EASY QUERYING
-- ============================================

-- View: Recent Application Logs
CREATE OR REPLACE VIEW V_RECENT_APPLICATION_LOGS AS
SELECT 
    LOG_ID,
    LOG_TIMESTAMP,
    LOG_LEVEL,
    LOG_SOURCE,
    LOG_MESSAGE,
    USER_NAME,
    TPA_CODE
FROM APPLICATION_LOGS
WHERE LOG_TIMESTAMP >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY LOG_TIMESTAMP DESC;

-- View: Recent Task Executions
CREATE OR REPLACE VIEW V_RECENT_TASK_EXECUTIONS AS
SELECT 
    EXECUTION_ID,
    TASK_NAME,
    EXECUTION_START,
    EXECUTION_END,
    EXECUTION_STATUS,
    EXECUTION_DURATION_MS,
    RECORDS_PROCESSED,
    RECORDS_FAILED,
    ERROR_MESSAGE
FROM TASK_EXECUTION_LOGS
WHERE EXECUTION_START >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY EXECUTION_START DESC;

-- View: Recent Errors
CREATE OR REPLACE VIEW V_RECENT_ERRORS AS
SELECT 
    ERROR_ID,
    ERROR_TIMESTAMP,
    ERROR_SOURCE,
    ERROR_TYPE,
    ERROR_MESSAGE,
    RESOLUTION_STATUS,
    USER_NAME,
    TPA_CODE
FROM ERROR_LOGS
WHERE ERROR_TIMESTAMP >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY ERROR_TIMESTAMP DESC;

-- View: File Processing Summary
CREATE OR REPLACE VIEW V_FILE_PROCESSING_SUMMARY AS
SELECT 
    FILE_NAME,
    TPA_CODE,
    COUNT(*) as TOTAL_STAGES,
    SUM(CASE WHEN STAGE_STATUS = 'SUCCESS' THEN 1 ELSE 0 END) as SUCCESSFUL_STAGES,
    SUM(CASE WHEN STAGE_STATUS = 'FAILED' THEN 1 ELSE 0 END) as FAILED_STAGES,
    MAX(STAGE_END) as LAST_STAGE_TIME,
    SUM(ROWS_PROCESSED) as TOTAL_ROWS_PROCESSED,
    SUM(ROWS_FAILED) as TOTAL_ROWS_FAILED
FROM FILE_PROCESSING_LOGS
WHERE STAGE_START >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
GROUP BY FILE_NAME, TPA_CODE
ORDER BY LAST_STAGE_TIME DESC;

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

-- Grant access to logging tables
GRANT SELECT, INSERT, UPDATE ON APPLICATION_LOGS TO ROLE IDENTIFIER($SNOWFLAKE_ROLE);
GRANT SELECT, INSERT, UPDATE ON TASK_EXECUTION_LOGS TO ROLE IDENTIFIER($SNOWFLAKE_ROLE);
GRANT SELECT, INSERT, UPDATE ON FILE_PROCESSING_LOGS TO ROLE IDENTIFIER($SNOWFLAKE_ROLE);
GRANT SELECT, INSERT, UPDATE ON API_REQUEST_LOGS TO ROLE IDENTIFIER($SNOWFLAKE_ROLE);
GRANT SELECT, INSERT, UPDATE ON ERROR_LOGS TO ROLE IDENTIFIER($SNOWFLAKE_ROLE);

-- Grant access to views
GRANT SELECT ON V_RECENT_APPLICATION_LOGS TO ROLE IDENTIFIER($SNOWFLAKE_ROLE);
GRANT SELECT ON V_RECENT_TASK_EXECUTIONS TO ROLE IDENTIFIER($SNOWFLAKE_ROLE);
GRANT SELECT ON V_RECENT_ERRORS TO ROLE IDENTIFIER($SNOWFLAKE_ROLE);
GRANT SELECT ON V_FILE_PROCESSING_SUMMARY TO ROLE IDENTIFIER($SNOWFLAKE_ROLE);

-- ============================================
-- VERIFICATION
-- ============================================

SHOW TABLES LIKE '%LOGS';
SHOW VIEWS LIKE 'V_%';

SELECT 'Logging system created successfully' AS status,
       'All log tables, procedures, and views are ready' AS note;
