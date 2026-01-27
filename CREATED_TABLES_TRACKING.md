# Created Tables Tracking Implementation

## Problem
The "Created Tables" section was showing all Silver layer tables including system tables (LLM_PROMPT_TEMPLATES, PROCESSING_WATERMARKS, etc.) mixed with user-created data tables (PROVIDER_A_DENTAL_CLAIMS).

## Solution: Tracking Table (Option 1)
Implemented a `created_tables` tracking table to explicitly track user-created data tables and distinguish them from system tables.

---

## Implementation Details

### 1. New Tracking Table

**Table**: `SILVER.created_tables` (Hybrid Table)

**Schema**:
```sql
CREATE HYBRID TABLE created_tables (
    table_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    physical_table_name VARCHAR(500) NOT NULL UNIQUE,
    schema_table_name VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(500) DEFAULT CURRENT_USER(),
    description VARCHAR(5000),
    active BOOLEAN DEFAULT TRUE,
    INDEX idx_created_tables_tpa (tpa),
    INDEX idx_created_tables_schema (schema_table_name),
    INDEX idx_created_tables_active (active)
)
```

**Purpose**: Tracks all user-created Silver data tables with metadata.

**Columns**:
- `physical_table_name`: Full table name (e.g., `PROVIDER_A_DENTAL_CLAIMS`)
- `schema_table_name`: Schema definition name (e.g., `DENTAL_CLAIMS`)
- `tpa`: Provider code (e.g., `provider_a`)
- `created_timestamp`: When the table was created
- `created_by`: User who created the table
- `description`: Optional description
- `active`: Whether the table is active

---

### 2. Updated `create_silver_table` Procedure

**File**: `silver/2_Silver_Target_Schemas.sql`

**Changes**:
- After creating the physical table, inserts a record into `created_tables`
- Uses `WHERE NOT EXISTS` to prevent duplicates
- Automatically populates metadata (table name, schema, TPA, description)

**Code Added**:
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
session.sql(tracking_sql).collect()
```

---

### 3. Updated API Endpoint

**File**: `backend/app/api/silver.py`

**Endpoint**: `GET /silver/tables`

**Changes**:
- Queries from `created_tables` instead of `INFORMATION_SCHEMA.TABLES`
- Joins with `INFORMATION_SCHEMA.TABLES` to get current row counts and sizes
- Filters by `active = TRUE`
- Returns additional metadata (schema name, TPA, created by)

**New Query**:
```sql
SELECT 
    ct.physical_table_name as TABLE_NAME,
    ct.schema_table_name as SCHEMA_TABLE,
    ct.tpa as TPA,
    ct.created_timestamp as CREATED_AT,
    ct.created_by as CREATED_BY,
    ct.description as DESCRIPTION,
    COALESCE(ist.row_count, 0) as ROW_COUNT,
    COALESCE(ist.bytes, 0) as BYTES,
    ist.last_altered as LAST_UPDATED
FROM SILVER.created_tables ct
LEFT JOIN INFORMATION_SCHEMA.TABLES ist 
    ON ist.table_schema = 'SILVER'
    AND ist.table_name = ct.physical_table_name
WHERE ct.active = TRUE
ORDER BY ct.created_timestamp DESC
```

---

### 4. Updated Frontend

**File**: `frontend/src/pages/SilverSchemas.tsx`

**Changes**:
- Added `getSilverTables()` API call
- Updated table columns to show:
  - Table Name (physical name)
  - Schema (schema definition name)
  - Provider (TPA)
  - Rows (row count)
  - Size (formatted bytes)
  - Created By (user)
  - Created At (timestamp)
- Auto-refreshes after creating a new table

**New Columns**:
- **Schema**: Shows which schema definition was used (e.g., `DENTAL_CLAIMS`)
- **Provider**: Shows which TPA the table belongs to (e.g., `provider_a`)
- **Created By**: Shows who created the table

---

### 5. Deployment Script

**File**: `silver/ADD_CREATED_TABLES_TRACKING.sql`

**Purpose**: 
- Creates the `created_tables` tracking table
- Backfills existing data tables automatically
- Excludes known system tables

**Backfill Logic**:
- Queries `INFORMATION_SCHEMA.TABLES` for existing tables
- Filters out system tables by name
- Uses regex to match `{TPA}_{TABLE_NAME}` pattern
- Extracts TPA and schema name from table name
- Inserts into tracking table

**System Tables Excluded**:
- `TARGET_SCHEMAS`
- `FIELD_MAPPINGS`
- `TRANSFORMATION_RULES`
- `SILVER_PROCESSING_LOG`
- `CREATED_TABLES`
- `DATA_QUALITY_METRICS`
- `QUARANTINE_RECORDS`
- `PROCESSING_WATERMARKS`
- `LLM_PROMPT_TEMPLATES`

---

## Deployment Status

✅ **Tracking table created** - `SILVER.created_tables`
✅ **Existing table backfilled** - `PROVIDER_A_DENTAL_CLAIMS` 
✅ **Procedure updated** - `create_silver_table` now tracks tables
✅ **API updated** - `/silver/tables` queries tracking table
✅ **Frontend updated** - Shows tracked tables only

---

## Benefits

1. ✅ **Clean Separation**: User data tables separated from system tables
2. ✅ **Rich Metadata**: Tracks schema, TPA, creator, description
3. ✅ **Flexible**: Easy to add/remove tables from tracking
4. ✅ **Auditable**: Know who created what and when
5. ✅ **Scalable**: Hybrid table for fast queries
6. ✅ **Automatic**: New tables automatically tracked on creation

---

## Usage

### Creating a Table
When you create a table through the UI:
1. Select a schema (e.g., `DENTAL_CLAIMS`)
2. Select a provider (e.g., `Provider A`)
3. Click "Create Table"
4. Physical table created: `PROVIDER_A_DENTAL_CLAIMS`
5. **Automatically tracked** in `created_tables`

### Viewing Tables
The "Created Tables" section now shows:
- ✅ Only user-created data tables
- ❌ No system tables
- 📊 Rich metadata (schema, TPA, creator, size, etc.)

### Manual Tracking (if needed)
To manually add a table to tracking:
```sql
INSERT INTO SILVER.created_tables 
(physical_table_name, schema_table_name, tpa, description)
VALUES 
('PROVIDER_B_MEDICAL_CLAIMS', 'MEDICAL_CLAIMS', 'provider_b', 'Manually tracked');
```

### Removing from Tracking
To hide a table (soft delete):
```sql
UPDATE SILVER.created_tables 
SET active = FALSE 
WHERE physical_table_name = 'PROVIDER_A_DENTAL_CLAIMS';
```

---

## Future Enhancements

Potential additions to the tracking table:
- **Table status** (active, archived, deprecated)
- **Data retention policy** (how long to keep data)
- **Last refresh timestamp** (when data was last loaded)
- **Source system** (where data comes from)
- **Business owner** (who owns the data)
- **Tags** (for categorization)

---

## Files Modified

1. ✅ `silver/1_Silver_Schema_Setup.sql` - Added `created_tables` table definition
2. ✅ `silver/2_Silver_Target_Schemas.sql` - Updated `create_silver_table` procedure
3. ✅ `silver/ADD_CREATED_TABLES_TRACKING.sql` - Deployment script (new)
4. ✅ `backend/app/api/silver.py` - Updated `/silver/tables` endpoint
5. ✅ `frontend/src/services/api.ts` - Added `getSilverTables()` method
6. ✅ `frontend/src/pages/SilverSchemas.tsx` - Updated UI to show tracked tables

---

## Testing

To verify the implementation:

1. **Check tracking table**:
```sql
SELECT * FROM BORDEREAU_PROCESSING_PIPELINE.SILVER.created_tables;
```

2. **Create a new table** through the UI and verify it appears in tracking

3. **Check API response**:
```bash
curl "https://[your-endpoint]/api/silver/tables"
```

4. **Verify UI** shows only user-created tables

---

**Status**: ✅ **Fully Implemented and Deployed**
