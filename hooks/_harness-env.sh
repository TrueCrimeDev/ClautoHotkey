#!/usr/bin/env bash
# Sourced by every hook. Resolves configuration in three tiers, then derives the
# WSL interpreter path from the Windows one.
#
#   1. $CLAUDE_PROJECT_DIR/harness.env  — the user's own project. Wins when present,
#      which is the normal case for a plugin install: config lives with your scripts,
#      not inside the plugin.
#   2. <install root>/harness.env       — a git-clone install, where the harness sits
#      in the project it serves.
#   3. Auto-detection                   — no harness.env anywhere. Probe the standard
#      AutoHotkey install locations so the plugin works with zero configuration.

_harness_root() {
    local d="${CLAUDE_PROJECT_DIR:-}"
    [[ -n "$d" && -f "$d/harness.env" ]] && { echo "$d"; return; }
    # hooks/ lives at the install root
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

_HARNESS_ROOT="$(_harness_root)"
[[ -f "$_HARNESS_ROOT/harness.env" ]] && source "$_HARNESS_ROOT/harness.env"

# Tier 3: nothing configured an interpreter, so find one.
if [[ -z "${AHK_BIN_WIN:-}" ]]; then
    for _candidate in \
        "/mnt/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" \
        "/mnt/c/Program Files/AutoHotkey/v2/AutoHotkey32.exe" \
        "/mnt/c/Program Files (x86)/AutoHotkey/v2/AutoHotkey64.exe" \
        "$HOME/AppData/Local/Programs/AutoHotkey/v2/AutoHotkey64.exe" \
        "/mnt/c/Users/${USER}/AppData/Local/Programs/AutoHotkey/v2/AutoHotkey64.exe"
    do
        if [[ -e "$_candidate" ]]; then
            AHK_BIN_WIN="$(printf '%s' "$_candidate" | sed 's|^/mnt/\([a-z]\)|\U\1:|; s|/|\\|g')"
            AHK_AUTODETECTED=1
            break
        fi
    done
    unset _candidate
fi

# Stock AutoHotkey has no `check /Diag=json`; only the +Console fork does. Default off
# unless a harness.env explicitly opted in.
: "${AHK_DIAG_JSON:=0}"
# Briefly running a standalone script catches runtime errors a syntax check cannot.
: "${RUNTIME_PROBE:=1}"
# The git identity guard is opt-in — it is a personal-account safety net, not a default.
: "${GIT_GUARD_ENABLED:=0}"

# Derive the WSL interpreter path from the Windows path (single backslashes at runtime).
if [[ -n "${AHK_BIN_WIN:-}" ]]; then
    AHK_BIN_WSL="$(printf '%s' "$AHK_BIN_WIN" | sed 's|\\|/|g; s|^\([A-Za-z]\):|/mnt/\L\1|')"
fi

export AHK_BIN_WIN AHK_BIN_WSL AHK_AUTODETECTED AHK_DIAG_JSON PROJECT_DIR MAIN_SCRIPT \
       DEPENDENCY_SCRIPTS NO_RUNTIME_CHECK NO_AUTO_RELOAD RUNTIME_PROBE DEMO_DIR \
       GIT_GUARD_ENABLED GIT_ALLOWED_IDENTITY GIT_BLOCKLIST
