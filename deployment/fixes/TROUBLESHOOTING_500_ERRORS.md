# Troubleshooting 500 Errors in SPCS

**Date**: January 21, 2026  
**Issue**: 500 Internal Server Errors in Snowpark Container Services

---

## Current Issue: Warehouse Not Selected

### Symptoms

- ✅ Health endpoint works: `/api/health` returns 200
- ❌ Other endpoints fail: `/api/tpas` returns 500
- ❌ Logs show: `No active warehouse selected in the current session`

### Root Cause

The backend code was fixed to explicitly set the warehouse, but **the container image hasn't been rebuilt/redeployed yet**. The running container still has the old code.

---

## Quick Fix: Redeploy Backend

### Option 1: Use the Redeploy Script (Recommended)

```bash
cd /Users/tboon/code/bordereau/deployment
./redeploy_backend.sh
```

This script will:
1. Build new backend image
2. Push to Snowflake registry
3. Restart the service
4. Verify the fix

### Option 2: Manual Steps

```bash
# 1. Build image
cd /Users/tboon/code/bordereau
docker build -f docker/Dockerfile.backend -t bordereau_backend:latest .

# 2. Tag for registry
docker tag bordereau_backend:latest \
  sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/bordereau_processing_pipeline/public/bordereau_repository/bordereau_backend:latest

# 3. Push to registry
docker push sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/bordereau_processing_pipeline/public/bordereau_repository/bordereau_backend:latest

# 4. Restart service
cd deployment
./manage_services.sh restart-image backend

# 5. Wait and verify
sleep 60
./manage_services.sh logs backend 50 | grep -i warehouse
```

---

## Verification Steps

### 1. Check Service Status

```bash
cd deployment
./manage_services.sh status
```

Expected: Both containers show `READY` status

### 2. Check Logs for Warehouse Setup

```bash
./manage_services.sh logs backend 50 | grep -i warehouse
```

Expected output:
```
INFO: Using warehouse for SPCS: COMPUTE_WH
INFO: Setting warehouse: COMPUTE_WH
INFO: Setting database: BORDEREAU_PROCESSING_PIPELINE
```

### 3. Test Health Endpoint

```bash
curl https://f2cmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app/api/health
```

Expected:
```json
{
  "status": "healthy",
  "snowflake": "connected",
  "version": "1.0.0"
}
```

### 4. Test TPAs Endpoint

```bash
curl https://f2cmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app/api/tpas
```

Expected: JSON array of TPAs (not an error)

### 5. Check for Errors in Logs

```bash
./manage_services.sh logs backend 100 | grep -i error
```

Expected: No warehouse-related errors

---

## Common Issues and Solutions

### Issue 1: "No active warehouse selected"

**Cause**: Old container image without warehouse fix

**Solution**: Redeploy backend (see above)

### Issue 2: Docker build fails

**Cause**: Docker not running or permission issues

**Solution**:
```bash
# Check Docker is running
docker ps

# If permission denied, add user to docker group
sudo usermod -aG docker $USER
# Then log out and back in
```

### Issue 3: Push to registry fails

**Cause**: Not authenticated to Snowflake registry

**Solution**:
```bash
# Login to Snowflake registry
snow connection test --connection DEPLOYMENT

# If that fails, check your connection
cat ~/.snowflake/connections.toml
```

### Issue 4: Service won't restart

**Cause**: Service might be in a bad state

**Solution**:
```bash
# Check service status
./manage_services.sh status

# If stuck, try suspend/resume
snow spcs service suspend BORDEREAU_APP --connection DEPLOYMENT
sleep 10
snow spcs service resume BORDEREAU_APP --connection DEPLOYMENT
```

### Issue 5: Still getting 500 after redeploy

**Cause**: Multiple possible issues

**Solution**:
```bash
# 1. Check if new image was pulled
./manage_services.sh describe backend | grep -i image

# 2. Check full logs for other errors
./manage_services.sh logs backend 200

# 3. Verify warehouse is in spec
cat ../docker/snowpark-spec.yaml | grep -i warehouse

# 4. Check if warehouse exists
snow sql -q "SHOW WAREHOUSES LIKE 'COMPUTE_WH'" --connection DEPLOYMENT
```

---

## Understanding the Fix

### What Changed

**Before (broken):**
```python
def get_connection(self):
    conn = snowflake.connector.connect(**connection_params)
    return conn  # ❌ Warehouse not set in session
```

**After (fixed):**
```python
def get_connection(self):
    conn = snowflake.connector.connect(**connection_params)
    
    # ✅ Explicitly set warehouse after connection
    with conn.cursor() as cursor:
        warehouse = connection_params.get('warehouse', settings.SNOWFLAKE_WAREHOUSE)
        if warehouse:
            cursor.execute(f"USE WAREHOUSE {warehouse}")
    
    return conn
```

### Why This Is Needed

When using SPCS OAuth authentication:
1. Snowflake provides an OAuth token
2. Connection succeeds
3. But **no warehouse is automatically selected**
4. Queries fail with "No active warehouse selected"

The fix explicitly runs `USE WAREHOUSE` after connection to ensure the warehouse is active.

---

## Monitoring After Fix

### Watch Logs in Real-Time

```bash
# Terminal 1: Watch backend logs
./manage_services.sh logs backend 50
# Press Ctrl+C, then run again to refresh

# Terminal 2: Test endpoints
while true; do
  echo "Testing at $(date)"
  curl -s https://f2cmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app/api/tpas | jq .
  sleep 5
done
```

### Check Service Health

```bash
# Every minute, check status
watch -n 60 './manage_services.sh status'
```

---

## Success Criteria

After redeployment, you should see:

✅ No warehouse errors in logs  
✅ `/api/health` returns 200  
✅ `/api/tpas` returns data (not error)  
✅ Logs show "Setting warehouse: COMPUTE_WH"  
✅ All API endpoints work correctly  

---

## Getting Help

If issues persist after redeployment:

1. **Collect diagnostic info:**
   ```bash
   cd deployment
   ./manage_services.sh all > diagnostics.txt 2>&1
   ./manage_services.sh logs backend 200 >> diagnostics.txt 2>&1
   ```

2. **Check these files:**
   - `deployment/WAREHOUSE_FIX.md` - Detailed fix explanation
   - `deployment/REDEPLOY_WAREHOUSE_FIX.md` - Redeploy instructions
   - `backend/app/services/snowflake_service.py` - Connection code
   - `backend/app/config.py` - Configuration code

3. **Verify the fix is in the code:**
   ```bash
   grep -A20 "def get_connection" backend/app/services/snowflake_service.py
   ```

   Should show `USE WAREHOUSE` command in the code.

---

**Status**: Fix implemented, awaiting redeploy  
**Last Updated**: January 21, 2026  
**Next Step**: Run `./redeploy_backend.sh`
