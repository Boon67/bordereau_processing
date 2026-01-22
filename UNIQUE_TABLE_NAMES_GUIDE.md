# Unique Table Names Per TPA - Implementation Guide

**Date**: January 21, 2026  
**Topic**: Each TPA should have uniquely named tables  
**Status**: 📋 Implementation Guide

---

## Current Situation

### Current Schema Structure

All TPAs currently share the same table names:

```
provider_a:
  - DENTAL_CLAIMS
  - MEDICAL_CLAIMS
  - MEMBER_ELIGIBILITY
  - PHARMACY_CLAIMS

provider_b:
  - DENTAL_CLAIMS
  - MEDICAL_CLAIMS
  - MEMBER_ELIGIBILITY
  - PHARMACY_CLAIMS

... (same for all providers)
```

**Issue**: This creates confusion because:
- Table names appear identical across providers
- Users can't tell which provider a table belongs to at a glance
- Harder to manage and distinguish provider-specific schemas

---

## Recommended Approach

### Option 1: TPA Prefix (Recommended)

Add TPA identifier as prefix to table names:

```
provider_a:
  - PROVIDER_A_DENTAL_CLAIMS
  - PROVIDER_A_MEDICAL_CLAIMS
  - PROVIDER_A_MEMBER_ELIGIBILITY
  - PROVIDER_A_PHARMACY_CLAIMS

provider_b:
  - PROVIDER_B_DENTAL_CLAIMS
  - PROVIDER_B_MEDICAL_CLAIMS
  - PROVIDER_B_MEMBER_ELIGIBILITY
  - PROVIDER_B_PHARMACY_CLAIMS
```

**Benefits**:
- ✅ Unique table names
- ✅ Clear ownership at a glance
- ✅ Easy to identify provider
- ✅ Consistent naming pattern

**Drawbacks**:
- Longer table names
- Need to update existing schemas

### Option 2: TPA-Specific Names

Each TPA defines their own unique table names:

```
provider_a (Healthcare):
  - HEALTHCARE_DENTAL
  - HEALTHCARE_MEDICAL
  - HEALTHCARE_ELIGIBILITY
  - HEALTHCARE_PHARMACY

provider_b (Insurance):
  - INSURANCE_DENTAL_CLAIMS
  - INSURANCE_MEDICAL_CLAIMS
  - INSURANCE_MEMBER_DATA
  - INSURANCE_RX_CLAIMS
```

**Benefits**:
- ✅ Unique table names
- ✅ Provider-specific naming
- ✅ Flexible structure

**Drawbacks**:
- Inconsistent naming across providers
- Harder to write cross-provider queries
- More complex to manage

### Option 3: Provider Name Prefix

Use human-readable provider name:

```
Provider A Healthcare:
  - PROVIDER_A_HEALTHCARE_DENTAL_CLAIMS
  - PROVIDER_A_HEALTHCARE_MEDICAL_CLAIMS
  - PROVIDER_A_HEALTHCARE_ELIGIBILITY
  - PROVIDER_A_HEALTHCARE_PHARMACY_CLAIMS

Provider B Insurance:
  - PROVIDER_B_INSURANCE_DENTAL_CLAIMS
  - PROVIDER_B_INSURANCE_MEDICAL_CLAIMS
  - PROVIDER_B_INSURANCE_ELIGIBILITY
  - PROVIDER_B_INSURANCE_PHARMACY_CLAIMS
```

**Benefits**:
- ✅ Very clear ownership
- ✅ Human-readable
- ✅ Unique names

**Drawbacks**:
- Very long table names
- Redundant information

---

## Implementation Steps

### Step 1: Choose Naming Convention

**Recommended**: Option 1 (TPA Prefix)

**Format**: `{TPA_CODE}_{TABLE_NAME}`

**Examples**:
- `PROVIDER_A_DENTAL_CLAIMS`
- `PROVIDER_B_MEDICAL_CLAIMS`
- `PROVIDER_C_MEMBER_ELIGIBILITY`

### Step 2: Update UI to Enforce Unique Names

**Add Schema Form**:

```tsx
<Form.Item
  name="table_name"
  label="Table Name"
  rules={[
    { required: true, message: 'Please enter table name' },
    {
      validator: async (_, value) => {
        if (value && !value.startsWith(selectedTpa.toUpperCase() + '_')) {
          throw new Error(`Table name must start with ${selectedTpa.toUpperCase()}_`)
        }
      }
    }
  ]}
>
  <Input 
    placeholder={`e.g., ${selectedTpa.toUpperCase()}_MEDICAL_CLAIMS`}
    prefix={`${selectedTpa.toUpperCase()}_`}
  />
</Form.Item>
```

**Auto-prefix Feature**:

```tsx
const handleAddSchema = () => {
  createTableForm.resetFields()
  // Pre-fill with TPA prefix
  createTableForm.setFieldsValue({
    table_name: `${selectedTpa.toUpperCase()}_`
  })
  setIsDrawerVisible(true)
}
```

### Step 3: Add Backend Validation

```python
@router.post("/schemas")
async def create_target_schema(schema: TargetSchemaCreate):
    """Create target schema definition"""
    
    # Validate table name starts with TPA prefix
    expected_prefix = f"{schema.tpa.upper()}_"
    if not schema.table_name.upper().startswith(expected_prefix):
        raise HTTPException(
            status_code=400,
            detail=f"Table name must start with {expected_prefix}"
        )
    
    # Check for uniqueness across all TPAs
    check_query = f"""
        SELECT COUNT(*) as count
        FROM SILVER.target_schemas
        WHERE table_name = '{schema.table_name.upper()}'
          AND tpa != '{schema.tpa}'
          AND active = TRUE
    """
    result = sf_service.execute_query_dict(check_query)
    
    if result[0]['COUNT'] > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Table name '{schema.table_name}' is already used by another TPA"
        )
    
    # Create schema
    ...
```

### Step 4: Migration Script

Create script to rename existing tables:

```sql
-- Backup current schemas
CREATE TABLE SILVER.target_schemas_backup AS
SELECT * FROM SILVER.target_schemas;

-- Update table names with TPA prefix
UPDATE SILVER.target_schemas
SET table_name = tpa || '_' || table_name
WHERE table_name NOT LIKE '%\_%'  -- Only if not already prefixed
  AND active = TRUE;

-- Verify updates
SELECT tpa, table_name, COUNT(*) as columns
FROM SILVER.target_schemas
WHERE active = TRUE
GROUP BY tpa, table_name
ORDER BY tpa, table_name;
```

### Step 5: Update Documentation

Update all documentation to reflect new naming convention:

- User guides
- API documentation
- Example schemas
- Training materials

---

## Migration Plan

### Phase 1: Preparation (Week 1)

1. **Communicate Change**
   - Notify all users
   - Explain new naming convention
   - Provide examples

2. **Update Documentation**
   - Update user guide
   - Update API docs
   - Create migration guide

3. **Test in Development**
   - Test migration script
   - Test UI changes
   - Test backend validation

### Phase 2: Implementation (Week 2)

1. **Deploy UI Changes**
   - Add prefix validation
   - Add auto-prefix feature
   - Update placeholders

2. **Deploy Backend Changes**
   - Add validation
   - Add uniqueness check
   - Update error messages

3. **Run Migration**
   - Backup existing data
   - Run migration script
   - Verify results

### Phase 3: Verification (Week 3)

1. **Verify Data**
   - Check all tables renamed
   - Verify no duplicates
   - Test queries

2. **User Testing**
   - Test creating new schemas
   - Test editing existing schemas
   - Verify error handling

3. **Monitor**
   - Watch for issues
   - Collect feedback
   - Address problems

---

## Example: Before and After

### Before Migration

```sql
SELECT tpa, table_name, COUNT(*) as columns
FROM SILVER.target_schemas
WHERE active = TRUE
GROUP BY tpa, table_name;
```

**Result**:
```
provider_a | DENTAL_CLAIMS      | 14
provider_a | MEDICAL_CLAIMS     | 14
provider_b | DENTAL_CLAIMS      | 14  ← Same name!
provider_b | MEDICAL_CLAIMS     | 14  ← Same name!
```

### After Migration

```sql
SELECT tpa, table_name, COUNT(*) as columns
FROM SILVER.target_schemas
WHERE active = TRUE
GROUP BY tpa, table_name;
```

**Result**:
```
provider_a | PROVIDER_A_DENTAL_CLAIMS      | 14
provider_a | PROVIDER_A_MEDICAL_CLAIMS     | 14
provider_b | PROVIDER_B_DENTAL_CLAIMS      | 14  ← Unique!
provider_b | PROVIDER_B_MEDICAL_CLAIMS     | 14  ← Unique!
```

---

## UI Changes

### Add Schema Form - Before

```
┌─────────────────────────────────────────┐
│ Add Silver Schema                       │
├─────────────────────────────────────────┤
│ Table Name:                             │
│ [                                    ]  │
│ e.g., MEDICAL_CLAIMS                    │
└─────────────────────────────────────────┘
```

### Add Schema Form - After

```
┌─────────────────────────────────────────┐
│ Add Silver Schema                       │
├─────────────────────────────────────────┤
│ Table Name:                             │
│ [PROVIDER_A_                         ]  │
│ e.g., PROVIDER_A_MEDICAL_CLAIMS         │
│                                         │
│ ℹ️ Table name must start with          │
│    PROVIDER_A_ for this TPA            │
└─────────────────────────────────────────┘
```

---

## Benefits of Unique Names

### 1. Clarity

**Before**: "Is this MEDICAL_CLAIMS for Provider A or Provider B?"  
**After**: "This is PROVIDER_A_MEDICAL_CLAIMS, clearly for Provider A"

### 2. No Confusion

**Before**: All providers show same table names  
**After**: Each provider has distinct table names

### 3. Better Queries

**Before**:
```sql
SELECT * FROM SILVER.MEDICAL_CLAIMS WHERE tpa = 'provider_a'
```

**After**:
```sql
SELECT * FROM SILVER.PROVIDER_A_MEDICAL_CLAIMS
```

### 4. Easier Management

**Before**: Need to always check TPA column  
**After**: Table name tells you the provider

### 5. Prevents Mistakes

**Before**: Easy to query wrong provider's data  
**After**: Table name makes it obvious

---

## Code Examples

### Frontend Validation

```tsx
const validateTableName = (tableName: string, tpa: string): boolean => {
  const prefix = `${tpa.toUpperCase()}_`
  
  if (!tableName.startsWith(prefix)) {
    message.error(`Table name must start with ${prefix}`)
    return false
  }
  
  return true
}
```

### Backend Validation

```python
def validate_table_name(table_name: str, tpa: str) -> bool:
    """Validate table name follows naming convention"""
    expected_prefix = f"{tpa.upper()}_"
    
    if not table_name.upper().startswith(expected_prefix):
        raise ValueError(
            f"Table name must start with {expected_prefix}"
        )
    
    return True
```

### Migration Script

```sql
-- Function to add TPA prefix
CREATE OR REPLACE FUNCTION add_tpa_prefix(
    tpa VARCHAR,
    table_name VARCHAR
)
RETURNS VARCHAR
AS
$$
    CASE
        WHEN table_name LIKE tpa || '_%' THEN table_name
        ELSE tpa || '_' || table_name
    END
$$;

-- Update all table names
UPDATE SILVER.target_schemas
SET table_name = add_tpa_prefix(tpa, table_name)
WHERE active = TRUE;
```

---

## Rollback Plan

If issues arise, rollback is straightforward:

```sql
-- Restore from backup
DELETE FROM SILVER.target_schemas;

INSERT INTO SILVER.target_schemas
SELECT * FROM SILVER.target_schemas_backup;

-- Verify restoration
SELECT COUNT(*) FROM SILVER.target_schemas;
SELECT COUNT(*) FROM SILVER.target_schemas_backup;
```

---

## Testing Checklist

### Pre-Migration

- [ ] Backup all schema data
- [ ] Test migration script in dev
- [ ] Verify UI changes work
- [ ] Test backend validation
- [ ] Document rollback procedure

### During Migration

- [ ] Run migration script
- [ ] Verify all tables renamed
- [ ] Check for duplicates
- [ ] Test queries still work
- [ ] Verify UI displays correctly

### Post-Migration

- [ ] Test creating new schemas
- [ ] Test editing existing schemas
- [ ] Test deleting schemas
- [ ] Verify validation works
- [ ] User acceptance testing

---

## Status

**Status**: 📋 Implementation Guide  
**Recommendation**: Option 1 (TPA Prefix)  
**Next Steps**: 
1. Get stakeholder approval
2. Schedule migration
3. Implement UI/backend changes
4. Run migration script
5. Verify and monitor

**Last Updated**: January 21, 2026
