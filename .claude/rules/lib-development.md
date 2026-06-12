---
paths:
  - "Lib/**/*.ahk"
---

# Library Development Rules

- Shared library. Changes affect every script that `#Include`s it.
- Do NOT add `#SingleInstance` or hotkeys. Libraries must be side-effect-free.
- Export only classes and functions. No auto-execute section.
- `_Dark.ahk` is the canonical dark-mode library in this tree.
- After editing, restart the parent script that includes this file, not the library itself.
