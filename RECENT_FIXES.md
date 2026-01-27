# Recent Fixes and Enhancements

This document consolidates all fixes and enhancements made during the recent development session.

## Table of Contents
1. [Authentication Cookie Fix](#authentication-cookie-fix)
2. [Schema Loading Fix](#schema-loading-fix)
3. [File Removal from @SRC Stage](#file-removal-fix)
4. [Silver Table Creation Fix](#silver-table-creation-fix)
5. [Field Mappings Display Fix](#field-mappings-display-fix)
6. [TPA-Agnostic Schema Redesign](#tpa-agnostic-schema-redesign)
7. [Configuration Variable Fix](#configuration-variable-fix)

---

## Authentication Cookie Fix

### Problem
Users were randomly logged out because the `sfc-ss-ingress-auth-v1` cookie (set by Snowpark Container Services) was being reset on API responses.

### Root Cause
Three-part issue:
1. Frontend axios not configured to send cookies
2. Nginx proxy not forwarding cookies from client to backend
3. Nginx not passing Set-Cookie headers from backend to client

### Solution

**Frontend** (`frontend/src/services/api.ts`):
```typescript
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: { 'Content-Type': 'application/json' },
  withCredentials: true, // ✅ Enable cookie sending
})
```

**Backend** (`backend/app/main.py`):
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],  # ✅ Expose Set-Cookie headers
)
```

**Nginx** (`docker/nginx.conf`):
```nginx
location /api/ {
    # ... existing config ...
    proxy_set_header Cookie $http_cookie;      # ✅ Forward cookies to backend
    proxy_pass_header Set-Cookie;              # ✅ Pass Set-Cookie to client
    proxy_buffering off;
    proxy_read_timeout 300s;
}
```

### Deployment
Requires container redeployment:
```bash
./deployment/redeploy_backend.sh
```

---

## Schema Loading Fix

### Problem
Sample schema loading failed with error:
```
ON_ERROR type CONTINUE is not supported for the copy statements on hybrid table.
```

### Root Cause
The `target_schemas` table is a **hybrid table** which doesn't support `ON_ERROR = CONTINUE` in COPY statements. Additionally, the table has a unique key on `(TABLE_NAME, COLUMN_NAME, TPA)` causing duplicate key violations on re-runs.

### Solution

**Updated** `sample_data/config/load_sample_schemas.sql`:
```sql
-- Clear existing data to avoid duplicates
TRUNCATE TABLE target_schemas;

-- Load with ABORT_STATEMENT (supported by hybrid tables)
COPY INTO target_schemas (...)
...
ON_ERROR = ABORT_STATEMENT;  -- Changed from CONTINUE
```

### Result
✅ 310 rows loaded successfully (5 TPAs × 4 table types)

---

## File Removal Fix

### Problem
After uploading and processing files, they remained in the `@SRC` stage instead of being removed.

### Root Cause
The `move_processed_files()` and `move_failed_files()` procedures were intentionally designed to only **copy** files, not **remove** them from `@SRC`. This was a design decision to keep files as "source of truth", but caused clutter.

### Solution

**Updated** `bronze/3_Bronze_Setup_Logic.sql`:
```python
# Copy file to destination
copy_cmd = f"COPY FILES INTO {dest_path} FROM {src_path}"
session.sql(copy_cmd).collect()

# ✅ Remove file from @SRC after successful copy
remove_cmd = f"REMOVE {src_path}"
session.sql(remove_cmd).collect()
```

Applied to both:
- `move_processed_files()` - removes from @SRC after copying to @COMPLETED
- `move_failed_files()` - removes from @SRC after copying to @ERROR

### File Processing Flow (Updated)
1. Upload → `@SRC/tpa/filename.csv`
2. Discovery → Added to queue
3. Processing → Data loaded into RAW_DATA_TABLE
4. Movement:
   - If SUCCESS: Copy to `@COMPLETED` → **Remove from @SRC** ✅
   - If FAILED: Copy to `@ERROR` → **Remove from @SRC** ✅

### Deployment
```bash
snow sql -f bronze/update_move_procedures.sql --connection DEPLOYMENT
```

---

## Silver Table Creation Fix

### Problem
1. Creating Silver tables via UI failed with 500 error
2. User requested schema management redesign: schemas shared across TPAs, but tables TPA-specific

### Root Cause
The `create_silver_table` SQL stored procedure had:
- SQL syntax errors in FOR loop
- Improper handling of string default values (not quoted)
- Complex cursor logic difficult to debug

### Solution

**Rewrote procedure in Python** (`silver/2_Silver_Target_Schemas.sql`):
```python
def create_silver_table(session, table_name, tpa):
    # Get column definitions
    columns = session.sql(f"""
        SELECT COLUMN_NAME, DATA_TYPE, NULLABLE, DEFAULT_VALUE
        FROM target_schemas
        WHERE table_name = '{table_name.upper()}'
          AND tpa = '{tpa}'
          AND active = TRUE
    """).collect()
    
    # Build column definitions with proper quoting
    column_defs = []
    for col in columns:
        col_def = f"{col['COLUMN_NAME']} {col['DATA_TYPE']}"
        if not col['NULLABLE']:
            col_def += " NOT NULL"
        if col['DEFAULT_VALUE']:
            # ✅ Proper handling of string literals vs functions
            if '(' in default_val or default_val.replace('.', '').isdigit():
                col_def += f" DEFAULT {default_val}"
            else:
                col_def += f" DEFAULT '{default_val}'"  # Quote strings
        column_defs.append(col_def)
    
    # Add metadata columns
    column_defs.extend([
        f"_TPA VARCHAR(100) DEFAULT '{tpa}'",
        "_BATCH_ID VARCHAR(100)",
        "_LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()",
        "_LOADED_BY VARCHAR(500) DEFAULT CURRENT_USER()"
    ])
    
    # Create table
    full_table_name = f"{tpa.upper()}_{table_name.upper()}"
    create_sql = f"CREATE TABLE IF NOT EXISTS {full_table_name} ({', '.join(column_defs)})"
    session.sql(create_sql).collect()
    
    return f"Successfully created table: {full_table_name}"
```

### Table Naming Convention
- Format: `{TPA}_{TABLE_NAME}`
- Example: `PROVIDER_A_MEDICAL_CLAIMS`, `PROVIDER_B_MEDICAL_CLAIMS`

### Metadata Columns (Auto-added)
- `_TPA VARCHAR(100)` - TPA identifier
- `_BATCH_ID VARCHAR(100)` - Processing batch ID
- `_LOAD_TIMESTAMP TIMESTAMP_NTZ` - Load timestamp
- `_LOADED_BY VARCHAR(500)` - User who loaded data

### Current Schema Design
- Schemas are **TPA-specific** (each TPA has own column definitions)
- Unique key: `(TABLE_NAME, COLUMN_NAME, TPA)`
- Tables named: `{TPA}_{TABLE_NAME}`

### Future Enhancement: TPA-Agnostic Schemas
To implement shared schemas across TPAs:
1. Remove TPA from unique constraint
2. Consolidate duplicate schema definitions
3. Add TPA selector to UI's "Create Table" flow

---

## Field Mappings Display Fix

### Problem
The Field Mappings page was not displaying target tables when no mappings existed yet. Users couldn't see which tables were available for mapping.

### Root Cause
The UI only showed tables that already had mappings, not all available target tables from the schema definitions.

### Solution

**Updated** `frontend/src/pages/SilverMappings.tsx`:

1. **Load Available Target Tables** from schema definitions:
```typescript
const loadTargetTables = async () => {
  const schemas = await apiService.getTargetSchemas(selectedTpa)
  // Group by table name and count columns
  const tableMap = schemas.reduce((acc, schema) => {
    if (!acc[schema.TABLE_NAME]) {
      acc[schema.TABLE_NAME] = { name: schema.TABLE_NAME, columns: 0 }
    }
    acc[schema.TABLE_NAME].columns++
    return acc
  }, {})
  setAvailableTargetTables(Object.values(tableMap))
}
```

2. **Display All Target Tables** with status:
```typescript
const allTargetTablesWithStatus = availableTargetTables.map(table => ({
  name: table.name,
  columns: table.columns,
  mappings: mappingsByTable[table.name] || [],
  hasMappings: !!mappingsByTable[table.name],
}))
```

3. **Enhanced Table Cards** to show:
   - ✅ Table name
   - ✅ Column count (e.g., "14 columns")
   - ✅ Mapping count or "No mappings yet"
   - ✅ Approval status

### User Experience

**Before**:
- "No field mappings found" - no visibility into available tables

**After**:
- Shows all 4 target tables (DENTAL_CLAIMS, MEDICAL_CLAIMS, MEMBER_ELIGIBILITY, PHARMACY_CLAIMS)
- Each table displays column count and mapping status
- Clear guidance: "Use Auto-Map (ML), Auto-Map (LLM), or Manual Mapping to create mappings"

### Example Display

```
DENTAL_CLAIMS
├─ 14 columns
├─ No mappings yet
└─ "Use Auto-Map (ML), Auto-Map (LLM), or Manual Mapping to create mappings."

MEDICAL_CLAIMS
├─ 14 columns
├─ 5 mappings
├─ 3/5 approved
└─ [Table showing source → target field mappings]
```

---

## TPA-Agnostic Schema Redesign

### Problem
Schemas were duplicated per TPA (310 rows = 62 columns × 5 TPAs), causing maintenance issues and confusion. The system didn't clearly separate schema definitions (templates) from table instances (TPA-specific data).

### Root Cause
The `target_schemas` table included TPA as part of the unique constraint, requiring identical schema definitions to be duplicated for each TPA.

### Solution

**Database Migration** (`silver/MIGRATE_TPA_AGNOSTIC_SCHEMAS.sql`):
```sql
-- Removed TPA column from target_schemas
-- Changed unique constraint from (table_name, column_name, tpa) to (table_name, column_name)
-- Consolidated 310 rows → 62 rows (80% reduction)
```

**Updated Procedures** (`silver/2_Silver_Target_Schemas.sql`):
```python
# create_silver_table: Removed TPA filter from schema query
WHERE table_name = '{table_name_upper}' AND active = TRUE

# get_target_schema: Removed tpa parameter
```

**Backend Updates**:
- `snowflake_service.py`: Made TPA optional, removed TPA filter
- `silver.py`: Updated API endpoints to not require TPA

**Frontend Updates**:
- `api.ts`: Removed TPA from `getTargetSchemas()` signature
- `SilverSchemas.tsx`: Load schemas once (TPA-agnostic), check table existence per TPA
- `SilverMappings.tsx`: Show all available tables with mapping status

**Sample Data**:
- `silver_target_schemas.csv`: Removed TPA column (311 → 63 lines)
- `load_sample_schemas.sql`: Updated COPY INTO to match new structure

### Design Principle

```
SCHEMAS (Shared)          TABLES (TPA-Specific)
├─ DENTAL_CLAIMS     →   ├─ PROVIDER_A_DENTAL_CLAIMS
├─ MEDICAL_CLAIMS    →   ├─ PROVIDER_A_MEDICAL_CLAIMS
├─ MEMBER_ELIGIBILITY→   ├─ PROVIDER_A_MEMBER_ELIGIBILITY
└─ PHARMACY_CLAIMS   →   └─ PROVIDER_A_PHARMACY_CLAIMS
```

### User Experience

**Before**:
- Schemas loaded per TPA (duplicated)
- Field Mappings showed "No field mappings found" with no table visibility

**After**:
- Schemas load immediately (shared across TPAs)
- Field Mappings shows all 4 tables with status:
  - DENTAL_CLAIMS (14 columns) - No mappings yet
  - MEDICAL_CLAIMS (14 columns) - 5 mappings, 3/5 approved
  - MEMBER_ELIGIBILITY (18 columns) - No mappings yet
  - PHARMACY_CLAIMS (16 columns) - No mappings yet
- TPA selection only required when creating physical tables

### Benefits
- **80% reduction** in schema metadata (310 → 62 rows)
- **Simplified maintenance**: Update once, applies to all TPAs
- **Clearer architecture**: Schemas = templates, Tables = TPA-specific instances
- **Better UX**: All tables visible, clear mapping status

---

## Configuration Variable Fix

### Problem
SQL files had hardcoded values like `BORDEREAU_PROCESSING_PIPELINE` and `SILVER` instead of using configuration variables from `default.config`.

### Root Cause
SQL files were using literal values instead of placeholders that could be substituted by deployment scripts.

### Solution

**Updated SQL Files**:
```sql
# OLD (hardcoded)
USE ROLE SYSADMIN;
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA SILVER;

# NEW (uses config variables)
SET DATABASE_NAME = '$DATABASE_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';
SET SNOWFLAKE_ROLE = '$SNOWFLAKE_ROLE';

USE ROLE IDENTIFIER($SNOWFLAKE_ROLE);
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);
```

**Updated Deployment Scripts**:
- `deploy_silver.sh`: Added `SNOWFLAKE_ROLE` to sed substitution
- `deploy.sh`: Added `export DEPLOY_ROLE="$ROLE"`

### Configuration Flow

```
default.config
    ↓
deploy.sh (loads config, exports variables)
    ↓
deploy_silver.sh (receives variables, substitutes in SQL)
    ↓
SQL files (execute with actual values)
```

### Benefits
- ✅ **No Hardcoding**: All configuration in `default.config`
- ✅ **Easy Customization**: Change config without modifying SQL
- ✅ **Consistent**: Same variables across all scripts
- ✅ **Flexible**: Deploy to different databases/schemas easily

---

## Summary of Files Changed

### Backend
- `backend/app/main.py` - Enhanced CORS middleware
- `backend/app/config.py` - Made CORS origins configurable
- `frontend/src/services/api.ts` - Added withCredentials

### Docker/Nginx
- `docker/nginx.conf` - Added cookie forwarding and pass-through

### Bronze Layer
- `bronze/3_Bronze_Setup_Logic.sql` - Updated move procedures to remove files
- `bronze/update_move_procedures.sql` - Deployment script

### Silver Layer
- `silver/2_Silver_Target_Schemas.sql` - Rewrote create_silver_table in Python
- `silver/fix_create_table_procedure.sql` - Standalone fix script

### Sample Data
- `sample_data/config/load_sample_schemas.sql` - Fixed for hybrid tables, uses config variables

### Frontend
- `frontend/src/pages/SilverMappings.tsx` - Enhanced to show all target tables
- `frontend/src/pages/SilverSchemas.tsx` - TPA-agnostic schema loading
- `frontend/src/services/api.ts` - Updated API signatures

### Deployment
- `deployment/deploy_silver.sh` - Added SNOWFLAKE_ROLE substitution
- `deployment/deploy.sh` - Export DEPLOY_ROLE variable

---

## Testing Checklist

### Authentication
- [ ] Access SPCS public endpoint
- [ ] Navigate through UI
- [ ] Verify not logged out randomly
- [ ] Check Cookie header in browser DevTools

### Schema Loading
- [ ] Run `load_sample_schemas.sh`
- [ ] Verify 310 rows loaded
- [ ] Check all 5 TPAs present

### File Processing
- [ ] Upload file via UI
- [ ] Wait for processing
- [ ] Verify file removed from @SRC
- [ ] Verify file in @COMPLETED

### Table Creation
- [ ] Go to Silver Layer → Target Schemas
- [ ] Click "Create Table"
- [ ] Verify table created successfully
- [ ] Check table structure with DESCRIBE

### Field Mappings Display
- [ ] Go to Silver Layer → Field Mappings
- [ ] Select a TPA
- [ ] Verify all target tables are displayed
- [ ] Verify tables show column counts
- [ ] Verify tables without mappings show guidance message
- [ ] Click "Auto-Map (ML)" and verify dropdown shows all tables

### TPA-Agnostic Schema Redesign
- [ ] Go to Silver Layer → Target Schemas
- [ ] Verify schemas load immediately (no TPA selection needed)
- [ ] Verify 4 tables displayed: DENTAL_CLAIMS, MEDICAL_CLAIMS, MEMBER_ELIGIBILITY, PHARMACY_CLAIMS
- [ ] Click "Create Table" and verify TPA selection dropdown appears
- [ ] Select a TPA and create table
- [ ] Verify table created as `PROVIDER_X_TABLE_NAME`
- [ ] Go to Field Mappings and verify all tables visible with mapping status

---

## Deployment Commands

```bash
# Deploy Bronze layer updates
snow sql -f bronze/update_move_procedures.sql --connection DEPLOYMENT

# Deploy Silver layer updates  
snow sql -f silver/fix_create_table_procedure.sql --connection DEPLOYMENT

# Redeploy container service (for auth fix)
./deployment/redeploy_backend.sh

# Or full redeployment
./deployment/deploy.sh
```

---

## Documentation Files Created
- `AUTHENTICATION_COOKIE_FIX.md` - Detailed auth fix
- `SCHEMA_LOADING_FIX.md` - Schema loading details
- `FILE_REMOVAL_FIX.md` - File removal details
- `SILVER_TABLE_CREATION_FIX.md` - Table creation details
- `RECENT_FIXES.md` - This consolidated document

**Note**: Individual fix documents can be removed after review as this document consolidates all information.
