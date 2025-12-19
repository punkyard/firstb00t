#!/bin/bash

# 🌈 color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # no color

# 📋 module information
MODULE_NAME="ssh_hardening"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="renforcement de la sécurité ssh"
MODULE_DEPENDENCIES=("sshd" "systemctl")

# 📝 logging function
log_action() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> /var/log/firstboot_script.log
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
    if [ -f /etc/ssh/sshd_config.bak ]; then
        mv /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
    fi
    # restart ssh service
    systemctl restart sshd
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

# 🔒 configure ssh
configure_ssh() {
    echo -e "${BLUE}🔒 configuration de ssh...${NC}"
    
    # backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak || handle_error "échec de la sauvegarde de la configuration" "sauvegarde de la configuration"
    
    # set security parameters
    cat > /etc/ssh/sshd_config << EOF
# port configuration
Port 22222

# authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# security
Protocol 2
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitUserEnvironment no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 2
LoginGraceTime 60

# logging
SyslogFacility AUTH
LogLevel VERBOSE

# other
Banner /etc/issue.net
EOF
    
    # set permissions
    chmod 600 /etc/ssh/sshd_config || handle_error "échec de la définition des permissions" "définition des permissions"
    
    log_action "info : configuration ssh effectuée"
}

# 🔄 restart service
restart_service() {
    echo -e "${BLUE}🔄 redémarrage du service ssh...${NC}"
    
    # test config
    sshd -t || handle_error "configuration ssh invalide" "test de la configuration"
    
    # restart service
    systemctl restart sshd || handle_error "échec du redémarrage du service" "redémarrage du service"
    
    # verify service status
    if ! systemctl is-active --quiet sshd; then
        handle_error "service ssh non actif" "vérification du service"
    fi
    
    log_action "info : service ssh redémarré"
}

# 🎯 main function
main() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════
║ 🚀 installation du module $MODULE_NAME...                   
╚════════════════════════════════════════════════════════════${NC}"

    # check dependencies
    check_dependencies

    # step 1: backup and configure
    update_progress 1 3
    echo -e "${BLUE}📦 étape 1 : configuration...${NC}"
    configure_ssh
    log_action "info : étape 1 terminée"

    # step 2: restart service
    update_progress 2 3
    echo -e "${BLUE}📦 étape 2 : redémarrage du service...${NC}"
    restart_service
    log_action "info : étape 2 terminée"

    # step 3: verify
    update_progress 3 3
    echo -e "${BLUE}📦 étape 3 : vérification...${NC}"
    
    # verify config
    if ! sshd -t; then
        handle_error "configuration ssh invalide" "vérification"
    fi
    
    # verify service
    if ! systemctl is-active --quiet sshd; then
        handle_error "service ssh non actif" "vérification"
    fi
    
    # verify port
    if ! netstat -tuln | grep -q ":22222"; then
        handle_error "port ssh non ouvert" "vérification"
    fi
    
    log_action "info : étape 3 terminée"

    echo -e "${GREEN}🎉 module $MODULE_NAME installé avec succès${NC}"
    log_action "succès : installation du module $MODULE_NAME terminée"
}

# 🎯 run main function
main 