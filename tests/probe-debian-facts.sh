#!/usr/bin/env bash
set -euo pipefail

# Fact probe for Debian host. No config changes.
# Usage: bash tests/probe-debian-facts.sh

ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }

section() {
  printf '\n=== %s ===\n' "$1"
}

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

section "host"
uname -a || true
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  info "ID=${ID:-unknown} VERSION_ID=${VERSION_ID:-unknown} PRETTY_NAME=${PRETTY_NAME:-unknown}"
else
  warn "/etc/os-release missing"
fi

section "identity"
info "user=$(id -un) uid=$(id -u)"
if [[ $(id -u) -eq 0 ]]; then
  ok "running as root"
else
  warn "not root (expected for some checks)"
fi

section "network"
if cmd_exists ip; then
  ip -brief addr || true
else
  warn "ip command missing"
fi
if cmd_exists ping; then
  ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1 && ok "ipv4 egress works" || warn "ipv4 ping failed"
else
  warn "ping missing"
fi
if cmd_exists ping6; then
  ping6 -c 1 -W 1 2606:4700:4700::1111 >/dev/null 2>&1 && ok "ipv6 egress works" || warn "ipv6 ping failed"
fi

section "package managers"
for c in apt-get nala apt; do
  if cmd_exists "$c"; then ok "$c present"; else warn "$c missing"; fi
done

section "firewall tooling"
for c in ufw nft iptables; do
  if cmd_exists "$c"; then ok "$c present"; else warn "$c missing"; fi
done

section "services present"
if cmd_exists systemctl; then
  for svc in ssh fail2ban ufw nftables apparmor unattended-upgrades; do
    if systemctl list-unit-files | grep -q "^${svc}\\.service"; then
      state="$(systemctl is-enabled "${svc}.service" 2>/dev/null || true)"
      info "${svc}.service unit present enabled=${state:-unknown}"
    else
      warn "${svc}.service unit not present"
    fi
  done
else
  warn "systemctl missing"
fi

section "ssh config surface"
if [[ -f /etc/ssh/sshd_config ]]; then
  grep -E '^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|AllowUsers|Port)\\b' /etc/ssh/sshd_config || true
else
  warn "/etc/ssh/sshd_config missing"
fi

section "container tooling"
for c in docker podman docker-compose; do
  if cmd_exists "$c"; then ok "$c present"; else warn "$c missing"; fi
done
if [[ -S /var/run/docker.sock ]]; then
  info "docker.sock present owner=$(stat -c '%U:%G %a' /var/run/docker.sock 2>/dev/null || stat -f '%Su:%Sg %OLp' /var/run/docker.sock 2>/dev/null || echo unknown)"
fi

section "summary"
info "fact probe complete"
