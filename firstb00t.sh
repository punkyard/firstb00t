#!/bin/bash

# 🔑 firstb00t (local helper)
# Purpose: run on your LOCAL machine to prepare SSH key + show copy-paste values.

set -Eeuo pipefail
export LC_ALL=C.UTF-8

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
source "$(dirname "${BASH_SOURCE[0]}")/../common/logging.sh" 2>/dev/null || true
print_title_frame "🔑" "firstb00t - LOCAL helper"
echo ""

# ===============================================================
# Step 1: check/create SSH key
# ===============================================================

echo -e "${BLUE}📦 Step 1: SSH key check${NC}"
echo ""

SSH_DIR="${HOME}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

SSH_KEY_ED25519="${SSH_DIR}/id_ed25519"
SSH_KEY_RSA="${SSH_DIR}/id_rsa"
SSH_KEY_DEFAULT_NAME="firstb00t_vps"
SSH_KEY_FIRSTB00T_DEFAULT="${SSH_DIR}/${SSH_KEY_DEFAULT_NAME}"

prompt_key_name() {
    local custom_key_name
    echo -e "${YELLOW}Enter a name for the SSH key (in ~/.ssh)${NC}" >&2
    echo -e "${YELLOW}Examples: ${CYAN}vps-name${NC} or with subfolder: ${CYAN}provider/vps-name${NC}" >&2
    read -r -p "Enter a name for the SSH key (relative to ~/.ssh, e.g., provider/vps-name): " custom_key_name
    custom_key_name="${custom_key_name:-$SSH_KEY_DEFAULT_NAME}"
    if [[ "$custom_key_name" == /* ]]; then
        echo "$custom_key_name"
    else
        echo "${SSH_DIR}/${custom_key_name}"
    fi
}

if [ -f "${SSH_KEY_ED25519}.pub" ] || [ -f "${SSH_KEY_RSA}.pub" ] || [ -f "${SSH_KEY_FIRSTB00T_DEFAULT}.pub" ]; then
    echo -e "${YELLOW}📋 Found existing SSH key(s):${NC}"
    [ -f "${SSH_KEY_ED25519}.pub" ] && echo -e "  • ${SSH_KEY_ED25519}"
    [ -f "${SSH_KEY_RSA}.pub" ] && echo -e "  • ${SSH_KEY_RSA}"
    [ -f "${SSH_KEY_FIRSTB00T_DEFAULT}.pub" ] && echo -e "  • ${SSH_KEY_FIRSTB00T_DEFAULT}"
    echo ""
    echo -e "${BLUE}🔑 SSH key options:${NC}"
    echo ""
    echo -e "  ${CYAN}A)${NC} Use existing key (recommended if you already use SSH)"
    echo -e "  ${CYAN}B)${NC} Create dedicated key for this VPS (you choose the name; it will live under ~/.ssh)"
    echo ""
    read -r -p "Your choice (A/B): " key_choice
    echo ""

    if [[ "$key_choice" =~ ^[Bb]$ ]]; then
        SSH_KEY="$(prompt_key_name)"
        mkdir -p "$(dirname "$SSH_KEY")"
        echo ""
        echo -e "${BLUE}🔐 Generating dedicated ED25519 SSH key...${NC}"
        echo ""
        echo -e "${YELLOW}Enter passphrase to protect the private key at rest; ssh-agent can cache it after one entry.${NC}"
        echo -e "Example: ${CYAN}correct-horse-battery-staple-2026!${NC}"
        echo -e "(If you leave it empty, you won't be prompted later.)"
        echo ""

        ssh-keygen -t ed25519 -f "$SSH_KEY" -C "firstb00t-vps-$(date +%Y%m%d)" || {
            echo -e "${RED}❌ Key generation failed${NC}"
            exit 1
        }
        echo ""
        echo -e "${GREEN}✅ Dedicated key generated: ${SSH_KEY}.pub${NC}"
    else
        # Use existing key (default to ED25519 > RSA)
        if [ -f "${SSH_KEY_ED25519}.pub" ]; then
            SSH_KEY="$SSH_KEY_ED25519"
        elif [ -f "${SSH_KEY_RSA}.pub" ]; then
            SSH_KEY="$SSH_KEY_RSA"
        elif [ -f "${SSH_KEY_FIRSTB00T_DEFAULT}.pub" ]; then
            SSH_KEY="$SSH_KEY_FIRSTB00T_DEFAULT"
        fi
        echo -e "${GREEN}✅ Using existing key: ${SSH_KEY}.pub${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No SSH key found in ~/.ssh${NC}"
    echo ""
    echo -e "${YELLOW}We recommend creating a dedicated ED25519 key for this VPS.${NC}"
    echo ""
    read -r -p "Generate a new dedicated key [${SSH_KEY_DEFAULT_NAME}] under ~/.ssh? (y/n): " gen_key
    echo ""

    if [[ "$gen_key" =~ ^[Yy]$ ]]; then
        SSH_KEY="$(prompt_key_name)"
        mkdir -p "$(dirname "$SSH_KEY")"
        echo ""
        echo -e "${BLUE}🔐 Generating dedicated ED25519 SSH key...${NC}"
        echo ""
        echo -e "${YELLOW}Enter a passphrase to protect the private key at rest; ssh-agent can cache it after one entry.${NC}"
        echo -e "Example: ${CYAN}correct-horse-battery-staple-2026!${NC}"
        echo -e "(If you leave it empty, you won't be prompted later.)"
        echo ""

        ssh-keygen -t ed25519 -f "$SSH_KEY" -C "firstb00t-vps-$(date +%Y%m%d)" || {
            echo -e "${RED}❌ Key generation failed${NC}"
            exit 1
        }
        echo ""
        echo -e "${GREEN}✅ Dedicated key generated: ${SSH_KEY}.pub${NC}"
    else
        echo -e "${RED}❌ Cannot proceed without an SSH key${NC}"
        exit 1
    fi
fi

# ===============================================================
# Step 2: extract public key
# ===============================================================

echo ""
echo -e "${BLUE}📋 Step 2: Reading public key${NC}"
echo ""

SSH_PUB="${SSH_KEY}.pub"

if [ ! -f "$SSH_PUB" ]; then
    echo -e "${RED}❌ Public key file not found: $SSH_PUB${NC}"
    exit 1
fi

PUBLIC_KEY="$(cat "$SSH_PUB")"
echo -e "${GREEN}✅ Public key loaded${NC}"
echo ""

# ===============================================================
# Step 3: get public IP (dual-stack)
# ===============================================================

echo -e "${BLUE}🌐 Step 3: Your public IP configuration${NC}"
echo ""
echo -e "${YELLOW}These public IP(s) can be used to allow SSH ONLY from you (safer).${NC}"
echo -e "${YELLOW}If you have both IPv4 and IPv6, using both is fine.${NC}"
echo ""

echo -e "${CYAN}━━━ IPv4 Address ━━━${NC}"
IPV4_DETECTED=""
if command -v curl >/dev/null 2>&1; then
    IPV4_DETECTED="$(curl -4 -s https://icanhazip.com 2>/dev/null || true)"
fi

if [ -n "$IPV4_DETECTED" ]; then
    IPV4_DETECTED="$(echo "$IPV4_DETECTED" | xargs | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)"
fi

# IPv6 detection (init before use to satisfy set -u)
IPV6_DETECTED=""
if command -v curl >/dev/null 2>&1; then
    IPV6_DETECTED="$(curl -6 -s https://icanhazip.com 2>/dev/null || true)"
fi

if [ -n "$IPV6_DETECTED" ]; then
    IPV6_DETECTED="$(echo "$IPV6_DETECTED" | xargs | grep -E '^[0-9a-fA-F:]+$' || true)"
fi

PUBLIC_IPV4=""
PUBLIC_IPV6=""

CHOICE_IP=""
if [ -n "$IPV4_DETECTED" ] && [ -n "$IPV6_DETECTED" ]; then
    echo -e "${CYAN}Detected IPv4:${NC} ${IPV4_DETECTED}"
    echo -e "${CYAN}Detected IPv6:${NC} ${IPV6_DETECTED}"
    echo -e "${BLUE}Select which IPs to use:${NC}"
    echo -e "  ${CYAN}1)${NC} IPv4 only"
    echo -e "  ${CYAN}2)${NC} IPv6 only"
    echo -e "  ${CYAN}3)${NC} Both IPv4 and IPv6"
    echo -e "  ${CYAN}4)${NC} Manual entry"
    read -r -p "Choice (1/2/3/4): " CHOICE_IP
elif [ -n "$IPV4_DETECTED" ]; then
    echo -e "${CYAN}Detected IPv4:${NC} ${IPV4_DETECTED}"
    read -r -p "Use this IPv4? (Y/n): " use_ipv4
    if [[ ! "$use_ipv4" =~ ^[Nn]$ ]]; then
        PUBLIC_IPV4="$IPV4_DETECTED"
    else
        CHOICE_IP="4"
    fi
elif [ -n "$IPV6_DETECTED" ]; then
    echo -e "${CYAN}Detected IPv6:${NC} ${IPV6_DETECTED}"
    read -r -p "Use this IPv6? (Y/n): " use_ipv6
    if [[ ! "$use_ipv6" =~ ^[Nn]$ ]]; then
        PUBLIC_IPV6="$IPV6_DETECTED"
    else
        CHOICE_IP="4"
    fi
else
    CHOICE_IP="4"
fi

if [[ "$CHOICE_IP" == "1" ]]; then
    PUBLIC_IPV4="$IPV4_DETECTED"
elif [[ "$CHOICE_IP" == "2" ]]; then
    PUBLIC_IPV6="$IPV6_DETECTED"
elif [[ "$CHOICE_IP" == "3" ]]; then
    PUBLIC_IPV4="$IPV4_DETECTED"
    PUBLIC_IPV6="$IPV6_DETECTED"
fi

if [[ "$CHOICE_IP" == "4" ]]; then
    read -r -p "Enter your IPv4 (or press Enter to skip): " PUBLIC_IPV4
    read -r -p "Enter your IPv6 (or press Enter to skip): " PUBLIC_IPV6
fi

echo ""
if [ -n "$PUBLIC_IPV4" ]; then
    echo -e "${GREEN}✅ IPv4: $PUBLIC_IPV4${NC}"
fi

if [ -n "$PUBLIC_IPV6" ]; then
    echo -e "${GREEN}✅ IPv6: $PUBLIC_IPV6${NC}"
fi

echo ""

# ===============================================================
# Step 4: VPS details
# ===============================================================

echo -e "${BLUE}🖥️  Step 4: VPS details${NC}"
echo ""
echo -e "${YELLOW}Get your VPS credentials from your provider's website/panel (e.g., Contabo, Linode, DigitalOcean).${NC}"
echo -e "${YELLOW}These are NOT your local SSH keys — these are the IP and login for your NEW server.${NC}"
echo ""

echo -e "${CYAN}━━━ Examples ━━━${NC}"
echo -e "IPv4: 203.0.113.45"
echo -e "IPv6: 2001:db8:85a3::8a2e:370:7334"
echo ""

vps_ipv4=""
vps_ipv6=""

read -r -p "Does your VPS have IPv4? (y/n): " has_ipv4
if [[ "$has_ipv4" =~ ^[Yy]$ ]]; then
    read -r -p "VPS IPv4: " vps_ipv4
    echo -e "${GREEN}✅ VPS IPv4: $vps_ipv4${NC}"
fi
echo ""

read -r -p "Does your VPS have IPv6? (y/n): " has_ipv6
if [[ "$has_ipv6" =~ ^[Yy]$ ]]; then
    read -r -p "VPS IPv6: " vps_ipv6
    echo -e "${GREEN}✅ VPS IPv6: $vps_ipv6${NC}"
fi
echo ""

if [ -z "$vps_ipv4" ] && [ -z "$vps_ipv6" ]; then
    echo -e "${RED}❌ At least one VPS IP (IPv4 or IPv6) is required${NC}"
    exit 1
fi

echo -e "${CYAN}━━━ VPS initial login username ━━━${NC}"
echo -e "${YELLOW}This is the username provided by your VPS provider (usually 'root' for new servers).${NC}"
read -r -p "VPS initial username (press Enter for 'root'): " vps_user
vps_user="${vps_user:-root}"
echo -e "${GREEN}✅ VPS initial user: $vps_user${NC}"

echo ""

# ===============================================================
# Step 5: display copy-paste data
# ===============================================================

print_title_frame "📋" "Copy-paste values for the VPS"
echo ""

echo -e "${YELLOW}🔐 SSH public key:${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo "$PUBLIC_KEY"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo ""

if [ -n "$PUBLIC_IPV4" ]; then
    echo -e "${YELLOW}🌐 Your public IPv4 (allowlist):${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
    echo "$PUBLIC_IPV4"
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
    echo ""
fi

if [ -n "$PUBLIC_IPV6" ]; then
    echo -e "${YELLOW}🌐 Your public IPv6 (allowlist):${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
    echo "$PUBLIC_IPV6"
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
    echo ""
fi

if [ -n "$vps_ipv4" ] || [ -n "$vps_ipv6" ]; then
    echo -e "${YELLOW}🖥️  VPS IP(s):${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
    [ -n "$vps_ipv4" ] && echo "IPv4: $vps_ipv4"
    [ -n "$vps_ipv6" ] && echo "IPv6: $vps_ipv6"
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
    echo ""
fi

echo -e "${YELLOW}⚙️  SSH key file on your local machine:${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo "$SSH_KEY"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo ""

# ===============================================================
# Step 6: instructions
# ===============================================================

print_title_frame "🔶" "Next steps"
echo ""

echo -e "${GREEN}1. Open a NEW terminal window${NC}"
echo ""

echo -e "${GREEN}2. Connect to VPS with SSH:${NC}"
if [ -n "$vps_ipv4" ]; then
    echo -e "${BLUE}   ssh ${vps_user}@${vps_ipv4}${NC}"
fi
if [ -n "$vps_ipv6" ]; then
    echo -e "${BLUE}   ssh ${vps_user}@${vps_ipv6}${NC}"
fi
echo ""

echo -e "${GREEN}3. Upload the required scripts to the VPS (from your LOCAL terminal, from the github/ directory):${NC}"
if [ -n "$vps_ipv4" ]; then
    echo -e "${CYAN}━━━ IPv4 upload commands ━━━${NC}"
    echo -e "${BLUE}   cd github${NC}"
    echo -e "${BLUE}   ssh ${vps_user}@${vps_ipv4} 'mkdir -p /home/firstb00t/modules'${NC}"
    echo -e "${BLUE}   scp -r setup ${vps_user}@${vps_ipv4}:/home/firstb00t/${NC}"
    echo -e "${BLUE}   scp firstb00t.sh ${vps_user}@${vps_ipv4}:/home/firstb00t/${NC}"
    echo -e "${BLUE}   scp -r common ${vps_user}@${vps_ipv4}:/home/firstb00t/${NC}"
    echo -e "${BLUE}   scp modules/01-profile_selection.sh modules/02-system_updates.sh modules/03-user_management.sh modules/04-ssh_config.sh modules/05-ssh_hardening.sh modules/06-firewall_config.sh modules/11-monitoring.sh ${vps_user}@${vps_ipv4}:/home/firstb00t/modules/${NC}"
    echo ""
fi
if [ -n "$vps_ipv6" ]; then
    echo -e "${CYAN}━━━ IPv6 upload commands ━━━${NC}"
    echo -e "${BLUE}   cd github${NC}"
    echo -e "${BLUE}   ssh ${vps_user}@${vps_ipv6} 'mkdir -p /home/firstb00t/modules'${NC}"
    echo -e "${BLUE}   scp -r setup ${vps_user}@${vps_ipv6}:/home/firstb00t/${NC}"
    echo -e "${BLUE}   scp firstb00t.sh ${vps_user}@${vps_ipv6}:/home/firstb00t/${NC}"
    echo -e "${BLUE}   scp -r common ${vps_user}@${vps_ipv6}:/home/firstb00t/${NC}"
    echo -e "${BLUE}   scp modules/01-profile_selection.sh modules/02-system_updates.sh modules/03-user_management.sh modules/04-ssh_config.sh modules/05-ssh_hardening.sh modules/06-firewall_config.sh modules/11-monitoring.sh ${vps_user}@${vps_ipv6}:/home/firstb00t/modules/${NC}"
    echo ""
fi
echo -e "${YELLOW}   (Optional) Env overrides: setup/debian.sh auto-loads ${CYAN}modules/sample.env${NC} if it exists.${NC}"
echo -e "${YELLOW}   Edit it locally BEFORE upload, then upload it like this:${NC}"
echo -e "${BLUE}   scp modules/sample.env ${vps_user}@<VPS_IP>:/home/firstb00t/modules/${NC}"
echo ""

echo -e "${GREEN}4. Run Debian setup on the VPS:${NC}"
echo -e "${BLUE}   # On the VPS terminal:${NC}"
echo -e "${BLUE}   cd /home/firstb00t${NC}"
echo -e "${BLUE}   bash setup/debian.sh --skip-ssh-hardening${NC}"
echo ""

echo -e "${GREEN}5. When prompted by setup/debian.sh, copy-paste:${NC}"
echo -e "${YELLOW}   • SSH public key (from above)${NC}"
echo -e "${YELLOW}   • your public IPv4 and/or IPv6 (from above)${NC}"
echo ""

echo -e "${GREEN}6. After setup, the full installer starts on the VPS${NC}"
echo ""

echo -e "${GREEN}7. Test SSH key access from local machine:${NC}"
if [ -n "$vps_ipv4" ]; then
    echo -e "${BLUE}   ssh -i ${SSH_KEY} ${vps_user}@${vps_ipv4} 'uptime'${NC}"
fi
if [ -n "$vps_ipv6" ]; then
    echo -e "${BLUE}   ssh -i ${SSH_KEY} ${vps_user}@${vps_ipv6} 'uptime'${NC}"
fi
echo ""

# ===============================================================
# Step 7: generate desktop report
# ===============================================================

read -r -p "Save a report on your Desktop with public details (SSH key + IPs)? (Y/n): " save_report
echo ""

if [[ ! "${save_report:-}" =~ ^[Nn]$ ]]; then
    REPORT_FILE="${HOME}/Desktop/firstb00t-report.txt"

    cat > "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════════
🔑 firstb00t — VPS Setup Report
═══════════════════════════════════════════════════════════════
Generated: $(date)

📋 SSH PUBLIC KEY:
────────────────────────────────────────────────────────────────
$PUBLIC_KEY
────────────────────────────────────────────────────────────────

🌐 YOUR PUBLIC IPs (for SSH allowlist):
────────────────────────────────────────────────────────────────
EOF

    if [ -n "$PUBLIC_IPV4" ]; then
        echo "IPv4: $PUBLIC_IPV4" >> "$REPORT_FILE"
    fi
    if [ -n "$PUBLIC_IPV6" ]; then
        echo "IPv6: $PUBLIC_IPV6" >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF
────────────────────────────────────────────────────────────────

🖥️  VPS DETAILS:
────────────────────────────────────────────────────────────────
EOF

    if [ -n "$vps_ipv4" ]; then
        echo "VPS IPv4: $vps_ipv4" >> "$REPORT_FILE"
    fi
    if [ -n "$vps_ipv6" ]; then
        echo "VPS IPv6: $vps_ipv6" >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF
VPS Username: $vps_user
────────────────────────────────────────────────────────────────

⚙️  LOCAL SSH KEY FILE:
────────────────────────────────────────────────────────────────
$SSH_KEY
────────────────────────────────────────────────────────────────

🔶 NEXT STEPS:
────────────────────────────────────────────────────────────────
1. Open a NEW terminal window

2. Connect to VPS with SSH:
EOF

    if [ -n "$vps_ipv4" ]; then
        echo "   ssh ${vps_user}@${vps_ipv4}" >> "$REPORT_FILE"
    fi
    if [ -n "$vps_ipv6" ]; then
        echo "   ssh ${vps_user}@${vps_ipv6}" >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF

3. Upload the required scripts to the VPS (from your LOCAL terminal, from the github/ directory):
EOF

    if [ -n "$vps_ipv4" ]; then
        cat >> "$REPORT_FILE" << EOF
   cd github
   ssh ${vps_user}@${vps_ipv4} 'mkdir -p /home/firstb00t/modules'
   scp -r setup ${vps_user}@${vps_ipv4}:/home/firstb00t/
   scp firstb00t.sh ${vps_user}@${vps_ipv4}:/home/firstb00t/
   scp -r common ${vps_user}@${vps_ipv4}:/home/firstb00t/
   scp modules/01-profile_selection.sh modules/02-system_updates.sh modules/03-user_management.sh modules/04-ssh_config.sh modules/05-ssh_hardening.sh modules/06-firewall_config.sh modules/11-monitoring.sh ${vps_user}@${vps_ipv4}:/home/firstb00t/modules/
EOF
    fi

    if [ -n "$vps_ipv6" ]; then
        cat >> "$REPORT_FILE" << EOF
   cd github
   ssh ${vps_user}@${vps_ipv6} 'mkdir -p /home/firstb00t/modules'
   scp -r setup ${vps_user}@${vps_ipv6}:/home/firstb00t/
   scp firstb00t.sh ${vps_user}@${vps_ipv6}:/home/firstb00t/
   scp -r common ${vps_user}@${vps_ipv6}:/home/firstb00t/
   scp modules/01-profile_selection.sh modules/02-system_updates.sh modules/03-user_management.sh modules/04-ssh_config.sh modules/05-ssh_hardening.sh modules/06-firewall_config.sh modules/11-monitoring.sh ${vps_user}@${vps_ipv6}:/home/firstb00t/modules/
EOF
    fi

    cat >> "$REPORT_FILE" << EOF

4. Run Debian setup on the VPS:
   cd /home/firstb00t
    bash setup/debian.sh --skip-ssh-hardening

5. When prompted by setup/debian.sh, copy-paste:
   • SSH public key (from above)
   • your public IPv4 and/or IPv6 (from above)

6. (Optional) Env overrides (setup/debian.sh loads modules/sample.env if present):
   • edit modules/sample.env locally
   • upload: scp modules/sample.env ${vps_user}@<VPS_IP>:/home/firstb00t/modules/

────────────────────────────────────────────────────────────────
EOF

    echo -e "${GREEN}✅ Report saved to: ${REPORT_FILE}${NC}"
    echo ""
else
    echo -e "${YELLOW}⏭️  Skipped saving Desktop report${NC}"
    echo ""
fi

print_title_frame "✅" "Local helper complete"
echo ""
echo -e "${YELLOW}Keep this terminal open while you set up the VPS.${NC}"
echo ""
