#!/usr/bin/env bash
# PreToolUse on Bash: block 'git push' commands when the active git user
# is one of the blocklisted accounts. Catches drift in local/global git
# config that would otherwise push to the wrong GitHub identity.
# Opt-in via GIT_GUARD_ENABLED; accounts to block come from GIT_BLOCKLIST.

set -u

source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"

# Opt-in: only guard pushes when explicitly enabled in harness.env.
[[ "${GIT_GUARD_ENABLED:-0}" != "1" ]] && exit 0
IFS=',' read -ra BLOCKLISTED_ACCOUNTS <<< "${GIT_BLOCKLIST:-}"

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

[[ -z "$cmd" ]] && exit 0

# Walk the command tokens to find 'git ... push' as a real invocation,
# correctly handling flags that take values (-c key=val, -C path).
is_git_push() {
    local -a tok
    read -ra tok <<< "$1"
    local i=0
    while (( i < ${#tok[@]} )); do
        if [[ "${tok[i]}" == "git" ]]; then
            (( i++ ))
            while (( i < ${#tok[@]} )); do
                local t="${tok[i]}"
                if [[ "$t" == "-c" || "$t" == "-C" ]]; then
                    (( i += 2 ))
                    continue
                fi
                if [[ "$t" == -* ]]; then
                    (( i++ ))
                    continue
                fi
                [[ "$t" == "push" ]] && return 0
                break
            done
        fi
        (( i++ ))
    done
    return 1
}

if ! is_git_push "$cmd"; then
    exit 0
fi

# Determine the target directory for the push. If the command has a 'cd <dir>'
# prefix, use that; otherwise use the current shell cwd.
target_dir=""
cd_match=$(echo "$cmd" | grep -oE '(^|&&|;)[[:space:]]*cd[[:space:]]+[^&;|]+' | head -1 | sed -E 's/^(&&|;)?[[:space:]]*cd[[:space:]]+//' | tr -d '"' | tr -d "'" | sed 's/[[:space:]]*$//')
if [[ -n "$cd_match" && -d "$cd_match" ]]; then
    target_dir="$cd_match"
else
    target_dir="$PWD"
fi

# Read the configured git user.name in the target dir.
user_name=$(cd "$target_dir" 2>/dev/null && git config user.name 2>/dev/null)

[[ -z "$user_name" ]] && exit 0

# Block if blocklisted.
for blocked in "${BLOCKLISTED_ACCOUNTS[@]}"; do
    blocked="$(echo "$blocked" | xargs)"
    [[ -z "$blocked" ]] && continue
    if [[ "$user_name" == "$blocked" ]]; then
        echo "BLOCKED: 'git push' as account '$user_name' is forbidden by default." >&2
        echo "" >&2
        echo "Working directory: $target_dir" >&2
        echo "Configured user:   $user_name" >&2
        echo "" >&2
        echo "Allowed identity (GIT_ALLOWED_IDENTITY): ${GIT_ALLOWED_IDENTITY:-<unset>}" >&2
        echo "Blocklisted (GIT_BLOCKLIST): ${BLOCKLISTED_ACCOUNTS[*]}" >&2
        echo "" >&2
        echo "To proceed:" >&2
        echo "  cd \"$target_dir\"" >&2
        echo "  git config user.name \"${GIT_ALLOWED_IDENTITY:-<your-identity>}\"" >&2
        echo "" >&2
        echo "If you intentionally want to push as $user_name, the user must" >&2
        echo "explicitly authorize the operation in this conversation." >&2
        exit 2
    fi
done

exit 0
