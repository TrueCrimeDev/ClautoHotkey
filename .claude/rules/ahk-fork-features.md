---
paths:
  - "**/*.ahk"
---

# AHK v2.1-alpha.30+Console — Fork Features Reference

> **Applies only when `AHK_DIAG_JSON=1`** (you're running the +Console fork set in
> `harness.env`). On stock AutoHotkey v2 these features — `Print`, `Eval`,
> `/Diag=json`, `/CrashLog`, structured exit codes — are unavailable; ignore this file.

The interpreter set in `harness.env` (`AHK_BIN_WIN`), when it is the +Console fork,
tracks upstream through the 2026-05-22 alpha.30 merge (commit `34b17011`) with extra
runtime, diagnostic, and CLI features. `A_AhkVersion` reports `2.1-alpha.30+Console`.
All upstream alpha.30 features still work; the additions below are fork-only.

## Features at a glance

| Feature                              | Surface                   | Default |
|---                                   |---                        |---      |
| Runtime expression evaluator         | `Eval(expr)` BIF          | Gated   |
| Eval gate (CLI)                      | `/Eval` flag              | n/a     |
| Eval gate (script)                   | `#EnableEval` directive   | n/a     |
| Stdout println helper (variadic)     | `Print(Fmt, Values*)` BIF | On      |
| Parse-failure error class            | `SyntaxError`             | On      |
| Structured crash log (CLI)           | `/CrashLog=<path>`        | Gated   |
| Structured crash log (script)        | `#CrashLog <path>`        | Gated   |
| Stderr file tee                      | `/StdErrFile=<path>`      | Gated   |
| Ctrl+C / signal exit code            | `code=130`                | On      |

Always-on additions (`Print`, `SyntaxError`, signal exit code) are safe to use unconditionally. Everything else is opt-in via a flag or directive.

## `Eval(expr)` — runtime expression evaluator

Evaluates an AHK expression string against the caller's live scope. Reads and writes caller locals; respects alpha.30 semantics (maybe operator, unset propagation, parenthesised maybe-call `(a?)()`).

```ahk
#Requires AutoHotkey v2.1-alpha.30
#EnableEval

x := 10
Eval("x := x + 1")
Print("{}", Eval("x * 2"))              ; -> 22
Print("{}", Eval("[1,2,3].Map(n => n*n).Reduce((a,b) => a+b, 0)"))  ; -> 14
```

- Gate it with either `#EnableEval` (preferred — self-documenting) or `/Eval` on the CLI. Both are equivalent and idempotent.
- Single-expression only — no multi-statement bodies. Assignments (`:=`, `+=`, ...) are valid expressions and do work.
- Cannot create new locals — protects against accidental scope pollution.
- Reentrant — `Eval` inside `Eval` is fine.
- Errors: parse failures throw `SyntaxError`; missing identifiers throw `UnsetError`; the gate-closed message is `"Eval is disabled (add #EnableEval to your script or pass /Eval)"`.
- Known v1 limitation: avoid IIFEs that combine the maybe operator with `||` inside `Eval` — that specific combo currently crashes through the runtime-preparse path.

## `Print(Fmt, Values*)` — variadic stdout println BIF

Writes the formatted text plus `\n` to stdout, UTF-8. No setup, no global FileOpen handle, no gate. As of alpha.30 the BIF is variadic: with 2+ args it dispatches to `Format(Fmt, Values*)` internally.

```ahk
Print("hello")                                 ; "hello\n"
Print()                                        ; "\n"
Print("x = {}", 42)                            ; "x = 42\n"
Print("0x{:08X} = {1}", 0xDEAD)                ; "0x0000DEAD = 57005\n"
Print("{1}/{2}/{1}", "a", "b")                 ; "a/b/a\n"
Print("{ok: true, n: 42}")                     ; literal braces preserved (1-arg form)
```

A single-arg call with literal `{...}` is preserved as-is (no Format pass), so JSON-like text still prints verbatim. Replaces the old `Print(Format(...))` idiom — never reintroduce `FileOpen("*", "w", "UTF-8")`.

If no console is attached, the call is a no-op (no crash). Prefer `Print` in tests, demos, and headless scripts.

## `SyntaxError` — new exception class

Extends `Error`. Thrown by `Eval()` on parse failure; scripts may also throw it for their own parse-related errors.

```ahk
try
    Eval("1 + ")
catch SyntaxError as e
    Print("parse failed: {}", e.Message)
```

Instances thrown by `Eval` carry `File="Eval"`, `Line=0`, `Column=0` (column is a best-effort placeholder for v1).

## `/CrashLog=<path>` and `#CrashLog <path>`

Append-only, UTF-8 structured log of every notable event in a script's life: `[START]`, `[PARSE]`, `[ERROR]`, `[FATAL]`, `[EXIT]`. Independent of `/ErrorStdOut`. Writes via open-write-flush-close so the previous record is on disk even if the next event crashes the interpreter.

```bat
bin\AutoHotkey64.exe /CrashLog=C:\logs\ahk.log script.ahk
```

```ahk
#Requires AutoHotkey v2.1-alpha.30
#CrashLog C:\logs\ahk.log
```

- The parent directory must exist; the file is created/appended on first write.
- `[ERROR]` is only written when the exception escapes all `OnError` handlers (handlers that return 1 silence the log entry — by design).
- `[FATAL]` is best-effort: `LastFile`/`LastLine`/`LastHotkey` are placeholder empty strings in v1; the exception code + address are accurate.
- Other Windows components (VC runtime, WER, attached debuggers) can preempt our SEH filter — `[FATAL]` may not fire if they do.

## `/StdErrFile=<path>` — stderr tee

Duplicates every byte the script writes to stderr into the file at `<path>`. Composes with `/ErrorStdOut`. No script-side directive (stderr redirection is a launcher concern).

```bat
bin\AutoHotkey64.exe /ErrorStdOut /StdErrFile=C:\logs\ahk.stderr script.ahk
```

## Exit code 130 — external signal

`SetConsoleCtrlHandler` is installed at startup. Ctrl+C, Ctrl+Break, console close, logoff, and shutdown all log `[EXIT] code=130 reason=ExternalSignal` to the crash log (if enabled), then return control to the OS for default termination. Distinguishes "user killed it" from "script exited cleanly" in launchers and CI.

## Combined exit-code taxonomy

| Code | Meaning                           | Crash-log `reason=`  |
|---   |---                                |---                   |
| 0    | Success                           | `Normal`             |
| 10   | Uncaught script-level exception   | `Error`              |
| 11   | Internal/critical OR SEH fault    | `Critical` / `Fatal` |
| 12   | Parse / load failure              | `Parse`              |
| 13   | `check` subcommand failed         | `Check`              |
| 14   | `test` subcommand failed          | `Test`               |
| 64   | CLI usage error                   | `Usage`              |
| 130  | Ctrl+C / Break / close / shutdown | `ExternalSignal`     |
| n    | `ExitApp(n)` for non-reserved n   | `ExitApp(n)`         |

## When to reach for what

- **Quick stdout from a test/demo** → `Print("msg")` or `Print("x = {}", x)`. Never reintroduce the `FileOpen("*","w","UTF-8")` idiom or the old `Print(Format(...))` wrapper.
- **Evaluate a user-supplied AHK expression in a REPL or helper** → `Eval(expr)` after `#EnableEval`. Catch `SyntaxError` separately from `UnsetError` and generic `Error`.
- **Headless script in production where you can't see stderr** → `/CrashLog=<abs path>` plus `/StdErrFile=<abs path>`. Read the log to diagnose silent exits.
- **Need to know if a script was Ctrl+C'd vs exited normally** → check exit code; 130 = signal.

## Alpha.30 upstream changes (not fork-specific)

The 2026-05-22 merge of upstream commit `34b17011` tightens the type system and call syntax.

**New:**

- `'Void'` return type for `DllCall` / `ComCall` / `CallbackCreate` — call runs but yields blank-unset instead of fabricating a numeric return.

**Breaking (migration required):**

- `a?.()` and `a?.[]` removed — use `(a?)()` and `(a?)[]`. The `?.` token now means maybe-property only.
- Property type strings (`i32`, `u32`, `f64`, `uptr`, `u8`, `u16`, ...) removed — use class refs (`Int8`, `Int16`, `Int32`, `Int64`, `UInt8`, `UInt16`, `UInt32`, `Float32`, `Float64`, `IntPtr`). **No `UInt64` class exists** — use `Int64` and handle the sign yourself.
- Typeless typed properties removed — `Struct X { buf: 32 }` (size without a class) is rejected. Reserve raw bytes via an array of typed fields or a `Buffer` companion alongside the struct.
- Unparenthesised `!a ?? b` and `b + a ?? c` rejected at load time — wrap explicitly: `!(a ?? b)`, `b + (a ?? c)`.

**Fixed:**

- `String(x)` survives a void `ToString()` (returns blank-unset cleanly instead of crashing).
- `x?.%y%` parses (was a load-time syntax error).
- `StrGet(x, 0)` returns an empty `String`, not the numeric pointer.
- Virtual ref assignments permit `unset` — callee can write `out := unset` through a `&ref` to leave the caller slot uninitialised.
- `DllCall` propagates exceptions thrown by an output-arg `__Value` getter (used to be swallowed).

## What's NOT in v1

Not yet available — don't suggest them: log rotation, JSON crash-log format, `#StdErrFile` directive, runtime-writable `A_CrashLogPath`, `Exec(stmts)` multi-statement evaluator, postfix cache for hot Eval paths, separate exit codes for `Critical` vs `Fatal`.

## Authoritative source

Full reference (with rationale, full event-record format, threading notes, build-system caveats): `Design/Coding/AutoHotkey/updates.md` in the AutoHotkey fork repo. Re-read it before relying on edge-case behaviour.
