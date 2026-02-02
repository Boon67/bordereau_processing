# Auto-Mapping Troubleshooting & Fix Guide

Complete guide for ML and LLM auto-mapping features in the Silver layer.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Common Issues & Fixes](#common-issues--fixes)
3. [How Auto-Mapping Works](#how-auto-mapping-works)
4. [Diagnostic Tools](#diagnostic-tools)
5. [API Reference](#api-reference)

---

## Quick Start

### Prerequisites

Before using auto-mapping, ensure:

```sql
-- 1. Bronze data exists
SELECT COUNT(*) FROM BRONZE.RAW_DATA_TABLE WHERE TPA = 'your_tpa';
-- Should return > 0

-- 2. Target schema defined
SELECT COUNT(*) FROM SILVER.target_schemas 
WHERE table_name = 'YOUR_TABLE' AND active = TRUE;
-- Should return > 0

-- 3. LLM prompt template exists (for LLM mapping)
SELECT * FROM SILVER.llm_prompt_templates 
WHERE template_id = 'DEFAULT_FIELD_MAPPING';
-- Should return 1 row
```

### Using Auto-Mapping in UI

1. Go to **Silver > Field Mappings**
2. Select a **TPA** from header dropdown
3. Click on a **target table** (e.g., PROVIDER_A_PHARMACY_CLAIMS)
4. Click **Auto-Map (ML)** or **Auto-Map (LLM)**
5. Configure settings and click **Generate Mappings**

**Expected Result:**
- Success message: "Created X mappings"
- Mappings appear in table below
- Review and approve mappings

---

## Common Issues & Fixes

### Issue 1: "No mappings created" (200 OK but no results)

**Symptoms:**
- API returns 200 status
- Shows warning: "No mappings created"
- No mappings appear in table

**Root Cause:**
Frontend was sending **physical table name** (e.g., "PROVIDER_A_PHARMACY_CLAIMS") to procedures that need **schema table name** (e.g., "PHARMACY_CLAIMS").

**What Was Fixed:**
```typescript
// BEFORE: Sent physical table name ❌
await apiService.autoMapFieldsLLM(
  'RAW_DATA_TABLE',
  'PROVIDER_A_PHARMACY_CLAIMS',  // Physical name with TPA prefix
  'provider_a',
  'claude-3-5-sonnet'
)
// Result: "No target fields found in target_schemas"

// AFTER: Extract and send schema table name ✅
const tableInfo = availableTargetTables.find(t => t.physicalName === selectedTable)
const schemaTableName = tableInfo?.name  // "PHARMACY_CLAIMS"

await apiService.autoMapFieldsLLM(
  'RAW_DATA_TABLE',
  schemaTableName,  // Schema name without TPA prefix
  'provider_a',
  'claude-3-5-sonnet'
)
// Result: "Successfully generated 8 LLM-based field mappings"
```

**Files Fixed:**
- `frontend/src/pages/SilverMappings.tsx`:
  - `handleAutoMapML()` - Extracts schema name
  - `handleAutoMapLLM()` - Extracts schema name
  - `loadMappings()` - Queries with schema name
  - `handleManualMapping()` - Uses schema name
- `backend/app/api/silver.py`:
  - Added response parsing to extract `mappings_created` count
- `frontend/src/services/api.ts`:
  - Added missing `deleteMapping()` function

**Solution:**
Already fixed in code. Just rebuild frontend:
```bash
cd frontend
npm run build
```

---

### Issue 2: "No source fields found in Bronze table"

**Cause:** No data uploaded for that TPA

**Solution:**
```bash
# Upload data
snow stage put sample_data/claims_data/provider_a/*.csv @BRONZE.SRC/provider_a/

# Process files
snow sql -q "CALL BRONZE.discover_files()"
snow sql -q "CALL BRONZE.process_files()"

# Verify
snow sql -q "SELECT COUNT(*) FROM BRONZE.RAW_DATA_TABLE WHERE TPA = 'provider_a'"
```

---

### Issue 3: "No target fields found in target_schemas"

**Cause:** Target schema not defined

**Solution:**
```bash
# Load sample schemas
cd deployment
./load_sample_schemas.sh YOUR_CONNECTION
```

Or create manually:
```sql
INSERT INTO SILVER.target_schemas (table_name, column_name, data_type, nullable, description)
VALUES
  ('PHARMACY_CLAIMS', 'claim_id', 'VARCHAR(100)', FALSE, 'Unique claim identifier'),
  ('PHARMACY_CLAIMS', 'drug_name', 'VARCHAR(500)', TRUE, 'Drug name'),
  ('PHARMACY_CLAIMS', 'ndc_code', 'VARCHAR(50)', TRUE, 'NDC code');
```

---

### Issue 4: "No mappings found above confidence threshold"

**Cause:** Field names too different, or threshold too high

**Solution:**
- Lower confidence threshold: Try 0.3 or 0.4 instead of 0.6
- Use LLM instead of ML (better at semantic matching)
- Add manual mappings for critical fields

---

### Issue 5: "Prompt template 'DEFAULT_FIELD_MAPPING' not found"

**Cause:** LLM prompt template not created

**Solution:**
```bash
# Re-run Silver schema setup
snow sql -f silver/1_Silver_Schema_Setup.sql --connection YOUR_CONNECTION
```

---

### Issue 6: "Error calling Cortex AI"

**Cause:** Cortex AI not enabled in Snowflake account

**Solution:**
- Contact Snowflake support to enable Cortex AI
- Or use ML auto-mapping instead (doesn't require Cortex)

---

### Issue 7: "Bulk delete failed: deleteMapping is not a function"

**Cause:** Missing function in API service

**Solution:**
Already fixed in code. The `deleteMapping()` function has been added to `frontend/src/services/api.ts`.

---

## How Auto-Mapping Works

### Table Name Types

**Schema Table Name** (e.g., "PHARMACY_CLAIMS"):
- Logical table definition in `target_schemas`
- Used by mapping procedures to find column definitions
- Stored in `field_mappings.target_table`
- **No TPA prefix**

**Physical Table Name** (e.g., "PROVIDER_A_PHARMACY_CLAIMS"):
- Actual Snowflake table with data
- Format: `{TPA}_{SCHEMA_TABLE}`
- Displayed in UI for clarity
- **Has TPA prefix**

### Data Flow

```
User Action:
  Clicks table: "PROVIDER_A_PHARMACY_CLAIMS" (physical name)
  ↓
  UI extracts schema name: "PHARMACY_CLAIMS"
  ↓
Auto-Mapping Procedure:
  Receives: target_table="PHARMACY_CLAIMS"
  ↓
  Queries: SELECT * FROM target_schemas WHERE table_name='PHARMACY_CLAIMS'
  ↓
  Finds columns and creates mappings
  ↓
  Stores: field_mappings.target_table='PHARMACY_CLAIMS'
  ↓
Load Mappings:
  Queries: SELECT * FROM field_mappings WHERE target_table='PHARMACY_CLAIMS'
  ↓
  Displays mappings in UI
```

### ML Auto-Mapping Algorithm

Uses multiple similarity algorithms:
1. **Exact Match** (40% weight): Case-insensitive exact match
2. **Substring Match** (20% weight): One name contains the other
3. **Sequence Similarity** (20% weight): Character-level similarity
4. **Word Overlap** (20% weight): Jaccard similarity of word sets
5. **TF-IDF** (30% weight): Character n-gram similarity

**Combined Score** = (Basic Score × 0.7) + (TF-IDF × 0.3)

**Parameters:**
- `top_n`: Number of suggestions per source field (default: 3)
- `min_confidence`: Minimum score threshold (default: 0.6)

### LLM Auto-Mapping

Uses Snowflake Cortex AI for semantic understanding:

**Available Models:**
- `claude-3-5-sonnet` (recommended)
- `llama3.1-70b`
- `llama3.1-8b` (faster, less accurate)
- `mistral-large`

**Process:**
1. Extracts source fields from Bronze data
2. Gets target columns from target_schemas
3. Sends to LLM with prompt template
4. LLM returns JSON array of mappings with confidence scores
5. Validates mappings against target schema
6. Stores valid mappings

---

## Diagnostic Tools

### SQL Diagnostic Queries

Run these queries to check all prerequisites:

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA SILVER;

-- 1. Check procedures exist
SHOW PROCEDURES LIKE 'auto_map_fields_ml';
SHOW PROCEDURES LIKE 'auto_map_fields_llm';

-- 2. Check Bronze data
SELECT TPA, COUNT(*) as record_count
FROM BRONZE.RAW_DATA_TABLE
GROUP BY TPA;

-- 3. Check target schemas
SELECT table_name, COUNT(*) as column_count
FROM target_schemas
WHERE active = TRUE
GROUP BY table_name;

-- 4. Check LLM prompt template
SELECT * FROM llm_prompt_templates
WHERE template_id = 'DEFAULT_FIELD_MAPPING';

-- 5. Test ML mapping
CALL auto_map_fields_ml(
    'RAW_DATA_TABLE',
    'PHARMACY_CLAIMS',
    'provider_a',
    3,
    0.6
);

-- 6. Check created mappings
SELECT 
    mapping_method,
    COUNT(*) as count,
    AVG(confidence_score) as avg_confidence
FROM field_mappings
GROUP BY mapping_method;
```

### Manual Testing

**Test ML Mapping:**
```sql
CALL SILVER.auto_map_fields_ml(
    'RAW_DATA_TABLE',
    'PHARMACY_CLAIMS',
    'provider_a',
    3,    -- top_n
    0.6   -- min_confidence
);
```

**Test LLM Mapping:**
```sql
-- First test Cortex AI
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'claude-3-5-sonnet',
    'Say OK if you can read this.'
) as test_response;

-- Then test mapping
CALL SILVER.auto_map_fields_llm(
    'RAW_DATA_TABLE',
    'PHARMACY_CLAIMS',
    'provider_a',
    'claude-3-5-sonnet',
    'DEFAULT_FIELD_MAPPING'
);
```

**Check Results:**
```sql
SELECT 
    source_field,
    target_column,
    mapping_method,
    ROUND(confidence_score, 2) as confidence,
    approved
FROM SILVER.field_mappings
WHERE tpa = 'provider_a'
  AND target_table = 'PHARMACY_CLAIMS'
ORDER BY confidence_score DESC;
```

---

## API Reference

### Backend Endpoints

**Auto-Map ML:**
```http
POST /api/silver/mappings/auto-ml
Content-Type: application/json

{
  "source_table": "RAW_DATA_TABLE",
  "target_table": "PHARMACY_CLAIMS",
  "tpa": "provider_a",
  "top_n": 3,
  "min_confidence": 0.6
}

Response:
{
  "message": "Successfully generated 15 ML-based field mappings...",
  "result": "Successfully generated 15 ML-based field mappings...",
  "mappings_created": 15,
  "success": true
}
```

**Auto-Map LLM:**
```http
POST /api/silver/mappings/auto-llm
Content-Type: application/json

{
  "source_table": "RAW_DATA_TABLE",
  "target_table": "PHARMACY_CLAIMS",
  "tpa": "provider_a",
  "model_name": "claude-3-5-sonnet"
}

Response:
{
  "message": "Successfully generated 12 LLM-based field mappings...",
  "result": "Successfully generated 12 LLM-based field mappings...",
  "mappings_created": 12,
  "success": true
}
```

**Get Mappings:**
```http
GET /api/silver/mappings?tpa=provider_a&target_table=PHARMACY_CLAIMS

Response:
[
  {
    "mapping_id": 1,
    "source_field": "drug_name",
    "target_column": "DRUG_NAME",
    "mapping_method": "LLM_CORTEX",
    "confidence_score": 0.95,
    "approved": false,
    ...
  }
]
```

### Frontend API Service

```typescript
// ML Auto-Mapping
await apiService.autoMapFieldsML(
  sourceTable: string,
  targetTable: string,    // Schema table name (no TPA prefix)
  tpa: string,
  topN: number,
  minConfidence: number
)

// LLM Auto-Mapping
await apiService.autoMapFieldsLLM(
  sourceTable: string,
  targetTable: string,    // Schema table name (no TPA prefix)
  tpa: string,
  modelName: string
)

// Get Mappings
await apiService.getFieldMappings(
  tpa: string,
  targetTable: string     // Schema table name (no TPA prefix)
)

// Approve Mapping
await apiService.approveMapping(mappingId: string)

// Delete Mapping
await apiService.deleteMapping(mappingId: string | number)
```

---

## Performance Tips

### ML Auto-Mapping

- **Typical time:** 5-30 seconds
- **Max time:** 90 seconds
- **Optimize:**
  - Specify target_table (don't leave NULL)
  - Reduce top_n to 1-2 for faster results
  - Increase min_confidence to 0.7-0.8 for fewer matches

### LLM Auto-Mapping

- **Typical time:** 10-60 seconds
- **Max time:** 180 seconds
- **Optimize:**
  - Use smaller models (llama3.1-8b vs llama3.1-70b)
  - Process one table at a time
  - Add descriptions to target_schemas for better results

---

## Applying the Fixes

All fixes are already in the code. To apply:

```bash
# 1. Rebuild frontend
cd frontend
npm run build

# 2. Restart backend (if running)
cd backend
# Press Ctrl+C, then:
uvicorn app.main:app --reload

# 3. Clear browser cache
# Hard refresh: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (Mac)
```

Or with Docker:
```bash
docker-compose down
docker-compose up -d --build
```

---

## Verification Checklist

After applying fixes:

- [ ] Frontend rebuilt and restarted
- [ ] Backend restarted (if applicable)
- [ ] Browser cache cleared
- [ ] Auto-Map (ML) creates mappings
- [ ] Auto-Map (LLM) creates mappings
- [ ] Mappings display immediately after creation
- [ ] Manual mapping works
- [ ] Bulk approve works
- [ ] Bulk delete works
- [ ] No console errors in browser DevTools
- [ ] No "No target fields found" errors

---

## Related Files

- **Frontend:** `frontend/src/pages/SilverMappings.tsx`
- **Backend API:** `backend/app/api/silver.py`
- **Backend Service:** `backend/app/services/snowflake_service.py`
- **Frontend API:** `frontend/src/services/api.ts`
- **Procedures:** `silver/3_Silver_Mapping_Procedures.sql`
- **Schema Setup:** `silver/1_Silver_Schema_Setup.sql`

---

## Summary of Fixes

### Fix 1: Backend Response Parsing
- Added `mappings_created` count extraction
- Added `success` flag to response
- File: `backend/app/api/silver.py`

### Fix 2: Schema vs Physical Table Names (Main Fix)
- Extract schema table name before calling procedures
- Use schema name for querying mappings
- Files: `frontend/src/pages/SilverMappings.tsx` (4 functions)

### Fix 3: Missing deleteMapping Function
- Added missing `deleteMapping()` to API service
- File: `frontend/src/services/api.ts`

**Status:** ✅ All fixes complete and tested
