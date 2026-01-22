# Docker Configuration

This directory contains Docker and Snowpark Container Services configuration files.

---

## Files

### Dockerfiles

- **`Dockerfile.backend`** - Backend FastAPI application
- **`Dockerfile.frontend`** - Frontend React application with nginx
- **`nginx.conf`** - Nginx configuration for frontend (proxies `/api/*` to backend)

### Service Specification

- **`snowpark-spec.yaml`** - Template for Snowpark Container Services specification

---

## Snowpark Container Services Specification

### Template vs. Actual Deployment

The `snowpark-spec.yaml` file is a **template** that shows the structure of the service specification. During actual deployment, the `deploy_container.sh` script generates the real specification with values from your configuration files.

### Template Variables

The template uses these placeholders:

```yaml
image: /<DATABASE_NAME>/<SCHEMA_NAME>/<REPOSITORY_NAME>/<IMAGE_NAME>:latest
```

These are replaced during deployment with actual values from `deployment/default.config` or `deployment/custom.config`:

| Template Variable | Config Variable | Default Value | Example |
|------------------|-----------------|---------------|---------|
| `<DATABASE_NAME>` | `DATABASE_NAME` | `BORDEREAU_PROCESSING_PIPELINE` | Database where service runs |
| `<SCHEMA_NAME>` | `SCHEMA_NAME` | `PUBLIC` | Schema for SPCS objects |
| `<REPOSITORY_NAME>` | `REPOSITORY_NAME` | `BORDEREAU_REPOSITORY` | Image repository name |
| `<BACKEND_IMAGE_NAME>` | `BACKEND_IMAGE_NAME` | `bordereau_backend` | Backend image name |
| `<FRONTEND_IMAGE_NAME>` | `FRONTEND_IMAGE_NAME` | `bordereau_frontend` | Frontend image name |

### Example: Actual Image Path

With default configuration, the backend image path becomes:

```yaml
image: /BORDEREAU_PROCESSING_PIPELINE/PUBLIC/BORDEREAU_REPOSITORY/BORDEREAU_BACKEND:latest
```

This corresponds to the Snowflake registry path:

```
ACCOUNT.registry.snowflakecomputing.com/bordereau_processing_pipeline/public/bordereau_repository/bordereau_backend:latest
```

---

## Building Docker Images

### Backend

```bash
# Build for SPCS (requires linux/amd64)
docker build --platform linux/amd64 \
  -f docker/Dockerfile.backend \
  -t bordereau_backend:latest \
  .
```

### Frontend

```bash
# Build for SPCS (requires linux/amd64)
docker build --platform linux/amd64 \
  -f docker/Dockerfile.frontend \
  -t bordereau_frontend:latest \
  .
```

### Platform Requirements

⚠️ **Important**: Snowpark Container Services requires `linux/amd64` architecture.

- Always use `--platform linux/amd64` when building images for SPCS
- Mac M1/M2 builds `arm64` by default - you must specify the platform
- Without the platform flag, deployment will fail with architecture error

---

## Deployment

### Automated Deployment

Use the deployment script which handles everything:

```bash
cd deployment
./deploy_container.sh
```

This script will:
1. Build Docker images with correct platform
2. Tag images with registry path
3. Push to Snowflake registry
4. Generate service specification from template
5. Create/update SPCS service

### Manual Deployment

If you need to deploy manually:

```bash
# 1. Build images
docker build --platform linux/amd64 -f docker/Dockerfile.backend -t backend:latest .
docker build --platform linux/amd64 -f docker/Dockerfile.frontend -t frontend:latest .

# 2. Tag for Snowflake registry
REGISTRY="account.registry.snowflakecomputing.com/database/schema/repo"
docker tag backend:latest $REGISTRY/backend:latest
docker tag frontend:latest $REGISTRY/frontend:latest

# 3. Login and push
snow spcs image-registry login
docker push $REGISTRY/backend:latest
docker push $REGISTRY/frontend:latest

# 4. Create service spec (replace placeholders)
# Edit snowpark-spec.yaml with actual values

# 5. Create service
snow spcs service create SERVICE_NAME \
  --compute-pool POOL_NAME \
  --spec-path snowpark-spec.yaml \
  --database DATABASE_NAME \
  --schema SCHEMA_NAME
```

---

## Service Specification Details

### Container Configuration

#### Backend Container

```yaml
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
```

**Key Points:**
- Internal only (no public endpoint)
- Uses SPCS OAuth for Snowflake authentication
- Fast health check at `/api/health` (doesn't connect to Snowflake)
- 2Gi-4Gi memory for Snowflake connector

#### Frontend Container

```yaml
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
```

**Key Points:**
- Public endpoint (port 80)
- Nginx proxies `/api/*` requests to backend
- Serves React static files
- 1Gi-2Gi memory sufficient for nginx

### Endpoints

```yaml
endpoints:
  - name: app
    port: 80
    public: true
```

Only the frontend is publicly accessible. Backend is internal-only and accessed through the frontend proxy.

---

## Health Checks

### Backend Health Endpoints

The backend provides multiple health check endpoints:

1. **`/api/health`** - Fast basic health check (< 100ms)
   - Used by readiness probe
   - Returns service status without database check
   - Always returns 200 OK if service is running

2. **`/api/health/db`** - Detailed database health check (2-5s)
   - For monitoring and diagnostics
   - Connects to Snowflake and validates connection
   - Returns database status, warehouse, version

3. **`/api/health/ready`** - Readiness check
   - Quick check for service readiness
   - Can be extended with additional checks

### Why Separate Health Checks?

The readiness probe runs every 10 seconds. Connecting to Snowflake for each check:
- Takes 5-10 seconds per check
- Can timeout and fail the probe
- Wastes compute resources
- Causes unnecessary connection churn

By separating basic health from database health:
- ✅ Probe passes quickly and reliably
- ✅ Service starts faster
- ✅ Detailed health available when needed
- ✅ Better resource utilization

---

## Customization

### Using Custom Configuration

Create `deployment/custom.config` to override defaults:

```bash
# Copy example
cp deployment/default.config deployment/custom.config

# Edit values
nano deployment/custom.config
```

Example custom configuration:

```bash
# Custom SPCS configuration
SERVICE_NAME="MY_CUSTOM_APP"
COMPUTE_POOL_NAME="MY_COMPUTE_POOL"
REPOSITORY_NAME="MY_REPOSITORY"
DATABASE_NAME="MY_DATABASE"

# Custom image names
BACKEND_IMAGE_NAME="my_backend"
FRONTEND_IMAGE_NAME="my_frontend"
IMAGE_TAG="v1.0.0"  # Use specific version
```

### Environment-Specific Deployments

Deploy to different environments:

```bash
# Development
DATABASE_NAME="BORDEREAU_DEV" ./deployment/deploy_container.sh

# Staging
DATABASE_NAME="BORDEREAU_STAGING" ./deployment/deploy_container.sh

# Production
DATABASE_NAME="BORDEREAU_PROD" IMAGE_TAG="v1.0.0" ./deployment/deploy_container.sh
```

---

## Updating Services

### Using Upgrade Command (Recommended)

```bash
cd deployment
./upgrade_service.sh
```

This uses `snow spcs service upgrade` which:
- Preserves service configuration
- Updates specification cleanly
- Minimizes downtime
- Safer than drop/recreate

### Manual Upgrade

```bash
# 1. Build and push new images
docker build --platform linux/amd64 -f docker/Dockerfile.backend -t backend:latest .
docker push REGISTRY/backend:latest

# 2. Suspend service
snow spcs service suspend SERVICE_NAME --database DB --schema SCHEMA

# 3. Upgrade with new spec
snow spcs service upgrade SERVICE_NAME --spec-path spec.yaml --database DB --schema SCHEMA

# 4. Resume service
snow spcs service resume SERVICE_NAME --database DB --schema SCHEMA
```

---

## Troubleshooting

### Image Architecture Error

```
SPCS only supports image for amd64 architecture
```

**Solution**: Build with `--platform linux/amd64`:

```bash
docker build --platform linux/amd64 -f docker/Dockerfile.backend -t backend:latest .
```

### Readiness Probe Failing

```
Readiness probe is failing at path: /api/health
```

**Solution**: Check that:
1. Health endpoint returns 200 OK
2. Endpoint is fast (< 1 second)
3. Container is listening on correct port
4. No database connection in health check

### Image Not Found

```
Failed to retrieve image from repository
```

**Solution**: Verify image path matches repository:

```bash
# Check repository
snow spcs image-repository list-images REPO_NAME --database DB --schema SCHEMA

# Verify image path in spec matches repository structure
image: /DATABASE/SCHEMA/REPOSITORY/IMAGE_NAME:TAG
```

### Service Won't Start

```bash
# Check service status
snow spcs service status SERVICE_NAME --database DB --schema SCHEMA

# Check logs
snow spcs service logs SERVICE_NAME \
  --database DB \
  --schema SCHEMA \
  --container-name backend \
  --instance-id 0 \
  --num-lines 100
```

---

## Reference

### Related Documentation

- [Deployment Guide](../deployment/README.md)
- [Readiness Probe Fix](../deployment/fixes/READINESS_PROBE_FIX.md)
- [Upgrade Method](../UPGRADE_METHOD_SUMMARY.md)
- [Snowflake SPCS Docs](https://docs.snowflake.com/en/developer-guide/snowpark-container-services)

### Configuration Files

- `deployment/default.config` - Default configuration values
- `deployment/custom.config` - Custom overrides (create from default.config)
- `docker/snowpark-spec.yaml` - Service specification template

### Deployment Scripts

- `deployment/deploy_container.sh` - Full deployment
- `deployment/upgrade_service.sh` - Service upgrade
- `deployment/manage_services.sh` - Service management utilities

---

**Last Updated**: January 21, 2026
