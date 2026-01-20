# Deploy Script Update - Container Deployment Integration

**Date**: January 19, 2026  
**Status**: ✅ Complete

---

## Overview

Updated the master `deploy.sh` script to optionally deploy containers to Snowpark Container Services (SPCS) after deploying the database layers.

---

## Changes Made

### 1. Added Optional Container Deployment Step

After deploying Bronze, Silver, and Gold layers, the script now:

1. **Prompts the user** whether to deploy to Snowpark Container Services
2. **Shows what will happen**:
   - Build Docker images for backend and frontend
   - Push images to Snowflake image repository
   - Create compute pool (if needed)
   - Deploy unified service with health checks
3. **Calls `deploy_container.sh`** if user confirms
4. **Tracks deployment status** in the summary

### 2. Updated Help Documentation

- Added step 9 to deployment process (SPCS deployment)
- Updated configuration notes about AUTO_APPROVE behavior
- Clarified that container deployment is optional

### 3. Enhanced Deployment Summary

The deployment summary now shows:
- Whether containers were deployed to SPCS
- Different "Next Steps" based on deployment choice

---

## Usage

### Interactive Deployment (Default)

```bash
cd deployment
./deploy.sh
```

After database layers are deployed, you'll see:

```
═══════════════════════════════════════════════════════════
OPTIONAL: SNOWPARK CONTAINER SERVICES DEPLOYMENT
═══════════════════════════════════════════════════════════

Would you like to deploy the application to Snowpark Container Services?
This will:
  • Build Docker images for backend and frontend
  • Push images to Snowflake image repository
  • Create compute pool (if needed)
  • Deploy unified service with health checks

Deploy to Snowpark Container Services? (y/n) [n]:
```

**Options**:
- Press `y` to deploy containers
- Press `n` or Enter to skip (default)

### Automated Deployment

With `AUTO_APPROVE=true` in config, the script:
- Skips all confirmation prompts
- **Does NOT deploy containers** (containers are optional)
- Completes database deployment only

To force container deployment in automated mode, run separately:

```bash
./deploy.sh && ./deploy_container.sh
```

---

## Deployment Flow

```
┌─────────────────────────────────────────┐
│  1. Validate Prerequisites             │
│  2. Check Roles & Permissions          │
│  3. Deploy Bronze Layer                │
│  4. Deploy Silver Layer                │
│  5. Deploy Gold Layer                  │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Prompt: Deploy to SPCS? (y/n)         │
└─────────────────────────────────────────┘
         ↓ Yes            ↓ No
┌─────────────────┐  ┌──────────────────┐
│ 6. Build Images │  │ Skip Containers  │
│ 7. Push to SPCS │  │                  │
│ 8. Deploy Svc   │  │                  │
└─────────────────┘  └──────────────────┘
         ↓                    ↓
┌─────────────────────────────────────────┐
│  Deployment Summary                     │
│  - Database Layers: ✓                   │
│  - Containers: ✓ or ⊘                   │
└─────────────────────────────────────────┘
```

---

## Deployment Summary Examples

### With Containers Deployed

```
╔═══════════════════════════════════════════════════════════╗
║                  DEPLOYMENT SUMMARY                       ║
╠═══════════════════════════════════════════════════════════╣
║  Connection: DEPLOYMENT
║  Database: BORDEREAU_PROCESSING_PIPELINE
║  Bronze Schema: BRONZE
║  Silver Schema: SILVER
║  Gold Schema: GOLD
║  Bronze Layer: ✓ Deployed
║  Silver Layer: ✓ Deployed
║  Gold Layer: ✓ Deployed
║  Containers: ✓ Deployed to SPCS
║  Duration: 15m 32s
║  Log: logs/deployment_20260119_143022.log
╚═══════════════════════════════════════════════════════════╝

Next steps:
1. Check service status:
   snow spcs service status BORDEREAU_APP --connection DEPLOYMENT

2. Get service endpoint:
   snow spcs service list-endpoints BORDEREAU_APP --connection DEPLOYMENT

3. Upload sample data:
   snow stage put sample_data/claims_data/provider_a/*.csv @BRONZE.SRC/provider_a/ --connection DEPLOYMENT
```

### Without Containers

```
╔═══════════════════════════════════════════════════════════╗
║                  DEPLOYMENT SUMMARY                       ║
╠═══════════════════════════════════════════════════════════╣
║  Connection: DEPLOYMENT
║  Database: BORDEREAU_PROCESSING_PIPELINE
║  Bronze Schema: BRONZE
║  Silver Schema: SILVER
║  Gold Schema: GOLD
║  Bronze Layer: ✓ Deployed
║  Silver Layer: ✓ Deployed
║  Gold Layer: ✓ Deployed
║  Containers: ⊘ Not deployed
║  Duration: 8m 45s
║  Log: logs/deployment_20260119_143022.log
╚═══════════════════════════════════════════════════════════╝

Next steps:
1. Start containerized apps locally (React + FastAPI):
   docker-compose up -d

   OR deploy to Snowpark Container Services:
   cd deployment && ./deploy_container.sh

2. Upload sample data:
   snow stage put sample_data/claims_data/provider_a/*.csv @BRONZE.SRC/provider_a/ --connection DEPLOYMENT

3. Resume tasks (optional - tasks are created in SUSPENDED state):
   snow sql --connection DEPLOYMENT -q "USE DATABASE BORDEREAU_PROCESSING_PIPELINE; USE SCHEMA BRONZE; ALTER TASK discover_files_task RESUME;"
```

---

## Benefits

### 1. Streamlined Workflow
- Single command for complete deployment
- No need to remember separate container script
- Clear prompts guide the user

### 2. Flexibility
- Optional container deployment
- Can skip for database-only deployments
- Easy to run containers later if needed

### 3. Better User Experience
- Clear explanation of what will happen
- Shows deployment status in summary
- Provides appropriate next steps

### 4. Automation Friendly
- AUTO_APPROVE mode works as expected
- Containers remain optional in automated mode
- Can chain commands for full automation

---

## Backward Compatibility

✅ **Fully backward compatible**

- Existing workflows continue to work
- No breaking changes to script interface
- Container deployment is purely additive
- Can still run `deploy_container.sh` separately

---

## Testing

### Test Scenarios

1. **Interactive with containers**:
   ```bash
   ./deploy.sh
   # Answer 'y' to container prompt
   ```

2. **Interactive without containers**:
   ```bash
   ./deploy.sh
   # Answer 'n' to container prompt
   ```

3. **Automated mode**:
   ```bash
   AUTO_APPROVE=true ./deploy.sh
   # Containers skipped automatically
   ```

4. **Separate container deployment**:
   ```bash
   ./deploy.sh
   # Answer 'n'
   # Later:
   ./deploy_container.sh
   ```

---

## Configuration

### AUTO_APPROVE Behavior

**Before**:
- `AUTO_APPROVE=true` skipped database confirmation only

**After**:
- `AUTO_APPROVE=true` skips database confirmation
- Container deployment defaults to 'no' (not prompted)
- Containers remain optional in automated mode

### Custom Configuration

No new configuration variables needed. The script uses existing settings from `deploy_container.sh`.

---

## Files Modified

1. **`deployment/deploy.sh`**
   - Added container deployment prompt section
   - Updated deployment summary
   - Enhanced next steps based on deployment choice
   - Updated help documentation

2. **`deployment/DEPLOY_SCRIPT_UPDATE.md`** (this file)
   - Documentation of changes

---

## Related Scripts

- **`deploy.sh`** - Master deployment script (updated)
- **`deploy_container.sh`** - Container deployment script (unchanged)
- **`deploy_bronze.sh`** - Bronze layer deployment (unchanged)
- **`deploy_silver.sh`** - Silver layer deployment (unchanged)
- **`deploy_gold.sh`** - Gold layer deployment (unchanged)

---

## Future Enhancements

Potential improvements:

1. **Environment Variable Control**
   - Add `DEPLOY_CONTAINERS=true/false` to config
   - Allow forcing container deployment in AUTO_APPROVE mode

2. **Container Configuration**
   - Pass database settings to container deployment
   - Ensure consistency between layers and containers

3. **Health Check Integration**
   - Wait for service to be healthy
   - Verify endpoints are accessible
   - Run smoke tests

4. **Rollback Support**
   - Add option to rollback containers on failure
   - Preserve previous service version

---

## Summary

✅ **Update Complete**

**Changes**:
- Added optional container deployment to `deploy.sh`
- Enhanced deployment summary with container status
- Updated help documentation
- Improved next steps guidance

**Benefits**:
- Streamlined deployment workflow
- Better user experience
- Flexible and automation-friendly
- Fully backward compatible

**Usage**:
```bash
cd deployment
./deploy.sh
# Answer 'y' or 'n' when prompted for container deployment
```

---

**Update Date**: January 19, 2026  
**Version**: 1.0  
**Status**: ✅ Complete
