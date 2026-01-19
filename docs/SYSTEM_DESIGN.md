# System Design Documentation

**Bordereau Processing Pipeline**  
**Version**: 2.0  
**Date**: January 19, 2026

---

## Table of Contents

1. [Design Principles](#design-principles)
2. [Design Patterns](#design-patterns)
3. [Database Design](#database-design)
4. [API Design](#api-design)
5. [Frontend Design](#frontend-design)
6. [Performance Design](#performance-design)
7. [Security Design](#security-design)
8. [Scalability Design](#scalability-design)
9. [Design Decisions](#design-decisions)

---

## Design Principles

### Core Principles

```
┌─────────────────────────────────────────────────────────────────┐
│                    DESIGN PRINCIPLES                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. SEPARATION OF CONCERNS                                      │
│     ┌────────────┬────────────┬────────────┬────────────┐     │
│     │ Presentation│ Application│  Business  │    Data    │     │
│     │    Layer    │    Layer   │   Logic    │   Layer    │     │
│     └────────────┴────────────┴────────────┴────────────┘     │
│                                                                 │
│  2. SINGLE RESPONSIBILITY                                       │
│     • Each component has one clear purpose                      │
│     • Bronze: Ingestion only                                    │
│     • Silver: Transformation only                               │
│     • Gold: Aggregation only                                    │
│                                                                 │
│  3. DRY (Don't Repeat Yourself)                                 │
│     • Reusable procedures and functions                         │
│     • Shared configuration                                      │
│     • Common utilities                                          │
│                                                                 │
│  4. FAIL FAST                                                   │
│     • Validate early in the pipeline                            │
│     • Reject bad data at Bronze                                 │
│     • Clear error messages                                      │
│                                                                 │
│  5. IMMUTABILITY                                                │
│     • Bronze data never modified                                │
│     • Audit trail preserved                                     │
│     • Reprocessing always possible                              │
│                                                                 │
│  6. IDEMPOTENCY                                                 │
│     • Same input → Same output                                  │
│     • Safe to retry operations                                  │
│     • MERGE statements for upserts                              │
│                                                                 │
│  7. OBSERVABILITY                                               │
│     • Comprehensive logging                                     │
│     • Performance metrics                                       │
│     • Quality dashboards                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Design Patterns

### 1. Medallion Architecture Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                  MEDALLION ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Bronze Layer (Raw)                                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Purpose: Immutable raw data storage                     │  │
│  │  Pattern: Append-only, no transformations                │  │
│  │  Schema: Flexible, preserves source format               │  │
│  │  Quality: Minimal validation                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│  Silver Layer (Refined)                                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Purpose: Cleaned, standardized data                     │  │
│  │  Pattern: Transform, validate, enrich                    │  │
│  │  Schema: Strict, business-aligned                        │  │
│  │  Quality: Comprehensive validation                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│  Gold Layer (Curated)                                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Purpose: Analytics-ready aggregations                   │  │
│  │  Pattern: Aggregate, calculate, optimize                 │  │
│  │  Schema: Denormalized, query-optimized                   │  │
│  │  Quality: Business metric validation                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Benefits:                                                      │
│  • Clear separation of concerns                                 │
│  • Incremental quality improvement                              │
│  • Reprocessing capability                                      │
│  • Audit trail preservation                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Multi-Tenancy Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                    MULTI-TENANCY DESIGN                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Pattern: Shared Database, Isolated Data                        │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Shared Infrastructure                                   │  │
│  │  • Single database                                       │  │
│  │  • Shared compute resources                             │  │
│  │  • Common procedures and tasks                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Data Isolation (TPA Column)                            │  │
│  │                                                          │  │
│  │  All tables include 'tpa' column:                       │  │
│  │  • Part of primary key or unique constraint             │  │
│  │  • Indexed for performance                              │  │
│  │  • Used in all queries (WHERE tpa = ?)                  │  │
│  │                                                          │  │
│  │  Example:                                                │  │
│  │  CREATE TABLE raw_claims_data (                         │  │
│  │      file_id VARCHAR,                                   │  │
│  │      tpa VARCHAR NOT NULL,  ← Tenant identifier         │  │
│  │      ...,                                               │  │
│  │      PRIMARY KEY (file_id, tpa)                         │  │
│  │  );                                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Access Control                                          │  │
│  │  • Role-based access (TPA_USER_A, TPA_USER_B)           │  │
│  │  • Row-level security policies                          │  │
│  │  • Secure views with TPA filtering                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Dynamic Table Creation (Silver Layer)                  │  │
│  │  • CLAIMS_<TPA> (separate table per tenant)             │  │
│  │  • Complete isolation                                   │  │
│  │  • Independent schema evolution                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Benefits:                                                      │
│  • Cost efficiency (shared infrastructure)                      │
│  • Complete data isolation                                      │
│  • Independent processing pipelines                             │
│  • Compliance with data residency                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3. Event-Driven Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                   EVENT-DRIVEN ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Pattern: Task-Based Orchestration                              │
│                                                                 │
│  Event: File Uploaded                                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  1. File lands in @BRONZE_STAGE                         │  │
│  │  2. Record inserted into raw_claims_data                │  │
│  │  3. Status = 'UPLOADED'                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│  Task: task_auto_process_files (Every 5 min)                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  1. Detect: SELECT WHERE status = 'UPLOADED'            │  │
│  │  2. Process: CALL process_file()                        │  │
│  │  3. Update: Status = 'PROCESSED'                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│  Task: task_auto_transform_bronze (Every 10 min)               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  1. Detect: New Bronze data                             │  │
│  │  2. Transform: Apply mappings and rules                 │  │
│  │  3. Load: Insert into Silver tables                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│  Task: task_master_gold_refresh (Daily 1 AM)                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  1. Orchestrate: Trigger dependent tasks                │  │
│  │  2. Aggregate: Create analytics tables                  │  │
│  │  3. Validate: Run quality checks                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Task Dependencies:                                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  AFTER task_master_gold_refresh                         │  │
│  │    ├─ task_refresh_claims_analytics                     │  │
│  │    └─ task_refresh_member_360                           │  │
│  │         └─ task_quality_checks                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Benefits:                                                      │
│  • Decoupled components                                         │
│  • Automatic processing                                         │
│  • Scalable orchestration                                       │
│  • Error isolation                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4. Repository Pattern (Backend)

```
┌─────────────────────────────────────────────────────────────────┐
│                     REPOSITORY PATTERN                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Snowflake Service (Data Access Layer)                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  class SnowflakeService:                                 │  │
│  │                                                          │  │
│  │      def get_connection(self):                          │  │
│  │          """Get pooled connection"""                    │  │
│  │                                                          │  │
│  │      def execute_query(self, sql, params):              │  │
│  │          """Execute parameterized query"""              │  │
│  │                                                          │  │
│  │      def fetch_all(self, sql, params):                  │  │
│  │          """Fetch all results"""                        │  │
│  │                                                          │  │
│  │      def fetch_one(self, sql, params):                  │  │
│  │          """Fetch single result"""                      │  │
│  │                                                          │  │
│  │      def call_procedure(self, proc_name, params):       │  │
│  │          """Call stored procedure"""                    │  │
│  │                                                          │  │
│  │      def upload_file(self, file, stage, path):          │  │
│  │          """Upload file to stage"""                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│  API Routers (Business Logic)                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  @router.post("/bronze/upload")                         │  │
│  │  async def upload_file(file, tpa):                      │  │
│  │      # Business logic                                   │  │
│  │      file_id = generate_id()                            │  │
│  │      path = f"{tpa}/{file_id}"                          │  │
│  │                                                          │  │
│  │      # Data access via service                          │  │
│  │      service.upload_file(file, "@BRONZE_STAGE", path)   │  │
│  │      service.call_procedure("register_file", params)    │  │
│  │                                                          │  │
│  │      return {"file_id": file_id, "status": "uploaded"}  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Benefits:                                                      │
│  • Separation of concerns                                       │
│  • Testable business logic                                      │
│  • Reusable data access                                         │
│  • Easy to mock for testing                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5. Strategy Pattern (AI Mapping)

```
┌─────────────────────────────────────────────────────────────────┐
│                      STRATEGY PATTERN                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Mapping Strategy Interface                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  PROCEDURE suggest_mappings(                            │  │
│  │      source_fields ARRAY,                               │  │
│  │      target_fields ARRAY,                               │  │
│  │      method VARCHAR  ← Strategy selector                │  │
│  │  )                                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                      │
│         ┌────────────────┼────────────────┐                    │
│         │                │                │                    │
│         ▼                ▼                ▼                    │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                │
│  │  MANUAL  │    │ ML_AUTO  │    │   LLM    │                │
│  │ Strategy │    │ Strategy │    │ Strategy │                │
│  └──────────┘    └──────────┘    └──────────┘                │
│       │                │                │                      │
│       ▼                ▼                ▼                      │
│  Load from       Pattern         Cortex AI                     │
│  CSV config      matching        semantic                      │
│                  algorithm       matching                      │
│                                                                 │
│  Implementation:                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  CASE method                                            │  │
│  │      WHEN 'MANUAL' THEN                                 │  │
│  │          CALL load_manual_mappings()                    │  │
│  │      WHEN 'ML_AUTO' THEN                                │  │
│  │          CALL suggest_mappings_ml()                     │  │
│  │      WHEN 'LLM_CORTEX' THEN                             │  │
│  │          CALL suggest_mappings_llm()                    │  │
│  │      ELSE                                               │  │
│  │          RAISE ERROR 'Unknown method'                   │  │
│  │  END CASE                                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Benefits:                                                      │
│  • Pluggable algorithms                                         │
│  • Easy to add new strategies                                   │
│  • Runtime strategy selection                                   │
│  • Testable in isolation                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Database Design

### Table Design Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    TABLE DESIGN DECISIONS                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Decision Tree: Hybrid vs Standard Table                        │
│                                                                 │
│                    Start                                        │
│                      │                                          │
│                      ▼                                          │
│            ┌──────────────────┐                                │
│            │ Table Size?      │                                │
│            └──────────────────┘                                │
│                      │                                          │
│         ┌────────────┴────────────┐                            │
│         │                         │                            │
│         ▼                         ▼                            │
│    < 10M rows               > 10M rows                         │
│         │                         │                            │
│         ▼                         ▼                            │
│  ┌──────────────┐         ┌──────────────┐                    │
│  │ Query Type?  │         │ Query Type?  │                    │
│  └──────────────┘         └──────────────┘                    │
│         │                         │                            │
│    ┌────┴────┐              ┌────┴────┐                       │
│    │         │              │         │                       │
│    ▼         ▼              ▼         ▼                       │
│  Point    Scan          Point      Scan                       │
│  Query    Query         Query      Query                      │
│    │         │              │         │                       │
│    ▼         ▼              ▼         ▼                       │
│  HYBRID   STANDARD     STANDARD   STANDARD                    │
│  TABLE    TABLE        TABLE      TABLE                       │
│  + INDEX  (no index)   (no index) + CLUSTER                   │
│                                                                 │
│  Examples by Layer:                                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Bronze Layer (All Standard)                              │  │
│  │ • raw_claims_data (append-only, no index)               │  │
│  │ • file_processing_log (append-only, no index)           │  │
│  │ • tpa_config (small, but rarely queried)                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Silver Layer (Mixed)                                     │  │
│  │ Hybrid Tables (with indexes):                            │  │
│  │ • target_schemas (frequent lookups by tpa)              │  │
│  │ • field_mappings (frequent lookups by tpa/table)        │  │
│  │ • transformation_rules (frequent lookups by tpa/type)   │  │
│  │ • llm_prompt_templates (frequent lookups by active)     │  │
│  │                                                          │  │
│  │ Standard Tables:                                         │  │
│  │ • CLAIMS_<TPA> (large, analytical queries)              │  │
│  │ • silver_processing_log (append-only)                   │  │
│  │ • quarantine_records (append-only)                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Gold Layer (Mixed)                                       │  │
│  │ Hybrid Tables (with indexes):                            │  │
│  │ • target_schemas (frequent lookups)                     │  │
│  │ • target_fields (frequent lookups)                      │  │
│  │ • transformation_rules (frequent lookups)               │  │
│  │ • field_mappings (frequent lookups)                     │  │
│  │ • quality_rules (frequent lookups)                      │  │
│  │ • business_metrics (frequent lookups)                   │  │
│  │                                                          │  │
│  │ Standard Tables (with clustering):                       │  │
│  │ • CLAIMS_ANALYTICS_ALL (large, time-series)             │  │
│  │ • MEMBER_360_ALL (large, member-centric)                │  │
│  │ • PROVIDER_PERFORMANCE_ALL (large, provider-centric)    │  │
│  │ • FINANCIAL_SUMMARY_ALL (large, time-series)            │  │
│  │                                                          │  │
│  │ Standard Tables (no clustering):                         │  │
│  │ • processing_log (append-only)                          │  │
│  │ • quality_check_results (append-only)                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Normalization Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                  NORMALIZATION BY LAYER                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Bronze Layer: No Normalization                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Store data as-is from source                          │  │
│  │  • Preserve original structure                           │  │
│  │  • No foreign keys                                       │  │
│  │  • Flexible schema                                       │  │
│  │                                                          │  │
│  │  Example: raw_claims_data                                │  │
│  │  All fields in one table, no relationships              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Silver Layer: 3NF (Third Normal Form)                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Normalized to 3NF                                     │  │
│  │  • Foreign keys enforced                                 │  │
│  │  • Referential integrity                                 │  │
│  │  • Separate tables for entities                         │  │
│  │                                                          │  │
│  │  Example:                                                │  │
│  │  CLAIMS_<TPA>                                            │  │
│  │    ├─ claim_id (PK)                                      │  │
│  │    ├─ member_id (FK → MEMBERS)                          │  │
│  │    └─ provider_id (FK → PROVIDERS)                      │  │
│  │                                                          │  │
│  │  MEMBERS_<TPA>                                           │  │
│  │    ├─ member_id (PK)                                     │  │
│  │    └─ member details                                     │  │
│  │                                                          │  │
│  │  PROVIDERS_<TPA>                                         │  │
│  │    ├─ provider_id (PK)                                   │  │
│  │    └─ provider details                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Gold Layer: Denormalized (Star Schema)                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Denormalized for query performance                    │  │
│  │  • No foreign keys                                       │  │
│  │  • Redundant data for speed                              │  │
│  │  • Optimized for analytics                               │  │
│  │                                                          │  │
│  │  Example: CLAIMS_ANALYTICS_ALL                           │  │
│  │  All dimensions flattened into fact table:              │  │
│  │    ├─ claim_id                                           │  │
│  │    ├─ member_id, member_name, member_age                │  │
│  │    ├─ provider_id, provider_name, provider_type         │  │
│  │    ├─ claim_date, claim_amount, claim_type              │  │
│  │    └─ aggregated metrics                                 │  │
│  │                                                          │  │
│  │  No JOINs needed for queries!                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Indexing Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                     INDEXING STRATEGY                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Index Types by Use Case                                        │
│                                                                 │
│  1. Primary Key Indexes (Automatic)                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Unique identifier                                     │  │
│  │  • Automatically indexed                                 │  │
│  │  • Used for point queries                                │  │
│  │                                                          │  │
│  │  Example:                                                │  │
│  │  CREATE HYBRID TABLE target_schemas (                   │  │
│  │      schema_id NUMBER PRIMARY KEY  ← Auto-indexed       │  │
│  │  );                                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  2. Foreign Key Indexes                                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Speed up JOINs                                        │  │
│  │  • Enforce referential integrity                        │  │
│  │                                                          │  │
│  │  Example:                                                │  │
│  │  CREATE HYBRID TABLE target_fields (                    │  │
│  │      field_id NUMBER PRIMARY KEY,                       │  │
│  │      schema_id NUMBER,                                  │  │
│  │      FOREIGN KEY (schema_id)                            │  │
│  │          REFERENCES target_schemas(schema_id),          │  │
│  │      INDEX idx_fields_schema (schema_id)  ← FK index    │  │
│  │  );                                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  3. Filter Indexes (TPA, Status, Active)                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Speed up WHERE clauses                                │  │
│  │  • Most commonly filtered columns                        │  │
│  │                                                          │  │
│  │  Example:                                                │  │
│  │  CREATE HYBRID TABLE transformation_rules (             │  │
│  │      rule_id NUMBER PRIMARY KEY,                        │  │
│  │      tpa VARCHAR NOT NULL,                              │  │
│  │      rule_type VARCHAR NOT NULL,                        │  │
│  │      is_active BOOLEAN DEFAULT TRUE,                    │  │
│  │      INDEX idx_rules_tpa (tpa),          ← Filter       │  │
│  │      INDEX idx_rules_type (rule_type),   ← Filter       │  │
│  │      INDEX idx_rules_active (is_active)  ← Filter       │  │
│  │  );                                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  4. Clustering Keys (Analytics Tables)                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Optimize scans and aggregations                       │  │
│  │  • Partition pruning                                     │  │
│  │  • Order matters (most selective first)                 │  │
│  │                                                          │  │
│  │  Example:                                                │  │
│  │  CREATE TABLE CLAIMS_ANALYTICS_ALL (                    │  │
│  │      ...                                                │  │
│  │  ) CLUSTER BY (                                         │  │
│  │      tpa,          ← 1st: Partition by tenant           │  │
│  │      claim_year,   ← 2nd: Partition by year             │  │
│  │      claim_month,  ← 3rd: Partition by month            │  │
│  │      claim_type    ← 4th: Partition by type             │  │
│  │  );                                                     │  │
│  │                                                          │  │
│  │  Query benefits:                                         │  │
│  │  WHERE tpa = 'A'                 ← Prunes 90% of data   │  │
│  │    AND claim_year = 2024         ← Prunes 90% more      │  │
│  │    AND claim_month BETWEEN 1 AND 6  ← Prunes 50% more  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Index Selection Guidelines:                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  ✓ Index columns in WHERE clauses                       │  │
│  │  ✓ Index foreign keys                                   │  │
│  │  ✓ Index frequently joined columns                      │  │
│  │  ✓ Cluster on time-series + dimension columns           │  │
│  │  ✗ Don't index low-cardinality columns (< 100 values)   │  │
│  │  ✗ Don't index columns rarely queried                   │  │
│  │  ✗ Don't over-index (max 5-10 per table)               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## API Design

### RESTful API Design

```
┌─────────────────────────────────────────────────────────────────┐
│                      REST API DESIGN                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Resource Naming Convention                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Use nouns, not verbs                                  │  │
│  │  • Use plural for collections                            │  │
│  │  • Use kebab-case for multi-word resources              │  │
│  │  • Hierarchical structure for relationships             │  │
│  │                                                          │  │
│  │  Good:                                                   │  │
│  │  GET  /api/bronze/files                                 │  │
│  │  GET  /api/bronze/files/{file_id}                       │  │
│  │  POST /api/bronze/files                                 │  │
│  │  GET  /api/silver/mappings                              │  │
│  │                                                          │  │
│  │  Bad:                                                    │  │
│  │  GET  /api/bronze/getFiles                              │  │
│  │  POST /api/bronze/createFile                            │  │
│  │  GET  /api/silver/mapping                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  HTTP Method Usage                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  GET    - Retrieve resource(s)                          │  │
│  │  POST   - Create new resource                           │  │
│  │  PUT    - Update entire resource                        │  │
│  │  PATCH  - Update partial resource                       │  │
│  │  DELETE - Remove resource                               │  │
│  │                                                          │  │
│  │  Examples:                                               │  │
│  │  GET    /api/bronze/files           → List files        │  │
│  │  GET    /api/bronze/files/123       → Get file 123      │  │
│  │  POST   /api/bronze/files           → Upload file       │  │
│  │  PUT    /api/tpa/provider-a         → Update TPA        │  │
│  │  DELETE /api/silver/mappings/456    → Delete mapping    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Response Format (JSON)                                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Success Response:                                       │  │
│  │  {                                                       │  │
│  │      "status": "success",                               │  │
│  │      "data": {                                          │  │
│  │          "file_id": "abc123",                           │  │
│  │          "tpa": "provider_a",                           │  │
│  │          "status": "processed"                          │  │
│  │      },                                                 │  │
│  │      "metadata": {                                      │  │
│  │          "timestamp": "2026-01-19T10:00:00Z",           │  │
│  │          "version": "2.0"                               │  │
│  │      }                                                  │  │
│  │  }                                                      │  │
│  │                                                          │  │
│  │  Error Response:                                         │  │
│  │  {                                                       │  │
│  │      "status": "error",                                 │  │
│  │      "error": {                                         │  │
│  │          "code": "INVALID_TPA",                         │  │
│  │          "message": "TPA 'xyz' not found",              │  │
│  │          "details": {                                   │  │
│  │              "tpa": "xyz",                              │  │
│  │              "valid_tpas": ["provider_a", "provider_b"] │  │
│  │          }                                              │  │
│  │      }                                                  │  │
│  │  }                                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  HTTP Status Codes                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  200 OK              - Successful GET/PUT/PATCH         │  │
│  │  201 Created         - Successful POST                  │  │
│  │  204 No Content      - Successful DELETE                │  │
│  │  400 Bad Request     - Invalid input                    │  │
│  │  401 Unauthorized    - Authentication required          │  │
│  │  403 Forbidden       - Insufficient permissions         │  │
│  │  404 Not Found       - Resource doesn't exist           │  │
│  │  409 Conflict        - Resource already exists          │  │
│  │  422 Unprocessable   - Validation failed                │  │
│  │  500 Server Error    - Internal error                   │  │
│  │  503 Unavailable     - Service temporarily down         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Pagination                                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Request:                                                │  │
│  │  GET /api/bronze/files?page=2&limit=50                  │  │
│  │                                                          │  │
│  │  Response:                                               │  │
│  │  {                                                       │  │
│  │      "data": [...],                                     │  │
│  │      "pagination": {                                    │  │
│  │          "page": 2,                                     │  │
│  │          "limit": 50,                                   │  │
│  │          "total": 250,                                  │  │
│  │          "pages": 5,                                    │  │
│  │          "has_next": true,                              │  │
│  │          "has_prev": true                               │  │
│  │      }                                                  │  │
│  │  }                                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Filtering & Sorting                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  GET /api/bronze/files?                                 │  │
│  │      tpa=provider_a&                                    │  │
│  │      status=processed&                                  │  │
│  │      sort=upload_timestamp&                             │  │
│  │      order=desc                                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Frontend Design

### Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  COMPONENT ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Component Hierarchy                                            │
│                                                                 │
│  App.tsx (Root)                                                 │
│  ├─ Layout                                                      │
│  │  ├─ Header                                                   │
│  │  ├─ Navigation (Tabs)                                        │
│  │  └─ Content                                                  │
│  │                                                              │
│  ├─ Bronze Module                                               │
│  │  ├─ BronzeUpload (Smart Component)                          │
│  │  │  ├─ FileUploader (Presentational)                        │
│  │  │  ├─ TPASelector (Presentational)                         │
│  │  │  └─ UploadProgress (Presentational)                      │
│  │  │                                                           │
│  │  ├─ BronzeStatus (Smart Component)                          │
│  │  │  ├─ StatusTable (Presentational)                         │
│  │  │  ├─ StatusFilter (Presentational)                        │
│  │  │  └─ StatusBadge (Presentational)                         │
│  │  │                                                           │
│  │  └─ BronzeData (Smart Component)                            │
│  │     └─ DataTable (Presentational)                           │
│  │                                                              │
│  ├─ Silver Module                                               │
│  │  ├─ SilverSchemas (Smart Component)                         │
│  │  │  ├─ SchemaForm (Presentational)                          │
│  │  │  └─ SchemaTable (Presentational)                         │
│  │  │                                                           │
│  │  ├─ SilverMappings (Smart Component)                        │
│  │  │  ├─ MappingForm (Presentational)                         │
│  │  │  ├─ MappingTable (Presentational)                        │
│  │  │  └─ AISuggestions (Presentational)                       │
│  │  │                                                           │
│  │  └─ SilverTransform (Smart Component)                       │
│  │     ├─ RuleForm (Presentational)                            │
│  │     └─ RuleTable (Presentational)                           │
│  │                                                              │
│  └─ Shared Components                                           │
│     ├─ DataTable (Reusable)                                    │
│     ├─ FormModal (Reusable)                                    │
│     ├─ LoadingSpinner (Reusable)                               │
│     └─ ErrorBoundary (Reusable)                                │
│                                                                 │
│  Component Types:                                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Smart Components (Container)                            │  │
│  │  • Manage state                                          │  │
│  │  • API calls                                             │  │
│  │  • Business logic                                        │  │
│  │  • Pass data to presentational components               │  │
│  │                                                          │  │
│  │  Presentational Components (UI)                          │  │
│  │  • Receive data via props                                │  │
│  │  • No API calls                                          │  │
│  │  • Emit events to parent                                 │  │
│  │  • Reusable and testable                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### State Management

```
┌─────────────────────────────────────────────────────────────────┐
│                    STATE MANAGEMENT                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  React Hooks Pattern (No Redux)                                 │
│                                                                 │
│  Component State (useState)                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  const [files, setFiles] = useState([]);                 │  │
│  │  const [loading, setLoading] = useState(false);          │  │
│  │  const [error, setError] = useState(null);               │  │
│  │                                                          │  │
│  │  Use for:                                                │  │
│  │  • Component-specific state                             │  │
│  │  • UI state (modals, dropdowns)                         │  │
│  │  • Form inputs                                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Side Effects (useEffect)                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  useEffect(() => {                                       │  │
│  │      const fetchFiles = async () => {                   │  │
│  │          setLoading(true);                              │  │
│  │          try {                                          │  │
│  │              const data = await api.getFiles();         │  │
│  │              setFiles(data);                            │  │
│  │          } catch (err) {                                │  │
│  │              setError(err.message);                     │  │
│  │          } finally {                                    │  │
│  │              setLoading(false);                         │  │
│  │          }                                              │  │
│  │      };                                                 │  │
│  │      fetchFiles();                                      │  │
│  │  }, []);  // Run once on mount                          │  │
│  │                                                          │  │
│  │  Use for:                                                │  │
│  │  • API calls                                            │  │
│  │  • Subscriptions                                        │  │
│  │  • Timers                                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Memoization (useMemo, useCallback)                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  const filteredFiles = useMemo(() => {                  │  │
│  │      return files.filter(f => f.status === 'processed');│  │
│  │  }, [files]);  // Recompute only when files change      │  │
│  │                                                          │  │
│  │  const handleUpload = useCallback((file) => {           │  │
│  │      // Upload logic                                    │  │
│  │  }, []);  // Stable reference                           │  │
│  │                                                          │  │
│  │  Use for:                                                │  │
│  │  • Expensive computations                               │  │
│  │  • Preventing unnecessary re-renders                    │  │
│  │  • Stable callback references                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Performance Design

### Query Optimization

```
┌─────────────────────────────────────────────────────────────────┐
│                   QUERY OPTIMIZATION                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Use Indexes Effectively                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Bad:                                                    │  │
│  │  SELECT * FROM transformation_rules                      │  │
│  │  WHERE tpa = 'provider_a';                              │  │
│  │  -- Full table scan                                     │  │
│  │                                                          │  │
│  │  Good:                                                   │  │
│  │  -- With INDEX idx_rules_tpa (tpa)                      │  │
│  │  SELECT * FROM transformation_rules                      │  │
│  │  WHERE tpa = 'provider_a';                              │  │
│  │  -- Index seek: 10-100x faster                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  2. Leverage Clustering                                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Bad:                                                    │  │
│  │  SELECT SUM(total_paid_amount)                          │  │
│  │  FROM CLAIMS_ANALYTICS_ALL                              │  │
│  │  WHERE claim_year = 2024;                               │  │
│  │  -- Scans all data                                      │  │
│  │                                                          │  │
│  │  Good:                                                   │  │
│  │  -- With CLUSTER BY (tpa, claim_year, ...)             │  │
│  │  SELECT SUM(total_paid_amount)                          │  │
│  │  FROM CLAIMS_ANALYTICS_ALL                              │  │
│  │  WHERE tpa = 'provider_a'                               │  │
│  │    AND claim_year = 2024;                               │  │
│  │  -- Partition pruning: 90% less data scanned           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  3. Avoid SELECT *                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Bad:                                                    │  │
│  │  SELECT * FROM CLAIMS_ANALYTICS_ALL;                    │  │
│  │  -- Returns all 50 columns                              │  │
│  │                                                          │  │
│  │  Good:                                                   │  │
│  │  SELECT claim_id, total_paid_amount, claim_date         │  │
│  │  FROM CLAIMS_ANALYTICS_ALL;                             │  │
│  │  -- Returns only needed columns                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  4. Use LIMIT for Large Results                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  SELECT * FROM raw_claims_data                          │  │
│  │  ORDER BY upload_timestamp DESC                         │  │
│  │  LIMIT 100;                                             │  │
│  │  -- Stop after 100 rows                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  5. Optimize JOINs                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Bad:                                                    │  │
│  │  SELECT *                                               │  │
│  │  FROM large_table l                                     │  │
│  │  JOIN small_table s ON l.id = s.id;                    │  │
│  │  -- Large table first                                   │  │
│  │                                                          │  │
│  │  Good:                                                   │  │
│  │  SELECT *                                               │  │
│  │  FROM small_table s                                     │  │
│  │  JOIN large_table l ON s.id = l.id;                    │  │
│  │  -- Small table first (build hash table)               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Caching Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    CACHING STRATEGY                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Backend Caching (Python)                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  from functools import lru_cache                         │  │
│  │                                                          │  │
│  │  @lru_cache(maxsize=128)                                │  │
│  │  def get_tpa_config(tpa: str):                          │  │
│  │      # Expensive database query                         │  │
│  │      return snowflake.fetch_one(                        │  │
│  │          "SELECT * FROM tpa_config WHERE tpa = ?",      │  │
│  │          [tpa]                                          │  │
│  │      )                                                  │  │
│  │                                                          │  │
│  │  # First call: Query database                           │  │
│  │  # Subsequent calls: Return cached result               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Frontend Caching (React)                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  const [tpaList, setTpaList] = useState([]);            │  │
│  │  const [cacheTime, setCacheTime] = useState(null);      │  │
│  │                                                          │  │
│  │  useEffect(() => {                                      │  │
│  │      const now = Date.now();                            │  │
│  │      const cacheValid = cacheTime &&                    │  │
│  │          (now - cacheTime) < 5 * 60 * 1000; // 5 min   │  │
│  │                                                          │  │
│  │      if (!cacheValid) {                                 │  │
│  │          fetchTPAs().then(data => {                     │  │
│  │              setTpaList(data);                          │  │
│  │              setCacheTime(now);                         │  │
│  │          });                                            │  │
│  │      }                                                  │  │
│  │  }, [cacheTime]);                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Database Result Caching (Snowflake)                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  -- Snowflake automatically caches query results        │  │
│  │  -- for 24 hours if:                                    │  │
│  │  -- 1. Same query text                                  │  │
│  │  -- 2. Same user                                        │  │
│  │  -- 3. Data hasn't changed                              │  │
│  │                                                          │  │
│  │  SELECT COUNT(*) FROM raw_claims_data;                  │  │
│  │  -- First execution: 5 seconds                          │  │
│  │  -- Second execution: < 1 second (cached)               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Security Design

### Authentication Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                  AUTHENTICATION DESIGN                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Multi-Method Authentication                                    │
│                                                                 │
│  Method 1: Snow CLI (Recommended)                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Use existing Snow CLI connection                      │  │
│  │  • No credentials in code                                │  │
│  │  • MFA supported                                         │  │
│  │  • Connection name: "DEPLOYMENT"                         │  │
│  │                                                          │  │
│  │  snowflake.connector.connect(                           │  │
│  │      connection_name="DEPLOYMENT"                       │  │
│  │  )                                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Method 2: Keypair Authentication                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • RSA private key                                       │  │
│  │  • More secure than password                             │  │
│  │  • Key rotation supported                                │  │
│  │                                                          │  │
│  │  with open('private_key.pem', 'rb') as key_file:        │  │
│  │      private_key = serialization.load_pem_private_key(  │  │
│  │          key_file.read(),                               │  │
│  │          password=None                                  │  │
│  │      )                                                  │  │
│  │                                                          │  │
│  │  snowflake.connector.connect(                           │  │
│  │      account=ACCOUNT,                                   │  │
│  │      user=USER,                                         │  │
│  │      private_key=private_key                            │  │
│  │  )                                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Method 3: Password Authentication                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Username + password                                   │  │
│  │  • Store in environment variables                        │  │
│  │  • Never commit to git                                   │  │
│  │                                                          │  │
│  │  snowflake.connector.connect(                           │  │
│  │      account=os.getenv('SNOWFLAKE_ACCOUNT'),            │  │
│  │      user=os.getenv('SNOWFLAKE_USER'),                  │  │
│  │      password=os.getenv('SNOWFLAKE_PASSWORD')           │  │
│  │  )                                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Authorization Design

```
┌─────────────────────────────────────────────────────────────────┐
│                   AUTHORIZATION DESIGN                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Role Hierarchy                                                 │
│                                                                 │
│  SYSADMIN (System Administrator)                                │
│  ├─ Full access to all layers                                   │
│  ├─ Can create/modify schemas                                   │
│  ├─ Can grant/revoke permissions                                │
│  └─ Production deployment role                                  │
│                                                                 │
│  BRONZE_ADMIN                                                   │
│  ├─ Full access to Bronze schema                                │
│  ├─ Can upload files                                            │
│  ├─ Can process files                                           │
│  └─ Can view processing logs                                    │
│                                                                 │
│  SILVER_ADMIN                                                   │
│  ├─ Full access to Silver schema                                │
│  ├─ Can create/modify schemas                                   │
│  ├─ Can create/modify mappings                                  │
│  ├─ Can execute transformations                                 │
│  └─ Read access to Bronze                                       │
│                                                                 │
│  GOLD_ADMIN                                                     │
│  ├─ Full access to Gold schema                                  │
│  ├─ Can execute aggregations                                    │
│  ├─ Can modify business metrics                                 │
│  └─ Read access to Silver                                       │
│                                                                 │
│  TPA_USER_<TPA>                                                 │
│  ├─ Read access to own TPA data only                            │
│  ├─ Can upload files for own TPA                                │
│  ├─ Can view processing status                                  │
│  └─ Cannot see other TPA data                                   │
│                                                                 │
│  Permission Matrix:                                             │
│  ┌────────────┬─────────┬─────────┬─────────┬──────────┐      │
│  │   Role     │ Bronze  │ Silver  │  Gold   │ All TPAs │      │
│  ├────────────┼─────────┼─────────┼─────────┼──────────┤      │
│  │ SYSADMIN   │   RW    │   RW    │   RW    │   Yes    │      │
│  │ BRONZE_ADM │   RW    │   R     │   -     │   Yes    │      │
│  │ SILVER_ADM │   R     │   RW    │   R     │   Yes    │      │
│  │ GOLD_ADMIN │   -     │   R     │   RW    │   Yes    │      │
│  │ TPA_USER   │   R     │   R     │   R     │   No     │      │
│  └────────────┴─────────┴─────────┴─────────┴──────────┘      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Scalability Design

### Horizontal Scaling

```
┌─────────────────────────────────────────────────────────────────┐
│                  HORIZONTAL SCALING                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Database Layer (Snowflake)                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Auto-scaling compute clusters                         │  │
│  │  • Multi-cluster warehouses                              │  │
│  │  • Concurrent query execution                            │  │
│  │  • Unlimited storage                                     │  │
│  │                                                          │  │
│  │  CREATE WAREHOUSE PROCESSING_WH                         │  │
│  │  WITH                                                   │  │
│  │      WAREHOUSE_SIZE = 'MEDIUM'                          │  │
│  │      MIN_CLUSTER_COUNT = 1                              │  │
│  │      MAX_CLUSTER_COUNT = 10                             │  │
│  │      AUTO_SUSPEND = 300                                 │  │
│  │      AUTO_RESUME = TRUE                                 │  │
│  │      SCALING_POLICY = 'STANDARD';                       │  │
│  │                                                          │  │
│  │  Scales from 1 to 10 clusters based on demand          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Application Layer (SPCS)                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Container replication                                 │  │
│  │  • Load balancing                                        │  │
│  │  • Auto-scaling based on CPU/memory                      │  │
│  │                                                          │  │
│  │  spec:                                                  │  │
│  │    containers:                                          │  │
│  │    - name: backend                                      │  │
│  │      replicas: 3  ← Multiple instances                  │  │
│  │      resources:                                         │  │
│  │        requests:                                        │  │
│  │          cpu: 0.6                                       │  │
│  │          memory: 2Gi                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Multi-Tenancy Scaling                                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Independent processing per TPA                        │  │
│  │  • Parallel task execution                               │  │
│  │  • No cross-TPA dependencies                             │  │
│  │                                                          │  │
│  │  Supports 1000+ TPAs with linear scaling                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Design Decisions

### Key Decisions and Rationale

```
┌─────────────────────────────────────────────────────────────────┐
│                    DESIGN DECISIONS                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Why Medallion Architecture?                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Decision: Bronze → Silver → Gold layers                 │  │
│  │                                                          │  │
│  │  Rationale:                                              │  │
│  │  • Clear separation of concerns                          │  │
│  │  • Incremental quality improvement                       │  │
│  │  • Audit trail preservation                              │  │
│  │  • Reprocessing capability                               │  │
│  │  • Industry best practice                                │  │
│  │                                                          │  │
│  │  Alternatives Considered:                                │  │
│  │  ✗ Single layer: No reprocessing, no audit trail        │  │
│  │  ✗ Two layers: Less flexibility                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  2. Why Hybrid Tables for Metadata?                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Decision: Use hybrid tables with indexes                │  │
│  │                                                          │  │
│  │  Rationale:                                              │  │
│  │  • 10-100x faster point queries                          │  │
│  │  • Support for UPDATE/DELETE                             │  │
│  │  • Frequent lookups during transformations              │  │
│  │  • Small table size (< 10M rows)                        │  │
│  │                                                          │  │
│  │  Alternatives Considered:                                │  │
│  │  ✗ Standard tables: Too slow for lookups                │  │
│  │  ✗ External cache: Added complexity                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  3. Why Task-Based Orchestration?                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Decision: Use Snowflake Tasks for automation            │  │
│  │                                                          │  │
│  │  Rationale:                                              │  │
│  │  • Native Snowflake feature                              │  │
│  │  • No external orchestrator needed                       │  │
│  │  • Automatic retry and error handling                    │  │
│  │  • Cost-effective (serverless)                           │  │
│  │                                                          │  │
│  │  Alternatives Considered:                                │  │
│  │  ✗ Airflow: Added infrastructure cost                   │  │
│  │  ✗ Lambda: Complex integration                          │  │
│  │  ✗ Manual: Not scalable                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  4. Why Multi-Tenant with TPA Column?                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Decision: Shared database, TPA-based isolation          │  │
│  │                                                          │  │
│  │  Rationale:                                              │  │
│  │  • Cost efficiency (shared infrastructure)               │  │
│  │  • Complete data isolation                               │  │
│  │  • Easy to add new TPAs                                  │  │
│  │  • Centralized management                                │  │
│  │                                                          │  │
│  │  Alternatives Considered:                                │  │
│  │  ✗ Separate databases: Too expensive                    │  │
│  │  ✗ No isolation: Security risk                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  5. Why FastAPI + React?                                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Decision: FastAPI backend, React frontend               │  │
│  │                                                          │  │
│  │  Rationale:                                              │  │
│  │  • FastAPI: Fast, modern, auto-docs                      │  │
│  │  • React: Component-based, large ecosystem               │  │
│  │  • TypeScript: Type safety                               │  │
│  │  • Ant Design: Professional UI components               │  │
│  │                                                          │  │
│  │  Alternatives Considered:                                │  │
│  │  ✗ Flask: Less modern, no async                         │  │
│  │  ✗ Angular: Steeper learning curve                      │  │
│  │  ✗ Vue: Smaller ecosystem                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Summary

This document provides comprehensive system design documentation covering:

1. **Design Principles** - Core principles guiding the architecture
2. **Design Patterns** - Medallion, multi-tenancy, event-driven, repository, strategy
3. **Database Design** - Table types, normalization, indexing strategies
4. **API Design** - RESTful conventions, response formats, error handling
5. **Frontend Design** - Component architecture, state management
6. **Performance Design** - Query optimization, caching strategies
7. **Security Design** - Authentication, authorization, role hierarchy
8. **Scalability Design** - Horizontal scaling, multi-tenancy
9. **Design Decisions** - Key decisions with rationale

### Key Takeaways

- **Medallion Architecture** provides clear separation and audit trail
- **Hybrid Tables** optimize metadata lookups (10-100x faster)
- **Task-Based Orchestration** provides serverless automation
- **Multi-Tenancy** balances cost and isolation
- **Modern Stack** (FastAPI + React) provides developer productivity

---

**Document Version**: 1.0  
**Last Updated**: January 19, 2026  
**Maintained By**: Platform Team
