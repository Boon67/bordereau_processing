# System Architecture Documentation

**Bordereau Processing Pipeline**  
**Version**: 2.1  
**Date**: January 22, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [High-Level Architecture](#high-level-architecture)
3. [Component Architecture](#component-architecture)
4. [Data Layer Architecture](#data-layer-architecture)
5. [Deployment Architecture](#deployment-architecture)
6. [Security Architecture](#security-architecture)
7. [Integration Architecture](#integration-architecture)
8. [Performance Architecture](#performance-architecture)
9. [Technology Stack](#technology-stack)

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

```mermaid
graph TB
    subgraph Presentation["PRESENTATION LAYER"]
        UI[React Frontend<br/>TypeScript + Ant Design<br/>Port 3000]
        
        subgraph UIPages["UI Pages"]
            Bronze[Bronze Pages]
            Silver[Silver Pages]
            Gold[Gold Pages]
            Admin[Admin Pages]
        end
    end
    
    subgraph Application["APPLICATION LAYER"]
        API[FastAPI Backend<br/>Python 3.10+<br/>Port 8000]
        
        subgraph APIServices["API Services"]
            BronzeAPI[Bronze API]
            SilverAPI[Silver API]
            GoldAPI[Gold API]
            TPAAPI[TPA API]
        end
        
        Connector[Snowflake Connector<br/>Connection Pooling<br/>Query Execution]
    end
    
    subgraph Data["DATA LAYER - SNOWFLAKE"]
        subgraph Bronze["BRONZE LAYER"]
            BronzeData[Raw Data<br/>Files & Stages<br/>8 Tables]
        end
        
        subgraph Silver["SILVER LAYER"]
            SilverData[Cleaned Data<br/>Hybrid Tables<br/>12 Tables]
        end
        
        subgraph Gold["GOLD LAYER"]
            GoldData[Analytics<br/>Clustered Tables<br/>12 Tables]
        end
    end
    
    UI -->|HTTPS/REST| API
    API -->|Snowflake Protocol| Connector
    Connector -->|SQL| Bronze
    Bronze -->|Tasks| Silver
    Silver -->|Tasks| Gold
    
    style Presentation fill:#e1f5ff
    style Application fill:#fff4e1
    style Data fill:#e8f5e9
    style Bronze fill:#ffebee
    style Silver fill:#e3f2fd
    style Gold fill:#fff9c4
```

### Architecture Layers

1. **Presentation Layer**
   - React-based SPA with TypeScript
   - Ant Design component library
   - Responsive, modern UI
   - Real-time status updates

2. **Application Layer**
   - FastAPI RESTful backend
   - Async request handling
   - Connection pooling
   - Business logic orchestration

3. **Data Layer**
   - Snowflake database
   - Medallion architecture
   - Hybrid and clustered tables
   - Automated task orchestration

---

## Component Architecture

### Frontend Architecture

```mermaid
graph LR
    subgraph Frontend["React Frontend"]
        subgraph Components["Components"]
            Upload[Upload Component]
            Status[Status Component]
            Data[Data Grid Component]
            Mapping[Mapping Component]
        end
        
        subgraph Services["Services"]
            API[API Service]
            Auth[Auth Service]
            State[State Management]
        end
        
        subgraph Pages["Pages"]
            BronzePage[Bronze Pages]
            SilverPage[Silver Pages]
            GoldPage[Gold Pages]
        end
    end
    
    subgraph External["External"]
        Backend[Backend API]
    end
    
    Components --> Services
    Services --> Pages
    API --> Backend
    
    style Frontend fill:#e1f5ff
    style Components fill:#bbdefb
    style Services fill:#90caf9
    style Pages fill:#64b5f6
```

### Backend Architecture

```mermaid
graph TB
    subgraph Backend["FastAPI Backend"]
        subgraph Routes["API Routes"]
            BronzeRoute[/api/bronze/*]
            SilverRoute[/api/silver/*]
            GoldRoute[/api/gold/*]
            TPARoute[/api/tpa/*]
        end
        
        subgraph Services["Business Services"]
            FileService[File Service]
            TransformService[Transform Service]
            MappingService[Mapping Service]
            TPAService[TPA Service]
        end
        
        subgraph Data["Data Access"]
            SnowRepo[Snowflake Repository]
            ConnPool[Connection Pool]
        end
        
        subgraph AI["AI Services"]
            MLService[ML Mapping Service]
            LLMService[LLM Service<br/>Cortex AI]
        end
    end
    
    Routes --> Services
    Services --> Data
    Services --> AI
    Data --> ConnPool
    
    style Backend fill:#fff4e1
    style Routes fill:#ffe0b2
    style Services fill:#ffcc80
    style Data fill:#ffb74d
    style AI fill:#ff9800
```

### Database Architecture

```mermaid
graph TB
    subgraph Database["SNOWFLAKE DATABASE"]
        subgraph Bronze["BRONZE LAYER"]
            BronzeStages[Stages<br/>@SRC, @COMPLETED<br/>@ERROR, @ARCHIVE]
            BronzeTables[Tables<br/>raw_claims_data<br/>file_processing_log<br/>tpa_config]
            BronzeProcs[Procedures<br/>register_tpa<br/>upload_file<br/>process_file]
            BronzeTasks[Tasks<br/>Auto-process<br/>Cleanup]
        end
        
        subgraph Silver["SILVER LAYER"]
            SilverHybrid[Hybrid Tables<br/>target_schemas<br/>field_mappings<br/>transformation_rules<br/>+ 8 indexes]
            SilverStandard[Standard Tables<br/>processing_log<br/>quality_metrics<br/>quarantine]
            SilverProcs[Procedures<br/>create_table<br/>map_fields<br/>transform<br/>suggest_ml<br/>suggest_llm]
            SilverTasks[Tasks<br/>Auto-transform<br/>Quality checks]
        end
        
        subgraph Gold["GOLD LAYER"]
            GoldHybrid[Hybrid Tables<br/>target_schemas<br/>transformation_rules<br/>quality_rules<br/>+ 14 indexes]
            GoldClustered[Clustered Tables<br/>CLAIMS_ANALYTICS<br/>MEMBER_360<br/>PROVIDER_PERF<br/>FINANCIAL_SUMMARY]
            GoldRules[Metadata<br/>11 Transform Rules<br/>5 Quality Rules<br/>5 Business Metrics]
        end
    end
    
    Bronze -->|Automated Tasks| Silver
    Silver -->|Automated Tasks| Gold
    
    style Database fill:#e8f5e9
    style Bronze fill:#ffcdd2
    style Silver fill:#bbdefb
    style Gold fill:#fff9c4
```

---

## Data Layer Architecture

### Table Types and Optimization

```mermaid
graph TB
    subgraph Tables["Table Types"]
        subgraph Hybrid["Hybrid Tables<br/>10 tables, 22 indexes"]
            HybridMeta[Metadata Tables<br/>Fast Point Lookups<br/>10-100x faster]
            HybridFeatures[Features:<br/>• Inline Indexes<br/>• UPDATE/DELETE<br/>• Row-level locking<br/>• Small datasets]
        end
        
        subgraph Standard["Standard Tables<br/>22 tables"]
            StandardAnalytics[Analytics Tables<br/>Large Scans<br/>Batch Processing]
            StandardFeatures[Features:<br/>• Clustering Keys<br/>• Micro-partitions<br/>• Columnar storage<br/>• Large datasets]
        end
        
        subgraph Clustered["Clustered Tables<br/>4 tables"]
            ClusteredAnalytics[Gold Analytics<br/>Time-series Queries<br/>2-10x faster]
            ClusteredFeatures[Features:<br/>• Automatic pruning<br/>• Optimized scans<br/>• Multi-dimensional<br/>• Query acceleration]
        end
    end
    
    subgraph Performance["Performance Optimization"]
        Indexes[22 Indexes<br/>on Hybrid Tables]
        Clustering[4 Clustering Keys<br/>on Analytics Tables]
        Partitioning[Automatic<br/>Micro-partitioning]
    end
    
    Hybrid --> Indexes
    Clustered --> Clustering
    Standard --> Partitioning
    
    style Hybrid fill:#e1f5ff
    style Standard fill:#f3e5f5
    style Clustered fill:#fff9c4
    style Performance fill:#e8f5e9
```

### Index Strategy

```mermaid
graph LR
    subgraph Silver["Silver Layer Indexes"]
        S1[target_schemas<br/>• idx_tpa<br/>• idx_table]
        S2[field_mappings<br/>• idx_tpa<br/>• idx_source]
        S3[transformation_rules<br/>• idx_tpa<br/>• idx_type<br/>• idx_active]
        S4[llm_prompt_templates<br/>• idx_active]
    end
    
    subgraph Gold["Gold Layer Indexes"]
        G1[target_schemas<br/>• idx_tpa<br/>• idx_active]
        G2[target_fields<br/>• idx_schema]
        G3[transformation_rules<br/>• idx_tpa<br/>• idx_type<br/>• idx_active]
        G4[field_mappings<br/>• idx_tpa<br/>• idx_source<br/>• idx_target]
        G5[quality_rules<br/>• idx_tpa<br/>• idx_table<br/>• idx_active]
        G6[business_metrics<br/>• idx_tpa<br/>• idx_category]
    end
    
    style Silver fill:#bbdefb
    style Gold fill:#fff9c4
```

### Clustering Strategy

```mermaid
graph TB
    subgraph Clustering["Clustering Key Strategy"]
        subgraph Claims["CLAIMS_ANALYTICS"]
            C1[CLUSTER BY:<br/>tpa, claim_year,<br/>claim_month, claim_type]
            C1Use[Use Case:<br/>Time-series analysis<br/>Provider trends<br/>Type breakdown]
        end
        
        subgraph Member["MEMBER_360"]
            C2[CLUSTER BY:<br/>tpa, member_id]
            C2Use[Use Case:<br/>Member lookups<br/>History queries<br/>Risk analysis]
        end
        
        subgraph Provider["PROVIDER_PERFORMANCE"]
            C3[CLUSTER BY:<br/>tpa, provider_id,<br/>measurement_period]
            C3Use[Use Case:<br/>Provider analysis<br/>Performance trends<br/>Network optimization]
        end
        
        subgraph Financial["FINANCIAL_SUMMARY"]
            C4[CLUSTER BY:<br/>tpa, fiscal_year,<br/>fiscal_month]
            C4Use[Use Case:<br/>Financial reporting<br/>Budget analysis<br/>Trend forecasting]
        end
    end
    
    style Claims fill:#ffcdd2
    style Member fill:#c5e1a5
    style Provider fill:#b3e5fc
    style Financial fill:#fff9c4
```

---

## Deployment Architecture

### Local Development

```mermaid
graph TB
    subgraph Local["Local Development"]
        Dev[Developer Machine]
        
        subgraph Services["Services"]
            FE[Frontend<br/>npm run dev<br/>Port 3000]
            BE[Backend<br/>uvicorn<br/>Port 8000]
        end
        
        subgraph Tools["Development Tools"]
            VSCode[VS Code / Cursor]
            Git[Git]
            Docker[Docker<br/>Optional]
        end
    end
    
    subgraph Cloud["Snowflake Cloud"]
        SF[Snowflake Database<br/>BORDEREAU_PROCESSING_PIPELINE]
    end
    
    Dev --> Services
    Dev --> Tools
    Services -->|HTTPS| SF
    
    style Local fill:#e1f5ff
    style Cloud fill:#e8f5e9
```

### Docker Deployment

```mermaid
graph TB
    subgraph Docker["Docker Compose"]
        subgraph Containers["Containers"]
            FEContainer[Frontend Container<br/>Node + Nginx<br/>Port 3000]
            BEContainer[Backend Container<br/>Python + FastAPI<br/>Port 8000]
        end
        
        subgraph Network["Docker Network"]
            Bridge[Bridge Network<br/>bordereau-network]
        end
        
        subgraph Volumes["Volumes"]
            Logs[Logs Volume]
            Data[Data Volume]
        end
    end
    
    subgraph External["External"]
        SF[Snowflake]
        User[Users]
    end
    
    Containers --> Bridge
    Containers --> Volumes
    User -->|Port 3000| FEContainer
    BEContainer -->|HTTPS| SF
    
    style Docker fill:#e1f5ff
    style External fill:#e8f5e9
```

### Snowpark Container Services (SPCS) - Current Deployment

```mermaid
graph TB
    subgraph SPCS["Snowpark Container Services"]
        subgraph ComputePool["Compute Pool: BORDEREAU_COMPUTE_POOL"]
            Pool[CPU_X64_XS<br/>Min: 1 node, Max: 3 nodes<br/>Auto-suspend: 10 min]
        end
        
        subgraph ImageRepo["Image Repository: BORDEREAU_REPOSITORY"]
            Repo[Registry: sfsenorthamerica-tboon-aws2<br/>Backend Image: bordereau_backend:latest<br/>Frontend Image: bordereau_frontend:latest]
        end
        
        subgraph Service["Unified Service: BORDEREAU_APP"]
            FEPod[Frontend Container<br/>nginx:alpine<br/>Port 80 PUBLIC<br/>Proxies /api/* to backend]
            BEPod[Backend Container<br/>python:3.11-slim<br/>Port 8000 INTERNAL<br/>FastAPI + Snowflake Connector]
        end
        
        subgraph Network["Networking"]
            Ingress[Public Endpoint<br/>HTTPS<br/>j6cmn2pb-*.snowflakecomputing.app]
            Internal[Internal Network<br/>backend:8000]
        end
    end
    
    subgraph Database["Database: BORDEREAU_PROCESSING_PIPELINE"]
        Bronze[BRONZE Schema<br/>8 Tables + Stages]
        Silver[SILVER Schema<br/>12 Hybrid Tables]
        Gold[GOLD Schema<br/>12 Tables + 4 Analytics]
    end
    
    Pool --> Service
    Repo --> Service
    Service --> Network
    Ingress --> FEPod
    FEPod -->|Internal Proxy| BEPod
    BEPod -->|Direct SQL| Database
    
    style SPCS fill:#fff4e1
    style Database fill:#e8f5e9
    style Service fill:#e3f2fd
```

**Key Features**:
- ✅ **Unified Service**: Single service with both frontend and backend
- ✅ **Secure**: Backend is internal-only, not publicly accessible
- ✅ **Efficient**: Frontend proxies API calls to backend
- ✅ **Scalable**: Min 1, Max 3 instances with auto-scaling
- ✅ **Cost-Effective**: Auto-suspend after 10 minutes of inactivity

---

## Security Architecture

### Authentication & Authorization

```mermaid
graph TB
    subgraph Auth["Authentication Flow"]
        User[User]
        UI[Frontend]
        API[Backend API]
        SF[Snowflake]
        
        User -->|1. Login| UI
        UI -->|2. API Request| API
        API -->|3. Validate| API
        API -->|4. Connect| SF
        SF -->|5. Verify Role| SF
        SF -->|6. Return Data| API
        API -->|7. Response| UI
        UI -->|8. Display| User
    end
    
    subgraph Roles["Role-Based Access Control"]
        Admin[ADMIN Role<br/>Full Access]
        ReadWrite[READWRITE Role<br/>CRUD Operations]
        ReadOnly[READONLY Role<br/>SELECT Only]
    end
    
    subgraph Security["Security Layers"]
        Network[Network Security<br/>HTTPS/TLS]
        App[Application Security<br/>Auth Tokens]
        Data[Data Security<br/>Encryption at Rest]
        Row[Row-Level Security<br/>TPA Isolation]
    end
    
    style Auth fill:#ffebee
    style Roles fill:#fff3e0
    style Security fill:#e8f5e9
```

### Multi-Tenancy Architecture

```mermaid
graph TB
    subgraph MultiTenant["Multi-Tenant Isolation"]
        subgraph TPA1["TPA: Provider A"]
            A_Bronze[Bronze Data<br/>TPA = PROVIDER_A]
            A_Silver[Silver Tables<br/>CLAIMS_PROVIDER_A]
            A_Gold[Gold Analytics<br/>Filtered by TPA]
        end
        
        subgraph TPA2["TPA: Provider B"]
            B_Bronze[Bronze Data<br/>TPA = PROVIDER_B]
            B_Silver[Silver Tables<br/>CLAIMS_PROVIDER_B]
            B_Gold[Gold Analytics<br/>Filtered by TPA]
        end
        
        subgraph Shared["Shared Resources"]
            Metadata[Metadata Tables<br/>TPA Column]
            Procedures[Stored Procedures<br/>TPA Parameter]
            Tasks[Tasks<br/>TPA Filtering]
        end
    end
    
    A_Bronze --> A_Silver --> A_Gold
    B_Bronze --> B_Silver --> B_Gold
    Shared -.->|Isolates| TPA1
    Shared -.->|Isolates| TPA2
    
    style TPA1 fill:#e3f2fd
    style TPA2 fill:#f3e5f5
    style Shared fill:#fff9c4
```

---

## Integration Architecture

### External Integrations

```mermaid
graph LR
    subgraph External["External Systems"]
        SFTP[SFTP/FTP Servers]
        S3[AWS S3]
        Azure[Azure Blob]
        GCS[Google Cloud Storage]
        API_Ext[External APIs]
    end
    
    subgraph Pipeline["Bordereau Pipeline"]
        Ingestion[Data Ingestion]
        Processing[Processing Engine]
        Export[Data Export]
    end
    
    subgraph Downstream["Downstream Systems"]
        BI[BI Tools<br/>Tableau, PowerBI]
        DW[Data Warehouse]
        ML[ML Platforms]
    end
    
    External -->|Pull/Push| Ingestion
    Ingestion --> Processing
    Processing --> Export
    Export --> Downstream
    
    style External fill:#e1f5ff
    style Pipeline fill:#fff4e1
    style Downstream fill:#e8f5e9
```

### API Integration

```mermaid
sequenceDiagram
    participant Client
    participant Frontend
    participant Backend
    participant Snowflake
    
    Client->>Frontend: 1. Upload File
    Frontend->>Backend: 2. POST /api/bronze/upload
    Backend->>Snowflake: 3. PUT file to @BRONZE_STAGE
    Snowflake-->>Backend: 4. File ID
    Backend->>Snowflake: 5. INSERT into raw_claims_data
    Snowflake-->>Backend: 6. Success
    Backend-->>Frontend: 7. {file_id, status}
    Frontend-->>Client: 8. Upload Complete
    
    Note over Snowflake: Task triggers automatically
    Snowflake->>Snowflake: 9. Process file (Task)
    
    Client->>Frontend: 10. Check Status
    Frontend->>Backend: 11. GET /api/bronze/status/{file_id}
    Backend->>Snowflake: 12. SELECT from file_processing_log
    Snowflake-->>Backend: 13. Status data
    Backend-->>Frontend: 14. {status, progress}
    Frontend-->>Client: 15. Display Status
```

---

## Performance Architecture

### Query Optimization

```mermaid
graph TB
    subgraph Optimization["Performance Optimization"]
        subgraph Indexes["Index Strategy"]
            I1[Hybrid Tables<br/>22 Inline Indexes<br/>10-100x faster lookups]
        end
        
        subgraph Clustering["Clustering Strategy"]
            C1[4 Clustered Tables<br/>Multi-dimensional<br/>2-10x faster scans]
        end
        
        subgraph Caching["Caching Strategy"]
            Cache1[Result Cache<br/>Snowflake Native]
            Cache2[Connection Pool<br/>Backend]
            Cache3[Query Cache<br/>Metadata]
        end
        
        subgraph Partitioning["Partitioning"]
            P1[Micro-partitions<br/>Automatic]
            P2[Partition Pruning<br/>Cluster Keys]
        end
    end
    
    subgraph Results["Performance Results"]
        R1[Metadata Queries:<br/>< 50ms]
        R2[Analytics Queries:<br/>< 2 seconds]
        R3[API Response:<br/>< 200ms]
    end
    
    Indexes --> Results
    Clustering --> Results
    Caching --> Results
    Partitioning --> Results
    
    style Optimization fill:#e8f5e9
    style Results fill:#c8e6c9
```

### Scalability Architecture

```mermaid
graph TB
    subgraph Scalability["Scalability Strategy"]
        subgraph Horizontal["Horizontal Scaling"]
            H1[Snowflake Compute<br/>Auto-scaling]
            H2[Multiple Warehouses<br/>Workload Isolation]
            H3[SPCS Pods<br/>Container Scaling]
        end
        
        subgraph Vertical["Vertical Scaling"]
            V1[Warehouse Size<br/>XS to 6XL]
            V2[Compute Pool<br/>CPU/Memory]
        end
        
        subgraph Data["Data Scaling"]
            D1[Unlimited Storage<br/>Snowflake]
            D2[Automatic Clustering<br/>Maintenance]
            D3[Partition Pruning<br/>Query Optimization]
        end
    end
    
    style Horizontal fill:#e1f5ff
    style Vertical fill:#f3e5f5
    style Data fill:#e8f5e9
```

---

## Technology Stack

### Complete Technology Stack

```mermaid
graph TB
    subgraph Stack["Technology Stack"]
        subgraph Frontend["Frontend"]
            F1[React 18]
            F2[TypeScript 5]
            F3[Ant Design 5]
            F4[Vite 5]
            F5[Axios]
        end
        
        subgraph Backend["Backend"]
            B1[Python 3.10+]
            B2[FastAPI 0.104+]
            B3[Uvicorn]
            B4[Pydantic]
            B5[Snowflake Connector]
        end
        
        subgraph Database["Database"]
            D1[Snowflake]
            D2[Hybrid Tables]
            D3[Clustered Tables]
            D4[Snowpark]
            D5[Cortex AI]
        end
        
        subgraph DevOps["DevOps"]
            O1[Docker]
            O2[Docker Compose]
            O3[Snowflake CLI]
            O4[Git]
            O5[Bash Scripts]
        end
        
        subgraph AI["AI/ML"]
            A1[Snowflake Cortex]
            A2[LLM Integration]
            A3[ML Models]
        end
    end
    
    style Frontend fill:#e1f5ff
    style Backend fill:#fff4e1
    style Database fill:#e8f5e9
    style DevOps fill:#f3e5f5
    style AI fill:#fff9c4
```

---

## Diagram Rendering

### How to View These Diagrams

1. **GitHub**: Mermaid diagrams render automatically in GitHub markdown
2. **VS Code**: Install "Markdown Preview Mermaid Support" extension
3. **Cursor**: Mermaid diagrams render in preview mode
4. **Export as Images**: Use [Mermaid Live Editor](https://mermaid.live/) to export as PNG/SVG
5. **Documentation Sites**: Most modern documentation platforms support Mermaid

### Export to Images

To export diagrams as images:

```bash
# Using Mermaid CLI
npm install -g @mermaid-js/mermaid-cli
mmdc -i docs/SYSTEM_ARCHITECTURE_MERMAID.md -o docs/images/architecture.png

# Or use Mermaid Live Editor
# 1. Copy diagram code
# 2. Paste into https://mermaid.live/
# 3. Click "Download PNG" or "Download SVG"
```

---

## Summary

This architecture documentation provides a comprehensive view of the Bordereau Processing Pipeline using professional Mermaid diagrams that can be:

- ✅ Rendered in GitHub/GitLab
- ✅ Viewed in modern IDEs
- ✅ Exported as high-quality images
- ✅ Embedded in documentation sites
- ✅ Easily maintained and updated

The diagrams cover all aspects of the system:
- High-level architecture
- Component architecture
- Data layer design
- Deployment options
- Security model
- Integration patterns
- Performance optimization
- Technology stack

**Next**: See [DATA_FLOW_MERMAID.md](DATA_FLOW_MERMAID.md) for detailed data flow diagrams.
