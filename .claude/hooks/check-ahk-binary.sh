#!/usr/bin/env bash
# PreToolUse on Bash: block invocations of any AutoHotkey*.exe that isn't the
# binary configured in harness.env (AHK_BIN_WIN). Keeps every run on one known
# interpreter. Plain-text mentions (commit messages, comments) are not flagged.

set -u

source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"

# Canonical binary from harness.env; build a normalized (drive-stripped,
# forward-slashed) match fragment that mirrors how the command is normalized.
CANONICAL_WIN="$AHK_BIN_WIN"
CANONICAL_WSL="$AHK_BIN_WSL"
CANONICAL_PATH_FRAGMENT="$(printf '%s' "${AHK_BIN_WIN:-}" | tr '\\' '/' | sed 's|^[A-Za-z]:||')"

# If no binary is configured, don't block anything.
[[ -z "$CANONICAL_PATH_FRAGMENT" ]] && exit 0

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

[[ -z "$cmd" ]] && exit 0

# Normalize backslashes to forward slashes for matching, but keep original for error message.
cmd_norm=$(echo "$cmd" | tr '\\' '/')

# Only act if the command actually references an AutoHotkey exe as a binary
# invocation — i.e., preceded by a path separator. Avoids false positives on
# plain-text mentions in commit messages, comments, etc.
if ! echo "$cmd_norm" | grep -qiE '/autohotkey[a-z0-9.-]*\.exe'; then
    exit 0
fi

# Allow only if the canonical path fragment appears as a complete binary
# (followed by whitespace, quote, or end-of-string) — not as a prefix of
# something like AutoHotkey64.exe.prev-alpha26.
if echo "$cmd_norm" | grep -qE "${CANONICAL_PATH_FRAGMENT}([^a-zA-Z0-9.]|$)"; then
    exit 0
fi

# Otherwise: block.
echo "BLOCKED: Non-canonical AutoHotkey binary referenced." >&2
echo "Command: $cmd" >&2
echo "" >&2
echo "Use the canonical alpha.30+Console fork build:" >&2
echo "  WSL:     $CANONICAL_WSL" >&2
echo "  Windows: $CANONICAL_WIN" >&2
echo "" >&2
echo "Only the binary set in harness.env (AHK_BIN_WIN) is allowed." >&2
echo "See .claude/rules/ahk-interpreter.md." >&2
exit 2
