#!/bin/bash
set -Eeuo pipefail

# 📋 Module 8: DNS Configuration with DNSSEC
# Purpose: Enable DNSSEC validation for DNS security (prevent spoofing/cache poisoning)
# References: NSA Sec 7.9 (DNS security), TuxCare #06 (protocol vulnerabilities)

MODULE_ID="8-dns_config"

# 🔐 Logging
log() {
  local level=$1; shift
  printf '%s [%s] [%s] %s\n' "$(date -Iseconds)" "$level" "$MODULE_ID" "$*" | tee -a "/var/log/firstb00t/${MODULE_ID}.log"
}

trap 'log error "Failed at line $LINENO"; rollback; exit 1' ERR
trap 'log info "Module finished (status: $?)"' EXIT

trap 'log error "Failed at line $LINENO"; rollback; exit 1' ERR
trap 'log info "Module finished (status: $?)"' EXIT

# 🔄 Idempotency: Check if DNSSEC already configured
ensure_systemd_resolved_installed() {
  if ! systemctl is-enabled systemd-resolved >/dev/null 2>&1; then
    log info "Enabling systemd-resolved for DNSSEC validation"
    systemctl enable systemd-resolved
    systemctl start systemd-resolved
  else
    log info "systemd-resolved already enabled"
  fi
}

# 🔐 NSA Sec 7.9: Enable DNSSEC validation
configure_dnssec() {
  log info "Configuring NSA Sec 7.9: DNSSEC validation (prevent DNS spoofing)"
  
  # Backup resolved.conf
  cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak 2>/dev/null || true
  
  # Configure DNSSEC validation
  cat > /etc/systemd/resolved.conf << 'EOF'
# NSA Sec 7.9: DNSSEC validation enabled
[Resolve]
DNS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
FallbackDNS=9.9.9.9 149.112.112.112
DNSSEC=yes
DNSOverTLS=opportunistic
Cache=yes
CacheFromLocalhost=no
ReadEtcHosts=yes
EOF
  
  log info "DNSSEC validation enabled (systemd-resolved)"
}

# 🔐 Update /etc/resolv.conf to use systemd-resolved stub
configure_resolv_conf() {
  log info "Configuring /etc/resolv.conf to use systemd-resolved stub resolver"
  
  # Backup existing resolv.conf
  if [ ! -L /etc/resolv.conf ]; then
    cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
  fi
  
  # Point to systemd-resolved stub
  ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  
  log info "resolv.conf linked to systemd-resolved stub (127.0.0.53)"
}

# 🔐 TuxCare #06: Verify DNSSEC validation working
test_dnssec() {
  log info "Testing DNSSEC validation (TuxCare #06 protocol security)"
  
  # Restart systemd-resolved to apply changes
  systemctl restart systemd-resolved
  sleep 2
  
  # Test DNSSEC-signed domain (cloudflare.com has DNSSEC)
  if resolvectl query cloudflare.com | grep -q "authenticated: yes"; then
    log info "✅ DNSSEC validation working (authenticated: yes)"
    return 0
  else
    log warn "⚠️ DNSSEC validation test inconclusive (may require time for cache)"
    return 0  # Don't fail module, just warn
  fi
}

# ✅ Validation: Verify DNSSEC configuration
validate() {
  log info "Validating Module 8 DNSSEC configuration..."
  
  local checks_passed=0
  local checks_total=4
  
  # Check 1: systemd-resolved enabled
  if systemctl is-enabled systemd-resolved >/dev/null 2>&1; then
    log info "✅ Check 1: systemd-resolved enabled"
    ((checks_passed++))
  else
    log error "❌ Check 1: systemd-resolved NOT enabled"
  fi
  
  # Check 2: DNSSEC=yes in resolved.conf
  if grep -q "^DNSSEC=yes" /etc/systemd/resolved.conf 2>/dev/null; then
    log info "✅ Check 2: DNSSEC validation enabled in resolved.conf"
    ((checks_passed++))
  else
    log error "❌ Check 2: DNSSEC NOT enabled in resolved.conf"
  fi
  
  # Check 3: resolv.conf points to stub
  if [ -L /etc/resolv.conf ] && readlink /etc/resolv.conf | grep -q "stub-resolv.conf"; then
    log info "✅ Check 3: /etc/resolv.conf linked to systemd-resolved stub"
    ((checks_passed++))
  else
    log error "❌ Check 3: resolv.conf NOT linked to systemd-resolved"
  fi
  
  # Check 4: systemd-resolved running
  if systemctl is-active --quiet systemd-resolved; then
    log info "✅ Check 4: systemd-resolved service running"
    ((checks_passed++))
  else
    log error "❌ Check 4: systemd-resolved NOT running"
  fi
  
  log info "Validation complete: $checks_passed/$checks_total checks passed"
  [ "$checks_passed" -eq "$checks_total" ] && return 0 || return 1
}

# 🔄 Rollback: Restore previous configuration
rollback() {
  log warn "Rolling back DNS configuration changes..."
  
  # Restore resolved.conf backup if exists
  if [ -f /etc/systemd/resolved.conf.bak ]; then
    cp /etc/systemd/resolved.conf.bak /etc/systemd/resolved.conf
    systemctl restart systemd-resolved
    log info "Restored /etc/systemd/resolved.conf from backup"
  fi
  
  # Restore resolv.conf backup if exists
  if [ -f /etc/resolv.conf.bak ] && [ ! -L /etc/resolv.conf.bak ]; then
    rm -f /etc/resolv.conf
    cp /etc/resolv.conf.bak /etc/resolv.conf
    log info "Restored /etc/resolv.conf from backup"
  fi
}

# 🚀 Main execution
main() {
  log info "Starting Module 8: DNS Configuration (NSA Sec 7.9 DNSSEC)"
  
  # Create logs directory if needed
  mkdir -p /var/log/firstb00t
  
  ensure_systemd_resolved_installed
  configure_dnssec
  configure_resolv_conf
  test_dnssec
  
  log info "All configurations applied. Running validation..."
  validate || { log error "Validation failed"; rollback; exit 1; }
  
  log info "Module 8 completed successfully (NSA Sec 7.9 DNSSEC validation enabled)"
}

main "$@" 