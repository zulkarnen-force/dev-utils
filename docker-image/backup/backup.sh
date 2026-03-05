#!/usr/bin/env bash
set -euo pipefail

TZ=${TZ:-Asia/Jakarta}
export TZ

BACKUP_DIR=${BACKUP_DIR:-/backup}
LABEL_FILTER=${LABEL_FILTER:-backup.enable=true}
INTERVAL=${INTERVAL:-300}
MAX_FILES=${MAX_FILES:-7}
BACKUP_FORMAT=${BACKUP_FORMAT:-compress}

# ── Rclone settings ──────────────────────────────────────────────────
RCLONE_ENABLED=${RCLONE_ENABLED:-false}

# Provider 1
RCLONE_1_PROVIDER=${RCLONE_1_PROVIDER:-}       # r2 | mega | pcloud
RCLONE_1_NAME=${RCLONE_1_NAME:-remote1}
RCLONE_1_REMOTE_PATH=${RCLONE_1_REMOTE_PATH:-backup}
# R2 (Cloudflare S3)
RCLONE_1_ACCESS_KEY_ID=${RCLONE_1_ACCESS_KEY_ID:-}
RCLONE_1_SECRET_ACCESS_KEY=${RCLONE_1_SECRET_ACCESS_KEY:-}
RCLONE_1_ENDPOINT=${RCLONE_1_ENDPOINT:-}
RCLONE_1_ACL=${RCLONE_1_ACL:-private}
# Mega
RCLONE_1_USER=${RCLONE_1_USER:-}
RCLONE_1_PASS=${RCLONE_1_PASS:-}
# PCloud
RCLONE_1_HOSTNAME=${RCLONE_1_HOSTNAME:-api.pcloud.com}
RCLONE_1_TOKEN=${RCLONE_1_TOKEN:-}

# Provider 2
RCLONE_2_PROVIDER=${RCLONE_2_PROVIDER:-}       # r2 | mega | pcloud
RCLONE_2_NAME=${RCLONE_2_NAME:-remote2}
RCLONE_2_REMOTE_PATH=${RCLONE_2_REMOTE_PATH:-backup}
# R2 (Cloudflare S3)
RCLONE_2_ACCESS_KEY_ID=${RCLONE_2_ACCESS_KEY_ID:-}
RCLONE_2_SECRET_ACCESS_KEY=${RCLONE_2_SECRET_ACCESS_KEY:-}
RCLONE_2_ENDPOINT=${RCLONE_2_ENDPOINT:-}
RCLONE_2_ACL=${RCLONE_2_ACL:-private}
# Mega
RCLONE_2_USER=${RCLONE_2_USER:-}
RCLONE_2_PASS=${RCLONE_2_PASS:-}
# PCloud
RCLONE_2_HOSTNAME=${RCLONE_2_HOSTNAME:-api.pcloud.com}
RCLONE_2_TOKEN=${RCLONE_2_TOKEN:-}

RCLONE_CONF="/tmp/rclone.conf"
# ─────────────────────────────────────────────────────────────────────

mkdir -p "$BACKUP_DIR"

log() {
  level=$1
  shift
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*"
}

# ── Rclone config generator ─────────────────────────────────────────
generate_rclone_remote() {
  local slot="$1"  # 1 or 2

  local provider_var="RCLONE_${slot}_PROVIDER"
  local name_var="RCLONE_${slot}_NAME"
  local provider="${!provider_var}"
  local name="${!name_var}"

  [[ -z "$provider" ]] && return

  log INFO "Configuring rclone remote [$name] with provider: $provider"

  case "$provider" in
    r2)
      local ak_var="RCLONE_${slot}_ACCESS_KEY_ID"
      local sk_var="RCLONE_${slot}_SECRET_ACCESS_KEY"
      local ep_var="RCLONE_${slot}_ENDPOINT"
      local acl_var="RCLONE_${slot}_ACL"
      cat >> "$RCLONE_CONF" <<EOF

[$name]
type = s3
provider = Cloudflare
access_key_id = ${!ak_var}
secret_access_key = ${!sk_var}
endpoint = ${!ep_var}
acl = ${!acl_var}
EOF
      ;;
    mega)
      local user_var="RCLONE_${slot}_USER"
      local pass_var="RCLONE_${slot}_PASS"
      local obscured_pass
      obscured_pass=$(rclone obscure "${!pass_var}")
      cat >> "$RCLONE_CONF" <<EOF

[$name]
type = mega
user = ${!user_var}
pass = $obscured_pass
EOF
      ;;
    pcloud)
      local host_var="RCLONE_${slot}_HOSTNAME"
      local token_var="RCLONE_${slot}_TOKEN"
      local raw_token="${!token_var}"
      # If the token is not already JSON, wrap it
      if [[ "$raw_token" != \{* ]]; then
        raw_token="{\"access_token\":\"${raw_token}\",\"token_type\":\"bearer\",\"expiry\":\"0001-01-01T00:00:00Z\"}"
      fi
      cat >> "$RCLONE_CONF" <<EOF

[$name]
type = pcloud
hostname = ${!host_var}
token = $raw_token
EOF
      ;;
    *)
      log ERROR "Unknown rclone provider: $provider (slot $slot)"
      ;;
  esac
}

setup_rclone() {
  if [[ "$RCLONE_ENABLED" != "true" ]]; then
    return
  fi

  : > "$RCLONE_CONF"   # truncate / create

  generate_rclone_remote 1
  generate_rclone_remote 2

  log INFO "Rclone config written to $RCLONE_CONF"
}

rclone_upload() {
  local source_file="$1"
  local container_name="$2"

  if [[ "$RCLONE_ENABLED" != "true" ]]; then
    return
  fi

  for slot in 1 2; do
    local provider_var="RCLONE_${slot}_PROVIDER"
    local name_var="RCLONE_${slot}_NAME"
    local path_var="RCLONE_${slot}_REMOTE_PATH"
    local provider="${!provider_var}"
    local name="${!name_var}"
    local remote_path="${!path_var}"

    [[ -z "$provider" ]] && continue

    local dest="${name}:${remote_path}/${container_name}/"

    log INFO "Uploading to rclone remote [$name] -> $dest"

    if rclone copy "$source_file" "$dest" --config "$RCLONE_CONF" 2>&1; then
      log INFO "Upload to [$name] completed"
      rclone_cleanup "$dest" "$name"
    else
      log ERROR "Upload to [$name] failed"
    fi
  done
}

rclone_cleanup() {
  local remote_dir="$1"
  local name="$2"

  local files
  files=$(rclone lsf "$remote_dir" --config "$RCLONE_CONF" 2>/dev/null | sort)
  local total
  total=$(echo "$files" | grep -c . || true)

  if (( total > MAX_FILES )); then
    local remove_count=$((total - MAX_FILES))
    log INFO "Rclone retention [$name]: removing $remove_count old backup(s)"

    echo "$files" | head -n "$remove_count" | while read -r f; do
      log INFO "Rclone removing: ${remote_dir}${f}"
      rclone deletefile "${remote_dir}${f}" --config "$RCLONE_CONF" 2>&1 || true
    done
  fi
}
# ─────────────────────────────────────────────────────────────────────

print_docs() {
  log INFO "------------------------------------------------------------"
  log INFO "Docker Postgres Backup Agent"
  log INFO ""
  log INFO "Container discovery label:"
  log INFO "  $LABEL_FILTER"
  log INFO ""
  log INFO "Required container environment variables:"
  log INFO "  POSTGRES_DB"
  log INFO "  POSTGRES_USER"
  log INFO "  POSTGRES_PASSWORD"
  log INFO ""
  log INFO "Backup format:"
  log INFO "  BACKUP_FORMAT=$BACKUP_FORMAT"
  log INFO "    plain     -> .sql"
  log INFO "    compress  -> .dump (pg_dump -Fc)"
  log INFO ""
  log INFO "Backup location:"
  log INFO "  $BACKUP_DIR/<container_name>/"
  log INFO ""
  log INFO "Retention:"
  log INFO "  MAX_FILES=$MAX_FILES"
  log INFO ""
  if [[ "$RCLONE_ENABLED" == "true" ]]; then
    log INFO "Rclone upload: ENABLED"
    [[ -n "$RCLONE_1_PROVIDER" ]] && log INFO "  Provider 1: $RCLONE_1_PROVIDER ($RCLONE_1_NAME -> $RCLONE_1_REMOTE_PATH)"
    [[ -n "$RCLONE_2_PROVIDER" ]] && log INFO "  Provider 2: $RCLONE_2_PROVIDER ($RCLONE_2_NAME -> $RCLONE_2_REMOTE_PATH)"
  else
    log INFO "Rclone upload: DISABLED"
  fi
  log INFO "------------------------------------------------------------"
}

cleanup_old_backups() {
  folder=$1

  total=$(ls -1 "$folder"/* 2>/dev/null | wc -l || true)

  if (( total > MAX_FILES )); then
    remove_count=$((total - MAX_FILES))

    log INFO "Retention policy: removing $remove_count old backup(s)"

    ls -1t "$folder"/* | tail -n "$remove_count" | while read -r file; do
      log INFO "Removing old backup: $file"
      rm -f "$file"
    done
  fi
}

run_backup() {

  containers=$(docker ps --filter "label=$LABEL_FILTER" --format "{{.Names}}")

  if [ -z "$containers" ]; then
    log WARN "No containers found with label: $LABEL_FILTER"
    return
  fi

  for container in $containers; do

    log INFO "Processing container: $container"

    env_json=$(docker inspect "$container" | jq '.[0].Config.Env')

    POSTGRES_DB=$(echo "$env_json" | jq -r '.[] | select(startswith("POSTGRES_DB=")) | split("=")[1]')
    POSTGRES_USER=$(echo "$env_json" | jq -r '.[] | select(startswith("POSTGRES_USER=")) | split("=")[1]')
    POSTGRES_PASSWORD=$(echo "$env_json" | jq -r '.[] | select(startswith("POSTGRES_PASSWORD=")) | split("=")[1]')

    if [[ -z "$POSTGRES_DB" || -z "$POSTGRES_USER" || -z "$POSTGRES_PASSWORD" ]]; then
      log ERROR "Missing required Postgres env vars in container: $container"
      log ERROR "Skipping container"
      continue
    fi

    container_dir="$BACKUP_DIR/$container"
    mkdir -p "$container_dir"

    timestamp=$(date +"%Y%m%d_%H%M%S")

    if [[ "$BACKUP_FORMAT" == "plain" ]]; then
      outfile="$container_dir/${POSTGRES_DB}_${timestamp}.sql"
      dump_cmd="pg_dump -U $POSTGRES_USER $POSTGRES_DB"
    else
      outfile="$container_dir/${POSTGRES_DB}_${timestamp}.dump"
      dump_cmd="pg_dump -U $POSTGRES_USER -Fc $POSTGRES_DB"
    fi

    log INFO "Creating backup -> $outfile"

    docker exec \
      -e PGPASSWORD="$POSTGRES_PASSWORD" \
      "$container" \
      sh -c "$dump_cmd" \
      > "$outfile"

    log INFO "Backup completed"

    rclone_upload "$outfile" "$container"

    cleanup_old_backups "$container_dir"

  done
}

next_run_time() {
  next_ts=$(( $(date +%s) + INTERVAL ))
  date -d "@$next_ts" '+%Y-%m-%d %H:%M:%S %Z'
}

print_docs
setup_rclone
log INFO "Backup agent started"
log INFO "Backup interval: $INTERVAL seconds"

while true; do
  log INFO "Starting backup cycle"
  run_backup
  next_run=$(next_run_time)
  log INFO "Next backup scheduled at: $next_run"
  sleep "$INTERVAL"
done