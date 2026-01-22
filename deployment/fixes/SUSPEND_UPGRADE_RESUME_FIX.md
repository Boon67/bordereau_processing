# Suspend/Upgrade/Resume Deployment Fix

**Date**: January 21, 2026  
**Issue**: Service drop/recreate changes endpoint URL  
**Status**: ✅ Fixed and Deployed

---

## Problem

The deployment script was dropping and recreating the service on every deployment:

```bash
# Old approach
snow spcs service drop BORDEREAU_APP
sleep 10
CREATE SERVICE BORDEREAU_APP ...
```

**Issues:**
- ❌ Endpoint URL changes on every deployment
- ❌ Existing connections are lost
- ❌ DNS name changes (e.g., `bordereau-app.bd3h.svc.spcs.internal` → `bordereau-app.xyz9.svc.spcs.internal`)
- ❌ Requires updating all references to the endpoint
- ❌ Downtime during service recreation

**Example:**
```
Before deployment: https://bordereau-app.bd3h.svc.spcs.internal
After deployment:  https://bordereau-app.xyz9.svc.spcs.internal  ← Changed!
```

---

## Solution

Use the `suspend` → `upgrade` → `resume` workflow to preserve the endpoint:

```bash
# New approach
snow spcs service suspend BORDEREAU_APP
snow spcs service upgrade BORDEREAU_APP --spec-path spec.yaml
snow spcs service resume BORDEREAU_APP
```

**Benefits:**
- ✅ Endpoint URL remains the same
- ✅ DNS name preserved
- ✅ Minimal downtime
- ✅ No need to update references
- ✅ Cleaner upgrade process

---

## Implementation

### File Changed

**`deployment/deploy_container.sh`**

### Before (Drop/Recreate)

```bash
# Check if service exists
SERVICE_EXISTS=$(snow spcs service list ...)

if [ -n "$SERVICE_EXISTS" ]; then
    log_warning "Service exists. Dropping for clean deployment..."
    
    # Drop existing service
    snow spcs service drop "${SERVICE_NAME}" \
        --database "${DATABASE_NAME}" \
        --schema "${SCHEMA_NAME}"
    
    log_success "Existing service dropped"
    sleep 10
fi

# Create service (new or recreated)
log_info "Creating service..."
CREATE SERVICE ${SERVICE_NAME} ...
```

### After (Suspend/Upgrade/Resume)

```bash
# Check if service exists
SERVICE_EXISTS=$(snow spcs service list ...)

if [ -n "$SERVICE_EXISTS" ]; then
    log_info "Service exists. Using suspend/upgrade/resume workflow..."
    
    # Step 1: Suspend the service
    log_info "Suspending service..."
    snow spcs service suspend "${SERVICE_NAME}" \
        --database "${DATABASE_NAME}" \
        --schema "${SCHEMA_NAME}"
    log_success "Service suspended"
    sleep 5
    
    # Step 2: Upgrade the service
    log_info "Upgrading service with new images..."
    snow spcs service upgrade "${SERVICE_NAME}" \
        --database "${DATABASE_NAME}" \
        --schema "${SCHEMA_NAME}" \
        --spec-path /tmp/unified_service_spec.yaml
    log_success "Service upgraded"
    
    # Step 3: Resume the service
    log_info "Resuming service..."
    snow spcs service resume "${SERVICE_NAME}" \
        --database "${DATABASE_NAME}" \
        --schema "${SCHEMA_NAME}"
    log_success "Service resumed"
    sleep 10
    
else
    # Create new service (first time only)
    log_info "Creating new service..."
    CREATE SERVICE ${SERVICE_NAME} ...
fi
```

---

## Workflow Comparison

### Old Workflow (Drop/Recreate)

```
┌─────────────────────────────────────────────────────────┐
│ 1. Check if service exists                             │
│    ✓ Service found: BORDEREAU_APP                      │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 2. Drop service                                         │
│    ✗ Endpoint: bordereau-app.bd3h.svc.spcs.internal    │
│    ✗ Service deleted                                    │
│    ✗ All connections lost                              │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 3. Wait for cleanup (10 seconds)                       │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Create new service                                   │
│    ✓ New endpoint: bordereau-app.xyz9.svc.spcs.internal│
│    ✗ Endpoint changed!                                 │
└─────────────────────────────────────────────────────────┘
```

**Total Time**: ~30-40 seconds  
**Endpoint**: **CHANGED** ❌

### New Workflow (Suspend/Upgrade/Resume)

```
┌─────────────────────────────────────────────────────────┐
│ 1. Check if service exists                             │
│    ✓ Service found: BORDEREAU_APP                      │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 2. Suspend service                                      │
│    ✓ Service suspended                                 │
│    ✓ Endpoint preserved                                │
│    ⏸ Service paused                                     │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 3. Upgrade service                                      │
│    ✓ New images applied                                │
│    ✓ New spec applied                                  │
│    ✓ Endpoint still preserved                          │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Resume service                                       │
│    ✓ Service running                                   │
│    ✓ Same endpoint: bordereau-app.bd3h.svc.spcs.internal│
│    ✓ Endpoint unchanged!                               │
└─────────────────────────────────────────────────────────┘
```

**Total Time**: ~20-25 seconds  
**Endpoint**: **PRESERVED** ✅

---

## Deployment Output

### Successful Upgrade

```bash
[INFO] Checking if service exists...
[INFO] Service 'BORDEREAU_APP' already exists. Using suspend/upgrade/resume workflow...

[INFO] Suspending service...
+-------------------------------------------+
| status | Statement executed successfully. |
+-------------------------------------------+
[SUCCESS] Service suspended

[INFO] Waiting for service to suspend...

[INFO] Upgrading service with new images...
+-------------------------------------------+
| status | Statement executed successfully. |
+-------------------------------------------+
[SUCCESS] Service upgraded

[INFO] Resuming service...
+-------------------------------------------+
| status | Statement executed successfully. |
+-------------------------------------------+
[SUCCESS] Service resumed

[INFO] Waiting for service to be ready...

[INFO] Getting service endpoint...
[SUCCESS] Service endpoint: https://bordereau-app.bd3h.svc.spcs.internal

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🎉 DEPLOYMENT SUCCESSFUL!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Application (Frontend):
    https://bordereau-app.bd3h.svc.spcs.internal  ← Same endpoint!
```

---

## Benefits

### 1. Stable Endpoint URL

**Before:**
```
Deployment 1: https://bordereau-app.bd3h.svc.spcs.internal
Deployment 2: https://bordereau-app.xyz9.svc.spcs.internal  ← Changed!
Deployment 3: https://bordereau-app.abc1.svc.spcs.internal  ← Changed again!
```

**After:**
```
Deployment 1: https://bordereau-app.bd3h.svc.spcs.internal
Deployment 2: https://bordereau-app.bd3h.svc.spcs.internal  ← Same!
Deployment 3: https://bordereau-app.bd3h.svc.spcs.internal  ← Still same!
```

### 2. No Configuration Updates

**Before:**
- Update all client configurations
- Update documentation
- Update bookmarks
- Notify all users

**After:**
- No updates needed
- Documentation stays accurate
- Bookmarks still work
- Users unaffected

### 3. Faster Deployments

**Before:**
- Drop service: ~5 seconds
- Wait for cleanup: 10 seconds
- Create service: ~15-20 seconds
- **Total: ~30-40 seconds**

**After:**
- Suspend: ~2 seconds
- Wait: 5 seconds
- Upgrade: ~5 seconds
- Resume: ~5 seconds
- Wait: 10 seconds
- **Total: ~20-25 seconds**

### 4. Better Production Practice

**Before:**
- Destructive operation (drop)
- Complete service recreation
- Higher risk of issues

**After:**
- Non-destructive operation (suspend)
- In-place upgrade
- Lower risk, easier rollback

---

## Service States

### Suspend

```bash
snow spcs service suspend BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

**What happens:**
- Service stops processing requests
- Containers are stopped
- Resources are released
- **Endpoint is preserved**
- Service metadata retained

### Upgrade

```bash
snow spcs service upgrade BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --spec-path /tmp/unified_service_spec.yaml
```

**What happens:**
- New spec file is applied
- New image references are updated
- Configuration changes are applied
- Service remains suspended
- **Endpoint still preserved**

### Resume

```bash
snow spcs service resume BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

**What happens:**
- New containers are started
- New images are pulled
- Service becomes available
- **Same endpoint is used**
- Ready to serve traffic

---

## First-Time Deployment

For new services (first deployment), the script still uses `CREATE SERVICE`:

```bash
if [ -n "$SERVICE_EXISTS" ]; then
    # Existing service: suspend/upgrade/resume
    ...
else
    # New service: create
    log_info "Creating new service..."
    CREATE SERVICE ${SERVICE_NAME} ...
fi
```

**Flow:**
1. Check if service exists
2. If **exists**: Use suspend/upgrade/resume
3. If **not exists**: Create new service

---

## Rollback Strategy

### If Upgrade Fails

```bash
# Service is suspended, so rollback is easy
snow spcs service resume BORDEREAU_APP  # Resume with old images

# Or upgrade again with previous spec
snow spcs service upgrade BORDEREAU_APP --spec-path old_spec.yaml
snow spcs service resume BORDEREAU_APP
```

### If Issues After Resume

```bash
# Suspend and rollback
snow spcs service suspend BORDEREAU_APP
snow spcs service upgrade BORDEREAU_APP --spec-path previous_spec.yaml
snow spcs service resume BORDEREAU_APP
```

---

## Testing

### Test Endpoint Preservation

```bash
# Get endpoint before deployment
ENDPOINT_BEFORE=$(snow spcs service list \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --format json | \
  jq -r '.[] | select(.name == "BORDEREAU_APP") | .dns_name')

echo "Endpoint before: $ENDPOINT_BEFORE"

# Deploy
./deploy_container.sh

# Get endpoint after deployment
ENDPOINT_AFTER=$(snow spcs service list \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --format json | \
  jq -r '.[] | select(.name == "BORDEREAU_APP") | .dns_name')

echo "Endpoint after: $ENDPOINT_AFTER"

# Verify they're the same
if [ "$ENDPOINT_BEFORE" = "$ENDPOINT_AFTER" ]; then
  echo "✅ Endpoint preserved!"
else
  echo "❌ Endpoint changed!"
fi
```

### Test Service Availability

```bash
# Before deployment
curl https://bordereau-app.bd3h.svc.spcs.internal/api/health

# Deploy
./deploy_container.sh

# After deployment (same URL!)
curl https://bordereau-app.bd3h.svc.spcs.internal/api/health
```

---

## Verification

### Check Service Status

```bash
snow spcs service status BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

### Check Service Details

```bash
snow spcs service describe BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

### Check Endpoint

```bash
snow spcs service list \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --format json | \
  jq '.[] | select(.name == "BORDEREAU_APP") | {name, dns_name, status}'
```

**Expected Output:**
```json
{
  "name": "BORDEREAU_APP",
  "dns_name": "bordereau-app.bd3h.svc.spcs.internal",
  "status": "RUNNING"
}
```

---

## Troubleshooting

### Service Stuck in SUSPENDED State

```bash
# Force resume
snow spcs service resume BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# Check status
snow spcs service status BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

### Upgrade Fails

```bash
# Check service logs
snow spcs service logs BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --container-name backend

# Resume with old config
snow spcs service resume BORDEREAU_APP
```

### Service Won't Resume

```bash
# Check compute pool
snow spcs compute-pool describe BORDEREAU_COMPUTE_POOL

# Check service events
snow spcs service status BORDEREAU_APP --verbose

# If needed, drop and recreate
snow spcs service drop BORDEREAU_APP
./deploy_container.sh
```

---

## Best Practices

### 1. Always Test in Non-Production First

```bash
# Test deployment
./deploy_container.sh

# Verify endpoint
curl https://bordereau-app.bd3h.svc.spcs.internal/api/health

# Check logs
snow spcs service logs BORDEREAU_APP --container-name backend
```

### 2. Monitor During Upgrade

```bash
# In one terminal: deploy
./deploy_container.sh

# In another terminal: watch status
watch -n 2 'snow spcs service status BORDEREAU_APP'
```

### 3. Keep Spec Files Versioned

```bash
# Save spec with version
cp /tmp/unified_service_spec.yaml \
   deployment/specs/unified_service_spec_v1.2.3.yaml

# Can rollback if needed
snow spcs service suspend BORDEREAU_APP
snow spcs service upgrade BORDEREAU_APP \
  --spec-path deployment/specs/unified_service_spec_v1.2.2.yaml
snow spcs service resume BORDEREAU_APP
```

---

## Related Documentation

- **Snowflake SPCS Documentation**: Service upgrade workflow
- **UPGRADE_METHOD_SUMMARY.md**: Original upgrade method documentation
- **deploy_container.sh**: Deployment script

---

## Quick Reference

### Suspend/Upgrade/Resume

```bash
# Suspend
snow spcs service suspend SERVICE_NAME \
  --database DATABASE \
  --schema SCHEMA

# Upgrade
snow spcs service upgrade SERVICE_NAME \
  --database DATABASE \
  --schema SCHEMA \
  --spec-path spec.yaml

# Resume
snow spcs service resume SERVICE_NAME \
  --database DATABASE \
  --schema SCHEMA
```

### Check Endpoint

```bash
snow spcs service list \
  --database DATABASE \
  --schema SCHEMA \
  --format json | \
  jq -r '.[] | select(.name == "SERVICE_NAME") | .dns_name'
```

---

## Status

**Status**: ✅ Implemented and Tested  
**Deployment**: January 21, 2026  
**Service**: BORDEREAU_APP  
**Endpoint**: https://bordereau-app.bd3h.svc.spcs.internal (preserved)

**Benefits**:
- Endpoint URL preserved across deployments
- Faster deployment times
- Lower risk of issues
- Better production practice

**Last Updated**: January 21, 2026
