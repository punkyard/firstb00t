# 🔒 SSL/TLS Configuration Module (7-ssl_config)

## Purpose

This module enforces NIST SP 800-52 Rev 2 compliant TLS configuration for all services (Apache, Nginx, Postfix). It implements TLS 1.2/1.3 with strong ciphers, Perfect Forward Secrecy (PFS), HSTS headers, and disables all weak protocols and ciphers.

**Security Standards:**
- NIST SP 800-52 Rev 2: Guidelines for TLS Implementations
- OWASP A02:2021 Cryptographic Failures
- NSA requirement: TLS 1.2+ mandatory, disable SSLv2/v3/TLS1.0/1.1

## 🔗 Dependencies

- openssl: SSL/TLS toolkit (certificate and key generation)
- certbot: Let's Encrypt client (for automatic certificate management)
- apache2 or nginx: Web server with TLS support
- postfix: SMTP server (optional, for mail TLS enforcement)
- systemctl: Service management
- curl/wget: Certificate validation and retrieval

## ⚙️ Configuration

### NIST SP 800-52 Compliance

**A. Protocol Version Enforcement**
   - **Enabled:** TLS 1.2, TLS 1.3
   - **Disabled:** SSLv2, SSLv3, TLS 1.0, TLS 1.1
   - Configuration: `SSLProtocol -all +TLSv1.2 +TLSv1.3` (Apache) / `ssl_protocols TLSv1.2 TLSv1.3;` (Nginx)

**B. Strong Cipher Suites (PFS-only)**
   - ECDHE-ECDSA-AES256-GCM-SHA384 (priority: elliptic curve)
   - ECDHE-RSA-AES256-GCM-SHA384 (priority: RSA)
   - ECDHE-ECDSA/RSA-CHACHA20-POLY1305 (modern, fast)
   - DHE-RSA-AES256-GCM-SHA384 (fallback: Diffie-Hellman)
   - ❌ Disabled: DES, 3DES, RC4, NULL, EXPORT ciphers
   - ❌ Disabled: Non-PFS ciphers (no RSA key transport)

**C. Perfect Forward Secrecy (PFS)**
   - All ciphers use ECDHE (preferred) or DHE (fallback)
   - Session tickets disabled (`SSLSessionTickets off`)
   - Session cache used instead (stateless, replay-resistant)
   - DHParam: 2048-bit for DH ciphers

**D. HTTP Strict-Transport-Security (HSTS)**
   - `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
   - Forces browsers to HTTPS for 1 year
   - Prevents downgrade attacks (MITM stripping HTTPS)
   - Enables HSTS preload list inclusion

**E. Certificate Validation (OCSP Stapling)**
   - OCSP stapling enabled (certificate freshness verification)
   - Resolver: 8.8.8.8 (Google DNS) for OCSP checks
   - Prevents client certificate revocation checks

**F. Security Headers**
   - X-Frame-Options: DENY (prevent clickjacking)
   - X-Content-Type-Options: nosniff (prevent MIME type sniffing)
   - Content-Security-Policy: `default-src 'self'; upgrade-insecure-requests` (XSS/injection defense)

### Postfix SMTP TLS (Module 7 Extension)

- **Mandatory TLS:** `smtpd_tls_security_level=encrypt` (enforce encrypted SMTP)
- **Outbound TLS:** `smtp_tls_security_level=encrypt` (relay to other MTAs)
- **Weak protocol disabled:** Blocks SSLv2, SSLv3, TLS 1.0/1.1
- Prevents plaintext SMTP auth and credential exposure

## 🚨 Error Handling

### Common Errors

A. Certificate generation failure
   - Cause: openssl not installed or permission denied
   - Solution: Verify openssl installed; check /etc/ssl/ permissions
   - Prevention: Ensure openssl installed by 1-system_updates

B. Let's Encrypt validation failure
   - Cause: Domain not reachable or DNS not configured
   - Solution: Verify domain registration and DNS pointing to server
   - Prevention: Run DNS configuration (7-dns_config) before requesting Let's Encrypt cert

C. Certificate expiry
   - Cause: Self-signed cert reached end-of-life or renewal failed
   - Solution: Manual regeneration or Let's Encrypt renewal
   - Prevention: Enable automatic renewal; set expiry alerts

D. Private key exposure
   - Cause: Key file permissions too permissive
   - Solution: Correct file permissions: chmod 600 on private keys
   - Prevention: Enforce 0600 permissions on key generation

## 🔄 Integration

### Input

- Domain configuration (from deployment settings or user input)
- Certificate type selection (self-signed, Let's Encrypt, or custom)
- DNS configuration (if using Let's Encrypt validation)
- Existing certificates (for validation and reuse)

### Output

- SSL/TLS certificates and keys installed
- Web server configured for HTTPS
- Certificate renewal automation enabled (if Let's Encrypt)
- Status report in logs

### Module Interactions

- **Upstream**: 8-dns_config (DNS must be correct for Let's Encrypt), 5-firewall_config (port 443 allowed)
- **Downstream**: Web applications using HTTPS, 10-monitoring (certificate expiry monitoring)

## 📊 Validation

### Success Criteria

- Certificate installed at correct path
- Private key has 0600 permissions
- HTTPS accessible on port 443
- Certificate chain valid and trusted (for Let's Encrypt)
- Self-signed cert properly generated (if applicable)
- TLS 1.2+ enforced
- Certificate expiry date logged

### Performance Metrics

- Certificate generation time (< 30 seconds for self-signed)
- Let's Encrypt validation time (< 2 minutes)
- HTTPS connection establishment time (< 1 second)

### Validation Commands

```bash
openssl s_client -connect localhost:443
openssl x509 -in /path/to/cert -text -noout
certbot certificates
systemctl status certbot.timer
```

## 🧹 Cleanup

### Temporary Files

- `/tmp/ssl-*` — Temporary certificate files during generation
- Cleaned up automatically after successful installation

### Configuration Files

- `/etc/ssl/certs/` — Public certificates (readable by all)
- `/etc/ssl/private/` — Private keys (readable by root only)
- `/etc/letsencrypt/` — Let's Encrypt certificates and configs
- Web server config: `/etc/apache2/sites-enabled/*.conf` or `/etc/nginx/sites-enabled/*`

### Backup & Recovery

- Backup location: `/var/log/firstboot/ssl-certs.bak`
- Private key backup: Never store in logs; keep separate secure location
- Recovery: Restore from backup or regenerate certificate

## 📝 Logging

### Log Files

- `/var/log/firstboot/7-ssl_config.log` — Module actions and certificate installation
- `/var/log/certbot.log` — Let's Encrypt operations and renewals
- Logs include: certificate type, domain, validity dates, renewal status

### Log Levels

- INFO: Certificate generation, installation, renewal successful
- WARNING: Certificate near expiry, renewal approaching
- ERROR: Generation failure, permission issues, domain validation failure

## 🔧 Maintenance

### Regular Tasks

- Monitor certificate expiry dates (automated by Let's Encrypt)
- Test HTTPS connectivity monthly
- Review TLS version enforcement
- Check cipher suite compatibility with clients

### Typical Updates

- Renew self-signed certificates annually (manual)
- Update domain list for Let's Encrypt (if using)
- Adjust TLS version minimums based on client requirements
- Enable/disable legacy cipher suites as needed

### Certificate Renewal

```bash
# Manual Let's Encrypt renewal
sudo certbot renew --force-renewal

# Check renewal status
sudo systemctl status certbot.timer

# View certificates
sudo certbot certificates

# Remove certificate (if needed)
sudo certbot revoke --cert-path /path/to/cert
```

---

**Module Type:** Security — Encryption  
**Execution Order:** Seventh (7)  
**Profile Availability:** Standard, Advanced  
**Configuration:** User input required (domain, cert type)  
**Service Integration:** Web servers, HTTPS, TLS protocols

