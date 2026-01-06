#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# 🌐 Server Orchestration Module
# Triggers module 11 backups across 2–5 hosts via SSH
# Sequential by default; optional GNU parallel for concurrency
# Logs to /var/log/firstb00t/12-server_orchestration.log

MODULE_ID="12-server_orchestration"
LOG_DIR="/var/log/firstb00t"
INVENTORY_FILE="${INVENTORY_FILE:-/etc/firstboot/backup.inventory}"
SSH_USER="${SSH_USER:-root}"
SSH_KEY_PATH="${SSH_KEY_PATH:-/root/.ssh/backup_key}"
BACKUP_COMMAND="${BACKUP_COMMAND:-/usr/local/bin/11-backup_config.sh}"
SSH_OPTS=("-o" "BatchMode=yes" "-o" "StrictHostKeyChecking=yes")
PARALLEL_ENABLED="${PARALLEL_ENABLED:-false}"
HOST_FAILURES=0

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
}

on_exit() {
    log info "Module exit status: $?"
}

# Read host list from inventory file
# Lines starting with # or blank lines ignored
read_inventory() {
    log info "Reading inventory from ${INVENTORY_FILE}"
    if [ ! -f "${INVENTORY_FILE}" ]; then
        log error "Inventory file not found: ${INVENTORY_FILE}"
        exit 1
    fi
    mapfile -t HOSTS < <(grep -vE '^\s*(#|$)' "${INVENTORY_FILE}")
    if [ "${#HOSTS[@]}" -eq 0 ]; then
        log error "No hosts in inventory ${INVENTORY_FILE}"
        exit 1
    fi
    log info "Loaded ${#HOSTS[@]} host(s): ${HOSTS[*]}"
}

# Execute backup on single host via SSH
run_host() {
    local host=$1
    log info "Running ${BACKUP_COMMAND} on ${host}"
    if ssh -i "${SSH_KEY_PATH}" "${SSH_OPTS[@]}" "${SSH_USER}@${host}" "${BACKUP_COMMAND}"; then
        log info "Host ${host}: backup succeeded"
        return 0
    else
        local exit_code=$?
        log error "Host ${host}: backup failed (exit ${exit_code})"
        return "${exit_code}"
    fi
}

# Attempt parallel execution with GNU parallel
# Falls back to sequential if parallel not available
run_parallel() {
    if ! command -v parallel >/dev/null 2>&1; then
        log warn "GNU parallel not available; using sequential mode"
        return 1
    fi
    
    log info "Parallel mode: spawning ${#HOSTS[@]} concurrent jobs"
    local failures=0
    printf '%s\n' "${HOSTS[@]}" | parallel --halt now,fail=1 \
        "ssh -i ${SSH_KEY_PATH} -o BatchMode=yes -o StrictHostKeyChecking=yes ${SSH_USER}@{} ${BACKUP_COMMAND}" \
        || failures=$?
    
    return "${failures}"
}

main() {
    log info "===== Module start ====="
    log info "SSH_USER=${SSH_USER}, SSH_KEY_PATH=${SSH_KEY_PATH}"
    read_inventory

    if [ "${PARALLEL_ENABLED}" = "true" ]; then
        log info "PARALLEL_ENABLED=true; attempting parallel mode"
        if run_parallel; then
            log info "===== All hosts completed (parallel) ====="
            return 0
        else
            log warn "Parallel mode failed; retrying sequential"
        fi
    fi

    log info "Sequential mode: processing ${#HOSTS[@]} host(s)"
    for host in "${HOSTS[@]}"; do
        if ! run_host "${host}"; then
            HOST_FAILURES=$((HOST_FAILURES + 1))
        fi
    done

    if [ "${HOST_FAILURES}" -gt 0 ]; then
        log error "===== Completed with ${HOST_FAILURES} host failure(s) ====="
        exit 1
    fi

    log info "===== All hosts completed (sequential) ====="
}

main "$@"
