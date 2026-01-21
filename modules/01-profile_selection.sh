#!/bin/bash

# 🌈 color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # no color

# 📋 Module information
MODULE_ID="01-profile_selection"
MODULE_NAME="profile_selection"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="security profile selection and configuration"
MODULE_DEPENDENCIES=("systemctl" "apt")

# 📝 Logging function
log_action() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> /var/log/firstboot_script.log
}

# 🚨 Error handling
handle_error() {
    error_message="$1"
    error_step="$2"
    echo -e "${RED}🔴 Error detected at step $error_step: $error_message${NC}"
    log_action "error: interruption at step $error_step: $error_message"
    cleanup
    exit 1
}

# 🧹 Cleanup function
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up...${NC}"
    # restore original config if needed
    if [ -f /home/firstb00t/profile.bak ]; then
        mv /home/firstb00t/profile.bak /home/firstb00t/profile
    fi
    log_action "info: cleanup completed"
}

# 🔄 Check dependencies
check_dependencies() {
    echo -e "${BLUE}🔍 Checking dependencies...${NC}"
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

# 🔍 assess system
assess_system() {
    echo -e "${BLUE}🔍 Assessing system...${NC}"
    
    # check system requirements
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    total_disk=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
    cpu_cores=$(nproc)
    
    # log system info
    log_action "info: total memory: ${total_mem}MB"
    log_action "info: disk space: ${total_disk}GB"
    log_action "info: CPU cores: ${cpu_cores}"
    
    # verify minimum requirements
    if [ "$total_mem" -lt 1024 ]; then
        handle_error "insufficient memory (minimum 1GB required)" "system assessment"
    fi
    if [ "$total_disk" -lt 10 ]; then
        handle_error "insufficient disk space (minimum 10GB required)" "system assessment"
    fi
    
    log_action "info: system assessment completed"
}

# ⚙️ Configure SSH port
configure_ssh_port() {
    # Skip if non-interactive
    if [ "${FIRSTBOOT_NON_INTERACTIVE:-false}" = "true" ]; then
        ssh_port="22022"
        export SSH_PORT="$ssh_port"
        echo "$ssh_port" > /etc/firstboot/ssh_port
        echo "✅ SSH port configured: ${ssh_port} (default, non-interactive)"
        log_action "info : SSH port configured to ${ssh_port} (non-interactive)"
        return
    fi
    
    echo ""
    echo "🔒 SSH Port Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Default port 22 is a common target for attacks."
    echo "Standard secure port: 22022"
    echo ""
    read -p "Enter SSH port (default 22022): " ssh_port
    
    # Validate port
    if [ -z "$ssh_port" ]; then
        ssh_port="22022"
    fi
    
    if ! [[ "$ssh_port" =~ ^[0-9]+$ ]] || [ "$ssh_port" -lt 1024 ] || [ "$ssh_port" -gt 65535 ]; then
        echo "❌ Invalid port. Using default 22022"
        ssh_port="22022"
    fi
    
    # Export for SSH modules
    export SSH_PORT="$ssh_port"
    echo "$ssh_port" > /home/firstb00t/ssh_port
    echo "✅ SSH port configured: ${ssh_port}"
    log_action "info : SSH port configured to ${ssh_port}"
}

# 📧 Configure admin email
configure_admin_email() {
    # Skip if non-interactive
    if [ "${FIRSTBOOT_NON_INTERACTIVE:-false}" = "true" ]; then
        admin_email="root@localhost"
        export ADMIN_EMAIL="$admin_email"
        echo "$admin_email" > /etc/firstboot/admin_email
        echo "✅ Admin email configured: ${admin_email} (default, non-interactive)"
        log_action "info : Admin email configured to ${admin_email} (non-interactive)"
        return
    fi
    
    echo ""
    echo "📧 Administrator Email Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Email address for security alerts and system notifications:"
    echo "- Fail2ban intrusion alerts"
    echo "- AIDE file integrity reports"
    echo "- Lynis vulnerability scan results"
    echo "- Certificate expiry warnings"
    echo ""
    read -p "Enter admin email (e.g., admin@example.com): " admin_email
    
    # Validate email format (basic check)
    if [ -z "$admin_email" ]; then
        echo "⚠️  No email provided. Using root@localhost (local only)"
        admin_email="root@localhost"
    elif ! [[ "$admin_email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "⚠️  Invalid email format. Using root@localhost"
        admin_email="root@localhost"
    fi
    
    # Export for modules
    export ADMIN_EMAIL="$admin_email"
    echo "$admin_email" > /home/firstb00t/admin_email
    echo "✅ Admin email configured: ${admin_email}"
    log_action "info : Admin email configured to ${admin_email}"
}

# 🍯 Configure SSH honeypot
configure_ssh_honeypot() {
    # Skip if non-interactive
    if [ "${FIRSTBOOT_NON_INTERACTIVE:-false}" = "true" ]; then
        export HONEYPOT_ENABLED="false"
        echo "false" > /home/firstb00t/honeypot_enabled
        echo "⏭️  Honeypot disabled (non-interactive mode)"
        log_action "info : SSH honeypot disabled (non-interactive)"
        return
    fi
    
    echo ""
    echo "🍯 SSH Honeypot Configuration (Port 22 Trap)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Leave port 22 open as a honeypot to trap attackers?"
    echo "- Any connection attempt to port 22 = permanent ban"
    echo "- Your management IP will be whitelisted"
    echo "- SSH will run on the secure port configured above"
    echo ""
    
    # Auto-detect user's source IP from SSH session
    local detected_ip=""
    if [ -n "$SSH_CONNECTION" ]; then
        detected_ip=$(echo "$SSH_CONNECTION" | awk '{print $1}')
        echo "🔍 Auto-detected your IP: ${detected_ip}"
    elif [ -n "$SSH_CLIENT" ]; then
        detected_ip=$(echo "$SSH_CLIENT" | awk '{print $1}')
        echo "🔍 Auto-detected your IP: ${detected_ip}"
    else
        echo "⚠️  Could not auto-detect IP (not running via SSH)"
    fi
    
    read -p "Enable port 22 honeypot? (y/N): " enable_honeypot
    
    if [[ "$enable_honeypot" =~ ^[Yy]$ ]]; then
        echo ""
        if [ -n "$detected_ip" ]; then
            echo "Detected IP: ${detected_ip}"
            read -p "Use this IP for whitelist? (Y/n): " use_detected
            if [[ "$use_detected" =~ ^[Nn]$ ]]; then
                read -p "Enter management IP (CIDR, e.g., 203.0.113.45/32): " mgmt_ip
            else
                # Add /32 if no CIDR notation
                if [[ "$detected_ip" =~ / ]]; then
                    mgmt_ip="$detected_ip"
                else
                    mgmt_ip="${detected_ip}/32"
                fi
            fi
        else
            read -p "Enter management IP (CIDR, e.g., 203.0.113.45/32): " mgmt_ip
        fi
        
        if [ -z "$mgmt_ip" ]; then
            echo "❌ No IP provided. Honeypot disabled for safety."
            export HONEYPOT_ENABLED="false"
        else
            export HONEYPOT_ENABLED="true"
            export HONEYPOT_WHITELIST_IP="$mgmt_ip"
            echo "true" > /home/firstb00t/honeypot_enabled
            echo "$mgmt_ip" > /home/firstb00t/honeypot_whitelist_ip
            echo "✅ Honeypot enabled. Whitelisted IP: ${mgmt_ip}"
            log_action "info : SSH honeypot enabled with whitelist ${mgmt_ip}"
        fi
    else
        export HONEYPOT_ENABLED="false"
        echo "false" > /home/firstb00t/honeypot_enabled
        echo "⏭️  Honeypot disabled. Port 22 will be closed by firewall."
        log_action "info : SSH honeypot disabled"
    fi
}

# ⚙️ Select profile
select_profile() {
    echo ""
    echo -e "${BLUE}⚙️ Selecting profile...${NC}"
    
    # Check if profile already specified via environment
    if [ -n "${FIRSTBOOT_PROFILE:-}" ]; then
        selected_profile="${FIRSTBOOT_PROFILE}"
        echo -e "${GREEN}✅ Profile: ${selected_profile} (pre-selected)${NC}"
    elif [ "${FIRSTBOOT_NON_INTERACTIVE:-false}" = "true" ]; then
        # Non-interactive mode: default to basic
        selected_profile="basic"
        echo -e "${GREEN}✅ Non-interactive mode: using basic profile${NC}"
    else
        # display available profiles
        echo ""
        echo -e "${CYAN}Available profiles:${NC}"
        echo "  🟢 basic      - Essential security"
        echo "  🟡 standard   - Balanced security"
        echo "  🔴 advanced   - Maximum security"
        echo "  🔶 step by step - Interactive module selection"
        echo ""
        
        # prompt for profile selection
        read -p "Choose profile (basic/standard/advanced/step by step): " selected_profile
    fi
    
    # validate selection
    case "$selected_profile" in
        "basic"|"standard"|"advanced"|"step by step")
            echo -e "${GREEN}✅ Profile selected: $selected_profile${NC}"
            log_action "info: profile selected: $selected_profile"
            ;;
        *)
            handle_error "invalid profile" "profile selection"
            ;;
    esac
    
    # save profile selection
    mkdir -p /home/firstb00t
    echo "$selected_profile" > /home/firstb00t/profile
    
    log_action "info: profile selection completed"
}

# ⚙️ configure profile
configure_profile() {
    echo ""
    echo -e "${BLUE}⚙️ Configuring profile...${NC}"
    
    # read selected profile
    selected_profile=$(cat /home/firstb00t/profile)
    
    # 🔶 ensure modules directory exists
    mkdir -p /home/firstb00t/modules
    
    # configure based on profile
    case "$selected_profile" in
        "basic")
            # basic profile configuration
            echo -e "${BLUE}📦 Profile: basic${NC}"
            # enable basic modules
            touch /home/firstb00t/modules/02-system_updates.enabled
            touch /home/firstb00t/modules/03-user_management.enabled
            # Temporarily skip SSH modules for testing to preserve log access
            # touch /home/firstb00t/modules/04-ssh_config.enabled
            # touch /home/firstb00t/modules/05-ssh_hardening.enabled
            touch /home/firstb00t/modules/06-firewall_config.enabled
            touch /home/firstb00t/modules/11-monitoring.enabled
            echo -e "${YELLOW}⚠️  SSH hardening modules skipped (testing mode)${NC}"
            ;;
        "standard")
            # standard profile configuration
            echo -e "${BLUE}📦 Profile: standard${NC}"
            # enable standard modules
            touch /home/firstb00t/modules/02-system_updates.enabled
            touch /home/firstb00t/modules/03-user_management.enabled
            touch /home/firstb00t/modules/04-ssh_config.enabled
            touch /home/firstb00t/modules/05-ssh_hardening.enabled
            touch /home/firstb00t/modules/06-firewall_config.enabled
            touch /home/firstb00t/modules/07-fail2ban.enabled
            touch /home/firstb00t/modules/08-ssl_config.enabled
            touch /home/firstb00t/modules/09-dns_config.enabled
            touch /home/firstb00t/modules/10-mail_config.enabled
            ;;
        "advanced")
            # advanced profile configuration
            echo -e "${BLUE}📦 Profile: advanced${NC}"
            # enable all modules
            touch /home/firstb00t/modules/02-system_updates.enabled
            touch /home/firstb00t/modules/03-user_management.enabled
            touch /home/firstb00t/modules/04-ssh_config.enabled
            touch /home/firstb00t/modules/05-ssh_hardening.enabled
            touch /home/firstb00t/modules/06-firewall_config.enabled
            touch /home/firstb00t/modules/07-fail2ban.enabled
            touch /home/firstb00t/modules/08-ssl_config.enabled
            touch /home/firstb00t/modules/09-dns_config.enabled
            touch /home/firstb00t/modules/10-mail_config.enabled
            touch /home/firstb00t/modules/11-monitoring.enabled
            ;;
        "step by step")
            # step by step profile configuration
            echo -e "${BLUE}📦 Profile: step by step${NC}"
            echo "Interactive module selection will be handled by the main script"
            # No modules enabled by default - main script will prompt for each
            ;;
    esac
    
    log_action "info: profile configuration completed"
}

# ✅ validate profile
validate_profile() {
    echo ""
    echo -e "${BLUE}✅ Validating profile...${NC}"
    
    # check if profile file exists
    if [ ! -f /home/firstb00t/profile ]; then
        handle_error "profile file not found" "profile validation"
    fi
    
    # check if modules directory exists
    if [ ! -d /home/firstb00t/modules ]; then
        handle_error "modules directory not found" "profile validation"
    fi
    
    # check if at least one module is enabled
    if ! ls /home/firstb00t/modules/*.enabled > /dev/null 2>&1; then
        handle_error "no modules enabled" "profile validation"
    fi
    
    log_action "info: profile validation completed"
}

# 🎯 main function
main() {
    # ensure common logging utilities are available
    source "$(dirname "${BASH_SOURCE[0]}")/../common/logging.sh" 2>/dev/null || true

    print_title_frame "🚀" "installing module ${MODULE_NAME}..."

    # check dependencies
    check_dependencies

    # step 1: assess system
    echo ""
    update_progress 1 7
    echo -e "${BLUE}📦 Step 1: Assessing system...${NC}"
    assess_system
    log_action "info: step 1 completed"

    # step 2: select profile
    echo ""
    update_progress 2 7
    echo -e "${BLUE}📦 Step 2: Selecting profile...${NC}"
    select_profile
    log_action "info: step 2 completed"
    
    # step 3: configure SSH port
    echo ""
    update_progress 3 7
    echo -e "${BLUE}📦 Step 3: Configuring SSH port...${NC}"
    configure_ssh_port
    log_action "info: step 3 completed"
    
    # step 4: configure admin email
    echo ""
    update_progress 4 7
    echo -e "${BLUE}📦 Step 4: Configuring admin email...${NC}"
    configure_admin_email
    log_action "info: step 4 completed"
    
    # step 5: configure SSH honeypot
    echo ""
    update_progress 5 7
    echo -e "${BLUE}📦 Step 5: Configuring SSH honeypot...${NC}"
    configure_ssh_honeypot
    log_action "info: step 5 completed"

    # step 6: configure profile
    echo ""
    update_progress 6 7
    echo -e "${BLUE}📦 Step 6: Configuring profile...${NC}"
    configure_profile
    log_action "info: step 6 completed"

    # step 7: validate
    echo ""
    update_progress 7 7
    echo -e "${BLUE}📦 Step 7: Validating profile...${NC}"
    validate_profile
    log_action "info: step 7 completed"

    echo ""
    echo -e "${GREEN}🎉 Module $MODULE_NAME installed successfully${NC}"
    log_action "success: module $MODULE_NAME installation completed"
}

# 🎯 run main function
main 