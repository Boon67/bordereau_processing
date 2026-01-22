# Delete Schema Feature

**Date**: January 21, 2026  
**Feature**: Delete entire table schemas  
**Status**: ✅ Implemented and Deployed

---

## Overview

Added the ability to delete entire table schemas (all columns for a table) from the Silver Target Schemas page.

---

## Features

### 1. Delete Entire Table Schema

Users can now delete an entire table schema, which removes all column definitions for that table.

**UI Location**: Silver Target Schemas page → Each table panel header

**Button**: "Delete Schema" (red, with trash icon)

**Confirmation**: Popup asking "Are you sure you want to delete [TABLE_NAME] and all its [N] columns?"

### 2. Delete Individual Columns

Existing functionality to delete individual columns remains available.

**UI Location**: Within each table's column list

**Button**: "Delete" (red link, in Actions column)

---

## Implementation

### Backend API

**New Endpoint**: `DELETE /api/silver/schemas/table/{table_name}`

**Parameters**:
- `table_name` (path): Name of the table to delete
- `tpa` (query): TPA code

**Response**:
```json
{
  "message": "Table schema 'MEDICAL_CLAIMS' deleted successfully",
  "columns_deleted": 14
}
```

**Code**:
```python
@router.delete("/schemas/table/{table_name}")
async def delete_table_schema(table_name: str, tpa: str):
    """Delete entire table schema (all columns for a table)"""
    sf_service = SnowflakeService()
    
    # Check if table exists
    check_query = f"""
        SELECT COUNT(*) as count
        FROM SILVER.target_schemas
        WHERE table_name = '{table_name.upper()}' 
          AND tpa = '{tpa}' 
          AND active = TRUE
    """
    result = sf_service.execute_query_dict(check_query)
    
    if result[0]['COUNT'] == 0:
        raise HTTPException(404, "Table schema not found")
    
    # Delete all columns
    delete_query = f"""
        DELETE FROM SILVER.target_schemas
        WHERE table_name = '{table_name.upper()}' AND tpa = '{tpa}'
    """
    sf_service.execute_query(delete_query)
    
    return {
        "message": f"Table schema '{table_name}' deleted successfully",
        "columns_deleted": result[0]['COUNT']
    }
```

### Frontend API

**New Method**: `apiService.deleteTableSchema(tableName, tpa)`

**Code**:
```typescript
deleteTableSchema: async (tableName: string, tpa: string): Promise<any> => {
  const response = await api.delete(`/silver/schemas/table/${tableName}`, {
    params: { tpa }
  })
  return response.data
}
```

### Frontend UI

**Delete Button in Panel Header**:
```tsx
<Popconfirm
  title="Delete table schema"
  description={`Are you sure you want to delete ${tableName} and all its ${tableSchemas.length} columns?`}
  onConfirm={(e) => {
    e?.stopPropagation()
    handleDeleteTable(tableName)
  }}
  okText="Yes"
  cancelText="No"
  okButtonProps={{ danger: true }}
>
  <Button
    danger
    size="small"
    icon={<DeleteOutlined />}
    onClick={(e) => e.stopPropagation()}
  >
    Delete Schema
  </Button>
</Popconfirm>
```

**Handler Function**:
```tsx
const handleDeleteTable = async (tableName: string) => {
  try {
    const result = await apiService.deleteTableSchema(tableName, selectedTpa)
    message.success(
      `Table schema ${tableName} deleted successfully (${result.columns_deleted} columns removed)`
    )
    loadSchemas()
  } catch (error: any) {
    message.error(`Failed to delete table schema: ${error.response?.data?.detail || error.message}`)
  }
}
```

---

## User Interface

### Table Panel Header

```
┌─────────────────────────────────────────────────────────────────────────┐
│ ▼ 📊 MEDICAL_CLAIMS [Provider B Insurance] (14 columns)                │
│                                    [Add Column] [Delete Schema]         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Delete Confirmation

```
┌─────────────────────────────────────────────────────────────────┐
│ Delete table schema                                             │
│                                                                 │
│ Are you sure you want to delete MEDICAL_CLAIMS and all its     │
│ 14 columns?                                                     │
│                                                                 │
│                                          [No]  [Yes]            │
└─────────────────────────────────────────────────────────────────┘
```

### Success Message

```
✓ Table schema MEDICAL_CLAIMS deleted successfully (14 columns removed)
```

---

## Use Cases

### 1. Remove Unused Table Schema

**Scenario**: A table schema was created by mistake or is no longer needed.

**Steps**:
1. Navigate to Silver Target Schemas
2. Select the TPA
3. Find the table to delete
4. Click "Delete Schema" button
5. Confirm deletion
6. Table and all columns are removed

### 2. Start Fresh

**Scenario**: Table schema needs to be completely redone.

**Steps**:
1. Delete the existing table schema
2. Click "Add Schema" to create new one
3. Add columns with correct definitions

### 3. Clean Up Test Data

**Scenario**: Test schemas need to be removed.

**Steps**:
1. Select the test TPA
2. Delete all test table schemas
3. Verify schemas are removed

---

## Safety Features

### 1. Confirmation Dialog

- Requires explicit confirmation
- Shows table name and column count
- Red "Yes" button to indicate danger
- Can cancel without action

### 2. TPA Scoping

- Only deletes schemas for the selected TPA
- Cannot accidentally delete another TPA's schemas
- TPA parameter is required

### 3. Error Handling

- 404 error if table doesn't exist
- Clear error messages
- Transaction-based deletion

### 4. Success Feedback

- Shows number of columns deleted
- Confirms table name
- Refreshes schema list

---

## Technical Details

### Database Operation

```sql
-- Check if table exists
SELECT COUNT(*) as count
FROM SILVER.target_schemas
WHERE table_name = 'MEDICAL_CLAIMS' 
  AND tpa = 'provider_b' 
  AND active = TRUE;

-- Delete all columns
DELETE FROM SILVER.target_schemas
WHERE table_name = 'MEDICAL_CLAIMS' 
  AND tpa = 'provider_b';
```

### Transaction Safety

- Single DELETE statement
- Atomic operation
- All columns deleted together
- No partial deletions

### Performance

- Indexed on `table_name` and `tpa`
- Fast deletion even with many columns
- Immediate UI refresh

---

## Testing

### Test Delete Single Table

```bash
# Create test table
curl -X POST "https://bordereau-app.bd3h.svc.spcs.internal/api/silver/schemas" \
  -H "Content-Type: application/json" \
  -d '{
    "table_name": "TEST_TABLE",
    "column_name": "TEST_COLUMN",
    "tpa": "provider_a",
    "data_type": "VARCHAR",
    "nullable": true
  }'

# Delete table schema
curl -X DELETE "https://bordereau-app.bd3h.svc.spcs.internal/api/silver/schemas/table/TEST_TABLE?tpa=provider_a"

# Verify deleted
curl "https://bordereau-app.bd3h.svc.spcs.internal/api/silver/schemas?tpa=provider_a"
```

### Test Error Handling

```bash
# Try to delete non-existent table
curl -X DELETE "https://bordereau-app.bd3h.svc.spcs.internal/api/silver/schemas/table/NONEXISTENT?tpa=provider_a"

# Expected: 404 error
```

### Test TPA Isolation

```bash
# Delete from provider_a
curl -X DELETE "https://bordereau-app.bd3h.svc.spcs.internal/api/silver/schemas/table/MEDICAL_CLAIMS?tpa=provider_a"

# Verify provider_b still has MEDICAL_CLAIMS
curl "https://bordereau-app.bd3h.svc.spcs.internal/api/silver/schemas?tpa=provider_b&table_name=MEDICAL_CLAIMS"

# Expected: provider_b's MEDICAL_CLAIMS still exists
```

---

## Comparison: Column Delete vs Table Delete

### Delete Column (Existing)

**Endpoint**: `DELETE /api/silver/schemas/{schema_id}`

**What it does**: Deletes a single column definition

**Use case**: Remove one column from a table

**Example**: Delete `MEMBER_ID` column from `MEDICAL_CLAIMS`

### Delete Table Schema (New)

**Endpoint**: `DELETE /api/silver/schemas/table/{table_name}`

**What it does**: Deletes all column definitions for a table

**Use case**: Remove entire table schema

**Example**: Delete entire `MEDICAL_CLAIMS` table (all 14 columns)

---

## Future Enhancements

### 1. Soft Delete

Instead of permanent deletion, mark as inactive:

```sql
UPDATE SILVER.target_schemas
SET active = FALSE,
    deleted_timestamp = CURRENT_TIMESTAMP(),
    deleted_by = CURRENT_USER()
WHERE table_name = 'MEDICAL_CLAIMS' AND tpa = 'provider_a';
```

**Benefits**:
- Can restore deleted schemas
- Audit trail of deletions
- Safer operation

### 2. Bulk Delete

Delete multiple tables at once:

```tsx
<Button onClick={handleBulkDelete}>
  Delete Selected Schemas
</Button>
```

### 3. Export Before Delete

Download schema definition before deleting:

```tsx
<Button onClick={() => exportSchema(tableName)}>
  Export & Delete
</Button>
```

### 4. Cascade Delete

Option to also delete physical table:

```tsx
<Checkbox>
  Also delete physical table from Silver layer
</Checkbox>
```

---

## Best Practices

### 1. Backup Before Deleting

```bash
# Export schema definition
curl "https://bordereau-app.bd3h.svc.spcs.internal/api/silver/schemas?tpa=provider_a&table_name=MEDICAL_CLAIMS" \
  > medical_claims_backup.json
```

### 2. Verify Before Confirming

- Check table name is correct
- Verify TPA is correct
- Review column count

### 3. Document Deletions

Keep a log of what was deleted and why:

```
2026-01-21: Deleted TEST_TABLE schema from provider_a (test data cleanup)
2026-01-21: Deleted OLD_CLAIMS schema from provider_b (replaced with new schema)
```

### 4. Test in Non-Production First

- Test deletion in development environment
- Verify expected behavior
- Then apply to production

---

## Related Features

### Add Schema

Create new table schema with "Add Schema" button

### Add Column

Add columns to existing table with "Add Column" button

### Edit Column

Edit column definitions with "Edit" button in column list

### Delete Column

Delete individual columns with "Delete" button in column list

---

## Files Changed

1. **`backend/app/api/silver.py`**
   - Added `delete_table_schema` endpoint
   - Enhanced error handling
   - Added column count in response

2. **`frontend/src/services/api.ts`**
   - Added `deleteTableSchema` method

3. **`frontend/src/pages/SilverSchemas.tsx`**
   - Added "Delete Schema" button to panel headers
   - Added `handleDeleteTable` function
   - Added confirmation dialog
   - Enhanced UI layout

---

## Status

**Status**: ✅ Implemented and Deployed  
**Deployment**: January 21, 2026  
**Service**: BORDEREAU_APP  
**Endpoint**: https://bordereau-app.bd3h.svc.spcs.internal

**Features**:
- Delete entire table schemas
- Confirmation dialog
- TPA-scoped deletion
- Error handling
- Success feedback

**Last Updated**: January 21, 2026
