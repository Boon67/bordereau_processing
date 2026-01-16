# Quick Start Guide

**Get the Snowflake File Processing Pipeline running in 10 minutes!**

## Prerequisites

Before you begin, ensure you have:

- ✅ Snowflake account with `SYSADMIN` or `ACCOUNTADMIN` privileges
- ✅ Snowflake CLI (`snow`) installed ([Installation Guide](https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation))
- ✅ Bash shell (macOS/Linux native, Windows use Git Bash)
- ✅ Git installed

## Step 1: Clone Repository (1 minute)

```bash
git clone <repository_url>
cd file_processing_pipeline
```

## Step 2: Configure Connection (2 minutes)

Create your custom configuration:

```bash
cp custom.config.example custom.config
```

Edit `custom.config` with your Snowflake credentials:

```bash
# Required settings
SNOWFLAKE_ACCOUNT="abc12345.us-east-1"
SNOWFLAKE_USER="your_username"
SNOWFLAKE_PASSWORD="your_password"
SNOWFLAKE_ROLE="SYSADMIN"
SNOWFLAKE_WAREHOUSE="COMPUTE_WH"

# Optional - use defaults or customize
DATABASE_NAME="FILE_PROCESSING_PIPELINE"
BRONZE_SCHEMA_NAME="BRONZE"
SILVER_SCHEMA_NAME="SILVER"
```

## Step 3: Deploy Application (5 minutes)

Run the master deployment script:

```bash
./deploy.sh
```

This will:
- ✅ Create database and schemas
- ✅ Set up RBAC roles (ADMIN, READWRITE, READONLY)
- ✅ Deploy Bronze layer (stages, tables, procedures, tasks)
- ✅ Deploy Silver layer (metadata tables, procedures, tasks)
- ✅ Deploy backend and frontend applications
- ✅ Load sample configurations

**Expected Output:**
```
╔═══════════════════════════════════════════════════════════╗
║     SNOWFLAKE FILE PROCESSING PIPELINE DEPLOYMENT         ║
╚═══════════════════════════════════════════════════════════╝

🥉 Deploying Bronze Layer...
✓ Bronze layer deployed successfully

🥈 Deploying Silver Layer...
✓ Silver layer deployed successfully

╔═══════════════════════════════════════════════════════════╗
║                  DEPLOYMENT SUMMARY                       ║
╠═══════════════════════════════════════════════════════════╣
║  Database: FILE_PROCESSING_PIPELINE                       ║
║  Bronze Layer: ✓ Deployed                                 ║
║  Silver Layer: ✓ Deployed                                 ║
║  Duration: 4m 32s                                         ║
╚═══════════════════════════════════════════════════════════╝
```

## Step 4: Start React + FastAPI Applications (1 minute)

### Option A: Local development (recommended)

```bash
# Backend
cd backend
pip install -r requirements.txt
cp .env.example .env
# Edit .env with SNOW_CONNECTION_NAME (snow CLI connection)
uvicorn app.main:app --reload --port 8000

# Frontend (new terminal)
cd frontend
npm install
npm run dev
```

Access:
- Frontend: `http://localhost:3000`
- API Docs: `http://localhost:8000/api/docs`

## Step 5: Upload Sample Data (1 minute)

1. Open the React frontend at `http://localhost:3000`
2. In the sidebar, select **📤 Upload Files**
3. Select TPA from dropdown (e.g., `provider_a`)
4. Drag and drop files from `sample_data/claims_data/provider_a/`
5. Click **Upload**
6. Navigate to **📊 Processing Status** to monitor progress

## Step 6: Configure Silver Mappings (Optional)

The sample data includes pre-configured mappings. To create your own:

1. Open the React frontend at `http://localhost:3000`
2. Select TPA from dropdown
3. Navigate to **🎯 Target Table Designer**
   - Define your target schema
4. Navigate to **🗺️ Field Mapper**
   - Use Manual CSV, ML Pattern Matching, or LLM Cortex AI
   - Approve mappings
5. Navigate to **🔄 Transformation Monitor**
   - Run transformation
   - Monitor progress

## Verification

### Verify Bronze Layer

```sql
USE DATABASE FILE_PROCESSING_PIPELINE;
USE SCHEMA BRONZE;

-- Check file processing queue
SELECT * FROM file_processing_queue ORDER BY discovered_timestamp DESC;

-- Check raw data
SELECT * FROM RAW_DATA_TABLE LIMIT 10;

-- Check task status
SHOW TASKS;
```

### Verify Silver Layer

```sql
USE SCHEMA SILVER;

-- Check target schemas
SELECT * FROM target_schemas;

-- Check field mappings
SELECT * FROM field_mappings WHERE approved = TRUE;

-- Check transformation rules
SELECT * FROM transformation_rules WHERE active = TRUE;
```

## Common Commands

### Start/Stop Tasks

```sql
-- Start Bronze tasks
ALTER TASK discover_files_task RESUME;

-- Start Silver tasks
CALL resume_all_silver_tasks();

-- Stop all tasks
ALTER TASK discover_files_task SUSPEND;
CALL suspend_all_silver_tasks();
```

### Manual Processing

```sql
-- Manually trigger file discovery
EXECUTE TASK discover_files_task;

-- Manually process queued files
CALL process_queued_files();

-- Manually run Silver transformation
CALL transform_bronze_to_silver(
    'RAW_DATA_TABLE',
    'CLAIMS_PROVIDER_A',
    'provider_a',
    'BRONZE',
    10000,
    TRUE,
    FALSE
);
```

## Troubleshooting

### Issue: Tasks not running

**Solution**: Check task privileges

```sql
USE ROLE ACCOUNTADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN WITH GRANT OPTION;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE FILE_PROCESSING_PIPELINE_ADMIN;
```

### Issue: Frontend not loading

**Solution**: Ensure React dev server is running

```bash
cd frontend
npm run dev
```

### Issue: File upload fails

**Solution**: Check stage permissions

```sql
USE ROLE FILE_PROCESSING_PIPELINE_ADMIN;
LIST @SRC;
```

### Issue: Transformation fails

**Solution**: Check quarantine records

```sql
SELECT * FROM quarantine_records ORDER BY quarantine_timestamp DESC LIMIT 10;
```

## Next Steps

- 📖 Read the [User Guide](docs/USER_GUIDE.md) for detailed usage instructions
- 🏗️ Review the [Architecture](docs/design/ARCHITECTURE.md) to understand the system design
- 🎓 Learn about [TPA Architecture](docs/guides/TPA_COMPLETE_GUIDE.md) for multi-tenant patterns
- 🧪 Review [Test Plans](docs/testing/TEST_PLAN_BRONZE.md) for comprehensive testing

## Cleanup

To completely remove the application:

```bash
./undeploy.sh
```

**Warning**: This will delete the database and all data!

## Support

- **Documentation**: See [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)
- **Troubleshooting**: Check [DEPLOYMENT_AND_OPERATIONS.md](docs/DEPLOYMENT_AND_OPERATIONS.md)
- **Architecture**: Review [ARCHITECTURE.md](docs/design/ARCHITECTURE.md)

---

**Congratulations!** 🎉 You now have a fully functional Snowflake File Processing Pipeline with Bronze and Silver layers, TPA support, and a modern React UI with FastAPI middleware.

**Version**: 1.0  
**Last Updated**: January 15, 2026
