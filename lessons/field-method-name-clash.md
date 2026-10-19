---
name: field-method-name-clash
cue: `Property is read-only` thrown by a plain `this.x := value` in a constructor, where the class also defines a method whose name differs only in case
component: rules/ahk-v2-syntax.md
confidence: medium
status: adopted
signature: Property is read-only
recorded: 2026-10-18
---

## Lesson

The syntax rule should state that a field and a method cannot share a name, because names are case-insensitive: assigning `this.quickAdd := false` in a class that defines `QuickAdd()` throws `Property is read-only`, and the message points at the assignment, not at the method. Name the state field differently (`quickAdding`) or keep the method. The error log shows the pattern recurring across unrelated scripts, so one line in the always-on rule is cheaper than the debugging it costs each time.

## Evidence

- Error log, 7 rows with the headline `Property is read-only`: `TapHoldLayer.ahk` (`tapHoldEngaged`, 2026-06-10), `DarkModeModular_Alpha.ahk` (`_shorthands`, 2026-09-02), `Nock.ahk` (`quickAdd`, 2026-10-18), and four single rows in other files.
- The 2026-10-18 case was confirmed: `NockApp` had both a `quickAdd` field and a `QuickAdd()` method; renaming the field fixed it. The two earlier cases match the pattern but their cause was not re-verified, which is why confidence is medium rather than high.

## Edits

| component | change | observed | verdict |
|---|---|---|---|
| rules/ahk-v2-syntax.md | one line stating that a field cannot share a method's name | no rollout yet | untested |
