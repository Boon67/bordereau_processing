# Transformation Validation Fix

## Issue Summary

The Bronze-to-Silver transformation was failing silently with no error messages shown to the user. The transformation API would return a 200 OK status but with an empty result.

### Root Cause

1. **Invalid Field Mappings**: Field mappings contained a mapping to a column (`SERVICE_DATE`) that did not exist in the physical Silver table
2. **Duplicate Mappings**: The same source column was mapped to multiple target columns, with one being invalid
3. **Silent Failures**: The Snowflake stored procedure was catching exceptions and logging them to `SILVER_PROCESSING_LOG`, but returning `None` to the backend
4. **No Pre-validation**: There was no validation of mappings before attempting transformation

### Error Details

```
SQL compilation error: error line 1 at position 38
invalid identifier 'SERVICE_DATE'
```

The transformation procedure was trying to INSERT into a column that didn't exist in the `PROVIDER_A_DENTAL_CLAIMS` table.

## Solution Implemented

### 1. Mapping Creation Validation

Added comprehensive validation to the `POST /api/silver/mappings` endpoint:

**Validation 1: Duplicate Check**
- Prevents creating multiple mappings to the same target column for a TPA/table combination
- Returns HTTP 400 with clear error message if duplicate exists

**Validation 2: Column Existence Check**
- Validates that the target column actually exists in the physical Silver table
- Queries `INFORMATION_SCHEMA.COLUMNS` to verify column presence
- Returns HTTP 400 if column doesn't exist, with instructions to add it to the target schema first

### 2. New Validation Endpoint

Created `GET /api/silver/mappings/validate` endpoint that:
- Checks all approved mappings for a TPA/table combination
- Validates each mapped column exists in the physical table
- Detects duplicate target column mappings
- Returns detailed validation report with:
  - `valid`: boolean indicating if all mappings are valid
  - `errors`: array of invalid mappings with details
  - `warnings`: array of potential issues (e.g., duplicate targets)
  - `total_mappings`: count of mappings checked
  - `physical_table`: name of the table validated against

**Example Response:**
```json
{
  "valid": false,
  "message": "Found 1 invalid mapping(s)",
  "errors": [
    {
      "mapping_id": 123,
      "source_field": "SERVICE_DATE",
      "target_column": "SERVICE_DATE",
      "error": "Target column 'SERVICE_DATE' does not exist in table 'PROVIDER_A_DENTAL_CLAIMS'"
    }
  ],
  "warnings": [],
  "total_mappings": 8,
  "physical_table": "PROVIDER_A_DENTAL_CLAIMS"
}
```

### 3. Pre-Transformation Validation

Enhanced `POST /api/silver/transform` endpoint with automatic pre-validation:

**Before Transformation:**
1. Checks that approved mappings exist for the TPA/table
2. Validates the physical table exists
3. Verifies all mapped columns exist in the physical table
4. Returns HTTP 400 with clear error message if validation fails

**Benefits:**
- Fails fast with actionable error messages
- Prevents wasted compute on transformations that will fail
- Guides users to fix mapping issues before running transformation

### 4. Immediate Fix Applied

Manually deleted the invalid `SERVICE_DATE` mapping:
```sql
DELETE FROM SILVER.FIELD_MAPPINGS 
WHERE target_table = 'DENTAL_CLAIMS' 
  AND tpa = 'provider_a' 
  AND target_column = 'SERVICE_DATE'
```

## Files Modified

1. **`backend/app/api/silver.py`**
   - Enhanced `create_field_mapping()` with duplicate and column existence validation
   - Added `validate_field_mappings()` endpoint for manual validation
   - Enhanced `transform_bronze_to_silver()` with automatic pre-validation

## Testing

### Test Case 1: Create Duplicate Mapping
```bash
POST /api/silver/mappings
{
  "source_field": "CLAIM_NUM",
  "target_table": "DENTAL_CLAIMS",
  "target_column": "CLAIM_ID",  # Already mapped
  "tpa": "provider_a"
}

# Expected: HTTP 400
# "Mapping already exists for target column 'CLAIM_ID'..."
```

### Test Case 2: Map to Non-Existent Column
```bash
POST /api/silver/mappings
{
  "source_field": "SERVICE_DATE",
  "target_table": "DENTAL_CLAIMS",
  "target_column": "SERVICE_DATE",  # Doesn't exist in table
  "tpa": "provider_a"
}

# Expected: HTTP 400
# "Target column 'SERVICE_DATE' does not exist in table 'PROVIDER_A_DENTAL_CLAIMS'..."
```

### Test Case 3: Validate Mappings
```bash
GET /api/silver/mappings/validate?tpa=provider_a&target_table=DENTAL_CLAIMS

# Expected: Validation report with any errors/warnings
```

### Test Case 4: Transform with Invalid Mappings
```bash
POST /api/silver/transform
{
  "source_table": "RAW_DATA_TABLE",
  "target_table": "DENTAL_CLAIMS",
  "tpa": "provider_a",
  ...
}

# Expected: HTTP 400 if mappings are invalid
# "Invalid mappings detected: columns SERVICE_DATE do not exist..."
```

## Benefits

1. **Better User Experience**: Clear, actionable error messages instead of silent failures
2. **Data Integrity**: Prevents invalid mappings from being created
3. **Faster Debugging**: Validation errors appear immediately, not after transformation starts
4. **Reduced Compute Waste**: Transformations don't run if they're guaranteed to fail
5. **Proactive Validation**: Users can validate mappings before attempting transformation

## Recommendations

### For Users

1. **Before Creating Mappings**: Ensure target columns exist in the target schema
2. **After Creating Mappings**: Use the validation endpoint to check for issues
3. **Before Transforming**: The system will automatically validate, but you can manually validate first
4. **If Transformation Fails**: Check `SILVER.SILVER_PROCESSING_LOG` for detailed error messages

### For Future Enhancements

1. **Frontend Integration**: Add a "Validate Mappings" button in the UI
2. **Auto-Fix Suggestions**: Suggest which columns to add to the schema
3. **Mapping Templates**: Pre-validate mapping templates before applying
4. **Schema Sync**: Automatically sync target schema changes to physical tables
5. **Bulk Validation**: Validate all TPAs/tables at once

## Related Issues

- Transformation returning empty results
- "Record count could not be determined" messages
- Silent transformation failures
- Invalid identifier SQL errors

## Deployment

**Status**: ✅ Deployed
- Backend image rebuilt with validation features
- Tagged as `validation` in Snowflake registry
- Service restarted and verified READY

**Image**: `sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/bordereau_processing_pipeline/public/bordereau_repository/bordereau_backend:validation`

**Deployment Time**: 2026-01-31 21:37 UTC

## Next Steps

1. Test transformation with valid mappings only
2. Monitor `SILVER_PROCESSING_LOG` for successful transformations
3. Consider adding frontend validation UI
4. Document mapping best practices for users
