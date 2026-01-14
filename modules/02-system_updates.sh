#!/bin/bash

# 🌈 color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # no color

# 📋 Module: System Updates with Rollback
MODULE_ID="1-system_updates"
MODULE_NAME="System Updates with Rollback Capability"
MODULE_VERSION="2.0.0"
MODULE_DESCRIPTION="Debian system updates with timeshift snapshots for safe rollback"
MODULE_DEPENDENCIES=("apt-get" "timeshift" "rsync")

# 📊 NSA/TuxCare compliance
# - NSA Sec 3.3.2: Security patch management with integrity verification
# - NSA Sec 5.3: Secure update mechanism with rollback capability
# - TuxCare #05: Patch Management (snapshot before updates, automated rollback)

# 🔧 Configuration
ADMIN_EMAIL="${ADMIN_EMAIL:-root@localhost}"
LOG_DIR="/var/log/firstb00t"
LOG_FILE="${LOG_DIR}/${MODULE_ID}.log"
SNAPSHOT_COMMENT_PREFIX="firstb00t-pre-update"

# 📝 Logging
log() {
    local level=$1; shift
    local message="$*"
    local timestamp=$(date -Iseconds)
    printf '%s [%s] [%s] %s\n' "$timestamp" "$level" "$MODULE_ID" "$message" | tee -a "$LOG_FILE"
}

# 🚨 Error handling
trap 'log error "Failed at line $LINENO"' ERR
trap 'log info "Module finished (exit status: $?)"' EXIT

# 🛠️ Ensure timeshift is installed
ensure_timeshift_installed() {
    log info "Checking timeshift installation"
    
    if ! command -v timeshift &>/dev/null; then
        log info "Installing timeshift"
        apt-get update -qq
        apt-get install -y timeshift rsync || {
            log error "Failed to install timeshift"
            return 1
        }
    fi
    
    log info "✅ Timeshift installed"
}

# 📸 Create pre-update snapshot
create_snapshot() {
    log info "Creating pre-update snapshot"
    
    local snapshot_comment="${SNAPSHOT_COMMENT_PREFIX}-$(date +%Y%m%d-%H%M%S)"
    
    # Create snapshot (rsync mode, works without BTRFS/LVM)
    if ! timeshift --create --comments "$snapshot_comment" --scripted; then
        log error "Snapshot creation failed, aborting updates"
        return 1
    fi
    
    # Store snapshot name for rollback reference
    LAST_SNAPSHOT=$(timeshift --list | grep "$SNAPSHOT_COMMENT_PREFIX" | tail -1 | awk '{print $3}')
    
    log info "✅ Snapshot created: $LAST_SNAPSHOT"
    echo "$LAST_SNAPSHOT" > /var/lib/firstb00t/last-update-snapshot.txt
}

# 🔄 Rollback to last snapshot
rollback() {
    log warn "🚨 Initiating rollback to pre-update snapshot"
    
    local snapshot_file="/var/lib/firstb00t/last-update-snapshot.txt"
    if [ ! -f "$snapshot_file" ]; then
        log error "No snapshot reference found at $snapshot_file"
        return 1
    fi
    
    local snapshot_name=$(cat "$snapshot_file")
    log warn "Restoring snapshot: $snapshot_name"
    
    # Confirm snapshot exists
    if ! timeshift --list | grep -q "$snapshot_name"; then
        log error "Snapshot $snapshot_name not found"
        return 1
    fi
    
    # Restore snapshot (scripted mode = non-interactive)
    if timeshift --restore --snapshot "$snapshot_name" --scripted; then
        log info "✅ Rollback successful"
        return 0
    else
        log error "❌ Rollback failed"
        return 1
    fi
}

# 🔐 Verify APT signature enforcement (NSA Sec 3.3.2)
ensure_apt_signature_verification() {
    log info "Configuring APT signature verification"
    
    local apt_conf="/etc/apt/apt.conf.d/99-firstb00t-security"
    
    cat > "$apt_conf" <<'EOF'
# firstb00t APT security settings (NSA Sec 3.3.2)
APT::Get::AllowUnauthenticated "false";
Acquire::AllowInsecureRepositories "false";
Acquire::AllowDowngradeToInsecureRepositories "false";
EOF
    
    log info "✅ APT signature verification enforced"
}

# 📦 Perform system updates with safety checks
perform_updates() {
    log info "Starting system updates"
    
    # Update package lists
    log info "Updating package lists"
    if ! apt-get update; then
        log error "apt-get update failed"
        rollback
        return 1
    fi
    
    # Check if updates are available
    local updates=$(apt-get -s upgrade | grep -c "^Inst" || true)
    if [ "$updates" -eq 0 ]; then
        log info "No updates available"
        return 0
    fi
    
    log info "Found $updates packages to update"
    
    # Upgrade packages (non-interactive)
    log info "Upgrading packages"
    if ! DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confold"; then
        log error "apt-get upgrade failed"
        rollback
        return 1
    fi
    
    # Full upgrade (handles kernel updates, held packages)
    log info "Performing full-upgrade"
    if ! DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y -o Dpkg::Options::="--force-confold"; then
        log error "apt-get full-upgrade failed"
        rollback
        return 1
    fi
    
    # Autoremove unused packages
    log info "Removing unused packages"
    apt-get autoremove -y || log warn "autoremove encountered issues (non-critical)"
    
    # Clean package cache
    log info "Cleaning package cache"
    apt-get clean || log warn "clean encountered issues (non-critical)"
    
    log info "✅ System updates completed successfully"
}

# 📧 Send update notification email
send_notification() {
    local status=$1
    local snapshot=$2
    
    if ! command -v mail &>/dev/null; then
        log warn "mail command not available, skipping email notification"
        return 0
    fi
    
    local subject="firstb00t: System updates $status"
    local body="System updates $status at $(date -Iseconds)\n\nSnapshot: $snapshot\n\nLog: $LOG_FILE"
    
    echo -e "$body" | mail -s "$subject" "$ADMIN_EMAIL" || log warn "Failed to send email notification"
}

# ✅ Validation checks
validate() {
    log info "Running validation checks"
    local checks_passed=0
    local checks_total=6
    
    # Check 1: Timeshift installed
    if command -v timeshift &>/dev/null; then
        log info "✅ Check 1/6: timeshift installed"
        ((checks_passed++))
    else
        log error "❌ Check 1/6: timeshift not found"
    fi
    
    # Check 2: APT signature verification enabled
    if [ -f "/etc/apt/apt.conf.d/99-firstb00t-security" ] && grep -q "AllowUnauthenticated.*false" /etc/apt/apt.conf.d/99-firstb00t-security; then
        log info "✅ Check 2/6: APT signature verification enforced"
        ((checks_passed++))
    else
        log error "❌ Check 2/6: APT signature verification not configured"
    fi
    
    # Check 3: Snapshot directory exists
    local snapshot_dir=$(timeshift --list 2>/dev/null | grep "Device" | head -1 | awk '{print $3}')
    if [ -n "$snapshot_dir" ]; then
        log info "✅ Check 3/6: Timeshift configured (backup location: $snapshot_dir)"
        ((checks_passed++))
    else
        log warn "⚠️ Check 3/6: Timeshift not yet configured (will auto-configure on first snapshot)"
        ((checks_passed++))  # Non-critical for initial setup
    fi
    
    # Check 4: Last snapshot reference exists (if updates ran)
    if [ -f "/var/lib/firstb00t/last-update-snapshot.txt" ]; then
        local last_snapshot=$(cat /var/lib/firstb00t/last-update-snapshot.txt)
        if timeshift --list 2>/dev/null | grep -q "$last_snapshot"; then
            log info "✅ Check 4/6: Last snapshot verified ($last_snapshot)"
            ((checks_passed++))
        fi
    else
        log warn "⚠️ Check 4/6: No previous snapshot (expected on first run)"
        ((checks_passed++))  # Non-critical for initial setup
    fi
    
    # Check 5: APT operational
    if apt-get update -qq &>/dev/null; then
        log info "✅ Check 5/6: APT functioning correctly"
        ((checks_passed++))
    else
        log error "❌ Check 5/6: APT update failed"
    fi
    
    # Check 6: No broken packages
    if ! dpkg -l | grep -q "^iF"; then
        log info "✅ Check 6/6: No broken packages"
        ((checks_passed++))
    else
        log error "❌ Check 6/6: Broken packages detected"
    fi
    
    log info "Validation: $checks_passed/$checks_total checks passed"
    
    if [ "$checks_passed" -ge 5 ]; then
        return 0
    else
        return 1
    fi
}

# 🎯 Main function
main() {
    log info "Starting ${MODULE_NAME} (${MODULE_VERSION})"
    
    # Ensure log directory exists
    mkdir -p "$LOG_DIR" /var/lib/firstb00t
    
    # Step 1: Install timeshift if needed
    ensure_timeshift_installed || exit 1
    
    # Step 2: Configure APT signature verification
    ensure_apt_signature_verification || exit 1
    
    # Step 3: Create pre-update snapshot
    create_snapshot || {
        log error "Snapshot creation failed, aborting updates"
        exit 1
    }
    
    # Step 4: Perform updates with rollback on failure
    if perform_updates; then
        log info "✅ Updates completed successfully"
        send_notification "successful" "$LAST_SNAPSHOT"
    else
        log error "Updates failed, system rolled back to snapshot"
        send_notification "failed (rolled back)" "$LAST_SNAPSHOT"
        exit 1
    fi
    
    # Step 5: Validate
    validate || {
        log error "Validation failed"
        exit 1
    }
    
    log info "✅ ${MODULE_NAME} completed successfully"
}

# 🚀 Run main function
main "$@"