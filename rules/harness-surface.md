---
paths:
  - "CLAUDE.md"
  - "skills/**"
  - "agents/**"
  - "rules/**"
  - "hooks/**"
  - "commands/**"
  - "lessons/**"
---

# Editing the harness itself

You are changing what every later session sees. Each component has a different cost:

| component | in context | cost |
|---|---|---|
| `CLAUDE.md`, rules whose paths match any `.ahk` | every session, every edit | paid on every run |
| `rules/` with narrow paths | first edit of a matching file | paid when it fires |
| `skills/` | when invoked | nothing until used |
| `agents/` | its own context window | a boot cost per launch |
| `hooks/` | inside the tool loop | cannot be skipped; no context cost |
| `Tools/` scripts | on demand | none |

Where new instruction goes, in this order: a **hook** for a mechanical check the model could otherwise skip; a **script** for a deterministic operation that keeps being hand-rolled; a **skill** for a procedure with a recognisable trigger; an **agent** for a bounded investigation whose input is large and whose answer is small; **always-on text** last, only for a short rule that applies to every run. If you add always-on text, cut something to pay for it.

Change only what evidence argues for: a `lessons/` entry, error-log rows, or a run that went wrong. No evidence, no change; leaving the tree as it is counts as an answer.

Before finishing, `python Tools/lint_harness.py` must report no errors. It checks that each skill's name matches its directory and is advertised, that every script a hook or skill names exists, that rules declare paths, that lessons carry cue, lesson, evidence and confidence, and that the counts quoted in the docs match the tree.

A change that comes out of a mistake gets a lesson (`python Tools/lessons.py add ...`, format in `lessons/INDEX.md`). A recurring error whose cause is not verified stays a `Tools/lessons.py propose` row, not a lesson.
