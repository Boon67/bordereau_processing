# Data Flow Documentation

**Bordereau Processing Pipeline**  
**Version**: 2.0  
**Date**: January 19, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [End-to-End Data Flow](#end-to-end-data-flow)
3. [Bronze Layer Data Flow](#bronze-layer-data-flow)
4. [Silver Layer Data Flow](#silver-layer-data-flow)
5. [Gold Layer Data Flow](#gold-layer-data-flow)
6. [Task Orchestration Flow](#task-orchestration-flow)
7. [Error Handling Flow](#error-handling-flow)
8. [Data Quality Flow](#data-quality-flow)

---

## Overview

The Bordereau Processing Pipeline implements a **medallion architecture** with three distinct layers, each serving a specific purpose in the data transformation journey from raw files to analytics-ready datasets.

### Data Flow Principles

1. **Unidirectional**: Data flows Bronze → Silver → Gold
2. **Immutable Bronze**: Raw data never modified
3. **Versioned**: All transformations tracked
4. **Auditable**: Complete lineage maintained
5. **Recoverable**: Failed records quarantined, not lost

---

## End-to-End Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COMPLETE DATA FLOW                                   │
└─────────────────────────────────────────────────────────────────────────────┘

                              START
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                           FILE UPLOAD                                     │
│                                                                           │
│  User/System                                                              │
│      │                                                                    │
│      ├─── Manual Upload (UI)                                             │
│      ├─── SFTP/FTP                                                        │
│      ├─── S3/Azure/GCS                                                    │
│      └─── API Upload                                                      │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                        BRONZE LAYER (Raw Data)                            │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 1. File Registration                                            │    │
│  │    • Generate file_id                                           │    │
│  │    • Extract metadata (size, format, TPA)                       │    │
│  │    • Store in @BRONZE_STAGE                                     │    │
│  │    • Insert into raw_claims_data                                │    │
│  │    • Status: UPLOADED                                           │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                │                                          │
│                                ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 2. File Validation                                              │    │
│  │    • Check file format                                          │    │
│  │    • Validate TPA configuration                                 │    │
│  │    • Verify file structure                                      │    │
│  │    • Parse headers                                              │    │
│  │    • Status: VALIDATING                                         │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                │                                          │
│                                ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 3. File Processing                                              │    │
│  │    • Load data into raw_claims_data                             │    │
│  │    • Preserve original format                                   │    │
│  │    • Add processing metadata                                    │    │
│  │    • Log to file_processing_log                                 │    │
│  │    • Status: PROCESSED                                          │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  Output: Raw data in Bronze tables (immutable)                           │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                      SILVER LAYER (Cleaned Data)                          │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 1. Schema Mapping                                               │    │
│  │    • Load target schema for TPA                                 │    │
│  │    • Retrieve field mappings                                    │    │
│  │    • Apply transformation logic                                 │    │
│  │    • AI-powered mapping suggestions (if needed)                 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                │                                          │
│                                ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 2. Data Transformation                                          │    │
│  │    • Apply field mappings                                       │    │
│  │    • Execute transformation rules                               │    │
│  │    • Data type conversions                                      │    │
│  │    • Standardization                                            │    │
│  │    • Deduplication                                              │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                │                                          │
│                                ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 3. Data Quality Checks                                          │    │
│  │    • Completeness validation                                    │    │
│  │    • Business rule validation                                   │    │
│  │    • Referential integrity                                      │    │
│  │    • Data quality scoring                                       │    │
│  │    • Failed records → quarantine_records                        │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                │                                          │
│                                ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 4. Load to Silver Tables                                        │    │
│  │    • Insert into CLAIMS_<TPA>                                   │    │
│  │    • Insert into MEMBERS_<TPA>                                  │    │
│  │    • Insert into PROVIDERS_<TPA>                                │    │
│  │    • Update processing watermarks                               │    │
│  │    • Log to silver_processing_log                               │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  Output: Cleaned, standardized data in Silver tables                     │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                       GOLD LAYER (Analytics Data)                         │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 1. Data Aggregation                                             │    │
│  │    • Load transformation rules                                  │    │
│  │    • Load field mappings (Silver → Gold)                        │    │
│  │    • Apply aggregation functions                                │    │
│  │    • Calculate derived metrics                                  │    │
│  │    • Apply business logic                                       │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                │                                          │
│                                ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 2. Analytics Table Population                                   │    │
│  │    • CLAIMS_ANALYTICS_ALL                                       │    │
│  │      - Aggregate by year/month/type                             │    │
│  │      - Calculate totals, averages, counts                       │    │
│  │    • MEMBER_360_ALL                                             │    │
│  │      - Consolidate member data                                  │    │
│  │      - Calculate lifetime metrics                               │    │
│  │    • PROVIDER_PERFORMANCE_ALL                                   │    │
│  │      - Provider KPIs                                            │    │
│  │      - Quality scores                                           │    │
│  │    • FINANCIAL_SUMMARY_ALL                                      │    │
│  │      - Financial metrics                                        │    │
│  │      - Loss ratios, margins                                     │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                │                                          │
│                                ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 3. Quality Validation                                           │    │
│  │    • Execute quality rules                                      │    │
│  │    • Validate business metrics                                  │    │
│  │    • Check data completeness                                    │    │
│  │    • Verify consistency                                         │    │
│  │    • Log to quality_check_results                               │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                │                                          │
│                                ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ 4. Business Metrics Calculation                                 │    │
│  │    • Total claims count                                         │    │
│  │    • Average claim amount                                       │    │
│  │    • Member retention rate                                      │    │
│  │    • Provider utilization                                       │    │
│  │    • Loss ratio                                                 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  Output: Analytics-ready data for BI tools and reporting                 │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                          CONSUMPTION                                      │
│                                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │   Tableau   │  │  Power BI   │  │   Looker    │  │   Custom    │   │
│  │ Dashboards  │  │   Reports   │  │  Analytics  │  │     UI      │   │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                               END
```

---

## Bronze Layer Data Flow

### Detailed Bronze Processing

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      BRONZE LAYER DETAILED FLOW                         │
└─────────────────────────────────────────────────────────────────────────┘

Step 1: File Upload
═══════════════════════════════════════════════════════════════════════════

  User Action                    System Action
  ───────────                    ─────────────
      │
      │ Select File
      │ Select TPA
      │ Click Upload
      │
      ▼
  ┌─────────────────────┐
  │  POST /api/bronze/  │
  │       upload        │
  └─────────────────────┘
      │
      ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │ Backend Processing:                                             │
  │                                                                 │
  │ 1. Receive file and metadata                                    │
  │    - File content                                               │
  │    - TPA identifier                                             │
  │    - Original filename                                          │
  │    - MIME type                                                  │
  │                                                                 │
  │ 2. Generate unique file_id                                      │
  │    file_id = UUID()                                             │
  │                                                                 │
  │ 3. Upload to Snowflake stage                                    │
  │    PUT file://<local_path>                                      │
  │        @BRONZE_STAGE/<tpa>/<file_id>/                          │
  │                                                                 │
  │ 4. Register in database                                         │
  │    INSERT INTO raw_claims_data (                                │
  │        file_id,                                                 │
  │        tpa,                                                     │
  │        file_name,                                               │
  │        file_path,                                               │
  │        upload_timestamp,                                        │
  │        file_size,                                               │
  │        status,                                                  │
  │        metadata                                                 │
  │    ) VALUES (...)                                               │
  │                                                                 │
  │ 5. Log upload event                                             │
  │    INSERT INTO file_processing_log (                            │
  │        file_id,                                                 │
  │        tpa,                                                     │
  │        stage = 'UPLOAD',                                        │
  │        status = 'SUCCESS'                                       │
  │    )                                                            │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘
      │
      ▼
  ┌─────────────────────┐
  │  Return Response    │
  │  {                  │
  │    file_id: "...",  │
  │    status: "..."    │
  │  }                  │
  └─────────────────────┘


Step 2: Automated Processing (Task-Driven)
═══════════════════════════════════════════════════════════════════════════

  Every 5 minutes:
  ┌─────────────────────────────────────────────────────────────────┐
  │ task_auto_process_files                                         │
  │                                                                 │
  │ 1. Find unprocessed files                                       │
  │    SELECT * FROM raw_claims_data                                │
  │    WHERE status = 'UPLOADED'                                    │
  │    ORDER BY upload_timestamp                                    │
  │    LIMIT 10;                                                    │
  │                                                                 │
  │ 2. For each file:                                               │
  │    CALL process_file(file_id);                                  │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘
      │
      ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │ process_file() Procedure                                        │
  │                                                                 │
  │ 1. Update status to PROCESSING                                  │
  │                                                                 │
  │ 2. Validate file format                                         │
  │    • Check file extension                                       │
  │    • Verify TPA configuration exists                            │
  │    • Validate delimiter/format                                  │
  │                                                                 │
  │ 3. Parse file headers                                           │
  │    • Extract column names                                       │
  │    • Detect data types                                          │
  │    • Count columns                                              │
  │                                                                 │
  │ 4. Load data                                                    │
  │    COPY INTO raw_claims_data_temp                               │
  │    FROM @BRONZE_STAGE/<path>                                    │
  │    FILE_FORMAT = (                                              │
  │        TYPE = CSV,                                              │
  │        FIELD_DELIMITER = ',',                                   │
  │        SKIP_HEADER = 1                                          │
  │    );                                                           │
  │                                                                 │
  │ 5. Update metadata                                              │
  │    UPDATE raw_claims_data                                       │
  │    SET                                                          │
  │        status = 'PROCESSED',                                    │
  │        row_count = <count>,                                     │
  │        processed_timestamp = CURRENT_TIMESTAMP()                │
  │    WHERE file_id = <file_id>;                                   │
  │                                                                 │
  │ 6. Log completion                                               │
  │    INSERT INTO file_processing_log (...)                        │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘


Step 3: Error Handling
═══════════════════════════════════════════════════════════════════════════

  If validation fails:
  ┌─────────────────────────────────────────────────────────────────┐
  │ 1. Update status to FAILED                                      │
  │                                                                 │
  │ 2. Log error details                                            │
  │    INSERT INTO file_processing_log (                            │
  │        file_id,                                                 │
  │        status = 'FAILED',                                       │
  │        error_message = <error>                                  │
  │    )                                                            │
  │                                                                 │
  │ 3. Move file to error location                                 │
  │    @BRONZE_STAGE/errors/<tpa>/<file_id>/                       │
  │                                                                 │
  │ 4. Notify administrators                                        │
  │    (Future: Email/Slack notification)                           │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘


Data State at Each Step:
═══════════════════════════════════════════════════════════════════════════

┌──────────────┬─────────────┬──────────────────────────────────────┐
│    Status    │   Location  │           Description                │
├──────────────┼─────────────┼──────────────────────────────────────┤
│  UPLOADED    │ @STAGE only │ File uploaded, not yet processed    │
│  VALIDATING  │ @STAGE      │ Validation in progress               │
│  PROCESSING  │ @STAGE      │ Loading data into tables             │
│  PROCESSED   │ @STAGE+DB   │ Data loaded, ready for Silver        │
│  FAILED      │ @STAGE/err  │ Processing failed, needs review      │
└──────────────┴─────────────┴──────────────────────────────────────┘
```

---

## Silver Layer Data Flow

### Detailed Silver Transformation

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     SILVER LAYER DETAILED FLOW                          │
└─────────────────────────────────────────────────────────────────────────┘

Trigger: Bronze data processed OR Manual transformation request
═══════════════════════════════════════════════════════════════════════════

Step 1: Schema Resolution
───────────────────────────────────────────────────────────────────────────

  ┌─────────────────────────────────────────────────────────────────┐
  │ 1. Load Target Schema for TPA                                  │
  │                                                                 │
  │    SELECT                                                       │
  │        table_name,                                              │
  │        column_name,                                             │
  │        data_type,                                               │
  │        nullable                                                 │
  │    FROM target_schemas                                          │
  │    WHERE tpa = <tpa>                                            │
  │      AND active = TRUE                                          │
  │    ORDER BY table_name, column_name;                            │
  │                                                                 │
  │    Result: Target schema definition                             │
  │    ┌──────────────┬─────────────┬───────────┬──────────┐      │
  │    │ table_name   │ column_name │ data_type │ nullable │      │
  │    ├──────────────┼─────────────┼───────────┼──────────┤      │
  │    │ CLAIMS_TPA_A │ claim_id    │ VARCHAR   │ FALSE    │      │
  │    │ CLAIMS_TPA_A │ member_id   │ VARCHAR   │ FALSE    │      │
  │    │ CLAIMS_TPA_A │ paid_amount │ NUMBER    │ TRUE     │      │
  │    └──────────────┴─────────────┴───────────┴──────────┘      │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘


Step 2: Field Mapping Resolution
───────────────────────────────────────────────────────────────────────────

  ┌─────────────────────────────────────────────────────────────────┐
  │ 2. Load Field Mappings                                          │
  │                                                                 │
  │    SELECT                                                       │
  │        source_field,                                            │
  │        target_table,                                            │
  │        target_column,                                           │
  │        transformation_logic,                                    │
  │        mapping_method                                           │
  │    FROM field_mappings                                          │
  │    WHERE tpa = <tpa>                                            │
  │      AND approved = TRUE                                        │
  │      AND active = TRUE;                                         │
  │                                                                 │
  │    Result: Field mapping definitions                            │
  │    ┌──────────────┬──────────────┬──────────────┬────────────┐│
  │    │ source_field │ target_table │ target_col   │ transform  ││
  │    ├──────────────┼──────────────┼──────────────┼────────────┤│
  │    │ ClaimNumber  │ CLAIMS_TPA_A │ claim_id     │ DIRECT     ││
  │    │ PatientID    │ CLAIMS_TPA_A │ member_id    │ DIRECT     ││
  │    │ PaidAmount   │ CLAIMS_TPA_A │ paid_amount  │ TO_NUMBER  ││
  │    └──────────────┴──────────────┴──────────────┴────────────┘│
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘


Step 3: Transformation Execution
───────────────────────────────────────────────────────────────────────────

  ┌─────────────────────────────────────────────────────────────────┐
  │ 3. Apply Transformations                                        │
  │                                                                 │
  │    MERGE INTO CLAIMS_TPA_A AS target                            │
  │    USING (                                                      │
  │        SELECT                                                   │
  │            ClaimNumber AS claim_id,                             │
  │            PatientID AS member_id,                              │
  │            TO_NUMBER(PaidAmount) AS paid_amount,                │
  │            CURRENT_TIMESTAMP() AS processed_at,                 │
  │            'BRONZE_TO_SILVER' AS source_system                  │
  │        FROM raw_claims_data                                     │
  │        WHERE tpa = <tpa>                                        │
  │          AND status = 'PROCESSED'                               │
  │          AND file_id = <file_id>                                │
  │    ) AS source                                                  │
  │    ON target.claim_id = source.claim_id                         │
  │    WHEN MATCHED THEN                                            │
  │        UPDATE SET                                               │
  │            target.paid_amount = source.paid_amount,             │
  │            target.updated_at = CURRENT_TIMESTAMP()              │
  │    WHEN NOT MATCHED THEN                                        │
  │        INSERT (claim_id, member_id, paid_amount, ...)           │
  │        VALUES (source.claim_id, source.member_id, ...);         │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘


Step 4: Data Quality Checks
───────────────────────────────────────────────────────────────────────────

  ┌─────────────────────────────────────────────────────────────────┐
  │ 4. Execute Quality Rules                                        │
  │                                                                 │
  │    For each rule in transformation_rules:                       │
  │                                                                 │
  │    Rule 1: Completeness Check                                   │
  │    ──────────────────────────                                   │
  │    SELECT COUNT(*) AS failed_count                              │
  │    FROM CLAIMS_TPA_A                                            │
  │    WHERE claim_id IS NULL                                       │
  │       OR member_id IS NULL;                                     │
  │                                                                 │
  │    If failed_count > 0:                                         │
  │        INSERT INTO quarantine_records (...)                     │
  │        error_action = 'QUARANTINE'                              │
  │                                                                 │
  │    Rule 2: Business Logic Validation                            │
  │    ───────────────────────────────────                          │
  │    SELECT COUNT(*) AS failed_count                              │
  │    FROM CLAIMS_TPA_A                                            │
  │    WHERE paid_amount < 0                                        │
  │       OR paid_amount > 1000000;                                 │
  │                                                                 │
  │    If failed_count > 0:                                         │
  │        UPDATE CLAIMS_TPA_A                                      │
  │        SET quality_flag = 'REVIEW_REQUIRED'                     │
  │        WHERE ...                                                │
  │                                                                 │
  │    Rule 3: Referential Integrity                                │
  │    ──────────────────────────────                               │
  │    SELECT c.claim_id                                            │
  │    FROM CLAIMS_TPA_A c                                          │
  │    LEFT JOIN MEMBERS_TPA_A m                                    │
  │        ON c.member_id = m.member_id                             │
  │    WHERE m.member_id IS NULL;                                   │
  │                                                                 │
  │    Failed records → quarantine_records                          │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘


Step 5: Logging and Watermarking
───────────────────────────────────────────────────────────────────────────

  ┌─────────────────────────────────────────────────────────────────┐
  │ 5. Update Processing Metadata                                   │
  │                                                                 │
  │    -- Log processing results                                    │
  │    INSERT INTO silver_processing_log (                          │
  │        run_id,                                                  │
  │        tpa,                                                     │
  │        source_file_id,                                          │
  │        target_table,                                            │
  │        records_processed,                                       │
  │        records_inserted,                                        │
  │        records_updated,                                         │
  │        records_quarantined,                                     │
  │        processing_timestamp,                                    │
  │        status                                                   │
  │    ) VALUES (...);                                              │
  │                                                                 │
  │    -- Update watermark for incremental processing               │
  │    MERGE INTO processing_watermarks                             │
  │    USING (SELECT <tpa>, <table>, <timestamp>) AS source         │
  │    ON watermarks.tpa = source.tpa                               │
  │       AND watermarks.table_name = source.table_name             │
  │    WHEN MATCHED THEN                                            │
  │        UPDATE SET last_processed_timestamp = source.timestamp   │
  │    WHEN NOT MATCHED THEN                                        │
  │        INSERT (tpa, table_name, last_processed_timestamp)       │
  │        VALUES (source.tpa, source.table_name, ...);             │
  │                                                                 │
  │    -- Update quality metrics                                    │
  │    INSERT INTO data_quality_metrics (                           │
  │        tpa,                                                     │
  │        table_name,                                              │
  │        metric_name,                                             │
  │        metric_value,                                            │
  │        measurement_timestamp                                    │
  │    ) VALUES                                                     │
  │        (<tpa>, 'CLAIMS_TPA_A', 'completeness', 0.98, ...),     │
  │        (<tpa>, 'CLAIMS_TPA_A', 'accuracy', 0.95, ...);         │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘


AI-Powered Mapping Suggestion Flow
═══════════════════════════════════════════════════════════════════════════

  When mappings don't exist or confidence is low:
  ┌─────────────────────────────────────────────────────────────────┐
  │ suggest_mappings_llm() Procedure                                │
  │                                                                 │
  │ 1. Extract source fields from Bronze                            │
  │    SELECT DISTINCT column_name                                  │
  │    FROM raw_claims_data_metadata                                │
  │    WHERE file_id = <file_id>;                                   │
  │                                                                 │
  │ 2. Get target schema                                            │
  │    SELECT column_name, description                              │
  │    FROM target_schemas                                          │
  │    WHERE tpa = <tpa>;                                           │
  │                                                                 │
  │ 3. Build LLM prompt                                             │
  │    prompt = """                                                 │
  │    Source fields: ClaimNumber, PatientID, PaidAmount            │
  │    Target fields: claim_id, member_id, paid_amount              │
  │    Suggest mappings with confidence scores.                     │
  │    """                                                          │
  │                                                                 │
  │ 4. Call Snowflake Cortex                                        │
  │    SELECT SNOWFLAKE.CORTEX.COMPLETE(                            │
  │        'snowflake-arctic',                                      │
  │        prompt                                                   │
  │    ) AS suggestions;                                            │
  │                                                                 │
  │ 5. Parse LLM response                                           │
  │    [                                                            │
  │        {                                                        │
  │            "source": "ClaimNumber",                             │
  │            "target": "claim_id",                                │
  │            "confidence": 0.95,                                  │
  │            "reasoning": "Direct field name match"               │
  │        },                                                       │
  │        {                                                        │
  │            "source": "PatientID",                               │
  │            "target": "member_id",                               │
  │            "confidence": 0.85,                                  │
  │            "reasoning": "Semantic similarity"                   │
  │        }                                                        │
  │    ]                                                            │
  │                                                                 │
  │ 6. Insert suggested mappings                                    │
  │    INSERT INTO field_mappings (                                 │
  │        source_field,                                            │
  │        target_column,                                           │
  │        tpa,                                                     │
  │        mapping_method = 'LLM_CORTEX',                           │
  │        confidence_score,                                        │
  │        approved = FALSE  -- Requires human approval             │
  │    ) VALUES (...);                                              │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘
```

---

## Gold Layer Data Flow

### Detailed Gold Aggregation

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      GOLD LAYER DETAILED FLOW                           │
└─────────────────────────────────────────────────────────────────────────┘

Trigger: Daily scheduled task (1 AM) OR Manual refresh
═══════════════════════════════════════════════════════════════════════════

Master Orchestration Flow
───────────────────────────────────────────────────────────────────────────

  ┌─────────────────────────────────────────────────────────────────┐
  │ task_master_gold_refresh (Daily 1 AM)                           │
  │                                                                 │
  │ CALL run_gold_transformations();                                │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘
      │
      ├──── Triggers ────┐
      │                  │
      ▼                  ▼
  task_refresh_      task_refresh_
  claims_analytics   member_360
  (2 AM)             (3 AM)
      │                  │
      └────── Triggers ──┘
                 │
                 ▼
         task_quality_checks
              (4 AM)


Step 1: Claims Analytics Transformation
───────────────────────────────────────────────────────────────────────────

  ┌─────────────────────────────────────────────────────────────────┐
  │ transform_claims_analytics() Procedure                          │
  │                                                                 │
  │ 1. Load transformation rules                                    │
  │    SELECT * FROM transformation_rules                           │
  │    WHERE target_table = 'CLAIMS_ANALYTICS_ALL'                  │
  │      AND is_active = TRUE                                       │
  │    ORDER BY execution_order;                                    │
  │                                                                 │
  │ 2. Load field mappings                                          │
  │    SELECT * FROM field_mappings                                 │
  │    WHERE target_table = 'CLAIMS_ANALYTICS_ALL'                  │
  │      AND is_active = TRUE;                                      │
  │                                                                 │
  │ 3. Execute aggregation                                          │
  │    MERGE INTO CLAIMS_ANALYTICS_ALL AS target                    │
  │    USING (                                                      │
  │        SELECT                                                   │
  │            tpa,                                                 │
  │            YEAR(claim_date) AS claim_year,                      │
  │            MONTH(claim_date) AS claim_month,                    │
  │            claim_type,                                          │
  │            COUNT(DISTINCT claim_id) AS total_claims,            │
  │            SUM(paid_amount) AS total_paid_amount,               │
  │            AVG(paid_amount) AS avg_claim_amount,                │
  │            COUNT(DISTINCT member_id) AS unique_members,         │
  │            COUNT(DISTINCT provider_id) AS unique_providers,     │
  │            MIN(claim_date) AS first_claim_date,                 │
  │            MAX(claim_date) AS last_claim_date,                  │
  │            CURRENT_TIMESTAMP() AS last_updated                  │
  │        FROM (                                                   │
  │            -- Union all TPA claims tables                       │
  │            SELECT * FROM SILVER.CLAIMS_PROVIDER_A               │
  │            UNION ALL                                            │
  │            SELECT * FROM SILVER.CLAIMS_PROVIDER_B               │
  │            UNION ALL                                            │
  │            SELECT * FROM SILVER.CLAIMS_PROVIDER_C               │
  │            -- ... more TPAs ...                                 │
  │        )                                                        │
  │        GROUP BY                                                 │
  │            tpa,                                                 │
  │            YEAR(claim_date),                                    │
  │            MONTH(claim_date),                                   │
  │            claim_type                                           │
  │    ) AS source                                                  │
  │    ON target.tpa = source.tpa                                   │
  │       AND target.claim_year = source.claim_year                 │
  │       AND target.claim_month = source.claim_month               │
  │       AND target.claim_type = source.claim_type                 │
  │    WHEN MATCHED THEN                                            │
  │        UPDATE SET                                               │
  │            target.total_claims = source.total_claims,           │
  │            target.total_paid_amount = source.total_paid_amount, │
  │            target.avg_claim_amount = source.avg_claim_amount,   │
  │            target.last_updated = source.last_updated            │
  │    WHEN NOT MATCHED THEN                                        │
  │        INSERT (tpa, claim_year, claim_month, ...)               │
  │        VALUES (source.tpa, source.claim_year, ...);             │
  │                                                                 │
  │ 4. Log processing                                               │
  │    INSERT INTO processing_log (                                 │
  │        run_id,                                                  │
  │        table_name = 'CLAIMS_ANALYTICS_ALL',                     │
  │        tpa = 'ALL',                                             │
  │        process_type = 'AGGREGATION',                            │
  │        status = 'COMPLETED',                                    │
  │        records_processed,                                       │
  │        records_inserted,                                        │
  │        records_updated,                                         │
  │        start_time,                                              │
  │        end_time,                                                │
  │        duration_seconds                                         │
  │    ) VALUES (...);                                              │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘


Step 2: Member 360 Transformation
───────────────────────────────────────────────────────────────────────────

  ┌─────────────────────────────────────────────────────────────────┐
  │ transform_member_360() Procedure                                │
  │                                                                 │
  │ 1. Consolidate member data from all TPAs                        │
  │                                                                 │
  │    MERGE INTO MEMBER_360_ALL AS target                          │
  │    USING (                                                      │
  │        SELECT                                                   │
  │            m.tpa,                                               │
  │            m.member_id,                                         │
  │            m.member_name,                                       │
  │            m.date_of_birth,                                     │
  │            m.gender,                                            │
  │            -- Aggregate claims data                             │
  │            COUNT(c.claim_id) AS total_claims,                   │
  │            SUM(c.paid_amount) AS total_paid,                    │
  │            AVG(c.paid_amount) AS avg_claim_amount,              │
  │            MIN(c.claim_date) AS first_claim_date,               │
  │            MAX(c.claim_date) AS last_claim_date,                │
  │            -- Calculate member tenure                           │
  │            DATEDIFF(day,                                        │
  │                MIN(c.claim_date),                               │
  │                MAX(c.claim_date)                                │
  │            ) AS member_tenure_days,                             │
  │            -- Risk scoring (placeholder)                        │
  │            CASE                                                 │
  │                WHEN COUNT(c.claim_id) > 50 THEN 'HIGH'          │
  │                WHEN COUNT(c.claim_id) > 20 THEN 'MEDIUM'        │
  │                ELSE 'LOW'                                       │
  │            END AS risk_category,                                │
  │            -- Chronic conditions (from diagnosis codes)         │
  │            ARRAY_AGG(DISTINCT c.diagnosis_code) AS conditions,  │
  │            CURRENT_TIMESTAMP() AS last_updated                  │
  │        FROM (                                                   │
  │            SELECT * FROM SILVER.MEMBERS_PROVIDER_A              │
  │            UNION ALL                                            │
  │            SELECT * FROM SILVER.MEMBERS_PROVIDER_B              │
  │            -- ... more TPAs ...                                 │
  │        ) m                                                      │
  │        LEFT JOIN (                                              │
  │            SELECT * FROM SILVER.CLAIMS_PROVIDER_A               │
  │            UNION ALL                                            │
  │            SELECT * FROM SILVER.CLAIMS_PROVIDER_B               │
  │            -- ... more TPAs ...                                 │
  │        ) c ON m.tpa = c.tpa AND m.member_id = c.member_id       │
  │        GROUP BY                                                 │
  │            m.tpa,                                               │
  │            m.member_id,                                         │
  │            m.member_name,                                       │
  │            m.date_of_birth,                                     │
  │            m.gender                                             │
  │    ) AS source                                                  │
  │    ON target.tpa = source.tpa                                   │
  │       AND target.member_id = source.member_id                   │
  │    WHEN MATCHED THEN                                            │
  │        UPDATE SET /* all fields */                              │
  │    WHEN NOT MATCHED THEN                                        │
  │        INSERT /* all fields */;                                 │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘


Step 3: Quality Checks
───────────────────────────────────────────────────────────────────────────

  ┌─────────────────────────────────────────────────────────────────┐
  │ execute_quality_checks() Procedure                              │
  │                                                                 │
  │ For each quality_rule WHERE is_active = TRUE:                   │
  │                                                                 │
  │ Quality Rule 1: Completeness Check                              │
  │ ────────────────────────────────────────                        │
  │ Rule: "All claims must have paid_amount"                        │
  │                                                                 │
  │ SELECT                                                          │
  │     COUNT(*) AS records_checked,                                │
  │     COUNT(CASE WHEN paid_amount IS NULL THEN 1 END)             │
  │         AS records_failed,                                      │
  │     COUNT(CASE WHEN paid_amount IS NOT NULL THEN 1 END)         │
  │         AS records_passed                                       │
  │ FROM CLAIMS_ANALYTICS_ALL                                       │
  │ WHERE tpa = <tpa>;                                              │
  │                                                                 │
  │ pass_rate = records_passed / records_checked                    │
  │ threshold_met = (pass_rate >= 0.95)                             │
  │ status = CASE                                                   │
  │     WHEN threshold_met THEN 'PASSED'                            │
  │     WHEN pass_rate >= 0.90 THEN 'WARNING'                       │
  │     ELSE 'FAILED'                                               │
  │ END                                                             │
  │                                                                 │
  │ INSERT INTO quality_check_results (...)                         │
  │                                                                 │
  │                                                                 │
  │ Quality Rule 2: Consistency Check                               │
  │ ───────────────────────────────────                             │
  │ Rule: "Total claims = sum of claims by type"                    │
  │                                                                 │
  │ WITH aggregates AS (                                            │
  │     SELECT                                                      │
  │         tpa,                                                    │
  │         claim_year,                                             │
  │         claim_month,                                            │
  │         SUM(total_claims) AS sum_by_type                        │
  │     FROM CLAIMS_ANALYTICS_ALL                                   │
  │     WHERE claim_type IS NOT NULL                                │
  │     GROUP BY tpa, claim_year, claim_month                       │
  │ ),                                                              │
  │ totals AS (                                                     │
  │     SELECT                                                      │
  │         tpa,                                                    │
  │         claim_year,                                             │
  │         claim_month,                                            │
  │         total_claims                                            │
  │     FROM CLAIMS_ANALYTICS_ALL                                   │
  │     WHERE claim_type = 'ALL'                                    │
  │ )                                                               │
  │ SELECT                                                          │
  │     COUNT(*) AS records_checked,                                │
  │     COUNT(CASE                                                  │
  │         WHEN ABS(t.total_claims - a.sum_by_type) > 0.01        │
  │         THEN 1                                                  │
  │     END) AS records_failed                                      │
  │ FROM totals t                                                   │
  │ JOIN aggregates a                                               │
  │     ON t.tpa = a.tpa                                            │
  │     AND t.claim_year = a.claim_year                             │
  │     AND t.claim_month = a.claim_month;                          │
  │                                                                 │
  │ INSERT INTO quality_check_results (...)                         │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘


Step 4: Business Metrics Calculation
───────────────────────────────────────────────────────────────────────────

  ┌─────────────────────────────────────────────────────────────────┐
  │ Calculate Business Metrics                                      │
  │                                                                 │
  │ For each business_metric WHERE is_active = TRUE:                │
  │                                                                 │
  │ Metric 1: Total Claims Count                                    │
  │ ──────────────────────────────                                  │
  │ SELECT                                                          │
  │     'TOTAL_CLAIMS_COUNT' AS metric_name,                        │
  │     tpa,                                                        │
  │     SUM(total_claims) AS metric_value,                          │
  │     CURRENT_TIMESTAMP() AS calculated_at                        │
  │ FROM CLAIMS_ANALYTICS_ALL                                       │
  │ WHERE claim_year = YEAR(CURRENT_DATE())                         │
  │ GROUP BY tpa;                                                   │
  │                                                                 │
  │                                                                 │
  │ Metric 2: Average Claim Amount                                  │
  │ ────────────────────────────────                                │
  │ SELECT                                                          │
  │     'AVG_CLAIM_AMOUNT' AS metric_name,                          │
  │     tpa,                                                        │
  │     AVG(avg_claim_amount) AS metric_value,                      │
  │     CURRENT_TIMESTAMP() AS calculated_at                        │
  │ FROM CLAIMS_ANALYTICS_ALL                                       │
  │ WHERE claim_year = YEAR(CURRENT_DATE())                         │
  │ GROUP BY tpa;                                                   │
  │                                                                 │
  │                                                                 │
  │ Metric 3: Loss Ratio                                            │
  │ ─────────────────────                                           │
  │ SELECT                                                          │
  │     'LOSS_RATIO' AS metric_name,                                │
  │     tpa,                                                        │
  │     (SUM(total_paid_amount) /                                   │
  │      SUM(total_premium_collected)) * 100 AS metric_value,       │
  │     CURRENT_TIMESTAMP() AS calculated_at                        │
  │ FROM FINANCIAL_SUMMARY_ALL                                      │
  │ WHERE fiscal_year = YEAR(CURRENT_DATE())                        │
  │ GROUP BY tpa;                                                   │
  │                                                                 │
  │ -- Store metrics for trending                                   │
  │ INSERT INTO business_metrics_history (...)                      │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘
```

---

## Task Orchestration Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    TASK ORCHESTRATION TIMELINE                          │
└─────────────────────────────────────────────────────────────────────────┘

Bronze Layer Tasks (Continuous)
═══════════════════════════════════════════════════════════════════════════

Every 5 minutes:
├─ task_auto_process_files
│  ├─ Find unprocessed files
│  ├─ Process up to 10 files
│  └─ Update statuses

Daily at midnight:
└─ task_cleanup_old_files
   ├─ Archive files older than 90 days
   └─ Delete temporary data


Silver Layer Tasks (Regular)
═══════════════════════════════════════════════════════════════════════════

Every 10 minutes:
├─ task_auto_transform_bronze
│  ├─ Check for new Bronze data
│  ├─ Apply transformations
│  ├─ Load to Silver tables
│  └─ Update watermarks

Every hour:
└─ task_quality_checks
   ├─ Execute quality rules
   ├─ Update quality metrics
   └─ Flag issues


Gold Layer Tasks (Daily)
═══════════════════════════════════════════════════════════════════════════

Daily at 1:00 AM:
└─ task_master_gold_refresh
   ├─ Orchestrates all Gold transformations
   └─ Triggers dependent tasks

Daily at 2:00 AM (after master):
├─ task_refresh_claims_analytics
│  ├─ Aggregate claims data
│  ├─ Calculate metrics
│  └─ Update CLAIMS_ANALYTICS_ALL

Daily at 3:00 AM (after claims):
├─ task_refresh_member_360
│  ├─ Consolidate member data
│  ├─ Calculate lifetime metrics
│  └─ Update MEMBER_360_ALL

Daily at 4:00 AM (after all refreshes):
└─ task_quality_checks
   ├─ Execute quality rules
   ├─ Validate business metrics
   └─ Generate quality reports


Task Dependency Graph
═══════════════════════════════════════════════════════════════════════════

                    task_master_gold_refresh (1 AM)
                              │
                              ▼
         ┌────────────────────┴────────────────────┐
         │                                         │
         ▼                                         ▼
task_refresh_claims_analytics (2 AM)    task_refresh_member_360 (3 AM)
         │                                         │
         └────────────────────┬────────────────────┘
                              │
                              ▼
                    task_quality_checks (4 AM)
```

---

## Error Handling Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      ERROR HANDLING STRATEGY                            │
└─────────────────────────────────────────────────────────────────────────┘

Error Types and Handling
═══════════════════════════════════════════════════════════════════════════

1. File Upload Errors
──────────────────────
   Error: Invalid file format
   ├─ Action: Reject upload
   ├─ Status: FAILED
   ├─ Location: Not stored
   └─ Notification: User notified immediately

   Error: TPA not configured
   ├─ Action: Reject upload
   ├─ Status: FAILED
   └─ Notification: Admin notified

2. Bronze Processing Errors
────────────────────────────
   Error: File parsing failed
   ├─ Action: Move to @BRONZE_STAGE/errors/
   ├─ Status: FAILED
   ├─ Log: file_processing_log
   ├─ Retry: Manual only
   └─ Notification: Admin email

   Error: Data type mismatch
   ├─ Action: Quarantine problematic rows
   ├─ Status: PARTIAL_SUCCESS
   ├─ Log: Details in processing_log
   └─ Notification: Warning to user

3. Silver Transformation Errors
────────────────────────────────
   Error: Mapping not found
   ├─ Action: Trigger AI mapping suggestion
   ├─ Status: PENDING_MAPPING
   ├─ Log: silver_processing_log
   └─ Notification: User to approve mappings

   Error: Quality rule violation
   ├─ Action: Insert into quarantine_records
   ├─ Status: QUARANTINED
   ├─ Log: data_quality_metrics
   └─ Notification: Quality team notified

   Error: Transformation logic failure
   ├─ Action: Rollback transaction
   ├─ Status: FAILED
   ├─ Log: Error details logged
   ├─ Retry: Automatic (3 attempts)
   └─ Notification: After 3 failures

4. Gold Aggregation Errors
───────────────────────────
   Error: Source data missing
   ├─ Action: Skip aggregation
   ├─ Status: SKIPPED
   ├─ Log: processing_log
   └─ Notification: Warning logged

   Error: Quality check failed
   ├─ Action: Flag data, continue
   ├─ Status: COMPLETED_WITH_WARNINGS
   ├─ Log: quality_check_results
   └─ Notification: Quality dashboard updated


Error Recovery Flow
═══════════════════════════════════════════════════════════════════════════

                    Error Detected
                          │
                          ▼
              ┌───────────────────────┐
              │  Log Error Details    │
              │  • Error type         │
              │  • Error message      │
              │  • Stack trace        │
              │  • Context data       │
              └───────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │  Determine Severity   │
              └───────────────────────┘
                          │
         ┌────────────────┼────────────────┐
         │                │                │
         ▼                ▼                ▼
    CRITICAL          WARNING           INFO
         │                │                │
         ▼                ▼                ▼
  Halt Process    Continue with     Log only
  Rollback        Warnings
  Notify Admin    Flag data
         │                │                │
         └────────────────┼────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │  Retry Strategy       │
              │  • Transient: Retry   │
              │  • Permanent: Manual  │
              └───────────────────────┘
```

---

## Data Quality Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      DATA QUALITY FRAMEWORK                             │
└─────────────────────────────────────────────────────────────────────────┘

Quality Dimensions
═══════════════════════════════════════════════════════════════════════════

1. COMPLETENESS
   ├─ Required fields populated
   ├─ No unexpected nulls
   └─ Threshold: 95%+

2. ACCURACY
   ├─ Values within expected ranges
   ├─ Data types correct
   └─ Threshold: 98%+

3. CONSISTENCY
   ├─ Cross-field validation
   ├─ Referential integrity
   └─ Threshold: 99%+

4. VALIDITY
   ├─ Format validation
   ├─ Business rule compliance
   └─ Threshold: 97%+

5. TIMELINESS
   ├─ Data freshness
   ├─ Processing latency
   └─ Threshold: < 24 hours


Quality Check Execution Flow
═══════════════════════════════════════════════════════════════════════════

                Start Quality Check
                          │
                          ▼
        ┌─────────────────────────────────────┐
        │  Load Active Quality Rules          │
        │  FROM quality_rules                 │
        │  WHERE is_active = TRUE             │
        │  ORDER BY priority                  │
        └─────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────┐
        │  For Each Rule:                     │
        │                                     │
        │  1. Execute check logic             │
        │  2. Calculate pass rate             │
        │  3. Compare to threshold            │
        │  4. Determine status                │
        │  5. Log results                     │
        └─────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────┐
        │  Aggregate Results                  │
        │  • Overall quality score            │
        │  • Dimension scores                 │
        │  • Failed rule count                │
        │  • Trend analysis                   │
        └─────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────┐
        │  Take Action Based on Severity      │
        │                                     │
        │  CRITICAL: Block downstream         │
        │  ERROR: Flag for review             │
        │  WARNING: Log and continue          │
        │  INFO: Log only                     │
        └─────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────┐
        │  Update Quality Dashboard           │
        │  • quality_check_results            │
        │  • data_quality_metrics             │
        │  • Quality trend charts             │
        └─────────────────────────────────────┘
                          │
                          ▼
                End Quality Check
```

---

## Summary

This document provides comprehensive data flow diagrams for:

1. **End-to-End Flow**: Complete journey from file upload to analytics
2. **Bronze Layer**: Raw data ingestion and validation
3. **Silver Layer**: Data transformation and quality checks
4. **Gold Layer**: Analytics aggregation and business metrics
5. **Task Orchestration**: Automated processing schedules
6. **Error Handling**: Comprehensive error management
7. **Data Quality**: Quality framework and validation

### Key Takeaways

- **Unidirectional Flow**: Data always moves Bronze → Silver → Gold
- **Immutable Bronze**: Raw data preserved for audit and reprocessing
- **Quality-First**: Multiple quality checkpoints at each layer
- **Automated**: Task-driven processing with minimal manual intervention
- **Recoverable**: Failed records quarantined, not lost
- **Auditable**: Complete lineage and logging at every step

---

**Document Version**: 1.0  
**Last Updated**: January 19, 2026  
**Maintained By**: Platform Team
