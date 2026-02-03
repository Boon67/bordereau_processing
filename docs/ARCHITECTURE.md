# Architecture and Data Model

Visual reference for system architecture, data entities, and relationships.

---

## System Architecture Diagram

```mermaid
graph TB
    subgraph "Core Entities"
        TPA[TPA<br/>Third Party Administrator]
        USER[User<br/>System User]
        FILE[File<br/>Source Data File]
    end

    subgraph "Bronze Layer - Raw Data Ingestion"
        STAGE_SRC[Stage: SRC<br/>Landing Zone]
        STAGE_PROC[Stage: PROCESSING<br/>Active Processing]
        STAGE_COMP[Stage: COMPLETED<br/>Success Archive]
        STAGE_ERR[Stage: ERROR<br/>Failed Files]
        STAGE_ARCH[Stage: ARCHIVE<br/>Long-term Storage]
        
        RAW_DATA[RAW_DATA_TABLE<br/>VARIANT Storage]
        FILE_QUEUE[file_processing_queue<br/>Processing Status]
        TPA_MASTER[TPA_MASTER<br/>TPA Registry]
    end

    subgraph "Silver Layer - Transformed Data"
        TARGET_SCHEMA[target_schemas<br/>Table Definitions]
        FIELD_MAPPING[field_mappings<br/>Bronze→Silver Mappings]
        TRANS_RULES[transformation_rules<br/>Data Quality Rules]
        CREATED_TABLES[created_tables<br/>Physical Table Registry]
        
        SILVER_LOG[silver_processing_log<br/>Transformation Audit]
        DQ_METRICS[data_quality_metrics<br/>Quality Tracking]
        QUARANTINE[quarantine_records<br/>Failed Records]
        WATERMARKS[processing_watermarks<br/>Incremental State]
        
        LLM_TEMPLATES[llm_prompt_templates<br/>AI Mapping Prompts]
        
        SILVER_TABLES[Silver Data Tables<br/>TPA_TABLENAME]
    end

    subgraph "Gold Layer - Business Analytics"
        GOLD_SCHEMA[target_schemas<br/>Business Entity Definitions]
        GOLD_FIELDS[target_fields<br/>Field Specifications]
        GOLD_MAPPINGS[field_mappings<br/>Silver→Gold Mappings]
        GOLD_TRANS[transformation_rules<br/>Business Rules]
        GOLD_TABLES[Gold Analytics Tables<br/>Aggregated/Conformed Data]
    end

    subgraph "Mapping Methods"
        MANUAL[Manual Mapping<br/>CSV Upload]
        ML_AUTO[ML Auto-Mapping<br/>Pattern Matching]
        LLM_CORTEX[LLM Auto-Mapping<br/>Cortex AI]
    end

    subgraph "Processing Types"
        DISCOVERY[Discovery<br/>File Detection]
        MAPPING[Mapping<br/>Field Alignment]
        TRANSFORMATION[Transformation<br/>Data Conversion]
        VALIDATION[Validation<br/>Quality Checks]
        PUBLISH[Publish<br/>Final Output]
    end

    %% Core Relationships
    TPA -->|owns| FILE
    USER -->|uploads| FILE
    TPA -->|registered in| TPA_MASTER
    
    %% Bronze Layer Flow
    FILE -->|lands in| STAGE_SRC
    STAGE_SRC -->|discovered| FILE_QUEUE
    FILE_QUEUE -->|processing| STAGE_PROC
    STAGE_PROC -->|success| STAGE_COMP
    STAGE_PROC -->|failure| STAGE_ERR
    STAGE_COMP -->|archive| STAGE_ARCH
    STAGE_ERR -->|archive| STAGE_ARCH
    
    FILE -->|parsed into| RAW_DATA
    RAW_DATA -->|belongs to| TPA
    
    %% Silver Layer Relationships
    TARGET_SCHEMA -->|defines| SILVER_TABLES
    FIELD_MAPPING -->|maps to| TARGET_SCHEMA
    FIELD_MAPPING -->|sources from| RAW_DATA
    FIELD_MAPPING -->|per| TPA
    
    TRANS_RULES -->|validates| SILVER_TABLES
    TRANS_RULES -->|per| TPA
    
    CREATED_TABLES -->|tracks| SILVER_TABLES
    CREATED_TABLES -->|per| TPA
    
    RAW_DATA -->|transforms to| SILVER_TABLES
    SILVER_TABLES -->|logged in| SILVER_LOG
    SILVER_TABLES -->|metrics in| DQ_METRICS
    TRANS_RULES -->|failures to| QUARANTINE
    WATERMARKS -->|tracks progress| SILVER_TABLES
    
    %% Mapping Methods
    MANUAL -->|creates| FIELD_MAPPING
    ML_AUTO -->|creates| FIELD_MAPPING
    LLM_CORTEX -->|creates| FIELD_MAPPING
    LLM_TEMPLATES -->|used by| LLM_CORTEX
    
    %% Gold Layer Relationships
    SILVER_TABLES -->|aggregates to| GOLD_TABLES
    GOLD_SCHEMA -->|defines| GOLD_TABLES
    GOLD_FIELDS -->|specifies| GOLD_SCHEMA
    GOLD_MAPPINGS -->|maps| SILVER_TABLES
    GOLD_TRANS -->|validates| GOLD_TABLES
    
    %% Processing Flow
    DISCOVERY -->|creates| FILE_QUEUE
    MAPPING -->|creates| FIELD_MAPPING
    TRANSFORMATION -->|creates| SILVER_TABLES
    VALIDATION -->|uses| TRANS_RULES
    PUBLISH -->|creates| GOLD_TABLES

    classDef coreEntity fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef bronzeEntity fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef silverEntity fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef goldEntity fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef processEntity fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    
    class TPA,USER,FILE coreEntity
    class STAGE_SRC,STAGE_PROC,STAGE_COMP,STAGE_ERR,STAGE_ARCH,RAW_DATA,FILE_QUEUE,TPA_MASTER bronzeEntity
    class TARGET_SCHEMA,FIELD_MAPPING,TRANS_RULES,CREATED_TABLES,SILVER_LOG,DQ_METRICS,QUARANTINE,WATERMARKS,LLM_TEMPLATES,SILVER_TABLES silverEntity
    class GOLD_SCHEMA,GOLD_FIELDS,GOLD_MAPPINGS,GOLD_TRANS,GOLD_TABLES goldEntity
    class MANUAL,ML_AUTO,LLM_CORTEX,DISCOVERY,MAPPING,TRANSFORMATION,VALIDATION,PUBLISH processEntity
```

---

## Entity Reference

### Core Entities

| Entity | Purpose | Key Attributes |
|--------|---------|----------------|
| **TPA** | Third Party Administrator - primary organizational dimension | `tpa_code`, `tpa_name`, `description` |
| **User** | System users who manage data and mappings | `user_id`, `username`, `role` |
| **File** | Source data files (CSV, Excel) | `file_name`, `tpa_code`, `upload_timestamp` |

### Bronze Layer - Raw Data Ingestion

| Entity | Purpose | Retention |
|--------|---------|-----------|
| **Stage: SRC** | Landing zone for incoming files | Until processed |
| **Stage: PROCESSING** | Files being actively processed | N/A |
| **Stage: COMPLETED** | Successfully processed files | 30 days |
| **Stage: ERROR** | Failed files | 30 days |
| **Stage: ARCHIVE** | Long-term storage | 90 days |
| **RAW_DATA_TABLE** | VARIANT (JSON) storage for raw records | Permanent |
| **file_processing_queue** | Processing status tracker | Permanent |
| **TPA_MASTER** | Registry of valid TPAs | Permanent |

**RAW_DATA_TABLE Clustering**: `TPA`, `FILE_NAME`, `LOAD_TIMESTAMP`

### Silver Layer - Transformed Data

| Entity | Purpose | Scope |
|--------|---------|-------|
| **target_schemas** | Reusable table definitions | Shared across TPAs |
| **field_mappings** | Bronze → Silver field mappings | TPA-specific |
| **transformation_rules** | Data quality and business rules | TPA-specific |
| **created_tables** | Registry of physical tables | TPA-specific |
| **silver_processing_log** | Transformation audit trail | All TPAs |
| **data_quality_metrics** | Quality measurements | Per batch |
| **quarantine_records** | Failed validation records | All TPAs |
| **processing_watermarks** | Incremental processing state | Per TPA/table |
| **llm_prompt_templates** | AI prompts for LLM mapping | Shared |

**Mapping Methods**: `MANUAL`, `ML_AUTO`, `LLM_CORTEX`  
**Rule Types**: `DATA_QUALITY`, `BUSINESS_LOGIC`, `STANDARDIZATION`, `DEDUPLICATION`, `REFERENTIAL_INTEGRITY`  
**Rule Actions**: `REJECT`, `QUARANTINE`, `FLAG`, `CORRECT`

### Gold Layer - Business Analytics

| Entity | Purpose |
|--------|---------|
| **target_schemas** | Business entity definitions |
| **target_fields** | Field specifications with business logic |
| **field_mappings** | Silver → Gold aggregation mappings |
| **transformation_rules** | Business rules and validations |
| **Gold Tables** | Final analytics tables (aggregated/conformed) |

---

## Data Flow

```
1. Upload      → Files land in @SRC/{tpa}/
2. Discovery   → discover_files_task scans stages
3. Parsing     → process_files_task → RAW_DATA_TABLE
4. Mapping     → Define field_mappings (Manual/ML/LLM)
5. Transform   → Apply mappings → Silver tables
6. Validate    → Apply transformation_rules
7. Quarantine  → Failed records → quarantine_records
8. Aggregate   → Silver → Gold analytics
9. Publish     → Gold tables available for analysis
```

---

## Key Design Principles

| Principle | Implementation |
|-----------|----------------|
| **TPA Isolation** | All data partitioned by TPA; separate folders, tables, mappings |
| **Schema Reusability** | One schema definition → multiple TPA-specific physical tables |
| **Mapping Flexibility** | Three methods: Manual (custom), ML (pattern), LLM (semantic) |
| **Data Quality** | Validation rules with configurable actions (reject/quarantine/flag/correct) |
| **Audit Trail** | Comprehensive logging at every processing stage |
| **Incremental Processing** | Watermarks track last processed record for efficiency |
| **Cascading Deletes** | Deleting tables removes associated mappings and rules |

---

## Table Naming Conventions

| Layer | Pattern | Example |
|-------|---------|---------|
| **Bronze** | `{TABLE_NAME}` | `RAW_DATA_TABLE` |
| **Silver** | `{TPA}_{TABLE_NAME}` | `PROVIDER_A_MEDICAL_CLAIMS` |
| **Gold** | `{ENTITY_NAME}` | `CLAIMS_ANALYTICS`, `MEMBER_360` |

---

## Processing States

**File Processing**:
```
PENDING → PROCESSING → SUCCESS
                    └→ FAILED
```

**Record Validation**:
```
Raw Record → Validation → PASS → Silver Table
                       └→ FAIL → Quarantine
```

**Task Execution**:
```
SCHEDULED → RUNNING → SUCCEEDED
                   └→ FAILED → RETRY
```

---

**Version**: 3.3 | **Last Updated**: February 3, 2026
