# TPA Complete Guide

**Comprehensive guide to TPA (Third Party Administrator) architecture and implementation.**

## Overview

TPA (Third Party Administrator) is a first-class dimension throughout the entire Snowflake File Processing Pipeline, enabling complete multi-tenant isolation where different healthcare providers/administrators can have completely different schemas, mappings, and business rules.

## TPA Architecture

### Core Principles

1. **TPA is REQUIRED**: Every metadata table includes TPA as part of unique constraints
2. **TPA from Path**: Bronze extracts TPA from file path automatically
3. **TPA Selection**: UI has TPA selection at top level
4. **TPA Filtering**: All queries filter by selected TPA
5. **TPA Tables**: Use TPA-specific table names (e.g., `CLAIMS_PROVIDER_A`)
6. **TPA Validation**: Validate TPA against `TPA_MASTER` table
7. **TPA Isolation**: Complete data isolation between TPAs

### TPA Data Flow

```
1. File Upload
   User selects TPA → Uploads file → Stored in @SRC/{tpa}/

2. Bronze Processing
   discover_files() extracts TPA from path → Stores in RAW_DATA_TABLE.TPA

3. Silver Configuration
   User selects TPA in UI → All operations filtered by TPA

4. Field Mapping
   Mappings defined per TPA → Same source field can map differently

5. Transformation
   Rules applied per TPA → Different validation per provider

6. Target Tables
   TPA-specific tables → CLAIMS_PROVIDER_A, CLAIMS_PROVIDER_B
```

## TPA Naming Convention

### TPA Codes

- **Format**: Lowercase with underscores
- **Examples**: `provider_a`, `blue_cross`, `united_health`
- **Rules**:
  - No spaces
  - No special characters except underscore
  - Maximum 500 characters
  - Must be unique

### Target Tables

- **Format**: `{TABLE_NAME}_{TPA_CODE}`
- **Examples**:
  - `CLAIMS_PROVIDER_A`
  - `MEMBERS_BLUE_CROSS`
  - `ELIGIBILITY_UNITED_HEALTH`

### File Paths

- **Format**: `@SRC/{tpa}/{filename}`
- **Examples**:
  - `@SRC/provider_a/claims-20240301.csv`
  - `@SRC/blue_cross/members-20240115.xlsx`

## TPA Implementation

### Bronze Layer

**TPA Master Table:**
```sql
CREATE TABLE TPA_MASTER (
    TPA_CODE VARCHAR(500) PRIMARY KEY,
    TPA_NAME VARCHAR(500) NOT NULL,
    TPA_DESCRIPTION VARCHAR(5000),
    ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

**Raw Data Table:**
```sql
CREATE TABLE RAW_DATA_TABLE (
    RECORD_ID NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    FILE_NAME VARCHAR(500) NOT NULL,
    FILE_ROW_NUMBER NUMBER(38,0) NOT NULL,
    TPA VARCHAR(500) NOT NULL,  -- REQUIRED
    RAW_DATA VARIANT NOT NULL,
    ...
);
```

**TPA Extraction:**
```sql
-- Extract TPA from file path
SELECT 
    SPLIT_PART(SPLIT_PART("name", '/', 1), '/', 1) AS tpa
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
```

### Silver Layer

**Target Schemas (TPA-aware):**
```sql
CREATE TABLE target_schemas (
    schema_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    table_name VARCHAR(500) NOT NULL,
    column_name VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,  -- REQUIRED
    ...
    CONSTRAINT uk_target_schemas UNIQUE (table_name, column_name, tpa)
);
```

**Field Mappings (TPA-aware):**
```sql
CREATE TABLE field_mappings (
    mapping_id NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
    source_field VARCHAR(500) NOT NULL,
    target_table VARCHAR(500) NOT NULL,
    target_column VARCHAR(500) NOT NULL,
    tpa VARCHAR(500) NOT NULL,  -- REQUIRED
    ...
    CONSTRAINT uk_field_mappings UNIQUE (source_field, target_table, target_column, tpa)
);
```

**Transformation Rules (TPA-aware):**
```sql
CREATE TABLE transformation_rules (
    rule_id VARCHAR(100) NOT NULL,
    tpa VARCHAR(500) NOT NULL,  -- REQUIRED
    ...
    CONSTRAINT pk_transformation_rules PRIMARY KEY (rule_id, tpa)
);
```

## TPA Management

### Adding New TPA

```sql
-- Method 1: Using procedure
CALL add_tpa('provider_f', 'Provider F Healthcare', 'Vision claims provider');

-- Method 2: Direct insert
INSERT INTO TPA_MASTER (TPA_CODE, TPA_NAME, TPA_DESCRIPTION)
VALUES ('provider_f', 'Provider F Healthcare', 'Vision claims provider');
```

### Deactivating TPA

```sql
-- Deactivate (stops processing new files)
CALL deactivate_tpa('provider_f');

-- Reactivate
CALL reactivate_tpa('provider_f');
```

### Viewing TPA Statistics

```sql
-- Comprehensive statistics
SELECT * FROM v_tpa_statistics;

-- Active TPAs only
SELECT * FROM TPA_MASTER WHERE ACTIVE = TRUE;
```

## TPA Benefits

### 1. Complete Isolation

Each TPA has independent:
- Schemas
- Field mappings
- Transformation rules
- Target tables
- Processing queues

### 2. Parallel Processing

Different TPAs can be processed simultaneously without conflicts.

### 3. Flexible Evolution

TPAs can change independently:
- Add/remove columns
- Change mappings
- Update rules
- No impact on other TPAs

### 4. Clear Governance

Easy to audit TPA-specific transformations:
```sql
-- View all mappings for a TPA
SELECT * FROM field_mappings WHERE tpa = 'provider_a';

-- View all rules for a TPA
SELECT * FROM transformation_rules WHERE tpa = 'provider_a';
```

### 5. Performance

Queries only scan relevant TPA data:
```sql
-- Efficient query (uses clustering)
SELECT * FROM RAW_DATA_TABLE WHERE TPA = 'provider_a';
```

### 6. Compliance

Physical data segregation for audits:
- Separate tables per TPA
- Clear data lineage
- Audit trail per TPA

### 7. Cost Allocation

Track storage and compute per TPA:
```sql
-- Storage by TPA
SELECT 
    TPA,
    COUNT(*) as records,
    SUM(LENGTH(RAW_DATA::STRING)) as bytes
FROM RAW_DATA_TABLE
GROUP BY TPA;
```

## TPA Best Practices

### 1. Naming

- Use descriptive TPA codes
- Document TPA names and descriptions
- Maintain consistent naming convention

### 2. Registration

- Register TPA before uploading files
- Validate TPA codes in applications
- Keep TPA_MASTER up to date

### 3. File Organization

- Always organize files by TPA folder
- Use consistent folder structure
- Include TPA in file names for clarity

### 4. Mappings

- Define mappings per TPA
- Document transformation logic
- Review and approve mappings

### 5. Rules

- Start with common rules across TPAs
- Customize rules per TPA as needed
- Document TPA-specific business logic

### 6. Monitoring

- Monitor processing per TPA
- Track quality metrics per TPA
- Alert on TPA-specific issues

### 7. Testing

- Test with sample data per TPA
- Validate mappings per TPA
- Verify rules per TPA

## TPA Examples

### Example 1: Different Field Names

**Provider A (Dental):**
- Source: `CLAIM_NUM`
- Target: `CLAIMS_PROVIDER_A.CLAIM_ID`

**Provider B (Medical):**
- Source: `CLAIM_ID`
- Target: `CLAIMS_PROVIDER_B.CLAIM_ID`

### Example 2: Different Data Types

**Provider A:**
- Source: `DOB` (string: "1985-03-15")
- Transformation: `TO_DATE(DOB)`
- Target: `DATE_OF_BIRTH DATE`

**Provider B:**
- Source: `DATE_OF_BIRTH` (string: "03/15/1985")
- Transformation: `TO_DATE(DATE_OF_BIRTH, 'MM/DD/YYYY')`
- Target: `DATE_OF_BIRTH DATE`

### Example 3: Different Business Rules

**Provider A:**
```sql
-- Rule: Dental claims must have valid procedure codes
rule_logic: PROCEDURE IN (SELECT code FROM dental_procedure_codes)
```

**Provider B:**
```sql
-- Rule: Medical claims must have valid diagnosis codes
rule_logic: DIAGNOSIS_CODE IN (SELECT code FROM icd10_codes)
```

## Related Documentation

- [User Guide](../USER_GUIDE.md)
- [Bronze README](../../bronze/README.md)
- [Silver README](../../silver/README.md)
- [TPA Upload Guide](../../bronze/TPA_UPLOAD_GUIDE.md)
- [TPA Mapping Guide](../../silver/TPA_MAPPING_GUIDE.md)

---

**Version**: 1.0  
**Last Updated**: January 15, 2026
