# 🛡️ Fail2ban Module (07-fail2ban)

## Purpose

This module installs and configures Fail2ban, an intrusion-prevention framework that monitors system logs and automatically blocks IP addresses attempting unauthorized access. It provides protection against brute-force SSH attacks and HTTP-based attacks.

## 🔗 Dependencies

- fail2ban: Intrusion prevention system
- systemctl: Service management
- iptables: Firewall infrastructure (for ban/unban actions)
- openssh-server: SSH service (primary protected service)
- logwatch: Log monitoring (optional, for integration)

## ⚙️ Configuration

### Protected Services

A. **SSH Protection** (always enabled)
   - Monitors: `/var/log/auth.log` for failed login attempts
   - Ban trigger: 5 failed attempts within 10 minutes
   - Ban duration: 10 minutes initial, escalating on repeat offenders
   - Whitelist: localhost (127.0.0.1), loopback
   - Integration: reads `/etc/firstboot/ssh_allowlist` (if present) and sets `ignoreip` accordingly; uses `$SSH_PORT` for jail port configuration

B. **HTTP/HTTPS Protection** (Standard+ profiles)
   - Monitors: `/var/log/apache2/error.log` (if Apache present)
   - Ban trigger: 5 HTTP errors (403, 404, 500) within 5 minutes
   - Ban duration: 5-60 minutes depending on offense count

C. **Custom Rules** (Advanced profile)
   - Additional jail configurations
   - Custom ban durations and thresholds
   - Integration with application-specific logs

### Ban Actions

- Default: iptables-multiport (blocks all ports to offending IP)
- Escalation: Extended ban duration for repeat offenders
- Whitelist: System administrator IPs and trusted networks
- Logging: All ban/unban events to `/var/log/fail2ban.log`

## 🚨 Error Handling

### Common Errors

A. Fail2ban service fails to start
   - Cause: Configuration syntax error or permission issue
   - Solution: Check fail2ban.log; validate jail configs with fail2ban-client
   - Prevention: Test config before service restart

B. iptables integration failure
   - Cause: iptables rules not properly applied or firewall conflict
   - Solution: Verify UFW not conflicting; check iptables rules with iptables -L
   - Prevention: Ensure 5-firewall_config module runs before this module

C. Log file not found
   - Cause: Service logs to different location or log file doesn't exist
   - Solution: Update jail paths to match actual log locations
   - Prevention: Verify service log locations before configuring jails

D. Ban persistence across reboots
   - Cause: iptables rules lost on reboot if not properly persisted
   - Solution: Use iptables-persistent or fail2ban persistent configuration
   - Prevention: Enable fail2ban service on boot; use recidive jail for long-term bans

## 🔄 Integration

### Input

- UFW firewall rules (from 5-firewall_config)
- System logs: `/var/log/auth.log`, `/var/log/apache2/error.log`
- iptables infrastructure
- Service configurations (SSH, HTTP/HTTPS from 3-ssh_config, 7-ssl_config)

### Output

- Fail2ban service running and enabled
- Jails configured and active (ssh, httpd, recidive)
- Ban/unban events logged to `/var/log/fail2ban.log`
- iptables rules updated with bans

### Module Interactions

- **Upstream**: 5-firewall_config (UFW foundation), 3-ssh_config (SSH protection), 7-ssl_config (HTTPS protection)
- **Downstream**: 10-monitoring (logs ban events), 7-dns_config (optional DNS protection)

## 📊 Validation

### Success Criteria

- Fail2ban installed and enabled
- At least 1 jail configured and active (ssh is mandatory)
- fail2ban service running without errors
- iptables rules properly applied for bans
- Log file `/var/log/fail2ban.log` being written
- Test login attempts properly logged and counted

### Performance Metrics

- Fail2ban startup time (typically < 5 seconds)
- Jail initialization time
- Ban/unban rule application latency
- Memory footprint (typically < 20MB)

### Validation Commands

```bash
systemctl status fail2ban
fail2ban-client status
fail2ban-client status sshd
sudo iptables -L -n | grep FAIL2BAN
tail -f /var/log/fail2ban.log
```

## 🧹 Cleanup

### Temporary Files

- None (ban rules are dynamic in iptables)

### Configuration Files

- `/etc/fail2ban/jail.local` — Custom jail configurations (preserves settings)
- `/etc/fail2ban/filter.d/` — Filter definitions (regex patterns for log analysis)
- `/etc/fail2ban/action.d/` — Action definitions (ban/unban scripts)

### Backup & Recovery

- Backup location: `/var/log/firstboot/fail2ban-config.bak`
- Ban database: Stored in iptables; cleared on service stop/restart
- Unban procedure: `fail2ban-client set <jail> unbanip <IP>` or restart service

### Safe Unban

```bash
# Unban specific IP from SSH jail
sudo fail2ban-client set sshd unbanip 192.168.1.100

# Unban all IPs from all jails
sudo fail2ban-client reset all
```

## 📝 Logging

### Log Files

- `/var/log/fail2ban.log` — Fail2ban actions and jail status
- `/var/log/firstboot/07-fail2ban.log` — Module installation and configuration
- `/var/log/auth.log` — SSH login attempts (monitored by fail2ban)

### Log Levels

- INFO: Jail start/stop, ban events, unban events
- NOTICE: IP banned, repeated offenders escalated
- ERROR: Configuration errors, permission issues
- WARNING: Low thresholds triggering frequent bans

## 🔧 Maintenance

### Regular Tasks

- Monitor `/var/log/fail2ban.log` for excessive bans (false positives)
- Review banned IP list: `fail2ban-client status <jail>`
- Check recidive jail (persistent offenders) regularly
- Validate jail configurations remain accurate

### Typical Updates

- Adjust ban thresholds if too many/few bans occurring
- Add new jails for new services (e.g., custom app ports)
- Expand whitelist with trusted networks
- Integrate new log sources for additional protection

### Troubleshooting

- If legitimate user IP blocked: Manual unban with command above
- If no bans occurring: Verify log paths and filter regex
- If service won't start: Check configuration syntax with fail2ban-client -c /etc/fail2ban
- If high CPU: Reduce filter regex complexity or increase scan interval

---

**Module Type:** Security — Intrusion prevention  
**Execution Order:** Seventh (7)  
**Profile Availability:** Standard, Advanced  
**Configuration:** Automatic with profile-specific rules  
**Service Integration:** SSH, HTTP/HTTPS, iptables, UFW

