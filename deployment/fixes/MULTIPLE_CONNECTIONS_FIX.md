# Multiple Connections Handling Fix

**Date**: January 21, 2026  
**Status**: ✅ Fixed

---

## Problem

When multiple Snow CLI connections were configured, the deployment script wasn't properly handling connection selection:

1. **Only showed default connection** - Didn't display all available connections
2. **Limited choice** - Asked "Use this connection?" without showing alternatives
3. **No selection menu** - Couldn't choose between DEV, PROD, STAGING, etc.
4. **Confusing flow** - `check_snow_connection.sh` and `deploy.sh` had overlapping logic

---

## Root Cause

**File**: `deployment/check_snow_connection.sh`

The script was:
1. Only retrieving the default connection (line 38)
2. Asking a yes/no question about that one connection
3. Not showing all available connections
4. Not delegating to `deploy.sh` for proper connection selection

---

## Fix Applied

### Enhanced `check_snow_connection.sh`

**Before**:
```bash
# Only got default connection
CONNECTION_NAME=$(snow connection list --format json | jq -r '.[] | select(.is_default == true) | .connection_name')

# Only showed that one connection
echo "Current connection: ${CONNECTION_NAME}"

# Asked yes/no
read -p "Use this connection? (y/n): " use_connection
```

**After**:
```bash
# Get ALL connections
mapfile -t connections < <(snow connection list --format json | jq -r '.[].connection_name')

# Show ALL connections
snow connection list

# Handle based on count
if [[ ${#connections[@]} -eq 1 ]]; then
    # Single connection - ask to use it
    read -p "Use this connection? (y/n): " use_connection
elif [[ ${#connections[@]} -gt 1 ]]; then
    # Multiple connections - let deploy.sh handle selection
    echo "Multiple connections found - selection will be prompted during deployment"
    exit 0
fi
```

---

## How It Works Now

### Scenario 1: Single Connection

```
check_snow_connection.sh
  ├─ Finds 1 connection: "DEPLOYMENT"
  ├─ Shows connection details
  │
  ├─ If USE_DEFAULT_CONNECTION="true"
  │   └─ Auto-accepts ✅
  │
  └─ If USE_DEFAULT_CONNECTION="false"
      └─ Asks: "Use this connection? (y/n)" ✅
```

### Scenario 2: Multiple Connections + USE_DEFAULT_CONNECTION="true"

```
check_snow_connection.sh
  ├─ Finds 3 connections: DEV, PROD (default), STAGING
  ├─ Shows all connections
  ├─ Checks USE_DEFAULT_CONNECTION="true"
  └─ Auto-selects default (PROD) ✅

deploy.sh
  └─ Uses PROD connection (no prompt) ✅
```

### Scenario 3: Multiple Connections + USE_DEFAULT_CONNECTION="false"

```
check_snow_connection.sh
  ├─ Finds 3 connections: DEV, PROD (default), STAGING
  ├─ Shows all connections
  ├─ Checks USE_DEFAULT_CONNECTION="false"
  └─ Passes control to deploy.sh ✅

deploy.sh
  ├─ Shows connection menu:
  │   1) DEV
  │   2) PROD (default)
  │   3) STAGING
  ├─ Prompts: "Select connection number [1-3]:" ✅
  └─ Uses selected connection ✅
```

---

## Configuration Options

### Option 1: Always Use Default (CI/CD)

```bash
# default.config
USE_DEFAULT_CONNECTION="true"
AUTO_APPROVE="true"
```

**Behavior**:
- ✅ No prompts at all
- ✅ Uses default connection automatically
- ✅ Perfect for automated deployments

### Option 2: Always Prompt (Interactive)

```bash
# custom.config
USE_DEFAULT_CONNECTION="false"
AUTO_APPROVE="false"
```

**Behavior**:
- ✅ Shows all connections
- ✅ Prompts for selection
- ✅ Prompts for deployment approval
- ✅ Perfect for manual deployments

### Option 3: Specific Connection (Production)

```bash
# prod.config
SNOWFLAKE_CONNECTION="PRODUCTION"
AUTO_APPROVE="false"
```

**Behavior**:
- ✅ Uses specified connection (no prompt)
- ✅ Prompts for deployment approval
- ✅ Perfect for production deployments

---

## Examples

### Example 1: Development Environment

**Setup**:
```bash
# Configure connections
snow connection add --connection-name DEV --account dev-account ... --default
snow connection add --connection-name LOCAL --account local-account ...
```

**Deploy with prompts**:
```bash
# custom.config
USE_DEFAULT_CONNECTION="false"

./deploy.sh custom.config
```

**Output**:
```
Available Snowflake Connections:

  1) DEV (default)
  2) LOCAL

Select connection number [1-2]: 1
Selected connection: DEV
```

### Example 2: Production Environment

**Setup**:
```bash
# Configure connections
snow connection add --connection-name DEV --account dev-account ...
snow connection add --connection-name STAGING --account staging-account ...
snow connection add --connection-name PROD --account prod-account ... --default
```

**Deploy automatically**:
```bash
# prod.config
USE_DEFAULT_CONNECTION="true"
AUTO_APPROVE="true"

./deploy.sh prod.config
```

**Output**:
```
✓ Using default connection: PROD (USE_DEFAULT_CONNECTION=true)

Deploying to PROD...
```

### Example 3: Multi-Environment Setup

**Setup**:
```bash
# Configure all environments
snow connection add --connection-name DEV --account dev ...
snow connection add --connection-name QA --account qa ...
snow connection add --connection-name STAGING --account staging ...
snow connection add --connection-name PROD --account prod ... --default
```

**Interactive deployment**:
```bash
# No config specified - prompts for everything
./deploy.sh
```

**Output**:
```
Available Snowflake Connections:

  1) DEV
  2) QA
  3) STAGING
  4) PROD (default)

Select connection number [1-4]: 3
Selected connection: STAGING

═══════════════════════════════════════════
  DEPLOYMENT CONFIGURATION
═══════════════════════════════════════════

Connection: STAGING
Database: BORDEREAU_PROCESSING_PIPELINE
...

Proceed with deployment? (y/n): y
```

---

## Benefits

### 1. Clear Connection Selection
- ✅ Shows ALL available connections
- ✅ Indicates which is default
- ✅ Numbered menu for easy selection

### 2. Flexible Configuration
- ✅ Fully automated (CI/CD)
- ✅ Interactive (manual)
- ✅ Specific connection (production)

### 3. Better User Experience
- ✅ No confusion about available connections
- ✅ Clear indication of what will be used
- ✅ Easy to switch between environments

### 4. Safer Deployments
- ✅ See all options before selecting
- ✅ Confirm connection before deploying
- ✅ Prevent accidental wrong-environment deployments

---

## Testing

### Test 1: Single Connection

```bash
# Setup
snow connection add --connection-name DEV --account xxx ... --default

# Test
./deploy.sh

# Expected: Uses DEV automatically (if USE_DEFAULT_CONNECTION="true")
#           or asks "Use this connection?" (if false)
```

### Test 2: Multiple Connections (Auto)

```bash
# Setup
snow connection add --connection-name DEV --account xxx ...
snow connection add --connection-name PROD --account yyy ... --default

# Config
USE_DEFAULT_CONNECTION="true"

# Test
./deploy.sh

# Expected: Uses PROD automatically (no prompt)
```

### Test 3: Multiple Connections (Interactive)

```bash
# Setup
snow connection add --connection-name DEV --account xxx ...
snow connection add --connection-name STAGING --account yyy ...
snow connection add --connection-name PROD --account zzz ... --default

# Config
USE_DEFAULT_CONNECTION="false"

# Test
./deploy.sh

# Expected: Shows menu with all 3 connections, prompts for selection
```

---

## Related Files

### Scripts
- `deployment/check_snow_connection.sh` - Connection validation (UPDATED)
- `deployment/deploy.sh` - Main deployment script (unchanged - already correct)

### Configuration
- `deployment/default.config` - Default settings
- `deployment/custom.config.example` - Custom config template

### Documentation
- `deployment/USE_DEFAULT_CONNECTION_FIX.md` - Original fix documentation (UPDATED)
- `deployment/README.md` - Deployment guide

---

## Summary

✅ **Issue**: Multiple connections not properly displayed or selectable  
✅ **Root Cause**: `check_snow_connection.sh` only showed default connection  
✅ **Fix**: Enhanced to show all connections and delegate selection to `deploy.sh`  
✅ **Result**: 
   - Single connection: Simple yes/no prompt
   - Multiple connections + USE_DEFAULT_CONNECTION="true": Auto-select default
   - Multiple connections + USE_DEFAULT_CONNECTION="false": Show selection menu

---

**Fixed**: January 21, 2026  
**Files Modified**: `deployment/check_snow_connection.sh`, `deployment/USE_DEFAULT_CONNECTION_FIX.md`  
**Status**: ✅ Ready to Use
