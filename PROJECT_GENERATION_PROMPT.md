# Bordereau Processing Pipeline - Complete Project Generation Prompt

**Version**: 2.0  
**Date**: January 19, 2026  
**Purpose**: Complete specification for regenerating the entire Bordereau Processing Pipeline

---

## 📋 Project Overview

Create a **modern healthcare claims data processing pipeline** called "Bordereau Processing Pipeline" with the following characteristics:

### Core Technologies
- **Backend**: FastAPI (Python 3.10+) with Snowflake Connector
- **Frontend**: React 18 + TypeScript + Vite + Ant Design
- **Database**: Snowflake (Bronze, Silver, Gold layers)
- **Deployment**: Docker, Snowpark Container Services (SPCS)
- **Orchestration**: Snowflake Tasks
- **Authentication**: Snow CLI, PAT tokens, Keypair authentication

### Architecture Pattern
Multi-tenant healthcare claims processing with **Bronze → Silver → Gold** data architecture:
- **Bronze Layer**: Raw data ingestion with TPA isolation
- **Silver Layer**: Cleaned, transformed data with ML/LLM-powered field mapping
- **Gold Layer**: Analytics-ready aggregated data with business metrics

---

## 🏗️ Complete Directory Structure

```
bordereau/
├── README.md                              # Main project documentation
├── QUICK_START.md                         # 10-minute quick start guide
├── MIGRATION_GUIDE.md                     # Migration instructions
├── DOCUMENTATION_STRUCTURE.md             # Documentation organization
├── DOCUMENTATION_CLEANUP_SUMMARY.md       # Documentation cleanup notes
├── GOLD_LAYER_SUMMARY.md                  # Gold layer implementation summary
├── HYBRID_TABLES_IMPLEMENTATION.md        # Hybrid tables guide
├── .gitignore                             # Git ignore patterns
├── docker-compose.yml                     # Local Docker orchestration
├── start.sh                               # Main startup script (backend + frontend)
│
├── backend/                               # FastAPI Backend
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                        # FastAPI application entry
│   │   ├── config.py                      # Configuration management
│   │   ├── api/                           # API endpoints
│   │   │   ├── __init__.py
│   │   │   ├── bronze.py                  # Bronze layer endpoints
│   │   │   ├── silver.py                  # Silver layer endpoints
│   │   │   └── tpa.py                     # TPA management endpoints
│   │   └── services/
│   │       ├── __init__.py
│   │       └── snowflake_service.py       # Snowflake connection service
│   ├── requirements.txt                   # Python dependencies
│   ├── config.example.env                 # Environment config example
│   ├── config.example.json                # JSON config example
│   ├── config.example.toml                # TOML config example
│   ├── start_server.sh                    # Backend startup script
│   └── README.md                          # Backend documentation
│
├── frontend/                              # React Frontend
│   ├── src/
│   │   ├── main.tsx                       # React entry point
│   │   ├── App.tsx                        # Main App component
│   │   ├── App.css                        # App styles
│   │   ├── index.css                      # Global styles
│   │   ├── pages/                         # Page components
│   │   │   ├── BronzeData.tsx             # Bronze data viewer
│   │   │   ├── BronzeStages.tsx           # Bronze stages manager
│   │   │   ├── BronzeStatus.tsx           # Bronze processing status
│   │   │   ├── BronzeTasks.tsx            # Bronze tasks monitor
│   │   │   ├── BronzeUpload.tsx           # File upload interface
│   │   │   ├── SilverData.tsx             # Silver data viewer
│   │   │   ├── SilverMappings.tsx         # Field mappings manager
│   │   │   ├── SilverSchemas.tsx          # Schema definitions
│   │   │   └── SilverTransform.tsx        # Transformation rules
│   │   ├── services/
│   │   │   └── api.ts                     # API client service
│   │   └── types/
│   │       └── index.ts                   # TypeScript type definitions
│   ├── index.html                         # HTML entry point
│   ├── package.json                       # Node dependencies
│   ├── package-lock.json                  # Locked dependencies
│   ├── tsconfig.json                      # TypeScript config
│   ├── tsconfig.node.json                 # Node TypeScript config
│   └── vite.config.ts                     # Vite bundler config
│
├── bronze/                                # Bronze Layer SQL
│   ├── 1_Setup_Database_Roles.sql         # Database and role setup
│   ├── 2_Bronze_Schema_Tables.sql         # Bronze schema and tables
│   ├── 3_Bronze_Setup_Logic.sql           # Bronze procedures
│   ├── 4_Bronze_Tasks.sql                 # Bronze automation tasks
│   ├── Fix_Task_Privileges.sql            # Task privilege fixes
│   ├── Reset.sql                          # Bronze reset script
│   ├── TPA_Management.sql                 # TPA management procedures
│   ├── README.md                          # Bronze documentation
│   └── TPA_UPLOAD_GUIDE.md                # TPA upload guide
│
├── silver/                                # Silver Layer SQL
│   ├── 1_Silver_Schema_Setup.sql          # Silver schema and metadata tables
│   ├── 2_Silver_Target_Schemas.sql        # Target schema definitions
│   ├── 3_Silver_Mapping_Procedures.sql    # Mapping procedures
│   ├── 4_Silver_Rules_Engine.sql          # Rules engine
│   ├── 5_Silver_Transformation_Logic.sql  # Transformation logic
│   ├── 6_Silver_Tasks.sql                 # Silver automation tasks
│   ├── 7_Load_Sample_Schemas.sql          # Load sample provider schemas
│   └── README.md                          # Silver documentation
│
├── gold/                                  # Gold Layer SQL
│   ├── 1_Gold_Schema_Setup.sql            # Gold schema and metadata tables
│   ├── 2_Gold_Target_Schemas.sql          # Gold analytics tables
│   ├── 3_Gold_Transformation_Rules.sql    # Gold transformation rules
│   ├── 4_Gold_Transformation_Procedures.sql # Gold procedures
│   ├── 5_Gold_Tasks.sql                   # Gold automation tasks
│   ├── README.md                          # Gold documentation
│   └── HYBRID_TABLES_GUIDE.md             # Hybrid tables vs standard tables
│
├── definition/                            # Additional definitions
│   └── mapping_procedures.sql             # Legacy mapping procedures
│
├── deployment/                            # Deployment Scripts
│   ├── deploy.sh                          # Master deployment (Bronze+Silver+Gold)
│   ├── deploy_bronze.sh                   # Bronze deployment
│   ├── deploy_silver.sh                   # Silver deployment
│   ├── deploy_gold.sh                     # Gold deployment
│   ├── deploy_container.sh                # SPCS container deployment
│   ├── deploy_full_stack.sh               # Full stack deployment
│   ├── deploy_frontend_spcs.sh            # Frontend SPCS deployment
│   ├── deploy_snowpark_container.sh       # Snowpark container deployment
│   ├── deploy_unified_service.sh          # Unified service deployment
│   ├── undeploy.sh                        # Cleanup script
│   ├── manage_services.sh                 # Service management
│   ├── manage_frontend_service.sh         # Frontend service management
│   ├── manage_snowpark_service.sh         # Snowpark service management
│   ├── push_image_to_snowflake.sh         # Image push script
│   ├── setup_keypair_auth.sh              # Keypair authentication setup
│   ├── configure_keypair_auth.sql         # Keypair SQL configuration
│   ├── check_snow_connection.sh           # Connection test script
│   ├── default.config                     # Default configuration
│   ├── custom.config.example              # Custom config example
│   ├── README.md                          # Deployment documentation
│   ├── QUICK_REFERENCE.md                 # Quick reference guide
│   ├── AUTHENTICATION_SETUP.md            # Authentication guide
│   ├── DEPLOYMENT_SNOW_CLI.md             # Snow CLI deployment guide
│   ├── DEPLOYMENT_SUMMARY.md              # Deployment summary
│   ├── DEPLOYMENT_SUCCESS.md              # Success verification
│   ├── SNOWPARK_CONTAINER_DEPLOYMENT.md   # SPCS deployment guide
│   ├── SNOWPARK_QUICK_START.md            # SPCS quick start
│   ├── CONSOLIDATION_SUMMARY.md           # Script consolidation notes
│   ├── TEST_RESULTS.md                    # Test results
│   ├── test_deploy_container.sh           # Container deployment test
│   └── legacy/                            # Legacy deployment methods
│       ├── README.md
│       └── FULL_STACK_SPCS_DEPLOYMENT.md
│
├── docker/                                # Docker Configuration
│   ├── Dockerfile.backend                 # Backend Docker image
│   ├── Dockerfile.frontend                # Frontend Docker image
│   ├── nginx.conf                         # Nginx configuration
│   └── snowpark-spec.yaml                 # Snowpark service spec
│
├── sample_data/                           # Sample Data
│   ├── claims_data/                       # Sample claims files
│   │   ├── provider_a/
│   │   │   └── dental-claims-20240301.csv
│   │   ├── provider_b/
│   │   │   └── medical-claims-20240115.csv
│   │   └── provider_e/
│   │       └── pharmacy-claims-20240201.csv
│   ├── config/                            # Configuration CSVs
│   │   ├── silver_field_mappings.csv
│   │   ├── silver_target_schemas.csv
│   │   ├── silver_transformation_rules.csv
│   │   ├── silver_target_schemas_samples.csv
│   │   └── silver_target_fields_samples.csv
│   └── README.md                          # Sample data documentation
│
├── docs/                                  # Additional Documentation
│   ├── README.md                          # Docs index
│   ├── USER_GUIDE.md                      # User guide
│   ├── DEPLOYMENT_AND_OPERATIONS.md       # Operations guide
│   ├── guides/
│   │   └── TPA_COMPLETE_GUIDE.md          # Complete TPA guide
│   └── testing/
│       └── TEST_PLAN_DEPLOYMENT_SCRIPTS.md # Test plan
│
└── tests/                                 # Test Scripts
    └── deployment/
        ├── README.md
        └── run_deploy_tests.sh
```

---

## 📊 Data Architecture

### Bronze Layer (Raw Data Ingestion)

**Purpose**: Multi-tenant raw data storage with TPA isolation

**Tables**:
1. **`raw_claims_data`** - Raw claims files (all TPAs)
   - Columns: `file_id`, `tpa`, `file_name`, `file_path`, `upload_timestamp`, `file_size`, `status`, `row_count`, `metadata`

2. **`file_processing_log`** - Processing history
   - Columns: `log_id`, `file_id`, `tpa`, `stage`, `status`, `records_processed`, `records_failed`, `start_time`, `end_time`, `error_message`

3. **`tpa_config`** - TPA configuration
   - Columns: `tpa_id`, `tpa_name`, `tpa_code`, `contact_email`, `file_format`, `delimiter`, `is_active`, `created_at`

**Stages**:
- `@BRONZE_STAGE` - Main file storage
- `@BRONZE_CONFIG` - Configuration files

**Procedures**:
- `register_tpa()` - Register new TPA
- `upload_file()` - Upload and register file
- `process_file()` - Process uploaded file
- `get_tpa_stats()` - Get TPA statistics

**Tasks**:
- `task_auto_process_files` - Auto-process new files (every 5 minutes)
- `task_cleanup_old_files` - Cleanup old files (daily)

### Silver Layer (Cleaned & Transformed Data)

**Purpose**: Standardized, cleaned data with dynamic schema per TPA

**Metadata Tables (Hybrid Tables with Indexes)**:

1. **`target_schemas`** (Hybrid Table)
   - Defines Silver table schemas per TPA
   - Columns: `schema_id`, `table_name`, `column_name`, `tpa`, `data_type`, `nullable`, `default_value`, `description`, `active`
   - Indexes: `idx_target_schemas_tpa (tpa)`, `idx_target_schemas_table (table_name)`

2. **`field_mappings`** (Hybrid Table)
   - Bronze → Silver field mappings
   - Columns: `mapping_id`, `source_field`, `source_table`, `target_table`, `target_column`, `tpa`, `mapping_method`, `transformation_logic`, `confidence_score`, `approved`
   - Indexes: `idx_field_mappings_tpa (tpa)`, `idx_field_mappings_target (target_table)`
   - Mapping Methods: MANUAL, ML_AUTO, LLM_CORTEX, SYSTEM

3. **`transformation_rules`** (Hybrid Table)
   - Data quality and business rules
   - Columns: `rule_id`, `tpa`, `rule_name`, `rule_type`, `target_table`, `target_column`, `rule_logic`, `error_action`, `priority`, `active`
   - Rule Types: DATA_QUALITY, BUSINESS_LOGIC, STANDARDIZATION, DEDUPLICATION, REFERENTIAL_INTEGRITY
   - Indexes: `idx_transformation_rules_tpa (tpa)`, `idx_transformation_rules_type (rule_type)`, `idx_transformation_rules_active (active)`

4. **`llm_prompt_templates`** (Hybrid Table)
   - LLM prompts for AI-powered mapping
   - Columns: `template_id`, `template_name`, `template_text`, `model_name`, `description`, `active`
   - Index: `idx_llm_templates_active (active)`

**Log Tables (Standard Tables)**:
5. **`silver_processing_log`** - Processing history
6. **`data_quality_metrics`** - Quality metrics
7. **`quarantine_records`** - Failed records
8. **`processing_watermarks`** - Incremental processing watermarks

**Dynamic Tables**:
- `CLAIMS_<TPA>` - Claims data per TPA (created dynamically)
- `MEMBERS_<TPA>` - Member data per TPA
- `PROVIDERS_<TPA>` - Provider data per TPA

**Procedures**:
- `create_silver_target_table()` - Create TPA-specific table
- `add_silver_target_field()` - Add field to schema
- `map_bronze_to_silver()` - Execute mappings
- `apply_transformation_rules()` - Apply rules
- `suggest_mappings_ml()` - ML-powered mapping suggestions
- `suggest_mappings_llm()` - LLM-powered mapping suggestions

**Tasks**:
- `task_auto_transform_bronze` - Auto-transform Bronze data (every 10 minutes)
- `task_quality_checks` - Run quality checks (hourly)

### Gold Layer (Analytics-Ready Data)

**Purpose**: Aggregated, analytics-ready data with business metrics

**Metadata Tables (Hybrid Tables with Indexes)**:

1. **`target_schemas`** (Hybrid Table)
   - Gold table definitions
   - Columns: `schema_id`, `table_name`, `tpa`, `description`, `business_owner`, `data_classification`, `refresh_frequency`, `retention_days`, `is_active`
   - Indexes: `idx_target_schemas_tpa (tpa)`, `idx_target_schemas_active (is_active)`

2. **`target_fields`** (Hybrid Table)
   - Gold field definitions
   - Columns: `field_id`, `schema_id`, `field_name`, `data_type`, `field_order`, `is_nullable`, `description`, `business_definition`, `calculation_logic`, `is_key`, `is_measure`, `is_dimension`
   - Index: `idx_target_fields_schema (schema_id)`

3. **`transformation_rules`** (Hybrid Table)
   - Business transformation rules
   - Columns: `rule_id`, `rule_name`, `rule_type`, `tpa`, `source_table`, `target_table`, `rule_logic`, `business_justification`, `priority`, `is_active`, `execution_order`
   - Rule Types: AGGREGATION, CALCULATION, DERIVATION, QUALITY_CHECK
   - Indexes: `idx_trans_rules_tpa (tpa)`, `idx_trans_rules_type (rule_type)`, `idx_trans_rules_active (is_active)`

4. **`field_mappings`** (Hybrid Table)
   - Silver → Gold mappings
   - Columns: `mapping_id`, `source_schema`, `source_table`, `source_field`, `target_table`, `target_field`, `tpa`, `transformation_logic`, `aggregation_function`, `group_by_fields`, `filter_condition`, `is_active`
   - Aggregation Functions: SUM, AVG, COUNT, MIN, MAX, FIRST, LAST
   - Indexes: `idx_field_mappings_tpa (tpa)`, `idx_field_mappings_source (source_table)`, `idx_field_mappings_target (target_table)`

5. **`quality_rules`** (Hybrid Table)
   - Data quality checks
   - Columns: `quality_rule_id`, `rule_name`, `rule_type`, `table_name`, `tpa`, `field_name`, `check_logic`, `threshold_value`, `threshold_operator`, `severity`, `action_on_failure`, `is_active`
   - Rule Types: COMPLETENESS, ACCURACY, CONSISTENCY, VALIDITY, TIMELINESS
   - Indexes: `idx_quality_rules_tpa (tpa)`, `idx_quality_rules_table (table_name)`, `idx_quality_rules_active (is_active)`

6. **`business_metrics`** (Hybrid Table)
   - KPI definitions
   - Columns: `metric_id`, `metric_name`, `metric_category`, `tpa`, `calculation_logic`, `source_tables`, `refresh_frequency`, `metric_owner`, `description`, `is_active`
   - Metric Categories: FINANCIAL, OPERATIONAL, CLINICAL, MEMBER
   - Indexes: `idx_business_metrics_tpa (tpa)`, `idx_business_metrics_category (metric_category)`

**Log Tables (Standard Tables)**:
7. **`processing_log`** - Gold processing history
8. **`quality_check_results`** - Quality check results

**Analytics Tables (Standard Tables with Clustering)**:

1. **`CLAIMS_ANALYTICS_ALL`**
   - Aggregated claims metrics across all TPAs
   - Fields: `claim_analytics_id`, `tpa`, `claim_year`, `claim_month`, `claim_type`, `total_claims`, `total_paid_amount`, `avg_claim_amount`, `unique_members`, `unique_providers`, etc.
   - **Clustering**: `CLUSTER BY (tpa, claim_year, claim_month, claim_type)`

2. **`MEMBER_360_ALL`**
   - Comprehensive member view
   - Fields: `member_360_id`, `tpa`, `member_id`, `member_name`, `total_claims`, `total_paid`, `first_claim_date`, `last_claim_date`, `risk_score`, `chronic_conditions`, etc.
   - **Clustering**: `CLUSTER BY (tpa, member_id)`

3. **`PROVIDER_PERFORMANCE_ALL`**
   - Provider performance metrics
   - Fields: `provider_performance_id`, `tpa`, `provider_id`, `provider_name`, `measurement_period`, `total_claims`, `total_paid`, `avg_claim_amount`, `quality_score`, etc.
   - **Clustering**: `CLUSTER BY (tpa, provider_id, measurement_period)`

4. **`FINANCIAL_SUMMARY_ALL`**
   - Financial analytics
   - Fields: `financial_summary_id`, `tpa`, `fiscal_year`, `fiscal_month`, `total_revenue`, `total_paid_claims`, `admin_costs`, `profit_margin`, `loss_ratio`, etc.
   - **Clustering**: `CLUSTER BY (tpa, fiscal_year, fiscal_month)`

**Procedures**:
- `transform_claims_analytics()` - Transform claims to analytics
- `transform_member_360()` - Create member 360 view
- `execute_quality_checks()` - Run quality checks
- `run_gold_transformations()` - Master transformation orchestrator

**Tasks**:
- `task_refresh_claims_analytics` - Refresh claims analytics (daily at 2 AM)
- `task_refresh_member_360` - Refresh member 360 (daily at 3 AM)
- `task_quality_checks` - Run quality checks (daily at 4 AM)
- `task_master_gold_refresh` - Master orchestrator (daily at 1 AM)

---

## 🔧 Backend Implementation (FastAPI)

### Main Application (`backend/app/main.py`)

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import bronze, silver, tpa
from app.config import settings

app = FastAPI(
    title="Bordereau Processing Pipeline API",
    description="Healthcare claims data processing pipeline",
    version="2.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(bronze.router, prefix="/api/bronze", tags=["Bronze"])
app.include_router(silver.router, prefix="/api/silver", tags=["Silver"])
app.include_router(tpa.router, prefix="/api/tpa", tags=["TPA"])

@app.get("/api/health")
async def health_check():
    return {"status": "healthy", "version": "2.0.0"}
```

### Configuration (`backend/app/config.py`)

Support multiple configuration sources:
1. Environment variables
2. JSON file (`config.json`)
3. TOML file (`config.toml`)
4. ENV file (`.env`)

Required settings:
- `SNOWFLAKE_ACCOUNT`
- `SNOWFLAKE_USER`
- `SNOWFLAKE_PASSWORD` or `SNOWFLAKE_PRIVATE_KEY_PATH`
- `SNOWFLAKE_ROLE`
- `SNOWFLAKE_WAREHOUSE`
- `DATABASE_NAME`
- `BRONZE_SCHEMA_NAME`
- `SILVER_SCHEMA_NAME`
- `GOLD_SCHEMA_NAME`

### Snowflake Service (`backend/app/services/snowflake_service.py`)

Implement connection pooling and query execution:
- `get_connection()` - Get Snowflake connection
- `execute_query()` - Execute SQL query
- `fetch_all()` - Fetch all results
- `fetch_one()` - Fetch single result
- `upload_file()` - Upload file to stage
- `call_procedure()` - Call stored procedure

### API Endpoints

**Bronze Layer (`backend/app/api/bronze.py`)**:
- `GET /api/bronze/files` - List uploaded files
- `POST /api/bronze/upload` - Upload file
- `GET /api/bronze/status/{file_id}` - Get file status
- `GET /api/bronze/stats` - Get Bronze statistics
- `GET /api/bronze/stages` - List stages
- `GET /api/bronze/tasks` - List tasks

**Silver Layer (`backend/app/api/silver.py`)**:
- `GET /api/silver/schemas` - List target schemas
- `POST /api/silver/schemas` - Create target schema
- `GET /api/silver/mappings` - List field mappings
- `POST /api/silver/mappings` - Create mapping
- `GET /api/silver/rules` - List transformation rules
- `POST /api/silver/rules` - Create rule
- `POST /api/silver/transform` - Execute transformation
- `POST /api/silver/suggest-mappings` - AI-powered mapping suggestions

**TPA Management (`backend/app/api/tpa.py`)**:
- `GET /api/tpa/list` - List all TPAs
- `POST /api/tpa/register` - Register new TPA
- `GET /api/tpa/{tpa_id}/stats` - Get TPA statistics
- `PUT /api/tpa/{tpa_id}` - Update TPA configuration

### Dependencies (`backend/requirements.txt`)

```
fastapi==0.104.1
uvicorn[standard]==0.24.0
snowflake-connector-python==3.5.0
python-multipart==0.0.6
pydantic==2.5.0
pydantic-settings==2.1.0
python-dotenv==1.0.0
tomli==2.0.1
cryptography==41.0.7
```

---

## 🎨 Frontend Implementation (React + TypeScript)

### Main App (`frontend/src/App.tsx`)

Create a tabbed interface with Ant Design:
- **Bronze Layer Tabs**: Upload, Status, Data, Stages, Tasks
- **Silver Layer Tabs**: Schemas, Mappings, Rules, Transform, Data
- **Gold Layer Tabs**: Analytics, Metrics, Quality

### API Service (`frontend/src/services/api.ts`)

Axios-based API client with:
- Base URL configuration
- Request/response interceptors
- Error handling
- Type-safe methods for all endpoints

### Page Components

**Bronze Pages**:
1. `BronzeUpload.tsx` - File upload with TPA selection, drag-and-drop
2. `BronzeStatus.tsx` - Processing status table with real-time updates
3. `BronzeData.tsx` - Raw data viewer with pagination
4. `BronzeStages.tsx` - Stage file browser
5. `BronzeTasks.tsx` - Task monitoring with execution history

**Silver Pages**:
1. `SilverSchemas.tsx` - Schema definition manager (CRUD)
2. `SilverMappings.tsx` - Field mapping interface with AI suggestions
3. `SilverTransform.tsx` - Transformation rules manager
4. `SilverData.tsx` - Transformed data viewer

### UI Components

Use Ant Design components:
- `Table` - Data tables with sorting, filtering, pagination
- `Form` - Forms with validation
- `Upload` - File upload with drag-and-drop
- `Tabs` - Navigation tabs
- `Card` - Content cards
- `Button` - Action buttons
- `Select` - Dropdowns
- `Input` - Text inputs
- `Modal` - Dialogs
- `Notification` - Toast notifications
- `Spin` - Loading indicators

### Dependencies (`frontend/package.json`)

```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "antd": "^5.11.5",
    "axios": "^1.6.2",
    "@ant-design/icons": "^5.2.6"
  },
  "devDependencies": {
    "@types/react": "^18.2.43",
    "@types/react-dom": "^18.2.17",
    "@vitejs/plugin-react": "^4.2.1",
    "typescript": "^5.3.3",
    "vite": "^5.0.8"
  }
}
```

---

## 🐳 Docker Configuration

### Backend Dockerfile (`docker/Dockerfile.backend`)

Multi-stage build:
1. Base: Python 3.10-slim
2. Install dependencies from requirements.txt
3. Copy application code
4. Expose port 8000
5. Run with uvicorn

### Frontend Dockerfile (`docker/Dockerfile.frontend`)

Multi-stage build:
1. Builder: Node 18-alpine, npm install, npm run build
2. Runtime: Nginx alpine, copy built files, custom nginx.conf
3. Expose port 80

### Nginx Configuration (`docker/nginx.conf`)

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    # Frontend routes
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy to backend
    location /api/ {
        proxy_pass http://backend:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Docker Compose (`docker-compose.yml`)

Services:
- `backend` - FastAPI backend (port 8000)
- `frontend` - React frontend with Nginx (port 3000)

Networks:
- `bordereau-network` - Internal network

Volumes:
- `./backend:/app` - Backend code mount
- `./frontend:/app` - Frontend code mount

---

## 🚀 Deployment Scripts

### Master Deployment (`deployment/deploy.sh`)

Orchestrates full deployment:
1. Load configuration from `custom.config` or `default.config`
2. Test Snowflake connection
3. Deploy Bronze layer (4 SQL files)
4. Deploy Silver layer (6 SQL files)
5. Load sample Silver schemas (7_Load_Sample_Schemas.sql)
6. Deploy Gold layer (5 SQL files)
7. Display deployment summary

Features:
- Color-coded logging (log_info, log_success, log_error, log_warning)
- Progress tracking (step X/Y)
- Error handling with `set -e`
- Configuration validation
- Connection testing

### Layer-Specific Deployments

**Bronze Deployment (`deploy_bronze.sh`)**:
- Execute bronze/*.sql files in order (1-4)
- Create database, roles, schemas, tables, procedures, tasks
- Grant privileges

**Silver Deployment (`deploy_silver.sh`)**:
- Execute silver/*.sql files in order (1-6)
- Create hybrid tables for metadata
- Create procedures for transformations
- Create tasks for automation

**Gold Deployment (`deploy_gold.sh`)**:
- Execute gold/*.sql files in order (1-5)
- Create hybrid tables for metadata
- Create analytics tables with clustering
- Create transformation procedures
- Create automated tasks

### Container Deployment (`deploy_container.sh`)

Deploy to Snowpark Container Services:
1. Create compute pool (`CPU_X64_XS`)
2. Create image repository
3. Get repository URL
4. Build Docker images (backend + frontend)
5. Push images to Snowflake
6. Create service specification (YAML)
7. Deploy service
8. Monitor service status

Service Specification:
```yaml
spec:
  containers:
  - name: backend
    image: /DB/SCHEMA/REPO/backend:latest
    env:
      SNOWFLAKE_ACCOUNT: ${SNOWFLAKE_ACCOUNT}
      DATABASE_NAME: ${DATABASE_NAME}
    resources:
      requests:
        cpu: 0.6
        memory: 2Gi
      limits:
        cpu: "2"
        memory: 4Gi
    readinessProbe:
      port: 8000
      path: /api/health

  - name: frontend
    image: /DB/SCHEMA/REPO/frontend:latest
    resources:
      requests:
        cpu: 0.4
        memory: 1Gi
      limits:
        cpu: 1
        memory: 2Gi
    readinessProbe:
      port: 80
      path: /

  endpoints:
  - name: frontend
    port: 80
    public: true
```

### Configuration Files

**Default Configuration (`deployment/default.config`)**:
```bash
# Snowflake Connection
SNOWFLAKE_ACCOUNT="your_account.region"
SNOWFLAKE_USER="your_username"
SNOWFLAKE_PASSWORD="your_password"
SNOWFLAKE_ROLE="SYSADMIN"
SNOWFLAKE_WAREHOUSE="COMPUTE_WH"

# Database Configuration
DATABASE_NAME="BORDEREAU_PIPELINE"
BRONZE_SCHEMA_NAME="BRONZE"
SILVER_SCHEMA_NAME="SILVER"
GOLD_SCHEMA_NAME="GOLD"

# SPCS Configuration
COMPUTE_POOL_NAME="BORDEREAU_COMPUTE_POOL"
COMPUTE_POOL_SIZE="CPU_X64_XS"
REPOSITORY_NAME="BORDEREAU_REPO"
SERVICE_NAME="BORDEREAU_SERVICE"
```

---

## 📝 Sample Data

### Claims Data Files

**Provider A - Dental Claims** (`sample_data/claims_data/provider_a/dental-claims-20240301.csv`):
```csv
claim_id,member_id,provider_id,service_date,procedure_code,billed_amount,paid_amount,claim_type
DC001,M12345,P98765,2024-03-01,D0120,150.00,120.00,DENTAL
DC002,M12346,P98765,2024-03-01,D1110,85.00,68.00,DENTAL
```

**Provider B - Medical Claims** (`sample_data/claims_data/provider_b/medical-claims-20240115.csv`):
```csv
ClaimNumber,PatientID,DoctorID,DateOfService,DiagnosisCode,ChargedAmount,PaidAmount,Type
MC001,P54321,D12345,2024-01-15,Z00.00,250.00,200.00,MEDICAL
MC002,P54322,D12346,2024-01-15,J06.9,180.00,144.00,MEDICAL
```

**Provider E - Pharmacy Claims** (`sample_data/claims_data/provider_e/pharmacy-claims-20240201.csv`):
```csv
rx_claim_id,patient_id,pharmacy_id,fill_date,ndc_code,quantity,cost,copay
RX001,PT9876,PH5432,2024-02-01,00378-1805-10,30,45.00,10.00
RX002,PT9877,PH5432,2024-02-01,00093-0058-01,90,120.00,15.00
```

### Configuration Files

**Silver Target Schemas** (`sample_data/config/silver_target_schemas_samples.csv`):
```csv
table_name,tpa,description,business_owner,data_classification,is_active
CLAIMS_PROVIDER_A,PROVIDER_A,Standardized claims for Provider A,Claims Team,CONFIDENTIAL,TRUE
MEMBERS_PROVIDER_A,PROVIDER_A,Member demographics for Provider A,Member Services,CONFIDENTIAL,TRUE
CLAIMS_PROVIDER_B,PROVIDER_B,Standardized claims for Provider B,Claims Team,CONFIDENTIAL,TRUE
```

**Silver Target Fields** (`sample_data/config/silver_target_fields_samples.csv`):
```csv
table_name,tpa,field_name,data_type,field_order,is_nullable,description
CLAIMS_PROVIDER_A,PROVIDER_A,claim_id,VARCHAR(100),1,FALSE,Unique claim identifier
CLAIMS_PROVIDER_A,PROVIDER_A,member_id,VARCHAR(100),2,FALSE,Member identifier
CLAIMS_PROVIDER_A,PROVIDER_A,provider_id,VARCHAR(100),3,FALSE,Provider identifier
```

---

## 🔐 Authentication

Support three authentication methods:

### 1. Snow CLI (Recommended)
- Use existing Snow CLI connection
- No credentials in code
- Connection name: `DEPLOYMENT`

### 2. Password Authentication
- Username + password
- Store in config files or environment variables

### 3. Keypair Authentication
- RSA private key
- More secure than password
- Setup script: `deployment/setup_keypair_auth.sh`

---

## 📊 Monitoring & Observability

### Task Monitoring Views

Create views for monitoring:

**Bronze Task History**:
```sql
CREATE OR REPLACE VIEW bronze_task_history AS
SELECT 
    name,
    state,
    scheduled_time,
    completed_time,
    error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE database_name = CURRENT_DATABASE()
  AND schema_name = 'BRONZE'
ORDER BY scheduled_time DESC
LIMIT 100;
```

**Silver Processing Summary**:
```sql
CREATE OR REPLACE VIEW silver_processing_summary AS
SELECT 
    tpa,
    COUNT(*) AS total_runs,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS successful_runs,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failed_runs,
    MAX(processing_timestamp) AS last_run
FROM silver_processing_log
GROUP BY tpa;
```

**Gold Quality Dashboard**:
```sql
CREATE OR REPLACE VIEW gold_quality_dashboard AS
SELECT 
    qr.rule_name,
    qr.table_name,
    qr.tpa,
    qcr.check_timestamp,
    qcr.records_checked,
    qcr.pass_rate,
    qcr.status
FROM quality_rules qr
LEFT JOIN quality_check_results qcr ON qr.quality_rule_id = qcr.quality_rule_id
WHERE qr.is_active = TRUE
ORDER BY qcr.check_timestamp DESC;
```

---

## 🎯 Key Features to Implement

### 1. Multi-Tenant Isolation
- All tables include `tpa` column
- Row-level security per TPA
- TPA-specific configurations

### 2. AI-Powered Field Mapping
- ML-based pattern matching
- LLM-powered semantic mapping using Snowflake Cortex
- Confidence scoring
- Human approval workflow

### 3. Data Quality Framework
- Configurable quality rules
- Automated quality checks
- Quarantine for failed records
- Quality metrics dashboard

### 4. Incremental Processing
- Watermark-based processing
- Process only changed data
- Efficient resource utilization

### 5. Hybrid Table Strategy
- **Metadata tables** → Hybrid tables with indexes
- **Analytics tables** → Standard tables with clustering
- **Log tables** → Standard tables (append-only)

### 6. Task Orchestration
- Automated processing pipelines
- Task dependencies
- Error handling and retry logic
- Monitoring and alerting

---

## 📚 Documentation Requirements

Create comprehensive documentation:

1. **README.md** - Project overview, quick start
2. **QUICK_START.md** - 10-minute setup guide
3. **Layer READMEs** - Bronze, Silver, Gold documentation
4. **Deployment Guides** - Multiple deployment methods
5. **User Guide** - End-user documentation
6. **TPA Guide** - TPA onboarding and management
7. **API Documentation** - FastAPI auto-generated docs
8. **Architecture Diagrams** - Data flow, system architecture

---

## 🧪 Testing

### Deployment Testing
- Connection tests
- SQL syntax validation
- Docker build tests
- Service health checks

### Integration Testing
- End-to-end data flow
- API endpoint testing
- UI component testing

### Sample Data Testing
- Upload sample files
- Verify Bronze ingestion
- Verify Silver transformation
- Verify Gold aggregation

---

## 🔄 Git Configuration

### .gitignore

```gitignore
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/

# Node
node_modules/
dist/
build/
*.log

# Configuration
config.json
config.toml
.env
custom.config
*.key
*.pem

# Docker
Dockerfile.frontend.spcs
Dockerfile.frontend.unified
nginx-spcs.conf
nginx-unified.conf

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
```

---

## 🎨 UI/UX Guidelines

### Design Principles
1. **Clean & Modern** - Ant Design components
2. **Intuitive Navigation** - Clear tabs and breadcrumbs
3. **Real-time Updates** - Live status indicators
4. **Responsive** - Works on desktop and tablet
5. **Accessible** - WCAG 2.1 AA compliance

### Color Scheme
- Primary: Ant Design blue (#1890ff)
- Success: Green (#52c41a)
- Warning: Orange (#faad14)
- Error: Red (#f5222d)
- Info: Blue (#1890ff)

### Typography
- Font Family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto
- Headings: Bold, larger sizes
- Body: Regular weight, readable sizes

---

## 🚀 Performance Optimization

### Database Optimization
1. **Hybrid Tables**: Fast metadata lookups with indexes
2. **Clustering Keys**: Efficient analytics queries
3. **Materialized Views**: Pre-computed aggregations
4. **Query Optimization**: Proper JOIN strategies

### Application Optimization
1. **Connection Pooling**: Reuse Snowflake connections
2. **Caching**: Cache frequently accessed data
3. **Pagination**: Limit result sets
4. **Lazy Loading**: Load data on demand

### Frontend Optimization
1. **Code Splitting**: Dynamic imports
2. **Lazy Loading**: Load components on demand
3. **Memoization**: React.memo, useMemo, useCallback
4. **Virtual Scrolling**: For large lists

---

## 📦 Deployment Checklist

- [ ] Snowflake account configured
- [ ] Snow CLI installed and configured
- [ ] Database and schemas created
- [ ] Roles and privileges granted
- [ ] Bronze layer deployed
- [ ] Silver layer deployed
- [ ] Gold layer deployed
- [ ] Sample data loaded
- [ ] Backend configured and running
- [ ] Frontend built and running
- [ ] API endpoints tested
- [ ] UI tested
- [ ] Documentation reviewed
- [ ] Monitoring configured

---

## 🎯 Success Criteria

The project is complete when:

1. ✅ All SQL scripts execute without errors
2. ✅ All tables created (Bronze: 3, Silver: 8+dynamic, Gold: 14)
3. ✅ All procedures created and tested
4. ✅ All tasks created and scheduled
5. ✅ Backend API running with all endpoints functional
6. ✅ Frontend UI accessible with all pages working
7. ✅ Sample data successfully processed through all layers
8. ✅ Docker containers build and run successfully
9. ✅ SPCS deployment successful (optional)
10. ✅ Documentation complete and accurate

---

## 📝 Additional Notes

### Hybrid Tables vs Standard Tables

**Use Hybrid Tables for:**
- Metadata tables (< 10M rows)
- Frequent point queries
- UPDATE/DELETE operations
- Need for indexes

**Use Standard Tables for:**
- Analytics tables (> 10M rows)
- Append-heavy workloads
- Time-series data
- Use clustering keys instead

### Sample Silver Schemas

Include sample schemas for 5 providers (A, B, C, D, E):
- Each provider has 3 tables: CLAIMS, MEMBERS, PROVIDERS
- Total: 15 tables with 66 fields
- Auto-loaded during deployment

### Gold Layer Transformations

Implement these transformations:
1. **Claims Analytics**: Aggregate claims by year/month/type
2. **Member 360**: Comprehensive member view
3. **Provider Performance**: Provider KPIs and metrics
4. **Financial Summary**: Financial analytics and reporting

### Quality Rules

Implement 5 quality rules:
1. Completeness check (required fields)
2. Validity check (data ranges)
3. Consistency check (cross-field validation)
4. Timeliness check (data freshness)
5. Referential integrity (foreign keys)

### Business Metrics

Implement 5 business metrics:
1. Total Claims Count
2. Average Claim Amount
3. Member Retention Rate
4. Provider Utilization Rate
5. Loss Ratio

---

## 🎓 Learning Resources

- [Snowflake Documentation](https://docs.snowflake.com)
- [FastAPI Documentation](https://fastapi.tiangolo.com)
- [React Documentation](https://react.dev)
- [Ant Design Documentation](https://ant.design)
- [Docker Documentation](https://docs.docker.com)
- [Snowpark Container Services](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/overview)

---

## 📞 Support

For issues or questions:
1. Check documentation in `docs/` folder
2. Review deployment logs
3. Check Snowflake query history
4. Review API logs
5. Check browser console for frontend errors

---

**End of Project Generation Prompt**

This document contains all specifications needed to regenerate the complete Bordereau Processing Pipeline project. Follow the structure, implement all features, and ensure all components work together seamlessly.

**Version**: 2.0  
**Last Updated**: January 19, 2026  
**Total Files**: ~100 files  
**Total Lines of Code**: ~15,000 lines  
**Estimated Implementation Time**: 40-60 hours
