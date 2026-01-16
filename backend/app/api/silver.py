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

@router.post("/tables/create")
async def create_silver_table(table_name: str, tpa: str):
    """Create Silver table from metadata"""
    try:
        sf_service = SnowflakeService()
        result = sf_service.execute_procedure("create_silver_table", table_name, tpa)
        return {"message": "Table created successfully", "result": result}
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
