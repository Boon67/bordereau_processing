# Field Mappings - Show Only Created Tables Fix

## Problem
The Field Mappings page was showing all schema definitions (DENTAL_CLAIMS, MEDICAL_CLAIMS, etc.) for all TPAs, even if no physical tables had been created yet. This was confusing because:
- Users couldn't map fields to tables that don't exist
- It showed schemas instead of actual created tables
- It didn't filter by the selected TPA

## Solution
Updated the Field Mappings page to only show **physically created tables** for the **selected TPA** by querying the `created_tables` tracking table.

---

## Implementation Details

### 1. Updated `loadTargetTables` Function

**File**: `frontend/src/pages/SilverMappings.tsx`

**Changes**:
- Changed from loading all schemas to loading created tables
- Filters tables by selected TPA
- Fetches column count from schema definitions for each created table
- Only runs when a TPA is selected

**Before**:
```typescript
const loadTargetTables = async () => {
  try {
    // Load available target schemas (TPA-agnostic)
    const schemas = await apiService.getTargetSchemas()
    
    // Group by table name and count columns
    const tableMap = schemas.reduce((acc: any, schema: any) => {
      if (!acc[schema.TABLE_NAME]) {
        acc[schema.TABLE_NAME] = {
          name: schema.TABLE_NAME,
          columns: 0,
        }
      }
      acc[schema.TABLE_NAME].columns++
      return acc
    }, {})
    
    setAvailableTargetTables(Object.values(tableMap))
  } catch (error) {
    console.error('Failed to load target tables:', error)
  }
}
```

**After**:
```typescript
const loadTargetTables = async () => {
  if (!selectedTpa) return
  
  try {
    // Load created tables for this TPA
    const createdTables = await apiService.getSilverTables()
    
    // Filter to only tables for the selected TPA
    const tpaCreatedTables = createdTables.filter(
      (table: any) => table.TPA.toLowerCase() === selectedTpa.toLowerCase()
    )
    
    // For each created table, get the column count from target_schemas
    const tablesWithColumns = await Promise.all(
      tpaCreatedTables.map(async (table: any) => {
        try {
          const schemas = await apiService.getTargetSchemas()
          const tableSchemas = schemas.filter(
            (s: any) => s.TABLE_NAME === table.SCHEMA_TABLE
          )
          return {
            name: table.SCHEMA_TABLE,
            physicalName: table.TABLE_NAME,
            columns: tableSchemas.length,
          }
        } catch (error) {
          return {
            name: table.SCHEMA_TABLE,
            physicalName: table.TABLE_NAME,
            columns: 0,
          }
        }
      })
    )
    
    setAvailableTargetTables(tablesWithColumns)
  } catch (error) {
    console.error('Failed to load target tables:', error)
  }
}
```

---

### 2. Updated `useEffect` Hook

**Changes**:
- Moved `loadTargetTables` call into the TPA-dependent `useEffect`
- Both `loadTargetTables` and `loadMappings` now run when TPA changes

**Before**:
```typescript
useEffect(() => {
  // Load target tables once (TPA-agnostic)
  loadTargetTables()
}, [])

useEffect(() => {
  // Load mappings when TPA changes
  if (selectedTpa) {
    loadMappings()
  }
}, [selectedTpa])
```

**After**:
```typescript
useEffect(() => {
  // Load created tables when TPA changes
  if (selectedTpa) {
    loadTargetTables()
    loadMappings()
  }
}, [selectedTpa])
```

---

### 3. Enhanced Empty State

**Changes**:
- Updated empty state to show helpful instructions
- Guides users to create tables first before mapping

**New Empty State**:
```tsx
{allTargetTablesWithStatus.length === 0 ? (
  <Card>
    <Alert
      message="No Tables Created Yet"
      description={
        <div>
          <p>No physical tables have been created for <strong>{selectedTpaName || selectedTpa}</strong> yet.</p>
          <p>To create field mappings, you must first:</p>
          <ol>
            <li>Go to <strong>Schemas and Tables</strong> page</li>
            <li>Select a schema definition (e.g., DENTAL_CLAIMS, MEDICAL_CLAIMS)</li>
            <li>Click <strong>Create Table</strong> and select <strong>{selectedTpaName || selectedTpa}</strong> as the provider</li>
            <li>Return here to create field mappings for the created table</li>
          </ol>
        </div>
      }
      type="info"
      showIcon
      style={{ margin: '20px 0' }}
    />
  </Card>
) : (
  // ... table list
)}
```

---

## User Flow

### Scenario 1: No Tables Created Yet

1. User selects "Provider A Healthcare" from TPA dropdown
2. User navigates to **Field Mappings** page
3. Page shows:
   - ℹ️ **Alert**: "No Tables Created Yet"
   - Step-by-step instructions to create tables first
   - No table list (because no tables exist)

### Scenario 2: Tables Created

1. User goes to **Schemas and Tables** page
2. User creates table: `PROVIDER_A_DENTAL_CLAIMS` (from `DENTAL_CLAIMS` schema)
3. User returns to **Field Mappings** page
4. Page shows:
   - ✅ **DENTAL_CLAIMS** (14 columns) - Available for mapping
   - Filter dropdown shows: "DENTAL_CLAIMS (14 columns)"
   - Auto-Map forms show: "DENTAL_CLAIMS (14 columns)"
   - Manual mapping form shows: "DENTAL_CLAIMS (14 columns)"

### Scenario 3: Multiple Tables for Same TPA

1. User creates:
   - `PROVIDER_A_DENTAL_CLAIMS`
   - `PROVIDER_A_MEDICAL_CLAIMS`
   - `PROVIDER_A_PHARMACY_CLAIMS`
2. Field Mappings page shows all three tables
3. Each table shows its own mapping status
4. All forms show all three tables in dropdowns

---

## Benefits

1. ✅ **Accurate Display**: Only shows tables that actually exist
2. ✅ **TPA-Specific**: Filters by selected TPA automatically
3. ✅ **Clear Guidance**: Helpful instructions when no tables exist
4. ✅ **Consistent**: All forms (Auto-Map ML, Auto-Map LLM, Manual) use the same filtered list
5. ✅ **Better UX**: Users can't try to map to non-existent tables

---

## Technical Details

### Data Flow

1. **User selects TPA** → `selectedTpa` state updates
2. **`useEffect` triggers** → Calls `loadTargetTables()` and `loadMappings()`
3. **`loadTargetTables()`**:
   - Calls `apiService.getSilverTables()` (queries `created_tables` tracking table)
   - Filters results by `TPA` matching `selectedTpa`
   - For each table, fetches schema definition to get column count
   - Updates `availableTargetTables` state
4. **UI renders**:
   - If `availableTargetTables.length === 0`: Shows empty state alert
   - Else: Shows table list with mapping status
   - All dropdowns populate from `availableTargetTables`

### API Dependency

This fix depends on the `created_tables` tracking table and the `/silver/tables` API endpoint:

**API Endpoint**: `GET /api/silver/tables`

**Returns**:
```json
[
  {
    "TABLE_NAME": "PROVIDER_A_DENTAL_CLAIMS",
    "SCHEMA_TABLE": "DENTAL_CLAIMS",
    "TPA": "provider_a",
    "CREATED_AT": "2026-01-26T16:22:13.098000",
    "CREATED_BY": "DEPLOY_USER",
    "DESCRIPTION": "Created from schema: DENTAL_CLAIMS for TPA: provider_a",
    "ROW_COUNT": 0,
    "BYTES": 0,
    "LAST_UPDATED": "2026-01-26T16:22:13.098000"
  }
]
```

**Frontend Filters By**:
```typescript
const tpaCreatedTables = createdTables.filter(
  (table: any) => table.TPA.toLowerCase() === selectedTpa.toLowerCase()
)
```

---

## Testing

### Test Case 1: No Tables Created
1. Select a TPA that has no tables created
2. Navigate to Field Mappings
3. **Expected**: See alert with instructions, no table list

### Test Case 2: One Table Created
1. Create `PROVIDER_A_DENTAL_CLAIMS` table
2. Select "Provider A Healthcare" TPA
3. Navigate to Field Mappings
4. **Expected**: See DENTAL_CLAIMS in table list and all dropdowns

### Test Case 3: Multiple Tables
1. Create multiple tables for Provider A
2. Select "Provider A Healthcare" TPA
3. Navigate to Field Mappings
4. **Expected**: See all Provider A tables, not other TPAs' tables

### Test Case 4: Switch TPA
1. Select "Provider A Healthcare" (has tables)
2. Switch to "Provider B Healthcare" (no tables)
3. **Expected**: Table list updates to show empty state
4. Switch back to Provider A
5. **Expected**: Tables reappear

---

## Files Modified

1. ✅ `frontend/src/pages/SilverMappings.tsx` - Updated table loading logic and empty state

---

## Related Features

This fix builds on:
- **Created Tables Tracking** (`created_tables` table)
- **TPA-Agnostic Schemas** (schema definitions shared across TPAs)
- **Physical Table Creation** (TPA-specific tables from schemas)

---

**Status**: ✅ **Fully Implemented**
