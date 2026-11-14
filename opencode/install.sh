#!/usr/bin/env bash
# Install ClautoHotkey into OpenCode (the 1.x line).
#
#   ./opencode/install.sh                  every project: ~/.config/opencode
#   ./opencode/install.sh --project DIR    one project: DIR/.opencode (+ AGENTS.md, harness.env)
#   ./opencode/install.sh --uninstall [--project DIR]
#
# What it writes:
#   opencode.json   a `plugin` entry pointing at opencode/clautohotkey.ts in this clone.
#                   The plugin registers the agents, the commands and every skill as a
#                   /<name> command, and bridges the hook scripts (validation after each
#                   .ahk edit, path-scoped rules, interpreter guard, v1 detection).
#   skill/<name>/   a copy of each skill, so the model can also pick skills itself
#                   through OpenCode's skill tool. Re-run after pulling to refresh.
#
# Nothing else is copied: agents, commands, rules, hooks and modules are read from the
# clone, so a `git pull` is the whole upgrade. Needs bash (Git Bash or WSL), OpenCode
# 1.x on PATH, and jq or Python 3 to edit opencode.json.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# This clone's config is the one that counts, not a project some session has open.
unset CLAUDE_PROJECT_DIR
source "$ROOT/hooks/_harness-env.sh"

MODE=install
PROJECT=""
SKILLS=1
FORCE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)   PROJECT="${2:-}"; shift 2 ;;
        --project=*) PROJECT="${1#*=}"; shift ;;
        --uninstall) MODE=uninstall; shift ;;
        --no-skills) SKILLS=0; shift ;;
        --force)     FORCE=1; shift ;;
        -h|--help)   sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $1 (try --help)" >&2; exit 64 ;;
    esac
done

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# OpenCode version gate. The plugin uses the 1.x API (singular `plugin`, `agent`,
# `command` keys and the tool.execute hooks). 2.x renamed all of it.
OC_VERSION=""
if type -P opencode >/dev/null 2>&1; then
    OC_VERSION="$(opencode --version 2>/dev/null | tr -d '\r' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
fi
if [[ -z "$OC_VERSION" ]]; then
    warn "opencode is not on PATH; installing anyway. Install it from https://opencode.ai and re-run to verify."
elif [[ "${OC_VERSION%%.*}" -ge 2 && $FORCE -ne 1 ]]; then
    die "OpenCode $OC_VERSION uses the V2 plugin API (plural 'plugins', Plugin.define); this plugin targets 1.x. Re-run with --force to write the 1.x config anyway."
fi

# Where to install.
if [[ -n "$PROJECT" ]]; then
    [[ -d "$PROJECT" ]] || die "no such directory: $PROJECT"
    PROJECT="$(cd "$PROJECT" && pwd)"
    TARGET="$PROJECT/.opencode"
else
    TARGET=""
    if [[ -n "$OC_VERSION" ]]; then
        TARGET="$(opencode debug paths 2>/dev/null | tr -d '\r' | awk '$1=="config"{ $1=""; sub(/^ +/, ""); print; exit }')"
    fi
    [[ -n "$TARGET" ]] && TARGET="$(harness_to_unix "$TARGET")"
    [[ -n "$TARGET" ]] || TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
fi
mkdir -p "$TARGET" || die "cannot create $TARGET"

# The clone's path as OpenCode (a Windows program under Git Bash, a Linux one under
# WSL) will spell it, and as a file URL for the plugin entry.
case "$HARNESS_PLATFORM" in
    msys|cygwin)
        ROOT_WIN="$(harness_to_win "$ROOT")"
        ROOT_FWD="${ROOT_WIN//\\//}"
        PLUGIN_URL="file:///$ROOT_FWD/opencode/clautohotkey.ts" ;;
    *)
        ROOT_FWD="$ROOT"
        PLUGIN_URL="file://$ROOT/opencode/clautohotkey.ts" ;;
esac

CONFIG="$TARGET/opencode.json"
if [[ ! -f "$CONFIG" && -f "$TARGET/opencode.jsonc" ]]; then
    CONFIG="$TARGET/opencode.jsonc"
fi

# edit_config add|remove: keep every other key, replace any earlier clautohotkey entry.
edit_config() {
    local action="$1" tmp="$CONFIG.tmp.$$"
    if [[ ! -f "$CONFIG" ]]; then
        printf '{}\n' > "$CONFIG" || die "cannot write $CONFIG"
    fi
    if [[ "${HARNESS_JQ:-}" == jq ]]; then
        if jq --arg url "$PLUGIN_URL" --arg action "$action" '
              .plugin = ([(.plugin // [])[] | select(test("clautohotkey\\.ts$") | not)]
                         + (if $action == "add" then [$url] else [] end))
              | if .plugin == [] then del(.plugin) else . end' "$CONFIG" > "$tmp" 2>/dev/null \
           && [[ -s "$tmp" ]]; then
            mv -f "$tmp" "$CONFIG"
            return 0
        fi
        rm -f "$tmp"
    fi
    if _harness_python; then
        local cfg_arg="$CONFIG"
        [[ "$_HARNESS_PY_KIND" == win ]] && cfg_arg="$(harness_to_win "$CONFIG")"
        if "$_HARNESS_PY" -E -S - "$cfg_arg" "$PLUGIN_URL" "$action" <<'PY'
import json, re, sys
path, url, action = sys.argv[1:4]
text = open(path, encoding="utf-8-sig").read()
try:
    cfg = json.loads(text) if text.strip() else {}
except json.JSONDecodeError:
    # JSONC: drop // and /* */ comments and trailing commas, then try again.
    # Strings are matched first and kept, so the // in "https://opencode.ai/..."
    # is not taken for a comment.
    string = r'"(?:\\.|[^"\\])*"'
    stripped = re.sub(string + r"|//[^\n]*|/\*.*?\*/",
                      lambda m: m.group(0) if m.group(0).startswith('"') else "", text, flags=re.S)
    stripped = re.sub(string + r"|,(?=\s*[}\]])",
                      lambda m: m.group(0) if m.group(0).startswith('"') else "", stripped, flags=re.S)
    cfg = json.loads(stripped)
    # json.dump below cannot write the comments back.
    sys.stderr.write("WARNING: %s had comments; they are not kept in the rewritten file\n" % path)
plugins = [p for p in cfg.get("plugin", []) if not str(p).endswith("clautohotkey.ts")]
if action == "add":
    plugins.append(url)
if plugins:
    cfg["plugin"] = plugins
else:
    cfg.pop("plugin", None)
with open(path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY
        then
            return 0
        fi
    fi
    die "could not edit $CONFIG: install jq or Python 3, or add this by hand:  \"plugin\": [\"$PLUGIN_URL\"]"
}

MARKER=".clautohotkey"

remove_skills() {
    local dir n=0
    for dir in "$TARGET"/skill/*/; do
        [[ -f "$dir$MARKER" ]] || continue
        rm -rf "$dir" && n=$((n + 1))
    done
    say "removed $n skill copies from $TARGET/skill"
}

install_skills() {
    local src name dest n=0
    for src in "$ROOT"/skills/*/; do
        name="$(basename "$src")"
        [[ "$name" == _* || ! -f "$src/SKILL.md" ]] && continue
        dest="$TARGET/skill/$name"
        if [[ -d "$dest" && ! -f "$dest/$MARKER" ]]; then
            warn "skipping skill '$name': $dest exists and is not ours"
            continue
        fi
        rm -rf "$dest"
        mkdir -p "$dest"
        cp -R "$src". "$dest"/ || die "cannot copy skill $name"
        # The bodies name files under ${CLAUDE_PLUGIN_ROOT}; write the clone path in.
        sed -i -e "s|\${CLAUDE_PLUGIN_ROOT}|$ROOT_FWD|g" -e "s|\$CLAUDE_PLUGIN_ROOT\b|$ROOT_FWD|g" "$dest/SKILL.md"
        printf 'installed from %s by opencode/install.sh; re-run it to refresh, do not edit here\n' "$ROOT_FWD" > "$dest/$MARKER"
        n=$((n + 1))
    done
    say "copied $n skills to $TARGET/skill (OpenCode's skill tool reads them; /<name> commands come from the plugin)"
}

render_project_files() {
    local agents="$PROJECT/AGENTS.md" env_file="$PROJECT/harness.env"
    if [[ -f "$agents" ]]; then
        say "AGENTS.md exists in $PROJECT; left untouched"
    elif [[ -f "$ROOT/CLAUDE.md.template" ]]; then
        local content
        content="$(cat "$ROOT/CLAUDE.md.template")"
        content="${content//# CLAUDE.md/# AGENTS.md}"
        content="${content//Project guidance for Claude Code. Rendered by \`setup.sh\`/Project guidance for OpenCode. Rendered by \`opencode\/install.sh\`}"
        content="${content//\`setup.sh\` will not overwrite it/the installer will not overwrite it}"
        content="${content//@AHK_BIN_WIN@/${AHK_BIN_WIN:-auto-detected}}"
        content="${content//@DEMO_DIR@/${DEMO_DIR:-}}"
        content="${content//@PROJECT_DIR@/$PROJECT}"
        content="${content//source hooks\/_harness-env.sh/source \"$ROOT_FWD\/hooks\/_harness-env.sh\"}"
        printf '%s\n' "$content" > "$agents" && say "rendered $agents"
    fi
    if [[ ! -f "$env_file" && -f "$ROOT/harness.env.example" ]]; then
        cp "$ROOT/harness.env.example" "$env_file" && say "created $env_file from the example (every key optional; AHK_BIN_WIN empty = auto-detect)"
    fi
}

if [[ "$MODE" == uninstall ]]; then
    [[ -f "$CONFIG" ]] && edit_config remove && say "removed the plugin entry from $CONFIG"
    remove_skills
    say "done. AGENTS.md and harness.env in a project are left in place."
    exit 0
fi

[[ -f "$ROOT/opencode/clautohotkey.ts" ]] || die "opencode/clautohotkey.ts is missing from this clone"
edit_config add
say "plugin entry written to $CONFIG"
say "  $PLUGIN_URL"
if [[ $SKILLS -eq 1 ]]; then
    install_skills
fi
[[ -n "$PROJECT" ]] && render_project_files

if [[ -z "${AHK_BIN_WIN:-}" ]]; then
    warn "no AutoHotkey v2 interpreter found. Set AHK_BIN_WIN in $ROOT/harness.env (or a project's harness.env); edits are not validated until then."
elif [[ "${AHK_BIN_MISSING:-0}" == 1 ]]; then
    warn "configured interpreter not found: $AHK_BIN_WIN"
else
    say "interpreter: $AHK_BIN_WIN$([[ "${AHK_AUTODETECTED:-0}" == 1 ]] && echo ' (auto-detected)')"
fi
[[ -n "${HARNESS_JQ:-}" ]] || warn "neither jq nor Python 3 found: the hook scripts will report themselves inactive."

say
say "ClautoHotkey is installed for OpenCode${OC_VERSION:+ $OC_VERSION}${PROJECT:+ in $PROJECT}."
say "Check:  opencode debug config | grep -c '\"ahk-'      (agents + commands registered by the plugin)"
say "        opencode debug skill | grep -c '\"ahk-'       (skill copies)"
say "Use:    /ahk-gui, /ahk-fix, /ahk-oop ... as commands; ask for the ahk-analysis or ahk-test-generator agent."
say "Update: git pull in $ROOT, then re-run this script to refresh the skill copies."
