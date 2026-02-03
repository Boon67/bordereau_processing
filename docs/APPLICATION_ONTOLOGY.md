# Bordereau Processing Pipeline - Application Ontology

## Mermaid Diagram

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

## Entity Descriptions

### Core Entities

**TPA (Third Party Administrator)**
- Primary organizational dimension
- All data is partitioned by TPA
- Registered in TPA_MASTER table

**User**
- System users who interact with the application
- Create mappings, upload files, manage schemas

**File**
- Source data files (CSV, Excel)
- Organized by TPA in stage folders
- Tracked through processing lifecycle

### Bronze Layer - Raw Data Ingestion

**Stages**
- `SRC`: Landing zone for incoming files
- `PROCESSING`: Files being actively processed
- `COMPLETED`: Successfully processed files (30-day retention)
- `ERROR`: Failed files (30-day retention)
- `ARCHIVE`: Long-term storage

**RAW_DATA_TABLE**
- Stores raw records as VARIANT (JSON)
- One row per source file record
- Clustered by TPA, FILE_NAME, LOAD_TIMESTAMP

**file_processing_queue**
- Tracks file processing status
- States: PENDING → PROCESSING → SUCCESS/FAILED

**TPA_MASTER**
- Registry of valid TPAs
- Reference data for all TPA codes

### Silver Layer - Transformed Data

**target_schemas**
- TPA-agnostic table definitions
- Shared schema across all TPAs
- Defines structure for Silver tables

**field_mappings**
- Bronze → Silver field mappings
- TPA-specific mappings
- Methods: MANUAL, ML_AUTO, LLM_CORTEX
- Includes transformation logic and confidence scores

**transformation_rules**
- Data quality and business rules
- Types: DATA_QUALITY, BUSINESS_LOGIC, STANDARDIZATION, DEDUPLICATION, REFERENTIAL_INTEGRITY
- Actions: REJECT, QUARANTINE, FLAG, CORRECT

**created_tables**
- Registry of physical Silver tables
- Format: {TPA}_{TABLE_NAME} (e.g., PROVIDER_A_DENTAL_CLAIMS)

**silver_processing_log**
- Audit trail for transformations
- Tracks batch processing metrics

**data_quality_metrics**
- Quality measurements per batch
- Pass/fail thresholds

**quarantine_records**
- Records that failed validation
- Stored for review and reprocessing

**processing_watermarks**
- Incremental processing state
- Tracks last processed record

**llm_prompt_templates**
- AI prompts for LLM-based field mapping
- Used by Cortex AI

### Gold Layer - Business Analytics

**target_schemas**
- Business entity definitions
- Analytics-ready table structures

**target_fields**
- Field specifications with business definitions
- Calculation logic for measures

**field_mappings**
- Silver → Gold aggregation mappings

**transformation_rules**
- Business rules and validations

**Gold Tables**
- Final analytics tables
- Aggregated and conformed data

## Data Flow

1. **Ingestion**: Files uploaded to Bronze SRC stage
2. **Discovery**: Files detected and queued
3. **Parsing**: Files parsed into RAW_DATA_TABLE
4. **Mapping**: Fields mapped using Manual/ML/LLM methods
5. **Transformation**: Raw data transformed to Silver tables
6. **Validation**: Quality rules applied
7. **Quarantine**: Failed records isolated
8. **Aggregation**: Silver data aggregated to Gold layer
9. **Publishing**: Final analytics tables available

## Key Relationships

- **TPA is the primary dimension** - All data is partitioned by TPA
- **Schemas are shared, tables are per-TPA** - One schema definition, multiple physical tables
- **Mappings are TPA-specific** - Each TPA has its own field mappings
- **Rules are TPA-specific** - Data quality rules per TPA
- **Three mapping methods** - Manual, ML pattern matching, LLM semantic understanding
- **Cascading deletes** - Deleting tables removes associated mappings and rules
