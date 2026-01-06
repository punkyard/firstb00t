# 🌐 Server Orchestration Module (12-server_orchestration)

## Purpose

Lightweight SSH orchestrator that triggers module 11 backups across 2–5 hosts. Execution is sequential by default for predictable ordering; optional GNU parallel for concurrency. Logs all remote command results to `/var/log/firstb00t/12-server_orchestration.log`.

## 🔗 Dependencies

- **openssh-client** — For SSH connectivity
- **GNU parallel** (optional) — For concurrent execution (`PARALLEL_ENABLED=true`)
- **Remote hosts** — Must have module 11 installed and executable
- **Remote SSH keys** — Authorized keys configured on each host

## ⚙️ Configuration

### Environment Variables

- `INVENTORY_FILE` (default: `/etc/firstboot/backup.inventory`) — List of hosts (one per line)
- `SSH_USER` (default: `root`) — SSH login user
- `SSH_KEY_PATH` (default: `/root/.ssh/backup_key`) — SSH private key for authentication
- `BACKUP_COMMAND` (default: `/usr/local/bin/11-backup_config.sh`) — Remote command to execute
- `PARALLEL_ENABLED` (default: `false`) — Enable concurrent SSH execution if parallel is available

### SSH Options

- `-o BatchMode=yes` — Disable interactive prompts (suitable for cron/systemd)
- `-o StrictHostKeyChecking=yes` — Prevent MITM attacks by validating host keys

## 🚀 Behavior

1. **Load inventory** — Read host list from `${INVENTORY_FILE}` (skip comments and blank lines)
2. **Check for parallel** — If `PARALLEL_ENABLED=true` and `parallel` command available, use concurrent mode
3. **Sequential mode (default):**
   - For each host: `ssh -i ${SSH_KEY_PATH} -o BatchMode=yes -o StrictHostKeyChecking=yes ${SSH_USER}@${host} ${BACKUP_COMMAND}`
   - Log success/failure per host
   - Continue processing remaining hosts even if one fails
4. **Parallel mode (if enabled and parallel available):**
   - Spawn up to N concurrent SSH jobs
   - Return non-zero if any job fails
5. **Exit** — Non-zero exit code if any host failed

## ✅ Validation

Success criteria:
- SSH key is readable and has correct permissions (`0600`)
- Each host responds to SSH with `StrictHostKeyChecking=yes`
- Remote command `/usr/local/bin/11-backup_config.sh` executes and exits 0
- Log file `/var/log/firstb00t/12-server_orchestration.log` records all host attempts

## 🧹 Rollback

Not applicable (orchestrator logs only). On remote host failure:
1. Check remote logs: `ssh ${SSH_USER}@${host} tail -f /var/log/firstb00t/11-backup_config.log`
2. Fix issue on remote host (e.g., BORG_REPO unreachable, passphrase wrong, volume missing)
3. Re-run orchestrator: `bash 12-server_orchestration.sh`

## 📝 Logging

All operations logged with timestamp, level (info/warn/error), module ID, and message:
- **INFO** — Module start/stop, host processing, SSH success
- **WARN** — GNU parallel not available (fallback to sequential)
- **ERROR** — SSH failures, command exit non-zero

Log file: `/var/log/firstb00t/12-server_orchestration.log`

## 🔒 Security Notes

- **SSH key** should be restricted to backup operations (e.g., via `~/.ssh/config` with command restrictions)
- **Host keys** validated with `StrictHostKeyChecking=yes` to prevent MITM
- **Inventory file** should be readable by root only (`0600`)
- **No passwords** — Uses key-based authentication only

## 📊 Security Compliance

- **NSA Sec 7.6**: Source-based access control (ACLs via SSH key restrictions)
- **TuxCare #06**: Protocol vulnerability prevention (SSH hardening, key-based auth)
- **TuxCare #08**: Access control lists (host-based restrictions, key restrictions)
- **Compliance Impact**: Module 12 contributes to Phase 4 target of 95%+ overall compliance

## 📚 Example Configuration

### /etc/firstboot/backup.inventory (hosts)
```
# Production hosts to backup
prod-db-1.example.com
prod-db-2.example.com
prod-app-1.example.com
```

### ~/.ssh/config (optional, for convenience)
```
Host prod-*
    User root
    IdentityFile ~/.ssh/backup_key
    StrictHostKeyChecking yes
    BatchMode yes
```

### Execution (sequential, default)
```bash
bash 12-server_orchestration.sh
# Processes hosts in order, logs each result
```

### Execution (parallel, if available)
```bash
PARALLEL_ENABLED=true bash 12-server_orchestration.sh
# Spawns concurrent SSH jobs if GNU parallel is installed
```

## 🔄 Idempotence

Safe to re-run:
- Each run reads fresh inventory
- SSH is stateless (no local state modified)
- Remote module 11 handles idempotence via timestamp-based archives
- No cleanup needed between runs
