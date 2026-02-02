# Container Deployment Troubleshooting

## Error: "Failed to create stage"

### Symptoms
```
[ERROR] Failed to create stage
```

When running `deploy_container.sh` or `deploy_container_ghcr.sh`

### Root Cause

The role you're using doesn't have `CREATE STAGE` privilege on the target schema (usually `PUBLIC`).

### Solution 1: Grant Privilege (Recommended)

Run as `ACCOUNTADMIN` or `SYSADMIN`:

```sql
USE ROLE SYSADMIN;

-- Grant CREATE STAGE privilege
GRANT CREATE STAGE ON SCHEMA BORDEREAU_PROCESSING_PIPELINE.PUBLIC 
TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;

-- Also grant ALL PRIVILEGES if needed
GRANT ALL PRIVILEGES ON SCHEMA BORDEREAU_PROCESSING_PIPELINE.PUBLIC 
TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
```

### Solution 2: Use SYSADMIN for Container Operations (Recommended)

Use SYSADMIN only for container/stage operations while keeping your custom role for data operations:

```bash
# Edit or create deployment/custom.config
echo 'CONTAINER_ROLE="SYSADMIN"' >> deployment/custom.config

# Then run deployment
./deployment/deploy_container.sh
```

This allows your custom role to manage data while SYSADMIN handles container infrastructure.

### Solution 3: Use SYSADMIN for Everything

Temporarily use SYSADMIN for all deployment operations:

```bash
# Edit deployment/custom.config
SNOWFLAKE_ROLE="SYSADMIN"
CONTAINER_ROLE="SYSADMIN"

# Or set environment variable
export SNOWFLAKE_ROLE="SYSADMIN"

# Then run deployment
./deployment/deploy_container.sh
```

### Solution 4: Create Stage Manually

```sql
USE ROLE SYSADMIN;
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA PUBLIC;

CREATE STAGE IF NOT EXISTS SERVICE_SPECS
    COMMENT = 'Stage for Snowpark Container Service specifications';

-- Grant usage to your role
GRANT READ, WRITE ON STAGE SERVICE_SPECS 
TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
```

Then re-run the deployment.

---

## Error: "Compute pool does not exist"

### Solution

The script should create it automatically, but if it fails:

```sql
USE ROLE SYSADMIN;

CREATE COMPUTE POOL BORDEREAU_COMPUTE_POOL
    MIN_NODES = 1
    MAX_NODES = 3
    INSTANCE_FAMILY = CPU_X64_XS
    AUTO_RESUME = TRUE
    AUTO_SUSPEND_SECS = 3600;

GRANT USAGE ON COMPUTE POOL BORDEREAU_COMPUTE_POOL 
TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
GRANT MONITOR ON COMPUTE POOL BORDEREAU_COMPUTE_POOL 
TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
GRANT OPERATE ON COMPUTE POOL BORDEREAU_COMPUTE_POOL 
TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
```

---

## Error: "Image repository does not exist"

### Solution

```sql
USE ROLE SYSADMIN;
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA PUBLIC;

CREATE IMAGE REPOSITORY IF NOT EXISTS BORDEREAU_REPOSITORY;

GRANT READ ON IMAGE REPOSITORY BORDEREAU_REPOSITORY 
TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
GRANT WRITE ON IMAGE REPOSITORY BORDEREAU_REPOSITORY 
TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
```

---

## Error: "Failed to upload service specification"

### Cause

Usually means the stage exists but you don't have WRITE privilege.

### Solution

```sql
USE ROLE SYSADMIN;

GRANT READ, WRITE ON STAGE BORDEREAU_PROCESSING_PIPELINE.PUBLIC.SERVICE_SPECS 
TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
```

---

## Error: "Service already exists"

### Solution

Delete the existing service first:

```sql
USE ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA PUBLIC;

-- Check service status
SHOW SERVICES;

-- Drop service
DROP SERVICE IF EXISTS BORDEREAU_APP;
```

Then re-run deployment.

---

## General Troubleshooting Steps

### 1. Check Current Role and Privileges

```sql
-- Check current role
SELECT CURRENT_ROLE();

-- Check privileges
SHOW GRANTS TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
```

### 2. Verify Database and Schema Exist

```sql
SHOW DATABASES LIKE 'BORDEREAU_PROCESSING_PIPELINE';
SHOW SCHEMAS IN DATABASE BORDEREAU_PROCESSING_PIPELINE;
```

### 3. Check Compute Pool Status

```sql
SHOW COMPUTE POOLS;

-- Check specific pool
DESCRIBE COMPUTE POOL BORDEREAU_COMPUTE_POOL;
```

### 4. Check Image Repository

```sql
SHOW IMAGE REPOSITORIES IN SCHEMA BORDEREAU_PROCESSING_PIPELINE.PUBLIC;
```

### 5. List Existing Services

```sql
SHOW SERVICES IN SCHEMA BORDEREAU_PROCESSING_PIPELINE.PUBLIC;
```

---

## Required Privileges Summary

Your deployment role needs:

**On Database:**
- `USAGE`
- `CREATE SCHEMA`

**On Schema (PUBLIC):**
- `USAGE`
- `CREATE STAGE`
- `CREATE SERVICE`
- `CREATE IMAGE REPOSITORY`

**On Compute Pool:**
- `USAGE`
- `MONITOR`
- `OPERATE`

**On Image Repository:**
- `READ`
- `WRITE`

**On Stage:**
- `READ`
- `WRITE`

### Grant All Required Privileges

```sql
USE ROLE SYSADMIN;

SET ROLE_NAME = 'BORDEREAU_PROCESSING_PIPELINE_ADMIN';
SET DB_NAME = 'BORDEREAU_PROCESSING_PIPELINE';
SET SCHEMA_NAME = 'PUBLIC';

-- Database privileges
GRANT USAGE ON DATABASE IDENTIFIER($DB_NAME) TO ROLE IDENTIFIER($ROLE_NAME);
GRANT CREATE SCHEMA ON DATABASE IDENTIFIER($DB_NAME) TO ROLE IDENTIFIER($ROLE_NAME);

-- Schema privileges
GRANT USAGE ON SCHEMA IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME) TO ROLE IDENTIFIER($ROLE_NAME);
GRANT CREATE STAGE ON SCHEMA IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME) TO ROLE IDENTIFIER($ROLE_NAME);
GRANT CREATE SERVICE ON SCHEMA IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME) TO ROLE IDENTIFIER($ROLE_NAME);
GRANT CREATE IMAGE REPOSITORY ON SCHEMA IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME) TO ROLE IDENTIFIER($ROLE_NAME);

-- Or grant all privileges on schema
GRANT ALL PRIVILEGES ON SCHEMA IDENTIFIER($DB_NAME || '.' || $SCHEMA_NAME) TO ROLE IDENTIFIER($ROLE_NAME);
```

---

## Debugging Tips

### Enable Verbose Output

Edit `deploy_container.sh` and change:

```bash
execute_sql() {
    local sql="$1"
    local show_errors="${2:-false}"  # Change to "true" for debugging
    ...
}
```

### Check Snow CLI Connection

```bash
# Test connection
snow connection test

# List connections
snow connection list

# Check current connection
snow connection show
```

### View Full Error Messages

Run SQL commands directly to see full error:

```bash
snow sql -q "
USE DATABASE BORDEREAU_PROCESSING_PIPELINE;
USE SCHEMA PUBLIC;
CREATE STAGE IF NOT EXISTS SERVICE_SPECS;
"
```

---

## Contact Support

If issues persist:

1. Check Snowflake query history for full error messages
2. Verify account has Snowpark Container Services enabled
3. Contact Snowflake support with:
   - Account name
   - Role name
   - Full error message
   - Query ID from query history
