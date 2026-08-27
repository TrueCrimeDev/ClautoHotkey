#!/usr/bin/env bash
# PreToolUse on Write|Edit: auto-load path-scoped rules.
# When the edited file matches a rule's `paths:` frontmatter glob, inject that
# rule's body as additionalContext — once per session per rule, so rules are
# seen without re-spamming context on every edit.

source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
session_id=$(echo "$input" | jq -r '.session_id // "default"' 2>/dev/null)
[[ -z "$file_path" ]] && exit 0

RULES_DIR="$(dirname "${BASH_SOURCE[0]}")/../rules"
[[ -d "$RULES_DIR" ]] || exit 0

# Normalize the edited path to a project-relative WSL path.
fp="$file_path"
case "$fp" in [A-Za-z]:*|*\\*) fp=$(wslpath -u "$fp" 2>/dev/null) ;; esac
proj="${CLAUDE_PROJECT_DIR:-${PROJECT_DIR:-$PWD}}"
relpath="${fp#"$proj"/}"

seen="/tmp/claude-rules-injected-$session_id"
touch "$seen" 2>/dev/null

# Read the `paths:` globs from a rule's YAML frontmatter (one per line).
get_paths() {
    awk '
        NR==1 && $0=="---" {fm=1; next}
        fm==1 && $0=="---" {exit}
        fm==1 && /^paths:/ {inp=1; next}
        fm==1 && inp==1 && /^[[:space:]]*-[[:space:]]*/ {
            line=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",line)
            gsub(/^["'"'"']|["'"'"']$/,"",line)
            print line; next
        }
        fm==1 && inp==1 && /^[^[:space:]-]/ {inp=0}
    ' "$1"
}

# Rule body with the frontmatter stripped.
get_body() {
    if [[ "$(head -1 "$1")" == "---" ]]; then
        awk 'f==2{print} /^---$/{f++}' "$1"
    else
        cat "$1"
    fi
}

# Convert a path glob to an anchored ERE. Handles **, *, ? without letting the
# expansion of ** (-> .*) be re-processed by the single-* rule (placeholders).
glob_to_re() {
    local g
    g=$(printf '%s' "$1" | sed -E 's/[][(){}.^$+|]/\\&/g')
    g=${g//'**/'/$'\x01'}
    g=${g//'**'/$'\x02'}
    g=${g//'*'/'[^/]*'}
    g=${g//'?'/'[^/]'}
    g=${g//$'\x01'/'(.*/)?'}
    g=${g//$'\x02'/'.*'}
    printf '^%s$' "$g"
}

matches() { # relpath rulefile -> 0 if any glob matches
    local glob re
    while IFS= read -r glob; do
        [[ -z "$glob" ]] && continue
        re=$(glob_to_re "$glob")
        [[ "$1" =~ $re ]] && return 0
    done < <(get_paths "$2")
    return 1
}

combined=""
for rule in "$RULES_DIR"/*.md; do
    [[ -f "$rule" ]] || continue
    name=$(basename "$rule")
    grep -qxF "$name" "$seen" 2>/dev/null && continue          # already injected this session
    matches "$relpath" "$rule" || continue
    echo "$name" >> "$seen"
    combined+="## Rule: ${name%.md} (auto-loaded for \`$relpath\`)

$(get_body "$rule")

"
done

[[ -z "$combined" ]] && exit 0

jq -n --arg ctx "$combined" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}'
exit 0
