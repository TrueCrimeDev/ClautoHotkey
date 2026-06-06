---
name: ahk-audit-errors
description: >
  Audit AHK v2 code for silent failures and inadequate error handling.
  Hunts for empty catch blocks, swallowed errors, broad bare-catches that
  hide unrelated failures, and fallbacks that mask problems from the user.
  TRIGGER when: user says "audit errors", "check error handling", "find silent failures",
  "review error handling", "scan for swallowed errors", "empty catch blocks", "/ahk-audit-errors".
---

# AHK v2 Silent Failure Auditor

You are auditing AHK v2 code with **zero tolerance** for silent failures. The CLAUDE.md project standard is *"Comprehensive error handling (no empty catch blocks)"* — your job is to enforce it.

## Non-negotiable rules

- **DO NOT** accept empty catch blocks — ever
- **DO NOT** accept errors caught without an action (logging-only doesn't count if the user can't see it)
- **DO NOT** accept bare `catch { ... }` that swallows every error class — type the catch unless you genuinely want everything
- **DO NOT** accept fallbacks that hide failure from the user (silent default values for failed parses, empty arrays for failed reads)
- **EVERY** caught error must be either: re-thrown, surfaced to the user (MsgBox/Tooltip/log file the user reads), or recovered with documented intent
- **EVERY** non-recoverable error must reach the user

A swallowed error in a hotkey handler is worse than a crash — the user doesn't know why their script stopped working.

## Scope

Default: scan unstaged `.ahk` changes (`git diff` if available) plus any files the user names.

If the user says "audit the whole project" or names a directory, walk that scope. Skip `Lib/.history/`, `archive/`, and other vendored paths.

## What to hunt for

### 1. Empty catch blocks

```ahk
try {
    risky()
} catch {
}                        ; ✗ silent
} catch Error as e {
}                        ; ✗ silent
} catch {
    ; ignore             ; ✗ comment-only
}
```

Action: flag each.

### 2. Log-only catches with no user feedback

```ahk
} catch Error as e {
    OutputDebug(e.Message)   ; ✗ user never sees OutputDebug unless DebugView is open
}
```

Action: flag unless the surrounding context shows the error is non-fatal AND a higher level handles it. If the catch is at the top of a hotkey/event handler, OutputDebug-only is always wrong.

### 3. Bare `catch` that swallows unrelated errors

```ahk
try {
    foo()
} catch {                ; ✗ catches everything: TypeError, OSError, MemberError...
    return false
}
```

Action: flag. Recommend `catch Error as e` or a specific class (`catch OSError`, `catch TypeError`).

### 4. Fallbacks that mask failure

```ahk
try {
    n := Integer(input)
} catch {
    n := 0               ; ✗ user thinks parsing succeeded
}
```

Action: flag. Either tell the user the input was invalid, or document intent: `; intentional: empty input means 0`.

### 5. Mock/fake fallbacks in production paths

```ahk
try {
    api.Get(url)
} catch {
    return Map()         ; ✗ caller can't distinguish "no data" from "failed"
}
```

Action: flag.

## How to run the audit

1. Identify the scope (unstaged diff, named file, or named directory).
2. `grep -nE 'catch[[:space:]]*(\\(|\\{|[A-Z])' <files>` — list every catch block with line number.
3. For each match, **read enough lines** to see the catch body. Use Read with offset/limit.
4. Classify each catch: pass / empty / log-only / bare / fallback-masks.
5. For every fail, write a finding with `file:line`, what's wrong, and the concrete fix.

## Report format

Group findings by severity. Use clickable `file:line` paths.

```
─ AHK ERROR HANDLING AUDIT ───────────────────────────

CRITICAL (silent failures)
  Lib/Foo.ahk:42  empty catch
    fix: re-throw, log to user-visible file, or MsgBox
  ContentEditor.ahk:118  bare catch swallows TypeError
    fix: catch Error as e, or specific subclass

WARNINGS (likely silent)
  ClipFluent.ahk:203  OutputDebug-only catch in hotkey handler
    fix: surface to user via TrayTip or status text

PASSED
  Win3.ahk:55  catch OSError, re-thrown ✓
  HoverScreenshot.ahk:88  catch with TrayTip ✓

─ SUMMARY ─────────────────────────────────────────
  scanned: 14 files, 27 catch blocks
  critical: 2 | warnings: 3 | passed: 22
```

If everything passes, say so plainly: `All N catch blocks reviewed. No silent failures found.`

## What NOT to flag

- Empty catches with explicit `; intentional: <reason>` comments — trust documented intent.
- `catch Error as e { throw e }` — that's a re-throw, fine.
- Catches in `__Delete()` destructors — destructors must not throw, swallowing is required.
- Unit-test code that asserts something throws.

## After the audit

If the user asks you to fix the findings, fix them in place — but ask first if there are >5 critical issues. A bulk silent-failure rewrite is the kind of change worth confirming.
