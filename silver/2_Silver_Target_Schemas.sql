-- ============================================
-- SILVER LAYER TARGET SCHEMA MANAGEMENT
-- ============================================
-- Purpose: Procedures for managing target table schemas
-- 
-- This script creates procedures for:
--   1. Creating Silver tables from metadata
--   2. Adding columns dynamically
--   3. Retrieving schema definitions
--   4. Validating schemas
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';

SET role_admin = $DATABASE_NAME || '_ADMIN';

USE ROLE IDENTIFIER($role_admin);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- ============================================
-- PROCEDURE: Create Silver Table from Metadata
-- ============================================

CREATE OR REPLACE PROCEDURE create_silver_table(table_name VARCHAR, tpa VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    full_table_name VARCHAR;
    create_sql VARCHAR;
    column_defs VARCHAR DEFAULT '';
    result_msg VARCHAR;
BEGIN
    -- Build full table name with TPA prefix
    full_table_name := UPPER(:tpa) || '_' || UPPER(:table_name);
    
    -- Build column definitions from target_schemas
    FOR COL_RECORD IN (
        SELECT 
            COLUMN_NAME,
            DATA_TYPE,
            NULLABLE,
            DEFAULT_VALUE
        FROM target_schemas
        WHERE table_name = UPPER(:table_name)
          AND tpa = :tpa
          AND active = TRUE
        ORDER BY schema_id
    ) DO
        IF (column_defs != '') THEN
            column_defs := column_defs || ', ';
        END IF;
        
        column_defs := column_defs || COL_RECORD.COLUMN_NAME || ' ' || COL_RECORD.DATA_TYPE;
        
        IF (NOT COL_RECORD.NULLABLE) THEN
            column_defs := column_defs || ' NOT NULL';
        END IF;
        
        IF (COL_RECORD.DEFAULT_VALUE IS NOT NULL) THEN
            column_defs := column_defs || ' DEFAULT ' || COL_RECORD.DEFAULT_VALUE;
        END IF;
    END FOR;
    
    IF (column_defs = '') THEN
        RETURN 'ERROR: No columns defined for table ' || :table_name || ' and TPA ' || :tpa;
    END IF;
    
    -- Add standard metadata columns
    column_defs := column_defs || ', _BATCH_ID VARCHAR(100)';
    column_defs := column_defs || ', _LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()';
    column_defs := column_defs || ', _LOADED_BY VARCHAR(500) DEFAULT CURRENT_USER()';
    
    -- Create table
    create_sql := 'CREATE TABLE IF NOT EXISTS ' || full_table_name || ' (' || column_defs || ')';
    EXECUTE IMMEDIATE :create_sql;
    
    result_msg := 'Successfully created table: ' || full_table_name;
    RETURN result_msg;
END;
$$;

-- ============================================
-- PROCEDURE: Get Target Schema
-- ============================================

CREATE OR REPLACE PROCEDURE get_target_schema(table_name VARCHAR, tpa VARCHAR)
RETURNS TABLE (column_name VARCHAR, data_type VARCHAR, nullable BOOLEAN, description VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    result RESULTSET;
BEGIN
    result := (
        SELECT 
            column_name,
            data_type,
            nullable,
            description
        FROM target_schemas
        WHERE table_name = UPPER(:table_name)
          AND tpa = :tpa
          AND active = TRUE
        ORDER BY schema_id
    );
    
    RETURN TABLE(result);
END;
$$;

-- ============================================
-- PROCEDURE: Get Approved Mappings
-- ============================================

CREATE OR REPLACE PROCEDURE get_approved_mappings(target_table VARCHAR, tpa VARCHAR)
RETURNS TABLE (source_field VARCHAR, target_column VARCHAR, transformation_logic VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    result RESULTSET;
BEGIN
    result := (
        SELECT 
            source_field,
            target_column,
            transformation_logic
        FROM field_mappings
        WHERE target_table = UPPER(:target_table)
          AND tpa = :tpa
          AND approved = TRUE
          AND active = TRUE
        ORDER BY mapping_id
    );
    
    RETURN TABLE(result);
END;
$$;

-- ============================================
-- VERIFICATION
-- ============================================

SHOW PROCEDURES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

SELECT 'Silver target schema procedures created successfully' AS status;
