#!/usr/bin/env bash
set -euo pipefail

TZ=${TZ:-Asia/Jakarta}
export TZ

BACKUP_DIR=${BACKUP_DIR:-/backup}
LABEL_FILTER=${LABEL_FILTER:-backup.enable=true}
INTERVAL=${INTERVAL:-300}
MAX_FILES=${MAX_FILES:-7}
BACKUP_FORMAT=${BACKUP_FORMAT:-compress}

mkdir -p "$BACKUP_DIR"

log() {
  level=$1
  shift
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*"
}

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

    cleanup_old_backups "$container_dir"

  done
}

next_run_time() {
  next_ts=$(( $(date +%s) + INTERVAL ))
  date -d "@$next_ts" '+%Y-%m-%d %H:%M:%S %Z'
}

print_docs
log INFO "Backup agent started"
log INFO "Backup interval: $INTERVAL seconds"

while true; do
  log INFO "Starting backup cycle"
  run_backup
  next_run=$(next_run_time)
  log INFO "Next backup scheduled at: $next_run"
  sleep "$INTERVAL"
done