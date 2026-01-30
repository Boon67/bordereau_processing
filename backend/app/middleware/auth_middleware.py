"""
Middleware for extracting and validating Snowflake ingress authentication tokens
"""

import base64
import json
import logging
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp
from typing import Optional

logger = logging.getLogger(__name__)


class SnowflakeAuthMiddleware(BaseHTTPMiddleware):
    """
    Middleware to extract Snowflake ingress authentication token from cookies.
    
    When running in Snowpark Container Services with ingress authentication enabled,
    Snowflake sets a cookie named 'sfc-ss-ingress-auth-v1-<service_id>' containing
    the authenticated user's session token.
    
    This middleware extracts that token and makes it available to request handlers
    via request.state.snowflake_token
    """
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
    
    async def dispatch(self, request: Request, call_next):
        # Log all headers for debugging
        logger.info(f"Request headers: {dict(request.headers)}")
        
        # Extract Snowflake ingress auth token from cookies
        token = self._extract_ingress_token(request)
        
        if token:
            # Store token in request state for use by request handlers
            request.state.snowflake_token = token
            request.state.snowflake_user = self._extract_user_from_token(token)
            logger.info(f"Extracted Snowflake token for user: {request.state.snowflake_user}")
        else:
            request.state.snowflake_token = None
            request.state.snowflake_user = None
            logger.info("No Snowflake ingress token found in request")
        
        response = await call_next(request)
        return response
    
    def _extract_ingress_token(self, request: Request) -> Optional[str]:
        """
        Extract Snowflake ingress authentication token from cookies or headers.
        
        Snowflake SPCS ingress can provide auth in multiple ways:
        1. Cookie: sfc-ss-ingress-auth-v1-<service_id>
        2. Header: Authorization (Bearer token)
        3. Header: X-Snowflake-Authorization-Token-Type
        """
        try:
            # First, try to get from cookies
            cookies = request.cookies
            logger.info(f"Total cookies received: {len(cookies)}")
            
            # Look for ingress auth cookie (pattern: sfc-ss-ingress-auth-v1-*)
            for cookie_name, cookie_value in cookies.items():
                if cookie_name.startswith('sfc-ss-ingress-auth-v1-'):
                    logger.info(f"Found ingress auth cookie: {cookie_name}")
                    return cookie_value
            
            # If no cookie, try headers
            auth_header = request.headers.get('authorization')
            if auth_header:
                logger.info(f"Found Authorization header")
                # Extract Bearer token if present
                if auth_header.lower().startswith('bearer '):
                    return auth_header[7:]  # Remove 'Bearer ' prefix
                return auth_header
            
            # Check for Snowflake-specific headers
            sf_token = request.headers.get('x-snowflake-authorization-token-type')
            if sf_token:
                logger.info(f"Found X-Snowflake-Authorization-Token-Type header")
                return sf_token
            
            logger.info("No ingress auth found in cookies or headers")
            return None
            
        except Exception as e:
            logger.error(f"Error extracting ingress token: {e}")
            return None
    
    def _extract_user_from_token(self, token: str) -> Optional[str]:
        """
        Extract username from JWT token (if possible).
        
        JWT tokens have three parts separated by dots: header.payload.signature
        The payload contains user information.
        """
        try:
            # JWT tokens are in format: header.payload.signature
            parts = token.split('.')
            
            if len(parts) != 3:
                return None
            
            # Decode the payload (second part)
            # Add padding if needed (JWT base64 encoding doesn't use padding)
            payload = parts[1]
            padding = 4 - (len(payload) % 4)
            if padding != 4:
                payload += '=' * padding
            
            decoded_payload = base64.b64decode(payload)
            payload_data = json.loads(decoded_payload)
            
            # Extract username (field name may vary)
            username = (
                payload_data.get('sub') or 
                payload_data.get('user') or 
                payload_data.get('username') or
                payload_data.get('preferred_username')
            )
            
            return username
            
        except Exception as e:
            logger.debug(f"Could not extract user from token: {e}")
            return None
