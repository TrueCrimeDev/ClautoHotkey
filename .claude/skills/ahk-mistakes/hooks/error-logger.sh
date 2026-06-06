#!/usr/bin/env bash
# PostToolUse hook: log AHK-related errors to .claude/error-log.jsonl
# Merges the previous error-pattern-logger.sh + failure-error-logger.sh into
# a single stdin-driven logger.
#
# Triggers (decided per call by inspecting tool name + payload):
#   - Bash commands invoking AutoHotkey64.exe / AutoHotkey32.exe / `ahk check`
#     when the command exited non-zero
#   - mcp__autohotkey-debug__* / mcp__ahk* tool failures
#   - Edit/Write of *.ahk that returned an error

set -u

input=$(cat)

tool_name=$(echo "$input"  | jq -r '.tool_name  // empty' 2>/dev/null)
tool_input=$(echo "$input" | jq -r '.tool_input // empty' 2>/dev/null)
tool_output=$(echo "$input"| jq -r '.tool_output// empty' 2>/dev/null)
err_field=$(echo "$input"  | jq -r '.error      // empty' 2>/dev/null)

should_log=false

case "$tool_name" in
    Bash)
        cmd=$(echo "$tool_input" | jq -r '.command // empty' 2>/dev/null)
        case "$cmd" in
            *AutoHotkey64.exe*|*AutoHotkey32.exe*|*ahk*check*)
                exit_code=$(echo "$tool_output" | jq -r '.exit_code // empty' 2>/dev/null)
                if [[ -n "$exit_code" && "$exit_code" != "0" ]]; then
                    should_log=true
                fi
                ;;
        esac
        ;;
    mcp__autohotkey-debug__*|mcp__ahk*)
        [[ -n "$err_field" ]] && should_log=true
        ;;
    Edit|Write)
        file_path=$(echo "$tool_input" | jq -r '.file_path // empty' 2>/dev/null)
        if [[ "$file_path" == *.ahk && -n "$err_field" ]]; then
            should_log=true
        fi
        ;;
esac

[[ "$should_log" == false ]] && exit 0

err_text="$err_field"
[[ -z "$err_text" ]] && err_text=$(echo "$tool_output" | jq -r '.stderr // empty' 2>/dev/null)
[[ -z "$err_text" ]] && err_text=$(echo "$tool_output" | jq -r '.stdout // empty' 2>/dev/null)

file=$(echo "$err_text" | grep -oE '[A-Za-z]:\\[^ ]+\.ahk' | head -1)
[[ -z "$file" ]] && file="unknown"

line=$(echo "$err_text" | grep -oE '\([0-9]+\)' | head -1 | tr -d '()')
[[ -z "$line" ]] && line="0"

err_type=$(echo "$err_text" | grep -oE '(TypeError|ValueError|OSError|TargetError|MemberError|PropertyError|MethodError|UnsetError|ZeroDivisionError|Error)' | head -1)
[[ -z "$err_type" ]] && err_type="unknown"

err_msg=$(echo "$err_text" | head -3 | tr '\n' ' ' | cut -c1-200)

# Always log to the project-level .claude/error-log.jsonl regardless of where
# this script lives (skill bundles us under skills/ahk-mistakes/hooks/).
log_file="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/error-log.jsonl"
ts=$(date -u +"%Y-%m-%dT%H:%M:%S")

jq -nc \
    --arg ts "$ts" \
    --arg tool "$tool_name" \
    --arg file "$file" \
    --arg line "$line" \
    --arg type "$err_type" \
    --arg msg "$err_msg" \
    '{timestamp: $ts, tool: $tool, file: $file, line: ($line | tonumber? // 0), type: $type, message: $msg}' \
    >> "$log_file" 2>/dev/null || true

D="\x1b[90m"
C="\x1b[36m"
R="\x1b[1;91m"
Z="\x1b[0m"
echo -e "${R}━━━ error-logger ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${Z}" >&2
echo -e "    ${C}${file##*\\}${Z}:${line} ${R}${err_type}${Z} ${D}(${tool_name})${Z}" >&2
echo -e "${R}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${Z}" >&2

exit 0
