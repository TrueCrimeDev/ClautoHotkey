---
paths:
  - "main.ahk"
---

# Main Script Rules

Conventions for a project with one always-running entry script (set as
`MAIN_SCRIPT` in `harness.env`). Change the `paths:` glob above to match your
entry file(s).

- The entry script is the always-running process; it `#Include`s the other modules.
- After editing the entry script or any file it includes, restart the entry script.
- Hotkeys and hotstrings live in the entry script. Libraries do NOT define hotkeys.
- `#SingleInstance Force` governs the whole script stack — be cautious changing it.
