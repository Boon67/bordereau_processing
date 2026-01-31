# Bronze Layer

**Raw data ingestion and file processing**

---

## Overview

The Bronze layer handles:
- File upload to Snowflake stages
- Automatic file discovery and processing
- Raw data storage in JSON format
- TPA (Third Party Administrator) management
- Multi-tenant data isolation

---

## Quick Start

### Deploy Bronze Layer

```bash
cd deployment
./deploy_bronze.sh
```

### Upload Files

1. Open UI → Bronze → Upload Files
2. Select TPA
3. Drag/drop CSV or Excel files
4. Monitor in Processing Status

### View Raw Data

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
SELECT * FROM BRONZE.RAW_DATA_TABLE LIMIT 100;
```

---

## Key Tables

| Table | Purpose |
|-------|---------|
| `TPA_MASTER` | TPA registry |
| `RAW_DATA_TABLE` | Raw JSON data from files |
| `FILE_PROCESSING_QUEUE` | File processing status |
| `APPLICATION_LOGS` | Application logs |
| `API_REQUEST_LOGS` | HTTP request logs |
| `ERROR_LOGS` | Error tracking |

---

## SQL Files

| File | Purpose |
|------|---------|
| `0_Setup_Container_Privileges.sql` | ACCOUNTADMIN setup (one-time) |
| `0_Setup_Logging.sql` | Create logging tables |
| `1_Setup_Database_Roles.sql` | Create roles and permissions |
| `2_Bronze_Schema_Tables.sql` | Create Bronze tables |
| `3_Bronze_Setup_Logic.sql` | Create procedures and functions |
| `4_Bronze_Tasks.sql` | Create automated tasks |
| `TPA_Management.sql` | TPA CRUD procedures |

---

## Documentation

**Quick Reference**: [docs/QUICK_REFERENCE.md](../docs/QUICK_REFERENCE.md)  
**Architecture**: [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)  
**User Guide**: [docs/USER_GUIDE.md](../docs/USER_GUIDE.md)  
**Deployment**: [deployment/README.md](../deployment/README.md)

---

**Version**: 3.1 | **Status**: ✅ Production Ready
