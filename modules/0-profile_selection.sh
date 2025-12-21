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
    if [ -f /etc/firstboot/profile.bak ]; then
        mv /etc/firstboot/profile.bak /etc/firstboot/profile
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
    echo -e "${GREEN}🟢 toutes les dépendances sont satisfaites${NC}"
    log_action "info : vérification des dépendances réussie"
}

# 📊 progress tracking
update_progress() {
    current_step="$1"
    total_steps="$2"
    echo -e "${BLUE}📊 progression : $current_step/$total_steps${NC}"
}

# 🔍 assess system
assess_system() {
    echo -e "${BLUE}🔍 évaluation du système...${NC}"
    
    # check system requirements
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    total_disk=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
    cpu_cores=$(nproc)
    
    # log system info
    log_action "info : mémoire totale : ${total_mem}MB"
    log_action "info : espace disque : ${total_disk}GB"
    log_action "info : cœurs cpu : ${cpu_cores}"
    
    # verify minimum requirements
    if [ "$total_mem" -lt 1024 ]; then
        handle_error "mémoire insuffisante (minimum 1GB requis)" "évaluation du système"
    fi
    if [ "$total_disk" -lt 10 ]; then
        handle_error "espace disque insuffisant (minimum 10GB requis)" "évaluation du système"
    fi
    
    log_action "info : évaluation du système terminée"
}

# ⚙️ Configure SSH port
configure_ssh_port() {
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
    echo "$ssh_port" > /etc/firstboot/ssh_port
    echo "✅ SSH port configured: ${ssh_port}"
    log_action "info : SSH port configured to ${ssh_port}"
}

# ⚙️ Select profile
select_profile() {
    echo -e "${BLUE}⚙️ sélection du profil...${NC}"
    
    # display available profiles
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════
║ 📋 profils disponibles :                                   
║                                                            
║ 🟢 basic    - sécurité essentielle                         
║ 🟡 standard - sécurité équilibrée                         
║ 🔴 advanced  - sécurité maximale                           
╚════════════════════════════════════════════════════════════${NC}"
    
    # prompt for profile selection
    read -p "choisir un profil (basic/standard/advanced) : " selected_profile
    
    # validate selection
    case "$selected_profile" in
        "basic"|"standard"|"advanced")
            echo -e "${GREEN}✅ profil $selected_profile sélectionné${NC}"
            log_action "info : profil $selected_profile sélectionné"
            ;;
        *)
            handle_error "profil invalide" "sélection du profil"
            ;;
    esac
    
    # save profile selection
    mkdir -p /etc/firstboot
    echo "$selected_profile" > /etc/firstboot/profile
    
    log_action "info : sélection du profil terminée"
}

# ⚙️ configure profile
configure_profile() {
    echo -e "${BLUE}⚙️ configuration du profil...${NC}"
    
    # read selected profile
    selected_profile=$(cat /etc/firstboot/profile)
    
    # 🔶 ensure modules directory exists
    mkdir -p /etc/firstboot/modules
    
    # configure based on profile
    case "$selected_profile" in
        "basic")
            # basic profile configuration
            echo -e "${BLUE}📦 configuration du profil basic...${NC}"
            # enable basic modules
            touch /etc/firstboot/modules/1-system_updates.enabled
            touch /etc/firstboot/modules/2-user_management.enabled
            touch /etc/firstboot/modules/3-ssh_config.enabled
            touch /etc/firstboot/modules/4-ssh_hardening.enabled
            touch /etc/firstboot/modules/5-firewall_config.enabled
            touch /etc/firstboot/modules/10-monitoring.enabled
            ;;
        "standard")
            # standard profile configuration
            echo -e "${BLUE}📦 configuration du profil standard...${NC}"
            # enable standard modules
            touch /etc/firstboot/modules/1-system_updates.enabled
            touch /etc/firstboot/modules/2-user_management.enabled
            touch /etc/firstboot/modules/3-ssh_config.enabled
            touch /etc/firstboot/modules/4-ssh_hardening.enabled
            touch /etc/firstboot/modules/5-firewall_config.enabled
            touch /etc/firstboot/modules/6-fail2ban.enabled
            touch /etc/firstboot/modules/7-ssl_config.enabled
            touch /etc/firstboot/modules/8-dns_config.enabled
            touch /etc/firstboot/modules/9-mail_config.enabled
            ;;
        "advanced")
            # advanced profile configuration
            echo -e "${BLUE}📦 configuration du profil advanced...${NC}"
            # enable all modules
            touch /etc/firstboot/modules/1-system_updates.enabled
            touch /etc/firstboot/modules/2-user_management.enabled
            touch /etc/firstboot/modules/3-ssh_config.enabled
            touch /etc/firstboot/modules/4-ssh_hardening.enabled
            touch /etc/firstboot/modules/5-firewall_config.enabled
            touch /etc/firstboot/modules/6-fail2ban.enabled
            touch /etc/firstboot/modules/7-ssl_config.enabled
            touch /etc/firstboot/modules/8-dns_config.enabled
            touch /etc/firstboot/modules/9-mail_config.enabled
            touch /etc/firstboot/modules/10-monitoring.enabled
            ;;
    esac
    
    log_action "info : configuration du profil terminée"
}

# ✅ validate profile
validate_profile() {
    echo -e "${BLUE}✅ validation du profil...${NC}"
    
    # check if profile file exists
    if [ ! -f /etc/firstboot/profile ]; then
        handle_error "fichier de profil non trouvé" "validation du profil"
    fi
    
    # check if modules directory exists
    if [ ! -d /etc/firstboot/modules ]; then
        handle_error "répertoire des modules non trouvé" "validation du profil"
    fi
    
    # check if at least one module is enabled
    if ! ls /etc/firstboot/modules/*.enabled > /dev/null 2>&1; then
        handle_error "aucun module activé" "validation du profil"
    fi
    
    log_action "info : validation du profil terminée"
}

# 🎯 main function
main() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════
║ 🚀 installation du module $MODULE_NAME...                    
╚════════════════════════════════════════════════════════════${NC}"

    # check dependencies
    check_dependencies

    # step 1: assess system
    update_progress 1 4
    echo -e "${BLUE}📦 étape 1 : évaluation du système...${NC}"
    assess_system
    log_action "info : étape 1 terminée"

    # step 2: select profile
    update_progress 2 5
    echo -e "${BLUE}📦 étape 2 : sélection du profil...${NC}"
    select_profile
    log_action "info : étape 2 terminée"
    
    # step 3: configure SSH port
    update_progress 3 5
    echo -e "${BLUE}📦 étape 3 : configuration du port SSH...${NC}"
    configure_ssh_port
    log_action "info : étape 3 terminée"

    # step 4: configure profile
    update_progress 4 5
    echo -e "${BLUE}📦 étape 4 : configuration du profil...${NC}"
    configure_profile
    log_action "info : étape 4 terminée"

    # step 5: validate
    update_progress 5 5
    echo -e "${BLUE}📦 étape 5 : validation du profil...${NC}"
    validate_profile
    log_action "info : étape 5 terminée"

    echo -e "${GREEN}🎉 module $MODULE_NAME installé avec succès${NC}"
    log_action "succès : installation du module $MODULE_NAME terminée"
}

# 🎯 run main function
main 