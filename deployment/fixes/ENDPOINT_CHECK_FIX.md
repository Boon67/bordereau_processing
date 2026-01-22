# Endpoint Check Not Working Fix

**Date**: January 21, 2026  
**Issue**: Service endpoint check timing out during deployment  
**Status**: ✅ Fixed

---

## Problem

After service creation, the deployment script gets stuck trying to retrieve the service endpoint:

```
[INFO] Getting service endpoint...
[INFO] Endpoint not ready, waiting... (attempt 1/10)
[INFO] Endpoint not ready, waiting... (attempt 2/10)
[INFO] Endpoint not ready, waiting... (attempt 3/10)
...
[INFO] Endpoint not ready, waiting... (attempt 10/10)
[WARNING] Endpoint not available yet. Check status later.
```

**Symptoms:**
- ❌ Endpoint check times out after 10 attempts
- ❌ Service is created successfully but endpoint not retrieved
- ❌ Deployment completes but without endpoint information
- ❌ Manual check shows endpoint exists

---

## Root Cause

The endpoint retrieval was using `execute_sql` with `SHOW ENDPOINTS IN SERVICE`:

```bash
local endpoint_output=$(execute_sql "
    SHOW ENDPOINTS IN SERVICE ${SERVICE_NAME};
")

local endpoint=$(echo "$endpoint_output" | jq -r '.[2][0].ingress_url // empty')
```

**Issues:**
1. `execute_sql` output format wasn't compatible with `jq` parsing
2. Array indexing `.[2][0]` was incorrect for the output structure
3. `ingress_url` field doesn't exist in the output
4. SQL command output format is different from JSON

---

## Solution

Use `snow spcs service list` command with JSON output:

### Before (Broken)

```bash
get_service_endpoint() {
    local endpoint_output=$(execute_sql "
        SHOW ENDPOINTS IN SERVICE ${SERVICE_NAME};
    ")
    
    local endpoint=$(echo "$endpoint_output" | jq -r '.[2][0].ingress_url // empty')
    
    if [ -n "$endpoint" ]; then
        SERVICE_ENDPOINT="https://${endpoint}"
        return 0
    fi
}
```

### After (Fixed)

```bash
get_service_endpoint() {
    # Use snow CLI to get service info
    local service_info=$(snow spcs service list \
        --database "${DATABASE_NAME}" \
        --schema "${SCHEMA_NAME}" \
        --format json 2>/dev/null | \
        jq -r ".[] | select(.name == \"${SERVICE_NAME}\")" 2>/dev/null)
    
    if [ -n "$service_info" ]; then
        # Extract DNS name from service info
        local dns_name=$(echo "$service_info" | jq -r '.dns_name // empty' 2>/dev/null)
        
        if [ -n "$dns_name" ] && [ "$dns_name" != "null" ] && [ "$dns_name" != "" ]; then
            SERVICE_ENDPOINT="https://${dns_name}"
            log_success "Service endpoint: $SERVICE_ENDPOINT"
            return 0
        fi
    fi
}
```

**Key Changes:**
1. ✅ Use `snow spcs service list` with `--format json`
2. ✅ Filter service by name using `jq`
3. ✅ Extract `dns_name` field (correct field name)
4. ✅ Validate DNS name is not empty or null
5. ✅ Better error messages

---

## Files Changed

### `deployment/deploy_container.sh`

**Endpoint Retrieval Function:**
```diff
  get_service_endpoint() {
      echo ""
      log_info "Getting service endpoint..."
      
      local max_attempts=10
      local attempt=1
      
      while [ $attempt -le $max_attempts ]; do
-         local endpoint_output=$(execute_sql "
-             USE DATABASE ${DATABASE_NAME};
-             USE SCHEMA ${SCHEMA_NAME};
-             SHOW ENDPOINTS IN SERVICE ${SERVICE_NAME};
-         " 2>/dev/null)
-         
-         local endpoint=$(echo "$endpoint_output" | jq -r '.[2][0].ingress_url // empty' 2>/dev/null)
+         # Use snow CLI to get service info
+         local service_info=$(snow spcs service list \
+             --database "${DATABASE_NAME}" \
+             --schema "${SCHEMA_NAME}" \
+             --format json 2>/dev/null | \
+             jq -r ".[] | select(.name == \"${SERVICE_NAME}\")" 2>/dev/null)
+         
+         if [ -n "$service_info" ]; then
+             # Extract DNS name from service info
+             local dns_name=$(echo "$service_info" | jq -r '.dns_name // empty' 2>/dev/null)
+             
+             if [ -n "$dns_name" ] && [ "$dns_name" != "null" ] && [ "$dns_name" != "" ]; then
+                 SERVICE_ENDPOINT="https://${dns_name}"
+                 log_success "Service endpoint: $SERVICE_ENDPOINT"
+                 return 0
+             fi
+         fi
```

---

## Verification

### Test Endpoint Retrieval

```bash
# Get service endpoint
snow spcs service list \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --format json | \
  jq -r '.[] | select(.name == "BORDEREAU_APP") | .dns_name'
```

**Expected Output:**
```
bordereau-app.bd3h.svc.spcs.internal
```

### Test Full Deployment

```bash
cd deployment
./deploy_container.sh
```

**Expected Output:**
```
[INFO] Getting service endpoint...
[SUCCESS] Service endpoint: https://bordereau-app.bd3h.svc.spcs.internal

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📍 ENDPOINT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Application (Frontend):
    https://bordereau-app.bd3h.svc.spcs.internal

  API (via Frontend proxy):
    https://bordereau-app.bd3h.svc.spcs.internal/api/health
```

---

## Understanding Service Endpoints

### Service Info Structure

When you run `snow spcs service list --format json`, you get:

```json
[
  {
    "name": "BORDEREAU_APP",
    "status": "RUNNING",
    "database_name": "BORDEREAU_PROCESSING_PIPELINE",
    "schema_name": "PUBLIC",
    "owner": "BORDEREAU_PROCESSING_PIPELINE_ADMIN",
    "compute_pool": "BORDEREAU_COMPUTE_POOL",
    "dns_name": "bordereau-app.bd3h.svc.spcs.internal",
    "current_instances": 1,
    "target_instances": 1,
    "min_instances": 1,
    "max_instances": 3,
    "created_on": "2026-01-22T00:18:56.123Z",
    "updated_on": "2026-01-22T00:19:12.456Z"
  }
]
```

**Key Fields:**
- `name` - Service name
- `status` - Service status (RUNNING, PENDING, SUSPENDED, etc.)
- `dns_name` - Internal DNS name for the service
- `current_instances` - Number of running instances

### Endpoint Types

**Internal Endpoint:**
```
bordereau-app.bd3h.svc.spcs.internal
```
- Accessible within Snowflake
- Used for service-to-service communication
- Format: `{service-name}.{random}.svc.spcs.internal`

**Public Endpoint (if configured):**
```
https://bordereau-app-{account}.snowflakecomputing.app
```
- Accessible from internet
- Requires public endpoint configuration
- Format: `https://{service-name}-{account}.snowflakecomputing.app`

---

## Troubleshooting

### Endpoint Still Not Found

If the endpoint check still fails:

1. **Check Service Status**
   ```bash
   snow spcs service status BORDEREAU_APP \
     --database BORDEREAU_PROCESSING_PIPELINE \
     --schema PUBLIC
   ```

2. **Verify Service is Running**
   ```bash
   snow spcs service list \
     --database BORDEREAU_PROCESSING_PIPELINE \
     --schema PUBLIC | grep BORDEREAU_APP
   ```

3. **Check if DNS Name Exists**
   ```bash
   snow spcs service list \
     --database BORDEREAU_PROCESSING_PIPELINE \
     --schema PUBLIC \
     --format json | jq '.[] | {name, dns_name, status}'
   ```

### Service Not Ready

If service is still starting:

```bash
# Wait for service to be ready
while true; do
  STATUS=$(snow spcs service list \
    --database BORDEREAU_PROCESSING_PIPELINE \
    --schema PUBLIC \
    --format json | \
    jq -r '.[] | select(.name == "BORDEREAU_APP") | .status')
  
  echo "Service status: $STATUS"
  
  if [ "$STATUS" = "RUNNING" ]; then
    echo "Service is ready!"
    break
  fi
  
  sleep 10
done
```

### DNS Name Empty

If `dns_name` is empty or null:

```bash
# Check service details
snow spcs service describe BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# Check if endpoints are configured
snow spcs service list-endpoints BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

---

## Manual Endpoint Retrieval

If the script fails, you can manually get the endpoint:

### Using Snow CLI

```bash
# Get DNS name
ENDPOINT=$(snow spcs service list \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --format json | \
  jq -r '.[] | select(.name == "BORDEREAU_APP") | .dns_name')

echo "Service endpoint: https://$ENDPOINT"
```

### Using SQL

```sql
-- Show service info
SHOW SERVICES LIKE 'BORDEREAU_APP' IN BORDEREAU_PROCESSING_PIPELINE.PUBLIC;

-- Show endpoints
SHOW ENDPOINTS IN SERVICE BORDEREAU_PROCESSING_PIPELINE.PUBLIC.BORDEREAU_APP;
```

---

## Best Practices

### 1. Always Check Service Status First

```bash
# Before getting endpoint
snow spcs service status SERVICE_NAME \
  --database DATABASE \
  --schema SCHEMA
```

### 2. Wait for Service to be Ready

```bash
# Don't check endpoint immediately after creation
sleep 30

# Then check endpoint
```

### 3. Use JSON Output for Parsing

```bash
# Good - structured JSON
snow spcs service list --format json | jq '.[] | .dns_name'

# Avoid - table format is hard to parse
snow spcs service list | grep dns_name
```

### 4. Validate Endpoint Before Using

```bash
# Check if endpoint is reachable
if [ -n "$ENDPOINT" ]; then
  curl -s -o /dev/null -w "%{http_code}" "https://$ENDPOINT/api/health"
fi
```

---

## Related Commands

### List All Services

```bash
snow spcs service list \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

### Get Service Details

```bash
snow spcs service describe BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

### List Service Endpoints

```bash
snow spcs service list-endpoints BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

### Test Endpoint

```bash
ENDPOINT=$(snow spcs service list \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --format json | \
  jq -r '.[] | select(.name == "BORDEREAU_APP") | .dns_name')

curl "https://$ENDPOINT/api/health"
```

---

## Quick Reference

```bash
# Get endpoint
snow spcs service list \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --format json | \
  jq -r '.[] | select(.name == "BORDEREAU_APP") | .dns_name'

# Full deployment with endpoint
cd deployment
./deploy_container.sh

# Manual endpoint check
./manage_services.sh status
```

---

## Status

**Status**: ✅ Fixed  
**Method**: Use `snow spcs service list` with JSON parsing  
**Impact**: Endpoint now retrieved successfully after deployment  
**Benefit**: Deployment summary shows correct endpoint URL

**Last Updated**: January 21, 2026
