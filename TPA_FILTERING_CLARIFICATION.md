# TPA Filtering Clarification

**Date**: January 21, 2026  
**Status**: ✅ Working Correctly - Enhanced Visual Clarity

---

## Summary

The TPA filtering **IS working correctly**. The confusion arose because all providers have the same table names (DENTAL_CLAIMS, MEDICAL_CLAIMS, MEMBER_ELIGIBILITY, PHARMACY_CLAIMS), making it appear that the filter wasn't working when switching providers.

---

## Database Investigation

### TPA Codes

```sql
SELECT TPA_CODE, TPA_NAME 
FROM BRONZE.TPA_MASTER 
WHERE ACTIVE = TRUE;
```

**Result:**
```
provider_a | Provider A Healthcare
provider_b | Provider B Insurance
provider_c | Provider C Medical
provider_d | Provider D Dental
provider_e | Provider E Pharmacy
```

### Schema Distribution

```sql
SELECT tpa, table_name, COUNT(*) as column_count 
FROM SILVER.target_schemas 
WHERE active = TRUE 
GROUP BY tpa, table_name;
```

**Result:**
```
provider_a | DENTAL_CLAIMS      | 14
provider_a | MEDICAL_CLAIMS     | 14
provider_a | MEMBER_ELIGIBILITY | 18
provider_a | PHARMACY_CLAIMS    | 16

provider_b | DENTAL_CLAIMS      | 14
provider_b | MEDICAL_CLAIMS     | 14
provider_b | MEMBER_ELIGIBILITY | 18
provider_b | PHARMACY_CLAIMS    | 16

provider_c | DENTAL_CLAIMS      | 14
provider_c | MEDICAL_CLAIMS     | 14
provider_c | MEMBER_ELIGIBILITY | 18
provider_c | PHARMACY_CLAIMS    | 16

... (same pattern for provider_d and provider_e)
```

### Key Finding

**All providers have identical table names!**

This is by design - each provider has their own version of:
- DENTAL_CLAIMS
- MEDICAL_CLAIMS
- MEMBER_ELIGIBILITY
- PHARMACY_CLAIMS

The tables are differentiated by the `TPA` column in the database, not by the table name.

---

## Why It Appeared Broken

### User Experience

```
1. User selects "Provider A Healthcare"
   → Sees: DENTAL_CLAIMS, MEDICAL_CLAIMS, MEMBER_ELIGIBILITY, PHARMACY_CLAIMS

2. User switches to "Provider B Insurance"
   → Sees: DENTAL_CLAIMS, MEDICAL_CLAIMS, MEMBER_ELIGIBILITY, PHARMACY_CLAIMS
   
3. User thinks: "The tables didn't change! The filter isn't working!"
```

### Reality

The filter **IS working** - Provider B's tables are being shown. They just happen to have the same names as Provider A's tables because that's the standard schema structure.

**Provider A's DENTAL_CLAIMS ≠ Provider B's DENTAL_CLAIMS**

They are different tables with different data, just the same name.

---

## Solution: Enhanced Visual Clarity

### Changes Made

1. **Provider Name in Success Message**
   ```tsx
   message.success(`Loaded ${data.length} schema definitions for ${selectedTpaName}`)
   ```
   - Now shows: "Loaded 62 schema definitions for Provider B Insurance"
   - Makes it clear which provider's data was loaded

2. **Provider Name in Table Filter Placeholder**
   ```tsx
   placeholder={`Filter tables for ${selectedTpaName || 'selected provider'}`}
   ```
   - Shows: "Filter tables for Provider B Insurance"
   - Reinforces which provider's tables are being filtered

3. **Enhanced Schema Information Card**
   ```tsx
   <Descriptions.Item label="Provider">
     <strong style={{ fontSize: '16px', color: '#1890ff' }}>
       {selectedTpaName || selectedTpa}
     </strong>
   </Descriptions.Item>
   ```
   - Provider name is now prominent and highlighted
   - Larger font, blue color
   - Listed first in the information card

4. **Provider Context in Note**
   ```tsx
   <p>
     Target schemas define the structure of tables in the Silver layer 
     where transformed data will be stored for <strong>{selectedTpaName}</strong>.
   </p>
   ```
   - Reinforces which provider's schemas are being viewed

5. **Provider Tags on Each Table**
   - Already implemented
   - Each table shows: `[Provider B Insurance]` tag
   - Blue color for visibility

---

## Visual Improvements

### Before

```
Silver Target Schemas
Define target table structures for the Silver layer

[Filter dropdown: "All tables"]

▼ DENTAL_CLAIMS (14 columns)
▼ MEDICAL_CLAIMS (14 columns)
▼ MEMBER_ELIGIBILITY (18 columns)
▼ PHARMACY_CLAIMS (16 columns)

Schema Information
Total Tables: 4
Total Columns: 62
TPA: provider_b
```

**Problem**: Not obvious which provider's data is shown

### After

```
Silver Target Schemas [Provider B Insurance]
Define target table structures for the Silver layer

[Filter dropdown: "Filter tables for Provider B Insurance"]

▼ DENTAL_CLAIMS [Provider B Insurance] (14 columns)
▼ MEDICAL_CLAIMS [Provider B Insurance] (14 columns)
▼ MEMBER_ELIGIBILITY [Provider B Insurance] (18 columns)
▼ PHARMACY_CLAIMS [Provider B Insurance] (16 columns)

Schema Information
Provider: Provider B Insurance  ← Large, blue, prominent
Total Tables: 4
Total Columns: 62
TPA Code: provider_b

Note: Target schemas define the structure of tables in the 
Silver layer where transformed data will be stored for 
Provider B Insurance.
```

**Solution**: Provider name is everywhere, impossible to miss

---

## Backend Filtering Verification

### API Endpoint

```python
@router.get("/schemas")
async def get_target_schemas(tpa: str, table_name: Optional[str] = None):
    sf_service = SnowflakeService()
    return sf_service.get_target_schemas(tpa, table_name)
```

### Database Query

```python
def get_target_schemas(self, tpa: str, table_name: Optional[str] = None):
    query = f"""
        SELECT * 
        FROM SILVER.target_schemas
        WHERE tpa = '{tpa}' AND active = TRUE  ← Filtering by TPA!
        ORDER BY table_name, schema_id
    """
    return self.execute_query_dict(query)
```

### Logging Added

```python
logger.info(f"Getting target schemas for TPA: '{tpa}'")
logger.info(f"Available TPAs in database: {existing_tpas}")
logger.info(f"Found {len(result)} schema records for TPA '{tpa}'")
```

**Verification**: Backend is correctly filtering by TPA code.

---

## Frontend Filtering Verification

### State Management

```tsx
useEffect(() => {
  if (selectedTpa) {
    setSelectedTable('')  // Reset table filter
    setSchemas([])        // Clear current schemas
    setAllSchemas([])     // Clear all schemas
    loadSchemas()         // Load new provider's schemas
  }
}, [selectedTpa])  ← Triggers when provider changes
```

### API Call

```tsx
const loadSchemas = async () => {
  const data = await apiService.getTargetSchemas(selectedTpa)
  // selectedTpa is passed to backend
  setAllSchemas(data)
  setSchemas(data)
}
```

**Verification**: Frontend is correctly passing TPA code to backend.

---

## Testing Results

### Test 1: Check Provider A

```bash
curl "https://bordereau-app.bd3h.svc.spcs.internal/api/silver/schemas?tpa=provider_a"
```

**Result**: Returns 62 schemas for provider_a

### Test 2: Check Provider B

```bash
curl "https://bordereau-app.bd3h.svc.spcs.internal/api/silver/schemas?tpa=provider_b"
```

**Result**: Returns 62 schemas for provider_b

### Test 3: Verify Different Data

```sql
-- Provider A's DENTAL_CLAIMS
SELECT * FROM SILVER.target_schemas 
WHERE tpa = 'provider_a' AND table_name = 'DENTAL_CLAIMS';

-- Provider B's DENTAL_CLAIMS
SELECT * FROM SILVER.target_schemas 
WHERE tpa = 'provider_b' AND table_name = 'DENTAL_CLAIMS';
```

**Result**: Different schema_id values, confirming they are different records.

---

## Why Same Table Names?

### Standard Schema Structure

Healthcare data typically follows standard table structures:

- **DENTAL_CLAIMS**: Dental service claims
- **MEDICAL_CLAIMS**: Medical service claims
- **MEMBER_ELIGIBILITY**: Member enrollment/eligibility
- **PHARMACY_CLAIMS**: Prescription drug claims

**Every provider** has these same tables because:
1. Industry standard structure
2. Consistent data model across providers
3. Easier to write queries that work across all providers
4. Simplifies transformation logic

### Differentiation

Tables are differentiated by:
- **TPA column**: Which provider owns the data
- **Schema_ID**: Unique identifier for each schema definition
- **Data content**: Different providers have different data

---

## User Guidance

### When Switching Providers

**What to look for:**

1. **Success Message**
   - "Loaded 62 schema definitions for [Provider Name]"
   - Confirms data was loaded for the selected provider

2. **Provider Tags**
   - Each table shows `[Provider Name]` in blue
   - Confirms which provider's tables you're viewing

3. **Schema Information Card**
   - Provider name is large and blue at the top
   - Shows which provider's data is displayed

4. **Table Filter Placeholder**
   - "Filter tables for [Provider Name]"
   - Reinforces the current provider context

### Expected Behavior

✅ **Correct**: Seeing the same table names across providers  
✅ **Correct**: Provider name tags change when switching  
✅ **Correct**: Schema count stays the same (all providers have 4 tables)  
✅ **Correct**: Column count stays the same (standard structure)  

❌ **Incorrect**: Provider name tags don't change  
❌ **Incorrect**: No success message when switching  
❌ **Incorrect**: Schema Information shows wrong provider  

---

## Architecture Notes

### Why Not Different Table Names?

**Option 1 (Current)**: Same table names, different TPA
```
provider_a | DENTAL_CLAIMS
provider_b | DENTAL_CLAIMS
provider_c | DENTAL_CLAIMS
```

**Option 2 (Alternative)**: Different table names
```
DENTAL_CLAIMS_PROVIDER_A
DENTAL_CLAIMS_PROVIDER_B
DENTAL_CLAIMS_PROVIDER_C
```

**Why Option 1 is Better:**
- ✅ Cleaner data model
- ✅ Standard industry structure
- ✅ Easier to write provider-agnostic queries
- ✅ Simpler transformation logic
- ✅ Less code duplication

**Why Option 2 is Worse:**
- ❌ Table name explosion (4 tables × 5 providers = 20 tables)
- ❌ Hard to write queries across providers
- ❌ Code duplication for each provider
- ❌ Harder to add new providers

---

## Summary

### The Issue

User thought filtering wasn't working because table names stayed the same when switching providers.

### The Reality

Filtering **IS working correctly**. All providers have the same table names by design.

### The Solution

Enhanced visual clarity so it's obvious which provider's data is being viewed:
- Provider name in success messages
- Provider name in filter placeholders
- Prominent provider display in info card
- Provider tags on every table
- Provider context in notes

### The Result

Now impossible to miss which provider's data you're viewing, even though table names are the same.

---

## Files Changed

1. **`frontend/src/pages/SilverSchemas.tsx`**
   - Enhanced success message with provider name
   - Updated filter placeholder with provider name
   - Prominent provider display in Schema Information card
   - Provider context in notes

2. **`backend/app/services/snowflake_service.py`**
   - Added logging for TPA filtering
   - Added debug query to show available TPAs
   - Verified filtering logic

---

## Status

**Status**: ✅ Working Correctly  
**Enhancement**: ✅ Deployed  
**Endpoint**: https://bordereau-app.bd3h.svc.spcs.internal

**Filtering**: Working as designed  
**Visual Clarity**: Significantly improved  
**User Confusion**: Resolved

**Last Updated**: January 21, 2026
