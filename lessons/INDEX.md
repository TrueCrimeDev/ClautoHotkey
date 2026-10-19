# Lessons

Each entry is something a recorded mistake taught about this harness: the shape of
situation it applies to, the change it argues for on a named component, and the
evidence behind it. Read the cue column first; open an entry only when its cue
matches what is in front of you. `proposed` entries are changes nobody has made yet.

Rebuilt by `Tools/lessons.py index`; do not edit by hand.

## adopted

| lesson | cue | component | confidence |
|---|---|---|---|
| [deleted-file-not-found](deleted-file-not-found.md) | the post-edit hook blocks with `Script file not found` for a probe or scratch script that was deleted or renamed before the hook ran | `hooks/ahk-post-edit.sh` | high |
| [field-method-name-clash](field-method-name-clash.md) | `Property is read-only` thrown by a plain `this.x := value` in a constructor, where the class also defines a method whose name differs only in case | `rules/ahk-v2-syntax.md` | medium |
| [runtime-probe-running-script](runtime-probe-running-script.md) | the post-edit runtime probe of a script that is already running reports `Another instance is already running` instead of a verdict | `hooks/ahk-post-edit.sh` | high |
| [shim-void-dllcall](shim-void-dllcall.md) | a candidate script run under the dry-run shim calls `DllCall(..., "Void")` and the gate reports `No value was returned` at a line inside DryRunShim.ahk | `Tools/harness/DryRunShim.ahk` | high |
| [standalone-module-validation-noise](standalone-module-validation-noise.md) | the post-edit validator reports `This local variable appears to never be assigned a value` for a class name, and that class is defined in a sibling file that the real entry script includes | `hooks/ahk-post-edit.sh` | high |
| [void-fat-arrow-callback](void-fat-arrow-callback.md) | a fat-arrow callback whose body is a call that returns nothing, such as a tray or timer lambda `(*) => this.Toggle()`, on the +Console fork | `rules/ahk-v2-syntax.md` | high |
