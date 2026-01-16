# Sample Data

**Sample data files for testing the Snowflake File Processing Pipeline.**

## Structure

```
sample_data/
├── claims_data/          # Sample claims files (5 TPAs)
│   ├── provider_a/       # Dental claims (CSV)
│   ├── provider_b/       # Medical claims (CSV)
│   ├── provider_c/       # Medical claims (Excel) - placeholder
│   ├── provider_d/       # Medical claims (Excel) - placeholder
│   └── provider_e/       # Pharmacy claims (CSV)
└── config/               # Configuration CSVs for Silver layer
    ├── silver_target_schemas.csv
    ├── silver_field_mappings.csv
    └── silver_transformation_rules.csv
```

## Claims Data

### Provider A - Dental Claims
- **File**: `provider_a/dental-claims-20240301.csv`
- **Type**: Dental claims
- **Records**: 5 sample claims
- **Fields**: CLAIM_NUM, PATIENT_FIRST_NAME, PATIENT_LAST_NAME, DOB, PROVIDER_NAME, NPI, SERVICE_DATE, DIAGNOSIS, PROCEDURE, BILLED_AMOUNT, PAID_AMOUNT

### Provider B - Medical Claims
- **File**: `provider_b/medical-claims-20240115.csv`
- **Type**: Medical claims
- **Records**: 5 sample claims
- **Fields**: CLAIM_ID, FIRST_NAME, LAST_NAME, DATE_OF_BIRTH, PROVIDER, PROVIDER_NPI, DATE_OF_SERVICE, DIAGNOSIS_CODE, PROCEDURE_CODE, CHARGE_AMOUNT, PAYMENT_AMOUNT

### Provider E - Pharmacy Claims
- **File**: `provider_e/pharmacy-claims-20240201.csv`
- **Type**: Pharmacy claims
- **Records**: 5 sample prescriptions
- **Fields**: RX_NUMBER, PATIENT_FNAME, PATIENT_LNAME, PATIENT_DOB, PHARMACY_NAME, PHARMACY_NPI, FILL_DATE, NDC, DRUG_NAME, QUANTITY, COST, COPAY

## Configuration Files

### silver_target_schemas.csv
Defines target table schemas for Silver layer:
- Table name
- Column name
- TPA
- Data type
- Nullable flag
- Default value
- Description

### silver_field_mappings.csv
Defines Bronze → Silver field mappings:
- Source field (from Bronze RAW_DATA_TABLE)
- Target table and column
- TPA
- Transformation logic
- Description

### silver_transformation_rules.csv
Defines data quality and business rules:
- Rule ID and name
- TPA
- Rule type (DATA_QUALITY, BUSINESS_LOGIC, etc.)
- Target table/column
- Rule logic
- Error action (REJECT, QUARANTINE, FLAG, CORRECT)

## Usage

### Upload Sample Data

**Via React UI:**
1. Open Bronze Ingestion Pipeline app
2. Select TPA (e.g., `provider_a`)
3. Upload corresponding file from `claims_data/provider_a/`

**Via SnowSQL:**
```sql
-- Upload Provider A data
PUT file://sample_data/claims_data/provider_a/*.csv @SRC/provider_a/ AUTO_COMPRESS=FALSE;

-- Upload Provider B data
PUT file://sample_data/claims_data/provider_b/*.csv @SRC/provider_b/ AUTO_COMPRESS=FALSE;

-- Upload Provider E data
PUT file://sample_data/claims_data/provider_e/*.csv @SRC/provider_e/ AUTO_COMPRESS=FALSE;
```

### Load Configuration

```sql
-- Load target schemas
CALL load_target_schemas_from_csv('@SILVER_CONFIG/silver_target_schemas.csv');

-- Load field mappings
CALL load_field_mappings_from_csv('@SILVER_CONFIG/silver_field_mappings.csv');

-- Load transformation rules
CALL load_transformation_rules_from_csv('@SILVER_CONFIG/silver_transformation_rules.csv');
```

---

**Version**: 1.0  
**Last Updated**: January 15, 2026
