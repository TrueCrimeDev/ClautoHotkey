#!/usr/bin/env bash
# Confirm the harness is actually working. Run it after install, or when something
# feels wrong and you want to know whether the problem is your setup or your script.
#
#   ./Tools/verify.sh
#
# Exit 0 = everything passed, 1 = at least one hard failure. Runs under WSL, Git
# Bash or Cygwin. It reads configuration exactly as the hooks do (hooks/_harness-env.sh),
# so a project's own harness.env wins when CLAUDE_PROJECT_DIR points at one.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pass=0 fail=0 warn=0

ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail + 1)); }
soft() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; warn=$((warn + 1)); }

source hooks/_harness-env.sh

# One JSON string literal, built without jq so the payloads do not depend on the
# thing being tested.
json_str() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '"%s"' "$s"
}

# A path the way Claude Code reports it on this platform: C:\... on Windows shells.
tool_path() {
    case "$HARNESS_PLATFORM" in
        msys|cygwin) harness_to_win "$1" ;;
        *)           printf '%s\n' "$1" ;;
    esac
}

echo
echo "Dependencies"
have_python=0
_harness_python && have_python=1
if type -P jq >/dev/null 2>&1; then
    ok "jq present"
elif [[ "${HARNESS_JQ:-}" == jqlite ]] && printf '{"a":[1,2]}' | jq -e '(.a | length) == 2' >/dev/null 2>&1; then
    soft "jq missing — hooks use the bundled jqlite on $_HARNESS_PY (install jq for speed)"
else
    bad "neither jq nor a working Python 3 — every hook reports itself inactive (install jq or Python 3.8+)"
fi
if [[ "$have_python" == 1 ]]; then
    ok "python present ($_HARNESS_PY)"
else
    soft "no working Python 3 — the module lint will not run"
fi

# JSON validity through Python when there is one, else through jq.
json_valid() {
    if [[ "$have_python" == 1 ]]; then
        local p="$1"
        [[ "$_HARNESS_PY_KIND" == win ]] && p="$(harness_to_win "$1")"
        "$_HARNESS_PY" -E -S -c 'import json, sys; json.load(open(sys.argv[1], "rb"))' "$p" 2>/dev/null
    elif [[ -n "${HARNESS_JQ:-}" ]]; then
        jq -e . "$1" >/dev/null 2>&1
    else
        return 2
    fi
}

echo
echo "Interpreter"
interpreter_ok=0
if [[ -z "${AHK_BIN_WIN:-}" ]]; then
    bad "no AutoHotkey binary configured or auto-detected — set AHK_BIN_WIN in harness.env"
elif [[ "${AHK_BIN_MISSING:-0}" == 1 ]]; then
    bad "configured binary does not exist: $AHK_BIN_WIN ($AHK_BIN_SH)"
else
    [[ "${AHK_AUTODETECTED:-0}" == "1" ]] \
        && ok "auto-detected $AHK_BIN_WIN" \
        || ok "configured $AHK_BIN_WIN"

    probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/clautohotkey-verify.XXXXXX")"
    # The interpreter is a Windows binary: hand it a Windows path.
    probe_win="$(harness_to_win "$probe_dir")"

    printf '%s\n' '#Requires AutoHotkey v2.0' 'FileAppend(A_AhkVersion, "*")' > "$probe_dir/ver.ahk"
    version="$("$AHK_BIN_SH" /ErrorStdOut "$probe_win\\ver.ahk" 2>/dev/null | tr -d '\r')"
    if [[ -n "$version" ]]; then
        ok "interpreter runs — A_AhkVersion = $version"
        interpreter_ok=1
        case "$version" in
            *Console*) ok "+Console fork detected — Print/Eval/JSON diagnostics available" ;;
            *alpha*)   soft "upstream v2.1-alpha — alpha syntax yes, fork BIFs no (set AHK_DIAG_JSON=0)" ;;
            *)         ok "stock v2 — the ahk-target rule will keep generated code portable" ;;
        esac
        if [[ "${AHK_DIAG_JSON:-0}" == "1" && "$version" != *Console* ]]; then
            bad "AHK_DIAG_JSON=1 but this build is not the +Console fork — set it to 0"
        fi
    else
        bad "interpreter produced no output — check the path and that it is AHK v2"
    fi

    # A broken script must be rejected, or the post-edit validator is useless.
    printf '%s\n' '#Requires AutoHotkey v2.0' 'x := ' > "$probe_dir/broken.ahk"
    "$AHK_BIN_SH" /ErrorStdOut /validate "$probe_win\\broken.ahk" >/dev/null 2>&1
    [[ $? -ne 0 ]] && ok "validation rejects broken syntax" || bad "validation accepted a broken script"
    rm -rf "$probe_dir"
fi

echo
echo "Hooks are live"
# Feed the hooks payloads shaped like Claude Code's and check that they act. The
# scratch project gets a copy of the configuration resolved above, so the hooks use
# the same interpreter, and any error record lands in its log rather than yours.
if [[ -z "${HARNESS_JQ:-}" ]]; then
    bad "skipped — without jq or Python every hook only reports itself inactive"
elif [[ -z "${AHK_BIN_WIN:-}" ]]; then
    bad "skipped — no interpreter configured, so the guard has nothing to enforce"
else
    live="$(mktemp -d "${TMPDIR:-/tmp}/clautohotkey-live.XXXXXX")"
    for f in harness.env harness.local.env; do
        [[ -f "$_HARNESS_ROOT/$f" ]] && cp "$_HARNESS_ROOT/$f" "$live/$f"
    done
    live_project="$(tool_path "$live")"
    session="verify-$$"

    payload="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$(json_str '"C:\NotTheConfigured\AutoHotkey64.exe" /ErrorStdOut x.ahk')}}"
    printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$live_project" bash hooks/check-ahk-binary.sh >/dev/null 2>&1
    rc=$?
    [[ $rc -eq 2 ]] && ok "check-ahk-binary blocks a non-configured AutoHotkey exe" \
                    || bad "check-ahk-binary let a non-configured AutoHotkey exe through (exit $rc, want 2)"

    payload="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$(json_str 'git status')}}"
    printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$live_project" bash hooks/check-ahk-binary.sh >/dev/null 2>&1
    rc=$?
    [[ $rc -eq 0 ]] && ok "check-ahk-binary leaves ordinary commands alone" \
                    || bad "check-ahk-binary blocked 'git status' (exit $rc)"

    edit_payload() {
        printf '{"session_id":"%s","tool_name":"Write","tool_input":{"file_path":%s}}' \
            "$session" "$(json_str "$(tool_path "$1")")"
    }

    if [[ "$interpreter_ok" == 1 ]]; then
        printf '%s\n' '#Requires AutoHotkey v2.0' 'x := ' > "$live/broken.ahk"
        printf '%s\n' '#Requires AutoHotkey v2.0' 'x := 1' > "$live/clean.ahk"
        edit_payload "$live/broken.ahk" | CLAUDE_PROJECT_DIR="$live_project" bash hooks/ahk-post-edit.sh >/dev/null 2>&1
        rc=$?
        [[ $rc -eq 2 ]] && ok "ahk-post-edit blocks a script with a syntax error" \
                        || bad "ahk-post-edit did not block 'x := ' (exit $rc, want 2)"
        edit_payload "$live/clean.ahk" | CLAUDE_PROJECT_DIR="$live_project" bash hooks/ahk-post-edit.sh >/dev/null 2>&1
        rc=$?
        [[ $rc -eq 0 ]] && ok "ahk-post-edit passes a clean script" \
                        || bad "ahk-post-edit rejected a clean script (exit $rc, want 0)"

        # The runtime probe really runs the edited script; with the dry-run shim in
        # place its effects must be recorded, not performed.
        if [[ "${AHK_DIAG_JSON:-0}" == 1 && -f Tools/harness/DryRunShim.ahk ]]; then
            { [[ -f "$live/harness.local.env" ]] && cat "$live/harness.local.env"; echo; echo "RUNTIME_PROBE=1"; } \
                > "$live/harness.local.env.new" && mv -f "$live/harness.local.env.new" "$live/harness.local.env"
            echo keep > "$live/sentinel.txt"
            printf '%s\n' '#Requires AutoHotkey v2.0' "FileDelete(\"$(harness_to_win "$live/sentinel.txt")\")" > "$live/deleter.ahk"
            edit_payload "$live/deleter.ahk" | CLAUDE_PROJECT_DIR="$live_project" bash hooks/ahk-post-edit.sh >/dev/null 2>&1
            rc=$?
            if [[ -f "$live/sentinel.txt" && $rc -eq 0 ]]; then
                ok "runtime probe runs under the dry-run shim (FileDelete was recorded, not performed)"
            else
                bad "runtime probe was not contained (exit $rc, sentinel $([[ -f "$live/sentinel.txt" ]] && echo kept || echo DELETED))"
            fi
        fi
    else
        bad "ahk-post-edit checks skipped — the interpreter does not run"
    fi
    rm -f "/tmp/ahk-edit-failed-$session"
    rm -rf "$live"
fi

echo
echo "Plugin manifests"
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
    if [[ ! -f "$f" ]]; then
        bad "$f missing"
    else
        json_valid "$f"
        case $? in
            0) ok "$f valid" ;;
            2) soft "$f not checked — needs Python or jq" ;;
            *) bad "$f is not valid JSON" ;;
        esac
    fi
done
if [[ -f hooks/hooks.json ]]; then
    if [[ -n "${HARNESS_JQ:-}" ]] && jq -e '.hooks' hooks/hooks.json >/dev/null 2>&1; then
        n=$(jq '[.hooks[][].hooks[]] | length' hooks/hooks.json)
        ok "hooks/hooks.json valid — $n hook(s) wired"
    else
        bad "hooks/hooks.json is not valid, or has no .hooks key (or there is no jq/Python to read it)"
    fi
else
    bad "hooks/hooks.json missing"
fi

echo
echo "Harness contents"
for d in skills agents rules hooks Modules; do
    n=$(find "$d" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l)
    [[ "$n" -gt 0 ]] && ok "$d/ — $n entries" || bad "$d/ is empty or missing"
done

missing_exec=$(find hooks -name '*.sh' ! -perm -u+x 2>/dev/null | wc -l)
[[ "$missing_exec" -eq 0 ]] && ok "all hooks executable" || bad "$missing_exec hook(s) not executable — run ./setup.sh"

echo
echo "Skill wiring"
dangling=0
while read -r ref; do
    [[ -f "$ref" ]] || { bad "dangling module reference: $ref"; dangling=$((dangling + 1)); }
done < <(grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/Modules/[A-Za-z/_]*\.md' skills agents commands 2>/dev/null \
         | sed 's|${CLAUDE_PLUGIN_ROOT}/||' | sort -u)
[[ "$dangling" -eq 0 ]] && ok "every module a skill loads exists"

noskill=$(find skills -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/SKILL.md' ';' -print 2>/dev/null | wc -l)
[[ "$noskill" -eq 0 ]] && ok "every skill directory has a SKILL.md" || bad "$noskill skill dir(s) missing SKILL.md"

echo
echo "Knowledge corpus"
if [[ "$have_python" == 1 && -f Tools/lint_modules.py ]]; then
    if out=$("$_HARNESS_PY" Tools/lint_modules.py --summary 2>&1); then
        ok "module lint clean ($(ls Modules/*.md Modules/Supplemental/*.md 2>/dev/null | wc -l) files)"
    else
        bad "module lint reported errors — run ./Tools/lint_modules.py"
        printf '%s\n' "$out" | tail -4 | sed 's/^/          /'
    fi
else
    soft "skipped — needs Python 3"
fi

echo
printf '%d passed, %d failed, %d warning(s)\n' "$pass" "$fail" "$warn"
[[ "$fail" -gt 0 ]] && exit 1
exit 0
