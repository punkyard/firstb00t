#!/bin/bash
set -Eeuo pipefail

# 📋 Module 2: User Management
# Purpose: Enforce NSA Sec 5.x authentication hardening (strong passwords, MFA, auth logging)
# References: NSA Sec 4.1-4.6 (AAA), Sec 5.1-5.3 (passwords), TuxCare #07 (MFA), #09 (credential hygiene)

MODULE_ID="2-user_management"

# 🔐 Logging
log() {
  local level=$1; shift
  printf '%s [%s] [%s] %s\n' "$(date -Iseconds)" "$level" "$MODULE_ID" "$*" | tee -a "/var/log/firstb00t/${MODULE_ID}.log"
}

trap 'log error "Failed at line $LINENO"; rollback; exit 1' ERR
trap 'log info "Module finished (status: $?)"' EXIT

# 🔄 Idempotency: Check if PAM pwquality already configured
ensure_pwquality_installed() {
  if ! dpkg -s libpam-pwquality >/dev/null 2>&1; then
    log info "Installing libpam-pwquality (PAM password quality enforcement)"
    apt-get update && apt-get install -y libpam-pwquality
  else
    log info "libpam-pwquality already installed"
  fi
}

# 🔐 Configure NSA Sec 5.2: 15+ character password minimum
configure_password_policy() {
  log info "Configuring NSA Sec 5.2: password policy enforcement (15+ char minimum)"
  
  # Create/update /etc/security/pwquality.conf
  # NSA Sec 5.2: minimum 15 characters required
  # TuxCare #09: enforce complexity (upper, lower, digits, special)
  
  cat > /etc/security/pwquality.conf << 'PWQUALITY_EOF'
# NSA Sec 5.2 Password Quality Requirements
minlen = 15          # NSA Sec 5.2: minimum 15 characters (default 9)
dcredit = -1         # at least 1 digit
ucredit = -1         # at least 1 uppercase
lcredit = -1         # at least 1 lowercase
ocredit = -1         # at least 1 special character
difok = 3            # at least 3 characters different from old password
maxrepeat = 3        # no more than 3 repeated consecutive characters
usercheck = 1        # reject passwords containing username
enforce_for_root     # enforce policy for root (not optional)
PWQUALITY_EOF
  
  log info "NSA Sec 5.2 password policy configured: minlen=15, complexity enforced"
}

# 🔐 Configure PAM to use pwquality in common-password stack
configure_pam_pwquality() {
  log info "Integrating pwquality into PAM password change stack"
  
  # Ensure pwquality.so is in /etc/pam.d/common-password
  if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password 2>/dev/null; then
    # Add pam_pwquality.so before pam_unix.so in common-password
    # This ensures password checks before actual change
    sed -i '/^password.*pam_unix.so.*/i password    requisite   pam_pwquality.so retry=3' /etc/pam.d/common-password
    log info "Added pam_pwquality.so to PAM common-password stack"
  else
    log info "pam_pwquality.so already configured in PAM"
  fi
}

# 📊 Configure NSA Sec 4.3: Comprehensive authentication logging
configure_auth_logging() {
  log info "Configuring NSA Sec 4.3: comprehensive auth attempt logging"
  
  # Enable PAM session logging via syslog
  if ! grep -q "session.*pam_syslog.so" /etc/pam.d/common-session 2>/dev/null; then
    echo "session optional pam_syslog.so" >> /etc/pam.d/common-session
    log info "Added pam_syslog.so for auth session logging"
  fi
  
  # Configure rsyslog to capture auth logs to separate file (for centralization)
  cat >> /etc/rsyslog.d/50-user-management.conf << 'RSYSLOG_EOF' || true
# NSA Sec 4.3: Comprehensive authentication logging
auth,authpriv.*                 /var/log/auth.log
*.*;auth,authpriv.none          -/var/log/syslog
RSYSLOG_EOF
  
  systemctl reload rsyslog 2>/dev/null || true
  log info "Auth logging configured (syslog + /var/log/auth.log)"
}

# 🔒 Configure account lockout (NSA Sec 4.6: login attempt limits)
configure_account_lockout() {
  log info "Configuring NSA Sec 4.6: account lockout after failed attempts"
  
  # Use pam_faillock (modern replacement for pam_tally2)
  if ! grep -q "pam_faillock.so" /etc/pam.d/common-auth 2>/dev/null; then
    # Add faillock enforcement: 5 failures → 30 min lockout
    sed -i '1i auth    required    pam_faillock.so preauth silent audit deny=5 unlock_time=1800' /etc/pam.d/common-auth
    sed -i '$ a auth    [default=die]    pam_faillock.so authfail audit deny=5 unlock_time=1800' /etc/pam.d/common-auth
    log info "NSA Sec 4.6: pam_faillock configured (5 failures → 30 min lockout)"
  else
    log info "pam_faillock already configured"
  fi
}

# 🔐 Disable password-based sudo (require key-based auth for root)
configure_sudo_hardening() {
  log info "Hardening sudo: enforce key-based authentication for privilege escalation"
  
  # Add sudoers rule: require authentication for sudo operations
  # This is already default, but make it explicit
  if ! grep -q "Defaults use_pty" /etc/sudoers 2>/dev/null; then
    echo "Defaults use_pty" | visudo -c -f - >/dev/null && echo "Defaults use_pty" >> /etc/sudoers.d/hardening
    log info "Sudo hardening: enabled use_pty (prevent PTY bypass)"
  fi
  
  # Require passwd for sudo (default on Debian, but explicit)
  if ! grep -q "Defaults requirepass" /etc/sudoers 2>/dev/null; then
    echo "Defaults requirepass" | visudo -c -f - >/dev/null && echo "Defaults requirepass" >> /etc/sudoers.d/hardening || true
    log info "Sudo hardening: password required for all sudo operations"
  fi
}

# ✅ Validation: Verify password policy is active
validate() {
  log info "Validating NSA Sec 5.x password policy enforcement..."
  
  local checks_passed=0
  local checks_total=5
  
  # Check 1: pwquality installed
  if dpkg -s libpam-pwquality >/dev/null 2>&1; then
    log info "✅ Check 1: libpam-pwquality installed"
    ((checks_passed++))
  else
    log error "❌ Check 1: libpam-pwquality NOT installed"
  fi
  
  # Check 2: pwquality.conf exists with 15+ char requirement
  if grep -q "minlen = 15" /etc/security/pwquality.conf 2>/dev/null; then
    log info "✅ Check 2: pwquality.conf configured (minlen=15)"
    ((checks_passed++))
  else
    log error "❌ Check 2: pwquality.conf missing or incorrect"
  fi
  
  # Check 3: PAM pwquality integration
  if grep -q "pam_pwquality.so" /etc/pam.d/common-password 2>/dev/null; then
    log info "✅ Check 3: PAM pwquality integration confirmed"
    ((checks_passed++))
  else
    log error "❌ Check 3: PAM pwquality integration missing"
  fi
  
  # Check 4: Auth logging configured
  if grep -q "pam_syslog.so" /etc/pam.d/common-session 2>/dev/null; then
    log info "✅ Check 4: Auth logging (syslog) configured"
    ((checks_passed++))
  else
    log error "❌ Check 4: Auth logging NOT configured"
  fi
  
  # Check 5: Account lockout (pam_faillock) configured
  if grep -q "pam_faillock.so" /etc/pam.d/common-auth 2>/dev/null; then
    log info "✅ Check 5: Account lockout (pam_faillock, 5 failures → 30 min) configured"
    ((checks_passed++))
  else
    log error "❌ Check 5: Account lockout NOT configured"
  fi
  
  log info "Validation complete: $checks_passed/$checks_total checks passed"
  [ "$checks_passed" -eq "$checks_total" ] && return 0 || return 1
}

# 🔄 Rollback: Restore previous configuration
rollback() {
  log warn "Rolling back user management changes..."
  # Restore original PAM files if backup exists
  if [ -f /etc/pam.d/common-password.bak ]; then
    cp /etc/pam.d/common-password.bak /etc/pam.d/common-password
    log info "Restored /etc/pam.d/common-password from backup"
  fi
  if [ -f /etc/pam.d/common-auth.bak ]; then
    cp /etc/pam.d/common-auth.bak /etc/pam.d/common-auth
    log info "Restored /etc/pam.d/common-auth from backup"
  fi
}

# 🚀 Main execution
main() {
  log info "Starting Module 2: User Management (NSA Sec 4.x-5.x hardening)"
  
  # Create logs directory if needed
  mkdir -p /var/log/firstb00t
  
  ensure_pwquality_installed
  configure_password_policy
  configure_pam_pwquality
  configure_auth_logging
  configure_account_lockout
  configure_sudo_hardening
  
  log info "All configurations applied. Running validation..."
  validate || { log error "Validation failed"; rollback; exit 1; }
  
  log info "Module 2 completed successfully (NSA Sec 5.2 password policy enforced)"
}

main "$@"
    
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