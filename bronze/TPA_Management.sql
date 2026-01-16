-- ============================================
-- TPA MANAGEMENT UTILITIES
-- ============================================
-- Purpose: Manage TPA (Third Party Administrator) master data
-- 
-- This script provides utilities for:
--   - Adding new TPAs
--   - Deactivating TPAs
--   - Viewing TPA statistics
--   - Validating TPA data
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
-- PROCEDURE: Add New TPA
-- ============================================

CREATE OR REPLACE PROCEDURE add_tpa(
    tpa_code VARCHAR,
    tpa_name VARCHAR,
    tpa_description VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    result_msg VARCHAR;
BEGIN
    -- Insert new TPA (or update if exists)
    MERGE INTO TPA_MASTER t
    USING (
        SELECT 
            :tpa_code AS TPA_CODE,
            :tpa_name AS TPA_NAME,
            :tpa_description AS TPA_DESCRIPTION
    ) s
    ON t.TPA_CODE = s.TPA_CODE
    WHEN MATCHED THEN UPDATE SET
        TPA_NAME = s.TPA_NAME,
        TPA_DESCRIPTION = s.TPA_DESCRIPTION,
        UPDATED_TIMESTAMP = CURRENT_TIMESTAMP(),
        ACTIVE = TRUE
    WHEN NOT MATCHED THEN INSERT (TPA_CODE, TPA_NAME, TPA_DESCRIPTION)
        VALUES (s.TPA_CODE, s.TPA_NAME, s.TPA_DESCRIPTION);
    
    result_msg := 'TPA ' || :tpa_code || ' added/updated successfully';
    RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Deactivate TPA
-- ============================================

CREATE OR REPLACE PROCEDURE deactivate_tpa(tpa_code VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    result_msg VARCHAR;
    rows_updated INTEGER;
BEGIN
    UPDATE TPA_MASTER
    SET ACTIVE = FALSE,
        UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()
    WHERE TPA_CODE = :tpa_code;
    
    rows_updated := SQLROWCOUNT;
    
    IF (rows_updated = 0) THEN
        result_msg := 'TPA ' || :tpa_code || ' not found';
    ELSE
        result_msg := 'TPA ' || :tpa_code || ' deactivated successfully';
    END IF;
    
    RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Reactivate TPA
-- ============================================

CREATE OR REPLACE PROCEDURE reactivate_tpa(tpa_code VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    result_msg VARCHAR;
    rows_updated INTEGER;
BEGIN
    UPDATE TPA_MASTER
    SET ACTIVE = TRUE,
        UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()
    WHERE TPA_CODE = :tpa_code;
    
    rows_updated := SQLROWCOUNT;
    
    IF (rows_updated = 0) THEN
        result_msg := 'TPA ' || :tpa_code || ' not found';
    ELSE
        result_msg := 'TPA ' || :tpa_code || ' reactivated successfully';
    END IF;
    
    RETURN result_msg;
END;
$$;

-- ============================================
-- VIEW: TPA Statistics
-- ============================================

CREATE OR REPLACE VIEW v_tpa_statistics AS
SELECT 
    t.TPA_CODE,
    t.TPA_NAME,
    t.TPA_DESCRIPTION,
    t.ACTIVE,
    COUNT(DISTINCT r.FILE_NAME) as file_count,
    COUNT(r.RECORD_ID) as record_count,
    MIN(r.LOAD_TIMESTAMP) as first_load,
    MAX(r.LOAD_TIMESTAMP) as last_load,
    SUM(CASE WHEN q.status = 'SUCCESS' THEN 1 ELSE 0 END) as successful_files,
    SUM(CASE WHEN q.status = 'FAILED' THEN 1 ELSE 0 END) as failed_files,
    SUM(CASE WHEN q.status = 'PENDING' THEN 1 ELSE 0 END) as pending_files
FROM TPA_MASTER t
LEFT JOIN RAW_DATA_TABLE r ON t.TPA_CODE = r.TPA
LEFT JOIN file_processing_queue q ON t.TPA_CODE = q.tpa
GROUP BY t.TPA_CODE, t.TPA_NAME, t.TPA_DESCRIPTION, t.ACTIVE
ORDER BY t.TPA_CODE;

COMMENT ON VIEW v_tpa_statistics IS 'Comprehensive statistics for each TPA including file counts, record counts, and processing status.';

-- ============================================
-- SAMPLE USAGE
-- ============================================

/*
-- Add a new TPA
CALL add_tpa('provider_f', 'Provider F Healthcare', 'Vision claims provider');

-- Deactivate a TPA
CALL deactivate_tpa('provider_f');

-- Reactivate a TPA
CALL reactivate_tpa('provider_f');

-- View TPA statistics
SELECT * FROM v_tpa_statistics;

-- View active TPAs only
SELECT * FROM TPA_MASTER WHERE ACTIVE = TRUE;
*/

-- ============================================
-- VERIFICATION
-- ============================================

-- Show all TPAs
SELECT * FROM TPA_MASTER ORDER BY TPA_CODE;

-- Show TPA statistics
SELECT * FROM v_tpa_statistics;

-- Display success message
SELECT 'TPA management utilities created successfully' AS status;
