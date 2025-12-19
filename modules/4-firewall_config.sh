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
MODULE_NAME="firewall_config"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="configuration du pare-feu avec ufw"
MODULE_DEPENDENCIES=("ufw" "systemctl")

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
    if [ -f /etc/ufw/before.rules.bak ]; then
        mv /etc/ufw/before.rules.bak /etc/ufw/before.rules
        log_action "info : configuration ufw restaurée"
    fi
    # leave ufw running; only restore config
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

# 🔒 configure firewall
configure_firewall() {
    echo -e "${BLUE}🔒 configuration du pare-feu...${NC}"
    
    # backup original config
    cp /etc/ufw/before.rules /etc/ufw/before.rules.bak || handle_error "échec de la sauvegarde de la configuration" "sauvegarde de la configuration"
    
    # reset ufw to default
    ufw --force reset || handle_error "échec de la réinitialisation du pare-feu" "réinitialisation"
    
    # set default policies
    ufw default deny incoming || handle_error "échec de la définition de la politique par défaut" "définition des politiques"
    ufw default allow outgoing || handle_error "échec de la définition de la politique par défaut" "définition des politiques"
    
    # allow ssh
    ufw allow 22222/tcp || handle_error "échec de l'ouverture du port ssh" "configuration des règles"
    
    # allow http/https
    ufw allow 80/tcp || handle_error "échec de l'ouverture du port http" "configuration des règles"
    ufw allow 443/tcp || handle_error "échec de l'ouverture du port https" "configuration des règles"
    
    # allow dns
    ufw allow 53/tcp || handle_error "échec de l'ouverture du port dns tcp" "configuration des règles"
    ufw allow 53/udp || handle_error "échec de l'ouverture du port dns udp" "configuration des règles"
    
    # allow smtp
    ufw allow 25/tcp || handle_error "échec de l'ouverture du port smtp" "configuration des règles"
    
    # allow imap/pop3
    ufw allow 143/tcp || handle_error "échec de l'ouverture du port imap" "configuration des règles"
    ufw allow 110/tcp || handle_error "échec de l'ouverture du port pop3" "configuration des règles"
    
    # allow submission
    ufw allow 587/tcp || handle_error "échec de l'ouverture du port submission" "configuration des règles"
    
    # enable logging
    ufw logging on || handle_error "échec de l'activation des logs" "configuration des logs"
    
    log_action "info : configuration du pare-feu effectuée"
}

# 🔄 restart service
restart_service() {
    echo -e "${BLUE}🔄 redémarrage du service ufw...${NC}"
    
    # enable ufw
    ufw --force enable || handle_error "échec de l'activation du pare-feu" "activation du pare-feu"
    
    # verify service status
    if ! systemctl is-active --quiet ufw; then
        handle_error "service ufw non actif" "vérification du service"
    fi
    
    log_action "info : service ufw redémarré"
}

# 🎯 main function
main() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════
║ 🚀 installation du module $MODULE_NAME...                    
╚════════════════════════════════════════════════════════════${NC}"

    # check dependencies
    check_dependencies

    # step 1: configure firewall
    update_progress 1 3
    echo -e "${BLUE}📦 étape 1 : configuration...${NC}"
    configure_firewall
    log_action "info : étape 1 terminée"

    # step 2: restart service
    update_progress 2 3
    echo -e "${BLUE}📦 étape 2 : redémarrage du service...${NC}"
    restart_service
    log_action "info : étape 2 terminée"

    # step 3: verify
    update_progress 3 3
    echo -e "${BLUE}📦 étape 3 : vérification...${NC}"
    
    # verify service
    if ! systemctl is-active --quiet ufw; then
        handle_error "service ufw non actif" "vérification"
    fi
    
    # verify rules
    if ! ufw status | grep -q "Status: active"; then
        handle_error "pare-feu non actif" "vérification"
    fi
    
    log_action "info : étape 3 terminée"

    echo -e "${GREEN}🎉 module $MODULE_NAME installé avec succès${NC}"
    log_action "succès : installation du module $MODULE_NAME terminée"
}

# 🎯 run main function
main 