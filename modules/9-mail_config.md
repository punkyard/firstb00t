# 📧 Mail Configuration Module (9-mail_config)

## Purpose

This module configures Postfix as a mail server with SPF (Sender Policy Framework), DKIM (DomainKeys Identified Mail), and DMARC (Domain-based Message Authentication, Reporting, and Conformance) for secure and authenticated email delivery. It enables the system to send and receive mail securely.

## 🔗 Dependencies

- postfix: Mail transfer agent (main package)
- mailutils: Mail utilities (sendmail command)
- opendkim: DKIM signing service
- opendmarc: DMARC monitoring service
- systemctl: Service management
- openssl: Certificate generation for mail encryption
- DNS configuration: For MX, SPF, DKIM, DMARC records

## ⚙️ Configuration

### Mail Server Modes

A. **Relay Only** (Lightweight)
   - Forwards mail to upstream relay (e.g., Gmail, Mandrill)
   - No local mailbox delivery
   - Minimal resource usage
   - Requires relay host credentials

B. **Local Delivery** (Standard)
   - Accepts mail for local domains
   - Stores mail in mailbox files (/var/mail/)
   - Implements SPF, DKIM, DMARC
   - Requires valid DNS records

C. **Full Mail Server** (Advanced)
   - Dovecot IMAP/POP3 access
   - Virtual mailboxes with user management
   - Web-based mail interface (optional)
   - Full email ecosystem

### Authentication Mechanisms

A. **SPF (Sender Policy Framework)**
   - DNS TXT record specifying authorized mail servers
   - Format: `v=spf1 a mx -all` (basic)
   - Prevents spoofing; reduces spam

B. **DKIM (DomainKeys Identified Mail)**
   - Public key cryptography for message signing
   - Domain and selector-based keys
   - Generated in /etc/opendkim/keys/
   - Stored in DNS as TXT records

C. **DMARC (Domain-based Message Authentication)**
   - Policy enforcement and reporting
   - Specifies handling of failed authentication
   - Enables quarantine/reject policies
   - Provides forensic reports (optional)

## 🚨 Error Handling

### Common Errors

A. Postfix service fails to start
   - Cause: Configuration syntax error or port conflict
   - Solution: Check postfix main.cf syntax; verify port 25 available
   - Prevention: Test config with postfix -c /etc/postfix -d

B. DKIM signing failure
   - Cause: Key generation failure or OpenDKIM misconfiguration
   - Solution: Regenerate keys; check opendkim.conf permissions
   - Prevention: Ensure keys in correct location with proper permissions

C. DNS record propagation delay
   - Cause: SPF, DKIM, DMARC records not yet visible globally
   - Solution: Wait 24-48 hours; verify with nslookup or dig
   - Prevention: Create DNS records before enabling mail services

D. Mail delivery failure
   - Cause: Relay authentication failure, DNS issues, or spam filters
   - Solution: Check authentication credentials; verify DNS
   - Prevention: Test delivery to external domains; monitor bounce messages

## 🔄 Integration

### Input

- Domain name (from deployment configuration)
- Mail relay credentials (if relay mode)
- DKIM/SPF/DMARC policies
- DNS records (pre-configured)
- System certificates (from 7-ssl_config if available)

### Output

- Postfix service running and configured
- DKIM keys generated and published in DNS
- SPF record implemented (via DNS)
- DMARC policy configured (via DNS)
- Mail delivery logging enabled
- Status report in logs

### Module Interactions

- **Upstream**: 8-dns_config (DNS resolution), 7-ssl_config (optional TLS certificates)
- **Downstream**: 10-monitoring (mail log monitoring), external mail validation services

## 📊 Validation

### Success Criteria

- Postfix installed and enabled
- DKIM keys generated and DNS records published
- SPF record configured in DNS
- DMARC policy in place
- Test mail delivery successful to external domain
- DKIM signature verification passing (with mail providers)
- No postfix errors in logs
- Mail relay authentication working (if relay mode)

### Performance Metrics

- Postfix startup time (typically < 5 seconds)
- Mail delivery time (< 5 seconds local, < 30 seconds external)
- DKIM signing overhead (< 100ms per message)
- Queue processing time (< 1 minute for successful delivery)

### Validation Commands

```bash
systemctl status postfix
systemctl status opendkim
postqueue -p
mail-spf-check example.com
dig example.com TXT
dig default._domainkey.example.com TXT
openssl s_client -connect smtp.example.com:587 -starttls smtp
```

## 🧹 Cleanup

### Temporary Files

- `/tmp/postfix-*` — Temporary mail files
- `/var/spool/postfix/` — Mail queue directory (preserved)

### Configuration Files

- `/etc/postfix/main.cf` — Main Postfix configuration
- `/etc/postfix/master.cf` — Service definitions
- `/etc/opendkim/opendkim.conf` — OpenDKIM configuration
- `/etc/opendkim/keys/` — DKIM private keys (sensitive)
- `/etc/opendmarc/opendmarc.conf` — DMARC configuration

### Backup & Recovery

- Backup location: `/var/log/firstboot/mail-config.bak`
- DKIM keys: Keep encrypted backup in separate secure location
- Mail queue: Persisted in /var/spool/postfix/ (auto-retained on reboot)
- Recovery: Restore config files; regenerate DKIM keys if lost

## 📝 Logging

### Log Files

- `/var/log/firstboot/9-mail_config.log` — Module actions and configuration
- `/var/log/mail.log` — Postfix mail delivery events
- `/var/log/mail.err` — Postfix errors
- Logs include: relay configuration, DKIM setup, delivery status

### Log Levels

- INFO: Service startup, successful deliveries, configuration applied
- WARNING: Delivery delays, DNS lookup timeouts, authentication failures
- ERROR: Service startup failures, configuration errors, fatal delivery failures

## 🔧 Maintenance

### Regular Tasks

- Monitor mail queue for stuck messages: `postqueue -p`
- Check delivery logs for errors: `tail -f /var/log/mail.log`
- Verify DKIM/SPF/DMARC records still published
- Test external mail delivery monthly

### Typical Updates

- Update relay credentials if password changes
- Adjust mail routing rules for new domains
- Enable/disable TLS based on recipient requirements
- Rotate DKIM keys periodically (annually recommended)

### Troubleshooting

```bash
# Check mail queue
postqueue -p

# Flush mail queue (send waiting messages)
postqueue -f

# View specific mail
postcat -q <message-id>

# Test DKIM signature
opendkim-testkey -d example.com -s default

# Check Postfix configuration
postfix -c /etc/postfix -d

# Reload Postfix config
postfix reload
```

---

**Module Type:** Services — Communication  
**Execution Order:** Ninth (9)  
**Profile Availability:** Standard, Advanced  
**Configuration:** User input required (domain, relay settings)  
**Service Integration:** Postfix, OpenDKIM, OpenDMARC, DNS

