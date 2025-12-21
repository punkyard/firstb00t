# 🔐 SSH configuration module (3-ssh_config)

## 🎯 Description
Configures basic SSH parameters with user-selectable port. Sets up secure defaults including:
- SSH port configuration (from `$SSH_PORT` environment variable, default 22022)
- key-based authentication enforcement
- root login disabled
- strong security settings

## ⚙️ Configuration

The module references the `SSH_PORT` environment variable set during profile selection. Default: `22022`.

### Port selection

- user is prompted during profile selection
- valid range: 1024–65535
- default: 22022 (commonly used secure port)
- stored in: `/etc/firstboot/ssh_port`

## 🔧 Prerequisites

- root access
- SSH daemon (`sshd`) installed
- `systemctl` available

## ♻️ Idempotency

The module is idempotent:
- re-running checks if backup exists before creating one
- re-running with same port is safe (no changes if already configured)
- re-running with different port updates configuration

## 📊 Validation

Verifies:
A. SSH config syntax (`sshd -t`)
B. SSH service is active
C. service restarted successfully

## 🧯 Rollback

Manual rollback if needed:
```bash
sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
sudo systemctl restart ssh
```

## 📝 Logging

Logs are written to:
- `/var/log/firstboot/3-ssh_config.log`

## 🔗 Related modules
- **4-ssh_hardening** — advanced SSH security hardening (runs after 3-ssh_config)
