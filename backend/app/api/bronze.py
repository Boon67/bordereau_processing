"""
Bronze Layer API Endpoints
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
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

@router.post("/process")
async def process_queue():
    """Manually trigger queue processing"""
    try:
        sf_service = SnowflakeService()
        
        # Get pending files from queue
        query = f"""
            SELECT queue_id, file_name, tpa, file_type 
            FROM {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
            WHERE status = 'PENDING'
            LIMIT 10
        """
        pending_files = sf_service.execute_query_dict(query)
        
        files_processed = 0
        for file_info in pending_files:
            queue_id = file_info['QUEUE_ID']
            file_name = file_info['FILE_NAME']
            tpa = file_info['TPA']
            file_type = file_info['FILE_TYPE']
            
            try:
                # Update status to PROCESSING
                update_query = f"""
                    UPDATE {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                    SET status = 'PROCESSING' 
                    WHERE queue_id = {queue_id}
                """
                sf_service.execute_query(update_query)
                
                # Call appropriate processing procedure
                # Convert file_name to stage path format: src/provider_a/file.csv -> @SRC/provider_a/file.csv
                stage_path = f"@{file_name.upper().split('/')[0]}/{'/'.join(file_name.split('/')[1:])}"
                
                if file_type == 'CSV':
                    proc_query = f"CALL {settings.BRONZE_SCHEMA_NAME}.process_single_csv_file('{stage_path}', '{tpa}')"
                elif file_type == 'EXCEL':
                    proc_query = f"CALL {settings.BRONZE_SCHEMA_NAME}.process_single_excel_file('{stage_path}', '{tpa}')"
                else:
                    raise Exception(f"Unsupported file type: {file_type}")
                
                # Execute procedure and get result
                result = sf_service.execute_query(proc_query)
                result_msg = result[0][0] if result and len(result) > 0 else "No result returned"
                
                logger.info(f"Processing result for {file_name}: {result_msg}")
                
                # Check if procedure returned an error
                if result_msg.startswith("ERROR:"):
                    raise Exception(result_msg)
                
                # Update status to SUCCESS
                success_query = f"""
                    UPDATE {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                    SET status = 'SUCCESS',
                        process_result = '{result_msg.replace("'", "''")}',
                        processed_timestamp = CURRENT_TIMESTAMP()
                    WHERE queue_id = {queue_id}
                """
                sf_service.execute_query(success_query)
                files_processed += 1
                
            except Exception as proc_error:
                logger.error(f"Error processing file {file_name} (queue_id={queue_id}): {str(proc_error)}")
                # Update status to FAILED
                error_msg = str(proc_error).replace("'", "''")  # Escape quotes
                fail_query = f"""
                    UPDATE {settings.BRONZE_SCHEMA_NAME}.file_processing_queue 
                    SET status = 'FAILED', 
                        error_message = '{error_msg[:500]}',
                        processed_timestamp = CURRENT_TIMESTAMP()
                    WHERE queue_id = {queue_id}
                """
                sf_service.execute_query(fail_query)
                logger.error(f"Failed to process file {file_name}: {proc_error}")
        
        return {
            "message": f"Queue processing completed. Processed {files_processed} files.",
            "files_processed": files_processed
        }
    except Exception as e:
        logger.error(f"Queue processing failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/tasks")
async def get_tasks():
    """Get Bronze tasks status"""
    try:
        sf_service = SnowflakeService()
        query = f"SHOW TASKS IN SCHEMA {settings.BRONZE_SCHEMA_NAME}"
        return sf_service.execute_query_dict(query)
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
        sf_service.execute_query(query)
        return {"message": f"Task {task_name} suspended successfully"}
    except Exception as e:
        logger.error(f"Failed to suspend task: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
