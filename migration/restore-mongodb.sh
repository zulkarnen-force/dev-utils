#!/bin/bash
set -euo pipefail

### DEFAULT CONFIGURATION ###
NAMESPACE="prod"
MONGODB_POD="mongodb-0"
REMOTE=""
LOCAL_TMP="/tmp/mongo-restore"
DB_NAME="superapps"
DB_USER="admin"
DB_PASSWORD=""
AUTH_DB="admin"
APP_DEPLOYMENT="api"
APP_REPLICAS=3
#############################

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Restore MongoDB database from rclone backup.

Required:
  -r, --remote REMOTE       Rclone remote path (e.g., labmu:backups/database)

Optional:
  -n, --namespace NAMESPACE Kubernetes namespace (default: ${NAMESPACE})
  -p, --pod POD             MongoDB pod name (default: ${MONGODB_POD})
  -d, --database DB         Database name (default: ${DB_NAME})
  -u, --user USER           Database user (default: ${DB_USER})
  -w, --password PASS       Database password (default: from env MONGO_PASSWORD)
  -A, --auth-db DB          Authentication database (default: ${AUTH_DB})
  -a, --app DEPLOYMENT      Application deployment name (default: ${APP_DEPLOYMENT})
  -R, --replicas COUNT      Application replicas (default: ${APP_REPLICAS})
  -t, --tmp DIR             Local temp directory (default: ${LOCAL_TMP})
  -h, --help                Show this help message

Examples:
  $(basename "$0") -r labmu:backups/database
  $(basename "$0") -r labmu:backups/database -n staging -d mydb -a web-api
  $(basename "$0") --remote minio:db-backups --namespace prod --pod mongodb-primary-0
EOF
  exit 0
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--remote)
      REMOTE="$2"
      shift 2
      ;;
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -p|--pod)
      MONGODB_POD="$2"
      shift 2
      ;;
    -d|--database)
      DB_NAME="$2"
      shift 2
      ;;
    -u|--user)
      DB_USER="$2"
      shift 2
      ;;
    -w|--password)
      DB_PASSWORD="$2"
      shift 2
      ;;
    -A|--auth-db)
      AUTH_DB="$2"
      shift 2
      ;;
    -a|--app)
      APP_DEPLOYMENT="$2"
      shift 2
      ;;
    -R|--replicas)
      APP_REPLICAS="$2"
      shift 2
      ;;
    -t|--tmp)
      LOCAL_TMP="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate required arguments
if [[ -z "${REMOTE}" ]]; then
  echo "Error: --remote is required"
  usage
fi

# Use environment variable if password not provided
if [[ -z "${DB_PASSWORD}" ]]; then
  DB_PASSWORD="${MONGO_PASSWORD:-}"
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting restore process"
log "Configuration:"
log "  Namespace:    ${NAMESPACE}"
log "  MongoDB Pod:  ${MONGODB_POD}"
log "  Remote:       ${REMOTE}"
log "  Database:     ${DB_NAME}"
log "  DB User:      ${DB_USER}"
log "  Auth DB:      ${AUTH_DB}"
log "  App Deploy:   ${APP_DEPLOYMENT}"
log "  Replicas:     ${APP_REPLICAS}"

mkdir -p ${LOCAL_TMP}

###########################################
# 1. Verify MongoDB Pod Exists
###########################################
if ! kubectl get pod ${MONGODB_POD} -n ${NAMESPACE} &>/dev/null; then
  log "MongoDB pod not found!"
  exit 1
fi

log "MongoDB pod found: ${MONGODB_POD}"

############################################
# 2. Get Latest Backup
############################################
log "Fetching latest backup from rclone"
LATEST=$(rclone lsf ${REMOTE} | grep '\.sql\.gz$' | sort | tail -n 1)

if [ -z "$LATEST" ]; then
  log "No .sql.gz backup found!"
  exit 1
fi

log "Latest backup: $LATEST"

############################################
# 3. Download Backup
############################################
log "Downloading backup locally"
rclone copy ${REMOTE}/${LATEST} ${LOCAL_TMP}

############################################
# 4. Gunzip Backup
############################################
log "Decompressing backup file"
gunzip ${LOCAL_TMP}/${LATEST}

# Remove .gz extension to get the backup directory name
BACKUP_DIR="${LATEST%.gz}"

############################################
# 5. Copy Backup Into Pod
############################################
log "Copying backup into MongoDB pod"
kubectl cp ${LOCAL_TMP}/${BACKUP_DIR} ${NAMESPACE}/${MONGODB_POD}:/tmp/restore-dump

############################################
# 6. Scale Down Application
############################################
log "Scaling down application"
kubectl scale deployment ${APP_DEPLOYMENT} -n ${NAMESPACE} --replicas=0

log "Waiting 10 seconds for connections to close"
sleep 10

############################################
# 7. Restore Database
############################################
log "Starting database restore"

if [[ -n "${DB_PASSWORD}" ]]; then
  AUTH_STRING="-u ${DB_USER} -p ${DB_PASSWORD} --authenticationDatabase ${AUTH_DB}"
else
  AUTH_STRING=""
fi

kubectl exec -n ${NAMESPACE} ${MONGODB_POD} -- bash -c "
set -e

echo 'Restoring database using mongorestore'
mongorestore ${AUTH_STRING} --db ${DB_NAME} /tmp/restore-dump

rm -rf /tmp/restore-dump
"

############################################
# 8. Scale Application Back
############################################
log "Scaling application back to ${APP_REPLICAS} replicas"
kubectl scale deployment ${APP_DEPLOYMENT} -n ${NAMESPACE} --replicas=${APP_REPLICAS}

############################################
# 9. Cleanup Local Files
############################################
rm -rf ${LOCAL_TMP}

log "Restore completed successfully"
