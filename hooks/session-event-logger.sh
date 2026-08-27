#!/usr/bin/env bash
# Shared Stop / SubagentStop / Notification logger.
# Appends one JSONL line per event to .claude/session-events.jsonl so the
# user can audit session activity over time (counts, durations, which
# subagents ran). One script serves all three events because the structure
# is identical — only the event_name and a few payload fields differ.

set -u

input=$(cat)

event=$(echo "$input"   | jq -r '.hook_event_name // "unknown"' 2>/dev/null)
session=$(echo "$input" | jq -r '.session_id      // empty'     2>/dev/null)
agent=$(echo "$input"   | jq -r '.subagent_type   // empty'     2>/dev/null)
matcher=$(echo "$input" | jq -r '.matcher         // empty'     2>/dev/null)
notif=$(echo "$input"   | jq -r '.notification    // empty'     2>/dev/null)

log_file="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/session-events.jsonl"
ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jq -nc \
    --arg ts "$ts" \
    --arg event "$event" \
    --arg session "$session" \
    --arg agent "$agent" \
    --arg matcher "$matcher" \
    --arg notif "$notif" \
    '{timestamp: $ts, event: $event}
     + (if $session != "" then {session: $session} else {} end)
     + (if $agent   != "" then {agent:   $agent}   else {} end)
     + (if $matcher != "" then {matcher: $matcher} else {} end)
     + (if $notif   != "" then {notification: $notif} else {} end)' \
    >> "$log_file" 2>/dev/null || true

exit 0
