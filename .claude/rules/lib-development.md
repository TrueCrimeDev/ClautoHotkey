---
paths:
  - "Lib/**/*.ahk"
---

# Library Development Rules

- Shared library. Changes affect every script that `#Include`s it.
- Do NOT add `#SingleInstance` or hotkeys. Libraries must be side-effect-free.
- Export only classes and functions. No auto-execute section.
- `DarkModeModular.ahk` is the canonical dark mode. `_Dark.ahk`, `DarkMode.ahk`, `Dark.ahk` are older -- do not extend them.
- After editing, restart the parent script that includes this file, not the library itself.
