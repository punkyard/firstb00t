# 🔥 Firewall Configuration Module (5-firewall_config)

## Purpose

This module configures UFW (Uncomplicated Firewall) with NSA-compliant security hardening based on the selected deployment profile. It implements defense-in-depth with egress filtering, anti-spoofing protections (uRPF), and comprehensive logging for denied traffic.

**NSA Compliance:** Implements requirements from NSA Network Infrastructure Security Guide (U/OO/118623-22):
- Sec 2.1: Stateful firewall with deny-by-default egress filtering
- Sec 8.1: Unicast Reverse Path Forwarding (uRPF) anti-spoofing

## 🔗 Dependencies

- ufw: Uncomplicated Firewall (main package)
- systemctl: Service management
- openssh-server: SSH service (protected by default rules)
- iptables: Underlying firewall infrastructure
- sysctl: Kernel parameter configuration (for uRPF)

## ⚙️ Configuration

### NSA Security Enhancements (Module 5 Hardening)

**A. Egress Filtering (NSA Sec 2.1)**
   - Default deny outbound policy (blocks unauthorized data exfiltration)
   - Allow only essential services:
     - DNS (53/tcp, 53/udp)
     - HTTP/HTTPS (80/tcp, 443/tcp) — package updates
     - NTP (123/udp) — time synchronization
     - SMTP/Submission (25/tcp, 587/tcp) — mail relay

**B. Anti-Spoofing Protection (NSA Sec 8.1)**
   - Enables strict uRPF (Unicast Reverse Path Forwarding)
   - Kernel parameter: `net.ipv4.conf.all.rp_filter=1`
   - Validates source IP addresses (drops spoofed packets)
   - Persists across reboots via `/etc/sysctl.conf`

**C. ACL Logging (NSA Requirement)**
   - UFW logging level: medium
   - Logs denied traffic to `/var/log/ufw.log`
   - Enables security monitoring and incident response

### Profile-Specific Rules

A. **Basic Profile Rules**
   - Allow SSH (default port or $SSH_PORT)
   - Allow HTTP (port 80) — limited
   - Deny all other inbound by default
   - Egress filtering: DNS, HTTP/HTTPS, NTP, SMTP only

B. **Standard Profile Rules**
   - All Basic rules +
   - Allow HTTPS (port 443) — SSL/TLS services
   - Allow DNS (port 53) — DNS queries
   - Restrict SMTP (port 25) — outbound mail relay

C. **Advanced Profile Rules**
   - All Standard rules +
   - Custom per-application rules
   - Rate limiting on sensitive ports
   - Anti-DDoS configurations

### SSH Port Integration

- Reads `$SSH_PORT` environment variable (set by 0-profile_selection module)
- Defaults to port 22022 if variable not set
- Creates UFW rules for custom port (e.g., ufw allow 22022/tcp)

## 🚨 Error Handling

### Common Errors

A. UFW not installed
   - Cause: ufw package not present on system
   - Solution: apt-get install ufw (run before firewall config)
   - Prevention: Verify package installation in 1-system_updates module

B. SSH port blocked
   - Cause: Custom SSH port not added to UFW allowlist
   - Solution: Check $SSH_PORT env var; add rule explicitly
   - Prevention: Validate port variable before creating rules

C. Firewall enable failure
   - Cause: UFW service not running or permission denied
   - Solution: Check systemctl status ufw; verify root access
   - Prevention: Ensure service is enabled and active

D. Port already in use
   - Cause: Attempt to allow port already managed by another service
   - Solution: Check existing firewall rules; resolve conflicts
   - Prevention: Audit existing rules before applying new ones

## 🔄 Integration

### Input

- `$SSH_PORT` environment variable (custom SSH port from 0-profile_selection)
- UFW package installation status
- Current firewall rules (for conflict detection)
- Profile selection (.enabled markers)

### Output

- UFW enabled and running
- Inbound rules configured (allow SSH, HTTP/HTTPS, etc.)
- Outbound rules configured (allow updates, DNS, etc.)
- Status report in logs

### Module Interactions

- **Upstream**: 0-profile_selection (provides $SSH_PORT), 1-system_updates (installs ufw)
- **Downstream**: 6-fail2ban (integrates with UFW), 7-ssl_config (HTTPS rules), 8-dns_config (DNS rules)

## 📊 Validation

### Success Criteria

- UFW installed and enabled
- SSH port (custom or default) is explicitly allowed
- HTTP and/or HTTPS rules configured per profile
- Outbound rules permit system updates and DNS
- No critical ports unexpectedly blocked
- Firewall status shows "active" and correct rule count

### Performance Metrics

- Firewall enable time (typically < 5 seconds)
- Rule application latency per rule
- Outbound connection test success rate

### Validation Commands

```bash
ufw status
ufw status numbered
sudo iptables -L -n
netstat -tln | grep LISTEN
```

## 🧹 Cleanup

### Temporary Files

- None (UFW rules are persistent in /etc/ufw/)

### Configuration Files

- `/etc/ufw/before.rules` — Pre-processing rules
- `/etc/ufw/after.rules` — Post-processing rules
- `/etc/ufw/user.rules` — Custom user rules
- `/etc/ufw/user6.rules` — IPv6 user rules

### Backup & Recovery

- Backup location: `/var/log/firstboot/firewall-rules.bak`
- Restore procedure: `ufw reset && ufw reload` (destructive; restores defaults)
- Rollback: If module fails, disable UFW: `systemctl disable ufw`

## 📝 Logging

### Log Files

- `/var/log/firstboot/5-firewall_config.log` — Module actions and rule application
- `/var/log/ufw.log` — UFW activity and blocked packets
- Logs include: rules added, enable/disable events, blocked connections

### Log Levels

- INFO: Rule creation, UFW enable/disable events
- ERROR: Rule syntax errors, permission issues, service failures
- SUCCESS: All rules applied, firewall enabled

## 🔧 Maintenance

### Regular Tasks

- Review firewall logs for unexpected blocks (`/var/log/ufw.log`)
- Test connectivity on allowed ports (SSH, HTTP/HTTPS)
- Audit rules against current service needs
- Check UFW service status

### Typical Updates

- Add new ports as services added (e.g., custom app ports)
- Adjust rate limiting based on attack patterns
- Expand DNS/NTP allowlist if resolvers change
- Review and tighten outbound rules for advanced profiles

---

**Module Type:** Security configuration  
**Execution Order:** Fifth (5)  
**Profile Availability:** Basic, Standard, Advanced  
**Configuration:** Automatic based on profile selection  
**Service Integration:** SSH, UFW, iptables

