#!/bin/bash
# Post-edit hook: auto-reload running AHK scripts after edits.
# Standalone .ahk: restart it if running.
# Lib/ file: restart any script running from the parent folder.
# Bails if ahk-post-edit.sh dropped the failure sentinel — never restart a
# script that just failed validation.

source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"

input=$(cat)
harness_need_jq || exit 1
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
session_id=$(echo "$input" | jq -r '.session_id // "default"' 2>/dev/null)

# Bail if ahk-post-edit.sh (earlier in the chain) dropped the failure
# sentinel for this session — never restart a script that just failed
# validation. Session-scoped so concurrent sessions don't suppress each other.
EDIT_FAIL_SENTINEL="/tmp/ahk-edit-failed-$session_id"
if [[ -f "$EDIT_FAIL_SENTINEL" ]]; then
    rm -f "$EDIT_FAIL_SENTINEL" 2>/dev/null
    exit 0
fi

# Collect candidate .ahk file paths from either Edit/Write (single path)
# or Bash (parse command for any .ahk references)
file_paths=()
case "$tool_name" in
    Edit|Write|NotebookEdit)
        fp=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        [[ -n "$fp" && "$fp" == *.ahk ]] && file_paths+=("$fp")
        ;;
    Bash)
        cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
        # Extract any token ending in .ahk (handles quoted/unquoted, /mnt/c, C:\)
        while IFS= read -r p; do
            [[ -n "$p" ]] && file_paths+=("$p")
        done < <(echo "$cmd" | grep -oE "[/A-Za-z0-9._\\:-]+\.ahk" | sort -u)
        ;;
    *)
        exit 0 ;;
esac

[[ ${#file_paths[@]} -eq 0 ]] && exit 0

# Restarting means stopping a script and starting it again with the interpreter;
# without one, stop before stopping anything.
harness_need_ahk || exit 1

# A value for a single-quoted PowerShell string, where only ' is special. Doubling
# backslashes (what this used to do) breaks [regex]::Escape, which then looks for
# C:\\Users and never matches a real command line.
ps_quote() { printf '%s' "${1//\'/\'\'}"; }

# Process each detected path (most edits only touch one)
for file_path in "${file_paths[@]}"; do
    # One spelling for this shell, whatever the tool or command used.
    file_path=$(harness_to_unix "$file_path")
    [[ -z "$file_path" || ! "$file_path" == *.ahk ]] && continue

filename=$(basename "$file_path")

# Skip auto-reload for library modules listed in NO_AUTO_RELOAD.
skip_reload=false
IFS=',' read -ra _noreload <<< "${NO_AUTO_RELOAD:-}"
for n in "${_noreload[@]}"; do [[ -n "$n" && "$filename" == "$(echo "$n" | xargs)" ]] && skip_reload=true; done
[[ "$skip_reload" == true ]] && continue

AHK_EXE="${AHK_EXE:-$AHK_BIN_SH}"
AHK_WIN=$(ps_quote "$(harness_to_win "$AHK_EXE")")

D="\x1b[90m"
C="\x1b[36m"
G="\x1b[32m"
Z="\x1b[0m"

if [[ "$file_path" == *"/Lib/"* ]]; then
    lib_dir=$(dirname "$file_path")
    script_dir=$(dirname "$lib_dir")
    search_dir=$(ps_quote "$(harness_to_win "$script_dir")")

    result=$(powershell.exe -NoProfile -Command "
        \$procs = Get-CimInstance Win32_Process -Filter \"Name='AutoHotkey64.exe'\" |
            Where-Object { \$_.CommandLine -match [regex]::Escape('$search_dir') }
        foreach (\$p in \$procs) {
            \$cmd = \$p.CommandLine
            if (\$cmd -match '\"\"([^\"\"]+\\.ahk)\"\"') { \$script = \$Matches[1] }
            elseif (\$cmd -match '\\s([^\\s]+\\.ahk)') { \$script = \$Matches[1] }
            else { continue }
            Stop-Process -Id \$p.ProcessId -Force
            Start-Sleep -Milliseconds 300
            Start-Process '$AHK_WIN' \$script
            Write-Output \$script
        }
    " 2>/dev/null | tr -d '\r')

    if [[ -n "$result" ]]; then
        restarted=$(basename "$result")
        echo -e "${D}─── ${G}reload${D} ──────────────────────────────────${Z}" >&2
        echo -e "    ${G}↺${Z} ${C}${restarted}${Z}  ${D}(lib edit: ${filename})${Z}" >&2
        echo -e "${D}──────────────────────────────────────────${Z}" >&2
    fi
else
    win_filename=$(ps_quote "$(basename "$file_path")")

    result=$(powershell.exe -NoProfile -Command "
        \$proc = Get-CimInstance Win32_Process -Filter \"Name='AutoHotkey64.exe'\" |
            Where-Object { \$_.CommandLine -like ('*' + [WildcardPattern]::Escape('$win_filename') + '*') } |
            Select-Object -First 1
        if (\$proc) {
            \$cmd = \$proc.CommandLine
            if (\$cmd -match '\"\"([^\"\"]+\\.ahk)\"\"') { \$script = \$Matches[1] }
            elseif (\$cmd -match '\\s([^\\s]+\\.ahk)') { \$script = \$Matches[1] }
            else { exit }
            Stop-Process -Id \$proc.ProcessId -Force
            Start-Sleep -Milliseconds 300
            Start-Process '$AHK_WIN' \$script
            Write-Output 'restarted'
        }
    " 2>/dev/null | tr -d '\r')

    if [[ "$result" == *"restarted"* ]]; then
        echo -e "${D}─── ${G}reload${D} ──────────────────────────────────${Z}" >&2
        echo -e "    ${G}↺${Z} ${C}${filename}${Z}  ${D}restarted${Z}" >&2
        echo -e "${D}──────────────────────────────────────────${Z}" >&2
    fi
fi

done

exit 0
