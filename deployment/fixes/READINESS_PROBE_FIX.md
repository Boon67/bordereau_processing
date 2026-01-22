# Backend Readiness Probe Failure Fix

**Date**: January 21, 2026  
**Issue**: Backend container failing readiness probe in SPCS  
**Status**: 🔧 Solution Available

---

## Problem

The backend container shows "Pending" status with message: "Readiness probe is failing at path /api/health"

**Symptoms:**
- ❌ Backend container status: "Pending"
- ❌ Frontend shows "Ready" but backend is not accessible
- ❌ Health check endpoint `/api/health` failing
- ❌ Service cannot start properly

---

## Root Causes

### 1. Health Check Tries to Connect to Snowflake (Slow)

The current health check at `/api/health` attempts to connect to Snowflake and execute a query:

```python
@app.get("/api/health")
async def health_check():
    try:
        # This is SLOW and can timeout
        sf_service = SnowflakeService()
        result = sf_service.execute_query("SELECT CURRENT_VERSION()")
        return {"status": "healthy", "snowflake": "connected"}
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={"status": "unhealthy", "error": str(e)}
        )
```

**Problems:**
- Snowflake connection can take 5-10 seconds
- Health check runs every 10 seconds
- Initial delay is only 10 seconds
- Connection failures return 503 (unhealthy)

### 2. Missing Warehouse Configuration for SPCS OAuth

When using SPCS OAuth authentication, the warehouse must be explicitly set:

```python
# In config.py - warehouse is added but may not be used correctly
config['warehouse'] = warehouse
```

However, the connection might not be using the warehouse properly.

### 3. Insufficient Initial Delay

The readiness probe starts checking after only 10 seconds:

```yaml
readinessProbe:
  httpGet:
    path: /api/health
    port: 8000
  initialDelaySeconds: 10  # Too short!
  periodSeconds: 10
```

The backend needs time to:
- Start Python interpreter
- Load all dependencies
- Initialize FastAPI
- Establish Snowflake connection

---

## Solutions

### Solution 1: Separate Basic Health from Database Health (Recommended)

Create two health endpoints:
1. `/api/health` - Basic health (fast, for readiness probe)
2. `/api/health/db` - Database health (detailed, for monitoring)

#### A. Update Backend Health Endpoints

Modify `backend/app/main.py`:

```python
@app.get("/api/health")
async def health_check():
    """
    Basic health check for readiness probe.
    Returns 200 if the service is running.
    Does NOT check Snowflake connection (too slow for probe).
    """
    return {
        "status": "healthy",
        "service": "running",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/health/db")
async def database_health_check():
    """
    Detailed health check including Snowflake connection.
    Use this for monitoring, not for readiness probe.
    """
    try:
        # Test Snowflake connection
        sf_service = SnowflakeService()
        
        # Set a short timeout for health check
        result = sf_service.execute_query(
            "SELECT CURRENT_VERSION(), CURRENT_WAREHOUSE(), CURRENT_DATABASE()",
            timeout=10
        )
        
        return {
            "status": "healthy",
            "service": "running",
            "database": "connected",
            "version": result[0][0] if result else "unknown",
            "warehouse": result[0][1] if result and len(result[0]) > 1 else "unknown",
            "database_name": result[0][2] if result and len(result[0]) > 2 else "unknown",
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Database health check failed: {str(e)}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "service": "running",
                "database": "disconnected",
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }
        )

@app.get("/api/health/ready")
async def readiness_check():
    """
    Readiness check - service is ready to accept traffic.
    Checks if critical dependencies are available.
    """
    checks = {
        "service": "running",
        "timestamp": datetime.now().isoformat()
    }
    
    # Optional: Add quick checks for critical dependencies
    # Don't check Snowflake here - too slow
    
    return {
        "status": "ready",
        **checks
    }
```

#### B. Update Snowpark Spec

Modify `docker/snowpark-spec.yaml`:

```yaml
spec:
  containers:
  - name: backend
    image: /snowflake_pipeline/backend:latest
    env:
      ENVIRONMENT: production
      SNOWFLAKE_ACCOUNT: <SNOWFLAKE_ACCOUNT>
      SNOWFLAKE_USER: <SNOWFLAKE_USER>
      SNOWFLAKE_PASSWORD: <SNOWFLAKE_PASSWORD>
      SNOWFLAKE_ROLE: SYSADMIN
      SNOWFLAKE_WAREHOUSE: COMPUTE_WH
      DATABASE_NAME: BORDEREAU_PROCESSING_PIPELINE
      BRONZE_SCHEMA_NAME: BRONZE
      SILVER_SCHEMA_NAME: SILVER
    resources:
      requests:
        cpu: 1
        memory: 2Gi
      limits:
        cpu: 2
        memory: 4Gi
    readinessProbe:
      httpGet:
        path: /api/health  # Use basic health check
        port: 8000
      initialDelaySeconds: 30  # Increased from 10
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    livenessProbe:
      httpGet:
        path: /api/health  # Use basic health check
        port: 8000
      initialDelaySeconds: 60  # Increased from 30
      periodSeconds: 30
      timeoutSeconds: 10
      failureThreshold: 3
```

**Key Changes:**
- `initialDelaySeconds: 30` for readiness (was 10)
- `initialDelaySeconds: 60` for liveness (was 30)
- Added `timeoutSeconds` and `failureThreshold`
- Both probes use `/api/health` (fast endpoint)

---

### Solution 2: Optimize Snowflake Connection for Health Checks

If you still want to check Snowflake in health endpoint, optimize the connection:

#### A. Add Connection Pool

Update `backend/app/services/snowflake_service.py`:

```python
class SnowflakeService:
    """Service for interacting with Snowflake"""
    
    # Class-level connection pool
    _connection_pool = None
    _pool_lock = threading.Lock()
    
    def __init__(self):
        self.connection_params = settings.get_snowflake_config()
        logger.info(f"Initialized Snowflake service for account: {self.connection_params.get('account')}")
    
    @classmethod
    def get_pooled_connection(cls):
        """Get connection from pool (faster for health checks)"""
        with cls._pool_lock:
            if cls._connection_pool is None:
                # Create connection pool
                cls._connection_pool = snowflake.connector.connect(
                    **settings.get_snowflake_config()
                )
            
            return cls._connection_pool
    
    def get_connection(self):
        """Get Snowflake connection with timeout settings"""
        try:
            # Add timeout parameters to prevent hanging
            connection_params = self.connection_params.copy()
            connection_params['network_timeout'] = 10  # Reduced from 60 for health checks
            connection_params['login_timeout'] = 10    # Reduced from 30 for health checks
            
            # Disable SSL certificate validation for stage operations
            connection_params['insecure_mode'] = True
            
            conn = snowflake.connector.connect(**connection_params)
            
            # Explicitly set warehouse, database, and schema after connection
            with conn.cursor() as cursor:
                warehouse = connection_params.get('warehouse', settings.SNOWFLAKE_WAREHOUSE)
                database = connection_params.get('database', settings.DATABASE_NAME)
                
                if warehouse:
                    logger.info(f"Setting warehouse: {warehouse}")
                    cursor.execute(f"USE WAREHOUSE {warehouse}")
                
                if database:
                    logger.info(f"Setting database: {database}")
                    cursor.execute(f"USE DATABASE {database}")
                    
                    schema = connection_params.get('schema')
                    if schema:
                        logger.info(f"Setting schema: {schema}")
                        cursor.execute(f"USE SCHEMA {schema}")
            
            return conn
        except Exception as e:
            logger.error(f"Failed to connect to Snowflake: {str(e)}")
            raise
```

#### B. Add Health Check Cache

Cache health check results to avoid repeated slow connections:

```python
from datetime import datetime, timedelta
import threading

# Global cache for health check
_health_cache = {
    "status": None,
    "timestamp": None,
    "lock": threading.Lock()
}

HEALTH_CACHE_TTL = 30  # seconds

@app.get("/api/health")
async def health_check():
    """
    Health check with caching to avoid repeated slow connections.
    """
    global _health_cache
    
    with _health_cache["lock"]:
        # Check if we have a recent cached result
        if (_health_cache["status"] is not None and 
            _health_cache["timestamp"] is not None):
            
            age = (datetime.now() - _health_cache["timestamp"]).total_seconds()
            
            if age < HEALTH_CACHE_TTL:
                # Return cached result
                return _health_cache["status"]
        
        # Cache is stale or doesn't exist, check Snowflake
        try:
            sf_service = SnowflakeService()
            result = sf_service.execute_query(
                "SELECT CURRENT_VERSION()",
                timeout=5  # Short timeout
            )
            
            status = {
                "status": "healthy",
                "snowflake": "connected",
                "version": result[0][0] if result else "unknown",
                "timestamp": datetime.now().isoformat()
            }
            
            # Update cache
            _health_cache["status"] = status
            _health_cache["timestamp"] = datetime.now()
            
            return status
            
        except Exception as e:
            logger.error(f"Health check failed: {str(e)}")
            
            # Don't cache failures
            return JSONResponse(
                status_code=503,
                content={
                    "status": "unhealthy",
                    "error": str(e),
                    "timestamp": datetime.now().isoformat()
                }
            )
```

---

### Solution 3: Fix SPCS OAuth Warehouse Configuration

Ensure warehouse is properly set for SPCS OAuth connections.

#### Update config.py

The current implementation already adds warehouse, but ensure it's used:

```python
def _load_spcs_token(self) -> Optional[dict]:
    """Load Snowpark Container Services OAuth token"""
    try:
        token_file = Path('/snowflake/session/token')
        
        if not token_file.exists():
            return None
        
        with open(token_file, 'r') as f:
            token = f.read().strip()
        
        if not token:
            return None
        
        snowflake_host = os.getenv('SNOWFLAKE_HOST')
        snowflake_account = os.getenv('SNOWFLAKE_ACCOUNT')
        snowflake_database = os.getenv('SNOWFLAKE_DATABASE')
        snowflake_schema = os.getenv('SNOWFLAKE_SCHEMA')
        
        if not snowflake_host or not snowflake_account:
            logger.warning("SPCS token found but required environment variables not set")
            return None
        
        config = {
            'host': snowflake_host,
            'account': snowflake_account,
            'token': token,
            'authenticator': 'oauth',
            'database': snowflake_database or self.DATABASE_NAME,
            'schema': snowflake_schema,
        }
        
        # CRITICAL: Add warehouse for SPCS OAuth
        # Check environment variable first, then fall back to config
        warehouse = os.getenv('SNOWFLAKE_WAREHOUSE') or self.SNOWFLAKE_WAREHOUSE
        if warehouse:
            config['warehouse'] = warehouse
            logger.info(f"SPCS OAuth: Using warehouse {warehouse}")
        else:
            logger.error("SPCS OAuth: No warehouse specified - connection will fail!")
            return None  # Don't return config without warehouse
        
        logger.info(f"SPCS OAuth token loaded for account: {snowflake_account}")
        return config
        
    except Exception as e:
        logger.debug(f"Could not load SPCS token: {e}")
        return None
```

---

### Solution 4: Add Startup Probe (Kubernetes 1.16+)

If SPCS supports startup probes, add one to handle slow initial startup:

```yaml
spec:
  containers:
  - name: backend
    # ... other config ...
    
    startupProbe:
      httpGet:
        path: /api/health
        port: 8000
      initialDelaySeconds: 10
      periodSeconds: 5
      failureThreshold: 12  # 12 * 5s = 60s total startup time
    
    readinessProbe:
      httpGet:
        path: /api/health
        port: 8000
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    
    livenessProbe:
      httpGet:
        path: /api/health
        port: 8000
      periodSeconds: 30
      timeoutSeconds: 10
      failureThreshold: 3
```

**Benefits:**
- Startup probe handles slow initial startup
- Readiness probe can be more aggressive after startup
- Liveness probe won't kill container during startup

---

## Implementation Steps

### Step 1: Update Health Endpoints (Quick Fix)

```bash
# Edit backend/app/main.py
# Add the new health endpoints as shown in Solution 1
```

### Step 2: Update Snowpark Spec

```bash
# Edit docker/snowpark-spec.yaml
# Update readiness and liveness probe settings
```

### Step 3: Rebuild and Redeploy

```bash
cd deployment

# Rebuild backend image
./deploy_container.sh

# Redeploy service
./manage_services.sh restart
```

### Step 4: Verify Health Endpoints

```bash
# Test basic health (should be fast)
curl https://your-endpoint.snowflakecomputing.app/api/health

# Test database health (may be slow)
curl https://your-endpoint.snowflakecomputing.app/api/health/db
```

### Step 5: Monitor Container Status

```bash
# Check service status
./manage_services.sh status

# Watch logs
./manage_services.sh logs backend 50
```

---

## Testing

### Test Health Endpoints Locally

```bash
# Start backend locally
cd backend
uvicorn app.main:app --reload

# Test basic health (should return immediately)
curl http://localhost:8000/api/health

# Test database health (may take a few seconds)
curl http://localhost:8000/api/health/db
```

### Test in SPCS

```bash
# Deploy to SPCS
cd deployment
./deploy_container.sh

# Check service status (should show "Ready" after ~30 seconds)
./manage_services.sh status

# Test health endpoint through service
curl https://your-endpoint.snowflakecomputing.app/api/health
```

---

## Troubleshooting

### Backend Still Shows "Pending"

1. **Check Logs**
   ```bash
   ./manage_services.sh logs backend 100
   ```

2. **Look for Errors**
   - Connection timeouts
   - Authentication failures
   - Missing environment variables

3. **Verify Warehouse**
   ```sql
   -- Check if warehouse exists and is available
   SHOW WAREHOUSES LIKE 'COMPUTE_WH';
   
   -- Check warehouse state
   SELECT "name", "state", "size"
   FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
   ```

### Health Check Returns 503

1. **Check Snowflake Connection**
   ```bash
   # View startup logs
   ./manage_services.sh logs backend 100 | grep -i "snowflake\|connection"
   ```

2. **Verify Environment Variables**
   ```bash
   # Check if SPCS env vars are set
   ./manage_services.sh logs backend 50 | grep -i "SNOWFLAKE_"
   ```

3. **Test Connection Manually**
   ```python
   # In Python shell
   from app.services.snowflake_service import SnowflakeService
   sf = SnowflakeService()
   conn = sf.get_connection()
   ```

### Probe Timeout

If probes are timing out:

1. **Increase Timeout**
   ```yaml
   readinessProbe:
     timeoutSeconds: 10  # Increase from 5
   ```

2. **Increase Initial Delay**
   ```yaml
   readinessProbe:
     initialDelaySeconds: 60  # Increase from 30
   ```

3. **Use Basic Health Check**
   - Make sure `/api/health` doesn't check Snowflake
   - Use `/api/health/db` for detailed checks

---

## Quick Reference

### Recommended Probe Settings

```yaml
# For fast health check (no DB connection)
readinessProbe:
  httpGet:
    path: /api/health
    port: 8000
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

livenessProbe:
  httpGet:
    path: /api/health
    port: 8000
  initialDelaySeconds: 60
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 3
```

### Health Endpoint Response Times

- `/api/health` - < 100ms (no DB check)
- `/api/health/db` - 2-5 seconds (with DB check)
- `/api/health/ready` - < 100ms (readiness check)

---

## Related Issues

- [SPCS_OAUTH_TOKEN_EXPIRATION_FIX.md](SPCS_OAUTH_TOKEN_EXPIRATION_FIX.md) - Token expiration handling
- [WAREHOUSE_FIX.md](WAREHOUSE_FIX.md) - Warehouse configuration for SPCS
- [TROUBLESHOOTING_500_ERRORS.md](TROUBLESHOOTING_500_ERRORS.md) - General error troubleshooting

---

## Status

**Current Status:** 🔧 Solution Available  
**Recommended Fix:** Separate basic health from database health  
**Priority:** High (blocks service startup)  
**Estimated Time:** 15-30 minutes

**Last Updated:** January 21, 2026
