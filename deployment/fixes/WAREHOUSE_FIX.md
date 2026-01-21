# Warehouse Fix for SPCS OAuth

**Issue**: `No active warehouse selected in the current session`  
**Date**: January 21, 2026  
**Status**: ✅ Fixed

---

## Problem

When running the backend in Snowpark Container Services (SPCS) with OAuth authentication, API calls were failing with:

```json
{
    "detail": "000606 (57P03): No active warehouse selected in the current session. Select an active warehouse with the 'use warehouse' command."
}
```

## Root Cause

When using SPCS OAuth authentication (`/snowflake/session/token`), Snowflake provides:
- ✅ `SNOWFLAKE_HOST` environment variable
- ✅ `SNOWFLAKE_ACCOUNT` environment variable
- ✅ `SNOWFLAKE_DATABASE` environment variable
- ✅ `SNOWFLAKE_SCHEMA` environment variable
- ❌ **NOT** `SNOWFLAKE_WAREHOUSE` environment variable

The connection was established successfully, but **no warehouse was set in the session**, causing all queries to fail.

## Solution

### 1. Explicitly Set Warehouse After Connection

Modified `backend/app/services/snowflake_service.py` to explicitly set warehouse, database, and schema after establishing connection:

```python
def get_connection(self):
    """Get Snowflake connection with timeout settings"""
    try:
        # ... connection setup ...
        
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
```

### 2. Enhanced SPCS OAuth Configuration

Modified `backend/app/config.py` to check for `SNOWFLAKE_WAREHOUSE` environment variable and provide better logging:

```python
# Add warehouse - CRITICAL for SPCS OAuth
# SPCS doesn't set SNOWFLAKE_WAREHOUSE env var by default
# Check env var first, then fall back to config default
warehouse = os.getenv('SNOWFLAKE_WAREHOUSE') or self.SNOWFLAKE_WAREHOUSE
if warehouse:
    config['warehouse'] = warehouse
    logger.info(f"Using warehouse for SPCS: {warehouse}")
else:
    logger.warning("No warehouse specified for SPCS connection - queries may fail")
```

## Configuration

### Option 1: Environment Variable (Recommended for SPCS)

Set in your Snowpark service spec:

```yaml
spec:
  containers:
  - name: backend
    image: /bordereau_processing_pipeline/repository/backend:latest
    env:
      SNOWFLAKE_WAREHOUSE: COMPUTE_WH  # ← Add this
      SNOWFLAKE_ROLE: SYSADMIN
      DATABASE_NAME: BORDEREAU_PROCESSING_PIPELINE
```

### Option 2: Default Configuration

The backend defaults to `COMPUTE_WH` if not specified:

```python
# In backend/app/config.py
SNOWFLAKE_WAREHOUSE: str = "COMPUTE_WH"
```

## Testing

### 1. Check Backend Logs

Look for these log messages:

```
INFO: Using warehouse for SPCS: COMPUTE_WH
INFO: Setting warehouse: COMPUTE_WH
INFO: Setting database: BORDEREAU_PROCESSING_PIPELINE
```

### 2. Test API Endpoint

```bash
# Get the backend endpoint
BACKEND_URL=$(snow spcs service status bordereau_container_service --connection DEPLOYMENT | grep -o 'https://[^"]*')

# Test health endpoint
curl $BACKEND_URL/api/health

# Expected response:
{
  "status": "healthy",
  "snowflake": "connected",
  "version": "1.0.0"
}
```

### 3. Test TPA Endpoint

```bash
# Test TPAs endpoint (requires warehouse)
curl $BACKEND_URL/api/tpas

# Should return list of TPAs, not warehouse error
```

## Verification

After applying the fix:

1. ✅ Backend connects to Snowflake successfully
2. ✅ Warehouse is explicitly set in session
3. ✅ All API endpoints work correctly
4. ✅ No "No active warehouse" errors

## Related Files

- `backend/app/services/snowflake_service.py` - Connection management
- `backend/app/config.py` - Configuration loading
- `docker/snowpark-spec.yaml` - SPCS service specification

## Prevention

To prevent this issue in the future:

1. **Always set warehouse explicitly** after connection for SPCS OAuth
2. **Include SNOWFLAKE_WAREHOUSE** in service spec environment variables
3. **Log warehouse selection** for debugging
4. **Test all API endpoints** after deployment

## Additional Notes

### Why This Happens

Snowflake's SPCS OAuth token provides authentication but doesn't include warehouse context. This is by design - the service should specify which warehouse to use.

### Why Explicit USE WAREHOUSE

While the connection parameters include `warehouse`, the SPCS OAuth connection doesn't automatically activate it. We must explicitly execute `USE WAREHOUSE` after connection.

### Performance Impact

Minimal - the `USE WAREHOUSE` command is executed once per connection and is very fast.

---

**Status**: ✅ Fixed and Deployed  
**Version**: 1.0  
**Last Updated**: January 21, 2026
