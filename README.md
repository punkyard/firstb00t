# 🚀 Firstb00t — your Debian server's first safe steps

Welcome! **Firstb00t** is an automated security setup for your brand-new Debian server. 

Think of it as a trusted checklist that runs on your first day with a new VPS — making sure everything is locked down and secure, without you needing to be a Linux expert.

---

## 💡 What Is This?

You just spun up a fresh Debian server (on Contabo, Linode, DigitalOcean, or anywhere else). Before you deploy your app, you need to:

- ✅ Update the system (security patches)
- ✅ Create a secure login (not root)
- ✅ Harden SSH (stronger protection)
- ✅ Set up a firewall (block bad traffic)
- ✅ Monitor what's happening (logs & alerts)

**Firstb00t does all this automatically**, safely, and the right way. No scary commands. No guessing. Just run it, answer a few questions, and you're done.

---

## 🎯 Who Is This For?

- 🟢 **Beginners**: First server? No problem. We handle the hard stuff.
- 🟡 **Small teams**: Deploy consistently across multiple servers.
- 🟢 **DevOps engineers**: Reproducible, auditable, idempotent.

**You don't need to be a Linux expert.** If you can copy-paste commands and say yes to a few prompts, you're good.

---

## 🚀 Quick Start (5 Minutes)

<details>
<summary>📖 <strong>click to expand SSH connection guide</strong></summary>

### Step 1: Connect to Your Server

**get your VPS credentials** from your provider (contabo, digitalocean, linode, etc.):
- 🔑 IP address (e.g., `203.0.113.42`)
- 🔑 root password or SSH key
- 📖 consult provider dashboard for connection details

**open terminal on your computer:**

**🪟 windows** (powershell or command prompt):
```powershell
ssh root@YOUR_VPS_IP
# example: ssh root@203.0.113.42
```

**🍎 macOS** (terminal app):
```bash
ssh root@YOUR_VPS_IP
# example: ssh root@203.0.113.42
```

**🐧 linux** (any terminal):
```bash
ssh root@YOUR_VPS_IP
# example: ssh root@203.0.113.42
```

**first-time connection:** type `yes` when asked about fingerprint verification

</details>

### Step 2: Download & Run
```bash
# Download the script
curl -O https://raw.githubusercontent.com/punkyard/firstb00t/main/debian-firstb00t.sh

# Make it runnable
chmod +x debian-firstb00t.sh

# Run it
bash debian-firstb00t.sh
```

### Step 3: Answer Questions
The script will ask you:
- 🔹 **Which security level?** (Basic / Standard / Advanced)
  - **Basic** = essentials (everyone needs this)
  - **Standard** = production-ready (add email, SSL)
  - **Advanced** = maximum security (intrusion detection)
- 🔹 **What username for your login?** (e.g., `admin`)
- 🔹 **SSH public key?** (paste your key for passwordless login)

That's it. The script does the rest.

---

## 📊 What Gets Installed?

### Basic Security (All Servers)
- **System Updates** — Latest security patches
- **User Management** — Create a safe login (non-root)
- **SSH Hardening** — Stronger, safer remote access (port 22222)
- **Firewall (UFW)** — Block bad traffic automatically
- **Monitoring** — Watch for problems and log everything

### Standard (Production Servers)
All Basic, plus:
- **Fail2Ban** — Block brute-force attacks
- **SSL/TLS** — Certificates for HTTPS
- **DNS Security** — Safer domain lookups
- **Mail Setup** — Secure email (if you need it)

### Advanced (High-Security)
All Standard, plus:
- **Intrusion Detection** — OSSEC watches 24/7
- **App Armor** — Extra container/app protection
- **Custom Hardening** — For experts

---

## ✅ After It Finishes

### Test Your New Login
```bash
# SSH on the new port (22222)
ssh -p 22222 admin@your-server-ip
```

### Check The Firewall
```bash
sudo ufw status
```

### View The Logs
```bash
# Everything that happened is logged here:
less /var/log/firstboot/system_updates.log
less /var/log/firstboot/ssh_hardening.log
less /var/log/firstboot/firewall.log
```

---

## 🛡️ Security Features (Explained Simply)

<details>
<summary>📚 <strong>click to see security features explained</strong></summary>

For detailed feature descriptions and module documentation, see [modules-features.md](modules-features.md)

### 1. **System Updates**
We get all the latest security patches — like Windows Update, but for Linux.

### 2. **User Management**
Root is the "superuser" — dangerous to use every day. We create a safer daily user for you.

### 3. **SSH Hardening**
- move SSH to a custom port (port 22022 instead of 22)
- require SSH keys (not passwords — much safer)
- disable direct root login
- disable outdated login methods

### 4. **Firewall (UFW)**
Think of it as a bouncer at a club. By default, no one gets in. Only traffic we explicitly allow (SSH, HTTP, HTTPS) gets through.

### 5. **Fail2Ban** (Standard+)
If someone tries to guess your password 5 times, they get blocked automatically for 10 minutes. Stops brute-force attacks.

### 6. **Monitoring**
Logs everything that happens. If something goes wrong, you can see what happened.

</details>

---

## ⏮️ Oops, Something Broke?

<details>
<summary>🔧 <strong>click for rollback & troubleshooting guide</strong></summary>

Don't panic. Everything is **reversible**. Each change we make has a backup:

```bash
# See what went wrong
less /var/log/firstboot/firewall.log

# Rollback SSH hardening (if you're locked out)
sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
sudo systemctl restart sshd

# Disable the firewall (emergency only)
sudo ufw disable
```

**Still stuck?** Open an issue on GitHub. We'll respond. 🙂

</details>

---

## 🔄 Can I run it again?

<details>
<summary>🔁 <strong>click to learn about idempotence</strong></summary>

Yes! The script is **idempotent** — that means:
- ✅ run it once = secure server
- ✅ run it twice = same secure server (nothing breaks)
- ✅ run it with different settings = updates safely

You can update your firewall rules, add a new user, change things — just re-run the script.

</details>

---

## 📚 Learn more

- **Module Docs** — See `github/modules/` for what each step does
- **Testing** — See `tests/` for how we validate everything
- **Development** — See `.github/specs/` for the roadmap

---

## 🐛 Found a Bug?

<details>
<summary>📖 <strong>click for issue reporting guide</strong></summary>

- **problems during setup?** [open an issue](https://github.com/punkyard/firstb00t/issues)
- **have an idea?** [suggest it in discussions](https://github.com/punkyard/firstb00t/discussions)
- **roadmap?** check [github issues](https://github.com/punkyard/firstb00t/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement) for planned features

**issue template:** include
1. OS/VPS provider used
2. what happened
3. what you expected
4. log output from `/var/log/firstboot/`

</details>

---

This project is free software. You can use, modify, and redistribute it freely — as long as you share any improvements back with the community.

<div align="center">

GNU Affero General Public License v3 (AGPLv3) — see [LICENSE](./LICENSE)</br>

made with ⏳ by <a href="https://github.com/punkyard">punkyard

</div>

