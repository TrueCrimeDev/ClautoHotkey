#!/usr/bin/env bash
# Bootstrap a clone of ahk-claude-harness into a working harness.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# Preflight: the hooks require jq.
command -v jq >/dev/null 2>&1 || echo "WARNING: 'jq' not found — the hooks require it. Install jq before using the harness."

if [[ ! -f harness.env ]]; then
  cp harness.env.example harness.env
  echo "Created harness.env from the example. Edit it with your values, then re-run ./setup.sh"
  exit 0
fi
source harness.env

# Derive WSL path for validation.
AHK_BIN_WSL="$(printf '%s' "${AHK_BIN_WIN:-}" | sed 's|\\|/|g; s|^\([A-Za-z]\):|/mnt/\L\1|')"

# Literal-safe token substitution (bash expansion — does NOT mangle backslashes).
render() {
  local tpl="$1" out="$2" content
  content="$(cat "$tpl")"
  content="${content//@AHK_BIN_WIN@/${AHK_BIN_WIN:-}}"
  content="${content//@DEMO_DIR@/${DEMO_DIR:-}}"
  content="${content//@PROJECT_DIR@/${PROJECT_DIR:-}}"
  printf '%s\n' "$content" > "$out"
}

# settings.json always; CLAUDE.md only if absent (don't clobber a personal one).
if [[ -f .claude/settings.json.template ]]; then
  render .claude/settings.json.template .claude/settings.json
  echo "rendered .claude/settings.json"
fi
if [[ -f CLAUDE.md.template ]]; then
  if [[ -f CLAUDE.md ]]; then
    echo "CLAUDE.md exists — left untouched (delete it to re-render)"
  else
    render CLAUDE.md.template CLAUDE.md
    echo "rendered CLAUDE.md"
  fi
fi

chmod +x .claude/hooks/*.sh setup.sh 2>/dev/null
[[ -d .claude/skills ]] && find .claude/skills -name '*.sh' -exec chmod +x {} +

if [[ -n "${AHK_BIN_WSL:-}" && ! -e "$AHK_BIN_WSL" ]]; then
  echo "WARNING: AHK binary not found at $AHK_BIN_WSL — fix AHK_BIN_WIN in harness.env"
fi
echo "setup complete."
