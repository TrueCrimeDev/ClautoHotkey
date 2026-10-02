#!/bin/bash
# PostToolUse hook for capture_error and analyze_error.
# Provides workflow guidance after key tools complete.

source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"

INPUT=$(cat)
harness_need_jq || exit 1
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty' 2>/dev/null)

case "$TOOL_NAME" in
  mcp__autohotkey-debug__capture_error)
    echo -e "\x1b[1;92m┌─ HOOK ▸ post-capture ───────────────────────────────────\x1b[0m" >&2
    if echo "$TOOL_OUTPUT" | jq -e '.status == "timeout"' >/dev/null 2>&1; then
      echo -e "\x1b[1;93m│ ⏱ capture_error timed out\x1b[0m" >&2
      echo -e "\x1b[1;92m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      echo '{"additionalContext": "capture_error timed out. Either the script has not been started with /Debug, or it ran without errors. Ask the user if they want to retry with a longer timeout or check debug_status."}'
    else
      echo -e "\x1b[1;92m│ ✓ Error captured — ready for analysis\x1b[0m" >&2
      echo -e "\x1b[1;92m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      echo '{"additionalContext": "Error captured successfully. Next steps: 1) analyze_error to diagnose, 2) apply_fix to patch the file, 3) tell user to re-run. If watches are set, consider stepping through the error area first."}'
    fi
    ;;
  mcp__autohotkey-debug__analyze_error)
    echo -e "\x1b[1;92m┌─ HOOK ▸ post-capture ───────────────────────────────────\x1b[0m" >&2
    if echo "$TOOL_OUTPUT" | jq -e '.status == "analyzed"' >/dev/null 2>&1; then
      echo -e "\x1b[1;92m│ ✓ Analysis complete via API\x1b[0m" >&2
      echo -e "\x1b[1;92m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      echo '{"additionalContext": "Claude API analysis complete. Extract the suggested_fix and call apply_fix if confidence is >= 0.7. Show the diagnosis to the user before applying."}'
    elif echo "$TOOL_OUTPUT" | jq -e '.status == "api_error"' >/dev/null 2>&1; then
      echo -e "\x1b[1;91m│ ✗ API analysis failed — falling back to client-side\x1b[0m" >&2
      echo -e "\x1b[1;91m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      echo '{"additionalContext": "API call failed. The analysis_prompt is included in the response — use it to analyze the error yourself."}'
    else
      echo -e "\x1b[1;92m│\x1b[0m Analysis prompt returned for client-side review" >&2
      echo -e "\x1b[1;92m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      echo '{"additionalContext": "Analysis prompt returned for client-side analysis. Read the prompt and provide your own diagnosis, then use apply_fix if confident."}'
    fi
    ;;
  mcp__autohotkey-debug__apply_fix)
    echo -e "\x1b[1;92m┌─ HOOK ▸ post-capture ───────────────────────────────────\x1b[0m" >&2
    if echo "$TOOL_OUTPUT" | jq -e '.success == true' >/dev/null 2>&1; then
      echo -e "\x1b[1;92m│ ✓ Fix applied successfully\x1b[0m" >&2
      echo -e "\x1b[1;92m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      echo '{"additionalContext": "Fix applied successfully. Tell the user to re-run: AutoHotkey64.exe /Debug script.ahk (using the custom engine from CLAUDE.md)"}'
    else
      echo -e "\x1b[1;91m│ ✗ Fix FAILED — line mismatch\x1b[0m" >&2
      echo -e "\x1b[1;91m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      echo '{"additionalContext": "Fix failed — likely a line mismatch. Read the actual line content from the error, adjust the original parameter, and retry apply_fix."}'
    fi
    ;;
  *)
    echo '{}'
    ;;
esac
