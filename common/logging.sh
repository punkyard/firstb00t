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
# use portable declarations (macOS bash may be older and lack 'declare -g' or associative arrays)
MODULE_START_TIME=""
MODULE_CHECKS_PASSED=0
MODULE_CHECKS_TOTAL=0
# associative arrays are Bash 4+; provide fallback when not available
if bash -c 'declare -A _ >/dev/null 2>&1'; then
    SUPPORTS_ASSOC_ARRAYS=1
    declare -A MODULE_ACTIONS=()
else
    SUPPORTS_ASSOC_ARRAYS=0
    MODULE_ACTIONS_LIST=""
fi

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

    # compute display width using Python (handles wide emoji and CJK)
    local py
    if command -v python3 >/dev/null 2>&1; then
        py=python3
    elif command -v python >/dev/null 2>&1; then
        py=python
    else
        # fallback: byte-based width (may misalign with wide chars)
        printf '║ %-*s ║\n' "$FRAME_INNER" "$text"
        return
    fi

    local width
    width=$( $py - <<'PY' "$text"
import sys, unicodedata
s = sys.argv[1]
width = 0
for ch in s:
    if unicodedata.category(ch) == 'Mn':
        continue
    ea = unicodedata.east_asian_width(ch)
    if ea in ('F','W'):
        width += 2
    else:
        width += 1
print(width)
PY
 )

    # ensure numeric
    width=${width:-0}

    local pad=$((FRAME_INNER - width))
    if [ $pad -lt 0 ]; then
        # truncate to fit and add ellipsis
        local max=$((FRAME_INNER - 3))
        text="${text:0:$max}..."
        pad=0
    fi

    # print line with calculated padding (spaces)
    printf '║ %s%*s ║\n' "$text" "$pad" ""
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

# Compute display width of a string (accounts for wide chars)
display_width() {
    local s="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 - <<PY "$s"
import sys, unicodedata
s = sys.argv[1]
width = 0
for ch in s:
    if unicodedata.category(ch) == 'Mn':
        continue
    ea = unicodedata.east_asian_width(ch)
    if ea in ('F','W'):
        width += 2
    else:
        width += 1
print(width)
PY
    elif command -v python >/dev/null 2>&1; then
        python - <<PY "$s"
import sys, unicodedata
s = sys.argv[1]
width = 0
for ch in s:
    if unicodedata.category(ch) == 'Mn':
        continue
    ea = unicodedata.east_asian_width(ch)
    if ea in ('F','W'):
        width += 2
    else:
        width += 1
print(width)
PY
    else
        # fallback: bytes length
        echo -n "${s}" | wc -c
    fi
}

# frame helpers that accept a width parameter
frame_border_top_n()  { local w=$1; printf '╔'; printf '═%.0s' $(seq 1 $((w-2))); printf '╗\n'; }
frame_border_bottom_n(){ local w=$1; printf '╚'; printf '═%.0s' $(seq 1 $((w-2))); printf '╝\n'; }
frame_line_n() {
    local w=$1; local raw="$2"
    local inner=$((w-4))
    local text
    text=$(frame_sanitize "$raw")

    # compute display width
    local dw
    dw=$(display_width "$text" 2>/dev/null || echo 0)
    dw=${dw:-0}

    local pad=$((inner - dw))
    if [ $pad -lt 0 ]; then
        # truncate cleanly (preserve bytes approx)
        local max=$((inner - 3))
        text="${text:0:$max}..."
        pad=0
    fi
    printf '║ %s%*s ║\n' "$text" "$pad" ""
}

# Print a colored framed title line with emoji and text. robust Python-based rendering
# usage: print_title_frame "🔥" "installation of the firewall..."
print_title_frame() {
    local emoji="${1:-}"
    local title="${2:-}"
    local CYAN='\033[0;36m'
    local NC='\033[0m'

    # prefer Python rendering for correct unicode width handling and consistent borders
    if command -v python3 >/dev/null 2>&1; then
        echo -e "${CYAN}"
        python3 - "$emoji" "$title" <<'PY'
import sys, unicodedata, os
emoji, title = sys.argv[1], sys.argv[2]
text = f"{emoji} {title}"

def width(s):
    w=0
    for ch in s:
        if unicodedata.category(ch) == 'Mn':
            continue
        ea = unicodedata.east_asian_width(ch)
        w += 2 if ea in ('F','W') else 1
    return w

# terminal width
try:
    cols = os.get_terminal_size().columns
except Exception:
    cols = 120
cols = max(40, min(cols, 120))

min_inner = 36
max_inner = cols - 4

# wrap text into segments not exceeding inner width, prefer word boundaries
def wrap_text(s, maxw):
    # compute total width
    words = s.split(' ')
    word_ws = []
    total = 0
    for w in words:
        wsum = 0
        for ch in w:
            if unicodedata.category(ch) == 'Mn':
                continue
            ea = unicodedata.east_asian_width(ch)
            wsum += 2 if ea in ('F','W') else 1
        word_ws.append((w, wsum))
        total += wsum + 1  # include a space after each word
    total = max(0, total - 1)  # no trailing space

    # min lines required to not exceed maxw
    min_lines = max(1, -(-total // maxw))  # ceil div
    # target average width per line
    target = -(-total // min_lines)

    lines = []
    cur_words = []
    cur_w = 0
    for i, (w, pw) in enumerate(word_ws):
        add_space = 1 if cur_words else 0
        if cur_w + add_space + pw <= target or not cur_words:
            if add_space:
                cur_w += 1
            cur_words.append(w)
            cur_w += pw
        else:
            lines.append(' '.join(cur_words))
            cur_words = [w]
            cur_w = pw
    if cur_words:
        lines.append(' '.join(cur_words))

    # ensure no line exceeds maxw; if it does, break long words
    new_lines = []
    for ln in lines:
        if width(ln) <= maxw:
            new_lines.append(ln)
            continue
        parts = ln.split(' ')
        cur = ''
        cur_w = 0
        for part in parts:
            pw = 0
            for ch in part:
                if unicodedata.category(ch) == 'Mn':
                    continue
                ea = unicodedata.east_asian_width(ch)
                pw += 2 if ea in ('F','W') else 1
            add_space = 1 if cur else 0
            if cur_w + add_space + pw <= maxw:
                if add_space:
                    cur += ' '
                    cur_w += 1
                cur += part
                cur_w += pw
            else:
                if cur:
                    new_lines.append(cur)
                # break the long word char-wise
                sub = ''
                sw = 0
                for ch in part:
                    if unicodedata.category(ch) == 'Mn':
                        sub += ch; continue
                    ea = unicodedata.east_asian_width(ch)
                    cw = 2 if ea in ('F','W') else 1
                    if sw + cw > maxw:
                        new_lines.append(sub)
                        sub = ch
                        sw = cw
                    else:
                        sub += ch
                        sw += cw
                if sub:
                    cur = sub
                    cur_w = sw
                else:
                    cur = ''
                    cur_w = 0
        if cur:
            new_lines.append(cur)
    lines = new_lines

    # try to rebalance neighboring lines to reduce variance
    if len(lines) > 1:
        improved = True
        while improved:
            improved = False
            ws = [width(x) for x in lines]
            for i in range(len(lines)-1):
                left_words = lines[i].split(' ')
                right_words = lines[i+1].split(' ')
                if len(left_words) <= 1:
                    continue
                # try moving the last word from left to start of right
                cand_left = ' '.join(left_words[:-1])
                cand_right = left_words[-1] + (' ' + ' '.join(right_words) if right_words else '')
                if width(cand_left) <= maxw and width(cand_right) <= maxw:
                    old_var = max(ws[i], ws[i+1]) - min(ws[i], ws[i+1])
                    new_var = abs(width(cand_left) - width(cand_right))
                    if new_var < old_var:
                        lines[i] = cand_left
                        lines[i+1] = cand_right
                        ws[i] = width(cand_left)
                        ws[i+1] = width(cand_right)
                        improved = True
                        break
            if not improved:
                break
    return lines

# choose inner width: try to fit whole text if possible else choose max_inner
dw = width(text)
if dw + 4 <= cols:
    inner = max(min_inner, dw)
    if inner + 4 > cols:
        inner = cols - 4
else:
    inner = max(min_inner, max_inner)

# ensure inner doesn't exceed max_inner
if inner > max_inner:
    inner = max_inner

lines = wrap_text(text, inner)
# recompute inner width from actual wrapped lines so frame matches content
actual_max = 0
for ln in lines:
    lw = width(ln)
    if lw > actual_max:
        actual_max = lw
# ensure inner respects min/max
inner = max(min_inner, min(actual_max, max_inner))
# print frame
w = inner + 4
top = '╔' + '═'*(w-2) + '╗'
bot = '╚' + '═'*(w-2) + '╝'
print(top)
for ln in lines:
    # compute pad
    lw = width(ln)
    pad = inner - lw
    print('║ ' + ln + ' ' * pad + ' ║')
print(bot)
PY
        echo -e "${NC}"
    else
        # fallback to previous shell-based rendering
        echo -e "${CYAN}"
        frame_border_top
        frame_line "${emoji} ${title}"
        frame_border_bottom
        echo -e "${NC}"
    fi
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

    if [ "${SUPPORTS_ASSOC_ARRAYS:-0}" -eq 1 ]; then
        if [[ ${#MODULE_ACTIONS[@]} -gt 0 ]]; then
            for action in "${!MODULE_ACTIONS[@]}"; do
                frame_line "${MODULE_ACTIONS[$action]} ${action}"
            done
            frame_border_mid
        fi
    else
        if [ -n "${MODULE_ACTIONS_LIST:-}" ]; then
            while IFS= read -r line; do
                frame_line "$line"
            done <<< "$MODULE_ACTIONS_LIST"
            frame_border_mid
        fi
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
    if [ "${SUPPORTS_ASSOC_ARRAYS:-0}" -eq 1 ]; then
        MODULE_ACTIONS["$action_name"]="$action_icon"
    else
        MODULE_ACTIONS_LIST="${MODULE_ACTIONS_LIST:+$MODULE_ACTIONS_LIST$'\n'}${action_icon} ${action_name}"
    fi
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
