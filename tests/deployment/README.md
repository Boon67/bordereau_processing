# Deployment Script Tests

Executable smoke tests for deployment scripts using Snowflake CLI.

## Prerequisites

- `snow` CLI installed and configured.
- `jq` installed.
- A Snowflake connection name (default: `pipeline`).

## Environment Variables

- `CONNECTION_NAME` (default: `pipeline`)
- `DATABASE_NAME` (default: `FILE_PROCESSING_PIPELINE`)
- `RUN_UNDEPLOY` (default: `false`) – set `true` to run `undeploy.sh`
- `SKIP_DEPLOY` (default: `false`) – set `true` to skip deploy steps

## Run

```bash
chmod +x tests/deployment/run_deploy_tests.sh
CONNECTION_NAME=pipeline tests/deployment/run_deploy_tests.sh
```

To include undeploy:

```bash
RUN_UNDEPLOY=true CONNECTION_NAME=pipeline tests/deployment/run_deploy_tests.sh
```
