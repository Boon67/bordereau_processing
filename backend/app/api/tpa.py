"""
TPA Management API Endpoints
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import logging

from app.services.snowflake_service import SnowflakeService

logger = logging.getLogger(__name__)
router = APIRouter()

class TPACreate(BaseModel):
    tpa_code: str
    tpa_name: str
    tpa_description: str = ""

@router.get("")
async def get_tpas():
    """Get all active TPAs"""
    try:
        sf_service = SnowflakeService()
        return sf_service.get_tpas()
    except Exception as e:
        logger.error(f"Failed to get TPAs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("")
async def create_tpa(tpa: TPACreate):
    """Create new TPA"""
    try:
        sf_service = SnowflakeService()
        result = sf_service.execute_procedure(
            "add_tpa",
            tpa.tpa_code,
            tpa.tpa_name,
            tpa.tpa_description
        )
        return {"message": "TPA created successfully", "result": result}
    except Exception as e:
        logger.error(f"Failed to create TPA: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
