#!/usr/bin/env bash
# End-to-end smoke test for the hook layer. Feeds the hooks payloads shaped like
# Claude Code's and checks what they do: exit status, the key line they print, and
# the side effects that must (or must not) happen. Works under WSL, Git Bash and
# Cygwin. Every hook that answers the model or writes a log has a case here: a
# hook that reads a field the host never sends, or answers in a shape the host
# drops, fails without a sound in every session, and only a test notices.
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
    rm -f "/tmp/claude-rules-injected-$session" /tmp/claude-rules-injected-"$session"-*
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
        edit_case 0 "skips the probe for #Import AHK" "$e/importer.ahk" "skipped: #Import"
        [[ -f "$e/sentinel.txt" ]] && ok "#Import AHK script was not run" \
                                   || bad "#Import AHK script ran and deleted the sentinel"

        # The other ways past the shim: the names-first spelling, the statement
        # form, code inside a module of its own, and any of them one #Include away.
        # Builds differ on the first two (alpha.38 reads neither as an import).
        # Where the interpreter parses the file the probe must be skipped; where
        # it does not, the syntax step blocks the edit. The file never runs.
        import_spelling_case() { # DESCRIPTION FILE
            if "$AHK_BIN_SH" check /Diag=json /ErrorStdOut "$(harness_to_win "$2")" >/dev/null 2>&1; then
                edit_case 0 "skips the probe for $1" "$2" "skipped: #Import"
            else
                edit_case 2 "blocks $1, which this build does not parse" "$2" "syntax error"
            fi
        }
        printf '%s\n' '#Requires AutoHotkey v2.1-alpha.30' '#Import {FileDelete as RealDelete} from AHK' \
            "RealDelete(\"$sentinel_win\")" > "$e/importer2.ahk"
        import_spelling_case "#Import {...} from AHK" "$e/importer2.ahk"
        printf '%s\n' '#Requires AutoHotkey v2.1-alpha.30' 'Import {FileDelete as RealDelete} from AHK' \
            "RealDelete(\"$sentinel_win\")" > "$e/importer3.ahk"
        import_spelling_case "an Import statement" "$e/importer3.ahk"
        printf '%s\n' '#Requires AutoHotkey v2.1-alpha.30' '#Import Worker {Wipe}' 'Wipe()' \
            '#Module Worker' "Wipe() => FileDelete(\"$sentinel_win\")" > "$e/modular.ahk"
        edit_case 0 "skips the probe for a script with a #Module section" "$e/modular.ahk" "skipped: #Import"
        mkdir -p "$e/inc"
        printf '%s\n' '#Import AHK {FileDelete as RealDelete}' "RealDelete(\"$sentinel_win\")" > "$e/inc/real.ahk"
        printf '%s\n' '#Requires AutoHotkey v2.1-alpha.30' '#Include inc\real.ahk' > "$e/viainclude.ahk"
        edit_case 0 "skips the probe when an included file imports from AHK" "$e/viainclude.ahk" "skipped: #Import"
        [[ -f "$e/sentinel.txt" ]] && ok "no module-using script was run" \
                                   || bad "a module-using script ran and deleted the sentinel"

        printf '%s\n' '#Requires AutoHotkey v2.0' 'FileDelete(p) {' '    return 0' '}' 'FileDelete("x")' > "$e/redefines.ahk"
        edit_case 0 "a script redefining a shimmed built-in is not blocked" "$e/redefines.ahk" "skipped"
        [[ -f "$e/sentinel.txt" ]] || bad "sentinel vanished during the redefinition case"

        rm -f "$e/gone.ahk"
        edit_case 0 "ignores a file deleted before the hook ran" "$e/gone.ahk"

        # A module only reached through another script's #Include: run on its own it
        # reports Helper as never assigned; through its includer it passes, and a
        # real error in it is reported through the includer.
        mkdir -p "$e/app"
        printf '%s\n' 'class Helper {' '    static Y := 1' '}' > "$e/app/Helper.ahk"
        printf '%s\n' 'class Mod {' '    static X := Helper.Y' '}' > "$e/app/Mod.ahk"
        printf '%s\n' '#Requires AutoHotkey v2.0' '#Include Helper.ahk' '#Include Mod.ahk' \
            'FileAppend(Mod.X "`n", "*")' > "$e/app/app.ahk"
        edit_case 0 "probes the includer instead of a module on its own" "$e/app/Mod.ahk" "via app.ahk"
        printf '%s\n' 'class Mod {' '    static X := Helper.Z' '}' > "$e/app/Mod.ahk"
        edit_case 2 "a module's real error surfaces through its includer" "$e/app/Mod.ahk" "through app.ahk"

        stray="$(ls -d "${TMPDIR:-/tmp}"/ahk-probe.* 2>/dev/null | wc -l)"
        [[ "$stray" -eq 0 ]] && ok "no probe scratch directories left behind" \
                             || bad "$stray ahk-probe.* scratch directories left in ${TMPDIR:-/tmp}"
    else
        printf '  SKIP  runtime-probe cases: AHK_DIAG_JSON is not 1 (stock AutoHotkey has no /Headless)\n'
    fi
else
    bad "post-edit cases skipped: no interpreter configured or it is missing (${AHK_BIN_WIN:-none})"
fi

# hook_out HOOK PAYLOAD [VAR=value ...]: run a hook on a payload in the scratch
# project "$quiet_project"; stdout lands in HOOK_OUT, stderr in HOOK_ERR, the exit
# status in HOOK_RC.
quiet_project="$scratch/quiet"
mkdir -p "$quiet_project"
hook_out() {
    local hook="$1" payload="$2"; shift 2
    HOOK_OUT="$(printf '%s' "$payload" \
        | env "$@" CLAUDE_PROJECT_DIR="$(tool_path "$quiet_project")" bash "$hook" 2>"$scratch/hook.err")"
    HOOK_RC=$?
    HOOK_ERR="$(cat "$scratch/hook.err")"
}
# expect DESCRIPTION CONDITION...: the condition is a command; its status decides.
expect() {
    local what="$1"; shift
    if "$@"; then ok "$what"; else bad "$what" "rc=$HOOK_RC out=${HOOK_OUT:0:200} err=${HOOK_ERR:0:200}"; fi
}
has() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }

echo
echo "check-ahk-binary: a bare name is judged by what PATH resolves it to"
# Stand-in binaries; lower-case names so the lookup also works where names are
# case-sensitive. Nothing runs them: the hook only asks where the name leads.
mkdir -p "$scratch/conf" "$scratch/other" "$scratch/bareproj"
printf '#!/bin/sh\n' > "$scratch/conf/autohotkey64.exe"
printf '#!/bin/sh\n' > "$scratch/other/autohotkey64.exe"
chmod +x "$scratch/conf/autohotkey64.exe" "$scratch/other/autohotkey64.exe"
printf 'AHK_BIN_WIN=%s\n' "'$(tool_path "$scratch/conf/autohotkey64.exe")'" > "$scratch/bareproj/harness.env"
bare_case() { # EXPECTED_EXIT DESCRIPTION COMMAND PATH_DIR
    local rc
    printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(json_str "$3")" \
        | PATH="$4:$PATH" CLAUDE_PROJECT_DIR="$(tool_path "$scratch/bareproj")" bash "$HOOKS/check-ahk-binary.sh" >/dev/null 2>&1
    rc=$?
    [[ $rc -eq $1 ]] && ok "check-ahk-binary $1: $2" || bad "check-ahk-binary $2 (exit $rc, want $1): $3"
}
bare_case 2 "bare name, PATH leads to another build" 'AutoHotkey64.exe /ErrorStdOut x.ahk' "$scratch/other"
bare_case 2 "bare name after cd &&" 'cd /tmp && AutoHotkey64.exe x.ahk' "$scratch/other"
bare_case 2 "bare name behind timeout" 'timeout -k 2 10s "AutoHotkey64.exe" x.ahk' "$scratch/other"
bare_case 2 "bare name inside \$( )" 'out=$(AutoHotkey64.exe x.ahk)' "$scratch/other"
bare_case 0 "bare name, PATH leads to the configured build" 'AutoHotkey64.exe /ErrorStdOut x.ahk' "$scratch/conf"
bare_case 0 "bare name in prose" 'echo "use AutoHotkey64.exe for this"' "$scratch/other"
bare_case 0 "bare name in a commit message" 'git commit -m "fix AutoHotkey64.exe detection"' "$scratch/other"

echo
echo "inject-rules"
# Two copies of the rules: as the repo stores them, and with the CRLF endings a
# core.autocrlf=true checkout produces. Both must behave the same.
rules_src="$(cd "$HOOKS/../rules" 2>/dev/null && pwd)"
if [[ -n "$rules_src" && -f "$rules_src/ahk-v2-syntax.md" && -f "$rules_src/gui-work.md" ]]; then
    mkdir -p "$quiet_project/Lib"
    printf '%s\n' 'x := 1' > "$quiet_project/plain.ahk"
    printf '%s\n' 'win := Gui()' 'win.Show()' > "$quiet_project/app.ahk"
    for flavour in lf crlf; do
        root="$scratch/rules-$flavour"
        mkdir -p "$root"
        cp -R "$HOOKS" "$root/hooks"
        cp -R "$rules_src" "$root/rules"
        if [[ "$flavour" == crlf ]]; then
            for f in "$root"/rules/*.md; do sed -i 's/\r$//; s/$/\r/' "$f"; done
        fi
        inject="$root/hooks/inject-rules.sh"
        rule_payload() { # SESSION_SUFFIX FILE [EXTRA_TOOL_INPUT_JSON]
            printf '{"session_id":"%s-%s","tool_name":"Write","tool_input":{"file_path":%s%s}}' \
                "$session" "$1" "$(json_str "$(tool_path "$2")")" "${3:-}"
        }
        hook_out "$inject" "$(rule_payload "$flavour-a" "$quiet_project/plain.ahk")" AHK_DIAG_JSON=0
        expect "$flavour rules: an .ahk edit loads ahk-v2-syntax and ahk-target" \
            eval 'has "$HOOK_OUT" "Rule: ahk-v2-syntax" && has "$HOOK_OUT" "Rule: ahk-target" && has "$HOOK_OUT" "hookSpecificOutput"'
        expect "$flavour rules: a stock build is not handed the fork notes" lacks "$HOOK_OUT" "Rule: ahk-fork-features"
        expect "$flavour rules: a script with no Gui call does not load gui-work" lacks "$HOOK_OUT" "Rule: gui-work"
        hook_out "$inject" "$(rule_payload "$flavour-a" "$quiet_project/plain.ahk")" AHK_DIAG_JSON=0
        expect "$flavour rules: nothing is injected twice in one session" test -z "$HOOK_OUT"
        hook_out "$inject" "$(rule_payload "$flavour-b" "$quiet_project/plain.ahk")" AHK_DIAG_JSON=1
        expect "$flavour rules: the fork build gets ahk-fork-features" has "$HOOK_OUT" "Rule: ahk-fork-features"
        hook_out "$inject" "$(rule_payload "$flavour-c" "$quiet_project/app.ahk")" AHK_DIAG_JSON=0
        expect "$flavour rules: a file that calls Gui( loads gui-work whatever its name" has "$HOOK_OUT" "Rule: gui-work"
        hook_out "$inject" "$(rule_payload "$flavour-d" "$quiet_project/fresh.ahk" ',"content":"win := gui(\"+Resize\")"')" AHK_DIAG_JSON=0
        expect "$flavour rules: a new file loads gui-work from the text being written" has "$HOOK_OUT" "Rule: gui-work"
        hook_out "$inject" "$(rule_payload "$flavour-e" "$quiet_project/sub/SETTINGSDIALOG.AHK")" AHK_DIAG_JSON=0
        expect "$flavour rules: path globs ignore case" has "$HOOK_OUT" "Rule: gui-work"
        hook_out "$inject" "$(rule_payload "$flavour-f" "$quiet_project/Lib/util.ahk")" AHK_DIAG_JSON=0
        expect "$flavour rules: a Lib/ file loads lib-development" has "$HOOK_OUT" "Rule: lib-development"
        hook_out "$inject" "$(rule_payload "$flavour-g" "$quiet_project/notes.md" ',"content":"Gui( in prose"')" AHK_DIAG_JSON=0
        expect "$flavour rules: a non-.ahk file loads nothing" test -z "$HOOK_OUT"
    done
else
    bad "inject-rules cases skipped: no rules/ beside $HOOKS"
fi

echo
echo "error-logger (PostToolUseFailure)"
logger="$HOOKS/../skills/ahk-mistakes/hooks/error-logger.sh"
if [[ -f "$logger" ]]; then
    log="$quiet_project/.claude/error-log.jsonl"
    rm -rf "$quiet_project/.claude"
    hook_out "$logger" '{"session_id":"s","hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"\"$AHK_BIN_WSL\" /ErrorStdOut x.ahk"},"error":"Exit code 2\nC:\\Scripts\\x.ahk (12) : ==> This variable has not been assigned a value.\nSpecifically: foo"}'
    expect "a failed interpreter run is logged, and .claude/ is created for it" \
        eval '[[ -s "$log" ]] && grep -q "\"line\":12" "$log" && grep -q "has not been assigned" "$log"'
    expect "the logged message leaves out the Exit code line" eval '! grep -q "Exit code" "$log"'
    : > "$log"
    hook_out "$logger" '{"session_id":"s","tool_name":"Bash","tool_input":{"command":"\"/c/AHK/AutoHotkey64.exe\" x.ahk"},"tool_output":{"stdout":"C:\\S\\y.ahk (3) : ==> TypeError: boom","exit_code":1}}'
    expect "the OpenCode bridge's payload (tool_output.exit_code) is logged too" grep -q '"type":"TypeError"' "$log"
    : > "$log"
    hook_out "$logger" '{"session_id":"s","tool_name":"Bash","tool_input":{"command":"\"$AHK_BIN_WSL\" Tools/harness/GateStatic.ahk a.ahk"},"error":"Exit code 1"}'
    hook_out "$logger" '{"session_id":"s","tool_name":"Bash","tool_input":{"command":"git status"},"error":"Exit code 128\nfatal"}'
    hook_out "$logger" '{"session_id":"s","tool_name":"Bash","tool_input":{"command":"\"$AHK_EXE\" ok.ahk"},"tool_output":{"stdout":"fine","exit_code":0}}'
    expect "a gate's exit 1, an unrelated failure and a clean run are not logged" test ! -s "$log"
    hook_out "$logger" '{"session_id":"s","tool_name":"Edit","tool_input":{"file_path":"C:\\S\\z.ahk"},"error":"String to replace not found"}'
    expect "a failed .ahk edit is logged" grep -q '"tool":"Edit"' "$log"
else
    bad "error-logger cases skipped: $logger not found"
fi

echo
echo "The quiet hooks answer where the host listens"
hook_out "$HOOKS/detect-v1-syntax.sh" '{"prompt":"MsgBox, hello\nStringLeft, out, var, 3"}'
expect "detect-v1-syntax warns on stdout, which is what reaches the model" has "$HOOK_OUT" "AutoHotkey v1 syntax"
expect "detect-v1-syntax keeps the stderr line the OpenCode bridge reads" has "$HOOK_ERR" "v1 patterns found:"
hook_out "$HOOKS/detect-v1-syntax.sh" '{"prompt":"add a MsgBox(\"hi\") to the script"}'
expect "detect-v1-syntax says nothing about v2 code" test -z "$HOOK_OUT"

marker="/tmp/claude-rules-injected-$session-compact"
echo "ahk-v2-syntax.md" > "$marker"
hook_out "$HOOKS/post-compact-state.sh" "{\"session_id\":\"$session-compact\",\"hook_event_name\":\"SessionStart\",\"source\":\"compact\"}"
expect "post-compact-state prints the session state as plain text" \
    eval 'has "$HOOK_OUT" "AHK Session State" && lacks "$HOOK_OUT" "additionalContext"'
expect "post-compact-state clears the rules marker so rules load again" test ! -e "$marker"

hook_out "$HOOKS/post-capture-guidance.sh" '{"tool_name":"mcp__autohotkey-debug__capture_error","tool_response":[{"type":"text","text":"{\"status\": \"timeout\"}"}]}'
expect "post-capture-guidance reads tool_response and answers under hookSpecificOutput" \
    eval 'has "$HOOK_OUT" "\"hookSpecificOutput\"" && has "$HOOK_OUT" "timed out"'
hook_out "$HOOKS/post-capture-guidance.sh" '{"tool_name":"mcp__autohotkey-debug__apply_fix","tool_response":{"success":false}}'
expect "post-capture-guidance tells a failed fix from an applied one" has "$HOOK_OUT" "Fix failed"
hook_out "$HOOKS/check-ahk-connection.sh" '{"tool_name":"mcp__autohotkey-debug__debug_status"}'
expect "check-ahk-connection answers under hookSpecificOutput" \
    eval 'printf "%s" "$HOOK_OUT" | jq -e ".hookSpecificOutput.additionalContext | length > 0" >/dev/null 2>&1'

rm -rf "$quiet_project/.claude"
hook_out "$HOOKS/session-event-logger.sh" '{"hook_event_name":"SubagentStop","session_id":"s","agent_type":"ahk-analysis"}'
hook_out "$HOOKS/session-event-logger.sh" '{"hook_event_name":"Notification","session_id":"s","message":"Claude needs your permission","notification_type":"permission_prompt"}'
events="$quiet_project/.claude/session-events.jsonl"
expect "session-event-logger records agent_type and the notification message" \
    eval 'grep -q "\"agent\":\"ahk-analysis\"" "$events" && grep -q "\"notification\":\"Claude needs your permission\"" "$events"'

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -gt 0 ]] && exit 1
exit 0
