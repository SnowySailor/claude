#!/bin/bash
# Claude Code status line: model, session cost, token usage, context %, cache expiry, session/weekly usage % + reset, git branch.
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
IN_TOK=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; DIM='\033[2m'; RESET='\033[0m'

# Format token counts compactly (e.g. 15500 -> 15.5k, 1200000 -> 1.2M)
fmt_tokens() {
    awk -v n="$1" 'BEGIN {
        if (n >= 1000000) printf "%.1fM", n/1000000;
        else if (n >= 1000) printf "%.1fk", n/1000;
        else printf "%d", n;
    }'
}
IN_FMT=$(fmt_tokens "$IN_TOK")

# Color the context percentage by how full it is.
if [ "$PCT" -ge 90 ]; then PCT_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then PCT_COLOR="$YELLOW"
else PCT_COLOR="$GREEN"; fi

COST_FMT=$(printf '$%.2f' "$COST")

NOW=$(date +%s)

# Format a duration in seconds: 2d05h / 1h23m / 4m12s / 42s. Pass "nosec" to drop seconds above 1m.
fmt_dur() {
    local s=$1 mode=$2
    [ "$s" -lt 0 ] && s=0
    if [ "$s" -ge 86400 ]; then printf '%dd%02dh' $((s / 86400)) $((s % 86400 / 3600))
    elif [ "$s" -ge 3600 ]; then printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
    elif [ "$s" -ge 60 ]; then
        if [ "$mode" = "nosec" ]; then printf '%dm' $((s / 60))
        else printf '%dm%02ds' $((s / 60)) $((s % 60)); fi
    else printf '%ds' "$s"; fi
}

# Plan usage for the current 5-hour session (only present for Pro/Max subscribers
# after the first API response; omitted from the line when unavailable).
SESSION_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
SESSION_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' | cut -d. -f1)
WEEKLY_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
WEEKLY_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty' | cut -d. -f1)
SESSION=""
if [ -n "$SESSION_PCT" ]; then
    if [ "$SESSION_PCT" -ge 90 ]; then S_COLOR="$RED"
    elif [ "$SESSION_PCT" -ge 70 ]; then S_COLOR="$YELLOW"
    else S_COLOR="$GREEN"; fi
    RESET_IN=""
    [ -n "$SESSION_RESET" ] && RESET_IN=" ${DIM}($(fmt_dur $((SESSION_RESET - NOW)) nosec))${RESET}"
    SESSION=" ${DIM}|${RESET} ⏱️ ${S_COLOR}${SESSION_PCT}%${RESET} session${RESET_IN}"
fi

# Prompt cache countdown (Claude Code v2.1.251+). expires_at is epoch seconds; ttl is "5m" or "1h".
CACHE=""
# Note: no "// empty" here, since jq's // treats false as missing and we need to see warm=false.
CACHE_WARM=$(echo "$input" | jq -r 'if .prompt_cache then (.prompt_cache.warm | tostring) else empty end')
if [ -n "$CACHE_WARM" ]; then
    CACHE_TTL=$(echo "$input" | jq -r '.prompt_cache.ttl // empty')
    CACHE_EXP=$(echo "$input" | jq -r '.prompt_cache.expires_at // empty' | cut -d. -f1)
    CACHE_LEFT=-1
    [ "$CACHE_WARM" = "true" ] && [ -n "$CACHE_EXP" ] && CACHE_LEFT=$((CACHE_EXP - NOW))
    if [ "$CACHE_LEFT" -gt 0 ]; then
        if [ "$CACHE_LEFT" -lt 60 ]; then C_COLOR="$RED"
        elif [ "$CACHE_LEFT" -lt 180 ]; then C_COLOR="$YELLOW"
        else C_COLOR="$GREEN"; fi
        CACHE=" ${DIM}|${RESET} 🧊 ${C_COLOR}$(fmt_dur "$CACHE_LEFT")${RESET}${CACHE_TTL:+ ${DIM}(${CACHE_TTL})${RESET}}"
    else
        CACHE=" ${DIM}| 🧊 cold${RESET}"
    fi
fi

WEEKLY=""
if [ -n "$WEEKLY_PCT" ]; then
    if [ "$WEEKLY_PCT" -ge 90 ]; then S_COLOR="$RED"
    elif [ "$WEEKLY_PCT" -ge 70 ]; then S_COLOR="$YELLOW"
    else S_COLOR="$GREEN"; fi
    W_RESET_IN=""
    [ -n "$WEEKLY_RESET" ] && W_RESET_IN=" ${DIM}($(fmt_dur $((WEEKLY_RESET - NOW)) nosec))${RESET}"
    WEEKLY=" ${DIM}|${RESET} ⏱️ ${S_COLOR}${WEEKLY_PCT}%${RESET} weekly${W_RESET_IN}"
fi

MODEL_LABEL="$MODEL"
[ -n "$EFFORT" ] && MODEL_LABEL="$MODEL · $EFFORT"

BRANCH=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    DIRTY=""
    [ -n "$(git --no-optional-locks status --porcelain --ignore-submodules=dirty 2>/dev/null)" ] && DIRTY=" ${RED}*${RESET}"
    BRANCH=" ${DIM}|${RESET} 🌿 $(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)${DIRTY}"
fi

echo -e "${CYAN}[$MODEL_LABEL]${RESET} ${DIM}|${RESET} 💰 ${YELLOW}${COST_FMT}${RESET} ${DIM}|${RESET} 🎟️ ${IN_FMT} in ${DIM}|${RESET} ${PCT_COLOR}${PCT}%${RESET} ctx${CACHE}${SESSION}${WEEKLY}${BRANCH}"
