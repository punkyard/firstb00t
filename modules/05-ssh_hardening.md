# 🛡️ SSH hardening module (4-ssh_hardening)

## 🎯 Purpose

Applies advanced SSH security hardening on top of basic configuration. Disables dangerous features and enforces strict authentication policies.

## 🔗 Dependencies

- `sshd` — SSH service
- `systemctl` — service management

## ⚙️ Configuration

### Required settings

- **port** — user-configurable via `$SSH_PORT` environment variable (default 22022)
- **protocol** — version 2 only
- **authentication** — public key only, no passwords
- **root login** — disabled

### Security features

- banner: `/etc/issue.net`
- timeout: 300 seconds
- max sessions: 2
- max auth tries: 3
- agent forwarding: disabled
- TCP forwarding: disabled

## 🚨 Error handling

### Common errors

A. invalid SSH configuration
   - cause: incorrect syntax in sshd_config
   - solution: check syntax and correct
   - prevention: test syntax before restart

B. service inactive
   - cause: restart failed
   - solution: check logs and restart
   - prevention: verify status after restart

C. unavailable port
   - cause: port already in use
   - solution: change port or release it
   - prevention: check port availability

### Recovery procedures

A. restore configuration:
   ```bash
   sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
   sudo systemctl restart ssh
   ```

B. verify service:
   ```bash
   sudo systemctl status ssh
   sudo sshd -t
   ```

C. test connection:
   ```bash
   ssh -p <SSH_PORT> user@localhost
   ```


## 🔄 Integration

### Input

- file /etc/ssh/sshd_config
- service sshd

### Output

- secured SSH configuration
- SSH service restarted
- SSH port modified

## 📊 Validation

### Success criteria

- valid SSH configuration
- SSH service active
- port 22222 open
- key-based authentication only

### Performance metrics

- service restart time
- connection time
- resource utilization

## 🧹 Cleanup

### Temporary files

- /etc/ssh/sshd_config.bak: configuration backup

### Configuration files

- /etc/ssh/sshd_config: SSH configuration
- /etc/issue.net: SSH banner

## 📝 Logging

### Log files

- /var/log/firstboot_script.log: module actions
- /var/log/auth.log: SSH logs

### Log levels

- info: normal actions
- error: detected problems
- success: successful operations

## 🔧 Maintenance

### Regular tasks

- verify logs
- verify connections
- update keys

### Updates

- update security parameters
- update firewall rules
- update keys 