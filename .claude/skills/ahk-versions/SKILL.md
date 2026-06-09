---
name: ahk-versions
description: >
  AHK v2 version & portability guidance — what runs on stock v2.0 vs v2.1-alpha vs the
  +Console fork, and how to write code that works on the build the user actually has.
  Use when choosing a #Requires floor, checking whether Print / Eval / typed Struct /
  (a?)() are available, detecting the interpreter at runtime, or making a script portable.
  TRIGGER when: user says "which version", "will this run on", "portable", "works on stock
  AHK", "is Print/Eval available", "what does the fork add", "#Requires version",
  "target v2.0", "detect the build", "A_AhkVersion".
  Examples: "will this run without my fork", "make this portable", "is typed Struct in v2.0"
---

# AHK v2 Versions & Portability

Decide what the user's build supports, then write code that runs on it.

## How to use

1. Establish the target build(s): only this repo's +Console fork? Also stock v2.0? Upstream v2.1-alpha?
2. Load the full reference — capability matrix + a portable fallback for every gated feature —
   from `Modules/Module_Versions.md`. It maps each feature to the builds that support it.
3. Apply the decision rule: **declare the floor, gate the extras.**
   - Reaches stock users → `#Requires AutoHotkey v2.0`, portable output, feature-gate alpha/fork constructs.
   - Fork-only → `#Requires AutoHotkey v2.1-alpha.30`, use `Print` / `Eval` / typed `Struct` freely.
4. For runtime branching, detect the build from `A_AhkVersion`:
   `InStr(A_AhkVersion, "Console")` → fork; `InStr(A_AhkVersion, "alpha")` → v2.1-alpha.

## Quick answers

- **Is `Print` / `Eval` available?** Fork only. Portable substitute: `FileAppend(text "`n", "*")` / `OutputDebug`.
- **Is typed `Struct` / `(a?)()` available?** v2.1-alpha+. v2.0 fallback: `Buffer` + `NumPut`/`NumGet`; `a ? a() : unset`.
- **What does the fork add over upstream alpha?** `Print`, `Eval`, JSON diagnostics, `/CrashLog`, exit code 130, `SyntaxError`.

For the full matrix, all fallbacks, and the silent alpha behavior shifts (void→`unset`,
read-only class base, `GuiCtrlFromHwnd` no-value), read `Modules/Module_Versions.md`.
