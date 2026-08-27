---
paths:
  - "!Tests/**/*.ahk"
---

# Test Script Rules

- Throwaway test/experiment scripts. No production quality needed.
- Each `Test*.ahk` is standalone. No shared state between test files.
- Use `FileAppend` to stdout (`"*"`) for output, not `MsgBox`.
- `#Requires AutoHotkey v2.1-alpha` at top (matches project engine).
