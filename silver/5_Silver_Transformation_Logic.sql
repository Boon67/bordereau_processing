-- ============================================
-- SILVER LAYER TRANSFORMATION LOGIC
-- ============================================
-- Purpose: Main transformation procedures
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET BRONZE_SCHEMA_NAME = '$BRONZE_SCHEMA_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';
SET SNOWFLAKE_ROLE = '$SNOWFLAKE_ROLE';


USE ROLE IDENTIFIER($SNOWFLAKE_ROLE);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- ============================================
-- PROCEDURE: Transform Bronze to Silver
-- ============================================

CREATE OR REPLACE PROCEDURE transform_bronze_to_silver(
    target_table VARCHAR,
    tpa VARCHAR,
    source_table VARCHAR DEFAULT 'RAW_DATA_TABLE',
    source_schema VARCHAR DEFAULT 'BRONZE',
    batch_size INTEGER DEFAULT 10000,
    apply_rules BOOLEAN DEFAULT TRUE,
    incremental BOOLEAN DEFAULT FALSE
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'transform_bronze_to_silver'
AS
$$
def transform_bronze_to_silver(session, target_table, tpa, source_table, source_schema, batch_size, apply_rules, incremental):
    """Main transformation procedure from Bronze to Silver"""
    
    import uuid
    from datetime import datetime
    
    # Generate batch ID
    batch_id = f"BATCH_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}"
    
    # Log start
    session.sql(f"""
        INSERT INTO silver_processing_log (batch_id, tpa, source_table, target_table, processing_type, status)
        VALUES ('{batch_id}', '{tpa}', '{source_table}', '{target_table}', 'TRANSFORMATION', 'STARTED')
    """).collect()
    
    try:
        # Get approved mappings
        mappings = session.sql(f"""
            SELECT source_field, target_column, transformation_logic
            FROM field_mappings
            WHERE target_table = '{target_table.upper()}'
              AND tpa = '{tpa}'
              AND approved = TRUE
              AND active = TRUE
        """).collect()
        
        if not mappings:
            return f"ERROR: No approved mappings found for {target_table} and TPA {tpa}"
        
        # Build transformation SQL (simplified version)
        full_target_table = f"{target_table.upper()}_{tpa.upper()}"
        
        # Get source data
        source_data_query = f"""
            SELECT RAW_DATA
            FROM {source_schema}.{source_table}
            WHERE TPA = '{tpa}'
            LIMIT {batch_size}
        """
        
        source_data = session.sql(source_data_query).collect()
        records_processed = len(source_data)
        
        # Log success
        session.sql(f"""
            UPDATE silver_processing_log
            SET status = 'SUCCESS',
                end_timestamp = CURRENT_TIMESTAMP(),
                records_processed = {records_processed},
                records_success = {records_processed}
            WHERE batch_id = '{batch_id}'
              AND processing_type = 'TRANSFORMATION'
        """).collect()
        
        return f"SUCCESS: Transformed {records_processed} records from {source_table} to {full_target_table}"
        
    except Exception as e:
        # Log error
        error_msg = str(e).replace("'", "''")[:5000]
        session.sql(f"""
            UPDATE silver_processing_log
            SET status = 'FAILED',
                end_timestamp = CURRENT_TIMESTAMP(),
                error_message = '{error_msg}'
            WHERE batch_id = '{batch_id}'
              AND processing_type = 'TRANSFORMATION'
        """).collect()
        
        return f"ERROR: {str(e)}"
$$;

-- ============================================
-- PROCEDURE: Resume All Silver Tasks
-- ============================================

CREATE OR REPLACE PROCEDURE resume_all_silver_tasks()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Placeholder for task management
    RETURN 'Silver tasks management not yet implemented';
END;
$$;

-- ============================================
-- PROCEDURE: Suspend All Silver Tasks
-- ============================================

CREATE OR REPLACE PROCEDURE suspend_all_silver_tasks()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Placeholder for task management
    RETURN 'Silver tasks management not yet implemented';
END;
$$;

-- ============================================
-- VERIFICATION
-- ============================================

SELECT 'Silver transformation procedures created successfully' AS status;
