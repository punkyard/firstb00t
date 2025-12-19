#!/bin/bash

# 🔶🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸🔸
# 🔶  🔒 CONFIGURATION SSH

echo "🔒 début de la configuration ssh..."

    echo "📄 sauvegarde de la configuration ssh actuelle..."
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    log_action "info : sauvegarde de la configuration ssh"

    echo "⚙️ configuration des paramètres de sécurité..."
    cat > /etc/ssh/sshd_config <<EOF
# configuration générée par firstb00t
# ne pas modifier manuellement

# paramètres de base
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# authentification
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# sécurité
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# limites
MaxAuthTries 3
MaxSessions 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

    echo "🔄 redémarrage du service ssh..."
    systemctl restart ssh
    if [ $? -eq 0 ]; then
        echo "🟢 service ssh redémarré avec succès"
        log_action "succès : redémarrage du service ssh"
    else
        echo "🔴 erreur lors du redémarrage du service ssh"
        handle_error "échec du redémarrage ssh" "configuration ssh"
    fi

    echo "🔍 vérification de la configuration ssh..."
    sshd -t
    if [ $? -eq 0 ]; then
        echo "🟢 configuration ssh valide"
        log_action "succès : vérification de la configuration ssh"
    else
        echo "🔴 erreur dans la configuration ssh"
        handle_error "configuration ssh invalide" "vérification ssh"
    fi

echo "🟢 configuration ssh terminée"
log_action "succès : configuration ssh terminée" 