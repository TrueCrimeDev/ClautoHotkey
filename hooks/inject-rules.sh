#!/usr/bin/env bash
# PreToolUse on Write|Edit: auto-load path-scoped rules.
# When the edited file matches a rule's `paths:` frontmatter glob, inject that
# rule's body as additionalContext — once per session per rule, so rules are
# seen without re-spamming context on every edit.
#
# Rule frontmatter:
#   paths:     globs against the project-relative path, matched without regard to
#              case because Windows paths have none
#   contains:  strings; an .ahk file that holds one (on disk, or in the text this
#              edit writes) matches whatever it is called. A GUI script is a GUI
#              script because it calls Gui(), not because of its name
#   build:     "fork" keeps the rule for the +Console fork (AHK_DIAG_JSON=1), so a
#              stock install is not handed notes on features it does not have
# A rule matches on a path glob or a contains string; build then narrows it.

source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"

input=$(cat)
harness_need_jq || exit 1
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
session_id=$(echo "$input" | jq -r '.session_id // "default"' 2>/dev/null)
[[ -z "$file_path" ]] && exit 0
# What this edit writes: Write sends content, Edit sends new_string.
incoming=$(echo "$input" | jq -r '(.tool_input.content // "") + "\n" + (.tool_input.new_string // "")' 2>/dev/null)

RULES_DIR="$(dirname "${BASH_SOURCE[0]}")/../rules"
[[ -d "$RULES_DIR" ]] || exit 0

# Normalize the edited path to a project-relative path. Both sides go through the
# same helper, so C:\... (Git Bash), /mnt/c/... (WSL) and a mix of the two line up;
# the prefix test ignores case because Windows paths do.
fp="$(harness_to_unix "$file_path")"
proj="$(harness_to_unix "${CLAUDE_PROJECT_DIR:-${PROJECT_DIR:-$PWD}}")"
proj="${proj%/}"
relpath="$fp"
if [[ -n "$proj" && "${fp,,}" == "${proj,,}/"* ]]; then
    relpath="${fp:${#proj}+1}"
fi

seen="/tmp/claude-rules-injected-$session_id"
touch "$seen" 2>/dev/null

# get_list KEY FILE: the items of a list in a rule's YAML frontmatter, one per
# line. A trailing carriage return is dropped from every line first: a checkout
# with core.autocrlf=true hands these files over with CRLF endings, and "---\r"
# is not "---".
get_list() {
    awk -v key="$1" '
        {sub(/\r$/, "")}
        NR==1 && $0=="---" {fm=1; next}
        fm==1 && $0=="---" {exit}
        fm==1 && $0 ~ ("^" key ":") {inp=1; next}
        fm==1 && inp==1 && /^[[:space:]]*-[[:space:]]*/ {
            line=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",line)
            gsub(/^["'"'"']|["'"'"']$/,"",line)
            print line; next
        }
        fm==1 && inp==1 && /^[^[:space:]-]/ {inp=0}
    ' "$2"
}

# get_scalar KEY FILE: a one-line `key: value` from the frontmatter.
get_scalar() {
    awk -v key="$1" '
        {sub(/\r$/, "")}
        NR==1 && $0=="---" {fm=1; next}
        fm==1 && $0=="---" {exit}
        fm==1 && $0 ~ ("^" key ":[[:space:]]*[^[:space:]]") {
            line=$0; sub("^" key ":[[:space:]]*","",line)
            gsub(/^["'"'"']|["'"'"']$/,"",line)
            print line; exit
        }
    ' "$2"
}

# Rule body with the frontmatter stripped. Only the first two "---" lines are the
# frontmatter fence; a later one is a horizontal rule in the body and stays.
get_body() {
    awk '
        {sub(/\r$/, "")}
        NR==1 && $0!="---" {f=2}
        f<2 && $0=="---" {f++; next}
        f==2 {print}
    ' "$1"
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

matches() { # relpath rulefile -> 0 if a glob or a contains string matches
    local glob re needle hit=1
    shopt -s nocasematch
    while IFS= read -r glob; do
        [[ -z "$glob" ]] && continue
        re=$(glob_to_re "$glob")
        if [[ "$1" =~ $re ]]; then hit=0; break; fi
    done < <(get_list paths "$2")
    if [[ $hit -ne 0 && "$1" == *.ahk ]]; then
        while IFS= read -r needle; do
            [[ -z "$needle" ]] && continue
            if [[ "$incoming" == *"$needle"* ]] \
                    || { [[ -f "$fp" ]] && grep -qiF -- "$needle" "$fp" 2>/dev/null; }; then
                hit=0; break
            fi
        done < <(get_list contains "$2")
    fi
    shopt -u nocasematch
    return $hit
}

# build: fork rules are for the +Console fork only.
build_ok() {
    local build
    build="$(get_scalar build "$1")"
    [[ "${build,,}" != fork || "${AHK_DIAG_JSON:-0}" == 1 ]]
}

combined=""
for rule in "$RULES_DIR"/*.md; do
    [[ -f "$rule" ]] || continue
    name=$(basename "$rule")
    grep -qxF "$name" "$seen" 2>/dev/null && continue          # already injected this session
    matches "$relpath" "$rule" || continue
    build_ok "$rule" || continue
    echo "$name" >> "$seen"
    combined+="## Rule: ${name%.md} (auto-loaded for \`$relpath\`)

$(get_body "$rule")

"
done

[[ -z "$combined" ]] && exit 0

jq -n --arg ctx "$combined" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}'
exit 0
