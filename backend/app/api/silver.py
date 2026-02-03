"""
Silver Layer API Endpoints
"""

from fastapi import APIRouter, Request, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import logging
import asyncio

from app.services.snowflake_service import SnowflakeService
from app.config import settings
from app.utils.cache import cache
from app.utils.auth_utils import get_caller_token

logger = logging.getLogger(__name__)
router = APIRouter()

def validate_default_value_compatibility(data_type: str, default_value: str) -> tuple[bool, str]:
    """
    Validate that a default value is compatible with the column data type.
    
    Returns:
        tuple[bool, str]: (is_valid, error_message)
    """
    if not default_value or not default_value.strip():
        return True, ""
    
    default_value = default_value.strip()
    data_type_upper = data_type.upper()
    
    # Extract base type (e.g., VARCHAR(100) -> VARCHAR)
    base_type = data_type_upper.split('(')[0].strip()
    
    # Functions that are always valid
    valid_functions = ['CURRENT_TIMESTAMP', 'CURRENT_DATE', 'CURRENT_TIME', 'CURRENT_USER', 
                      'SYSDATE', 'GETDATE', 'UUID_STRING', 'SEQ']
    
    # Check if it's a function call
    is_function = '(' in default_value and ')' in default_value
    if is_function:
        func_name = default_value.split('(')[0].strip().upper()
        
        # Type-specific function validation
        if base_type in ['DATE']:
            if func_name in ['CURRENT_TIMESTAMP', 'GETDATE', 'SYSDATE']:
                return False, f"DATE columns cannot use {func_name}(). Use CURRENT_DATE() instead."
            if func_name not in ['CURRENT_DATE']:
                return False, f"DATE columns should use CURRENT_DATE() for date functions."
        
        elif base_type in ['TIME']:
            if func_name not in ['CURRENT_TIME']:
                return False, f"TIME columns should use CURRENT_TIME() for time functions."
        
        elif base_type in ['TIMESTAMP', 'TIMESTAMP_NTZ', 'TIMESTAMP_LTZ', 'TIMESTAMP_TZ']:
            if func_name == 'CURRENT_DATE':
                return False, f"TIMESTAMP columns cannot use CURRENT_DATE(). Use CURRENT_TIMESTAMP() instead."
        
        # If it's a recognized function, it's valid
        if func_name in valid_functions:
            return True, ""
    
    # Validate literal values based on type
    if base_type in ['NUMBER', 'INT', 'INTEGER', 'BIGINT', 'SMALLINT', 'TINYINT', 'BYTEINT',
                     'FLOAT', 'DOUBLE', 'REAL', 'DECIMAL', 'NUMERIC']:
        # Check if it's a valid number
        try:
            float(default_value.replace(',', ''))
            return True, ""
        except ValueError:
            if not is_function:
                return False, f"Default value '{default_value}' is not a valid number for {data_type}."
    
    elif base_type == 'BOOLEAN':
        if default_value.upper() not in ['TRUE', 'FALSE', '0', '1']:
            return False, f"Default value '{default_value}' is not valid for BOOLEAN. Use TRUE or FALSE."
    
    elif base_type in ['VARCHAR', 'CHAR', 'STRING', 'TEXT']:
        # String literals should be quoted, but we'll accept them without quotes
        # The stored procedure will handle the quoting
        return True, ""
    
    elif base_type in ['DATE', 'TIME', 'TIMESTAMP', 'TIMESTAMP_NTZ', 'TIMESTAMP_LTZ', 'TIMESTAMP_TZ']:
        # If not a function, check if it's a quoted date/time string
        if not is_function and not (default_value.startswith("'") and default_value.endswith("'")):
            return False, f"Date/time default values should be functions like CURRENT_DATE() or quoted strings like '2024-01-01'."
    
    return True, ""

class TargetSchemaCreate(BaseModel):
    table_name: str
    column_name: str
    tpa: str
    data_type: str
    nullable: bool = True
    default_value: Optional[str] = None
    description: Optional[str] = None

class TargetSchemaUpdate(BaseModel):
    data_type: Optional[str] = None
    nullable: Optional[bool] = None
    default_value: Optional[str] = None
    description: Optional[str] = None

class FieldMappingCreate(BaseModel):
    source_field: str
    target_table: str
    target_column: str
    tpa: str
    transformation_logic: Optional[str] = None
    description: Optional[str] = None

class TransformRequest(BaseModel):
    source_table: str
    target_table: str
    tpa: str
    source_schema: str = "BRONZE"
    batch_size: int = 10000
    apply_rules: bool = True
    incremental: bool = False

@router.get("/schemas")
async def get_target_schemas(request: Request, tpa: Optional[str] = None, table_name: Optional[str] = None):
    """Get target schemas (TPA-agnostic)"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        return await sf_service.get_target_schemas(tpa, table_name)
    except Exception as e:
        logger.error(f"Failed to get target schemas: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/schemas/{table_name}/columns")
async def get_target_columns(request: Request, table_name: str):
    """Get column names for a specific target table"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        query = f"""
            SELECT column_name
            FROM {settings.SILVER_SCHEMA_NAME}.target_schemas
            WHERE table_name = '{table_name.upper()}'
              AND active = TRUE
            ORDER BY schema_id
        """
        result = await sf_service.execute_query_dict(query)
        return [row['COLUMN_NAME'] for row in result]
    except Exception as e:
        logger.error(f"Failed to get target columns: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/cortex-models")
async def get_cortex_models(request: Request):
    """Get list of available Cortex LLM models (filtered by allowed models)"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Execute both queries in the same session
        # This is necessary because RESULT_SCAN(LAST_QUERY_ID()) requires the same session
        queries = [
            "SHOW MODELS IN SNOWFLAKE.MODELS",
            """SELECT "name" AS model_name
               FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
               WHERE "model_type" = 'CORTEX_BASE'
               ORDER BY "name" """
        ]
        result = await sf_service.execute_queries_same_session(queries)
        all_models = [row['MODEL_NAME'] for row in result]
        
        # Filter by allowed models from configuration
        allowed_models = settings.allowed_llm_models_list
        filtered_models = [model for model in all_models if model.upper() in [m.upper() for m in allowed_models]]
        
        # If no models match, return the allowed list anyway (they might not be available yet)
        if not filtered_models:
            return allowed_models
        
        return filtered_models
    except Exception as e:
        logger.error(f"Failed to get Cortex models: {str(e)}")
        # Return the configured allowed models as fallback
        return settings.allowed_llm_models_list

@router.post("/schemas")
async def create_target_schema(request: Request, schema: TargetSchemaCreate):
    """Create target schema definition (TPA-agnostic)"""
    try:
        # Validation: Non-nullable columns must have a default value
        if not schema.nullable and not schema.default_value:
            raise HTTPException(
                status_code=400, 
                detail="Non-nullable columns must have a default value. Please provide a default value or make the column nullable."
            )
        
        # Validation: Default value must be compatible with data type
        if schema.default_value:
            is_valid, error_msg = validate_default_value_compatibility(schema.data_type, schema.default_value)
            if not is_valid:
                raise HTTPException(status_code=400, detail=error_msg)
        
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Escape single quotes by doubling them for SQL
        escaped_table = schema.table_name.upper().replace("'", "''")
        escaped_column = schema.column_name.upper().replace("'", "''")
        escaped_data_type = schema.data_type.replace("'", "''")
        escaped_default = schema.default_value.replace("'", "''") if schema.default_value else None
        escaped_description = schema.description.replace("'", "''") if schema.description else None
        
        query = f"""
            INSERT INTO {settings.SILVER_SCHEMA_NAME}.target_schemas
            (table_name, column_name, data_type, nullable, default_value, description)
            VALUES ('{escaped_table}', '{escaped_column}',
                    '{escaped_data_type}', {schema.nullable}, 
                    {'NULL' if not escaped_default else f"'{escaped_default}'"},
                    {'NULL' if not escaped_description else f"'{escaped_description}'"})
        """
        await sf_service.execute_query(query)
        
        # Invalidate schema cache
        cache.clear("schemas")
        
        return {"message": "Target schema created successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to create target schema: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/schemas/{schema_id}")
async def update_target_schema(request: Request, schema_id: int, schema: TargetSchemaUpdate):
    """Update target schema definition"""
    try:
        logger.info(f"Update schema request: schema_id={schema_id}, data_type={schema.data_type}, nullable={schema.nullable}, default_value={schema.default_value}, description={schema.description}")
        
        # Validation: If both data_type and default_value are provided, validate compatibility
        if schema.data_type and schema.default_value:
            is_valid, error_msg = validate_default_value_compatibility(schema.data_type, schema.default_value)
            if not is_valid:
                raise HTTPException(status_code=400, detail=error_msg)
        
        # If only default_value is provided, we need to fetch the data_type to validate
        if schema.default_value and not schema.data_type:
            sf_service_temp = SnowflakeService(caller_token=get_caller_token(request))
            existing_query = f"""
                SELECT data_type FROM {settings.SILVER_SCHEMA_NAME}.target_schemas
                WHERE schema_id = {schema_id}
            """
            existing_result = await sf_service_temp.execute_query_dict(existing_query)
            if existing_result and len(existing_result) > 0:
                existing_data_type = existing_result[0]['DATA_TYPE']
                is_valid, error_msg = validate_default_value_compatibility(existing_data_type, schema.default_value)
                if not is_valid:
                    raise HTTPException(status_code=400, detail=error_msg)
        
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Build update query dynamically based on provided fields
        # Since frontend now filters out undefined/null values, we can trust what's sent
        update_fields = []
        if schema.data_type is not None:
            logger.info(f"Adding data_type update: {schema.data_type}")
            # Escape single quotes by doubling them for SQL
            escaped_data_type = schema.data_type.replace("'", "''")
            update_fields.append(f"data_type = '{escaped_data_type}'")
        if schema.nullable is not None:
            logger.info(f"Adding nullable update: {schema.nullable}")
            update_fields.append(f"nullable = {schema.nullable}")
        if schema.default_value is not None:
            logger.info(f"Adding default_value update: {schema.default_value}")
            if schema.default_value == "":
                update_fields.append(f"default_value = NULL")
            else:
                # Escape single quotes by doubling them for SQL
                escaped_default = schema.default_value.replace("'", "''")
                update_fields.append(f"default_value = '{escaped_default}'")
        if schema.description is not None:
            logger.info(f"Adding description update: {schema.description}")
            # Escape single quotes by doubling them for SQL
            escaped_description = schema.description.replace("'", "''")
            update_fields.append(f"description = '{escaped_description}'")
        
        if not update_fields:
            logger.error("No fields to update")
            raise HTTPException(status_code=400, detail="No fields to update")
        
        query = f"""
            UPDATE {settings.SILVER_SCHEMA_NAME}.target_schemas
            SET {', '.join(update_fields)}, updated_timestamp = CURRENT_TIMESTAMP()
            WHERE schema_id = {schema_id}
        """
        logger.info(f"Executing query: {query}")
        await sf_service.execute_query(query)
        
        # Invalidate schema cache
        cache.clear("schemas")
        
        logger.info("Schema updated successfully")
        return {"message": "Target schema updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update target schema: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/schemas/{schema_id}")
async def delete_target_schema(request: Request, schema_id: int):
    """Delete target schema column definition"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.target_schemas
            WHERE schema_id = {schema_id}
        """
        await sf_service.execute_query(query)
        
        # Invalidate schema cache
        cache.clear("schemas")
        
        return {"message": "Target schema column deleted successfully"}
    except Exception as e:
        logger.error(f"Failed to delete target schema: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/schemas/table/{table_name}")
async def delete_table_schema(request: Request, table_name: str, tpa: str):
    """Delete entire table schema (all columns for a table)
    
    WARNING: This will delete the schema definition, all field mappings,
    and all transformation rules for this table across ALL TPAs.
    """
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # First check if table exists
        # Escape single quotes for SQL safety
        escaped_table_name = table_name.upper().replace("'", "''")
        escaped_tpa = tpa.replace("'", "''")
        
        check_query = f"""
            SELECT COUNT(*) as count
            FROM {settings.SILVER_SCHEMA_NAME}.target_schemas
            WHERE table_name = '{escaped_table_name}'
        """
        result = await sf_service.execute_query_dict(check_query)
        
        if not result or result[0]['COUNT'] == 0:
            raise HTTPException(status_code=404, detail=f"Table schema '{table_name}' not found")
        
        # 1. Delete all field mappings for this table (across all TPAs)
        delete_mappings_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.field_mappings
            WHERE target_table = '{escaped_table_name}'
        """
        await sf_service.execute_query(delete_mappings_query)
        logger.info(f"Deleted field mappings for table '{table_name}' across all TPAs")
        
        # 2. Delete all transformation rules for this table (across all TPAs)
        delete_rules_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.transformation_rules
            WHERE target_table = '{escaped_table_name}'
        """
        await sf_service.execute_query(delete_rules_query)
        logger.info(f"Deleted transformation rules for table '{table_name}' across all TPAs")
        
        # 3. Delete all columns for this table from target_schemas
        delete_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.target_schemas
            WHERE table_name = '{escaped_table_name}'
        """
        await sf_service.execute_query(delete_query)
        
        logger.info(f"Deleted table schema '{table_name}' ({result[0]['COUNT']} columns)")
        return {
            "message": f"Table schema '{table_name}' and all associated mappings and rules deleted successfully",
            "columns_deleted": result[0]['COUNT']
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete table schema: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/tables")
async def list_silver_tables(request: Request):
    """List all user-created Silver tables with metadata"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        query = f"""
            SELECT 
                ct.physical_table_name as TABLE_NAME,
                ct.schema_table_name as SCHEMA_TABLE,
                ct.tpa as TPA,
                ct.created_timestamp as CREATED_AT,
                ct.created_by as CREATED_BY,
                ct.description as DESCRIPTION,
                COALESCE(ist.row_count, 0) as ROW_COUNT,
                COALESCE(ist.bytes, 0) as BYTES,
                ist.last_altered as LAST_UPDATED
            FROM {settings.SILVER_SCHEMA_NAME}.created_tables ct
            LEFT JOIN {settings.DATABASE_NAME}.INFORMATION_SCHEMA.TABLES ist 
                ON ist.table_schema = '{settings.SILVER_SCHEMA_NAME}'
                AND ist.table_name = ct.physical_table_name
            WHERE ct.active = TRUE
            ORDER BY ct.created_timestamp DESC
        """
        result = await sf_service.execute_query_dict(query)
        return result
    except Exception as e:
        logger.error(f"Failed to list Silver tables: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/tables/exists")
async def check_table_exists(request: Request, table_name: str, tpa: str):
    """Check if a physical Silver table exists
    
    Checks for table with name format: {TPA}_{TABLE_NAME}
    """
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        physical_table_name = f"{tpa.upper()}_{table_name.upper()}"
        
        query = f"""
            SELECT COUNT(*) as count
            FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = '{settings.SILVER_SCHEMA_NAME}'
              AND TABLE_NAME = '{physical_table_name}'
        """
        result = await sf_service.execute_query_dict(query)
        exists = result[0]['COUNT'] > 0 if result else False
        
        return {
            "exists": exists,
            "physical_table_name": physical_table_name
        }
    except Exception as e:
        logger.error(f"Failed to check table existence: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/tables/create")
async def create_silver_table(request: Request, table_name: str, tpa: str):
    """Create physical Silver table from schema metadata
    
    Creates a table with name format: {TPA}_{TABLE_NAME}
    Example: PROVIDER_A_MEDICAL_CLAIMS
    """
    try:
        logger.info(f"Creating table: table_name={table_name}, tpa={tpa}")
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Use fully qualified procedure name
        proc_name = f"{settings.SILVER_SCHEMA_NAME}.create_silver_table"
        logger.info(f"Calling procedure: {proc_name}")
        
        result = await sf_service.execute_procedure(proc_name, table_name, tpa)
        logger.info(f"Procedure result: {result}")
        
        # Check if result indicates an error
        if result and isinstance(result, str) and result.startswith("ERROR:"):
            logger.error(f"Procedure returned error: {result}")
            raise HTTPException(status_code=400, detail=result)
        
        # Extract the actual table name from the result
        physical_table_name = f"{tpa.upper()}_{table_name.upper()}"
        
        return {
            "message": f"Table {physical_table_name} created successfully",
            "physical_table_name": physical_table_name,
            "result": result
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to create table: {str(e)}", exc_info=True)
        
        # Provide more detailed error message
        error_msg = str(e)
        if "does not exist" in error_msg.lower():
            error_msg = f"Table creation failed: {error_msg}. Please ensure the schema definition exists."
        elif "already exists" in error_msg.lower():
            error_msg = f"Table already exists: {tpa.upper()}_{table_name.upper()}"
        
        raise HTTPException(status_code=500, detail=error_msg)

@router.delete("/tables/delete")
async def delete_physical_table(request: Request, table_name: str, tpa: str):
    """Delete physical Silver table
    
    Deletes the physical table with name format: {TPA}_{TABLE_NAME}
    Example: PROVIDER_A_MEDICAL_CLAIMS
    
    WARNING: This will permanently delete the table and all its data.
    Also deletes all associated field mappings and transformation rules for this table.
    """
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Construct the physical table name
        physical_table_name = f"{tpa.upper()}_{table_name.upper()}"
        
        logger.info(f"Attempting to delete physical table: {physical_table_name} for TPA: {tpa}")
        
        # Escape single quotes for SQL safety
        escaped_table_name = physical_table_name.replace("'", "''")
        escaped_tpa = tpa.replace("'", "''")
        escaped_schema_table_name = table_name.upper().replace("'", "''")
        
        # 1. Delete field mappings for this table
        delete_mappings_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.field_mappings
            WHERE target_table = '{escaped_schema_table_name}'
              AND tpa = '{escaped_tpa}'
        """
        await sf_service.execute_query(delete_mappings_query)
        logger.info(f"Deleted field mappings for table {table_name} and TPA {tpa}")
        
        # 2. Delete transformation rules for this table
        delete_rules_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.transformation_rules
            WHERE target_table = '{escaped_schema_table_name}'
              AND tpa = '{escaped_tpa}'
        """
        await sf_service.execute_query(delete_rules_query)
        logger.info(f"Deleted transformation rules for table {table_name} and TPA {tpa}")
        
        # 3. Drop the physical table
        drop_query = f"DROP TABLE IF EXISTS {settings.SILVER_SCHEMA_NAME}.{physical_table_name}"
        await sf_service.execute_query(drop_query)
        logger.info(f"Physical table {physical_table_name} dropped successfully")
        
        # 4. Remove from created_tables tracking
        delete_tracking_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.created_tables
            WHERE physical_table_name = '{escaped_table_name}'
              AND tpa = '{escaped_tpa}'
        """
        await sf_service.execute_query(delete_tracking_query)
        logger.info(f"Removed {physical_table_name} from created_tables tracking")
        
        logger.info(f"Successfully deleted physical table {physical_table_name} for TPA {tpa}")
        
        return {
            "message": f"Table {physical_table_name} and associated mappings and rules deleted successfully",
            "physical_table_name": physical_table_name
        }
    except Exception as e:
        logger.error(f"Failed to delete table: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/data")
async def get_silver_data(request: Request, tpa: str, table_name: str, limit: int = 100):
    """Get data from a Silver layer table
    
    Args:
        tpa: TPA code (e.g., 'provider_a')
        table_name: Schema table name (e.g., 'DENTAL_CLAIMS')
        limit: Maximum number of rows to return (default: 100)
    
    Returns:
        List of records from the physical table
    """
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Construct the physical table name: {TPA}_{TABLE_NAME}
        physical_table_name = f"{tpa.upper()}_{table_name.upper()}"
        
        # Query the physical table
        query = f"""
            SELECT *
            FROM {settings.SILVER_SCHEMA_NAME}.{physical_table_name}
            LIMIT {limit}
        """
        
        result = await sf_service.execute_query_dict(query)
        
        # Also get row count
        count_query = f"""
            SELECT COUNT(*) as TOTAL_COUNT
            FROM {settings.SILVER_SCHEMA_NAME}.{physical_table_name}
        """
        count_result = await sf_service.execute_query_dict(count_query)
        total_count = count_result[0]['TOTAL_COUNT'] if count_result else 0
        
        return {
            "data": result,
            "total_count": total_count,
            "limit": limit,
            "table_name": physical_table_name
        }
    except Exception as e:
        logger.error(f"Failed to get Silver data: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/data/stats")
async def get_silver_data_stats(request: Request, tpa: str, table_name: str):
    """Get statistics for a Silver layer table with data quality metrics"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Construct the physical table name
        physical_table_name = f"{tpa.upper()}_{table_name.upper()}"
        
        # Get table statistics - simple count query
        stats_query = f"""
            SELECT 
                COUNT(*) as TOTAL_RECORDS
            FROM {settings.SILVER_SCHEMA_NAME}.{physical_table_name}
        """
        
        result = await sf_service.execute_query_dict(stats_query)
        
        # Get data quality metrics
        quality_query = f"""
            SELECT 
                metric_name,
                metric_value,
                metric_threshold,
                passed,
                description,
                measured_timestamp
            FROM {settings.SILVER_SCHEMA_NAME}.data_quality_metrics
            WHERE target_table = '{physical_table_name}'
              AND tpa = '{tpa.upper()}'
            ORDER BY measured_timestamp DESC
            LIMIT 20
        """
        
        quality_metrics = await sf_service.execute_query_dict(quality_query)
        
        # Calculate overall quality score from metrics
        if quality_metrics:
            passed_count = sum(1 for m in quality_metrics if m.get('PASSED'))
            total_count = len(quality_metrics)
            quality_score = round((passed_count / total_count) * 100, 1) if total_count > 0 else 0
        else:
            quality_score = 0
        
        # Get last updated timestamp from quality metrics if available
        last_updated = None
        if quality_metrics:
            last_updated = max(m['MEASURED_TIMESTAMP'] for m in quality_metrics if m.get('MEASURED_TIMESTAMP'))
        
        if result and len(result) > 0:
            return {
                "total_records": result[0]['TOTAL_RECORDS'] or 0,
                "last_updated": last_updated,
                "data_quality_score": quality_score,
                "quality_metrics": [
                    {
                        "metric_name": m['METRIC_NAME'],
                        "metric_value": m['METRIC_VALUE'],
                        "metric_threshold": m['METRIC_THRESHOLD'],
                        "passed": m['PASSED'],
                        "description": m['DESCRIPTION'],
                        "measured_timestamp": m['MEASURED_TIMESTAMP']
                    }
                    for m in quality_metrics
                ] if quality_metrics else []
            }
        else:
            return {
                "total_records": 0,
                "last_updated": None,
                "data_quality_score": 0,
                "quality_metrics": []
            }
    except Exception as e:
        logger.error(f"Failed to get Silver data stats: {str(e)}")
        # Return basic stats on error
        try:
            # Fallback to simple count query
            simple_query = f"SELECT COUNT(*) as TOTAL_RECORDS FROM {settings.SILVER_SCHEMA_NAME}.{physical_table_name}"
            simple_result = await sf_service.execute_query_dict(simple_query)
            return {
                "total_records": simple_result[0]['TOTAL_RECORDS'] if simple_result else 0,
                "last_updated": None,
                "data_quality_score": 0,
                "quality_metrics": []
            }
        except:
            raise HTTPException(status_code=500, detail=str(e))

@router.get("/mappings")
async def get_field_mappings(request: Request, tpa: Optional[str] = None, target_table: Optional[str] = None):
    """Get field mappings (optionally filtered by TPA and/or target table)"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        return await sf_service.get_field_mappings(tpa, target_table)
    except Exception as e:
        logger.error(f"Failed to get field mappings: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/mappings/validate")
async def validate_field_mappings(request: Request, tpa: str, target_table: str):
    """Validate field mappings against physical table structure"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Get all active approved mappings
        mappings_query = f"""
            SELECT source_field, target_column, mapping_id
            FROM {settings.SILVER_SCHEMA_NAME}.field_mappings
            WHERE target_table = '{target_table.upper()}'
              AND tpa = '{tpa}'
              AND approved = TRUE
              AND active = TRUE
        """
        mappings = await sf_service.execute_query_dict(mappings_query)
        
        if not mappings:
            return {
                "valid": False,
                "message": "No approved mappings found",
                "errors": [],
                "warnings": []
            }
        
        # Get physical table columns
        physical_table_name = f"{tpa.upper()}_{target_table.upper()}"
        columns_query = f"""
            SELECT column_name
            FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.COLUMNS
            WHERE table_schema = '{settings.SILVER_SCHEMA_NAME}'
              AND table_name = '{physical_table_name}'
        """
        
        try:
            columns_result = await sf_service.execute_query_dict(columns_query)
            existing_columns = {row['COLUMN_NAME'].upper() for row in columns_result}
        except Exception as e:
            return {
                "valid": False,
                "message": f"Could not validate: table '{physical_table_name}' may not exist",
                "errors": [str(e)],
                "warnings": []
            }
        
        # Validate each mapping
        errors = []
        warnings = []
        duplicate_targets = {}
        
        for mapping in mappings:
            target_col = mapping['TARGET_COLUMN'].upper()
            
            # Check if target column exists
            if target_col not in existing_columns:
                errors.append({
                    "mapping_id": mapping['MAPPING_ID'],
                    "source_field": mapping['SOURCE_FIELD'],
                    "target_column": target_col,
                    "error": f"Target column '{target_col}' does not exist in table '{physical_table_name}'"
                })
            
            # Check for duplicate target columns
            if target_col in duplicate_targets:
                warnings.append({
                    "target_column": target_col,
                    "warning": f"Multiple source fields mapped to '{target_col}': {duplicate_targets[target_col]} and {mapping['SOURCE_FIELD']}"
                })
            else:
                duplicate_targets[target_col] = mapping['SOURCE_FIELD']
        
        return {
            "valid": len(errors) == 0,
            "message": "All mappings are valid" if len(errors) == 0 else f"Found {len(errors)} invalid mapping(s)",
            "errors": errors,
            "warnings": warnings,
            "total_mappings": len(mappings),
            "physical_table": physical_table_name
        }
        
    except Exception as e:
        logger.error(f"Failed to validate field mappings: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/mappings")
async def create_field_mapping(request: Request, mapping: FieldMappingCreate):
    """Create field mapping with validation"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Validation 1: Check if mapping already exists
        check_duplicate_query = f"""
            SELECT COUNT(*) as count
            FROM {settings.SILVER_SCHEMA_NAME}.field_mappings
            WHERE target_table = '{mapping.target_table.upper()}'
              AND target_column = '{mapping.target_column.upper()}'
              AND tpa = '{mapping.tpa}'
              AND active = TRUE
        """
        duplicate_result = await sf_service.execute_query_dict(check_duplicate_query)
        if duplicate_result and duplicate_result[0]['COUNT'] > 0:
            raise HTTPException(
                status_code=400, 
                detail=f"Mapping already exists for target column '{mapping.target_column}' in table '{mapping.target_table}' for TPA '{mapping.tpa}'"
            )
        
        # Validation 2: Check if target column exists in physical table
        physical_table_name = f"{mapping.tpa.upper()}_{mapping.target_table.upper()}"
        try:
            column_check_query = f"""
                SELECT column_name
                FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.COLUMNS
                WHERE table_schema = '{settings.SILVER_SCHEMA_NAME}'
                  AND table_name = '{physical_table_name}'
                  AND column_name = '{mapping.target_column.upper()}'
            """
            column_result = await sf_service.execute_query_dict(column_check_query)
            if not column_result or len(column_result) == 0:
                raise HTTPException(
                    status_code=400,
                    detail=f"Target column '{mapping.target_column}' does not exist in table '{physical_table_name}'. Please add it to the target schema first."
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.warning(f"Could not validate column existence: {str(e)}")
            # Continue anyway if we can't check (table might not exist yet)
        
        # Create the mapping
        query = f"""
            INSERT INTO {settings.SILVER_SCHEMA_NAME}.field_mappings
            (source_field, target_table, target_column, tpa, mapping_method, transformation_logic, description, approved)
            VALUES ('{mapping.source_field.upper()}', '{mapping.target_table.upper()}', 
                    '{mapping.target_column.upper()}', '{mapping.tpa}', 'MANUAL',
                    {'NULL' if not mapping.transformation_logic else f"'{mapping.transformation_logic}'"},
                    {'NULL' if not mapping.description else f"'{mapping.description}'"}, TRUE)
        """
        await sf_service.execute_query(query)
        return {"message": "Field mapping created successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to create field mapping: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

class AutoMapMLRequest(BaseModel):
    source_table: str
    target_table: str
    tpa: str
    top_n: int = 3
    min_confidence: float = 0.6

class AutoMapLLMRequest(BaseModel):
    source_table: str
    target_table: str
    tpa: str
    model_name: str = "llama3.1-70b"

@router.post("/mappings/auto-ml")
async def auto_map_fields_ml(request: Request, mapping_request: AutoMapMLRequest):
    """Auto-map fields using ML
    
    Note: This operation can take 30-60 seconds depending on data volume.
    The procedure analyzes source fields and calculates similarity scores
    using multiple algorithms (TF-IDF, sequence matching, word overlap).
    """
    try:
        logger.info(f"Starting ML auto-mapping: source={mapping_request.source_table}, target={mapping_request.target_table}, tpa={mapping_request.tpa}")
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        result = await sf_service.execute_procedure(
            "auto_map_fields_ml",
            mapping_request.source_table,
            mapping_request.target_table,
            mapping_request.tpa,
            mapping_request.top_n,
            mapping_request.min_confidence
        )
        logger.info(f"ML auto-mapping completed. Result type: {type(result)}, Result value: {result}")
        
        # Parse the result string to extract number of mappings created
        # Result format: "Successfully generated X ML-based field mappings..."
        mappings_created = 0
        if result and isinstance(result, str):
            import re
            match = re.search(r'generated (\d+)', result)
            if match:
                mappings_created = int(match.group(1))
                logger.info(f"Extracted mappings_created from result: {mappings_created}")
            else:
                logger.warning(f"Could not extract mapping count from result string: {result}")
        
        # If result is None or empty, check if mappings were actually created by querying
        if not result or mappings_created == 0:
            # Query to check if mappings exist for this table/TPA
            # Escape single quotes in table name and TPA to prevent SQL errors
            safe_table = mapping_request.target_table.replace("'", "''")
            safe_tpa = mapping_request.tpa.replace("'", "''")
            
            check_query = f"""
                SELECT COUNT(*) as count 
                FROM {settings.SILVER_SCHEMA_NAME}.FIELD_MAPPINGS 
                WHERE TARGET_TABLE = '{safe_table}' 
                AND TPA = '{safe_tpa}'
                AND MAPPING_METHOD LIKE 'ML%'
            """
            try:
                mapping_check = await sf_service.execute_query_dict(check_query)
                if mapping_check and len(mapping_check) > 0:
                    actual_count = mapping_check[0].get('COUNT', 0)
                    if actual_count > 0:
                        mappings_created = actual_count
                        result = f"Successfully generated {actual_count} ML-based field mappings"
                        logger.info(f"Verified {actual_count} ML mappings in database")
            except Exception as check_error:
                logger.warning(f"Could not verify mapping count: {check_error}")
        
        return {
            "message": result if result else "ML auto-mapping completed",
            "result": result,
            "mappings_created": mappings_created,
            "success": mappings_created > 0 or (result and "successfully" in result.lower())
        }
    except asyncio.TimeoutError:
        logger.error(f"ML auto-mapping timed out for TPA {mapping_request.tpa}")
        raise HTTPException(
            status_code=504,
            detail="Procedure execution timed out. Try reducing the data volume or increasing timeout."
        )
    except Exception as e:
        logger.error(f"ML auto-mapping failed: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/mappings/auto-llm")
async def auto_map_fields_llm(request: Request, mapping_request: AutoMapLLMRequest):
    """Auto-map fields using LLM
    
    Note: This operation can take 30-90 seconds depending on data volume
    and LLM model response time. The procedure uses Snowflake Cortex AI
    to semantically understand field relationships.
    """
    try:
        logger.info(f"Starting LLM auto-mapping: source={mapping_request.source_table}, target={mapping_request.target_table}, tpa={mapping_request.tpa}, model={mapping_request.model_name}")
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Escape single quotes for SQL safety
        safe_table = mapping_request.target_table.replace("'", "''")
        safe_tpa = mapping_request.tpa.replace("'", "''")
        safe_source = mapping_request.source_table.replace("'", "''")
        
        # PRE-FLIGHT CHECK 1: Verify TPA exists and is active
        logger.info(f"Pre-flight check 1: Verifying TPA '{mapping_request.tpa}' exists")
        tpa_check = await sf_service.execute_query_dict(f"""
            SELECT TPA_CODE, TPA_NAME, ACTIVE 
            FROM {settings.BRONZE_SCHEMA_NAME}.TPA_MASTER 
            WHERE TPA_CODE = '{safe_tpa}'
        """)
        if not tpa_check or len(tpa_check) == 0:
            raise HTTPException(
                status_code=400, 
                detail=f"TPA '{mapping_request.tpa}' is not registered. Please register the TPA first in the Bronze layer."
            )
        if not tpa_check[0].get('ACTIVE', False):
            raise HTTPException(
                status_code=400,
                detail=f"TPA '{mapping_request.tpa}' is inactive. Please activate the TPA before mapping."
            )
        logger.info(f"✓ TPA '{tpa_check[0]['TPA_NAME']}' is valid and active")
        
        # PRE-FLIGHT CHECK 2: Verify Bronze data exists for this TPA
        logger.info(f"Pre-flight check 2: Checking Bronze data for TPA '{mapping_request.tpa}'")
        bronze_check = await sf_service.execute_query_dict(f"""
            SELECT COUNT(*) as record_count,
                   COUNT(DISTINCT f.key) as field_count
            FROM {settings.BRONZE_SCHEMA_NAME}.{safe_source},
            LATERAL FLATTEN(input => RAW_DATA) f
            WHERE RAW_DATA IS NOT NULL
              AND TPA = '{safe_tpa}'
            LIMIT 1000
        """)
        if not bronze_check or bronze_check[0].get('RECORD_COUNT', 0) == 0:
            raise HTTPException(
                status_code=400,
                detail=f"No data found for TPA '{mapping_request.tpa}' in Bronze table '{mapping_request.source_table}'. Please upload data files first using the Bronze upload feature."
            )
        field_count = bronze_check[0].get('FIELD_COUNT', 0)
        record_count = bronze_check[0].get('RECORD_COUNT', 0)
        logger.info(f"✓ Found {record_count} records with {field_count} unique fields for TPA '{mapping_request.tpa}'")
        
        # PRE-FLIGHT CHECK 3: Verify target schema exists
        logger.info(f"Pre-flight check 3: Verifying target schema for table '{mapping_request.target_table}'")
        schema_check = await sf_service.execute_query_dict(f"""
            SELECT COUNT(*) as column_count,
                   LISTAGG(DISTINCT column_name, ', ') WITHIN GROUP (ORDER BY column_name) as columns
            FROM {settings.SILVER_SCHEMA_NAME}.target_schemas
            WHERE table_name = '{safe_table}'
              AND active = TRUE
        """)
        if not schema_check or schema_check[0].get('COLUMN_COUNT', 0) == 0:
            raise HTTPException(
                status_code=400,
                detail=f"No schema definition found for table '{mapping_request.target_table}'. Please create the table schema first using the Silver Schemas page."
            )
        column_count = schema_check[0].get('COLUMN_COUNT', 0)
        logger.info(f"✓ Target schema '{mapping_request.target_table}' has {column_count} columns defined")
        
        # PRE-FLIGHT CHECK 4: Verify LLM prompt template exists
        logger.info(f"Pre-flight check 4: Checking LLM prompt template")
        template_check = await sf_service.execute_query_dict(f"""
            SELECT template_id, template_name, model_name
            FROM {settings.SILVER_SCHEMA_NAME}.llm_prompt_templates
            WHERE template_id = 'DEFAULT_FIELD_MAPPING'
              AND active = TRUE
        """)
        if not template_check or len(template_check) == 0:
            raise HTTPException(
                status_code=500,
                detail="LLM prompt template 'DEFAULT_FIELD_MAPPING' not found. The Silver layer may not be fully deployed. Please contact your administrator."
            )
        logger.info(f"✓ LLM prompt template '{template_check[0]['TEMPLATE_NAME']}' is available")
        
        # PRE-FLIGHT CHECK 5: Test Cortex AI availability (quick test)
        logger.info(f"Pre-flight check 5: Testing Cortex AI availability")
        try:
            cortex_test = await sf_service.execute_query_dict(f"""
                SELECT SNOWFLAKE.CORTEX.COMPLETE('{mapping_request.model_name}', 'test') as test_response
            """)
            logger.info(f"✓ Cortex AI model '{mapping_request.model_name}' is available and responding")
        except Exception as cortex_error:
            error_str = str(cortex_error).lower()
            if "does not exist" in error_str and "function" in error_str:
                raise HTTPException(
                    status_code=500,
                    detail="Cortex AI is not enabled in your Snowflake account. Please contact Snowflake support to enable Cortex AI functionality."
                )
            elif "not available" in error_str or "invalid" in error_str:
                raise HTTPException(
                    status_code=400,
                    detail=f"Model '{mapping_request.model_name}' is not available in your Snowflake region. Available models typically include: llama3.1-8b, llama3.1-70b, mistral-large, mixtral-8x7b. Please try a different model."
                )
            else:
                raise HTTPException(
                    status_code=500,
                    detail=f"Cortex AI test failed: {str(cortex_error)}"
                )
        
        # All pre-flight checks passed - proceed with LLM mapping
        logger.info(f"✓ All pre-flight checks passed. Proceeding with LLM auto-mapping...")
        logger.info(f"  - TPA: {mapping_request.tpa} ({tpa_check[0]['TPA_NAME']})")
        logger.info(f"  - Source: {record_count} records, {field_count} fields")
        logger.info(f"  - Target: {mapping_request.target_table} ({column_count} columns)")
        logger.info(f"  - Model: {mapping_request.model_name}")
        
        result = await sf_service.execute_procedure(
            "auto_map_fields_llm",
            mapping_request.source_table,
            mapping_request.target_table,
            mapping_request.tpa,
            mapping_request.model_name,
            "DEFAULT_FIELD_MAPPING"
        )
        logger.info(f"LLM auto-mapping completed. Result type: {type(result)}, Result value: '{result}'")
        
        # Check if procedure returned an error message
        if result and isinstance(result, str):
            result_lower = result.lower()
            if "error" in result_lower or "failed" in result_lower:
                # Procedure returned an error message
                if "no source fields found" in result_lower:
                    raise HTTPException(
                        status_code=400,
                        detail=f"No source fields found for TPA '{mapping_request.tpa}'. This shouldn't happen after pre-flight checks. Please try again."
                    )
                elif "no target fields found" in result_lower:
                    raise HTTPException(
                        status_code=400,
                        detail=f"No target schema found for '{mapping_request.target_table}'. This shouldn't happen after pre-flight checks. Please try again."
                    )
                elif "prompt template" in result_lower and "not found" in result_lower:
                    raise HTTPException(
                        status_code=500,
                        detail="LLM prompt template not found. This shouldn't happen after pre-flight checks. Please contact your administrator."
                    )
                elif "could not parse" in result_lower:
                    # LLM returned unparseable response
                    raise HTTPException(
                        status_code=500,
                        detail=f"LLM returned an invalid response format. {result[:200]}"
                    )
                else:
                    # Generic error from procedure
                    raise HTTPException(status_code=500, detail=f"LLM mapping failed: {result}")
        
        # Parse the result string to extract number of mappings created
        # Result format: "Successfully generated X LLM-based field mappings..."
        mappings_created = 0
        if result and isinstance(result, str):
            import re
            match = re.search(r'generated (\d+)', result)
            if match:
                mappings_created = int(match.group(1))
                logger.info(f"✓ Successfully created {mappings_created} LLM-based field mappings")
            else:
                logger.warning(f"Could not extract mapping count from result string: '{result}'")
        
        # Always verify actual mappings in database (more reliable than parsing string)
        logger.info(f"Verifying actual mappings in database for table='{mapping_request.target_table}', tpa='{mapping_request.tpa}'")
        safe_table = mapping_request.target_table.replace("'", "''")
        safe_tpa = mapping_request.tpa.replace("'", "''")
        
        check_query = f"""
            SELECT COUNT(*) as count 
            FROM {settings.SILVER_SCHEMA_NAME}.FIELD_MAPPINGS 
            WHERE TARGET_TABLE = '{safe_table}' 
            AND TPA = '{safe_tpa}'
            AND MAPPING_METHOD LIKE 'LLM%'
            AND ACTIVE = TRUE
        """
        try:
            mapping_check = await sf_service.execute_query_dict(check_query)
            if mapping_check and len(mapping_check) > 0:
                actual_count = mapping_check[0].get('COUNT', 0)
                logger.info(f"Database verification: Found {actual_count} LLM mappings")
                
                # If we found mappings in DB but didn't parse them from result, use DB count
                if actual_count > 0 and mappings_created == 0:
                    mappings_created = actual_count
                    if not result or not result.strip():
                        result = f"Successfully generated {actual_count} LLM-based field mappings"
                    logger.info(f"Updated mappings_created from database: {actual_count}")
                
                # If result says 0 but DB has mappings, something is wrong
                if mappings_created == 0 and actual_count == 0:
                    logger.error(f"Procedure completed but no mappings were created. Result: '{result}'")
                    raise HTTPException(
                        status_code=500,
                        detail=f"LLM procedure completed but no mappings were created. The LLM may have returned an unexpected response format. Please check the logs or try again."
                    )
        except HTTPException:
            raise
        except Exception as check_error:
            logger.warning(f"Could not verify mapping count: {check_error}")
            # If we can't verify but have a result, trust the result
            if mappings_created == 0 and result:
                logger.error(f"Cannot verify mappings and result shows 0: '{result}'")
        
        return {
            "message": result if result else "LLM auto-mapping completed",
            "result": result,
            "mappings_created": mappings_created,
            "success": mappings_created > 0
        }
    except asyncio.TimeoutError:
        logger.error(f"LLM auto-mapping timed out for TPA {mapping_request.tpa}")
        raise HTTPException(
            status_code=504,
            detail="Procedure execution timed out. LLM processing can take longer for large datasets."
        )
    except Exception as e:
        error_msg = str(e)
        logger.error(f"LLM auto-mapping failed: {error_msg}", exc_info=True)
        logger.error(f"Request details: source={mapping_request.source_table}, target={mapping_request.target_table}, tpa={mapping_request.tpa}, model={mapping_request.model_name}")
        
        # Provide more helpful error messages
        if "does not exist" in error_msg.lower() and "procedure" in error_msg.lower():
            raise HTTPException(status_code=500, detail=f"Procedure 'auto_map_fields_llm' not found. Please ensure Silver layer is deployed correctly.")
        elif "does not exist" in error_msg.lower() and "function" in error_msg.lower() and "cortex" in error_msg.lower():
            raise HTTPException(status_code=500, detail=f"Cortex AI is not enabled in your Snowflake account. Contact Snowflake support to enable Cortex AI.")
        elif "cortex" in error_msg.lower() and "not available" in error_msg.lower():
            raise HTTPException(status_code=500, detail=f"Model '{mapping_request.model_name}' is not available in your region. Try a different model.")
        elif "no source fields found" in error_msg.lower():
            raise HTTPException(status_code=500, detail=f"No data found for TPA '{mapping_request.tpa}' in Bronze table. Please upload data first.")
        elif "no target fields found" in error_msg.lower():
            raise HTTPException(status_code=500, detail=f"No schema found for table '{mapping_request.target_table}'. Please create the table schema first.")
        elif "prompt template" in error_msg.lower() and "not found" in error_msg.lower():
            raise HTTPException(status_code=500, detail=f"LLM prompt template not found. Please run Silver schema setup.")
        elif "compilation error" in error_msg.lower():
            raise HTTPException(status_code=500, detail=f"SQL compilation error in procedure: {error_msg}")
        elif "insufficient privileges" in error_msg.lower():
            raise HTTPException(status_code=500, detail=f"Insufficient privileges to use Cortex AI. Grant USAGE on SNOWFLAKE.CORTEX to your role.")
        else:
            raise HTTPException(status_code=500, detail=f"LLM auto-mapping failed: {error_msg}")

@router.post("/mappings/{mapping_id}/approve")
async def approve_mapping(request: Request, mapping_id: int):
    """Approve a field mapping"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        result = await sf_service.execute_procedure("approve_field_mapping", mapping_id)
        return {"message": "Mapping approved successfully", "result": result}
    except Exception as e:
        logger.error(f"Failed to approve mapping: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/mappings/{mapping_id}")
async def decline_mapping(request: Request, mapping_id: int):
    """Decline and delete a field mapping"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.field_mappings
            WHERE mapping_id = {mapping_id}
        """
        await sf_service.execute_query(query)
        logger.info(f"Deleted mapping {mapping_id}")
        return {"message": "Mapping declined and deleted successfully"}
    except Exception as e:
        logger.error(f"Failed to decline mapping: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/transform")
async def transform_bronze_to_silver(request: Request, transform_request: TransformRequest):
    """Transform Bronze data to Silver with pre-validation"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Log transformation start
        logger.info(f"Starting transformation: {transform_request.target_table} for TPA {transform_request.tpa}")
        
        # Pre-validation: Check mappings before running transformation
        try:
            logger.info(f"Pre-validation: Checking approved mappings for table='{transform_request.target_table}', tpa='{transform_request.tpa}'")
            mappings_query = f"""
                SELECT target_column
                FROM {settings.SILVER_SCHEMA_NAME}.field_mappings
                WHERE target_table = '{transform_request.target_table.upper()}'
                  AND tpa = '{transform_request.tpa}'
                  AND approved = TRUE
                  AND active = TRUE
            """
            logger.debug(f"Mappings query: {mappings_query}")
            mappings = await sf_service.execute_query_dict(mappings_query)
            logger.info(f"Found {len(mappings) if mappings else 0} approved mappings")
            
            if not mappings or len(mappings) == 0:
                raise HTTPException(
                    status_code=400,
                    detail=f"No approved mappings found for table '{transform_request.target_table}' and TPA '{transform_request.tpa}'. Please create and approve mappings first."
                )
            
            # Check if physical table exists and validate columns
            physical_table_name = f"{transform_request.tpa.upper()}_{transform_request.target_table.upper()}"
            logger.info(f"Pre-validation: Checking if physical table '{physical_table_name}' exists")
            
            # First check if table exists
            table_exists_query = f"""
                SELECT COUNT(*) as count
                FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.TABLES
                WHERE table_schema = '{settings.SILVER_SCHEMA_NAME}'
                  AND table_name = '{physical_table_name}'
            """
            logger.debug(f"Table exists query: {table_exists_query}")
            table_check = await sf_service.execute_query_dict(table_exists_query)
            
            if not table_check or table_check[0].get('COUNT', 0) == 0:
                raise HTTPException(
                    status_code=400,
                    detail=f"Physical table '{physical_table_name}' does not exist. Please create the table first using the 'Create Physical Table' button."
                )
            
            logger.info(f"Physical table '{physical_table_name}' exists, validating columns")
            
            # Now get columns
            columns_query = f"""
                SELECT column_name
                FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.COLUMNS
                WHERE table_schema = '{settings.SILVER_SCHEMA_NAME}'
                  AND table_name = '{physical_table_name}'
            """
            logger.debug(f"Columns query: {columns_query}")
            columns_result = await sf_service.execute_query_dict(columns_query)
            existing_columns = {row['COLUMN_NAME'].upper() for row in columns_result}
            logger.info(f"Found {len(existing_columns)} columns in physical table")
            
            # Validate all mapped columns exist
            invalid_columns = []
            for mapping in mappings:
                if mapping['TARGET_COLUMN'].upper() not in existing_columns:
                    invalid_columns.append(mapping['TARGET_COLUMN'])
            
            if invalid_columns:
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid mappings detected: columns {', '.join(invalid_columns)} do not exist in table '{physical_table_name}'. Please fix the mappings before transforming."
                )
            
            logger.info("Pre-validation passed successfully")
                
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Pre-validation failed with error: {str(e)}", exc_info=True)
            # Don't proceed if pre-validation fails with unexpected error
            raise HTTPException(
                status_code=500,
                detail=f"Pre-validation failed: {str(e)}"
            )
        
        # Execute transformation
        # Note: Procedure signature is (target_table, tpa, source_table, source_schema, batch_size, apply_rules, incremental)
        result = await sf_service.execute_procedure(
            "transform_bronze_to_silver",
            transform_request.target_table,
            transform_request.tpa,
            transform_request.source_table,
            transform_request.source_schema,
            transform_request.batch_size,
            transform_request.apply_rules,
            transform_request.incremental
        )
        logger.info(f"Transformation completed. Result type: {type(result)}, Result value: {result}")
        
        # Ensure result is a string
        result_str = str(result) if result is not None else "Transformation completed with unknown status"
        
        return {"message": "Transformation completed", "result": result_str}
    except Exception as e:
        logger.error(f"Transformation failed: {str(e)}", exc_info=True)
        
        # Log error to Snowflake
        from app.utils.snowflake_logger import log_error
        from app.utils.auth_utils import get_caller_user
        import traceback
        
        try:
            await log_error(
                source="transform_bronze_to_silver",
                error_type=type(e).__name__,
                error_message=str(e),
                stack_trace=traceback.format_exc(),
                context={
                    "target_table": transform_request.target_table,
                    "tpa": transform_request.tpa,
                    "source_table": transform_request.source_table
                },
                user_name=get_caller_user(request),
                tpa_code=transform_request.tpa
            )
        except:
            pass  # Don't let logging errors crash the response
        
        raise HTTPException(status_code=500, detail=str(e))

# ============================================
# Task Management Endpoints
# ============================================

@router.get("/tasks")
async def get_silver_tasks(request: Request):
    """Get Silver tasks status with predecessor information"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        query = f"SHOW TASKS IN SCHEMA {settings.SILVER_SCHEMA_NAME}"
        tasks = await sf_service.execute_query_dict(query, timeout=30)
        
        # Add predecessor information to each task
        for task in tasks:
            task_name = task.get('name', '')
            # Get task details including predecessors
            desc_query = f"DESC TASK {settings.SILVER_SCHEMA_NAME}.{task_name}"
            try:
                desc_result = await sf_service.execute_query_dict(desc_query, timeout=30)
                # Find predecessor info in description
                for row in desc_result:
                    if row.get('property', '').upper() == 'PREDECESSORS':
                        task['predecessors'] = row.get('value', '')
                        break
                else:
                    task['predecessors'] = ''
            except:
                task['predecessors'] = ''
        
        return tasks
    except Exception as e:
        logger.error(f"Failed to get Silver tasks: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/tasks/{task_name}/resume")
async def resume_silver_task(request: Request, task_name: str):
    """Resume a Silver task"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        query = f"ALTER TASK {settings.SILVER_SCHEMA_NAME}.{task_name} RESUME"
        await sf_service.execute_query(query)
        return {"message": f"Task {task_name} resumed successfully"}
    except Exception as e:
        logger.error(f"Failed to resume Silver task: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/tasks/{task_name}/suspend")
async def suspend_silver_task(request: Request, task_name: str):
    """Suspend a Silver task"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        query = f"ALTER TASK {settings.SILVER_SCHEMA_NAME}.{task_name} SUSPEND"
        await sf_service.execute_query(query, timeout=30)
        return {"message": f"Task {task_name} suspended successfully"}
    except Exception as e:
        logger.error(f"Failed to suspend Silver task: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

class SilverScheduleUpdate(BaseModel):
    schedule: str

@router.put("/tasks/{task_name}/schedule")
async def update_silver_task_schedule(request: Request, task_name: str, schedule_update: SilverScheduleUpdate):
    """Update Silver task schedule (only for root tasks without predecessors)"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        schedule = schedule_update.schedule
        
        # Check if task has predecessors
        desc_query = f"DESC TASK {settings.SILVER_SCHEMA_NAME}.{task_name}"
        desc_result = await sf_service.execute_query_dict(desc_query, timeout=30)
        
        has_predecessors = False
        for row in desc_result:
            if row.get('property', '').upper() == 'PREDECESSORS':
                predecessors = row.get('value', '')
                if predecessors and predecessors.strip():
                    has_predecessors = True
                    break
        
        if has_predecessors:
            raise HTTPException(
                status_code=400,
                detail="Cannot modify schedule for tasks with predecessors. Only root tasks can have their schedule changed."
            )
        
        # Suspend task first
        suspend_query = f"ALTER TASK {settings.SILVER_SCHEMA_NAME}.{task_name} SUSPEND"
        await sf_service.execute_query(suspend_query, timeout=30)
        
        # Update schedule
        update_query = f"ALTER TASK {settings.SILVER_SCHEMA_NAME}.{task_name} SET SCHEDULE = '{schedule}'"
        await sf_service.execute_query(update_query, timeout=30)
        
        # Resume task
        resume_query = f"ALTER TASK {settings.SILVER_SCHEMA_NAME}.{task_name} RESUME"
        await sf_service.execute_query(resume_query, timeout=30)
        
        return {"message": f"Task {task_name} schedule updated successfully to: {schedule}"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update Silver task schedule: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# DATA QUALITY ENDPOINTS
# ============================================

@router.post("/quality/check")
async def run_quality_checks(
    request: Request,
    table_name: str,
    tpa: str,
    batch_id: Optional[str] = None
):
    """
    Run data quality checks on a Silver table
    
    Performs comprehensive quality validation including:
    - Row count validation
    - Null value analysis
    - Duplicate detection
    - Completeness score
    - Data freshness
    - Range validation
    - Date validation
    """
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        logger.info(f"Running data quality checks: table={table_name}, tpa={tpa}")
        
        # Call the stored procedure
        proc_name = "SILVER.run_data_quality_checks"
        result = await sf_service.execute_procedure(
            proc_name,
            table_name,
            tpa,
            batch_id
        )
        
        logger.info(f"Quality check result: {result}")
        
        return {
            "success": True,
            "message": result,
            "table_name": table_name,
            "tpa": tpa
        }
        
    except Exception as e:
        logger.error(f"Error running quality checks: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/quality/check-all")
async def run_quality_checks_all(
    request: Request,
    tpa: str,
    batch_id: Optional[str] = None
):
    """
    Run data quality checks on all Silver tables for a TPA
    """
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        logger.info(f"Running data quality checks for all tables: tpa={tpa}")
        
        # Call the stored procedure
        proc_name = "SILVER.run_data_quality_checks_all"
        result = await sf_service.execute_procedure(
            proc_name,
            tpa,
            batch_id
        )
        
        logger.info(f"Quality check result: {result}")
        
        return {
            "success": True,
            "message": result,
            "tpa": tpa
        }
        
    except Exception as e:
        logger.error(f"Error running quality checks: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/quality/summary")
async def get_quality_summary(
    request: Request,
    tpa: Optional[str] = None
):
    """
    Get data quality summary for all tables or a specific TPA
    """
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        query = "SELECT * FROM SILVER.v_data_quality_summary"
        if tpa:
            query += f" WHERE tpa = '{tpa}'"
        query += " ORDER BY quality_score ASC, tpa, target_table"
        
        results = await sf_service.execute_query(query)
        
        return {
            "success": True,
            "data": results
        }
        
    except Exception as e:
        logger.error(f"Error getting quality summary: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/quality/failures")
async def get_quality_failures(
    request: Request,
    tpa: Optional[str] = None,
    table_name: Optional[str] = None
):
    """
    Get all failed data quality checks
    """
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        query = "SELECT * FROM SILVER.v_data_quality_failures WHERE 1=1"
        if tpa:
            query += f" AND tpa = '{tpa}'"
        if table_name:
            query += f" AND target_table LIKE '%{table_name.upper()}%'"
        query += " ORDER BY measured_timestamp DESC LIMIT 100"
        
        results = await sf_service.execute_query(query)
        
        return {
            "success": True,
            "data": results
        }
        
    except Exception as e:
        logger.error(f"Error getting quality failures: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/quality/trends")
async def get_quality_trends(
    request: Request,
    tpa: str,
    table_name: Optional[str] = None
):
    """
    Get quality score trends over time
    """
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        query = f"SELECT * FROM SILVER.v_data_quality_trends WHERE tpa = '{tpa}'"
        if table_name:
            query += f" AND target_table LIKE '%{table_name.upper()}%'"
        query += " ORDER BY measured_timestamp DESC LIMIT 50"
        
        results = await sf_service.execute_query(query)
        
        return {
            "success": True,
            "data": results
        }
        
    except Exception as e:
        logger.error(f"Error getting quality trends: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/quality/metrics")
async def get_quality_metrics(
    request: Request,
    tpa: str,
    table_name: str,
    batch_id: Optional[str] = None
):
    """
    Get detailed quality metrics for a specific table
    """
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Construct full table name
        full_table_name = f"{tpa.upper()}_{table_name.upper()}"
        
        query = f"""
            SELECT 
                metric_name,
                metric_value,
                metric_threshold,
                passed,
                description,
                measured_timestamp
            FROM SILVER.data_quality_metrics
            WHERE tpa = '{tpa}'
              AND target_table = '{full_table_name}'
        """
        
        if batch_id:
            query += f" AND batch_id = '{batch_id}'"
        else:
            # Get latest batch
            query += f"""
                AND batch_id = (
                    SELECT MAX(batch_id)
                    FROM SILVER.data_quality_metrics
                    WHERE tpa = '{tpa}'
                      AND target_table = '{full_table_name}'
                )
            """
        
        query += " ORDER BY metric_name"
        
        results = await sf_service.execute_query(query)
        
        return {
            "success": True,
            "table_name": full_table_name,
            "tpa": tpa,
            "metrics": results
        }
        
    except Exception as e:
        logger.error(f"Error getting quality metrics: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
