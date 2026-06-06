#!/bin/bash
# UserPromptSubmit hook: Detect AHK v1 syntax in user prompts
# Non-blocking — adds context warning when v1 patterns are found.

input=$(cat)
user_prompt=$(echo "$input" | jq -r '.prompt // .user_prompt // empty' 2>/dev/null)

if [[ -z "$user_prompt" ]]; then
    exit 0
fi

v1_patterns=0
v1_found=""

# Check for common v1-only patterns
if echo "$user_prompt" | grep -qP '(?i)\bIfEqual\b'; then
    v1_patterns=$((v1_patterns + 1))
    v1_found="${v1_found}IfEqual "
fi

if echo "$user_prompt" | grep -qP '(?i)\bStringLeft\b|\bStringRight\b|\bStringMid\b|\bStringLen\b'; then
    v1_patterns=$((v1_patterns + 1))
    v1_found="${v1_found}String* "
fi

if echo "$user_prompt" | grep -qP '(?i)^Gui\s*,\s*Add'; then
    v1_patterns=$((v1_patterns + 1))
    v1_found="${v1_found}Gui,Add "
fi

if echo "$user_prompt" | grep -qP '(?i)\bMsgBox\s*,'; then
    v1_patterns=$((v1_patterns + 1))
    v1_found="${v1_found}MsgBox, "
fi

if echo "$user_prompt" | grep -qP '(?i)\bSetTimer\s*,'; then
    v1_patterns=$((v1_patterns + 1))
    v1_found="${v1_found}SetTimer, "
fi

# Require assignment context (:= new Foo() / = new Foo()) so prose like
# "a new function()" doesn't trip the detector.
if echo "$user_prompt" | grep -qP '(?i)(:?=)\s*new\s+\w+\('; then
    v1_patterns=$((v1_patterns + 1))
    v1_found="${v1_found}new "
fi

if echo "$user_prompt" | grep -qP '(?i)\bComObjCreate\b'; then
    v1_patterns=$((v1_patterns + 1))
    v1_found="${v1_found}ComObjCreate "
fi

if [[ $v1_patterns -ge 2 ]]; then
    echo -e "\x1b[1;91m┌─ HOOK ▸ detect-v1-syntax ───────────────────────────────\x1b[0m" >&2
    echo -e "\x1b[1;91m│\x1b[0m v1 patterns found: \x1b[1;33m${v1_found}\x1b[0m" >&2
    echo -e "\x1b[1;91m│\x1b[0m This project is \x1b[1mAHK v2 ONLY\x1b[0m — use /ahk-fix to convert" >&2
    echo -e "\x1b[1;91m└─────────────────────────────────────────────────────────\x1b[0m" >&2
fi

exit 0
