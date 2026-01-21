# 🔐 SSH configuration module (04-ssh_config)

## 🎯 Purpose

Enforce **NSA Secure Shell security hardening (CSIS 7.11.1)** with strong cryptography, idle timeout, and key-based authentication. Per NSA Network Infrastructure Security Guide (U/OO/118623-22).

**NSA Requirements Met:**
- ✅ NSA Sec 7.11.1: Strong cipher suites (AES-256-GCM, ChaCha20-Poly1305)
- ✅ NSA Sec 7.11.1: Strong key exchange (Curve25519, DHE-SHA256)
- ✅ NSA Sec 7.11.1: Strong MACs (HMAC-SHA2-512-ETM, HMAC-SHA2-256-ETM)
- ✅ NSA Sec 7.11.1: Idle session timeout (300s + 300s keep-alive = 600s total)
- ✅ NSA Sec 7.11.1: Key-based authentication only (PasswordAuthentication no)

## ⚙️ Configuration

### A. Strong Cipher Suite Configuration (NSA Sec 7.11.1)

**File:** `/etc/ssh/sshd_config.d/99-ciphers-hardened.conf`

```bash
# Strong Symmetric Ciphers Only
Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes128-gcm@openssh.com

# Strong Key Exchange Algorithms
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# Strong Message Authentication Codes
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# Strong Host Key Algorithms
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
```

**Security Details:**
- **Ciphers:** AES-256-GCM (256-bit authenticated encryption) + ChaCha20-Poly1305 fallback
- **KEX:** Elliptic curve (Curve25519, constant-time implementation) or DHE-SHA256 with 2048+ bits
- **MACs:** HMAC-SHA2-512-ETM (Encrypt-Then-MAC prevents oracle attacks)
- **Host Keys:** Ed25519 (elliptic curve, 128-bit equiv. security) preferred; RSA-SHA2-512 fallback

### B. Idle Session Timeout (NSA Sec 7.11.1)

**File:** `/etc/ssh/sshd_config.d/99-timeouts-hardened.conf`

```bash
ClientAliveInterval 300      # Send keep-alive every 300 seconds (5 minutes)
ClientAliveCountMax 2         # Disconnect after 2 missed responses = 600s total
```

**Behavior:** SSH server sends keep-alive packets every 5 minutes; if client doesn't respond to 2 consecutive packets (10 minutes elapsed), session is forcibly disconnected. Prevents stale/abandoned connections consuming resources.

### C. Main SSH Config

**File:** `/etc/ssh/sshd_config`

- Port 22022 (configurable via `$SSH_PORT` environment variable; can be overridden per profile)
- PermitRootLogin no
- PasswordAuthentication no (key-based only)
- PubkeyAuthentication yes
- UsePAM yes (integrates with PAM for account/session management)
- X11Forwarding no
- LogLevel VERBOSE (logs all authentication attempts to syslog, integrated with Module 10)

### D. Source-Based Access Control (NSA Sec 7.6)

**File:** `/etc/ssh/sshd_config.d/99-acl.conf`

The module creates two `Match Address` blocks for network-layer access control:

1. **Allow trusted subnets** (default: `192.168.1.0/24,10.0.0.0/8`):
   ```bash
   Match Address ${SSH_ALLOWED_SUBNETS}
       PubkeyAuthentication yes
       PasswordAuthentication no
       AuthenticationMethods publickey
   ```

   **Note:** `AuthenticationMethods publickey` enforces public-key-only authentication for matched addresses.

2. **Deny all others**:
   ```bash
   Match Address *
       DenyUsers *
   ```

**Configuration:** Set `$SSH_ALLOWED_SUBNETS` environment variable before module execution to customize trusted sources. Default denies all IPs outside the allowed subnets.

## 🔧 Prerequisites

- root access
- openssh-server installed (script installs if missing)
- systemctl available
- valid SSH host keys (auto-generated on Debian install)

## ♻️ Idempotency

✅ **Fully idempotent:**
- Re-running with same port is safe (no changes if already configured)
- Backup is created once and preserved
- sshd_config.d/ directory allows safe drop-in configs (no primary file overwrite)
- Validation re-checks all crypto specs and restarts service only if needed

## 📊 Validation

The script validates:
1. SSH config syntax (`sshd -t`)
2. Strong ciphers explicitly configured (AES-256-GCM present)
3. Idle timeout configured (ClientAliveInterval 300)
4. SSH service restarted successfully
5. SSH daemon is listening on configured port

**Test Command:**
```bash
bash tests/modules/04-ssh_config/validate.sh
```

## 🧯 Rollback

If configuration fails:
```bash
sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
sudo rm -f /etc/ssh/sshd_config.d/99-*.conf
sudo systemctl restart ssh
```

## 📝 Logging

- **Log File:** `/var/log/firstboot/04-ssh_config.log`
- **Format:** ISO8601 timestamp, log level, module ID, message
- **Integration:** SSH daemon logs all authentication attempts to syslog (LogLevel VERBOSE), forwarded to centralized rsyslog by Module 10

## 📚 References

- NSA Network Infrastructure Security Guide: Section 7.11.1 (Secure Shell Configuration)
- NIST SP 800-53: SC-13 (Cryptographic Protection)
- OpenSSH Manual: man 5 sshd_config

Logs are written to:
- `/var/log/firstboot/04-ssh_config.log`

## 🔗 Related modules
- **05-ssh_hardening** — advanced SSH security hardening (runs after 04-ssh_config)
