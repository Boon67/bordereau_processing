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
SET SNOWFLAKE_ROLE = '$SNOWFLAKE_ROLE';

USE ROLE IDENTIFIER($SNOWFLAKE_ROLE);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- ============================================
-- PROCEDURE: Create Silver Table from Metadata
-- ============================================

CREATE OR REPLACE PROCEDURE create_silver_table(table_name VARCHAR, tpa VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'create_silver_table'
AS
$$
def create_silver_table(session, table_name, tpa):
    """Create a Silver table from schema metadata"""
    
    table_name_upper = table_name.upper()
    tpa_upper = tpa.upper()
    full_table_name = f"{tpa_upper}_{table_name_upper}"
    
    # Get column definitions from target_schemas (TPA-agnostic)
    query = f"""
        SELECT 
            COLUMN_NAME,
            DATA_TYPE,
            NULLABLE,
            DEFAULT_VALUE
        FROM target_schemas
        WHERE table_name = '{table_name_upper}'
          AND active = TRUE
        ORDER BY schema_id
    """
    
    columns = session.sql(query).collect()
    
    if not columns:
        return f"ERROR: No columns defined for table {table_name}"
    
    # Build column definitions
    column_defs = []
    for col in columns:
        col_def = f"{col['COLUMN_NAME']} {col['DATA_TYPE']}"
        
        if not col['NULLABLE']:
            col_def += " NOT NULL"
        
        if col['DEFAULT_VALUE']:
            default_val = col['DEFAULT_VALUE']
            # Check if it's a function call (contains parentheses) or a number
            if '(' in default_val or default_val.replace('.', '').replace('-', '').isdigit():
                col_def += f" DEFAULT {default_val}"
            else:
                # It's a string literal, needs quotes
                col_def += f" DEFAULT '{default_val}'"
        
        column_defs.append(col_def)
    
    # Add metadata columns
    column_defs.append(f"_TPA VARCHAR(100) DEFAULT '{tpa}'")
    column_defs.append("_BATCH_ID VARCHAR(100)")
    column_defs.append("_LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()")
    column_defs.append("_LOADED_BY VARCHAR(500) DEFAULT CURRENT_USER()")
    
    # Create table
    create_sql = f"CREATE TABLE IF NOT EXISTS {full_table_name} ({', '.join(column_defs)})"
    session.sql(create_sql).collect()
    
    # Track the created table
    tracking_sql = f"""
        INSERT INTO created_tables (physical_table_name, schema_table_name, tpa, description)
        SELECT '{full_table_name}', '{table_name_upper}', '{tpa}', 
               'Created from schema: {table_name_upper} for TPA: {tpa}'
        WHERE NOT EXISTS (
            SELECT 1 FROM created_tables WHERE physical_table_name = '{full_table_name}'
        )
    """
    session.sql(tracking_sql).collect()
    
    return f"Successfully created table: {full_table_name} ({len(columns)} columns + 4 metadata columns)"
$$;

-- ============================================
-- PROCEDURE: Get Target Schema
-- ============================================

CREATE OR REPLACE PROCEDURE get_target_schema(table_name VARCHAR)
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

-- SHOW PROCEDURES IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

SELECT 'Silver target schema procedures created successfully' AS status;
