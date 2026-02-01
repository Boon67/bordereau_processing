#!/usr/bin/env python3
"""
Generate Sample Silver Target Schemas
Creates sample schema definitions for each TPA to demonstrate the system
"""

import csv
import os
from pathlib import Path

# Sample schema definitions for different claim types
SAMPLE_SCHEMAS = {
    'MEDICAL_CLAIMS': [
        ('CLAIM_ID', 'VARCHAR(100)', False, None, 'Unique claim identifier'),
        ('MEMBER_ID', 'VARCHAR(100)', False, None, 'Member identifier'),
        ('PROVIDER_ID', 'VARCHAR(100)', True, None, 'Provider identifier'),
        ('PROVIDER_NAME', 'VARCHAR(500)', True, None, 'Provider name'),
        ('SERVICE_DATE', 'DATE', False, None, 'Date of service'),
        ('DIAGNOSIS_CODE', 'VARCHAR(50)', True, None, 'Primary diagnosis code'),
        ('PROCEDURE_CODE', 'VARCHAR(50)', True, None, 'Procedure code'),
        ('BILLED_AMOUNT', 'NUMBER(18,2)', False, '0.00', 'Amount billed'),
        ('ALLOWED_AMOUNT', 'NUMBER(18,2)', False, '0.00', 'Amount allowed'),
        ('PAID_AMOUNT', 'NUMBER(18,2)', False, '0.00', 'Amount paid'),
        ('MEMBER_RESPONSIBILITY', 'NUMBER(18,2)', True, '0.00', 'Member cost share'),
        ('CLAIM_STATUS', 'VARCHAR(50)', True, 'PENDING', 'Claim status'),
        ('PROCESSED_DATE', 'TIMESTAMP_NTZ', True, None, 'Date processed'),
        ('CREATED_AT', 'TIMESTAMP_NTZ', False, 'CURRENT_TIMESTAMP()', 'Record creation timestamp'),
    ],
    'DENTAL_CLAIMS': [
        ('CLAIM_ID', 'VARCHAR(100)', False, None, 'Unique claim identifier'),
        ('MEMBER_ID', 'VARCHAR(100)', False, None, 'Member identifier'),
        ('DENTIST_ID', 'VARCHAR(100)', True, None, 'Dentist identifier'),
        ('DENTIST_NAME', 'VARCHAR(500)', True, None, 'Dentist name'),
        ('SERVICE_DATE', 'DATE', False, None, 'Date of service'),
        ('TOOTH_NUMBER', 'VARCHAR(10)', True, None, 'Tooth number'),
        ('PROCEDURE_CODE', 'VARCHAR(50)', True, None, 'Dental procedure code'),
        ('SURFACE', 'VARCHAR(20)', True, None, 'Tooth surface'),
        ('BILLED_AMOUNT', 'NUMBER(18,2)', False, '0.00', 'Amount billed'),
        ('ALLOWED_AMOUNT', 'NUMBER(18,2)', False, '0.00', 'Amount allowed'),
        ('PAID_AMOUNT', 'NUMBER(18,2)', False, '0.00', 'Amount paid'),
        ('MEMBER_RESPONSIBILITY', 'NUMBER(18,2)', True, '0.00', 'Member cost share'),
        ('CLAIM_STATUS', 'VARCHAR(50)', True, 'PENDING', 'Claim status'),
        ('CREATED_AT', 'TIMESTAMP_NTZ', False, 'CURRENT_TIMESTAMP()', 'Record creation timestamp'),
    ],
    'PHARMACY_CLAIMS': [
        ('CLAIM_ID', 'VARCHAR(100)', False, None, 'Unique claim identifier'),
        ('MEMBER_ID', 'VARCHAR(100)', False, None, 'Member identifier'),
        ('PHARMACY_ID', 'VARCHAR(100)', True, None, 'Pharmacy identifier'),
        ('PHARMACY_NAME', 'VARCHAR(500)', True, None, 'Pharmacy name'),
        ('FILL_DATE', 'DATE', False, None, 'Prescription fill date'),
        ('NDC_CODE', 'VARCHAR(50)', False, None, 'National Drug Code'),
        ('DRUG_NAME', 'VARCHAR(500)', True, None, 'Drug name'),
        ('QUANTITY', 'NUMBER(18,2)', False, None, 'Quantity dispensed'),
        ('DAYS_SUPPLY', 'NUMBER(10,0)', True, None, 'Days supply'),
        ('PRESCRIBER_ID', 'VARCHAR(100)', True, None, 'Prescriber identifier'),
        ('BILLED_AMOUNT', 'NUMBER(18,2)', False, '0.00', 'Amount billed'),
        ('ALLOWED_AMOUNT', 'NUMBER(18,2)', False, '0.00', 'Amount allowed'),
        ('PAID_AMOUNT', 'NUMBER(18,2)', False, '0.00', 'Amount paid'),
        ('MEMBER_COPAY', 'NUMBER(18,2)', True, '0.00', 'Member copay'),
        ('CLAIM_STATUS', 'VARCHAR(50)', True, 'PENDING', 'Claim status'),
        ('CREATED_AT', 'TIMESTAMP_NTZ', False, 'CURRENT_TIMESTAMP()', 'Record creation timestamp'),
    ],
    'MEMBER_ELIGIBILITY': [
        ('MEMBER_ID', 'VARCHAR(100)', False, None, 'Unique member identifier'),
        ('FIRST_NAME', 'VARCHAR(200)', False, None, 'Member first name'),
        ('LAST_NAME', 'VARCHAR(200)', False, None, 'Member last name'),
        ('DATE_OF_BIRTH', 'DATE', False, None, 'Date of birth'),
        ('GENDER', 'VARCHAR(10)', True, None, 'Gender'),
        ('ADDRESS_LINE1', 'VARCHAR(500)', True, None, 'Address line 1'),
        ('ADDRESS_LINE2', 'VARCHAR(500)', True, None, 'Address line 2'),
        ('CITY', 'VARCHAR(200)', True, None, 'City'),
        ('STATE', 'VARCHAR(50)', True, None, 'State'),
        ('ZIP_CODE', 'VARCHAR(20)', True, None, 'ZIP code'),
        ('PHONE', 'VARCHAR(50)', True, None, 'Phone number'),
        ('EMAIL', 'VARCHAR(200)', True, None, 'Email address'),
        ('PLAN_ID', 'VARCHAR(100)', True, None, 'Plan identifier'),
        ('PLAN_NAME', 'VARCHAR(500)', True, None, 'Plan name'),
        ('EFFECTIVE_DATE', 'DATE', False, None, 'Coverage effective date'),
        ('TERMINATION_DATE', 'DATE', True, None, 'Coverage termination date'),
        ('STATUS', 'VARCHAR(50)', False, 'ACTIVE', 'Eligibility status'),
        ('CREATED_AT', 'TIMESTAMP_NTZ', False, 'CURRENT_TIMESTAMP()', 'Record creation timestamp'),
    ],
}

# TPAs to generate schemas for
TPAS = ['provider_a', 'provider_b', 'provider_c', 'provider_d', 'provider_e']

def generate_schema_csv(output_dir: Path):
    """Generate silver_target_schemas.csv file"""
    output_file = output_dir / 'silver_target_schemas.csv'
    
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        # Write header
        writer.writerow(['TABLE_NAME', 'TPA', 'COLUMN_NAME', 'DATA_TYPE', 'NULLABLE', 'DEFAULT_VALUE', 'DESCRIPTION'])
        
        # Write schema definitions for each TPA
        for tpa in TPAS:
            for table_name, columns in SAMPLE_SCHEMAS.items():
                for col_name, data_type, nullable, default_val, description in columns:
                    writer.writerow([
                        table_name,
                        tpa,
                        col_name,
                        data_type,
                        'Y' if nullable else 'N',
                        default_val or '',
                        description
                    ])
    
    print(f"✓ Generated {output_file}")
    print(f"  - {len(TPAS)} TPAs")
    print(f"  - {len(SAMPLE_SCHEMAS)} table types")
    print(f"  - {sum(len(cols) for cols in SAMPLE_SCHEMAS.values())} columns per TPA")
    print(f"  - {len(TPAS) * sum(len(cols) for cols in SAMPLE_SCHEMAS.values())} total rows")

def generate_sql_load_script(output_dir: Path):
    """Generate SQL script to load the schemas"""
    output_file = output_dir / 'load_sample_schemas.sql'
    
    with open(output_file, 'w') as f:
        f.write("""-- Load Sample Silver Target Schemas
-- This script loads sample schema definitions for demonstration

USE DATABASE &{DATABASE_NAME};
USE SCHEMA &{SILVER_SCHEMA_NAME};

-- Create stage for config files if not exists
CREATE STAGE IF NOT EXISTS SILVER_CONFIG;

-- Upload the CSV file first:
-- snow stage put sample_data/config/silver_target_schemas.csv @SILVER_CONFIG/ --connection DEPLOYMENT

-- Load schemas from CSV
COPY INTO target_schemas (
    TABLE_NAME,
    TPA,
    COLUMN_NAME,
    DATA_TYPE,
    NULLABLE,
    DEFAULT_VALUE,
    DESCRIPTION
)
FROM (
    SELECT 
        $1::VARCHAR as TABLE_NAME,
        $2::VARCHAR as TPA,
        $3::VARCHAR as COLUMN_NAME,
        $4::VARCHAR as DATA_TYPE,
        CASE WHEN $5 = 'Y' THEN TRUE ELSE FALSE END as NULLABLE,
        NULLIF($6, '')::VARCHAR as DEFAULT_VALUE,
        $7::VARCHAR as DESCRIPTION
    FROM @SILVER_CONFIG/silver_target_schemas.csv
)
FILE_FORMAT = (
    TYPE = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
)
ON_ERROR = CONTINUE;

-- Verify loaded schemas
SELECT 
    TPA,
    TABLE_NAME,
    COUNT(*) as COLUMN_COUNT
FROM target_schemas
GROUP BY TPA, TABLE_NAME
ORDER BY TPA, TABLE_NAME;

-- Show sample
SELECT * FROM target_schemas LIMIT 10;
""")
    
    print(f"✓ Generated {output_file}")

def generate_readme(output_dir: Path):
    """Generate README for sample schemas"""
    output_file = output_dir / 'SAMPLE_SCHEMAS_README.md'
    
    with open(output_file, 'w') as f:
        f.write("""# Sample Silver Target Schemas

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
snow stage put sample_data/config/silver_target_schemas.csv \\
    @SILVER.SILVER_CONFIG/ \\
    --connection DEPLOYMENT \\
    --overwrite

# 2. Load schemas
snow sql -f sample_data/config/load_sample_schemas.sql \\
    --connection DEPLOYMENT
```

### Option 2: Load via API

```bash
# Use the backend API to load schemas
curl -X POST https://your-endpoint.snowflakecomputing.app/api/silver/schemas/bulk \\
    -H "Content-Type: application/json" \\
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

**Generated**: """ + f"{os.popen('date').read().strip()}" + """
**Total Schemas**: """ + f"{len(TPAS) * len(SAMPLE_SCHEMAS)}" + """
**Total Columns**: """ + f"{len(TPAS) * sum(len(cols) for cols in SAMPLE_SCHEMAS.values())}" + """
""")
    
    print(f"✓ Generated {output_file}")

def main():
    # Get script directory
    script_dir = Path(__file__).parent
    config_dir = script_dir / 'config'
    
    # Create config directory if it doesn't exist
    config_dir.mkdir(exist_ok=True)
    
    print("Generating sample Silver target schemas...")
    print("=" * 60)
    
    # Generate files
    generate_schema_csv(config_dir)
    generate_sql_load_script(config_dir)
    generate_readme(config_dir)
    
    print("=" * 60)
    print("✓ Sample schema generation complete!")
    print()
    print("Next steps:")
    print("1. Review generated files in sample_data/config/")
    print("2. Upload to Snowflake:")
    print("   cd /Users/tboon/code/bordereau")
    print("   snow stage put sample_data/config/silver_target_schemas.csv @SILVER.SILVER_CONFIG/ --connection DEPLOYMENT")
    print("3. Load schemas:")
    print("   snow sql -f sample_data/config/load_sample_schemas.sql --connection DEPLOYMENT")

if __name__ == '__main__':
    main()
