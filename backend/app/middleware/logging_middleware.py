"""
Middleware for automatic API request/response logging
"""

import time
import json
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp
from app.utils.logging_utils import SnowflakeLogger
import logging

logger = logging.getLogger(__name__)


class LoggingMiddleware(BaseHTTPMiddleware):
    """Middleware to log all API requests and responses to Snowflake"""
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
    
    async def dispatch(self, request: Request, call_next):
        # Start timing
        start_time = time.time()
        
        # Extract request details
        method = request.method
        path = request.url.path
        client_ip = request.client.host if request.client else None
        user_agent = request.headers.get('user-agent', '')
        
        # Extract query parameters
        params = dict(request.query_params) if request.query_params else None
        
        # Try to extract request body (for POST/PUT requests)
        body = None
        if method in ['POST', 'PUT', 'PATCH']:
            try:
                # Store body for later use
                body_bytes = await request.body()
                # Try to parse as JSON
                if body_bytes:
                    try:
                        body = json.loads(body_bytes.decode('utf-8'))
                    except:
                        body = {'raw': body_bytes.decode('utf-8', errors='ignore')[:500]}
                
                # Create a new request with the body
                async def receive():
                    return {'type': 'http.request', 'body': body_bytes}
                
                request._receive = receive
            except Exception as e:
                logger.debug(f"Could not read request body: {e}")
        
        # Process request
        response = None
        error_message = None
        response_status = None
        
        try:
            response = await call_next(request)
            response_status = response.status_code
        except Exception as e:
            error_message = str(e)
            response_status = 500
            raise
        finally:
            # Calculate response time
            response_time_ms = int((time.time() - start_time) * 1000)
            
            # Extract TPA from path or params
            tpa_code = None
            if params and 'tpa' in params:
                tpa_code = params['tpa']
            elif body and isinstance(body, dict) and 'tpa' in body:
                tpa_code = body['tpa']
            
            # Log to Snowflake (async, don't block response)
            try:
                SnowflakeLogger.log_api_request(
                    method=method,
                    path=path,
                    params=params,
                    body=body,
                    response_status=response_status,
                    response_time_ms=response_time_ms,
                    error_message=error_message,
                    client_ip=client_ip,
                    user_agent=user_agent,
                    tpa_code=tpa_code
                )
            except Exception as log_error:
                # Don't fail the request if logging fails
                logger.error(f"Failed to log request: {log_error}")
        
        return response
