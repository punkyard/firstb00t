![](docs/punkyard-firstb00t.png)

# 🚀 Firstb00t — Enterprise-grade Debian Hardening

[![NSA Security Compliance](https://img.shields.io/badge/NSA%20Compliance-95%25-brightgreen)](https://media.defense.gov/2022/Jun/15/2003018261/-1/-1/0/CTR_NSA_NETWORK_INFRASTRUCTURE_SECURITY_GUIDE_20220615.PDF) 
[![Version](https://img.shields.io/badge/version-v1.0.0-blue)](https://github.com/punkyard/firstb00t/releases)
[![Status](https://img.shields.io/badge/status-Phase%204%20Complete-green)]()

**Firstb00t** is a modular, automated security setup for **Debian 12/13**. It converts a fresh VPS into a production-hardened infrastructure in minutes using a simple, guided workflow.

---

## 🎯 Technical specs (NSA compliance)

Firstb00t implements **95%+ compliance** (39 of 41 requirements) with the **NSA Network Infrastructure Security Guide**.

- ✅ **System**: Timeshift snapshots, mirror optimization, APT signature enforcement.
- ✅ **Users**: Root disabled, secure sudo admin creation, SSH key-only auth.
- ✅ **Network**: UFW deny-by-default, rate-limiting, custom SSH port (22022).
- ✅ **Privacy**: DNSSEC validation, log masking, encrypted backups.
- ✅ **Backup**: BorgBackup with deduplication, encryption, and automated retention.
- ✅ **Monitoring**: Fail2Ban, Logwatch, intrusion detection via OSSEC.

---

## 🚀 Quick start

**Run this single command on your local machine** (macOS, Linux, or WSL) to start the orchestration:

```bash
curl -O https://raw.githubusercontent.com/punkyard/firstb00t/main/firstb00t.sh && bash firstb00t.sh
```

### 🛠️ How it works
- **Step 1 (Local Helper)**: The script prepares your SSH keys and detects your public IPs for the firewall allowlist.
- **Step 2 (Scripted Handoff)**: The script manages the handoff and secure upload of the project to your VPS.
- **Step 3 (Automated Install)**: Instructions continue inside your terminal; you'll finish by running the bootstrap on the server as directed.

---

## 📂 Architecture & modules
- **modules/**: 13 idempotent security modules (safe to run multiple times).
- **tests/**: Production validation suite (run `bash tests/run_tests.sh`).
- **docs/**: Detailed [technical guides](modules/) for every component.

---

## ⏮️ Oops, something broke?
Don't panic. Each change we make has a backup and is **reversible**. 
- Rollback SSH: `sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config && sudo systemctl restart sshd`
- Disable Firewall: `sudo ufw disable`
- Full Logs: `/var/log/firstb00t/`

---

## 📜 License
Affero GNU General Public License v3 (AGPLv3).

---
*Built for production. Targeted at beginners and DevOps alike.*

<div align="center">
made with ⏳ by <a href="https://github.com/punkyard">punkyard</a>
</div>

