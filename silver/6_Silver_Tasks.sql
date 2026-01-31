-- ============================================
-- SILVER LAYER TASKS
-- ============================================
-- Purpose: Task orchestration for automated transformation
-- 
-- This script creates 1 task:
--   1. auto_transform_mappings_task - Run all approved mappings (every 24 hours)
--
-- Task Dependencies:
--   auto_transform_mappings_task (root, scheduled daily)
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================

SET DATABASE_NAME = '$DATABASE_NAME';
SET BRONZE_SCHEMA_NAME = '$BRONZE_SCHEMA_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';
SET WAREHOUSE_NAME = '$SNOWFLAKE_WAREHOUSE';
SET SNOWFLAKE_ROLE = '$SNOWFLAKE_ROLE';

USE ROLE IDENTIFIER($SNOWFLAKE_ROLE);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- ============================================
-- SUSPEND EXISTING TASKS (if any)
-- ============================================

ALTER TASK IF EXISTS auto_transform_mappings_task SUSPEND;

-- ============================================
-- PROCEDURE: Run All Approved Mappings
-- ============================================

CREATE OR REPLACE PROCEDURE run_all_approved_mappings()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_all_approved_mappings'
AS
$$
def run_all_approved_mappings(session):
    """
    Iterate through all approved mappings and run transformations
    Groups by TPA and target_table to run each unique combination
    """
    
    import uuid
    from datetime import datetime
    
    # Generate run ID
    run_id = f"AUTO_TRANSFORM_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}"
    
    results = {
        'run_id': run_id,
        'total_transformations': 0,
        'successful': 0,
        'failed': 0,
        'details': []
    }
    
    try:
        # Get all unique TPA + target_table combinations that have approved mappings
        query = """
            SELECT DISTINCT 
                tpa,
                target_table,
                COUNT(*) as mapping_count
            FROM field_mappings
            WHERE approved = TRUE
              AND active = TRUE
            GROUP BY tpa, target_table
            ORDER BY tpa, target_table
        """
        
        combinations = session.sql(query).collect()
        
        if not combinations:
            return f"No approved mappings found. Run ID: {run_id}"
        
        results['total_transformations'] = len(combinations)
        
        # Iterate through each combination and run transformation
        for combo in combinations:
            tpa = combo['TPA']
            target_table = combo['TARGET_TABLE']
            mapping_count = combo['MAPPING_COUNT']
            
            try:
                # Call the transformation procedure
                transform_query = f"""
                    CALL transform_bronze_to_silver(
                        '{target_table}',
                        '{tpa}',
                        'RAW_DATA_TABLE',
                        'BRONZE',
                        10000,
                        TRUE,
                        FALSE
                    )
                """
                
                result = session.sql(transform_query).collect()
                
                # Extract result message
                if result and len(result) > 0:
                    result_msg = result[0][0] if result[0] else 'Unknown result'
                else:
                    result_msg = 'No result returned'
                
                results['successful'] += 1
                results['details'].append({
                    'tpa': tpa,
                    'target_table': target_table,
                    'mapping_count': mapping_count,
                    'status': 'SUCCESS',
                    'message': result_msg
                })
                
            except Exception as e:
                results['failed'] += 1
                error_msg = str(e)[:500]  # Limit error message length
                results['details'].append({
                    'tpa': tpa,
                    'target_table': target_table,
                    'mapping_count': mapping_count,
                    'status': 'FAILED',
                    'message': error_msg
                })
        
        # Log summary to processing log
        summary = f"Run ID: {run_id} | Total: {results['total_transformations']} | Success: {results['successful']} | Failed: {results['failed']}"
        
        session.sql(f"""
            INSERT INTO silver_processing_log (batch_id, tpa, source_table, target_table, processing_type, status, records_processed)
            VALUES ('{run_id}', 'ALL', 'AUTO_TRANSFORM', 'ALL_TABLES', 'AUTO_TRANSFORMATION', 
                    CASE WHEN {results['failed']} = 0 THEN 'SUCCESS' ELSE 'PARTIAL' END,
                    {results['successful']})
        """).collect()
        
        return summary
        
    except Exception as e:
        error_msg = str(e).replace("'", "''")[:5000]
        
        # Log error
        session.sql(f"""
            INSERT INTO silver_processing_log (batch_id, tpa, source_table, target_table, processing_type, status, error_message)
            VALUES ('{run_id}', 'ALL', 'AUTO_TRANSFORM', 'ALL_TABLES', 'AUTO_TRANSFORMATION', 'FAILED', '{error_msg}')
        """).collect()
        
        return f"ERROR: {str(e)}"
$$;

-- ============================================
-- TASK 1: Auto Transform Mappings (Root Task)
-- ============================================

CREATE OR REPLACE TASK auto_transform_mappings_task
    WAREHOUSE = IDENTIFIER($WAREHOUSE_NAME)
    SCHEDULE = 'USING CRON 0 2 * * * America/New_York'
    COMMENT = 'Automatically run all approved field mappings for all TPAs. Runs daily at 2 AM (configurable).'
AS
CALL run_all_approved_mappings();

-- ============================================
-- VERIFICATION PROCEDURE
-- ============================================

CREATE OR REPLACE PROCEDURE get_auto_transform_status()
RETURNS TABLE (
    run_date DATE,
    total_runs NUMBER,
    successful_runs NUMBER,
    failed_runs NUMBER,
    last_run_time TIMESTAMP_NTZ
)
LANGUAGE SQL
AS
$$
DECLARE
    result RESULTSET;
BEGIN
    result := (
        SELECT 
            DATE(end_timestamp) as run_date,
            COUNT(*) as total_runs,
            SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) as successful_runs,
            SUM(CASE WHEN status IN ('FAILED', 'PARTIAL') THEN 1 ELSE 0 END) as failed_runs,
            MAX(end_timestamp) as last_run_time
        FROM silver_processing_log
        WHERE processing_type = 'AUTO_TRANSFORMATION'
          AND end_timestamp >= DATEADD(day, -30, CURRENT_TIMESTAMP())
        GROUP BY DATE(end_timestamp)
        ORDER BY run_date DESC
    );
    
    RETURN TABLE(result);
END;
$$;

-- ============================================
-- HELPER PROCEDURE: Manual Run
-- ============================================

CREATE OR REPLACE PROCEDURE run_transformations_manual(
    tpa_filter VARCHAR DEFAULT 'ALL',
    table_filter VARCHAR DEFAULT 'ALL'
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_transformations_manual'
AS
$$
def run_transformations_manual(session, tpa_filter, table_filter):
    """
    Manually run transformations with optional filters
    """
    
    import uuid
    from datetime import datetime
    
    run_id = f"MANUAL_TRANSFORM_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}"
    
    # Build WHERE clause based on filters
    where_clauses = ["approved = TRUE", "active = TRUE"]
    
    if tpa_filter and tpa_filter.upper() != 'ALL':
        where_clauses.append(f"tpa = '{tpa_filter}'")
    
    if table_filter and table_filter.upper() != 'ALL':
        where_clauses.append(f"target_table = '{table_filter}'")
    
    where_clause = " AND ".join(where_clauses)
    
    # Get matching combinations
    query = f"""
        SELECT DISTINCT 
            tpa,
            target_table,
            COUNT(*) as mapping_count
        FROM field_mappings
        WHERE {where_clause}
        GROUP BY tpa, target_table
        ORDER BY tpa, target_table
    """
    
    combinations = session.sql(query).collect()
    
    if not combinations:
        return f"No approved mappings found matching filters. TPA: {tpa_filter}, Table: {table_filter}"
    
    successful = 0
    failed = 0
    
    for combo in combinations:
        tpa = combo['TPA']
        target_table = combo['TARGET_TABLE']
        
        try:
            transform_query = f"""
                CALL transform_bronze_to_silver(
                    '{target_table}',
                    '{tpa}',
                    'RAW_DATA_TABLE',
                    'BRONZE',
                    10000,
                    TRUE,
                    FALSE
                )
            """
            
            session.sql(transform_query).collect()
            successful += 1
            
        except Exception as e:
            failed += 1
    
    return f"Manual run complete. Run ID: {run_id} | Total: {len(combinations)} | Success: {successful} | Failed: {failed}"
$$;

-- ============================================
-- RESUME TASKS (in dependency order)
-- ============================================

-- Note: Tasks are created in SUSPENDED state by default
-- The deployment script will automatically resume these tasks
--
-- To manually resume tasks, run:
--   ALTER TASK auto_transform_mappings_task RESUME;

-- ============================================
-- VERIFICATION
-- ============================================

-- Show created tasks
SHOW TASKS IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- Show created procedures
SHOW PROCEDURES LIKE '%transform%' IN SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);

-- Display success message
SELECT 'Silver tasks created successfully' AS status,
       'Tasks are in SUSPENDED state. Use ALTER TASK ... RESUME to start.' AS note,
       'Default schedule: Daily at 2 AM (USING CRON 0 2 * * * America/New_York)' AS schedule_info;

-- ============================================
-- USAGE EXAMPLES
-- ============================================

-- Example 1: Check auto-transform status
-- CALL get_auto_transform_status();

-- Example 2: Manually run all transformations
-- CALL run_all_approved_mappings();

-- Example 3: Manually run transformations for specific TPA
-- CALL run_transformations_manual('provider_a', 'ALL');

-- Example 4: Manually run transformations for specific table
-- CALL run_transformations_manual('ALL', 'CLAIMS');

-- Example 5: Manually run transformations for specific TPA and table
-- CALL run_transformations_manual('provider_a', 'CLAIMS');

-- Example 6: View recent transformation logs
-- SELECT * FROM silver_processing_log 
-- WHERE processing_type = 'AUTO_TRANSFORMATION' 
-- ORDER BY end_timestamp DESC 
-- LIMIT 10;
