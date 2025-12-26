# ✨ Module features & descriptions

## 🎯 Core modules

### 0-profile_selection
**Select security profile** — Choose between Basic, Standard, and Advanced security configurations. Also prompts for SSH port selection (default 22022). Saves profile choice and SSH port for use by other modules.

### 1-system_updates
**Automated Debian package updates** — Updates package lists and installs latest security patches. Uses apt-get to ensure system is current before deploying other security modules.

### 2-user_management
**Create sudo user** — Disables root login and creates a new non-root user with sudo access. Enforces strong password policies and secure account setup.

### 3-ssh_config
**Basic SSH configuration** — Configures SSH with user-selected port (references `$SSH_PORT` env var). Sets up key-based authentication enforcement and disables password auth.

### 4-ssh_hardening
**Advanced SSH hardening** — Applies strict SSH security policies including disabled X11 forwarding, restricted authentication attempts, and enhanced logging. Works with 3-ssh_config for comprehensive SSH security.

---

## 🔒 Security features

### 5-firewall_config
**UFW firewall rules** — Configures uncomplicated firewall (UFW) with deny-all-incoming default. Opens only SSH (on configured port) and HTTP/HTTPS. Supports Basic/Standard/Advanced rule sets.

### 6-fail2ban
**Brute-force protection** — Monitors SSH and HTTP logs, automatically blocks IPs after failed login attempts. Provides intrusion detection for production servers.

### 7-ssl_config
**SSL/TLS certificate management** — Manages X.509 certificates and HTTPS configuration. Supports auto-renewal of Let's Encrypt certificates for web services.

### 8-dns_config
**DNS security** — Configures secure DNS resolver with DNSSEC validation. Hardens DNS settings to prevent DNS hijacking and cache poisoning.

### 9-mail_config
**Postfix mail server** — Sets up Postfix for secure mail delivery. Integrates SPF, DKIM, and DMARC for email authentication. Supports relay configuration for VPS deployments.

---

## 🛠️ Operational features

### 10-monitoring
**System monitoring & logging** — Configures Logwatch for log analysis and alerts. Sets up log rotation and basic system monitoring. Provides audit trails for all module execution.

---

## 📊 Full feature matrix

| Feature | Basic | Standard | Advanced |
|---------|:-----:|:--------:|:--------:|
| System Updates | ✅ | ✅ | ✅ |
| User Management | ✅ | ✅ | ✅ |
| SSH Config | ✅ | ✅ | ✅ |
| SSH Hardening | ✅ | ✅ | ✅ |
| Firewall (UFW) | ✅ | ✅ | ✅ |
| Fail2Ban | ❌ | ✅ | ✅ |
| SSL/TLS | ❌ | ✅ | ✅ |
| DNS Security | ❌ | ✅ | ✅ |
| Mail (Postfix) | ❌ | ✅ | ✅ |
| Monitoring | ✅ | ✅ | ✅ |
