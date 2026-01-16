# Test Plan - Deployment Scripts

**Scope:** `deploy.sh`, `deploy_bronze.sh`, `deploy_silver.sh`, `undeploy.sh`, `check_snow_connection.sh`

**Goal:** Validate automated deployment and cleanup using Snowflake CLI connections across common and failure scenarios.

## 1. Prerequisites

- Snowflake CLI installed and on PATH (`snow --version`).
- `jq` installed (`jq --version`).
- Snowflake account with access to create databases, schemas, roles, tasks.
- Two Snowflake connections (for multi-connection tests):
  - `pipeline` (default)
  - `pipeline_alt` (non-default)

## 2. Test Data

- Use existing SQL scripts and sample data in `sample_data/`.
- Use default database name: `FILE_PROCESSING_PIPELINE`.

## 3. Environment Matrix

| ID | OS | Snow CLI | jq | Connection | Expected |
|----|----|----------|----|------------|----------|
| E1 | macOS | Latest | Latest | default | Success |
| E2 | macOS | Latest | Latest | non-default | Success |
| E3 | Linux | Latest | Latest | default | Success |
| E4 | Linux | Latest | Latest | non-default | Success |

## 4. Test Cases

### 4.1 Connection Setup - `check_snow_connection.sh`

**TC-001: Snow CLI not installed**
- **Setup:** Temporarily remove `snow` from PATH.
- **Command:** `./check_snow_connection.sh`
- **Expected:** Script exits with error and installation guidance.

**TC-002: No connections configured**
- **Setup:** Move `~/.snowflake/connections.toml` aside.
- **Command:** `./check_snow_connection.sh`
- **Expected:** Prompts for connection details; creates connection; `snow connection test` passes.

**TC-003: Existing default connection**
- **Setup:** Ensure `pipeline` is default.
- **Command:** `./check_snow_connection.sh`
- **Expected:** Detects connection; prompts to use; exits 0 when accepted.

**TC-004: Existing connection but user declines**
- **Setup:** Default connection exists.
- **Command:** `./check_snow_connection.sh`
- **Expected:** Prompts for new connection; creates and tests it.

### 4.2 Master Deploy - `deploy.sh`

**TC-005: Deploy with default connection**
- **Command:** `./deploy.sh`
- **Expected:** Bronze and Silver deploy successfully; summary shows default connection.

**TC-006: Deploy with explicit connection**
- **Command:** `./deploy.sh pipeline_alt`
- **Expected:** Uses `pipeline_alt`; deploy completes.

**TC-007: Missing connection name**
- **Setup:** Remove default connection and pass non-existent name.
- **Command:** `./deploy.sh missing_conn`
- **Expected:** Fails with clear error; no partial deployment.

**TC-008: Invalid SQL**
- **Setup:** Temporarily introduce a syntax error in a SQL file.
- **Command:** `./deploy.sh`
- **Expected:** Script exits non-zero; error logged; no subsequent scripts run.

### 4.3 Bronze Deploy - `deploy_bronze.sh`

**TC-009: Bronze deploy success**
- **Command:** `./deploy_bronze.sh pipeline`
- **Expected:** Creates database, schemas, stages, tables, procedures, tasks.

**TC-010: Bronze deploy idempotency**
- **Command:** Run `./deploy_bronze.sh pipeline` twice.
- **Expected:** Second run succeeds; no duplicate errors.

### 4.4 Silver Deploy - `deploy_silver.sh`

**TC-011: Silver deploy success**
- **Command:** `./deploy_silver.sh pipeline`
- **Expected:** Creates Silver schema objects; procedures and metadata tables exist.

**TC-012: Silver deploy idempotency**
- **Command:** Run `./deploy_silver.sh pipeline` twice.
- **Expected:** Second run succeeds; no duplicate errors.

### 4.5 Undeploy - `undeploy.sh`

**TC-013: Cancel undeploy at first prompt**
- **Command:** `./undeploy.sh`
- **Input:** Anything other than `yes`
- **Expected:** Script exits; database remains.

**TC-014: Cancel undeploy at database confirmation**
- **Command:** `./undeploy.sh`
- **Input:** `yes`, then incorrect database name
- **Expected:** Script exits; database remains.

**TC-015: Successful undeploy**
- **Command:** `./undeploy.sh`
- **Input:** `yes`, then `FILE_PROCESSING_PIPELINE`
- **Expected:** Database dropped; roles removed.

## 5. Validation Queries

After deploy:

```sql
SHOW DATABASES LIKE 'FILE_PROCESSING_PIPELINE';
SHOW SCHEMAS IN DATABASE FILE_PROCESSING_PIPELINE;
SHOW TABLES IN SCHEMA FILE_PROCESSING_PIPELINE.BRONZE;
SHOW TABLES IN SCHEMA FILE_PROCESSING_PIPELINE.SILVER;
SHOW TASKS IN SCHEMA FILE_PROCESSING_PIPELINE.BRONZE;
```

After undeploy:

```sql
SHOW DATABASES LIKE 'FILE_PROCESSING_PIPELINE';
SHOW ROLES LIKE 'FILE_PROCESSING_PIPELINE_%';
```

## 6. Automation Hooks

Suggested automation wrapper (bash):

```bash
set -euo pipefail
./check_snow_connection.sh
./deploy_bronze.sh pipeline
./deploy_silver.sh pipeline
./deploy.sh pipeline
./undeploy.sh <<EOF
yes
FILE_PROCESSING_PIPELINE
EOF
```

## 7. Expected Artifacts

- Logs in `logs/` for each deployment.
- Snowflake objects created and visible via `SHOW` commands.

## 8. Risks and Mitigations

- **Risk:** Missing `jq` causes connection parsing failures.
  - **Mitigation:** Add prerequisite check or fallback parsing.
- **Risk:** Partial deployments if SQL fails mid-run.
  - **Mitigation:** Use `set -e` and validate before next stage.

## 9. Pass/Fail Criteria

- **Pass:** All success tests complete with expected objects present and no errors.
- **Fail:** Any script exits non-zero unexpectedly, or objects are missing after deploy.
