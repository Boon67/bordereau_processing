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
    """Get list of available Cortex LLM models"""
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
        return [row['MODEL_NAME'] for row in result]
    except Exception as e:
        logger.error(f"Failed to get Cortex models: {str(e)}")
        # Return a default list if the query fails
        return [
            'llama3.1-70b',
            'llama3.1-8b',
            'mistral-large',
            'mixtral-8x7b',
            'gemma-7b'
        ]

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
    """Delete entire table schema (all columns for a table)"""
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
        
        # Delete all columns for this table
        delete_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.target_schemas
            WHERE table_name = '{escaped_table_name}'
        """
        await sf_service.execute_query(delete_query)
        
        logger.info(f"Deleted table schema '{table_name}' for TPA '{tpa}' ({result[0]['COUNT']} columns)")
        return {
            "message": f"Table schema '{table_name}' deleted successfully",
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
            LEFT JOIN INFORMATION_SCHEMA.TABLES ist 
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
            FROM INFORMATION_SCHEMA.TABLES
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
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        # Use fully qualified procedure name
        proc_name = f"{settings.SILVER_SCHEMA_NAME}.create_silver_table"
        result = await sf_service.execute_procedure(proc_name, table_name, tpa)
        
        # Extract the actual table name from the result
        physical_table_name = f"{tpa.upper()}_{table_name.upper()}"
        
        return {
            "message": f"Table {physical_table_name} created successfully",
            "physical_table_name": physical_table_name,
            "result": result
        }
    except Exception as e:
        logger.error(f"Failed to create table: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/tables/delete")
async def delete_physical_table(request: Request, table_name: str, tpa: str):
    """Delete physical Silver table
    
    Deletes the physical table with name format: {TPA}_{TABLE_NAME}
    Example: PROVIDER_A_MEDICAL_CLAIMS
    
    WARNING: This will permanently delete the table and all its data.
    """
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Construct the physical table name
        physical_table_name = f"{tpa.upper()}_{table_name.upper()}"
        
        logger.info(f"Attempting to delete physical table: {physical_table_name} for TPA: {tpa}")
        
        # Drop the physical table
        drop_query = f"DROP TABLE IF EXISTS {settings.SILVER_SCHEMA_NAME}.{physical_table_name}"
        await sf_service.execute_query(drop_query)
        logger.info(f"Physical table {physical_table_name} dropped successfully")
        
        # Remove from created_tables tracking (escape single quotes for SQL safety)
        escaped_table_name = physical_table_name.replace("'", "''")
        escaped_tpa = tpa.replace("'", "''")
        delete_tracking_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.created_tables
            WHERE physical_table_name = '{escaped_table_name}'
              AND tpa = '{escaped_tpa}'
        """
        await sf_service.execute_query(delete_tracking_query)
        logger.info(f"Removed {physical_table_name} from created_tables tracking")
        
        logger.info(f"Successfully deleted physical table {physical_table_name} for TPA {tpa}")
        
        return {
            "message": f"Table {physical_table_name} deleted successfully",
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
    """Get statistics for a Silver layer table"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Construct the physical table name
        physical_table_name = f"{tpa.upper()}_{table_name.upper()}"
        
        # Get table statistics
        stats_query = f"""
            SELECT 
                COUNT(*) as TOTAL_RECORDS,
                MAX(CREATED_TIMESTAMP) as LAST_UPDATED
            FROM {settings.SILVER_SCHEMA_NAME}.{physical_table_name}
        """
        
        result = await sf_service.execute_query_dict(stats_query)
        
        if result and len(result) > 0:
            return {
                "total_records": result[0]['TOTAL_RECORDS'] or 0,
                "last_updated": result[0]['LAST_UPDATED'],
                "data_quality_score": 95  # Placeholder - could be calculated from validation rules
            }
        else:
            return {
                "total_records": 0,
                "last_updated": None,
                "data_quality_score": 0
            }
    except Exception as e:
        logger.error(f"Failed to get Silver data stats: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/mappings")
async def get_field_mappings(request: Request, tpa: str, target_table: Optional[str] = None):
    """Get field mappings"""
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
            FROM {settings.SILVER_SCHEMA_NAME}.INFORMATION_SCHEMA.COLUMNS
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
                FROM {settings.SILVER_SCHEMA_NAME}.INFORMATION_SCHEMA.COLUMNS
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
        logger.info(f"ML auto-mapping completed: {result}")
        return {"message": "ML auto-mapping completed", "result": result}
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
        result = await sf_service.execute_procedure(
            "auto_map_fields_llm",
            mapping_request.source_table,
            mapping_request.target_table,
            mapping_request.tpa,
            mapping_request.model_name,
            "DEFAULT_FIELD_MAPPING"
        )
        logger.info(f"LLM auto-mapping completed: {result}")
        return {"message": "LLM auto-mapping completed", "result": result}
    except asyncio.TimeoutError:
        logger.error(f"LLM auto-mapping timed out for TPA {mapping_request.tpa}")
        raise HTTPException(
            status_code=504,
            detail="Procedure execution timed out. LLM processing can take longer for large datasets."
        )
    except Exception as e:
        logger.error(f"LLM auto-mapping failed: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

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
            mappings_query = f"""
                SELECT target_column
                FROM {settings.SILVER_SCHEMA_NAME}.field_mappings
                WHERE target_table = '{transform_request.target_table.upper()}'
                  AND tpa = '{transform_request.tpa}'
                  AND approved = TRUE
                  AND active = TRUE
            """
            mappings = await sf_service.execute_query_dict(mappings_query)
            
            if not mappings or len(mappings) == 0:
                raise HTTPException(
                    status_code=400,
                    detail=f"No approved mappings found for table '{transform_request.target_table}' and TPA '{transform_request.tpa}'. Please create and approve mappings first."
                )
            
            # Check if physical table exists and validate columns
            physical_table_name = f"{transform_request.tpa.upper()}_{transform_request.target_table.upper()}"
            columns_query = f"""
                SELECT column_name
                FROM {settings.SILVER_SCHEMA_NAME}.INFORMATION_SCHEMA.COLUMNS
                WHERE table_schema = '{settings.SILVER_SCHEMA_NAME}'
                  AND table_name = '{physical_table_name}'
            """
            columns_result = await sf_service.execute_query_dict(columns_query)
            existing_columns = {row['COLUMN_NAME'].upper() for row in columns_result}
            
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
                
        except HTTPException:
            raise
        except Exception as e:
            logger.warning(f"Could not pre-validate mappings: {str(e)}. Proceeding with transformation...")
        
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
