#!/usr/bin/env bash
set -euo pipefail

# Non-destructive harness runner for firstb00t prep.
# Usage: bash tests/run-harness.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE_SCRIPT="$ROOT_DIR/tests/probe-debian-facts.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    fail "missing required command: $1"
    return 1
  }
  pass "command exists: $1"
}

info "harness start"

# 1) Local repo checks
[[ -f "$ROOT_DIR/debian-firstb00t.sh" ]] && pass "script exists" || fail "script missing"
[[ -f "$ROOT_DIR/README.md" ]] && pass "README exists" || fail "README missing"
[[ -f "$PROBE_SCRIPT" ]] && pass "probe script exists" || fail "probe script missing"

# 2) Host capability checks (non-destructive)
need_cmd bash
need_cmd grep
need_cmd awk
need_cmd sed

# 3) Run fact probe
info "running fact probe"
bash "$PROBE_SCRIPT"

# 4) Explicit TODO reminder for remote run context
cat <<'EOM'

[INFO] next checks inside Debian VM/VPS via VS Code Remote SSH:
- confirm script prompt order (hostname/timezone early, ssh key last)
- verify firewall backend choice flow (ufw default, nftables advanced)
- verify ftp yes/no branch and passive range prompts
- verify docker/podman choice and /srv/containers convention
- verify ssh lockout recovery text appears before enforcing strict ssh
EOM

info "harness done"
