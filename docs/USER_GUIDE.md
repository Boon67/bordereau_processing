# User Guide

**Complete usage guide for the Snowflake File Processing Pipeline.**

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Bronze Layer Usage](#bronze-layer-usage)
4. [Silver Layer Usage](#silver-layer-usage)
5. [TPA Management](#tpa-management)
6. [Monitoring & Troubleshooting](#monitoring--troubleshooting)

## Introduction

The Snowflake File Processing Pipeline is a 100% Snowflake-native data pipeline with Bronze and Silver layers, featuring TPA (Third Party Administrator) as a first-class dimension for true multi-tenant data isolation.

### Key Features

- **Automatic file ingestion** from CSV and Excel files
- **TPA-based data isolation** for multi-tenant scenarios
- **Three mapping methods**: Manual CSV, ML Pattern Matching, LLM Cortex AI
- **Comprehensive rules engine** with 5 rule types
- **Modern React UI** with FastAPI middleware
- **No external orchestration** required

## Getting Started

### Prerequisites

- Snowflake account with appropriate privileges
- Access to the React frontend and FastAPI backend
- Sample data files (provided in `sample_data/`)

### Quick Start

1. **Access the React App**
   - Start the backend and frontend locally
   - Open the UI at `http://localhost:3000`

2. **Upload Sample Data**
   - Open Bronze Ingestion Pipeline
   - Select TPA (e.g., `provider_a`)
   - Upload files from `sample_data/claims_data/`

3. **Monitor Processing**
   - View processing status in Bronze app
   - Check raw data viewer

4. **Configure Silver Mappings**
   - Open Silver Transformation Manager
   - Define target schemas
   - Create field mappings
   - Run transformations

## Bronze Layer Usage

### Uploading Files

**Step 1: Select TPA**
- In the sidebar, select your TPA from the dropdown
- TPA must be registered in `TPA_MASTER`

**Step 2: Upload Files**
- Navigate to **📤 Upload Files**
- Drag and drop CSV or Excel files
- Click **Upload**
- Files are automatically uploaded to `@SRC/{tpa}/`

**Step 3: Monitor Processing**
- Navigate to **📊 Processing Status**
- View real-time processing metrics
- Check for any failed files

### File Organization

Files must be organized by TPA:
```
@SRC/
├── provider_a/
│   └── claims-20240301.csv
├── provider_b/
│   └── claims-20240115.csv
└── provider_e/
    └── pharmacy-claims-20240201.csv
```

### Viewing Raw Data

1. Navigate to **📋 Raw Data Viewer**
2. Select TPA from sidebar
3. Select file from dropdown
4. View sample data (first 100 records)

### Task Management

1. Navigate to **⚙️ Task Management**
2. View task status
3. Resume or suspend tasks as needed

**Quick Actions:**
- **🔍 Discover Files**: Manually trigger file discovery
- **▶️ Process Queue**: Manually process pending files

## Silver Layer Usage

### Defining Target Schemas

1. Open Silver Transformation Manager
2. Select TPA from sidebar
3. Navigate to **🎯 Target Table Designer**
4. Define table schema:
   - Table name
   - Column names
   - Data types
   - Nullable flags
   - Descriptions

### Creating Field Mappings

**Method 1: Manual CSV**
1. Prepare CSV with mappings
2. Upload to `@SILVER_CONFIG`
3. Load via procedure

**Method 2: ML Pattern Matching**
1. Navigate to **🗺️ Field Mapper**
2. Select "ML Auto-Mapping"
3. Set confidence threshold
4. Review and approve suggestions

**Method 3: LLM Cortex AI**
1. Navigate to **🗺️ Field Mapper**
2. Select "LLM Mapping"
3. Choose Cortex AI model
4. Review and approve suggestions

### Defining Transformation Rules

1. Navigate to **📜 Rules Engine**
2. Create new rule:
   - Rule ID and name
   - Rule type (DATA_QUALITY, BUSINESS_LOGIC, etc.)
   - Target table/column
   - Rule logic (SQL expression)
   - Error action (REJECT, QUARANTINE, FLAG, CORRECT)

### Running Transformations

1. Navigate to **🔄 Transformation Monitor**
2. Select source and target tables
3. Select TPA
4. Configure options:
   - Batch size
   - Apply rules (yes/no)
   - Incremental (yes/no)
5. Click **Run Transformation**
6. Monitor progress

### Viewing Transformed Data

1. Navigate to **📊 Data Viewer**
2. Select TPA and table
3. View transformed records
4. Check quality metrics

## TPA Management

### Adding New TPA

```sql
CALL add_tpa('provider_f', 'Provider F Healthcare', 'Vision claims provider');
```

### Deactivating TPA

```sql
CALL deactivate_tpa('provider_f');
```

### Viewing TPA Statistics

```sql
SELECT * FROM v_tpa_statistics;
```

## Monitoring & Troubleshooting

### Common Issues

**Issue: File not discovered**
- Solution: Check file is in correct TPA folder
- Manually trigger: Click **🔍 Discover Files**

**Issue: File processing failed**
- Solution: Check error message in processing queue
- View failed files: Navigate to **📊 Processing Status**

**Issue: Transformation failed**
- Solution: Check quarantine records
- Review error messages in processing log

### Key Queries

```sql
-- View processing status
SELECT * FROM v_processing_status_summary;

-- View failed files
SELECT * FROM v_failed_files;

-- View quarantine records
SELECT * FROM quarantine_records ORDER BY quarantine_timestamp DESC LIMIT 10;

-- View transformation logs
SELECT * FROM silver_processing_log ORDER BY start_timestamp DESC LIMIT 20;
```

## Best Practices

1. **File Naming**: Use descriptive, date-based names
2. **Batch Uploads**: Upload 10-20 files at a time
3. **Monitor Processing**: Check status between batches
4. **Test First**: Upload small sample before full dataset
5. **Validate Mappings**: Review ML/LLM suggestions carefully
6. **Define Rules**: Start with data quality rules
7. **Incremental Processing**: Use watermarks for large datasets

## TPA (Multi-Tenant) Architecture

### What is TPA?

TPA (Third Party Administrator) enables complete multi-tenant isolation where different healthcare providers can have:
- Different schemas and field mappings
- Different transformation rules
- Separate data tables
- Independent processing pipelines

### TPA Naming Convention

**TPA Codes**: Lowercase with underscores (e.g., `provider_a`, `blue_cross`)

**Target Tables**: `{TABLE_NAME}_{TPA}` (e.g., `CLAIMS_PROVIDER_A`)

**File Paths**: `@SRC/{tpa}/{filename}`

### TPA Data Flow

1. **File Upload**: Select TPA → Upload file → Stored in `@SRC/{tpa}/`
2. **Bronze Processing**: TPA extracted from path → Stored in `RAW_DATA_TABLE.TPA`
3. **Silver Configuration**: Select TPA in UI → All operations filtered by TPA
4. **Field Mapping**: Mappings defined per TPA
5. **Transformation**: Rules applied per TPA
6. **Target Tables**: TPA-specific tables created

### Managing TPAs

**Add TPA**:
1. Go to Admin > TPA Management
2. Click "Add TPA"
3. Enter TPA code, name, and description
4. Click "Create"

**View TPAs**: All pages have TPA selector at the top

**TPA Isolation**: Each TPA has completely separate:
- Field mappings
- Target schemas
- Transformation rules
- Data tables

---

## Related Documentation

- [Documentation Hub](README.md) - Complete documentation index
- [Quick Start Guide](../QUICK_START.md) - Get running in 10 minutes
- [Architecture](ARCHITECTURE.md) - System design and data flow
- [Bronze README](../bronze/README.md) - Bronze layer details
- [Silver README](../silver/README.md) - Silver layer details
- [Deployment Guide](../deployment/README.md) - Deployment documentation

---

**Version**: 2.0  
**Last Updated**: January 31, 2026
