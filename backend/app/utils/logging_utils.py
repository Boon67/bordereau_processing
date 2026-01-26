"""
Logging utilities for application-wide logging to Snowflake
"""

import json
import traceback
from datetime import datetime
from typing import Optional, Dict, Any
from app.services.snowflake_service import SnowflakeService
from app.config import settings
import logging

logger = logging.getLogger(__name__)


class SnowflakeLogger:
    """Logger that writes to Snowflake hybrid tables"""
    
    @staticmethod
    def log_application_event(
        level: str,
        source: str,
        message: str,
        details: Optional[Dict[str, Any]] = None,
        user_name: Optional[str] = None,
        tpa_code: Optional[str] = None
    ):
        """Log an application event to APPLICATION_LOGS table"""
        try:
            sf_service = SnowflakeService()
            
            # Prepare details as JSON string
            details_json = json.dumps(details) if details else 'null'
            user_str = f"'{user_name}'" if user_name else 'null'
            tpa_str = f"'{tpa_code}'" if tpa_code else 'null'
            
            # Escape single quotes in message
            message_escaped = message.replace("'", "''")
            
            query = f"""
                INSERT INTO {settings.BRONZE_SCHEMA_NAME}.APPLICATION_LOGS (
                    LOG_LEVEL, LOG_SOURCE, LOG_MESSAGE, LOG_DETAILS, USER_NAME, TPA_CODE
                ) VALUES (
                    '{level}', '{source}', '{message_escaped}', 
                    PARSE_JSON('{details_json}'), {user_str}, {tpa_str}
                )
            """
            
            sf_service.execute_query(query)
            
        except Exception as e:
            # Don't fail the main operation if logging fails
            logger.error(f"Failed to log to Snowflake: {str(e)}")
    
    @staticmethod
    def log_api_request(
        method: str,
        path: str,
        params: Optional[Dict] = None,
        body: Optional[Dict] = None,
        response_status: Optional[int] = None,
        response_time_ms: Optional[int] = None,
        response_body: Optional[Dict] = None,
        error_message: Optional[str] = None,
        user_name: Optional[str] = None,
        client_ip: Optional[str] = None,
        user_agent: Optional[str] = None,
        tpa_code: Optional[str] = None
    ):
        """Log an API request to API_REQUEST_LOGS table"""
        try:
            sf_service = SnowflakeService()
            
            # Prepare JSON fields (properly escape for SQL)
            if params:
                params_json = json.dumps(params).replace("'", "''")
            else:
                params_json = None
            
            if body:
                body_json = json.dumps(body).replace("'", "''")
            else:
                body_json = None
            
            if response_body:
                response_json = json.dumps(response_body).replace("'", "''")
            else:
                response_json = None
            
            # Prepare optional string fields (escape quotes for SQL)
            if error_message:
                escaped_error = error_message.replace('"', '""')
                error_str = f"'{escaped_error}'"
            else:
                error_str = 'null'
            
            user_str = f"'{user_name}'" if user_name else 'null'
            ip_str = f"'{client_ip}'" if client_ip else 'null'
            agent_str = f"'{user_agent[:500]}'" if user_agent else 'null'
            tpa_str = f"'{tpa_code}'" if tpa_code else 'null'
            status_str = str(response_status) if response_status else 'null'
            time_str = str(response_time_ms) if response_time_ms else 'null'
            
            # Build VALUES clause with proper NULL handling
            params_val = f"PARSE_JSON('{params_json}')" if params_json else 'NULL'
            body_val = f"PARSE_JSON('{body_json}')" if body_json else 'NULL'
            response_val = f"PARSE_JSON('{response_json}')" if response_json else 'NULL'
            
            query = f"""
                INSERT INTO {settings.BRONZE_SCHEMA_NAME}.API_REQUEST_LOGS (
                    REQUEST_METHOD, REQUEST_PATH, REQUEST_PARAMS, REQUEST_BODY,
                    RESPONSE_STATUS, RESPONSE_TIME_MS, RESPONSE_BODY, ERROR_MESSAGE,
                    USER_NAME, CLIENT_IP, USER_AGENT, TPA_CODE
                ) VALUES (
                    '{method}', '{path}', {params_val}, {body_val},
                    {status_str}, {time_str}, {response_val}, {error_str},
                    {user_str}, {ip_str}, {agent_str}, {tpa_str}
                )
            """
            
            sf_service.execute_query(query)
            
        except Exception as e:
            logger.error(f"Failed to log API request to Snowflake: {str(e)}")
    
    @staticmethod
    def log_error(
        source: str,
        error_type: str,
        error_message: str,
        stack_trace: Optional[str] = None,
        context: Optional[Dict[str, Any]] = None,
        user_name: Optional[str] = None,
        tpa_code: Optional[str] = None
    ):
        """Log an error to ERROR_LOGS table"""
        try:
            sf_service = SnowflakeService()
            
            # Prepare fields
            context_json = json.dumps(context) if context else 'null'
            stack_escaped = stack_trace.replace("'", "''")[:5000] if stack_trace else ''
            message_escaped = error_message.replace("'", "''")[:1000]
            user_str = f"'{user_name}'" if user_name else 'null'
            tpa_str = f"'{tpa_code}'" if tpa_code else 'null'
            stack_str = f"'{stack_escaped}'" if stack_trace else 'null'
            
            query = f"""
                INSERT INTO {settings.BRONZE_SCHEMA_NAME}.ERROR_LOGS (
                    ERROR_LEVEL, ERROR_SOURCE, ERROR_TYPE, ERROR_MESSAGE,
                    ERROR_STACK_TRACE, ERROR_CONTEXT, USER_NAME, TPA_CODE
                ) VALUES (
                    'ERROR', '{source}', '{error_type}', '{message_escaped}',
                    {stack_str}, PARSE_JSON('{context_json}'), {user_str}, {tpa_str}
                )
            """
            
            sf_service.execute_query(query)
            
        except Exception as e:
            logger.error(f"Failed to log error to Snowflake: {str(e)}")


def log_info(source: str, message: str, **kwargs):
    """Convenience function for INFO level logging"""
    SnowflakeLogger.log_application_event('INFO', source, message, kwargs.get('details'), kwargs.get('user_name'), kwargs.get('tpa_code'))


def log_warning(source: str, message: str, **kwargs):
    """Convenience function for WARNING level logging"""
    SnowflakeLogger.log_application_event('WARNING', source, message, kwargs.get('details'), kwargs.get('user_name'), kwargs.get('tpa_code'))


def log_error(source: str, message: str, **kwargs):
    """Convenience function for ERROR level logging"""
    SnowflakeLogger.log_application_event('ERROR', source, message, kwargs.get('details'), kwargs.get('user_name'), kwargs.get('tpa_code'))


def log_exception(source: str, exception: Exception, **kwargs):
    """Log an exception with full stack trace"""
    stack_trace = traceback.format_exc()
    context = kwargs.get('context', {})
    context['exception_args'] = str(exception.args)
    
    SnowflakeLogger.log_error(
        source=source,
        error_type=type(exception).__name__,
        error_message=str(exception),
        stack_trace=stack_trace,
        context=context,
        user_name=kwargs.get('user_name'),
        tpa_code=kwargs.get('tpa_code')
    )
