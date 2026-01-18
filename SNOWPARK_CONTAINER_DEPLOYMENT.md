# Snowpark Container Services Deployment Guide

This guide explains how to deploy the Bordereau Processing Pipeline to Snowpark Container Services.

## Overview

Snowpark Container Services allows you to run containerized applications directly within Snowflake, providing:
- Seamless integration with Snowflake data
- Automatic scaling and high availability
- Secure execution within Snowflake's environment
- No need to manage external infrastructure

## Prerequisites

### 1. Software Requirements

- **Snowflake CLI**: Install via pip
  ```bash
  pip install snowflake-cli-labs
  ```

- **Docker**: Install from [docker.com](https://docs.docker.com/get-docker/)

- **jq** (optional, for JSON parsing): 
  ```bash
  # macOS
  brew install jq
  
  # Linux
  sudo apt-get install jq
  ```

### 2. Snowflake Requirements

- **Account**: Snowflake account with Snowpark Container Services enabled
- **Role**: `ACCOUNTADMIN` or role with these privileges:
  - `CREATE COMPUTE POOL`
  - `CREATE IMAGE REPOSITORY`
  - `CREATE SERVICE`
  - `USAGE` on warehouse
  - `CREATE DATABASE`, `CREATE SCHEMA` privileges

### 3. Configure Snow CLI

Set up your Snowflake connection:

```bash
snow connection add

# Follow prompts to enter:
# - Connection name: DEPLOYMENT
# - Account: SFSENORTHAMERICA-TBOON_AWS2
# - User: DEMO_SVC
# - Authentication method: keypair
# - Private key path: ~/.snowflake/keys/demo_svc_key.p8
```

Test the connection:

```bash
snow connection test --connection DEPLOYMENT
```

## Deployment Steps

### Option 1: Automated Deployment (Recommended)

Run the deployment script:

```bash
./deploy_snowpark_container.sh
```

This script will:
1. ✅ Validate prerequisites
2. ✅ Create compute pool
3. ✅ Create image repository
4. ✅ Build Docker image
5. ✅ Push image to Snowflake registry
6. ✅ Deploy service
7. ✅ Show service endpoint

### Option 2: Manual Deployment

#### Step 1: Create Compute Pool

```sql
USE ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;

CREATE COMPUTE POOL BORDEREAU_COMPUTE_POOL
    MIN_NODES = 1
    MAX_NODES = 3
    INSTANCE_FAMILY = CPU_X64_XS
    AUTO_RESUME = TRUE
    AUTO_SUSPEND_SECS = 3600;

-- Check status
DESCRIBE COMPUTE POOL BORDEREAU_COMPUTE_POOL;
```

#### Step 2: Create Image Repository

```sql
CREATE IMAGE REPOSITORY BORDEREAU_REPOSITORY;

-- Get repository URL
SELECT REPOSITORY_URL 
FROM INFORMATION_SCHEMA.IMAGE_REPOSITORIES 
WHERE REPOSITORY_NAME = 'BORDEREAU_REPOSITORY';
```

#### Step 3: Build and Push Docker Image

```bash
# Get repository URL
REPO_URL=$(snow sql -q "SELECT REPOSITORY_URL FROM INFORMATION_SCHEMA.IMAGE_REPOSITORIES WHERE REPOSITORY_NAME = 'BORDEREAU_REPOSITORY'" --format json | jq -r '.[0].REPOSITORY_URL')

# Build image
docker build -f docker/Dockerfile.backend -t ${REPO_URL}/bordereau_backend:latest .

# Login to Snowflake registry
docker login ${REPO_URL} -u DEMO_SVC

# Push image
docker push ${REPO_URL}/bordereau_backend:latest
```

#### Step 4: Create Service Specification

Create `service_spec.yaml`:

```yaml
spec:
  containers:
  - name: backend
    image: <REPO_URL>/bordereau_backend:latest
    env:
      ENVIRONMENT: production
      SNOWFLAKE_ACCOUNT: SFSENORTHAMERICA-TBOON_AWS2
      SNOWFLAKE_USER: DEMO_SVC
      SNOWFLAKE_ROLE: BORDEREAU_PROCESSING_PIPELINE_ADMIN
      SNOWFLAKE_WAREHOUSE: COMPUTE_WH
      DATABASE_NAME: BORDEREAU_PROCESSING_PIPELINE
      BRONZE_SCHEMA_NAME: BRONZE
      SILVER_SCHEMA_NAME: SILVER
    resources:
      requests:
        cpu: "1"
        memory: 2Gi
      limits:
        cpu: "2"
        memory: 4Gi
    readinessProbe:
      httpGet:
        path: /api/health
        port: 8000
      initialDelaySeconds: 10
      periodSeconds: 10
    livenessProbe:
      httpGet:
        path: /api/health
        port: 8000
      initialDelaySeconds: 30
      periodSeconds: 30

  endpoints:
  - name: backend
    port: 8000
    public: true
```

#### Step 5: Deploy Service

```sql
-- Create stage for service specs
CREATE STAGE IF NOT EXISTS SERVICE_SPECS;

-- Upload spec file
PUT file:///path/to/service_spec.yaml @SERVICE_SPECS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Create service
CREATE SERVICE BORDEREAU_SERVICE
    IN COMPUTE POOL BORDEREAU_COMPUTE_POOL
    FROM @SERVICE_SPECS
    SPECIFICATION_FILE = 'service_spec.yaml'
    MIN_INSTANCES = 1
    MAX_INSTANCES = 3;

-- Get service status
SELECT SYSTEM$GET_SERVICE_STATUS('BORDEREAU_SERVICE');

-- Get service endpoint
SELECT SYSTEM$GET_SERVICE_ENDPOINT('BORDEREAU_SERVICE', 'backend');
```

## Service Management

Use the management script for common operations:

```bash
# Make script executable
chmod +x manage_snowpark_service.sh

# Show service status
./manage_snowpark_service.sh status

# Show logs
./manage_snowpark_service.sh logs 100

# Get endpoint
./manage_snowpark_service.sh endpoint

# Restart service
./manage_snowpark_service.sh restart

# Show all information
./manage_snowpark_service.sh all
```

### Manual Management Commands

```sql
-- Service status
SELECT SYSTEM$GET_SERVICE_STATUS('BORDEREAU_SERVICE');

-- Service logs
SELECT SYSTEM$GET_SERVICE_LOGS('BORDEREAU_SERVICE', 0, 'backend', 100);

-- Service endpoint
SELECT SYSTEM$GET_SERVICE_ENDPOINT('BORDEREAU_SERVICE', 'backend');

-- Suspend service
ALTER SERVICE BORDEREAU_SERVICE SUSPEND;

-- Resume service
ALTER SERVICE BORDEREAU_SERVICE RESUME;

-- Drop service
DROP SERVICE BORDEREAU_SERVICE;

-- Compute pool status
DESCRIBE COMPUTE POOL BORDEREAU_COMPUTE_POOL;

-- Suspend compute pool
ALTER COMPUTE POOL BORDEREAU_COMPUTE_POOL SUSPEND;

-- Resume compute pool
ALTER COMPUTE POOL BORDEREAU_COMPUTE_POOL RESUME;

-- Drop compute pool
DROP COMPUTE POOL BORDEREAU_COMPUTE_POOL;
```

## Monitoring

### Service Health

```bash
# Get endpoint
ENDPOINT=$(./manage_snowpark_service.sh endpoint | grep -o 'https://[^"]*')

# Test health endpoint
curl $ENDPOINT/api/health

# Test API
curl $ENDPOINT/api/tpas
```

### Service Logs

```sql
-- Real-time logs
SELECT SYSTEM$GET_SERVICE_LOGS('BORDEREAU_SERVICE', 0, 'backend', 100);

-- Filter logs by severity
SELECT * FROM TABLE(SYSTEM$GET_SERVICE_LOGS('BORDEREAU_SERVICE', 0, 'backend', 1000))
WHERE message LIKE '%ERROR%';
```

### Resource Usage

```sql
-- Service metrics
SELECT * FROM TABLE(SYSTEM$GET_SERVICE_METRICS('BORDEREAU_SERVICE'));

-- Compute pool usage
SELECT * FROM TABLE(INFORMATION_SCHEMA.COMPUTE_POOL_HISTORY(
    COMPUTE_POOL_NAME => 'BORDEREAU_COMPUTE_POOL',
    START_TIME => DATEADD('hour', -24, CURRENT_TIMESTAMP())
));
```

## Updating the Service

### Update Image

```bash
# Build new image
docker build -f docker/Dockerfile.backend -t ${REPO_URL}/bordereau_backend:v2 .

# Push new image
docker push ${REPO_URL}/bordereau_backend:v2

# Update service spec with new image tag
# Then recreate service
snow sql -q "
ALTER SERVICE BORDEREAU_SERVICE SUSPEND;
DROP SERVICE BORDEREAU_SERVICE;
CREATE SERVICE BORDEREAU_SERVICE
    IN COMPUTE POOL BORDEREAU_COMPUTE_POOL
    FROM @SERVICE_SPECS
    SPECIFICATION_FILE = 'service_spec_v2.yaml'
    MIN_INSTANCES = 1
    MAX_INSTANCES = 3;
"
```

### Update Configuration

```bash
# Update service spec with new environment variables
# Upload new spec
snow object stage copy service_spec.yaml @SERVICE_SPECS/service_spec.yaml --overwrite

# Recreate service
./manage_snowpark_service.sh restart
```

## Troubleshooting

### Service Won't Start

```sql
-- Check service status
SELECT SYSTEM$GET_SERVICE_STATUS('BORDEREAU_SERVICE');

-- Check logs for errors
SELECT SYSTEM$GET_SERVICE_LOGS('BORDEREAU_SERVICE', 0, 'backend', 500);

-- Check compute pool
DESCRIBE COMPUTE POOL BORDEREAU_COMPUTE_POOL;
```

### Image Push Fails

```bash
# Verify Docker login
docker login ${REPO_URL} -u DEMO_SVC

# Check repository exists
snow sql -q "SHOW IMAGE REPOSITORIES LIKE 'BORDEREAU_REPOSITORY'"

# Try alternative push method
snow spcs image-repository push --image ${REPO_URL}/bordereau_backend:latest
```

### Connection Issues

```sql
-- Test from within service
SELECT SYSTEM$GET_SERVICE_LOGS('BORDEREAU_SERVICE', 0, 'backend', 100);

-- Look for connection errors
-- Check environment variables are correct
```

### Performance Issues

```sql
-- Check resource usage
SELECT * FROM TABLE(SYSTEM$GET_SERVICE_METRICS('BORDEREAU_SERVICE'));

-- Increase resources in service spec
-- Update CPU/memory limits
-- Increase MIN_INSTANCES for better availability
```

## Cost Optimization

### Auto-Suspend

Compute pools auto-suspend after inactivity:

```sql
-- Set auto-suspend to 1 hour
ALTER COMPUTE POOL BORDEREAU_COMPUTE_POOL 
SET AUTO_SUSPEND_SECS = 3600;

-- Disable auto-suspend (not recommended)
ALTER COMPUTE POOL BORDEREAU_COMPUTE_POOL 
SET AUTO_SUSPEND_SECS = 0;
```

### Right-Sizing

```sql
-- Start with smaller instance family
CREATE COMPUTE POOL BORDEREAU_COMPUTE_POOL
    INSTANCE_FAMILY = CPU_X64_XS;  -- Smallest

-- Scale up if needed
-- CPU_X64_S, CPU_X64_M, CPU_X64_L
```

### Instance Scaling

```sql
-- Adjust min/max instances
ALTER COMPUTE POOL BORDEREAU_COMPUTE_POOL
SET MIN_NODES = 1
    MAX_NODES = 5;
```

## Security

### Network Isolation

Services run in isolated networks within Snowflake. External access requires explicit configuration.

### Secrets Management

Use Snowflake secrets for sensitive data:

```sql
-- Create secret
CREATE SECRET snowflake_api_key
    TYPE = GENERIC_STRING
    SECRET_STRING = 'your-secret-key';

-- Reference in service spec
env:
  API_KEY:
    secretKeyRef:
      name: snowflake_api_key
```

### Role-Based Access

```sql
-- Grant service access to specific roles
GRANT USAGE ON SERVICE BORDEREAU_SERVICE TO ROLE DATA_ANALYST;

-- Restrict compute pool access
GRANT USAGE ON COMPUTE POOL BORDEREAU_COMPUTE_POOL TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
```

## Best Practices

1. **Use Health Checks**: Always implement readiness and liveness probes
2. **Resource Limits**: Set appropriate CPU and memory limits
3. **Auto-Scaling**: Configure MIN/MAX instances based on load
4. **Logging**: Use structured logging for better debugging
5. **Monitoring**: Regularly check service metrics and logs
6. **Version Control**: Tag images with versions, not just `latest`
7. **Testing**: Test in development compute pool before production
8. **Documentation**: Keep service specs in version control

## Additional Resources

- [Snowpark Container Services Documentation](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/overview)
- [Snowflake CLI Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## Support

For issues or questions:
1. Check service logs: `./manage_snowpark_service.sh logs`
2. Review Snowflake documentation
3. Contact Snowflake support for platform issues
