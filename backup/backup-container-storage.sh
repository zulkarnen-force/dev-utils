#!/bin/bash
set -euo pipefail

### DEFAULT CONFIGURATION ###
CONTAINER=""
CONTAINER_PATH=""
LOCAL_DEST="/tmp/container-backup"
REMOTE=""
RETENTION=7
LOG_FILE=""
FOLDER_BACKUP_URL="https://raw.githubusercontent.com/zulkarnen-force/bash-scripting/main/backup/folder.py"
PYTHON_BIN="/usr/bin/python3"
#############################

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Backup a folder from a running Docker container and push it to rclone remote.

Steps:
  1. docker cp <container>:<path> to local directory
  2. Push the copied folder to rclone via curl + folder.py

Required:
  -c, --container NAME        Docker container name or ID
  -p, --path PATH             Path inside the container to copy
  -r, --remote REMOTE         Rclone remote destination (e.g., labmu:vm005-eventmu-public-thumbnail-event)

Optional:
  -d, --dest DIR              Local destination directory (default: ${LOCAL_DEST})
  -R, --retention DAYS        Backup retention in days (default: ${RETENTION})
  -l, --log FILE              Log file path (appends output). If not set, logs to stdout.
  -P, --python PATH           Python binary path (default: ${PYTHON_BIN})
  -h, --help                  Show this help message

Examples:
  $(basename "$0") -c eventmu_app -p /app/public/thumbnail-event -r labmu:vm005-eventmu-public-thumbnail-event
  $(basename "$0") -c eventmu_app -p /app/public/img -r labmu:vm005-eventmu-img -R 14 -l /home/vm005/backup/logs/eventmu.log
  $(basename "$0") --container my_app --path /data/uploads --remote minio:backups/uploads --retention 30
EOF
  exit 0
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--container)
      CONTAINER="$2"
      shift 2
      ;;
    -p|--path)
      CONTAINER_PATH="$2"
      shift 2
      ;;
    -r|--remote)
      REMOTE="$2"
      shift 2
      ;;
    -d|--dest)
      LOCAL_DEST="$2"
      shift 2
      ;;
    -R|--retention)
      RETENTION="$2"
      shift 2
      ;;
    -l|--log)
      LOG_FILE="$2"
      shift 2
      ;;
    -P|--python)
      PYTHON_BIN="$2"
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
if [[ -z "${CONTAINER}" ]]; then
  echo "Error: --container is required"
  usage
fi

if [[ -z "${CONTAINER_PATH}" ]]; then
  echo "Error: --path is required"
  usage
fi

if [[ -z "${REMOTE}" ]]; then
  echo "Error: --remote is required"
  usage
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Redirect all output to log file if specified
if [[ -n "${LOG_FILE}" ]]; then
  LOG_DIR=$(dirname "${LOG_FILE}")
  mkdir -p "${LOG_DIR}"
  exec >> "${LOG_FILE}" 2>&1
fi

log "Starting container storage backup"
log "Configuration:"
log "  Container:      ${CONTAINER}"
log "  Container Path: ${CONTAINER_PATH}"
log "  Local Dest:     ${LOCAL_DEST}"
log "  Remote:         ${REMOTE}"
log "  Retention:      ${RETENTION} days"
log "  Log File:       ${LOG_FILE:-<stdout>}"

############################################
# 1. Verify Container is Running
############################################
if ! docker inspect --format='{{.State.Running}}' "${CONTAINER}" 2>/dev/null | grep -q "true"; then
  log "Error: Container '${CONTAINER}' is not running!"
  exit 1
fi

log "Container is running: ${CONTAINER}"

############################################
# 2. Prepare Local Destination
############################################
FOLDER_NAME=$(basename "${CONTAINER_PATH}")
LOCAL_FOLDER="${LOCAL_DEST}/${FOLDER_NAME}"

mkdir -p "${LOCAL_DEST}"

# Clean previous copy if exists
if [[ -d "${LOCAL_FOLDER}" ]]; then
  log "Cleaning previous local copy: ${LOCAL_FOLDER}"
  rm -rf "${LOCAL_FOLDER}"
fi

############################################
# 3. Docker CP from Container
############################################
log "Copying from container: ${CONTAINER}:${CONTAINER_PATH} -> ${LOCAL_DEST}/"
docker cp "${CONTAINER}:${CONTAINER_PATH}" "${LOCAL_DEST}/"

if [[ ! -d "${LOCAL_FOLDER}" ]]; then
  log "Error: docker cp failed! Local folder not found: ${LOCAL_FOLDER}"
  exit 1
fi

COPY_SIZE=$(du -sh "${LOCAL_FOLDER}" | cut -f1)
log "Copy completed: ${LOCAL_FOLDER} (${COPY_SIZE})"

############################################
# 4. Push to Rclone via folder.py
############################################
log "Pushing to rclone remote: ${REMOTE}"
curl -sL "${FOLDER_BACKUP_URL}" | "${PYTHON_BIN}" - \
  --folder "${LOCAL_FOLDER}" \
  --remote "${REMOTE}" \
  --retention "${RETENTION}"

log "Rclone push completed"

############################################
# 5. Cleanup Local Copy
############################################
log "Cleaning up local copy: ${LOCAL_FOLDER}"
rm -rf "${LOCAL_FOLDER}"

log "Container storage backup completed successfully"
