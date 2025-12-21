# 🎯 Profile Selection Module

## Purpose

This module handles initial system profile selection and SSH port configuration. It prompts the user to select a security profile (Basic, Standard, or Advanced) and configure a custom SSH port, then creates `.enabled` marker files to control which modules run during the firstboot sequence.

## 🔗 Dependencies

- bash: shell scripting
- systemctl: service management
- apt: package management
- User input: interactive prompts for profile and SSH port selection

## ⚙️ Configuration

### Profile Options

A. **Basic Profile** — Essential security (6 modules)
   - System updates
   - User management
   - SSH configuration
   - SSH hardening
   - Firewall (UFW)
   - Monitoring (Logwatch)

B. **Standard Profile** — Production-ready (9 modules)
   - All Basic modules +
   - Fail2ban (brute-force protection)
   - SSL/TLS configuration
   - DNS security
   - Postfix mail server

C. **Advanced Profile** — Full hardening (10 modules)
   - All Standard modules +
   - Profile selection module itself (explicit control)

### SSH Port Configuration

- Default port: 22 (standard SSH)
- Custom range: 10000-65535 (user-configurable)
- Environment variable: `$SSH_PORT` (passed to 3-ssh_config and 4-ssh_hardening modules)
- Storage: Created as `/etc/firstboot/modules/profile` and `/etc/firstboot/ssh_port` config files

### Marker Files

- Location: `/etc/firstboot/modules/`
- Format: `NN-module_name.enabled` (empty marker file)
- Purpose: Controls module execution in main firstb00t script
- Created by: touch commands in respective profile case blocks

## 🚨 Error Handling

### Common Errors

A. Invalid profile selection
   - Cause: User enters invalid option (not 1, 2, or 3)
   - Solution: Script loops until valid selection received
   - Prevention: Clear prompt with numbered options

B. Invalid SSH port
   - Cause: User enters port outside valid range or non-numeric
   - Solution: Script validates and re-prompts
   - Prevention: Numeric validation and range check before acceptance

C. Directory creation failure
   - Cause: `/etc/firstboot/modules/` doesn't exist or permission denied
   - Solution: Create directory with appropriate permissions
   - Prevention: Verify directory exists; create if needed with mkdir -p

## 🔄 Integration

### Input

- User interactive selection (profile choice)
- User interactive input (SSH port number)
- Existing system services (systemctl to restart SSH after config)

### Output

- `.enabled` marker files in `/etc/firstboot/modules/` for selected profile modules
- Environment variable `$SSH_PORT` exported for downstream modules
- Configuration stored in `/etc/firstboot/profile` and `/etc/firstboot/ssh_port`

### Module Interactions

- **Downstream**: 3-ssh_config (uses $SSH_PORT), 4-ssh_hardening (respects port config), all selected modules (read .enabled markers)
- **Upstream**: None (always first module after system entry)

## 📊 Validation

### Success Criteria

- Profile selection captured and valid (1, 2, or 3)
- SSH port captured, valid, and numeric (10000-65535)
- Correct `.enabled` marker files created for selected profile
- Environment variable $SSH_PORT accessible to downstream modules
- No errors in marker file creation

### Performance Metrics

- Selection completion time (typically < 60 seconds)
- Marker file creation count (6, 9, or 10 depending on profile)
- Directory creation latency

## 🧹 Cleanup

### Temporary Files

- None (process is stateless after .enabled markers created)

### Configuration Files

- `/etc/firstboot/modules/*.enabled` — Marker files (preserved for subsequent runs)
- `/etc/firstboot/profile` — Selected profile (preserved)
- `/etc/firstboot/ssh_port` — Configured port (preserved)

### Recovery

- Remove `.enabled` files to reset profile
- Delete config files to clear stored settings
- Rerun 0-profile_selection.sh to reconfigure

## 📝 Logging

### Log Files

- `/var/log/firstboot/0-profile_selection.log` — Module actions and user selections
- Logs include: profile selected, SSH port configured, marker files created, timestamps

### Log Levels

- INFO: User selections, marker file creation
- ERROR: Invalid input, directory creation failures, permission issues
- SUCCESS: Profile finalized, all markers created

## 🔧 Maintenance

### Regular Tasks

- Verify profile-to-module mapping remains accurate
- Test each profile variant (Basic, Standard, Advanced)
- Validate SSH port configuration across profiles
- Check marker file permissions and existence

### Typical Updates

- Add new module to profile mapping (if new modules added)
- Expand SSH port validation logic (if security requirements change)
- Enhance user prompts (if new profiles added)

---

**Module Type:** System initialization  
**Execution Order:** First (0)  
**Profile Availability:** Advanced (all profiles)  
**Configuration:** Interactive (user prompts)

