# Technical Reference

**Detailed technical documentation for advanced topics**

---

## Silver Metadata Columns

### Overview
All Silver layer tables automatically include 7 metadata columns for data lineage and traceability.

### Columns

| Column | Type | Purpose |
|--------|------|---------|
| `_RECORD_ID` | NUMBER(38,0) NOT NULL UNIQUE | Merge key linking to Bronze `RECORD_ID` |
| `_FILE_NAME` | VARCHAR(500) | Source file name |
| `_FILE_ROW_NUMBER` | NUMBER(38,0) | Row number in source file |
| `_TPA` | VARCHAR(100) | TPA code (defaults to table's TPA) |
| `_BATCH_ID` | VARCHAR(100) | Transformation batch ID |
| `_LOAD_TIMESTAMP` | TIMESTAMP_NTZ | When record was loaded/updated |
| `_LOADED_BY` | VARCHAR(500) | User who processed the record |

### Usage Examples

**Trace record to source:**
```sql
SELECT 
    claim_id,
    _FILE_NAME,
    _FILE_ROW_NUMBER,
    _LOAD_TIMESTAMP
FROM PROVIDER_A_CLAIMS
WHERE claim_id = '12345';
```

**Find all records from specific file:**
```sql
SELECT COUNT(*) as record_count
FROM PROVIDER_A_CLAIMS
WHERE _FILE_NAME = 'claims_2024_01.csv';
```

**Audit recent transformations:**
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

**Complete data lineage:**
```sql
SELECT 
    s.claim_id,
    s._RECORD_ID,
    s._FILE_NAME,
    s._FILE_ROW_NUMBER,
    b.RAW_DATA
FROM PROVIDER_A_CLAIMS s
JOIN BRONZE.RAW_DATA_TABLE b ON s._RECORD_ID = b.RECORD_ID
WHERE s.claim_id = '12345';
```

### Benefits
- **Full Traceability**: Every record traces to exact source file and row
- **Audit Compliance**: Complete audit trail of processing
- **Data Quality**: Easy to identify and investigate issues
- **Idempotent Processing**: `_RECORD_ID` prevents duplicates
- **Debugging**: Quick source file lookup for issues

---

## Silver Auto-Transform Task

### Overview
Automated task that runs all approved field mappings on a schedule, transforming Bronze data to Silver tables.

### Task Configuration

**Name**: `auto_transform_mappings_task`  
**Schedule**: Daily at 2 AM (configurable)  
**Default CRON**: `USING CRON 0 2 * * * America/New_York`  
**Warehouse**: Configured warehouse

### How It Works

**Discovery Phase:**
1. Queries `field_mappings` table
2. Finds unique TPA + target_table combinations
3. Filters for `approved = TRUE` and `active = TRUE`

**Transformation Phase:**
For each TPA + target_table:
1. Calls `transform_bronze_to_silver()` procedure
2. Transforms up to 10,000 records per run (configurable)
3. Uses MERGE logic to prevent duplicates
4. Logs results to `silver_processing_log`

### Task Management

**Resume task:**
```sql
ALTER TASK auto_transform_mappings_task RESUME;
```

**Suspend task:**
```sql
ALTER TASK auto_transform_mappings_task SUSPEND;
```

**Check status:**
```sql
SHOW TASKS LIKE 'auto_transform_mappings_task';
```

**View execution history:**
```sql
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'auto_transform_mappings_task',
    SCHEDULED_TIME_RANGE_START => DATEADD(day, -7, CURRENT_TIMESTAMP())
))
ORDER BY SCHEDULED_TIME DESC;
```

### Configuration

**Change schedule:**
```sql
ALTER TASK auto_transform_mappings_task
SET SCHEDULE = 'USING CRON 0 3 * * * America/New_York';  -- 3 AM daily
```

**Change batch size:**
Modify the procedure call in task definition to use different batch size parameter.

### Monitoring

**Check processing log:**
```sql
SELECT 
    batch_id,
    tpa,
    target_table,
    status,
    records_processed,
    start_timestamp,
    end_timestamp,
    error_message
FROM SILVER.SILVER_PROCESSING_LOG
WHERE start_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY start_timestamp DESC;
```

**Failed transformations:**
```sql
SELECT *
FROM SILVER.SILVER_PROCESSING_LOG
WHERE status = 'FAILED'
ORDER BY start_timestamp DESC
LIMIT 10;
```

### Best Practices
- Monitor task execution history regularly
- Review failed transformations promptly
- Adjust schedule based on data volume
- Keep batch size reasonable (10K-50K)
- Ensure approved mappings are validated

---

## Validation System

### Overview
Three-layer validation system prevents invalid transformations and provides clear error messages.

### Layer 1: Mapping Creation Validation

**Endpoint**: `POST /api/silver/mappings`

**Checks**:
- Duplicate mappings to same target column
- Target column exists in physical table

**Example Error**:
```json
{
  "detail": "Mapping already exists for target column 'CLAIM_ID' in table 'DENTAL_CLAIMS' for TPA 'provider_a'"
}
```

### Layer 2: Manual Validation

**Endpoint**: `GET /api/silver/mappings/validate?tpa=provider_a&target_table=CLAIMS`

**Response**:
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

### Layer 3: Pre-Transformation Validation

**Endpoint**: `POST /api/silver/transform`

**Automatic Checks**:
1. Approved mappings exist
2. Physical table exists
3. All mapped columns exist in table

**Example Error**:
```json
{
  "detail": "Invalid mappings detected: columns SERVICE_DATE do not exist in table 'PROVIDER_A_DENTAL_CLAIMS'. Please fix the mappings before transforming."
}
```

### Usage in Code

**Validate before creating mapping:**
```python
# Check if column exists first
columns_query = f"""
    SELECT column_name
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = 'SILVER'
      AND table_name = 'PROVIDER_A_DENTAL_CLAIMS'
      AND column_name = 'SERVICE_DATE'
"""
```

**Validate all mappings:**
```bash
curl -X GET "https://your-app.snowflakecomputing.app/api/silver/mappings/validate?tpa=provider_a&target_table=DENTAL_CLAIMS"
```

---

## MERGE Transformation Logic

### Overview
Silver transformations use MERGE statements for idempotent operations.

### MERGE Statement Structure

```sql
MERGE INTO {target_table} AS target
USING (
    SELECT 
        RECORD_ID AS _RECORD_ID,
        {mapped_columns},
        '{tpa}' AS _TPA,
        '{batch_id}' AS _BATCH_ID,
        CURRENT_TIMESTAMP() AS _LOAD_TIMESTAMP,
        CURRENT_USER() AS _LOADED_BY
    FROM BRONZE.RAW_DATA_TABLE
    WHERE TPA = '{tpa}'
      AND RAW_DATA IS NOT NULL
    LIMIT {batch_size}
) AS source
ON target._RECORD_ID = source._RECORD_ID
WHEN MATCHED THEN
    UPDATE SET
        {all_columns_updated}
WHEN NOT MATCHED THEN
    INSERT ({all_columns})
    VALUES ({all_values})
```

### Behavior

**When Matched** (record exists):
- Updates all business columns
- Updates `_BATCH_ID`, `_LOAD_TIMESTAMP`, `_LOADED_BY`
- Preserves `_RECORD_ID`, `_FILE_NAME`, `_FILE_ROW_NUMBER`, `_TPA`

**When Not Matched** (new record):
- Inserts all columns including metadata

### Benefits
- **No Duplicates**: Running same transformation multiple times updates existing records
- **Audit Trail**: Metadata shows when record was last processed
- **Data Quality**: Ensures 1:1 mapping from Bronze to Silver
- **Safe Re-runs**: Can safely re-run failed transformations

### Example

**First Run:**
```sql
-- Inserts 1000 records
CALL transform_bronze_to_silver('CLAIMS', 'provider_a', ...);
-- Result: 1000 records in PROVIDER_A_CLAIMS
```

**Second Run (same data):**
```sql
-- Updates same 1000 records
CALL transform_bronze_to_silver('CLAIMS', 'provider_a', ...);
-- Result: Still 1000 records (updated, not duplicated)
```

---

## Performance Optimization

### Batch Processing
- Default batch size: 10,000 records
- Adjust based on data volume and complexity
- Larger batches = fewer iterations, more memory

### Warehouse Sizing
- Small warehouse: < 100K records
- Medium warehouse: 100K - 1M records
- Large warehouse: > 1M records

### Incremental Processing
```sql
CALL transform_bronze_to_silver(
    'CLAIMS',
    'provider_a',
    'RAW_DATA_TABLE',
    'BRONZE',
    10000,
    TRUE,
    TRUE  -- incremental = TRUE
);
```

### Monitoring Performance
```sql
SELECT 
    target_table,
    AVG(DATEDIFF(second, start_timestamp, end_timestamp)) as avg_duration_seconds,
    AVG(records_processed) as avg_records,
    COUNT(*) as total_runs
FROM SILVER.SILVER_PROCESSING_LOG
WHERE status = 'SUCCESS'
  AND start_timestamp > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY target_table
ORDER BY avg_duration_seconds DESC;
```

---

## Troubleshooting

### Transformation Fails

**Check validation:**
```bash
GET /api/silver/mappings/validate?tpa=provider_a&target_table=CLAIMS
```

**Check processing log:**
```sql
SELECT * FROM SILVER.SILVER_PROCESSING_LOG 
WHERE status = 'FAILED' 
ORDER BY start_timestamp DESC 
LIMIT 5;
```

### No Data After Transform

**Verify source data:**
```sql
SELECT COUNT(*) FROM BRONZE.RAW_DATA_TABLE WHERE TPA = 'provider_a';
```

**Check mappings:**
```sql
SELECT COUNT(*) FROM SILVER.FIELD_MAPPINGS 
WHERE target_table = 'CLAIMS' 
  AND tpa = 'provider_a' 
  AND approved = TRUE 
  AND active = TRUE;
```

### Duplicate Records

**Check for duplicate _RECORD_ID:**
```sql
SELECT _RECORD_ID, COUNT(*) as count
FROM PROVIDER_A_CLAIMS
GROUP BY _RECORD_ID
HAVING COUNT(*) > 1;
```

Should return 0 rows due to UNIQUE constraint.

---

---

## Default Value Validation

### Overview
Comprehensive validation ensures default values are compatible with column data types.

### Validation Rules

**Date/Time Types:**
- `DATE`: Valid = `CURRENT_DATE()`, `'2024-01-01'` | Invalid = `CURRENT_TIMESTAMP()`
- `TIMESTAMP`: Valid = `CURRENT_TIMESTAMP()` | Invalid = `CURRENT_DATE()`
- `TIME`: Valid = `CURRENT_TIME()`, `'12:00:00'`

**Numeric Types:**
- `NUMBER`, `INT`, `FLOAT`: Valid = `0`, `100.50` | Invalid = `'abc'`, `'N/A'`

**Boolean Type:**
- `BOOLEAN`: Valid = `TRUE`, `FALSE`, `0`, `1` | Invalid = `'YES'`, `'true'`

### Implementation

**Backend** (`backend/app/api/silver.py`):
- `validate_default_value_compatibility()` function
- Extracts base data type
- Identifies functions vs literals
- Returns clear error messages

**Frontend** (`frontend/src/pages/SilverSchemas.tsx`):
- Client-side validation
- Real-time feedback
- Type-specific hints
- Dynamic placeholders

### Examples

**Valid:**
```sql
SERVICE_DATE DATE DEFAULT CURRENT_DATE()
CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
AMOUNT NUMBER(18,2) DEFAULT 0.00
STATUS VARCHAR(50) DEFAULT 'PENDING'
```

**Invalid (Now Caught):**
```sql
-- Error: DATE columns cannot use CURRENT_TIMESTAMP()
SERVICE_DATE DATE DEFAULT CURRENT_TIMESTAMP()

-- Error: Default value 'N/A' is not a valid number
AMOUNT NUMBER DEFAULT 'N/A'
```

---

## Deployment Fixes

### Template Syntax Fix

**Problem**: Snowflake CLI 3.14.0 treats `<% %>` as Jinja2 syntax, causing parsing errors.

**Solution**:
1. Reverted to `&{}` syntax in all SQL files
2. Added `--enable-templating NONE` flag
3. Implemented sed preprocessing for variable substitution

**Files Modified**: 19 SQL files, 3 deployment scripts

### Variable Substitution

**Helper Function** (`deploy_gold.sh`):
```bash
execute_sql() {
    local sql_file="$1"
    sed "s|&{DATABASE_NAME}|$DATABASE_NAME|g; \
         s|&{SILVER_SCHEMA_NAME}|$SILVER_SCHEMA_NAME|g; \
         s|&{GOLD_SCHEMA_NAME}|$GOLD_SCHEMA_NAME|g" "$sql_file" | \
    snow sql --stdin --connection "$CONNECTION_NAME" --enable-templating NONE
}
```

### Benefits
- No CLI downgrade required
- Reliable variable substitution
- No template conflicts
- Backwards compatible

---

## Table Creation Error Handling

### Enhanced Stored Procedure

**Improvements** (`silver/2_Silver_Target_Schemas.sql`):
- Wrapped in try-except block
- Specific error handling for each step
- Descriptive ERROR messages
- Escape single quotes in defaults

**Error Detection**:
```python
if not columns:
    return f"ERROR: No columns defined for table '{table_name}'"

try:
    session.sql(create_sql).collect()
except Exception as create_error:
    return f"ERROR: Failed to create table: {str(create_error)}"
```

### Enhanced Backend API

**Improvements** (`backend/app/api/silver.py`):
- Detailed logging at each step
- Check for "ERROR:" prefix in results
- Improved exception handling
- Specific error messages

**Error Handling**:
```python
if result and isinstance(result, str) and result.startswith("ERROR:"):
    logger.error(f"Procedure returned error: {result}")
    raise HTTPException(status_code=400, detail=result)
```

### Common Errors

**No columns defined**: Add columns to schema first  
**Failed to process column**: Check data type and default value syntax  
**Failed to create table**: Verify permissions and warehouse status

---

## Documentation

**Main Docs**:
- [Quick Reference](QUICK_REFERENCE.md) - One-page cheat sheet
- [Architecture](ARCHITECTURE.md) - System design
- [User Guide](USER_GUIDE.md) - Usage instructions
- [Changelog](CHANGELOG.md) - Recent updates

**Component Docs**:
- [Bronze Layer](../bronze/README.md)
- [Silver Layer](../silver/README.md)
- [Gold Layer](../gold/README.md)

---

**Version**: 3.1 | **Updated**: Jan 31, 2026
