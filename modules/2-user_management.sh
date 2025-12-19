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
MODULE_NAME="user_management"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="gestion des utilisateurs et des privilèges sudo"
MODULE_DEPENDENCIES=("useradd" "usermod" "passwd" "groupadd")

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
    rm -f /tmp/user-*
    # remove user if creation failed
    if [ -n "$user_sudo" ] && [ "$user_created" = "true" ]; then
        userdel -r "$user_sudo" 2>/dev/null
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

# 🔒 password validation
validate_password() {
    local password="$1"
    # check length
    if [ ${#password} -lt 12 ]; then
        return 1
    fi
    # check complexity
    if ! [[ "$password" =~ [A-Z] ]] || ! [[ "$password" =~ [a-z] ]] || ! [[ "$password" =~ [0-9] ]] || ! [[ "$password" =~ [^A-Za-z0-9] ]]; then
        return 1
    fi
    return 0
}

# 👤 create sudo user
create_sudo_user() {
    local username="$1"
    local password="$2"
    
    echo -e "${BLUE}👤 création de l'utilisateur sudo : $username${NC}"
    
    # create user
    useradd -m -s /bin/bash "$username" || handle_error "échec de la création de l'utilisateur" "création de l'utilisateur"
    user_created="true"
    
    # set password
    echo "$username:$password" | chpasswd || handle_error "échec de la définition du mot de passe" "définition du mot de passe"
    
    # add to sudo group
    usermod -aG sudo "$username" || handle_error "échec de l'ajout au groupe sudo" "ajout au groupe sudo"
    
    # create .ssh directory
    mkdir -p "/home/$username/.ssh" || handle_error "échec de la création du répertoire .ssh" "création du répertoire .ssh"
    chmod 700 "/home/$username/.ssh" || handle_error "échec de la définition des permissions .ssh" "définition des permissions .ssh"
    
    # set ownership
    chown -R "$username:$username" "/home/$username" || handle_error "échec de la définition des propriétaires" "définition des propriétaires"
    
    log_action "info : utilisateur sudo créé avec succès"
}

# 🎯 main function
main() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════
║ 🚀 installation du module $MODULE_NAME...                    
╚════════════════════════════════════════════════════════════${NC}"

    # check dependencies
    check_dependencies

    # step 1: get user information
    update_progress 1 3
    echo -e "${BLUE}📦 étape 1 : configuration de l'utilisateur...${NC}"
    
    # read username
    read -p "nom d'utilisateur sudo : " user_sudo
    if [ -z "$user_sudo" ]; then
        handle_error "nom d'utilisateur vide" "configuration de l'utilisateur"
    fi
    
    # read password
    read -sp "mot de passe : " user_password
    echo
    if ! validate_password "$user_password"; then
        handle_error "mot de passe trop faible" "configuration de l'utilisateur"
    fi
    
    log_action "info : étape 1 terminée"

    # step 2: create user
    update_progress 2 3
    echo -e "${BLUE}📦 étape 2 : création de l'utilisateur...${NC}"
    create_sudo_user "$user_sudo" "$user_password"
    log_action "info : étape 2 terminée"

    # step 3: verify
    update_progress 3 3
    echo -e "${BLUE}📦 étape 3 : vérification...${NC}"
    
    # verify user exists
    if ! id "$user_sudo" &>/dev/null; then
        handle_error "utilisateur non trouvé" "vérification"
    fi
    
    # verify sudo group
    if ! groups "$user_sudo" | grep -q sudo; then
        handle_error "utilisateur non dans le groupe sudo" "vérification"
    fi
    
    # verify .ssh directory
    if [ ! -d "/home/$user_sudo/.ssh" ]; then
        handle_error "répertoire .ssh non trouvé" "vérification"
    fi
    
    log_action "info : étape 3 terminée"

    echo -e "${GREEN}🎉 module $MODULE_NAME installé avec succès${NC}"
    log_action "succès : installation du module $MODULE_NAME terminée"
}

# 🎯 run main function
main 