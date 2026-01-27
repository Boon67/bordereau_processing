"""
Snowflake Service - Handles all Snowflake interactions
Supports both snow CLI connections and direct credentials
"""

import snowflake.connector
from snowflake.connector import DictCursor
from typing import List, Dict, Any, Optional
import logging

from app.config import settings

logger = logging.getLogger(__name__)

class SnowflakeService:
    """Service for interacting with Snowflake"""
    
    def __init__(self):
        # Get connection parameters from settings (handles both snow CLI and direct)
        self.connection_params = settings.get_snowflake_config()
        logger.info(f"Initialized Snowflake service for account: {self.connection_params.get('account')}")
    
    def get_connection(self):
        """Get Snowflake connection with timeout settings"""
        try:
            # Add timeout parameters to prevent hanging
            connection_params = self.connection_params.copy()
            connection_params['network_timeout'] = 60  # 60 seconds for network operations
            connection_params['login_timeout'] = 30    # 30 seconds for login
            
            # Disable SSL certificate validation for stage operations
            # This is needed when uploading to Snowflake stages backed by S3
            connection_params['insecure_mode'] = True
            
            conn = snowflake.connector.connect(**connection_params)
            
            # Explicitly set warehouse, database, and schema after connection
            # This is especially important for SPCS OAuth connections
            with conn.cursor() as cursor:
                warehouse = connection_params.get('warehouse', settings.SNOWFLAKE_WAREHOUSE)
                database = connection_params.get('database', settings.DATABASE_NAME)
                
                if warehouse:
                    logger.info(f"Setting warehouse: {warehouse}")
                    cursor.execute(f"USE WAREHOUSE {warehouse}")
                
                if database:
                    logger.info(f"Setting database: {database}")
                    cursor.execute(f"USE DATABASE {database}")
                    
                    # Set schema if provided
                    schema = connection_params.get('schema')
                    if schema:
                        logger.info(f"Setting schema: {schema}")
                        cursor.execute(f"USE SCHEMA {schema}")
            
            return conn
        except Exception as e:
            logger.error(f"Failed to connect to Snowflake: {str(e)}")
            raise
    
    def execute_query(self, query: str, params: Optional[Dict] = None, timeout: int = 300) -> List[tuple]:
        """Execute a query and return results with timeout"""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    # Set statement timeout (in seconds)
                    cursor.execute(f"ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = {timeout}")
                    
                    if params:
                        cursor.execute(query, params)
                    else:
                        cursor.execute(query)
                    return cursor.fetchall()
        except Exception as e:
            logger.error(f"Query execution failed: {str(e)}")
            raise
    
    def execute_query_dict(self, query: str, params: Optional[Dict] = None, timeout: int = 300) -> List[Dict[str, Any]]:
        """Execute a query and return results as list of dictionaries with timeout"""
        try:
            with self.get_connection() as conn:
                with conn.cursor(DictCursor) as cursor:
                    # Set statement timeout (in seconds)
                    cursor.execute(f"ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = {timeout}")
                    
                    if params:
                        cursor.execute(query, params)
                    else:
                        cursor.execute(query)
                    return cursor.fetchall()
        except Exception as e:
            logger.error(f"Query execution failed: {str(e)}")
            raise
    
    def execute_procedure(self, procedure_name: str, *args) -> Any:
        """Execute a stored procedure"""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    result = cursor.callproc(procedure_name, args)
                    return result
        except Exception as e:
            logger.error(f"Procedure execution failed: {str(e)}")
            raise
    
    def upload_file_to_stage(self, local_path: str, stage_path: str) -> bool:
        """Upload file to Snowflake stage"""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    put_query = f"PUT file://{local_path} {stage_path} AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
                    cursor.execute(put_query)
                    return True
        except Exception as e:
            logger.error(f"File upload failed: {str(e)}")
            raise
    
    def list_stage_files(self, stage_name: str) -> List[Dict[str, Any]]:
        """List files in a stage"""
        try:
            query = f"LIST {stage_name}"
            return self.execute_query_dict(query)
        except Exception as e:
            logger.error(f"Failed to list stage files: {str(e)}")
            raise
    
    def get_tpas(self) -> List[Dict[str, Any]]:
        """Get all TPAs"""
        query = f"""
            SELECT 
                TPA_CODE,
                TPA_NAME,
                TPA_DESCRIPTION,
                ACTIVE,
                CREATED_TIMESTAMP,
                UPDATED_TIMESTAMP
            FROM {settings.BRONZE_SCHEMA_NAME}.TPA_MASTER
            WHERE ACTIVE = TRUE
            ORDER BY TPA_CODE
        """
        return self.execute_query_dict(query)
    
    def get_processing_queue(self, tpa: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get file processing queue with timeout"""
        query = f"""
            SELECT 
                queue_id,
                file_name,
                tpa,
                file_type,
                file_size_bytes,
                status,
                discovered_timestamp,
                processed_timestamp,
                error_message,
                process_result,
                retry_count
            FROM {settings.BRONZE_SCHEMA_NAME}.file_processing_queue
        """
        
        if tpa:
            query += f" WHERE tpa = '{tpa}'"
        
        query += " ORDER BY discovered_timestamp DESC LIMIT 100"
        
        return self.execute_query_dict(query, timeout=30)
    
    def get_raw_data(self, tpa: str, file_name: Optional[str] = None, limit: int = 100) -> List[Dict[str, Any]]:
        """Get raw data records"""
        query = f"""
            SELECT 
                RECORD_ID,
                FILE_NAME,
                FILE_ROW_NUMBER,
                TPA,
                RAW_DATA,
                FILE_TYPE,
                LOAD_TIMESTAMP,
                LOADED_BY
            FROM {settings.BRONZE_SCHEMA_NAME}.RAW_DATA_TABLE
            WHERE TPA = '{tpa}'
        """
        
        if file_name:
            query += f" AND FILE_NAME = '{file_name}'"
        
        query += f" ORDER BY FILE_ROW_NUMBER LIMIT {limit}"
        
        return self.execute_query_dict(query)
    
    def get_target_schemas(self, tpa: Optional[str] = None, table_name: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get target schemas (TPA-agnostic)"""
        logger.info(f"Getting target schemas - table_name: '{table_name}'")
        
        query = f"""
            SELECT 
                schema_id,
                table_name,
                column_name,
                data_type,
                nullable,
                default_value,
                description,
                active
            FROM {settings.SILVER_SCHEMA_NAME}.target_schemas
            WHERE active = TRUE
        """
        
        if table_name:
            query += f" AND table_name = '{table_name.upper()}'"
        
        query += " ORDER BY table_name, schema_id"
        
        logger.info(f"Executing query: {query}")
        result = self.execute_query_dict(query)
        logger.info(f"Found {len(result)} schema records")
        
        return result
    
    def get_field_mappings(self, tpa: str, target_table: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get field mappings"""
        query = f"""
            SELECT 
                mapping_id,
                source_field,
                source_table,
                target_table,
                target_column,
                tpa,
                mapping_method,
                transformation_logic,
                confidence_score,
                approved,
                approved_by,
                approved_timestamp,
                description,
                active
            FROM {settings.SILVER_SCHEMA_NAME}.field_mappings
            WHERE tpa = '{tpa}' AND active = TRUE
        """
        
        if target_table:
            query += f" AND target_table = '{target_table.upper()}'"
        
        query += " ORDER BY target_table, mapping_id"
        
        return self.execute_query_dict(query)
