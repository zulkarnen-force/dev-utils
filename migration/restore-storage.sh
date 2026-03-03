#!/bin/bash
set -euo pipefail

### DEFAULT CONFIGURATION ###
NAMESPACE="prod"
POD=""
REMOTE=""
TARGET_PATH=""
LOCAL_TMP="/tmp/storage-restore"
CONTAINER=""
SHELL_CMD="bash"
#############################

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Restore folder backup from rclone to Kubernetes pod.

Required:
  -r, --remote REMOTE       Rclone remote path (e.g., labmu:backups/storage)
  -p, --pod POD             Target pod name
  -T, --target PATH         Target path inside pod to restore to

Optional:
  -n, --namespace NAMESPACE Kubernetes namespace (default: ${NAMESPACE})
  -c, --container NAME      Container name (if pod has multiple containers)
  -s, --shell SHELL         Shell to use in pod (default: ${SHELL_CMD})
  -t, --tmp DIR             Local temp directory (default: ${LOCAL_TMP})
  -h, --help                Show this help message

Examples:
  $(basename "$0") -r labmu:backups/uploads -p app-0 -T /app/uploads
  $(basename "$0") -r minio:backups/media -p web-0 -T /var/www/media -n staging
  $(basename "$0") --remote s3:backups/data --pod api-0 --target /data -c main
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
      POD="$2"
      shift 2
      ;;
    -T|--target)
      TARGET_PATH="$2"
      shift 2
      ;;
    -c|--container)
      CONTAINER="$2"
      shift 2
      ;;
    -s|--shell)
      SHELL_CMD="$2"
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

if [[ -z "${POD}" ]]; then
  echo "Error: --pod is required"
  usage
fi

if [[ -z "${TARGET_PATH}" ]]; then
  echo "Error: --target is required"
  usage
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Build kubectl exec command with optional container
kubectl_exec() {
  if [[ -n "${CONTAINER}" ]]; then
    kubectl exec -n "${NAMESPACE}" "${POD}" -c "${CONTAINER}" -- "$@"
  else
    kubectl exec -n "${NAMESPACE}" "${POD}" -- "$@"
  fi
}

log "Starting storage restore process"
log "Configuration:"
log "  Namespace:   ${NAMESPACE}"
log "  Pod:         ${POD}"
log "  Container:   ${CONTAINER:-<default>}"
log "  Shell:       ${SHELL_CMD}"
log "  Remote:      ${REMOTE}"
log "  Target Path: ${TARGET_PATH}"

mkdir -p "${LOCAL_TMP}"

###########################################
# 1. Verify Pod Exists
###########################################
if ! kubectl get pod "${POD}" -n "${NAMESPACE}" &>/dev/null; then
  log "Error: Pod not found!"
  exit 1
fi

log "Pod found: ${POD}"

############################################
# 2. Get Latest Backup
############################################
log "Fetching latest backup from rclone"
LATEST=$(rclone lsf "${REMOTE}" | sort | tail -n 1)

if [[ -z "${LATEST}" ]]; then
  log "Error: No backup found!"
  exit 1
fi

log "Latest backup: ${LATEST}"

############################################
# 3. Download Backup
############################################
log "Downloading backup locally"
rclone copy "${REMOTE}/${LATEST}" "${LOCAL_TMP}"

LOCAL_FILE="${LOCAL_TMP}/${LATEST}"
if [[ ! -f "${LOCAL_FILE}" ]]; then
  log "Error: Download failed!"
  exit 1
fi

FILE_SIZE=$(du -h "${LOCAL_FILE}" | cut -f1)
log "Downloaded: ${LOCAL_FILE} (${FILE_SIZE})"

############################################
# 4. Copy Backup Into Pod
############################################
log "Copying backup into pod"
kubectl cp "${LOCAL_FILE}" "${NAMESPACE}/${POD}:/tmp/restore.tar.gz"

############################################
# 5. Extract Backup
############################################
log "Extracting backup to ${TARGET_PATH}"

kubectl_exec ${SHELL_CMD} -c "
set -e

# Ensure target directory exists
mkdir -p '${TARGET_PATH}'

# Extract archive
tar -xzf /tmp/restore.tar.gz -C '${TARGET_PATH}'

# Cleanup
rm -f /tmp/restore.tar.gz

echo 'Extraction completed'
"

############################################
# 6. Cleanup Local Files
############################################
rm -rf "${LOCAL_TMP}"

log "Storage restore completed successfully"
