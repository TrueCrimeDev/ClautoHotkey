---
name: ahk-async
description: >
  Timers, non-blocking work and function design for AHK v2 — SetTimer lifecycle, one-shot and
  self-rearming timers, Critical and A_IsCritical, debounce and throttle, state machines, chunked
  processing, scope with global and static, optional and variadic parameters, closures, ByRef
  outputs and memoization.
  TRIGGER when: user says "SetTimer", "timer", "delay", "debounce", "throttle", "background task",
  "non-blocking", "Critical", "poll", "periodic", "state machine", "global variable", "static
  variable", "variadic", "spread", "closure", "optional parameter", "ByRef", "memoize", "function
  scope", "why is my variable empty in the function".
  Examples: "run a task every 5 seconds and stop it", "debounce a text change", "make this loop not
  freeze the GUI", "why does count += 1 throw in my function"
---

# AHK v2 Timers, Async Patterns and Functions

## How to use

1. Timers, Critical, debounce, throttle, state machines, chunked work: `${CLAUDE_PLUGIN_ROOT}/Modules/Module_AsyncAndTimers.md`
2. Scope, parameters, variadics, closures, ByRef, memoization: `${CLAUDE_PLUGIN_ROOT}/Modules/Module_Functions.md`
3. Callbacks owned by a class also need `${CLAUDE_PLUGIN_ROOT}/Modules/Module_Objects.md` for binding rules.

## Critical rules

- Pass timer callbacks as `this.Method.Bind(this)` and keep the BoundFunc in a field, so the same object can be cancelled with `SetTimer(fn, 0)`.
- A live timer holds a reference to its callback, so `__Delete` will not run while it is armed. Give the class an explicit `Stop()` or `Dispose()`.
- A timer never re-enters itself, even when its callback sleeps. A guard flag is only needed when a hotkey or GUI event can also start the same work.
- Assigning to a name inside a function creates a silent local. Reading-then-modifying a name that was never assigned there, as in `count += 1`, throws `UnsetError`. Declare `global` or `static` explicitly.
- Long work belongs in chunks: process a slice, then re-arm a one-shot timer. `Sleep` keeps the thread open and lets threads pile up.

Window, input and hotkey timing belongs to `/ahk-input` when that skill is present.
