# Backend Readiness Probe Fix - Quick Summary

**Issue**: Backend container showing "Pending" status with "Readiness probe is failing at path /api/health"

---

## What Was Fixed

### 1. Separated Health Check Endpoints

**Before**: `/api/health` tried to connect to Snowflake (slow, 5-10 seconds)

**After**: Three separate endpoints:
- `/api/health` - Basic health check (< 100ms) - **Used by readiness probe**
- `/api/health/db` - Database health check (2-5 seconds) - For monitoring
- `/api/health/ready` - Readiness check (< 100ms) - For additional checks

### 2. Improved Probe Timing

**Before**:
```yaml
readinessProbe:
  initialDelaySeconds: 10  # Too short!
  periodSeconds: 10
```

**After**:
```yaml
readinessProbe:
  initialDelaySeconds: 30  # Gives backend time to start
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

livenessProbe:
  initialDelaySeconds: 60  # Even more time
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 3
```

### 3. Enhanced SPCS OAuth Configuration

Added better logging and error handling for warehouse configuration in SPCS OAuth mode.

---

## Files Changed

1. `backend/app/main.py` - Added new health endpoints
2. `docker/snowpark-spec.yaml` - Updated probe settings
3. `docker/Dockerfile.backend` - Updated healthcheck start period
4. `backend/app/config.py` - Enhanced SPCS OAuth logging

---

## How to Deploy the Fix

### Option 1: Automated Script (Recommended)

```bash
cd deployment
./fix_readiness_probe.sh
```

This script will:
1. Check current service status
2. Rebuild backend image
3. Push to Snowflake registry
4. Suspend and resume service
5. Monitor startup
6. Test health endpoints

### Option 2: Manual Deployment

```bash
cd deployment

# 1. Rebuild and push backend
./deploy_container.sh

# 2. Restart service
./manage_services.sh restart

# 3. Monitor status
./manage_services.sh status

# 4. Check logs
./manage_services.sh logs backend 50
```

---

## Testing the Fix

### Test Health Endpoints

```bash
# Get service endpoint
ENDPOINT=$(snow spcs service list --database BORDEREAU_PROCESSING_PIPELINE --schema BRONZE --format json | jq -r '.[0].dns_name')

# Test basic health (should be fast)
curl https://$ENDPOINT/api/health

# Test database health (may take a few seconds)
curl https://$ENDPOINT/api/health/db

# Test readiness
curl https://$ENDPOINT/api/health/ready
```

### Expected Results

**Basic Health** (`/api/health`):
```json
{
  "status": "healthy",
  "service": "running",
  "timestamp": "2026-01-21T18:30:00.000000"
}
```

**Database Health** (`/api/health/db`):
```json
{
  "status": "healthy",
  "service": "running",
  "database": "connected",
  "version": "8.10.0",
  "warehouse": "COMPUTE_WH",
  "database_name": "BORDEREAU_PROCESSING_PIPELINE",
  "timestamp": "2026-01-21T18:30:00.000000"
}
```

---

## Timeline

After deploying the fix:

1. **0-30 seconds**: Backend container starts, Python loads
2. **30 seconds**: First readiness probe check (should pass now!)
3. **40 seconds**: Backend should show "Ready" status
4. **60 seconds**: Liveness probe starts checking

---

## Troubleshooting

### Backend Still Shows "Pending"

```bash
# Check logs for errors
./manage_services.sh logs backend 100

# Look for:
# - Connection errors
# - Missing environment variables
# - Warehouse issues
```

### Health Check Returns 503

This means the database health check is failing. Check:

```bash
# View Snowflake connection logs
./manage_services.sh logs backend 50 | grep -i "snowflake\|connection\|warehouse"
```

### Probe Timeout

If probes are still timing out, you may need to increase the timeout:

```yaml
readinessProbe:
  timeoutSeconds: 10  # Increase from 5
  initialDelaySeconds: 60  # Increase from 30
```

---

## Related Documentation

- **[deployment/fixes/READINESS_PROBE_FIX.md](deployment/fixes/READINESS_PROBE_FIX.md)** - Complete fix documentation
- **[deployment/fixes/SPCS_OAUTH_TOKEN_EXPIRATION_FIX.md](deployment/fixes/SPCS_OAUTH_TOKEN_EXPIRATION_FIX.md)** - Token expiration handling
- **[deployment/fixes/WAREHOUSE_FIX.md](deployment/fixes/WAREHOUSE_FIX.md)** - Warehouse configuration

---

## Quick Commands

```bash
# Deploy fix
cd deployment && ./fix_readiness_probe.sh

# Check status
./manage_services.sh status

# View logs
./manage_services.sh logs backend 50

# Test health
curl https://$(snow spcs service list --database BORDEREAU_PROCESSING_PIPELINE --schema BRONZE --format json | jq -r '.[0].dns_name')/api/health
```

---

**Status**: ✅ Ready to Deploy  
**Estimated Time**: 5-10 minutes  
**Risk Level**: Low (only affects health checks)

**Last Updated**: January 21, 2026
