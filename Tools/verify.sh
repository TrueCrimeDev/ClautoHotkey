#!/usr/bin/env bash
# Confirm the harness is actually working. Run it after install, or when something
# feels wrong and you want to know whether the problem is your setup or your script.
#
#   ./Tools/verify.sh
#
# Exit 0 = everything passed, 1 = at least one hard failure.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pass=0 fail=0 warn=0

ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail + 1)); }
soft() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; warn=$((warn + 1)); }

echo
echo "Dependencies"
command -v jq      >/dev/null 2>&1 && ok "jq present" || bad "jq missing — every hook needs it"
command -v python3 >/dev/null 2>&1 && ok "python3 present" || soft "python3 missing — the module lint will not run"

echo
echo "Interpreter"
source hooks/_harness-env.sh 2>/dev/null
if [[ -z "${AHK_BIN_WSL:-}" ]]; then
    bad "no AutoHotkey binary configured or auto-detected — set AHK_BIN_WIN in harness.env"
elif [[ ! -e "$AHK_BIN_WSL" ]]; then
    bad "configured binary does not exist: $AHK_BIN_WSL"
else
    [[ "${AHK_AUTODETECTED:-0}" == "1" ]] \
        && ok "auto-detected $AHK_BIN_WIN" \
        || ok "configured $AHK_BIN_WIN"

    probe_dir="${TMPDIR:-/tmp}/clautohotkey-verify.$$"
    mkdir -p "$probe_dir"
    # The interpreter is a Windows binary: hand it a Windows path.
    if command -v wslpath >/dev/null 2>&1; then
        probe_win="$(wslpath -w "$probe_dir" 2>/dev/null)"
    else
        probe_win="$probe_dir"
    fi

    printf '%s\n' '#Requires AutoHotkey v2.0' 'FileAppend(A_AhkVersion, "*")' > "$probe_dir/ver.ahk"
    version="$("$AHK_BIN_WSL" /ErrorStdOut /Headless "$probe_win\\ver.ahk" 2>/dev/null | tr -d '\r')"
    if [[ -n "$version" ]]; then
        ok "interpreter runs — A_AhkVersion = $version"
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
    "$AHK_BIN_WSL" /ErrorStdOut /validate "$probe_win\\broken.ahk" >/dev/null 2>&1
    [[ $? -ne 0 ]] && ok "validation rejects broken syntax" || bad "validation accepted a broken script"
    rm -rf "$probe_dir"
fi

echo
echo "Plugin manifests"
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
    if [[ ! -f "$f" ]]; then
        bad "$f missing"
    elif command -v python3 >/dev/null 2>&1 && ! python3 -c "import json,sys; json.load(open('$f'))" 2>/dev/null; then
        bad "$f is not valid JSON"
    else
        ok "$f valid"
    fi
done
if [[ -f hooks/hooks.json ]]; then
    if command -v jq >/dev/null 2>&1 && jq -e '.hooks' hooks/hooks.json >/dev/null 2>&1; then
        n=$(jq '[.hooks[][].hooks[]] | length' hooks/hooks.json)
        ok "hooks/hooks.json valid — $n hook(s) wired"
    else
        bad "hooks/hooks.json is not valid, or has no .hooks key"
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
if command -v python3 >/dev/null 2>&1 && [[ -f Tools/lint_modules.py ]]; then
    if out=$(python3 Tools/lint_modules.py --summary 2>&1); then
        ok "module lint clean ($(ls Modules/*.md Modules/Supplemental/*.md 2>/dev/null | wc -l) files)"
    else
        bad "module lint reported errors — run ./Tools/lint_modules.py"
        printf '%s\n' "$out" | tail -4 | sed 's/^/          /'
    fi
else
    soft "skipped — needs python3"
fi

echo
printf '%d passed, %d failed, %d warning(s)\n' "$pass" "$fail" "$warn"
[[ "$fail" -gt 0 ]] && exit 1
exit 0
