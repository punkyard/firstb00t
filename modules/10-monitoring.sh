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
MODULE_NAME="monitoring"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="system monitoring configuration"
MODULE_DEPENDENCIES=("prometheus" "node_exporter" "systemctl" "curl")

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
    log_action "erreur : interruption à l'étape $error_step : $error_message"
    cleanup
    exit 1
}

# 🧹 cleanup function
cleanup() {
    echo -e "${YELLOW}🧹 nettoyage en cours...${NC}"
    # restore original config if needed
    if [ -f /etc/prometheus/prometheus.yml.bak ]; then
        mv /etc/prometheus/prometheus.yml.bak /etc/prometheus/prometheus.yml
        log_action "info : configuration prometheus restaurée"
    fi
    # leave services running; only restore config
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

# 📦 install monitoring tools
install_monitoring() {
    echo -e "${BLUE}📦 installation des outils de monitoring...${NC}"
    
    # check if already installed
    if dpkg -s prometheus >/dev/null 2>&1 && dpkg -s prometheus-node-exporter >/dev/null 2>&1; then
        log_action "info : outils de monitoring déjà installés"
        echo -e "${GREEN}✅ outils de monitoring déjà installés${NC}"
        return 0
    fi
    
    # update package list
    apt update || handle_error "échec de la mise à jour des paquets" "mise à jour des paquets"
    
    # install prometheus and node_exporter
    apt install -y prometheus prometheus-node-exporter || handle_error "échec de l'installation des paquets" "installation"
    
    log_action "info : outils de monitoring installés"
}

# 🔒 configure prometheus
configure_prometheus() {
    echo -e "${BLUE}🔒 configuration de prometheus...${NC}"
    
    # backup original config
    cp /etc/prometheus/prometheus.yml /etc/prometheus/prometheus.yml.bak || handle_error "échec de la sauvegarde de la configuration" "sauvegarde de la configuration"
    
    # configure prometheus.yml
    cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node"
    static_configs:
      - targets: ["localhost:9100"]

  - job_name: "apache"
    static_configs:
      - targets: ["localhost:9117"]

  - job_name: "mysql"
    static_configs:
      - targets: ["localhost:9104"]

  - job_name: "postfix"
    static_configs:
      - targets: ["localhost:9154"]

  - job_name: "dovecot"
    static_configs:
      - targets: ["localhost:9162"]
EOF
    
    # set permissions
    chmod 644 /etc/prometheus/prometheus.yml || handle_error "échec de la définition des permissions" "définition des permissions"
    
    log_action "info : configuration de prometheus effectuée"
}

# 🔄 restart services
restart_services() {
    echo -e "${BLUE}🔄 redémarrage des services...${NC}"
    
    # restart prometheus
    systemctl restart prometheus || handle_error "échec du redémarrage de prometheus" "redémarrage de prometheus"
    
    # restart node_exporter
    systemctl restart node_exporter || handle_error "échec du redémarrage de node_exporter" "redémarrage de node_exporter"
    
    # verify services
    if ! systemctl is-active --quiet prometheus; then
        handle_error "service prometheus non actif" "vérification des services"
    fi
    if ! systemctl is-active --quiet node_exporter; then
        handle_error "service node_exporter non actif" "vérification des services"
    fi
    
    log_action "info : services redémarrés"
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

    # step 1: install monitoring tools
    update_progress 1 4
    echo -e "${BLUE}📦 étape 1 : installation...${NC}"
    install_monitoring
    log_action "info : étape 1 terminée"

    # step 2: configure prometheus
    update_progress 2 4
    echo -e "${BLUE}📦 étape 2 : configuration...${NC}"
    configure_prometheus
    log_action "info : étape 2 terminée"

    # step 3: restart services
    update_progress 3 4
    echo -e "${BLUE}📦 étape 3 : redémarrage des services...${NC}"
    restart_services
    log_action "info : étape 3 terminée"

    # step 4: verify
    update_progress 4 4
    echo -e "${BLUE}📦 étape 4 : vérification...${NC}"
    
    # verify services
    if ! systemctl is-active --quiet prometheus; then
        handle_error "service prometheus non actif" "vérification"
    fi
    if ! systemctl is-active --quiet node_exporter; then
        handle_error "service node_exporter non actif" "vérification"
    fi
    
    # verify ports
    if ! netstat -tuln | grep -q ":9090"; then
        handle_error "port prometheus non ouvert" "vérification"
    fi
    if ! netstat -tuln | grep -q ":9100"; then
        handle_error "port node_exporter non ouvert" "vérification"
    fi
    
    # verify metrics
    if ! curl -s http://localhost:9090/-/healthy | grep -q "OK"; then
        handle_error "prometheus non accessible" "vérification"
    fi
    if ! curl -s http://localhost:9100/metrics | grep -q "node_"; then
        handle_error "node_exporter non accessible" "vérification"
    fi
    
    log_action "info : étape 4 terminée"

    echo -e "${GREEN}🎉 module $MODULE_NAME installé avec succès${NC}"
    log_action "succès : installation du module $MODULE_NAME terminée"
}

# 🎯 run main function
main 