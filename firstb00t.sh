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
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║ 🔑 firstb00t - LOCAL helper                                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
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
SSH_KEY_FIRSTB00T="${SSH_DIR}/firstb00t_vps"

if [ -f "${SSH_KEY_ED25519}.pub" ] || [ -f "${SSH_KEY_RSA}.pub" ] || [ -f "${SSH_KEY_FIRSTB00T}.pub" ]; then
    echo -e "${YELLOW}📋 Found existing SSH key(s):${NC}"
    [ -f "${SSH_KEY_ED25519}.pub" ] && echo -e "  • ${SSH_KEY_ED25519}"
    [ -f "${SSH_KEY_RSA}.pub" ] && echo -e "  • ${SSH_KEY_RSA}"
    [ -f "${SSH_KEY_FIRSTB00T}.pub" ] && echo -e "  • ${SSH_KEY_FIRSTB00T}"
    echo ""
    echo -e "${BLUE}🔑 SSH key options:${NC}"
    echo -e "  ${CYAN}A)${NC} Use existing key (recommended if you already use SSH)"
    echo -e "  ${CYAN}B)${NC} Create dedicated key for this VPS: ${SSH_KEY_FIRSTB00T}"
    echo ""
    read -r -p "Your choice (A/B): " key_choice
    echo ""

    if [[ "$key_choice" =~ ^[Bb]$ ]]; then
        SSH_KEY="$SSH_KEY_FIRSTB00T"
        echo -e "${BLUE}🔐 Generating dedicated ED25519 key for firstb00t VPS...${NC}"
        echo -e "${YELLOW}Tip: you can set a passphrase for better security.${NC}"
        echo -e "${YELLOW}(If you leave it empty, you won't be prompted later.)${NC}"
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
        elif [ -f "${SSH_KEY_FIRSTB00T}.pub" ]; then
            SSH_KEY="$SSH_KEY_FIRSTB00T"
        fi
        echo -e "${GREEN}✅ Using existing key: ${SSH_KEY}.pub${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No SSH key found in ~/.ssh${NC}"
    echo ""
    echo -e "${YELLOW}We recommend creating a dedicated ED25519 key for this VPS.${NC}"
    echo ""
    read -r -p "Generate a new dedicated key ${SSH_KEY_FIRSTB00T}? (y/n): " gen_key
    echo ""

    if [[ "$gen_key" =~ ^[Yy]$ ]]; then
        SSH_KEY="$SSH_KEY_FIRSTB00T"

        echo -e "${BLUE}🔐 Generating dedicated ED25519 key for firstb00t VPS...${NC}"
        echo -e "${YELLOW}Tip: you can set a passphrase for better security.${NC}"
        echo -e "${YELLOW}(If you leave it empty, you won't be prompted later.)${NC}"
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

PUBLIC_IPV4=""
if [ -n "$IPV4_DETECTED" ]; then
    echo -e "${CYAN}Detected IPv4: ${IPV4_DETECTED}${NC}"
    read -r -p "Use this IPv4? (Y/n): " use_ipv4
    if [[ ! "$use_ipv4" =~ ^[Nn]$ ]]; then
        PUBLIC_IPV4="$IPV4_DETECTED"
    else
        read -r -p "Enter your IPv4 address: " PUBLIC_IPV4
    fi
else
    read -r -p "Enter your IPv4 address (or press Enter to skip): " PUBLIC_IPV4
fi

if [ -n "$PUBLIC_IPV4" ]; then
    echo -e "${GREEN}✅ IPv4: $PUBLIC_IPV4${NC}"
fi

echo ""
echo -e "${CYAN}━━━ IPv6 Address ━━━${NC}"
IPV6_DETECTED=""
if command -v curl >/dev/null 2>&1; then
    IPV6_DETECTED="$(curl -6 -s https://icanhazip.com 2>/dev/null || true)"
fi

if [ -n "$IPV6_DETECTED" ]; then
    IPV6_DETECTED="$(echo "$IPV6_DETECTED" | xargs | grep -E '^[0-9a-fA-F:]+$' || true)"
fi

PUBLIC_IPV6=""
if [ -n "$IPV6_DETECTED" ]; then
    echo -e "${CYAN}Detected IPv6: ${IPV6_DETECTED}${NC}"
    read -r -p "Use this IPv6? (Y/n): " use_ipv6
    if [[ ! "$use_ipv6" =~ ^[Nn]$ ]]; then
        PUBLIC_IPV6="$IPV6_DETECTED"
    else
        read -r -p "Enter your IPv6 address: " PUBLIC_IPV6
    fi
else
    read -r -p "Enter your IPv6 address (or press Enter to skip): " PUBLIC_IPV6
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

echo -e "${CYAN}━━━ VPS IP Address ━━━${NC}"
echo -e "${CYAN}Example IPv4: 203.0.113.45${NC}"
echo -e "${CYAN}Example IPv6: 2001:db8:85a3::8a2e:370:7334${NC}"
read -r -p "VPS IP (IPv4 or IPv6): " vps_ip

if [ -z "$vps_ip" ]; then
    echo -e "${RED}❌ VPS IP is required${NC}"
    exit 1
fi

echo -e "${GREEN}✅ VPS IP: $vps_ip${NC}"

echo ""
echo -e "${CYAN}━━━ VPS Username ━━━${NC}"
read -r -p "VPS username (press Enter for root): " vps_user
vps_user="${vps_user:-root}"
echo -e "${GREEN}✅ VPS user: $vps_user${NC}"

echo ""

# ===============================================================
# Step 5: display copy-paste data
# ===============================================================

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║ 📋 Copy-paste values for the VPS                            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
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

echo -e "${YELLOW}🖥️  VPS IP:${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo "$vps_ip"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo ""

echo -e "${YELLOW}⚙️  SSH key file on your local machine:${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo "$SSH_KEY"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
echo ""

# ===============================================================
# Step 6: instructions
# ===============================================================

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║ 🔶 Next steps                                              ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}1. Open a NEW terminal window${NC}"
echo ""

echo -e "${GREEN}2. Connect to VPS with SSH:${NC}"
echo -e "${BLUE}   ssh ${vps_user}@${vps_ip}${NC}"
echo ""

echo -e "${GREEN}3. Upload the project to the VPS (recommended):${NC}"
echo -e "${BLUE}   # From your local terminal:${NC}"
echo -e "${BLUE}   scp -r github/* ${vps_user}@${vps_ip}:/root/firstb00t/${NC}"
echo ""

echo -e "${GREEN}4. Run Debian setup on the VPS:${NC}"
echo -e "${BLUE}   # On the VPS terminal:${NC}"
echo -e "${BLUE}   cd /root/firstb00t${NC}"
echo -e "${BLUE}   bash setup/debian.sh${NC}"
echo ""

echo -e "${GREEN}5. When prompted by setup/debian.sh, copy-paste:${NC}"
echo -e "${YELLOW}   • SSH public key (from above)${NC}"
echo -e "${YELLOW}   • your public IPv4 and/or IPv6 (from above)${NC}"
echo ""

echo -e "${GREEN}6. After setup, the full installer starts on the VPS${NC}"
echo ""

echo -e "${GREEN}7. Test SSH key access from local machine:${NC}"
echo -e "${BLUE}   ssh -i ${SSH_KEY} ${vps_user}@${vps_ip} 'uptime'${NC}"
echo ""

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║ ✅ Local helper complete                                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Keep this terminal open while you set up the VPS.${NC}"
echo ""
