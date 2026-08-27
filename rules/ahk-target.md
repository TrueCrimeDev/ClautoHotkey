---
paths:
  - "**/*.ahk"
---

# Target Build

The knowledge modules were written and verified against **v2.1-alpha.30 + the +Console
fork**, so their examples name alpha-only and fork-only constructs freely. Most people
running AutoHotkey do not have that build. Emit code for the build the user actually has.

## Which build is this?

`AHK_BIN_WIN` in `harness.env` names the interpreter. If there is no `harness.env`, the
harness auto-detected one — almost certainly stock AutoHotkey from autohotkey.com.
`AHK_DIAG_JSON=1` is a reliable tell that the user opted into the fork; `0` (the default)
means assume stock.

To settle it, ask the binary:

```bash
"$AHK_BIN_WSL" /ErrorStdOut /Headless <(echo 'FileAppend(A_AhkVersion "`n", "*")')
```

- contains `Console` → the +Console fork. Everything in the modules is available.
- contains `alpha` → upstream v2.1-alpha. Alpha syntax yes, fork BIFs no.
- otherwise → stock v2.0. Portable subset only.

## Default posture: write for stock

Unless the user has told you otherwise, or `harness.env` pins the fork:

- Emit `#Requires AutoHotkey v2.0` — not `v2.1-alpha.30`.
- Stay inside the v2.0 feature set. When a module's example uses something newer, port it
  down rather than copying it across.

## What is gated, and the portable substitute

| Construct | Needs | Portable form |
|---|---|---|
| `Print(fmt, vals*)` | fork | ``FileAppend(text "`n", "*")`` or `OutputDebug` |
| `Eval(expr)`, `#EnableEval` | fork | no substitute — restructure to avoid it |
| `SyntaxError` class | fork | `catch Error` |
| `check /Diag=json`, `/CrashLog`, `/StdErrFile` | fork | `/ErrorStdOut` |
| exit code `130` on signal | fork | no substitute |
| typed `Struct` / class-ref typed properties | v2.1-alpha | `Buffer` + `NumPut`/`NumGet` |
| `(a?)()` and `(a?)[]` | v2.1-alpha | `a ? a() : unset` |
| `Class(BaseObj)` as a factory | v2.1-alpha | manual prototype chain via `ObjSetBase()` |

## Alpha.30 traps that do not apply to stock

The modules document several alpha.30 behaviours that are **not** v2.0 behaviours. Do not
carry these warnings into stock-targeted code or "fix" v2.0 code against them:

- class-body initializers routing through `__Set`
- `RegExMatch` throwing on a subpattern that does not exist (v2.0 returns `""`)
- end-of-chain `.Base`, `GuiCtrlFromHwnd` and `FileRead`-on-empty returning no value
- property type strings (`u32`, `uptr`) having been removed
- a class object's base being read-only (alpha.27/.28 only; writable again on alpha.30)

## Pinning a different floor

A project that genuinely needs alpha or fork features should say so in `harness.env`, and
its scripts should pin the matching floor explicitly:

```ahk
#Requires AutoHotkey v2.1-alpha.30
```

State the requirement in the file, don't leave it implied. `Module_Versions.md` carries the
full capability matrix and a fallback for every gated construct.
