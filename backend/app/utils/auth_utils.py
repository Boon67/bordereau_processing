"""
Authentication utilities for extracting and using caller's credentials
"""

from fastapi import Request
from typing import Optional
import logging
from app.config import settings

logger = logging.getLogger(__name__)


def get_caller_token(request: Request) -> Optional[str]:
    """
    Extract the caller's Snowflake token from the request.
    
    The token is set by SnowflakeAuthMiddleware in request.state.snowflake_token
    
    Args:
        request: FastAPI Request object
        
    Returns:
        Snowflake OAuth token if available (and if USE_CALLERS_RIGHTS is enabled), None otherwise
    """
    # Check if caller's rights mode is enabled
    if not settings.USE_CALLERS_RIGHTS:
        logger.debug("Caller's rights mode is disabled, using service token")
        return None
    
    try:
        token = getattr(request.state, 'snowflake_token', None)
        if token:
            logger.debug("Using caller's Snowflake token")
        else:
            logger.debug("No caller token found, will use service token")
        return token
    except Exception as e:
        logger.debug(f"Could not extract caller token: {e}")
        return None


def get_caller_user(request: Request) -> Optional[str]:
    """
    Extract the caller's username from the request.
    
    The username is set by SnowflakeAuthMiddleware in request.state.snowflake_user
    
    Args:
        request: FastAPI Request object
        
    Returns:
        Username if available, None otherwise
    """
    try:
        return getattr(request.state, 'snowflake_user', None)
    except Exception as e:
        logger.debug(f"Could not extract caller user: {e}")
        return None
