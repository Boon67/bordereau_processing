# AutoML and LLM Mapping 500 Error Fix

## Issue
The AutoML and LLM mapping endpoints (`/api/silver/mappings/auto-ml` and `/api/silver/mappings/auto-llm`) were throwing 500 errors when called from the Snowpark Container Services environment.

## Root Cause
The `execute_procedure()` method in `SnowflakeService` was using Python's `cursor.callproc()` method, which doesn't work properly with Snowflake stored procedures, especially Python-based procedures. This caused the procedure calls to fail silently or throw errors.

## Solution
Modified the `_execute_procedure_sync()` method in `/backend/app/services/snowflake_service.py` to:

1. **Use CALL statement instead of callproc()**: Build a proper SQL `CALL` statement with formatted parameters
2. **Proper parameter formatting**: 
   - Strings are quoted and escaped (single quotes doubled)
   - Numbers and booleans are passed without quotes
   - NULL values are handled correctly
3. **Better logging**: Added logging of the actual CALL statement being executed for debugging
4. **Result handling**: Properly fetch and return the procedure result

## Changes Made

### File: `backend/app/services/snowflake_service.py`

**Before:**
```python
def _execute_procedure_sync(self, procedure_name: str, *args) -> Any:
    """Execute a stored procedure synchronously (internal use)"""
    try:
        with self.get_connection() as conn:
            with conn.cursor() as cursor:
                # Ensure we're using the SILVER schema for procedures
                cursor.execute(f"USE SCHEMA {settings.SILVER_SCHEMA_NAME}")
                result = cursor.callproc(procedure_name, args)
                return result
    except Exception as e:
        logger.error(f"Procedure execution failed: {str(e)}")
        raise
```

**After:**
```python
def _execute_procedure_sync(self, procedure_name: str, *args) -> Any:
    """Execute a stored procedure synchronously (internal use)"""
    try:
        with self.get_connection() as conn:
            with conn.cursor() as cursor:
                # Ensure we're using the SILVER schema for procedures
                cursor.execute(f"USE SCHEMA {settings.SILVER_SCHEMA_NAME}")
                
                # Build CALL statement with proper parameter formatting
                # Format parameters: strings get quotes, numbers/booleans don't
                formatted_args = []
                for arg in args:
                    if arg is None:
                        formatted_args.append('NULL')
                    elif isinstance(arg, str):
                        # Escape single quotes in strings
                        escaped = arg.replace("'", "''")
                        formatted_args.append(f"'{escaped}'")
                    elif isinstance(arg, bool):
                        formatted_args.append('TRUE' if arg else 'FALSE')
                    else:
                        formatted_args.append(str(arg))
                
                params_str = ', '.join(formatted_args)
                call_stmt = f"CALL {procedure_name}({params_str})"
                
                logger.info(f"Executing procedure: {call_stmt}")
                cursor.execute(call_stmt)
                
                # Fetch the result
                result = cursor.fetchone()
                if result:
                    return result[0] if len(result) == 1 else result
                return None
    except Exception as e:
        logger.error(f"Procedure execution failed: {str(e)}")
        raise
```

## Affected Endpoints

This fix affects all stored procedure calls, including:

1. **AutoML Mapping**: `POST /api/silver/mappings/auto-ml`
   - Calls: `auto_map_fields_ml(source_table, target_table, tpa, top_n, min_confidence)`

2. **LLM Mapping**: `POST /api/silver/mappings/auto-llm`
   - Calls: `auto_map_fields_llm(source_table, target_table, tpa, model_name, custom_prompt_id)`

3. **Field Mapping Approval**: `POST /api/silver/mappings/{mapping_id}/approve`
   - Calls: `approve_field_mapping(mapping_id)`

4. **Bronze to Silver Transform**: `POST /api/silver/transform`
   - Calls: `transform_bronze_to_silver(...)`

5. **Create Silver Table**: `POST /api/silver/tables/create`
   - Calls: `create_silver_table(table_name, tpa)`

## Testing

After deployment, test the endpoints:

```bash
# Test AutoML mapping
curl -X POST "https://your-endpoint.snowflakecomputing.app/api/silver/mappings/auto-ml" \
  -H "Content-Type: application/json" \
  -d '{
    "source_table": "RAW_DATA_TABLE",
    "target_table": "MEDICAL_CLAIMS",
    "tpa": "provider_a",
    "top_n": 3,
    "min_confidence": 0.6
  }'

# Test LLM mapping
curl -X POST "https://your-endpoint.snowflakecomputing.app/api/silver/mappings/auto-llm" \
  -H "Content-Type: application/json" \
  -d '{
    "source_table": "RAW_DATA_TABLE",
    "target_table": "MEDICAL_CLAIMS",
    "tpa": "provider_a",
    "model_name": "llama3.1-70b"
  }'
```

## Deployment

The fix was deployed using:
```bash
cd deployment
./redeploy_backend.sh
```

This script:
1. Builds the backend Docker image
2. Pushes it to the Snowflake registry
3. Restarts the Snowpark Container Service to pull the new image

## Status

✅ **Fixed and Deployed** - 2026-01-27

The backend service has been redeployed with the fix and is now running successfully.
