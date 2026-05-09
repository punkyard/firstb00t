# firstb00t

Hardening script for fresh Linux servers
linux, bash, debian, server, script, bash-script, firstboot

# 🚧 Work in progress.

## Purpose

These `*-firstb00t.sh` scripts harden Linux servers on their very first boot from a single ssh-command run by `root` or `sudo` user.

## What it does

All major steps are prompted (confirm before action) in this order:

0. check root + Debian compatibility (12/13), network check
1. bootstrap apt: `apt-get update` + install `sudo` + `wget` (installs wget if missing)
2. create/verify sudo admin user
3. set hostname + timezone
4. install `nala` (then use `nala` for remaining package installs)
5. install baseline tools (`curl`, `btop`)
6. firewall + SSH port prompt:
	- choose backend: UFW or nftables
	- choose SSH port
	- optional keep port `22` as honeypot when using custom port
7. SSH hardening: `PermitRootLogin no`, optional `PasswordAuthentication no`, `AllowUsers`, SSH reload
8. Fail2Ban setup:
	- auto-detect SSH client IP for whitelist
	- prompt for extra whitelist IP/CIDRs (local/public)
	- forever ban (`bantime=-1`) with whitelist safety net
9. optional security services:
	- unattended-upgrades
	- AppArmor
	- rkhunter
10. FTP policy prompt (skip or configure)
11. optional container engine:
	- Docker CE (installs `ca-certificates` + `gnupg` only when needed for Docker repo)
	- or Podman
	- prompt volume root folder for bind-mounts/backup (default `/mnt/docker/volumes`; Docker images stay in `/var/lib/docker`)
12. add admin SSH public key (idempotent; no duplicate key lines)
13. print summary + suggested `btop` usage


## Repository contents

- `debian-firstb00t.sh` — main hardening script
- `README.md` — project overview


## Quick start

Run the appropriate command on your server at first boot as root.

For Debian 10, 11, 12, 13:
```sh
wget -qO- https://raw.githubusercontent.com/punkyard/firstb00t/main/debian-firstb00t.sh | bash
```

Requirements:

- Debian 12 or 13 server with network access
- root shell or root SSH login
- `bash` available (default on Debian)

### Options

1. run script and answer prompts step-by-step
2. duplicate the .env.sample file and pre-fill your answers to these questions and let the script run automatically

