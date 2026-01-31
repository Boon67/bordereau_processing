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
