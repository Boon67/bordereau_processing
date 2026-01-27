"""
TPA Management API Endpoints
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import logging

from app.services.snowflake_service import SnowflakeService

logger = logging.getLogger(__name__)
router = APIRouter()

class TPACreate(BaseModel):
    tpa_code: str
    tpa_name: str
    tpa_description: str = ""
    active: bool = True

class TPAUpdate(BaseModel):
    tpa_name: Optional[str] = None
    tpa_description: Optional[str] = None
    active: Optional[bool] = None

class TPAStatusUpdate(BaseModel):
    active: bool

@router.get("")
async def get_tpas():
    """Get all TPAs (active and inactive)"""
    try:
        sf_service = SnowflakeService()
        # Get all TPAs, not just active ones
        query = """
            SELECT 
                TPA_CODE,
                TPA_NAME,
                TPA_DESCRIPTION,
                ACTIVE,
                CREATED_TIMESTAMP,
                UPDATED_TIMESTAMP
            FROM BRONZE.TPA_MASTER
            ORDER BY CREATED_TIMESTAMP DESC
        """
        return await sf_service.execute_query_dict(query)
    except Exception as e:
        logger.error(f"Failed to get TPAs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("")
async def create_tpa(tpa: TPACreate):
    """Create new TPA"""
    try:
        sf_service = SnowflakeService()
        
        # Check if TPA already exists
        check_query = f"SELECT COUNT(*) as count FROM BRONZE.TPA_MASTER WHERE TPA_CODE = '{tpa.tpa_code}'"
        result = await sf_service.execute_query_dict(check_query)
        if result and result[0]['COUNT'] > 0:
            raise HTTPException(status_code=400, detail=f"TPA with code '{tpa.tpa_code}' already exists")
        
        # Call the add_tpa procedure
        result = await sf_service.execute_procedure(
            "add_tpa",
            tpa.tpa_code,
            tpa.tpa_name,
            tpa.tpa_description
        )
        
        # Update active status if needed
        if not tpa.active:
            update_query = f"""
                UPDATE BRONZE.TPA_MASTER 
                SET ACTIVE = FALSE 
                WHERE TPA_CODE = '{tpa.tpa_code}'
            """
            await sf_service.execute_query(update_query)
        
        return {"message": "TPA created successfully", "tpa_code": tpa.tpa_code}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to create TPA: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{tpa_code}")
async def update_tpa(tpa_code: str, tpa: TPAUpdate):
    """Update existing TPA"""
    try:
        sf_service = SnowflakeService()
        
        # Check if TPA exists
        check_query = f"SELECT COUNT(*) as count FROM BRONZE.TPA_MASTER WHERE TPA_CODE = '{tpa_code}'"
        result = await sf_service.execute_query_dict(check_query)
        if not result or result[0]['COUNT'] == 0:
            raise HTTPException(status_code=404, detail=f"TPA with code '{tpa_code}' not found")
        
        # Build update query
        updates = []
        if tpa.tpa_name is not None:
            updates.append(f"TPA_NAME = '{tpa.tpa_name}'")
        if tpa.tpa_description is not None:
            updates.append(f"TPA_DESCRIPTION = '{tpa.tpa_description}'")
        if tpa.active is not None:
            updates.append(f"ACTIVE = {tpa.active}")
        
        if updates:
            updates.append("UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()")
            update_query = f"""
                UPDATE BRONZE.TPA_MASTER 
                SET {', '.join(updates)}
                WHERE TPA_CODE = '{tpa_code}'
            """
            await sf_service.execute_query(update_query)
        
        return {"message": "TPA updated successfully", "tpa_code": tpa_code}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update TPA: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{tpa_code}")
async def delete_tpa(tpa_code: str):
    """Delete TPA (soft delete by setting ACTIVE = FALSE)"""
    try:
        sf_service = SnowflakeService()
        
        # Check if TPA exists
        check_query = f"SELECT COUNT(*) as count FROM BRONZE.TPA_MASTER WHERE TPA_CODE = '{tpa_code}'"
        result = await sf_service.execute_query_dict(check_query)
        if not result or result[0]['COUNT'] == 0:
            raise HTTPException(status_code=404, detail=f"TPA with code '{tpa_code}' not found")
        
        # Soft delete by setting ACTIVE = FALSE
        delete_query = f"""
            UPDATE BRONZE.TPA_MASTER 
            SET ACTIVE = FALSE, UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()
            WHERE TPA_CODE = '{tpa_code}'
        """
        await sf_service.execute_query(delete_query)
        
        return {"message": "TPA deleted successfully", "tpa_code": tpa_code}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete TPA: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.patch("/{tpa_code}/status")
async def update_tpa_status(tpa_code: str, status: TPAStatusUpdate):
    """Update TPA active status"""
    try:
        sf_service = SnowflakeService()
        
        # Check if TPA exists
        check_query = f"SELECT COUNT(*) as count FROM BRONZE.TPA_MASTER WHERE TPA_CODE = '{tpa_code}'"
        result = await sf_service.execute_query_dict(check_query)
        if not result or result[0]['COUNT'] == 0:
            raise HTTPException(status_code=404, detail=f"TPA with code '{tpa_code}' not found")
        
        # Update status
        update_query = f"""
            UPDATE BRONZE.TPA_MASTER 
            SET ACTIVE = {status.active}, UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()
            WHERE TPA_CODE = '{tpa_code}'
        """
        await sf_service.execute_query(update_query)
        
        return {
            "message": f"TPA {'activated' if status.active else 'deactivated'} successfully",
            "tpa_code": tpa_code,
            "active": status.active
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update TPA status: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
