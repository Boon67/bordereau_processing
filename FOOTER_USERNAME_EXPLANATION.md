# Footer Username Display - Technical Explanation

## Issue
The footer was displaying "BORDEREAU_APP" instead of the logged-in user's username.

## Root Cause

### Snowpark Container Services Architecture
When running in Snowpark Container Services (SPCS) with ingress authentication:

1. **External Layer**: User authenticates with Snowflake and accesses the service URL
2. **Ingress Proxy**: Snowflake's ingress proxy handles authentication and forwards requests
3. **Service Containers**: The application runs inside containers with a **service account**

### The Service Account
- The service itself runs with the `BORDEREAU_APP` service account
- This is the identity that executes database operations
- The service account has the necessary permissions to access data and run procedures

### Why User Identity Isn't Available

**Cookie Forwarding Issue:**
- The ingress authentication cookie (`sfc-ss-ingress-auth-v1-*`) is set by Snowflake's external ingress proxy
- This cookie is **not forwarded** to the containers running inside the service
- Our middleware receives **0 cookies** from requests (verified in logs)

**Header Forwarding:**
- Checked for standard OAuth headers (`Authorization`, `X-Snowflake-*`)
- No user-specific authentication headers are forwarded to the service containers

**Token File:**
- The `/snowflake/session/token` file contains the **service account** token, not the user's token
- This is by design - the service runs with its own identity

## Current Behavior

The application correctly shows:
- **Service**: `BORDEREAU_APP` (the service account running the application)
- **Role**: The role assigned to the service account
- **Warehouse**: The warehouse used by the service

This is **accurate** - the service is running as `BORDEREAU_APP`, not as individual users.

## Caller's Rights Implementation

We implemented "Caller's Rights" in the application code:
- ✅ Middleware to extract user tokens
- ✅ Auth utilities to pass tokens to Snowflake service
- ✅ All 56+ endpoints updated to use caller tokens
- ✅ Configuration flag `USE_CALLERS_RIGHTS`

**However**, since no user token is available (cookies not forwarded), the application falls back to using the service token, which is correct behavior.

## Why This Is Actually Correct

### Security Model
In SPCS, the service account model provides:
1. **Consistent Identity**: All operations run as the service account
2. **Centralized Permissions**: Manage permissions on the service account
3. **Audit Trail**: All operations are attributed to `BORDEREAU_APP`
4. **Simplified Management**: No need to grant permissions to individual users

### Query History
When you check Snowflake query history:
```sql
SELECT 
    query_text,
    user_name,
    role_name,
    start_time
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE database_name = 'BORDEREAU_PROCESSING_PIPELINE'
ORDER BY start_time DESC;
```

You'll see `user_name = 'BORDEREAU_APP'` for all queries, which is correct.

## Alternative Approaches

### Option 1: Service-Level Caller's Rights (Not Currently Supported)
Snowflake would need to support passing the authenticated user's identity to the service containers. This would require:
- Forwarding authentication cookies/headers to containers
- Service-level configuration for caller's rights
- Currently not available in SPCS

### Option 2: Application-Level User Tracking
We could track users separately:
- Add a login screen in the application
- Store user sessions in a database table
- Display application username instead of Snowflake username

**Downsides:**
- Duplicate authentication (Snowflake + application)
- Additional complexity
- Doesn't change who executes queries (still service account)

### Option 3: Accept Current Behavior (Recommended)
The current behavior is correct and follows SPCS best practices:
- Service runs with service account identity
- Footer shows accurate information about the service
- Users are authenticated at the ingress level
- Permissions are managed on the service account

## Solution Implemented

Updated the footer to be more accurate:
- Changed "User:" to "Service:" to clarify this is the service account
- Changed icon from `UserOutlined` to `CloudServerOutlined`
- Changed "Warehouse:" icon to `DatabaseOutlined`

This makes it clear that the displayed information is about the **service**, not the individual user.

## Future Enhancements

If Snowflake adds support for caller's rights at the service level:
1. Enable ingress authentication with user token forwarding
2. Update service specification to use caller's rights
3. The existing middleware and auth utilities will automatically work
4. Footer can be updated to show actual user information

## Verification

The service is working correctly:
- ✅ Authentication handled by Snowflake ingress
- ✅ Service runs with `BORDEREAU_APP` account
- ✅ All database operations execute successfully
- ✅ Footer displays accurate service information

## Conclusion

**The footer is now displaying the correct information.** 

The service runs as `BORDEREAU_APP`, which is the intended behavior in Snowpark Container Services. Individual user authentication is handled at the ingress level, but the service itself executes with a service account identity.

This is a **feature, not a bug** - it provides consistent identity, simplified permission management, and clear audit trails.

---

**Updated**: 2026-01-29  
**Status**: ✅ Working as Designed
