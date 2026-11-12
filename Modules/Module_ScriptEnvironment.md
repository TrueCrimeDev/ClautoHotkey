---
name: Module_ScriptEnvironment
description: 'The AHK v2 script shell around your code — the header (#Requires, #SingleInstance), A_ path
  and state variables, working directory versus script directory, #Include resolution and the Lib
  search order, #Import modules on v2.1-alpha.33, persistence without #Persistent, admin elevation by
  relaunch, tray menu customization, OnExit/Reload/ExitApp lifecycle, A_Args, Ahk2Exe compiler
  directives, and the +Console fork launch flags and exit codes (/Headless, /ErrorStdOut, /CrashLog,
  exit 10/11/12/130). TRIGGER when the request involves: #Requires, #SingleInstance, #Include,
  #IncludeAgain, #Import, #NoTrayIcon, A_ScriptDir, A_ScriptFullPath, A_WorkingDir, A_LineFile, A_Args,
  A_IsAdmin, A_IsCompiled, A_AhkPath, A_TrayMenu, TraySetIcon, A_IconTip, Persistent, OnExit, ExitApp,
  Reload, SetWorkingDir, Ahk2Exe, "*RunAs", "tray menu", "tray icon", "run as administrator", "UAC",
  "single instance", "script startup", "script keeps exiting", "compiled script", "exit code of a
  script", "headless run". Not covered: Run/RunWait, processes, registry, clipboard - see
  Module_System.md; GUI windows opened from the tray - see Module_GUI.md; version floors and
  portability - see Module_Versions.md; keyword and directive lookup - see Module_Instructions.md;
  error handling - see Module_Errors.md.'
---

# Module_ScriptEnvironment

_Targets v2.1-alpha.33+Console (the fork). Directives and variables are stock v2.0 unless noted._

## API QUICK-REFERENCE

### Header directives

| Directive | Notes |
|-----------|-------|
| `#Requires AutoHotkey v2.1-alpha.33` | Load-time gate; position in the file does not matter, but keep it first so readers see it. Use `v2.0` only for code that must run on stock builds (see `Module_Versions.md`) |
| `#SingleInstance Force\|Ignore\|Prompt\|Off` | Bare `#SingleInstance` means `Force`. With **no** directive the default is `Prompt`. `Off` allows parallel copies |
| `#Include File` / `#Include <Lib>` | Textual include at load time; a file already included is skipped (`#IncludeAgain` forces a repeat) |
| `#Import Name` | Module import (alpha.31+); allowed inside a function body from alpha.33 |
| `#NoTrayIcon` | Hide the tray icon |
| `#CrashLog <path>` / `#EnableEval` | Fork-only; see `Module_Versions.md` |

### Variables

| Variable | Meaning |
|----------|---------|
| `A_ScriptDir`, `A_ScriptName`, `A_ScriptFullPath` | The running script's folder (no trailing `\`), file name, full path. A compiled exe reports its own location |
| `A_WorkingDir` | Current directory; may differ from `A_ScriptDir` (shortcut "Start in", launcher) |
| `A_LineFile` | File containing the executing line; differs from `A_ScriptFullPath` inside an include |
| `A_Args` | Array of command-line arguments passed to the script |
| `A_IsAdmin`, `A_IsCompiled` | `1`/`0` |
| `A_AhkPath`, `A_AhkVersion` | Interpreter path and version; the fork reports `2.1-alpha.33+Console` |
| `A_TrayMenu`, `A_IconTip` | The tray `Menu` object; tooltip text (writable) |
| `A_ScriptHwnd` | HWND of the script's hidden main window |

### Lifecycle functions

| Function | Notes |
|----------|-------|
| `SetWorkingDir(Dir)` | Changes `A_WorkingDir` only; it does **not** move `#Include` resolution |
| `OnExit(Callback [, AddRemove])` | Callback `(ExitReason, ExitCode)`; return nonzero to cancel the exit (not for logoff/shutdown) |
| `ExitApp([Code])` | Exit with a code; runs `OnExit` callbacks |
| `Reload()` | Relaunch the script; `OnExit` callbacks see reason `"Reload"` |
| `Persistent([Value])` | Keep the script alive with no hotkeys, timers or GUI; replaces v1 `#Persistent` |
| `TraySetIcon([File, Num, Freeze])` | Set the tray icon |

## AHK V2 CONSTRAINTS

- **Instance policy is not optional to think about.** Interactive tools usually want
  `#SingleInstance Force` (new copy replaces the old). A background helper started twice by
  accident wants `Ignore`. Test scripts and anything the harness runs in parallel want `Off`.
  Omitting the directive gives the `Prompt` dialog, which hangs a headless launch.
- **A script exits when it has nothing left to run.** Hotkeys, hotstrings, timers, GUI windows,
  `OnMessage` handlers, `InputHook`s and a tray menu with callbacks keep it alive. A script
  made of only function definitions and top-level code ends at the last line; call
  `Persistent()` when it should wait for external events such as `ComObjConnect` or a
  `WM_COPYDATA` message.
- **A relative `#Include` resolves against the folder of the file that contains the directive**
  (for the main script, `A_ScriptDir`), never against `A_WorkingDir`. `SetWorkingDir` cannot
  break an include, and the same `#Include Lib\Utils.ahk` works from any launch directory,
  compiled or not. Verified on the fork: `sub\a.ahk` containing `#Include b.ahk` loads
  `sub\b.ahk`. `%A_ScriptDir%` is accepted and explicit but not required. `#Include "dir\"`
  (a folder) changes the directory later relative includes resolve against.
- `#Include <Name>` searches, in order, `A_ScriptDir\Lib`, `A_MyDocuments\AutoHotkey\Lib`, then
  the interpreter's own `Lib`. Use `*i` (`#Include "*i optional.ahk"`) to skip a missing file.
- **Do not `#Include` a second copy of a library with the same class names.** The second copy
  redefines the class and fails to load. Include the canonical file once.
- **Modules (alpha.31+).** The `export` keyword is gone: every module-level name is exported,
  and names starting with `_` are skipped by `{*}`. A file is a module named by its filename
  (`#Import Win32` loads `Win32.ahk`), so do not put `#Module Win32` inside it. On alpha.33
  `#Import` may sit inside a function, scoping the names to that function. Do not take
  `&Module.Var` from outside the module; write with `Mod.X := v` or call an exported function.
- **Elevation is a relaunch, not a switch.** A running process cannot raise its own token.
  Guard on `A_IsAdmin`, relaunch with the `*RunAs` verb, and `ExitApp()` straight away. The
  guard is what stops a loop; a denied UAC prompt makes `Run` throw `OSError`, which you must
  catch (see TIER 4).
- An unelevated script cannot send input to, or hotkey over, an elevated window. If a hotkey
  is dead only over one program, check `A_IsAdmin` first.
- **Tray callbacks and `OnExit` callbacks are invoked without your object.** A method used as a
  callback must be bound: `this.Cleanup.Bind(this)`, or `ObjBindMethod(this, "Cleanup")`.
- **`OnExit` must be quick.** At logoff or shutdown Windows terminates a process that does not
  finish promptly, so a handler that waits on a network call or a dialog is cut off. Write small
  state, close handles, return.
- There is no `Menu, Tray, ...` command and no `DeleteStandard`. `A_TrayMenu.Delete()` with no
  argument removes everything, standard items included; delete named items to keep the rest.
- Ahk2Exe directives (`;@Ahk2Exe-SetVersion ...`) are comments to the interpreter and are read
  only by the compiler. Put them in the header so they are easy to find.
- Keep app-wide constants (name, version, log path) in one `class AppConfig { static ... }` rather
  than scattering string literals.

✗ / ✓ pairs:

- ✗ `Run('*RunAs "' A_ScriptFullPath '"')` unguarded, then continuing — the denied or looping
  relaunch case
- ✓ `if !A_IsAdmin { relaunch; ExitApp() }` inside `try`

- ✗ `A_TrayMenu.Add("Status", app.ShowStatus)` — `this` is not set inside `ShowStatus`
- ✓ `A_TrayMenu.Add("Status", app.ShowStatus.Bind(app))`

- ✗ relying on `#Persistent` — removed in v2
- ✓ a hotkey, timer or GUI, or an explicit `Persistent()`

## TIER 1 — The script header and where files are
> COVERED: #Requires · #SingleInstance · A_ScriptDir · A_WorkingDir · A_LineFile

```ahk
#Requires AutoHotkey v2.1-alpha.33
#SingleInstance Force

class AppConfig {
    static Name := "MyApp"
    static Version := "1.0.0"
    static LogFile := A_ScriptDir "\Logs\app.log"
}

ShowEnvironment() {
    Print("script dir  : {}", A_ScriptDir)
    Print("working dir : {}", A_WorkingDir)
    Print("this file   : {}", A_LineFile)
    Print("compiled    : {}", A_IsCompiled ? "yes" : "no")
    Print("admin       : {}", A_IsAdmin ? "yes" : "no")
    Print("version     : {}", A_AhkVersion)
    Print("args        : {}", A_Args.Length)
}
ShowEnvironment()
```

When the script must work with relative file names, anchor once at startup:
`SetWorkingDir(A_ScriptDir)`. Do that only for file access you control; it changes behaviour of
anything else in the process that uses relative paths.

## TIER 2 — Include and import
> COVERED: #Include forms · Lib search · #Import in a function

```ahk
#Include Lib\StringUtils.ahk            ; relative to the script folder
#Include "*i Lib\Optional.ahk"          ; no error if the file is absent
#Include <Logger>                       ; Lib\Logger.ahk by the search order above

; alpha.33: a module import scoped to one function. Helpers.ahk is a module named by its
; filename and exports every top-level name, e.g. Greet(name) and class Counter.
ReportGreeting() {
    #Import Helpers
    Print(Helpers.Greet("world"))
}
```

Functions and classes are defined at load, so include order only matters for top-level
statements that use them. Put the entry-point call at the bottom of the main file.

## TIER 3 — Tray menu
> COVERED: A_TrayMenu · A_IconTip · TraySetIcon · bound callbacks

```ahk
class TrayApp {
    __New(name) {
        this.name := name
        this.paused := false
        A_IconTip := name " - running"
        A_TrayMenu.Delete()                          ; drop the standard items
        A_TrayMenu.Add("Status", this.ShowStatus.Bind(this))
        A_TrayMenu.Add("Pause", this.TogglePause.Bind(this))
        A_TrayMenu.Add()                             ; separator
        A_TrayMenu.Add("Exit", (*) => ExitApp())
        A_TrayMenu.Default := "Status"               ; double-click the icon
    }

    ShowStatus(*) {
        MsgBox(this.name " is " (this.paused ? "paused" : "running"))
    }

    TogglePause(itemName, *) {
        this.paused := !this.paused
        A_TrayMenu.Rename(itemName, this.paused ? "Resume" : "Pause")
        A_IconTip := this.name " - " (this.paused ? "paused" : "running")
    }
}

app := TrayApp("MyApp")
```

Tray callbacks receive `(ItemName, ItemPos, Menu)`; declare trailing `*` to ignore what you
do not use. Build the menu once at startup, not from a timer or hotkey.

## TIER 4 — Elevation by relaunch
> COVERED: A_IsAdmin · *RunAs · compiled versus interpreted command line · A_Args

```ahk
EnsureAdmin() {
    if A_IsAdmin
        return
    try {
        args := ""
        for arg in A_Args
            args .= ' "' arg '"'
        if A_IsCompiled
            Run('*RunAs "' A_ScriptFullPath '"' args)
        else
            Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"' args)
    } catch OSError as err {
        MsgBox("Administrator rights are required.`n`n" err.Message, "Elevation failed", "Icon!")
    }
    ExitApp()                       ; both outcomes end this unelevated copy
}

EnsureAdmin()
```

A compiled exe is its own interpreter, so it relaunches itself; an `.ahk` file must be handed
to `A_AhkPath`. Arguments are forwarded so the elevated copy sees the same `A_Args`.

## TIER 5 — Lifecycle: OnExit, Reload, exit codes
> COVERED: OnExit reasons · ExitApp codes · Reload · Persistent

`OnExit` fires for every exit path: `Exit`/`ExitApp`, a script error, `Reload`, a window close,
`Logoff` and `Shutdown`. The reason string says which. The fork's launcher exit codes build on
the same mechanism: an uncaught exception ends the process with `10`, an internal fault `11`, a
load failure `12`, Ctrl+C/Break/close/logoff/shutdown `130`; your own `ExitApp(n)` returns `n`.

```ahk
class Service {
    __New() {
        this.started := A_TickCount
        OnExit(this.Shutdown.Bind(this))
    }

    Shutdown(reason, code) {
        try FileAppend(Format("{} reason={} code={}`n", A_Now, reason, code), A_Temp "\svc-exit.log")
        return 0                    ; allow the exit
    }
}

svc := Service()
Persistent()                        ; nothing else keeps this script alive
```

A callback that returns nonzero cancels a user-initiated exit (a close request, `ExitApp`) but
cannot stop `Logoff` or `Shutdown`. Use `Reload()` to restart after a config change; the
callback then sees reason `"Reload"` and can skip work that only makes sense on a real exit.

## TIER 6 — Running scripts from a harness (fork)
> COVERED: /ErrorStdOut · /Headless · /CrashLog · /StdErrFile · exit-code checks

A script launched by a test runner, scheduler or another script has no person at a keyboard.
Prepare for that:

- `#SingleInstance Off` (or `Force` with care) so a stale copy cannot trigger a `Prompt`.
- No `MsgBox` on the normal path; report with `Print` (stdout) and the exit code.
- Launch with `/ErrorStdOut` so load and runtime errors go to stderr instead of a dialog,
  and `/Headless` so nothing needs a visible desktop.
- Add `/CrashLog=<abs path>` and `/StdErrFile=<abs path>` when the run is unattended; a silent
  exit then leaves a `[EXIT] code=... reason=...` record.
- Branch on the exit code: `0` normal, `10` uncaught exception, `11` internal fault,
  `12` parse failure, `130` signalled. The script itself should call `ExitApp(n)` with its own
  small, documented codes for expected failures, away from the reserved values.

```ahk
; run one step and translate the result into an exit code
Main() {
    try {
        result := DoWork()
        Print("result: {}", result)
        ExitApp(0)
    } catch Error as err {
        Print("failed: {}", err.Message)
        ExitApp(2)                  ; expected failure, distinct from the reserved codes
    }
}

DoWork() {
    return 42
}

if A_LineFile = A_ScriptFullPath    ; run only when this file is the entry script
    Main()
```

Invocation (PowerShell, pipe so the GUI-subsystem exe is awaited):

```powershell
& "$env:USERPROFILE\Documents\Design\Coding\AutoHotkey\bin\AutoHotkey64.exe" /Headless /ErrorStdOut "C:\path\script.ahk" | Out-String
```

## TIER 7 — Compiled scripts
> COVERED: A_IsCompiled · Ahk2Exe directives

```ahk
;@Ahk2Exe-SetMainIcon Assets\app.ico
;@Ahk2Exe-SetVersion 1.2.0
;@Ahk2Exe-SetProductName MyApp
;@Ahk2Exe-SetCompanyName Example Co
;@Ahk2Exe-SetDescription Automation tool

#Requires AutoHotkey v2.1-alpha.33

; Compiled and interpreted both answer A_ScriptDir with the folder holding the program
DataPath(name) {
    return A_ScriptDir "\" name
}
```

Resources added with `;@Ahk2Exe-AddResource file, name` are read back at run time through the
Windows resource API (`DllCall`), not through `FileRead`. Read build-time-only settings with
`A_IsCompiled` so dev-only code can be skipped in the shipped exe.

## SEE ALSO

> This module does NOT cover: Run, RunWait, process and registry work → see Module_System.md
> This module does NOT cover: windows opened from the tray → see Module_GUI.md
> This module does NOT cover: version floors and fork feature gates → see Module_Versions.md
> This module does NOT cover: error-class design → see Module_Errors.md

- `Module_System.md` — what an elevated script usually does next (registry, processes).
- `Module_Versions.md` — choosing the `#Requires` floor, `/CrashLog` and `/StdErrFile` details.
- `Module_Instructions.md` — the directive and keyword reference.
- `Module_Errors.md` — catching the `OSError` from a denied UAC prompt, logging in `OnExit`.
- `Module_GUI.md` — GUI windows a tray item opens.

<!-- Adapted in part from hsinming/AutoHotkey-V2-vibe-coding-tools (no license file upstream); see THIRD-PARTY.md -->
