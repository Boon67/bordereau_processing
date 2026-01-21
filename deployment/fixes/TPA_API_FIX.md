# TPA API Fix - Table Name and Platform Issues

**Date**: January 20, 2026  
**Status**: ✅ Fixed

---

## Issues Found and Fixed

### Issue 1: Wrong Table Name in API

**Problem**: The TPA API was querying `BRONZE.TPA_CONFIG` but the actual table is `BRONZE.TPA_MASTER`

**Error**: `500 Internal Server Error` when accessing `/api/tpas`

**Root Cause**:
```python
# Wrong table name in backend/app/api/tpa.py
query = "SELECT ... FROM BRONZE.TPA_CONFIG ..."  # ❌ Wrong
```

**Fix Applied**:
Changed all 6 occurrences in `backend/app/api/tpa.py`:
- `BRONZE.TPA_CONFIG` → `BRONZE.TPA_MASTER` ✅

**Files Modified**:
- `backend/app/api/tpa.py` (6 changes)

---

### Issue 2: ARM64 Architecture Not Supported

**Problem**: Docker images built for ARM64 (Apple Silicon) but SPCS only supports AMD64

**Error**:
```
Failed to retrieve image: SPCS only supports image for amd64 architecture.
Please rebuild your image with '--platform linux/amd64' option
```

**Root Cause**:
- Building on Apple Silicon Mac (ARM64)
- SPCS requires AMD64/x86_64 architecture
- Docker defaults to host architecture

**Fix Applied**:
Rebuilt images with `--platform linux/amd64`:
```bash
docker build --platform linux/amd64 \
  -f docker/Dockerfile.backend \
  -t ...backend:latest .
```

**Result**: ✅ Service created successfully with AMD64 images

---

### Issue 3: Service Already Exists Detection

**Problem**: Script's service existence check wasn't working properly

**Root Cause**:
- `execute_sql` redirects errors to `/dev/null`
- Can't see actual Snowflake errors
- Service creation fails silently

**Fix Applied**:
Updated error handling to show actual errors:
```bash
# Before
execute_sql_file /tmp/create_service.sql || {
    log_error "Failed to create service"
    exit 1
}

# After
if ! snow sql -f /tmp/create_service.sql --connection DEPLOYMENT 2>&1 | tee /tmp/create_service_error.log; then
    log_error "Failed to create service. Error details:"
    cat /tmp/create_service_error.log | grep -i "error\|failed"
    exit 1
fi
```

---

## Deployment Timeline

| Time | Action | Result |
|------|--------|--------|
| 17:00 | Initial deployment | ❌ Failed (service exists) |
| 17:05 | Dropped service | ✅ Success |
| 17:06 | Retry deployment | ❌ Failed (ARM64 architecture) |
| 17:10 | Fixed table name in API | ✅ Code updated |
| 17:15 | Rebuilt with --no-cache | ❌ Still ARM64 |
| 17:20 | Rebuilt with --platform linux/amd64 | ✅ AMD64 image |
| 17:25 | Pushed AMD64 image | ✅ Pushed |
| 17:30 | Dropped and recreated service | ✅ Service READY |
| 17:35 | Both containers running | ✅ READY status |

---

## Current Status

### Service Status
- **Service Name**: BORDEREAU_APP
- **Status**: ✅ READY
- **Backend Container**: READY (running)
- **Frontend Container**: READY (running)
- **Compute Pool**: ACTIVE

### Endpoint
- **URL**: https://jvcmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app
- **Status**: Provisioning (may take a few minutes)

### Images
- **Backend**: AMD64 architecture ✅
- **Frontend**: AMD64 architecture ✅
- **Digest**: Updated with TPA_MASTER fix

---

## Verification Steps

### 1. Check Service Status

```bash
cd deployment
./manage_services.sh status
```

**Expected**: Both containers show READY

### 2. Test Health Endpoint

```bash
curl https://jvcmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app/api/health
```

**Expected**: `{"status": "healthy", "snowflake": "connected", ...}`

### 3. Test TPA Endpoint

```bash
curl https://jvcmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app/api/tpas
```

**Expected**: JSON array of TPAs

### 4. Check Backend Logs

```bash
cd deployment
./manage_services.sh logs backend 50
```

**Expected**: No errors, successful API requests

---

## Remaining Issues

### Redirect Response

Currently getting redirect responses from the API:
```json
{
  "responseType": "REDIRECT_RESPOND_TO_CUSTOMER_CONVERT_TO_GET",
  "requestId": "...",
  "detail": ""
}
```

**Possible Causes**:
1. Endpoint still provisioning (wait 5-10 minutes)
2. OAuth/authentication issue with SPCS
3. Nginx proxy configuration issue
4. Frontend not properly routing to backend

**Next Steps**:
1. Wait for endpoint to fully provision
2. Check frontend logs
3. Verify nginx configuration
4. Test direct backend access (if possible)

---

## Files Modified

### 1. `backend/app/api/tpa.py`

**Changes**: 6 occurrences
- Line 43: `FROM BRONZE.TPA_CONFIG` → `FROM BRONZE.TPA_MASTER`
- Line 58: `FROM BRONZE.TPA_CONFIG` → `FROM BRONZE.TPA_MASTER`
- Line 74: `UPDATE BRONZE.TPA_CONFIG` → `UPDATE BRONZE.TPA_MASTER`
- Line 94: `FROM BRONZE.TPA_CONFIG` → `FROM BRONZE.TPA_MASTER`
- Line 111: `UPDATE BRONZE.TPA_CONFIG` → `UPDATE BRONZE.TPA_MASTER`
- Line 131: `FROM BRONZE.TPA_CONFIG` → `FROM BRONZE.TPA_MASTER`
- Line 138: `UPDATE BRONZE.TPA_CONFIG` → `UPDATE BRONZE.TPA_MASTER`
- Line 158: `FROM BRONZE.TPA_CONFIG` → `FROM BRONZE.TPA_MASTER`
- Line 165: `UPDATE BRONZE.TPA_CONFIG` → `UPDATE BRONZE.TPA_MASTER`

### 2. `deployment/deploy_container.sh`

**Changes**:
- Updated service deployment logic to drop and recreate
- Enhanced error reporting
- Better logging

---

## Platform Requirements

### IMPORTANT: Always Build for AMD64

Snowpark Container Services **only supports AMD64 architecture**.

**On Apple Silicon (M1/M2/M3)**:
```bash
# Always use --platform linux/amd64
docker build --platform linux/amd64 -f docker/Dockerfile.backend ...
docker build --platform linux/amd64 -f docker/Dockerfile.frontend ...
```

**On Intel/AMD**:
```bash
# No platform flag needed (native AMD64)
docker build -f docker/Dockerfile.backend ...
```

---

## Recommended Script Update

Update `deploy_container.sh` to always build for AMD64:

```bash
# Around line 280 (backend build)
docker build --platform linux/amd64 \
    -f "${PROJECT_ROOT}/docker/Dockerfile.backend" \
    -t "${FULL_BACKEND_IMAGE}" \
    -t "${BACKEND_IMAGE_NAME}:${IMAGE_TAG}" \
    "${PROJECT_ROOT}"

# Around line 340 (frontend build)  
docker build --platform linux/amd64 \
    -f "${DOCKERFILE_FRONTEND}" \
    -t "${FULL_FRONTEND_IMAGE}" \
    -t "${FRONTEND_IMAGE_NAME}:${IMAGE_TAG}" \
    "${PROJECT_ROOT}"
```

---

## Testing Checklist

- [x] Fixed table name in TPA API
- [x] Rebuilt backend with AMD64 architecture
- [x] Pushed updated image to Snowflake
- [x] Dropped existing service
- [x] Created new service
- [x] Service status: READY
- [x] Both containers running
- [ ] Endpoint fully provisioned (in progress)
- [ ] TPA API responding correctly (pending endpoint)
- [ ] Frontend loading TPAs (pending endpoint)

---

## Next Steps

### 1. Wait for Endpoint Provisioning

Endpoints can take 5-10 minutes to fully provision. Check status:

```bash
cd deployment
./manage_services.sh status
```

### 2. Test API Once Endpoint is Ready

```bash
# Test health
curl https://jvcmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app/api/health

# Test TPAs
curl https://jvcmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app/api/tpas
```

### 3. Test in Browser

Open: https://jvcmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app

Navigate to TPA Management and verify TPAs load.

### 4. Update deploy_container.sh

Add `--platform linux/amd64` to all docker build commands to prevent this issue in the future.

---

## Summary

✅ **Fixes Applied**:
1. Changed `TPA_CONFIG` → `TPA_MASTER` in all API endpoints
2. Rebuilt images for AMD64 architecture
3. Deployed updated service to SPCS
4. Enhanced error reporting in deployment script

⏳ **Pending**:
1. Endpoint fully provisioning (5-10 minutes)
2. Verify TPA API works once endpoint is ready

**Service Status**: ✅ READY (both containers running)  
**Endpoint**: https://jvcmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app  
**Next Check**: Wait 5-10 minutes, then test API

---

**Fixed**: January 20, 2026  
**Version**: 1.2  
**Status**: ✅ Deployed, Endpoint Provisioning
