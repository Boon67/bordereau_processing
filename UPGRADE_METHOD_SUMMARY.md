# Service Upgrade Method - Best Practices

**Date**: January 21, 2026  
**Recommended Method**: `snow spcs service upgrade`

---

## Overview

When updating Snowpark Container Services with new images, use the `snow spcs service upgrade` command instead of dropping and recreating the service.

---

## Why Use Upgrade Instead of Drop/Recreate?

### ✅ Benefits of `snow spcs service upgrade`

1. **Preserves Configuration**
   - Service settings remain intact
   - No need to reconfigure endpoints
   - Maintains service history

2. **Cleaner Operation**
   - Single command to update spec
   - No risk of losing service metadata
   - Easier to script and automate

3. **Less Disruptive**
   - Shorter downtime
   - Predictable upgrade process
   - Better for production environments

4. **Faster Deployment**
   - No need to recreate compute pool associations
   - Quicker startup time
   - Maintains warm connections

### ❌ Issues with Drop/Recreate

- Loses service configuration
- Requires recreating all associations
- Longer downtime
- More error-prone
- Harder to rollback

---

## Upgrade Process

### Automated Script (Recommended)

```bash
cd deployment
./upgrade_service.sh
```

### Manual Steps

```bash
# 1. Suspend service
snow spcs service suspend BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# 2. Wait for suspension
sleep 10

# 3. Upgrade with new spec
snow spcs service upgrade BORDEREAU_APP \
  --spec-path /path/to/spec.yaml \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# 4. Resume service
snow spcs service resume BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

---

## Complete Deployment Workflow

### Step 1: Build New Image

```bash
cd /path/to/project

# Build for amd64 platform (required for SPCS)
docker build --platform linux/amd64 \
  -f docker/Dockerfile.backend \
  -t backend:latest .
```

### Step 2: Tag and Push

```bash
# Tag for Snowflake registry
docker tag backend:latest \
  ACCOUNT.registry.snowflakecomputing.com/DATABASE/SCHEMA/REPO/backend:latest

# Login to registry
snow spcs image-registry login

# Push image
docker push \
  ACCOUNT.registry.snowflakecomputing.com/DATABASE/SCHEMA/REPO/backend:latest
```

### Step 3: Upgrade Service

```bash
# Use automated script
./deployment/upgrade_service.sh

# Or manually with suspend/upgrade/resume
```

### Step 4: Verify

```bash
# Check status
snow spcs service status BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# Check logs
snow spcs service logs BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --container-name backend \
  --instance-id 0 \
  --num-lines 50
```

---

## Service Specification File

Create or update your service spec file:

```yaml
spec:
  containers:
  - name: backend
    image: /DATABASE/SCHEMA/REPO/BACKEND:latest
    env:
      ENVIRONMENT: production
      SNOWFLAKE_ROLE: SYSADMIN
      SNOWFLAKE_WAREHOUSE: COMPUTE_WH
      DATABASE_NAME: BORDEREAU_PROCESSING_PIPELINE
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
    image: /DATABASE/SCHEMA/REPO/FRONTEND:latest
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
  - name: app
    port: 80
    public: true
```

---

## Monitoring Upgrade

### Check Service Status

```bash
# Watch service status
watch -n 5 'snow spcs service status BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC'
```

### Expected Timeline

1. **0s** - Suspend command issued
2. **5-10s** - Service suspended
3. **10s** - Upgrade command issued
4. **12s** - Spec updated
5. **15s** - Resume command issued
6. **20-30s** - Containers starting
7. **30-60s** - Readiness probes passing
8. **60s** - Service READY ✅

---

## Troubleshooting

### Service Won't Suspend

```bash
# Check if service is already suspended
snow spcs service status BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# Force suspend if needed
snow sql -q "ALTER SERVICE BORDEREAU_PROCESSING_PIPELINE.PUBLIC.BORDEREAU_APP SUSPEND"
```

### Upgrade Fails

```bash
# Check spec file syntax
cat /path/to/spec.yaml

# Verify image exists
snow spcs image-repository list-images REPO \
  --database DATABASE \
  --schema SCHEMA

# Resume with old spec if needed
snow spcs service resume BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

### Service Won't Resume

```bash
# Check compute pool
snow spcs compute-pool status POOL_NAME

# Check logs for errors
snow spcs service logs BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --container-name backend \
  --instance-id 0 \
  --num-lines 100
```

---

## Rollback Strategy

If upgrade fails, you can rollback:

### Option 1: Resume with Old Spec

```bash
# Service will use previous spec
snow spcs service resume BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

### Option 2: Upgrade to Previous Version

```bash
# Suspend
snow spcs service suspend BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# Upgrade to old spec
snow spcs service upgrade BORDEREAU_APP \
  --spec-path /path/to/old-spec.yaml \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# Resume
snow spcs service resume BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

---

## Best Practices

### 1. Version Your Images

Instead of using `:latest`, use specific versions:

```bash
docker tag backend:latest backend:v1.2.3
docker push REGISTRY/backend:v1.2.3
```

Update spec to reference specific version:

```yaml
image: /DATABASE/SCHEMA/REPO/BACKEND:v1.2.3
```

### 2. Test in Non-Production First

```bash
# Test in dev environment
./deployment/upgrade_service.sh \
  --database DEV_DATABASE \
  --schema DEV_SCHEMA \
  --service DEV_SERVICE

# Then deploy to production
./deployment/upgrade_service.sh
```

### 3. Keep Spec Files in Version Control

```bash
# Commit spec changes
git add docker/service-spec.yaml
git commit -m "Update service spec for v1.2.3"
git push
```

### 4. Monitor After Upgrade

```bash
# Watch for 5 minutes after upgrade
for i in {1..30}; do
  echo "Check $i/30"
  snow spcs service status BORDEREAU_APP \
    --database BORDEREAU_PROCESSING_PIPELINE \
    --schema PUBLIC | grep -E "backend|READY"
  sleep 10
done
```

---

## Automation

### CI/CD Integration

```yaml
# Example GitHub Actions workflow
name: Deploy to SPCS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Build Docker image
        run: |
          docker build --platform linux/amd64 \
            -f docker/Dockerfile.backend \
            -t backend:${{ github.sha }} .
      
      - name: Push to Snowflake
        run: |
          snow spcs image-registry login
          docker tag backend:${{ github.sha }} \
            $REGISTRY/backend:${{ github.sha }}
          docker push $REGISTRY/backend:${{ github.sha }}
      
      - name: Upgrade service
        run: |
          ./deployment/upgrade_service.sh
```

---

## Reference

### Official Documentation

- [snow spcs service upgrade](https://docs.snowflake.com/en/developer-guide/snowflake-cli/command-reference/spcs-commands/service-commands/upgrade)
- [Snowpark Container Services](https://docs.snowflake.com/en/developer-guide/snowpark-container-services)

### Related Scripts

- `deployment/upgrade_service.sh` - Automated upgrade script
- `deployment/deploy_container.sh` - Initial deployment
- `deployment/manage_services.sh` - Service management utilities

---

## Quick Reference

```bash
# Build
docker build --platform linux/amd64 -f docker/Dockerfile.backend -t backend:latest .

# Push
docker tag backend:latest REGISTRY/backend:latest
docker push REGISTRY/backend:latest

# Upgrade
./deployment/upgrade_service.sh

# Verify
snow spcs service status BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

---

**Last Updated**: January 21, 2026  
**Status**: ✅ Recommended Method for All Service Updates
