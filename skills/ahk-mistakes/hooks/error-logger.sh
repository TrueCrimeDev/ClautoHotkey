#!/usr/bin/env bash
# Log AHK-related tool failures to .claude/error-log.jsonl, the file /ahk-mistakes
# and Tools/lessons.py read.
#
# Wired to PostToolUseFailure in Claude Code: PostToolUse fires only for calls
# that succeeded, and its payload carries neither an exit code nor an error. A
# failed call arrives here with the reason in `.error` - for Bash that is
# "Exit code N" followed by the command's output. The OpenCode bridge has no such
# event and calls this script after every bash tool with the exit code it saw, as
# `.tool_output.exit_code`; both shapes are read.
#
# Logged (decided per call from the tool name and payload):
#   - Bash commands that ran the interpreter and failed
#   - mcp__autohotkey-debug__* / mcp__ahk* tool failures
#   - Edit/Write of *.ahk that failed
# Not logged: the grading gates. They exit 1 whenever a graded script fails, which
# is their verdict on someone else's code, not a mistake made in this session.

set -u

# The shared loader lives in the plugin's hooks/ (this file is bundled with the
# skill); it supplies the jqlite fallback when jq is not installed.
source "$(dirname "${BASH_SOURCE[0]}")/../../../hooks/_harness-env.sh"

input=$(cat)
harness_need_jq || exit 1

tool_name=$(echo "$input" | jq -r '.tool_name  // empty'     2>/dev/null)
session=$(echo "$input"   | jq -r '.session_id // "default"' 2>/dev/null)
err_field=$(echo "$input" | jq -r '.error      // empty'     2>/dev/null)
oc_exit=$(echo "$input"   | jq -r '.tool_output.exit_code // empty' 2>/dev/null)

should_log=false

case "$tool_name" in
    Bash)
        cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
        # A command spells the interpreter as a path or as one of the variables the
        # loader exports; matched in lower case because Windows paths are.
        lc="${cmd,,}"
        case "$lc" in
            *gatestatic.ahk*|*gatepure.ahk*|*gatedryrun.ahk*|*gatelive.ahk*|*selftest.ahk*|*reduce.ahk*)
                ;;
            *autohotkey*.exe*|*ahk_bin_*|*ahk_exe*)
                if [[ -n "$err_field" ]]; then
                    should_log=true
                elif [[ -n "$oc_exit" && "$oc_exit" != "0" ]]; then
                    should_log=true
                fi
                ;;
        esac
        ;;
    mcp__autohotkey-debug__*|mcp__ahk*)
        [[ -n "$err_field" ]] && should_log=true
        ;;
    Edit|Write)
        file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        if [[ "$file_path" == *.ahk && -n "$err_field" ]]; then
            should_log=true
        fi
        ;;
esac

[[ "$should_log" == false ]] && exit 0

# The text to mine: Claude Code's error string without its "Exit code N" first
# line, else what the OpenCode bridge captured.
err_text="$err_field"
if [[ "$err_text" =~ ^Exit\ code\ [0-9]+ ]]; then
    err_text="${err_text#*$'\n'}"
    [[ "$err_text" == "$err_field" ]] && err_text=""
fi
[[ -z "$err_text" ]] && err_text=$(echo "$input" | jq -r '.tool_output.stderr // empty' 2>/dev/null)
[[ -z "$err_text" ]] && err_text=$(echo "$input" | jq -r '.tool_output.stdout // empty' 2>/dev/null)
[[ -z "$err_text" ]] && err_text="$err_field"

file=$(echo "$err_text" | grep -oE '[A-Za-z]:\\[^ ]+\.ahk' | head -1)
[[ -z "$file" ]] && file="unknown"

line=$(echo "$err_text" | grep -oE '\([0-9]+\)' | head -1 | tr -d '()')
[[ -z "$line" ]] && line="0"

err_type=$(echo "$err_text" | grep -oE '(TypeError|ValueError|OSError|TargetError|MemberError|PropertyError|MethodError|UnsetError|ZeroDivisionError|Error)' | head -1)
[[ -z "$err_type" ]] && err_type="unknown"

err_msg=$(echo "$err_text" | head -3 | tr '\n' ' ' | cut -c1-200)

# Always the project-level .claude/error-log.jsonl, wherever this script lives
# (the skill bundles it under skills/ahk-mistakes/hooks/).
log_file="$(harness_log_file error-log.jsonl)"
ts=$(date -u +"%Y-%m-%dT%H:%M:%S")

jq -nc \
    --arg ts "$ts" \
    --arg tool "$tool_name" \
    --arg file "$file" \
    --arg line "$line" \
    --arg type "$err_type" \
    --arg msg "$err_msg" \
    --arg session "$session" \
    '{timestamp: $ts, session: $session, tool: $tool, file: $file, line: ($line | tonumber? // 0), type: $type, message: $msg}' \
    >> "$log_file" 2>/dev/null || true

D="\x1b[90m"
C="\x1b[36m"
R="\x1b[1;91m"
Z="\x1b[0m"
echo -e "${R}━━━ error-logger ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${Z}" >&2
echo -e "    ${C}${file##*\\}${Z}:${line} ${R}${err_type}${Z} ${D}(${tool_name})${Z}" >&2
echo -e "${R}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${Z}" >&2

exit 0
