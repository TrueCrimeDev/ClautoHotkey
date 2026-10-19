---
name: deleted-file-not-found
cue: the post-edit hook blocks with `Script file not found` for a probe or scratch script that was deleted or renamed before the hook ran
component: hooks/ahk-post-edit.sh
confidence: high
status: adopted
signature: Script file not found
recorded: 2026-10-18
---

## Lesson

A PostToolUse hook runs after the edit, and a transient script is often gone by then. `hooks/ahk-post-edit.sh` must check that the file still exists before validating it, and exit quietly when it does not: there is nothing to validate, and a block here only teaches the model to distrust the hook. The project-level copy of the hook had this check for months; the plugin copy did not, which is how the pattern became the single largest row in the log.

## Evidence

- Error log, 121 rows with the headline `Script file not found`, the largest pattern in the log; almost all on `probe*.ahk` scratch files, last on 2026-09-16.
- `.claude/hooks/ahk-post-edit.sh` in the parent repo already carried the missing-file bail with the comment "common with transient probe/repro scripts cleaned up mid-edit"; the plugin's `hooks/ahk-post-edit.sh` did not.
- `Tools/tests/hooks_smoke.sh`: a payload naming a file that does not exist now exits 0 with no output.

## Edits

| component | change | observed | verdict |
|---|---|---|---|
| hooks/ahk-post-edit.sh | exit 0 when the edited file no longer exists | smoke case passes | helped |
