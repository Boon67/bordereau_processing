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
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        query = f"""
            INSERT INTO {settings.SILVER_SCHEMA_NAME}.target_schemas
            (table_name, column_name, data_type, nullable, default_value, description)
            VALUES ('{schema.table_name.upper()}', '{schema.column_name.upper()}',
                    '{schema.data_type}', {schema.nullable}, 
                    {'NULL' if not schema.default_value else f"'{schema.default_value}'"},
                    {'NULL' if not schema.description else f"'{schema.description}'"})
        """
        await sf_service.execute_query(query)
        
        # Invalidate schema cache
        cache.clear("schemas")
        
        return {"message": "Target schema created successfully"}
    except Exception as e:
        logger.error(f"Failed to create target schema: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/schemas/{schema_id}")
async def update_target_schema(request: Request, schema_id: int, schema: TargetSchemaUpdate):
    """Update target schema definition"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Build update query dynamically based on provided fields
        update_fields = []
        if schema.data_type is not None:
            update_fields.append(f"data_type = '{schema.data_type}'")
        if schema.nullable is not None:
            update_fields.append(f"nullable = {schema.nullable}")
        if schema.default_value is not None:
            update_fields.append(f"default_value = '{schema.default_value}'")
        if schema.description is not None:
            update_fields.append(f"description = '{schema.description}'")
        
        if not update_fields:
            raise HTTPException(status_code=400, detail="No fields to update")
        
        query = f"""
            UPDATE {settings.SILVER_SCHEMA_NAME}.target_schemas
            SET {', '.join(update_fields)}, updated_at = CURRENT_TIMESTAMP()
            WHERE schema_id = {schema_id}
        """
        await sf_service.execute_query(query)
        
        # Invalidate schema cache
        cache.clear("schemas")
        
        return {"message": "Target schema updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update target schema: {str(e)}")
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
        check_query = f"""
            SELECT COUNT(*) as count
            FROM {settings.SILVER_SCHEMA_NAME}.target_schemas
            WHERE table_name = '{table_name.upper()}' AND tpa = '{tpa}' AND active = TRUE
        """
        result = await sf_service.execute_query_dict(check_query)
        
        if not result or result[0]['COUNT'] == 0:
            raise HTTPException(status_code=404, detail=f"Table schema '{table_name}' not found for TPA '{tpa}'")
        
        # Delete all columns for this table
        delete_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.target_schemas
            WHERE table_name = '{table_name.upper()}' AND tpa = '{tpa}'
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

@router.get("/mappings")
async def get_field_mappings(request: Request, tpa: str, target_table: Optional[str] = None):
    """Get field mappings"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        return await sf_service.get_field_mappings(tpa, target_table)
    except Exception as e:
        logger.error(f"Failed to get field mappings: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/mappings")
async def create_field_mapping(request: Request, mapping: FieldMappingCreate):
    """Create field mapping"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
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
    """Transform Bronze data to Silver"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        result = await sf_service.execute_procedure(
            "transform_bronze_to_silver",
            transform_request.source_table,
            transform_request.target_table,
            transform_request.tpa,
            transform_request.source_schema,
            transform_request.batch_size,
            transform_request.apply_rules,
            transform_request.incremental
        )
        return {"message": "Transformation completed", "result": result}
    except Exception as e:
        logger.error(f"Transformation failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
