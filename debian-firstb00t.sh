#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="firstb00t"
SCRIPT_VERSION="0.1.0"

LOG_FILE="/var/log/firstb00t.log"
TEMP_SUDOERS_FILE=""

ADMIN_USER=""
SSH_PORT="22"
FIREWALL_BACKEND="ufw"
FTP_ENABLED="no"
FTP_DIR="/srv/ftp"
FTP_USER=""
FTP_PASSIVE_RANGE="40000:40100"
CONTAINER_ENGINE="docker"
CONTAINER_ROOT="/srv/containers"

APT_PACKAGES=(
	curl wget git build-essential btop ufw fail2ban
	unattended-upgrades trash-cli rsync ca-certificates gnupg
)

_green="\033[0;32m"
_yellow="\033[1;33m"
_red="\033[0;31m"
_blue="\033[0;34m"
_nc="\033[0m"

log() {
	local level="$1"
	shift
	printf '%s [%s] %s\n' "$(date '+%F %T')" "$level" "$*" | tee -a "$LOG_FILE"
}

info() { log "INFO" "$*"; }
warn() { log "WARN" "$*"; }
error() { log "ERROR" "$*"; }

ok() {
	printf "%b[OK]%b %s\n" "$_green" "$_nc" "$*"
}

note() {
	printf "%b[NOTE]%b %s\n" "$_blue" "$_nc" "$*"
}

abort() {
	error "$*"
	printf "%b[FAIL]%b %s\n" "$_red" "$_nc" "$*"
	exit 1
}

cleanup() {
	if [[ -n "${TEMP_SUDOERS_FILE}" && -f "${TEMP_SUDOERS_FILE}" ]]; then
		rm -f "${TEMP_SUDOERS_FILE}" || true
	fi
}

trap cleanup EXIT

run_cmd() {
	local description="$1"
	shift
	info "$description"
	"$@"
}

run_as_admin() {
	local cmd="$1"
	run_cmd "Run as ${ADMIN_USER}: ${cmd}" runuser -l "$ADMIN_USER" -c "$cmd"
}

prompt_input() {
	local var_name="$1"
	local prompt="$2"
	local default_value="${3:-}"
	local answer

	if [[ -n "$default_value" ]]; then
		read -r -p "$prompt [$default_value]: " answer
		answer="${answer:-$default_value}"
	else
		read -r -p "$prompt: " answer
	fi

	printf -v "$var_name" '%s' "$answer"
}

prompt_yes_no() {
	local var_name="$1"
	local prompt="$2"
	local default_value="${3:-yes}"
	local answer
	local default_hint="Y/n"

	[[ "$default_value" == "no" ]] && default_hint="y/N"

	while true; do
		read -r -p "$prompt ($default_hint): " answer
		answer="${answer,,}"
		answer="${answer:-$default_value}"
		case "$answer" in
			y|yes)
				printf -v "$var_name" '%s' "yes"
				return
				;;
			n|no)
				printf -v "$var_name" '%s' "no"
				return
				;;
			*)
				warn "Answer yes or no."
				;;
		esac
	done
}

require_root() {
	[[ "${EUID}" -eq 0 ]] || abort "Run as root."
}

require_debian() {
	[[ -f /etc/os-release ]] || abort "/etc/os-release missing."
	# shellcheck disable=SC1091
	. /etc/os-release
	[[ "${ID:-}" == "debian" || "${ID_LIKE:-}" == *"debian"* ]] || abort "Debian required."
}

check_network() {
	note "Need network now for package install."
	if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
		ok "Network reachable."
	else
		abort "No network."
	fi
}

bootstrap_nala() {
	run_cmd "apt-get update" apt-get update
	run_cmd "Install bootstrap packages" apt-get install -y nala sudo
}

collect_identity() {
	note "Set hostname first. Reason: stable host identity in logs and SSH banners."
	prompt_input NEW_HOSTNAME "Hostname" "$(hostnamectl --static 2>/dev/null || hostname)"
	if [[ -n "$NEW_HOSTNAME" ]]; then
		run_cmd "Set hostname" hostnamectl set-hostname "$NEW_HOSTNAME"
	fi

	note "Choose timezone now. Reason: correct logs and scheduled jobs."
	printf '%s\n' "1) Europe/Paris" "2) Europe/London" "3) Europe/Berlin" "4) Europe/Amsterdam" "5) Europe/Madrid" "6) Europe/Rome" "7) Other"
	local tz_choice
	read -r -p "Timezone choice [1-7]: " tz_choice
	case "$tz_choice" in
		1) TIMEZONE="Europe/Paris" ;;
		2) TIMEZONE="Europe/London" ;;
		3) TIMEZONE="Europe/Berlin" ;;
		4) TIMEZONE="Europe/Amsterdam" ;;
		5) TIMEZONE="Europe/Madrid" ;;
		6) TIMEZONE="Europe/Rome" ;;
		7)
			note "All TZ list: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
			note "Local command: timedatectl list-timezones"
			prompt_input TIMEZONE "Enter timezone (example Europe/Paris)" "Europe/Paris"
			;;
		*) TIMEZONE="Europe/Paris" ;;
	esac
	run_cmd "Set timezone ${TIMEZONE}" timedatectl set-timezone "$TIMEZONE"
}

create_admin_user() {
	note "Need sudo admin user. Reason: no direct root ops for daily administration."
	prompt_input ADMIN_USER "Sudo admin username" "admin"
	[[ -n "$ADMIN_USER" ]] || abort "Username empty."

	if id "$ADMIN_USER" >/dev/null 2>&1; then
		ok "User ${ADMIN_USER} exists."
	else
		run_cmd "Create user ${ADMIN_USER}" useradd -m -s /bin/bash "$ADMIN_USER"
		run_cmd "Set password for ${ADMIN_USER}" passwd "$ADMIN_USER"
	fi

	run_cmd "Add ${ADMIN_USER} to sudo group" usermod -aG sudo "$ADMIN_USER"

	TEMP_SUDOERS_FILE="/etc/sudoers.d/zz-firstb00t-${ADMIN_USER}"
	printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$ADMIN_USER" > "$TEMP_SUDOERS_FILE"
	chmod 0440 "$TEMP_SUDOERS_FILE"
	ok "Temporary passwordless sudo enabled for script run (${TEMP_SUDOERS_FILE})."
}

prompt_ftp() {
	note "FTP question now. Reason: firewall and package paths depend on this choice."
	prompt_yes_no FTP_ENABLED "Keep/enable FTP service" "no"
	if [[ "$FTP_ENABLED" == "yes" ]]; then
		prompt_input FTP_DIR "FTP folder path" "/srv/ftp"
		prompt_input FTP_USER "FTP username" "ftpuser"
		read -r -s -p "FTP password: " FTP_PASSWORD
		printf '\n'
		[[ -n "$FTP_PASSWORD" ]] || abort "FTP password empty."
	fi
}

install_base_packages() {
	note "Install core packages with nala via sudo user. Reason: consistent package workflow after bootstrap."
	run_as_admin "sudo nala update"
	run_as_admin "sudo nala install -y ${APT_PACKAGES[*]}"
}

setup_ftp_if_needed() {
	[[ "$FTP_ENABLED" == "yes" ]] || return 0

	run_as_admin "sudo nala install -y vsftpd"
	run_cmd "Create FTP directory" mkdir -p "$FTP_DIR"

	if ! id "$FTP_USER" >/dev/null 2>&1; then
		run_cmd "Create FTP user" useradd -d "$FTP_DIR" -s /usr/sbin/nologin "$FTP_USER"
	fi

	echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd
	run_cmd "Set FTP directory ownership" chown -R "$FTP_USER:$FTP_USER" "$FTP_DIR"

	if ! grep -q "# firstb00t-vsftpd" /etc/vsftpd.conf; then
		cat >> /etc/vsftpd.conf <<EOF

# firstb00t-vsftpd
write_enable=YES
local_enable=YES
pasv_enable=YES
pasv_min_port=${FTP_PASSIVE_RANGE%:*}
pasv_max_port=${FTP_PASSIVE_RANGE#*:}
chroot_local_user=YES
allow_writeable_chroot=YES
EOF
	fi

	run_cmd "Enable and restart vsftpd" systemctl enable --now vsftpd
	ok "FTP configured at ${FTP_DIR}."
}

prompt_container_engine() {
	note "Choose container engine. Reason: install path and hardening differ."
	printf '%s\n' "1) Hardened Docker (default)" "2) Podman"
	local choice
	read -r -p "Container engine [1-2]: " choice
	case "$choice" in
		2) CONTAINER_ENGINE="podman" ;;
		*) CONTAINER_ENGINE="docker" ;;
	esac

	prompt_input CONTAINER_ROOT "Container root folder (for all volumes)" "/srv/containers"
	run_cmd "Create container root folder" mkdir -p "$CONTAINER_ROOT"
	run_cmd "Set secure permissions on ${CONTAINER_ROOT}" chmod 0750 "$CONTAINER_ROOT"
}

install_container_engine() {
	if [[ "$CONTAINER_ENGINE" == "podman" ]]; then
		run_as_admin "sudo nala install -y podman"
		ok "Podman installed."
		return
	fi

	note "Install Docker CE repo and engine."
	run_as_admin "sudo install -m 0755 -d /etc/apt/keyrings"
	run_as_admin "curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
	run_as_admin "sudo chmod a+r /etc/apt/keyrings/docker.gpg"
	run_as_admin "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \$(. /etc/os-release && echo \$VERSION_CODENAME) stable\" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null"
	run_as_admin "sudo nala update"
	run_as_admin "sudo nala install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
	run_cmd "Enable docker service" systemctl enable --now docker
	run_cmd "Add ${ADMIN_USER} to docker group" usermod -aG docker "$ADMIN_USER"
	ok "Docker CE installed and hardened baseline ready."
}

prompt_firewall_backend() {
	note "Firewall mandatory. Reason: server must ship locked down in one run."
	printf '%s\n' "1) UFW (default, simple)" "2) nftables (advanced, more powerful, more complex)"
	local fw_choice
	read -r -p "Firewall backend [1-2]: " fw_choice
	case "$fw_choice" in
		2) FIREWALL_BACKEND="nftables" ;;
		*) FIREWALL_BACKEND="ufw" ;;
	esac

	prompt_input SSH_PORT "SSH port" "22"
}

apply_firewall_ufw() {
	run_as_admin "sudo nala install -y ufw"
	run_cmd "Reset UFW rules" ufw --force reset
	run_cmd "UFW default deny incoming" ufw default deny incoming
	run_cmd "UFW default allow outgoing" ufw default allow outgoing
	run_cmd "Allow SSH port ${SSH_PORT}" ufw allow "${SSH_PORT}/tcp"

	if [[ "$FTP_ENABLED" == "yes" ]]; then
		run_cmd "Allow FTP control" ufw allow 21/tcp
		run_cmd "Allow FTP passive range" ufw allow "${FTP_PASSIVE_RANGE}/tcp"
	fi

	run_cmd "Enable UFW" ufw --force enable
	run_cmd "Enable UFW service" systemctl enable ufw
	ok "UFW firewall applied."
}

apply_firewall_nftables() {
	run_as_admin "sudo nala install -y nftables"

	cat > /etc/nftables.conf <<EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
	chain input {
		type filter hook input priority 0;
		policy drop;

		iif lo accept
		ct state established,related accept

		tcp dport ${SSH_PORT} accept
EOF

	if [[ "$FTP_ENABLED" == "yes" ]]; then
		cat >> /etc/nftables.conf <<EOF
		tcp dport 21 accept
		tcp dport ${FTP_PASSIVE_RANGE} accept
EOF
	fi

	cat >> /etc/nftables.conf <<'EOF'

		ip protocol icmp accept
		ip6 nexthdr icmpv6 accept
	}

	chain forward {
		type filter hook forward priority 0;
		policy drop;
	}

	chain output {
		type filter hook output priority 0;
		policy accept;
	}
}
EOF

	run_cmd "Load nftables rules" nft -f /etc/nftables.conf
	run_cmd "Enable nftables service" systemctl enable --now nftables
	ok "nftables firewall applied."
}

set_sshd_option() {
	local key="$1"
	local value="$2"
	local file="/etc/ssh/sshd_config"
	if grep -qE "^\s*${key}\b" "$file"; then
		sed -i "s|^\s*${key}.*|${key} ${value}|" "$file"
	else
		printf '%s %s\n' "$key" "$value" >> "$file"
	fi
}

configure_ssh_hardening() {
	note "SSH hardening now. Reason: reduce remote attack surface."
	local disable_root disable_password

	prompt_yes_no disable_root "Disable root SSH login" "yes"
	prompt_yes_no disable_password "Disable SSH password authentication" "yes"

	if [[ "$disable_root" == "yes" ]]; then
		set_sshd_option "PermitRootLogin" "no"
	fi

	if [[ "$disable_password" == "yes" ]]; then
		set_sshd_option "PasswordAuthentication" "no"
		set_sshd_option "ChallengeResponseAuthentication" "no"
	fi

	set_sshd_option "PubkeyAuthentication" "yes"
	set_sshd_option "AllowUsers" "$ADMIN_USER"
	set_sshd_option "Port" "$SSH_PORT"

	run_cmd "Validate sshd config" sshd -t
	note "Recovery note: if locked out, use VPS console to restore /etc/ssh/sshd_config and restart ssh."
	run_cmd "Reload SSH daemon" systemctl reload ssh || systemctl restart ssh
	ok "SSH hardening applied."
}

configure_system_services() {
	run_cmd "Enable time sync" timedatectl set-ntp true

	local enable_unattended enable_apparmor enable_rkhunter
	prompt_yes_no enable_unattended "Enable unattended security upgrades" "yes"
	if [[ "$enable_unattended" == "yes" ]]; then
		run_as_admin "sudo nala install -y unattended-upgrades"
		run_cmd "Enable unattended-upgrades" systemctl enable --now unattended-upgrades
	fi

	prompt_yes_no enable_apparmor "Enable AppArmor" "yes"
	if [[ "$enable_apparmor" == "yes" ]]; then
		run_as_admin "sudo nala install -y apparmor apparmor-utils"
		run_cmd "Enable AppArmor" systemctl enable --now apparmor
	fi

	prompt_yes_no enable_rkhunter "Install rkhunter" "yes"
	if [[ "$enable_rkhunter" == "yes" ]]; then
		run_as_admin "sudo nala install -y rkhunter"
	fi
}

final_ssh_key_setup() {
	note "Last step: SSH key setup. Reason: keep access safe after all hardening changes."
	local add_key
	prompt_yes_no add_key "Add SSH public key for ${ADMIN_USER} now" "yes"
	[[ "$add_key" == "yes" ]] || return 0

	local pubkey
	read -r -p "Paste public key (ssh-ed25519/ssh-rsa ...): " pubkey
	[[ "$pubkey" == ssh-* ]] || abort "Invalid public key format."

	local ssh_dir="/home/${ADMIN_USER}/.ssh"
	local auth_keys="${ssh_dir}/authorized_keys"

	run_cmd "Create ${ssh_dir}" mkdir -p "$ssh_dir"
	run_cmd "Add key to authorized_keys" bash -c "printf '%s\n' '$pubkey' >> '$auth_keys'"
	run_cmd "Set SSH permissions" chmod 700 "$ssh_dir"
	run_cmd "Set authorized_keys permissions" chmod 600 "$auth_keys"
	run_cmd "Fix ownership on SSH files" chown -R "${ADMIN_USER}:${ADMIN_USER}" "$ssh_dir"

	ok "SSH key added for ${ADMIN_USER}."
}

apply_firewall() {
	if [[ "$FIREWALL_BACKEND" == "nftables" ]]; then
		apply_firewall_nftables
	else
		apply_firewall_ufw
	fi
}

print_summary() {
	cat <<EOF

========== firstb00t summary ==========
Version:            ${SCRIPT_VERSION}
Admin user:         ${ADMIN_USER}
Hostname:           $(hostname)
Timezone:           $(timedatectl show -p Timezone --value)
Firewall backend:   ${FIREWALL_BACKEND}
SSH port:           ${SSH_PORT}
FTP enabled:        ${FTP_ENABLED}
Container engine:   ${CONTAINER_ENGINE}
Container root:     ${CONTAINER_ROOT}
Log file:           ${LOG_FILE}
=======================================

Backup note: keep container volumes under ${CONTAINER_ROOT} for easy remote backup.
EOF
}

main() {
	mkdir -p "$(dirname "$LOG_FILE")"
	touch "$LOG_FILE"

	printf "%b%s%b %s\n" "$_yellow" "$SCRIPT_NAME" "$_nc" "v${SCRIPT_VERSION}"
	note "This script changes SSH, firewall, packages, and services."
	prompt_yes_no proceed "Continue now" "yes"
	[[ "$proceed" == "yes" ]] || abort "Canceled by user."

	require_root
	require_debian
	check_network

	bootstrap_nala
	collect_identity
	create_admin_user
	prompt_ftp
	install_base_packages
	setup_ftp_if_needed
	prompt_container_engine
	install_container_engine
	prompt_firewall_backend
	apply_firewall
	configure_ssh_hardening
	configure_system_services
	final_ssh_key_setup

	ok "Hardening complete."
	print_summary
}

main "$@"
