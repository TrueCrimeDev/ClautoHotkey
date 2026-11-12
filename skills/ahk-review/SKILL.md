---
name: ahk-review
description: >
  Review and defensive-validation knowledge for AHK v2 — a method for reviewing a script (static gates
  first, six ordered dimensions, Critical/Major/Minor grading) and a pattern set for guard clauses,
  TypeError vs ValueError, optional parameters, duck typing and form validation.
  TRIGGER when: user says "review this script", "code review", "audit", "find bugs", "what's wrong
  with", "is this v2 compliant", "best practices", "validate input", "guard clause", "type check",
  "fail early", "defensive programming", "constructor guard", "TypeError", "ValueError".
  Examples: "review my class", "audit this GUI script", "add validation to this function",
  "what should I check before shipping this"
---

# AHK v2 Review and Validation

## How to use

1. For a review, load `${CLAUDE_PLUGIN_ROOT}/Modules/Module_CodeReview.md`. Run `check` or `Check()` first and only then read the code by dimension.
2. For adding or judging validation, load `${CLAUDE_PLUGIN_ROOT}/Modules/Module_Validation.md`.
3. For error-class design and try/catch structure, also load `${CLAUDE_PLUGIN_ROOT}/Modules/Module_Errors.md`.

## Report shape

Report every dimension, including the ones that pass. Findings are ranked Critical, Major, Minor, and each names the file, the line and the fix. End with a priority list.

## Quick answers

- Put guard clauses at the top of the function. Throw `TypeError` for a wrong kind and `ValueError` for a right kind with a bad value, and pass `-1` so the report points at the caller.
- Use `IsSet` for optional parameters, not `= ""`.
- Use `IsNumber()` for text input. `"5" is Number` is false because it is a String.
- On the fork, validate untrusted JSON with `JSON.Validate` and code strings with `Check()`.
