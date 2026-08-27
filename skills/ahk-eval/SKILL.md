---
name: ahk-eval
description: >
  Live AHK v2 REPL backed by the fork's native repl subcommand. Execute AHK expressions and
  get immediate results without writing a multi-line script. Use when testing snippets,
  checking syntax, or evaluating expressions without creating files.
  TRIGGER when: user says "eval", "try this expression", "what does X return",
  "test this snippet", "run this AHK code", "check if this works".
  Examples: "/ahk-eval StrSplit('a,b,c', ',').Length" returns "3"
---

# AHK v2 Live REPL

Evaluate AHK v2 expressions and return results. The fork binary ships a `repl` subcommand — a persistent read-eval-print session over stdin/stdout. Prefer it over generating harness scripts: no temp file, no `#EnableEval` boilerplate (the gate is implied), and one process evaluates any number of expressions with state carried between lines.

## How to use

The user supplies one or more AHK expressions (or, less commonly, a multi-line block). You:

1. Decide expressions (Mode A) vs. multi-statement block (Mode B).
2. Mode A: pipe the lines into `repl /Diag=json` — one JSON result line per input line, in order.
3. Mode B: write a temp script and run it normally.
4. Report results; on `ok:false`, pass the error type and message through verbatim.

## Mode A — expressions via `repl` (preferred)

One expression per line. Comma compounds work (`x := 1, y := 2`). Lines evaluate in global scope and **state persists between lines**, so a sequence like `x := 10` then `x * 4` works. Errors never end the session — every line gets its result line.

```bash
# Single expression — no temp file, no harness
printf '%s\n' 'StrSplit("a,b,c", ",").Length' \
    | timeout 5 "$AHK_EXE" repl /Diag=json
```

```bash
# Stateful sequence — heredoc, one result line per input line
timeout 5 "$AHK_EXE" repl /Diag=json <<'EOF'
x := 10
x * 4
EOF
```

Wire format (`/Diag=json` — exactly one stdout line per input line, never desynchronizes):

```json
{"kind":"result","ok":true,"type":"Integer","value":"42"}
{"kind":"result","ok":false,"type":"SyntaxError","value":"Missing operand."}
{"kind":"result","ok":true,"type":"Unset","value":""}
```

Without `/Diag=json` (text mode): values print to stdout, void/unset prints nothing, objects print as `<ClassName object>`, errors print one `Type: Message` line to stderr. Prefer JSON — the 1:1 line mapping is what lets you attribute results when piping several expressions.

EOF (pipe end) or `.exit` exits `0`; `ExitApp(n)` typed into the session exits `n`; `timeout` kill exits `124`.

## Mode A+ — session against a loaded script

`repl <script.ahk>` loads the script, runs its auto-execute section, then opens the session against its live state — globals, functions, classes, hotkeys, and timers all reachable:

```bash
timeout 10 "$AHK_EXE" repl /ErrorStdOut /Diag=json "$(wslpath -w "$SCRIPT")" <<'EOF'
MyGlobalConfig["mode"]
MyClass.Instance.Count
EOF
```

`/ErrorStdOut` matters here: a load-time parse error in the script happens before the REPL takes over error routing.

## Mode B — multi-statement block

When the user provides a block the REPL can't take line-by-line (function definitions, loops with bodies, classes), inline it into a temp script:

```ahk
#Requires AutoHotkey v2.1-alpha.30
<USER_CODE>
```

Encourage `Print(...)` calls in the block — there's no implicit result to surface.

```bash
TEMP_FILE="$CLAUDE_JOB_DIR/ahk_eval_$$.ahk"
WIN_PATH=$(wslpath -w "$TEMP_FILE")

timeout 5 "$AHK_EXE" /Headless /ErrorStdOut "$WIN_PATH" \
    1>"$CLAUDE_JOB_DIR/ahk_eval_out.txt" \
    2>"$CLAUDE_JOB_DIR/ahk_eval_err.txt"
exit_code=$?

stdout=$(cat "$CLAUDE_JOB_DIR/ahk_eval_out.txt" 2>/dev/null)
stderr=$(cat "$CLAUDE_JOB_DIR/ahk_eval_err.txt" 2>/dev/null)

rm -f "$TEMP_FILE" "$CLAUDE_JOB_DIR/ahk_eval_out.txt" "$CLAUDE_JOB_DIR/ahk_eval_err.txt"
```

## Examples (Mode A)

| Input                                                     | Result line `value` |
|---                                                        |---      |
| `StrSplit("a,b,c", ",").Length`                           | `3`     |
| `SubStr("hello world", 7)`                                | `world` |
| `RegExMatch("abc123", "\d+", &m) ? m[0] : "none"`         | `123`   |
| `Format("{:04d}", 42)`                                    | `0042`  |
| `Round(3.14159, 2)`                                       | `3.14`  |
| `[10, 20, 30][2]`                                         | `20`    |

## Error reporting

`ok:false` lines carry the error class in `type` and the message in `value`. Pass both through verbatim, then add a one-line interpretation if the fix is obvious. Because the session survives errors, a batch of lines always yields a full set of results — report all of them, not just the first failure.

## Known limitations

- The REPL takes single-line expressions only — function/class definitions and brace blocks need Mode B.
- Object results print as `<ClassName object>`, not contents — chain an accessor or `JSON.Stringify`-style expression if the user wants contents.
- JSON `value` is capped at ~4K characters per line.
- The IIFE + maybe-operator + `||` combo (e.g. `(() => x? || 42)()`) crashes the Eval preparse — fall back to Mode B.
- A whitespace-preceded `;` inside a string literal is eaten as a comment, same as in scripts — escape it (`` `; ``) or keep it flush against a non-space character.

## Rules

- `repl` must be the **first** argument; flags and the optional script follow.
- Always use `/Diag=json` in Mode A so results map 1:1 to input lines.
- Quote each AHK line with bash single quotes and use `"` inside the expression; for lines containing `'`, use a quoted heredoc (`<<'EOF'`) instead.
- Default timeout: 5 seconds (10 when loading a script). Bump only if the user asks.
- Mode B temp files go under `$CLAUDE_JOB_DIR` (never `/tmp`) and are cleaned up in every code path.
