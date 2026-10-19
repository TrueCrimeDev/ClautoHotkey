---
name: runtime-probe-running-script
cue: the post-edit runtime probe of a script that is already running reports `Another instance is already running` instead of a verdict
component: hooks/ahk-post-edit.sh
confidence: high
status: adopted
signature: Another instance is already running
recorded: 2026-10-18
verified: 2026-10-18 against the bundled v2 docs
---

## Lesson

The probe must launch with `/force`, which the AutoHotkey docs define as "the same effect as `#SingleInstance Off`": the probe instance runs beside the user's running copy instead of refusing to start. The shim branch of `hooks/ahk-post-edit.sh` already passed it; the fallback branch, used when no dry-run shim is found, did not, and every "Another instance" row came from there. Both branches now pass it. The earlier draft of this lesson assumed `/force` replaced the running instance; the docs say otherwise, so no running-process check is needed.

## Evidence

- Error log, 38 rows with the headline `Another instance is already running. Use #SingleInstance Force or /force`; 25 of them on `ShortcutManager.ahk`, 4 on `FocusAudioTab.ahk`, 3 on `Esoteric_FiberInversion_Demo.ahk` (2026-09-26).
- `Docs/` (bundled v2 help), command-line switches: `/force` "Launch unconditionally, skipping any warning dialogs. This has the same effect as #SingleInstance Off."
- `hooks/ahk-post-edit.sh` before the change: `/force` on the shim launch, absent on the fallback launch.

## Edits

| component | change | observed | verdict |
|---|---|---|---|
| hooks/ahk-post-edit.sh | `/force` on the fallback launch | no rollout on a stock build yet; the switch's meaning is documented | untested |
