# Silver Layer Metadata Columns

## Overview
All Silver layer tables automatically include metadata columns that provide traceability, audit trails, and data lineage back to the Bronze layer.

## Metadata Columns

### Source Traceability Columns
These columns link Silver records back to their source in Bronze:

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `_RECORD_ID` | NUMBER(38,0) NOT NULL UNIQUE | Unique identifier from Bronze RAW_DATA_TABLE.RECORD_ID. Used as the merge key to prevent duplicates. |
| `_FILE_NAME` | VARCHAR(500) | Source file name from Bronze (e.g., "claims_2024_01.csv"). Enables tracing back to the original file. |
| `_FILE_ROW_NUMBER` | NUMBER(38,0) | Row number in the source file from Bronze. Combined with FILE_NAME, provides exact location in source. |

### Processing Metadata Columns
These columns track when and how the data was processed:

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `_TPA` | VARCHAR(100) | Third Party Administrator code (e.g., "provider_a"). Defaults to the TPA for which the table was created. |
| `_BATCH_ID` | VARCHAR(100) | Batch identifier for the transformation run (e.g., "BATCH_20240131_143052_a1b2c3d4"). Updated on each transformation. |
| `_LOAD_TIMESTAMP` | TIMESTAMP_NTZ | Timestamp when the record was loaded or last updated. Updated on each transformation. |
| `_LOADED_BY` | VARCHAR(500) | Snowflake user who executed the transformation. Updated on each transformation. |

## Total Metadata Columns
**7 metadata columns** are automatically added to every Silver table in addition to the business columns defined in the schema.

## Usage Examples

### 1. Trace a Record Back to Source File
```sql
SELECT 
    claim_id,
    member_id,
    _FILE_NAME,
    _FILE_ROW_NUMBER,
    _LOAD_TIMESTAMP
FROM PROVIDER_A_CLAIMS
WHERE claim_id = '12345';
```

**Result:**
```
CLAIM_ID | MEMBER_ID | _FILE_NAME              | _FILE_ROW_NUMBER | _LOAD_TIMESTAMP
---------|-----------|-------------------------|------------------|------------------
12345    | M001      | claims_2024_01.csv      | 42               | 2024-01-31 14:30:52
```

### 2. Find All Records from a Specific File
```sql
SELECT 
    COUNT(*) as record_count,
    MIN(_FILE_ROW_NUMBER) as first_row,
    MAX(_FILE_ROW_NUMBER) as last_row
FROM PROVIDER_A_CLAIMS
WHERE _FILE_NAME = 'claims_2024_01.csv';
```

### 3. Audit Recent Transformations
```sql
SELECT 
    _BATCH_ID,
    _LOADED_BY,
    _LOAD_TIMESTAMP,
    COUNT(*) as records_affected
FROM PROVIDER_A_CLAIMS
WHERE _LOAD_TIMESTAMP > DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY _BATCH_ID, _LOADED_BY, _LOAD_TIMESTAMP
ORDER BY _LOAD_TIMESTAMP DESC;
```

### 4. Complete Data Lineage (Bronze → Silver)
```sql
SELECT 
    -- Silver columns
    s.claim_id,
    s.member_id,
    s._RECORD_ID,
    s._FILE_NAME,
    s._FILE_ROW_NUMBER,
    s._LOAD_TIMESTAMP,
    -- Bronze columns
    b.RECORD_ID,
    b.FILE_NAME,
    b.FILE_ROW_NUMBER,
    b.LOAD_TIMESTAMP as bronze_load_timestamp,
    b.RAW_DATA
FROM PROVIDER_A_CLAIMS s
JOIN BRONZE.RAW_DATA_TABLE b 
    ON s._RECORD_ID = b.RECORD_ID
WHERE s.claim_id = '12345';
```

### 5. Identify Records Processed in Latest Batch
```sql
SELECT *
FROM PROVIDER_A_CLAIMS
WHERE _BATCH_ID = (
    SELECT MAX(_BATCH_ID) 
    FROM PROVIDER_A_CLAIMS
);
```

### 6. Find Duplicate Source Rows (Data Quality Check)
```sql
-- Should return 0 rows due to UNIQUE constraint on _RECORD_ID
SELECT 
    _FILE_NAME,
    _FILE_ROW_NUMBER,
    COUNT(*) as duplicate_count
FROM PROVIDER_A_CLAIMS
GROUP BY _FILE_NAME, _FILE_ROW_NUMBER
HAVING COUNT(*) > 1;
```

## Benefits

1. **Full Traceability**: Every Silver record can be traced back to its exact source file and row number
2. **Audit Compliance**: Complete audit trail of who processed data and when
3. **Data Quality**: Easy to identify and investigate data issues by tracing back to source
4. **Idempotent Processing**: The `_RECORD_ID` ensures no duplicates when re-running transformations
5. **Debugging**: When issues arise, you can quickly find the source file and row to investigate
6. **Data Lineage**: Clear lineage from Bronze → Silver for regulatory and compliance requirements

## Technical Details

### Merge Key
The `_RECORD_ID` column serves as the merge key in the `MERGE` statement:
```sql
ON target._RECORD_ID = source._RECORD_ID
```

This ensures that:
- Running the same transformation multiple times updates existing records instead of creating duplicates
- Each Bronze record maps to exactly one Silver record
- The transformation is idempotent and safe to re-run

### Updates on Re-processing
When a transformation is re-run, the following metadata columns are updated:
- `_BATCH_ID` - Updated to the new batch ID
- `_LOAD_TIMESTAMP` - Updated to current timestamp
- `_LOADED_BY` - Updated to current user

The following columns remain unchanged (preserving source lineage):
- `_RECORD_ID` - Never changes (it's the merge key)
- `_FILE_NAME` - Never changes (source file doesn't change)
- `_FILE_ROW_NUMBER` - Never changes (source row doesn't change)
- `_TPA` - Never changes (TPA doesn't change)

## Schema Definition

When creating a Silver table via `create_silver_table()`, the metadata columns are automatically appended:

```python
# Business columns from target_schemas
column_defs = [...]  # Based on schema definition

# Metadata columns (automatically added)
column_defs.append("_RECORD_ID NUMBER(38,0) NOT NULL UNIQUE")
column_defs.append("_FILE_NAME VARCHAR(500)")
column_defs.append("_FILE_ROW_NUMBER NUMBER(38,0)")
column_defs.append("_TPA VARCHAR(100) DEFAULT '{tpa}'")
column_defs.append("_BATCH_ID VARCHAR(100)")
column_defs.append("_LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()")
column_defs.append("_LOADED_BY VARCHAR(500) DEFAULT CURRENT_USER()")
```

## Related Documentation
- `MERGE_TRANSFORMATION_UPDATE.md` - Details on the MERGE transformation logic
- `bronze/2_Bronze_Schema_Tables.sql` - Source of RECORD_ID, FILE_NAME, FILE_ROW_NUMBER
- `silver/2_Silver_Target_Schemas.sql` - Table creation with metadata columns
- `silver/5_Silver_Transformation_Logic.sql` - MERGE transformation that populates metadata
