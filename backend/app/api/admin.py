"""
Admin API endpoints for system management and validation
"""
from fastapi import APIRouter, Request, HTTPException
from app.services.snowflake_service import SnowflakeService
from app.utils.auth_utils import get_caller_token
from app.config import settings
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

@router.get("/validate-schema")
async def validate_schema(request: Request):
    """Validate database schema completeness
    
    Checks that all required tables, procedures, and views exist
    Returns detailed status for each schema layer
    """
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        validation_result = {
            "overall_status": "COMPLETE",
            "bronze": {"status": "PASS", "required_count": 0, "existing_count": 0},
            "silver": {"status": "PASS", "required_count": 0, "existing_count": 0},
            "gold": {"status": "PASS", "required_count": 0, "existing_count": 0},
            "procedures": {"status": "PASS", "required_count": 0, "existing_count": 0},
            "critical_checks": [],
            "missing_tables": [],
            "missing_procedures": []
        }
        
        # Check BRONZE tables
        bronze_required = [
            'RAW_DATA_TABLE', 'TPA_MASTER', 'FILE_PROCESSING_LOGS', 
            'FILE_PROCESSING_QUEUE', 'API_REQUEST_LOGS', 'APPLICATION_LOGS', 
            'ERROR_LOGS', 'TASK_EXECUTION_LOGS'
        ]
        
        bronze_check = await sf_service.execute_query_dict(f"""
            WITH required_tables AS (
                SELECT 'RAW_DATA_TABLE' as table_name UNION ALL
                SELECT 'TPA_MASTER' UNION ALL
                SELECT 'FILE_PROCESSING_LOGS' UNION ALL
                SELECT 'FILE_PROCESSING_QUEUE' UNION ALL
                SELECT 'API_REQUEST_LOGS' UNION ALL
                SELECT 'APPLICATION_LOGS' UNION ALL
                SELECT 'ERROR_LOGS' UNION ALL
                SELECT 'TASK_EXECUTION_LOGS'
            ),
            existing_tables AS (
                SELECT table_name
                FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.TABLES
                WHERE table_schema = '{settings.BRONZE_SCHEMA_NAME}'
                  AND table_type = 'BASE TABLE'
            )
            SELECT 
                COUNT(DISTINCT rt.table_name) as required_count,
                COUNT(DISTINCT et.table_name) as existing_count
            FROM required_tables rt
            LEFT JOIN existing_tables et ON rt.table_name = et.table_name
        """)
        
        if bronze_check:
            validation_result["bronze"]["required_count"] = bronze_check[0]["REQUIRED_COUNT"]
            validation_result["bronze"]["existing_count"] = bronze_check[0]["EXISTING_COUNT"]
            validation_result["bronze"]["status"] = "PASS" if bronze_check[0]["REQUIRED_COUNT"] == bronze_check[0]["EXISTING_COUNT"] else "FAIL"
        
        # Check SILVER tables
        silver_required = [
            'TARGET_SCHEMAS', 'FIELD_MAPPINGS', 'TRANSFORMATION_RULES', 
            'CREATED_TABLES', 'LLM_PROMPT_TEMPLATES', 'SILVER_PROCESSING_LOG',
            'DATA_QUALITY_METRICS', 'QUARANTINE_RECORDS', 'PROCESSING_WATERMARKS'
        ]
        
        silver_check = await sf_service.execute_query_dict(f"""
            WITH required_tables AS (
                SELECT 'TARGET_SCHEMAS' as table_name UNION ALL
                SELECT 'FIELD_MAPPINGS' UNION ALL
                SELECT 'TRANSFORMATION_RULES' UNION ALL
                SELECT 'CREATED_TABLES' UNION ALL
                SELECT 'LLM_PROMPT_TEMPLATES' UNION ALL
                SELECT 'SILVER_PROCESSING_LOG' UNION ALL
                SELECT 'DATA_QUALITY_METRICS' UNION ALL
                SELECT 'QUARANTINE_RECORDS' UNION ALL
                SELECT 'PROCESSING_WATERMARKS'
            ),
            existing_tables AS (
                SELECT table_name
                FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.TABLES
                WHERE table_schema = '{settings.SILVER_SCHEMA_NAME}'
                  AND table_type IN ('BASE TABLE', 'HYBRID')
            )
            SELECT 
                COUNT(DISTINCT rt.table_name) as required_count,
                COUNT(DISTINCT et.table_name) as existing_count
            FROM required_tables rt
            LEFT JOIN existing_tables et ON rt.table_name = et.table_name
        """)
        
        if silver_check:
            validation_result["silver"]["required_count"] = silver_check[0]["REQUIRED_COUNT"]
            validation_result["silver"]["existing_count"] = silver_check[0]["EXISTING_COUNT"]
            validation_result["silver"]["status"] = "PASS" if silver_check[0]["REQUIRED_COUNT"] == silver_check[0]["EXISTING_COUNT"] else "FAIL"
        
        # Get missing Silver tables
        missing_silver = await sf_service.execute_query_dict(f"""
            WITH required_tables AS (
                SELECT 'TARGET_SCHEMAS' as table_name UNION ALL
                SELECT 'FIELD_MAPPINGS' UNION ALL
                SELECT 'TRANSFORMATION_RULES' UNION ALL
                SELECT 'CREATED_TABLES' UNION ALL
                SELECT 'LLM_PROMPT_TEMPLATES' UNION ALL
                SELECT 'SILVER_PROCESSING_LOG' UNION ALL
                SELECT 'DATA_QUALITY_METRICS' UNION ALL
                SELECT 'QUARANTINE_RECORDS' UNION ALL
                SELECT 'PROCESSING_WATERMARKS'
            ),
            existing_tables AS (
                SELECT table_name
                FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.TABLES
                WHERE table_schema = '{settings.SILVER_SCHEMA_NAME}'
                  AND table_type IN ('BASE TABLE', 'HYBRID')
            )
            SELECT rt.table_name as missing_table
            FROM required_tables rt
            LEFT JOIN existing_tables et ON rt.table_name = et.table_name
            WHERE et.table_name IS NULL
        """)
        
        if missing_silver:
            validation_result["missing_tables"].extend([row["MISSING_TABLE"] for row in missing_silver])
        
        # Check GOLD tables
        gold_check = await sf_service.execute_query_dict(f"""
            WITH required_tables AS (
                SELECT 'PROCESSING_LOG' as table_name UNION ALL
                SELECT 'QUALITY_CHECK_RESULTS' UNION ALL
                SELECT 'FIELD_MAPPINGS' UNION ALL
                SELECT 'TRANSFORMATION_RULES' UNION ALL
                SELECT 'TARGET_SCHEMAS' UNION ALL
                SELECT 'TARGET_FIELDS' UNION ALL
                SELECT 'QUALITY_RULES' UNION ALL
                SELECT 'MEMBER_JOURNEYS' UNION ALL
                SELECT 'JOURNEY_EVENTS' UNION ALL
                SELECT 'BUSINESS_METRICS'
            ),
            existing_tables AS (
                SELECT table_name
                FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.TABLES
                WHERE table_schema = 'GOLD'
                  AND table_type = 'BASE TABLE'
            )
            SELECT 
                COUNT(DISTINCT rt.table_name) as required_count,
                COUNT(DISTINCT et.table_name) as existing_count
            FROM required_tables rt
            LEFT JOIN existing_tables et ON rt.table_name = et.table_name
        """)
        
        if gold_check:
            validation_result["gold"]["required_count"] = gold_check[0]["REQUIRED_COUNT"]
            validation_result["gold"]["existing_count"] = gold_check[0]["EXISTING_COUNT"]
            validation_result["gold"]["status"] = "PASS" if gold_check[0]["REQUIRED_COUNT"] == gold_check[0]["EXISTING_COUNT"] else "FAIL"
        
        # Check SILVER procedures
        procedures_check = await sf_service.execute_query_dict(f"""
            WITH required_procedures AS (
                SELECT 'TRANSFORM_BRONZE_TO_SILVER' as procedure_name UNION ALL
                SELECT 'AUTO_MAP_FIELDS_ML' UNION ALL
                SELECT 'AUTO_MAP_FIELDS_LLM' UNION ALL
                SELECT 'APPROVE_FIELD_MAPPING' UNION ALL
                SELECT 'CREATE_SILVER_TABLE'
            ),
            existing_procedures AS (
                SELECT procedure_name
                FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.PROCEDURES
                WHERE procedure_schema = '{settings.SILVER_SCHEMA_NAME}'
            )
            SELECT 
                COUNT(DISTINCT rp.procedure_name) as required_count,
                COUNT(DISTINCT ep.procedure_name) as existing_count
            FROM required_procedures rp
            LEFT JOIN existing_procedures ep ON rp.procedure_name = ep.procedure_name
        """)
        
        if procedures_check:
            validation_result["procedures"]["required_count"] = procedures_check[0]["REQUIRED_COUNT"]
            validation_result["procedures"]["existing_count"] = procedures_check[0]["EXISTING_COUNT"]
            validation_result["procedures"]["status"] = "PASS" if procedures_check[0]["REQUIRED_COUNT"] == procedures_check[0]["EXISTING_COUNT"] else "FAIL"
        
        # Get missing procedures
        missing_procs = await sf_service.execute_query_dict(f"""
            WITH required_procedures AS (
                SELECT 'TRANSFORM_BRONZE_TO_SILVER' as procedure_name UNION ALL
                SELECT 'AUTO_MAP_FIELDS_ML' UNION ALL
                SELECT 'AUTO_MAP_FIELDS_LLM' UNION ALL
                SELECT 'APPROVE_FIELD_MAPPING' UNION ALL
                SELECT 'CREATE_SILVER_TABLE'
            ),
            existing_procedures AS (
                SELECT procedure_name
                FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.PROCEDURES
                WHERE procedure_schema = '{settings.SILVER_SCHEMA_NAME}'
            )
            SELECT rp.procedure_name as missing_procedure
            FROM required_procedures rp
            LEFT JOIN existing_procedures ep ON rp.procedure_name = ep.procedure_name
            WHERE ep.procedure_name IS NULL
        """)
        
        if missing_procs:
            validation_result["missing_procedures"].extend([row["MISSING_PROCEDURE"] for row in missing_procs])
        
        # Critical checks
        critical_checks = []
        
        # Check transform readiness
        transform_ready = await sf_service.execute_query_dict(f"""
            SELECT 
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.TABLES 
                        WHERE table_schema = '{settings.SILVER_SCHEMA_NAME}' 
                        AND table_name = 'SILVER_PROCESSING_LOG'
                    )
                    AND EXISTS (
                        SELECT 1 FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.PROCEDURES 
                        WHERE procedure_schema = '{settings.SILVER_SCHEMA_NAME}' 
                        AND procedure_name = 'TRANSFORM_BRONZE_TO_SILVER'
                    )
                    THEN 'READY'
                    ELSE 'NOT READY'
                END as status,
                CASE 
                    WHEN NOT EXISTS (
                        SELECT 1 FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.TABLES 
                        WHERE table_schema = '{settings.SILVER_SCHEMA_NAME}' 
                        AND table_name = 'SILVER_PROCESSING_LOG'
                    )
                    THEN 'Missing: silver_processing_log table'
                    WHEN NOT EXISTS (
                        SELECT 1 FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.PROCEDURES 
                        WHERE procedure_schema = '{settings.SILVER_SCHEMA_NAME}' 
                        AND procedure_name = 'TRANSFORM_BRONZE_TO_SILVER'
                    )
                    THEN 'Missing: transform_bronze_to_silver procedure'
                    ELSE 'All components present'
                END as details
        """)
        
        if transform_ready:
            critical_checks.append({
                "check_name": "Transform Readiness",
                "status": transform_ready[0]["STATUS"],
                "details": transform_ready[0]["DETAILS"]
            })
        
        # Check auto-mapping readiness
        mapping_ready = await sf_service.execute_query_dict(f"""
            SELECT 
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.TABLES 
                        WHERE table_schema = '{settings.SILVER_SCHEMA_NAME}' 
                        AND table_name = 'LLM_PROMPT_TEMPLATES'
                    )
                    AND EXISTS (
                        SELECT 1 FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.PROCEDURES 
                        WHERE procedure_schema = '{settings.SILVER_SCHEMA_NAME}' 
                        AND procedure_name = 'AUTO_MAP_FIELDS_LLM'
                    )
                    AND EXISTS (
                        SELECT 1 FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.PROCEDURES 
                        WHERE procedure_schema = '{settings.SILVER_SCHEMA_NAME}' 
                        AND procedure_name = 'AUTO_MAP_FIELDS_ML'
                    )
                    THEN 'READY'
                    ELSE 'NOT READY'
                END as status,
                CASE 
                    WHEN NOT EXISTS (
                        SELECT 1 FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.TABLES 
                        WHERE table_schema = '{settings.SILVER_SCHEMA_NAME}' 
                        AND table_name = 'LLM_PROMPT_TEMPLATES'
                    )
                    THEN 'Missing: llm_prompt_templates table'
                    WHEN NOT EXISTS (
                        SELECT 1 FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.PROCEDURES 
                        WHERE procedure_schema = '{settings.SILVER_SCHEMA_NAME}' 
                        AND procedure_name = 'AUTO_MAP_FIELDS_LLM'
                    )
                    THEN 'Missing: auto_map_fields_llm procedure'
                    WHEN NOT EXISTS (
                        SELECT 1 FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.PROCEDURES 
                        WHERE procedure_schema = '{settings.SILVER_SCHEMA_NAME}' 
                        AND procedure_name = 'AUTO_MAP_FIELDS_ML'
                    )
                    THEN 'Missing: auto_map_fields_ml procedure'
                    ELSE 'All components present'
                END as details
        """)
        
        if mapping_ready:
            critical_checks.append({
                "check_name": "Auto-Mapping Readiness",
                "status": mapping_ready[0]["STATUS"],
                "details": mapping_ready[0]["DETAILS"]
            })
        
        validation_result["critical_checks"] = critical_checks
        
        # Determine overall status
        if (validation_result["bronze"]["status"] == "PASS" and 
            validation_result["silver"]["status"] == "PASS" and 
            validation_result["gold"]["status"] == "PASS" and 
            validation_result["procedures"]["status"] == "PASS" and
            all(check["status"] == "READY" for check in critical_checks)):
            validation_result["overall_status"] = "COMPLETE"
        else:
            validation_result["overall_status"] = "INCOMPLETE"
        
        logger.info(f"Schema validation completed: {validation_result['overall_status']}")
        return validation_result
        
    except Exception as e:
        logger.error(f"Schema validation failed: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
