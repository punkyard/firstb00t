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

# 📋 module information
MODULE_NAME="fail2ban"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="installation et configuration de fail2ban"
MODULE_DEPENDENCIES=("apt" "systemctl" "fail2ban-client")

# 📝 logging function
log_action() {
    mkdir -p /var/log/firstboot
    echo "[$(date -Iseconds)] [${MODULE_NAME}] $1" | tee -a "/var/log/firstboot/${MODULE_NAME}.log"
}

# 🚨 error handling
handle_error() {
    error_message="$1"
    error_step="$2"
    echo -e "${RED}🔴 erreur détectée à l'étape $error_step : $error_message${NC}"
    log_action "erreur : interruption à l'étape $error_step : $error_message"
    cleanup
    exit 1
}

# 🧹 cleanup function
cleanup() {
    echo -e "${YELLOW}🧹 nettoyage en cours...${NC}"
    # restore original config if needed
    if [ -f /etc/fail2ban/jail.local.bak ]; then
        mv /etc/fail2ban/jail.local.bak /etc/fail2ban/jail.local
        log_action "info : configuration fail2ban restaurée"
    fi
    # leave fail2ban running; only restore config
    log_action "info : nettoyage effectué"
}

# 🔄 check dependencies
check_dependencies() {
    echo -e "${BLUE}🔍 vérification des dépendances...${NC}"
    for dep in "${MODULE_DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            handle_error "dépendance manquante : $dep" "vérification des dépendances"
        fi
    done
    echo -e "${GREEN}🟢 toutes les dépendances sont satisfaites${NC}"
    log_action "info : vérification des dépendances réussie"
}

# 📊 progress tracking
update_progress() {
    current_step="$1"
    total_steps="$2"
    echo -e "${BLUE}📊 progression : $current_step/$total_steps${NC}"
}

# 📦 install fail2ban
install_fail2ban() {
    echo -e "${BLUE}📦 installation de fail2ban...${NC}"
    
    # check if already installed
    if dpkg -s fail2ban >/dev/null 2>&1; then
        log_action "info : fail2ban déjà installé"
        echo -e "${GREEN}✅ fail2ban déjà installé${NC}"
        return 0
    fi
    
    # update package list
    apt update || handle_error "échec de la mise à jour des paquets" "mise à jour des paquets"
    
    # install fail2ban
    apt install -y fail2ban || handle_error "échec de l'installation de fail2ban" "installation"
    
    log_action "info : fail2ban installé"
}

# 🔒 configure fail2ban
configure_fail2ban() {
    echo -e "${BLUE}🔒 configuration de fail2ban...${NC}"
    
    # backup original config
    cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak 2>/dev/null || true
    
    # create jail.local
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
destemail = root@localhost
sender = fail2ban@localhost
action = %(action_mwl)s

[sshd]
enabled = true
port = 22222
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
findtime = 600
bantime = 3600

[sshd-ddos]
enabled = true
port = 22222
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 3
findtime = 600
bantime = 3600

[apache]
enabled = true
port = http,https
filter = apache-auth
logpath = /var/log/apache2/error.log
maxretry = 3
findtime = 600
bantime = 3600

[apache-bad-requests]
enabled = true
port = http,https
filter = apache-bad-requests
logpath = /var/log/apache2/access.log
maxretry = 3
findtime = 600
bantime = 3600

[postfix]
enabled = true
port = smtp,465,submission
filter = postfix
logpath = /var/log/mail.log
maxretry = 3
findtime = 600
bantime = 3600

[dovecot]
enabled = true
port = pop3,pop3s,imap,imaps
filter = dovecot
logpath = /var/log/mail.log
maxretry = 3
findtime = 600
bantime = 3600
EOF
    
    # set permissions
    chmod 644 /etc/fail2ban/jail.local || handle_error "échec de la définition des permissions" "définition des permissions"
    
    log_action "info : configuration de fail2ban effectuée"
}

# 🔄 restart service
restart_service() {
    echo -e "${BLUE}🔄 redémarrage du service fail2ban...${NC}"
    
    # restart service
    systemctl restart fail2ban || handle_error "échec du redémarrage du service" "redémarrage du service"
    
    # verify service status
    if ! systemctl is-active --quiet fail2ban; then
        handle_error "service fail2ban non actif" "vérification du service"
    fi
    
    log_action "info : service fail2ban redémarré"
}

# 🎯 main function
main() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════
║ 🚀 installation du module $MODULE_NAME...                    
╚════════════════════════════════════════════════════════════${NC}"
profile enablement
    if [ ! -f "/etc/firstboot/modules/${MODULE_NAME}.enabled" ]; then
        log_action "info: module disabled for this profile; skipping"
        echo -e "${YELLOW}⏭️  module non activé pour ce profil${NC}"
        exit 0
    fi

    # check 
    # check dependencies
    check_dependencies

    # step 1: install fail2ban
    update_progress 1 4
    echo -e "${BLUE}📦 étape 1 : installation...${NC}"
    install_fail2ban
    log_action "info : étape 1 terminée"

    # step 2: configure fail2ban
    update_progress 2 4
    echo -e "${BLUE}📦 étape 2 : configuration...${NC}"
    configure_fail2ban
    log_action "info : étape 2 terminée"

    # step 3: restart service
    update_progress 3 4
    echo -e "${BLUE}📦 étape 3 : redémarrage du service...${NC}"
    restart_service
    log_action "info : étape 3 terminée"

    # step 4: verify
    update_progress 4 4
    echo -e "${BLUE}📦 étape 4 : vérification...${NC}"
    
    # verify service
    if ! systemctl is-active --quiet fail2ban; then
        handle_error "service fail2ban non actif" "vérification"
    fi
    
    # verify jails
    if ! fail2ban-client status | grep -q "Status: active"; then
        handle_error "fail2ban non actif" "vérification"
    fi
    
    log_action "info : étape 4 terminée"

    echo -e "${GREEN}🎉 module $MODULE_NAME installé avec succès${NC}"
    log_action "succès : installation du module $MODULE_NAME terminée"
}

# 🎯 run main function
main 