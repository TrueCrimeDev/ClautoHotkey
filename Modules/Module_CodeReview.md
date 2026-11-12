---
name: Module_CodeReview
description: >
  Method for reviewing an AHK v2 script — run the static gates first, then evaluate six ordered
  dimensions (syntax compliance, error handling, scope and architecture, GUI and event binding,
  performance and resources, readability), grade findings Critical / Major / Minor, and report every
  dimension with a priority list. Includes the verified table of which built-ins throw, and review
  patterns for unbound callbacks, swallowed errors, loop-invariant I/O and COM lifetime on
  v2.1-alpha.33+Console.
  TRIGGER when the request involves: review, "code review", audit, "check my script", "find bugs",
  "what's wrong with", "quality check", "is this v2 compliant", "best practices", "refactor review",
  "is my error handling correct", "review this class", "review my GUI", severity, "priority list".
  Not covered: syntax and API semantics — see Module_Instructions.md; error class hierarchy, OnError and
  try/catch structure — see Module_Errors.md; GUI construction — see Module_GUI.md; class design —
  see Module_Classes.md; formatting rules — see Module_Formatting.md.
---

# Module_CodeReview

A review is a measurement against the project's rules, not a list of taste. Machine-checkable
defects come from the engine; the reviewer's time goes to what a parser cannot see.

## API QUICK-REFERENCE

### Review workflow
| Step | Action |
|------|--------|
| 1 | Run the real parser first: `check <file>` (add `/Diag=json` for records), or `Check(source)` from a script. A script that does not load has no further findings worth ranking |
| 2 | For a batch or CI-style pass, use the harness static gate (`Tools/harness/GateStatic.ahk`) and the pure gate for existing `TestKit` tests |
| 3 | Walk the six dimensions in order; do not skip or reorder |
| 4 | Write the report in the format below, one section per dimension, then the priority list |

### Severity
| Severity | Meaning |
|----------|---------|
| Critical | Script will not load, crashes, loses data, or does the wrong thing at runtime |
| Major | Violates a project rule or creates real maintenance risk |
| Minor | Readability or style with no correctness impact |
| Pass | Nothing found in the dimension — always written out explicitly |

### The six dimensions
| # | Name | Look for | Escalate when the script has |
|---|------|----------|------------------------------|
| 1 | Syntax and v2 compliance | v1 leftovers, `#Requires`, label hotkeys, `=` where `:=` was meant, removed alpha.30 forms | Always — everything else assumes the code loads |
| 2 | Error handling and type safety | unguarded throwing calls, empty or swallowing `catch`, unvalidated external text | File, registry, COM, `DllCall`, `Download`, window targeting |
| 3 | Scope and architecture | globals, pseudo-arrays, `{}` used as a dictionary, multi-purpose functions | Many globals, long functions, parallel variables |
| 4 | GUI and event binding | unbound method callbacks, block-body fat arrows, timer ownership, teardown | `Gui()`, `SetTimer`, `OnMessage`, class-based callbacks |
| 5 | Performance and resources | loop-invariant I/O, repeated COM creation, leaked handles, linear lookups in hot paths | Loops over I/O or COM, hotkeys that do real work |
| 6 | Readability and composite | naming, dead code, debug output, duplicate intent, doc comments | More than ~50 lines or more than one hotkey; full-review request |

### Which built-ins throw (verified on the fork)
| Call | Failure raises | Review rule |
|------|----------------|-------------|
| `FileRead`, `FileOpen` on a missing or locked file | `OSError` | Guard when the path is not known-good |
| `RegRead` with no default and a missing value | `OSError` | Pass a default or catch |
| `Download` | `OSError` | Always guard |
| `ComObject("ProgID")` | `Error` / `OSError` on a bad ProgID or HRESULT | Guard; Office and WMI may be absent |
| `DllCall("lib\fn", ...)` | `Error` on a missing DLL or function | Guard when the target is optional |
| `RegExMatch`, `RegExReplace` with a malformed pattern | `Error` | Guard only for dynamic patterns |
| `WinGetTitle`, `WinActivate`, `WinGetPID` and other `Win*` reads on a missing window | `TargetError` | `WinExist` first, or catch `TargetError` |
| `ProcessGetPath` on a missing process | `TargetError` | `ProcessExist` first |
| `Integer("abc")`, `Number("abc")` | `TypeError` | `IsInteger` / `IsNumber` first when the text is untrusted |
| `MsgBox`, `ToolTip`, `Sleep`, `Send`, `StrLen`, `Print` | does not throw in normal use | Do not demand a `try` around these |
| `ComObjQuery` | `Error` if the interface is unsupported | Returns a wrapper, not a raw pointer |

### Report format
```text
AHK v2 Code Review Report
Scope: full script | fragment (state which constructs were visible)
Static gate: check PASS | check FAIL (list diagnostics, stop ranking below)

Dimension 1 - Syntax and v2 compliance
- Critical, line 12: `x = 5` is a load-time syntax error. Use `x := 5`.
Dimension 2 - Error handling and type safety
- Pass: no issues found.
Dimension 3 - Scope and architecture
- Not applicable: no globals or data structures in the fragment.
(Dimensions 4, 5, 6 in the same shape)

Summary
Two or three sentences.

Priority action list
1. Top issue, one-line rationale (Critical)
2. ...
```

## AHK V2 CONSTRAINTS

- Run the parser before reading. `x = 5` as a statement, a duplicate hotkey, a `=> {` block arrow and
  v1 command syntax are all load-time errors on this engine, so they are Critical because the script
  does not start, and the engine already names the line. Do not rediscover them by eye.
- `=` in expression position (`ok := a = b`, `return a = b`) is a silent comparison. That is the
  form worth hunting for by hand: ask whether comparison was intended.
- Only demand `try` around calls that really throw (table above). A `try` around `MsgBox` or `Sleep`
  fabricates a risk and costs the review its credibility.
- A `catch` must handle, report or re-throw. An empty `catch` body, or one that only returns a default
  with no trace, is Critical because the failure becomes undiagnosable. Surface `e.Message`
  (and `e.Extra`) with `Print`, `OutputDebug` or a log.
- Method callbacks need `.Bind(this)`. Without it `this` inside the handler is the *event source*
  (the control), so the first `this.Prop` read is a `PropertyError`; if the method declares more
  parameters than the event supplies, registration itself throws "Invalid callback function".
- Fat arrows hold one expression. A multi-statement body belongs in a named method.
- `ComObject` and `ComObjQuery` return self-releasing wrappers. Release by dropping the last
  reference (`obj := ""`), and reserve `ObjRelease` for raw integer pointers obtained through
  `DllCall`.
- Evaluate only what is present. No GUI means Dimension 4 is "Not applicable", not a finding.
- Each line gets one primary dimension owner so the priority list is not inflated.
- Mark fragment reviews at the top of the report and limit Dimension 1 to the visible code.
- Do not report `.=` string building in a loop as quadratic. AHK grows string capacity in place, so it
  is not a bottleneck at review scale; measure with `A_TickCount` before claiming otherwise.
- Do not report `CoordMode` as leaking globally. It is per-thread: a new hotkey or timer thread
  starts from the script's defaults.

Triage order when time is short: Dimension 1 and the static gate, then Dimension 2, then Dimension 4
(callbacks fail at runtime), then Dimensions 3, 5 and 6.

## TIER 1 — Syntax and v2 compliance
> METHODS COVERED: `check` · `Check()` · `:=` · `#Requires` · hotkey function form · `Map()`

Let the parser find what it can, then review what it cannot. This block shows the compliant forms of
the usual v1 leftovers; the v1 forms stay in comments because they do not load.
```ahk
#Requires AutoHotkey v2.1-alpha.30

; Real-engine verdict on a source string, no temp file by hand
verdict := Check("x = 5")
Print("loads: {}", verdict.Ok)

; ✗ x = 5                  load error: use :=
; ✗ MsgBox, Title, Text    load error: v1 command syntax
; ✗ SetTimer, Label, 1000  load error: v1 command syntax
; ✗ ^F1::                  followed by return: label hotkey, v1 form

counter := 0
counter := counter + 1
MsgBox("Text", "Title")

Tick() {
    ToolTip(A_Now)
}
SetTimer(Tick, -1000)

; Hotkeys: one expression or a block, each combination registered once
^F2:: Print("single statement")
^F3:: {
    Print("first")
    Print("second")
}

; Silent hazard the parser accepts: comparison where assignment was meant
matched := counter = 1
Print("{}", matched)

; Dynamic names: a Map, not %name% indirection
lookup := Map()
lookup["host"] := "localhost"
Print("{}", lookup["host"])
```

## TIER 2 — Error handling and type safety
> METHODS COVERED: `try` · `catch` · `else` · `finally` · `FileRead()` · `RegRead()` · `IsInteger()` · `Integer()`

Check that throwing calls are guarded at the right boundary and that every catch leaves a trace.
```ahk
#Requires AutoHotkey v2.1-alpha.30

; ✗ content := FileRead(path)         unguarded: a missing file ends the script
; ✗ catch { }                         swallows the failure with no trace

LoadText(path) {
    try {
        return FileRead(path, "UTF-8")
    } catch OSError as err {
        Print("LoadText failed [{}]: {}", err.Number, err.Message)
        return ""
    }
}

; Untrusted text: validate the content, then convert
ReadTimeoutMs() {
    raw := RegRead("HKCU\Software\Demo", "Timeout", "30")
    if !IsInteger(raw)
        return 30000
    return Integer(raw) * 1000
}

; else keeps the success path out of the guarded region
try {
    text := FileRead(A_ScriptFullPath, "UTF-8")
} catch OSError as err {
    Print("read failed: {}", err.Message)
} else {
    Print("read {} chars", StrLen(text))
}

; Catch the narrow class when the handler is class-specific
OpenWindowTitle(winTitle) {
    try {
        return WinGetTitle(winTitle)
    } catch TargetError {
        return ""
    }
}

Print("[{}] {}", LoadText(A_ScriptDir "\missing.txt"), ReadTimeoutMs())
Print("[{}]", OpenWindowTitle("ahk_class NoSuchWindowClass"))
```

## TIER 3 — Scope and architecture
> METHODS COVERED: `Map()` · `Array` · `static` class state · `global`

Flag implicit global coupling, parallel variables that want to be a collection, and functions with
more than one job.
```ahk
#Requires AutoHotkey v2.1-alpha.30

; ✗ item1 := "apple", item2 := "banana"      pseudo-array: cannot loop or count
; ✗ configHost := "x", configPort := "y"     parallel variables standing in for a Map
; ✗ cfg := {host: "x"}                       an object literal used as a dictionary

items := ["apple", "banana", "cherry"]
for i, item in items
    Print("{}: {}", i, item)

config := Map()
config["host"] := "localhost"
config["port"] := 5432
Print("{}:{}", config["host"], config["port"])

; Shared mutable state lives in one owner instead of scattered globals
class Session {
    static HitCount := 0
    static Increment(delta := 1) {
        Session.HitCount += delta
    }
}

; One job per function, magic numbers named
MAX_RETRIES := 3
RETRY_DELAY_MS := 500

ShouldRetry(attempt) => attempt < MAX_RETRIES

Session.Increment()
Print("{} {}", Session.HitCount, ShouldRetry(1))
```

## TIER 4 — GUI and event binding
> METHODS COVERED: `Gui()` · `.OnEvent()` · `.Bind()` · `SetTimer()` · `__Delete`

The commonest Critical runtime defect is a method passed as a callback without `.Bind(this)`. A timer
turned off by reference needs that reference stored.
```ahk
#Requires AutoHotkey v2.1-alpha.30

class StatusPanel {
    status := "ready"

    __New() {
        this.ui := Gui("+Resize", "Status")
        this.btn := this.ui.AddButton("w120", "Refresh")
        this.btn.OnEvent("Click", this.OnRefresh.Bind(this))
        this.ui.OnEvent("Close", this.OnClose.Bind(this))

        this.tickFn := this.OnTick.Bind(this)
        SetTimer(this.tickFn, 1000)
    }

    OnRefresh(ctrl, info) {
        Print("status is {}", this.status)
    }

    OnTick() {
        this.status := FormatTime(, "HH:mm:ss")
    }

    OnClose(gui) {
        this.Dispose()
    }

    Dispose() {
        if !this.HasOwnProp("tickFn")
            return
        SetTimer(this.tickFn, 0)
        this.ui.Destroy()
        this.DeleteProp("tickFn")
    }

    __Delete() {
        this.Dispose()
    }
}

; ✗ this.btn.OnEvent("Click", this.OnRefresh)         unbound: `this` is the Button
; ✗ btn.OnEvent("Click", (*) => { Step1(), Step2() })  block-body arrow: load error
; ✗ SetTimer(this.OnTick.Bind(this), 0)                a fresh Bind is a different object

panel := StatusPanel()
panel.Dispose()
```

## TIER 5 — Performance and resources
> METHODS COVERED: `FileRead()` · `Map.Has()` · `ComObject()` · `static` caches

Flag work that is repeated for no reason and handles that are never released. Do not invent
performance problems: if a finding needs a number, measure it.
```ahk
#Requires AutoHotkey v2.1-alpha.30

; ✗ Loop 100 { data := FileRead("config.txt") ... }   loop-invariant disk read

CountHits(path, needle, repeats) {
    try {
        data := FileRead(path, "UTF-8")
    } catch OSError as err {
        Print("read failed: {}", err.Message)
        return 0
    }
    total := 0
    Loop repeats
        total += InStr(data, needle) ? 1 : 0
    return total
}

; Repeated membership test: build the Map once
VALID_COMMANDS := Map()
for name in ["open", "save", "close", "quit"]
    VALID_COMMANDS[name] := true

IsValidCommand(cmd) => VALID_COMMANDS.Has(cmd)

; Compile-once cache for a hot pattern
class Patterns {
    static Email := "i)^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$"
}

IsEmail(text) => RegExMatch(text, Patterns.Email) > 0

; COM: one instance outside the loop, released by dropping the reference
CountDictionaryKeys(words) {
    dict := ComObject("Scripting.Dictionary")
    for word in words
        dict.Item[word] := 1
    count := dict.Count
    dict := ""
    return count
}

; ✗ ObjRelease(dict)    the wrapper is not a raw pointer; only DllCall pointers need ObjRelease

Print("{} {} {}", CountHits(A_ScriptFullPath, "Print", 10), IsValidCommand("save"), IsEmail("a@b.co"))
Print("{}", CountDictionaryKeys(["a", "b", "a"]))
```

## TIER 6 — Readability, maintainability and composite
> METHODS COVERED: naming · dead code · `OutputDebug()` · priority list

Naming and layout rules are owned by `Module_Formatting.md`; doc-comment conventions by
`Module_JSDOC.md`. Review for what the rules cannot enforce.
```ahk
#Requires AutoHotkey v2.1-alpha.30

; ✗ x := 0, tmp2 := GetData()     names that say nothing
; ✗ class myDataManager { }       classes are PascalCase
; ✗ MsgBox("DEBUG " v)            debug output left in the shipped path
; ✗ a large commented-out function kept "just in case": version control already has it

DEBUG_MODE := false

DebugLog(msg) {
    if DEBUG_MODE
        OutputDebug("[DEBUG] " msg)
}

class DataManager {
    retryCount := 0

    Describe() => "retries: " this.retryCount
}

dm := DataManager()
DebugLog(dm.Describe())
Print("{}", dm.Describe())
```

Composing the priority list: Critical first, then Major by blast radius, at most five items, each
with the line, the defect, and the consequence in one sentence. Example:

```text
Priority action list
1. Line 24: FileRead is unguarded, a missing file ends the script (Critical)
2. Line 41: OnClick passed without .Bind(this), first this.status read throws (Critical)
3. Line 60: settings kept in six parallel globals, collapse into one Map (Major)
```

## ANTI-PATTERNS

| Pattern | Wrong | Correct | Why it happens |
|---------|-------|---------|----------------|
| Inventing throwing calls | "wrap `MsgBox` in try/catch" | Use the throwing-calls table | General defensive-coding habit |
| Hand-spotting what the parser reports | Counting `=` assignments in prose | Run `check` first and quote its diagnostics | The engine names the line for free |
| Treating a bare `x = 5` as silent | "variable stays empty, no error" | Load-time syntax error on this engine | Remembered v1 behaviour |
| Missing `.Bind(this)` described as `this` undefined | "`this` is unset in the handler" | `this` is the event source; first member read is a `PropertyError` | JavaScript callback intuition |
| Claiming a leak without evidence | "`.=` in a loop is quadratic", "CoordMode leaks" | Measure, or drop the finding | Pattern-matching on folklore |
| `ObjRelease` on a COM wrapper | `ObjRelease(comObj)` | `comObj := ""` | C-style manual memory habit |
| Omitting empty dimensions | Skip sections with no findings | Write "Pass" or "Not applicable (reason)" | Report completeness is not automatic |
| Flagging absent features | "no `.Destroy()`" on a script with no GUI | "Not applicable: no GUI present" | Checklist applied without reading the code |

## SEE ALSO

- `Module_Instructions.md` — the syntax baseline that Dimension 1 measures against.
- `Module_Errors.md` — error classes, `OnError`, try/catch/else/finally order and symptom triage.
- `Module_GUI.md` — control creation and layout behind Dimension 4.
- `Module_Classes.md` — class design and `__Delete` behind Dimensions 3 and 4.
- `Module_Formatting.md` and `Module_JSDOC.md` (Supplemental) — Dimension 6 rules.
- `Module_Validation.md` — guard-clause review criteria for Dimension 2.

<!-- Adapted from hsinming/AutoHotkey-V2-vibe-coding-tools (no license file upstream); see THIRD-PARTY.md -->
