# firstb00t

Hardening script for fresh Linux servers
linux, bash, debian, server, script, bash-script, firstboot

# 🚧 Work in progress.

## Purpose

These `*-firstb00t.sh` scripts harden Linux servers on their very first boot from a single ssh-command run by `root` or `sudo` user.

## What it does

1. `apt-get update` → install `sudo`
2. create sudo admin user → switch to sudo admin user
3. set hostname + timezone
4. install `nala`
5. choose set up a **firewall** (UFW or nftables)
6. **SSH hardening**: `PermitRootLogin No`, `SSH Port` → reload sshd
7. install **Fail2Ban**: whitelist admin IP, forever jail attempts on port 22

**Optional — install only if chosen:**
8. **FTP** — skip or install and configure
10. `unattended-upgrades` for ...
11. AppArmor for ...
12. rkhunter for
13. container engine: Docker CE or Podman → set volumes path to `/srv/containers`

14. Add SSH public key for admin user - forever jail attempts without a key
15. Print summary and test commands


## Repository contents

- `debian-firstb00t.sh` — main hardening script
- `README.md` — project overview


## Quick start

Run this on your server at first boot as root:

```sh
wget -qO- https://raw.githubusercontent.com/punkyard/firstb00t/main/origin/debian-firstb00t.sh | bash
```

Requirements:

- Debian server with network access
- root shell or root SSH login
- `bash` available (default on Debian)

### Options

1. run the script and answer qestions along
2. duplicate the .env.sample file and pre-fill your answers to these questions and let the script run automatically

