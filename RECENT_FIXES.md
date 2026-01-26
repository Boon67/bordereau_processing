# Recent Fixes and Enhancements

This document consolidates all fixes and enhancements made during the recent development session.

## Table of Contents
1. [Authentication Cookie Fix](#authentication-cookie-fix)
2. [Schema Loading Fix](#schema-loading-fix)
3. [File Removal from @SRC Stage](#file-removal-fix)
4. [Silver Table Creation Fix](#silver-table-creation-fix)

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
- `sample_data/config/load_sample_schemas.sql` - Fixed for hybrid tables

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
