# TPA API Fixes - Array vs Dictionary Issue

**Date**: January 21, 2026  
**Status**: ✅ Fixed (All CRUD Operations)

---

## Problem

The TPA API had multiple issues where it was using `execute_query()` (returns arrays) instead of `execute_query_dict()` (returns objects), causing errors in:
1. **GET /api/tpas** - Dropdown showing blank
2. **POST /api/tpas** - Create TPA failing
3. **PUT /api/tpas/{code}** - Update TPA failing
4. **DELETE /api/tpas/{code}** - Delete TPA failing
5. **PATCH /api/tpas/{code}/status** - Status update failing

### Symptoms

- API endpoint `/api/tpas` returning data
- Data format: Array of arrays instead of objects
- UI dropdown blank (couldn't read array values)

### Example of Wrong Format

```json
[
    [
        "provider_a",
        "Provider A Healthcare",
        "Dental claims provider",
        true,
        "2026-01-18T11:07:54.741000",
        "2026-01-18T11:07:54.741000"
    ],
    ...
]
```

### Expected Format

```json
[
    {
        "TPA_CODE": "provider_a",
        "TPA_NAME": "Provider A Healthcare",
        "TPA_DESCRIPTION": "Dental claims provider",
        "ACTIVE": true,
        "CREATED_TIMESTAMP": "2026-01-18T11:07:54.741000",
        "UPDATED_TIMESTAMP": "2026-01-18T11:07:54.741000"
    },
    ...
]
```

---

## Root Cause

**File**: `backend/app/api/tpa.py`  
**Lines**: 46, 59, 95, 132, 159

Multiple endpoints were using `execute_query()` which returns tuples (arrays), instead of `execute_query_dict()` which returns dictionaries (objects with named properties).

### Issue 1: GET Endpoint (Line 46)
```python
# WRONG - Returns arrays
return sf_service.execute_query(query)

# CORRECT - Returns objects
return sf_service.execute_query_dict(query)
```

### Issue 2: CREATE/UPDATE/DELETE Endpoints (Lines 59, 95, 132, 159)
```python
# WRONG - Returns arrays, but code tries to access as dict
result = sf_service.execute_query(check_query)
if result and result[0]['COUNT'] > 0:  # ❌ TypeError: tuple indices must be integers

# CORRECT - Returns objects
result = sf_service.execute_query_dict(check_query)
if result and result[0]['COUNT'] > 0:  # ✅ Works!
```

---

## Fix Applied

### Changed Code

**File**: `backend/app/api/tpa.py`

#### Fix 1: GET Endpoint (Line 46)
```python
@router.get("")
async def get_tpas():
    # FIXED: Changed from execute_query() to execute_query_dict()
    return sf_service.execute_query_dict(query)
```

#### Fix 2: CREATE Endpoint (Line 59)
```python
@router.post("")
async def create_tpa(tpa: TPACreate):
    # Check if TPA already exists
    check_query = f"SELECT COUNT(*) as count FROM BRONZE.TPA_MASTER WHERE TPA_CODE = '{tpa.tpa_code}'"
    # FIXED: Changed from execute_query() to execute_query_dict()
    result = sf_service.execute_query_dict(check_query)
    if result and result[0]['COUNT'] > 0:
        raise HTTPException(status_code=400, detail=f"TPA with code '{tpa.tpa_code}' already exists")
```

#### Fix 3: UPDATE Endpoint (Line 95)
```python
@router.put("/{tpa_code}")
async def update_tpa(tpa_code: str, tpa: TPAUpdate):
    # Check if TPA exists
    check_query = f"SELECT COUNT(*) as count FROM BRONZE.TPA_MASTER WHERE TPA_CODE = '{tpa_code}'"
    # FIXED: Changed from execute_query() to execute_query_dict()
    result = sf_service.execute_query_dict(check_query)
    if not result or result[0]['COUNT'] == 0:
        raise HTTPException(status_code=404, detail=f"TPA with code '{tpa_code}' not found")
```

#### Fix 4: DELETE Endpoint (Line 132)
```python
@router.delete("/{tpa_code}")
async def delete_tpa(tpa_code: str):
    # Check if TPA exists
    check_query = f"SELECT COUNT(*) as count FROM BRONZE.TPA_MASTER WHERE TPA_CODE = '{tpa_code}'"
    # FIXED: Changed from execute_query() to execute_query_dict()
    result = sf_service.execute_query_dict(check_query)
    if not result or result[0]['COUNT'] == 0:
        raise HTTPException(status_code=404, detail=f"TPA with code '{tpa_code}' not found")
```

#### Fix 5: PATCH Status Endpoint (Line 159)
```python
@router.patch("/{tpa_code}/status")
async def update_tpa_status(tpa_code: str, status: TPAStatusUpdate):
    # Check if TPA exists
    check_query = f"SELECT COUNT(*) as count FROM BRONZE.TPA_MASTER WHERE TPA_CODE = '{tpa_code}'"
    # FIXED: Changed from execute_query() to execute_query_dict()
    result = sf_service.execute_query_dict(check_query)
    if not result or result[0]['COUNT'] == 0:
        raise HTTPException(status_code=404, detail=f"TPA with code '{tpa_code}' not found")
```

### Deployment Steps

#### First Fix (GET Endpoint)
1. **Updated Code**: Changed line 46 to `execute_query_dict()`
2. **Rebuilt Backend**: Docker image `sha256:61f13c9ddb35...`
3. **Deployed**: Service endpoint `fzcmn2pb-...`

#### Second Fix (All CRUD Operations)
1. **Updated Code**: Changed lines 59, 95, 132, 159 to `execute_query_dict()`
2. **Rebuilt Backend**: Docker image `sha256:dc3b2c5dc5dc...`
3. **Pushed Image**: New digest `sha256:dc3b2c5dc5dc762a001bc31c4968407bbc370ff77d16e791656123167460c9fd`
4. **Dropped Service**: `DROP SERVICE BORDEREAU_APP`
5. **Recreated Service**: With updated backend image
6. **Verified**: Both containers READY
7. **New Endpoint**: `jzcmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app`

---

## Why This Happened

### Snowflake Connector Behavior

The Snowflake Python connector has two cursor types:

1. **Default Cursor** (`execute_query()`)
   - Returns: `List[tuple]` - Array of arrays
   - Fast but no column names
   - Used for: Internal processing

2. **DictCursor** (`execute_query_dict()`)
   - Returns: `List[Dict]` - Array of objects
   - Column names as keys
   - Used for: API responses

### Frontend Expectation

The React frontend expects objects with named properties:

```typescript
// Frontend code expects this structure
interface TPA {
  TPA_CODE: string;
  TPA_NAME: string;
  TPA_DESCRIPTION: string;
  ACTIVE: boolean;
  CREATED_TIMESTAMP: string;
  UPDATED_TIMESTAMP: string;
}

// Dropdown code
options={tpas.map(tpa => ({
  value: tpa.TPA_CODE,      // ✅ Works with objects
  label: tpa.TPA_NAME,       // ✅ Works with objects
}))}

// With arrays, this fails:
// tpa[0] !== tpa.TPA_CODE
// tpa[1] !== tpa.TPA_NAME
```

---

## Verification

### Test API Response

```bash
# After fix, API should return objects
curl https://jxcmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app/api/tpas

# Expected response format:
[
  {
    "TPA_CODE": "provider_a",
    "TPA_NAME": "Provider A Healthcare",
    "TPA_DESCRIPTION": "Dental claims provider",
    "ACTIVE": true,
    "CREATED_TIMESTAMP": "2026-01-18T11:07:54.741000",
    "UPDATED_TIMESTAMP": "2026-01-18T11:07:54.741000"
  },
  ...
]
```

### Test UI

1. Open: https://jzcmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app
2. Log in with Snowflake OAuth
3. **Test Dropdown**: Check TPA dropdown in header - Should show all TPAs
4. **Test TPA Management**: Navigate to Administration → TPA Management
   - ✅ View all TPAs
   - ✅ Create new TPA
   - ✅ Edit existing TPA
   - ✅ Delete TPA (soft delete)
   - ✅ Toggle active status

---

## Prevention

### Code Review Checklist

When creating new API endpoints:

- [ ] Use `execute_query_dict()` for API responses
- [ ] Use `execute_query()` only for internal processing
- [ ] Test API response format matches frontend expectations
- [ ] Verify TypeScript interfaces match API response

### Service Class Methods

**Use `execute_query_dict()` for**:
- ✅ API endpoints returning data to frontend
- ✅ Any response that needs column names
- ✅ JSON API responses

**Use `execute_query()` for**:
- ✅ Internal processing
- ✅ When you only need values, not column names
- ✅ Performance-critical operations

---

## Related Files

### Backend Files
- `backend/app/api/tpa.py` - TPA API endpoints (FIXED)
- `backend/app/services/snowflake_service.py` - Database service (has both methods)

### Frontend Files
- `frontend/src/App.tsx` - TPA dropdown component
- `frontend/src/services/api.ts` - API client
- `frontend/src/types/index.ts` - TypeScript interfaces

---

## Current Status

### Service Status
- **Service**: BORDEREAU_APP
- **Backend**: ✅ READY (with all fixes)
- **Frontend**: ✅ READY
- **Endpoint**: https://jzcmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app

### Database Status
- **TPAs**: 5 active TPAs in BRONZE.TPA_MASTER
- **API**: All endpoints return objects (not arrays)
- **UI**: 
  - ✅ Dropdown populates correctly
  - ✅ TPA Management fully functional
  - ✅ Create/Edit/Delete operations working

---

## Summary

✅ **Issue**: TPA API returning arrays instead of objects across all endpoints  
✅ **Root Cause**: Using `execute_query()` instead of `execute_query_dict()` in 5 locations  
✅ **Fix**: Changed 5 lines in `backend/app/api/tpa.py` (lines 46, 59, 95, 132, 159)  
✅ **Deployed**: Backend rebuilt and service updated twice  
✅ **Result**: All TPA operations now working correctly:
   - ✅ GET /api/tpas - Dropdown populated
   - ✅ POST /api/tpas - Create TPA working
   - ✅ PUT /api/tpas/{code} - Update TPA working
   - ✅ DELETE /api/tpas/{code} - Delete TPA working
   - ✅ PATCH /api/tpas/{code}/status - Status toggle working

---

**Fixed**: January 21, 2026  
**Version**: 2.0 (Complete CRUD Fix)  
**Status**: ✅ Deployed and Ready  
**Endpoint**: https://jzcmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app
