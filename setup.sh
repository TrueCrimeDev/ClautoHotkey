#!/usr/bin/env bash
# Bootstrap a cloned ClautoHotkey into a working harness.
#
# You only need this for the clone route. Installing the plugin instead —
#   /plugin marketplace add TrueCrimeDev/ClautoHotkey
#   /plugin install clautohotkey@clautohotkey
# — needs no setup at all, and the harness auto-detects your AutoHotkey binary.
#
# Runs under WSL, Git Bash or Cygwin.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ ! -f harness.env ]]; then
    cp harness.env.example harness.env
    echo "Created harness.env from the example. Edit it with your values, then re-run ./setup.sh"
    exit 0
fi

# Load configuration the way the hooks do (harness.env, then harness.local.env,
# with ${WIN_HOME} and the path helpers available), so setup sees what they see.
# This clone's config is the one that counts here, not whatever project a calling
# Claude Code session has open.
unset CLAUDE_PROJECT_DIR
source hooks/_harness-env.sh

case "${HARNESS_JQ:-}" in
    jq)     ;;
    jqlite) echo "NOTE: 'jq' not found — the hooks will use the bundled jqlite on Python ($_HARNESS_PY)." ;;
    *)      echo "WARNING: neither 'jq' nor a working Python 3 was found — every hook will report itself inactive. Install jq or Python 3.8+." ;;
esac
_harness_python || echo "NOTE: no working Python 3 found — Tools/lint_modules.py will not run."

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
# truth for the hook wiring, two ways of addressing it. `jq` here is the real jq or,
# without it, jqlite running on Python.
if [[ -f hooks/hooks.json ]]; then
    if [[ -n "${HARNESS_JQ:-}" ]]; then
        mkdir -p .claude
        if jq '{
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
              > .claude/settings.json.tmp \
            && [[ -s .claude/settings.json.tmp ]]; then
            mv -f .claude/settings.json.tmp .claude/settings.json
            echo "rendered .claude/settings.json from hooks/hooks.json (via $HARNESS_JQ)"
        else
            rm -f .claude/settings.json.tmp
            echo "WARNING: could not render .claude/settings.json from hooks/hooks.json"
        fi
    else
        echo "WARNING: .claude/settings.json not rendered — it needs jq or Python 3."
    fi
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

if [[ -z "${AHK_BIN_WIN:-}" ]]; then
    echo "WARNING: no AutoHotkey v2 binary configured or found — set AHK_BIN_WIN in harness.env"
elif [[ "${AHK_BIN_MISSING:-0}" == 1 ]]; then
    echo "WARNING: AHK binary not found at $AHK_BIN_WIN ($AHK_BIN_SH) — fix AHK_BIN_WIN in harness.env or harness.local.env"
fi

echo "setup complete. Run ./Tools/verify.sh to confirm the harness works."
