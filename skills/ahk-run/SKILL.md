---
name: ahk-run
description: >
  Run an AHK v2 script against the alpha.30+Console fork and capture its output.
  Executes headlessly with stdout/stderr capture and exit-code reporting.
  TRIGGER when: user says "run this", "execute", "test run", "try running",
  "launch script", "check output".
---

# AHK v2 Script Runner

Execute AHK v2 scripts with the canonical fork interpreter and capture all output.

## Usage

`/ahk-run <file>` — runs the script headlessly and returns output.

If no file specified, run the most recently edited `.ahk` file.

## Execution (standard)

```bash
WIN_PATH=$(wslpath -w "$FILE")

timeout 10 "$AHK_EXE" /Headless /ErrorStdOut "$WIN_PATH" \
    1>"$CLAUDE_JOB_DIR/ahk_run_out.txt" \
    2>"$CLAUDE_JOB_DIR/ahk_run_err.txt"

EXIT_CODE=$?
```

## Execution (diagnostic — when the script keeps exiting silently)

The fork adds two flags that survive launchers that swallow stderr (VSCode AHK extension, custom runners, scheduled tasks). Use them when a normal run produces no useful output:

```bash
CRASH_LOG="$CLAUDE_JOB_DIR/ahk_run_crash.log"
STDERR_FILE="$CLAUDE_JOB_DIR/ahk_run_stderr.txt"
CRASH_LOG_WIN=$(wslpath -w "$CRASH_LOG")
STDERR_FILE_WIN=$(wslpath -w "$STDERR_FILE")

timeout 10 "$AHK_EXE" \
    /Headless /ErrorStdOut \
    "/CrashLog=$CRASH_LOG_WIN" \
    "/StdErrFile=$STDERR_FILE_WIN" \
    "$WIN_PATH"
EXIT_CODE=$?

# CRASH_LOG holds [START]/[PARSE]/[ERROR]/[FATAL]/[EXIT] records appended for this run.
# STDERR_FILE holds the byte-exact stderr stream.
```

Surface both files in the result block when the diagnostic run is used.

## Output format

```
─ RUN RESULT ─────────────────────────────────────────────

File: script.ahk
Exit code: 0 (Normal)

─ STDOUT ─────────────────────────────────────────────────

<captured stdout>

─ STDERR ─────────────────────────────────────────────────

<captured stderr, if any>

─ CRASH LOG (if diagnostic mode) ─────────────────────────

<contents of $CRASH_LOG>
```

## Exit codes (alpha.30+Console fork)

| Code | Reason            | Meaning                                          |
|---   |---                |---                                               |
| 0    | `Normal`          | Clean exit                                       |
| 10   | `Error`           | Uncaught script-level exception                  |
| 11   | `Critical`/`Fatal`| Interpreter critical error or SEH fault          |
| 12   | `Parse`           | Parse / load failure                             |
| 13   | `Check`           | `check` subcommand verdict failed                |
| 14   | `Test`            | `test` subcommand verdict failed                 |
| 64   | `Usage`           | CLI usage error                                  |
| 124  | (timeout)         | Hit our 10-second wrapper (not the AHK process)  |
| 130  | `ExternalSignal`  | Ctrl+C / Break / close / logoff / shutdown       |
| n    | `ExitApp(n)`      | Intentional `ExitApp(n)` for non-reserved n      |

Codes 11 (`Critical` vs `Fatal`) and 130 are fork additions. Don't conflate 10 (script throw) with 11 (interpreter fault) — the crash-log `reason=` field disambiguates them when in doubt.

## Before running

1. **Validate** with `check /Diag=json` first.
2. If validation fails, report errors instead of running.
3. If validation passes, run with `/Headless /ErrorStdOut`.

## Rules

- Always use `/Headless` to suppress dialogs.
- Always use `/ErrorStdOut` to put runtime errors on stderr.
- Default timeout: 10 seconds. Use 5s for known-quick eval, 30s for known-slow setup.
- Write temp/output files under `$CLAUDE_JOB_DIR` (never `/tmp` — parallel jobs collide).
- Report both stdout and stderr in the result.
- Reach for the diagnostic flags when stderr is empty and the exit code is non-zero.
