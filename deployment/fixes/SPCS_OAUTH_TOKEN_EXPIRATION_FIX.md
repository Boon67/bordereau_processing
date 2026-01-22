# SPCS OAuth Token Expiration Fix

**Date**: January 21, 2026  
**Issue**: Getting logged out and need to reauthenticate in SPCS  
**Status**: 🔧 Solution Available

---

## Problem

When running the application in Snowpark Container Services (SPCS), users occasionally get logged out and need to reauthenticate, especially:

- After suspending and resuming tasks
- After service restarts
- After periods of inactivity
- During long-running operations

**Symptoms:**
- ❌ API calls return authentication errors
- ❌ "Session expired" or "Token invalid" messages
- ❌ Need to refresh browser or re-login
- ❌ Happens more frequently after service operations

---

## Root Cause

### OAuth Token Lifecycle in SPCS

When using SPCS OAuth authentication (`SNOWSERVICES_INGRESS_OAUTH`):

1. **Token Lifetime**: OAuth tokens have a limited lifetime (typically 1 hour)
2. **No Auto-Refresh**: Tokens don't automatically refresh in SPCS
3. **Service Restart**: New tokens are issued after service restart
4. **Session State**: Backend loses session state on restart

**Why it happens during task suspend/resume:**
- Suspending a service stops containers
- Resuming creates new containers with new OAuth tokens
- Old tokens in browser/cache become invalid
- Backend needs to re-establish connection with new token

---

## Solutions

### Solution 1: Implement Token Refresh in Backend (Recommended)

Update the backend to handle token expiration gracefully and refresh tokens automatically.

#### A. Add Token Refresh Logic

Create `backend/app/middleware/token_refresh.py`:

```python
from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
import logging
import os

logger = logging.getLogger(__name__)

async def refresh_oauth_token_middleware(request: Request, call_next):
    """
    Middleware to handle OAuth token expiration and refresh
    """
    try:
        response = await call_next(request)
        return response
    except Exception as e:
        error_msg = str(e).lower()
        
        # Check if error is related to token expiration
        if any(keyword in error_msg for keyword in [
            'token', 'authentication', 'unauthorized', 'session'
        ]):
            logger.warning(f"Possible token expiration detected: {e}")
            
            # If using SPCS OAuth, token is automatically refreshed
            # by Snowflake on next request
            if os.getenv('SNOWFLAKE_AUTHENTICATOR') == 'SNOWSERVICES_INGRESS_OAUTH':
                logger.info("SPCS OAuth detected - token will refresh automatically")
                # Return 401 to trigger frontend re-authentication
                return JSONResponse(
                    status_code=401,
                    content={
                        "detail": "Session expired. Please refresh the page.",
                        "code": "TOKEN_EXPIRED"
                    }
                )
        
        # Re-raise if not token-related
        raise
```

#### B. Update Backend Main App

Modify `backend/app/main.py`:

```python
from app.middleware.token_refresh import refresh_oauth_token_middleware

app = FastAPI(title="Bordereau API")

# Add token refresh middleware
app.middleware("http")(refresh_oauth_token_middleware)
```

#### C. Add Connection Retry Logic

Update `backend/app/services/snowflake_service.py`:

```python
def get_connection(self):
    """Get Snowflake connection with retry on token expiration"""
    max_retries = 3
    retry_delay = 1  # seconds
    
    for attempt in range(max_retries):
        try:
            conn = snowflake.connector.connect(**self.connection_params)
            
            # Explicitly set context
            with conn.cursor() as cursor:
                warehouse = self.connection_params.get('warehouse')
                database = self.connection_params.get('database')
                
                if warehouse:
                    cursor.execute(f"USE WAREHOUSE {warehouse}")
                if database:
                    cursor.execute(f"USE DATABASE {database}")
            
            return conn
            
        except snowflake.connector.errors.DatabaseError as e:
            error_msg = str(e).lower()
            
            # Check if it's a token expiration error
            if 'token' in error_msg or 'authentication' in error_msg:
                if attempt < max_retries - 1:
                    logger.warning(f"Token expired, retrying... (attempt {attempt + 1}/{max_retries})")
                    time.sleep(retry_delay)
                    continue
                else:
                    logger.error("Token refresh failed after retries")
                    raise
            else:
                # Not a token error, raise immediately
                raise
    
    raise Exception("Failed to establish connection after retries")
```

---

### Solution 2: Frontend Token Handling

Update the frontend to handle token expiration gracefully.

#### A. Add Token Expiration Handler

Create `frontend/src/utils/authHandler.ts`:

```typescript
export const handleAuthError = (error: any) => {
  // Check if error is authentication-related
  if (error.response?.status === 401) {
    const errorCode = error.response?.data?.code;
    
    if (errorCode === 'TOKEN_EXPIRED') {
      // Show user-friendly message
      message.warning('Session expired. Refreshing page...');
      
      // Refresh page to get new token
      setTimeout(() => {
        window.location.reload();
      }, 1500);
      
      return true; // Handled
    }
  }
  
  return false; // Not handled
};
```

#### B. Update API Service

Modify `frontend/src/services/api.ts`:

```typescript
import { handleAuthError } from '../utils/authHandler';

// Add response interceptor
api.interceptors.response.use(
  (response) => response,
  (error) => {
    // Try to handle auth errors
    if (handleAuthError(error)) {
      return Promise.reject(error);
    }
    
    // Handle other errors normally
    return Promise.reject(error);
  }
);
```

---

### Solution 3: Increase Token Lifetime (Limited)

While you can't directly control SPCS OAuth token lifetime, you can configure session settings:

```sql
-- Set session timeout (applies to all sessions)
ALTER ACCOUNT SET CLIENT_SESSION_KEEP_ALIVE = TRUE;
ALTER ACCOUNT SET CLIENT_SESSION_KEEP_ALIVE_HEARTBEAT_FREQUENCY = 3600; -- 1 hour
```

**Note:** This has limited effect on SPCS OAuth tokens, which are managed by Snowflake.

---

### Solution 4: Service Health Check

Add a health check endpoint that validates token status:

#### Backend Health Check

Update `backend/app/api/health.py`:

```python
from fastapi import APIRouter, HTTPException
from app.services.snowflake_service import SnowflakeService

router = APIRouter()

@router.get("/health")
async def health_check():
    """Health check with token validation"""
    try:
        # Try to connect to Snowflake
        sf_service = SnowflakeService()
        conn = sf_service.get_connection()
        
        # Execute simple query to validate token
        with conn.cursor() as cursor:
            cursor.execute("SELECT CURRENT_USER(), CURRENT_ROLE()")
            result = cursor.fetchone()
        
        conn.close()
        
        return {
            "status": "healthy",
            "database": "connected",
            "user": result[0] if result else None,
            "role": result[1] if result else None,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(
            status_code=503,
            detail={
                "status": "unhealthy",
                "error": str(e),
                "code": "CONNECTION_FAILED"
            }
        )
```

#### Frontend Periodic Check

Add periodic health checks in frontend:

```typescript
// In App.tsx or main component
useEffect(() => {
  // Check health every 5 minutes
  const healthCheckInterval = setInterval(async () => {
    try {
      await api.get('/api/health');
    } catch (error) {
      if (handleAuthError(error)) {
        clearInterval(healthCheckInterval);
      }
    }
  }, 5 * 60 * 1000); // 5 minutes
  
  return () => clearInterval(healthCheckInterval);
}, []);
```

---

## Workarounds (Immediate)

### For Users

1. **Refresh Browser**
   ```
   Press Cmd+R (Mac) or Ctrl+R (Windows)
   ```

2. **Clear Cache and Reload**
   ```
   Press Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
   ```

3. **Open in New Tab**
   ```
   Right-click link → Open in New Tab
   ```

### For Administrators

1. **Restart Service** (gets new tokens)
   ```bash
   cd deployment
   ./manage_services.sh restart
   ```

2. **Check Service Status**
   ```bash
   ./manage_services.sh status
   ```

3. **View Logs** (check for auth errors)
   ```bash
   ./manage_services.sh logs backend 100 | grep -i "auth\|token"
   ```

---

## Prevention Best Practices

### 1. Minimize Service Restarts

- Avoid unnecessary task suspensions
- Use `ALTER TASK RESUME` instead of recreating tasks
- Plan maintenance windows

### 2. Implement Graceful Degradation

- Show user-friendly error messages
- Auto-retry failed requests
- Provide manual refresh option

### 3. Monitor Token Expiration

```sql
-- Check session info
SELECT 
    SESSION_ID,
    USER_NAME,
    CREATED_ON,
    LAST_SUCCESS_LOGIN,
    DATEDIFF(MINUTE, LAST_SUCCESS_LOGIN, CURRENT_TIMESTAMP()) as minutes_since_login
FROM TABLE(INFORMATION_SCHEMA.SESSIONS())
WHERE USER_NAME = CURRENT_USER()
ORDER BY CREATED_ON DESC;
```

### 4. Add User Notifications

Show warnings before token expiration:

```typescript
// Warn user 5 minutes before expected expiration
const TOKEN_LIFETIME = 60 * 60 * 1000; // 1 hour
const WARNING_TIME = 5 * 60 * 1000; // 5 minutes

setTimeout(() => {
  message.warning(
    'Your session will expire soon. Please save your work.',
    10 // Show for 10 seconds
  );
}, TOKEN_LIFETIME - WARNING_TIME);
```

---

## Testing

### Test Token Expiration Handling

1. **Simulate Token Expiration**
   ```bash
   # Restart service to force new tokens
   cd deployment
   ./manage_services.sh restart
   
   # Try to use old browser session
   # Should see graceful handling
   ```

2. **Test Auto-Refresh**
   ```bash
   # Make API call
   curl https://your-endpoint.snowflakecomputing.app/api/health
   
   # Restart service
   ./manage_services.sh restart
   
   # Make same API call (should handle gracefully)
   curl https://your-endpoint.snowflakecomputing.app/api/health
   ```

3. **Monitor Logs**
   ```bash
   # Watch for token refresh attempts
   ./manage_services.sh logs backend 50 | grep -i "token\|refresh\|auth"
   ```

---

## Related Issues

- [WAREHOUSE_FIX.md](WAREHOUSE_FIX.md) - Warehouse context for SPCS OAuth
- [TROUBLESHOOTING_500_ERRORS.md](TROUBLESHOOTING_500_ERRORS.md) - Related authentication issues
- [AUTHENTICATION_SETUP.md](../AUTHENTICATION_SETUP.md) - Authentication configuration

---

## Implementation Checklist

- [ ] Add token refresh middleware to backend
- [ ] Add connection retry logic
- [ ] Implement frontend auth error handler
- [ ] Add periodic health checks
- [ ] Add user notifications for expiring sessions
- [ ] Update error messages to be user-friendly
- [ ] Test token expiration scenarios
- [ ] Document for users

---

## Quick Reference

### When You Get Logged Out

```bash
# Option 1: Refresh browser
Press Cmd+R or Ctrl+R

# Option 2: Restart service (admin)
cd deployment
./manage_services.sh restart

# Option 3: Check service health
./manage_services.sh health
```

### Check Token Status

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;

-- Check current session
SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE();

-- Check session age
SELECT 
    DATEDIFF(MINUTE, LAST_SUCCESS_LOGIN, CURRENT_TIMESTAMP()) as session_age_minutes
FROM TABLE(INFORMATION_SCHEMA.SESSIONS())
WHERE SESSION_ID = CURRENT_SESSION();
```

---

## Status

**Current Status:** 🔧 Workarounds Available  
**Recommended Fix:** Implement token refresh middleware  
**Timeline:** Can be implemented in next update  
**Workaround:** Refresh browser when logged out

**Last Updated:** January 21, 2026
