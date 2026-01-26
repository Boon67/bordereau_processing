# Schema Loading Fix

## Problem

The sample schema loading was failing with the error:
```
ON_ERROR type CONTINUE is not supported for the copy statements on hybrid table.
```

## Root Cause

The `target_schemas` table in the SILVER schema is a **hybrid table** (combines transactional and analytical capabilities). Hybrid tables have restrictions on COPY INTO operations:

- ❌ `ON_ERROR = CONTINUE` is **not supported**
- ✅ `ON_ERROR = ABORT_STATEMENT` is **supported**

Additionally, the table has a composite unique key on `(TABLE_NAME, COLUMN_NAME, TPA)`, which means re-running the load script would cause duplicate key violations.

## Solution

Updated `sample_data/config/load_sample_schemas.sql` to:

1. **Truncate the table first** to clear existing data and avoid duplicates
2. **Use `ON_ERROR = ABORT_STATEMENT`** instead of `CONTINUE`

### Changes Made

```sql
-- Clear existing data to avoid duplicate key violations
-- (target_schemas has a unique key on TABLE_NAME, COLUMN_NAME, TPA)
TRUNCATE TABLE target_schemas;

-- Load schemas from CSV
-- Note: Hybrid tables require ON_ERROR = ABORT_STATEMENT (not CONTINUE)
COPY INTO target_schemas (...)
...
ON_ERROR = ABORT_STATEMENT;
```

## Results

✅ **310 rows loaded successfully**
- 5 TPAs (provider_a through provider_e)
- 4 table types per TPA:
  - MEDICAL_CLAIMS (14 columns)
  - DENTAL_CLAIMS (14 columns)
  - PHARMACY_CLAIMS (16 columns)
  - MEMBER_ELIGIBILITY (18 columns)

## Verification

```sql
SELECT TPA, TABLE_NAME, COUNT(*) as COLUMN_COUNT
FROM target_schemas
GROUP BY TPA, TABLE_NAME
ORDER BY TPA, TABLE_NAME;
```

Output shows all 20 table schemas (5 TPAs × 4 tables) with correct column counts.

## Hybrid Tables

Hybrid tables in Snowflake provide:
- **Transactional capabilities**: ACID compliance, row-level locking, unique/foreign keys
- **Analytical capabilities**: Fast queries, columnar storage
- **Restrictions**: Limited COPY INTO options, no clustering keys, no time travel beyond 1 day

The `target_schemas` table uses hybrid table features:
- Primary key on `SCHEMA_ID`
- Unique key on `(TABLE_NAME, COLUMN_NAME, TPA)`
- Automatic timestamp tracking with `CURRENT_TIMESTAMP()`

## Files Changed

1. `sample_data/config/load_sample_schemas.sql` - Added TRUNCATE and fixed ON_ERROR

## Testing

The script now works correctly and can be run multiple times without errors:

```bash
cd /Users/tboon/code/bordereau
snow sql -f sample_data/config/load_sample_schemas.sql --connection DEPLOYMENT
```

## References

- [Snowflake Hybrid Tables Documentation](https://docs.snowflake.com/en/user-guide/tables-hybrid)
- [COPY INTO Limitations for Hybrid Tables](https://docs.snowflake.com/en/sql-reference/sql/copy-into-table#usage-notes)
