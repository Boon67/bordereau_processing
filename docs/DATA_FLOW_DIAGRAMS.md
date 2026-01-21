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

```mermaid
flowchart TD
    Start([File Upload]) --> Upload[Upload to Bronze]
    
    Upload --> BronzeValidate{Validate File}
    BronzeValidate -->|Valid| BronzeProcess[Process & Store]
    BronzeValidate -->|Invalid| BronzeError[Move to @ERROR]
    
    BronzeProcess --> BronzeComplete[Move to @COMPLETED]
    BronzeComplete --> BronzeTask[Bronze Task<br/>Every 5 min]
    
    BronzeTask --> SilverMap{Schema<br/>Mapped?}
    SilverMap -->|Yes| SilverTransform[Transform to Silver]
    SilverMap -->|No| SilverWait[Wait for Mapping]
    
    SilverTransform --> SilverQuality{Quality<br/>Check}
    SilverQuality -->|Pass| SilverComplete[Silver Table]
    SilverQuality -->|Fail| SilverQuarantine[Quarantine]
    
    SilverComplete --> SilverTask[Silver Task<br/>Every 10 min]
    SilverTask --> GoldAggregate[Aggregate to Gold]
    
    GoldAggregate --> GoldQuality{Quality<br/>Check}
    GoldQuality -->|Pass| GoldComplete[Gold Analytics]
    GoldQuality -->|Fail| GoldLog[Log Issues]
    
    GoldComplete --> End([Analytics Ready])
    
    BronzeError --> ErrorReview[Manual Review]
    SilverQuarantine --> QuarantineReview[Manual Review]
    GoldLog --> IssueReview[Manual Review]
    
    style Start fill:#4caf50
    style End fill:#4caf50
    style BronzeProcess fill:#ffcdd2
    style SilverTransform fill:#bbdefb
    style GoldAggregate fill:#fff9c4
    style BronzeError fill:#f44336
    style SilverQuarantine fill:#ff9800
    style GoldLog fill:#ff9800
```

---

## Bronze Layer Data Flow

### File Upload and Processing

```mermaid
sequenceDiagram
    participant User
    participant UI as Frontend
    participant API as Backend API
    participant Stage as @BRONZE_STAGE
    participant Table as raw_claims_data
    participant Log as file_processing_log
    participant Task as Bronze Task
    
    User->>UI: 1. Select File & TPA
    UI->>API: 2. POST /api/bronze/upload
    API->>Stage: 3. PUT file
    Stage-->>API: 4. File stored
    
    API->>Table: 5. INSERT metadata
    Note over Table: file_id, tpa, filename,<br/>size, status=UPLOADED
    
    API->>Log: 6. Log upload
    Log-->>API: 7. Log ID
    API-->>UI: 8. {file_id, status}
    UI-->>User: 9. Upload Success
    
    Note over Task: Runs every 5 minutes
    Task->>Table: 10. SELECT status=UPLOADED
    Table-->>Task: 11. Pending files
    
    loop For each file
        Task->>Task: 12. Validate format
        Task->>Task: 13. Parse data
        Task->>Table: 14. UPDATE status=PROCESSED
        Task->>Log: 15. Log processing
    end
    
    Task->>Stage: 16. MOVE to @COMPLETED
```

### Bronze Processing States

```mermaid
stateDiagram-v2
    [*] --> UPLOADED: File uploaded
    UPLOADED --> VALIDATING: Task picks up
    VALIDATING --> PROCESSING: Validation passed
    VALIDATING --> ERROR: Validation failed
    PROCESSING --> PROCESSED: Processing complete
    PROCESSING --> ERROR: Processing failed
    PROCESSED --> COMPLETED: Moved to @COMPLETED
    ERROR --> MANUAL_REVIEW: Needs attention
    MANUAL_REVIEW --> UPLOADED: Retry
    MANUAL_REVIEW --> ARCHIVED: Discard
    COMPLETED --> ARCHIVED: After retention period
    ARCHIVED --> [*]
    
    note right of VALIDATING
        Check format
        Verify TPA
        Validate structure
    end note
    
    note right of PROCESSING
        Parse data
        Load to table
        Generate metadata
    end note
```

### Bronze Data Storage

```mermaid
graph TB
    subgraph Upload["File Upload"]
        File[CSV/Excel File]
        Metadata[File Metadata<br/>TPA, Size, Format]
    end
    
    subgraph Stages["Bronze Stages"]
        SRC[@SRC<br/>Source Files]
        COMPLETED[@COMPLETED<br/>Processed Files]
        ERROR[@ERROR<br/>Failed Files]
        ARCHIVE[@ARCHIVE<br/>Old Files]
    end
    
    subgraph Tables["Bronze Tables"]
        Raw[raw_claims_data<br/>Immutable Raw Data]
        Queue[file_processing_queue<br/>Processing Queue]
        Log[file_processing_log<br/>Audit Trail]
        TPA[tpa_config<br/>TPA Settings]
    end
    
    File --> SRC
    Metadata --> Raw
    SRC -->|Success| COMPLETED
    SRC -->|Failure| ERROR
    COMPLETED -->|30 days| ARCHIVE
    
    Raw --> Queue
    Queue --> Log
    TPA -.->|Config| Queue
    
    style Upload fill:#e1f5ff
    style Stages fill:#ffebee
    style Tables fill:#ffcdd2
```

---

## Silver Layer Data Flow

### Schema Mapping and Transformation

```mermaid
flowchart TD
    Start([Bronze Data Ready]) --> CheckSchema{Schema<br/>Defined?}
    
    CheckSchema -->|No| DefineSchema[Define Target Schema]
    DefineSchema --> CreateMappings[Create Field Mappings]
    
    CheckSchema -->|Yes| LoadMappings[Load Mappings]
    CreateMappings --> LoadMappings
    
    LoadMappings --> AICheck{Use AI<br/>Mapping?}
    AICheck -->|Yes| AIMap[AI-Powered Mapping<br/>ML or LLM]
    AICheck -->|No| ManualMap[Manual Mapping]
    
    AIMap --> ValidateMap{Validate<br/>Mappings}
    ManualMap --> ValidateMap
    
    ValidateMap -->|Invalid| CreateMappings
    ValidateMap -->|Valid| Transform[Apply Transformations]
    
    Transform --> ApplyRules[Apply Business Rules]
    ApplyRules --> QualityCheck{Quality<br/>Check}
    
    QualityCheck -->|Pass| SilverTable[Insert into Silver Table]
    QualityCheck -->|Fail| Quarantine[Move to Quarantine]
    
    SilverTable --> UpdateLog[Update Processing Log]
    Quarantine --> UpdateLog
    
    UpdateLog --> End([Silver Data Ready])
    
    style Start fill:#4caf50
    style End fill:#4caf50
    style Transform fill:#bbdefb
    style AIMap fill:#fff9c4
    style QualityCheck fill:#ff9800
```

### Silver Transformation Process

```mermaid
sequenceDiagram
    participant Bronze as Bronze Table
    participant Mapping as field_mappings
    participant Rules as transformation_rules
    participant Proc as Transform Procedure
    participant Silver as Silver Table
    participant Quality as quality_metrics
    participant Quarantine as quarantine_records
    
    Note over Proc: Task triggers every 10 min
    
    Proc->>Bronze: 1. SELECT new records
    Bronze-->>Proc: 2. Raw data
    
    Proc->>Mapping: 3. GET field mappings
    Mapping-->>Proc: 4. Mapping rules
    
    Proc->>Rules: 5. GET transformation rules
    Rules-->>Proc: 6. Business rules
    
    loop For each record
        Proc->>Proc: 7. Map fields
        Proc->>Proc: 8. Apply transformations
        Proc->>Proc: 9. Validate data
        
        alt Quality Check Pass
            Proc->>Silver: 10a. INSERT record
            Proc->>Quality: 11a. Log metrics
        else Quality Check Fail
            Proc->>Quarantine: 10b. INSERT record
            Proc->>Quality: 11b. Log failure
        end
    end
    
    Proc->>Proc: 12. Update watermark
```

### AI-Powered Mapping

```mermaid
graph TB
    subgraph Input["Input"]
        BronzeFields[Bronze Fields<br/>Unknown Schema]
        TargetSchema[Target Schema<br/>Defined Structure]
    end
    
    subgraph AI["AI Mapping Engine"]
        ML[ML Model<br/>Pattern Matching<br/>Historical Data]
        LLM[Cortex LLM<br/>Semantic Understanding<br/>Context Analysis]
        
        ML --> Combine[Combine Results]
        LLM --> Combine
    end
    
    subgraph Output["Output"]
        Suggestions[Mapping Suggestions<br/>Confidence Scores]
        Review[Human Review<br/>Approve/Reject]
    end
    
    BronzeFields --> ML
    BronzeFields --> LLM
    TargetSchema --> ML
    TargetSchema --> LLM
    
    Combine --> Suggestions
    Suggestions --> Review
    Review -->|Approved| FinalMapping[Final Mappings]
    Review -->|Rejected| ML
    
    style Input fill:#e1f5ff
    style AI fill:#fff9c4
    style Output fill:#e8f5e9
```

### Silver Data Quality

```mermaid
flowchart TD
    Start([Record Received]) --> Completeness{Completeness<br/>Check}
    
    Completeness -->|Pass| Validity{Validity<br/>Check}
    Completeness -->|Fail| LogComplete[Log Issue]
    
    Validity -->|Pass| Consistency{Consistency<br/>Check}
    Validity -->|Fail| LogValid[Log Issue]
    
    Consistency -->|Pass| Timeliness{Timeliness<br/>Check}
    Consistency -->|Fail| LogConsist[Log Issue]
    
    Timeliness -->|Pass| AllPass{All Checks<br/>Passed?}
    Timeliness -->|Fail| LogTime[Log Issue]
    
    LogComplete --> Severity1{Severity}
    LogValid --> Severity2{Severity}
    LogConsist --> Severity3{Severity}
    LogTime --> Severity4{Severity}
    
    Severity1 -->|Critical| Quarantine[Quarantine Record]
    Severity1 -->|Warning| AllPass
    Severity2 -->|Critical| Quarantine
    Severity2 -->|Warning| AllPass
    Severity3 -->|Critical| Quarantine
    Severity3 -->|Warning| AllPass
    Severity4 -->|Critical| Quarantine
    Severity4 -->|Warning| AllPass
    
    AllPass -->|Yes| SilverTable[Insert to Silver]
    AllPass -->|No| Quarantine
    
    SilverTable --> End([Quality Verified])
    Quarantine --> Review[Manual Review]
    
    style Start fill:#4caf50
    style End fill:#4caf50
    style SilverTable fill:#bbdefb
    style Quarantine fill:#ff9800
```

---

## Gold Layer Data Flow

### Analytics Aggregation

```mermaid
flowchart TD
    Start([Silver Data Ready]) --> SelectTables[Select Silver Tables]
    
    SelectTables --> LoadRules[Load Transformation Rules]
    LoadRules --> LoadMetrics[Load Business Metrics]
    
    LoadMetrics --> Aggregate[Aggregate Data]
    
    Aggregate --> ClaimsAnalytics[CLAIMS_ANALYTICS<br/>Time-series aggregation]
    Aggregate --> Member360[MEMBER_360<br/>Member consolidation]
    Aggregate --> ProviderPerf[PROVIDER_PERFORMANCE<br/>Provider metrics]
    Aggregate --> Financial[FINANCIAL_SUMMARY<br/>Financial rollups]
    
    ClaimsAnalytics --> QualityRules{Quality<br/>Rules}
    Member360 --> QualityRules
    ProviderPerf --> QualityRules
    Financial --> QualityRules
    
    QualityRules -->|Pass| GoldTables[Insert to Gold Tables]
    QualityRules -->|Fail| LogIssues[Log Quality Issues]
    
    GoldTables --> UpdateMetrics[Update Business Metrics]
    LogIssues --> UpdateMetrics
    
    UpdateMetrics --> End([Analytics Ready])
    
    style Start fill:#4caf50
    style End fill:#4caf50
    style ClaimsAnalytics fill:#fff9c4
    style Member360 fill:#fff9c4
    style ProviderPerf fill:#fff9c4
    style Financial fill:#fff9c4
```

### Gold Transformation Flow

```mermaid
sequenceDiagram
    participant Task as Gold Task
    participant Silver as Silver Tables
    participant Rules as transformation_rules
    participant Proc as Transform Procedure
    participant Gold as Gold Analytics
    participant Quality as quality_check_results
    participant Log as processing_log
    
    Note over Task: Runs daily
    
    Task->>Proc: 1. Trigger transformation
    
    Proc->>Rules: 2. GET active rules
    Rules-->>Proc: 3. Transformation logic
    
    Proc->>Silver: 4. SELECT data
    Note over Silver: Filtered by TPA<br/>Time period
    Silver-->>Proc: 5. Source data
    
    loop For each aggregation
        Proc->>Proc: 6. Apply aggregation
        Proc->>Proc: 7. Calculate metrics
        Proc->>Proc: 8. Apply business rules
        
        Proc->>Gold: 9. MERGE into target
        Note over Gold: UPSERT based on<br/>clustering keys
    end
    
    Proc->>Quality: 10. Run quality checks
    Quality-->>Proc: 11. Check results
    
    alt All Checks Pass
        Proc->>Log: 12a. Log success
    else Some Checks Fail
        Proc->>Log: 12b. Log warnings
    end
    
    Log-->>Task: 13. Completion status
```

### Gold Analytics Tables

```mermaid
graph TB
    subgraph Silver["Silver Layer"]
        S1[CLAIMS_PROVIDER_A]
        S2[CLAIMS_PROVIDER_B]
        S3[CLAIMS_PROVIDER_C]
        S4[MEMBERS_*]
        S5[PROVIDERS_*]
    end
    
    subgraph Gold["Gold Layer Analytics"]
        subgraph Claims["CLAIMS_ANALYTICS"]
            C1[Aggregated by:<br/>• Year/Month<br/>• Claim Type<br/>• Provider<br/>• TPA]
            C2[Metrics:<br/>• Total Claims<br/>• Total Amount<br/>• Avg per Claim<br/>• Discount Rate]
        end
        
        subgraph Member["MEMBER_360"]
            M1[Aggregated by:<br/>• Member ID<br/>• TPA]
            M2[Metrics:<br/>• Total Claims<br/>• Utilization<br/>• Risk Score<br/>• Demographics]
        end
        
        subgraph Provider["PROVIDER_PERFORMANCE"]
            P1[Aggregated by:<br/>• Provider ID<br/>• Period<br/>• TPA]
            P2[Metrics:<br/>• Claim Count<br/>• Avg Cost<br/>• Quality Score<br/>• Network Status]
        end
        
        subgraph Financial["FINANCIAL_SUMMARY"]
            F1[Aggregated by:<br/>• Fiscal Year/Month<br/>• TPA]
            F2[Metrics:<br/>• Revenue<br/>• Costs<br/>• Margins<br/>• Trends]
        end
    end
    
    S1 --> Claims
    S2 --> Claims
    S3 --> Claims
    S4 --> Member
    S4 --> Claims
    S5 --> Provider
    S1 --> Financial
    S2 --> Financial
    S3 --> Financial
    
    style Silver fill:#bbdefb
    style Claims fill:#fff9c4
    style Member fill:#c8e6c9
    style Provider fill:#b3e5fc
    style Financial fill:#ffccbc
```

---

## Task Orchestration Flow

### Task Dependencies and Schedule

```mermaid
gantt
    title Task Orchestration Timeline
    dateFormat HH:mm
    axisFormat %H:%M
    
    section Bronze Layer
    File Discovery       :done, bronze1, 00:00, 5m
    File Processing      :done, bronze2, after bronze1, 10m
    File Cleanup         :done, bronze3, after bronze2, 5m
    
    section Silver Layer
    Wait for Bronze      :crit, silver1, after bronze3, 5m
    Schema Mapping       :active, silver2, after silver1, 15m
    Transformation       :silver3, after silver2, 20m
    Quality Checks       :silver4, after silver3, 10m
    
    section Gold Layer
    Wait for Silver      :crit, gold1, after silver4, 10m
    Aggregation          :gold2, after gold1, 30m
    Quality Checks       :gold3, after gold2, 10m
    Metric Calculation   :gold4, after gold3, 5m
```

### Task Execution Flow

```mermaid
flowchart TD
    Start([Scheduler]) --> BronzeTask[Bronze Task<br/>Every 5 minutes]
    
    BronzeTask --> BronzeCheck{New Files?}
    BronzeCheck -->|Yes| BronzeProcess[Process Files]
    BronzeCheck -->|No| BronzeWait[Wait]
    
    BronzeProcess --> BronzeComplete[Update Status]
    BronzeComplete --> TriggerSilver[Trigger Silver]
    
    TriggerSilver --> SilverTask[Silver Task<br/>Every 10 minutes]
    
    SilverTask --> SilverCheck{New Bronze<br/>Data?}
    SilverCheck -->|Yes| SilverTransform[Transform Data]
    SilverCheck -->|No| SilverWait[Wait]
    
    SilverTransform --> SilverComplete[Update Status]
    SilverComplete --> TriggerGold[Trigger Gold]
    
    TriggerGold --> GoldTask[Gold Task<br/>Daily]
    
    GoldTask --> GoldCheck{New Silver<br/>Data?}
    GoldCheck -->|Yes| GoldAggregate[Aggregate Data]
    GoldCheck -->|No| GoldWait[Wait]
    
    GoldAggregate --> GoldComplete[Update Status]
    GoldComplete --> End([Complete])
    
    BronzeWait --> End
    SilverWait --> End
    GoldWait --> End
    
    style Start fill:#4caf50
    style End fill:#4caf50
    style BronzeProcess fill:#ffcdd2
    style SilverTransform fill:#bbdefb
    style GoldAggregate fill:#fff9c4
```

### Task Monitoring

```mermaid
graph TB
    subgraph Monitoring["Task Monitoring"]
        subgraph Status["Task Status"]
            Running[Running Tasks]
            Completed[Completed Tasks]
            Failed[Failed Tasks]
            Suspended[Suspended Tasks]
        end
        
        subgraph Metrics["Metrics"]
            Duration[Execution Duration]
            Records[Records Processed]
            Errors[Error Count]
            Success[Success Rate]
        end
        
        subgraph Logs["Logging"]
            ProcessLog[processing_log]
            TaskHistory[task_history]
            ErrorLog[error_log]
        end
        
        subgraph Views["Monitoring Views"]
            V1[v_bronze_status]
            V2[v_silver_status]
            V3[v_gold_status]
            V4[v_task_summary]
        end
    end
    
    Status --> Metrics
    Metrics --> Logs
    Logs --> Views
    
    style Status fill:#e1f5ff
    style Metrics fill:#fff9c4
    style Logs fill:#ffebee
    style Views fill:#e8f5e9
```

---

## Error Handling Flow

### Error Processing

```mermaid
flowchart TD
    Start([Error Detected]) --> Classify{Error<br/>Type}
    
    Classify -->|Validation| ValidationError[Validation Error]
    Classify -->|Transformation| TransformError[Transformation Error]
    Classify -->|Quality| QualityError[Quality Error]
    Classify -->|System| SystemError[System Error]
    
    ValidationError --> LogError1[Log Error]
    TransformError --> LogError2[Log Error]
    QualityError --> LogError3[Log Error]
    SystemError --> LogError4[Log Error]
    
    LogError1 --> Severity1{Severity}
    LogError2 --> Severity2{Severity}
    LogError3 --> Severity3{Severity}
    LogError4 --> Severity4{Severity}
    
    Severity1 -->|Critical| MoveError[Move to @ERROR]
    Severity1 -->|Warning| Quarantine[Move to Quarantine]
    Severity1 -->|Info| Continue[Continue Processing]
    
    Severity2 -->|Critical| MoveError
    Severity2 -->|Warning| Quarantine
    Severity2 -->|Info| Continue
    
    Severity3 -->|Critical| MoveError
    Severity3 -->|Warning| Quarantine
    Severity3 -->|Info| Continue
    
    Severity4 -->|Critical| Alert[Send Alert]
    Severity4 -->|Warning| Quarantine
    Severity4 -->|Info| Continue
    
    MoveError --> Retry{Auto<br/>Retry?}
    Retry -->|Yes| RetryProcess[Retry Processing]
    Retry -->|No| ManualReview[Manual Review]
    
    RetryProcess --> RetryCount{Retry<br/>Count < 3?}
    RetryCount -->|Yes| Start
    RetryCount -->|No| ManualReview
    
    Alert --> ManualReview
    Quarantine --> ManualReview
    Continue --> End([Processing Continues])
    ManualReview --> End
    
    style Start fill:#ff9800
    style End fill:#4caf50
    style MoveError fill:#f44336
    style Quarantine fill:#ff9800
    style Continue fill:#4caf50
```

### Error Recovery

```mermaid
stateDiagram-v2
    [*] --> Processing
    Processing --> Error: Error occurs
    Error --> Logged: Log error
    Logged --> Classified: Classify severity
    
    Classified --> Retry: Retriable error
    Classified --> Quarantine: Data quality issue
    Classified --> Failed: Non-retriable error
    
    Retry --> Processing: Retry attempt
    Retry --> Failed: Max retries exceeded
    
    Quarantine --> ManualReview: Needs attention
    ManualReview --> Processing: Fixed & retry
    ManualReview --> Failed: Cannot fix
    
    Failed --> Archived: After review
    Archived --> [*]
    
    note right of Retry
        Max 3 attempts
        Exponential backoff
    end note
    
    note right of Quarantine
        Preserve data
        Flag for review
        Track lineage
    end note
```

---

## Data Quality Flow

### Quality Check Framework

```mermaid
graph TB
    subgraph Input["Input Data"]
        Record[Data Record]
    end
    
    subgraph Checks["Quality Checks"]
        subgraph Completeness["Completeness"]
            C1[Required Fields Present]
            C2[No Null Values]
            C3[Field Population Rate]
        end
        
        subgraph Validity["Validity"]
            V1[Data Type Correct]
            V2[Format Valid]
            V3[Range Check]
            V4[Pattern Match]
        end
        
        subgraph Consistency["Consistency"]
            CS1[Cross-field Validation]
            CS2[Referential Integrity]
            CS3[Business Rule Check]
        end
        
        subgraph Timeliness["Timeliness"]
            T1[Date Range Valid]
            T2[Not Too Old]
            T3[Sequential Order]
        end
    end
    
    subgraph Results["Results"]
        Pass[All Checks Pass<br/>Insert to Table]
        Warning[Some Warnings<br/>Insert with Flags]
        Fail[Critical Failure<br/>Move to Quarantine]
    end
    
    Record --> Completeness
    Record --> Validity
    Record --> Consistency
    Record --> Timeliness
    
    Completeness --> Score[Calculate<br/>Quality Score]
    Validity --> Score
    Consistency --> Score
    Timeliness --> Score
    
    Score --> Evaluate{Evaluate<br/>Score}
    Evaluate -->|>= 95%| Pass
    Evaluate -->|75-94%| Warning
    Evaluate -->|< 75%| Fail
    
    style Input fill:#e1f5ff
    style Checks fill:#fff9c4
    style Results fill:#e8f5e9
    style Pass fill:#4caf50
    style Warning fill:#ff9800
    style Fail fill:#f44336
```

### Quality Metrics Tracking

```mermaid
flowchart LR
    subgraph Source["Data Source"]
        Bronze[Bronze Layer]
        Silver[Silver Layer]
        Gold[Gold Layer]
    end
    
    subgraph Metrics["Quality Metrics"]
        M1[Completeness Rate]
        M2[Validity Rate]
        M3[Consistency Rate]
        M4[Timeliness Rate]
        M5[Overall Quality Score]
    end
    
    subgraph Storage["Metric Storage"]
        QM[quality_metrics Table]
        QR[quality_check_results Table]
    end
    
    subgraph Reporting["Reporting"]
        Dashboard[Quality Dashboard]
        Alerts[Quality Alerts]
        Trends[Trend Analysis]
    end
    
    Bronze --> Metrics
    Silver --> Metrics
    Gold --> Metrics
    
    Metrics --> Storage
    Storage --> Reporting
    
    style Source fill:#e1f5ff
    style Metrics fill:#fff9c4
    style Storage fill:#ffebee
    style Reporting fill:#e8f5e9
```

---

## Summary

This data flow documentation provides comprehensive Mermaid diagrams covering:

- ✅ End-to-end data flow across all layers
- ✅ Detailed Bronze, Silver, and Gold processing
- ✅ Task orchestration and scheduling
- ✅ Error handling and recovery
- ✅ Data quality framework
- ✅ AI-powered mapping flows
- ✅ State transitions and sequences

All diagrams are:
- Professional and publication-ready
- Renderable in GitHub/GitLab
- Exportable as high-quality images
- Easy to maintain and update

**Next**: See [SYSTEM_DESIGN_MERMAID.md](SYSTEM_DESIGN_MERMAID.md) for design patterns and decisions.
