# 📦 User Management Module

## 🎯 Purpose

Enforce NSA Sec 4.x-5.x authentication hardening and credential hygiene policies:
- NSA Sec 5.2: 15+ character password minimum (pwquality enforcement)
- NSA Sec 4.3: Comprehensive authentication logging (syslog + /var/log/auth.log)
- NSA Sec 4.6: Account lockout after failed attempts (pam_faillock)
- TuxCare #09: Prevent weak credentials (enforce password complexity)
- TuxCare #03: Enable security monitoring (auth event tracking)

## 🔗 Dependencies

- libpam-pwquality: PAM password quality enforcement (15+ char minimum, complexity rules)
- libpam-faillock: Account lockout mechanism (5 failures → 30 min lockout)
- rsyslog: Authentication logging to syslog and /var/log/auth.log

## ⚙️ Configuration

### A. NSA Sec 5.2: Password Policy (/etc/security/pwquality.conf)

```bash
minlen = 15          # NSA Sec 5.2: mandatory 15+ character minimum
dcredit = -1         # require at least 1 digit
ucredit = -1         # require at least 1 uppercase letter
lcredit = -1         # require at least 1 lowercase letter
ocredit = -1         # require at least 1 special character
difok = 3            # at least 3 characters different from old password
maxrepeat = 3        # no more than 3 repeated consecutive characters
usercheck = 1        # reject passwords containing username
enforce_for_root     # enforce policy for root account
```

**Effect:** All passwords (user + root) must be 15+ chars with upper, lower, digit, special char

### B. NSA Sec 4.3: Authentication Logging

**Syslog Integration:**
- pam_syslog.so in common-session stack → logs all auth events
- rsyslog.d/50-user-management.conf → routes to /var/log/auth.log
- Centralization-ready for SIEM integration

**Auditable Events:**
- Successful logins (local/SSH)
- Failed login attempts (tracked per source)
- Privilege escalation (sudo commands)
- Password changes
- Account lockout/unlock

### C. NSA Sec 4.6: Account Lockout (pam_faillock)

```bash
deny=5              # lock account after 5 failed attempts
unlock_time=1800    # 30-minute lockout period
```

**Behavior:**
- Blocks further login attempts for 30 minutes
- Applies to all accounts including root
- Admin reset: `faillock --user username --reset`

### D. Sudo Hardening

- Require password for all sudo operations (PAM integration)
- Use PTY (pseudo-terminal) for sudo sessions (prevents TTY bypass)
- Enforced via /etc/sudoers.d/hardening rules

## 🚨 Error Handling

### Common Issues

A. Password rejected with "failed strength check"
   - cause: password < 15 chars or missing complexity requirement
   - solution: use 15+ chars with upper, lower, digit, special char
   - test: `echo "TestPassword123!" | xargs echo` (17 chars, all requirements)

B. Account locked after 5 failed attempts
   - cause: brute-force protection (expected behavior)
   - solution: wait 30 minutes or admin reset
   - admin: `sudo faillock --user username --reset`

C. pam_pwquality.so not found
   - cause: libpam-pwquality not installed
   - solution: `apt-get install libpam-pwquality`

### Recovery Procedures

A. Unlock account immediately
   - `faillock --user username --reset` (as root)

B. Bypass pwquality temporarily (emergency)
   - Edit /etc/security/pwquality.conf, lower minlen
   - Not recommended (security risk)

C. Restore default PAM configuration
   - Restore from /etc/pam.d/common-password.bak
   - Re-run module with rollback on failure

## 📊 Testing & Validation

**Test Suite:** `tests/modules/2-user_management/test_validation.sh`

**Test Coverage (5 checks):**
1. ✅ libpam-pwquality installed
2. ✅ pwquality.conf: minlen=15, complexity enforced
3. ✅ PAM pam_pwquality.so integration in common-password
4. ✅ Auth logging (syslog) configured
5. ✅ Account lockout (pam_faillock, 5 failures → 30 min) configured

**Manual Test:**
```bash
# Test 1: Password too short
sudo passwd testuser
# Enter: "short"
# Expected: "failed strength check (too short)"

# Test 2: Password without digit
sudo passwd testuser
# Enter: "ValidPasswordNoDigit!"
# Expected: "failed strength check (need digits)"

# Test 3: Valid password
sudo passwd testuser
# Enter: "ValidPassword123!"
# Expected: "password updated successfully"
```

## 🔒 Security Notes

- **Password Storage:** Uses SHA-512 hashing (modern Debian default, NSA Sec 5.1 compliant)
- **Failed Attempts:** Tracked in /var/log/faillog and syslog (forensics-ready)
- **Root Protection:** pwquality and faillock apply to root (strong enforcement)
- **PAM Stack:** Changes affect all login methods (local, SSH, su, sudo)

## 📋 TuxCare Top 10 Mapping

| TuxCare | Status | Implementation |
|---------|--------|-----------------|
| #07 Missing MFA | ⏳ Phase 3 | Future: pam-google-authenticator |
| #09 Weak credentials | ✅ **FIXED** | 15+ char + complexity via pwquality |
| #03 No monitoring | ✅ **FIXED** | Syslog + /var/log/auth.log |
| #04 Network gaps | SSH Module 3 | IP-based ACLs |

## 🔮 Future Enhancements (Phase 3)

A. **TOTP-based MFA** (NSA Sec 4.2 RBAC)
   - pam-google-authenticator
   - Enforce for sudo escalation
   - Optional for regular login

B. **Centralized AAA** (LDAP/RADIUS)
   - pam-ldap configuration
   - Enterprise account integration

C. **Password Expiry Policy** (NSA Sec 5.5)
   - chage enforcement: 90-day rotation
   - Prevent reuse of last 5 passwords

## 📚 References

- NSA Network Infrastructure Security Guide (U/OO/118623-22, Oct 2023)
  - Sec 4.1-4.6: AAA and authentication hardening
  - Sec 5.1-5.3: Password policies and strength requirements
- TuxCare Top 10 Cybersecurity Misconfigurations Playbook
- PAM Documentation: https://linux.die.net/man/5/pam.conf
- pwquality Reference: https://linux.die.net/man/5/pwquality.conf
   - verify .ssh permissions
C. verify
   - confirm deletion
   - verify system status

## 🔄 Integration

### Input

- user input for name
- user input for password

### Output

- user created with sudo
- .ssh directory configured
- permissions set

## 📊 Validation

### Success criteria

- user exists in /etc/passwd
- user is in sudo group
- .ssh directory exists with correct permissions
- password is set

### Performance metrics

- user creation time
- permission configuration time
- home directory size

## 🧹 Cleanup

### Temporary files

- /tmp/user-*: temporary files
- /etc/passwd.bak: passwd file backup
- /etc/group.bak: group file backup

### Configuration files

- /etc/passwd: user information
- /etc/group: group information
- /etc/sudoers: sudo configuration

## 📝 Logging

### Log files

- /var/log/firstboot_script.log: module actions
- /var/log/auth.log: authentication actions

### Log levels

- info: normal actions
- error: detected problems
- success: successful operations

## 🔧 Maintenance

### Regular tasks

- verify permissions
- verify groups
- verify passwords

### Updates

- update password criteria
- update permissions
- update groups
