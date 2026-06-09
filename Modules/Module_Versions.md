# Module_Versions.md
<!-- DOMAIN: Versions, portability, and the +Console fork -->
<!-- SCOPE: Which features exist on stock v2.0, on upstream v2.1-alpha, and on the +Console fork — and the portable fallback for every fork-only or alpha-only feature. General syntax/OOP belongs in the other modules; this one answers "will this run on the build my user has?" -->
<!-- TRIGGERS: #Requires, A_AhkVersion, VerCompare, version, "which version", v2.0, v2.1, alpha, fork, "+Console", Print, Eval, "#EnableEval", portable, portability, fallback, "works everywhere", "stock v2", diagnostics, "Diag=json", SyntaxError, typed Struct, "maybe operator", "(a?)()" -->
<!-- CONSTRAINTS: A script only loads on a build that supports every construct it uses. Pick the lowest build that runs your code and declare it with #Requires — bump it only when you actually use an alpha- or fork-only feature. Print/Eval and JSON diagnostics are +Console fork extras; never call them in code meant to run on stock AHK without a guard or a fallback. typed Struct, (a?)(), block-body fat arrows, and the maybe operator are v2.1-alpha features absent from v2.0. Detect the build at runtime from A_AhkVersion, never assume the extras exist. -->
<!-- CROSS-REF: Module_DllCall.md, Module_Errors.md, Module_Instructions.md, Module_GUI.md -->
<!-- VERSION: spans AHK v2.0 → v2.1-alpha.30 +Console -->

## CAPABILITY MATRIX

What runs where. "alpha" = upstream `v2.1-alpha` from autohotkey.com; "fork" = the
`v2.1-alpha.30 +Console` build this repo recommends (upstream alpha **plus** the extras).

| Feature | v2.0 (stable) | v2.1-alpha | +Console fork |
|---------|:---:|:---:|:---:|
| `??` null-coalescing, `?:` ternary | ✓ | ✓ | ✓ |
| Maybe operator `var?` (suppress unset) | ✗ | ✓ | ✓ |
| Maybe-call / index `(a?)()` `(a?)[]` | ✗ | ✓ | ✓ |
| Block-body fat arrow `=> { ... }` | ✗ | ✓ | ✓ |
| Typed properties / `Struct` (class-ref fields) | ✗ | ✓ | ✓ |
| `"Void"` return for DllCall/ComCall | ✗ | ✓ | ✓ |
| Void call yields `unset` (not a fake number) | ✗ | ✓ | ✓ |
| `Print(fmt, vals*)` stdout println | ✗ | ✗ | ✓ |
| `Eval(expr)` runtime evaluator | ✗ | ✗ | ✓ |
| `SyntaxError` exception class | ✗ | ✗ | ✓ |
| JSON diagnostics `check /Diag=json` | ✗ | ✗ | ✓ |
| `/CrashLog`, `/StdErrFile`, exit code `130` | ✗ | ✗ | ✓ |

The bottom block (Print/Eval/diagnostics/CLI) is what makes the fork AI-friendly. Everything
above it is upstream and reaches anyone on the matching build.

## API QUICK-REFERENCE

| Symbol | Where | Notes |
|--------|-------|-------|
| `A_AhkVersion` | all | Version string; the fork reports `"2.1-alpha.30+Console"` |
| `VerCompare(a, b)` | all | `-1/0/1`; understands pre-release tags (`"2.1-alpha.30"`) |
| `#Requires AutoHotkey v2.0` | all | Load-time floor; refuses to run on an older/mismatched build |
| `FileAppend(Text, "*")` | all | **Portable stdout** (`"**"` = stderr); the v2.0-safe `Print` substitute |
| `OutputDebug(Text)` | all | Portable debug sink (DebugView / attached debugger) |
| `Print(Fmt, Vals*)` | fork | Variadic stdout println — `Print("x = {}", x)`; no `Format()` wrapper needed |
| `Eval(Expr)` | fork | Runtime expression evaluator; gated by `#EnableEval` or `/Eval` |

## AHK V2 CONSTRAINTS

- Pick the **floor build** — the lowest one your code runs on — and declare it. Use
  `#Requires AutoHotkey v2.0` for maximum reach; bump to `v2.1-alpha.30` only when the
  script actually uses a v2.1 construct (typed `Struct`, `(a?)()`, block-body arrows).
- `#Requires` is a hard gate: requiring `v2.0` and then writing `(a?)()` fails to load on
  the very build you required. Match the directive to the syntax you use.
- `Print`/`Eval` are fork-only. In code that may run on stock AHK, either guard them behind
  a runtime fork check or use the portable fallback (`FileAppend(..., "*")`).
- Detect the build at runtime, do not assume it:
  `isFork := InStr(A_AhkVersion, "Console") > 0`, `isAlpha := InStr(A_AhkVersion, "alpha") > 0`.
- The fork's CLI/diagnostic features (`/Diag=json`, `/CrashLog`, exit `130`) are invoked by
  the harness around your script — they don't change what the script source may contain.
- `FileAppend(text, "*")` needs a real stdout (the script launched with output redirected or
  from a console). The fork is console-enabled so `Print` always has somewhere to go.

✗ / ✓ pairs:

- ✗ `Print("done")` in a script you hand to a stock-v2.0 user — `Print` is undefined there
- ✓ `FileAppend("done`n", "*")` — writes to stdout on any v2 build

- ✗ `#Requires AutoHotkey v2.0` then using `Struct` or `(a?)()` — load error on that build
- ✓ bump to `#Requires AutoHotkey v2.1-alpha.30` when you use an alpha-only construct

- ✗ assuming a maybe-call works everywhere: `result := (cb?)()`
- ✓ guard it for v2.0: `result := cb ? cb() : unset`

## TIER 1 — Know your build
> COVERED: A_AhkVersion · VerCompare · #Requires · runtime detection

```ahk
; ✓ Load-time floor: refuses to run on anything older than declared
#Requires AutoHotkey v2.0

; ✓ Runtime feature detection — branch on what the interpreter actually is
isAlpha := InStr(A_AhkVersion, "alpha") > 0          ; v2.1-alpha syntax available
isFork  := InStr(A_AhkVersion, "Console") > 0        ; Print/Eval/diagnostics available

; ✓ Finer comparison when a specific alpha matters
if VerCompare(A_AhkVersion, "2.1-alpha.30") >= 0
    ; typed Struct, (a?)(), Void return are all present
```

## TIER 2 — Portable output and debugging
> COVERED: FileAppend("*") · OutputDebug · the portable Print substitute

These work on every v2 build, fork or not. Reach for them in code you distribute.

```ahk
; ✓ Portable stdout — the v2.0-safe equivalent of the fork's Print
FileAppend("Result: " value "`n", "*")               ; "**" targets stderr instead

; ✓ Portable debug channel (DebugView or an attached debugger)
OutputDebug("state=" this.state["mode"])
```

## TIER 3 — The +Console fork extras
> COVERED: Print · Eval (#EnableEval) · when to use them · guarded usage

On the fork, prefer `Print`/`Eval` in tests and demos — that's their reason to exist. Keep
them out of code that must also run on stock AHK, or guard them.

```ahk
; ✓ Fork-native: variadic, no Format() wrapper, goes straight to stdout
Print("x = {}, y = {}", x, y)

; ✓ Fork-native REPL-style evaluation (needs the directive or the /Eval flag)
#EnableEval
total := Eval("[1,2,3].Map(n => n*n).Reduce((a,b) => a+b, 0)")   ; 14

; ✓ Guarded so the same source still loads (and degrades) on stock AHK
Out(fmt, vals*) {
    if InStr(A_AhkVersion, "Console")
        Print(fmt, vals*)
    else
        FileAppend(Format(fmt, vals*) "`n", "*")
}
```

## TIER 4 — v2.1-alpha syntax and semantics (fork or upstream alpha)
> COVERED: (a?)() · typed Struct · "Void" return · void→unset · alpha behavior shifts

These reach anyone on v2.1-alpha — fork or upstream. They do **not** exist on v2.0, so gate
the file with `#Requires AutoHotkey v2.1-alpha.30` (or higher) when you use them.

```ahk
; ✓ Maybe-call (alpha): runs the call only if the callable is set — replaces a?.()
(this.onChange?)(newValue)

; ✓ Typed Struct with class-ref fields (alpha) — see Module_DllCall.md for Buffer fallback
Struct POINT {
    x: Int32
    y: Int32
}

; ✓ "Void" return: the call runs but yields blank-unset instead of a fabricated number
DllCall("Sleep", "UInt", 100, "Void")
```

Behavior shifts to know on alpha (they bite silently — not load errors):

- A void method/function call returns `unset`, not `0`. A fat-arrow body that is just a void
  call, or a comma-tail ending in one, now yields `unset` — wrap as `(call(), 0)` if you need
  a value.
- A class object's `base` is read-only (alpha.27+): `ClassObj.base := X` and
  `ObjSetBase(ClassObj, X)` both throw.
- `GuiCtrlFromHwnd`/`GuiFromHwnd` return **no value** (not `""`) on no match — assigning the
  result throws; use `?? 0` or `IsSet`.

v2.0 fallbacks: replace `(a?)()` with `a ? a() : unset`; replace typed `Struct` with `Buffer`
+ `NumPut`/`NumGet` (Module_DllCall.md); drop the `"Void"` return type and ignore the result.

## TIER 5 — Shipping build-portable code
> COVERED: choosing the floor · feature-gating · the decision rule

```ahk
; ✓ A helper that uses the fork's speed when present, stays correct everywhere
class Logger {
    static Write(line) {
        if InStr(A_AhkVersion, "Console")
            Print("{}", line)
        else
            FileAppend(line "`n", "*")
    }
}
```

Decision rule: **declare the floor, gate the extras.** If the code must reach stock-v2 users,
floor at `v2.0`, write portable output, and feature-gate anything alpha/fork. If it targets
only this repo's fork, floor at `v2.1-alpha.30` and use `Print`/`Eval`/typed `Struct` freely.

## SEE ALSO

> This module does NOT cover: the `Buffer`/`NumPut` fallback for typed `Struct` → see Module_DllCall.md
> This module does NOT cover: general error handling and exception classes → see Module_Errors.md

- `Module_DllCall.md` — `Buffer` + `NumGet`/`NumPut` is the v2.0-portable substitute for typed `Struct`.
- `Module_Errors.md` — `SyntaxError` (fork) and the standard exception hierarchy; `try/catch` for guarded feature use.
- `Module_Instructions.md` — the repo's default interpreter and the `#Requires` header convention.
