"""
Silver Layer API Endpoints
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import logging

from app.services.snowflake_service import SnowflakeService
from app.config import settings

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
async def get_target_schemas(tpa: str, table_name: Optional[str] = None):
    """Get target schemas"""
    try:
        sf_service = SnowflakeService()
        return sf_service.get_target_schemas(tpa, table_name)
    except Exception as e:
        logger.error(f"Failed to get target schemas: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/schemas")
async def create_target_schema(schema: TargetSchemaCreate):
    """Create target schema definition"""
    try:
        sf_service = SnowflakeService()
        query = f"""
            INSERT INTO {settings.SILVER_SCHEMA_NAME}.target_schemas
            (table_name, column_name, tpa, data_type, nullable, default_value, description)
            VALUES ('{schema.table_name.upper()}', '{schema.column_name.upper()}', '{schema.tpa}',
                    '{schema.data_type}', {schema.nullable}, 
                    {'NULL' if not schema.default_value else f"'{schema.default_value}'"},
                    {'NULL' if not schema.description else f"'{schema.description}'"})
        """
        sf_service.execute_query(query)
        return {"message": "Target schema created successfully"}
    except Exception as e:
        logger.error(f"Failed to create target schema: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/schemas/{schema_id}")
async def update_target_schema(schema_id: int, schema: TargetSchemaUpdate):
    """Update target schema definition"""
    try:
        sf_service = SnowflakeService()
        
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
        sf_service.execute_query(query)
        return {"message": "Target schema updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update target schema: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/schemas/{schema_id}")
async def delete_target_schema(schema_id: int):
    """Delete target schema column definition"""
    try:
        sf_service = SnowflakeService()
        query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.target_schemas
            WHERE schema_id = {schema_id}
        """
        sf_service.execute_query(query)
        return {"message": "Target schema column deleted successfully"}
    except Exception as e:
        logger.error(f"Failed to delete target schema: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/schemas/table/{table_name}")
async def delete_table_schema(table_name: str, tpa: str):
    """Delete entire table schema (all columns for a table)"""
    try:
        sf_service = SnowflakeService()
        
        # First check if table exists
        check_query = f"""
            SELECT COUNT(*) as count
            FROM {settings.SILVER_SCHEMA_NAME}.target_schemas
            WHERE table_name = '{table_name.upper()}' AND tpa = '{tpa}' AND active = TRUE
        """
        result = sf_service.execute_query_dict(check_query)
        
        if not result or result[0]['COUNT'] == 0:
            raise HTTPException(status_code=404, detail=f"Table schema '{table_name}' not found for TPA '{tpa}'")
        
        # Delete all columns for this table
        delete_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.target_schemas
            WHERE table_name = '{table_name.upper()}' AND tpa = '{tpa}'
        """
        sf_service.execute_query(delete_query)
        
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

@router.get("/tables/exists")
async def check_table_exists(table_name: str, tpa: str):
    """Check if a physical Silver table exists
    
    Checks for table with name format: {TPA}_{TABLE_NAME}
    """
    try:
        sf_service = SnowflakeService()
        physical_table_name = f"{tpa.upper()}_{table_name.upper()}"
        
        query = f"""
            SELECT COUNT(*) as count
            FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = '{settings.SILVER_SCHEMA_NAME}'
              AND TABLE_NAME = '{physical_table_name}'
        """
        result = sf_service.execute_query_dict(query)
        exists = result[0]['COUNT'] > 0 if result else False
        
        return {
            "exists": exists,
            "physical_table_name": physical_table_name
        }
    except Exception as e:
        logger.error(f"Failed to check table existence: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/tables/create")
async def create_silver_table(table_name: str, tpa: str):
    """Create physical Silver table from schema metadata
    
    Creates a table with name format: {TPA}_{TABLE_NAME}
    Example: PROVIDER_A_MEDICAL_CLAIMS
    """
    try:
        sf_service = SnowflakeService()
        # Use fully qualified procedure name
        proc_name = f"{settings.SILVER_SCHEMA_NAME}.create_silver_table"
        result = sf_service.execute_procedure(proc_name, table_name, tpa)
        
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
async def get_field_mappings(tpa: str, target_table: Optional[str] = None):
    """Get field mappings"""
    try:
        sf_service = SnowflakeService()
        return sf_service.get_field_mappings(tpa, target_table)
    except Exception as e:
        logger.error(f"Failed to get field mappings: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/mappings")
async def create_field_mapping(mapping: FieldMappingCreate):
    """Create field mapping"""
    try:
        sf_service = SnowflakeService()
        query = f"""
            INSERT INTO {settings.SILVER_SCHEMA_NAME}.field_mappings
            (source_field, target_table, target_column, tpa, mapping_method, transformation_logic, description, approved)
            VALUES ('{mapping.source_field.upper()}', '{mapping.target_table.upper()}', 
                    '{mapping.target_column.upper()}', '{mapping.tpa}', 'MANUAL',
                    {'NULL' if not mapping.transformation_logic else f"'{mapping.transformation_logic}'"},
                    {'NULL' if not mapping.description else f"'{mapping.description}'"}, TRUE)
        """
        sf_service.execute_query(query)
        return {"message": "Field mapping created successfully"}
    except Exception as e:
        logger.error(f"Failed to create field mapping: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/mappings/auto-ml")
async def auto_map_fields_ml(
    source_table: str,
    target_table: str,
    tpa: str,
    top_n: int = 3,
    min_confidence: float = 0.6
):
    """Auto-map fields using ML"""
    try:
        sf_service = SnowflakeService()
        result = sf_service.execute_procedure(
            "auto_map_fields_ml",
            source_table,
            target_table,
            top_n,
            min_confidence
        )
        return {"message": "ML auto-mapping completed", "result": result}
    except Exception as e:
        logger.error(f"ML auto-mapping failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/mappings/auto-llm")
async def auto_map_fields_llm(
    source_table: str,
    target_table: str,
    tpa: str,
    model_name: str = "llama3.1-70b"
):
    """Auto-map fields using LLM"""
    try:
        sf_service = SnowflakeService()
        result = sf_service.execute_procedure(
            "auto_map_fields_llm",
            source_table,
            target_table,
            model_name,
            "DEFAULT_FIELD_MAPPING"
        )
        return {"message": "LLM auto-mapping completed", "result": result}
    except Exception as e:
        logger.error(f"LLM auto-mapping failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/mappings/{mapping_id}/approve")
async def approve_mapping(mapping_id: int):
    """Approve a field mapping"""
    try:
        sf_service = SnowflakeService()
        result = sf_service.execute_procedure("approve_field_mapping", mapping_id)
        return {"message": "Mapping approved successfully", "result": result}
    except Exception as e:
        logger.error(f"Failed to approve mapping: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/transform")
async def transform_bronze_to_silver(request: TransformRequest):
    """Transform Bronze data to Silver"""
    try:
        sf_service = SnowflakeService()
        result = sf_service.execute_procedure(
            "transform_bronze_to_silver",
            request.source_table,
            request.target_table,
            request.tpa,
            request.source_schema,
            request.batch_size,
            request.apply_rules,
            request.incremental
        )
        return {"message": "Transformation completed", "result": result}
    except Exception as e:
        logger.error(f"Transformation failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
