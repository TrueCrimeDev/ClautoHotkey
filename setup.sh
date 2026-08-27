#!/usr/bin/env bash
# Bootstrap a cloned ClautoHotkey into a working harness.
#
# You only need this for the clone route. Installing the plugin instead —
#   /plugin marketplace add TrueCrimeDev/ClautoHotkey
#   /plugin install clautohotkey@clautohotkey
# — needs no setup at all, and the harness auto-detects your AutoHotkey binary.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || echo "WARNING: 'jq' not found — the hooks require it. Install jq before using the harness."
command -v python3 >/dev/null 2>&1 || echo "NOTE: 'python3' not found — Tools/lint_modules.py will not run."

if [[ ! -f harness.env ]]; then
    cp harness.env.example harness.env
    echo "Created harness.env from the example. Edit it with your values, then re-run ./setup.sh"
    exit 0
fi
source harness.env

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

# The plugin wires its hooks through hooks/hooks.json and ${CLAUDE_PLUGIN_ROOT}. A clone
# has no plugin root, so derive .claude/settings.json from the same file — one source of
# truth for the hook wiring, two ways of addressing it.
if [[ -f hooks/hooks.json ]] && command -v jq >/dev/null 2>&1; then
    mkdir -p .claude
    jq '{
          "$schema": "https://json.schemastore.org/claude-code-settings.json",
          permissions: {
            deny: [
              "Read(**/node_modules/**)", "Glob(**/node_modules/**)", "Grep(**/node_modules/**)",
              "Read(.history/**)", "Glob(.history/**)", "Grep(.history/**)"
            ]
          },
          hooks: .hooks
        }' hooks/hooks.json \
      | sed 's|\${CLAUDE_PLUGIN_ROOT}|$CLAUDE_PROJECT_DIR|g' \
      > .claude/settings.json
    echo "rendered .claude/settings.json from hooks/hooks.json"
fi

if [[ -f CLAUDE.md.template ]]; then
    if [[ -f CLAUDE.md ]]; then
        echo "CLAUDE.md exists — left untouched (delete it to re-render)"
    else
        render CLAUDE.md.template CLAUDE.md
        echo "rendered CLAUDE.md"
    fi
fi

chmod +x hooks/*.sh setup.sh 2>/dev/null
[[ -d skills ]] && find skills -name '*.sh' -exec chmod +x {} +
[[ -f Tools/lint_modules.py ]] && chmod +x Tools/lint_modules.py

if [[ -n "${AHK_BIN_WSL:-}" && ! -e "$AHK_BIN_WSL" ]]; then
    echo "WARNING: AHK binary not found at $AHK_BIN_WSL — fix AHK_BIN_WIN in harness.env"
fi

echo "setup complete. Run ./Tools/verify.sh to confirm the harness works."
