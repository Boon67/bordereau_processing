# Privilege Check Enhancement

**Last Updated**: January 23, 2026

## Overview

The `deploy.sh` script now automatically checks for container service privileges and notifies users if they're missing, similar to how it handles the `EXECUTE TASK` privilege.

## What Was Added

### Automatic Privilege Checking

The deployment script now checks for two container service privileges on the admin role:

1. **CREATE COMPUTE POOL ON ACCOUNT** - Required to create compute pools
2. **BIND SERVICE ENDPOINT ON ACCOUNT** - Required to create public endpoints

### User Notification

If privileges are missing, the script:
- ✅ Displays a clear warning message
- ✅ Shows exactly which privileges are missing
- ✅ Provides the SQL commands to grant them
- ✅ Offers the quick command to run the setup script
- ✅ Allows deployment to continue (containers are optional)
- ✅ Skips the container deployment prompt if privileges aren't available

## Example Output

### When Privileges Are Missing

```
[INFO] Checking container service privileges...
[WARNING] Container service privileges not fully granted to BORDEREAU_PROCESSING_PIPELINE_ADMIN
[WARNING]   Missing: CREATE COMPUTE POOL ON ACCOUNT
[WARNING]   Missing: BIND SERVICE ENDPOINT ON ACCOUNT
[INFO] These privileges are required for Snowpark Container Services deployment
[INFO] To grant these privileges, run the following SQL as ACCOUNTADMIN:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
USE ROLE ACCOUNTADMIN;
GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[INFO] Or run: snow sql -f bronze/0_Setup_Container_Privileges.sql --connection DEPLOYMENT -D DATABASE_NAME=BORDEREAU_PROCESSING_PIPELINE

[WARNING] Container deployment will be skipped if these privileges are not granted
[INFO] You can continue with Bronze/Silver/Gold deployment and add containers later
```

### When Privileges Are Granted

```
[INFO] Checking container service privileges...
[SUCCESS] Container service privileges verified for BORDEREAU_PROCESSING_PIPELINE_ADMIN
```

## Deployment Flow

### Before This Enhancement

1. User runs `deploy.sh`
2. Script checks EXECUTE TASK privilege
3. Script deploys Bronze/Silver/Gold layers
4. Script prompts for container deployment
5. **Container deployment fails** with cryptic error
6. User has to debug and figure out missing privileges

### After This Enhancement

1. User runs `deploy.sh`
2. Script checks EXECUTE TASK privilege
3. **Script checks container service privileges** ✨
4. **If missing, displays clear instructions** ✨
5. Script deploys Bronze/Silver/Gold layers
6. **Script skips container prompt if privileges missing** ✨
7. User can grant privileges and run container deployment later

## Benefits

### 1. **Proactive Error Prevention**
- Catches missing privileges before deployment fails
- Saves time by not attempting container deployment without prerequisites

### 2. **Clear User Guidance**
- Shows exact SQL commands needed
- Provides alternative quick command
- Explains what each privilege is for

### 3. **Non-Blocking**
- Deployment continues even if container privileges are missing
- Bronze/Silver/Gold layers deploy successfully
- Containers can be added later

### 4. **Consistent Experience**
- Matches the pattern used for EXECUTE TASK privilege
- Familiar workflow for users

## Implementation Details

### Check Logic

```bash
# Check if CREATE COMPUTE POOL is granted
CREATE_COMPUTE_POOL_GRANTED=$(snow sql --connection "$CONNECTION_NAME" --format json \
    -q "SHOW GRANTS TO ROLE ${ADMIN_ROLE_NAME}" 2>/dev/null | \
    jq -r '.[] | select(.privilege == "CREATE COMPUTE POOL" and .granted_on == "ACCOUNT") | .privilege' \
    2>/dev/null || echo "")

# Check if BIND SERVICE ENDPOINT is granted
BIND_ENDPOINT_GRANTED=$(snow sql --connection "$CONNECTION_NAME" --format json \
    -q "SHOW GRANTS TO ROLE ${ADMIN_ROLE_NAME}" 2>/dev/null | \
    jq -r '.[] | select(.privilege == "BIND SERVICE ENDPOINT" and .granted_on == "ACCOUNT") | .privilege' \
    2>/dev/null || echo "")
```

### Conditional Prompting

```bash
# Skip container prompt if privileges not available
if [[ -z "$CREATE_COMPUTE_POOL_GRANTED" ]] || [[ -z "$BIND_ENDPOINT_GRANTED" ]]; then
    log_message INFO "Skipping container deployment prompt (privileges not granted)"
    DEPLOY_CONTAINERS_DECISION="n"
else
    # Show prompt and ask user
    read -p "Deploy to Snowpark Container Services? (y/n) [n]: "
fi
```

## User Workflow

### First-Time Deployment

1. Run `deploy.sh`
2. See privilege check warning
3. Copy and run the SQL commands as ACCOUNTADMIN
4. Continue with Bronze/Silver/Gold deployment
5. Run `deploy_container.sh` separately later

### Subsequent Deployments

1. Run `deploy.sh`
2. Privilege check passes ✓
3. Prompted for container deployment
4. Choose to deploy or skip

## Related Files

| File | Purpose |
|------|---------|
| `deployment/deploy.sh` | Main deployment script with privilege checks |
| `bronze/0_Setup_Container_Privileges.sql` | Script to grant container privileges |
| `deployment/CONTAINER_PRIVILEGES_SETUP.md` | Detailed privilege setup guide |
| `deployment/deploy_container.sh` | Container deployment script |

## Testing

### Test Missing Privileges

```bash
# Revoke privileges (as ACCOUNTADMIN)
USE ROLE ACCOUNTADMIN;
REVOKE CREATE COMPUTE POOL ON ACCOUNT FROM ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
REVOKE BIND SERVICE ENDPOINT ON ACCOUNT FROM ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;

# Run deployment
cd deployment
./deploy.sh

# Should see warning and SQL commands
```

### Test With Privileges

```bash
# Grant privileges (as ACCOUNTADMIN)
snow sql -f bronze/0_Setup_Container_Privileges.sql \
    --connection DEPLOYMENT \
    -D DATABASE_NAME=BORDEREAU_PROCESSING_PIPELINE

# Run deployment
cd deployment
./deploy.sh

# Should see success message and container prompt
```

## Summary

This enhancement makes the deployment process more user-friendly by:
- ✅ Checking privileges proactively
- ✅ Providing clear guidance when privileges are missing
- ✅ Allowing deployment to continue without blocking
- ✅ Preventing cryptic container deployment failures
- ✅ Maintaining consistency with existing privilege checks

Users now get a smooth deployment experience with clear feedback at every step! 🎉
