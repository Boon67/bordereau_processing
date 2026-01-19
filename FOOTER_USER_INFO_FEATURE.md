# Footer with User Information Feature

**Created**: January 19, 2026  
**Status**: ✅ Complete and Ready

---

## Overview

A footer component has been added to the application that displays the currently logged-in Snowflake user, their active role, and the warehouse being used. This provides transparency and helps with auditing and troubleshooting.

---

## Features

### Information Displayed

1. **Username** - The logged-in Snowflake user (e.g., DEPLOY_USER)
2. **Role** - The current active role (e.g., SYSADMIN)
3. **Warehouse** - The active compute warehouse (e.g., COMPUTE_WH)
4. **Copyright Notice** - Application copyright information

### Visual Design

- **Icons**: Professional icons for each piece of information
  - 👤 UserOutlined for username
  - 🛡️ SafetyOutlined for role
  - ☁️ CloudServerOutlined for warehouse
- **Colors**: Distinct colors for each element
  - Blue for user
  - Green for role
  - Purple for warehouse
- **Layout**: Responsive flexbox layout that adapts to screen size
- **Styling**: Consistent with Ant Design theme

---

## Files Created/Modified

### New Files
```
backend/app/api/user.py
```

### Modified Files
```
backend/app/main.py
frontend/src/App.tsx
frontend/src/services/api.ts
```

---

## API Endpoint

### GET /api/user/current

Returns current Snowflake session information.

**Response:**
```json
{
  "username": "DEPLOY_USER",
  "role": "SYSADMIN",
  "warehouse": "COMPUTE_WH",
  "database": "BORDEREAU_PROCESSING_PIPELINE",
  "schema": "BRONZE",
  "account": "SFSENORTHAMERICA-TBOON-AWS2",
  "region": "AWS_US_WEST_2"
}
```

**Snowflake Functions Used:**
- `CURRENT_USER()` - Returns the logged-in username
- `CURRENT_ROLE()` - Returns the active role
- `CURRENT_WAREHOUSE()` - Returns the active warehouse
- `CURRENT_DATABASE()` - Returns the current database
- `CURRENT_SCHEMA()` - Returns the current schema
- `CURRENT_ACCOUNT()` - Returns the Snowflake account
- `CURRENT_REGION()` - Returns the Snowflake region

---

## Implementation Details

### Backend

**File**: `backend/app/api/user.py`

```python
@router.get("/current")
async def get_current_user():
    """Get current user information from Snowflake session"""
    sf_service = SnowflakeService()
    query = """
        SELECT 
            CURRENT_USER() as username,
            CURRENT_ROLE() as role,
            CURRENT_WAREHOUSE() as warehouse,
            CURRENT_DATABASE() as database,
            CURRENT_SCHEMA() as schema,
            CURRENT_ACCOUNT() as account,
            CURRENT_REGION() as region
    """
    result = sf_service.execute_query_dict(query)
    return result[0]
```

### Frontend

**File**: `frontend/src/App.tsx`

The footer is added at the bottom of the main layout:

```tsx
<Footer style={{ textAlign: 'center', background: '#f0f2f5', ... }}>
  <div style={{ display: 'flex', justifyContent: 'space-between', ... }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: '24px', ... }}>
      {userInfo && (
        <>
          <div>
            <UserOutlined /> User: {userInfo.username}
          </div>
          <div>
            <SafetyOutlined /> Role: {userInfo.role}
          </div>
          <div>
            <CloudServerOutlined /> Warehouse: {userInfo.warehouse}
          </div>
        </>
      )}
    </div>
    <div>Bordereau Processing Pipeline © 2026</div>
  </div>
</Footer>
```

---

## Behavior

### On Application Load

1. Frontend calls `/api/user/current` endpoint
2. Backend queries Snowflake session information
3. Response is stored in React state
4. Footer updates with user information

### Loading State

- While loading: "Loading user information..."
- After load: Displays actual user information
- On error: Continues showing loading message (non-critical)

### Error Handling

- Errors are logged to console
- No error message shown to user
- Application continues to function normally
- Footer gracefully handles missing data

---

## Responsive Design

### Desktop (> 768px)
```
┌─────────────────────────────────────────────────────────────┐
│ 👤 User: DEPLOY_USER  🛡️ Role: SYSADMIN  ☁️ Warehouse: COMPUTE_WH │
│                                                             │
│                Bordereau Processing Pipeline © 2026         │
└─────────────────────────────────────────────────────────────┘
```

### Tablet (< 768px)
```
┌─────────────────────────────────────────┐
│ 👤 User: DEPLOY_USER                    │
│ 🛡️ Role: SYSADMIN                       │
│ ☁️ Warehouse: COMPUTE_WH                │
│                                         │
│ Bordereau Processing Pipeline © 2026   │
└─────────────────────────────────────────┘
```

### Mobile (< 480px)
```
┌──────────────────────┐
│ 👤 User: DEPLOY_USER │
│ 🛡️ Role: SYSADMIN    │
│ ☁️ Warehouse:        │
│    COMPUTE_WH        │
│                      │
│ Bordereau Processing │
│ Pipeline © 2026      │
└──────────────────────┘
```

---

## Use Cases

### Security & Auditing
- **Verify Identity**: Confirm you're logged in as the correct user
- **Role Verification**: Ensure you're using the appropriate role
- **Warehouse Tracking**: Know which warehouse is being used for queries

### Troubleshooting
- **Connection Verification**: Confirm Snowflake connection is active
- **Permission Issues**: Check if role has necessary permissions
- **Resource Issues**: Verify warehouse availability

### Multi-User Environments
- **User Identification**: Clearly identify which user is logged in
- **Session Clarity**: Prevent confusion in shared environments
- **Action Attribution**: Track who performed actions

---

## Security Considerations

### Information Displayed
- ✅ **Username**: Not sensitive, visible in Snowflake UI
- ✅ **Role**: Not sensitive, user's active role
- ✅ **Warehouse**: Not sensitive, compute resource name

### Information NOT Displayed
- ❌ **Passwords**: Never exposed
- ❌ **Tokens**: Never exposed
- ❌ **Private Keys**: Never exposed
- ❌ **Connection Strings**: Never exposed

### Privacy
- Information is session-specific
- Only visible to the logged-in user
- No sensitive data is exposed
- No cross-user information leakage

---

## Testing

### Manual Testing Checklist

- [ ] Open application at http://localhost:3000
- [ ] Scroll to bottom of page
- [ ] Verify footer is visible
- [ ] Check username is displayed correctly
- [ ] Check role is displayed correctly
- [ ] Check warehouse is displayed correctly
- [ ] Verify icons are showing
- [ ] Test on desktop screen size
- [ ] Test on tablet screen size
- [ ] Test on mobile screen size
- [ ] Verify copyright notice is visible
- [ ] Check layout is responsive

### API Testing

```bash
# Test the API endpoint directly
curl http://localhost:8000/api/user/current

# Expected response:
{
  "username": "DEPLOY_USER",
  "role": "SYSADMIN",
  "warehouse": "COMPUTE_WH",
  "database": "BORDEREAU_PROCESSING_PIPELINE",
  "schema": "BRONZE",
  "account": "SFSENORTHAMERICA-TBOON-AWS2",
  "region": "AWS_US_WEST_2"
}
```

---

## Troubleshooting

### Footer Not Showing

**Problem**: Footer is not visible at the bottom of the page.

**Solutions**:
1. Check browser console for errors
2. Verify backend is running
3. Check API endpoint is accessible
4. Ensure Snowflake connection is working

### User Information Not Loading

**Problem**: Footer shows "Loading user information..." indefinitely.

**Solutions**:
1. Check browser console for API errors
2. Verify `/api/user/current` endpoint is responding
3. Check Snowflake connection
4. Verify user has permissions to query session information

### Incorrect Information Displayed

**Problem**: Username, role, or warehouse is incorrect.

**Solutions**:
1. Verify you're using the correct Snowflake connection
2. Check environment variables or configuration
3. Confirm the connection configuration in backend
4. Test Snowflake connection directly

---

## Future Enhancements

### Potential Improvements

1. **Database/Schema Display**
   - Add current database and schema to footer
   - Toggle to show/hide additional information

2. **Session Timeout Indicator**
   - Show session expiration time
   - Warning before session expires
   - Auto-refresh session

3. **User Profile Dropdown**
   - Click username to see full profile
   - Switch roles from footer
   - Switch warehouses from footer

4. **Connection Status**
   - Real-time connection status indicator
   - Green/yellow/red status light
   - Reconnect button if disconnected

5. **Performance Metrics**
   - Show warehouse credit usage
   - Display query count
   - Show data processed

---

## Technical Architecture

### Data Flow

```
┌──────────┐     GET /api/user/current     ┌──────────┐
│          │ ──────────────────────────────> │          │
│ Frontend │                                 │ Backend  │
│          │ <────────────────────────────── │          │
└──────────┘     User Info JSON             └──────────┘
                                                   │
                                                   │ SQL Query
                                                   │ CURRENT_USER()
                                                   │ CURRENT_ROLE()
                                                   │ etc.
                                                   ▼
                                             ┌──────────┐
                                             │          │
                                             │Snowflake │
                                             │          │
                                             └──────────┘
```

### Component Hierarchy

```
App
├── Layout
│   ├── Header
│   ├── Layout (nested)
│   │   ├── Sider (menu)
│   │   └── Layout (nested)
│   │       ├── Content (pages)
│   │       └── Footer ← User info displayed here
```

---

## Summary

The footer with user information provides:

✅ **Transparency** - Clear visibility of logged-in user  
✅ **Security** - Verify correct user and role  
✅ **Troubleshooting** - Quick access to session information  
✅ **Professional Design** - Clean, modern appearance  
✅ **Responsive Layout** - Works on all screen sizes  
✅ **Non-Intrusive** - Doesn't block critical functionality  

**Access**: http://localhost:3000

---

**Status**: ✅ Production Ready  
**Version**: 1.0  
**Last Updated**: January 19, 2026
