#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# 📊 Module 11: Monitoring (AIDE, Centralized Rsyslog, NTP, Vulnerability Scanning)
MODULE_ID="11-monitoring"
MODULE_VERSION="2.1.0"
MODULE_DESCRIPTION="file integrity monitoring (AIDE), centralized logging (rsyslog), time synchronization (NTP), vulnerability scanning (Lynis)"

# 📝 Logging function
log() {
  local level=$1; shift
  mkdir -p /var/log/firstboot
  printf '%s [%s] [%s] %s\n' "$(date -Iseconds)" "$level" "$MODULE_ID" "$*" | tee -a "/var/log/firstboot/${MODULE_ID}.log"
}

# 🛡️ Error handling
trap 'log ERROR "Failed at line $LINENO"; rollback; exit 1' ERR
trap 'log INFO "Module finished (status: $?)"' EXIT

# 🧹 Rollback function
rollback() {
  log WARN "Rolling back Module 10 changes"
  systemctl stop chrony >/dev/null 2>&1 || true
  systemctl stop rsyslog >/dev/null 2>&1 || true
  [ -f /etc/rsyslog.d/50-remote.conf.bak ] && mv /etc/rsyslog.d/50-remote.conf.bak /etc/rsyslog.d/50-remote.conf
  log INFO "Rollback completed"
}

# Install dependencies
install_dependencies() {
  log INFO "Installing dependencies..."
  apt-get update >/dev/null 2>&1 || { log ERROR "Failed to update packages"; return 1; }
  
  if ! dpkg -s aide aide-common >/dev/null 2>&1; then
    log INFO "Installing AIDE..."
    apt-get install -y aide aide-common >/dev/null 2>&1 || { log ERROR "AIDE install failed"; return 1; }
  fi
  
  if ! dpkg -s chrony >/dev/null 2>&1; then
    log INFO "Installing Chrony (NTP)..."
    apt-get install -y chrony >/dev/null 2>&1 || { log ERROR "Chrony install failed"; return 1; }
  fi
  
  if ! dpkg -s rsyslog >/dev/null 2>&1; then
    log INFO "Installing rsyslog..."
    apt-get install -y rsyslog >/dev/null 2>&1 || { log ERROR "rsyslog install failed"; return 1; }
  fi

  if ! dpkg -s lynis >/dev/null 2>&1; then
    log INFO "Installing Lynis (vulnerability scanning)..."
    apt-get install -y lynis >/dev/null 2>&1 || { log ERROR "Lynis install failed"; return 1; }
  fi
  
  log INFO "Dependencies installed"
}

run_vulnerability_scan() {
  log INFO "Running vulnerability scan (Lynis)"
  mkdir -p /var/log/firstboot
  local report_file="/var/log/firstboot/lynis-report.txt"
  local log_file="/var/log/firstboot/lynis.log"

  # Lynis exit codes: 0=OK, 1=warnings, 2=tests skipped, 128=errors
  lynis audit system --quiet --logfile "${log_file}" --report-file "${report_file}" >/dev/null 2>&1 || {
    local rc=$?
    log ERROR "Lynis scan returned code ${rc}"; return 1;
  }

  log INFO "Lynis scan complete. Report: ${report_file}"
}

# Configure AIDE
configure_aide() {
  log INFO "Configuring AIDE for file integrity monitoring..."
  
  if [ ! -f /var/lib/aide/aide.db ]; then
    log INFO "Initializing AIDE database (may take several minutes)..."
    aideinit >/dev/null 2>&1 || { log ERROR "AIDE init failed"; return 1; }
    cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  fi
  
  # Add critical paths
  mkdir -p /etc/aide/aide.conf.d
  cat > /etc/aide/aide.conf.d/10_monitoring <<'EOF'
/boot   R
/etc    R
/sbin   R
/usr/sbin R
/usr/bin R
/lib    R
/lib64  R
EOF
  
  # Create daily cron job
  cat > /etc/cron.daily/aide-check <<'EOF'
#!/bin/bash
/usr/bin/aide --check >> /var/log/firstboot/aide-daily.log 2>&1
EOF
  chmod +x /etc/cron.daily/aide-check
  
  log INFO "AIDE configuration completed"
}

# Configure NTP
configure_ntp() {
  log INFO "Configuring Chrony for NTP..."
  
  [ -f /etc/chrony/chrony.conf ] && [ ! -f /etc/chrony/chrony.conf.bak ] && cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.bak
  
  cat > /etc/chrony/chrony.conf <<'EOF'
pool pool.ntp.org iburst maxsources 4
server time.nist.gov iburst
server time.cloudflare.com iburst
makestep 1.0 3
logdir /var/log/chrony
sourcedir /etc/chrony/sources.d
keyfile /etc/chrony/chrony.keys
driftfile /var/lib/chrony/chrony.drift
allow 127.0.0.1
allow ::1
EOF
  
  systemctl enable chrony >/dev/null 2>&1 || { log ERROR "Chrony enable failed"; return 1; }
  systemctl restart chrony >/dev/null 2>&1 || { log ERROR "Chrony restart failed"; return 1; }
  
  log INFO "NTP configuration completed"
}

# Configure rsyslog
configure_rsyslog() {
  log INFO "Configuring rsyslog for centralized logging..."
  
  local remote_syslog_server="${REMOTE_SYSLOG_SERVER:-syslog.example.com}"
  
  [ -f /etc/rsyslog.d/50-remote.conf ] && [ ! -f /etc/rsyslog.d/50-remote.conf.bak ] && cp /etc/rsyslog.d/50-remote.conf /etc/rsyslog.d/50-remote.conf.bak
  
  cat > /etc/rsyslog.d/50-remote.conf <<EOF
*.* @@${remote_syslog_server}:514
\$ActionQueueType LinkedList
\$ActionQueueFileName remote_queue
\$ActionResumeRetryCount -1
\$ActionQueueSaveOnShutdown on
local0.* /var/log/firstboot/syslog-backup.log
EOF
  
  systemctl enable rsyslog >/dev/null 2>&1 || { log ERROR "rsyslog enable failed"; return 1; }
  systemctl restart rsyslog >/dev/null 2>&1 || { log ERROR "rsyslog restart failed"; return 1; }
  
  log INFO "Centralized logging configured"
}

# Validate
validate() {
  log INFO "Validating configuration..."
  local ok=true
  
  [ -f /var/lib/aide/aide.db ] && log INFO "✓ AIDE database OK" || { log ERROR "✗ AIDE DB missing"; ok=false; }
  [ -f /etc/cron.daily/aide-check ] && log INFO "✓ AIDE cron OK" || { log ERROR "✗ AIDE cron missing"; ok=false; }
  systemctl is-active chrony >/dev/null 2>&1 && log INFO "✓ Chrony OK" || { log ERROR "✗ Chrony not running"; ok=false; }
  systemctl is-active rsyslog >/dev/null 2>&1 && log INFO "✓ rsyslog OK" || { log ERROR "✗ rsyslog not running"; ok=false; }
  [ -f /etc/rsyslog.d/50-remote.conf ] && log INFO "✓ rsyslog config OK" || { log ERROR "✗ rsyslog config missing"; ok=false; }
  [ -f /var/log/firstboot/lynis-report.txt ] && log INFO "✓ Lynis report present" || { log ERROR "✗ Lynis report missing"; ok=false; }
  command -v lynis >/dev/null 2>&1 && log INFO "✓ Lynis installed" || { log ERROR "✗ Lynis not installed"; ok=false; }
  
  [ "$ok" = true ] && return 0 || return 1
}

# Main
main() {
  log INFO "======== Module 10: Monitoring ========"
  log INFO "Version: $MODULE_VERSION"
  
  install_dependencies || return 1
  configure_aide || return 1
  configure_ntp || return 1
  configure_rsyslog || return 1
  run_vulnerability_scan || return 1
  validate || return 1
  
  log INFO "========== Module 10 Complete ========="
}

main "$@"
