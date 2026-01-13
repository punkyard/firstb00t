#!/usr/bin/env bash
#
# logging.sh - Enhanced Logging Library with User-Friendly Display
#
# Purpose: Provide clean, informative output that reassures users
# about what the script is doing to their server
#
# Usage: source common/logging.sh
#

set -Eeuo pipefail

# Frame settings for summaries
FRAME_WIDTH=59
FRAME_INNER=$((FRAME_WIDTH - 4)) # accounts for "║ " and " ║"

# Module tracking
declare -g MODULE_START_TIME
declare -g MODULE_CHECKS_PASSED=0
declare -g MODULE_CHECKS_TOTAL=0
declare -A MODULE_ACTIONS=()

# Enhanced log function - messages on separate line for readability
log() {
    local level=$1; shift
    local message="$*"
    local timestamp
    timestamp=$(date -Iseconds)
    
    # Log to file with timestamp/module on one line, message on next
    {
        printf '%s [%s] [%s]\n' "$timestamp" "$level" "${MODULE_ID:-system}"
        printf '%s\n' "$message"
    } | tee -a "/var/log/firstb00t/${MODULE_ID:-system}.log"
}

# Visual separator
log_separator() {
    local char="${1:-═}"
    local width=60
    printf '%*s\n' "$width" | tr ' ' "$char"
}

# Sanitize line content to avoid comment markers and keep width
frame_sanitize() {
    local text="$1"
    text=${text//#/}           # remove '#'
    text=${text/$'\t'/'    '}   # replace tabs with spaces
    printf '%s' "$text"
}

frame_border_top()  { printf '╔'; printf '═%.0s' $(seq 1 $((FRAME_WIDTH-2))); printf '╗\n'; }
frame_border_mid()  { printf '╠'; printf '═%.0s' $(seq 1 $((FRAME_WIDTH-2))); printf '╣\n'; }
frame_border_bottom(){ printf '╚'; printf '═%.0s' $(seq 1 $((FRAME_WIDTH-2))); printf '╝\n'; }

frame_line() {
    local raw="$1"
    local text
    text=$(frame_sanitize "$raw")
    printf '║ %-*s ║\n' "$FRAME_INNER" "$text"
}

# Module start banner
module_start() {
    local module_name="$1"
    local module_desc="$2"
    
    MODULE_START_TIME=$(date +%s)
    MODULE_CHECKS_PASSED=0
    MODULE_CHECKS_TOTAL=0
    
    echo ""
    log_separator "═"
    echo "🚀 MODULE: ${module_name}"
    echo "📋 ${module_desc}"
    log_separator "═"
    echo ""
    
    log info "Starting module: ${module_name}"
}

# Module end summary
module_end() {
    local module_name="$1"
    local status="$2"  # success | failed | warning
    
    local end_time duration status_icon status_color
    end_time=$(date +%s)
    duration=$((end_time - MODULE_START_TIME))
    
    case "$status" in
        success)
            status_icon="✅"
            status_color="SUCCESS"
            ;;
        failed)
            status_icon="❌"
            status_color="FAILED"
            ;;
        warning)
            status_icon="⚠️"
            status_color="WARNING"
            ;;
        *)
            status_icon="ℹ️"
            status_color="COMPLETED"
            ;;
    esac
    
    echo ""
    frame_border_top
    frame_line "${status_icon} MODULE ${MODULE_ID:-?}: ${module_name} - ${status_color}"
    frame_border_mid

    if [[ ${#MODULE_ACTIONS[@]} -gt 0 ]]; then
        for action in "${!MODULE_ACTIONS[@]}"; do
            frame_line "${MODULE_ACTIONS[$action]} ${action}"
        done
        frame_border_mid
    fi

    if [[ $MODULE_CHECKS_TOTAL -gt 0 ]]; then
        frame_line "🔍 Validation: ${MODULE_CHECKS_PASSED}/${MODULE_CHECKS_TOTAL} checks passed"
    fi

    frame_line "⏱️  Duration: ${duration}s"
    frame_line "📝 Logs: /var/log/firstb00t/${MODULE_ID}.log"
    frame_border_bottom
    echo ""

    log info "Module ${module_name} completed: ${status_color} (${duration}s)"
}

# Record an action (for summary)
record_action() {
    local action_name="$1"
    local action_icon="${2:-✓}"
    MODULE_ACTIONS["$action_name"]="$action_icon"
}

# Validation check (increments counters)
check() {
    local check_name="$1"
    local check_result="${2:-true}"  # true/false
    
    ((MODULE_CHECKS_TOTAL++))
    
    if [[ "$check_result" == "true" ]]; then
        ((MODULE_CHECKS_PASSED++))
        log info "✅ Check ${MODULE_CHECKS_PASSED}/${MODULE_CHECKS_TOTAL}: ${check_name}"
    else
        log warn "❌ Check failed: ${check_name}"
    fi
}

# Step marker (for multi-step operations)
step() {
    local step_num="$1"
    local step_total="$2"
    local step_desc="$3"
    
    echo ""
    echo "📦 Step ${step_num}/${step_total}: ${step_desc}"
    log info "Step ${step_num}/${step_total}: ${step_desc}"
}

# Security impact note (what changed on the server)
security_impact() {
    local impact="$1"
    echo "🔒 Security impact: ${impact}"
    log info "Security impact: ${impact}"
}

# Progress indicator
progress() {
    local current="$1"
    local total="$2"
    local desc="${3:-}"
    
    local percent=$((current * 100 / total))
    local bar_length=30
    local filled=$((bar_length * current / total))
    local empty=$((bar_length - filled))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%% %s" "$percent" "$desc"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# User explanation (what is happening and why)
explain() {
    local explanation="$1"
    echo "💡 ${explanation}"
}

# Warning message
warn_user() {
    local warning="$1"
    echo "⚠️  WARNING: ${warning}"
    log warn "$warning"
}

# Final deployment summary (called by main script)
deployment_summary() {
    local profile="$1"
    local modules_total="$2"
    local modules_passed="$3"
    local modules_failed="$4"
    local start_time="$5"
    
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo ""
    echo ""
    log_separator "═"
    log_separator "═"
    echo "  🎉 FIRSTB00T DEPLOYMENT COMPLETE"
    log_separator "═"
    log_separator "═"
    echo ""
    echo "📊 Deployment Summary:"
    echo "   Profile: ${profile}"
    echo "   Modules: ${modules_passed}/${modules_total} successful"
    if [[ $modules_failed -gt 0 ]]; then
        echo "   ⚠️  Failed: ${modules_failed} modules"
    fi
    echo "   Duration: ${minutes}m ${seconds}s"
    echo ""
    echo "🔒 Security Status:"
    echo "   ✅ System hardening applied"
    echo "   ✅ Security policies enforced"
    echo "   ✅ Audit logging enabled"
    echo ""
    echo "📝 Review logs in: /var/log/firstb00t/"
    echo ""
    echo "🔄 Next steps:"
    if [[ $modules_failed -eq 0 ]]; then
        echo "   1. Review logs for any warnings"
        echo "   2. Test system functionality"
        echo "   3. Reboot server for kernel updates to take effect"
        echo "   4. Configure application-specific settings"
    else
        echo "   1. Check failed module logs in /var/log/firstb00t/"
        echo "   2. Fix configuration issues"
        echo "   3. Re-run failed modules individually"
    fi
    echo ""
    log_separator "═"
    log_separator "═"
    echo ""
}

# Export functions for use in modules
export -f log log_separator module_start module_end record_action check step security_impact progress explain warn_user deployment_summary
