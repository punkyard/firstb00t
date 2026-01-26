#!/bin/bash

# 🔧 Debian setup & installation (runs on VPS)
# Purpose: complete Debian hardening workflow
# A. inject SSH key + capture allowlist
# B. run profile selection + all modules

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
NO_MODULES="false"
SKIP_SSH_HARDENING="false"
SKIP_KEY="false"
PROFILE="basic"
FIRSTBOOT_REEXEC=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --non-interactive)
            NON_INTERACTIVE="true"
            shift
            ;;
        --interactive)
            NON_INTERACTIVE="false"
            shift
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --no-modules)
            NO_MODULES="true"
            shift
            ;;
        --skip-ssh-hardening)
            SKIP_SSH_HARDENING="true"
            shift
            ;;
        --skip-key)
            SKIP_KEY="true"
            shift
            ;;
        -h|--help)
            echo -e "${BLUE}Usage: $0 [--profile basic|standard|advanced] [--non-interactive|--interactive] [--no-modules] [--skip-ssh-hardening] [--skip-key]${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: ${1}${NC}"
            exit 1
            ;;
    esac
done

# Export for modules to use
export FIRSTBOOT_PROFILE="${PROFILE}"
export FIRSTBOOT_NON_INTERACTIVE="${NON_INTERACTIVE}"

# =======================================================================
# Logging
# =======================================================================

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

update_progress() {
    echo "📊 progress: ${1:-0}/${2:-0}"
}

# =======================================================================
# Main
# =======================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
source "$(dirname "${BASH_SOURCE[0]}")/../common/logging.sh" 2>/dev/null || true
# provide minimal fallbacks when common/logging.sh isn't available (e.g., single-file download)
if ! type print_title_frame >/dev/null 2>&1; then
    print_title_frame() {
        local icon="$1"; shift
        local title="$*"
        printf "\n%s %s\n\n" "$icon" "$title"
    }
fi
if ! type log_action >/dev/null 2>&1; then
    log_action() {
        mkdir -p /var/log/firstboot 2>/dev/null || true
        echo "[$(date -Iseconds)] [$MODULE_NAME] $1" >> "/var/log/firstboot/${MODULE_NAME}.log" 2>/dev/null || true
    }
fi
print_title_frame "🔧" "Debian setup (SSH key + allowlist + modules)"
echo ""

# Create .ssh directory
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# =======================================================================
# FIRST ACTION: System preparation (apt update + sudo user)
# =======================================================================

echo -e "${BLUE}🔄 System preparation...${NC}"

echo -e "${YELLOW}📦 Updating package lists...${NC}"
apt update
log_action "info: apt update completed"

echo -e "${YELLOW}👤 creating admin user...${NC}"
# Prompt for admin username and create it correctly; default is 'firstb00t'
DEFAULT_ADMIN="${ADMIN_USER:-firstb00t}"
read -r -p "admin username [${DEFAULT_ADMIN}]: " ADMIN_USER_INPUT
ADMIN_USER="${ADMIN_USER_INPUT:-$DEFAULT_ADMIN}"

if id "$ADMIN_USER" &>/dev/null; then
    echo -e "${GREEN}✅ admin user '$ADMIN_USER' already exists${NC}"
    log_action "info: admin user $ADMIN_USER exists"
else
    useradd -m -s /bin/bash -G sudo "$ADMIN_USER"
    echo "$ADMIN_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${ADMIN_USER}"
    chmod 440 "/etc/sudoers.d/${ADMIN_USER}"
    echo -e "${GREEN}✅ admin user '$ADMIN_USER' created${NC}"
    log_action "info: admin user $ADMIN_USER created"
    # expire password so admin must set one on first login (safe default)
    passwd -e "$ADMIN_USER" || true
fi

# If we haven't already re-exec'd as the admin user, do so now (guarded)
if [ "${FIRSTBOOT_REEXEC:-}" != "1" ]; then
    export FIRSTBOOT_REEXEC=1
    echo -e "${YELLOW}🔁 restarting script as '$ADMIN_USER' to continue...${NC}"
    # Re-run the script as the admin user in interactive mode to continue safely
    SCRIPT_PATH="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"
    exec su - "$ADMIN_USER" -c "env FIRSTBOOT_REEXEC=1 bash -lc 'bash \"$SCRIPT_PATH\" --interactive'"
fi
fi

echo -e "${YELLOW}🔄 Switching to sudo user to continue installation...${NC}"
exec su - sudo

# =======================================================================
# PART A: SSH key injection
# =======================================================================

echo -e "${BLUE}📋 Part A: SSH public key${NC}"
echo ""
echo -e "${YELLOW}Paste your SSH public key from your LOCAL machine.${NC}"
echo -e "${YELLOW}Tip (local machine): run: bash firstb00t.sh${NC}"
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

# =======================================================================
# PART B: IP allowlist
# =======================================================================

echo -e "${BLUE}📍 Part B: Your public IP(s) (SSH firewall allowlist)${NC}"
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

mkdir -p /home/firstb00t
ALLOWLIST_FILE="/home/firstb00t/ssh_allowlist"

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

# =======================================================================
# PART C: Verify SSH access
# =======================================================================

echo -e "${BLUE}🧪 Part C: Verify your SSH access (from your LOCAL machine)${NC}"
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

# =======================================================================
# PART D: Module installation
# =======================================================================

if [[ "${NO_MODULES}" == "true" ]]; then
    echo -e "${YELLOW}ℹ️  --no-modules set: stopping after SSH setup${NC}"
    log_action "info: --no-modules set; stopping before module installation"
    exit 0
fi

cat <<EOF
${CYAN}

  .d888 d8b                  888    888       .d8888b.   .d8888b.  888
d88P"  Y8P                  888    888      d88P  Y88b d88P  Y88b 888
888                         888    888      888    888 888    888 888
888888 888 888d888 .d8888b  888888 88888b.  888    888 888    888 888888
888    888 888P"   88K      888    888 "88b 888    888 888    888 888
888    888 888     "Y8888b. 888    888  888 888    888 888    888 888
888    888 888          X88 Y88b.  888 d88P Y88b  d88P Y88b  d88P Y88b.
888    888 888      88888P'  "Y888 88888P"   "Y8888P"   "Y8888P"   "Y888

${NC}

${GREEN}🚀 Debian First-Boot Automation Script

This script performs standard initialization tasks when first booting
a freshly installed Linux Debian server (version 9, 10, 11, 12, 13)
(on VPS, home-server, virtual machine, or any other environment)
and sets up services to enhance server security.

${YELLOW}⚠️  Prerequisites:
${CYAN}• Registrar DNS already configured to point to this server IP
• SPF, DKIM, and DMARC entries already configured${NC}

${BLUE}📋 This script installs only open-source software
recognized by the Debian Linux community from official repositories
and recommends the creation of strong passwords.${NC}

${GREEN}⏱️  Estimated time: 30 minutes${NC}
EOF

echo -e "${BLUE}📦 Part D: Starting module installation...${NC}"

# Detect module location (modules/ subdir or flat)
MODULES_DIR="../modules"
[ ! -d "$MODULES_DIR" ] && [ -f "../01-profile_selection.sh" ] && MODULES_DIR=".."
[ ! -d "$MODULES_DIR" ] && [ -d "modules" ] && MODULES_DIR="modules"

# Load environment variables (optional)
SAMPLE_ENV=""
[ -f "${MODULES_DIR}/sample.env" ] && SAMPLE_ENV="${MODULES_DIR}/sample.env"
if [ -n "$SAMPLE_ENV" ]; then
    echo "📄 loading environment variables..."
    # shellcheck disable=SC1091
    source "$SAMPLE_ENV"
else
    echo "🟡 optional environment file not found (sample.env) — continuing with defaults"
    log_action "info: sample.env missing; defaults used"
fi

# Install the profile selection module
echo "🚀 installing profile selection module..."
source "${MODULES_DIR}/01-profile_selection.sh"

if [[ "${SKIP_SSH_HARDENING}" == "true" ]]; then
    # 🟡 Path A debugging helper: avoid SSH lockout when password auth is still needed to collect logs
    rm -f "/home/firstb00t/modules/05-ssh_hardening.enabled" || true
    echo -e "${YELLOW}⚠️  --skip-ssh-hardening set: skipping 05-ssh_hardening for this run${NC}"
    log_action "info: --skip-ssh-hardening set; removed 05-ssh_hardening.enabled marker"
fi

# Load SSH port configuration if available
if [ -f /home/firstb00t/ssh_port ]; then
    export SSH_PORT=$(cat /home/firstb00t/ssh_port)
    log_action "info: SSH port loaded: ${SSH_PORT}"
fi

# Install enabled modules in order
for module in ${MODULES_DIR}/[0-9][0-9]-*.sh; do
    [ -f "$module" ] || continue
    module_name=$(basename "$module" .sh)
    
    # Check if step by step mode
    if [ "$(cat /home/firstb00t/profile)" = "step by step" ]; then
        echo ""
        echo -e "${YELLOW}📦 Module: $module_name${NC}"
        read -p "Install this module? (y/N): " install_module
        if [[ "$install_module" =~ ^[Yy]$ ]]; then
            touch "/home/firstb00t/modules/${module_name}.enabled"
            echo "📦 installing module: $module_name"
            source "$module"
        else
            echo "⏭️ skipping module: $module_name"
        fi
    else
        if [ -f "/home/firstb00t/modules/${module_name}.enabled" ]; then
            echo "📦 installing module: $module_name"
            source "$module"
        else
            echo "⏭️ module $module_name not enabled for this profile"
        fi
    fi
done

echo -e "${GREEN}✅ Module installation completed${NC}"
log_action "success: module installation completed"

# =======================================================================
# PART E: Finalization
# =======================================================================

echo -e "${BLUE}✅ Part E: Finalizing installation...${NC}"

echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -f /tmp/script_temp_*

echo -e "${CYAN}📋 Generating final report...${NC}"
echo -e "   ${BLUE}• Selected profile: $(cat /home/firstb00t/profile)${NC}"
echo -e "   ${BLUE}• Modules installed: $(ls /home/firstb00t/modules/*.enabled | wc -l)${NC}"
echo -e "   ${BLUE}• Active services: $(systemctl list-units --type=service --state=active | wc -l)${NC}"
echo -e "   ${BLUE}• Users created: $(grep -c "^[^:]*:[^:]*:[0-9]\{4\}" /etc/passwd)${NC}"

echo "🟢 installation completed successfully"
log_action "success: installation completed"

exit 0
