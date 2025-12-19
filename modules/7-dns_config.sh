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
MODULE_NAME="dns_config"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="configuration du serveur dns"
MODULE_DEPENDENCIES=("bind9" "systemctl" "named-checkconf")

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
    if [ -f /etc/bind/named.conf.bak ]; then
        mv /etc/bind/named.conf.bak /etc/bind/named.conf
        log_action "info : configuration bind9 restaurée"
    fi
    # leave bind9 running; only restore config
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

# 📦 install bind9
install_bind9() {
    echo -e "${BLUE}📦 installation de bind9...${NC}"
    
    # check if already installed
    if dpkg -s bind9 >/dev/null 2>&1; then
        log_action "info : bind9 déjà installé"
        echo -e "${GREEN}✅ bind9 déjà installé${NC}"
        return 0
    fi
    
    # update package list
    apt update || handle_error "échec de la mise à jour des paquets" "mise à jour des paquets"
    
    # install bind9
    apt install -y bind9 bind9utils bind9-doc || handle_error "échec de l'installation de bind9" "installation"
    
    log_action "info : bind9 installé"
}

# 🔒 configure bind9
configure_bind9() {
    echo -e "${BLUE}🔒 configuration de bind9...${NC}"
    
    # backup original config
    cp /etc/bind/named.conf /etc/bind/named.conf.bak || handle_error "échec de la sauvegarde de la configuration" "sauvegarde de la configuration"
    
    # configure named.conf
    cat > /etc/bind/named.conf << EOF
options {
    directory "/var/cache/bind";
    recursion no;
    allow-query { localhost; };
    allow-transfer { none; };
    allow-update { none; };
    allow-notify { none; };
    listen-on { 127.0.0.1; };
    listen-on-v6 { ::1; };
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    forward only;
    dnssec-validation auto;
    auth-nxdomain no;
    version "not available";
};

zone "." {
    type hint;
    file "/etc/bind/db.root";
};

zone "localhost" {
    type master;
    file "/etc/bind/db.local";
};

zone "127.in-addr.arpa" {
    type master;
    file "/etc/bind/db.127";
};

zone "0.in-addr.arpa" {
    type master;
    file "/etc/bind/db.0";
};

zone "255.in-addr.arpa" {
    type master;
    file "/etc/bind/db.255";
};

include "/etc/bind/named.conf.local";
EOF
    
    # set permissions
    chmod 644 /etc/bind/named.conf || handle_error "échec de la définition des permissions" "définition des permissions"
    
    log_action "info : configuration de bind9 effectuée"
}

# 🔄 restart service
restart_service() {
    echo -e "${BLUE}🔄 redémarrage du service bind9...${NC}"
    
    # check config
    named-checkconf /etc/bind/named.conf || handle_error "configuration bind9 invalide" "vérification de la configuration"
    
    # restart service
    systemctl restart bind9 || handle_error "échec du redémarrage du service" "redémarrage du service"
    
    # verify service status
    if ! systemctl is-active --quiet bind9; then
        handle_error "service bind9 non actif" "vérification du service"
    fi
    
    log_action "info : service bind9 redémarré"
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

    # step 1: install bind9
    update_progress 1 4
    echo -e "${BLUE}📦 étape 1 : installation...${NC}"
    install_bind9
    log_action "info : étape 1 terminée"

    # step 2: configure bind9
    update_progress 2 4
    echo -e "${BLUE}📦 étape 2 : configuration...${NC}"
    configure_bind9
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
    if ! systemctl is-active --quiet bind9; then
        handle_error "service bind9 non actif" "vérification"
    fi
    
    # verify dns resolution
    if ! dig @127.0.0.1 localhost > /dev/null; then
        handle_error "résolution dns locale échouée" "vérification"
    fi
    
    log_action "info : étape 4 terminée"

    echo -e "${GREEN}🎉 module $MODULE_NAME installé avec succès${NC}"
    log_action "succès : installation du module $MODULE_NAME terminée"
}

# 🎯 run main function
main 