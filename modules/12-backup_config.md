# 💾 Backup Configuration Module (11-backup_config)

## Purpose

BorgBackup configuration for Docker volumes: encrypted, deduplicated daily backups over SSH with automatic retention pruning and compaction. Archives are named `{hostname}-{volume}-{timestamp}` and stored remotely. Logs all operations to `/var/log/firstb00t/11-backup_config.log`.

## 🔗 Dependencies

- **borgbackup** — Deduplicating backup tool
- **ssh** — For BORG_RSH transport and authentication
- **docker** — Volume mount paths at `/var/lib/docker/volumes/<name>/_data`
- **cron or systemd timer** — For daily scheduling (external)

## ⚙️ Configuration

### Environment Variables

- `BORG_REPO` (required) — SSH remote repo (e.g., `ssh://backup-user@backup-host/backups/host1`)
- `BORG_PASSPHRASE` (required) — Encryption passphrase for repository
- `BORG_RSH` (optional) — SSH command options (default: `ssh -o BatchMode=yes -o StrictHostKeyChecking=yes`)
- `ENV_FILE` (default: `/etc/firstboot/backup.env`) — File containing BORG_REPO and BORG_PASSPHRASE
- `INVENTORY_FILE` (default: `/etc/firstboot/backup.inventory`) — List of volumes to backup
- `VOLUME_BASE` (default: `/var/lib/docker/volumes`) — Docker volume base path

### Retention Policy

- `--keep-daily 7` — Keep 7 daily backups
- `--keep-weekly 4` — Keep 4 weekly backups
- `--keep-monthly 6` — Keep 6 monthly backups

## 🚀 Behavior

1. **Load environment** — Source `${ENV_FILE}` for BORG_REPO and BORG_PASSPHRASE
2. **Validate borg** — Check `borg` binary exists
3. **Read inventory** — Load volume list from `${INVENTORY_FILE}` (skip comments and blank lines)
4. **For each volume:**
   - Mount path: `${VOLUME_BASE}/${volume}/_data`
   - Create archive: `borg create --one-file-system --compression lz4 ${BORG_REPO}::{hostname}-{volume}-{timestamp} ${path}`
   - Prune old: `borg prune ${BORG_REPO} --keep-daily 7 --keep-weekly 4 --keep-monthly 6`
   - Compact: `borg compact ${BORG_REPO}` (reclaim deduped space)
5. **Validate** — `borg list ${BORG_REPO}` confirms accessibility

## ✅ Validation

Success criteria:
- `borg` binary present
- `${BORG_REPO}` accessible via SSH
- Archive created and listed in repo
- `${INVENTORY_FILE}` readable with at least one volume
- Log entries recorded to `/var/log/firstb00t/11-backup_config.log`

## 🧹 Rollback

On error, automatically delete the last attempted archive:
```bash
borg delete "${BORG_REPO}::${last_archive}"
```

## 📝 Logging

All operations logged with timestamp, level (info/warn/error), module ID, and message:
- **INFO** — Module start/stop, archive creation, prune/compact, volume completion
- **WARN** — Volume paths not found (skipped)
- **ERROR** — Missing files, borg command failures, validation failures

Log file: `/var/log/firstb00t/11-backup_config.log`

## 🔒 Security Notes

- **Passphrase** stored in `/etc/firstboot/backup.env` with permissions `0600` (root-only)
- **SSH key** referenced in `BORG_RSH` should be dedicated backup key with restricted permissions (`0600`)
- **StrictHostKeyChecking=yes** prevents MITM attacks
- **BatchMode=yes** disables interactive prompts (suitable for cron/systemd)

## 📊 Security Compliance

- **NSA Sec 6.1**: Centralized logging (all operations logged to `/var/log/firstb00t/11-backup_config.log`)
- **TuxCare #03**: Monitoring (backup validation and error detection)
- **TuxCare #10**: Code execution prevention (encryption prevents unauthorized access to backups)
- **Compliance Impact**: Module 11 contributes to Phase 4 target of 95%+ overall compliance

## 📚 Example Configuration

### /etc/firstboot/backup.env
```bash
BORG_REPO="ssh://backup-user@backup.example.com/backups/prod-host1"
BORG_PASSPHRASE="your-secure-passphrase-here"
BORG_RSH="ssh -i /root/.ssh/backup_key -o BatchMode=yes -o StrictHostKeyChecking=yes"
```

### /etc/firstboot/backup.inventory
```
# Docker volumes to backup
postgres
redis
app-data
```

## 🔄 Idempotence

Safe to re-run:
- Creates new archive each run (timestamp-based naming prevents conflicts)
- Prune/compact are safe to repeat
- Skips non-existent volume paths
