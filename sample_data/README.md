# Sample Data

**Sample healthcare claims data for testing**

---

## Overview

Sample data files and schemas for testing the Bordereau Processing Pipeline.

---

## Quick Start

### Load Sample Data

```bash
cd sample_data
./quick_start.sh
```

This will:
1. Load sample target schemas
2. Load sample field mappings
3. Upload sample claims files
4. Process files through Bronze layer

### Manual Load

```bash
cd deployment
./load_sample_schemas.sh
```

---

## Sample Files

### Claims Data (`claims_data/`)

**Provider A** - Dental Claims:
- `provider_a/dental-claims-20240301.csv`
- Fields: CLAIM_NUM, MEMBER_ID, NPI, PROVIDER_NAME, PROCEDURE, SERVICE_DATE, BILLED_AMOUNT, PAID_AMOUNT

**Provider B** - Medical Claims:
- `provider_b/medical-claims-20240115.csv`
- Fields: Similar structure with medical-specific codes

**Provider E** - Pharmacy Claims:
- `provider_e/pharmacy-claims-20240201.csv`
- Fields: Prescription and pharmacy-specific data

### Configuration (`config/`)

| File | Purpose |
|------|---------|
| `silver_target_schemas.csv` | Target table column definitions |
| `silver_field_mappings.csv` | Pre-configured field mappings |
| `silver_transformation_rules.csv` | Data transformation rules |
| `load_sample_schemas.sql` | SQL to load configurations |

---

## Data Structure

### Sample Claims Record

```json
{
  "CLAIM_NUM": "CLM001",
  "MEMBER_ID": "M12345",
  "NPI": "1234567890",
  "PROVIDER_NAME": "Dr. Smith",
  "PROCEDURE": "D0120",
  "SERVICE_DATE": "2024-03-01",
  "BILLED_AMOUNT": 150.00,
  "PAID_AMOUNT": 120.00
}
```

---

## Usage

### 1. Upload Sample Files

```bash
# Via UI
Bronze → Upload Files → Select TPA → Upload CSV

# Via SQL
PUT file://sample_data/claims_data/provider_a/*.csv @SRC/provider_a/;
```

### 2. Process Files

Files are automatically processed by Bronze tasks, or manually:

```sql
CALL BRONZE.process_file('dental-claims-20240301.csv', 'provider_a');
```

### 3. View Raw Data

```sql
SELECT * FROM BRONZE.RAW_DATA_TABLE 
WHERE TPA = 'provider_a' 
LIMIT 100;
```

### 4. Transform to Silver

```sql
CALL SILVER.transform_bronze_to_silver(
  'DENTAL_CLAIMS',
  'provider_a',
  'RAW_DATA_TABLE',
  'BRONZE',
  10000,
  TRUE,
  FALSE
);
```

---

## Generate Custom Data

```bash
# Generate sample schemas
python generate_sample_schemas.py

# Generate sample data
python generate_sample_data.py --tpa provider_a --records 1000
```

---

## Documentation

**Quick Reference**: [docs/QUICK_REFERENCE.md](../docs/QUICK_REFERENCE.md)  
**User Guide**: [docs/USER_GUIDE.md](../docs/USER_GUIDE.md)  
**Bronze Layer**: [bronze/README.md](../bronze/README.md)

---

**Version**: 3.1 | **Status**: ✅ Production Ready
