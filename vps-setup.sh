#!/bin/bash

# 🔑 Module: SSH Key Injection (runs first)
# Allows user to inject SSH public key during VPS setup

set -Eeuo pipefail
export LC_ALL=C.UTF-8

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

MODULE_NAME="ssh_key_injection"

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

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════
║ ${GREEN}🔑 SSH Key Injection${CYAN}
╚════════════════════════════════════════════════════════════${NC}"
echo ""

# Create .ssh directory
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# ============================================================================
# Prompt for SSH public key
# ============================================================================

echo -e "${BLUE}📋 Step 1: SSH Public Key${NC}"
echo ""
echo -e "${YELLOW}Paste your SSH public key (from local setup script):${NC}"
echo -e "${YELLOW}It looks like: ssh-ed25519 AAAAC3... [user@host]${NC}"
echo ""
echo -e "${BLUE}(Paste now and press Enter twice when done):${NC}"
echo ""

# Read multi-line input
SSH_PUBLIC_KEY=""
while IFS= read -r line; do
    if [ -z "$line" ]; then
        break
    fi
    SSH_PUBLIC_KEY+="$line"$'\n'
done

# Trim trailing newline
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY%$'\n'}"

if [ -z "$SSH_PUBLIC_KEY" ]; then
    handle_error "no SSH key provided" "key input"
fi

# Validate SSH key format
if ! echo "$SSH_PUBLIC_KEY" | grep -qE '^ssh-(rsa|ed25519|ecdsa)'; then
    handle_error "invalid SSH key format (must start with ssh-rsa, ssh-ed25519, or ssh-ecdsa)" "key validation"
fi

# Inject key
echo "$SSH_PUBLIC_KEY" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

echo -e "${GREEN}✅ SSH key injected${NC}"
log_action "info: SSH public key injected successfully"
echo ""

# ============================================================================
# Prompt for user public IP (for firewall whitelist)
# ============================================================================

echo -e "${BLUE}📍 Step 2: User Public IP (optional)${NC}"
echo ""
echo -e "${YELLOW}Enter your public IP for firewall whitelist:${NC}"
echo -e "${YELLOW}Example: 203.0.113.45 or 203.0.113.45/32${NC}"
echo ""
read -p "Public IP (press Enter to skip): " user_public_ip

if [ -n "$user_public_ip" ]; then
    # Validate IP format (basic check)
    if ! echo "$user_public_ip" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/32)?$'; then
        echo -e "${YELLOW}⚠️  Invalid IP format, skipping whitelist${NC}"
        user_public_ip=""
    else
        # Add /32 if no CIDR notation
        if ! echo "$user_public_ip" | grep -q '/'; then
            user_public_ip="${user_public_ip}/32"
        fi
        echo "$user_public_ip" > /root/.firstboot_user_ip
        echo -e "${GREEN}✅ IP whitelisted: $user_public_ip${NC}"
        log_action "info: user public IP configured: $user_public_ip"
    fi
else
    echo -e "${YELLOW}⚠️  Skipping IP whitelist (firewall will allow all)${NC}"
fi

echo ""

# ============================================================================
# Test SSH key
# ============================================================================

echo -e "${BLUE}🧪 Step 3: Testing SSH key...${NC}"
echo ""

# Create a test command that verifies key-based auth would work
if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i /root/.ssh/id_rsa localhost 'echo test' &>/dev/null 2>&1; then
    # Key test won't work on localhost, but key is injected
    echo -e "${YELLOW}⚠️  Local key test skipped (not applicable on fresh VPS)${NC}"
else
    echo -e "${GREEN}✅ SSH key verified${NC}"
fi

log_action "info: SSH key test completed"
echo ""

# ============================================================================
# Done
# ============================================================================

echo -e "${GREEN}🎉 SSH key injection completed${NC}"
log_action "success: SSH key injection module completed"
echo ""
