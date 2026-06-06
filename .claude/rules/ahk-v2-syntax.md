---
paths:
  - "**/*.ahk"
---

# AHK v2 Syntax Rules

- `:=` for all assignment. Never bare `=`.
- `ClassName()` to instantiate. Never `new ClassName`.
- `Map()` for key-value data. Never object literals `{}` for data storage.
- Assign Map entries individually: `m["key"] := "val"`. Never pass pairs to constructor.
- Arrays are 1-indexed. Never index at 0.
- Fat arrow `=>` for single expressions only. Never `=> { }` with braces.
- Event handlers: extract to method + `.Bind(this)`. Never inline multi-line callbacks.
- Semicolons for comments. Never `//` C-style comments.
- Backtick for escapes inside strings. Never backslash.
- `ComObject()` not `ComObjCreate()`.
- `&var` for ByRef.
- Map has no `.Keys()` method -- iterate with `for key in mapObj`.
- Never empty `catch` blocks. Every `catch` must handle or re-throw.
- Declare variables explicitly and early within scope.
- Verify a method/property exists on the class before calling it. AHK v2 has its own API -- never assume methods from other languages exist.

## Version baseline

- The interpreter is the one set in `harness.env` (`AHK_BIN_WIN`). Set `AHK_DIAG_JSON=1` if it is the **v2.1-alpha.30+Console fork** (`A_AhkVersion` reports `2.1-alpha.30+Console`); the typed-property and Eval/Print notes below are fork features.
- New scripts should declare `#Requires AutoHotkey v2.1-alpha.30` unless they specifically depend on an older alpha. Match the user's existing `#Requires` line when modifying a file in place.
- Alpha.30 typed-property and call-syntax rules are mandatory in new code:
  - Maybe-call/index: `(a?)()` and `(a?)[]` — never `a?.()` / `a?.[]`.
  - Typed properties: class refs only — `Int8` / `Int16` / `Int32` / `Int64` / `UInt8` / `UInt16` / `UInt32` / `Float32` / `Float64` / `IntPtr`. No `i32` / `u32` / `uptr` strings, no typeless `buf: 32`. No `UInt64` class — use `Int64` and handle the sign yourself.
  - `DllCall` / `ComCall` / `CallbackCreate` accept `"Void"` return when the result is uninteresting (yields blank-unset instead of fabricating a numeric return).
  - Parenthesise `!a ?? b` and `b + a ?? c` — bare forms are rejected at load time.

## Fork-only built-ins (always available)

- `Print(Fmt, Values*)` — variadic stdout println. `Print("x = {}", x)` replaces the old `Print(Format(...))` idiom; with 2+ args it dispatches to `Format` internally. A single-arg call with literal `{...}` is preserved verbatim. Use instead of the old `FileOpen("*", "w", "UTF-8")` boilerplate. No-op when no console is attached.
- `SyntaxError` — exception class extending `Error`. Catch it separately from `UnsetError`/`ValueError` when handling expression-parsing code.

## Fork-only built-ins (gated)

- `Eval(expr)` — runtime expression evaluator. Enable with `#EnableEval` at top of script (or `/Eval` on the CLI). Evaluates one expression at a time against the caller's live scope, including assignments. Throws `SyntaxError` on bad input, `UnsetError` on missing identifiers.

Full fork reference: `.claude/rules/ahk-fork-features.md`.
