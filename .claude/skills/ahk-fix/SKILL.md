---
name: ahk-fix
description: >
  Load AHK v2 error diagnosis, debugging, and fix knowledge.
  Use when diagnosing errors, fixing broken scripts, or debugging unexpected behavior.
  TRIGGER when: user mentions error, crash, broken, not working, debug, exception, TypeError, UnsetError,
  ValueError, OSError, syntax error, runtime error, fix, problem, issue, thrown, try, catch, troubleshoot,
  bug, fail, undefined, wrong output, unexpected behavior.
  Examples: "fix this error", "script crashes on startup", "UnsetError on line 42", "debug this"
---

# AHK v2 Error Diagnosis Skill

When this skill is invoked, load the following module files:

1. **Read** `Modules/Module_Errors.md` — V1→V2 breaking changes, error class hierarchy, API quick-reference, anti-patterns, diagnostic checklist
2. **Read** `Modules/Supplemental/Module_ErrorHandling.md` — Additional error types, try/catch patterns, prevention strategies
3. **Read** `Modules/Supplemental/Module_Debug.md` — Systematic debugging process, code inspection, resolution strategies
4. **Read** `Modules/Supplemental/Module_Components.md` — Common component patterns to validate against

## Diagnosis Workflow

Follow this exact sequence for every error:

```
1. IDENTIFY    → Determine error type (syntax / runtime / logic)
2. LOCATE      → Find exact line and surrounding context
3. DIAGNOSE    → Determine root cause using error type patterns below
4. FIX         → Provide before/after code with explanation
5. PREVENT     → Explain why it happened and how to avoid it
```

## Common Error Patterns (Quick Reference)

```
UnsetError          → Variable used before assignment. Add initialization.
TypeError           → Wrong type passed. Check object vs string vs number.
ValueError          → Invalid value for operation. Validate inputs.
MemberError         → Property/method doesn't exist. Check spelling and HasProp().
OSError             → OS operation failed. Check DllCall types and file paths.
MethodError         → Calling non-existent method. Verify method name and class.
PropertyError       → Accessing non-existent property. Use HasProp() guard.
```

## v1-to-v2 Error Triggers

These v1 patterns cause errors in v2 — check for them:

```
WRONG (v1)                          RIGHT (v2)
─────────────────────────────────────────────────
x = value                          x := value
IfEqual, x, value                  if (x = value)
StringLeft, out, str, n            out := SubStr(str, 1, n)
Gui, Add, Button, , OK             gui.AddButton(, "OK")
MsgBox, text                       MsgBox("text")
new MyClass()                      MyClass()
ComObjCreate("...")                 ComObject("...")
```

## Integration with autohotkey-debug MCP

When live debugging is available, use the MCP tools:
1. `capture_error` — wait for the exception
2. `analyze_error` — build analysis
3. `apply_fix` — write the fix
4. `get_source_context` — read code around error line

## Console Error Checking

```powershell
# Syntax check
bin\AutoHotkey64.exe check script.ahk

# Runtime check (headless, 2s timeout)
timeout 2 bin\AutoHotkey64.exe /ErrorStdOut /Headless script.ahk

# Capture stderr
bin\AutoHotkey64.exe /ErrorStdOut script.ahk 2>err.txt
```
