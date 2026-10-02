#!/usr/bin/env bash
# Sourced by every hook, and by Tools/verify.sh, setup.sh and skill snippets. It is
# sourced, so it never exits, and it prints nothing on stdout: several hooks answer
# Claude Code with JSON there. Anything slow it learns about the machine is cached.
#
# Configuration resolves in three tiers:
#
#   1. $CLAUDE_PROJECT_DIR/harness.env  - the user's own project. Wins when present,
#      which is the normal case for a plugin install: config lives with your scripts,
#      not inside the plugin.
#   2. <install root>/harness.env       - a git-clone install, where the harness sits
#      in the project it serves.
#   3. Auto-detection                   - no harness.env anywhere. Probe the standard
#      AutoHotkey install locations so the plugin works with zero configuration.
#
# harness.local.env next to the chosen harness.env is sourced after it: per-machine
# overrides (gitignored), so one harness.env can serve a WSL machine and a Git Bash
# machine. Both files may use ${WIN_HOME}, the Windows profile directory
# (C:\Users\you), which is worked out before either file is read.
#
# The same hooks run under WSL, Git Bash (MSYS2) and Cygwin. HARNESS_PLATFORM says
# which, and harness_to_unix / harness_to_win translate paths between the spelling
# this shell uses and the one Windows programs (the interpreter, PowerShell) need.

# Platform: wsl, msys (Git Bash / MSYS2), cygwin, linux or other. Git Bash 3.6+
# reports OSTYPE=cygwin, so MSYSTEM (or uname) is what separates it from real
# Cygwin - and the difference matters: drives are /c/... there, /cygdrive/c/... here.
case "${OSTYPE:-}" in
    linux*)
        if [[ -n "${WSL_DISTRO_NAME:-}${WSL_INTEROP:-}" || -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
            HARNESS_PLATFORM=wsl
        elif [[ -r /proc/version && "$(< /proc/version)" == *[Mm]icrosoft* ]]; then
            HARNESS_PLATFORM=wsl
        else
            HARNESS_PLATFORM=linux
        fi ;;
    msys*)
        HARNESS_PLATFORM=msys ;;
    cygwin*)
        if [[ -n "${MSYSTEM:-}" ]]; then
            HARNESS_PLATFORM=msys
        else
            case "$(uname -s 2>/dev/null)" in
                MINGW*|MSYS*) HARNESS_PLATFORM=msys ;;
                *) HARNESS_PLATFORM=cygwin ;;
            esac
        fi ;;
    *)
        HARNESS_PLATFORM=other ;;
esac

# MSYS rewrites arguments that look like POSIX paths when it starts a Windows
# program, so `AutoHotkey64.exe /ErrorStdOut x.ahk` would receive
# C:/Program Files/Git/ErrorStdOut. Hooks pass Windows paths explicitly instead.
if [[ "$HARNESS_PLATFORM" == msys ]]; then
    export MSYS_NO_PATHCONV=1
    export MSYS2_ARG_CONV_EXCL='*'
fi

# Split a drive-rooted path in any spelling (C:\x, C:/x, /mnt/c/x, /cygdrive/c/x, and
# /c/x where that names a drive) into _HD (lower-case letter) and _HR (the rest,
# forward slashes). Returns 1 for anything else. Callers declare _HD/_HR local.
_harness_split_drive() {
    local p="$1"
    case "$p" in
        [A-Za-z]:)            _HD="${p:0:1}"; _HR="" ;;
        [A-Za-z]:[\\/]*)      _HD="${p:0:1}"; _HR="${p:2}" ;;
        /mnt/[A-Za-z])        _HD="${p:5:1}"; _HR="" ;;
        /mnt/[A-Za-z]/*)      _HD="${p:5:1}"; _HR="${p:6}" ;;
        /cygdrive/[A-Za-z])   _HD="${p:10:1}"; _HR="" ;;
        /cygdrive/[A-Za-z]/*) _HD="${p:10:1}"; _HR="${p:11}" ;;
        /[A-Za-z]|/[A-Za-z]/*)
            # Git Bash spells drives /c/...; elsewhere only when /c is no real directory.
            if [[ "$HARNESS_PLATFORM" != msys ]] && [[ "$HARNESS_PLATFORM" == linux || -d "${p:0:2}" ]]; then
                return 1
            fi
            _HD="${p:1:1}"; _HR="${p:2}" ;;
        *)
            return 1 ;;
    esac
    _HD="${_HD,,}"
    _HR="${_HR//\\//}"
    return 0
}

# _harness_win_into VAR PATH / _harness_unix_into VAR PATH store the converted path
# in VAR without a subshell; forks are slow on Git Bash and every hook sources this.
_harness_win_into() {
    local __w_p="${2:-}" __w_o="" _HD _HR
    if [[ -z "$__w_p" ]]; then
        __w_o=""
    elif _harness_split_drive "$__w_p"; then
        _HR="${_HR//\//\\}"
        __w_o="${_HD^^}:${_HR:-\\}"
    else
        case "$__w_p" in
            \\\\*) __w_o="$__w_p" ;;
            //*)   __w_o="${__w_p//\//\\}" ;;
            *)
                # Not on a drive (/tmp, /home/you): only the platform tool knows where
                # that lives on the Windows side.
                case "$HARNESS_PLATFORM" in
                    msys|cygwin) type -P cygpath >/dev/null 2>&1 && __w_o="$(cygpath -w "$__w_p" 2>/dev/null)" ;;
                    wsl)         type -P wslpath >/dev/null 2>&1 && __w_o="$(command wslpath -w "$__w_p" 2>/dev/null)" ;;
                esac
                [[ -n "$__w_o" ]] || __w_o="${__w_p//\//\\}" ;;
        esac
    fi
    printf -v "$1" '%s' "$__w_o"
}

_harness_unix_into() {
    local __u_p="${2:-}" __u_o="" _HD _HR
    if [[ -z "$__u_p" ]]; then
        __u_o=""
    elif _harness_split_drive "$__u_p"; then
        case "$HARNESS_PLATFORM" in
            msys)
                __u_o="/$_HD$_HR" ;;
            cygwin)
                type -P cygpath >/dev/null 2>&1 && __u_o="$(cygpath -u "${_HD^^}:${_HR:-/}" 2>/dev/null)"
                [[ -n "$__u_o" ]] || __u_o="/cygdrive/$_HD$_HR" ;;
            wsl)
                # /mnt is only the default automount root; wslpath knows the real one.
                if [[ ! -d "/mnt/$_HD" ]] && type -P wslpath >/dev/null 2>&1; then
                    __u_o="$(command wslpath -u "${_HD^^}:${_HR:-/}" 2>/dev/null)"
                fi
                [[ -n "$__u_o" ]] || __u_o="/mnt/$_HD$_HR" ;;
            *)
                __u_o="/mnt/$_HD$_HR" ;;
        esac
    else
        __u_o="${__u_p//\\//}"
    fi
    printf -v "$1" '%s' "$__u_o"
}

# harness_to_unix PATH: the spelling this shell uses (/c/x on Git Bash, /mnt/c/x on WSL).
# harness_to_win PATH:  the Windows spelling (C:\x) for the interpreter and PowerShell.
# Both accept any spelling: C:\x, C:/x, /c/x, /mnt/c/x, /cygdrive/c/x.
harness_to_unix() { local __r; _harness_unix_into __r "${1:-}"; printf '%s\n' "$__r"; }
harness_to_win()  { local __r; _harness_win_into __r "${1:-}"; printf '%s\n' "$__r"; }

_harness_cache_file() {
    printf -v "$1" '%s/clautohotkey-%s.%s' "${TMPDIR:-/tmp}" "$2" "${UID:-${USER:-${USERNAME:-user}}}"
}

_harness_cache_put() {  # file value: atomic, because hooks run in parallel
    printf '%s\n' "$2" > "$1.$$" 2>/dev/null && mv -f "$1.$$" "$1" 2>/dev/null
}

# A config file saved by a Windows editor has CRLF line endings, and a plain
# `source` would leave a \r on every value (AHK_DIAG_JSON=1\r is not 1).
_harness_source_env() {
    local _harness_env_body
    [[ -f "$1" ]] || return 0
    _harness_env_body="$(< "$1")"
    if [[ "$_harness_env_body" == *$'\r'* ]]; then
        eval "${_harness_env_body//$'\r'/}"
    else
        source "$1"
    fi
}

# Where this file lives: hooks/ under the install root. Worked out from BASH_SOURCE
# rather than `cd ... && pwd`, which would cost a subshell.
_harness_here="${BASH_SOURCE[0]:-}"
case "$_harness_here" in
    */*|*\\*) _harness_here="${_harness_here%[/\\]*}" ;;
    *)        _harness_here="." ;;
esac
case "$_harness_here" in
    /*|[A-Za-z]:*) ;;
    *) _harness_here="$PWD/$_harness_here" ;;
esac
_harness_unix_into _HARNESS_HOOKS "$_harness_here"
_HARNESS_HOOKS="${_HARNESS_HOOKS//\/.\//\/}"
_HARNESS_HOOKS="${_HARNESS_HOOKS%/.}"
_HARNESS_INSTALL_ROOT="${_HARNESS_HOOKS%/*}"
unset _harness_here

# Tier 1 when the project carries its own config, else tier 2 (the install root).
_harness_unix_into _HARNESS_PROJECT "${CLAUDE_PROJECT_DIR:-}"
if [[ -n "$_HARNESS_PROJECT" && ( -f "$_HARNESS_PROJECT/harness.env" || -f "$_HARNESS_PROJECT/harness.local.env" ) ]]; then
    _HARNESS_ROOT="$_HARNESS_PROJECT"
else
    _HARNESS_ROOT="$_HARNESS_INSTALL_ROOT"
fi

# WIN_HOME, the Windows profile directory, so harness.env can say
# "${WIN_HOME}\Documents\..." instead of hard-coding one user's name. Git Bash and
# Cygwin export USERPROFILE; WSL usually does not, but a project under
# /mnt/c/Users/<name>/ gives it away; failing both, ask cmd.exe once and cache it.
_harness_win_home() {
    local p w cache re='^([A-Za-z]):\\[Uu]sers\\([^\\]+)\\'
    WIN_HOME=""
    if [[ -n "${USERPROFILE:-}" ]]; then
        _harness_win_into WIN_HOME "$USERPROFILE"
        return
    fi
    for p in "$_HARNESS_ROOT" "$_HARNESS_INSTALL_ROOT" "$_HARNESS_PROJECT" "${HOME:-}"; do
        [[ -n "$p" ]] || continue
        _harness_win_into w "$p"
        if [[ "$w\\" =~ $re ]]; then
            WIN_HOME="${BASH_REMATCH[1]^^}:\\Users\\${BASH_REMATCH[2]}"
            return
        fi
    done
    _harness_cache_file cache winhome
    if [[ -f "$cache" ]]; then
        IFS= read -r WIN_HOME < "$cache"
        [[ "$WIN_HOME" == [A-Za-z]:\\* ]] && return
        WIN_HOME=""
    fi
    if type -P cmd.exe >/dev/null 2>&1; then
        WIN_HOME="$(cd /mnt/c 2>/dev/null || cd / ; cmd.exe /d /c echo %USERPROFILE% 2>/dev/null)"
        WIN_HOME="${WIN_HOME%%$'\r'*}"
        if [[ "$WIN_HOME" == [A-Za-z]:\\* ]]; then
            _harness_cache_put "$cache" "$WIN_HOME"
        else
            WIN_HOME=""
        fi
    fi
}
if [[ -z "${WIN_HOME:-}" ]]; then
    _harness_win_home
fi

_harness_source_env "$_HARNESS_ROOT/harness.env"
_harness_source_env "$_HARNESS_ROOT/harness.local.env"

# Stock AutoHotkey has no `check /Diag=json`; only the +Console fork does. Default off
# unless a harness.env explicitly opted in.
: "${AHK_DIAG_JSON:=0}"
# Briefly running a standalone script catches runtime errors a syntax check cannot.
: "${RUNTIME_PROBE:=1}"
# The git identity guard is opt-in - it is a personal-account safety net, not a default.
: "${GIT_GUARD_ENABLED:=0}"

# Tier 3: nothing configured an interpreter, so look in the standard places. Generic
# locations only; a personal build belongs in harness.env or harness.local.env.
AHK_AUTODETECTED=0
if [[ -z "${AHK_BIN_WIN:-}" ]]; then
    _harness_pf="${PROGRAMFILES:-C:\\Program Files}"
    _harness_lad="${LOCALAPPDATA:-}"
    [[ -z "$_harness_lad" && -n "$WIN_HOME" ]] && _harness_lad="$WIN_HOME\\AppData\\Local"
    for _harness_c in \
        "$_harness_pf\\AutoHotkey\\v2\\AutoHotkey64.exe" \
        "$_harness_pf\\AutoHotkey\\v2\\AutoHotkey32.exe" \
        "C:\\Program Files (x86)\\AutoHotkey\\v2\\AutoHotkey64.exe" \
        "C:\\Program Files (x86)\\AutoHotkey\\v2\\AutoHotkey32.exe" \
        ${_harness_lad:+"$_harness_lad\\Programs\\AutoHotkey\\v2\\AutoHotkey64.exe"} \
        ${_harness_lad:+"$_harness_lad\\Programs\\AutoHotkey\\v2\\AutoHotkey32.exe"}
    do
        _harness_unix_into _harness_u "$_harness_c"
        if [[ -f "$_harness_u" ]]; then
            AHK_BIN_WIN="$_harness_c"
            AHK_AUTODETECTED=1
            break
        fi
    done
    if [[ -z "${AHK_BIN_WIN:-}" ]] && _harness_u="$(type -P AutoHotkey64.exe 2>/dev/null)" && [[ -n "$_harness_u" ]]; then
        _harness_win_into AHK_BIN_WIN "$_harness_u"
        AHK_AUTODETECTED=1
    fi
    unset _harness_pf _harness_lad _harness_c _harness_u
fi

# AHK_BIN_WIN is the Windows path; AHK_BIN_WSL is the same binary as this shell sees
# it (the historical name - WSL or not), AHK_BIN_SH the same value under a neutral
# name. A configured binary that is not there is reported by the hooks
# (AHK_BIN_MISSING=1) rather than silently skipped or swapped for another one.
AHK_BIN_SH="" AHK_BIN_WSL="" AHK_BIN_MISSING=0
if [[ -n "${AHK_BIN_WIN:-}" ]]; then
    _harness_win_into AHK_BIN_WIN "$AHK_BIN_WIN"
    _harness_unix_into AHK_BIN_SH "$AHK_BIN_WIN"
    AHK_BIN_WSL="$AHK_BIN_SH"
    [[ -f "$AHK_BIN_SH" ]] || AHK_BIN_MISSING=1
fi

# PROJECT_DIR is optional: the project Claude Code opened, else the install root.
# Kept in this shell's spelling; DEMO_DIR defaults to <project>\Demo, Windows form.
[[ -n "${PROJECT_DIR:-}" ]] || PROJECT_DIR="${_HARNESS_PROJECT:-$_HARNESS_INSTALL_ROOT}"
_harness_unix_into PROJECT_DIR "$PROJECT_DIR"
if [[ -z "${DEMO_DIR:-}" ]]; then
    _harness_win_into DEMO_DIR "$PROJECT_DIR"
    DEMO_DIR="${DEMO_DIR%\\}\\Demo"
fi

# A Python 3.8+ that really runs, as "<win|posix>|<path>". `command -v python3` is
# not enough: on Windows the WindowsApps python3.exe is a Store stub that prints
# "Python was not found" and fails, so every candidate is executed. The verdict is
# cached per user and re-validated by checking the cached path still exists.
# HARNESS_PYTHON=<path> pins an interpreter; HARNESS_PYTHON=none disables Python.
_harness_python() {
    local cache="" line exe out kind c
    local -a cand cmd
    _HARNESS_PY="" _HARNESS_PY_KIND=""
    if [[ -n "${HARNESS_PYTHON:-}" ]]; then
        [[ "$HARNESS_PYTHON" == none ]] && return 1
        _harness_unix_into exe "$HARNESS_PYTHON"
        cand=("$exe")
    else
        _harness_cache_file cache python
        if [[ -f "$cache" ]] && IFS= read -r line < "$cache"; then
            kind="${line%%|*}" exe="${line#*|}"
            if [[ -n "$exe" && -f "$exe" && ( "$kind" == win || "$kind" == posix ) ]]; then
                _HARNESS_PY="$exe" _HARNESS_PY_KIND="$kind"
                return 0
            fi
        fi
        cand=(python3 python "py -3")
    fi
    for c in "${cand[@]}"; do
        if [[ "$c" == "py -3" ]]; then cmd=(py -3); else cmd=("$c"); fi
        type -P "${cmd[0]}" >/dev/null 2>&1 || [[ -f "${cmd[0]}" ]] || continue
        out="$("${cmd[@]}" -E -S -c 'import sys, json, re
sys.stdout.write(sys.executable)
sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null)" || continue
        out="${out%%$'\r'*}"
        [[ -n "$out" ]] || continue
        case "$out" in
            /*) kind=posix exe="$out" ;;
            *)  kind=win; _harness_unix_into exe "$out" ;;
        esac
        if [[ ! -f "$exe" ]]; then
            exe="$(type -P "${cmd[0]}" 2>/dev/null)"
            [[ -n "$exe" && "${cmd[0]}" != py ]] || continue
        fi
        _HARNESS_PY="$exe" _HARNESS_PY_KIND="$kind"
        [[ -n "$cache" ]] && _harness_cache_put "$cache" "$kind|$exe"
        return 0
    done
    return 1
}

# A native jq.exe writes CRLF unless given -b, and command substitution keeps the CR
# ("Bash\r" is not "Bash"). Probe a jq found under Git Bash/Cygwin once and cache it.
_harness_jq_line_endings() {
    local cache line jqp mode
    jqp="$(type -P jq)"
    _harness_cache_file cache jqmode
    if [[ -f "$cache" ]] && IFS= read -r line < "$cache" && [[ "${line%|*}" == "$jqp" ]]; then
        mode="${line##*|}"
    else
        if [[ "$(command jq -b -n 1 2>/dev/null)" == 1 ]]; then
            mode=binary
        elif [[ "$(command jq -n 1 2>/dev/null)" == *$'\r' ]]; then
            mode=strip
        else
            mode=plain
        fi
        _harness_cache_put "$cache" "$jqp|$mode"
    fi
    case "$mode" in
        binary) jq() { command jq -b "$@"; }; _HARNESS_JQ_FN=1 ;;
        strip)  jq() { local _rc; command jq "$@" | tr -d '\r'; _rc=${PIPESTATUS[0]}; return "$_rc"; }; _HARNESS_JQ_FN=1 ;;
    esac
}

# Every hook parses its stdin with jq. Without one, `jq` becomes a shell function
# that runs the bundled _jqlite.py on a working Python, so hook code stays the same.
# HARNESS_JQ says which is in use (jq, jqlite, or empty: hooks report themselves
# inactive). HARNESS_FORCE_JQLITE=1 ignores a real jq (Tools/tests use it).
HARNESS_JQ=""
if [[ -n "${_HARNESS_JQ_FN:-}" ]]; then
    unset -f jq
    unset _HARNESS_JQ_FN
fi
if [[ "${HARNESS_FORCE_JQLITE:-0}" != 1 ]] && type -P jq >/dev/null 2>&1; then
    HARNESS_JQ=jq
    case "$HARNESS_PLATFORM" in
        msys|cygwin) _harness_jq_line_endings ;;
    esac
elif [[ -f "$_HARNESS_HOOKS/_jqlite.py" ]] && _harness_python; then
    if [[ "$_HARNESS_PY_KIND" == win ]]; then
        _harness_win_into _HARNESS_JQLITE "$_HARNESS_HOOKS/_jqlite.py"
    else
        _HARNESS_JQLITE="$_HARNESS_HOOKS/_jqlite.py"
    fi
    jq() { "$_HARNESS_PY" -E -S "$_HARNESS_JQLITE" "$@"; }
    _HARNESS_JQ_FN=1
    HARNESS_JQ=jqlite
fi

# Hooks call this before their first jq use. With neither jq nor a working Python
# there is nothing to read the payload with: say so in one line and let the hook
# exit 1, a non-blocking error Claude Code shows the user, instead of doing nothing.
harness_need_jq() {
    [[ -n "${HARNESS_JQ:-}" ]] && return 0
    printf '%s\n' "ClautoHotkey hooks inactive: install jq or Python 3 (${0##*/} did nothing)" >&2
    return 1
}

# Hooks that run the interpreter call this; same contract as harness_need_jq.
harness_need_ahk() {
    if [[ -z "${AHK_BIN_WIN:-}" ]]; then
        printf '%s\n' "ClautoHotkey: no AutoHotkey v2 interpreter configured or found - set AHK_BIN_WIN in harness.env (${0##*/} did nothing)" >&2
        return 1
    fi
    if [[ "${AHK_BIN_MISSING:-0}" == 1 ]]; then
        printf '%s\n' "ClautoHotkey: AutoHotkey binary not found: $AHK_BIN_WIN - fix AHK_BIN_WIN in harness.env or harness.local.env (${0##*/} did nothing)" >&2
        return 1
    fi
    return 0
}

# Skill snippets written for WSL call wslpath after sourcing this; on Git Bash and
# Cygwin, cygpath takes the same -u / -w / -m flags.
if [[ "$HARNESS_PLATFORM" == msys || "$HARNESS_PLATFORM" == cygwin ]] \
        && ! type -P wslpath >/dev/null 2>&1 && type -P cygpath >/dev/null 2>&1; then
    wslpath() { cygpath "$@"; }
fi

export AHK_BIN_WIN AHK_BIN_WSL AHK_BIN_SH AHK_BIN_MISSING AHK_AUTODETECTED AHK_DIAG_JSON \
       PROJECT_DIR MAIN_SCRIPT DEPENDENCY_SCRIPTS NO_RUNTIME_CHECK NO_AUTO_RELOAD \
       RUNTIME_PROBE DEMO_DIR GIT_GUARD_ENABLED GIT_ALLOWED_IDENTITY GIT_BLOCKLIST \
       WIN_HOME HARNESS_PLATFORM
