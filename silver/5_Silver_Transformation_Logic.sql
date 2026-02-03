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
    import json
    
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
            # Log error
            session.sql(f"""
                UPDATE silver_processing_log
                SET status = 'FAILED',
                    end_timestamp = CURRENT_TIMESTAMP(),
                    error_message = 'No approved mappings found for {target_table} and TPA {tpa}'
                WHERE batch_id = '{batch_id}'
                  AND processing_type = 'TRANSFORMATION'
            """).collect()
            return f"ERROR: No approved mappings found for {target_table} and TPA {tpa}"
        
        # Build mapping dictionary
        mapping_dict = {}
        for row in mappings:
            mapping_dict[row['SOURCE_FIELD']] = {
                'target_column': row['TARGET_COLUMN'],
                'transformation_logic': row['TRANSFORMATION_LOGIC']
            }
        
        # Build full target table name (TPA_TABLENAME format)
        full_target_table = f"{tpa.upper()}_{target_table.upper()}"
        
        # Build column list for MERGE
        target_columns = [m['TARGET_COLUMN'] for m in mappings]
        
        # Build SELECT statement with field mappings
        select_parts = []
        for row in mappings:
            source_field = row['SOURCE_FIELD']
            transformation = row['TRANSFORMATION_LOGIC']
            
            # If transformation logic exists, use it; otherwise, direct mapping
            if transformation and transformation.strip():
                # For now, just use direct mapping - transformation logic can be enhanced later
                select_parts.append(f"RAW_DATA:{source_field}::VARCHAR AS {row['TARGET_COLUMN']}")
            else:
                select_parts.append(f"RAW_DATA:{source_field}::VARCHAR AS {row['TARGET_COLUMN']}")
        
        select_str = ',\n            '.join(select_parts)
        
        # Build column list strings for MERGE statement
        columns_str = ', '.join(target_columns)
        update_set_parts = [f"{col} = source.{col}" for col in target_columns]
        update_set_str = ',\n                '.join(update_set_parts)
        insert_columns_str = ', '.join(['_RECORD_ID', '_FILE_NAME', '_FILE_ROW_NUMBER'] + target_columns + ['_TPA', '_BATCH_ID', '_LOAD_TIMESTAMP', '_LOADED_BY'])
        insert_values_str = ', '.join(['source._RECORD_ID', 'source._FILE_NAME', 'source._FILE_ROW_NUMBER'] + [f'source.{col}' for col in target_columns] + ['source._TPA', 'source._BATCH_ID', 'source._LOAD_TIMESTAMP', 'source._LOADED_BY'])
        
        # Build and execute MERGE statement
        merge_query = f"""
            MERGE INTO {full_target_table} AS target
            USING (
                SELECT 
                    RECORD_ID AS _RECORD_ID,
                    FILE_NAME AS _FILE_NAME,
                    FILE_ROW_NUMBER AS _FILE_ROW_NUMBER,
                    {select_str},
                    '{tpa}' AS _TPA,
                    '{batch_id}' AS _BATCH_ID,
                    CURRENT_TIMESTAMP() AS _LOAD_TIMESTAMP,
                    CURRENT_USER() AS _LOADED_BY
                FROM {source_schema}.{source_table}
                WHERE TPA = '{tpa}'
                  AND RAW_DATA IS NOT NULL
                LIMIT {batch_size}
            ) AS source
            ON target._RECORD_ID = source._RECORD_ID
            WHEN MATCHED THEN
                UPDATE SET
                {update_set_str},
                _FILE_NAME = source._FILE_NAME,
                _FILE_ROW_NUMBER = source._FILE_ROW_NUMBER,
                _BATCH_ID = source._BATCH_ID,
                _LOAD_TIMESTAMP = source._LOAD_TIMESTAMP,
                _LOADED_BY = source._LOADED_BY
            WHEN NOT MATCHED THEN
                INSERT ({insert_columns_str})
                VALUES ({insert_values_str})
        """
        
        # Execute transformation
        merge_result = session.sql(merge_query).collect()
        
        # Get the number of rows affected from the merge result
        # MERGE returns a Row object with columns like 'number of rows inserted', 'number of rows updated'
        records_processed = 0
        if merge_result and len(merge_result) > 0:
            result_row = merge_result[0]
            # Try to access as dictionary keys (case-insensitive)
            try:
                rows_inserted = result_row['number of rows inserted'] if 'number of rows inserted' in result_row else (result_row['NUMBER OF ROWS INSERTED'] if 'NUMBER OF ROWS INSERTED' in result_row else 0)
                rows_updated = result_row['number of rows updated'] if 'number of rows updated' in result_row else (result_row['NUMBER OF ROWS UPDATED'] if 'NUMBER OF ROWS UPDATED' in result_row else 0)
                records_processed = rows_inserted + rows_updated
            except (KeyError, TypeError):
                # If we can't get the counts, just set to 0
                records_processed = 0
        
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
        
        return f"SUCCESS: Merged {records_processed} records from {source_table} to {full_target_table} (inserted/updated)"
        
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
