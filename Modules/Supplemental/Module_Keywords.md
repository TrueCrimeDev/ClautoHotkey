# AHK v2 Keywords

Compact AutoHotkey **v2-only** keyword reference. v1 keyword lists (`setbatchlines`, `gosub`, `byref`, `errorlevel`, `comobjcreate`, `#ifwinactive`, ...) must never be used — those identifiers do not exist in v2.

## Flow control

- `if` / `else`
- `loop` (plus `Loop Files`, `Loop Parse`, `Loop Read`, `Loop Reg`)
- `while`
- `for` ... `in`
- `until`
- `break` / `continue`
- `return`
- `switch` / `case` / `default`
- `try` / `catch` / `finally` / `throw`
- `goto`

## Declarations

- `class` / `extends`
- `static`
- `global` / `local`
- `get` / `set` (property accessors)

## Word operators and special tokens

- `and` / `or` / `not` (word forms of `&&` / `||` / `!`)
- `is` (type check: `x is Integer`)
- `in` (for-loop enumeration only — `if x in list` is v1-only)
- `unset` (and the `IsSet()` operator-function)
- `this` / `super` (inside classes)
- `true` / `false`

## Common directives

- `#Requires` — pin the interpreter (`#Requires AutoHotkey v2.0`, or `v2.1-alpha.30` for fork-targeted code)
- `#Include` / `#IncludeAgain`
- `#SingleInstance`
- `#HotIf` (replaces v1 `#IfWinActive` family)
- `#Warn`
- `#ErrorStdOut`
- Fork-only (+Console): `#EnableEval`, `#CrashLog`
