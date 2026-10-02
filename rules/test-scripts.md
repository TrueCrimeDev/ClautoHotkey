---
paths:
  - "!Tests/**/*.ahk"
  - "**/Tests/**/*.ahk"
  - "**/*.test.ahk"
---

# Test Script Rules

- **Unit tests use TestKit.** `#Include` the harness's `Tools\harness\TestKit.ahk` (or a
  copy of `TestKit.ahk` + `HarnessCore.ahk` in the project's `Lib\`), assert with
  `TestKit.Eq/Throws/DeepEq/...`, group with `TestKit.Test(name, fn)`, and end with
  `TestKit.Summary()` as the last statement. Name the file `Tests\<Stem>.test.ahk`
  (or `Test_<Stem>.ahk` / `<Stem>_Test.ahk`) so `GatePure.ahk` finds it for `<Stem>.ahk`.
- Experiment scripts under `!Tests\` are throwaway — no production quality needed.
- Each test file is standalone. No shared state between test files.
- Output goes through `Print` (the +Console fork's stdout BIF) — TestKit does this for you.
  Not `MsgBox`, and not `FileAppend(..., "*")`.
- Keep unit tests pure: no `Send`, `Run`, file writes or clipboard. GatePure runs them under
  the dry-run shim, and the post-edit hook runs every saved file.
- `#Requires AutoHotkey v2.1-alpha.30` at top (matches project engine).
