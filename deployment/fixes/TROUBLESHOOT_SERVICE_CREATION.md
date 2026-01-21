# Troubleshooting Service Creation Failure

**Issue**: `CREATE SERVICE BORDEREAU_APP` failed  
**Date**: January 19, 2026

---

## Common Causes and Solutions

### 1. Check the Actual Error Message

Run this to see the full error:

```sql
-- Connect to Snowflake
snow sql --connection DEPLOYMENT

-- Try to create the service manually to see the full error
USE ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA PUBLIC;

CREATE SERVICE BORDEREAU_APP
    IN COMPUTE POOL BORDEREAU_COMPUTE_POOL
    FROM @SERVICE_SPECS
    SPECIFICATION_FILE = 'unified_service_spec.yaml'
    MIN_INSTANCES = 1
    MAX_INSTANCES = 3
    COMMENT = 'Bordereau unified service (Frontend + Backend)';
```

---

## Common Issues

### Issue 1: Service Already Exists

**Error**: `Service 'BORDEREAU_APP' already exists`

**Solution**:
```sql
-- Drop the existing service
DROP SERVICE IF EXISTS BORDEREAU_APP;

-- Then recreate
CREATE SERVICE BORDEREAU_APP ...;
```

**Or update the script to check first**:
```bash
# In deploy_container.sh, add:
snow sql --connection DEPLOYMENT -q "DROP SERVICE IF EXISTS BORDEREAU_APP;"
```

---

### Issue 2: Compute Pool Not Ready

**Error**: `Compute pool 'BORDEREAU_COMPUTE_POOL' is not in ACTIVE or IDLE state`

**Check pool status**:
```sql
SHOW COMPUTE POOLS LIKE 'BORDEREAU_COMPUTE_POOL';
```

**Solution**:
```sql
-- Wait for pool to be ready
-- Check status
SELECT 
    name,
    state,
    num_services,
    num_jobs
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- If stuck, restart the pool
ALTER COMPUTE POOL BORDEREAU_COMPUTE_POOL STOP ALL;
ALTER COMPUTE POOL BORDEREAU_COMPUTE_POOL RESUME;
```

---

### Issue 3: Image Not Found

**Error**: `Image not found in repository`

**Check images**:
```sql
-- List images in repository
SHOW IMAGES IN IMAGE REPOSITORY BORDEREAU_REPOSITORY;
```

**Solution**:
```bash
# Rebuild and push images
cd deployment
./deploy_container.sh
```

---

### Issue 4: Invalid Specification File

**Error**: `Invalid service specification` or `YAML parsing error`

**Check the spec file**:
```sql
-- View the uploaded spec
SELECT * FROM @SERVICE_SPECS;

-- Download and inspect
GET @SERVICE_SPECS/unified_service_spec.yaml file:///tmp/;
cat /tmp/unified_service_spec.yaml
```

**Common YAML issues**:
- Incorrect indentation
- Missing required fields
- Invalid image references
- Port conflicts

---

### Issue 5: Insufficient Privileges

**Error**: `Insufficient privileges to operate on compute pool`

**Check privileges**:
```sql
-- Show grants on compute pool
SHOW GRANTS ON COMPUTE POOL BORDEREAU_COMPUTE_POOL;

-- Grant necessary privileges
USE ROLE ACCOUNTADMIN;
GRANT USAGE ON COMPUTE POOL BORDEREAU_COMPUTE_POOL 
    TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
GRANT OPERATE ON COMPUTE POOL BORDEREAU_COMPUTE_POOL 
    TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
```

---

### Issue 6: Image Repository Access

**Error**: `Cannot access image repository`

**Check repository access**:
```sql
-- Show grants on repository
SHOW GRANTS ON IMAGE REPOSITORY BORDEREAU_REPOSITORY;

-- Grant access
USE ROLE ACCOUNTADMIN;
GRANT READ ON IMAGE REPOSITORY BORDEREAU_REPOSITORY 
    TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
```

---

## Diagnostic Commands

### 1. Check Service Status

```sql
-- Show all services
SHOW SERVICES IN DATABASE BORDEREAU_PROCESSING_PIPELINE;

-- Check specific service
SHOW SERVICES LIKE 'BORDEREAU_APP';

-- Get service status
CALL SYSTEM$GET_SERVICE_STATUS('BORDEREAU_APP');
```

### 2. Check Compute Pool

```sql
-- Show compute pools
SHOW COMPUTE POOLS;

-- Check pool details
DESC COMPUTE POOL BORDEREAU_COMPUTE_POOL;

-- Check pool state
SELECT 
    name,
    state,
    instance_family,
    min_nodes,
    max_nodes,
    num_services
FROM TABLE(INFORMATION_SCHEMA.COMPUTE_POOLS)
WHERE name = 'BORDEREAU_COMPUTE_POOL';
```

### 3. Check Images

```sql
-- Show image repository
SHOW IMAGE REPOSITORIES LIKE 'BORDEREAU_REPOSITORY';

-- List images
SHOW IMAGES IN IMAGE REPOSITORY BORDEREAU_REPOSITORY;

-- Check image details
DESC IMAGE REPOSITORY BORDEREAU_REPOSITORY;
```

### 4. Check Specification File

```sql
-- List files in stage
LIST @SERVICE_SPECS;

-- View spec file content
SELECT $1 FROM @SERVICE_SPECS/unified_service_spec.yaml;
```

---

## Quick Fix Script

Create a script to diagnose and fix common issues:

```bash
#!/bin/bash
# diagnose_service.sh

echo "=== Checking Service Status ==="
snow sql --connection DEPLOYMENT -q "
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
SHOW SERVICES LIKE 'BORDEREAU_APP';
"

echo ""
echo "=== Checking Compute Pool ==="
snow sql --connection DEPLOYMENT -q "
SHOW COMPUTE POOLS LIKE 'BORDEREAU_COMPUTE_POOL';
"

echo ""
echo "=== Checking Images ==="
snow sql --connection DEPLOYMENT -q "
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
SHOW IMAGES IN IMAGE REPOSITORY BORDEREAU_REPOSITORY;
"

echo ""
echo "=== Checking Specification File ==="
snow sql --connection DEPLOYMENT -q "
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
LIST @SERVICE_SPECS;
"

echo ""
echo "=== Attempting to Drop and Recreate Service ==="
snow sql --connection DEPLOYMENT -q "
USE ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA PUBLIC;

-- Drop if exists
DROP SERVICE IF EXISTS BORDEREAU_APP;

-- Recreate
CREATE SERVICE BORDEREAU_APP
    IN COMPUTE POOL BORDEREAU_COMPUTE_POOL
    FROM @SERVICE_SPECS
    SPECIFICATION_FILE = 'unified_service_spec.yaml'
    MIN_INSTANCES = 1
    MAX_INSTANCES = 3
    COMMENT = 'Bordereau unified service (Frontend + Backend)';
"
```

---

## Enhanced Error Handling in deploy_container.sh

Update the script to show full error messages:

```bash
# Around line 553, replace:
execute_sql_file /tmp/create_service.sql || {
    log_error "Failed to create service"
    exit 1
}

# With:
if ! execute_sql_file /tmp/create_service.sql 2>&1 | tee /tmp/service_error.log; then
    log_error "Failed to create service. Error details:"
    cat /tmp/service_error.log
    echo ""
    log_error "Diagnostic information:"
    
    # Show compute pool status
    echo "Compute Pool Status:"
    snow sql --connection DEPLOYMENT -q "SHOW COMPUTE POOLS LIKE '${COMPUTE_POOL_NAME}';" 2>/dev/null
    
    # Show existing services
    echo ""
    echo "Existing Services:"
    snow sql --connection DEPLOYMENT -q "USE DATABASE ${DATABASE_NAME}; SHOW SERVICES;" 2>/dev/null
    
    exit 1
fi
```

---

## Step-by-Step Manual Creation

If automated creation fails, try manual steps:

```sql
-- Step 1: Verify prerequisites
USE ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA PUBLIC;

-- Step 2: Check compute pool
SHOW COMPUTE POOLS LIKE 'BORDEREAU_COMPUTE_POOL';
-- Ensure state is ACTIVE or IDLE

-- Step 3: Check images exist
SHOW IMAGES IN IMAGE REPOSITORY BORDEREAU_REPOSITORY;
-- Should show bordereau_backend and bordereau_frontend

-- Step 4: Check spec file
LIST @SERVICE_SPECS;
-- Should show unified_service_spec.yaml

-- Step 5: Drop existing service if any
DROP SERVICE IF EXISTS BORDEREAU_APP;

-- Step 6: Create service
CREATE SERVICE BORDEREAU_APP
    IN COMPUTE POOL BORDEREAU_COMPUTE_POOL
    FROM @SERVICE_SPECS
    SPECIFICATION_FILE = 'unified_service_spec.yaml'
    MIN_INSTANCES = 1
    MAX_INSTANCES = 3
    COMMENT = 'Bordereau unified service (Frontend + Backend)';

-- Step 7: Check service status
SHOW SERVICES LIKE 'BORDEREAU_APP';

-- Step 8: Get detailed status
CALL SYSTEM$GET_SERVICE_STATUS('BORDEREAU_APP');

-- Step 9: View service logs
CALL SYSTEM$GET_SERVICE_LOGS('BORDEREAU_APP', 0, 'frontend');
CALL SYSTEM$GET_SERVICE_LOGS('BORDEREAU_APP', 0, 'backend');
```

---

## Most Likely Issue

Based on the output, the most likely issue is:

### **Service Already Exists**

The script checks if the service exists, but there might be a timing issue or the service is in a bad state.

**Quick Fix**:

```bash
# Drop the service first
snow sql --connection DEPLOYMENT -q "
USE ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
DROP SERVICE IF EXISTS BORDEREAU_APP;
"

# Wait a moment
sleep 5

# Then run deploy_container.sh again
cd deployment
./deploy_container.sh
```

---

## Prevention

Update `deploy_container.sh` to handle existing services better:

```bash
# Around line 530, add:
log_step "8/10: Checking for existing service..."

# Check if service exists and drop it
SERVICE_EXISTS=$(snow sql --connection DEPLOYMENT --format json \
    -q "USE DATABASE ${DATABASE_NAME}; SHOW SERVICES LIKE '${SERVICE_NAME}';" 2>/dev/null \
    | jq -r 'length' 2>/dev/null || echo "0")

if [ "$SERVICE_EXISTS" -gt 0 ]; then
    log_warning "Service ${SERVICE_NAME} already exists. Dropping..."
    snow sql --connection DEPLOYMENT -q "
        USE ROLE ${SNOWFLAKE_ROLE};
        USE DATABASE ${DATABASE_NAME};
        DROP SERVICE IF EXISTS ${SERVICE_NAME};
    " >/dev/null 2>&1
    
    # Wait for service to be fully dropped
    sleep 5
    log_success "Existing service dropped"
fi
```

---

## Summary

**Immediate Action**:
1. Run the diagnostic commands above to see the actual error
2. Most likely: Drop the existing service and recreate
3. Check compute pool is in ACTIVE/IDLE state
4. Verify images exist in repository

**Command to try**:
```bash
# Quick fix
snow sql --connection DEPLOYMENT -q "
USE ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
DROP SERVICE IF EXISTS BORDEREAU_APP;
"

# Then retry
cd deployment && ./deploy_container.sh
```

---

**Created**: January 19, 2026  
**Status**: Troubleshooting Guide
