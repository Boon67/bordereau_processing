"""
Snowflake Logging Handler
Writes application logs to Snowflake logging tables
"""

import logging
import json
from datetime import datetime
from typing import Optional, Dict, Any
import asyncio
from queue import Queue
import threading

from app.services.snowflake_service import SnowflakeService
from app.config import settings


class SnowflakeLogHandler(logging.Handler):
    """
    Custom logging handler that writes logs to Snowflake APPLICATION_LOGS table
    Uses a background thread to avoid blocking the main application
    """
    
    def __init__(self, batch_size: int = 10, flush_interval: int = 5):
        super().__init__()
        self.batch_size = batch_size
        self.flush_interval = flush_interval
        self.log_queue = Queue()
        self.running = True
        
        # Start background thread for batch processing
        self.worker_thread = threading.Thread(target=self._process_logs, daemon=True)
        self.worker_thread.start()
    
    def emit(self, record: logging.LogRecord):
        """Called when a log record is emitted"""
        try:
            # Extract log details
            log_entry = {
                'level': record.levelname,
                'source': record.name,
                'message': record.getMessage(),
                'details': {
                    'filename': record.filename,
                    'line_number': record.lineno,
                    'function': record.funcName,
                    'thread': record.thread,
                    'thread_name': record.threadName,
                }
            }
            
            # Add exception info if present
            if record.exc_info:
                log_entry['details']['exception'] = self.format(record)
            
            # Add to queue for batch processing
            self.log_queue.put(log_entry)
            
        except Exception as e:
            # Don't let logging errors crash the application
            print(f"Error in SnowflakeLogHandler: {e}")
    
    def _process_logs(self):
        """Background thread that processes logs in batches"""
        batch = []
        
        while self.running:
            try:
                # Collect logs for batch
                while len(batch) < self.batch_size:
                    try:
                        log_entry = self.log_queue.get(timeout=self.flush_interval)
                        batch.append(log_entry)
                    except:
                        break
                
                # Write batch to Snowflake if we have logs
                if batch:
                    self._write_batch(batch)
                    batch = []
                    
            except Exception as e:
                print(f"Error processing log batch: {e}")
                batch = []
    
    def _write_batch(self, batch: list):
        """Write a batch of logs to Snowflake"""
        try:
            sf_service = SnowflakeService()
            
            # Build multi-row INSERT ... SELECT statement
            # (Snowflake does not allow PARSE_JSON inside a VALUES clause)
            selects = []
            for log in batch:
                # Escape strings for SQL
                level = log['level'].replace("'", "''")
                source = log['source'].replace("'", "''")
                message = log['message'].replace("'", "''")[:4000]  # Truncate long messages
                
                # Convert details to JSON string
                details_json_str = json.dumps(log['details'])
                
                selects.append(
                    f"SELECT '{level}', '{source}', '{message}', TO_VARIANT(PARSE_JSON($${details_json_str}$$)), CURRENT_USER(), NULL"
                )
            
            selects_str = '\nUNION ALL\n'.join(selects)
            
            query = f"""
                INSERT INTO {settings.BRONZE_SCHEMA_NAME}.APPLICATION_LOGS 
                (LOG_LEVEL, LOG_SOURCE, LOG_MESSAGE, LOG_DETAILS, USER_NAME, TPA_CODE)
                {selects_str}
            """
            
            # Execute synchronously in background thread
            sf_service._execute_query_sync(query)
            
        except Exception as e:
            print(f"Error writing logs to Snowflake: {e}")
    
    def close(self):
        """Clean shutdown of the handler"""
        self.running = False
        if self.worker_thread.is_alive():
            self.worker_thread.join(timeout=10)
        super().close()


async def log_api_request(
    method: str,
    path: str,
    params: Optional[Dict[str, Any]],
    body: Optional[Dict[str, Any]],
    status: int,
    response_time_ms: int,
    error_message: Optional[str],
    user_name: Optional[str],
    client_ip: Optional[str],
    user_agent: Optional[str],
    tpa_code: Optional[str]
):
    """Log an API request to Snowflake"""
    try:
        sf_service = SnowflakeService()
        
        # Properly escape and format values
        def escape_str(s: Optional[str]) -> str:
            """Escape string for SQL, return NULL if None"""
            if s is None:
                return 'NULL'
            return f"'{s.replace(chr(92), chr(92)+chr(92)).replace(chr(39), chr(39)+chr(39))}'"
        
        def escape_json(obj: Optional[Dict]) -> str:
            """Convert dict to JSON and escape for SQL, return NULL if None"""
            if obj is None or not obj:
                return 'NULL'
            json_str = json.dumps(obj)
            # Use $$ delimiter to avoid escaping issues
            return f"TO_VARIANT(PARSE_JSON($${json_str}$$))"
        
        # Build the query using SELECT instead of VALUES
        # (Snowflake does not allow PARSE_JSON inside a VALUES clause)
        query = f"""
            INSERT INTO {settings.BRONZE_SCHEMA_NAME}.API_REQUEST_LOGS (
                REQUEST_METHOD,
                REQUEST_PATH,
                REQUEST_PARAMS,
                REQUEST_BODY,
                RESPONSE_STATUS,
                RESPONSE_TIME_MS,
                ERROR_MESSAGE,
                USER_NAME,
                CLIENT_IP,
                USER_AGENT,
                TPA_CODE
            ) SELECT
                {escape_str(method)},
                {escape_str(path)},
                {escape_json(params)},
                {escape_json(body)},
                {status},
                {response_time_ms},
                {escape_str(error_message[:4000] if error_message else None)},
                {escape_str(user_name)},
                {escape_str(client_ip)},
                {escape_str(user_agent[:500] if user_agent else None)},
                {escape_str(tpa_code)}
        """
        
        await sf_service.execute_query(query)
        
    except Exception as e:
        # Don't let logging errors crash the application
        logging.error(f"Error logging API request: {e}")


async def log_error(
    source: str,
    error_type: str,
    error_message: str,
    stack_trace: Optional[str],
    context: Optional[Dict[str, Any]],
    user_name: Optional[str],
    tpa_code: Optional[str]
):
    """Log an error to Snowflake ERROR_LOGS table"""
    try:
        sf_service = SnowflakeService()
        
        # Escape strings
        source = source.replace("'", "''")
        error_type = error_type.replace("'", "''")
        error_message = error_message.replace("'", "''")[:4000]
        stack = stack_trace.replace("'", "''")[:8000] if stack_trace else 'NULL'
        context_json_str = json.dumps(context or {}) if context else None
        user = user_name.replace("'", "''") if user_name else 'NULL'
        tpa = tpa_code.replace("'", "''") if tpa_code else 'NULL'
        
        # Build context value using $$ delimiter
        context_val = f"TO_VARIANT(PARSE_JSON($${context_json_str}$$))" if context_json_str else 'NULL'
        
        # Use SELECT instead of VALUES
        # (Snowflake does not allow PARSE_JSON inside a VALUES clause)
        query = f"""
            INSERT INTO {settings.BRONZE_SCHEMA_NAME}.ERROR_LOGS (
                ERROR_LEVEL,
                ERROR_SOURCE,
                ERROR_TYPE,
                ERROR_MESSAGE,
                ERROR_STACK_TRACE,
                ERROR_CONTEXT,
                USER_NAME,
                TPA_CODE
            ) SELECT
                'ERROR',
                '{source}',
                '{error_type}',
                '{error_message}',
                {f"'{stack}'" if stack_trace else 'NULL'},
                {context_val},
                {f"'{user}'" if user_name else 'NULL'},
                {f"'{tpa}'" if tpa_code else 'NULL'}
        """
        
        await sf_service.execute_query(query)
        
    except Exception as e:
        # Don't let logging errors crash the application
        logging.error(f"Error logging error to Snowflake: {e}")
