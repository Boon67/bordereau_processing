"""
TPA Management API Endpoints
"""

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from typing import Optional
import logging

from app.services.snowflake_service import SnowflakeService
from app.utils.auth_utils import get_caller_token
from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()

class TPACreate(BaseModel):
    tpa_code: str
    tpa_name: str
    tpa_description: str = ""
    active: bool = True

class TPAUpdate(BaseModel):
    tpa_code: Optional[str] = None  # Allow updating TPA code
    tpa_name: Optional[str] = None
    tpa_description: Optional[str] = None
    active: Optional[bool] = None

class TPAStatusUpdate(BaseModel):
    active: bool

@router.get("")
async def get_tpas(request: Request):
    """Get all TPAs (active and inactive)"""
    try:
        # Use caller's token if available (caller's rights)
        caller_token = get_caller_token(request)
        sf_service = SnowflakeService(caller_token=caller_token)
        
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
async def create_tpa(request: Request, tpa: TPACreate):
    """Create new TPA"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
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
async def update_tpa(request: Request, tpa_code: str, tpa: TPAUpdate):
    """Update existing TPA (including TPA code with cascade updates)"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Check if TPA exists
        check_query = f"SELECT COUNT(*) as count FROM BRONZE.TPA_MASTER WHERE TPA_CODE = '{tpa_code}'"
        result = await sf_service.execute_query_dict(check_query)
        if not result or result[0]['COUNT'] == 0:
            raise HTTPException(status_code=404, detail=f"TPA with code '{tpa_code}' not found")
        
        # If TPA code is being changed, handle cascade updates
        new_tpa_code = tpa.tpa_code if tpa.tpa_code is not None else tpa_code
        
        if new_tpa_code != tpa_code:
            # Check if new TPA code already exists
            check_new_query = f"SELECT COUNT(*) as count FROM BRONZE.TPA_MASTER WHERE TPA_CODE = '{new_tpa_code}'"
            new_result = await sf_service.execute_query_dict(check_new_query)
            if new_result and new_result[0]['COUNT'] > 0:
                raise HTTPException(status_code=400, detail=f"TPA code '{new_tpa_code}' already exists")
            
            logger.info(f"Updating TPA code from '{tpa_code}' to '{new_tpa_code}' with cascade updates")
            
            # Get list of physical tables that need to be renamed
            from app.config import settings
            tables_query = f"""
                SELECT physical_table_name, schema_table_name
                FROM {settings.SILVER_SCHEMA_NAME}.created_tables 
                WHERE tpa = '{tpa_code}' AND active = TRUE
            """
            tables_result = await sf_service.execute_query_dict(tables_query)
            
            # Rename physical tables
            for table_row in tables_result:
                old_table_name = table_row['PHYSICAL_TABLE_NAME']
                schema_table = table_row['SCHEMA_TABLE_NAME']
                new_table_name = f"{new_tpa_code.upper()}_{schema_table.upper()}"
                
                try:
                    # Rename the physical table
                    rename_query = f"""
                        ALTER TABLE {settings.SILVER_SCHEMA_NAME}.{old_table_name} 
                        RENAME TO {settings.SILVER_SCHEMA_NAME}.{new_table_name}
                    """
                    await sf_service.execute_query(rename_query)
                    logger.info(f"Renamed table {old_table_name} to {new_table_name}")
                except Exception as e:
                    logger.warning(f"Failed to rename table {old_table_name}: {e}")
            
            # Update created_tables tracking
            update_tables_query = f"""
                UPDATE {settings.SILVER_SCHEMA_NAME}.created_tables 
                SET tpa = '{new_tpa_code}',
                    physical_table_name = CONCAT('{new_tpa_code.upper()}_', schema_table_name)
                WHERE tpa = '{tpa_code}'
            """
            await sf_service.execute_query(update_tables_query)
            logger.info(f"Updated created_tables for TPA '{tpa_code}' to '{new_tpa_code}'")
            
            # Update field mappings
            update_mappings_query = f"""
                UPDATE {settings.SILVER_SCHEMA_NAME}.field_mappings 
                SET tpa = '{new_tpa_code}'
                WHERE tpa = '{tpa_code}'
            """
            await sf_service.execute_query(update_mappings_query)
            logger.info(f"Updated field mappings for TPA '{tpa_code}' to '{new_tpa_code}'")
            
            # Update transformation rules
            update_rules_query = f"""
                UPDATE {settings.SILVER_SCHEMA_NAME}.transformation_rules 
                SET tpa = '{new_tpa_code}'
                WHERE tpa = '{tpa_code}'
            """
            await sf_service.execute_query(update_rules_query)
            logger.info(f"Updated transformation rules for TPA '{tpa_code}' to '{new_tpa_code}'")
            
            # Update processing logs
            update_logs_query = f"""
                UPDATE {settings.SILVER_SCHEMA_NAME}.silver_processing_log 
                SET tpa = '{new_tpa_code}'
                WHERE tpa = '{tpa_code}'
            """
            await sf_service.execute_query(update_logs_query)
            logger.info(f"Updated processing logs for TPA '{tpa_code}' to '{new_tpa_code}'")
            
            # Update Bronze raw data
            update_bronze_query = f"""
                UPDATE {settings.BRONZE_SCHEMA_NAME}.RAW_DATA_TABLE 
                SET TPA = '{new_tpa_code}'
                WHERE TPA = '{tpa_code}'
            """
            await sf_service.execute_query(update_bronze_query)
            logger.info(f"Updated Bronze raw data for TPA '{tpa_code}' to '{new_tpa_code}'")
        
        # Build update query for TPA_MASTER
        updates = []
        if new_tpa_code != tpa_code:
            updates.append(f"TPA_CODE = '{new_tpa_code}'")
        if tpa.tpa_name is not None:
            escaped_name = tpa.tpa_name.replace("'", "''")
            updates.append(f"TPA_NAME = '{escaped_name}'")
        if tpa.tpa_description is not None:
            escaped_desc = tpa.tpa_description.replace("'", "''")
            updates.append(f"TPA_DESCRIPTION = '{escaped_desc}'")
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
            logger.info(f"Updated TPA_MASTER for TPA '{tpa_code}'")
        
        return {
            "message": "TPA updated successfully",
            "tpa_code": new_tpa_code,
            "old_tpa_code": tpa_code if new_tpa_code != tpa_code else None,
            "tables_renamed": len(tables_result) if new_tpa_code != tpa_code else 0
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update TPA: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{tpa_code}")
async def delete_tpa(request: Request, tpa_code: str):
    """Delete TPA and all related data (mappings, tables, etc.)"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
        # Check if TPA exists
        check_query = f"SELECT COUNT(*) as count FROM BRONZE.TPA_MASTER WHERE TPA_CODE = '{tpa_code}'"
        result = await sf_service.execute_query_dict(check_query)
        if not result or result[0]['COUNT'] == 0:
            raise HTTPException(status_code=404, detail=f"TPA with code '{tpa_code}' not found")
        
        logger.info(f"Deleting TPA '{tpa_code}' and all related data")
        
        # 1. Get list of physical tables for this TPA
        tables_query = f"""
            SELECT physical_table_name 
            FROM {settings.SILVER_SCHEMA_NAME}.created_tables 
            WHERE tpa = '{tpa_code}' AND active = TRUE
        """
        tables_result = await sf_service.execute_query_dict(tables_query)
        
        # 2. Drop physical tables
        for table_row in tables_result:
            table_name = table_row['PHYSICAL_TABLE_NAME']
            try:
                drop_query = f"DROP TABLE IF EXISTS {settings.SILVER_SCHEMA_NAME}.{table_name}"
                await sf_service.execute_query(drop_query)
                logger.info(f"Dropped table {table_name}")
            except Exception as e:
                logger.warning(f"Failed to drop table {table_name}: {e}")
        
        # 3. Delete from created_tables tracking
        delete_tables_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.created_tables 
            WHERE tpa = '{tpa_code}'
        """
        await sf_service.execute_query(delete_tables_query)
        logger.info(f"Deleted created_tables records for TPA '{tpa_code}'")
        
        # 4. Delete field mappings
        delete_mappings_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.field_mappings 
            WHERE tpa = '{tpa_code}'
        """
        await sf_service.execute_query(delete_mappings_query)
        logger.info(f"Deleted field mappings for TPA '{tpa_code}'")
        
        # 5. Delete transformation rules (if any)
        delete_rules_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.transformation_rules 
            WHERE tpa = '{tpa_code}'
        """
        await sf_service.execute_query(delete_rules_query)
        logger.info(f"Deleted transformation rules for TPA '{tpa_code}'")
        
        # 6. Delete processing logs
        delete_logs_query = f"""
            DELETE FROM {settings.SILVER_SCHEMA_NAME}.silver_processing_log 
            WHERE tpa = '{tpa_code}'
        """
        await sf_service.execute_query(delete_logs_query)
        logger.info(f"Deleted processing logs for TPA '{tpa_code}'")
        
        # 7. Delete Bronze raw data
        delete_bronze_query = f"""
            DELETE FROM {settings.BRONZE_SCHEMA_NAME}.RAW_DATA_TABLE 
            WHERE TPA = '{tpa_code}'
        """
        await sf_service.execute_query(delete_bronze_query)
        logger.info(f"Deleted Bronze raw data for TPA '{tpa_code}'")
        
        # 8. Finally, delete the TPA from TPA_MASTER
        delete_tpa_query = f"""
            DELETE FROM BRONZE.TPA_MASTER 
            WHERE TPA_CODE = '{tpa_code}'
        """
        await sf_service.execute_query(delete_tpa_query)
        logger.info(f"Deleted TPA '{tpa_code}' from TPA_MASTER")
        
        return {
            "message": "TPA and all related data deleted successfully",
            "tpa_code": tpa_code,
            "tables_dropped": len(tables_result)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete TPA: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.patch("/{tpa_code}/status")
async def update_tpa_status(request: Request, tpa_code: str, status: TPAStatusUpdate):
    """Update TPA active status"""
    try:
        sf_service = SnowflakeService(caller_token=get_caller_token(request))
        
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
