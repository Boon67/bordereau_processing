# Container Deployment Guide

Quick reference for deploying to Snowpark Container Services.

## Quick Start

### Full Deployment (First Time)

```bash
cd deployment
./deploy_container.sh
```

### Service Only (Redeploy Without Rebuild)

```bash
cd deployment
./deploy_service_only.sh
```

---

## Common Issues

### "Failed to create stage"

**Windows Users:** Use SYSADMIN for container operations:

```bash
echo 'CONTAINER_ROLE="SYSADMIN"' > deployment/custom.config
./deploy_container.sh
```

**Or grant privileges:**
```sql
USE ROLE SYSADMIN;
GRANT ALL PRIVILEGES ON SCHEMA BORDEREAU_PROCESSING_PIPELINE.PUBLIC 
TO ROLE YOUR_ROLE;
```

### "File doesn't exist" (Windows Git Bash)

The script now auto-converts paths. If issues persist:

```bash
# Verify file exists
ls -la tmp/unified_service_spec.yaml

# Check path conversion in output
# Should show: z:/path/to/file (not /z/path/to/file)
```

### "Image not found"

Images must exist in repository. Run full deployment first:

```bash
./deploy_container.sh
```

---

## Configuration

Create `deployment/custom.config`:

```bash
# Essential settings
CONTAINER_ROLE="SYSADMIN"              # Use SYSADMIN for container ops
IMAGE_TAG="latest"                     # Or specific version

# Optional
SNOWFLAKE_CONNECTION="YOUR_CONNECTION"
DATABASE_NAME="BORDEREAU_PROCESSING_PIPELINE"
SERVICE_NAME="BORDEREAU_APP"
```

---

## Verification

```bash
# Check service status
snow spcs service status BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# View logs
snow spcs service logs BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --container-name frontend

# Get endpoint
snow spcs service describe BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

---

## Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `deploy_container.sh` | Full deployment | First time, image changes |
| `deploy_service_only.sh` | Service only | Config changes, redeploy |
| `manage_services.sh` | Manage running services | Start/stop/restart |

---

## Troubleshooting

**Check prerequisites:**
```bash
snow --version
docker --version
jq --version
```

**View detailed errors:**
```bash
# Check tmp directory
ls -la tmp/

# View SQL errors
cat tmp/create_service_error.log
```

**Reset and retry:**
```bash
# Drop service
snow sql -q "DROP SERVICE IF EXISTS BORDEREAU_APP" \
  --database BORDEREAU_PROCESSING_PIPELINE

# Redeploy
./deploy_container.sh
```

---

## See Also

- [DEPLOY.md](../DEPLOY.md) - Main deployment guide
- [README.md](../README.md) - Project overview
