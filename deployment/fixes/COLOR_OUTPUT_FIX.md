# Color Output Fix for deploy_container.sh

**Date**: January 21, 2026  
**Status**: ✅ Fixed

---

## Problem

The deployment script's final summary was showing ANSI color codes literally instead of rendering them as colors:

```
  Check status:
    \033[0;36mcd deployment\033[0m
    \033[0;36m./manage_services.sh status\033[0m
```

Instead of:
```
  Check status:
    cd deployment          (in cyan color)
    ./manage_services.sh status    (in cyan color)
```

---

## Root Cause

**File**: `deployment/deploy_container.sh`  
**Lines**: 611, 614, 617, 619, 628-629, 632-633, 636

The `print_summary()` function was using `echo` instead of `echo -e` to output strings containing ANSI color codes.

### Why This Matters

- `echo` - Outputs text literally, including escape sequences
- `echo -e` - Interprets escape sequences (like `\033[0;36m` for cyan color)

### Example

```bash
# WRONG - Shows literal codes
echo "    ${CYAN}cd deployment${NC}"
# Output: \033[0;36mcd deployment\033[0m

# CORRECT - Shows colored text
echo -e "    ${CYAN}cd deployment${NC}"
# Output: cd deployment (in cyan)
```

---

## Fix Applied

### Changed Lines

**Lines with color codes changed from `echo` to `echo -e`:**

```bash
# Line 611 - Green endpoint URL
echo -e "    ${GREEN}${SERVICE_ENDPOINT}${NC}"

# Line 614 - Blue API URL
echo -e "    ${BLUE}${SERVICE_ENDPOINT}/api/health${NC}"

# Line 617 - Cyan curl command
echo -e "    ${CYAN}curl ${SERVICE_ENDPOINT}/api/health${NC}"

# Line 619 - Yellow provisioning message
echo -e "  ${YELLOW}Endpoint provisioning in progress...${NC}"

# Line 628 - Cyan cd command
echo -e "    ${CYAN}cd deployment${NC}"

# Line 629 - Cyan status command
echo -e "    ${CYAN}./manage_services.sh status${NC}"

# Line 632 - Cyan logs command (backend)
echo -e "    ${CYAN}./manage_services.sh logs backend 100${NC}"

# Line 633 - Cyan logs command (frontend)
echo -e "    ${CYAN}./manage_services.sh logs frontend 100${NC}"

# Line 636 - Cyan health command
echo -e "    ${CYAN}./manage_services.sh health${NC}"
```

---

## Endpoint Display

### How Endpoint is Retrieved

The script uses the Snowflake CLI (`snow`) to get the service endpoint:

**Function**: `get_service_endpoint()` (lines 555-588)

```bash
get_service_endpoint() {
    log_info "Getting service endpoint..."
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        # Query Snowflake for endpoint
        local endpoint_output=$(execute_sql "
            USE DATABASE ${DATABASE_NAME};
            USE SCHEMA ${SCHEMA_NAME};
            SHOW ENDPOINTS IN SERVICE ${SERVICE_NAME};
        " 2>/dev/null)
        
        # Parse endpoint from JSON output
        local endpoint=$(echo "$endpoint_output" | jq -r '.[2][0].ingress_url // empty' 2>/dev/null)
        
        # Check if endpoint is ready
        if [ -n "$endpoint" ] && [ "$endpoint" != "null" ] && [[ ! "$endpoint" =~ "provisioning" ]]; then
            SERVICE_ENDPOINT="https://${endpoint}"
            log_success "Service endpoint: $SERVICE_ENDPOINT"
            return 0
        fi
        
        # Wait and retry
        if [ $attempt -lt $max_attempts ]; then
            log_info "Endpoint not ready, waiting... (attempt $attempt/$max_attempts)"
            sleep 10
        fi
        
        ((attempt++))
    done
    
    # Endpoint not ready after max attempts
    log_warning "Endpoint not available yet. Check status later"
}
```

### Endpoint Retrieval Process

1. **Query Snowflake**: Uses `SHOW ENDPOINTS IN SERVICE` SQL command
2. **Parse JSON**: Extracts `ingress_url` from JSON output using `jq`
3. **Check Status**: Verifies endpoint is not "provisioning"
4. **Retry Logic**: Tries up to 10 times with 10-second intervals (up to 100 seconds total)
5. **Display**: Shows endpoint in summary or "provisioning" message

### Why Endpoint May Show "Provisioning"

Snowflake takes 2-3 minutes to provision public endpoints for SPCS services. If the script finishes before the endpoint is ready, it shows:

```
  Endpoint provisioning in progress...
  Check status: ./manage_services.sh status
```

You can check the endpoint later with:
```bash
cd deployment
./manage_services.sh status
```

---

## Result

### Before (Broken Colors)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🛠️  MANAGEMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Check status:
    \033[0;36mcd deployment\033[0m
    \033[0;36m./manage_services.sh status\033[0m

  View logs:
    \033[0;36m./manage_services.sh logs backend 100\033[0m
    \033[0;36m./manage_services.sh logs frontend 100\033[0m

  Run health check:
    \033[0;36m./manage_services.sh health\033[0m
```

### After (Proper Colors)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🛠️  MANAGEMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Check status:
    cd deployment                        (cyan)
    ./manage_services.sh status          (cyan)

  View logs:
    ./manage_services.sh logs backend 100    (cyan)
    ./manage_services.sh logs frontend 100   (cyan)

  Run health check:
    ./manage_services.sh health              (cyan)
```

---

## Color Codes Used

The script uses these ANSI color codes:

```bash
RED='\033[0;31m'      # Error messages
GREEN='\033[0;32m'    # Success messages, URLs
YELLOW='\033[1;33m'   # Warnings, "provisioning" messages
BLUE='\033[0;34m'     # API endpoints, labels
CYAN='\033[0;36m'     # Commands, code examples
NC='\033[0m'          # No Color (reset)
```

---

## Testing

### Test the Fix

Run the container deployment:

```bash
cd deployment
./deploy_container.sh
```

**Expected Output** (at end of deployment):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🎉 DEPLOYMENT SUCCESSFUL!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✅ Unified Service Deployed
     • Frontend + Backend in single service
     • Backend is internal-only (no public endpoint)
     • Frontend proxies /api/* to backend

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📍 ENDPOINT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Application (Frontend):
    https://f2cmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app  (green)

  API (via Frontend proxy):
    https://f2cmn2pb-.../api/health  (blue)

  Test:
    curl https://f2cmn2pb-.../api/health  (cyan)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🛠️  MANAGEMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Check status:
    cd deployment  (cyan)
    ./manage_services.sh status  (cyan)

  View logs:
    ./manage_services.sh logs backend 100  (cyan)
    ./manage_services.sh logs frontend 100  (cyan)

  Run health check:
    ./manage_services.sh health  (cyan)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

All commands should appear in **cyan color**, URLs in **green/blue**, and warnings in **yellow**.

---

## Summary

✅ **Issue**: ANSI color codes displayed literally instead of as colors  
✅ **Root Cause**: Using `echo` instead of `echo -e` for colored output  
✅ **Fix**: Changed 9 `echo` statements to `echo -e` in `print_summary()` function  
✅ **Endpoint**: Retrieved via `SHOW ENDPOINTS IN SERVICE` using Snowflake CLI  
✅ **Result**: Proper color rendering in deployment summary

---

**Fixed**: January 21, 2026  
**File**: `deployment/deploy_container.sh`  
**Status**: ✅ Ready to Use
