# Silver Layer

**Data transformation and field mapping**

---

## Overview

The Silver layer handles:
- Target schema definition
- Field mapping (Manual, ML, LLM)
- Data transformation from Bronze
- Mapping validation
- MERGE-based idempotent transformations

---

## Quick Start

### Deploy Silver Layer

```bash
cd deployment
./deploy_silver.sh
```

### Create Mappings

1. Open UI → Silver → Field Mappings
2. Select TPA and target table
3. Choose mapping method:
   - **Manual**: CSV upload or one-by-one
   - **ML**: Pattern matching
   - **LLM**: Cortex AI suggestions
4. Approve mappings
5. Validate before transforming

### Run Transformation

```bash
# Via UI
Silver → Transform → Execute

# Via SQL
CALL SILVER.transform_bronze_to_silver(
  'CLAIMS',           -- target_table
  'provider_a',       -- tpa
  'RAW_DATA_TABLE',   -- source_table
  'BRONZE',           -- source_schema
  10000,              -- batch_size
  TRUE,               -- apply_rules
  FALSE               -- incremental
);
```

---

## Key Tables

| Table | Purpose |
|-------|---------|
| `TARGET_SCHEMAS` | Column definitions for target tables |
| `FIELD_MAPPINGS` | Source → Target field mappings |
| `TRANSFORMATION_RULES` | Data transformation rules |
| `SILVER_PROCESSING_LOG` | Transformation execution log |
| `{TPA}_{TABLE}` | Actual Silver data tables |

---

## Metadata Columns

Every Silver table includes 7 metadata columns for data lineage:
- `_RECORD_ID` - Links to Bronze, merge key
- `_FILE_NAME` - Source file
- `_FILE_ROW_NUMBER` - Row in source file
- `_TPA` - TPA code
- `_BATCH_ID` - Transformation batch
- `_LOAD_TIMESTAMP` - When processed
- `_LOADED_BY` - Who processed

See [docs/guides/SILVER_METADATA_COLUMNS.md](../docs/guides/SILVER_METADATA_COLUMNS.md) for details.

---

## SQL Files

| File | Purpose |
|------|---------|
| `1_Silver_Schema_Setup.sql` | Create Silver schema |
| `2_Silver_Target_Schemas.sql` | Target schema tables and procedures |
| `3_Silver_Field_Mappings.sql` | Field mapping tables |
| `4_Silver_Transformation_Rules.sql` | Transformation rules |
| `5_Silver_Transformation_Logic.sql` | MERGE-based transformation |
| `6_Silver_Tasks.sql` | Automated transformation tasks |
| `8_Load_Sample_Schemas.sql` | Load sample schema definitions (optional) |
| `7_Data_Quality_Checks.sql` | Comprehensive data quality validation |

---

## Data Quality Checks (v3.2)

### Overview
Comprehensive data quality validation runs on transformed Silver tables.

### Quality Checks Performed

**1. Row Count Validation**
- Ensures table has data

**2. Null Value Analysis**
- Checks null percentage for each column
- Threshold: < 50% nulls per column

**3. Duplicate Detection**
- Identifies duplicate `_RECORD_ID` values

**4. Completeness Score**
- Overall data completeness across all columns
- Threshold: ≥ 80%

**5. Data Freshness**
- Hours since last data load
- Threshold: ≤ 24 hours

**6. Range Validation**
- Checks for negative values in amount columns
- Validates numeric ranges

**7. Date Validation**
- Identifies future dates in date columns

**8. Overall Quality Score**
- Aggregate score: (passed checks / total checks) × 100
- Threshold: ≥ 80%

### Run Quality Checks

**Single Table:**
```sql
CALL SILVER.run_data_quality_checks('DENTAL_CLAIMS', 'provider_a');
```

**All Tables for TPA:**
```sql
CALL SILVER.run_data_quality_checks_all('provider_a');
```

**Via API:**
```bash
# Single table
POST /api/silver/quality/check?table_name=DENTAL_CLAIMS&tpa=provider_a

# All tables
POST /api/silver/quality/check-all?tpa=provider_a

# Get summary
GET /api/silver/quality/summary?tpa=provider_a

# Get failures
GET /api/silver/quality/failures?tpa=provider_a

# Get trends
GET /api/silver/quality/trends?tpa=provider_a&table_name=DENTAL_CLAIMS
```

### View Quality Metrics

**Summary View:**
```sql
SELECT * FROM SILVER.v_data_quality_summary WHERE tpa = 'provider_a';
```

**Failed Checks:**
```sql
SELECT * FROM SILVER.v_data_quality_failures WHERE tpa = 'provider_a';
```

**Quality Trends:**
```sql
SELECT * FROM SILVER.v_data_quality_trends 
WHERE tpa = 'provider_a' 
ORDER BY measured_timestamp DESC;
```

---

## Validation System (v3.1)

**Before creating mappings:**
- Checks for duplicate target columns
- Validates columns exist in physical table

**Before transformations:**
- Auto-validates all approved mappings
- Fails fast with clear error messages

**Manual validation:**
```bash
GET /api/silver/mappings/validate?tpa=provider_a&target_table=CLAIMS
```

---

## Documentation

**Quick Reference**: [docs/QUICK_REFERENCE.md](../docs/QUICK_REFERENCE.md)  
**Architecture**: [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)  
**Metadata Guide**: [docs/guides/SILVER_METADATA_COLUMNS.md](../docs/guides/SILVER_METADATA_COLUMNS.md)  
**Auto-Transform**: [docs/guides/SILVER_AUTO_TRANSFORM_TASK.md](../docs/guides/SILVER_AUTO_TRANSFORM_TASK.md)

---

**Version**: 3.1 | **Status**: ✅ Production Ready
