# Sample Silver Target Schemas

This directory contains sample schema definitions for the Silver layer.

## Files

- `silver_target_schemas.csv` - Schema definitions for all TPAs
- `load_sample_schemas.sql` - SQL script to load schemas into Snowflake

## Schema Types

The sample includes schemas for:

1. **MEDICAL_CLAIMS** - Medical claim data
2. **DENTAL_CLAIMS** - Dental claim data
3. **PHARMACY_CLAIMS** - Pharmacy/prescription claim data
4. **MEMBER_ELIGIBILITY** - Member eligibility and demographics

## TPAs Included

Sample schemas are generated for:
- provider_a
- provider_b
- provider_c
- provider_d
- provider_e

## Usage

### Option 1: Load via SQL Script

```bash
cd /Users/tboon/code/bordereau

# 1. Upload CSV to Snowflake stage
snow stage put sample_data/config/silver_target_schemas.csv \
    @SILVER.SILVER_CONFIG/ \
    --connection DEPLOYMENT \
    --overwrite

# 2. Load schemas
snow sql -f sample_data/config/load_sample_schemas.sql \
    --connection DEPLOYMENT
```

### Option 2: Load via API

```bash
# Use the backend API to load schemas
curl -X POST https://your-endpoint.snowflakecomputing.app/api/silver/schemas/bulk \
    -H "Content-Type: application/json" \
    -d @sample_data/config/silver_target_schemas.csv
```

### Option 3: Load via UI

1. Navigate to Silver Schemas page
2. Click "Add Column" for each field
3. Or use bulk import feature (if available)

## Customization

To customize schemas for your TPAs:

1. Edit `silver_target_schemas.csv`
2. Add/remove columns as needed
3. Reload using one of the methods above

## Schema Structure

Each row in the CSV defines one column:

- `TABLE_NAME` - Name of the target table
- `TPA` - TPA identifier
- `COLUMN_NAME` - Column name
- `DATA_TYPE` - Snowflake data type
- `NULLABLE` - Y/N for nullable
- `DEFAULT_VALUE` - Default value (optional)
- `DESCRIPTION` - Column description

## Next Steps

After loading schemas:

1. Create physical tables: Use "Create Table" button in UI
2. Define field mappings: Map Bronze fields to Silver columns
3. Set up transformations: Define transformation rules
4. Test with sample data: Upload sample claim files

---

**Generated**: Mon Jan 26 10:11:24 CST 2026
**Total Schemas**: 20
**Total Columns**: 310
