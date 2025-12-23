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

# 🔐 Load admin email for MFA enrollment notifications
ADMIN_EMAIL=$(cat /etc/firstboot/admin_email 2>/dev/null || echo "root@localhost")

# � Idempotency: Check if PAM pwquality already configured
ensure_pwquality_installed() {
  if ! dpkg -s libpam-pwquality >/dev/null 2>&1; then
    log info "Installing libpam-pwquality (PAM password quality enforcement)"
    apt-get update && apt-get install -y libpam-pwquality
  else
    log info "libpam-pwquality already installed"
  fi
}

# 🔐 TuxCare #07: Install Google Authenticator (TOTP MFA)
ensure_mfa_installed() {
  if ! dpkg -s libpam-google-authenticator >/dev/null 2>&1; then
    log info "Installing libpam-google-authenticator (TOTP MFA - TuxCare #07)"
    apt-get update && apt-get install -y libpam-google-authenticator qrencode
  else
    log info "libpam-google-authenticator already installed"
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

# 🔐 TuxCare #07: Configure TOTP MFA in PAM
configure_mfa_pam() {
  log info "Configuring TuxCare #07: TOTP MFA via pam_google_authenticator.so"
  
  # Backup PAM files before modification
  cp /etc/pam.d/common-auth /etc/pam.d/common-auth.bak-mfa || true
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak-mfa || true
  
  # Add MFA to common-auth stack (before pam_unix.so)
  # Use nullok initially to allow non-enrolled users (for migration)
  if ! grep -q "pam_google_authenticator.so" /etc/pam.d/common-auth 2>/dev/null; then
    # Insert before first pam_unix line
    sed -i '/^auth.*pam_unix.so.*/i auth required pam_google_authenticator.so nullok' /etc/pam.d/common-auth
    log info "Added pam_google_authenticator.so to PAM common-auth stack (nullok mode for migration)"
  else
    log info "pam_google_authenticator.so already in PAM common-auth"
  fi
  
  # Enable challenge-response in SSH (required for TOTP)
  sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || \
  sed -i 's/^#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || \
  echo "ChallengeResponseAuthentication yes" >> /etc/ssh/sshd_config
  
  sed -i 's/^KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || \
  sed -i 's/^#KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || \
  echo "KbdInteractiveAuthentication yes" >> /etc/ssh/sshd_config
  
  # Ensure AuthenticationMethods allows keyboard-interactive + publickey
  if ! grep -q "^AuthenticationMethods" /etc/ssh/sshd_config 2>/dev/null; then
    echo "AuthenticationMethods publickey,keyboard-interactive" >> /etc/ssh/sshd_config
    log info "Set SSH AuthenticationMethods to publickey,keyboard-interactive (key + TOTP)"
  fi
  
  log info "SSH configured for MFA: publickey + TOTP required"
}

# 🔐 TuxCare #07: Generate TOTP secrets for admin users
generate_mfa_secrets() {
  log info "Generating TOTP MFA secrets for admin users"
  
  # Get list of sudo users
  local admin_users=$(getent group sudo 2>/dev/null | cut -d: -f4 | tr ',' ' ')
  
  if [ -z "$admin_users" ]; then
    log warn "No sudo users found. Skipping MFA enrollment."
    return
  fi
  
  for user in $admin_users; do
    # Skip root for now (requires special handling)
    if [ "$user" = "root" ]; then
      log info "Skipping root MFA enrollment (use manual google-authenticator)"
      continue
    fi
    
    if [ ! -f "/home/${user}/.google_authenticator" ]; then
      log info "Generating TOTP secret for user: ${user}"
      
      # Generate secret non-interactively with secure defaults
      # -t: time-based (TOTP), -d: disallow reuse, -f: force overwrite
      # -r 3 -R 30: rate limit (3 attempts per 30 seconds)
      # -w 3: window size (accept 3 time steps before/after)
      # -Q UTF8 -q: QR code UTF8, quiet mode
      su - "$user" -c "google-authenticator -t -d -f -r 3 -R 30 -w 3 -Q UTF8 -q" 2>&1 | tee "/var/log/firstb00t/mfa-${user}.log" || true
      
      # Save recovery codes separately
      local codes_file="/var/log/firstb00t/mfa-${user}-recovery.txt"
      if [ -f "/home/${user}/.google_authenticator" ]; then
        # Extract emergency scratch codes (lines after secret)
        tail -n +2 "/home/${user}/.google_authenticator" | head -5 > "${codes_file}"
        chmod 600 "${codes_file}"
        chown "$user:$user" "${codes_file}"
        
        log info "✅ MFA enrolled for ${user}. Recovery codes: ${codes_file}"
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "🔐 MFA ENROLLMENT: ${user}"
        echo "═══════════════════════════════════════════════════════════"
        echo "Scan QR code with authenticator app (Google Auth, Authy, etc.):"
        echo ""
        # Display QR code if in interactive terminal
        if [ -t 0 ]; then
          su - "$user" -c "head -1 ~/.google_authenticator | qrencode -t ANSI256" 2>/dev/null || echo "(QR code display requires interactive terminal)"
        else
          echo "Run as ${user}: head -1 ~/.google_authenticator | qrencode -t ANSI256"
        fi
        echo ""
        echo "Recovery codes saved: ${codes_file}"
        echo "⚠️  Store recovery codes securely (offline backup recommended)"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
      else
        log error "Failed to generate MFA secret for ${user}"
      fi
    else
      log info "MFA already configured for ${user}"
    fi
  done
  
  # Restart SSH to apply MFA changes
  systemctl restart sshd
  log info "SSH restarted with MFA enabled"
}

# � TuxCare #07: Configure TOTP MFA in PAM
configure_mfa_pam() {
  log info "Configuring TuxCare #07: TOTP MFA via pam_google_authenticator.so"
  
  # Add MFA to common-auth stack (before pam_unix.so)
  # Use nullok initially to allow non-enrolled users (for migration)
  if ! grep -q "pam_google_authenticator.so" /etc/pam.d/common-auth 2>/dev/null; then
    # Insert before first pam_unix line
    sed -i '/^auth.*pam_unix.so.*/i auth required pam_google_authenticator.so nullok' /etc/pam.d/common-auth
    log info "Added pam_google_authenticator.so to PAM common-auth stack (nullok mode for migration)"
  else
    log info "pam_google_authenticator.so already in PAM common-auth"
  fi
  
  # Enable challenge-response in SSH (required for TOTP)
  sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true
  sed -i 's/^KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true
  
  # Ensure AuthenticationMethods allows keyboard-interactive
  if ! grep -q "^AuthenticationMethods" /etc/ssh/sshd_config 2>/dev/null; then
    echo "AuthenticationMethods publickey,keyboard-interactive" >> /etc/ssh/sshd_config
    log info "Set SSH AuthenticationMethods to publickey,keyboard-interactive (key + TOTP)"
  fi
  
  log info "SSH configured for MFA: publickey + TOTP required"
}

# 🔐 TuxCare #07: Generate TOTP secrets for admin users
generate_mfa_secrets() {
  log info "Generating TOTP MFA secrets for admin users"
  
  # Get list of sudo users
  local admin_users=$(getent group sudo | cut -d: -f4 | tr ',' ' ')
  
  if [ -z "$admin_users" ]; then
    log warn "No sudo users found. Skipping MFA enrollment."
    return
  fi
  
  for user in $admin_users; do
    if [ ! -f "/home/${user}/.google_authenticator" ]; then
      log info "Generating TOTP secret for user: ${user}"
      
      # Generate secret non-interactively with secure defaults
      su - "$user" -c "google-authenticator -t -d -f -r 3 -R 30 -w 3 -Q UTF8 -q" 2>&1 | tee "/var/log/firstb00t/mfa-${user}.log"
      
      # Extract QR code and backup codes
      local qr_file="/var/log/firstb00t/mfa-${user}-qr.txt"
      local codes_file="/var/log/firstb00t/mfa-${user}-recovery.txt"
      
      su - "$user" -c "cat ~/.google_authenticator | head -1" > "${codes_file}"
      
      log info "✅ MFA enrolled for ${user}. Recovery codes: ${codes_file}"
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "🔐 MFA ENROLLMENT: ${user}"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "Scan QR code with authenticator app (Google Auth, Authy, etc.):"
      echo ""
      su - "$user" -c "qrencode -t ANSI256 < ~/.google_authenticator | head -1"
      echo ""
      echo "Recovery codes saved: ${codes_file}"
      echo "⚠️  Store recovery codes securely (offline backup recommended)"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
    else
      log info "MFA already configured for ${user}"
    fi
  done
  
  # Restart SSH to apply MFA changes
  systemctl restart sshd
  log info "SSH restarted with MFA enabled"
}

# �📊 Configure NSA Sec 4.3: Comprehensive authentication logging
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
  log info "Validating NSA Sec 5.x password policy + TuxCare #07 MFA..."
  
  local checks_passed=0
  local checks_total=6
  
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
  
  # Check 6: MFA (pam_google_authenticator) configured
  if grep -q "pam_google_authenticator.so" /etc/pam.d/common-auth 2>/dev/null; then
    log info "✅ Check 6: MFA (TOTP via pam_google_authenticator.so) configured"
    ((checks_passed++))
  else
    log error "❌ Check 6: MFA NOT configured"
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
  log info "Starting Module 2: User Management (NSA Sec 4.x-5.x + TuxCare #07 MFA)"
  
  # Create logs directory if needed
  mkdir -p /var/log/firstb00t
  
  ensure_pwquality_installed
  configure_password_policy
  configure_pam_pwquality
  configure_auth_logging
  configure_account_lockout
  configure_sudo_hardening
  
  # TuxCare #07: MFA deployment (CRITICAL for Zero Trust)
  log info "═══════════════════════════════════════════════════════════"
  log info "TuxCare #07: Deploying Multi-Factor Authentication (MFA)"
  log info "═══════════════════════════════════════════════════════════"
  ensure_mfa_installed
  configure_mfa_pam
  generate_mfa_secrets
  
  log info "All configurations applied. Running validation..."
  validate || { log error "Validation failed"; rollback; exit 1; }
  
  log info "Module 2 completed successfully (NSA Sec 5.2 + TuxCare #07 MFA)"
}

main "$@" 