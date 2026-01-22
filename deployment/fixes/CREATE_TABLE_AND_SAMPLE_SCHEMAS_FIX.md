# Create Table UI and Sample Schemas Fix

**Date**: January 21, 2026  
**Issues Fixed**:
1. Create Table button not working (no schemas available)
2. Missing sample schemas for TPAs

**Status**: ✅ Fixed

---

## Problems

### Problem 1: Create Table Not Working

**Symptom:**
- "Create Table" drawer shows validation error
- Dropdown says "Please select table name"
- No tables available in dropdown
- Confusing user experience

**Root Cause:**
- No schema definitions exist in database
- Empty `tables` array causes dropdown to be empty
- Form validation fails because no selection possible
- No helpful error message explaining the issue

### Problem 2: No Sample Schemas

**Symptom:**
- Fresh deployment has no schema definitions
- Users must manually define all schemas
- Time-consuming setup process
- No examples to follow

**Root Cause:**
- Deployment doesn't include sample schema definitions
- No automated way to generate schemas for TPAs
- Missing sample data for demonstration

---

## Solutions Implemented

### Solution 1: Improved UI Messaging

**File Modified:** `frontend/src/pages/SilverSchemas.tsx`

**Changes:**
```typescript
<Form.Item
  name="table_name"
  label="Table Name"
  rules={[{ required: true, message: 'Please select table name' }]}
  help={tables.length === 0 ? "No schemas defined yet. Please add schema columns first using 'Add Column' button." : undefined}
  validateStatus={tables.length === 0 ? "warning" : undefined}
>
  <Select
    placeholder={tables.length === 0 ? "No tables available - add schema columns first" : "Select table to create"}
    options={tables.map(t => ({ label: t, value: t }))}
    showSearch
    disabled={tables.length === 0}
  />
</Form.Item>
```

**Benefits:**
- ✅ Clear error message when no schemas exist
- ✅ Dropdown disabled when empty
- ✅ Helpful guidance to add columns first
- ✅ Warning status indicator

### Solution 2: Sample Schema Generator

**File Created:** `sample_data/generate_sample_schemas.py`

**Features:**
- Generates schema definitions for 5 TPAs (provider_a through provider_e)
- Creates 4 table types:
  - `MEDICAL_CLAIMS` (14 columns)
  - `DENTAL_CLAIMS` (14 columns)
  - `PHARMACY_CLAIMS` (16 columns)
  - `MEMBER_ELIGIBILITY` (18 columns)
- Total: 310 schema definitions (62 columns × 5 TPAs)
- Outputs CSV file for bulk loading
- Generates SQL load script
- Creates README documentation

**Usage:**
```bash
cd /Users/tboon/code/bordereau
python3 sample_data/generate_sample_schemas.py
```

**Output Files:**
- `sample_data/config/silver_target_schemas.csv` - Schema definitions
- `sample_data/config/load_sample_schemas.sql` - SQL load script
- `sample_data/config/SAMPLE_SCHEMAS_README.md` - Documentation

### Solution 3: Automated Schema Loading

**File Created:** `deployment/load_sample_schemas.sh`

**Features:**
- Automated 3-step process:
  1. Generate sample schemas
  2. Upload to Snowflake stage
  3. Load into target_schemas table
- Verification of loaded schemas
- Error handling and rollback
- Progress indicators

**Usage:**
```bash
cd /Users/tboon/code/bordereau/deployment
./load_sample_schemas.sh [CONNECTION_NAME]
```

### Solution 4: Integration with Deployment

**File Modified:** `deployment/deploy.sh`

**Changes:**
- Added optional prompt to load sample schemas
- Integrated with main deployment flow
- Shows schema status in deployment summary
- Supports AUTO_APPROVE mode

**New Deployment Flow:**
```
1. Deploy Bronze Layer ✓
2. Deploy Silver Layer ✓
3. Load Sample Schemas? (optional) ← NEW
4. Deploy Gold Layer ✓
5. Deploy Containers? (optional)
```

---

## Sample Schema Structure

### Table Types Included

#### 1. MEDICAL_CLAIMS
```
- CLAIM_ID (VARCHAR)
- MEMBER_ID (VARCHAR)
- PROVIDER_ID (VARCHAR)
- SERVICE_DATE (DATE)
- DIAGNOSIS_CODE (VARCHAR)
- PROCEDURE_CODE (VARCHAR)
- BILLED_AMOUNT (NUMBER)
- ALLOWED_AMOUNT (NUMBER)
- PAID_AMOUNT (NUMBER)
- MEMBER_RESPONSIBILITY (NUMBER)
- CLAIM_STATUS (VARCHAR)
- PROCESSED_DATE (TIMESTAMP)
- CREATED_AT (TIMESTAMP)
```

#### 2. DENTAL_CLAIMS
```
- CLAIM_ID (VARCHAR)
- MEMBER_ID (VARCHAR)
- DENTIST_ID (VARCHAR)
- SERVICE_DATE (DATE)
- TOOTH_NUMBER (VARCHAR)
- PROCEDURE_CODE (VARCHAR)
- BILLED_AMOUNT (NUMBER)
- ALLOWED_AMOUNT (NUMBER)
- PAID_AMOUNT (NUMBER)
- ... (14 total columns)
```

#### 3. PHARMACY_CLAIMS
```
- CLAIM_ID (VARCHAR)
- MEMBER_ID (VARCHAR)
- PHARMACY_ID (VARCHAR)
- FILL_DATE (DATE)
- NDC_CODE (VARCHAR)
- DRUG_NAME (VARCHAR)
- QUANTITY (NUMBER)
- DAYS_SUPPLY (NUMBER)
- ... (16 total columns)
```

#### 4. MEMBER_ELIGIBILITY
```
- MEMBER_ID (VARCHAR)
- FIRST_NAME (VARCHAR)
- LAST_NAME (VARCHAR)
- DATE_OF_BIRTH (DATE)
- GENDER (VARCHAR)
- ADDRESS_LINE1 (VARCHAR)
- CITY (VARCHAR)
- STATE (VARCHAR)
- ZIP_CODE (VARCHAR)
- ... (18 total columns)
```

---

## Usage Guide

### For New Deployments

```bash
cd /Users/tboon/code/bordereau/deployment

# Deploy everything with sample schemas
./deploy.sh

# When prompted "Load sample schemas? (y/n) [y]:"
# Press Enter or type 'y'
```

### For Existing Deployments

```bash
cd /Users/tboon/code/bordereau/deployment

# Load sample schemas manually
./load_sample_schemas.sh DEPLOYMENT
```

### Using the UI

After loading schemas:

1. **Navigate to Silver Schemas page**
2. **Select a TPA** (e.g., provider_a)
3. **View available schemas** - You'll see 4 tables with all columns
4. **Create Table** - Click "Create Table" button
5. **Select table** - Choose from dropdown (now populated!)
6. **Confirm** - Click "Create Table" to create physical table

---

## Verification

### Check Loaded Schemas

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA SILVER;

-- Count schemas by TPA and table
SELECT 
    TPA,
    TABLE_NAME,
    COUNT(*) as COLUMN_COUNT
FROM target_schemas
GROUP BY TPA, TABLE_NAME
ORDER BY TPA, TABLE_NAME;
```

**Expected Output:**
```
provider_a | DENTAL_CLAIMS      | 14
provider_a | MEDICAL_CLAIMS     | 14
provider_a | MEMBER_ELIGIBILITY | 18
provider_a | PHARMACY_CLAIMS    | 16
... (20 rows total - 4 tables × 5 TPAs)
```

### Test Create Table in UI

1. Open application: `https://your-endpoint.snowflakecomputing.app`
2. Navigate to "Silver Schemas"
3. Select TPA: "provider_a"
4. Click "Create Table"
5. Select table: "MEDICAL_CLAIMS"
6. Click "Create Table" button
7. Verify table created successfully

---

## Customization

### Add More TPAs

Edit `sample_data/generate_sample_schemas.py`:

```python
# Add more TPAs
TPAS = ['provider_a', 'provider_b', 'provider_c', 'provider_d', 'provider_e', 'provider_f']
```

### Add More Table Types

```python
SAMPLE_SCHEMAS = {
    'MEDICAL_CLAIMS': [...],
    'DENTAL_CLAIMS': [...],
    'PHARMACY_CLAIMS': [...],
    'MEMBER_ELIGIBILITY': [...],
    'PROVIDER_DIRECTORY': [  # NEW
        ('PROVIDER_ID', 'VARCHAR(100)', False, None, 'Provider identifier'),
        ('PROVIDER_NAME', 'VARCHAR(500)', False, None, 'Provider name'),
        # ... more columns
    ],
}
```

### Modify Column Definitions

```python
'MEDICAL_CLAIMS': [
    ('CLAIM_ID', 'VARCHAR(100)', False, None, 'Unique claim identifier'),
    ('CUSTOM_FIELD', 'VARCHAR(200)', True, None, 'Your custom field'),  # ADD
    # ... rest of columns
]
```

Then regenerate:
```bash
python3 sample_data/generate_sample_schemas.py
./deployment/load_sample_schemas.sh
```

---

## Troubleshooting

### Issue: Schemas Not Showing in UI

**Solution:**
```bash
# Reload schemas in UI
1. Click "Reload" button
2. Or refresh browser page
```

### Issue: Create Table Still Disabled

**Cause:** Browser cache

**Solution:**
```bash
# Hard refresh
Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
```

### Issue: Duplicate Schemas

**Solution:**
```sql
-- Clear existing schemas first
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA SILVER;
TRUNCATE TABLE target_schemas;

-- Then reload
cd deployment
./load_sample_schemas.sh
```

### Issue: Wrong TPA Names

**Solution:**
```bash
# Edit generator script
nano sample_data/generate_sample_schemas.py

# Update TPAS list
TPAS = ['your_tpa_1', 'your_tpa_2', ...]

# Regenerate and reload
python3 sample_data/generate_sample_schemas.py
./deployment/load_sample_schemas.sh
```

---

## Files Created/Modified

### Created
1. `sample_data/generate_sample_schemas.py` - Schema generator
2. `sample_data/config/silver_target_schemas.csv` - Schema definitions
3. `sample_data/config/load_sample_schemas.sql` - Load script
4. `sample_data/config/SAMPLE_SCHEMAS_README.md` - Documentation
5. `deployment/load_sample_schemas.sh` - Automated loader
6. `deployment/fixes/CREATE_TABLE_AND_SAMPLE_SCHEMAS_FIX.md` - This file

### Modified
1. `frontend/src/pages/SilverSchemas.tsx` - Improved UI messaging
2. `deployment/deploy.sh` - Added optional schema loading

---

## Benefits

### For Users
- ✅ Clear error messages when schemas missing
- ✅ Helpful guidance on next steps
- ✅ Ready-to-use sample schemas
- ✅ No manual schema entry required
- ✅ Working examples to follow

### For Developers
- ✅ Automated schema generation
- ✅ Easy customization
- ✅ Integrated with deployment
- ✅ Repeatable process
- ✅ Version controlled schemas

### For Demonstrations
- ✅ Quick setup for demos
- ✅ Realistic sample data
- ✅ Multiple TPAs ready
- ✅ All claim types covered
- ✅ Professional appearance

---

## Next Steps

After loading schemas:

1. **Create Physical Tables**
   - Use "Create Table" button in UI
   - Creates actual Snowflake tables

2. **Define Field Mappings**
   - Navigate to "Field Mappings" page
   - Map Bronze fields to Silver columns

3. **Set Up Transformations**
   - Navigate to "Transformation Rules" page
   - Define data transformation logic

4. **Upload Sample Data**
   - Upload claim files to Bronze layer
   - Test end-to-end processing

---

## Related Documentation

- [Silver Layer README](../../silver/README.md)
- [Sample Data README](../../sample_data/README.md)
- [User Guide](../../docs/USER_GUIDE.md)
- [Deployment Guide](../README.md)

---

**Status**: ✅ Complete and Tested  
**Version**: 1.0  
**Last Updated**: January 21, 2026
