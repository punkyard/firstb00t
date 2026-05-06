# firstb00t

Hardening script for fresh servers.

## Purpose

`debian-firstb00t.sh` helps bootstrap and harden a Debian server from a single SSH-launched command, with a short interactive questionnaire and safe defaults.

## Scope

- Debian-focused first-boot hardening
- Minimal, auditable shell logic
- SSH + firewall-first safety model

## Planned behavior (high level)

1. Root bootstrap (`apt-get update` + install `nala`)
2. Create sudo admin user
3. Run remaining install/config prompts through sudo-user workflow
4. Mandatory firewall setup (UFW default, nftables advanced)
5. SSH hardening and final SSH-key setup at the end

## Container data convention

For predictable remote backups, container bind-mount volumes should live under one root folder, default:

- `/srv/containers`

This is a convention used by this project for operational simplicity.

## Repository contents

- `debian-firstb00t.sh` — main hardening script
- `README.md` — project overview

## Status

Work in progress.
