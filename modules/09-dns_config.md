# 🌐 DNS Configuration Module (8-dns_config)

## Purpose

This module configures DNS (Domain Name System) settings for secure and reliable domain resolution. It implements DNSSEC validation, configures DNS security policies, and ensures the system can reliably resolve domains for Let's Encrypt validation, package updates, and application connectivity.

## 🔗 Dependencies

- systemd-resolved: DNS resolver service (modern Debian default)
- resolvectl: DNS configuration tool
- dnsmasq or bind9: Optional DNS caching/forwarding (advanced)
- openssl: DNSSEC validation tools
- curl: DNS validation testing

## ⚙️ Configuration

### DNS Resolvers

A. **Default Configuration**
   - Uses systemd-resolved (Debian default)
   - Fallback resolvers: 8.8.8.8 (Google), 1.1.1.1 (Cloudflare)
   - DNSSEC: Enabled for validation
   - Cache: Enabled (improves performance)

B. **Privacy-Focused Configuration**
   - Primary: 1.1.1.1 (Cloudflare, privacy-first)
   - Fallback: 1.0.0.1 (Cloudflare secondary)
   - DNSSEC: Enabled
   - DoH/DoT: Optional (DNS over HTTPS/TLS)

C. **Custom Configuration**
   - User-specified resolvers
   - Internal DNS servers for private networks
   - Custom domain suffixes for internal resolution

### DNSSEC Settings

- Validation: Enabled (trust-anchor updates automatic)
- Negative trust anchor: Configurable for problematic domains
- Trust store: System CA certificates via /etc/ssl/certs/

## 🚨 Error Handling

### Common Errors

A. systemd-resolved service not running
   - Cause: Service stopped or disabled
   - Solution: systemctl restart systemd-resolved
   - Prevention: Ensure service enabled: systemctl enable systemd-resolved

B. DNS resolution failure
   - Cause: Network connectivity or resolver unreachable
   - Solution: Check network connection; try alternative resolvers
   - Prevention: Configure fallback resolvers; test connectivity

C. DNSSEC validation failure
   - Cause: Problematic domain or resolver issue
   - Solution: Temporarily disable DNSSEC; contact domain owner
   - Prevention: Add known problematic domains to negative trust anchor list

D. Let's Encrypt validation timeout
   - Cause: DNS propagation delay or resolver lag
   - Solution: Wait for DNS propagation; add longer delays
   - Prevention: Configure DNS well before requesting certificates

## 🔄 Integration

### Input

- Network connectivity status
- Domain names (from deployment configuration)
- DNS resolver preferences (user configuration)
- DNSSEC policy settings

### Output

- systemd-resolved configured and running
- DNS resolvers set and tested
- DNSSEC validation enabled
- DNS resolution working for all critical domains
- Status report in logs

### Module Interactions

- **Upstream**: 5-firewall_config (DNS port 53 allowed), network configuration
- **Downstream**: 7-ssl_config (domain resolution for Let's Encrypt), 9-mail_config (MX record resolution), 10-monitoring (DNS logging)

## 📊 Validation

### Success Criteria

- systemd-resolved running and enabled
- DNS resolvers responding
- DNSSEC validation working
- Public domain resolution successful
- Let's Encrypt domain validation working
- No DNS resolution timeouts (< 2 seconds)
- Fallback resolvers functioning

### Performance Metrics

- DNS query response time (< 100ms typical)
- Cache hit rate (80%+ expected after warmup)
- DNSSEC validation overhead (< 50ms)

### Validation Commands

```bash
systemctl status systemd-resolved
resolvectl status
nslookup example.com
dig example.com +dnssec
systemctl status systemd-resolved
tail -f /var/log/systemd/resolved.log
```

## 🧹 Cleanup

### Temporary Files

- None (DNS configuration is persistent)

### Configuration Files

- `/etc/systemd/resolved.conf` — Main DNS configuration
- `/etc/resolv.conf` — Symlink to systemd-resolved runtime configuration (auto-generated)
- `/etc/systemd/resolved.conf.d/` — Directory for additional configurations
- `/var/cache/systemd/resolved/` — DNS cache (auto-managed)

### Backup & Recovery

- Backup location: `/var/log/firstboot/dns-config.bak`
- Recovery: Restore /etc/systemd/resolved.conf and restart service
- Reset to defaults: Remove custom config; restart systemd-resolved

## 📝 Logging

### Log Files

- `/var/log/firstboot/8-dns_config.log` — Module actions and configuration
- `/var/log/systemd/resolved.log` — DNS resolver activity and queries
- Logs include: resolver configuration, DNSSEC status, query results

### Log Levels

- INFO: Resolver configuration, successful resolutions
- WARNING: Slow resolution, DNSSEC issues, fallback resolver usage
- ERROR: Resolution failure, service startup failure

## 🔧 Maintenance

### Regular Tasks

- Monitor DNS query performance (check logs weekly)
- Verify DNSSEC validation still working (test with dig +dnssec)
- Test Let's Encrypt domain validation (if using SSL module)
- Check resolver responsiveness

### Typical Updates

- Change DNS resolvers if primary becomes unreliable
- Add domain suffixes for new internal networks
- Disable DNSSEC if problematic (not recommended)
- Update negative trust anchor list as needed

### DNS Testing

```bash
# Resolve domain with DNSSEC validation
dig example.com +dnssec

# Test specific resolver
dig @8.8.8.8 example.com

# Check cache effectiveness
systemd-resolve --statistics

# Flush DNS cache
systemctl restart systemd-resolved
```

---

**Module Type:** Networking — Infrastructure  
**Execution Order:** Eighth (8)  
**Profile Availability:** Standard, Advanced  
**Configuration:** Automatic with optional user overrides  
**Service Integration:** systemd-resolved, DNSSEC, network services

