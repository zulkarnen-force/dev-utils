#!/bin/bash
set -euo pipefail

### CONFIGURATION ###
NAMESPACE="prod"
POSTGRES_POD="postgres-0"
REMOTE="labmu:laravel-app-backups/database-backups/ktam-api"
LOCAL_TMP="/tmp/pg-restore"
DB_NAME="mydb"
DB_USER="postgres"
APP_DEPLOYMENT="api"
APP_REPLICAS=3
#####################

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting restore process"

mkdir -p ${LOCAL_TMP}

###########################################
1. Verify Postgres Pod Exists
###########################################
if ! kubectl get pod ${POSTGRES_POD} -n ${NAMESPACE} &>/dev/null; then
  log "Postgres pod not found!"
  exit 1
fi

log "Postgres pod found: ${POSTGRES_POD}"

############################################
# 2. Get Latest Backup
############################################
log "Fetching latest backup from rclone"
LATEST=$(rclone lsf ${REMOTE} | sort | tail -n 1)

if [ -z "$LATEST" ]; then
  log "No backup found!"
  exit 1
fi

log "Latest backup: $LATEST"

############################################
# 3. Download Backup
############################################
log "Downloading backup locally"
rclone copy ${REMOTE}/${LATEST} ${LOCAL_TMP}

############################################
# 4. Validate Backup Integrity
############################################
log "Validating gzip integrity"
gunzip -t ${LOCAL_TMP}/${LATEST}

############################################
# 5. Scale Down Application
############################################
log "Scaling down application"
kubectl scale deployment ${APP_DEPLOYMENT} -n ${NAMESPACE} --replicas=0

log "Waiting 10 seconds for connections to close"
sleep 10

############################################
# 6. Copy Backup Into Pod
############################################
log "Copying backup into Postgres pod"
kubectl cp ${LOCAL_TMP}/${LATEST} ${NAMESPACE}/${POSTGRES_POD}:/tmp/restore.sql.gz

############################################
# 7. Restore Database
############################################
log "Starting database restore"

kubectl exec -n ${NAMESPACE} ${POSTGRES_POD} -- bash -c "
set -e

gunzip -f /tmp/restore.sql.gz

echo 'Terminating active connections'
psql -U ${DB_USER} -d postgres -c \"
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname='${DB_NAME}'
AND pid <> pg_backend_pid();
\"

echo 'Restoring database'
psql -U ${DB_USER} -d ${DB_NAME} --single-transaction -f /tmp/restore.sql

rm -f /tmp/restore.sql
"

############################################
# 8. Scale Application Back
############################################
log "Scaling application back to ${APP_REPLICAS} replicas"
kubectl scale deployment ${APP_DEPLOYMENT} -n ${NAMESPACE} --replicas=${APP_REPLICAS}

############################################
# 9. Cleanup
############################################
rm -rf ${LOCAL_TMP}

log "Restore completed successfully"