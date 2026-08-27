---
name: ahk-mistakes
description: >
  Show your most common AHK v2 mistakes from the error log.
  Reads .claude/error-log.jsonl and reports recurring patterns with prevention tips.
  TRIGGER when: user says "my mistakes", "common errors", "what do I keep getting wrong",
  "error patterns", "recurring bugs".
---

# AHK v2 Mistake Pattern Analyzer

Read the error log and show your most recurring mistakes with prevention tips.

## Error Log Location

`.claude/error-log.jsonl` — populated by `hooks/error-logger.sh` (bundled with this skill) and by direct writes from `.claude/hooks/ahk-post-edit.sh` on validation failures.

Each line is a JSON object:
```json
{"timestamp":"2026-03-04T12:00:00","tool":"Edit","file":"script.ahk","line":42,"type":"syntax","message":"Missing closing brace"}
```

## Analysis Workflow

1. **Read** `.claude/error-log.jsonl`
2. **Parse** each JSON line
3. **Group** errors by type and message pattern
4. **Count** occurrences of each pattern
5. **Sort** by frequency (most common first)
6. **Report** top 10 patterns with:
   - Error type and message
   - How many times it occurred
   - Most recent occurrence
   - Files affected
   - Prevention tip

## Report Template

```
─ YOUR TOP MISTAKES ──────────────────────────────────────

1. Missing .Bind(this) on event handlers (12 occurrences)
   Last: ContentEditor.ahk:145 — 2 hours ago
   Fix: Always use gui.OnEvent("Click", this.Method.Bind(this))

2. Unset variable in class method (8 occurrences)
   Last: DarkModeModular.ahk:89 — yesterday
   Fix: Declare variables before use or check with IsSet()

3. Fat arrow with multi-line block (5 occurrences)
   Last: ClipFluent.ahk:234 — 3 days ago
   Fix: Use => for single expressions only, use { } for blocks

─ SUMMARY ────────────────────────────────────────────────

Total errors logged: 47
Unique patterns: 12
Most error-prone file: DarkModeModular.ahk (15 errors)
Most common type: syntax (28), runtime (14), other (5)
```

## Prevention Integration

After showing the report, suggest:
- Which `/ahk-*` skills to invoke for the top error types
- Whether any hookify rules could catch the patterns
- Specific code patterns to watch for
