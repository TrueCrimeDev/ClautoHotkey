#!/usr/bin/env bash
# Sourced by every hook. Locates harness.env (repo root) and loads its values,
# then derives AHK_BIN_WSL from the Windows path.

_harness_root() {
  local d="${CLAUDE_PROJECT_DIR:-}"
  [[ -n "$d" && -f "$d/harness.env" ]] && { echo "$d"; return; }
  # fall back to walking up from this file: .claude/hooks/ -> repo root
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

_HARNESS_ROOT="$(_harness_root)"
[[ -f "$_HARNESS_ROOT/harness.env" ]] && source "$_HARNESS_ROOT/harness.env"

# Derive the WSL interpreter path from the Windows path (single backslashes at runtime).
if [[ -n "${AHK_BIN_WIN:-}" ]]; then
  AHK_BIN_WSL="$(printf '%s' "$AHK_BIN_WIN" | sed 's|\\|/|g; s|^\([A-Za-z]\):|/mnt/\L\1|')"
fi

export AHK_BIN_WIN AHK_BIN_WSL AHK_DIAG_JSON PROJECT_DIR MAIN_SCRIPT \
       DEPENDENCY_SCRIPTS NO_RUNTIME_CHECK NO_AUTO_RELOAD RUNTIME_PROBE DEMO_DIR \
       GIT_GUARD_ENABLED GIT_ALLOWED_IDENTITY GIT_BLOCKLIST
