---
name: standalone-module-validation-noise
cue: the post-edit validator reports `This local variable appears to never be assigned a value` for a class name, and that class is defined in a sibling file that the real entry script includes
component: hooks/ahk-post-edit.sh
confidence: high
status: adopted
signature: appears to never be assigned a value
recorded: 2026-10-18
verified: 2026-10-18 on 2.1-alpha.35+Console
---

## Lesson

`hooks/ahk-post-edit.sh` validated the edited file on its own. For a module that is only ever reached through an entry script's `#Include`, every reference to a class from a sibling file became an "appears to never be assigned" warning, the runtime probe exited non-zero, and the edit was blocked while the real entry script passed. The hook now looks for an includer in the file's folder or its parent (three levels deep, so a module included by a module still resolves), runs the probe on that script, and reports the verdict under its name. A module included by the main script is validated through step 2 instead of being run.

## Evidence

- Error log, 69 rows with that headline (73 mention it), all logged as blocking `runtime` failures; 46 of them carried no other error. The most affected files are `__Tableau_a5.ahk` (17), `_Menu.ahk` (5) and `GUI_Specialty.ahk` (5).
- 2026-10-18, the Nock port: editing `NockPanel.ahk` and `NockPages.ahk` produced warnings for `Color` and `UI`, both defined in sibling files included by `Nock.ahk`; `check` on `Nock.ahk` passed every time.
- `Tools/tests/hooks_smoke.sh`: a module whose only reference is a sibling class passes through its includer (`via app.ahk`), and a genuine error in the same module is still blocked, reported through the includer.

## Edits

| component | change | observed | verdict |
|---|---|---|---|
| hooks/ahk-post-edit.sh | `find_includer`, probe the includer, report `runtime(via X)` | smoke case passes where the old hook blocked; the error case still blocks | helped |
