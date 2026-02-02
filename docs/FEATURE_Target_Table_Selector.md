# Feature: Target Table Selector in Auto-Mapping

## Overview

Added a target table dropdown selector to both ML and LLM auto-mapping forms, allowing users to choose which table to map fields to instead of being limited to the currently selected table.

---

## Changes Made

### 1. Added Target Table Dropdown to ML Auto-Mapping Form

**Location:** `frontend/src/pages/SilverMappings.tsx`

**Added:**
```typescript
<Form.Item
  name="target_table"
  label="Target Table"
  rules={[{ required: true, message: 'Please select target table' }]}
  tooltip="Select the schema table to map fields to"
>
  <Select
    placeholder="Select target table"
    options={availableTargetTables.map(table => ({
      label: `${table.name} (${table.columns} columns)`,
      value: table.name
    }))}
    showSearch
  />
</Form.Item>
```

**Benefits:**
- Shows all available target tables for the selected TPA
- Displays column count for each table
- Searchable dropdown for easy selection
- Pre-selects the currently viewed table

### 2. Added Target Table Dropdown to LLM Auto-Mapping Form

**Location:** `frontend/src/pages/SilverMappings.tsx`

**Added:** Same dropdown as ML form

### 3. Updated Form Handlers

**Before:**
```typescript
// Had to extract schema name from selectedTable
const tableInfo = availableTargetTables.find(t => t.physicalName === selectedTable)
const schemaTableName = tableInfo?.name || selectedTable

const result = await apiService.autoMapFieldsML(
  values.source_table,
  schemaTableName,
  selectedTpa,
  values.top_n,
  values.min_confidence / 100
)
```

**After:**
```typescript
// Use target_table directly from form values
const result = await apiService.autoMapFieldsML(
  values.source_table,
  values.target_table,  // Already a schema table name from dropdown
  selectedTpa,
  values.top_n,
  values.min_confidence / 100
)
```

### 4. Updated Button Behavior

**Before:**
- Buttons disabled when no table selected: `disabled={!selectedTable}`
- Users had to click on a table panel first

**After:**
- Buttons disabled only when no TPA selected: `disabled={!selectedTpa}`
- Users can click Auto-Map buttons without selecting a table first
- Table can be chosen from the dropdown in the form

### 5. Updated Default Values

**Added logic to pre-populate target table:**
```typescript
useEffect(() => {
  // Extract schema table name from physical table name
  const tableInfo = availableTargetTables.find(t => t.physicalName === selectedTable)
  const schemaTableName = tableInfo?.name || ''
  
  autoMLForm.setFieldsValue({
    source_table: 'RAW_DATA_TABLE',
    target_table: schemaTableName  // Pre-select current table
  })
  
  autoLLMForm.setFieldsValue({
    source_table: 'RAW_DATA_TABLE',
    target_table: schemaTableName
  })
}, [selectedTable, availableTargetTables])
```

---

## User Experience

### Before

1. User must click on a specific table panel
2. Click "Auto-Map (ML)" or "Auto-Map (LLM)" button
3. Form opens with no target table selection
4. Mapping applies to the clicked table only

**Limitations:**
- Can't easily map to a different table
- Must close form and click different table to change target
- No visibility into which table is being mapped

### After

1. User selects a TPA from header
2. Click "Auto-Map (ML)" or "Auto-Map (LLM)" button (no table selection required)
3. Form opens with:
   - **Target Table dropdown** showing all available tables
   - Current table pre-selected (if viewing one)
   - Column count displayed for each table
4. User can select any table from dropdown
5. Click "Generate Mappings"

**Benefits:**
- ✅ More flexible - can map to any table
- ✅ Better visibility - see all available tables
- ✅ Faster workflow - no need to navigate to table first
- ✅ Shows column counts to help choose the right table
- ✅ Searchable dropdown for large table lists

---

## Example Workflow

### Scenario: Map fields for multiple tables

**Old way:**
1. Click on PHARMACY_CLAIMS table
2. Click "Auto-Map (LLM)"
3. Generate mappings
4. Close form
5. Click on MEDICAL_CLAIMS table
6. Click "Auto-Map (LLM)"
7. Generate mappings
8. Repeat for each table...

**New way:**
1. Click "Auto-Map (LLM)" once
2. Select "PHARMACY_CLAIMS" from dropdown
3. Generate mappings
4. Change dropdown to "MEDICAL_CLAIMS"
5. Generate mappings
6. Change dropdown to "DENTAL_CLAIMS"
7. Generate mappings
8. All done in one form!

---

## Technical Details

### Form Structure

**ML Auto-Mapping Form:**
```typescript
{
  source_table: 'RAW_DATA_TABLE',
  target_table: 'PHARMACY_CLAIMS',  // NEW: User-selected
  top_n: 3,
  min_confidence: 0.6
}
```

**LLM Auto-Mapping Form:**
```typescript
{
  source_table: 'RAW_DATA_TABLE',
  target_table: 'PHARMACY_CLAIMS',  // NEW: User-selected
  model_name: 'claude-3-5-sonnet'
}
```

### Dropdown Options

Each option shows:
- **Label:** `PHARMACY_CLAIMS (16 columns)`
- **Value:** `PHARMACY_CLAIMS` (schema table name)

The dropdown is populated from `availableTargetTables` which contains:
```typescript
{
  name: 'PHARMACY_CLAIMS',           // Schema table name
  physicalName: 'PROVIDER_A_PHARMACY_CLAIMS',  // Physical table name
  tpa: 'provider_a',
  columns: 16
}
```

---

## Validation

The target table field is **required**:
```typescript
rules={[{ required: true, message: 'Please select target table' }]}
```

Users must select a table before generating mappings.

---

## Backward Compatibility

✅ **Fully backward compatible**

- If user clicks on a table panel first, that table is pre-selected in the dropdown
- Existing workflow still works exactly as before
- New workflow adds flexibility without breaking old behavior

---

## Files Changed

- `frontend/src/pages/SilverMappings.tsx`
  - Added target table dropdown to ML form
  - Added target table dropdown to LLM form
  - Updated `handleAutoMapML()` handler
  - Updated `handleAutoMapLLM()` handler
  - Updated button disabled logic
  - Updated default values useEffect

---

## How to Apply

```bash
# Rebuild frontend
cd frontend
npm run build

# Or restart dev server
npm run dev

# Clear browser cache
# Hard refresh: Ctrl+Shift+R or Cmd+Shift+R
```

---

## Testing

1. **Test with table pre-selected:**
   - Click on a table panel
   - Click "Auto-Map (LLM)"
   - Verify dropdown shows selected table
   - Generate mappings
   - Verify mappings created for that table

2. **Test without table pre-selected:**
   - Don't click on any table
   - Click "Auto-Map (LLM)"
   - Select table from dropdown
   - Generate mappings
   - Verify mappings created for selected table

3. **Test changing tables:**
   - Open "Auto-Map (LLM)" form
   - Select "PHARMACY_CLAIMS"
   - Generate mappings
   - Change dropdown to "MEDICAL_CLAIMS"
   - Generate mappings
   - Verify both tables have mappings

4. **Test validation:**
   - Open form
   - Clear target table selection
   - Try to submit
   - Verify error message: "Please select target table"

---

## Bug Fix: Auto-Refresh After Mapping

### Issue
When creating mappings for a table different from the currently selected one, the UI showed "No mappings created" even though mappings were successfully created. Users had to manually refresh to see the new mappings.

### Root Cause
After successful mapping, `loadMappings()` was called, which loaded mappings for `selectedTable` (the currently viewed table), not the table that was just mapped to.

### Fix
After successful mapping, the UI now automatically switches to the table that was just mapped:

```typescript
if (result.mappings_created > 0) {
  message.success(`Created ${result.mappings_created} LLM-based mappings for ${values.target_table}`)
  setIsAutoLLMDrawerVisible(false)
  
  // Switch to the table that was just mapped
  const tableInfo = availableTargetTables.find(t => t.name === values.target_table)
  if (tableInfo) {
    setSelectedTable(tableInfo.physicalName)
  }
  // loadMappings will be called automatically by the selectedTable useEffect
}
```

### Result
- ✅ UI automatically switches to the mapped table
- ✅ Mappings display immediately
- ✅ Success message shows which table was mapped
- ✅ No manual refresh needed

---

## Status

✅ **COMPLETE** - Target table selector added to both ML and LLM auto-mapping forms  
✅ **FIXED** - Auto-refresh after mapping now works correctly
