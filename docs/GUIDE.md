# Complete Guide

Healthcare claims processing pipeline with medallion architecture and AI-powered field mapping.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Architecture Overview](#architecture-overview)
3. [Bronze Layer](#bronze-layer)
4. [Silver Layer](#silver-layer)
5. [Gold Layer](#gold-layer)
6. [TPA Management](#tpa-management)
7. [Technical Details](#technical-details)

---

## Getting Started

### Prerequisites

- Snowflake account with admin privileges
- Python 3.10+, Node.js 18+
- Snowflake CLI: `pip install snowflake-cli-labs`

### First-Time Setup

```bash
# 1. Configure Snowflake connection
snow connection add

# 2. Deploy database layers
cd deployment
./deploy.sh YOUR_CONNECTION

# 3. Start application
cd ..
./start.sh
```

### Quick Workflow

1. **Add TPA**: Admin → TPA Management → Add TPA
2. **Upload Files**: Bronze → Upload Files → Select files
3. **Define Schema**: Silver → Target Schemas → Add Schema
4. **Create Mappings**: Silver → Field Mappings → Auto-Map
5. **Transform**: Silver → Transform → Run Transformation
6. **View Analytics**: Gold → Analytics

---

## Architecture Overview

### System Components

```
┌─────────────────┐
│ React Frontend  │ Port 3000/80
│ TypeScript + UI │
└────────┬────────┘
         │ REST API
┌────────▼────────┐
│ FastAPI Backend │ Port 8000
│ Python 3.11     │
└────────┬────────┘
         │ Snowflake Connector
┌────────▼────────────────────┐
│ Snowflake Database          │
│ ┌─────────────────────────┐ │
│ │ Bronze (Raw Data)       │ │
│ │ 8 tables, append-only   │ │
│ └───────────┬─────────────┘ │
│             │ Tasks (60min) │
│ ┌───────────▼─────────────┐ │
│ │ Silver (Cleaned Data)   │ │
│ │ 12 hybrid tables        │ │
│ └───────────┬─────────────┘ │
│             │ Tasks (10min) │
│ ┌───────────▼─────────────┐ │
│ │ Gold (Analytics)        │ │
│ │ 12 clustered tables     │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

### Data Flow

1. **Upload** → Files to Bronze stage `@SRC/{tpa}/`
2. **Ingest** → Bronze task processes files into `RAW_DATA_TABLE`
3. **Map** → Define schemas and field mappings (Manual/ML/LLM)
4. **Transform** → Silver task applies mappings and validation
5. **Aggregate** → Gold task calculates analytics
6. **Analyze** → View metrics in UI

### Multi-Tenancy

**TPA Isolation**:
- Separate folders: `@SRC/{tpa}/`
- Separate tables: `CLAIMS_{TPA}`
- TPA column indexed in all tables
- Complete data separation

---

## Bronze Layer

### Upload Files

1. Navigate to **Bronze → Upload Files**
2. Select TPA from searchable dropdown
3. Drag and drop CSV/Excel files
4. Click **Upload**
5. Files auto-process via scheduled task

**File Path**: `@SRC/{tpa}/filename.csv`

### View Raw Data

**Bronze → Raw Data**
- Filter by TPA (searchable multi-select)
- Search by filename
- View all uploaded records
- Check processing statistics

### Monitor Processing

**Bronze → Processing Status**
- Shows all files across all TPAs by default
- Filter by TPA (initially empty - select to filter)
- Filter by status (Success/Failed/Processing/Pending)
- Filter by file type
- View statistics:
  - Total files processed
  - Success/failure counts and rates
  - Files currently processing
  - Total rows ingested
- Actions:
  - Reprocess failed files
  - Delete file data for successful files
- Real-time refresh button

### File Stages

**Bronze → File Stages**
- **SRC**: Uploaded files awaiting processing
- **PROCESSING**: Reserved for future use
- **COMPLETED**: Successfully processed files
- **ERROR**: Failed files (check logs)
- **ARCHIVE**: Files older than 30 days

**Actions**: Delete individual files or bulk delete selected files

### Tasks

**Bronze → Tasks**
- **discover_files_task**: Scans stages for new files (60 min)
- **process_files_task**: Processes files into raw table (60 min)

**Actions**: Resume, suspend, or manually trigger tasks

---

## Silver Layer

### Target Schemas

**Silver → Target Schemas**

Define reusable table schemas:

1. Click **Add Schema**
2. Enter table name (e.g., `MEDICAL_CLAIMS`)
3. Define columns:
   - Column name
   - Data type (VARCHAR, NUMBER, DATE, etc.)
   - Nullable (yes/no)
   - Description
4. Click **Save Schema**

**Create Physical Table**:
1. Select schema from the list
2. Click **Create Table**
3. Select TPA from dropdown
4. Table created as `{TPA}_{TABLE_NAME}` (e.g., `PROVIDER_A_MEDICAL_CLAIMS`)

**Created Tables Section**:
- Loading spinner displays while fetching created tables
- Shows all physical tables across all TPAs
- Displays: Table name, Schema, Provider (TPA), Mappings count, Row count, Size, Quality score
- Actions: View schema definition, delete table

**Schema Usage**: Shows count of physical tables created from each schema

### Field Mappings

**Silver → Field Mappings**

Map source fields to target columns using three methods:

**Initial Load**: Loading spinner displays while fetching tables and mappings

#### Auto-Map with ML

1. Expand a table card
2. Click **Auto-Map (ML)** button
3. Configure:
   - Top N matches per field (default: 3)
   - Confidence threshold (0-100%, default: 60%)
   - Higher = stricter matching
4. Wait for processing (30-60 seconds)
5. Review suggested mappings with confidence scores
6. Approve or decline each mapping

**ML Algorithm**: TF-IDF + SequenceMatcher + word overlap for pattern matching

#### Auto-Map with LLM

1. Expand a table card
2. Click **Auto-Map (LLM)** button
3. Select Cortex AI model (default: llama3.1-70b)
4. Wait for processing (30-90 seconds)
5. AI generates intelligent mappings with reasoning
6. Review suggestions
7. Approve or edit mappings

**LLM**: Snowflake Cortex AI for semantic understanding

#### Manual Mapping

1. Expand a table card
2. Click **Add Mapping** button
3. Fill in:
   - Source field (from raw data)
   - Target column (from schema)
   - Transformation logic (optional SQL)
   - Approved status (checkbox)
4. Click **Save**

**Features**:
- Loading spinners for better UX feedback
- Search tables by name, TPA, or schema
- Filter by mapping status (All/With Mappings/No Mappings)
- Duplicate detection (highlighted in yellow)
- Bulk approve/delete mappings
- Auto-refresh after changes
- Shows mapping count and approval rate per table

### Transform Data

**Silver → Transform**

Visual flow display shows source → target transformation:

1. Select TPA (searchable dropdown)
2. Wait for tables to load (loading spinner displayed)
3. Source table auto-selected: `RAW_DATA_TABLE`
4. Target table auto-selected if only one exists for TPA
5. Click **Next** to verify mappings
6. Review field mappings (shows all active mappings)
   - Source field → Target column
   - Mapping method (ML/LLM/Manual)
   - Confidence scores
   - Transformation logic
7. Click **Next** to execute
8. Click **Execute Transform**
9. Monitor progress and view results

**Transformation Steps**:
1. **Select Tables** - Choose source and target (with loading feedback)
2. **Verify Mappings** - Review all active mappings with details
3. **Execute Transform** - Apply mappings and validation rules
4. **Complete** - View results, statistics, and transformation history

### View Silver Data

**Silver → View Data**

1. Select TPA (searchable dropdown)
2. All tables for that TPA are displayed in an accordion view
3. Click on any table to expand and view its data
4. Use search box to filter records
5. Adjust row limit (100/500/1000/5000 rows)
6. Check data quality statistics:
   - Total records
   - Data quality score
   - Last updated timestamp

**Features**:
- Accordion view - all TPA tables shown automatically
- No need to select tables from dropdown (tables are TPA-specific)
- Record count displayed in table header
- Search across all columns
- Adjustable row limits
- Quality metrics per table

---

## Gold Layer

### Analytics

**Gold → Analytics**

View aggregated business metrics:

**Claims Analytics**:
- Total claims, amounts, averages
- Claims by type, status, provider
- Trend analysis

**Member 360**:
- Member demographics
- Claim history
- Provider relationships
- Risk scores

**Provider Performance**:
- Claims processed
- Average processing time
- Approval rates
- Payment metrics

**Financial Summary**:
- Total payments
- Outstanding amounts
- Payment trends
- Cost analysis

**Filters**: Date range, TPA selection

### Quality Metrics

**Gold → Quality**

Data quality dashboard:
- Validation rule results
- Error rates by field
- Quality trends over time
- Failed record details

### Transformation Rules

**Gold → Rules**

Define business rules:
- Validation rules (e.g., amount > 0)
- Transformation logic
- Quality checks
- Quarantine conditions

---

## TPA Management

### Add TPA

**Admin → TPA Management**

1. Click **Add TPA**
2. Enter:
   - **TPA Code**: Lowercase with underscores (e.g., `provider_a`)
   - **TPA Name**: Display name (e.g., `Provider A Healthcare`)
   - **Description**: Optional details
3. Click **Create**

### TPA Structure

**Naming Convention**:
- Code: `provider_a` (used in paths and table names)
- Name: `Provider A Healthcare` (displayed in UI)
- Tables: `CLAIMS_PROVIDER_A`
- Paths: `@SRC/provider_a/file.csv`

**Isolation**:
- Separate field mappings
- Separate target tables
- Separate transformation rules
- Independent processing pipelines

### TPA Selectors

All TPA filters use searchable dropdowns:
- Type to filter TPAs
- Displays TPA names (stores TPA codes)
- Alphabetically sorted
- Single selection for Upload, Transform, View Data
- Multi-select for Bronze Raw Data, File Stages

---

## Technical Details

### Technology Stack

**Frontend**:
- React 18, TypeScript 5
- Ant Design 5 (UI components)
- Vite 5 (build tool)
- Axios (HTTP client)

**UI/UX Features**:
- Loading spinners on all data-fetching operations
- Accordion views for TPA-specific tables (no unnecessary dropdowns)
- Color-coded layer headers (darker bronze for better visibility)
- Real-time feedback for auto-mapping operations
- Empty state messages with helpful guidance
- Responsive design with mobile support

**Backend**:
- Python 3.11, FastAPI
- Uvicorn (ASGI server)
- Snowflake Connector
- Pydantic (validation)

**Database**:
- Snowflake (cloud data platform)
- Hybrid Tables (fast lookups)
- Clustered Tables (fast scans)
- Snowpark (Python in SQL)
- Cortex AI (LLM mapping)

### Table Types

**Standard Tables** (Bronze):
- Columnar storage
- Append-only raw data
- Large datasets

**Hybrid Tables** (Silver):
- Row-based storage with indexes
- 10-100x faster point queries
- Metadata tables (mappings, schemas)
- 22 indexes total

**Clustered Tables** (Gold):
- Columnar storage with clustering
- 2-10x faster analytical queries
- Analytics and aggregations

### Task Automation

**Bronze Tasks** (Every 60 minutes):
- `discover_files_task`: Scan stages for new files
- `process_files_task`: Process files into raw table

**Silver Tasks** (Every 10 minutes):
- Transform raw data to Silver tables
- Apply validation rules
- Update quality metrics

**Gold Tasks** (Daily at 1 AM):
- Aggregate Silver data
- Calculate analytics and KPIs
- Update member 360 views

### Security

**Caller's Rights Execution**:
- Operations use user's credentials
- No shared service account
- User-level audit trails

**Required Permissions**:
- Bronze: SELECT, INSERT on tables; READ, WRITE on stages
- Silver: SELECT, INSERT, UPDATE, DELETE; EXECUTE on procedures
- Gold: SELECT on tables; EXECUTE on procedures

### Performance

**Query Optimization**:
- Hybrid tables: 10-100x faster (indexed lookups)
- Clustered tables: 2-10x faster (analytical scans)
- Result caching: Snowflake 24h, Backend 5m

**Scalability**:
- Auto-scaling compute clusters
- Container replication (1-3 instances)
- Linear scaling (supports 1000+ TPAs)

### Monitoring

**Log Tables** (Admin → System Logs):
- `APPLICATION_LOGS`: Application events
- `API_REQUEST_LOGS`: Request/response tracking
- `ERROR_LOGS`: Error tracking
- `FILE_PROCESSING_LOGS`: Processing stages
- `TASK_EXECUTION_LOGS`: Task tracking

### Deployment

**Local Development**:
```bash
./start.sh  # Starts backend + frontend
```

**Snowflake Database Only**:
```bash
cd deployment
./deploy.sh YOUR_CONNECTION
```

**Snowpark Container Services** (Full Stack):
```bash
# Build and push images
./build_and_push_ghcr.sh YOUR_GITHUB_USERNAME

# Deploy to Snowflake
cd deployment
./deploy_container.sh YOUR_CONNECTION
```

**Authentication Methods**:
1. Snow CLI (dev)
2. PAT Token (prod)
3. Keypair (most secure)

### Best Practices

1. **File Naming**: Use descriptive, date-based names (e.g., `claims-2024-03-01.csv`)
2. **Batch Uploads**: Upload 10-20 files at a time
3. **Test First**: Upload sample file before full dataset
4. **Validate Mappings**: Review ML/LLM suggestions before approving
5. **Monitor Tasks**: Check task status regularly
6. **Define Rules**: Set up quality rules before transformations
7. **Incremental Processing**: Use for large datasets

### Troubleshooting

**File Not Processing**:
- Check file in correct TPA folder (`@SRC/{tpa}/`)
- Verify CSV/Excel format
- Manually trigger: Bronze → Tasks → Resume

**Transformation Failed**:
- Check field mappings exist and are correct
- Verify target table exists
- Review error logs in Admin → System Logs

**Mapping Errors**:
- Ensure target columns exist in physical table
- Check for duplicate mappings (highlighted in UI)
- Verify source field names match raw data

**Performance Issues**:
- Reduce batch size in transformations
- Check Snowflake warehouse size
- Monitor task execution times in logs

**Connection Issues**:
```bash
# Test connection
snow connection test YOUR_CONNECTION

# Check credentials
cat ~/.snowflake/connections.toml
```

**Windows Path Issues**:
- Use Git Bash for deployment scripts
- Scripts auto-convert paths for Snowflake PUT command

---

**Version**: 3.1 | **Last Updated**: February 2, 2026
