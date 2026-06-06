#!/bin/bash
# PostCompact hook: Re-inject running AHK process state after context compaction.
# Long sessions lose awareness of what's running — this restores it.

source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"

# Get running AHK processes
processes=$(powershell.exe -NoProfile -Command "
    Get-CimInstance Win32_Process -Filter \"Name='AutoHotkey64.exe'\" |
    ForEach-Object {
        if (\$_.CommandLine -match '[\"\" ]([A-Za-z]:\\\\[^\"\"]+\\.ahk)') {
            \$Matches[1]
        }
    }
" 2>/dev/null | tr -d '\r' | grep -v '^$')

if [[ -z "$processes" ]]; then
    proc_summary="No AHK scripts currently running."
else
    count=$(echo "$processes" | wc -l)
    proc_list=$(echo "$processes" | while IFS= read -r p; do
        echo "  - $(basename "$p")"
    done)
    proc_summary="${count} AHK script(s) running:
${proc_list}"
fi

# Check for active debug sessions
debug_server=$(powershell.exe -NoProfile -Command "
    Get-NetTCPConnection -LocalPort 9000 -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1 | ForEach-Object { 'listening' }
" 2>/dev/null | tr -d '\r')

if [[ "$debug_server" == "listening" ]]; then
    debug_note="Debug server active on port 9000."
else
    debug_note=""
fi

# Build context injection
context="## AHK Session State (restored after compaction)

${proc_summary}"

if [[ -n "$debug_note" ]]; then
    context="${context}
${debug_note}"
fi

# Return as additionalContext so Claude sees it
jq -nc --arg ctx "$context" '{"additionalContext": $ctx}'

exit 0
