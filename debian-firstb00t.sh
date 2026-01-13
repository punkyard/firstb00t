#!/bin/bash

# Strict mode for safer execution
set -Eeuo pipefail

# Ensure UTF-8 locale to avoid garbled characters on minimal VPS images
export LC_ALL=C.UTF-8 || true
export LANG=C.UTF-8 || true

# Parse command-line arguments
SELECTED_PROFILE=""
NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            SELECTED_PROFILE="$2"
            shift 2
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        *)
            echo "Usage: $0 [--profile basic|standard|advanced] [--non-interactive]"
            exit 1
            ;;
    esac
done

# Export for modules to use
export SELECTED_PROFILE
export NON_INTERACTIVE

# Load common logging utilities if available; provide lightweight shims otherwise
if [ -f "common/logging.sh" ]; then
    # shellcheck disable=SC1091
    source "common/logging.sh"
fi

# Provide fallback shims if not already defined
if ! declare -f log_action >/dev/null 2>&1; then
    log_action() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
fi
if ! declare -f handle_error >/dev/null 2>&1; then
    handle_error() { echo "🔴 erreur: ${2:-step} : ${1:-message}" >&2; }
fi
if ! declare -f update_progress >/dev/null 2>&1; then
    update_progress() { echo "📊 progression : ${1:-0}/${2:-0}"; }
fi

# Parse command line arguments
PROFILE="basic"
NON_INTERACTIVE="true"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

while [[ $# -gt 0 ]]; do
    case "${1}" in
        --profile)
            PROFILE="${2}"
            shift 2
            ;;
        --non-interactive)
            NON_INTERACTIVE="true"
            shift
            ;;
        --interactive)
            NON_INTERACTIVE="false"
            shift
            ;;
        -h|--help)
            echo -e "${BLUE}Usage: $0 [--profile <basic|standard|advanced>] [--non-interactive|--interactive]${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: ${1}${NC}"
            exit 1
            ;;
    esac
done

# Export for modules to use
export FIRSTBOOT_PROFILE="${PROFILE}"
export FIRSTBOOT_NON_INTERACTIVE="${NON_INTERACTIVE}"

cat <<EOF
${CYAN}

  .d888 d8b                  888    888       .d8888b.   .d8888b.  888    
d88P"  Y8P                  888    888      d88P  Y88b d88P  Y88b 888    
888                         888    888      888    888 888    888 888    
888888 888 888d888 .d8888b  888888 88888b.  888    888 888    888 888888 
888    888 888P"   88K      888    888 "88b 888    888 888    888 888    
888    888 888     "Y8888b. 888    888  888 888    888 888    888 888    
888    888 888          X88 Y88b.  888 d88P Y88b  d88P Y88b  d88P Y88b.  
888    888 888      88888P'  "Y888 88888P"   "Y8888P"   "Y8888P"   "Y888

${NC}

${GREEN}🚀 Debian First-Boot Automation Script

This script performs standard initialization tasks when first booting
a freshly installed Linux Debian server (version 9, 10, 11, 12, 13)
(on VPS, home-server, virtual machine, or any other environment)
and sets up services to enhance server security.

${YELLOW}⚠️  Prerequisites:
${CYAN}• Registrar DNS already configured to point to this server IP
• SPF, DKIM, and DMARC entries already configured${NC}

${BLUE}📋 This script installs only open-source software
recognized by the Debian Linux community from official repositories
and recommends the creation of strong passwords.${NC}

${GREEN}⏱️  Estimated time: 30 minutes${NC}
EOF

# 🔶🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸
# 🔶  📦 MODULE INSTALLATION

echo -e "${BLUE}📦 Starting module installation...${NC}"

    # Detect module location (modules/ subdir or flat)
    MODULES_DIR="modules"
    [ ! -d "modules" ] && [ -f "01-profile_selection.sh" ] && MODULES_DIR="."

    # charger les variables d'environnement (facultatif)
    SAMPLE_ENV=""
    [ -f "${MODULES_DIR}/sample.env" ] && SAMPLE_ENV="${MODULES_DIR}/sample.env"
    if [ -n "$SAMPLE_ENV" ]; then
        echo "📄 chargement des variables d'environnement..."
        # shellcheck disable=SC1091
        source "$SAMPLE_ENV"
    else
        echo "🟡 variables d'environnement facultatives non trouvées (sample.env) — poursuite avec les valeurs par défaut"
        log_action "info : sample.env absent, valeurs par défaut utilisées"
    fi

    # installer le module de sélection de profil
    echo "🚀 installation du module de sélection de profil..."
    source "${MODULES_DIR}/01-profile_selection.sh"
    # Load SSH port configuration if available
    if [ -f /etc/firstboot/ssh_port ]; then
        export SSH_PORT=$(cat /etc/firstboot/ssh_port)
        log_action "info : SSH port loaded: ${SSH_PORT}"
    fi
    # installer les modules activés dans l'ordre
    for module in ${MODULES_DIR}/[0-9][0-9]-*.sh; do
        [ -f "$module" ] || continue
        module_name=$(basename "$module" .sh)
        if [ -f "/etc/firstboot/modules/${module_name}.enabled" ]; then
            echo "📦 installation du module : $module_name"
            source "$module"
        else
            echo "⏭️ module $module_name non activé pour ce profil"
        fi
    done

echo -e "${GREEN}✅ Module installation completed${NC}"
log_action "success: module installation completed"

# 🔶🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸
# 🔶  🎯 FINALIZATION

echo -e "${BLUE}✅ Finalizing installation...${NC}"

    echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
    rm -f /tmp/script_temp_*

    echo -e "${CYAN}📋 Generating final report...${NC}"
    echo -e "   ${BLUE}• Selected profile: $(cat /etc/firstboot/profile)${NC}"
    echo -e "   ${BLUE}• Modules installed: $(ls /etc/firstboot/modules/*.enabled | wc -l)${NC}"
    echo -e "   ${BLUE}• Active services: $(systemctl list-units --type=service --state=active | wc -l)${NC}"
    echo -e "   ${BLUE}• Users created: $(grep -c "^[^:]*:[^:]*:[0-9]\{4\}" /etc/passwd)${NC}"

    echo "🟢 installation terminée avec succès"
    log_action "succès : installation terminée"

exit 0
