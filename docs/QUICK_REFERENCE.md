# Quick Reference Guide

**One-page reference for Bordereau Processing Pipeline v3.1**

---

## 🚀 Quick Start

```bash
# Deploy everything
cd deployment && ./deploy.sh

# Start locally
./start.sh

# Access
Frontend: http://localhost:3000
Backend:  http://localhost:8000/api/docs
```

---

## 📊 Architecture

**Bronze** → Raw data ingestion, file processing  
**Silver** → Cleaned/transformed data, field mappings  
**Gold** → Analytics, aggregations, member journeys

**Auth**: OAuth with caller's rights (user-level permissions)  
**Deployment**: Snowpark Container Services or local Docker

---

## 🔧 Common Operations

### Upload Files
1. Select TPA → Upload Files
2. Drag/drop CSV or Excel
3. Monitor in Processing Status

### Create Mappings
1. Silver → Field Mappings
2. Select TPA + Target Table
3. Choose method: Manual / ML / LLM
4. **Validate** before transforming

### Run Transformation
1. Silver → Transform
2. Select source/target tables
3. System auto-validates mappings
4. Execute transformation
5. View results with record count

### Manage TPAs
1. Bronze → TPA Management
2. Add/Edit/Delete TPAs
3. TPA Code must be unique
4. Creates isolated data structures

---

## ✅ Validation System (New in v3.1)

**Before Creating Mappings**:
- Checks for duplicate target columns
- Validates columns exist in physical table
- Returns clear error messages

**Before Transformations**:
- Auto-validates all approved mappings
- Fails fast if issues detected
- Prevents wasted compute

**Manual Validation**:
```
GET /api/silver/mappings/validate?tpa=provider_a&target_table=CLAIMS
```

---

## 📋 Metadata Columns (Silver)

Every Silver table includes 7 metadata columns:

| Column | Purpose |
|--------|---------|
| `_RECORD_ID` | Merge key, links to Bronze |
| `_FILE_NAME` | Source file name |
| `_FILE_ROW_NUMBER` | Row in source file |
| `_TPA` | TPA code |
| `_BATCH_ID` | Transformation batch |
| `_LOAD_TIMESTAMP` | When processed |
| `_LOADED_BY` | Who processed |

**Use Case**: Complete data lineage from Bronze → Silver

---

## 🔍 Monitoring

### Logs (Snowflake Tables)
- `BRONZE.APPLICATION_LOGS` - App logs
- `BRONZE.API_REQUEST_LOGS` - HTTP requests
- `BRONZE.ERROR_LOGS` - Errors with stack traces

### Processing Status
- Bronze → Processing Status
- View queue, success/fail counts
- Check error messages

### Task Management
- Bronze → Task Management
- Resume/suspend automated tasks
- View task schedules

---

## 🐛 Troubleshooting

### Transformation Fails
1. Check validation: `GET /api/silver/mappings/validate`
2. Verify mappings exist and are approved
3. Check target table has required columns
4. Review `SILVER.SILVER_PROCESSING_LOG`

### No Data After Transform
- Verify source data exists in Bronze
- Check TPA filter matches data
- Ensure mappings are approved
- Look for errors in processing log

### 500 Errors
- Check backend logs: `./deployment/manage_services.sh logs backend 50`
- Review `ERROR_LOGS` table
- Verify Snowflake connection
- Check user permissions

### File Upload Issues
- Verify TPA exists in `TPA_MASTER`
- Check file format (CSV/Excel)
- Ensure proper column headers
- Review `FILE_PROCESSING_QUEUE`

---

## 🔐 Authentication

**Local Development**: Snow CLI (automatic)  
**Production**: PAT Token or Keypair  
**Container**: OAuth with SPCS ingress token

See `backend/README.md` for setup details.

---

## 📁 Key Files

**Config**:
- `deployment/default.config` - Deployment settings
- `backend/config.toml` - Backend auth config

**SQL**:
- `bronze/*.sql` - Bronze layer setup
- `silver/*.sql` - Silver layer setup
- `gold/*.sql` - Gold layer setup

**Code**:
- `backend/app/api/` - API endpoints
- `frontend/src/pages/` - UI pages
- `backend/app/services/snowflake_service.py` - Snowflake connector

---

## 🎯 Best Practices

### Field Mappings
✅ Validate mappings before transforming  
✅ Use descriptive mapping names  
✅ Approve only verified mappings  
✅ One source field → one target column  
❌ Don't map to non-existent columns

### Transformations
✅ Start with small batch sizes (1000)  
✅ Test with single TPA first  
✅ Review results before production  
✅ Re-running is safe (MERGE-based)  
❌ Don't transform without validation

### TPA Management
✅ Use consistent naming (lowercase)  
✅ Document TPA purpose/description  
✅ Test with sample data first  
❌ Don't delete TPAs with active data

### Data Quality
✅ Monitor processing logs regularly  
✅ Check metadata columns for lineage  
✅ Validate source data quality  
✅ Use transformation rules for cleaning  
❌ Don't skip validation steps

---

## 📚 Documentation

**Quick Access**:
- [README](../README.md) - Project overview
- [QUICK_START](../QUICK_START.md) - 10-min setup
- [ARCHITECTURE](ARCHITECTURE.md) - System design
- [USER_GUIDE](USER_GUIDE.md) - Complete guide
- [CHANGELOG](CHANGELOG.md) - Recent updates

**Guides**:
- [Silver Metadata](guides/SILVER_METADATA_COLUMNS.md)
- [TPA Guide](guides/TPA_COMPLETE_GUIDE.md)
- [Table Editor](guides/TABLE_EDITOR_APPLICATION_GUIDE.md)

**Deployment**:
- [Deployment Guide](../deployment/README.md)
- [Backend Setup](../backend/README.md)

---

## 🆘 Support

**Check First**:
1. Review error message carefully
2. Check validation endpoint
3. Review processing logs
4. Verify permissions

**Common Solutions**:
- Restart service: `./deployment/manage_services.sh restart`
- Check status: `./deployment/manage_services.sh status`
- View logs: `./deployment/manage_services.sh logs backend 100`
- Test connection: `snow connection test`

**Documentation**: All issues and solutions documented in [CHANGELOG](CHANGELOG.md)

---

**Version**: 3.1 | **Updated**: Jan 31, 2026 | **Status**: ✅ Production Ready
