"""
Logging API Endpoints
"""

from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
from datetime import datetime, timedelta
import logging

from app.services.snowflake_service import SnowflakeService
from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/application")
async def get_application_logs(
    limit: int = Query(100, le=1000),
    level: Optional[str] = None,
    source: Optional[str] = None,
    days: int = Query(7, le=30)
):
    """Get application logs"""
    try:
        sf_service = SnowflakeService()
        
        where_clauses = [
            f"LOG_TIMESTAMP >= DATEADD(DAY, -{days}, CURRENT_TIMESTAMP())"
        ]
        
        if level:
            where_clauses.append(f"LOG_LEVEL = '{level}'")
        
        if source:
            where_clauses.append(f"LOG_SOURCE = '{source}'")
        
        where_clause = " AND ".join(where_clauses)
        
        query = f"""
            SELECT 
                LOG_ID,
                LOG_TIMESTAMP,
                LOG_LEVEL,
                LOG_SOURCE,
                LOG_MESSAGE,
                LOG_DETAILS,
                USER_NAME,
                TPA_CODE
            FROM {settings.BRONZE_SCHEMA_NAME}.APPLICATION_LOGS
            WHERE {where_clause}
            ORDER BY LOG_TIMESTAMP DESC
            LIMIT {limit}
        """
        
        result = await sf_service.execute_query(query)
        return result
        
    except Exception as e:
        logger.error(f"Error fetching application logs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/tasks")
async def get_task_execution_logs(
    limit: int = Query(100, le=1000),
    task_name: Optional[str] = None,
    status: Optional[str] = None,
    days: int = Query(7, le=30)
):
    """Get task execution logs"""
    try:
        sf_service = SnowflakeService()
        
        where_clauses = [
            f"EXECUTION_START >= DATEADD(DAY, -{days}, CURRENT_TIMESTAMP())"
        ]
        
        if task_name:
            where_clauses.append(f"TASK_NAME = '{task_name}'")
        
        if status:
            where_clauses.append(f"EXECUTION_STATUS = '{status}'")
        
        where_clause = " AND ".join(where_clauses)
        
        query = f"""
            SELECT 
                EXECUTION_ID,
                TASK_NAME,
                EXECUTION_START,
                EXECUTION_END,
                EXECUTION_STATUS,
                EXECUTION_DURATION_MS,
                RECORDS_PROCESSED,
                RECORDS_FAILED,
                ERROR_MESSAGE,
                EXECUTION_DETAILS,
                WAREHOUSE_USED
            FROM {settings.BRONZE_SCHEMA_NAME}.TASK_EXECUTION_LOGS
            WHERE {where_clause}
            ORDER BY EXECUTION_START DESC
            LIMIT {limit}
        """
        
        result = await sf_service.execute_query(query)
        return result
        
    except Exception as e:
        logger.error(f"Error fetching task execution logs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/file-processing")
async def get_file_processing_logs(
    limit: int = Query(100, le=1000),
    file_name: Optional[str] = None,
    stage: Optional[str] = None,
    tpa: Optional[str] = None,
    days: int = Query(7, le=30)
):
    """Get file processing logs"""
    try:
        sf_service = SnowflakeService()
        
        where_clauses = [
            f"STAGE_START >= DATEADD(DAY, -{days}, CURRENT_TIMESTAMP())"
        ]
        
        if file_name:
            where_clauses.append(f"FILE_NAME LIKE '%{file_name}%'")
        
        if stage:
            where_clauses.append(f"PROCESSING_STAGE = '{stage}'")
        
        if tpa:
            where_clauses.append(f"TPA_CODE = '{tpa}'")
        
        where_clause = " AND ".join(where_clauses)
        
        query = f"""
            SELECT 
                PROCESSING_LOG_ID,
                QUEUE_ID,
                FILE_NAME,
                TPA_CODE,
                PROCESSING_STAGE,
                STAGE_STATUS,
                STAGE_START,
                STAGE_END,
                STAGE_DURATION_MS,
                ROWS_PROCESSED,
                ROWS_FAILED,
                ERROR_MESSAGE,
                STAGE_DETAILS
            FROM {settings.BRONZE_SCHEMA_NAME}.FILE_PROCESSING_LOGS
            WHERE {where_clause}
            ORDER BY STAGE_START DESC
            LIMIT {limit}
        """
        
        result = await sf_service.execute_query(query)
        return result
        
    except Exception as e:
        logger.error(f"Error fetching file processing logs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/errors")
async def get_error_logs(
    limit: int = Query(100, le=1000),
    source: Optional[str] = None,
    resolution_status: Optional[str] = None,
    days: int = Query(7, le=30)
):
    """Get error logs"""
    try:
        sf_service = SnowflakeService()
        
        where_clauses = [
            f"ERROR_TIMESTAMP >= DATEADD(DAY, -{days}, CURRENT_TIMESTAMP())"
        ]
        
        if source:
            where_clauses.append(f"ERROR_SOURCE = '{source}'")
        
        if resolution_status:
            where_clauses.append(f"RESOLUTION_STATUS = '{resolution_status}'")
        
        where_clause = " AND ".join(where_clauses)
        
        query = f"""
            SELECT 
                ERROR_ID,
                ERROR_TIMESTAMP,
                ERROR_LEVEL,
                ERROR_SOURCE,
                ERROR_TYPE,
                ERROR_MESSAGE,
                ERROR_STACK_TRACE,
                ERROR_CONTEXT,
                USER_NAME,
                TPA_CODE,
                RESOLUTION_STATUS,
                RESOLUTION_NOTES,
                RESOLVED_BY,
                RESOLVED_AT
            FROM {settings.BRONZE_SCHEMA_NAME}.ERROR_LOGS
            WHERE {where_clause}
            ORDER BY ERROR_TIMESTAMP DESC
            LIMIT {limit}
        """
        
        result = await sf_service.execute_query(query)
        return result
        
    except Exception as e:
        logger.error(f"Error fetching error logs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/api-requests")
async def get_api_request_logs(
    limit: int = Query(100, le=1000),
    method: Optional[str] = None,
    path: Optional[str] = None,
    min_response_time: Optional[int] = None,
    days: int = Query(7, le=30)
):
    """Get API request logs"""
    try:
        sf_service = SnowflakeService()
        
        where_clauses = [
            f"REQUEST_TIMESTAMP >= DATEADD(DAY, -{days}, CURRENT_TIMESTAMP())"
        ]
        
        if method:
            where_clauses.append(f"REQUEST_METHOD = '{method}'")
        
        if path:
            where_clauses.append(f"REQUEST_PATH LIKE '%{path}%'")
        
        if min_response_time:
            where_clauses.append(f"RESPONSE_TIME_MS >= {min_response_time}")
        
        where_clause = " AND ".join(where_clauses)
        
        query = f"""
            SELECT 
                REQUEST_ID,
                REQUEST_TIMESTAMP,
                REQUEST_METHOD,
                REQUEST_PATH,
                REQUEST_PARAMS,
                RESPONSE_STATUS,
                RESPONSE_TIME_MS,
                ERROR_MESSAGE,
                USER_NAME,
                CLIENT_IP,
                USER_AGENT,
                TPA_CODE
            FROM {settings.BRONZE_SCHEMA_NAME}.API_REQUEST_LOGS
            WHERE {where_clause}
            ORDER BY REQUEST_TIMESTAMP DESC
            LIMIT {limit}
        """
        
        result = await sf_service.execute_query(query)
        return result
        
    except Exception as e:
        logger.error(f"Error fetching API request logs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stats")
async def get_log_statistics(days: int = Query(7, le=30)):
    """Get logging statistics"""
    try:
        sf_service = SnowflakeService()
        
        query = f"""
            SELECT 
                'application_logs' as log_type,
                COUNT(*) as total_count,
                SUM(CASE WHEN LOG_LEVEL = 'ERROR' THEN 1 ELSE 0 END) as error_count,
                SUM(CASE WHEN LOG_LEVEL = 'WARNING' THEN 1 ELSE 0 END) as warning_count
            FROM {settings.BRONZE_SCHEMA_NAME}.APPLICATION_LOGS
            WHERE LOG_TIMESTAMP >= DATEADD(DAY, -{days}, CURRENT_TIMESTAMP())
            
            UNION ALL
            
            SELECT 
                'task_executions' as log_type,
                COUNT(*) as total_count,
                SUM(CASE WHEN EXECUTION_STATUS = 'FAILED' THEN 1 ELSE 0 END) as error_count,
                0 as warning_count
            FROM {settings.BRONZE_SCHEMA_NAME}.TASK_EXECUTION_LOGS
            WHERE EXECUTION_START >= DATEADD(DAY, -{days}, CURRENT_TIMESTAMP())
            
            UNION ALL
            
            SELECT 
                'errors' as log_type,
                COUNT(*) as total_count,
                SUM(CASE WHEN RESOLUTION_STATUS = 'UNRESOLVED' THEN 1 ELSE 0 END) as error_count,
                0 as warning_count
            FROM {settings.BRONZE_SCHEMA_NAME}.ERROR_LOGS
            WHERE ERROR_TIMESTAMP >= DATEADD(DAY, -{days}, CURRENT_TIMESTAMP())
        """
        
        result = await sf_service.execute_query(query)
        return result
        
    except Exception as e:
        logger.error(f"Error fetching log statistics: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
