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
MODULE_NAME="ssl_config"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="SSL/TLS configuration for services"
MODULE_DEPENDENCIES=("openssl" "systemctl" "certbot")

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
    if [ -f /etc/ssl/openssl.cnf.bak ]; then
        mv /etc/ssl/openssl.cnf.bak /etc/ssl/openssl.cnf
    fi
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

# 📦 install certbot
install_certbot() {
    echo -e "${BLUE}📦 installing certbot...${NC}"
    
    # check if already installed
    if dpkg -s certbot >/dev/null 2>&1; then
        log_action "info: certbot already installed"
        echo -e "${GREEN}✅ certbot already installed${NC}"
        return 0
    fi
    
    # update package list
    apt update || handle_error "failed to update package lists" "package update"
    
    # install certbot
    apt install -y certbot python3-certbot-apache python3-certbot-nginx || handle_error "failed to install certbot" "package install"
    
    log_action "info: certbot installed"
}

# 🔒 configure ssl
configure_ssl() {
    echo -e "${BLUE}🔒 configuring SSL...${NC}"
    
    # backup original config
    cp /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf.bak || handle_error "failed to back up OpenSSL config" "backup"
    
    # create dhparam (skip if exists)
    if [ ! -f /etc/ssl/certs/dhparam.pem ]; then
        openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048 || handle_error "failed to generate DH parameters" "dhparam generation"
    else
        log_action "info: dhparam already exists"
    fi
    
    # configure openssl
    cat > /etc/ssl/openssl.cnf << EOF
[req]
default_bits = 2048
default_md = sha256
default_keyfile = privkey.pem
distinguished_name = req_distinguished_name
req_extensions = v3_req
x509_extensions = v3_ca

[req_distinguished_name]
countryName = Country Name (2 letter code)
stateOrProvinceName = State or Province Name
localityName = Locality Name
organizationName = Organization Name
organizationalUnitName = Organizational Unit Name
commonName = Common Name
emailAddress = Email Address

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[v3_ca]
basicConstraints = CA:TRUE
keyUsage = cRLSign, keyCertSign
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
IP.1 = 127.0.0.1
EOF
    
    # set permissions
    chmod 644 /etc/ssl/openssl.cnf || handle_error "failed to set OpenSSL config permissions" "permissions"
    
    log_action "info: SSL configuration applied"
}

# 🔄 configure services
configure_services() {
    echo -e "${BLUE}🔄 configuring services (NIST SP 800-52)...${NC}"
    
    # NIST SP 800-52 Rev 2: TLS 1.2+ with strong ciphers and PFS
    STRONG_CIPHERS="ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"
    
    # configure apache2
    if [ -f /etc/apache2/apache2.conf ]; then
        echo -e "${BLUE}🔒 hardening Apache2 (NIST SP 800-52)...${NC}"
        cat > /etc/apache2/conf-available/ssl-hardening.conf << EOF
# NIST SP 800-52 Rev 2 compliance
# Disable weak protocols (SSLv2, SSLv3, TLS 1.0, TLS 1.1)
SSLProtocol -all +TLSv1.2 +TLSv1.3

# Strong ciphers with Perfect Forward Secrecy (ECDHE/DHE first)
SSLCipherSuite ${STRONG_CIPHERS}
SSLHonorCipherOrder on

# Disable session tickets (use only session IDs)
SSLSessionTickets off

# OCSP stapling for certificate validation
SSLUseStapling on
SSLStaplingCache "shmcb:logs/ssl_stapling(32768)"
SSLStaplingReturnResponderErrors off

# HSTS: force browsers to use HTTPS (prevent downgrade attacks)
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"

# X-Frame-Options: prevent clickjacking
Header always set X-Frame-Options "DENY"

# X-Content-Type-Options: prevent MIME type sniffing
Header always set X-Content-Type-Options "nosniff"

# Content-Security-Policy: defense against XSS/injection
Header always set Content-Security-Policy "default-src 'self'; upgrade-insecure-requests"
EOF
        a2enconf ssl-hardening || handle_error "failed to enable Apache2 SSL hardening" "Apache2 configuration"
        a2enmod headers || handle_error "failed to enable Apache2 headers module" "Apache2 configuration"
        log_action "info: Apache2 TLS 1.2/1.3 hardening configured"
    fi
    
    # configure nginx
    if [ -f /etc/nginx/nginx.conf ]; then
        echo -e "${BLUE}🔒 hardening Nginx (NIST SP 800-52)...${NC}"
        cat > /etc/nginx/conf.d/ssl-hardening.conf << EOF
# NIST SP 800-52 Rev 2 compliance
# Disable weak protocols (SSLv2, SSLv3, TLS 1.0, TLS 1.1)
ssl_protocols TLSv1.2 TLSv1.3;

# Strong ciphers with Perfect Forward Secrecy (ECDHE/DHE)
ssl_ciphers '${STRONG_CIPHERS}';
ssl_prefer_server_ciphers on;

# Session management (no tickets, use session cache)
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
ssl_session_tickets off;

# OCSP stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# DH parameters for DHE ciphers
ssl_dhparam /etc/ssl/certs/dhparam.pem;

# HSTS: force browsers to use HTTPS (prevent downgrade attacks)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# X-Frame-Options: prevent clickjacking
add_header X-Frame-Options "DENY" always;

# X-Content-Type-Options: prevent MIME type sniffing
add_header X-Content-Type-Options "nosniff" always;

# Content-Security-Policy: defense against XSS/injection
add_header Content-Security-Policy "default-src 'self'; upgrade-insecure-requests" always;
EOF
        nginx -t || handle_error "invalid Nginx configuration" "Nginx configuration"
        log_action "info: Nginx TLS 1.2/1.3 hardening configured"
    fi
    
    # configure postfix (SMTP TLS mandatory)
    if [ -f /etc/postfix/main.cf ]; then
        echo -e "${BLUE}🔒 hardening Postfix (SMTP TLS mandatory)...${NC}"
        # Ensure mandatory TLS for submission (enforce in master.cf)
        postconf -e "smtpd_tls_security_level=encrypt" || handle_error "failed to set Postfix TLS level" "Postfix configuration"
        postconf -e "smtpd_tls_protocol=!SSLv2,!SSLv3,!TLSv1,!TLSv1.1" || handle_error "failed to disable weak TLS" "Postfix configuration"
        postconf -e "smtp_tls_security_level=encrypt" || handle_error "failed to set outbound TLS" "Postfix configuration"
        log_action "info: Postfix TLS 1.2+ mandatory encryption configured"
    fi
    
    log_action "info: service TLS hardening completed (NIST SP 800-52)"
}

# 🎯 main function
main() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════
║ 🚀 installing module $MODULE_NAME...                    
╚════════════════════════════════════════════════════════════${NC}"
    # profile enablement
    if [ ! -f "/etc/firstboot/modules/${MODULE_NAME}.enabled" ]; then
        log_action "info: module disabled for this profile; skipping"
        echo -e "${YELLOW}⏭️  module not enabled for this profile${NC}"
        exit 0
    fi

    # check 
    # check dependencies
    check_dependencies

    # step 1: install certbot
    update_progress 1 4
    echo -e "${BLUE}📦 step 1: installation...${NC}"
    install_certbot
    log_action "info: step 1 completed"

    # step 2: configure ssl
    update_progress 2 4
    echo -e "${BLUE}📦 step 2: SSL configuration...${NC}"
    configure_ssl
    log_action "info: step 2 completed"

    # step 3: configure services
    update_progress 3 4
    echo -e "${BLUE}📦 step 3: service configuration...${NC}"
    configure_services
    log_action "info: step 3 completed"

    # step 4: verify
    update_progress 4 4
    echo -e "${BLUE}📦 step 4: verification...${NC}"
    
    # verify dhparam
    if [ ! -f /etc/ssl/certs/dhparam.pem ]; then
        handle_error "DH parameters not generated" "verification"
    fi
    
    # verify openssl config
    if ! openssl ciphers -v | grep -q "TLSv1.2"; then
        handle_error "invalid OpenSSL cipher configuration" "verification"
    fi
    
    log_action "info: step 4 completed"

    echo -e "${GREEN}🎉 module $MODULE_NAME installed successfully${NC}"
    log_action "success: module $MODULE_NAME installation completed"
}

# 🎯 run main function
main 