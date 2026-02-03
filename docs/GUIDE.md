# Bordereau User Guide

> Complete guide to healthcare claims processing with AI-powered field mapping

[![Version](https://img.shields.io/badge/version-3.3-blue)]()
[![Status](https://img.shields.io/badge/docs-up%20to%20date-brightgreen)]()

**Last Updated**: February 3, 2026 | **Reading Time**: 20 minutes

---

## 📋 Table of Contents

| Section | Topics | Time |
|---------|--------|------|
| **[1. Getting Started](#getting-started)** | Prerequisites, Setup, Quick Start | 5 min |
| **[2. TPA Management](#tpa-management)** | What is TPA, Add TPA, Selectors | 3 min |
| **[3. Bronze Layer](#bronze-layer---data-ingestion)** | Upload, Monitor, Stages, Tasks | 5 min |
| **[4. Silver Layer](#silver-layer---transformation)** | Schemas, Mapping (ML/LLM), Transform | 10 min |
| **[5. Gold Layer](#gold-layer---analytics)** | Analytics, Quality, Rules | 3 min |
| **[6. Technical Reference](#technical-reference)** | Stack, Performance, Security, Deployment | 5 min |
| **[7. Troubleshooting](#troubleshooting)** | Common Issues, Solutions, Error Messages | 5 min |

**Total Reading Time**: ~35 minutes | **Quick Start**: 5 minutes

---

## Getting Started

### Prerequisites

| Requirement | Version | Installation |
|-------------|---------|--------------|
| Snowflake account | Enterprise+ | Admin privileges required |
| Python | 3.10+ | `python --version` |
| Node.js | 18+ | `node --version` |
| Snowflake CLI | Latest | `pip install snowflake-cli-labs` |

### First-Time Setup

```bash
# 1. Configure Snowflake connection
snow connection add
# Enter: account, user, password/authenticator, warehouse, database, schema, role

# 2. Deploy database layers (Bronze, Silver, Gold)
cd deployment
./deploy.sh YOUR_CONNECTION

# 3. Start application (backend + frontend)
cd ..
./start.sh
```

**Access UI**: http://localhost:3000  
**API Docs**: http://localhost:8000/docs

### 5-Minute Quick Start

1. **Add TPA**: Admin → TPA Management → Create TPA (`provider_a`)
2. **Upload File**: Bronze → Upload Files → Select TPA → Drop CSV
3. **Auto-Map**: Silver → Field Mappings → Select table → Auto-Map (ML)
4. **Transform**: Silver → Transform → Select TPA → Execute
5. **View Data**: Silver → View Data → Select TPA → Browse tables

---

## TPA Management

### What is a TPA?

**Third Party Administrator** - The organizational unit for data isolation.

Each TPA has:
- Unique code (e.g., `provider_a`)
- Separate file storage (`@SRC/provider_a/`)
- Dedicated tables (`PROVIDER_A_MEDICAL_CLAIMS`)
- Independent field mappings
- Isolated transformation rules

### Add New TPA

**Location**: Admin → TPA Management

1. Click **Add TPA**
2. Fill in details:
   - **TPA Code**: `provider_a` (lowercase, underscores only)
   - **TPA Name**: `Provider A Healthcare` (display name)
   - **Description**: Optional details
3. Click **Create**

**Naming Rules**:
- Code: Used in paths and table names (lowercase, underscores)
- Name: Displayed in UI (any format)
- Tables: Auto-generated as `{TPA_CODE}_{TABLE_NAME}`

### TPA Selectors

All TPA dropdowns are searchable:
- Type to filter by name
- Stores TPA code internally
- Single-select for uploads and transforms
- Multi-select for data viewing and filtering

---

## Bronze Layer - Data Ingestion

**Purpose**: Land and parse raw files into Snowflake with TPA isolation.

### 1. Upload Files

**Location**: Bronze → Upload Files

**Steps**:
1. Select TPA from searchable dropdown
2. Drag and drop CSV/Excel files (or click to browse)
3. Click **Upload**
4. Files land in `@SRC/{tpa}/filename.csv`
5. Auto-processed by scheduled task (every 60 minutes)

**Supported Formats**: CSV, Excel (.xlsx, .xls)  
**File Size**: Up to 100MB per file  
**Batch Size**: 10-20 files recommended

### 2. View Raw Data

**Location**: Bronze → Raw Data

**Features**:
- Filter by TPA (multi-select, searchable)
- Search by filename
- View all parsed records (VARIANT JSON format)
- Check row counts and load timestamps

**Use Case**: Verify files were parsed correctly before transformation.

### 3. Monitor Processing

**Location**: Bronze → Processing Status

**Dashboard Metrics**:
- Total files processed
- Success/failure counts and rates
- Files currently processing
- Total rows ingested

**Filters**:
- TPA (multi-select)
- Status (Success/Failed/Processing/Pending)
- File type (CSV/Excel)

**Actions**:
- **Reprocess**: Retry failed files
- **Delete**: Remove processed file data
- **Refresh**: Update status in real-time

### 4. File Stages

**Location**: Bronze → File Stages

**Stage Lifecycle**:

| Stage | Purpose | Retention |
|-------|---------|-----------|
| **SRC** | Landing zone for uploads | Until processed |
| **PROCESSING** | Reserved for future use | N/A |
| **COMPLETED** | Successfully processed files | 30 days |
| **ERROR** | Failed files (check logs) | 30 days |
| **ARCHIVE** | Long-term storage | 90 days |

**Actions**: Delete individual files or bulk delete selected files

### 5. Automated Tasks

**Location**: Bronze → Tasks

| Task | Frequency | Purpose |
|------|-----------|---------|
| `discover_files_task` | Every 60 min | Scan stages for new files |
| `process_files_task` | Every 60 min | Parse files into `RAW_DATA_TABLE` |

**Actions**:
- **Resume**: Start suspended task
- **Suspend**: Pause task execution
- **Execute Now**: Trigger immediate run

**Tip**: Manually trigger tasks after bulk uploads for faster processing.

---

## Silver Layer - Transformation

**Purpose**: Map and transform raw data into standardized, validated tables.

### 1. Define Target Schemas

**Location**: Silver → Target Schemas

**Create Reusable Schema**:
1. Click **Add Schema**
2. Enter table name (e.g., `MEDICAL_CLAIMS`)
3. Define columns:
   - **Name**: Column identifier (e.g., `CLAIM_ID`)
   - **Type**: VARCHAR, NUMBER, DATE, TIMESTAMP, BOOLEAN
   - **Nullable**: Allow NULL values?
   - **Description**: Business definition
4. Click **Save Schema**

**Create Physical Table**:
1. Select schema from list
2. Click **Create Table**
3. Select TPA from dropdown
4. Table created as `{TPA}_{TABLE_NAME}`

**Example**: Schema `MEDICAL_CLAIMS` + TPA `provider_a` = Table `PROVIDER_A_MEDICAL_CLAIMS`

**Created Tables View**:
- Shows all physical tables across TPAs
- Displays: Name, Schema, TPA, Mappings, Rows, Size, Quality
- Actions: View definition, delete table

### 2. Map Fields (3 Methods)

**Location**: Silver → Field Mappings

#### Mapping Method Comparison

| Feature | ML Auto-Map | LLM Auto-Map | Manual |
|---------|-------------|--------------|--------|
| **Speed** | ⚡ Fast (30-60s) | ⚡ Medium (30-90s) | 🐌 Slow (per field) |
| **Accuracy** | 📊 70-85% | 🎯 85-95% | ✅ 100% |
| **Best For** | Consistent naming | Semantic matching | Custom logic |
| **Cost** | 💰 Free | 💰💰 Cortex credits | 💰 Free |
| **Reasoning** | ❌ No | ✅ Yes | ✅ Manual |
| **Batch Size** | ✅ All fields | ✅ All fields | ❌ One at a time |
| **Learning** | ❌ Static | ✅ AI-powered | ❌ N/A |

**💡 Recommendation**: Start with LLM for first mapping, use ML for similar TPAs, Manual for edge cases.

---

#### Method 1: Auto-Map with ML (Pattern Matching)

**Best for**: Consistent naming conventions, structured data, similar TPAs

**Steps**:
1. Expand table card
2. Click **Auto-Map (ML)**
3. Configure:
   - **Top N matches**: 1-5 (default: 3)
   - **Confidence threshold**: 0-100% (default: 60%)
4. Wait 30-60 seconds
5. Review suggestions with confidence scores
6. Approve or decline each mapping

**Algorithm**: TF-IDF + SequenceMatcher + word overlap

**Example Matches**:
```
clm_id          → CLAIM_ID          (95% confidence) ✅
patient_name    → MEMBER_NAME       (78% confidence) ✅
svc_date        → SERVICE_DATE      (65% confidence) ⚠️
xyz123          → ???               (0% confidence)  ❌
```

**Pros**: Fast, free, good for standardized data  
**Cons**: Struggles with abbreviations, no semantic understanding

---

#### Method 2: Auto-Map with LLM (Semantic Understanding)

**Best for**: Inconsistent naming, complex mappings, semantic matching, first-time setup

**Steps**:
1. Expand table card
2. Click **Auto-Map (LLM)**
3. Select model (default: `llama3.1-70b`)
4. Wait 30-90 seconds
5. Review AI-generated mappings with reasoning
6. Approve or edit mappings

**Powered by**: Snowflake Cortex AI

**Example with Reasoning**:
```
svc_dt          → SERVICE_DATE
  Reasoning: "svc is common abbreviation for service"

pt_nm           → MEMBER_NAME
  Reasoning: "pt likely means patient, nm means name"

amt_pd          → AMOUNT_PAID
  Reasoning: "amt = amount, pd = paid"
```

**Pros**: Semantic understanding, explains reasoning, handles abbreviations  
**Cons**: Slower, uses Cortex credits, may need review

---

#### Method 3: Manual Mapping

**Best for**: Custom transformations, complex business logic, edge cases

**Steps**:
1. Expand table card
2. Click **Add Mapping**
3. Fill in:
   - **Source Field**: From `RAW_DATA_TABLE` (e.g., `claim_amt`)
   - **Target Column**: From schema (e.g., `CLAIM_AMOUNT`)
   - **Transformation**: Optional SQL (e.g., `CAST(claim_amt AS NUMBER(10,2))`)
   - **Approved**: Check to activate
4. Click **Save**

**Transformation Examples**:

| Use Case | Transformation | Example |
|----------|---------------|---------|
| **Date Parsing** | `TO_DATE(field, 'format')` | `TO_DATE(service_date, 'MM/DD/YYYY')` |
| **String Cleaning** | `UPPER(TRIM(field))` | `UPPER(TRIM(provider_name))` |
| **Type Casting** | `CAST(field AS type)` | `CAST(claim_amount AS NUMBER(10,2))` |
| **Calculations** | `field * multiplier` | `claim_amount * 0.8` |
| **Conditionals** | `CASE WHEN ... THEN ... END` | `CASE WHEN status='A' THEN 'Approved' END` |
| **Concatenation** | `field1 \|\| field2` | `first_name \|\| ' ' \|\| last_name` |

**Pros**: Full control, custom logic, no AI needed  
**Cons**: Time-consuming, manual work, prone to errors

---

**Mapping Features**:
- 🔍 Search tables by name/TPA/schema
- 🎯 Filter by status (All/With Mappings/No Mappings)
- ⚠️ Duplicate detection (yellow highlight)
- ✅ Bulk approve/delete
- 📊 Shows mapping count and approval rate

### 3. Execute Transformation

**Location**: Silver → Transform

**4-Step Wizard**:

**Step 1: Select Tables**
1. Select TPA (searchable dropdown)
2. Source: `RAW_DATA_TABLE` (auto-selected)
3. Target: Select destination table
4. Click **Next**

**Step 2: Verify Mappings**
- Review all active mappings
- Check source → target alignment
- View transformation logic
- See confidence scores
- Click **Next**

**Step 3: Execute**
- Click **Execute Transform**
- Monitor progress bar
- Wait for completion (1-5 minutes)

**Step 4: Results**
- View transformation statistics
- Check success/failure counts
- Review data quality metrics
- See transformation history

### 4. View Transformed Data

**Location**: Silver → View Data

**Steps**:
1. Select TPA (searchable dropdown)
2. All TPA tables displayed in accordion
3. Click table to expand and view data
4. Use search to filter records
5. Adjust row limit (100/500/1000/5000)

**Quality Metrics**:
- Total records
- Data quality score (0-100%)
- Last updated timestamp
- Validation pass rate

---

## Gold Layer - Analytics

**Purpose**: Provide business-ready analytics and aggregations.

### 1. Analytics Dashboard

**Location**: Gold → Analytics

**Claims Analytics**:
- Total claims count and amounts
- Average claim amount
- Claims by type (Medical, Dental, Pharmacy, Vision)
- Claims by status (Submitted, Approved, Denied, Paid)
- Provider distribution
- Trend analysis over time

**Member 360 View**:
- Member demographics (age, gender, location)
- Complete claim history
- Provider relationships and patterns
- Risk scores and health indicators
- Lifetime value metrics

**Provider Performance**:
- Claims processed per provider
- Average processing time
- Approval rates and denial reasons
- Payment metrics and trends
- Network efficiency scores

**Financial Summary**:
- Total payments by period
- Outstanding amounts
- Payment trends and forecasts
- Cost analysis by category
- Budget vs. actual comparisons

**Filters**:
- Date range picker
- TPA selection (multi-select)
- Claim type filter
- Status filter

### 2. Quality Metrics

**Location**: Gold → Quality

**Dashboard Components**:
- Validation rule results (pass/fail counts)
- Error rates by field and rule
- Quality trends over time (line charts)
- Failed record details with reasons
- Top quality issues (ranked list)

**Use Case**: Monitor data quality and identify systematic issues.

### 3. Transformation Rules

**Location**: Gold → Rules

**Rule Types**:
- **Validation**: `claim_amount > 0`, `service_date <= CURRENT_DATE`
- **Business Logic**: `IF claim_type = 'DENTAL' THEN provider_type = 'DENTIST'`
- **Quality Checks**: Null checks, format validation, range checks
- **Quarantine**: Isolate records that fail critical rules

**Actions**:
- REJECT: Block record from processing
- QUARANTINE: Isolate for review
- FLAG: Mark for attention but allow
- CORRECT: Auto-fix with transformation

---

## Technical Reference

### Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | React 18 + TypeScript 5 | UI framework |
| | Ant Design 5 | Component library |
| | Vite 5 | Build tool and dev server |
| | Axios | HTTP client |
| **Backend** | Python 3.11 + FastAPI | REST API framework |
| | Uvicorn | ASGI server |
| | Snowflake Connector | Database driver |
| | Pydantic | Data validation |
| **Database** | Snowflake | Cloud data platform |
| | Hybrid Tables | Indexed metadata storage |
| | Clustered Tables | Analytics aggregations |
| | Snowpark | Python in SQL |
| | Cortex AI | LLM field mapping |

### Table Types and Performance

| Type | Storage | Use Case | Performance | Cost | When to Use |
|------|---------|----------|-------------|------|-------------|
| **Standard** | Columnar | Bronze raw data | Baseline | 💰 Low | Large append-only datasets |
| **Hybrid** | Row + Indexes | Silver metadata | 🚀 10-100x faster | 💰💰 Medium | Frequent point queries |
| **Clustered** | Columnar + Clustering | Gold analytics | 🚀 2-10x faster | 💰 Low | Large analytical scans |

**Performance Comparison** (1M row query):

```
Standard Table:     ████████████████████ 20 seconds
Hybrid Table:       ██ 0.2 seconds (100x faster)
Clustered Table:    ████ 4 seconds (5x faster)
```

**Index Count**: 22 indexes across Silver hybrid tables

**Hybrid Table Indexes**:
- `target_schemas`: PK on `schema_id`, index on `table_name`
- `field_mappings`: PK on `mapping_id`, indexes on `tpa_code`, `table_name`, `source_field`, `target_column`
- `created_tables`: PK on `table_id`, indexes on `tpa_code`, `schema_id`
- `transformation_rules`: PK on `rule_id`, indexes on `tpa_code`, `table_name`

### Task Automation

| Layer | Task | Frequency | Duration | Purpose |
|-------|------|-----------|----------|---------|
| **Bronze** | `discover_files_task` | ⏰ Every 60 min | ~30s | Scan stages for new files |
| | `process_files_task` | ⏰ Every 60 min | ~2-5 min | Parse files into `RAW_DATA_TABLE` |
| **Silver** | `transform_task` | ⏰ Every 10 min | ~1-3 min | Apply mappings and validation |
| **Gold** | `aggregate_task` | ⏰ Daily 1 AM | ~5-10 min | Calculate analytics and KPIs |

**Task Execution Flow**:

```
┌─────────────────┐
│ File Uploaded   │
└────────┬────────┘
         │ Wait up to 60 min
┌────────▼────────┐
│ Discover Task   │ Scans @SRC stage
└────────┬────────┘
         │ Queues file
┌────────▼────────┐
│ Process Task    │ Parses to RAW_DATA_TABLE
└────────┬────────┘
         │ Wait up to 10 min
┌────────▼────────┐
│ Transform Task  │ Applies mappings to Silver
└────────┬────────┘
         │ Wait until 1 AM
┌────────▼────────┐
│ Aggregate Task  │ Calculates Gold analytics
└─────────────────┘
```

**Manual Trigger**: Bronze → Tasks → Execute Now (bypasses wait time)

### Security Model

**Caller's Rights Execution**:
- All operations use user's credentials
- No shared service account
- User-level audit trails in logs

**Required Permissions**:

| Layer | Tables | Stages | Procedures |
|-------|--------|--------|------------|
| Bronze | SELECT, INSERT | READ, WRITE | - |
| Silver | SELECT, INSERT, UPDATE, DELETE | - | EXECUTE |
| Gold | SELECT | - | EXECUTE |

### Performance Optimization

**Query Optimization**:
- Hybrid tables: 10-100x faster (indexed lookups)
- Clustered tables: 2-10x faster (analytical scans)
- Result caching: Snowflake 24h, Backend 5m

**Scalability**:
- Auto-scaling compute clusters
- Container replication (1-3 instances)
- Linear scaling (tested with 1000+ TPAs)

### Monitoring and Logging

**Location**: Admin → System Logs

| Log Table | Contents |
|-----------|----------|
| `APPLICATION_LOGS` | Application events, user actions |
| `API_REQUEST_LOGS` | HTTP requests/responses, latency |
| `ERROR_LOGS` | Exceptions, stack traces |
| `FILE_PROCESSING_LOGS` | File lifecycle, processing stages |
| `TASK_EXECUTION_LOGS` | Task runs, duration, status |

### Deployment Options

#### Option 1: Local Development

```bash
./start.sh  # Starts backend (port 8000) + frontend (port 3000)
```

**Access**:
- UI: http://localhost:3000
- API: http://localhost:8000/docs

#### Option 2: Snowflake Database Only

```bash
cd deployment
./deploy.sh YOUR_CONNECTION
```

**Deploys**: Bronze, Silver, Gold schemas, tables, tasks, procedures

#### Option 3: Snowpark Container Services (Full Stack)

```bash
# 1. Build and push Docker images
./build_and_push_ghcr.sh YOUR_GITHUB_USERNAME

# 2. Deploy to Snowflake SPCS
cd deployment
./deploy_container.sh YOUR_CONNECTION
```

**Includes**: Backend + Frontend containers, load balancer, auto-scaling

**Authentication Methods**:
1. **Snow CLI** (dev): `snow connection add`
2. **PAT Token** (prod): GitHub Personal Access Token
3. **Keypair** (most secure): RSA key pair authentication

### Best Practices

| Category | Recommendation |
|----------|----------------|
| **File Naming** | Use descriptive, date-based names: `claims-2024-03-01.csv` |
| **Batch Size** | Upload 10-20 files at a time for optimal processing |
| **Testing** | Upload sample file before full dataset |
| **Mapping** | Review ML/LLM suggestions before approving |
| **Monitoring** | Check task status and logs regularly |
| **Quality** | Define validation rules before transformations |
| **Processing** | Use incremental mode for large datasets |

---

## Troubleshooting

### File Not Processing

**Symptoms**: File uploaded but not appearing in raw data

**Solutions**:
1. Check file in correct TPA folder: `@SRC/{tpa}/filename.csv`
2. Verify CSV/Excel format (no corruption)
3. Check Bronze → Processing Status for errors
4. Manually trigger: Bronze → Tasks → Execute Now
5. Review logs: Admin → System Logs → File Processing

### Transformation Failed

**Symptoms**: Transform job fails or produces no output

**Solutions**:
1. Verify field mappings exist and are approved
2. Check target table exists: Silver → Target Schemas → Created Tables
3. Ensure source fields match raw data column names
4. Review transformation logic for SQL errors
5. Check logs: Admin → System Logs → Error Logs

### Mapping Errors

**Symptoms**: Duplicate mappings, incorrect field alignment

**Solutions**:
1. Check for duplicate mappings (highlighted in yellow)
2. Verify target columns exist in physical table
3. Ensure source field names match raw data exactly
4. Delete and recreate mappings if needed
5. Use ML/LLM auto-mapping for bulk corrections

### Performance Issues

**Symptoms**: Slow queries, timeouts, high latency

**Solutions**:
1. Reduce batch size in transformations (default: 10,000 rows)
2. Check Snowflake warehouse size (recommend: MEDIUM or larger)
3. Monitor task execution times in logs
4. Increase warehouse size for large datasets
5. Use incremental processing for ongoing loads

### Connection Issues

**Symptoms**: Cannot connect to Snowflake, authentication errors

**Solutions**:

```bash
# Test connection
snow connection test YOUR_CONNECTION

# View connection details
cat ~/.snowflake/connections.toml

# Re-add connection
snow connection add
```

**Common Issues**:
- Incorrect account identifier (use `account.region.cloud`)
- Expired password or token
- Insufficient role permissions
- Network/firewall blocking Snowflake

### Windows Path Issues

**Symptoms**: Deployment scripts fail on Windows

**Solutions**:
1. Use Git Bash (not CMD or PowerShell)
2. Scripts auto-convert paths for Snowflake PUT command
3. Use forward slashes in paths: `deployment/deploy.sh`
4. Alternatively, use `.bat` scripts: `deployment/deploy.bat`

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `Table does not exist` | Target table not created | Silver → Target Schemas → Create Table |
| `No mappings found` | Field mappings not defined | Silver → Field Mappings → Auto-Map or Manual |
| `Permission denied` | Insufficient Snowflake role | Grant required permissions to role |
| `File not found in stage` | Wrong TPA folder or file deleted | Re-upload file to correct TPA folder |
| `Transformation timeout` | Large dataset or small warehouse | Increase warehouse size or reduce batch |

---

**Version**: 3.3 | **Last Updated**: February 3, 2026
