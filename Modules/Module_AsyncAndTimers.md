---
name: Module_AsyncAndTimers
description: 'Timers and cooperative async in AHK v2 - SetTimer one-shot, repeating and self-cancelling timers,
  class timers with a stored BoundFunc, explicit Stop/Dispose teardown, the Sleep/Critical/thread-interrupt
  model, debounce and throttle, parameterised callbacks via Bind, and non-blocking state machines and
  chunked processing. TRIGGER when the request involves: SetTimer, Sleep, Critical, A_IsCritical, timer,
  delay, interval, "run every N seconds", "one-off delay", "background task", debounce, throttle, polling,
  async, re-entrancy, "race condition", "shared state", "timer never stops", "class timer", "timer leak",
  "timer callback error", "chunked processing", "state machine". Not covered: true multithreading, COM
  async and inter-process communication - see Module_COM.md and Module_DllCall.md; __New/__Delete and
  inheritance - see Module_Classes.md; GUI event threading - see Module_GUI.md; try/catch design -
  see Module_Errors.md.'
---

# Module_AsyncAndTimers

AHK v2 has no real threads. A "thread" is a pseudo-thread: the script interpreter suspends the current one,
runs a timer, hotkey or event callback to completion, then resumes. Everything below follows from that.
Target: AutoHotkey v2.1-alpha.33+Console. Every pattern here also runs on stock v2.0 except the arrowless
function expression `(params) { ... }`, which is v2.1 only (see Module_Versions.md).

## API QUICK-REFERENCE

### SetTimer
| Form | Notes |
|------|-------|
| `SetTimer(Fn, Period?, Priority?)` | Positive period repeats; negative fires once and deletes itself; `0` cancels. A new timer with no period uses 250 ms. |
| `SetTimer(Fn, 0)` | Cancels the timer registered for `Fn`. The callback object must be the one used to start it. |
| `SetTimer(, 0)` | Inside a timer callback only: cancels the timer that launched the current thread. |
| `SetTimer(Fn)` | Calling again with the same `Fn` and a new period replaces the old entry, no duplicate is created. |
| Priority | Integer, default 0. Controls whether the timer may interrupt a running thread of a given priority. |
| Timer identity | A timer is keyed by the callback object. Two separate `.Bind()` results are two different timers. |

### Sleep, Critical, threads
| Item | Notes |
|------|-------|
| `Sleep(N)` | Waits N ms, but the thread stays alive and **can be interrupted**: timers, hotkeys and GUI events keep running while it sleeps. It does not freeze the script. |
| `Sleep(-1)` | Not a delay. Processes pending messages and returns at once. |
| `Sleep(0)` | Yields the rest of the OS time slice. |
| `Critical` / `Critical "On"` | Makes the current thread uninterruptible. Interrupting events are queued, not dropped, and run after release. Default message-check interval is 16. |
| `Critical "Off"` / `Critical 0` | Ends the critical section. |
| `A_IsCritical` | `0` when not critical, otherwise the interval (16 for plain `Critical`). Save it before entering `Critical` in code that may run inside an outer critical section. |
| Thread limit | `#MaxThreadsPerHotkey` and the global thread cap (default 10) bound how many pseudo-threads can stack up. |
| New-thread grace | A newly started thread is protected from interruption for about 15 ms (see `Thread "Interrupt"`), so short callbacks rarely race and long ones do. |

### Binding
| Item | Notes |
|------|-------|
| `Fn.Bind(args*)` | Returns a new BoundFunc each call. Store it; a fresh `.Bind()` can never match a registered timer. |
| `ObjBindMethod(obj, "Name", args*)` | Same effect by method name. The project canon for timer and GUI callbacks is `.Bind(this)`. |
| `FormatTime(ts?, fmt?)` | Human-readable time. `A_Now` is the raw `YYYYMMDDHH24MISS` string. |
| `A_TickCount` | Milliseconds since boot; use for elapsed-time measurement. |

## AHK V2 CONSTRAINTS

- Store the bound method once, for example `this.TickFn := this.OnTick.Bind(this)`, and use that same stored
  object for start and cancel: `SetTimer(this.TickFn, 250)` and `SetTimer(this.TickFn, 0)`. A fresh
  `.Bind(this)` at cancel time is a different object and the timer stays alive.
- A registered timer holds a reference to its callback, which holds `this`; and the stored BoundFunc on
  the instance makes a reference cycle. `__Delete` therefore never runs while the timer is live. Give every
  class timer an explicit `Stop()` (or `Dispose()`) and call it; `__Delete` is only a backstop for
  objects whose timer is already stopped.
- Do not pass a bare `this.Method` to `SetTimer`: it is called with zero arguments and the method's hidden
  `this` is unfilled. Use `.Bind(this)`.
- `Sleep(-1)` is not a pause. `Sleep(N)` is not a freeze either, and is rarely what you want in an event
  handler: the handler stays open, other events can interrupt it, and threads can pile up toward the cap.
  Use a one-shot timer (`SetTimer(Fn, -ms)`) to defer work.
- A timer is never re-entered by itself. While a timer callback is still running (even asleep in
  `Sleep`), later firings of that same timer are skipped, not stacked. An `IsRunning` guard is
  needed only when the same work can be started from several entry points: two timers, a timer and a hotkey,
  or a timer and a GUI event.
- `Critical` makes a thread uninterruptible; it does not stop the timer from becoming due, and the queued
  interruptions all run after `Critical "Off"`. Use it only around the few statements that must be
  atomic. Holding it across `Sleep`, file I/O or a COM call starves every other event.
- In a function called from a hotkey or timer that might already be critical, save `A_IsCritical`, enter
  `Critical`, and restore the saved value with `Critical prev`. An unconditional `Critical "Off"` would end
  the caller's critical section.
- Exceptions thrown inside a timer callback are not delivered to whoever started the timer. They reach
  `OnError` or the default error dialog. Catch inside the callback anything you can recover from, and
  register `OnError` for the rest (see Module_Errors.md).
- Closures capture the variable, not its value. A closure created in a loop sees the variable's final
  value; use `Fn.Bind(value)` to freeze a value at scheduling time.
- Assign to a shared global from a function only after `global Name` in that function. Without the
  declaration `Name := ...` creates a local and `Name += 1` throws UnsetError.
- Timer periods resolve to the OS clock tick (about 10 to 16 ms). Periods under that do not run faster.
- Multi-statement callbacks are named methods or functions. `=>` takes one expression and never a `{ }` block.

Safe-access priority order for deferred work:
  1. `SetTimer(Fn, -ms)`: one-shot, deletes itself, nothing to clean up.
  2. `SetTimer(Fn, ms)` with a stored callback and an explicit `Stop()`: repeating work.
  3. A one-shot timer that re-arms itself at the end of each run: repeating work that must never overlap
     itself, even when the callback takes longer than the period.
  4. `Critical` around the read-modify-write: only when two pseudo-threads mutate the same variable.

Pairing rules:
- ✗ `SetTimer(this.OnTick, 1000)` (hidden `this` unfilled)
- ✓ `SetTimer(this.TickFn, 1000)` with `this.TickFn := this.OnTick.Bind(this)` in `__New`
- ✗ `SetTimer(this.OnTick.Bind(this), 0)` to cancel (different object, timer survives)
- ✓ `SetTimer(this.TickFn, 0)` (same stored object)
- ✗ `Sleep(5000)` inside an event handler to wait before the next step
- ✓ `SetTimer(NextStep, -5000)`
- ✗ `SetTimer(() => DoWork(i), -100)` inside a loop (every callback sees the last `i`)
- ✓ `SetTimer(DoWork.Bind(i), -100)`

## TIER 1 - One-Off Delays, Repeating Timers, Self-Cancel
> METHODS COVERED: `SetTimer` · `FormatTime` · `ToolTip`

A negative period fires once. A positive period repeats until cancelled. A timer callback can cancel its
own timer with `SetTimer(, 0)`, which needs no reference to the function.

```ahk
ShowTime() {
    ToolTip("Now: " FormatTime(, "HH:mm:ss"))
}
SetTimer(ShowTime, 1000)

HideToolTip() {
    ToolTip()
}
SetTimer(HideToolTip, -3000)

CountdownTick() {
    static count := 5
    ToolTip(count--)
    if (count < 0) {
        SetTimer(, 0)
        ToolTip()
    }
}
SetTimer(CountdownTick, 1000)

; ✗ Sleep(3000) in an event handler keeps that thread open for 3 s and lets others pile up
; ✓ Defer instead, as HideToolTip does above
```

## TIER 2 - Class Timers: Stored Bind, Explicit Stop, Period Changes
> METHODS COVERED: `SetTimer` · `.Bind` · `ObjBindMethod`

A class timer needs three things: the bound method stored on the instance, a liveness flag so `Start` and
`Stop` are idempotent, and an explicit `Stop()` that the owner calls. The callback stored on the object
and the timer's reference to it form a cycle, so do not rely on `__Delete` to cancel the timer.

```ahk
class AsyncWorker {
    __New() {
        this.IsActive := false
        this.TickCount := 0
        this.TickFn := this.OnTick.Bind(this)
    }

    Start(intervalMs := 1000) {
        if this.IsActive
            return
        this.IsActive := true
        SetTimer(this.TickFn, intervalMs)
    }

    Stop() {
        if !this.IsActive
            return
        this.IsActive := false
        SetTimer(this.TickFn, 0)
    }

    SetInterval(intervalMs) {
        if this.IsActive
            SetTimer(this.TickFn, intervalMs)
    }

    OnTick() {
        this.TickCount++
    }

    Dispose() {
        this.Stop()
        this.TickFn := unset
    }
}

worker := AsyncWorker()
worker.Start(500)
worker.SetInterval(200)
worker.Stop()
worker.Dispose()

; ✗ SetTimer(this.OnTick.Bind(this), 0) inside Stop(): a new object, the timer is never cancelled
; ✓ Call Stop()/Dispose() from the owner; a __Delete that only calls Stop() will not run while the timer is live
```

`ObjBindMethod(this, "OnTick")` produces an equivalent BoundFunc and is useful when the method name is a
variable. Store its result the same way.

## TIER 3 - Shared State: Critical Sections, Guards, Registries
> METHODS COVERED: `Critical` · `A_IsCritical` · `SetTimer` · `Map.Has` · `Map.Delete`

Two pseudo-threads can interleave between any two statements of an interruptible thread. `Critical` makes a
short read-modify-write atomic. A timer cannot re-enter itself, so a guard flag matters only when the same
work has several entry points. AHK has no API that lists active timers or reports their period, so track
them in a `Map`.

```ahk
global g_Counter := 0

; ✗ Race: a timer callback can run between the read and the write and its increment is lost
IncrementUnsafe() {
    global g_Counter
    local snapshot := g_Counter
    g_Counter := snapshot + 1
}

; ✓ The whole read-modify-write is one uninterruptible step
IncrementSafe() {
    global g_Counter
    Critical
    local snapshot := g_Counter
    g_Counter := snapshot + 1
    Critical "Off"
}

class FileWatcher {
    __New(path) {
        this.Path := path
        this.IsBusy := false
        this.PollFn := this.Poll.Bind(this)
    }

    Start(intervalMs := 500) {
        SetTimer(this.PollFn, intervalMs)
    }

    Stop() {
        SetTimer(this.PollFn, 0)
    }

    ; Poll can also be called from a hotkey or a GUI button, so it guards itself
    Poll() {
        if this.IsBusy
            return
        this.IsBusy := true
        try {
            if FileExist(this.Path)
                content := FileRead(this.Path)
        } finally {
            this.IsBusy := false
        }
    }
}

class TimerRegistry {
    __New() {
        this.Tasks := Map()
    }

    Register(name, callback, intervalMs) {
        if this.Tasks.Has(name)
            throw ValueError("Task already registered", -1, name)
        entry := Map()
        entry["Callback"] := callback
        entry["Interval"] := intervalMs
        this.Tasks[name] := entry
        SetTimer(callback, intervalMs)
    }

    IsActive(name) => this.Tasks.Has(name)

    Interval(name) => this.Tasks.Has(name) ? this.Tasks[name]["Interval"] : 0

    Stop(name) {
        if !this.Tasks.Has(name)
            return
        SetTimer(this.Tasks[name]["Callback"], 0)
        this.Tasks.Delete(name)
    }

    StopAll() {
        for name, entry in this.Tasks
            SetTimer(entry["Callback"], 0)
        this.Tasks.Clear()
    }
}
```

Register a bound or stored callback, never a fresh arrow, so `Stop` can cancel the same object.

## TIER 4 - Debounce, Throttle, Non-Overlapping Repeats
> METHODS COVERED: `SetTimer` · `.Bind` · `A_TickCount`

A debounced function runs once after a quiet period: each call re-arms the same one-shot timer, and
calling `SetTimer` again with the same callback and a new negative period replaces the pending entry. A
throttled function runs at most once per window. For work that must never overlap itself, re-arm a
one-shot timer at the end of each run instead of using a repeating timer.

```ahk
CreateDebounce(callback, waitMs) {
    fire := () => callback()
    Debounced() {
        SetTimer(fire, -waitMs)
    }
    return Debounced
}

OnTypingComplete() {
    ; save the draft
}

DebouncedSave := CreateDebounce(OnTypingComplete, 1000)
DebouncedSave()
DebouncedSave()
DebouncedSave()

CreateThrottle(callback, windowMs) {
    last := 0
    Throttled(args*) {
        if (A_TickCount - last < windowMs)
            return
        last := A_TickCount
        callback(args*)
    }
    return Throttled
}

class SerialPoller {
    __New(intervalMs := 500) {
        this.Interval := intervalMs
        this.Active := false
        this.RunFn := this.Run.Bind(this)
    }

    Start() {
        this.Active := true
        SetTimer(this.RunFn, -this.Interval)
    }

    Stop() {
        this.Active := false
        SetTimer(this.RunFn, 0)
    }

    Run() {
        try {
            this.DoWork()
        } finally {
            if this.Active
                SetTimer(this.RunFn, -this.Interval)
        }
    }

    DoWork() {
    }
}

; ✗ timeoutCallback := () => { return callback() }   (a block body after => is a syntax error on every build)
; ✓ A named inner function, as Debounced above, or the one-expression form () => callback()
```

## TIER 5 - Parameterised Callbacks and A_IsCritical Save/Restore
> METHODS COVERED: `SetTimer` · `.Bind` · `Critical` · `A_IsCritical`

Arguments reach a timer callback only through `.Bind()`. Bound values are fixed when `.Bind()` runs, so a
loop that schedules several timers gets one value per timer. When one function can run both inside and
outside a critical section, save and restore `A_IsCritical`.

```ahk
class NotificationSystem {
    __New() {
        this.Queue := []
    }

    ScheduleAlert(message, delayMs) {
        SetTimer(this.ShowAlert.Bind(this, message), -delayMs)
    }

    ShowAlert(message) {
        this.Queue.Push(message)
    }
}

ShowAlert(msg) {
    ToolTip(msg)
}

ScheduleAll(messages) {
    ; ✗ SetTimer(() => ShowAlert(msg), ...) here: every callback would see the final msg
    for i, msg in messages
        SetTimer(ShowAlert.Bind(msg), -(1000 * i))
}

ProtectedUpdate(shared, key, value) {
    prev := A_IsCritical
    Critical
    shared[key] := value
    shared["LastModified"] := A_TickCount
    Critical prev
}

; ✗ Critical wrapped around Sleep(500) or FileRead("huge.txt"): every other event waits the whole time
```

## TIER 6 - State Machines and Chunked Processing
> METHODS COVERED: `SetTimer` · `.Bind` · `Min`

A sequence with waits between steps becomes a state machine: each step sets the next state and schedules
the same handler with a one-shot timer, so nothing ever blocks. Large data sets are processed a fixed
chunk per tick so the script stays responsive; calibrate the chunk so one tick finishes well inside the
period.

```ahk
class AsyncSequence {
    __New() {
        this.State := 0
        this.StepFn := this.Step.Bind(this)
    }

    Start() {
        this.State := 1
        SetTimer(this.StepFn, -10)
    }

    Step() {
        switch this.State {
            case 1:
                this.State := 2
                SetTimer(this.StepFn, -500)
            case 2:
                this.State := 3
                SetTimer(this.StepFn, -1000)
            case 3:
                this.State := 0
        }
    }
}

class ChunkedProcessor {
    __New(items, handler, chunkSize := 100) {
        this.Items := items
        this.Handler := handler
        this.Index := 1
        this.ChunkSize := chunkSize
        this.WorkFn := this.ProcessChunk.Bind(this)
    }

    Start() {
        SetTimer(this.WorkFn, 10)
    }

    ProcessChunk() {
        last := Min(this.Index + this.ChunkSize - 1, this.Items.Length)
        handle := this.Handler
        while this.Index <= last {
            handle(this.Items[this.Index])
            this.Index++
        }
        if this.Index > this.Items.Length
            SetTimer(this.WorkFn, 0)
    }
}

; A function stored in a property is called as a method, so `this.Handler(x)` passes `this` first.
; Copy it to a local (handle := this.Handler) before calling, as ProcessChunk does.

; ✗ Phase1(), Sleep(500), Phase2(), Sleep(1000): keeps the thread open and interruptible for the whole run
; ✓ AsyncSequence above: each wait is a timer, each step runs and returns
```

### Performance Notes

- Prefer a `Map` registry keyed by name to scanning an Array of callbacks: lookups are constant time.
- Create bound callbacks once (in `__New`) and reuse them. Calling `.Bind()` inside a ticking callback
  allocates a new BoundFunc every run.
- Every interrupting thread is queued while `Critical` is on and must be dispatched after it ends, so
  widening a critical section raises the cost for every waiting event. Keep it to the minimum statements.
- Batch work with a 10 to 15 ms timer and a fixed chunk instead of a long loop with `Sleep`.

## ANTI-PATTERNS

| Pattern | Wrong | Correct | Why it happens |
|---------|-------|---------|----------------|
| Unbound method in SetTimer | `SetTimer(this.OnTick, 1000)` | `SetTimer(this.TickFn, 1000)` with a stored `.Bind(this)` | v1 had no bound-method objects, and other languages bind implicitly |
| Fresh Bind at cancel time | `SetTimer(this.OnTick.Bind(this), 0)` | Cancel with the stored object | Each `.Bind()` returns a distinct object |
| Relying on `__Delete` to stop a timer | A class with only a `__Delete` that calls `SetTimer(..., 0)` | Explicit `Stop()` called by the owner | The live timer keeps the object referenced, so `__Delete` never fires |
| Sleep as the wait between steps | `Sleep(5000)` in a handler | `SetTimer(Next, -5000)` | v1 scripts used Sleep loops as the async pattern |
| Sleep(-1) as a short pause | `Sleep(-1)` | `Sleep(10)` or restructure | -1 only flushes the message queue |
| String period | `SetTimer(Fn, "1000")` | `SetTimer(Fn, 1000)` | Numeric strings are tolerated today, but pass a number |
| Block body after fat arrow | `() => { return x }` | A named function, or `() => x` | JavaScript habit |
| Closure in a loop as timer callback | `SetTimer(() => Work(i), -100)` | `SetTimer(Work.Bind(i), -100)` | Closures capture the variable, not its value |
| Unguarded shared state | `n := n + 1` across two pseudo-threads | `Critical` around the read-modify-write | Interruption can land between any two statements |
| Over-held Critical | `Critical` across `Sleep` or I/O | Bracket only the atomic statements | Mutex habit from other languages; here other events queue |
| Writing a global without declaring it | `g_Counter += 1` in a function | `global g_Counter` first | Assume-local scope; the write creates a local |
| Uncaught callback error | A timer callback that can throw, no handler | `try/catch` inside, plus `OnError` | Errors do not reach the code that started the timer |

## SEE ALSO

> This module does NOT cover: true multithreading, COM-based async and inter-process communication - see Module_COM.md and Module_DllCall.md
> This module does NOT cover: `__New`/`__Delete` lifecycle, inheritance and prototype chains - see Module_Classes.md
> This module does NOT cover: GUI event handler threading and control updates from callbacks - see Module_GUI.md
> This module does NOT cover: try/catch/finally, custom Error subclasses and `OnError` - see Module_Errors.md

- `Module_Objects.md` - BoundFunc and `ObjBindMethod`; why a bare method reference loses `this`.
- `Module_Classes.md` - lifecycle methods behind every class-based timer pattern here.
- `Module_GUI.md` - handler threading and offloading work from GUI events to timers.
- `Module_Errors.md` - exception handling inside timer callbacks.
- `Module_Versions.md` - which of these constructs run on stock v2.0.

<!-- Adapted from hsinming/AutoHotkey-V2-vibe-coding-tools (no license file upstream); see THIRD-PARTY.md -->
