# AHK Interpreter Rule

**ALWAYS** run AutoHotkey through the interpreter configured in `harness.env`
(`AHK_BIN_WIN`). Hooks resolve it automatically — `_harness-env.sh` derives the
WSL path as `AHK_BIN_WSL`. In a manual `Bash` call, source `harness.env` first
or use the `AHK_BIN_WSL` value.

## Why one interpreter

- A script that declares a specific `#Requires AutoHotkey v2...` only loads on a
  matching build — keep every run on the same binary.
- `check-ahk-binary.sh` blocks any other `AutoHotkey*.exe` in a Bash command, so
  interpreter drift is caught before it wastes a run.

## Fork vs stock (`AHK_DIAG_JSON`)

This harness optionally targets a custom **v2.1-alpha.30+Console fork** with
richer diagnostics. Set `AHK_DIAG_JSON=1` in `harness.env` if your build is that
fork; leave `0` for stock AutoHotkey v2. The post-edit hook validates with
`check /Diag=json` on the fork and `/validate` on stock.

**Everything below is fork-only — it applies only when `AHK_DIAG_JSON=1`.**

### Fork features at a glance

| Feature                              | Surface                  | Default |
|---                                   |---                       |---      |
| Runtime expression evaluator         | `Eval(expr)` BIF         | Gated   |
| Eval gate (CLI)                      | `/Eval`                  | n/a     |
| Eval gate (script)                   | `#EnableEval`            | n/a     |
| Stdout println helper (variadic)     | `Print(Fmt, Values*)`    | On      |
| Parse-failure error class            | `SyntaxError`            | On      |
| Structured crash log (CLI)           | `/CrashLog=<path>`       | Gated   |
| Structured crash log (script)        | `#CrashLog <path>`       | Gated   |
| Stderr file tee                      | `/StdErrFile=<path>`     | Gated   |
| Ctrl+C / signal exit code            | `130`                    | On      |

`Print` accepts a format string and trailing values directly — `Print("x={}", x)`
replaces the old `Print(Format("x={}", x))` idiom. A single-arg call with literal
braces is preserved verbatim (no Format pass).

Full reference: `.claude/rules/ahk-fork-features.md`.

## Alpha.30 syntax changes (fork; mirrors upstream alpha.30)

**New:**

- `'Void'` return type for `DllCall` / `ComCall` / `CallbackCreate` — call runs but yields blank-unset instead of a fabricated numeric return.

**Breaking (migration required):**

- `a?.()` and `a?.[]` removed — use `(a?)()` and `(a?)[]`.
- Property type strings (`i32`, `u32`, `f64`, `uptr`, `u8`, `u16`, ...) removed — use class refs (`Int8`, `Int16`, `Int32`, `Int64`, `UInt8`, `UInt16`, `UInt32`, `Float32`, `Float64`, `IntPtr`). No `UInt64` class exists — use `Int64` and treat sign manually.
- Typeless typed properties removed — `Struct X { buf: 32 }` (size without a class) is rejected. Reserve raw bytes via typed fields (e.g. `Int8` array) or a `Buffer` companion.
- Unparenthesised `!a ?? b` and `b + a ?? c` rejected at load time — wrap explicitly: `!(a ?? b)`, `b + (a ?? c)`.

**Fixed:**

- `String(x)` survives a void `ToString()` (returns unset cleanly instead of crashing).
- `x?.%y%` parses (was a load-time syntax error).
- `StrGet(x, 0)` returns an empty `String`, not the numeric pointer.
- Virtual ref assignments permit `unset` — callee can write `out := unset` through a `&ref`.
- `DllCall` propagates exceptions thrown by an output-arg `__Value` getter (used to be swallowed).

## Common commands

`AHK_BIN_WSL` is the WSL interpreter path from `harness.env`.

```bash
# Validate (stock AHK)
"$AHK_BIN_WSL" /ErrorStdOut /validate "<script.ahk>"

# Validate with JSON diagnostics (fork only)
"$AHK_BIN_WSL" check /Diag=json /ErrorStdOut "<script.ahk>"

# Run with stderr capture
"$AHK_BIN_WSL" /ErrorStdOut "<script.ahk>"

# Headless run with full diagnostics (fork only)
"$AHK_BIN_WSL" /Headless /ErrorStdOut /CrashLog=<log-path> /StdErrFile=<err-path> "<script.ahk>"

# Run with the Eval() BIF enabled (fork only)
"$AHK_BIN_WSL" /Eval /ErrorStdOut "<script.ahk>"
```

## Fork-only exit codes (key ones)

| Code | Reason            | When                                            |
|---   |---                |---                                              |
| 10   | `Error`           | Uncaught script-level exception                  |
| 11   | `Critical`/`Fatal`| Internal error or SEH fault                      |
| 12   | `Parse`           | Parse / load failure                             |
| 130  | `ExternalSignal`  | Ctrl+C / Ctrl+Break / close / logoff / shutdown  |
