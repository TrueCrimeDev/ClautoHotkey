---
name: void-fat-arrow-callback
cue: a fat-arrow callback whose body is a call that returns nothing, such as a tray or timer lambda `(*) => this.Toggle()`, on the +Console fork
component: rules/ahk-v2-syntax.md
confidence: high
status: adopted
signature: No value was returned
recorded: 2026-10-18
verified: 2026-10-18 on 2.1-alpha.35+Console
---

## Lesson

The fat-arrow rule in `rules/ahk-v2-syntax.md` must say that the single expression has to yield a value. On the fork a fat arrow whose body is a void call returns unset; calling it as a bare statement is fine, but any caller that reads the result, an assignment, an expression, a menu or `OnEvent` callback, throws `UnsetError: No value was returned` at that moment, not at load, so `check` passes and the failure surfaces when the item is clicked. The fix is a named method bound with `.Bind(this)`; the rule already prefers that form for handlers, it just did not say why a one-line lambda is unsafe.

## Evidence

- Error log, 8 rows with the headline `No value was returned` raised in the script itself (another 16 came from the dry-run shim, see `shim-void-dllcall`), between 2026-06 and 2026-10-18, in `picker_probe.ahk`, `DarkModeModular_Showcase.ahk`, `DarkMode_Lib.ahk` and `KeyPressOSD_v2.ahk`.
- 2026-10-18, the Nock port: every tray lambda of the form `(*) => this.ToggleNotch()` threw on click; rewriting them as methods, or appending `, 0` to the expression, removed every occurrence.
- Probe on 2.1-alpha.35+Console, 2026-10-18: with `f := (*) => Sleep(1)`, the statement `f()` runs, but `x := f()` and `f() . ""` both throw `UnsetError: No value was returned`; `(*) => (Sleep(1), 0)` never throws. A `SetTimer` callback of that shape ran without error, so timers do not read the result; menu callbacks do, which is what the Nock port hit.

## Edits

| component | change | observed | verdict |
|---|---|---|---|
| rules/ahk-v2-syntax.md | one line under the fat-arrow bullet naming the error and the method-plus-Bind fix | no rollout yet | untested |
