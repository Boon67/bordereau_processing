# Silver Layer MERGE Transformation Update

## Overview
Updated the Silver layer transformation logic to use `MERGE` statements instead of `INSERT` statements to prevent duplicate records when running multiple transformations.

## Changes Made

### 1. Silver Table Schema (`silver/2_Silver_Target_Schemas.sql`)
- **Added `_RECORD_ID` column**: A unique identifier column that references the Bronze `RECORD_ID`
- **Added `_FILE_NAME` column**: Stores the source file name from Bronze for traceability
- **Added `_FILE_ROW_NUMBER` column**: Stores the row number in the source file from Bronze
- The `_RECORD_ID` column is marked as `NOT NULL UNIQUE` to ensure data integrity
- Updated metadata column count from 4 to 7

**Before:**
```sql
column_defs.append(f"_TPA VARCHAR(100) DEFAULT '{tpa}'")
column_defs.append("_BATCH_ID VARCHAR(100)")
column_defs.append("_LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()")
column_defs.append("_LOADED_BY VARCHAR(500) DEFAULT CURRENT_USER()")
```

**After:**
```sql
column_defs.append("_RECORD_ID NUMBER(38,0) NOT NULL UNIQUE")  # Unique identifier from Bronze RECORD_ID
column_defs.append("_FILE_NAME VARCHAR(500)")  # Source file name from Bronze
column_defs.append("_FILE_ROW_NUMBER NUMBER(38,0)")  # Row number in source file from Bronze
column_defs.append(f"_TPA VARCHAR(100) DEFAULT '{tpa}'")
column_defs.append("_BATCH_ID VARCHAR(100)")
column_defs.append("_LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()")
column_defs.append("_LOADED_BY VARCHAR(500) DEFAULT CURRENT_USER()")
```

### 2. Transformation Logic (`silver/5_Silver_Transformation_Logic.sql`)
- **Replaced `INSERT` with `MERGE`**: The transformation now uses a `MERGE INTO` statement
- **Merge Key**: Uses `_RECORD_ID` to match existing records
- **Behavior**:
  - `WHEN MATCHED`: Updates existing records with new data and metadata
  - `WHEN NOT MATCHED`: Inserts new records

**Key Changes:**
```sql
MERGE INTO {full_target_table} AS target
USING (
    SELECT 
        RECORD_ID AS _RECORD_ID,
        FILE_NAME AS _FILE_NAME,
        FILE_ROW_NUMBER AS _FILE_ROW_NUMBER,
        {mapped_columns},
        '{tpa}' AS _TPA,
        '{batch_id}' AS _BATCH_ID,
        CURRENT_TIMESTAMP() AS _LOAD_TIMESTAMP,
        CURRENT_USER() AS _LOADED_BY
    FROM {source_schema}.{source_table}
    WHERE TPA = '{tpa}'
      AND RAW_DATA IS NOT NULL
    LIMIT {batch_size}
) AS source
ON target._RECORD_ID = source._RECORD_ID
WHEN MATCHED THEN
    UPDATE SET
    {all_columns_updated},
    _FILE_NAME = source._FILE_NAME,
    _FILE_ROW_NUMBER = source._FILE_ROW_NUMBER
WHEN NOT MATCHED THEN
    INSERT ({all_columns})
    VALUES ({all_values})
```

## Benefits

1. **No Duplicate Records**: Running the same transformation multiple times will update existing records instead of creating duplicates
2. **Idempotent Operations**: Transformations can be safely re-run without data quality issues
3. **Full Traceability**: Each Silver record can be traced back to its source file and row number via `_FILE_NAME` and `_FILE_ROW_NUMBER`
4. **Audit Trail**: The `_BATCH_ID`, `_LOAD_TIMESTAMP`, and `_LOADED_BY` fields are updated on each merge, providing visibility into when records were last processed
5. **Consistent with Gold Layer**: The Silver layer now follows the same pattern as the Gold layer transformations
6. **Data Lineage**: Complete lineage from Bronze → Silver with file-level granularity

## Migration Notes

### For Existing Tables
If you have existing Silver tables without the new metadata columns, you'll need to:

1. **Option A - Recreate Tables** (Recommended for development):
   ```sql
   DROP TABLE IF EXISTS {TPA}_{TABLE_NAME};
   CALL create_silver_table('{TABLE_NAME}', '{TPA}');
   ```

2. **Option B - Add Columns to Existing Tables** (For production with data):
   ```sql
   ALTER TABLE {TPA}_{TABLE_NAME} ADD COLUMN _RECORD_ID NUMBER(38,0);
   ALTER TABLE {TPA}_{TABLE_NAME} ADD COLUMN _FILE_NAME VARCHAR(500);
   ALTER TABLE {TPA}_{TABLE_NAME} ADD COLUMN _FILE_ROW_NUMBER NUMBER(38,0);
   
   -- Backfill from Bronze if possible
   -- This requires knowing which Bronze records correspond to Silver records
   ```

### For New Deployments
- New tables created via `create_silver_table()` will automatically include the `_RECORD_ID` column
- No additional steps required

## Testing

To verify the merge behavior:

1. Run a transformation:
   ```sql
   CALL transform_bronze_to_silver('CLAIMS', 'provider_a');
   ```

2. Check record count:
   ```sql
   SELECT COUNT(*) FROM PROVIDER_A_CLAIMS;
   ```

3. Run the same transformation again:
   ```sql
   CALL transform_bronze_to_silver('CLAIMS', 'provider_a');
   ```

4. Verify record count hasn't changed (records were updated, not duplicated):
   ```sql
   SELECT COUNT(*) FROM PROVIDER_A_CLAIMS;
   ```

5. Check that metadata was updated and includes source file information:
   ```sql
   SELECT _RECORD_ID, _FILE_NAME, _FILE_ROW_NUMBER, _BATCH_ID, _LOAD_TIMESTAMP 
   FROM PROVIDER_A_CLAIMS 
   ORDER BY _LOAD_TIMESTAMP DESC 
   LIMIT 10;
   ```

6. Verify traceability back to Bronze:
   ```sql
   -- Find a Silver record and trace it back to Bronze
   SELECT 
       s._RECORD_ID,
       s._FILE_NAME,
       s._FILE_ROW_NUMBER,
       b.RECORD_ID,
       b.FILE_NAME,
       b.FILE_ROW_NUMBER,
       b.RAW_DATA
   FROM PROVIDER_A_CLAIMS s
   JOIN BRONZE.RAW_DATA_TABLE b ON s._RECORD_ID = b.RECORD_ID
   LIMIT 5;
   ```

## Comparison with Gold Layer

The Gold layer already uses MERGE statements (see `gold/4_Gold_Transformation_Procedures.sql`):
- Claims Analytics: Merges on `tpa`, `claim_year`, `claim_month`, `claim_type`, `provider_id`
- Member 360: Merges on `tpa`, `member_id`

The Silver layer now follows the same pattern, ensuring consistency across all transformation layers.

## Related Files
- `silver/2_Silver_Target_Schemas.sql` - Table creation with `_RECORD_ID`
- `silver/5_Silver_Transformation_Logic.sql` - MERGE transformation logic
- `gold/4_Gold_Transformation_Procedures.sql` - Reference implementation for Gold layer
- `bronze/2_Bronze_Schema_Tables.sql` - Source of `RECORD_ID`
