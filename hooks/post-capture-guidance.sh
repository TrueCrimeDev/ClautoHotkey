#!/bin/bash
# PostToolUse hook for capture_error, analyze_error and apply_fix (the optional
# autohotkey-debug MCP server). Tells the model what the next step is.
#
# The result arrives as `tool_response` (`tool_output` from hosts that call it
# that), and for an MCP tool it may be the server's object or that object as JSON
# text inside a content block. Rather than assume one shape, the fields are looked
# for in the result's text, with or without the backslashes of an embedded string.
# The guidance has to sit under hookSpecificOutput to reach the model.

source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"

INPUT=$(cat)
harness_need_jq || exit 1
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
RESULT=$(echo "$INPUT" | jq -c '.tool_response // .tool_output // empty' 2>/dev/null)

# result_has KEY VALUE: "KEY": VALUE somewhere in the result. VALUE is a quoted
# string unless it is true or false.
result_has() {
    local value="$2"
    [[ "$value" == true || "$value" == false ]] || value="\\\\?\"$value\\\\?\""
    printf '%s' "$RESULT" | grep -qE "\\\\?\"$1\\\\?\"[[:space:]]*:[[:space:]]*$value"
}

advise() {
    jq -nc --arg ctx "$1" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
}

case "$TOOL_NAME" in
  mcp__autohotkey-debug__capture_error)
    echo -e "\x1b[1;92m┌─ HOOK ▸ post-capture ───────────────────────────────────\x1b[0m" >&2
    if result_has status timeout; then
      echo -e "\x1b[1;93m│ ⏱ capture_error timed out\x1b[0m" >&2
      echo -e "\x1b[1;92m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      advise "capture_error timed out. Either the script has not been started with /Debug, or it ran without errors. Ask the user if they want to retry with a longer timeout or check debug_status."
    else
      echo -e "\x1b[1;92m│ ✓ Error captured — ready for analysis\x1b[0m" >&2
      echo -e "\x1b[1;92m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      advise "Error captured successfully. Next steps: 1) analyze_error to diagnose, 2) apply_fix to patch the file, 3) tell user to re-run. If watches are set, consider stepping through the error area first."
    fi
    ;;
  mcp__autohotkey-debug__analyze_error)
    echo -e "\x1b[1;92m┌─ HOOK ▸ post-capture ───────────────────────────────────\x1b[0m" >&2
    if result_has status analyzed; then
      echo -e "\x1b[1;92m│ ✓ Analysis complete via API\x1b[0m" >&2
      echo -e "\x1b[1;92m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      advise "Claude API analysis complete. Extract the suggested_fix and call apply_fix if confidence is >= 0.7. Show the diagnosis to the user before applying."
    elif result_has status api_error; then
      echo -e "\x1b[1;91m│ ✗ API analysis failed — falling back to client-side\x1b[0m" >&2
      echo -e "\x1b[1;91m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      advise "API call failed. The analysis_prompt is included in the response — use it to analyze the error yourself."
    else
      echo -e "\x1b[1;92m│\x1b[0m Analysis prompt returned for client-side review" >&2
      echo -e "\x1b[1;92m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      advise "Analysis prompt returned for client-side analysis. Read the prompt and provide your own diagnosis, then use apply_fix if confident."
    fi
    ;;
  mcp__autohotkey-debug__apply_fix)
    echo -e "\x1b[1;92m┌─ HOOK ▸ post-capture ───────────────────────────────────\x1b[0m" >&2
    if result_has success true; then
      echo -e "\x1b[1;92m│ ✓ Fix applied successfully\x1b[0m" >&2
      echo -e "\x1b[1;92m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      advise "Fix applied successfully. Tell the user to re-run the script with the configured interpreter and /Debug."
    else
      echo -e "\x1b[1;91m│ ✗ Fix FAILED — line mismatch\x1b[0m" >&2
      echo -e "\x1b[1;91m└─────────────────────────────────────────────────────────\x1b[0m" >&2
      advise "Fix failed — likely a line mismatch. Read the actual line content from the error, adjust the original parameter, and retry apply_fix."
    fi
    ;;
  *)
    echo '{}'
    ;;
esac
