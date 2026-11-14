#!/bin/bash
# PreToolUse hook for debug MCP tools.
# Checks if AutoHotkey is likely connected by testing port 9000.
# Provides helpful context if the debugger isn't reachable.

source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"

# Read tool input from stdin
INPUT=$(cat)
harness_need_jq || exit 1
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Only check for debug-related MCP tools
case "$TOOL_NAME" in
  mcp__autohotkey-debug__debug_*|mcp__autohotkey-debug__capture_error|mcp__autohotkey-debug__breakpoint_*|mcp__autohotkey-debug__variables_get|mcp__autohotkey-debug__evaluate|mcp__autohotkey-debug__stack_trace|mcp__autohotkey-debug__watch_list)
    echo -e "\x1b[1;92m┌─ HOOK ▸ check-ahk-connection ───────────────────────────\x1b[0m" >&2
    echo -e "\x1b[1;92m│\x1b[0m Pre-check for: \x1b[36m$TOOL_NAME\x1b[0m" >&2
    echo -e "\x1b[1;92m└─────────────────────────────────────────────────────────\x1b[0m" >&2
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "If this tool returns a connection error, tell the user to run their script with the configured interpreter and /Debug: \"$AHK_BIN_WSL\" /Debug script.ahk (source hooks/_harness-env.sh for the path)."}}'
    ;;
  *)
    echo '{}'
    ;;
esac
