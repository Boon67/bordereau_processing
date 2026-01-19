# System Architecture Documentation

**Bordereau Processing Pipeline**  
**Version**: 2.0  
**Date**: January 19, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [High-Level Architecture](#high-level-architecture)
3. [Component Architecture](#component-architecture)
4. [Data Layer Architecture](#data-layer-architecture)
5. [Deployment Architecture](#deployment-architecture)
6. [Security Architecture](#security-architecture)
7. [Integration Architecture](#integration-architecture)

---

## Overview

The Bordereau Processing Pipeline is a modern, cloud-native healthcare claims data processing system built on Snowflake. It implements a **medallion architecture** (Bronze → Silver → Gold) with multi-tenant isolation and AI-powered data transformation capabilities.

### Key Characteristics

- **Cloud-Native**: Built for Snowflake with SPCS deployment
- **Multi-Tenant**: TPA-based isolation at all layers
- **AI-Powered**: ML/LLM-driven field mapping and validation
- **Event-Driven**: Task-based automation and orchestration
- **Scalable**: Horizontal scaling via Snowflake compute
- **Secure**: Role-based access control and data encryption

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │           React Frontend (TypeScript + Ant Design)           │  │
│  │                                                              │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │  │
│  │  │  Bronze  │  │  Silver  │  │   Gold   │  │   Admin  │   │  │
│  │  │   Pages  │  │   Pages  │  │   Pages  │  │   Pages  │   │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │  │
│  │                                                              │  │
│  │                    Port 3000 / 80 (SPCS)                    │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ HTTPS / REST API
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        APPLICATION LAYER                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              FastAPI Backend (Python 3.10+)                  │  │
│  │                                                              │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │  │
│  │  │  Bronze  │  │  Silver  │  │   Gold   │  │   TPA    │   │  │
│  │  │   API    │  │   API    │  │   API    │  │   API    │   │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │  │
│  │                                                              │  │
│  │  ┌──────────────────────────────────────────────────────┐   │  │
│  │  │         Snowflake Connection Service                 │   │  │
│  │  │  (Connection Pooling, Query Execution, Auth)        │   │  │
│  │  └──────────────────────────────────────────────────────┘   │  │
│  │                                                              │  │
│  │                    Port 8000 (Internal)                     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Snowflake Connector
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          DATA LAYER                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    SNOWFLAKE DATABASE                        │  │
│  │                                                              │  │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐│  │
│  │  │  BRONZE LAYER  │  │  SILVER LAYER  │  │   GOLD LAYER   ││  │
│  │  │                │  │                │  │                ││  │
│  │  │  Raw Data      │→ │  Cleaned Data  │→ │  Analytics     ││  │
│  │  │  Ingestion     │  │  Transformation│  │  Aggregation   ││  │
│  │  │                │  │                │  │                ││  │
│  │  │  • Files       │  │  • Hybrid Tbl  │  │  • Hybrid Tbl  ││  │
│  │  │  • Stages      │  │  • Dynamic Tbl │  │  • Clustered   ││  │
│  │  │  • Tasks       │  │  • Procedures  │  │  • Metrics     ││  │
│  │  │  • Procedures  │  │  • Tasks       │  │  • Tasks       ││  │
│  │  └────────────────┘  └────────────────┘  └────────────────┘│  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Task Orchestration
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      ORCHESTRATION LAYER                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              Snowflake Task Scheduler                        │  │
│  │                                                              │  │
│  │  Bronze Tasks → Silver Tasks → Gold Tasks                   │  │
│  │  (Every 5min)   (Every 10min)   (Daily)                     │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Component Architecture

### 1. Frontend Components

```
┌─────────────────────────────────────────────────────────────┐
│                    React Application                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                   App.tsx                           │   │
│  │              (Main Application)                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│         ┌────────────────┼────────────────┐                │
│         ▼                ▼                ▼                │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐            │
│  │  Bronze  │    │  Silver  │    │   Gold   │            │
│  │  Module  │    │  Module  │    │  Module  │            │
│  └──────────┘    └──────────┘    └──────────┘            │
│       │               │                │                   │
│       ▼               ▼                ▼                   │
│  ┌─────────────────────────────────────────────┐          │
│  │           API Service Layer                 │          │
│  │  (Axios Client, Error Handling, Types)     │          │
│  └─────────────────────────────────────────────┘          │
│                          │                                 │
│                          ▼                                 │
│  ┌─────────────────────────────────────────────┐          │
│  │         Ant Design Components               │          │
│  │  (Table, Form, Upload, Modal, etc.)        │          │
│  └─────────────────────────────────────────────┘          │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**Key Components:**

- **Pages** (9 components):
  - Bronze: Upload, Status, Data, Stages, Tasks
  - Silver: Schemas, Mappings, Transform, Data
  
- **Services**:
  - API Client (Axios-based)
  - Type Definitions (TypeScript)
  
- **UI Library**: Ant Design
  - Tables with pagination
  - Forms with validation
  - File upload with drag-and-drop
  - Modals and notifications

### 2. Backend Components

```
┌─────────────────────────────────────────────────────────────┐
│                   FastAPI Application                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                  main.py                            │   │
│  │         (Application Entry Point)                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│         ┌────────────────┼────────────────┐                │
│         ▼                ▼                ▼                │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐            │
│  │  Bronze  │    │  Silver  │    │   TPA    │            │
│  │  Router  │    │  Router  │    │  Router  │            │
│  └──────────┘    └──────────┘    └──────────┘            │
│       │               │                │                   │
│       └───────────────┼────────────────┘                   │
│                       ▼                                    │
│  ┌─────────────────────────────────────────────┐          │
│  │       Snowflake Service Layer               │          │
│  │  • Connection Management                    │          │
│  │  • Query Execution                          │          │
│  │  • File Upload                              │          │
│  │  • Procedure Calls                          │          │
│  └─────────────────────────────────────────────┘          │
│                       │                                    │
│                       ▼                                    │
│  ┌─────────────────────────────────────────────┐          │
│  │         Configuration Layer                 │          │
│  │  (ENV, JSON, TOML, Pydantic Settings)      │          │
│  └─────────────────────────────────────────────┘          │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**Key Components:**

- **Routers** (3 modules):
  - Bronze API: File upload, status, data retrieval
  - Silver API: Schema management, mappings, transformations
  - TPA API: TPA registration and management
  
- **Services**:
  - Snowflake Service: Connection pooling, query execution
  - Configuration: Multi-source config management
  
- **Middleware**:
  - CORS handling
  - Error handling
  - Request logging

### 3. Database Components

```
┌─────────────────────────────────────────────────────────────┐
│                  SNOWFLAKE DATABASE                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              BRONZE SCHEMA                          │   │
│  │                                                     │   │
│  │  Tables (3):                                        │   │
│  │  • raw_claims_data                                  │   │
│  │  • file_processing_log                             │   │
│  │  • tpa_config                                       │   │
│  │                                                     │   │
│  │  Stages (2):                                        │   │
│  │  • @BRONZE_STAGE                                    │   │
│  │  • @BRONZE_CONFIG                                   │   │
│  │                                                     │   │
│  │  Procedures (4):                                    │   │
│  │  • register_tpa()                                   │   │
│  │  • upload_file()                                    │   │
│  │  • process_file()                                   │   │
│  │  • get_tpa_stats()                                  │   │
│  │                                                     │   │
│  │  Tasks (2):                                         │   │
│  │  • task_auto_process_files (5min)                  │   │
│  │  • task_cleanup_old_files (daily)                  │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│                          ▼                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              SILVER SCHEMA                          │   │
│  │                                                     │   │
│  │  Metadata Tables (8):                               │   │
│  │  • target_schemas (HYBRID, 2 indexes)              │   │
│  │  • field_mappings (HYBRID, 2 indexes)              │   │
│  │  • transformation_rules (HYBRID, 3 indexes)        │   │
│  │  • llm_prompt_templates (HYBRID, 1 index)          │   │
│  │  • silver_processing_log                           │   │
│  │  • data_quality_metrics                            │   │
│  │  • quarantine_records                              │   │
│  │  • processing_watermarks                           │   │
│  │                                                     │   │
│  │  Dynamic Tables:                                    │   │
│  │  • CLAIMS_<TPA> (per TPA)                          │   │
│  │  • MEMBERS_<TPA> (per TPA)                         │   │
│  │  • PROVIDERS_<TPA> (per TPA)                       │   │
│  │                                                     │   │
│  │  Procedures (6):                                    │   │
│  │  • create_silver_target_table()                    │   │
│  │  • map_bronze_to_silver()                          │   │
│  │  • apply_transformation_rules()                    │   │
│  │  • suggest_mappings_ml()                           │   │
│  │  • suggest_mappings_llm()                          │   │
│  │                                                     │   │
│  │  Tasks (2):                                         │   │
│  │  • task_auto_transform_bronze (10min)              │   │
│  │  • task_quality_checks (hourly)                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│                          ▼                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │               GOLD SCHEMA                           │   │
│  │                                                     │   │
│  │  Metadata Tables (6 HYBRID):                        │   │
│  │  • target_schemas (2 indexes)                      │   │
│  │  • target_fields (1 index)                         │   │
│  │  • transformation_rules (3 indexes)                │   │
│  │  • field_mappings (3 indexes)                      │   │
│  │  • quality_rules (3 indexes)                       │   │
│  │  • business_metrics (2 indexes)                    │   │
│  │                                                     │   │
│  │  Analytics Tables (4 CLUSTERED):                    │   │
│  │  • CLAIMS_ANALYTICS_ALL                            │   │
│  │    CLUSTER BY (tpa, year, month, type)             │   │
│  │  • MEMBER_360_ALL                                  │   │
│  │    CLUSTER BY (tpa, member_id)                     │   │
│  │  • PROVIDER_PERFORMANCE_ALL                        │   │
│  │    CLUSTER BY (tpa, provider_id, period)           │   │
│  │  • FINANCIAL_SUMMARY_ALL                           │   │
│  │    CLUSTER BY (tpa, year, month)                   │   │
│  │                                                     │   │
│  │  Log Tables (2):                                    │   │
│  │  • processing_log                                  │   │
│  │  • quality_check_results                           │   │
│  │                                                     │   │
│  │  Procedures (4):                                    │   │
│  │  • transform_claims_analytics()                    │   │
│  │  • transform_member_360()                          │   │
│  │  • execute_quality_checks()                        │   │
│  │  • run_gold_transformations()                      │   │
│  │                                                     │   │
│  │  Tasks (4):                                         │   │
│  │  • task_master_gold_refresh (daily 1am)            │   │
│  │  • task_refresh_claims_analytics (daily 2am)       │   │
│  │  • task_refresh_member_360 (daily 3am)             │   │
│  │  • task_quality_checks (daily 4am)                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Layer Architecture

### Table Type Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                    TABLE TYPE DECISION                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Metadata Tables (< 10M rows, frequent lookups)            │
│  ────────────────────────────────────────────              │
│                    │                                        │
│                    ▼                                        │
│           HYBRID TABLES                                     │
│           with INDEXES                                      │
│                                                             │
│  • Fast point queries (WHERE id = X)                       │
│  • Support UPDATE/DELETE                                   │
│  • Primary keys + secondary indexes                        │
│  • Used for: schemas, mappings, rules                      │
│                                                             │
│  Examples:                                                  │
│  • target_schemas (tpa, is_active indexes)                 │
│  • field_mappings (tpa, target_table indexes)              │
│  • transformation_rules (tpa, type, active indexes)        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Analytics Tables (> 10M rows, analytical queries)         │
│  ────────────────────────────────────────────              │
│                    │                                        │
│                    ▼                                        │
│         STANDARD TABLES                                     │
│         with CLUSTERING                                     │
│                                                             │
│  • Optimized for scans and aggregations                    │
│  • Clustering keys for pruning                             │
│  • Time-series and dimensional queries                     │
│  • Used for: analytics, facts                              │
│                                                             │
│  Examples:                                                  │
│  • CLAIMS_ANALYTICS_ALL                                    │
│    CLUSTER BY (tpa, year, month, type)                     │
│  • MEMBER_360_ALL                                          │
│    CLUSTER BY (tpa, member_id)                             │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Log Tables (append-only, no filtering)                    │
│  ────────────────────────────────────────────              │
│                    │                                        │
│                    ▼                                        │
│         STANDARD TABLES                                     │
│         (no clustering)                                     │
│                                                             │
│  • Append-only workload                                    │
│  • No clustering needed                                    │
│  • Sequential scans                                        │
│  • Used for: logs, audit trails                            │
│                                                             │
│  Examples:                                                  │
│  • processing_log                                          │
│  • quality_check_results                                   │
│  • file_processing_log                                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Index Distribution

```
HYBRID TABLES WITH INDEXES
═══════════════════════════════════════════════════════════

Silver Layer (4 hybrid tables, 8 indexes):
┌────────────────────────────────────────────────────────┐
│ target_schemas                                         │
│ • idx_target_schemas_tpa (tpa)                        │
│ • idx_target_schemas_table (table_name)               │
├────────────────────────────────────────────────────────┤
│ field_mappings                                         │
│ • idx_field_mappings_tpa (tpa)                        │
│ • idx_field_mappings_target (target_table)            │
├────────────────────────────────────────────────────────┤
│ transformation_rules                                   │
│ • idx_transformation_rules_tpa (tpa)                  │
│ • idx_transformation_rules_type (rule_type)           │
│ • idx_transformation_rules_active (active)            │
├────────────────────────────────────────────────────────┤
│ llm_prompt_templates                                   │
│ • idx_llm_templates_active (active)                   │
└────────────────────────────────────────────────────────┘

Gold Layer (6 hybrid tables, 14 indexes):
┌────────────────────────────────────────────────────────┐
│ target_schemas                                         │
│ • idx_target_schemas_tpa (tpa)                        │
│ • idx_target_schemas_active (is_active)               │
├────────────────────────────────────────────────────────┤
│ target_fields                                          │
│ • idx_target_fields_schema (schema_id)                │
├────────────────────────────────────────────────────────┤
│ transformation_rules                                   │
│ • idx_trans_rules_tpa (tpa)                           │
│ • idx_trans_rules_type (rule_type)                    │
│ • idx_trans_rules_active (is_active)                  │
├────────────────────────────────────────────────────────┤
│ field_mappings                                         │
│ • idx_field_mappings_tpa (tpa)                        │
│ • idx_field_mappings_source (source_table)            │
│ • idx_field_mappings_target (target_table)            │
├────────────────────────────────────────────────────────┤
│ quality_rules                                          │
│ • idx_quality_rules_tpa (tpa)                         │
│ • idx_quality_rules_table (table_name)                │
│ • idx_quality_rules_active (is_active)                │
├────────────────────────────────────────────────────────┤
│ business_metrics                                       │
│ • idx_business_metrics_tpa (tpa)                      │
│ • idx_business_metrics_category (metric_category)     │
└────────────────────────────────────────────────────────┘

Total: 10 hybrid tables, 22 indexes
```

### Clustering Strategy

```
STANDARD TABLES WITH CLUSTERING
═══════════════════════════════════════════════════════════

Gold Analytics Tables (4 clustered):
┌────────────────────────────────────────────────────────┐
│ CLAIMS_ANALYTICS_ALL                                   │
│ CLUSTER BY (tpa, claim_year, claim_month, claim_type) │
│                                                        │
│ Optimizes:                                             │
│ • Time-series analysis by year/month                   │
│ • Claims type filtering                                │
│ • TPA-specific queries                                 │
│ • Partition pruning on date ranges                     │
├────────────────────────────────────────────────────────┤
│ MEMBER_360_ALL                                         │
│ CLUSTER BY (tpa, member_id)                           │
│                                                        │
│ Optimizes:                                             │
│ • Member-centric queries                               │
│ • TPA-specific member lookups                          │
│ • Member history retrieval                             │
├────────────────────────────────────────────────────────┤
│ PROVIDER_PERFORMANCE_ALL                               │
│ CLUSTER BY (tpa, provider_id, measurement_period)     │
│                                                        │
│ Optimizes:                                             │
│ • Provider performance queries                         │
│ • Period-based analysis                                │
│ • TPA-specific provider metrics                        │
├────────────────────────────────────────────────────────┤
│ FINANCIAL_SUMMARY_ALL                                  │
│ CLUSTER BY (tpa, fiscal_year, fiscal_month)           │
│                                                        │
│ Optimizes:                                             │
│ • Financial reporting by period                        │
│ • Year-over-year comparisons                           │
│ • TPA-specific financial analysis                      │
└────────────────────────────────────────────────────────┘
```

---

## Deployment Architecture

### Local Development

```
┌─────────────────────────────────────────────────────────────┐
│                    LOCAL DEVELOPMENT                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Developer Machine                                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                                                      │  │
│  │  ┌────────────────┐         ┌────────────────┐     │  │
│  │  │   Frontend     │         │    Backend     │     │  │
│  │  │   (Vite Dev)   │         │   (Uvicorn)    │     │  │
│  │  │   Port 3000    │         │   Port 8000    │     │  │
│  │  └────────────────┘         └────────────────┘     │  │
│  │         │                            │              │  │
│  │         │                            │              │  │
│  │         └────────────┬───────────────┘              │  │
│  │                      │                              │  │
│  │                      ▼                              │  │
│  │         ┌────────────────────────┐                 │  │
│  │         │  Snowflake Connector   │                 │  │
│  │         └────────────────────────┘                 │  │
│  │                      │                              │  │
│  └──────────────────────┼──────────────────────────────┘  │
│                         │                                 │
└─────────────────────────┼─────────────────────────────────┘
                          │
                          │ HTTPS
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   SNOWFLAKE CLOUD                           │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Database: BORDEREAU_PIPELINE                        │  │
│  │  • BRONZE Schema                                     │  │
│  │  • SILVER Schema                                     │  │
│  │  • GOLD Schema                                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Docker Deployment

```
┌─────────────────────────────────────────────────────────────┐
│                    DOCKER DEPLOYMENT                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Docker Host                                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Docker Compose Network                              │  │
│  │                                                      │  │
│  │  ┌────────────────┐         ┌────────────────┐     │  │
│  │  │   Frontend     │         │    Backend     │     │  │
│  │  │   Container    │────────▶│   Container    │     │  │
│  │  │   (Nginx)      │  Proxy  │   (FastAPI)    │     │  │
│  │  │   Port 3000    │         │   Port 8000    │     │  │
│  │  └────────────────┘         └────────────────┘     │  │
│  │                                      │              │  │
│  └──────────────────────────────────────┼──────────────┘  │
│                                         │                  │
└─────────────────────────────────────────┼──────────────────┘
                                          │
                                          │ HTTPS
                                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   SNOWFLAKE CLOUD                           │
└─────────────────────────────────────────────────────────────┘
```

### Snowpark Container Services (SPCS)

```
┌─────────────────────────────────────────────────────────────┐
│              SNOWPARK CONTAINER SERVICES                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Snowflake Account                                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                                                      │  │
│  │  ┌────────────────────────────────────────────────┐ │  │
│  │  │         Compute Pool (CPU_X64_XS)              │ │  │
│  │  │         1 CPU, 4GB RAM                         │ │  │
│  │  │                                                │ │  │
│  │  │  ┌──────────────────────────────────────────┐ │ │  │
│  │  │  │   BORDEREAU_SERVICE                      │ │ │  │
│  │  │  │                                          │ │ │  │
│  │  │  │  ┌────────────┐    ┌────────────┐      │ │ │  │
│  │  │  │  │  Frontend  │    │  Backend   │      │ │ │  │
│  │  │  │  │ Container  │───▶│ Container  │      │ │ │  │
│  │  │  │  │  (0.4 CPU) │    │  (0.6 CPU) │      │ │ │  │
│  │  │  │  │  (1GB RAM) │    │  (2GB RAM) │      │ │ │  │
│  │  │  │  └────────────┘    └────────────┘      │ │ │  │
│  │  │  │        │                   │            │ │ │  │
│  │  │  │        │                   │            │ │ │  │
│  │  │  │  Public Endpoint    Internal Only      │ │ │  │
│  │  │  │  (Port 80)          (Port 8000)        │ │ │  │
│  │  │  └──────────────────────────────────────────┘ │ │  │
│  │  │                                                │ │  │
│  │  └────────────────────────────────────────────────┘ │  │
│  │                         │                            │  │
│  │                         ▼                            │  │
│  │  ┌────────────────────────────────────────────────┐ │  │
│  │  │         Image Repository                       │ │  │
│  │  │  • bordereau_backend:latest                    │ │  │
│  │  │  • bordereau_frontend:latest                   │ │  │
│  │  └────────────────────────────────────────────────┘ │  │
│  │                         │                            │  │
│  │                         ▼                            │  │
│  │  ┌────────────────────────────────────────────────┐ │  │
│  │  │         Database Schemas                       │ │  │
│  │  │  • BRONZE                                      │ │  │
│  │  │  • SILVER                                      │ │  │
│  │  │  • GOLD                                        │ │  │
│  │  └────────────────────────────────────────────────┘ │  │
│  │                                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  External Access:                                           │
│  https://<service-url>.snowflakecomputing.com              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Security Architecture

### Authentication & Authorization

```
┌─────────────────────────────────────────────────────────────┐
│                  AUTHENTICATION FLOW                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  User/Application                                           │
│         │                                                   │
│         ▼                                                   │
│  ┌─────────────────────────────────────┐                   │
│  │   Authentication Method Selection   │                   │
│  └─────────────────────────────────────┘                   │
│         │                                                   │
│         ├──────────────┬──────────────┬──────────────┐     │
│         ▼              ▼              ▼              ▼     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ Snow CLI │  │ Password │  │ Keypair  │  │   OAuth  │  │
│  │  (Conn)  │  │  (User/  │  │  (RSA    │  │  (Future)│  │
│  │          │  │   Pass)  │  │   Key)   │  │          │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
│         │              │              │              │     │
│         └──────────────┴──────────────┴──────────────┘     │
│                        │                                   │
│                        ▼                                   │
│         ┌──────────────────────────────┐                   │
│         │  Snowflake Authentication   │                   │
│         └──────────────────────────────┘                   │
│                        │                                   │
│                        ▼                                   │
│         ┌──────────────────────────────┐                   │
│         │    Role-Based Access         │                   │
│         │    • SYSADMIN                │                   │
│         │    • BRONZE_ADMIN            │                   │
│         │    • SILVER_ADMIN            │                   │
│         │    • GOLD_ADMIN              │                   │
│         │    • TPA_USER                │                   │
│         └──────────────────────────────┘                   │
│                        │                                   │
│                        ▼                                   │
│         ┌──────────────────────────────┐                   │
│         │   Schema-Level Permissions   │                   │
│         │   • USAGE on schemas         │                   │
│         │   • SELECT on tables         │                   │
│         │   • INSERT on tables         │                   │
│         │   • EXECUTE on procedures    │                   │
│         └──────────────────────────────┘                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Data Security

```
┌─────────────────────────────────────────────────────────────┐
│                    DATA SECURITY LAYERS                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Layer 1: Network Security                           │  │
│  │  • TLS 1.2+ encryption in transit                    │  │
│  │  • Private endpoints (SPCS)                          │  │
│  │  • Network policies                                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                         │                                   │
│                         ▼                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Layer 2: Authentication                             │  │
│  │  • Multi-factor authentication                       │  │
│  │  • Keypair authentication                            │  │
│  │  • OAuth integration                                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                         │                                   │
│                         ▼                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Layer 3: Authorization                              │  │
│  │  • Role-based access control (RBAC)                  │  │
│  │  • Schema-level permissions                          │  │
│  │  • Row-level security (TPA isolation)               │  │
│  └──────────────────────────────────────────────────────┘  │
│                         │                                   │
│                         ▼                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Layer 4: Data Encryption                            │  │
│  │  • Encryption at rest (AES-256)                      │  │
│  │  • Automatic key rotation                            │  │
│  │  • Customer-managed keys (optional)                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                         │                                   │
│                         ▼                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Layer 5: Audit & Monitoring                         │  │
│  │  • Query history tracking                            │  │
│  │  • Access logs                                       │  │
│  │  • Data lineage                                      │  │
│  │  • Compliance reporting                              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Multi-Tenant Isolation

```
┌─────────────────────────────────────────────────────────────┐
│                  MULTI-TENANT ISOLATION                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  TPA A                  TPA B                  TPA C        │
│    │                      │                      │          │
│    ▼                      ▼                      ▼          │
│  ┌─────────┐          ┌─────────┐          ┌─────────┐    │
│  │ TPA_A   │          │ TPA_B   │          │ TPA_C   │    │
│  │ Role    │          │ Role    │          │ Role    │    │
│  └─────────┘          └─────────┘          └─────────┘    │
│       │                    │                    │          │
│       └────────────────────┼────────────────────┘          │
│                            │                                │
│                            ▼                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           Row-Level Security (RLS)                   │  │
│  │                                                      │  │
│  │  Bronze Layer:                                       │  │
│  │  • raw_claims_data WHERE tpa = CURRENT_TPA()        │  │
│  │  • file_processing_log WHERE tpa = CURRENT_TPA()    │  │
│  │                                                      │  │
│  │  Silver Layer:                                       │  │
│  │  • CLAIMS_<TPA> (separate tables per TPA)           │  │
│  │  • field_mappings WHERE tpa = CURRENT_TPA()         │  │
│  │  • transformation_rules WHERE tpa = CURRENT_TPA()   │  │
│  │                                                      │  │
│  │  Gold Layer:                                         │  │
│  │  • CLAIMS_ANALYTICS_ALL WHERE tpa = CURRENT_TPA()   │  │
│  │  • MEMBER_360_ALL WHERE tpa = CURRENT_TPA()         │  │
│  │                                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                            │                                │
│                            ▼                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           Data Isolation Benefits                    │  │
│  │                                                      │  │
│  │  ✓ Complete data separation                         │  │
│  │  ✓ Independent processing pipelines                 │  │
│  │  ✓ TPA-specific configurations                      │  │
│  │  ✓ Isolated failure domains                         │  │
│  │  ✓ Compliance with data residency                   │  │
│  │                                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Integration Architecture

### External Integrations

```
┌─────────────────────────────────────────────────────────────┐
│                  INTEGRATION POINTS                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           File Upload Integration                    │  │
│  │                                                      │  │
│  │  Sources:                                            │  │
│  │  • Manual upload via UI                              │  │
│  │  • SFTP/FTP servers                                  │  │
│  │  • S3/Azure Blob/GCS                                 │  │
│  │  • Email attachments                                 │  │
│  │  • API endpoints                                     │  │
│  │                                                      │  │
│  │  ────────────▶ @BRONZE_STAGE                        │  │
│  └──────────────────────────────────────────────────────┘  │
│                            │                                │
│                            ▼                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           AI/ML Integration                          │  │
│  │                                                      │  │
│  │  Snowflake Cortex:                                   │  │
│  │  • LLM-powered field mapping                         │  │
│  │  • Semantic similarity matching                      │  │
│  │  • Data quality predictions                          │  │
│  │  • Anomaly detection                                 │  │
│  │                                                      │  │
│  │  Models:                                             │  │
│  │  • snowflake-arctic                                  │  │
│  │  • mistral-large                                     │  │
│  │  • llama2-70b-chat                                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                            │                                │
│                            ▼                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           Monitoring Integration                     │  │
│  │                                                      │  │
│  │  • Snowflake Query History                           │  │
│  │  • Task execution logs                               │  │
│  │  • Resource monitors                                 │  │
│  │  • Custom dashboards                                 │  │
│  │  • Alert notifications                               │  │
│  └──────────────────────────────────────────────────────┘  │
│                            │                                │
│                            ▼                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           BI Tool Integration                        │  │
│  │                                                      │  │
│  │  Compatible with:                                    │  │
│  │  • Tableau                                           │  │
│  │  • Power BI                                          │  │
│  │  • Looker                                            │  │
│  │  • Sigma                                             │  │
│  │  • Custom dashboards                                 │  │
│  │                                                      │  │
│  │  Access: Gold Layer Analytics Tables                │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### API Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      REST API DESIGN                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Base URL: /api                                             │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Bronze Layer Endpoints                              │  │
│  │                                                      │  │
│  │  GET    /api/bronze/files                            │  │
│  │  POST   /api/bronze/upload                           │  │
│  │  GET    /api/bronze/status/{file_id}                 │  │
│  │  GET    /api/bronze/stats                            │  │
│  │  GET    /api/bronze/stages                           │  │
│  │  GET    /api/bronze/tasks                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Silver Layer Endpoints                              │  │
│  │                                                      │  │
│  │  GET    /api/silver/schemas                          │  │
│  │  POST   /api/silver/schemas                          │  │
│  │  GET    /api/silver/mappings                         │  │
│  │  POST   /api/silver/mappings                         │  │
│  │  GET    /api/silver/rules                            │  │
│  │  POST   /api/silver/rules                            │  │
│  │  POST   /api/silver/transform                        │  │
│  │  POST   /api/silver/suggest-mappings                 │  │
│  │  GET    /api/silver/data                             │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Gold Layer Endpoints (Future)                       │  │
│  │                                                      │  │
│  │  GET    /api/gold/analytics                          │  │
│  │  GET    /api/gold/metrics                            │  │
│  │  GET    /api/gold/quality                            │  │
│  │  POST   /api/gold/refresh                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  TPA Management Endpoints                            │  │
│  │                                                      │  │
│  │  GET    /api/tpa/list                                │  │
│  │  POST   /api/tpa/register                            │  │
│  │  GET    /api/tpa/{tpa_id}/stats                      │  │
│  │  PUT    /api/tpa/{tpa_id}                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Health & Monitoring                                 │  │
│  │                                                      │  │
│  │  GET    /api/health                                  │  │
│  │  GET    /api/docs (Swagger UI)                       │  │
│  │  GET    /api/redoc (ReDoc)                           │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Performance Characteristics

### Query Performance

```
┌─────────────────────────────────────────────────────────────┐
│                  PERFORMANCE METRICS                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Hybrid Table Queries (Metadata):                           │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Point Query (WHERE id = X)          ~10ms         │    │
│  │ Indexed Filter (WHERE tpa = 'A')    ~50ms         │    │
│  │ Complex Join (3 tables)             ~200ms        │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  Standard Table Queries (Analytics):                        │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Clustered Scan (time-series)        ~500ms        │    │
│  │ Aggregation (GROUP BY)              ~1-2s         │    │
│  │ Full Table Scan (no cluster)        ~5-10s        │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  Data Processing:                                           │
│  ┌────────────────────────────────────────────────────┐    │
│  │ File Upload (10MB)                  ~5s           │    │
│  │ Bronze Processing (1000 rows)       ~10s          │    │
│  │ Silver Transformation (1000 rows)   ~30s          │    │
│  │ Gold Aggregation (1M rows)          ~2-5min       │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Scalability

```
┌─────────────────────────────────────────────────────────────┐
│                  SCALABILITY CHARACTERISTICS                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Horizontal Scaling:                                        │
│  • Snowflake auto-scales compute                            │
│  • Multi-cluster warehouses                                 │
│  • Concurrent query execution                               │
│                                                             │
│  Data Volume:                                               │
│  • Bronze: Unlimited (stage-based)                          │
│  • Silver: 100M+ rows per TPA                               │
│  • Gold: 1B+ rows (clustered)                               │
│                                                             │
│  Concurrent Users:                                          │
│  • Frontend: 100+ simultaneous users                        │
│  • API: 1000+ requests/second                               │
│  • Database: Unlimited (Snowflake)                          │
│                                                             │
│  TPAs:                                                      │
│  • Supported: 1000+ TPAs                                    │
│  • Isolation: Complete per-TPA                              │
│  • Processing: Parallel per TPA                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Technology Stack Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    TECHNOLOGY STACK                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Frontend:                                                  │
│  • React 18.2.0                                             │
│  • TypeScript 5.3.3                                         │
│  • Ant Design 5.11.5                                        │
│  • Vite 5.0.8                                               │
│  • Axios 1.6.2                                              │
│                                                             │
│  Backend:                                                   │
│  • Python 3.10+                                             │
│  • FastAPI 0.104.1                                          │
│  • Uvicorn 0.24.0                                           │
│  • Snowflake Connector 3.5.0                                │
│  • Pydantic 2.5.0                                           │
│                                                             │
│  Database:                                                  │
│  • Snowflake (Cloud Data Platform)                          │
│  • Hybrid Tables (with indexes)                             │
│  • Standard Tables (with clustering)                        │
│  • Snowflake Tasks (orchestration)                          │
│  • Snowflake Cortex (AI/ML)                                 │
│                                                             │
│  Deployment:                                                │
│  • Docker 24.0+                                             │
│  • Docker Compose 2.0+                                      │
│  • Snowpark Container Services                              │
│  • Nginx (reverse proxy)                                    │
│                                                             │
│  Development:                                               │
│  • Git (version control)                                    │
│  • Bash (deployment scripts)                                │
│  • Snow CLI (Snowflake CLI)                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Next Steps

1. **Review Data Flow Documentation** - See `DATA_FLOW.md` for detailed data flow diagrams
2. **Review System Design** - See `SYSTEM_DESIGN.md` for design patterns and decisions
3. **Deployment Guide** - See `deployment/README.md` for deployment instructions
4. **API Documentation** - Access `/api/docs` when backend is running

---

**Document Version**: 1.0  
**Last Updated**: January 19, 2026  
**Maintained By**: Platform Team
