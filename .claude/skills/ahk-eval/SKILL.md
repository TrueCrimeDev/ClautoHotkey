---
name: ahk-eval
description: >
  Live AHK v2 REPL backed by the fork's native Eval() BIF. Execute AHK expressions and
  get immediate results without writing a multi-line script. Use when testing snippets,
  checking syntax, or evaluating expressions without creating files.
  TRIGGER when: user says "eval", "try this expression", "what does X return",
  "test this snippet", "run this AHK code", "check if this works".
  Examples: "/ahk-eval StrSplit('a,b,c', ',').Length" returns "3"
---

# AHK v2 Live REPL

Evaluate a single AHK v2 expression and return its result. The fork binary ships a native `Eval()` BIF — prefer it over the old "spin a script, capture stdout" dance.

## How to use

The user supplies one AHK expression (or, less commonly, a short multi-line block). You:

1. Decide single-expression vs. multi-statement.
2. Build the minimal harness script for the chosen mode.
3. Run it with the canonical interpreter.
4. Capture stdout / stderr / exit code and return them.

## Mode A — single expression (preferred)

Wrap with `Print(Eval(...))` and the `#EnableEval` directive. One round-trip; no temp boilerplate beyond the directive.

```ahk
#Requires AutoHotkey v2.1-alpha.30
#EnableEval
try
    Print("{}", String(Eval("<USER_EXPRESSION>") ?? "<unset>"))
catch SyntaxError as e
    Print("SyntaxError: {}", e.Message)
catch UnsetError as e
    Print("UnsetError: {}", e.Message)
catch as e
    Print("{}: {}", e.__Class, e.Message)
```

Substitute `<USER_EXPRESSION>` literally. Eval reads/writes locals in its caller, but for one-shot REPL evaluation there are no caller locals to worry about.

## Mode B — multi-statement block

When the user provides multiple statements (e.g. a loop with side effects), `Eval` cannot accept the whole thing. Fall back to inlining the block directly:

```ahk
#Requires AutoHotkey v2.1-alpha.30
<USER_CODE>
```

Encourage the user to add `Print(...)` calls themselves — there's no implicit result to surface.

## Execution

```bash
TEMP_FILE="$CLAUDE_JOB_DIR/ahk_eval_$$.ahk"
WIN_PATH=$(wslpath -w "$TEMP_FILE")

# 5s timeout. /CrashLog gives us a structured fallback if Eval crashes the interpreter.
timeout 5 "$AHK_EXE" \
    /Headless /ErrorStdOut \
    "$WIN_PATH" \
    1>"$CLAUDE_JOB_DIR/ahk_eval_out.txt" \
    2>"$CLAUDE_JOB_DIR/ahk_eval_err.txt"
exit_code=$?

stdout=$(cat "$CLAUDE_JOB_DIR/ahk_eval_out.txt" 2>/dev/null)
stderr=$(cat "$CLAUDE_JOB_DIR/ahk_eval_err.txt" 2>/dev/null)

rm -f "$TEMP_FILE" "$CLAUDE_JOB_DIR/ahk_eval_out.txt" "$CLAUDE_JOB_DIR/ahk_eval_err.txt"
```

## Examples (Mode A)

| Input                                                     | Output  |
|---                                                        |---      |
| `StrSplit("a,b,c", ",").Length`                           | `3`     |
| `SubStr("hello world", 7)`                                | `world` |
| `RegExMatch("abc123", "\d+", &m) ? m[0] : "none"`         | `123`   |
| `Format("{:04d}", 42)`                                    | `0042`  |
| `Map("a",1,"b",2).Count`                                  | `2`     |
| `[1,2,3].Map(n => n*n).Reduce((a,b) => a+b, 0)`           | `14`    |

## Error reporting

The harness already classifies parse vs. unset vs. other errors. Pass the line through verbatim, then add your own one-line interpretation if the fix is obvious (e.g. missing `#EnableEval` produces `Error: Eval is disabled ...` — instruct the user, or rerun with `/Eval`).

## Known v1 limitation

The combo IIFE + maybe operator + `||` inside `Eval` crashes the runtime preparse path. If the user supplies something like `(() => x? || 42)()` to `/ahk-eval`, fall back to Mode B.

## Rules

- Always include `#EnableEval` in the Mode A harness — never assume the CLI flag.
- Always use `/Headless` and `/ErrorStdOut` so dialogs don't appear and runtime errors land on stderr.
- Default timeout: 5 seconds. Bump only if the user asks.
- Write temp files under `$CLAUDE_JOB_DIR` (never `/tmp` — parallel jobs collide).
- Clean up temp files in every code path.
