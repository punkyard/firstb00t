#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# 💾 BorgBackup Volume Protection Module
# Backs up Docker volumes with encryption, deduplication, retention policy
# Logs to /var/log/firstb00t/12-backup_config.log

MODULE_ID="12-backup_config"
LOG_DIR="/var/log/firstb00t"
ENV_FILE="${ENV_FILE:-/etc/firstboot/backup.env}"
INVENTORY_FILE="${INVENTORY_FILE:-/etc/firstboot/backup.inventory}"
VOLUME_BASE="${VOLUME_BASE:-/var/lib/docker/volumes}"
RETENTION_ARGS=(--keep-daily 7 --keep-weekly 4 --keep-monthly 6)
BORG_RSH_DEFAULT="ssh -o BatchMode=yes -o StrictHostKeyChecking=yes"
last_archive=""

mkdir -p "${LOG_DIR}"

# Logging: timestamp, level, module, message
log() {
    local level=$1; shift
    printf '%s [%s] [%s] %s\n' "$(date -Iseconds)" "$level" "$MODULE_ID" "$*" | tee -a "${LOG_DIR}/${MODULE_ID}.log"
}

# Error and exit trap handlers
trap 'on_error $LINENO' ERR
trap 'on_exit' EXIT

on_error() {
    local line=${1:-unknown}
    log error "Failed at line ${line}"
    rollback || true
}

on_exit() {
    log info "Module exit status: $?"
}

# Require borgbackup binary
require_borg() {
    if ! command -v borg >/dev/null 2>&1; then
        log error "borg binary not found; install borgbackup first"
        exit 1
    fi
    log info "borgbackup found"
}

# Load environment variables from file
# BORG_REPO, BORG_PASSPHRASE required; BORG_RSH optional
load_env() {
    log info "Loading environment from ${ENV_FILE}"
    if [ -f "${ENV_FILE}" ]; then
        # shellcheck disable=SC1090
        set -a && source "${ENV_FILE}" && set +a
    fi
    : "${BORG_REPO:?Missing BORG_REPO in ${ENV_FILE}}"
    : "${BORG_PASSPHRASE:?Missing BORG_PASSPHRASE in ${ENV_FILE}}"
    export BORG_REPO BORG_PASSPHRASE
    export BORG_RSH="${BORG_RSH:-${BORG_RSH_DEFAULT}}"
    log info "Environment loaded: BORG_REPO=${BORG_REPO}, BORG_RSH=${BORG_RSH}"
}

# Read volume list from inventory file
# Lines starting with # or blank lines ignored
read_inventory() {
    log info "Reading inventory from ${INVENTORY_FILE}"
    if [ ! -f "${INVENTORY_FILE}" ]; then
        log error "Inventory file not found: ${INVENTORY_FILE}"
        exit 1
    fi
    mapfile -t VOLUMES < <(grep -vE '^\s*(#|$)' "${INVENTORY_FILE}")
    if [ "${#VOLUMES[@]}" -eq 0 ]; then
        log error "No volumes in inventory ${INVENTORY_FILE}"
        exit 1
    fi
    log info "Loaded ${#VOLUMES[@]} volume(s): ${VOLUMES[*]}"
}

# Backup single volume: borg create -> prune -> compact
backup_volume() {
    local volume=$1
    local path="${VOLUME_BASE}/${volume}/_data"
    
    if [ ! -d "${path}" ]; then
        log warn "Skipping ${volume}: path not found ${path}"
        return 0
    fi

    local ts archive
    ts="$(date -Iseconds | tr ':' '-')"
    archive="${HOSTNAME:-host}-${volume}-${ts}"
    last_archive="${archive}"

    log info "Creating archive: ${archive} from ${path}"
    borg create --one-file-system --compression lz4 "${BORG_REPO}::${archive}" "${path}"
    log info "Created ${archive}"
    
    log info "Running prune: ${RETENTION_ARGS[*]}"
    borg prune "${BORG_REPO}" "${RETENTION_ARGS[@]}"
    
    log info "Running compact"
    borg compact "${BORG_REPO}"
    
    if borg list "${BORG_REPO}" | grep -q "${archive}"; then
        log info "Backup verified: ${volume} (${archive})"
    else
        log error "Archive ${archive} not found after create"
        return 1
    fi
}

# Validate: borg list succeeds
validate() {
    log info "Validating borg repo"
    if ! borg list "${BORG_REPO}" >/dev/null 2>&1; then
        log error "Validation failed: cannot list ${BORG_REPO}"
        return 1
    fi
    log info "Validation passed"
}

# Rollback: delete last attempted archive on error
rollback() {
    if [ -n "${last_archive:-}" ]; then
        log warn "Rollback: deleting archive ${last_archive}"
        borg delete "${BORG_REPO}::${last_archive}" || log error "Rollback failed"
    fi
}

main() {
    log info "===== Module start ====="
    require_borg
    load_env
    read_inventory

    for vol in "${VOLUMES[@]}"; do
        last_archive=""
        backup_volume "${vol}" || log error "Failed to backup ${vol}"
    done

    validate || exit 1
    log info "===== All backups complete ====="
}

main "$@"
