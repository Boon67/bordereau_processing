# Authentication Cookie Fix

## Problem

Users were being kicked out randomly because the `sfc-ss-ingress-auth-v1` cookie (set by Snowpark Container Services ingress) was getting reset on some API responses.

## Root Cause

The issue had **two parts**:

### 1. Frontend Not Sending Credentials
The frontend axios client was not configured to send cookies with requests. This meant the authentication cookie wasn't being included in API calls.

### 2. Nginx Not Forwarding Cookies
The nginx proxy (frontend container) was not properly forwarding cookies between:
- Client → Backend (missing `Cookie` header forwarding)
- Backend → Client (missing `Set-Cookie` header pass-through)

This caused the SPCS authentication cookie to be lost during the proxy chain.

## Solution

### Frontend Fix (`frontend/src/services/api.ts`)

Added `withCredentials: true` to the axios configuration:

```typescript
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // Enable sending cookies with cross-origin requests
})
```

### Backend CORS Fix (`backend/app/main.py`)

Enhanced CORS middleware to expose headers:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],  # Expose all headers including Set-Cookie
)
```

### Nginx Proxy Fix (`docker/nginx.conf`)

Added critical cookie forwarding directives:

```nginx
location /api/ {
    # ... existing config ...
    
    # CRITICAL: Forward cookies from client to backend
    proxy_set_header Cookie $http_cookie;
    
    # CRITICAL: Pass through Set-Cookie headers from backend to client
    proxy_pass_header Set-Cookie;
    
    # Disable buffering for real-time responses
    proxy_buffering off;
    
    # Increase timeouts for long-running requests
    proxy_read_timeout 300s;
    proxy_connect_timeout 75s;
}
```

## How SPCS Authentication Works

1. **User accesses SPCS public endpoint** → SPCS ingress redirects to Snowflake authentication
2. **User authenticates with Snowflake** → SPCS ingress sets `sfc-ss-ingress-auth-v1` cookie
3. **Browser sends requests with cookie** → Frontend (nginx) must forward cookie to backend
4. **Backend processes request** → Response goes back through nginx to client
5. **Cookie is maintained** → User stays authenticated

## Files Changed

1. `frontend/src/services/api.ts` - Added `withCredentials: true`
2. `backend/app/config.py` - Made CORS origins configurable
3. `backend/app/main.py` - Enhanced CORS middleware
4. `docker/nginx.conf` - Added cookie forwarding and pass-through

## Testing

After redeploying the service:

1. Access the SPCS public endpoint
2. Authenticate with Snowflake
3. Navigate through the UI and make API calls
4. Verify that you are **not** logged out randomly
5. Check browser DevTools → Network tab → Verify `Cookie` header is present in requests
6. Check response headers → Verify `Set-Cookie` is present when needed

## Deployment

To apply these fixes:

```bash
cd /Users/tboon/code/bordereau
./deployment/redeploy_backend.sh
```

Or full redeployment:

```bash
cd /Users/tboon/code/bordereau
./deployment/deploy.sh
```

## Additional Notes

- The `sfc-ss-ingress-auth-v1` cookie is managed by SPCS, not our application
- Our application must properly forward this cookie through the proxy chain
- The cookie has a limited lifetime and will eventually expire (requiring re-authentication)
- This is expected behavior and not a bug
- The fixes ensure the cookie is not prematurely lost during normal operation

## References

- [Snowpark Container Services Service Networking](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/service-network-communications)
- [SPCS Troubleshooting](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/troubleshooting)
- Logout endpoint: `/sfc-endpoint/logout` (provided by SPCS)
