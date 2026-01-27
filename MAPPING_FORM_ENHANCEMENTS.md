# Field Mapping Form Enhancements

## Overview
Enhanced the Field Mappings page with dynamic dropdowns for better user experience and data accuracy.

## Changes Implemented

### 1. Manual Mapping Form - Dynamic Dropdowns

#### Source Field Dropdown
- **Before**: Text input requiring manual typing
- **After**: Dropdown populated with actual fields from `RAW_DATA_TABLE`
- **Data Source**: `GET /bronze/source-fields?tpa={tpa}`
- **Query**: Extracts distinct field names from JSON data filtered by TPA
  ```sql
  SELECT DISTINCT f.key as field_name
  FROM BRONZE.RAW_DATA_TABLE,
  LATERAL FLATTEN(input => RAW_DATA) f
  WHERE TPA = '{tpa}'
    AND RAW_DATA IS NOT NULL
  ORDER BY f.key
  ```

#### Target Column Dropdown
- **Before**: Text input requiring manual typing
- **After**: Dropdown populated with columns from selected target table's schema
- **Data Source**: `GET /silver/schemas/{table_name}/columns`
- **Query**: Retrieves column definitions from `target_schemas` table
  ```sql
  SELECT column_name
  FROM SILVER.target_schemas
  WHERE table_name = '{table_name}'
    AND active = TRUE
  ORDER BY schema_id
  ```

#### Features
- ✅ **TPA-filtered source fields** - Only shows fields from uploaded data for selected TPA
- ✅ **Schema-aware target columns** - Only shows valid columns for selected table
- ✅ **Dynamic loading** - Target columns load when table is selected
- ✅ **Searchable dropdowns** - Type to filter options
- ✅ **Loading states** - Visual feedback while fetching data
- ✅ **Smart validation** - Target column disabled until table selected
- ✅ **Auto-reset** - Target column clears when changing tables

### 2. Auto-Map (LLM) Form - Dynamic Model Dropdown

#### Cortex LLM Model Dropdown
- **Before**: Hardcoded list of 4 models
- **After**: Dynamically loaded from Snowflake Cortex
- **Data Source**: `GET /silver/cortex-models`
- **Query**: Uses Snowflake's SHOW MODELS command
  ```sql
  SHOW MODELS IN SNOWFLAKE.MODELS;
  
  SELECT "name" AS model_name
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
  WHERE "model_type" = 'CORTEX_BASE'
  ORDER BY "name";
  ```

#### Features
- ✅ **Live model list** - Shows all available Cortex LLM models in your Snowflake account
- ✅ **Automatic updates** - New models appear automatically
- ✅ **Fallback handling** - Provides default list if query fails
- ✅ **Auto-selection** - First model selected by default
- ✅ **Searchable** - Easy to find specific models

## Backend Changes

### New API Endpoints

#### 1. Get Source Fields
```python
@router.get("/bronze/source-fields")
async def get_source_fields(tpa: str):
    """Get distinct source field names from RAW_DATA_TABLE for a TPA"""
```

#### 2. Get Target Columns
```python
@router.get("/silver/schemas/{table_name}/columns")
async def get_target_columns(table_name: str):
    """Get column names for a specific target table"""
```

#### 3. Get Cortex Models
```python
@router.get("/silver/cortex-models")
async def get_cortex_models():
    """Get list of available Cortex LLM models"""
```

## Frontend Changes

### New State Variables
```typescript
const [sourceFields, setSourceFields] = useState<string[]>([])
const [targetColumns, setTargetColumns] = useState<string[]>([])
const [cortexModels, setCortexModels] = useState<string[]>([])
const [loadingSourceFields, setLoadingSourceFields] = useState(false)
const [loadingTargetColumns, setLoadingTargetColumns] = useState(false)
const [loadingCortexModels, setLoadingCortexModels] = useState(false)
```

### New API Service Methods
```typescript
getSourceFields: async (tpa: string): Promise<string[]>
getTargetColumns: async (tableName: string): Promise<string[]>
getCortexModels: async (): Promise<string[]>
```

### Load Functions
```typescript
loadSourceFields() - Loads when Manual Mapping modal opens
loadTargetColumns(tableName) - Loads when target table selected
loadCortexModels() - Loads when Auto-Map LLM drawer opens
```

## User Experience Improvements

### Before
1. **Manual typing** - Users had to remember exact field/column names
2. **Typo errors** - Easy to make mistakes in spelling
3. **No validation** - Could enter non-existent fields
4. **Static model list** - Limited to hardcoded models

### After
1. **Point and click** - Select from actual data
2. **No typos** - Choose from validated options
3. **Real-time validation** - Only valid options shown
4. **Dynamic model list** - All available models shown
5. **Contextual help** - Loading states and helpful messages
6. **Smart defaults** - Auto-selects when only one option

## Error Handling

### Source Fields
- Shows "No source fields found. Upload data first." if no data
- Graceful error handling with user-friendly messages

### Target Columns
- Shows "Select a target table first" until table selected
- Disabled state prevents premature selection

### Cortex Models
- Falls back to default list if query fails
- Shows loading state during fetch
- Provides 5 common models as fallback

## Testing

### Manual Mapping
1. Select a TPA
2. Click "Manual Mapping"
3. Verify source fields load from uploaded data
4. Select a target table
5. Verify target columns load from schema
6. Create mapping successfully

### Auto-Map LLM
1. Select a TPA
2. Click "Auto-Map (LLM)"
3. Verify Cortex models load dynamically
4. Select a model from the list
5. Generate mappings successfully

## Files Modified

### Backend
- `backend/app/api/bronze.py` - Added `get_source_fields` endpoint
- `backend/app/api/silver.py` - Added `get_target_columns` and `get_cortex_models` endpoints

### Frontend
- `frontend/src/services/api.ts` - Added API service methods
- `frontend/src/pages/SilverMappings.tsx` - Converted forms to use dropdowns

## Benefits

1. **Reduced Errors** - No more typos or invalid field names
2. **Better UX** - Point-and-click instead of typing
3. **Data-Driven** - Shows actual data, not assumptions
4. **TPA-Aware** - Filters appropriately by context
5. **Schema-Aware** - Only shows valid target columns
6. **Future-Proof** - Automatically includes new models
7. **Discoverable** - Users can see what's available
8. **Validated** - Only allows valid selections

## Next Steps

Consider adding:
- Column type indicators in dropdowns (e.g., "CUSTOMER_ID (VARCHAR)")
- Sample values preview for source fields
- Column descriptions in tooltips
- Recently used fields/columns at top
- Fuzzy search for better filtering
