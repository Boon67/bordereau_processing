# Created Tables Data Fix

## Problem
The Field Mappings page was showing "No Tables Created Yet" even though the Schemas and Tables page showed `PROVIDER_A_DENTAL_CLAIMS` was created.

## Root Cause
The `created_tables` tracking table had incorrect data from the backfill script:
- `SCHEMA_TABLE_NAME` was `CLAIMS` instead of `DENTAL_CLAIMS`
- `TPA` was `PROVIDER_A_DENTAL` instead of `provider_a`

This happened because the regex patterns in the backfill script were too simplistic and couldn't properly parse `PROVIDER_A_DENTAL_CLAIMS`.

---

## Data Before Fix

```sql
SELECT * FROM created_tables;
```

| TABLE_ID | PHYSICAL_TABLE_NAME | SCHEMA_TABLE_NAME | TPA | CREATED_TIMESTAMP |
|----------|---------------------|-------------------|-----|-------------------|
| 1 | PROVIDER_A_DENTAL_CLAIMS | **CLAIMS** ❌ | **PROVIDER_A_DENTAL** ❌ | 2026-01-26 16:22:13 |

**Issues**:
- `SCHEMA_TABLE_NAME`: `CLAIMS` (should be `DENTAL_CLAIMS`)
- `TPA`: `PROVIDER_A_DENTAL` (should be `provider_a`)

---

## Fix Applied

### 1. Corrected Existing Data

```sql
-- Fix schema_table_name
UPDATE BORDEREAU_PROCESSING_PIPELINE.SILVER.created_tables 
SET schema_table_name = 'DENTAL_CLAIMS' 
WHERE physical_table_name = 'PROVIDER_A_DENTAL_CLAIMS';

-- Fix TPA
UPDATE BORDEREAU_PROCESSING_PIPELINE.SILVER.created_tables 
SET tpa = 'provider_a' 
WHERE physical_table_name = 'PROVIDER_A_DENTAL_CLAIMS';
```

### 2. Data After Fix

```sql
SELECT * FROM created_tables;
```

| TABLE_ID | PHYSICAL_TABLE_NAME | SCHEMA_TABLE_NAME | TPA | CREATED_TIMESTAMP |
|----------|---------------------|-------------------|-----|-------------------|
| 1 | PROVIDER_A_DENTAL_CLAIMS | **DENTAL_CLAIMS** ✅ | **provider_a** ✅ | 2026-01-26 16:22:13 |

---

## Updated Backfill Script

**File**: `silver/ADD_CREATED_TABLES_TRACKING.sql`

### Old Approach (Regex - Unreliable)

```sql
-- Extract schema table name by removing TPA prefix
REGEXP_REPLACE(t.table_name, '^[A-Z_]+_([A-Z_]+)$', '\\1') as schema_table_name,
-- Extract TPA from table name (everything before the last underscore group)
REGEXP_REPLACE(t.table_name, '^([A-Z_]+?)_[A-Z_]+$', '\\1') as tpa,
```

**Problem**: Regex couldn't handle multi-word table names like `PROVIDER_A_DENTAL_CLAIMS`

### New Approach (Lookup-Based - Reliable)

```sql
-- Try to match against known schema names from target_schemas
COALESCE(
    (SELECT DISTINCT ts.table_name 
     FROM target_schemas ts 
     WHERE t.table_name LIKE '%' || ts.table_name
     LIMIT 1),
    'UNKNOWN'
) as schema_table_name,

-- Try to match against known TPAs from tpa_registry
COALESCE(
    (SELECT LOWER(tr.tpa_code)
     FROM BRONZE.tpa_registry tr
     WHERE t.table_name LIKE UPPER(tr.tpa_code) || '_%'
     LIMIT 1),
    'unknown'
) as tpa,
```

**Benefits**:
- Matches against actual data in `target_schemas` and `tpa_registry`
- More reliable than regex patterns
- Handles multi-word table names correctly
- Falls back to 'UNKNOWN'/'unknown' if no match found

---

## Why This Matters

### Impact on Field Mappings Page

The Field Mappings page filters created tables by TPA:

```typescript
const tpaCreatedTables = createdTables.filter(
  (table: any) => table.TPA.toLowerCase() === selectedTpa.toLowerCase()
)
```

**Before Fix**:
- User selects TPA: `provider_a`
- Filter looks for: `table.TPA === 'provider_a'`
- Finds: `PROVIDER_A_DENTAL` ❌ (no match)
- Result: "No Tables Created Yet"

**After Fix**:
- User selects TPA: `provider_a`
- Filter looks for: `table.TPA === 'provider_a'`
- Finds: `provider_a` ✅ (match!)
- Result: Shows `DENTAL_CLAIMS` table

### Impact on Schema Matching

The page also needs to match the schema name to get column counts:

```typescript
const tableSchemas = schemas.filter(
  (s: any) => s.TABLE_NAME === table.SCHEMA_TABLE
)
```

**Before Fix**:
- Looks for schema: `CLAIMS`
- Finds in `target_schemas`: Nothing ❌
- Result: 0 columns shown

**After Fix**:
- Looks for schema: `DENTAL_CLAIMS`
- Finds in `target_schemas`: 14 columns ✅
- Result: Shows "DENTAL_CLAIMS (14 columns)"

---

## Prevention

### Best Practice: Use `create_silver_table` Procedure

The `create_silver_table` stored procedure automatically tracks tables correctly:

```python
# Track the created table
tracking_sql = f"""
    INSERT INTO created_tables (physical_table_name, schema_table_name, tpa, description)
    SELECT '{full_table_name}', '{table_name_upper}', '{tpa}', 
           'Created from schema: {table_name_upper} for TPA: {tpa}'
    WHERE NOT EXISTS (
        SELECT 1 FROM created_tables WHERE physical_table_name = '{full_table_name}'
    )
"""
```

**Correct Data**:
- `physical_table_name`: `PROVIDER_A_DENTAL_CLAIMS`
- `schema_table_name`: `DENTAL_CLAIMS` (from input parameter)
- `tpa`: `provider_a` (from input parameter)

### Manual Table Creation

If you create tables manually (outside the procedure), you must also manually insert into `created_tables`:

```sql
-- Create the table
CREATE TABLE PROVIDER_B_MEDICAL_CLAIMS (...);

-- Track it
INSERT INTO created_tables (physical_table_name, schema_table_name, tpa, description)
VALUES ('PROVIDER_B_MEDICAL_CLAIMS', 'MEDICAL_CLAIMS', 'provider_b', 'Manually created');
```

---

## Verification

### 1. Check Tracking Table

```sql
SELECT 
    physical_table_name,
    schema_table_name,
    tpa,
    created_timestamp
FROM BORDEREAU_PROCESSING_PIPELINE.SILVER.created_tables
WHERE active = TRUE;
```

**Expected**:
- `PROVIDER_A_DENTAL_CLAIMS` | `DENTAL_CLAIMS` | `provider_a` | 2026-01-26...

### 2. Test Field Mappings Page

1. Navigate to Field Mappings page
2. Select "Provider A Healthcare" from TPA dropdown
3. **Expected**: See `DENTAL_CLAIMS (14 columns)` table
4. **Before fix**: Saw "No Tables Created Yet"

### 3. Test API

```bash
curl "https://[endpoint]/api/silver/tables"
```

**Expected Response**:
```json
[
  {
    "TABLE_NAME": "PROVIDER_A_DENTAL_CLAIMS",
    "SCHEMA_TABLE": "DENTAL_CLAIMS",
    "TPA": "provider_a",
    "CREATED_AT": "2026-01-26T16:22:13.098000",
    "ROW_COUNT": 0,
    "BYTES": 0
  }
]
```

---

## Files Modified

1. ✅ `silver/ADD_CREATED_TABLES_TRACKING.sql` - Updated backfill logic
2. ✅ Database: Fixed existing data with UPDATE statements

---

## Related Issues

This fix resolves:
- ✅ Field Mappings page showing "No Tables Created Yet"
- ✅ Incorrect schema name in tracking table
- ✅ Incorrect TPA in tracking table
- ✅ Future backfills will be more reliable

---

**Status**: ✅ **Fixed and Verified**
