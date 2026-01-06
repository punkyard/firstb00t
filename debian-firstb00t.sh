#!/bin/bash

cat <<EOF
 ████                                               █████
░░███                                             ███░░░███
 ░███   ██████     ████████   ██████   █████████ ███   ░░███
 ░███  ███░░███   ░░███░░███ ███░░███ ░█░░░░███ ░███    ░███
 ░███ ░███████     ░███ ░░░ ░███████  ░   ███░  ░███    ░███
 ░███ ░███░░░      ░███     ░███░░░     ███░   █░░███   ███
 █████░░██████  ██ █████    ░░██████   █████████ ░░░█████░
░░░░░  ░░░░░░  ░░ ░░░░░      ░░░░░░   ░░░░░░░░░    ░░░░░░

🚀 script de premier démarrage pour serveur web Debian

Ce script effectue les tâches habituelles lors du premier démarrage
d'un serveur Linux Debian (version 9, 10, 11, 12, 13) fraîchement installé
(sur VPS, home-server, machine virtuelle ou tout autre environnement)
et met en place des services améliorant sa sécurité.

Ce script installe exclusivement des logiciels open-source
reconnus par la communauté Linux Debian depuis leurs dépôts officiels
et recommande la création de mots de passe forts.

Le serveur DNS du registrar devra déjà être configuré pour pointer vers l`IP du serveur,
ainsi que les entrées SPF, DKIM et DMARC

Temps estimé : 30 minutes
EOF

# 🔶🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸
# 🔶  📦 INSTALLATION DES MODULES

echo "📦 début de l'installation des modules..."

    # charger les variables d'environnement
    if [ -f "modules/sample.env" ]; then
        echo "📄 chargement des variables d'environnement..."
        source "modules/sample.env"
    else
        echo "🔴 fichier sample.env non trouvé"
        handle_error "fichier sample.env manquant" "chargement des variables"
    fi

    # installer le module de sélection de profil
    echo "� installation du module de sélection de profil..."
    source "modules/01-profile_selection.sh"
    # Load SSH port configuration if available
    if [ -f /etc/firstboot/ssh_port ]; then
        export SSH_PORT=$(cat /etc/firstboot/ssh_port)
        log_action "info : SSH port loaded: ${SSH_PORT}"
    fi
    # installer les modules activés dans l'ordre
    for module in modules/*.sh; do
        if [ -f "$module" ]; then
            module_name=$(basename "$module" .sh)
            if [ -f "/etc/firstboot/modules/${module_name}.enabled" ]; then
                echo "📦 installation du module : $module"
                source "$module"
            else
                echo "⏭️ module $module_name non activé pour ce profil"
            fi
        fi
    done

echo "🟢 installation des modules terminée"
log_action "succès : installation des modules terminée"

# 🔶🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸
# 🔶  ✅ FINALISATION

echo "✅ finalisation de l'installation..."

    echo "🧹 nettoyage des fichiers temporaires..."
    rm -f /tmp/script_temp_*

    echo "📋 génération du rapport final..."
    echo "   - profil sélectionné : $(cat /etc/firstboot/profile)"
    echo "   - modules installés : $(ls /etc/firstboot/modules/*.enabled | wc -l)"
    echo "   - services configurés : $(systemctl list-units --type=service --state=active | wc -l)"
    echo "   - utilisateurs créés : $(grep -c "^[^:]*:[^:]*:[0-9]\{4\}" /etc/passwd)"

    echo "🟢 installation terminée avec succès"
    log_action "succès : installation terminée"

exit 0
