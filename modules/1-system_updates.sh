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
MODULE_NAME="system_updates"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="système de mise à jour automatique pour debian"
MODULE_DEPENDENCIES=("apt" "apt-get")

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
    # remove temporary files
    rm -f /tmp/apt-update-*
    # restore original sources if needed
    if [ -f /etc/apt/sources.list.bak ]; then
        mv /etc/apt/sources.list.bak /etc/apt/sources.list
    fi
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

# 🎯 main function
main() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════
║ 🚀 installation du module $MODULE_NAME...                    
╚════════════════════════════════════════════════════════════${NC}"

    # check dependencies
    check_dependencies

    # step 1: backup and prepare
    update_progress 1 4
    echo -e "${BLUE}📦 étape 1 : préparation...${NC}"
    # backup sources list
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    # create temporary files
    touch /tmp/apt-update-$(date +%Y%m%d_%H%M%S)
    log_action "info : étape 1 terminée"

    # step 2: update package lists
    update_progress 2 4
    echo -e "${BLUE}📦 étape 2 : mise à jour des listes de paquets...${NC}"
    apt update || handle_error "échec de la mise à jour des listes de paquets" "mise à jour des listes"
    log_action "info : étape 2 terminée"

    # step 3: upgrade packages
    update_progress 3 4
    echo -e "${BLUE}📦 étape 3 : mise à jour des paquets...${NC}"
    apt upgrade -y || handle_error "échec de la mise à jour des paquets" "mise à jour des paquets"
    log_action "info : étape 3 terminée"

    # step 4: cleanup
    update_progress 4 4
    echo -e "${BLUE}🧹 étape 4 : nettoyage...${NC}"
    apt autoremove -y || handle_error "échec du nettoyage" "nettoyage"
    apt clean || handle_error "échec du nettoyage du cache" "nettoyage du cache"
    log_action "info : étape 4 terminée"

    echo -e "${GREEN}🎉 module $MODULE_NAME installé avec succès${NC}"
    log_action "succès : installation du module $MODULE_NAME terminée"
}

# 🎯 run main function
main 