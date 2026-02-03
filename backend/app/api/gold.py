"""
Gold Layer API Endpoints
"""

from fastapi import APIRouter, Request, HTTPException
from pydantic import BaseModel
from typing import Optional
import logging

from app.services.snowflake_service import SnowflakeService
from app.config import settings
from app.utils.auth_utils import get_caller_token

logger = logging.getLogger(__name__)
router = APIRouter()

class RuleStatusUpdate(BaseModel):
    is_active: bool

@router.get("/analytics/{table_name}")
async def get_gold_table_data(request: Request, table_name: str, tpa: str, limit: int = 100):
    """Get data from Gold analytics tables"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Validate table name to prevent SQL injection
        valid_tables = ['CLAIMS_ANALYTICS', 'MEMBER_360', 'PROVIDER_PERFORMANCE', 'FINANCIAL_SUMMARY']
        if table_name.upper() not in valid_tables:
            raise HTTPException(status_code=400, detail=f"Invalid table name. Must be one of: {valid_tables}")
        
        # Check if Gold schema exists
        check_schema = f"""
            SELECT COUNT(*) as cnt 
            FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.SCHEMATA 
            WHERE SCHEMA_NAME = 'GOLD' AND CATALOG_NAME = '{settings.DATABASE_NAME}'
        """
        schema_result = await sf_service.execute_query_dict(check_schema)
        if not schema_result or schema_result[0]['CNT'] == 0:
            return []
        
        # Build query with TPA filter
        tpa_suffix = f"_{tpa}" if tpa != 'ALL' else "_ALL"
        full_table_name = f"{table_name.upper()}{tpa_suffix}"
        
        query = f"""
            SELECT *
            FROM {settings.DATABASE_NAME}.GOLD.{full_table_name}
            ORDER BY UPDATED_AT DESC
            LIMIT {limit}
        """
        
        return await sf_service.execute_query_dict(query)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get Gold table data: {str(e)}")
        if "does not exist" in str(e).lower() or "invalid" in str(e).lower():
            return []
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/analytics/{table_name}/stats")
async def get_gold_stats(request: Request, table_name: str, tpa: str):
    """Get statistics for Gold analytics table"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Validate table name
        valid_tables = ['CLAIMS_ANALYTICS', 'MEMBER_360', 'PROVIDER_PERFORMANCE', 'FINANCIAL_SUMMARY']
        if table_name.upper() not in valid_tables:
            raise HTTPException(status_code=400, detail=f"Invalid table name. Must be one of: {valid_tables}")
        
        # Check if Gold schema exists
        check_schema = f"""
            SELECT COUNT(*) as cnt 
            FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.SCHEMATA 
            WHERE SCHEMA_NAME = 'GOLD' AND CATALOG_NAME = '{settings.DATABASE_NAME}'
        """
        schema_result = await sf_service.execute_query_dict(check_schema)
        if not schema_result or schema_result[0]['CNT'] == 0:
            return {"total_records": 0, "last_updated": None, "status": "No Data", "quality_score": 0}
        
        tpa_suffix = f"_{tpa}" if tpa != 'ALL' else "_ALL"
        full_table_name = f"{table_name.upper()}{tpa_suffix}"
        
        query = f"""
            SELECT 
                COUNT(*) as total_records,
                MAX(UPDATED_AT) as last_updated,
                'Active' as status
            FROM {settings.DATABASE_NAME}.GOLD.{full_table_name}
        """
        
        result = await sf_service.execute_query_dict(query)
        if result and len(result) > 0:
            stats = result[0]
            stats['quality_score'] = 100  # Default quality score
            return stats
        return {"total_records": 0, "last_updated": None, "status": "No Data", "quality_score": 0}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get Gold stats: {str(e)}")
        if "does not exist" in str(e).lower() or "invalid" in str(e).lower():
            return {"total_records": 0, "last_updated": None, "status": "No Data", "quality_score": 0}
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/metrics")
async def get_business_metrics(request: Request, tpa: str):
    """Get business metrics for TPA"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Check if Gold schema exists
        check_schema = f"""
            SELECT COUNT(*) as cnt 
            FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.SCHEMATA 
            WHERE SCHEMA_NAME = 'GOLD' AND CATALOG_NAME = '{settings.DATABASE_NAME}'
        """
        schema_result = await sf_service.execute_query_dict(check_schema)
        if not schema_result or schema_result[0]['CNT'] == 0:
            return []
        
        query = f"""
            SELECT 
                METRIC_ID,
                METRIC_NAME,
                METRIC_CATEGORY,
                TPA,
                CALCULATION_LOGIC,
                SOURCE_TABLES,
                REFRESH_FREQUENCY,
                METRIC_OWNER,
                DESCRIPTION,
                IS_ACTIVE,
                CREATED_AT,
                UPDATED_AT
            FROM {settings.DATABASE_NAME}.GOLD.business_metrics
            WHERE TPA = '{tpa}' OR TPA = 'ALL'
            ORDER BY METRIC_CATEGORY, METRIC_NAME
        """
        
        return await sf_service.execute_query_dict(query)
    except Exception as e:
        logger.error(f"Failed to get business metrics: {str(e)}")
        # Return empty array instead of error for missing tables
        if "does not exist" in str(e).lower() or "invalid" in str(e).lower():
            return []
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/quality/results")
async def get_quality_check_results(request: Request, tpa: str, limit: int = 100):
    """Get quality check results for TPA"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Check if Gold schema exists
        check_schema = f"""
            SELECT COUNT(*) as cnt 
            FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.SCHEMATA 
            WHERE SCHEMA_NAME = 'GOLD' AND CATALOG_NAME = '{settings.DATABASE_NAME}'
        """
        schema_result = await sf_service.execute_query_dict(check_schema)
        if not schema_result or schema_result[0]['CNT'] == 0:
            return []
        
        query = f"""
            SELECT 
                CHECK_ID,
                QUALITY_RULE_ID,
                TABLE_NAME,
                TPA,
                CHECK_TIMESTAMP,
                CHECK_STATUS,
                RECORDS_CHECKED,
                RECORDS_FAILED,
                ERROR_MESSAGE,
                EXECUTION_TIME_MS,
                CHECKED_BY
            FROM {settings.DATABASE_NAME}.GOLD.quality_check_results
            WHERE TPA = '{tpa}' OR TPA = 'ALL'
            ORDER BY CHECK_TIMESTAMP DESC
            LIMIT {limit}
        """
        
        results = await sf_service.execute_query_dict(query)
        
        # Enrich with rule information
        for result in results:
            if result.get('QUALITY_RULE_ID'):
                rule_query = f"""
                    SELECT RULE_NAME, SEVERITY, CHECK_LOGIC, ACTION_ON_FAILURE
                    FROM {settings.DATABASE_NAME}.GOLD.quality_rules
                    WHERE QUALITY_RULE_ID = {result['QUALITY_RULE_ID']}
                """
                rule_data = await sf_service.execute_query_dict(rule_query)
                if rule_data and len(rule_data) > 0:
                    result.update(rule_data[0])
        
        return results
    except Exception as e:
        logger.error(f"Failed to get quality check results: {str(e)}")
        if "does not exist" in str(e).lower() or "invalid" in str(e).lower():
            return []
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/quality/stats")
async def get_quality_stats(request: Request, tpa: str):
    """Get quality statistics for TPA"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Check if Gold schema exists
        check_schema = f"""
            SELECT COUNT(*) as cnt 
            FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.SCHEMATA 
            WHERE SCHEMA_NAME = 'GOLD' AND CATALOG_NAME = '{settings.DATABASE_NAME}'
        """
        schema_result = await sf_service.execute_query_dict(check_schema)
        if not schema_result or schema_result[0]['CNT'] == 0:
            return {"total_checks": 0, "passed_checks": 0, "failed_checks": 0, "warning_checks": 0, "pass_rate": 0}
        
        query = f"""
            SELECT 
                COUNT(*) as total_checks,
                SUM(CASE WHEN CHECK_STATUS = 'PASSED' THEN 1 ELSE 0 END) as passed_checks,
                SUM(CASE WHEN CHECK_STATUS = 'FAILED' THEN 1 ELSE 0 END) as failed_checks,
                SUM(CASE WHEN CHECK_STATUS = 'WARNING' THEN 1 ELSE 0 END) as warning_checks,
                AVG(CASE WHEN CHECK_STATUS = 'PASSED' THEN 100 ELSE 0 END) as pass_rate
            FROM {settings.DATABASE_NAME}.GOLD.quality_check_results
            WHERE TPA = '{tpa}' OR TPA = 'ALL'
        """
        
        result = await sf_service.execute_query_dict(query)
        return result[0] if result and len(result) > 0 else {"total_checks": 0, "passed_checks": 0, "failed_checks": 0, "warning_checks": 0, "pass_rate": 0}
    except Exception as e:
        logger.error(f"Failed to get quality stats: {str(e)}")
        if "does not exist" in str(e).lower() or "invalid" in str(e).lower():
            return {"total_checks": 0, "passed_checks": 0, "failed_checks": 0, "warning_checks": 0, "pass_rate": 0}
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/rules/transformation")
async def get_transformation_rules(request: Request, tpa: str):
    """Get transformation rules for TPA"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Check if Gold schema exists
        check_schema = f"""
            SELECT COUNT(*) as cnt 
            FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.SCHEMATA 
            WHERE SCHEMA_NAME = 'GOLD' AND CATALOG_NAME = '{settings.DATABASE_NAME}'
        """
        schema_result = await sf_service.execute_query_dict(check_schema)
        if not schema_result or schema_result[0]['CNT'] == 0:
            return []
        
        query = f"""
            SELECT 
                RULE_ID,
                RULE_NAME,
                RULE_TYPE,
                TPA,
                SOURCE_TABLE,
                TARGET_TABLE,
                RULE_LOGIC,
                RULE_DESCRIPTION,
                BUSINESS_JUSTIFICATION,
                PRIORITY,
                EXECUTION_ORDER,
                IS_ACTIVE,
                CREATED_AT,
                UPDATED_AT
            FROM {settings.DATABASE_NAME}.GOLD.transformation_rules
            WHERE TPA = '{tpa}' OR TPA = 'ALL'
            ORDER BY EXECUTION_ORDER, PRIORITY
        """
        
        return await sf_service.execute_query_dict(query)
    except Exception as e:
        logger.error(f"Failed to get transformation rules: {str(e)}")
        if "does not exist" in str(e).lower() or "invalid" in str(e).lower():
            return []
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/rules/quality")
async def get_quality_rules(request: Request, tpa: str):
    """Get quality rules for TPA"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Check if Gold schema exists
        check_schema = f"""
            SELECT COUNT(*) as cnt 
            FROM {settings.DATABASE_NAME}.INFORMATION_SCHEMA.SCHEMATA 
            WHERE SCHEMA_NAME = 'GOLD' AND CATALOG_NAME = '{settings.DATABASE_NAME}'
        """
        schema_result = await sf_service.execute_query_dict(check_schema)
        if not schema_result or schema_result[0]['CNT'] == 0:
            return []
        
        query = f"""
            SELECT 
                QUALITY_RULE_ID,
                RULE_NAME,
                RULE_TYPE,
                TABLE_NAME,
                TPA,
                FIELD_NAME,
                CHECK_LOGIC,
                THRESHOLD_VALUE,
                THRESHOLD_OPERATOR,
                SEVERITY,
                ACTION_ON_FAILURE,
                RULE_DESCRIPTION,
                IS_ACTIVE,
                CREATED_AT,
                UPDATED_AT
            FROM {settings.DATABASE_NAME}.GOLD.quality_rules
            WHERE TPA = '{tpa}' OR TPA = 'ALL'
            ORDER BY SEVERITY DESC, RULE_NAME
        """
        
        return await sf_service.execute_query_dict(query)
    except Exception as e:
        logger.error(f"Failed to get quality rules: {str(e)}")
        if "does not exist" in str(e).lower() or "invalid" in str(e).lower():
            return []
        raise HTTPException(status_code=500, detail=str(e))

@router.patch("/rules/transformation/{rule_id}/status")
async def update_transformation_rule_status(request: Request, rule_id: int, status: RuleStatusUpdate):
    """Update transformation rule active status"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        query = f"""
            UPDATE {settings.DATABASE_NAME}.GOLD.transformation_rules
            SET IS_ACTIVE = {status.is_active}, UPDATED_AT = CURRENT_TIMESTAMP()
            WHERE RULE_ID = {rule_id}
        """
        
        await sf_service.execute_query(query)
        
        return {
            "message": f"Rule {'activated' if status.is_active else 'deactivated'} successfully",
            "rule_id": rule_id,
            "is_active": status.is_active
        }
    except Exception as e:
        logger.error(f"Failed to update transformation rule status: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.patch("/rules/quality/{rule_id}/status")
async def update_quality_rule_status(request: Request, rule_id: int, status: RuleStatusUpdate):
    """Update quality rule active status"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        query = f"""
            UPDATE {settings.DATABASE_NAME}.GOLD.quality_rules
            SET IS_ACTIVE = {status.is_active}, UPDATED_AT = CURRENT_TIMESTAMP()
            WHERE QUALITY_RULE_ID = {rule_id}
        """
        
        await sf_service.execute_query(query)
        
        return {
            "message": f"Rule {'activated' if status.is_active else 'deactivated'} successfully",
            "rule_id": rule_id,
            "is_active": status.is_active
        }
    except Exception as e:
        logger.error(f"Failed to update quality rule status: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# ============================================
# Task Management Endpoints
# ============================================

@router.get("/tasks")
async def get_gold_tasks(request: Request):
    """Get Gold tasks status with predecessor information"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        query = f"SHOW TASKS IN SCHEMA {settings.GOLD_SCHEMA_NAME}"
        tasks = await sf_service.execute_query_dict(query, timeout=30)
        
        # Add predecessor information to each task
        for task in tasks:
            task_name = task.get('name', '')
            # Get task details including predecessors
            desc_query = f"DESC TASK {settings.GOLD_SCHEMA_NAME}.{task_name}"
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
        logger.error(f"Failed to get Gold tasks: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/tasks/{task_name}/resume")
async def resume_gold_task(request: Request, task_name: str):
    """Resume a Gold task"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        query = f"ALTER TASK {settings.GOLD_SCHEMA_NAME}.{task_name} RESUME"
        await sf_service.execute_query(query)
        return {"message": f"Task {task_name} resumed successfully"}
    except Exception as e:
        logger.error(f"Failed to resume Gold task: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/tasks/{task_name}/suspend")
async def suspend_gold_task(request: Request, task_name: str):
    """Suspend a Gold task"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        query = f"ALTER TASK {settings.GOLD_SCHEMA_NAME}.{task_name} SUSPEND"
        await sf_service.execute_query(query, timeout=30)
        return {"message": f"Task {task_name} suspended successfully"}
    except Exception as e:
        logger.error(f"Failed to suspend Gold task: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

class GoldScheduleUpdate(BaseModel):
    schedule: str

@router.put("/tasks/{task_name}/schedule")
async def update_gold_task_schedule(request: Request, task_name: str, schedule_update: GoldScheduleUpdate):
    """Update Gold task schedule (only for root tasks without predecessors)"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        schedule = schedule_update.schedule
        
        # Check if task has predecessors
        desc_query = f"DESC TASK {settings.GOLD_SCHEMA_NAME}.{task_name}"
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
        suspend_query = f"ALTER TASK {settings.GOLD_SCHEMA_NAME}.{task_name} SUSPEND"
        await sf_service.execute_query(suspend_query, timeout=30)
        
        # Update schedule
        update_query = f"ALTER TASK {settings.GOLD_SCHEMA_NAME}.{task_name} SET SCHEDULE = '{schedule}'"
        await sf_service.execute_query(update_query, timeout=30)
        
        # Resume task
        resume_query = f"ALTER TASK {settings.GOLD_SCHEMA_NAME}.{task_name} RESUME"
        await sf_service.execute_query(resume_query, timeout=30)
        
        return {"message": f"Task {task_name} schedule updated successfully to: {schedule}"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update Gold task schedule: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
