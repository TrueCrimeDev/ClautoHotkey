#!/usr/bin/env bash
# PreToolUse on Bash: block invocations of any AutoHotkey*.exe that isn't the
# binary configured in harness.env (AHK_BIN_WIN). Keeps every run on one known
# interpreter. Plain-text mentions (commit messages, comments) are not flagged.
#
# Matching works on fixed strings, case-insensitively (Windows paths are): the
# command is lower-cased and its backslashes turned into slashes, and the
# references a command usually spells the interpreter with ($AHK_BIN_WSL,
# ${AHK_BIN_SH}, $AHK_BIN_WIN, $USERPROFILE, %USERPROFILE%, $env:USERPROFILE,
# $HOME, ~) are expanded first. The configured binary is then accepted in any
# spelling - C:\..., C:/..., /c/..., /mnt/c/..., /cygdrive/c/... - when it starts
# a token and nothing is glued to its end, so a neighbour such as
# AutoHotkey64.exe.alpha29.bak is still blocked. Any other path ending in
# /AutoHotkey*.exe is blocked.

set -u

source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"

input=$(cat)
harness_need_jq || exit 1

# Most Bash calls have nothing to do with AutoHotkey. Deciding that from the raw
# payload skips starting jq (or Python, for jqlite) on every one of them.
raw="${input,,}"
[[ "$raw" == *autohotkey* || "$raw" == *ahk_bin_* ]] || exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$cmd" ]] && exit 0

# _flat VAR VALUE: VALUE lower-cased with slashes, the form everything is compared in.
_flat() {
    local __f="${2,,}"
    printf -v "$1" '%s' "${__f//\\//}"
}

# Expand $NAME (when not followed by an identifier character) and ${NAME} in $c.
# Replacements are quoted: bash 5.2 would otherwise read a '&' in them as the match.
_subst_var() {
    local name="$1" val="$2" out="" re
    c="${c//"\${$name}"/"$val"}"
    [[ "$c" == *"\$$name"* ]] || return 0
    re="^(.*)[\$]$name([^a-z0-9_].*)?\$"
    while [[ "$c" =~ $re ]]; do
        out="$val${BASH_REMATCH[2]}$out"
        c="${BASH_REMATCH[1]}"
    done
    c="$c$out"
}

_flat c "$cmd"
_flat v_sh "${AHK_BIN_SH:-}"
_flat v_win "${AHK_BIN_WIN:-}"
_flat v_profile "${USERPROFILE:-${WIN_HOME:-}}"
_flat v_home "${HOME:-}"

_subst_var ahk_bin_wsl "$v_sh"
_subst_var ahk_bin_sh "$v_sh"
_subst_var ahk_bin_win "$v_win"
c="${c//"\$env:userprofile"/"$v_profile"}"
c="${c//"%userprofile%"/"$v_profile"}"
_subst_var userprofile "$v_profile"
_subst_var home "$v_home"
if [[ -n "$v_home" ]]; then
    [[ "$c" == "~/"* || "$c" == "~" ]] && c="$v_home${c:1}"
    for b in ' ' $'\t' $'\n' '"' "'" '=' '(' ':'; do
        c="${c//"$b~/"/"$b$v_home/"}"
    done
fi
while [[ "$c" == *//* ]]; do
    c="${c//\/\//"/"}"
done

exe_re='/autohotkey[a-z0-9._-]*\.exe'

if [[ -z "$v_win" ]]; then
    # Nothing configured or found to compare against: nothing to enforce, but an
    # AutoHotkey run without a configured interpreter is worth one line.
    [[ "$c" =~ $exe_re ]] && { harness_need_ahk; exit 1; }
    exit 0
fi

# Every spelling of the configured binary, longest first.
spellings=()
if [[ "$v_win" == [a-z]:/* ]]; then
    d="${v_win:0:1}" rest="${v_win:2}"
    spellings=("/cygdrive/$d$rest" "/mnt/$d$rest" "$d:$rest" "/$d$rest")
else
    spellings=("$v_win")
fi
[[ -n "$v_sh" ]] && spellings+=("$v_sh")

# Replace each spelling that starts a token with \x01; a spelling glued to text
# before it stays, and is then caught as an unknown binary below.
boundary=$' \t\r\n"\'`=(&;|<>,'
mark=$'\x01'
for sp in "${spellings[@]}"; do
    out=""
    while [[ "$c" == *"$sp"* ]]; do
        pre="${c%%"$sp"*}"
        c="${c#*"$sp"}"
        ch="${pre: -1}"
        if [[ -z "$pre" || "$boundary" == *"$ch"* ]]; then
            out+="$pre$mark"
        else
            out+="$pre$sp"
        fi
    done
    c="$out$c"
done

reason=""
suffix_re="$mark"'[a-z0-9._-]'
if [[ "$c" =~ $suffix_re ]]; then
    reason="a renamed or suffixed copy of the configured binary"
elif [[ "$c" =~ $exe_re ]]; then
    reason="an AutoHotkey binary other than the configured one"
fi

if [[ -z "$reason" ]]; then
    # Only the configured binary is used. If it is not there, the run will fail;
    # say why once instead of letting it look like a script problem.
    if [[ "$c" == *"$mark"* && "${AHK_BIN_MISSING:-0}" == 1 ]]; then
        harness_need_ahk
        exit 1
    fi
    exit 0
fi

echo "BLOCKED: Non-canonical AutoHotkey binary referenced ($reason)." >&2
echo "Command: $cmd" >&2
echo "" >&2
echo "Use the configured interpreter:" >&2
echo "  This shell: ${AHK_BIN_SH:-$AHK_BIN_WIN}" >&2
echo "  Windows:    $AHK_BIN_WIN" >&2
[[ "${AHK_BIN_MISSING:-0}" == 1 ]] && echo "  (it does not exist on this machine - fix AHK_BIN_WIN in harness.local.env)" >&2
echo "" >&2
echo "Only the binary set in harness.env (AHK_BIN_WIN) is allowed." >&2
echo "See the ahk-interpreter rule." >&2
exit 2
