#!/usr/bin/env bash
# End-to-end smoke test for the hook layer. Feeds check-ahk-binary.sh and
# ahk-post-edit.sh payloads shaped like Claude Code's and checks what they do:
# exit status, the key line they print, and the side effects that must (or must
# not) happen. Works under WSL, Git Bash and Cygwin.
#
#   bash Tools/tests/hooks_smoke.sh [HOOKS_DIR]
#
# HOOKS_DIR defaults to this plugin's hooks/; pass a repo-level .claude/hooks to
# run the same cases against that copy. Every run happens in a scratch project
# (CLAUDE_PROJECT_DIR points at it), so error records and sentinels never touch a
# real project. The post-edit cases need a working interpreter; the edited
# scripts are harmless, and the one that calls FileDelete targets a scratch file
# that the dry-run shim must leave in place.
#
# Exit 0 when every case passes, 1 otherwise.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS="${1:-$HERE/../../hooks}"
HOOKS="$(cd "$HOOKS" && pwd)"

source "$HOOKS/_harness-env.sh"

pass=0 fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); [[ -n "${2:-}" ]] && printf '        %s\n' "${2//$'\n'/ | }"; }

# A JSON string literal built in bash, so payloads do not depend on jq or jqlite.
json_str() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '"%s"' "$s"
}

# A path the way Claude Code reports it on this platform.
tool_path() {
    case "$HARNESS_PLATFORM" in
        msys|cygwin) harness_to_win "$1" ;;
        *)           printf '%s\n' "$1" ;;
    esac
}

scratch="$(mktemp -d "${TMPDIR:-/tmp}/clautohotkey-smoke.XXXXXX")"
session="smoke-$$"
cleanup() {
    rm -rf "$scratch"
    rm -f "/tmp/ahk-edit-failed-$session" "/tmp/claude-rules-injected-$session"
}
trap cleanup EXIT

LAST_ERR=""
# bash_case EXPECTED_EXIT DESCRIPTION COMMAND [PROJECT]
bash_case() {
    local want="$1" what="$2" cmd="$3" project="${4:-$real_project}" rc
    LAST_ERR="$(printf '{"session_id":"%s","tool_name":"Bash","tool_input":{"command":%s}}' \
                    "$session" "$(json_str "$cmd")" \
                | CLAUDE_PROJECT_DIR="$(tool_path "$project")" bash "$HOOKS/check-ahk-binary.sh" 2>&1 >/dev/null)"
    rc=$?
    if [[ $rc -eq $want ]]; then
        ok "check-ahk-binary $want: $what"
    else
        bad "check-ahk-binary $what (exit $rc, want $want): $cmd" "$LAST_ERR"
    fi
}

# edit_case EXPECTED_EXIT DESCRIPTION FILE [EXPECTED_STDERR_FRAGMENT] [PATH_FORM]
edit_case() {
    local want="$1" what="$2" file="$3" needle="${4:-}" form="${5:-tool}" p rc
    if [[ "$form" == unix ]]; then p="$file"; else p="$(tool_path "$file")"; fi
    LAST_ERR="$(printf '{"session_id":"%s","tool_name":"Write","tool_input":{"file_path":%s}}' \
                    "$session" "$(json_str "$p")" \
                | CLAUDE_PROJECT_DIR="$(tool_path "$edit_project")" bash "$HOOKS/ahk-post-edit.sh" 2>&1 >/dev/null)"
    rc=$?
    LAST_ERR="$(printf '%s' "$LAST_ERR" | sed 's/\x1b\[[0-9;]*m//g')"
    if [[ $rc -ne $want ]]; then
        bad "ahk-post-edit $what (exit $rc, want $want)" "$LAST_ERR"
    elif [[ -n "$needle" && "$LAST_ERR" != *"$needle"* ]]; then
        bad "ahk-post-edit $what (exit $rc as expected, but no '$needle' in its output)" "$LAST_ERR"
    else
        ok "ahk-post-edit $want: $what"
    fi
}

echo "Hooks under test: $HOOKS"
echo "Platform: $HARNESS_PLATFORM, jq: ${HARNESS_JQ:-none}, interpreter: ${AHK_BIN_WIN:-none}"

echo
echo "Payload encoding"
probe=$'tab\there "quotes" back\\slash C:\\x\\y.ahk \u2014 end'
if [[ -n "${HARNESS_JQ:-}" ]] && [[ "$(printf '{"c":%s}' "$(json_str "$probe")" | jq -r '.c')" == "$probe" ]]; then
    ok "payload strings survive the round trip through ${HARNESS_JQ}"
else
    bad "payload string round trip through ${HARNESS_JQ:-nothing} changed the text"
fi

# A synthetic configuration whose binary does not exist and whose path has the
# characters that broke the old regex match: spaces, parentheses and dots.
synthetic="$scratch/synthetic"
mkdir -p "$synthetic"
printf '%s\n' 'AHK_BIN_WIN="${WIN_HOME:-C:\Users\nobody}\Tools\AHK Fork (x86)\v2.1\AutoHotkey64.exe"' \
    > "$synthetic/harness.env"
fake_win="${WIN_HOME:-C:\\Users\\nobody}\\Tools\\AHK Fork (x86)\\v2.1"

# The real configuration, as resolved for this hooks directory, copied into a
# scratch project so hooks run with it but write nothing into the real one.
real_project="$scratch/real"
mkdir -p "$real_project"
for f in harness.env harness.local.env; do
    [[ -f "$_HARNESS_ROOT/$f" ]] && cp "$_HARNESS_ROOT/$f" "$real_project/$f"
done

echo
echo "check-ahk-binary: ordinary commands"
bash_case 0 "ls" 'ls -la'
bash_case 0 "git status" 'git status'
bash_case 0 "python script" 'python x.py --flag'
bash_case 0 "plain-text mention" 'echo "use AutoHotkey64.exe for this"'

echo
echo "check-ahk-binary: synthetic binary with spaces, parentheses and dots (absent)"
bash_case 1 "configured binary that is missing is reported, not blocked" "\"$fake_win\\AutoHotkey64.exe\" x.ahk" "$synthetic"
bash_case 2 "suffixed copy (.bak)" "\"$fake_win\\AutoHotkey64.exe.bak\" x.ahk" "$synthetic"
bash_case 2 "other exe in the same folder" "\"$fake_win\\AutoHotkey32.exe\" x.ahk" "$synthetic"
bash_case 2 "dot in the folder name is literal" "\"${fake_win%.1}X1\\AutoHotkey64.exe\" x.ahk" "$synthetic"
bash_case 2 "Program Files build" '"/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" x.ahk' "$synthetic"
bash_case 0 "ordinary command" 'ls' "$synthetic"
if [[ -n "${WIN_HOME:-}" ]]; then
    bash_case 1 "\$USERPROFILE-relative spelling" "\"\$USERPROFILE\\Tools\\AHK Fork (x86)\\v2.1\\AutoHotkey64.exe\" x.ahk" "$synthetic"
fi

if [[ -n "${AHK_BIN_WIN:-}" && "${AHK_BIN_MISSING:-0}" != 1 ]]; then
    echo
    echo "check-ahk-binary: the configured binary in every spelling"
    w="$AHK_BIN_WIN"
    fwd="${w//\\//}"
    drive="${fwd:0:1}" rest="${fwd:2}"
    bash_case 0 "Windows path" "\"$w\" /ErrorStdOut /validate x.ahk"
    bash_case 0 "forward slashes" "\"$fwd\" x.ahk"
    bash_case 0 "/c/ spelling" "\"/${drive,,}$rest\" x.ahk"
    bash_case 0 "/mnt/c/ spelling" "/mnt/${drive,,}${rest// /\\ } x.ahk"
    bash_case 0 "lower case" "\"${w,,}\" x.ahk"
    bash_case 0 "doubled backslashes" "\"${w//\\/\\\\}\" x.ahk"
    bash_case 0 "\$AHK_BIN_WSL" '"$AHK_BIN_WSL" /ErrorStdOut x.ahk'
    bash_case 0 "\${AHK_BIN_SH}" '"${AHK_BIN_SH}" /ErrorStdOut x.ahk'
    bash_case 0 "\$AHK_BIN_WIN" '& "$AHK_BIN_WIN" x.ahk'
    if [[ -n "${WIN_HOME:-}" && "${w,,}" == "${WIN_HOME,,}\\"* ]]; then
        tail="${w:${#WIN_HOME}}"
        bash_case 0 "\$USERPROFILE" "\"\$USERPROFILE$tail\" x.ahk"
        bash_case 0 "\${USERPROFILE}" "\"\${USERPROFILE}${tail//\\//}\" x.ahk"
        bash_case 0 "%USERPROFILE%" "cmd /c \"%USERPROFILE%$tail\" x.ahk"
        bash_case 0 "\$env:USERPROFILE" "powershell.exe -Command \"& \\\"\$env:USERPROFILE$tail\\\" x.ahk\""
    fi
    home_unix="$(harness_to_unix "${HOME:-}")"
    sh_path="$AHK_BIN_SH"
    if [[ -n "$home_unix" && "${sh_path,,}" == "${home_unix,,}/"* ]]; then
        bash_case 0 "\$HOME" "\"\$HOME${sh_path:${#home_unix}}\" x.ahk"
        bash_case 0 "~" "~${sh_path:${#home_unix}} x.ahk"
    fi

    echo
    echo "check-ahk-binary: everything else is blocked"
    bash_case 2 "Program Files (/c/ spelling)" '"/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" x.ahk'
    bash_case 2 "Program Files (Windows spelling)" '"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" x.ahk'
    bash_case 2 "Program Files (x86), v1-style name" '"C:\Program Files (x86)\AutoHotkey\AutoHotkey.exe" x.ahk'
    bash_case 2 "upper-case Program Files" '"/C/PROGRAM FILES/AUTOHOTKEY/V2/AUTOHOTKEY64.EXE" x.ahk'
    bash_case 2 ".alpha29.bak next to the configured binary" "\"${AHK_BIN_SH}.alpha29.bak\" x.ahk"
    bash_case 2 "\$AHK_BIN_WSL with a suffix" '"$AHK_BIN_WSL.alpha29.bak" x.ahk'
    bash_case 2 "renamed backup run from its folder" "cd \"${AHK_BIN_SH%/*}\" && ./AutoHotkey64.exe.prev-alpha26 x.ahk"
    bash_case 2 "configured path glued under another directory" "/tmp${AHK_BIN_SH} x.ahk"
    bash_case 2 "configured and unknown binary in one command" "\"\$AHK_BIN_WSL\" a.ahk && \"/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe\" b.ahk"
else
    bad "real-configuration cases skipped: no interpreter configured or it is missing (${AHK_BIN_WIN:-none})"
fi

echo
echo "Inactive hooks are loud"
LAST_ERR="$(printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' \
    | HARNESS_FORCE_JQLITE=1 HARNESS_PYTHON=none CLAUDE_PROJECT_DIR="$(tool_path "$real_project")" \
      bash "$HOOKS/check-ahk-binary.sh" 2>&1 >/dev/null)"
rc=$?
if [[ $rc -eq 1 && "$LAST_ERR" == *"hooks inactive: install jq or Python 3"* ]]; then
    ok "check-ahk-binary without jq or Python: one stderr line, exit 1"
else
    bad "check-ahk-binary without jq or Python (exit $rc)" "$LAST_ERR"
fi
LAST_ERR="$(printf '{"tool_name":"Write","tool_input":{"file_path":"x.ahk"}}' \
    | HARNESS_FORCE_JQLITE=1 HARNESS_PYTHON=none CLAUDE_PROJECT_DIR="$(tool_path "$real_project")" \
      bash "$HOOKS/ahk-post-edit.sh" 2>&1 >/dev/null)"
rc=$?
if [[ $rc -eq 1 && "$LAST_ERR" == *"hooks inactive: install jq or Python 3"* ]]; then
    ok "ahk-post-edit without jq or Python: one stderr line, exit 1"
else
    bad "ahk-post-edit without jq or Python (exit $rc)" "$LAST_ERR"
fi

echo
echo "ahk-post-edit"
if [[ -n "${AHK_BIN_WIN:-}" && "${AHK_BIN_MISSING:-0}" != 1 ]]; then
    # Same interpreter as the real configuration, with the runtime probe forced on.
    edit_project="$scratch/edit"
    mkdir -p "$edit_project/.claude" "$edit_project/Lib"
    {
        for f in harness.env harness.local.env; do
            [[ -f "$_HARNESS_ROOT/$f" ]] && { tr -d '\r' < "$_HARNESS_ROOT/$f"; echo; }
        done
        echo 'RUNTIME_PROBE=1'
        echo 'MAIN_SCRIPT="main.ahk"'
        echo 'DEPENDENCY_SCRIPTS=""'
        echo 'NO_RUNTIME_CHECK=""'
    } > "$edit_project/harness.env"
    e="$edit_project"
    printf '%s\n' '#Requires AutoHotkey v2.0' 'x := ' > "$e/broken.ahk"
    printf '%s\n' '#Requires AutoHotkey v2.0' 'x := 1' > "$e/clean.ahk"
    printf '%s\n' '#Requires AutoHotkey v2.0' 'x := 1' > "$e/main.ahk"
    printf '%s\n' 'not an ahk file' > "$e/notes.txt"

    edit_case 2 "blocks a syntax error (Claude Code path form)" "$e/broken.ahk" "syntax error"
    edit_case 2 "blocks a syntax error (shell path form)" "$e/broken.ahk" "syntax error" unix
    if [[ -f "/tmp/ahk-edit-failed-$session" ]]; then
        ok "failure sentinel left for ahk-auto-reload"
    else
        bad "no failure sentinel at /tmp/ahk-edit-failed-$session"
    fi
    if [[ -s "$e/.claude/error-log.jsonl" ]] \
            && grep -q '"type":"syntax"' "$e/.claude/error-log.jsonl"; then
        ok "syntax error logged to the project's .claude/error-log.jsonl"
    else
        bad "no syntax record in the scratch project's error log"
    fi
    edit_case 0 "passes a clean script" "$e/clean.ahk" "clean.ahk"
    edit_case 0 "passes a clean script (shell path form)" "$e/clean.ahk" "clean.ahk" unix
    edit_case 0 "ignores a non-.ahk file" "$e/notes.txt"

    # The probe only runs on the +Console fork (AHK_DIAG_JSON=1), as the hook decides.
    probe_on=0
    if [[ "$(CLAUDE_PROJECT_DIR="$(tool_path "$e")" bash -c 'source "$1/_harness-env.sh"; echo "$AHK_DIAG_JSON"' _ "$HOOKS")" == 1 ]]; then
        probe_on=1
    fi
    if [[ "$probe_on" == 1 ]]; then
        printf '%s\n' '#Requires AutoHotkey v2.0' 'y := [1,2]' 'z := y[5]' > "$e/rterr.ahk"
        printf '%s\n' '#Requires AutoHotkey v2.0' 'y := [1,2]' 'z := y[5]' > "$e/Lib/libmod.ahk"
        edit_case 2 "blocks a runtime error caught by the probe" "$e/rterr.ahk" "runtime error"
        edit_case 0 "Lib/ file: rechecks the main script and does not run the file" "$e/Lib/libmod.ahk" "main"

        echo keep > "$e/sentinel.txt"
        sentinel_win="$(harness_to_win "$e/sentinel.txt")"
        printf '%s\n' '#Requires AutoHotkey v2.0' "FileDelete(\"$sentinel_win\")" 'FileAppend("ran`n", "*")' > "$e/deleter.ahk"
        edit_case 0 "probes a script that deletes a file" "$e/deleter.ahk" "runtime"
        if [[ -f "$e/sentinel.txt" ]]; then
            ok "the dry-run shim kept FileDelete from deleting anything"
        else
            bad "the probe deleted the sentinel file - the runtime probe is not contained"
            echo keep > "$e/sentinel.txt"
        fi

        printf '%s\n' '#Requires AutoHotkey v2.0' '#Import AHK {FileDelete as RealDelete}' \
            "RealDelete(\"$sentinel_win\")" > "$e/importer.ahk"
        edit_case 0 "skips the probe for #Import AHK" "$e/importer.ahk" "skipped: #Import AHK"
        [[ -f "$e/sentinel.txt" ]] && ok "#Import AHK script was not run" \
                                   || bad "#Import AHK script ran and deleted the sentinel"

        printf '%s\n' '#Requires AutoHotkey v2.0' 'FileDelete(p) {' '    return 0' '}' 'FileDelete("x")' > "$e/redefines.ahk"
        edit_case 0 "a script redefining a shimmed built-in is not blocked" "$e/redefines.ahk" "skipped"
        [[ -f "$e/sentinel.txt" ]] || bad "sentinel vanished during the redefinition case"

        stray="$(ls -d "${TMPDIR:-/tmp}"/ahk-probe.* 2>/dev/null | wc -l)"
        [[ "$stray" -eq 0 ]] && ok "no probe scratch directories left behind" \
                             || bad "$stray ahk-probe.* scratch directories left in ${TMPDIR:-/tmp}"
    else
        printf '  SKIP  runtime-probe cases: AHK_DIAG_JSON is not 1 (stock AutoHotkey has no /Headless)\n'
    fi
else
    bad "post-edit cases skipped: no interpreter configured or it is missing (${AHK_BIN_WIN:-none})"
fi

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -gt 0 ]] && exit 1
exit 0
