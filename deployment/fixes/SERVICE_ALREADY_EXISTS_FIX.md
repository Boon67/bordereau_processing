# Service Already Exists Error Fix

**Date**: January 21, 2026  
**Issue**: "Object 'BORDEREAU_APP' already exists" error during deployment  
**Status**: ✅ Fixed

---

## Problem

When running `./deploy_container.sh`, the deployment fails with:

```
CREATE SERVICE BORDEREAU_APP
    IN COMPUTE POOL BORDEREAU_COMPUTE_POOL
    FROM @SERVICE_SPECS
    SPECIFICATION_FILE = 'unified_service_spec.yaml'
    MIN_INSTANCES = 1
    MAX_INSTANCES = 3
    COMMENT = 'Bordereau unified service (Frontend + Backend)';

Error: SQL compilation error: Object 'BORDEREAU_APP' already exists.
```

**Symptoms:**
- ❌ Deployment fails at service creation step
- ❌ Service already exists from previous deployment
- ❌ Script doesn't detect existing service properly
- ❌ Manual intervention required

---

## Root Cause

The deployment script had logic to check if the service exists, but it wasn't working correctly:

```bash
# Old code - didn't work properly
SERVICE_EXISTS=$(execute_sql "
    SHOW SERVICES LIKE '${SERVICE_NAME}';
" | jq -r 'length' 2>/dev/null || echo "0")
```

**Issues:**
1. `execute_sql` function output format wasn't compatible with `jq`
2. `SHOW SERVICES` output wasn't being parsed correctly
3. Check always returned 0, so service was never dropped
4. Script tried to `CREATE SERVICE` even when it existed

---

## Solution

Updated the service existence check to use `snow spcs service list` command:

### Before (Broken)

```bash
# Check if service exists
SERVICE_EXISTS=$(execute_sql "
    USE DATABASE ${DATABASE_NAME};
    USE SCHEMA ${SCHEMA_NAME};
    SHOW SERVICES LIKE '${SERVICE_NAME}';
" | jq -r 'length' 2>/dev/null || echo "0")

if [ "$SERVICE_EXISTS" -gt 0 ]; then
    # Drop service
    execute_sql "DROP SERVICE IF EXISTS ${SERVICE_NAME};"
fi

# Create service
CREATE SERVICE ${SERVICE_NAME} ...
```

### After (Fixed)

```bash
# Check if service exists using snow CLI
log_info "Checking if service exists..."
SERVICE_EXISTS=$(snow spcs service list \
    --database "${DATABASE_NAME}" \
    --schema "${SCHEMA_NAME}" \
    --format json 2>/dev/null | \
    jq -r ".[] | select(.name == \"${SERVICE_NAME}\") | .name" || echo "")

if [ -n "$SERVICE_EXISTS" ]; then
    log_warning "Service '$SERVICE_NAME' already exists. Dropping for clean deployment..."
    
    # Drop existing service using snow CLI
    snow spcs service drop "${SERVICE_NAME}" \
        --database "${DATABASE_NAME}" \
        --schema "${SCHEMA_NAME}"
    
    log_success "Existing service dropped"
    
    # Wait for service to be fully dropped
    log_info "Waiting for service cleanup..."
    sleep 10
fi

# Create service with DROP IF EXISTS as safety net
DROP SERVICE IF EXISTS ${SERVICE_NAME};
CREATE SERVICE ${SERVICE_NAME} ...
```

**Key Changes:**
1. ✅ Use `snow spcs service list` with JSON output
2. ✅ Parse JSON with `jq` to find specific service
3. ✅ Use `snow spcs service drop` command
4. ✅ Added `DROP SERVICE IF EXISTS` before `CREATE SERVICE` as safety net
5. ✅ Increased wait time to 10 seconds for cleanup
6. ✅ Better logging for visibility

---

## Files Changed

### `deployment/deploy_container.sh`

**Service Existence Check:**
```diff
- SERVICE_EXISTS=$(execute_sql "
-     SHOW SERVICES LIKE '${SERVICE_NAME}';
- " | jq -r 'length' 2>/dev/null || echo "0")
+ SERVICE_EXISTS=$(snow spcs service list \
+     --database "${DATABASE_NAME}" \
+     --schema "${SCHEMA_NAME}" \
+     --format json 2>/dev/null | \
+     jq -r ".[] | select(.name == \"${SERVICE_NAME}\") | .name" || echo "")

- if [ "$SERVICE_EXISTS" -gt 0 ]; then
+ if [ -n "$SERVICE_EXISTS" ]; then
```

**Service Drop:**
```diff
- execute_sql "DROP SERVICE IF EXISTS ${SERVICE_NAME};"
+ snow spcs service drop "${SERVICE_NAME}" \
+     --database "${DATABASE_NAME}" \
+     --schema "${SCHEMA_NAME}"

- sleep 5
+ sleep 10
```

**Service Creation:**
```diff
  CREATE SERVICE ${SERVICE_NAME}
+     -- Drop service if it still exists (edge case)
+     DROP SERVICE IF EXISTS ${SERVICE_NAME};
+     
+     -- Create new service
      IN COMPUTE POOL ${COMPUTE_POOL_NAME}
```

---

## Usage

### Automatic Handling (Recommended)

The script now automatically handles existing services:

```bash
cd deployment
./deploy_container.sh
```

**Output:**
```
[INFO] Checking if service exists...
[WARNING] Service 'BORDEREAU_APP' already exists. Dropping for clean deployment...
[SUCCESS] Existing service dropped
[INFO] Waiting for service cleanup...
[INFO] Creating service 'BORDEREAU_APP'...
[SUCCESS] Service created successfully
```

### Manual Service Management

If you need to manually manage services:

#### Check if Service Exists

```bash
snow spcs service list \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --format json | jq -r '.[] | select(.name == "BORDEREAU_APP")'
```

#### Drop Service

```bash
snow spcs service drop BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

#### Check Service Status

```bash
snow spcs service status BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

---

## Alternative: Use Upgrade Instead of Drop/Recreate

For production environments, consider using the upgrade approach instead:

```bash
# Use upgrade_service.sh instead
cd deployment
./upgrade_service.sh
```

**Benefits:**
- ✅ No service downtime
- ✅ Preserves service configuration
- ✅ Safer for production
- ✅ Faster deployment

See [UPGRADE_METHOD_SUMMARY.md](../../UPGRADE_METHOD_SUMMARY.md) for details.

---

## Troubleshooting

### Service Still Exists After Drop

If the service still exists after trying to drop it:

```bash
# Check service status
snow spcs service status BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# If status is SUSPENDED or PENDING, wait longer
sleep 30

# Try dropping again
snow spcs service drop BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

### Permission Denied

```
Error: Insufficient privileges to drop service
```

**Solution:** Check your role has the necessary privileges:

```sql
-- Grant privileges
GRANT USAGE ON COMPUTE POOL BORDEREAU_COMPUTE_POOL TO ROLE YOUR_ROLE;
GRANT OPERATE ON SERVICE BORDEREAU_APP TO ROLE YOUR_ROLE;

-- Or use admin role
USE ROLE ACCOUNTADMIN;
```

### Service in Use

```
Error: Cannot drop service while it is running
```

**Solution:** Suspend the service first:

```bash
# Suspend service
snow spcs service suspend BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# Wait for suspension
sleep 10

# Drop service
snow spcs service drop BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

### Compute Pool Not Found

```
Error: Compute pool 'BORDEREAU_COMPUTE_POOL' does not exist
```

**Solution:** Create the compute pool first:

```bash
# Check if pool exists
snow spcs compute-pool list

# Create pool if needed
snow spcs compute-pool create BORDEREAU_COMPUTE_POOL \
  --family STANDARD_1 \
  --min-nodes 1 \
  --max-nodes 3
```

---

## Best Practices

### 1. Development vs. Production

**Development:**
- ✅ Use drop/recreate for clean slate
- ✅ Fast iteration
- ✅ No state to preserve

```bash
./deploy_container.sh  # Drops and recreates
```

**Production:**
- ✅ Use upgrade for zero-downtime
- ✅ Preserves configuration
- ✅ Safer deployment

```bash
./upgrade_service.sh  # Upgrades in place
```

### 2. Check Before Deploy

Always check what will be affected:

```bash
# List services
snow spcs service list \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# Check service status
snow spcs service status BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

### 3. Backup Important Data

Before dropping services:

```bash
# Export service logs
snow spcs service logs BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --container-name backend \
  --instance-id 0 \
  --num-lines 1000 > service_logs_backup.txt

# Document current configuration
snow spcs service describe BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC > service_config_backup.txt
```

### 4. Use Proper Wait Times

After dropping a service, wait for cleanup:

```bash
# Minimum wait time
sleep 10

# For large services
sleep 30

# Check if fully dropped
while snow spcs service status BORDEREAU_APP 2>&1 | grep -q "does not exist"; do
  echo "Service still exists, waiting..."
  sleep 5
done
```

---

## Testing

### Test Service Drop

```bash
# Create test service
snow spcs service create TEST_SERVICE \
  --compute-pool BORDEREAU_COMPUTE_POOL \
  --spec-path test-spec.yaml \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# Verify it exists
snow spcs service list \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC | grep TEST_SERVICE

# Drop it
snow spcs service drop TEST_SERVICE \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# Verify it's gone
snow spcs service list \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC | grep TEST_SERVICE || echo "Service successfully dropped"
```

### Test Deployment Script

```bash
# Run deployment twice to test drop/recreate
cd deployment

# First deployment
./deploy_container.sh

# Second deployment (should drop and recreate)
./deploy_container.sh
```

**Expected Output:**
```
[INFO] Checking if service exists...
[WARNING] Service 'BORDEREAU_APP' already exists. Dropping for clean deployment...
[SUCCESS] Existing service dropped
[INFO] Waiting for service cleanup...
[INFO] Creating service 'BORDEREAU_APP'...
[SUCCESS] Service created successfully
```

---

## Related Issues

- [UPGRADE_METHOD_SUMMARY.md](../../UPGRADE_METHOD_SUMMARY.md) - Use upgrade instead of drop/recreate
- [CONTAINER_DEPLOYMENT_FIX.md](CONTAINER_DEPLOYMENT_FIX.md) - General deployment issues
- [TROUBLESHOOT_SERVICE_CREATION.md](TROUBLESHOOT_SERVICE_CREATION.md) - Service creation failures

---

## Quick Reference

### Check Service

```bash
snow spcs service list --database BORDEREAU_PROCESSING_PIPELINE --schema PUBLIC
```

### Drop Service

```bash
snow spcs service drop BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

### Deploy (Auto-handles existing)

```bash
cd deployment
./deploy_container.sh
```

### Upgrade (Recommended for production)

```bash
cd deployment
./upgrade_service.sh
```

---

## Status

**Status**: ✅ Fixed  
**Method**: Improved service existence check using snow CLI  
**Impact**: Deployments now handle existing services automatically  
**Recommendation**: Use upgrade_service.sh for production deployments

**Last Updated**: January 21, 2026
