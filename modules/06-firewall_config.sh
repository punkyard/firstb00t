#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

# 🌈 color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # no color

# 📋 Module information
MODULE_NAME="firewall_config"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="firewall configuration with ufw"
MODULE_DEPENDENCIES=("ufw" "systemctl")

# 📝 Logging function
log_action() {
    mkdir -p /var/log/firstboot
    echo "[$(date -Iseconds)] [${MODULE_NAME}] $1" | tee -a "/var/log/firstboot/${MODULE_NAME}.log"
}

# 🚨 Error handling
handle_error() {
    error_message="$1"
    error_step="$2"
    echo -e "${RED}🔴 ERROR at step '$error_step': $error_message${NC}"
    log_action "error: interrupted at step '$error_step': $error_message"
    cleanup
    exit 1
}

# 🧹 cleanup function
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up...${NC}"
    # restore original config if needed
    if [ -f /etc/ufw/before.rules.bak ]; then
        mv /etc/ufw/before.rules.bak /etc/ufw/before.rules
        log_action "info: ufw config restored"
    fi
    # leave ufw running; only restore config
    log_action "info: cleanup completed"
}

# 🔄 check dependencies
check_dependencies() {
    echo -e "${BLUE}🔍 Checking dependencies...${NC}"
    
    # Install ufw if missing
    if ! command -v ufw &> /dev/null; then
        echo -e "${YELLOW}📦 Installing ufw...${NC}"
        DEBIAN_FRONTEND=noninteractive apt-get update -qq || handle_error "apt update failed" "dependency installation"
        DEBIAN_FRONTEND=noninteractive apt-get install -y ufw || handle_error "ufw installation failed" "dependency installation"
        log_action "info: ufw installed successfully"
    fi
    
    for dep in "${MODULE_DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            handle_error "missing dependency: $dep" "dependency check"
        fi
    done
    echo -e "${GREEN}✅ All dependencies satisfied${NC}"
    log_action "info: dependency check passed"
}

# 📊 progress tracking
update_progress() {
    current_step="$1"
    total_steps="$2"
    echo -e "${BLUE}📊 Progress: $current_step/$total_steps${NC}"
}

# 🔒 configure firewall
configure_firewall() {
    echo -e "${BLUE}🔒 Configuring firewall...${NC}"
    
    # backup original config
    cp /etc/ufw/before.rules /etc/ufw/before.rules.bak || handle_error "config backup failed" "backup config"
    
    # reset ufw to default
    ufw --force reset || handle_error "firewall reset failed" "reset"
    
    # set default policies (NSA Sec 2.1: deny-by-default)
    ufw default deny incoming || handle_error "setting default policy failed" "set policies"
    ufw default deny outgoing || handle_error "setting default egress policy failed" "set policies"
    ufw default deny routed || handle_error "setting default routed policy failed" "set policies"
    
    # NSA Sec 8.1: Enable uRPF anti-spoofing (kernel parameter)
    echo -e "${BLUE}🛡️  Enabling uRPF anti-spoofing...${NC}"
    sysctl -w net.ipv4.conf.all.rp_filter=1 || handle_error "uRPF activation failed" "uRPF"
    sysctl -w net.ipv4.conf.default.rp_filter=1 || handle_error "uRPF default activation failed" "uRPF"
    # persist across reboots
    if ! grep -q "net.ipv4.conf.all.rp_filter" /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv4.conf.all.rp_filter=1" >> /etc/sysctl.conf
    fi
    if ! grep -q "net.ipv4.conf.default.rp_filter" /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv4.conf.default.rp_filter=1" >> /etc/sysctl.conf
    fi
    log_action "info: uRPF anti-spoofing enabled"
    
    # NSA Sec 2.1: Egress filtering (allow essential outbound services only)
    echo -e "${BLUE}🚪 Configuring egress filtering...${NC}"
    # allow DNS queries
    ufw allow out 53/tcp comment 'Allow DNS TCP' || handle_error "DNS TCP egress rule failed" "egress filtering"
    ufw allow out 53/udp comment 'Allow DNS UDP' || handle_error "DNS UDP egress rule failed" "egress filtering"
    # allow HTTP/HTTPS for package updates
    ufw allow out 80/tcp comment 'Allow HTTP' || handle_error "HTTP egress rule failed" "egress filtering"
    ufw allow out 443/tcp comment 'Allow HTTPS' || handle_error "HTTPS egress rule failed" "egress filtering"
    # allow NTP
    ufw allow out 123/udp comment 'Allow NTP' || handle_error "NTP egress rule failed" "egress filtering"
    # allow SMTP outbound (for sending mail)
    ufw allow out 25/tcp comment 'Allow SMTP' || handle_error "SMTP egress rule failed" "egress filtering"
    ufw allow out 587/tcp comment 'Allow SMTP submission' || handle_error "submission egress rule failed" "egress filtering"
    log_action "info: egress filtering configured"
    
    # allow ssh (configurable port, default 22222)
    SSH_PORT=${SSH_PORT:-22222}

    # Optional: restrict SSH to a user allowlist created during VPS bootstrap
    # One entry per line, e.g.:
    #   203.0.113.45/32
    #   2001:db8:85a3::8a2e:370:7334/128
    SSH_ALLOWLIST_FILE="/etc/firstboot/ssh_allowlist"

    if [ -s "$SSH_ALLOWLIST_FILE" ]; then
        echo -e "${BLUE}🔐 Restricting SSH to allowlisted IPs...${NC}"
        while IFS= read -r src; do
            [ -n "$src" ] || continue
            ufw allow from "$src" to any port "$SSH_PORT" proto tcp comment 'Allow SSH (allowlist)' \
                || handle_error "SSH allowlist rule failed for: $src" "rule configuration"
        done < "$SSH_ALLOWLIST_FILE"
        log_action "info: SSH restricted via allowlist ($SSH_ALLOWLIST_FILE)"
    else
        ufw allow ${SSH_PORT}/tcp comment 'Allow SSH' || handle_error "SSH port opening failed" "rule configuration"
        log_action "warning: SSH open to the internet (no allowlist at $SSH_ALLOWLIST_FILE)"
    fi
    
    # allow http/https
    ufw allow 80/tcp comment 'Allow HTTP' || handle_error "HTTP port opening failed" "rule configuration"
    ufw allow 443/tcp comment 'Allow HTTPS' || handle_error "HTTPS port opening failed" "rule configuration"
    
    # allow dns
    ufw allow 53/tcp comment 'Allow DNS TCP' || handle_error "DNS TCP port opening failed" "rule configuration"
    ufw allow 53/udp comment 'Allow DNS UDP' || handle_error "DNS UDP port opening failed" "rule configuration"
    
    # allow smtp
    ufw allow 25/tcp comment 'Allow SMTP' || handle_error "SMTP port opening failed" "rule configuration"
    
    # allow imap/pop3
    ufw allow 143/tcp comment 'Allow IMAP' || handle_error "IMAP port opening failed" "rule configuration"
    ufw allow 110/tcp comment 'Allow POP3' || handle_error "POP3 port opening failed" "rule configuration"
    
    # allow submission
    ufw allow 587/tcp comment 'Allow submission' || handle_error "submission port opening failed" "rule configuration"
    
    # NSA requirement: Enable logging for denied traffic (ACL logging)
    ufw logging medium || handle_error "enabling logs failed" "log configuration"
    
    log_action "info: firewall configuration completed"
}

# 🔄 restart service
restart_service() {
    echo -e "${BLUE}🔄 Restarting ufw service...${NC}"
    
    # enable ufw
    ufw --force enable || handle_error "firewall activation failed" "firewall activation"
    
    # verify service status
    if ! systemctl is-active --quiet ufw; then
        handle_error "ufw service not active" "service verification"
    fi
    
    log_action "info: ufw service restarted"
}

# 🎯 main function
main() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════
║ ${GREEN}🚀 Installing module ${CYAN}$MODULE_NAME${GREEN}...
║${CYAN}
╚════════════════════════════════════════════════════════════${NC}"

    # check dependencies
    check_dependencies

    # step 1: configure firewall
    update_progress 1 3
    echo -e "${BLUE}📦 Step 1: Configuring...${NC}"
    configure_firewall
    log_action "info: step 1 completed"

    # step 2: restart service
    update_progress 2 3
    echo -e "${BLUE}📦 Step 2: Restarting service...${NC}"
    restart_service
    log_action "info: step 2 completed"

    # step 3: verify
    update_progress 3 3
    echo -e "${BLUE}📦 Step 3: Verifying...${NC}"
    
    # verify service
    if ! systemctl is-active --quiet ufw; then
        handle_error "ufw service not active" "verification"
    fi
    
    # verify rules
    if ! ufw status | grep -q "Status: active"; then
        handle_error "firewall not active" "verification"
    fi
    
    log_action "info: step 3 completed"

    echo -e "${GREEN}🎉 Module $MODULE_NAME installed successfully${NC}"
    log_action "success: module $MODULE_NAME installation completed"
}

# 🎯 run main function
main 