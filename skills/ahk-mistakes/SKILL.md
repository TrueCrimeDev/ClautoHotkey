---
name: ahk-mistakes
description: >
  Show your most common AHK v2 mistakes from the error log and turn a verified one
  into a lesson for the harness. Reads .claude/error-log.jsonl, reports recurring
  patterns with prevention tips, and writes lessons/ entries with cue, lesson,
  evidence and confidence.
  TRIGGER when: user says "my mistakes", "common errors", "what do I keep getting wrong",
  "error patterns", "recurring bugs", "what did we learn", "record a lesson".
---

# AHK v2 Mistake Pattern Analyzer

Read the error log, show the recurring mistakes, and when a cause is verified, record
the lesson where every later session will read it.

## Error Log Location

`.claude/error-log.jsonl` in the project, populated by `skills/ahk-mistakes/hooks/error-logger.sh`
(bundled with this skill, run on failed tool calls) and by direct writes from the post-edit
validator on validation failures.

Each line is a JSON object:
```json
{"timestamp":"2026-03-04T12:00:00","tool":"Edit","file":"script.ahk","line":42,"type":"syntax","message":"Missing closing brace"}
```

## Step 1: the frequency report

Run the proposer, which groups rows by the interpreter's headline and drops anything a
lesson already covers:

```bash
python "${CLAUDE_PLUGIN_ROOT}/Tools/lessons.py" propose --min 2
```

The list under "Already covered by a lesson" matters as much as the table. A signature
matches a headline, not a cause, so when the proposer says some of a lesson's rows came
"after it was recorded", open those rows: either the fix did not hold, or something new
fails with the same message and needs a lesson of its own with a narrower signature.

Report the top patterns in this form:

```
─ YOUR TOP MISTAKES ──────────────────────────────────────

1. Missing .Bind(this) on event handlers (12 occurrences)
   Last: ContentEditor.ahk:145 — 2 hours ago
   Fix: Always use gui.OnEvent("Click", this.Method.Bind(this))

2. Unset variable in class method (8 occurrences)
   Last: DarkModeModular.ahk:89 — yesterday
   Fix: Declare variables before use or check with IsSet()

─ SUMMARY ────────────────────────────────────────────────

Total errors logged: 47
Unique patterns: 12
Most error-prone file: DarkModeModular.ahk (15 errors)
Already covered by lessons: void-fat-arrow-callback (24)
```

For each pattern name the `/ahk-*` skill that would have prevented it and the code
pattern to watch for.

## Step 2: reflect, then record at most one lesson

A count is not a lesson. Before writing one, establish the cause: open the rows,
reproduce the failure in a probe on the configured interpreter, and identify the harness
component that should have prevented it (a rule, a skill, a hook, a module, a gate).

Write the reflection in two parts, the second only if the first supports it:

```
<edits>
component: <path as it appears in the tree>
change: <what should change, or did change>
observed: <the execution difference and where it was seen>
verdict: helped | hurt | no observed effect | confounded | untested
</edits>

<experience>
cue: <the shape of situation this applies to, not this script's facts>
lesson: <the operation on the harness, naming the component>
evidence: <rows, files, dates, the probe>
confidence: high | medium | low, and why
</experience>
```

Use `confounded` whenever several things changed at once or a single run is all that
stands behind the difference. A lesson resting only on confounded rows is not written;
the pattern stays a `propose` row until the cause is verified.

Then record it:

```bash
python "${CLAUDE_PLUGIN_ROOT}/Tools/lessons.py" add \
  --name <slug> --component <path> --confidence <level> --status proposed \
  --signature "<regex over the error headline>" \
  --cue "..." --lesson "..." --evidence "..."
```

The tool refuses an entry missing any of cue, lesson, evidence or confidence, and
rebuilds the folder's `INDEX.md`. Mark it `adopted` only once the component change is made.

Where the entry lands depends on where the harness lives. Run from inside a clone of
the harness, it joins `lessons/` there and `python Tools/lint_harness.py` must stay clean
afterwards. Installed as a plugin, the harness folder is replaced on every update, so the
entry goes to the plugin's data folder or, failing that, to `.claude/lessons/` in the
project. `lessons.py where` prints both folders.

## Reading the library

```bash
python "${CLAUDE_PLUGIN_ROOT}/Tools/lessons.py" where
```

Each folder it prints has an `INDEX.md` listing its lessons by cue. Scan the cues before
diagnosing a recurring error; if one matches, apply its lesson instead of rediscovering it.
