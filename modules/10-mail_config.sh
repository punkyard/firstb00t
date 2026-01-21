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
MODULE_ID="10-mail_config"
MODULE_NAME="mail_config"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="mail server configuration"
MODULE_DEPENDENCIES=("postfix" "dovecot" "systemctl" "openssl")

# 📝 Logging function
log_action() {
    mkdir -p /var/log/firstboot
    echo "[$(date -Iseconds)] [${MODULE_NAME}] $1" | tee -a "/var/log/firstboot/${MODULE_NAME}.log"
}

# 🚨 Error handling
handle_error() {
    error_message="$1"
    error_step="$2"
    echo -e "${RED}🔴 Error detected at step $error_step: $error_message${NC}"
    log_action "error: interrupted at step $error_step: $error_message"
    cleanup
    exit 1
}

# 🧹 cleanup function
cleanup() {
    echo -e "${YELLOW}🧹 cleaning up...${NC}"
    # restore original config if needed
    if [ -f /etc/postfix/main.cf.bak ]; then
        mv /etc/postfix/main.cf.bak /etc/postfix/main.cf
        log_action "info: Postfix configuration restored"
    fi
    if [ -f /etc/dovecot/dovecot.conf.bak ]; then
        mv /etc/dovecot/dovecot.conf.bak /etc/dovecot/dovecot.conf
        log_action "info: Dovecot configuration restored"
    fi
    # leave services running; only restore configs
    log_action "info: cleanup completed"
}

# 🔄 check dependencies
check_dependencies() {
    echo -e "${BLUE}🔍 checking dependencies...${NC}"
    for dep in "${MODULE_DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            handle_error "missing dependency: $dep" "dependency check"
        fi
    done
    echo -e "${GREEN}🟢 all dependencies satisfied${NC}"
    log_action "info: dependency check passed"
}

# 📊 progress tracking
update_progress() {
    current_step="$1"
    total_steps="$2"
    echo -e "${BLUE}📊 progress: $current_step/$total_steps${NC}"
}

# 📦 install mail server
install_mail_server() {
    echo -e "${BLUE}📦 installing mail server...${NC}"
    
    # check if already installed
    if dpkg -s postfix >/dev/null 2>&1 && dpkg -s dovecot-imapd >/dev/null 2>&1; then
        log_action "info: mail server already installed"
        echo -e "${GREEN}✅ mail server already installed${NC}"
        return 0
    fi
    
    # update package list
    apt update || handle_error "failed to update package lists" "package update"
    
    # install postfix and dovecot
    apt install -y postfix dovecot-imapd dovecot-pop3d || handle_error "failed to install packages" "package install"
    
    log_action "info: mail server installed"
}

# 🔒 configure postfix
configure_postfix() {
    echo -e "${BLUE}🔒 configuring Postfix...${NC}"
    
    # backup original config
    cp /etc/postfix/main.cf /etc/postfix/main.cf.bak || handle_error "failed to back up Postfix configuration" "backup"
    
    # configure main.cf
    cat > /etc/postfix/main.cf << EOF
# basic configuration
smtpd_banner = \$myhostname ESMTP \$mail_name
biff = no
append_dot_mydomain = no
readme_directory = no

# tls parameters
smtpd_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key
smtpd_use_tls = yes
smtpd_tls_auth_only = yes
smtpd_tls_security_level = may
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_mandatory_ciphers = high
smtpd_tls_ciphers = high
tls_high_cipherlist = ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
smtpd_tls_mandatory_exclude_ciphers = aNULL, DES, 3DES, MD5, DES+MD5, RC4
smtpd_tls_exclude_ciphers = aNULL, DES, 3DES, MD5, DES+MD5, RC4
smtpd_tls_dh1024_param_file = \${config_directory}/dh2048.pem
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache

# authentication
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = \$myhostname

# restrictions
smtpd_helo_required = yes
smtpd_helo_restrictions = permit_mynetworks, reject_invalid_helo_hostname, reject_non_fqdn_helo_hostname, reject_unknown_helo_hostname
smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination, reject_invalid_hostname, reject_non_fqdn_hostname, reject_non_fqdn_sender, reject_non_fqdn_recipient, reject_unknown_sender_domain, reject_unknown_recipient_domain, reject_rbl_client zen.spamhaus.org, reject_rhsbl_reverse_client dbl.spamhaus.org, reject_rhsbl_helo dbl.spamhaus.org, reject_rhsbl_sender dbl.spamhaus.org
smtpd_sender_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_non_fqdn_sender, reject_unknown_sender_domain, reject_unauth_pipelining
smtpd_client_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unknown_client_hostname
smtpd_data_restrictions = reject_unauth_pipelining

# other
myhostname = \$hostname
mydomain = \$hostname
myorigin = \$mydomain
inet_interfaces = all
inet_protocols = all
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
message_size_limit = 0
virtual_mailbox_domains = \$mydomain
virtual_mailbox_base = /var/mail/vhosts
virtual_mailbox_maps = hash:/etc/postfix/vmaps
virtual_minimum_uid = 100
virtual_uid_maps = static:5000
virtual_gid_maps = static:5000
virtual_alias_maps = hash:/etc/postfix/valiases
EOF
    
    # set permissions
    chmod 644 /etc/postfix/main.cf || handle_error "failed to set Postfix config permissions" "permissions"
    
    log_action "info: Postfix configuration applied"
}

# 🔒 configure dovecot
configure_dovecot() {
    echo -e "${BLUE}🔒 configuring Dovecot...${NC}"
    
    # backup original config
    cp /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.bak || handle_error "failed to back up Dovecot configuration" "backup"
    
    # configure dovecot.conf
    cat > /etc/dovecot/dovecot.conf << EOF
protocols = imap pop3
listen = *

mail_privileged_group = mail
mail_access_groups = mail

mail_location = maildir:/var/mail/vhosts/%d/%n

passdb {
    driver = pam
}

userdb {
    driver = static
    args = uid=5000 gid=5000 home=/var/mail/vhosts/%d/%n
}

service auth {
    unix_listener /var/spool/postfix/private/auth {
        mode = 0660
        user = postfix
        group = postfix
    }
}

ssl = required
ssl_cert = </etc/ssl/certs/ssl-cert-snakeoil.pem
ssl_key = </etc/ssl/private/ssl-cert-snakeoil.key
ssl_min_protocol = TLSv1.2
ssl_prefer_server_ciphers = yes
ssl_cipher_list = ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
EOF
    
    # set permissions
    chmod 644 /etc/dovecot/dovecot.conf || handle_error "failed to set Dovecot config permissions" "permissions"
    
    log_action "info: Dovecot configuration applied"
}

# 🔄 restart services
restart_services() {
    echo -e "${BLUE}🔄 restarting services...${NC}"
    
    # restart postfix
    systemctl restart postfix || handle_error "failed to restart Postfix" "Postfix restart"
    
    # restart dovecot
    systemctl restart dovecot || handle_error "failed to restart Dovecot" "Dovecot restart"
    
    # verify services
    if ! systemctl is-active --quiet postfix; then
        handle_error "Postfix service is not active" "service verification"
    fi
    if ! systemctl is-active --quiet dovecot; then
        handle_error "Dovecot service is not active" "service verification"
    fi
    
    log_action "info: services restarted"
}

# 🎯 main function
main() {
    source "$(dirname "${BASH_SOURCE[0]}")/../common/logging.sh" 2>/dev/null || true

    print_title_frame "📧" "installing module ${MODULE_NAME}..."
    # profile enablement
    if [ ! -f "/etc/firstboot/modules/${MODULE_NAME}.enabled" ]; then
        log_action "info: module disabled for this profile; skipping"
        echo -e "${YELLOW}⏭️  module not enabled for this profile${NC}"
        exit 0
    fi

    # check 
    # check dependencies
    check_dependencies

    # step 1: install mail server
    update_progress 1 5
    echo -e "${BLUE}📦 step 1: installation...${NC}"
    install_mail_server
    log_action "info: step 1 completed"

    # step 2: configure postfix
    update_progress 2 5
    echo -e "${BLUE}📦 step 2: Postfix configuration...${NC}"
    configure_postfix
    log_action "info: step 2 completed"

    # step 3: configure dovecot
    update_progress 3 5
    echo -e "${BLUE}📦 step 3: Dovecot configuration...${NC}"
    configure_dovecot
    log_action "info: step 3 completed"

    # step 4: restart services
    update_progress 4 5
    echo -e "${BLUE}📦 step 4: restarting services...${NC}"
    restart_services
    log_action "info: step 4 completed"

    # step 5: verify
    update_progress 5 5
    echo -e "${BLUE}📦 step 5: verification...${NC}"
    
    # verify services
    if ! systemctl is-active --quiet postfix; then
        handle_error "Postfix service is not active" "verification"
    fi
    if ! systemctl is-active --quiet dovecot; then
        handle_error "Dovecot service is not active" "verification"
    fi
    
    # verify ports
    if ! netstat -tuln | grep -q ":25"; then
        handle_error "SMTP port (25) is not open" "verification"
    fi
    if ! netstat -tuln | grep -q ":143"; then
        handle_error "IMAP port (143) is not open" "verification"
    fi
    if ! netstat -tuln | grep -q ":110"; then
        handle_error "POP3 port (110) is not open" "verification"
    fi
    
    log_action "info: step 5 completed"

    echo -e "${GREEN}🎉 module $MODULE_NAME installed successfully${NC}"
    log_action "success: module $MODULE_NAME installation completed"
}

# 🎯 run main function
main 