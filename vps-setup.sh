#!/bin/bash

# Compatibility shim
# This script was renamed to debian-setup.sh.

set -Eeuo pipefail

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${SCRIPT_DIR}/debian-setup.sh"

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║ 🔁 Script renamed                                          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}This script is deprecated: vps-setup.sh${NC}"
echo -e "${YELLOW}New name: debian-setup.sh${NC}"
echo ""

if [ -f "$TARGET" ]; then
    exec bash "$TARGET" "$@"
fi

echo -e "${RED}🔴 Cannot continue: $TARGET not found.${NC}"
exit 1

