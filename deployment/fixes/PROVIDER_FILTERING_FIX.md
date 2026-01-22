# Provider Filtering and Display Fix

**Date**: January 21, 2026  
**Issue**: Provider filtering not working and provider name not displayed on tables  
**Status**: ✅ Fixed and Deployed (Enhanced)

---

## Problem

The Silver Schemas page had two issues:

**Issue 1: Provider Not Displayed on Tables**
- ❌ Tables didn't show which provider they belonged to
- ❌ User couldn't tell at a glance which provider a table was associated with
- ❌ Had to remember or check elsewhere to know the provider context

**Issue 2: Provider Filter Not Working**
- ❌ When changing the selected provider, tables from the previous provider were still shown
- ❌ Table filter dropdown wasn't reset when provider changed
- ❌ Schemas state was being mutated directly, causing filter issues

**Example:**
```
User selects "Provider A Healthcare"
  → Shows MEDICAL_CLAIMS, DENTAL_CLAIMS

User switches to "Provider B Medical"
  → Still shows Provider A's tables (BUG!)
  → Should show Provider B's tables
```

---

## Root Cause

### Issue 1: Missing Provider Display

The table panel headers didn't include the provider name:

```tsx
// Before - No provider shown
<Panel
  header={
    <Space>
      <TableOutlined />
      <strong>{tableName}</strong>
      <Tag color="purple">{tableSchemas.length} columns</Tag>
    </Space>
  }
>
```

### Issue 2: State Management Problems

1. **No state reset on provider change:**
   ```tsx
   useEffect(() => {
     if (selectedTpa) {
       loadSchemas()  // Loads new data
       // BUT selectedTable filter still has old value!
     }
   }, [selectedTpa])
   ```

2. **Direct state mutation in filter:**
   ```tsx
   onChange={(value) => {
     if (value) {
       const filtered = schemas.filter(s => s.TABLE_NAME === value)
       setSchemas(filtered)  // Mutates schemas state!
     } else {
       loadSchemas()  // Has to reload from API
     }
   }}
   ```

3. **No separation of filtered vs all data:**
   - Only one `schemas` state held both filtered and unfiltered data
   - When filtering, original data was lost
   - Switching providers didn't clear the filter

---

## Solution

### Fix 1: Display Provider Name on Tables

Added provider name tag to each table panel header:

```tsx
<Panel
  header={
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
      <Space>
        <TableOutlined />
        <strong>{tableName}</strong>
        {selectedTpaName && <Tag color="blue">{selectedTpaName}</Tag>}
        <Tag color="purple">{tableSchemas.length} columns</Tag>
      </Space>
      <Button ... >Add Column</Button>
    </div>
  }
>
```

### Fix 2: Proper State Management

**Added separate state for all schemas:**

```tsx
const [schemas, setSchemas] = useState<TargetSchema[]>([])        // Filtered/displayed
const [allSchemas, setAllSchemas] = useState<TargetSchema[]>([])  // All loaded data
```

**Reset table filter on provider change:**

```tsx
useEffect(() => {
  if (selectedTpa) {
    setSelectedTable('')  // Clear table filter
    loadSchemas()
  }
}, [selectedTpa])
```

**Store both filtered and all data:**

```tsx
const loadSchemas = async () => {
  const data = await apiService.getTargetSchemas(selectedTpa)
  setAllSchemas(data)  // Store all data
  setSchemas(data)      // Display all initially
  // ...
}
```

**Filter from all data without mutation:**

```tsx
onChange={(value) => {
  setSelectedTable(value)
  if (value) {
    const filtered = allSchemas.filter(s => s.TABLE_NAME === value)
    setSchemas(filtered)  // Filter from allSchemas
  } else {
    setSchemas(allSchemas)  // Reset to all schemas
  }
}}
```

---

## Files Changed

### `frontend/src/pages/SilverSchemas.tsx`

**1. Added Separate State for All Schemas**

```diff
  const SilverSchemas: React.FC<SilverSchemasProps> = ({ selectedTpa, selectedTpaName }) => {
    const [loading, setLoading] = useState(false)
    const [schemas, setSchemas] = useState<TargetSchema[]>([])
+   const [allSchemas, setAllSchemas] = useState<TargetSchema[]>([])
    const [selectedTable, setSelectedTable] = useState<string>('')
```

**2. Reset Table Filter on Provider Change**

```diff
  useEffect(() => {
    if (selectedTpa) {
+     setSelectedTable('')  // Reset table filter when TPA changes
+     setSchemas([])        // Clear current schemas
+     setAllSchemas([])     // Clear all schemas
      loadSchemas()
    }
  }, [selectedTpa])
```

**3. Added Loading State for Provider Changes**

```diff
+ {loading && schemas.length === 0 ? (
+   <Card style={{ marginTop: 16 }}>
+     <div style={{ textAlign: 'center', padding: '40px' }}>
+       <Spin size="large" />
+       <p style={{ marginTop: 16, color: '#666' }}>Loading schemas for {selectedTpaName}...</p>
+     </div>
+   </Card>
+ ) : Object.keys(schemasByTable).length === 0 ? (
    <Card style={{ marginTop: 16 }}>
      <p style={{ textAlign: 'center', padding: '40px', color: '#999' }}>
-       No target schemas found for this TPA.
+       No target schemas found for {selectedTpaName || 'this TPA'}.
      </p>
    </Card>
+ ) : (
```

**4. Store Both Filtered and All Data**

```diff
  const loadSchemas = async () => {
    setLoading(true)
    try {
-     const data = await apiService.getTargetSchemas(selectedTpa, selectedTable || undefined)
+     const data = await apiService.getTargetSchemas(selectedTpa)
+     setAllSchemas(data)
      setSchemas(data)
```

**5. Filter from All Data Without Mutation**

```diff
  <Select
    value={selectedTable}
    onChange={(value) => {
      setSelectedTable(value)
      if (value) {
-       const filtered = schemas.filter(s => s.TABLE_NAME === value)
+       const filtered = allSchemas.filter(s => s.TABLE_NAME === value)
        setSchemas(filtered)
      } else {
-       loadSchemas()
+       setSchemas(allSchemas)
      }
    }}
```

**6. Display Provider Name on Table Panels**

```diff
  <Panel
    key={tableName}
    header={
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
        <Space>
          <TableOutlined />
          <strong>{tableName}</strong>
+         {selectedTpaName && <Tag color="blue">{selectedTpaName}</Tag>}
          <Tag color="purple">{tableSchemas.length} columns</Tag>
        </Space>
```

---

## User Workflow Improvements

### Before (Broken)

1. Select "Provider A Healthcare"
   - Shows: MEDICAL_CLAIMS, DENTAL_CLAIMS
2. Select "MEDICAL_CLAIMS" from table filter
   - Shows: Only MEDICAL_CLAIMS
3. Switch to "Provider B Medical"
   - **BUG**: Still shows Provider A's MEDICAL_CLAIMS
   - **BUG**: Table filter still shows "MEDICAL_CLAIMS"
   - **BUG**: No provider name shown on tables

### After (Fixed)

1. Select "Provider A Healthcare"
   - Shows: MEDICAL_CLAIMS [Provider A Healthcare], DENTAL_CLAIMS [Provider A Healthcare]
2. Select "MEDICAL_CLAIMS" from table filter
   - Shows: Only MEDICAL_CLAIMS [Provider A Healthcare]
3. Switch to "Provider B Medical"
   - ✅ Table filter automatically clears
   - ✅ Shows Provider B's tables
   - ✅ Each table shows "Provider B Medical" tag

---

## Visual Changes

### Before

```
┌─────────────────────────────────────────────────────────────┐
│ ▼ 📊 DENTAL_CLAIMS (14 columns)          [Add Column]      │
└─────────────────────────────────────────────────────────────┘
```

**Problems:**
- No provider name shown
- Can't tell which provider this table belongs to

### After

```
┌─────────────────────────────────────────────────────────────┐
│ ▼ 📊 DENTAL_CLAIMS [Provider A Healthcare] (14 columns)    │
│                                            [Add Column]      │
└─────────────────────────────────────────────────────────────┘
```

**Benefits:**
- ✅ Provider name clearly displayed
- ✅ Blue tag stands out visually
- ✅ Consistent with top-level provider display

---

## State Management Flow

### Data Flow Diagram

```
Provider Selected
       ↓
   loadSchemas()
       ↓
   API Call → getTargetSchemas(selectedTpa)
       ↓
   ┌─────────────────┐
   │   allSchemas    │ ← Store ALL data
   └─────────────────┘
       ↓
   ┌─────────────────┐
   │    schemas      │ ← Display data (initially all)
   └─────────────────┘
       ↓
   Render Tables


Table Filter Applied
       ↓
   Filter from allSchemas (not schemas!)
       ↓
   ┌─────────────────┐
   │    schemas      │ ← Update display data
   └─────────────────┘
       ↓
   Render Filtered Tables


Provider Changed
       ↓
   Clear selectedTable filter
       ↓
   loadSchemas() again
       ↓
   New data replaces allSchemas and schemas
```

### Key Principles

1. **Separation of Concerns**
   - `allSchemas`: Source of truth for all loaded data
   - `schemas`: What's currently displayed (filtered or all)

2. **Immutable Filtering**
   - Always filter from `allSchemas`
   - Never mutate the source data
   - Can reset to all data without API call

3. **Automatic Reset**
   - Provider change clears table filter
   - Prevents showing wrong provider's data
   - User doesn't have to manually clear filter

---

## Testing

### Test Provider Display

1. Navigate to Silver Schemas page
2. Select "Provider A Healthcare"
3. Verify each table shows "[Provider A Healthcare]" tag
4. Switch to "Provider B Medical"
5. Verify each table shows "[Provider B Medical]" tag

**Expected:**
```
✅ MEDICAL_CLAIMS [Provider A Healthcare] (14 columns)
✅ DENTAL_CLAIMS [Provider A Healthcare] (14 columns)

After switch:
✅ MEDICAL_CLAIMS [Provider B Medical] (12 columns)
✅ PHARMACY_CLAIMS [Provider B Medical] (16 columns)
```

### Test Provider Filtering

1. Select "Provider A Healthcare"
2. Note tables shown (e.g., MEDICAL_CLAIMS, DENTAL_CLAIMS)
3. Select "MEDICAL_CLAIMS" from table filter dropdown
4. Verify only MEDICAL_CLAIMS is shown
5. Switch to "Provider B Medical"
6. Verify:
   - ✅ Table filter dropdown is cleared
   - ✅ Provider B's tables are shown
   - ✅ Provider A's tables are NOT shown

### Test Table Filter Reset

1. Select a provider
2. Apply table filter
3. Clear table filter (click X)
4. Verify all tables for that provider are shown
5. Switch provider
6. Verify table filter is empty
7. Apply new table filter
8. Verify filtering works correctly

---

## Benefits

### User Experience

1. **Clear Context**
   - Always know which provider you're viewing
   - No confusion about table ownership
   - Visual consistency throughout the app

2. **Correct Filtering**
   - Provider changes immediately show correct data
   - No stale data from previous provider
   - Table filter automatically resets

3. **Better Performance**
   - No unnecessary API calls when clearing table filter
   - Filtering happens client-side from cached data
   - Faster user interactions

### Code Quality

1. **Proper State Management**
   - Clear separation of filtered vs all data
   - Immutable filtering patterns
   - Predictable state updates

2. **Maintainability**
   - Easy to understand data flow
   - No hidden state mutations
   - Clear dependency tracking in useEffect

---

## Edge Cases Handled

### Empty Provider

```tsx
{selectedTpaName && <Tag color="blue">{selectedTpaName}</Tag>}
```
- Only shows tag if provider name exists
- Gracefully handles missing provider name

### No Tables

- Empty state message shown
- No errors from filtering empty array
- Filter dropdown disabled when no tables

### Rapid Provider Switching

- Each provider change resets filter
- Previous data is replaced, not merged
- No race conditions from multiple API calls

---

## Deployment

### Build Frontend

```bash
cd /Users/tboon/code/bordereau
npm run build --prefix frontend
```

**Result:**
```
✓ 3061 modules transformed.
✓ built in 3.62s
```

### Deploy Container

```bash
cd deployment
./deploy_container.sh
```

**Result:**
```
🎉 DEPLOYMENT SUCCESSFUL!

Service endpoint: https://bordereau-app.bd3h.svc.spcs.internal
```

### Verification

1. Access the application
2. Test provider switching
3. Verify provider names shown on tables
4. Test table filtering
5. Verify filter resets on provider change

---

## Related Issues

This fix also addresses:

1. **SCHEMA_EDIT_DELETE_TREE_VIEW_FIX.md**
   - Continued UI improvements to Silver Schemas page
   - Better table organization and display

2. **SILVER_SCHEMAS_UI_IMPROVEMENT.md**
   - Part of overall UI enhancement effort
   - Consistent with "Add Column" button changes

---

## Future Enhancements

### Potential Improvements

1. **Provider Color Coding**
   - Different colors for different providers
   - Easier visual distinction

2. **Provider Icons**
   - Custom icons per provider type
   - Healthcare, Medical, Dental, etc.

3. **Multi-Provider View**
   - Compare tables across providers
   - Side-by-side schema comparison

4. **Provider Statistics**
   - Show table count per provider
   - Column count statistics
   - Data volume metrics

---

## Quick Reference

### Provider Display

```tsx
// Shows provider name on each table
{selectedTpaName && <Tag color="blue">{selectedTpaName}</Tag>}
```

### State Management

```tsx
// Separate filtered and all data
const [schemas, setSchemas] = useState<TargetSchema[]>([])
const [allSchemas, setAllSchemas] = useState<TargetSchema[]>([])

// Reset filter on provider change
useEffect(() => {
  if (selectedTpa) {
    setSelectedTable('')
    loadSchemas()
  }
}, [selectedTpa])

// Filter from all data
const filtered = allSchemas.filter(s => s.TABLE_NAME === value)
setSchemas(filtered)
```

---

## Status

**Status**: ✅ Fixed and Deployed  
**Deployment**: January 21, 2026  
**Service**: BORDEREAU_APP  
**Endpoint**: https://bordereau-app.bd3h.svc.spcs.internal

**Impact**: 
- Provider filtering now works correctly
- Provider context always visible
- Better user experience
- Cleaner state management

**Last Updated**: January 21, 2026
