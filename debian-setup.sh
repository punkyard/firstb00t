#!/bin/bash

# 🔑 Debian setup (runs on VPS)
# Purpose: inject SSH public key + capture IPv4/IPv6 allowlist BEFORE running the full installer.

set -Eeuo pipefail
export LC_ALL=C.UTF-8

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

MODULE_NAME="debian_setup"

NON_INTERACTIVE="false"
NO_CHAIN="false"
CHAIN_ARGS=("--interactive")

# Parse flags for setup script. Any args after "--" are passed to debian-firstb00t.sh.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --non-interactive)
            NON_INTERACTIVE="true"
            shift
            ;;
        --no-chain)
            NO_CHAIN="true"
            shift
            ;;
        --)
            shift
            CHAIN_ARGS=("$@")
            break
            ;;
        *)
            # Unknown arg for setup; treat as chain arg for backward compatibility
            CHAIN_ARGS=("$@")
            break
            ;;
    esac
done

# ============================================================================
# Logging
# ============================================================================

log_action() {
    mkdir -p /var/log/firstboot
    echo "[$(date -Iseconds)] [$MODULE_NAME] $1" | tee -a "/var/log/firstboot/${MODULE_NAME}.log"
}

handle_error() {
    error_message="$1"
    error_step="${2:-unknown}"
    echo -e "${RED}🔴 ERROR at step '$error_step': $error_message${NC}"
    log_action "error: interrupted at step '$error_step': $error_message"
    exit 1
}

# ============================================================================
# Main
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║ 🔧 Debian setup (SSH key + allowlist)                      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Create .ssh directory
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# ==========================================================================
# Step 1: prompt for SSH public key
# ==========================================================================

echo -e "${BLUE}📋 Step 1: SSH public key${NC}"
echo ""
echo -e "${YELLOW}Paste your SSH public key from your LOCAL machine.${NC}"
echo -e "${YELLOW}Tip (local machine): run: bash github/firstb00t.sh${NC}"
echo -e "${YELLOW}It looks like: ssh-ed25519 AAAAC3... [user@host]${NC}"
echo ""

if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    if [[ -s /root/.ssh/authorized_keys ]]; then
        echo -e "${GREEN}✅ Existing SSH key(s) already present in /root/.ssh/authorized_keys${NC}"
        log_action "info: non-interactive: existing authorized_keys present; skipping key injection"
    else
        handle_error "non-interactive mode requires an existing /root/.ssh/authorized_keys (or switch to interactive mode)" "key input"
    fi
else
    echo -e "${BLUE}(Paste now and press Enter twice when done)${NC}"
    echo ""

    SSH_PUBLIC_KEY=""
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            break
        fi
        SSH_PUBLIC_KEY+="$line"$'\n'
    done

    SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY%$'\n'}"

    if [ -z "$SSH_PUBLIC_KEY" ]; then
        handle_error "no SSH key provided" "key input"
    fi

    if ! echo "$SSH_PUBLIC_KEY" | grep -qE '^ssh-(rsa|ed25519|ecdsa)'; then
        handle_error "invalid SSH key format (must start with ssh-rsa, ssh-ed25519, or ssh-ecdsa)" "key validation"
    fi

    echo "$SSH_PUBLIC_KEY" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys

    echo -e "${GREEN}✅ SSH key injected${NC}"
    log_action "info: SSH public key injected successfully"
    echo ""
fi

# ==========================================================================
# Step 2: prompt for user public IPs (allowlist)
# ==========================================================================

echo -e "${BLUE}📍 Step 2: Your public IP(s) (SSH firewall allowlist)${NC}"
echo ""
echo -e "${YELLOW}💡 Beginner explanation:${NC}"
echo -e "${YELLOW}A firewall is a security gate.${NC}"
echo -e "${YELLOW}An allowlist (aka whitelist) is a list of IP addresses allowed through the gate.${NC}"
echo ""
echo -e "${YELLOW}If you enter your public IPv4 and/or IPv6, we will allow SSH ONLY from you.${NC}"
echo -e "${YELLOW}If you skip this, SSH may be reachable from the whole internet (less safe).${NC}"
echo ""
echo -e "${YELLOW}🔶 IMPORTANT: copy-paste your IPs from your LOCAL terminal output.${NC}"
echo -e "${YELLOW}If you lost them, you can re-check from your local machine with:${NC}"
echo -e "${YELLOW}  • IPv4: curl -4 ifconfig.me${NC}"
echo -e "${YELLOW}  • IPv6: curl -6 ifconfig.me${NC}"
echo ""

user_public_ipv4=""
user_public_ipv6=""

if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    log_action "info: non-interactive: skipping allowlist prompts"
else
    read -r -p "Your public IPv4 (press Enter to skip): " user_public_ipv4
    read -r -p "Your public IPv6 (press Enter to skip): " user_public_ipv6
fi

mkdir -p /etc/firstboot
ALLOWLIST_FILE="/etc/firstboot/ssh_allowlist"

# Start fresh each run (idempotent)
: > "$ALLOWLIST_FILE" || true

allowlist_count=0

if [ -n "${user_public_ipv4:-}" ]; then
    if ! echo "$user_public_ipv4" | grep -qE '^[0-9]{1,3}(\.[0-9]{1,3}){3}(/([0-9]|[12][0-9]|3[0-2]))?$'; then
        echo -e "${YELLOW}⚠️  Invalid IPv4 format, ignoring: $user_public_ipv4${NC}"
    else
        if ! echo "$user_public_ipv4" | grep -q '/'; then
            user_public_ipv4="${user_public_ipv4}/32"
        fi
        echo "$user_public_ipv4" >> "$ALLOWLIST_FILE"
        allowlist_count=$((allowlist_count + 1))
    fi
fi

if [ -n "${user_public_ipv6:-}" ]; then
    if ! echo "$user_public_ipv6" | grep -qE '^[0-9A-Fa-f:]+(/([0-9]|[1-9][0-9]|1[01][0-9]|12[0-8]))?$'; then
        echo -e "${YELLOW}⚠️  Invalid IPv6 format, ignoring: $user_public_ipv6${NC}"
    else
        if ! echo "$user_public_ipv6" | grep -q '/'; then
            user_public_ipv6="${user_public_ipv6}/128"
        fi
        echo "$user_public_ipv6" >> "$ALLOWLIST_FILE"
        allowlist_count=$((allowlist_count + 1))
    fi
fi

if [ "$allowlist_count" -gt 0 ]; then
    chmod 600 "$ALLOWLIST_FILE" || true
    entries_word="entries"
    if [ "$allowlist_count" -eq 1 ]; then
        entries_word="entry"
    fi
    echo -e "${GREEN}✅ SSH allowlist saved (${allowlist_count} ${entries_word}):${NC}"
    cat "$ALLOWLIST_FILE"
    log_action "info: ssh allowlist saved to $ALLOWLIST_FILE ($allowlist_count entries)"
else
    rm -f "$ALLOWLIST_FILE" || true
    echo -e "${YELLOW}⚠️  No IP provided. SSH will NOT be restricted by IP allowlist.${NC}"
    log_action "info: no ssh allowlist provided"
fi

echo ""

# =========================================================================
# Step 3: verify SSH access (user action)
# =========================================================================

echo -e "${BLUE}🧪 Step 3: Verify your SSH access (from your LOCAL machine)${NC}"
echo ""
echo -e "${GREEN}✅ Your SSH key is now stored on this VPS in:${NC}"
echo -e "${GREEN}   /root/.ssh/authorized_keys${NC}"
echo ""
echo -e "${YELLOW}Now test from your LOCAL machine (your computer), not from inside the VPS.${NC}"
echo -e "${YELLOW}Keep this VPS terminal open, open a NEW terminal on your computer and run:${NC}"
echo -e "${YELLOW}   ssh root@<VPS_IP> 'uptime'${NC}"
echo ""
echo -e "${YELLOW}Expected result:${NC}"
echo -e "${YELLOW}  • you should NOT be asked for the VPS password${NC}"
echo -e "${YELLOW}  • you should see an uptime output${NC}"
echo ""
echo -e "${YELLOW}If you ARE asked for a password, STOP here and fix SSH key access first.${NC}"

log_action "info: user instructed to test SSH key access from local machine"
echo ""

# ==========================================================================
# Step 4: continue with full installation (on VPS)
# ==========================================================================

echo -e "${BLUE}🚀 Step 4: Full installation (runs on this VPS)${NC}"
echo ""

if [[ "${NO_CHAIN}" == "true" ]]; then
    echo -e "${YELLOW}ℹ️  --no-chain set: not starting debian-firstb00t.sh${NC}"
    log_action "info: --no-chain set; stopping after setup"
    exit 0
fi

if [ -f "${SCRIPT_DIR}/debian-firstb00t.sh" ]; then
    echo -e "${GREEN}✅ Starting main installer: debian-firstb00t.sh${NC}"
    echo -e "${YELLOW}(This will now ask profile questions and run modules)${NC}"
    echo ""
    log_action "info: chaining into ${SCRIPT_DIR}/debian-firstb00t.sh"
    bash "${SCRIPT_DIR}/debian-firstb00t.sh" "${CHAIN_ARGS[@]}"
else
    echo -e "${RED}🔴 Cannot continue: ${SCRIPT_DIR}/debian-firstb00t.sh not found.${NC}"
    echo -e "${YELLOW}You likely uploaded only this setup script.${NC}"
    echo ""
    echo -e "${YELLOW}From your local machine, upload the full project files to /root/firstb00t/:${NC}"
    echo -e "${YELLOW}  scp -r github/* root@<VPS_IP>:/root/firstb00t/${NC}"
    echo ""
    log_action "error: debian-firstb00t.sh missing; cannot proceed to full install"
    exit 1
fi
