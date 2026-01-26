"""
Bronze Layer API Endpoints
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import tempfile
import os
import logging

from app.services.snowflake_service import SnowflakeService
from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()

@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    tpa: str = Form(...)
):
    """Upload file to Bronze @SRC stage"""
    try:
        # Validate file extension
        file_ext = os.path.splitext(file.filename)[1].lower()
        if file_ext not in settings.ALLOWED_EXTENSIONS:
            raise HTTPException(
                status_code=400,
                detail=f"File type {file_ext} not allowed. Allowed types: {settings.ALLOWED_EXTENSIONS}"
            )
        
        # Save file temporarily with original filename
        temp_dir = tempfile.gettempdir()
        tmp_path = os.path.join(temp_dir, file.filename)
        
        content = await file.read()
        with open(tmp_path, 'wb') as tmp_file:
            tmp_file.write(content)
        
        try:
            # Upload to Snowflake stage
            sf_service = SnowflakeService()
            stage_path = f"@{settings.BRONZE_SCHEMA_NAME}.SRC/{tpa}/"
            sf_service.upload_file_to_stage(tmp_path, stage_path)
            
            return {
                "message": f"File uploaded successfully to {stage_path}",
                "file_name": file.filename,
                "tpa": tpa,
                "size": len(content)
            }
        finally:
            # Clean up temp file
            os.unlink(tmp_path)
            
    except Exception as e:
        logger.error(f"File upload failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/queue")
async def get_processing_queue(tpa: Optional[str] = None):
    """Get file processing queue"""
    try:
        sf_service = SnowflakeService()
        return sf_service.get_processing_queue(tpa)
    except Exception as e:
        logger.error(f"Failed to get processing queue: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/status")
async def get_processing_status():
    """Get processing status summary"""
    try:
        sf_service = SnowflakeService()
        query = f"""
            SELECT * FROM {settings.BRONZE_SCHEMA_NAME}.v_processing_status_summary
            ORDER BY tpa, status
        """
        return sf_service.execute_query_dict(query)
    except Exception as e:
        logger.error(f"Failed to get processing status: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/stats")
async def get_bronze_stats(tpa: Optional[str] = None):
    """Get Bronze layer statistics including total row count"""
    try:
        sf_service = SnowflakeService()
        
        # Build WHERE clause for TPA filter
        tpa_filter = f"WHERE TPA = '{tpa}'" if tpa else ""
        
        # Get total row count from RAW_DATA_TABLE
        row_count_query = f"""
            SELECT COUNT(*) as total_rows
            FROM {settings.BRONZE_SCHEMA_NAME}.RAW_DATA_TABLE
            {tpa_filter}
        """
        row_count_result = sf_service.execute_query(row_count_query)
        total_rows = row_count_result[0][0] if row_count_result else 0
        
        # Get file statistics
        file_stats_query = f"""
            SELECT 
                COUNT(DISTINCT FILE_NAME) as total_files,
                COUNT(DISTINCT TPA) as total_tpas,
                MIN(LOAD_TIMESTAMP) as earliest_load,
                MAX(LOAD_TIMESTAMP) as latest_load
            FROM {settings.BRONZE_SCHEMA_NAME}.RAW_DATA_TABLE
            {tpa_filter}
        """
        file_stats_result = sf_service.execute_query_dict(file_stats_query)
        file_stats = file_stats_result[0] if file_stats_result else {}
        
        return {
            "total_rows": total_rows,
            "total_files": file_stats.get('TOTAL_FILES', 0),
            "total_tpas": file_stats.get('TOTAL_TPAS', 0),
            "earliest_load": file_stats.get('EARLIEST_LOAD'),
            "latest_load": file_stats.get('LATEST_LOAD')
        }
    except Exception as e:
        logger.error(f"Failed to get Bronze stats: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/raw-data")
async def get_raw_data(
    tpa: str,
    file_name: Optional[str] = None,
    limit: int = 100
):
    """Get raw data records"""
    try:
        sf_service = SnowflakeService()
        return sf_service.get_raw_data(tpa, file_name, limit)
    except Exception as e:
        logger.error(f"Failed to get raw data: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/stages/{stage_name}")
async def list_stage_files(stage_name: str):
    """List files in a stage"""
    try:
        sf_service = SnowflakeService()
        stage_path = f"@{settings.BRONZE_SCHEMA_NAME}.{stage_name.upper()}"
        return sf_service.list_stage_files(stage_path)
    except Exception as e:
        logger.error(f"Failed to list stage files: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/stages/{stage_name}/files")
async def delete_stage_file(stage_name: str, file_path: str):
    """Delete a file from a stage and update the processing queue"""
    try:
        sf_service = SnowflakeService()
        
        # Remove the file from the stage
        # file_path format: src/provider_a/file.csv
        # Need to convert to: @BRONZE.SRC/provider_a/file.csv
        stage_file_path = f"@{settings.BRONZE_SCHEMA_NAME}.{stage_name.upper()}/{'/'.join(file_path.split('/')[1:])}"
        
        remove_query = f"REMOVE {stage_file_path}"
        sf_service.execute_query(remove_query)
        logger.info(f"Removed file from stage: {stage_file_path}")
        
        # Update or remove the file from the processing queue
        # Check if file exists in queue
        check_query = f"""
            SELECT queue_id, status 
            FROM {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
            WHERE file_name = '{file_path}'
        """
        queue_result = sf_service.execute_query_dict(check_query)
        
        if queue_result:
            queue_id = queue_result[0]['QUEUE_ID']
            current_status = queue_result[0]['STATUS']
            
            # Delete from queue if PENDING or FAILED, update if SUCCESS/PROCESSING
            if current_status in ['PENDING', 'FAILED']:
                delete_query = f"""
                    DELETE FROM {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                    WHERE queue_id = {queue_id}
                """
                sf_service.execute_query(delete_query)
                logger.info(f"Deleted queue entry for {file_path} (queue_id={queue_id})")
                queue_action = "deleted"
            else:
                update_query = f"""
                    UPDATE {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                    SET status = 'DELETED',
                        error_message = 'File manually deleted from stage',
                        processed_timestamp = CURRENT_TIMESTAMP()
                    WHERE queue_id = {queue_id}
                """
                sf_service.execute_query(update_query)
                logger.info(f"Updated queue entry to DELETED for {file_path} (queue_id={queue_id})")
                queue_action = "marked_deleted"
        else:
            queue_action = "not_in_queue"
        
        return {
            "message": f"File deleted successfully from {stage_name} stage",
            "file_path": file_path,
            "stage_path": stage_file_path,
            "queue_action": queue_action
        }
    except Exception as e:
        logger.error(f"Failed to delete file: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/stages/{stage_name}/files/bulk-delete")
async def bulk_delete_stage_files(stage_name: str, file_paths: List[str]):
    """Delete multiple files from a stage at once"""
    try:
        sf_service = SnowflakeService()
        
        results = {
            "success": [],
            "failed": [],
            "total": len(file_paths)
        }
        
        for file_path in file_paths:
            try:
                # Remove the file from the stage
                stage_file_path = f"@{settings.BRONZE_SCHEMA_NAME}.{stage_name.upper()}/{'/'.join(file_path.split('/')[1:])}"
                
                remove_query = f"REMOVE {stage_file_path}"
                sf_service.execute_query(remove_query)
                logger.info(f"Removed file from stage: {stage_file_path}")
                
                # Update or remove from processing queue
                check_query = f"""
                    SELECT queue_id, status 
                    FROM {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                    WHERE file_name = '{file_path}'
                """
                queue_result = sf_service.execute_query_dict(check_query)
                
                if queue_result:
                    queue_id = queue_result[0]['QUEUE_ID']
                    current_status = queue_result[0]['STATUS']
                    
                    if current_status in ['PENDING', 'FAILED']:
                        delete_query = f"""
                            DELETE FROM {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                            WHERE queue_id = {queue_id}
                        """
                        sf_service.execute_query(delete_query)
                    else:
                        update_query = f"""
                            UPDATE {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                            SET status = 'DELETED',
                                error_message = 'File manually deleted from stage (bulk delete)',
                                processed_timestamp = CURRENT_TIMESTAMP()
                            WHERE queue_id = {queue_id}
                        """
                        sf_service.execute_query(update_query)
                
                results["success"].append(file_path)
                
            except Exception as e:
                logger.error(f"Failed to delete file {file_path}: {str(e)}")
                results["failed"].append({"file": file_path, "error": str(e)})
        
        return {
            "message": f"Bulk delete completed: {len(results['success'])} succeeded, {len(results['failed'])} failed",
            "results": results
        }
    except Exception as e:
        logger.error(f"Bulk delete failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/discover")
async def discover_files():
    """Manually trigger file discovery
    
    This endpoint triggers the Snowflake task to discover files asynchronously.
    It returns immediately without waiting for discovery to complete.
    Use the /queue endpoint to check for newly discovered files.
    """
    try:
        sf_service = SnowflakeService()
        
        # First, get a quick count of files in the stage
        try:
            stage_files = sf_service.list_stage_files(f"@{settings.BRONZE_SCHEMA_NAME}.SRC", timeout=10)
            file_count = len(stage_files)
        except Exception as e:
            # If listing times out, just proceed with task execution
            logger.warning(f"Could not list stage files: {e}")
            file_count = "unknown"
        
        # Trigger the Snowflake task to discover files asynchronously
        # This executes the task immediately without waiting for its schedule
        try:
            execute_task_query = f"""
                EXECUTE TASK {settings.BRONZE_SCHEMA_NAME}.discover_files_task
            """
            sf_service.execute_query(execute_task_query, timeout=10)
            logger.info(f"Triggered discover_files_task for {file_count} files in stage")
            
            return {
                "message": f"File discovery started for approximately {file_count} file(s) in @SRC stage",
                "status": "discovering",
                "note": "Discovery is happening asynchronously. Check /api/bronze/queue for newly discovered files."
            }
        except Exception as task_error:
            # If task execution fails (maybe task doesn't exist or is suspended),
            # fall back to calling the procedure directly
            logger.warning(f"Failed to execute task, falling back to direct procedure call: {task_error}")
            
            try:
                # Call the discover_files procedure directly (with timeout)
                proc_query = f"CALL {settings.BRONZE_SCHEMA_NAME}.discover_files()"
                result = sf_service.execute_query(proc_query, timeout=30)
                result_msg = result[0][0] if result and len(result) > 0 else "Discovery completed"
                
                return {
                    "message": result_msg,
                    "status": "completed",
                    "note": "Discovery completed synchronously (fallback mode).",
                    "fallback_mode": True
                }
            except Exception as proc_error:
                logger.error(f"Both task and procedure execution failed: {proc_error}")
                raise HTTPException(
                    status_code=500, 
                    detail=f"File discovery failed. Please check that discover_files_task is resumed: {str(proc_error)}"
                )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"File discovery failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/reset-stuck")
async def reset_stuck_files():
    """Reset stuck files in PROCESSING status back to PENDING"""
    try:
        sf_service = SnowflakeService()
        
        # Reset files that have been in PROCESSING status for more than 5 minutes
        reset_query = f"""
            UPDATE {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
            SET status = 'PENDING',
                error_message = 'Reset from stuck PROCESSING status'
            WHERE status = 'PROCESSING'
            AND (processed_timestamp IS NULL OR processed_timestamp < DATEADD(minute, -5, CURRENT_TIMESTAMP()))
        """
        sf_service.execute_query(reset_query)
        
        # Get count of reset files
        count_query = f"""
            SELECT COUNT(*) 
            FROM {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
            WHERE status = 'PENDING' 
            AND error_message = 'Reset from stuck PROCESSING status'
        """
        result = sf_service.execute_query(count_query)
        reset_count = result[0][0] if result else 0
        
        return {"message": f"Reset {reset_count} stuck files to PENDING status", "files_reset": reset_count}
    except Exception as e:
        logger.error(f"Failed to reset stuck files: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/reprocess/{queue_id}")
async def reprocess_file(queue_id: int):
    """Reprocess a failed file by resetting it to PENDING status"""
    try:
        sf_service = SnowflakeService()
        
        # Check if file exists and get its current status
        check_query = f"""
            SELECT queue_id, file_name, status, tpa
            FROM {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
            WHERE queue_id = {queue_id}
        """
        result = sf_service.execute_query_dict(check_query)
        
        if not result:
            raise HTTPException(status_code=404, detail=f"File with queue_id {queue_id} not found")
        
        file_info = result[0]
        current_status = file_info['STATUS']
        file_name = file_info['FILE_NAME']
        
        # Only allow reprocessing of FAILED files
        if current_status not in ['FAILED', 'SUCCESS']:
            raise HTTPException(
                status_code=400, 
                detail=f"Cannot reprocess file with status '{current_status}'. Only FAILED or SUCCESS files can be reprocessed."
            )
        
        # Reset the file to PENDING status
        reset_query = f"""
            UPDATE {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
            SET status = 'PENDING',
                error_message = NULL,
                process_result = NULL,
                processed_timestamp = NULL
            WHERE queue_id = {queue_id}
        """
        sf_service.execute_query(reset_query)
        
        logger.info(f"Reset file {file_name} (queue_id={queue_id}) from {current_status} to PENDING for reprocessing")
        
        return {
            "message": f"File {file_name} reset to PENDING status for reprocessing",
            "queue_id": queue_id,
            "file_name": file_name,
            "previous_status": current_status
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to reprocess file: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/process")
async def process_queue():
    """Manually trigger file discovery and processing
    
    This endpoint triggers the discover_files_task which automatically triggers
    process_files_task as its successor. This ensures both discovery and processing
    happen in the correct order.
    
    Returns immediately without waiting for processing to complete.
    Use the /queue endpoint to check processing status.
    """
    try:
        sf_service = SnowflakeService()
        
        # Get quick counts for informational purposes
        try:
            check_query = f"""
                SELECT 
                    COUNT(*) as pending_count,
                    (SELECT COUNT(*) FROM {settings.BRONZE_SCHEMA_NAME}.file_processing_queue WHERE status = 'PROCESSING') as processing_count
                FROM {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                WHERE status = 'PENDING'
            """
            result = sf_service.execute_query_dict(check_query, timeout=10)
            pending_count = result[0]['PENDING_COUNT'] if result else 0
            processing_count = result[0]['PROCESSING_COUNT'] if result else 0
        except Exception as e:
            logger.warning(f"Could not get queue counts: {e}")
            pending_count = "unknown"
            processing_count = "unknown"
        
        # Trigger discover_files_task which will automatically trigger process_files_task
        # This ensures we discover any new files AND process all pending files
        try:
            execute_task_query = f"""
                EXECUTE TASK {settings.BRONZE_SCHEMA_NAME}.discover_files_task
            """
            sf_service.execute_query(execute_task_query, timeout=10)
            logger.info(f"Triggered discover_files_task (which triggers process_files_task). Pending: {pending_count}, Processing: {processing_count}")
            
            return {
                "message": f"Discovery and processing started. {pending_count} pending file(s) in queue.",
                "pending_count": pending_count,
                "processing_count": processing_count,
                "status": "discovering_and_processing",
                "note": "discover_files_task will find new files, then process_files_task will process all pending files. Check /api/bronze/queue for status updates."
            }
        except Exception as task_error:
            # If task execution fails, fall back to calling the discover procedure directly
            logger.warning(f"Failed to execute discover_files_task, falling back to procedure: {task_error}")
            
            try:
                # Call discover procedure directly (with timeout)
                proc_query = f"CALL {settings.BRONZE_SCHEMA_NAME}.discover_files()"
                result = sf_service.execute_query(proc_query, timeout=30)
                result_msg = result[0][0] if result and len(result) > 0 else "Discovery completed"
                
                return {
                    "message": f"{result_msg}. Processing will happen via scheduled tasks.",
                    "pending_count": pending_count,
                    "status": "discovered",
                    "note": "Discovery completed. Scheduled tasks will process files. Check /api/bronze/queue for status.",
                    "fallback_mode": True
                }
            except Exception as proc_error:
                logger.error(f"Both task and procedure execution failed: {proc_error}")
                raise HTTPException(
                    status_code=500, 
                    detail=f"Discovery and processing failed. Please check that discover_files_task is resumed: {str(proc_error)}"
                )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Queue processing failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/tasks")
async def get_tasks():
    """Get Bronze tasks status with predecessor information"""
    try:
        sf_service = SnowflakeService()
        query = f"SHOW TASKS IN SCHEMA {settings.BRONZE_SCHEMA_NAME}"
        tasks = sf_service.execute_query_dict(query, timeout=30)
        
        # Add predecessor information to each task
        for task in tasks:
            task_name = task.get('name', '')
            # Get task details including predecessors
            desc_query = f"DESC TASK {settings.BRONZE_SCHEMA_NAME}.{task_name}"
            try:
                desc_result = sf_service.execute_query_dict(desc_query, timeout=30)
                # Find predecessor info in description
                for row in desc_result:
                    if row.get('property', '').upper() == 'PREDECESSORS':
                        task['predecessors'] = row.get('value', '')
                        break
                else:
                    task['predecessors'] = ''
            except:
                task['predecessors'] = ''
        
        return tasks
    except Exception as e:
        logger.error(f"Failed to get tasks: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/tasks/{task_name}/resume")
async def resume_task(task_name: str):
    """Resume a task"""
    try:
        sf_service = SnowflakeService()
        query = f"ALTER TASK {settings.BRONZE_SCHEMA_NAME}.{task_name} RESUME"
        sf_service.execute_query(query)
        return {"message": f"Task {task_name} resumed successfully"}
    except Exception as e:
        logger.error(f"Failed to resume task: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/tasks/{task_name}/suspend")
async def suspend_task(task_name: str):
    """Suspend a task"""
    try:
        sf_service = SnowflakeService()
        query = f"ALTER TASK {settings.BRONZE_SCHEMA_NAME}.{task_name} SUSPEND"
        sf_service.execute_query(query, timeout=30)
        return {"message": f"Task {task_name} suspended successfully"}
    except Exception as e:
        logger.error(f"Failed to suspend task: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

class ScheduleUpdate(BaseModel):
    schedule: str

@router.put("/tasks/{task_name}/schedule")
async def update_task_schedule(task_name: str, schedule_update: ScheduleUpdate):
    """Update task schedule (only for root tasks without predecessors)"""
    try:
        sf_service = SnowflakeService()
        schedule = schedule_update.schedule
        
        # Check if task has predecessors
        desc_query = f"DESC TASK {settings.BRONZE_SCHEMA_NAME}.{task_name}"
        desc_result = sf_service.execute_query_dict(desc_query, timeout=30)
        
        has_predecessors = False
        for row in desc_result:
            if row.get('property', '').upper() == 'PREDECESSORS':
                predecessors = row.get('value', '')
                if predecessors and predecessors.strip():
                    has_predecessors = True
                    break
        
        if has_predecessors:
            raise HTTPException(
                status_code=400,
                detail="Cannot modify schedule for tasks with predecessors. Only root tasks can have their schedule changed."
            )
        
        # Update the schedule
        alter_query = f"ALTER TASK {settings.BRONZE_SCHEMA_NAME}.{task_name} SET SCHEDULE = '{schedule}'"
        sf_service.execute_query(alter_query, timeout=30)
        
        return {"message": f"Task {task_name} schedule updated successfully", "new_schedule": schedule}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update task schedule: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/clear-all-data")
async def clear_all_data():
    """
    Clear all data from Bronze layer including:
    - All files from all stages (@SRC, @COMPLETED, @ERROR, @ARCHIVE)
    - All records from RAW_DATA_TABLE
    - All entries from file_processing_queue
    
    WARNING: This is a destructive operation that cannot be undone!
    """
    try:
        sf_service = SnowflakeService()
        results = {
            "stages_cleared": [],
            "tables_truncated": [],
            "errors": []
        }
        
        logger.warning("⚠️  CLEARING ALL BRONZE DATA - This is a destructive operation!")
        
        # Clear all stages
        stages = ["SRC", "COMPLETED", "ERROR", "ARCHIVE"]
        for stage in stages:
            try:
                remove_query = f"REMOVE @{settings.BRONZE_SCHEMA_NAME}.{stage}"
                sf_service.execute_query(remove_query)
                results["stages_cleared"].append(stage)
                logger.info(f"Cleared stage: @{stage}")
            except Exception as e:
                error_msg = f"Failed to clear stage {stage}: {str(e)}"
                results["errors"].append(error_msg)
                logger.error(error_msg)
        
        # Truncate tables (preserve structure, delete data)
        tables = ["RAW_DATA_TABLE", "file_processing_queue"]
        for table in tables:
            try:
                truncate_query = f"TRUNCATE TABLE IF EXISTS {settings.BRONZE_SCHEMA_NAME}.{table}"
                sf_service.execute_query(truncate_query)
                results["tables_truncated"].append(table)
                logger.info(f"Truncated table: {table}")
            except Exception as e:
                error_msg = f"Failed to truncate table {table}: {str(e)}"
                results["errors"].append(error_msg)
                logger.error(error_msg)
        
        # Build summary message
        success_count = len(results["stages_cleared"]) + len(results["tables_truncated"])
        error_count = len(results["errors"])
        
        if error_count == 0:
            message = f"✅ All Bronze data cleared successfully! Cleared {len(results['stages_cleared'])} stages and truncated {len(results['tables_truncated'])} tables."
        else:
            message = f"⚠️  Partial success: {success_count} operations succeeded, {error_count} failed. Check errors for details."
        
        return {
            "message": message,
            "results": results
        }
        
    except Exception as e:
        logger.error(f"Failed to clear all data: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/data/file/{file_name}")
async def delete_file_data(file_name: str):
    """
    Delete all data records for a specific file from RAW_DATA_TABLE.
    Updates the queue status to 'DELETED'.
    
    Args:
        file_name: Name of the file (with or without path)
    
    Returns:
        Success message with number of rows deleted
    """
    try:
        sf_service = SnowflakeService()
        
        # Call the stored procedure to delete file data
        query = f"CALL {settings.BRONZE_SCHEMA_NAME}.delete_file_data('{file_name}')"
        result = sf_service.execute_query(query)
        
        result_message = result[0][0] if result and len(result) > 0 else "File data deleted"
        
        logger.info(f"Deleted data for file: {file_name} - {result_message}")
        
        return {
            "message": result_message,
            "file_name": file_name
        }
        
    except Exception as e:
        logger.error(f"Failed to delete file data for {file_name}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
