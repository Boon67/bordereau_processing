# Deployment Guide

**Complete deployment guide for Bordereau Processing Pipeline**

> **📖 Full documentation**: [docs/README.md](../docs/README.md) | **⚡ Quick commands**: [docs/QUICK_REFERENCE.md](../docs/QUICK_REFERENCE.md)

---

## Quick Start

### Deploy Everything (Bronze + Silver + Gold)

**Linux/Mac:**
```bash
cd deployment && ./deploy.sh
```

**Windows (Git Bash):**
```bash
cd deployment && ./deploy.sh  # Works in Git Bash!
```

**Windows (CMD):**
```cmd
cd deployment && deploy.bat
```

### Deploy Container Services (Recommended)

**Prerequisites** (one-time, requires ACCOUNTADMIN):
```bash
snow sql -f bronze/0_Setup_Container_Privileges.sql \
  --connection default \
  -D DATABASE_NAME=BORDEREAU_PROCESSING_PIPELINE
```

**Deploy:**
```bash
cd deployment && ./deploy_container.sh
```

**Access**: `https://<your-service>.snowflakecomputing.app`

---

## Deployment Scripts

| Script | Purpose | Use When |
|--------|---------|----------|
| `deploy.sh` | Deploy all layers (Bronze + Silver + Gold) | First-time setup or full redeploy |
| `deploy_bronze.sh` | Bronze layer only | Updating ingestion logic |
| `deploy_silver.sh` | Silver layer only | Updating transformations |
| `deploy_gold.sh` | Gold layer only | Updating analytics |
| `deploy_container.sh` | Backend + Frontend to SPCS | Deploying web application |
| `manage_services.sh` | Service management | Start/stop/restart services |
| `undeploy.sh` | Remove all resources | Cleanup or reset |

---

## Configuration

### Default Configuration

Edit `default.config` or create `custom.config`:

```bash
# Snowflake Connection
SNOWFLAKE_CONNECTION=""              # Leave empty for default
SNOWFLAKE_ROLE="SYSADMIN"
SNOWFLAKE_WAREHOUSE="COMPUTE_WH"

# Database
DATABASE_NAME="BORDEREAU_PROCESSING_PIPELINE"
BRONZE_SCHEMA_NAME="BRONZE"
SILVER_SCHEMA_NAME="SILVER"

# Container Services
SERVICE_NAME="BORDEREAU_APP"
COMPUTE_POOL_NAME="BORDEREAU_COMPUTE_POOL"
REPOSITORY_NAME="BORDEREAU_REPOSITORY"

# Deployment Options
DEPLOY_BRONZE="true"
DEPLOY_SILVER="true"
DEPLOY_CONTAINERS="true"
LOAD_SAMPLE_SCHEMAS="true"
AUTO_RESUME_TASKS="true"
```

### Custom Configuration

```bash
# Create custom config
cp custom.config.example custom.config

# Edit with your settings
nano custom.config

# Deploy with custom config
./deploy.sh
```

---

## Windows Deployment

### Prerequisites

1. **Git Bash** (recommended) - Comes with [Git for Windows](https://git-scm.com/download/win)
2. **Snowflake CLI**: `pip install snowflake-cli-labs`
3. **Python 3.8+**: [python.org](https://www.python.org/downloads/)
4. **jq**: Download from [stedolan.github.io/jq](https://stedolan.github.io/jq/download/)

### Path Handling

Scripts automatically detect Windows and handle paths correctly:
- ✅ **Git Bash** (recommended) - Full support
- ✅ **WSL** - Full support
- ✅ **MSYS2** - Full support
- ❌ **PowerShell** - Use Git Bash instead
- ❌ **CMD** - Use `.bat` scripts or Git Bash

### Common Issues

**Issue**: `bash: ./deploy.sh: Permission denied`
```bash
chmod +x deployment/*.sh
```

**Issue**: Line ending errors (CRLF)
```bash
git config core.autocrlf false
git rm --cached -r .
git reset --hard
```

**Issue**: `jq: command not found`
- Download `jq.exe` from [stedolan.github.io/jq](https://stedolan.github.io/jq/download/)
- Place in `C:\Program Files\Git\usr\bin\`

---

## Service Management

### Check Status

```bash
./manage_services.sh status
```

### View Logs

```bash
./manage_services.sh logs backend 100
./manage_services.sh logs frontend 50
```

### Restart Services

```bash
./manage_services.sh restart
```

### Restart with New Image

```bash
./manage_services.sh restart-image backend
```

---

## Authentication Setup

### Snow CLI (Development)

```bash
snow connection add --connection-name default
```

### PAT Token (Production)

```bash
# Generate token in Snowflake UI: User > My Profile > Password
export SNOWFLAKE_PASSWORD="your-pat-token"
```

### Keypair (Most Secure)

```bash
# Generate keypair
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

# Configure in Snowflake
snow sql -f configure_keypair_auth.sql
```

See [backend/README.md](../backend/README.md) for detailed auth setup.

---

## Troubleshooting

### Deployment Fails

**Check connection:**
```bash
./check_snow_connection.sh
```

**Verify privileges:**
```sql
SHOW GRANTS TO ROLE SYSADMIN;
```

**Check logs:**
```bash
cat logs/deploy_*.log
```

### Service Won't Start

**Check service status:**
```bash
./manage_services.sh status
```

**View service logs:**
```bash
./manage_services.sh logs backend 200
```

**Verify compute pool:**
```sql
SHOW COMPUTE POOLS;
DESC COMPUTE POOL BORDEREAU_COMPUTE_POOL;
```

### Container Image Issues

**Rebuild and push:**
```bash
# Backend
docker build -f docker/Dockerfile.backend -t backend:latest .
docker tag backend:latest <registry>/backend:latest
docker push <registry>/backend:latest

# Restart service
./manage_services.sh restart-image backend
```

### Task Issues

**Resume tasks:**
```bash
snow sql -f resume_tasks.sql
```

**Check task status:**
```bash
snow sql -f check_task_status.sql
```

---

## Advanced Configuration

### Custom Warehouse

```bash
# In custom.config
SNOWFLAKE_WAREHOUSE="COMPUTE_WH_LARGE"
```

### Custom Schemas

```bash
# In custom.config
BRONZE_SCHEMA_NAME="BRONZE_DEV"
SILVER_SCHEMA_NAME="SILVER_DEV"
```

### Skip Components

```bash
# In custom.config
DEPLOY_BRONZE="false"      # Skip Bronze layer
DEPLOY_SILVER="true"       # Deploy Silver only
LOAD_SAMPLE_SCHEMAS="false" # Skip sample data
```

### Environment-Specific Deployment

```bash
# Development
./deploy.sh DEV

# Production
./deploy.sh PROD ../configs/production.config
```

---

## Verification

### Check Database

```sql
SHOW DATABASES LIKE 'BORDEREAU_PROCESSING_PIPELINE';
SHOW SCHEMAS IN DATABASE BORDEREAU_PROCESSING_PIPELINE;
```

### Check Tables

```sql
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
SHOW TABLES IN SCHEMA BRONZE;
SHOW TABLES IN SCHEMA SILVER;
SHOW TABLES IN SCHEMA GOLD;
```

### Check Services

```sql
SHOW SERVICES;
CALL SYSTEM$GET_SERVICE_STATUS('BORDEREAU_PROCESSING_PIPELINE.PUBLIC.BORDEREAU_APP');
```

### Test API

```bash
# Health check
curl https://<your-service>.snowflakecomputing.app/api/health

# List TPAs
curl https://<your-service>.snowflakecomputing.app/api/tpas
```

---

## Undeployment

### Remove Everything

```bash
./undeploy.sh
```

### Remove Services Only

```sql
DROP SERVICE IF EXISTS BORDEREAU_APP;
DROP COMPUTE POOL IF EXISTS BORDEREAU_COMPUTE_POOL;
DROP IMAGE REPOSITORY IF EXISTS BORDEREAU_REPOSITORY;
```

### Remove Database

```sql
DROP DATABASE IF EXISTS BORDEREAU_PROCESSING_PIPELINE;
```

---

## Best Practices

### Development
✅ Use Snow CLI for authentication  
✅ Deploy to DEV environment first  
✅ Test with sample data  
✅ Review logs regularly  
❌ Don't deploy directly to production

### Production
✅ Use PAT token or keypair auth  
✅ Use custom configuration file  
✅ Enable task auto-resume  
✅ Monitor service status  
✅ Regular backups of configuration

### Windows
✅ Use Git Bash for best compatibility  
✅ Check line endings (LF not CRLF)  
✅ Install jq before deploying  
✅ Use forward slashes in paths  
❌ Don't use PowerShell for deployment scripts

---

## Documentation

**Quick Access**:
- [Quick Reference](../docs/QUICK_REFERENCE.md) - One-page cheat sheet
- [Architecture](../docs/ARCHITECTURE.md) - System design
- [User Guide](../docs/USER_GUIDE.md) - Usage instructions
- [Backend README](../backend/README.md) - API and authentication

**Layer Docs**:
- [Bronze Layer](../bronze/README.md) - File ingestion
- [Silver Layer](../silver/README.md) - Transformations
- [Gold Layer](../gold/README.md) - Analytics

---

## Support

**Common Commands**:
```bash
# Check status
./manage_services.sh status

# View logs
./manage_services.sh logs backend 100

# Restart service
./manage_services.sh restart

# Test connection
./check_snow_connection.sh

# Full redeploy
./deploy.sh
```

**Get Help**:
1. Check [Quick Reference](../docs/QUICK_REFERENCE.md)
2. Review error messages in logs
3. Verify configuration in `default.config`
4. Check Snowflake permissions

---

**Version**: 3.1 | **Updated**: Jan 31, 2026 | **Status**: ✅ Production Ready
