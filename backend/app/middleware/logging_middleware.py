"""
API Request Logging Middleware
Captures all API requests and logs them to Snowflake
"""

import time
import json
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp
import logging

from app.utils.snowflake_logger import log_api_request
from app.utils.auth_utils import get_caller_user

logger = logging.getLogger(__name__)


class APILoggingMiddleware(BaseHTTPMiddleware):
    """
    Middleware to log all API requests to Snowflake
    """
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
    
    async def dispatch(self, request: Request, call_next):
        # Skip logging for health checks and static files
        if request.url.path in ["/api/health", "/health", "/", "/favicon.ico"]:
            return await call_next(request)
        
        # Skip logging for non-API paths
        if not request.url.path.startswith("/api/"):
            return await call_next(request)
        
        # Record start time
        start_time = time.time()
        
        # Extract request details
        method = request.method
        path = request.url.path
        query_params = dict(request.query_params) if request.query_params else None
        client_ip = request.client.host if request.client else None
        user_agent = request.headers.get("user-agent")
        
        # Try to get username
        user_name = None
        try:
            user_name = get_caller_user(request)
        except:
            pass
        
        # Try to get TPA from query params or state
        tpa_code = query_params.get("tpa") if query_params else None
        if not tpa_code and hasattr(request.state, "tpa"):
            tpa_code = request.state.tpa
        
        # Get request body for POST/PUT/PATCH
        request_body = None
        if method in ["POST", "PUT", "PATCH"]:
            try:
                # Store body for later use
                body_bytes = await request.body()
                if body_bytes:
                    request_body = json.loads(body_bytes.decode())
                # Re-create receive that properly handles body + disconnect sequence
                # BaseHTTPMiddleware expects: first call returns body, subsequent calls return disconnect
                body_sent = False
                async def receive():
                    nonlocal body_sent
                    if not body_sent:
                        body_sent = True
                        return {"type": "http.request", "body": body_bytes, "more_body": False}
                    # After body is sent, wait indefinitely (middleware will handle disconnect)
                    import asyncio
                    await asyncio.sleep(3600)
                    return {"type": "http.disconnect"}
                request._receive = receive
            except:
                pass
        
        # Process request
        response = None
        error_message = None
        status_code = 500
        
        try:
            response = await call_next(request)
            status_code = response.status_code
        except Exception as e:
            error_message = str(e)
            logger.error(f"Request failed: {method} {path} - {error_message}")
            raise
        finally:
            # Calculate response time
            response_time_ms = int((time.time() - start_time) * 1000)
            
            # Log to Snowflake asynchronously (don't wait for it)
            try:
                # Debug log what we're about to send
                logger.info(f"Logging API request: {method} {path} - Status: {status_code}, Time: {response_time_ms}ms, IP: {client_ip}")
                
                # Use asyncio.create_task to run in background
                import asyncio
                asyncio.create_task(log_api_request(
                    method=method,
                    path=path,
                    params=query_params,
                    body=request_body,
                    status=status_code,
                    response_time_ms=response_time_ms,
                    error_message=error_message,
                    user_name=user_name,
                    client_ip=client_ip,
                    user_agent=user_agent,
                    tpa_code=tpa_code
                ))
            except Exception as log_error:
                # Don't let logging errors affect the response
                logger.error(f"Failed to log API request: {log_error}")
        
        return response
