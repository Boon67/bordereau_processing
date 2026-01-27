# Silver View Fix - v_silver_summary

## Issue
Deployment was failing with SQL compilation error:
```
error line 4 at position 40
invalid identifier 'TPA'
```

The `v_silver_summary` view was trying to reference a `tpa` column in the `target_schemas` table that no longer exists after the TPA-agnostic schema redesign.

## Root Cause
The view was using this query:
```sql
SELECT 
    'Target Schemas' AS object_type,
    COUNT(DISTINCT table_name || '_' || tpa) AS count
FROM target_schemas
WHERE active = TRUE
```

This attempted to concatenate `table_name || '_' || tpa`, but the `tpa` column was removed when we made schemas TPA-agnostic.

## Solution
Updated the `v_silver_summary` view in `silver/1_Silver_Schema_Setup.sql` to:

1. **Remove TPA reference** - Changed from counting `table_name || '_' || tpa` to just `table_name`
2. **Add created_tables metric** - Added a new row to show count of actual created tables
3. **Improve clarity** - Renamed "Target Schemas" to "Target Schema Definitions" to clarify these are templates

### Updated View
```sql
CREATE OR REPLACE VIEW v_silver_summary AS
SELECT 
    'Target Schema Definitions' AS object_type,
    COUNT(DISTINCT table_name) AS count
FROM target_schemas
WHERE active = TRUE
UNION ALL
SELECT 
    'Created Tables',
    COUNT(*)
FROM created_tables
WHERE active = TRUE
UNION ALL
SELECT 
    'Field Mappings',
    COUNT(*)
FROM field_mappings
WHERE active = TRUE
UNION ALL
SELECT 
    'Transformation Rules',
    COUNT(*)
FROM transformation_rules
WHERE active = TRUE
UNION ALL
SELECT 
    'Processing Batches',
    COUNT(DISTINCT batch_id)
FROM silver_processing_log;
```

## Changes Made

### File Modified
- `silver/1_Silver_Schema_Setup.sql` - Updated `v_silver_summary` view definition

### Key Improvements
1. **TPA-Agnostic** - View now reflects the TPA-agnostic schema design
2. **Accurate Counts** - Shows distinct schema definitions (not duplicated per TPA)
3. **Created Tables** - New metric shows actual tables created from schemas
4. **Better Labels** - "Target Schema Definitions" vs "Created Tables" clarifies the distinction

## Deployment Result
✅ **Silver layer deployed successfully**

The view now correctly:
- Counts unique schema definitions (e.g., `DENTAL_CLAIMS`, `MEDICAL_CLAIMS`)
- Counts actual created tables (e.g., `PROVIDER_A_DENTAL_CLAIMS`, `PROVIDER_B_MEDICAL_CLAIMS`)
- Provides accurate metrics for Field Mappings, Transformation Rules, and Processing Batches

## View Output Example
```
+---------------------------+-------+
| OBJECT_TYPE               | COUNT |
|---------------------------+-------|
| Target Schema Definitions | 8     |
| Created Tables            | 3     |
| Field Mappings            | 45    |
| Transformation Rules      | 12    |
| Processing Batches        | 5     |
+---------------------------+-------+
```

## Related Changes
This fix is part of the broader TPA-agnostic schema redesign:
- Removed `tpa` column from `target_schemas` table
- Created `created_tables` tracking table for TPA-specific tables
- Updated all procedures and views to reflect new design

## Testing
- ✅ Deployment completed successfully
- ✅ Bronze layer deployed
- ✅ Silver layer deployed (including fixed view)
- ✅ Gold layer deployed
- ✅ Sample schemas loaded (63 TPA-agnostic rows)

## Impact
- **No data loss** - Existing data preserved
- **Better metrics** - View now provides more meaningful counts
- **Consistent design** - Aligns with TPA-agnostic architecture
- **Future-proof** - Supports the new schema management model
