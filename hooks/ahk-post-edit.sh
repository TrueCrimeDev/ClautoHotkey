#!/bin/bash
# Post-edit hook for AutoHotkey v2 scripts
# Validates syntax after edits using the custom engine's check command
# with structured JSON diagnostics. Blocks on syntax errors.
# Also runs standalone scripts briefly to catch runtime errors.

# Timing
start_ns=$(date +%s%N)

# Load config (AHK_BIN_WSL, AHK_DIAG_JSON, MAIN_SCRIPT, dependency lists).
source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"
AHK_EXE="${AHK_EXE:-$AHK_BIN_WSL}"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${PROJECT_DIR:-$(pwd)}}"
MAIN_SCRIPT="${MAIN_SCRIPT:-main.ahk}"

# Validate a file with the right command for the build:
# fork (AHK_DIAG_JSON=1) emits JSON diagnostics; stock falls back to /validate.
ahk_validate() {
    if [[ "${AHK_DIAG_JSON:-0}" == "1" ]]; then
        "$AHK_EXE" check /Diag=json /ErrorStdOut "$1" 2>&1
    else
        "$AHK_EXE" /ErrorStdOut /validate "$1" 2>&1
    fi
}

# Parse JSON from stdin to get the edited file path
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
session_id=$(echo "$input" | jq -r '.session_id // "default"' 2>/dev/null)

# Only process .ahk files (skip .d.ahk type declaration stubs)
if [[ ! "$file_path" == *.ahk ]] || [[ "$file_path" == *.d.ahk ]]; then
    exit 0
fi

filename=$(basename "$file_path")

# Sentinel for auto-reload coordination. Cleared on entry; re-touched on any
# failure path so ahk-auto-reload.sh (next in the PostToolUse chain) bails
# rather than restarting a script that just failed validation.
EDIT_FAIL_SENTINEL="/tmp/ahk-edit-failed-$session_id"
rm -f "$EDIT_FAIL_SENTINEL" 2>/dev/null

mark_failed() { touch "$EDIT_FAIL_SENTINEL" 2>/dev/null; }

# Append a structured error record to .claude/error-log.jsonl so /ahk-mistakes
# can surface recurring patterns. Hook-blocked failures don't surface a tool
# .error field, so the standalone error-logger hook misses them — log here.
log_error() {
    local err_type="$1" err_line="$2" err_msg="$3"
    local log_file="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/error-log.jsonl"
    local ts=$(date -u +"%Y-%m-%dT%H:%M:%S")
    jq -nc \
        --arg ts "$ts" \
        --arg tool "post-edit" \
        --arg file "$filename" \
        --arg line "$err_line" \
        --arg type "$err_type" \
        --arg msg "$err_msg" \
        '{timestamp: $ts, tool: $tool, file: $file, line: ($line | tonumber? // 0), type: $type, message: $msg}' \
        >> "$log_file" 2>/dev/null || true
}

# ── Colors ──
D="\x1b[90m"    # dim gray
B="\x1b[1m"     # bold
C="\x1b[36m"    # cyan
G="\x1b[32m"    # green
BG="\x1b[1;32m" # bold green
R="\x1b[91m"    # red
BR="\x1b[1;91m" # bold red
Y="\x1b[33m"    # yellow
Z="\x1b[0m"     # reset

# ── Lines ──
TOP="──────────────────────────────────────"

# Helper: elapsed time in ms
elapsed_ms() {
    echo $(( ($(date +%s%N) - start_ns) / 1000000 ))
}

# Helper: print failure block
fail_block() {
    local label="$1"
    local detail="$2"
    echo "" >&2
    echo -e "${BR}━━━ ✗ ahk ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${Z}" >&2
    echo -e "    ${BR}✗${Z} ${B}${C}${filename}${Z}  ${D}·${Z}  ${BR}${label}${Z}" >&2
    echo -e "      ${R}${detail}${Z}" >&2
    echo -e "${BR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${Z}" >&2
    echo "" >&2
}

# Emit the model-facing block guidance. Written to stderr because callers
# exit 2 — Claude Code feeds a PostToolUse hook's stderr back to the model
# only on exit 2 (exit 1 is a non-blocking error shown to the user alone).
block_response() {
    local reason="$1"
    local context="$2"
    echo "$reason" >&2
    echo "$context" >&2
}

# Convert WSL path to Windows path for the AHK engine
if [[ "$file_path" == /mnt/* ]]; then
    win_path=$(wslpath -w "$file_path" 2>/dev/null)
else
    win_path="$file_path"
fi

# Track which steps passed
passed_steps=""

# --- Step 1: Validate the edited file ---

validation_output=$(ahk_validate "$win_path")
validation_exit=$?

if [[ $validation_exit -ne 0 ]]; then
    if [[ "${AHK_DIAG_JSON:-0}" == "1" ]]; then
        diag_msg=$(echo "$validation_output" | jq -r '.message // empty' 2>/dev/null)
        diag_line=$(echo "$validation_output" | jq -r '.line // empty' 2>/dev/null)
    else
        diag_line=$(echo "$validation_output" | grep -oE '\(([0-9]+)\)' | head -1 | tr -d '()')
        diag_msg=$(echo "$validation_output" | sed -n 's/.*==> //p' | head -1)
    fi

    if [[ -n "$diag_msg" ]]; then
        error_detail="Line ${diag_line:-?}: $diag_msg"
    else
        error_detail="$validation_output"
    fi

    mark_failed
    log_error "syntax" "${diag_line:-0}" "${diag_msg:-$error_detail}"
    fail_block "syntax error" "$error_detail"
    block_response \
        "AHK v2 syntax error in $filename: $error_detail" \
        "Fix the syntax error and retry (validation exit $validation_exit)."
    exit 2
fi

passed_steps="syntax"

# --- Step 2: If main script dependency was edited, validate main script too ---

is_dependency=false
[[ "$filename" == "$MAIN_SCRIPT" ]] && is_dependency=true
IFS=',' read -ra _deps <<< "${DEPENDENCY_SCRIPTS:-}"
for d in "${_deps[@]}"; do [[ -n "$d" && "$filename" == "$(echo "$d" | xargs)" ]] && is_dependency=true; done

if [[ "$file_path" == *"/Lib/"* ]]; then
    is_dependency=true
fi

if [[ "$is_dependency" == true && -n "$MAIN_SCRIPT" && -f "$PROJECT_DIR/$MAIN_SCRIPT" ]]; then
    main_win_path=$(wslpath -w "$PROJECT_DIR/$MAIN_SCRIPT" 2>/dev/null)

    main_output=$(ahk_validate "$main_win_path")
    main_exit=$?

    if [[ $main_exit -ne 0 ]]; then
        diag_msg=$(echo "$main_output" | jq -r '.message // empty' 2>/dev/null)
        diag_line=$(echo "$main_output" | jq -r '.line // empty' 2>/dev/null)

        if [[ -n "$diag_msg" ]]; then
            error_detail="Line $diag_line: $diag_msg"
        else
            error_detail="$main_output"
        fi

        mark_failed
        log_error "main-script-broken" "${diag_line:-0}" "broke $MAIN_SCRIPT: ${diag_msg:-$error_detail}"
        fail_block "broke $MAIN_SCRIPT" "$error_detail"
        block_response \
            "Main script ($MAIN_SCRIPT) validation failed after editing $filename: $error_detail" \
            "The edit to $filename broke the main script. Check #Include directives and shared dependencies."
        exit 2
    fi

    passed_steps="$passed_steps  main"
fi

# --- Step 3: Runtime error check for standalone scripts ---

run_runtime_check=true

# Global toggle — RUNTIME_PROBE=0 disables the runtime probe everywhere
# (useful for example/knowledge repos full of GUI scripts).
[[ "${RUNTIME_PROBE:-1}" != "1" ]] && run_runtime_check=false

# The runtime probe uses /Headless (fork-only). Skip it on stock AHK so we
# never launch GUI windows or trip on an unknown switch.
[[ "${AHK_DIAG_JSON:-0}" != "1" ]] && run_runtime_check=false

if [[ "$file_path" == *"/Lib/"* ]]; then
    run_runtime_check=false
fi

[[ "$filename" == "$MAIN_SCRIPT" ]] && run_runtime_check=false
IFS=',' read -ra _norun <<< "${NO_RUNTIME_CHECK:-}"
for n in "${_norun[@]}"; do [[ -n "$n" && "$filename" == "$(echo "$n" | xargs)" ]] && run_runtime_check=false; done

if [[ "$run_runtime_check" == true ]]; then
    runtime_err_tmp="/tmp/ahk_runtime_err-$session_id.txt"
    runtime_stdout=$(timeout 2 "$AHK_EXE" /ErrorStdOut /Headless "$win_path" 2>"$runtime_err_tmp")
    runtime_exit=$?
    runtime_stderr=$(cat "$runtime_err_tmp" 2>/dev/null)
    rm -f "$runtime_err_tmp"

    if [[ $runtime_exit -eq 124 ]]; then
        # Timeout — normal for persistent scripts
        passed_steps="$passed_steps  ${Y}runtime${D}(persistent)"
    elif [[ $runtime_exit -ne 0 ]]; then
        if [[ -n "$runtime_stderr" ]]; then
            rt_diag_msg=$(echo "$runtime_stderr" | jq -r '.message // empty' 2>/dev/null)
            rt_diag_line=$(echo "$runtime_stderr" | jq -r '.line // empty' 2>/dev/null)

            if [[ -n "$rt_diag_msg" ]]; then
                rt_error_detail="Line $rt_diag_line: $rt_diag_msg"
            else
                rt_error_detail="$runtime_stderr"
            fi
        elif [[ -n "$runtime_stdout" ]]; then
            rt_error_detail="$runtime_stdout"
        else
            rt_error_detail="Exit code $runtime_exit (no output)"
        fi

        mark_failed
        log_error "runtime" "${rt_diag_line:-0}" "${rt_diag_msg:-$rt_error_detail}"
        fail_block "runtime error" "$rt_error_detail"
        block_response \
            "AHK v2 runtime error in $filename: $rt_error_detail" \
            "Syntax was OK but the script hit a runtime error (exit $runtime_exit). Fix the error and retry. Common causes: undefined variables, wrong function signatures, missing #Include files, type mismatches. Use get_source_context to read the code around the error line."
        exit 2
    else
        passed_steps="$passed_steps  runtime"
    fi
fi

# Step 4 (restart) removed — ahk-auto-reload.sh handles restarts.
# It runs next in the PostToolUse chain and skips if the sentinel above is set.

# ── Success ──
ms=$(elapsed_ms)
echo "" >&2
echo -e "${BG}━━━ ✓ ahk ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${Z}" >&2
echo -e "    ${BG}✓${Z} ${B}${C}${filename}${Z}  ${D}${passed_steps}  ${ms}ms${Z}" >&2
echo -e "${BG}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${Z}" >&2
exit 0
