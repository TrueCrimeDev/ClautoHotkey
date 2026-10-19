---
name: shim-void-dllcall
cue: a candidate script run under the dry-run shim calls `DllCall(..., "Void")` and the gate reports `No value was returned` at a line inside DryRunShim.ahk
component: Tools/harness/DryRunShim.ahk
confidence: high
status: adopted
signature: DryRunShim\.ahk \(\d+\) : ==> No value was returned
recorded: 2026-10-18
verified: 2026-10-18 on 2.1-alpha.35+Console
---

## Lesson

A wrapper that forwards a built-in must not add a failure the built-in does not have. The shim's `DllCall` ended in `return HarnessReal_DllCall(fn, args*)`; when the candidate used the alpha.30 `"Void"` return type the real call yields no value and the `return` threw `UnsetError`, so the dry-run tier failed scripts that run cleanly outside it. The wrapper now checks for a trailing `Void` (or `Cdecl Void`) argument and forwards without returning. Any other shadowing wrapper in the shim that `return`s a forwarded call has the same exposure.

## Evidence

- Error log: 16 of the 24 rows with the headline `No value was returned` point at `tools/harness/DryRunShim.ahk (584)`, `Specifically: HarnessReal_DllCall(fn, args*)`, the latest on 2026-10-15 for `flash_probe.ahk` and `move_probe.ahk`. The shim, not the candidates, was the larger source of that headline.
- Probe `void_probe.ahk` on 2.1-alpha.35+Console: a wrapper that returns `DllCall("Sleep", "UInt", 1, "Void")` throws `UnsetError`; the guarded form does not; a non-void `GetTickCount` still returns through the guard.
- After the fix, `GateDryRun.ahk` on the probe reports `dryrun pass` with every check passing.

## Edits

| component | change | observed | verdict |
|---|---|---|---|
| Tools/harness/DryRunShim.ahk | `HarnessDllIsVoid` guard before the forwarding return | probe failed before the change and passes after it | helped |
