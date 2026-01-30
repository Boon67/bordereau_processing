"""
User Information API Endpoints
"""

from fastapi import APIRouter, Request, HTTPException
import logging

from app.services.snowflake_service import SnowflakeService
from app.utils.auth_utils import get_caller_token

logger = logging.getLogger(__name__)
router = APIRouter()

@router.get("/current")
async def get_current_user(request: Request):
    """Get current user information from Snowflake session"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Get current user and role information
        query = """
            SELECT 
                CURRENT_USER() as username,
                CURRENT_ROLE() as role,
                CURRENT_WAREHOUSE() as warehouse,
                CURRENT_DATABASE() as database,
                CURRENT_SCHEMA() as schema,
                CURRENT_ACCOUNT() as account,
                CURRENT_REGION() as region
        """
        
        result = await sf_service.execute_query_dict(query)
        
        if result and len(result) > 0:
            user_info = result[0]
            return {
                "username": user_info.get("USERNAME"),
                "role": user_info.get("ROLE"),
                "warehouse": user_info.get("WAREHOUSE"),
                "database": user_info.get("DATABASE"),
                "schema": user_info.get("SCHEMA"),
                "account": user_info.get("ACCOUNT"),
                "region": user_info.get("REGION"),
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to retrieve user information")
            
    except Exception as e:
        logger.error(f"Failed to get current user: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
