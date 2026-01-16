# Silver Layer - Transformation & Quality

**Transform Bronze raw data into clean, standardized Silver tables using TPA-specific mappings and rules.**

## Overview

The Silver layer provides:
- Dynamic schema management (create tables from metadata)
- Three mapping methods: Manual CSV, ML Pattern Matching, LLM Cortex AI
- Comprehensive rules engine with 5 rule types
- Quality tracking and quarantine system
- Incremental processing with watermarks

## Architecture

### Metadata Tables (8)

1. **`target_schemas`** - Dynamic target table definitions per TPA
2. **`field_mappings`** - Bronze → Silver field mappings per TPA
3. **`transformation_rules`** - Data quality and business rules per TPA
4. **`silver_processing_log`** - Transformation batch audit trail
5. **`data_quality_metrics`** - Quality tracking per TPA and batch
6. **`quarantine_records`** - Failed validation records
7. **`processing_watermarks`** - Incremental processing state per TPA
8. **`llm_prompt_templates`** - LLM prompt templates for field mapping

### Field Mapping Methods

1. **Manual CSV**: User-defined mappings loaded from CSV files
2. **ML Pattern Matching**: Auto-suggest using similarity algorithms (exact, substring, TF-IDF)
3. **LLM Cortex AI**: Semantic understanding using Snowflake Cortex AI models

### Rule Types

1. **DATA_QUALITY**: Null checks, format validation, range checks
2. **BUSINESS_LOGIC**: Calculations, lookups, conditional transformations
3. **STANDARDIZATION**: Date normalization, name casing, code mapping
4. **DEDUPLICATION**: Exact/fuzzy matching with conflict resolution
5. **REFERENTIAL_INTEGRITY**: Foreign key validation, lookup validation

## Deployment

```bash
# Deploy Silver layer only
./deploy_silver.sh

# Or deploy entire pipeline
./deploy.sh
```

## Usage

See [User Guide](../docs/USER_GUIDE.md) and [TPA Mapping Guide](TPA_MAPPING_GUIDE.md) for detailed instructions.

---

**Version**: 1.0  
**Last Updated**: January 15, 2026
