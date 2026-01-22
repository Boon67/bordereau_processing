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
    """Manually trigger file discovery"""
    try:
        sf_service = SnowflakeService()
        
        # List files in SRC stage
        stage_files = sf_service.list_stage_files(f"@{settings.BRONZE_SCHEMA_NAME}.SRC")
        
        # Insert new files into queue
        files_discovered = 0
        for file_info in stage_files:
            file_name = file_info.get('name', '')
            if not file_name:
                continue
                
            # Extract TPA from path (e.g., "src/provider_a/file.csv" -> "provider_a")
            path_parts = file_name.split('/')
            tpa = path_parts[1] if len(path_parts) > 1 else 'unknown'
            
            # Determine file type
            file_ext = file_name.lower()
            if file_ext.endswith('.csv'):
                file_type = 'CSV'
            elif file_ext.endswith(('.xlsx', '.xls')):
                file_type = 'EXCEL'
            else:
                file_type = 'UNKNOWN'
            
            # Check if file already exists in queue
            check_query = f"""
                SELECT COUNT(*) FROM {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                WHERE file_name = '{file_name}'
            """
            exists = sf_service.execute_query(check_query)[0][0] > 0
            
            if not exists:
                # Insert into queue
                insert_query = f"""
                    INSERT INTO {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                    (file_name, tpa, file_type, file_size_bytes, status)
                    VALUES ('{file_name}', '{tpa}', '{file_type}', {file_info.get('size', 0)}, 'PENDING')
                """
                sf_service.execute_query(insert_query)
                files_discovered += 1
        
        return {
            "message": f"File discovery completed successfully. Discovered {files_discovered} new files.",
            "files_discovered": files_discovered
        }
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
    """Manually trigger queue processing"""
    try:
        sf_service = SnowflakeService()
        
        # Get pending files from queue with short timeout
        query = f"""
            SELECT queue_id, file_name, tpa, file_type 
            FROM {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
            WHERE status = 'PENDING'
            LIMIT 10
        """
        pending_files = sf_service.execute_query_dict(query, timeout=30)
        
        files_processed = 0
        for file_info in pending_files:
            queue_id = file_info['QUEUE_ID']
            file_name = file_info['FILE_NAME']
            tpa = file_info['TPA']
            file_type = file_info['FILE_TYPE']
            
            try:
                # Update status to PROCESSING
                logger.info(f"Processing file: {file_name} (queue_id={queue_id}, type={file_type}, tpa={tpa})")
                update_query = f"""
                    UPDATE {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                    SET status = 'PROCESSING',
                        processed_timestamp = CURRENT_TIMESTAMP()
                    WHERE queue_id = {queue_id}
                """
                sf_service.execute_query(update_query)
                
                # Call appropriate processing procedure
                # Convert file_name to stage path format: src/provider_a/file.csv -> @SRC/provider_a/file.csv
                stage_path = f"@{file_name.upper().split('/')[0]}/{'/'.join(file_name.split('/')[1:])}"
                logger.info(f"Stage path: {stage_path}")
                
                if file_type == 'CSV':
                    proc_query = f"CALL {settings.BRONZE_SCHEMA_NAME}.process_single_csv_file('{stage_path}', '{tpa}')"
                elif file_type == 'EXCEL':
                    proc_query = f"CALL {settings.BRONZE_SCHEMA_NAME}.process_single_excel_file('{stage_path}', '{tpa}')"
                else:
                    raise Exception(f"Unsupported file type: {file_type}")
                
                logger.info(f"Calling procedure: {proc_query}")
                
                # Execute procedure and get result with longer timeout (20 minutes for file processing)
                # Increased from 10 to 20 minutes to handle larger files
                result = sf_service.execute_query(proc_query, timeout=1200)
                result_msg = result[0][0] if result and len(result) > 0 else "No result returned"
                
                logger.info(f"Processing result for {file_name}: {result_msg}")
                
                # Check if procedure returned an error (check for common error patterns)
                if any(keyword in result_msg.upper() for keyword in ['ERROR:', 'FAILED', 'EXCEPTION']):
                    raise Exception(result_msg)
                
                # Sanitize result message for SQL
                # Replace backslashes first, then single quotes
                safe_result_msg = result_msg.replace("\\", "\\\\").replace("'", "''")
                # Truncate safely to 500 chars
                if len(safe_result_msg) > 500:
                    safe_result_msg = safe_result_msg[:497] + "..."
                
                # Update status to SUCCESS
                success_query = f"""
                    UPDATE {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                    SET status = 'SUCCESS',
                        process_result = '{safe_result_msg}',
                        processed_timestamp = CURRENT_TIMESTAMP()
                    WHERE queue_id = {queue_id}
                """
                sf_service.execute_query(success_query)
                files_processed += 1
                logger.info(f"Successfully processed file: {file_name}")
                
            except Exception as proc_error:
                logger.error(f"Error processing file {file_name} (queue_id={queue_id}): {str(proc_error)}", exc_info=True)
                
                # Sanitize error message for SQL
                error_str = str(proc_error)
                # Replace backslashes first, then single quotes
                safe_error_msg = error_str.replace("\\", "\\\\").replace("'", "''")
                # Truncate safely to 500 chars
                if len(safe_error_msg) > 500:
                    safe_error_msg = safe_error_msg[:497] + "..."
                
                # Update status to FAILED
                try:
                    fail_query = f"""
                        UPDATE {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                        SET status = 'FAILED', 
                            error_message = '{safe_error_msg}',
                            processed_timestamp = CURRENT_TIMESTAMP(),
                            retry_count = COALESCE(retry_count, 0) + 1
                        WHERE queue_id = {queue_id}
                    """
                    sf_service.execute_query(fail_query)
                    logger.info(f"Updated queue status to FAILED for {file_name}")
                except Exception as update_error:
                    logger.error(f"Failed to update queue status for {file_name}: {update_error}")
                    # Continue processing other files even if update fails
        
        return {
            "message": f"Queue processing completed. Processed {files_processed} files.",
            "files_processed": files_processed
        }
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
