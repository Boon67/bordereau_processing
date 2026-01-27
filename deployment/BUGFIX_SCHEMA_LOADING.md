# Bug Fix: Sample Schema Loading Failure

## Issue

Sample Silver target schemas were not loading during deployment, causing the frontend to show "No target schemas found" message.

## Root Cause

The `load_sample_schemas.sh` script was calling `snow sql -f load_sample_schemas.sql`, but the SQL file used Snowflake variables (`$DATABASE_NAME`, `$SILVER_SCHEMA_NAME`) that were not being substituted by the Snow CLI.

The SQL file had:
```sql
SET DATABASE_NAME = '$DATABASE_NAME';
SET SILVER_SCHEMA_NAME = '$SILVER_SCHEMA_NAME';
USE DATABASE IDENTIFIER($DATABASE_NAME);
USE SCHEMA IDENTIFIER($SILVER_SCHEMA_NAME);
```

This resulted in an error: "Object does not exist, or operation cannot be performed" because the variables were not being replaced with actual values.

## Solution

Modified `load_sample_schemas.sh` to execute the COPY INTO command directly using `snow sql -q` with inline SQL instead of using `-f` with a file. This allows proper variable substitution using shell variables.

### Changes Made

#### 1. `deployment/load_sample_schemas.sh`
- Changed from `snow sql -f load_sample_schemas.sql` to `snow sql -q "..."` with inline SQL
- Variables are now properly substituted: `${DATABASE_NAME}`, `${SILVER_SCHEMA_NAME}`
- The COPY INTO command is embedded directly in the shell script

#### 2. `sample_data/config/load_sample_schemas.sql`
- Removed the variable SET statements that weren't working
- Added note that script expects database/schema to be already set
- File is now primarily for reference/documentation

## Testing

Tested the fix by:
1. Truncating the `target_schemas` table
2. Running `./load_sample_schemas.sh DEPLOYMENT`
3. Verifying 62 rows were loaded across 4 tables

Result:
```
✓ DENTAL_CLAIMS: 14 columns
✓ MEDICAL_CLAIMS: 14 columns
✓ MEMBER_ELIGIBILITY: 18 columns
✓ PHARMACY_CLAIMS: 16 columns
```

## Impact

- Sample schemas now load successfully during deployment when `LOAD_SAMPLE_SCHEMAS="true"`
- Frontend will display schemas correctly
- Users can immediately start creating tables and defining mappings

## Files Modified

1. `deployment/load_sample_schemas.sh` - Fixed to use inline SQL with proper variable substitution
2. `sample_data/config/load_sample_schemas.sql` - Simplified for reference only

## Prevention

For future scripts that need to use Snow CLI:
- Use `snow sql -q "..."` with inline SQL for variable substitution
- OR use `sed` to replace variables before passing to `snow sql -f`
- Document which approach is being used

## Related Issues

This fix also resolves:
- Empty schemas page in frontend
- "No target schemas found" message
- Inability to create Silver tables
- Deployment showing "Sample Schemas: ⊘ Not loaded"
