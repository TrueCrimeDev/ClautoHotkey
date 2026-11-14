#!/bin/bash
# SessionStart (matcher: compact): put back what compaction dropped.
#
# Wired to SessionStart rather than PreCompact or PostCompact because neither of
# those can add to the model's context; a SessionStart hook's plain stdout can,
# and SessionStart fires with source "compact" once the summary is in place.
#
#   - Which AHK scripts are running. Long sessions lose track of what they started.
#   - The path-scoped rules. inject-rules.sh injects each rule once per session and
#     remembers that in a marker file; the rule text itself did not survive the
#     compaction, so the marker is cleared and the next matching edit loads it again.

source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"

input=$(cat)
if [[ -n "${HARNESS_JQ:-}" ]]; then
    session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
    [[ -n "$session_id" ]] && rm -f "/tmp/claude-rules-injected-$session_id" 2>/dev/null
fi

# Get running AHK processes (powershell.exe is on PATH under WSL and Git Bash alike)
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
        echo "  - ${p##*[\\/]}"
    done)
    proc_summary="${count} AHK script(s) running:
${proc_list}"
fi

# Check for active debug sessions
debug_server=$(powershell.exe -NoProfile -Command "
    Get-NetTCPConnection -LocalPort 9000 -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1 | ForEach-Object { 'listening' }
" 2>/dev/null | tr -d '\r')

echo "## AHK Session State (restored after compaction)"
echo
echo "$proc_summary"
[[ "$debug_server" == "listening" ]] && echo "Debug server active on port 9000."
echo "Path-scoped rules load again on the next matching edit."

exit 0
