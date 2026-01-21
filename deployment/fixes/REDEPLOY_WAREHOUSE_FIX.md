# Redeploy Instructions - Warehouse Fix

**Date**: January 21, 2026  
**Issue**: Backend still showing warehouse errors despite code fix

## Current Status

✅ Code has been fixed in:
- `backend/app/services/snowflake_service.py`
- `backend/app/config.py`

❌ Container image has NOT been rebuilt/redeployed yet

## Error in Logs

```
2026-01-21 21:30:43,612 - app.api.tpa - ERROR - Failed to get TPAs: 000606   
(57P03): No active warehouse selected in the current session.
```

## Solution: Rebuild and Redeploy

### Step 1: Rebuild Backend Image

```bash
cd /Users/tboon/code/bordereau

# Build new backend image with the warehouse fix
docker build -f docker/Dockerfile.backend -t bordereau_backend:latest .
```

### Step 2: Push to Snowflake Registry

```bash
# Tag for Snowflake registry
docker tag bordereau_backend:latest \
  sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/bordereau_processing_pipeline/public/bordereau_repository/bordereau_backend:latest

# Push to registry
docker push sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/bordereau_processing_pipeline/public/bordereau_repository/bordereau_backend:latest
```

### Step 3: Restart Service

```bash
cd deployment

# Restart the service to pull new image
./manage_services.sh restart-image backend
```

### Step 4: Verify Fix

```bash
# Wait for service to restart (30-60 seconds)
sleep 60

# Check logs for warehouse being set
./manage_services.sh logs backend 50 | grep -i warehouse

# Should see:
# INFO: Using warehouse for SPCS: COMPUTE_WH
# INFO: Setting warehouse: COMPUTE_WH

# Test the API
curl https://f2cmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app/api/tpas
```

## Quick One-Liner

```bash
cd /Users/tboon/code/bordereau && \
docker build -f docker/Dockerfile.backend -t bordereau_backend:latest . && \
docker tag bordereau_backend:latest sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/bordereau_processing_pipeline/public/bordereau_repository/bordereau_backend:latest && \
docker push sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/bordereau_processing_pipeline/public/bordereau_repository/bordereau_backend:latest && \
cd deployment && \
./manage_services.sh restart-image backend
```

## Expected Results

After redeployment:
- ✅ No more warehouse errors
- ✅ `/api/tpas` returns data
- ✅ All API endpoints work
- ✅ Logs show "Setting warehouse: COMPUTE_WH"

---

**Status**: Ready to redeploy  
**Estimated Time**: 5-10 minutes
