#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONNECTION_NAME="${CONNECTION_NAME:-pipeline}"
DATABASE_NAME="${DATABASE_NAME:-FILE_PROCESSING_PIPELINE}"
RUN_UNDEPLOY="${RUN_UNDEPLOY:-false}"
SKIP_DEPLOY="${SKIP_DEPLOY:-false}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

log "Starting deployment script tests"
require_cmd snow
require_cmd jq

log "Using connection: ${CONNECTION_NAME}"
log "Database: ${DATABASE_NAME}"

log "Step 1: Check snow CLI connection"
"${ROOT_DIR}/check_snow_connection.sh"

if [[ "${SKIP_DEPLOY}" != "true" ]]; then
  log "Step 2: Deploy Bronze layer"
  "${ROOT_DIR}/deploy_bronze.sh" "${CONNECTION_NAME}"

  log "Step 3: Deploy Silver layer"
  "${ROOT_DIR}/deploy_silver.sh" "${CONNECTION_NAME}"

  log "Step 4: Master deploy (idempotency check)"
  "${ROOT_DIR}/deploy.sh" "${CONNECTION_NAME}"
fi

log "Step 5: Validate objects"
snow sql --connection "${CONNECTION_NAME}" --stdin <<EOF
SHOW DATABASES LIKE '${DATABASE_NAME}';
SHOW SCHEMAS IN DATABASE ${DATABASE_NAME};
SHOW TABLES IN SCHEMA ${DATABASE_NAME}.BRONZE;
SHOW TABLES IN SCHEMA ${DATABASE_NAME}.SILVER;
SHOW TASKS IN SCHEMA ${DATABASE_NAME}.BRONZE;
EOF

if [[ "${RUN_UNDEPLOY}" == "true" ]]; then
  log "Step 6: Undeploy (destructive)"
  "${ROOT_DIR}/undeploy.sh" <<EOF
yes
${DATABASE_NAME}
EOF

  log "Step 7: Validate cleanup"
  snow sql --connection "${CONNECTION_NAME}" --stdin <<EOF
SHOW DATABASES LIKE '${DATABASE_NAME}';
SHOW ROLES LIKE '${DATABASE_NAME}_%';
EOF
fi

log "Deployment script tests completed"
