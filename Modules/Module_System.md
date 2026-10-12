---
name: Module_System
description: 'Operating-system integration in AHK v2 that needs no COM — clipboard capture and restore
  (A_Clipboard, ClipWait, ClipboardAll), launching programs (Run, RunWait exit codes, A_ComSpec, PID
  capture), process and window wait/exists patterns with mandatory timeouts, registry read/write/delete,
  environment variables, and shutdown. TRIGGER when the request involves: A_Clipboard, ClipWait,
  ClipboardAll, Run, RunWait, "exit code", ProcessExist, ProcessWait, ProcessWaitClose, ProcessClose,
  WinWait, WinWaitActive, WinWaitClose, RegRead, RegWrite, RegDelete, RegDeleteKey, SetRegView, EnvGet,
  EnvSet, Shutdown, A_ComSpec, "start application", "kill process", "clipboard text", "write registry",
  "run at startup", "wait for window", "duplicate instance of a program", "environment variable".
  Not covered: COM automation, WMI and SafeArrays - see Module_COM.md; script directives, A_ path
  variables, elevation relaunch, tray and OnExit - see Module_ScriptEnvironment.md; raw Win32 calls -
  see Module_DllCall.md; try/catch design - see Module_Errors.md.'
---

# Module_System

_AHK v2.0+ throughout; nothing here depends on the fork. `Print()` appears in examples and is
fork-only (use `FileAppend(text "`n", "*")` on stock v2.0)._

## API QUICK-REFERENCE

### Clipboard

| Symbol | Signature | Notes |
|--------|-----------|-------|
| `A_Clipboard` | variable | Text read/write. Clear it to `""` before a copy so `ClipWait` sees the new content, not leftovers |
| `ClipWait()` | `ClipWait([Timeout, WaitForAnyData])` | Returns nonzero when the clipboard filled, `0` on timeout — check it |
| `ClipboardAll()` | `ClipboardAll([Data, Size])` | Binary snapshot of every format; assign back to `A_Clipboard` to restore |

### Launch and process

| Symbol | Signature | Notes |
|--------|-----------|-------|
| `Run()` | `Run(Target [, WorkDir, Options, &PID])` | Non-blocking; take the PID with `&PID` |
| `RunWait()` | `RunWait(Target [, WorkDir, Options, &PID])` | Blocks; **the return value is the exit code** |
| `ProcessExist()` | `ProcessExist([PIDOrName])` | PID if running, else `0` |
| `ProcessWait()` | `ProcessWait(PIDOrName [, Timeout])` | PID on success, `0` on timeout |
| `ProcessWaitClose()` | `ProcessWaitClose(PIDOrName [, Timeout])` | `0` once the process is gone, its PID if it is still running at timeout |
| `ProcessClose()` | `ProcessClose(PIDOrName)` | Force-terminates; returns the PID closed or `0` |
| `A_ComSpec` | variable | Path to `cmd.exe`; use it instead of a hard-coded name |
| `A_IsAdmin` | variable | `1` when elevated — check before a privileged change |

### Window waits

| Symbol | Signature | Notes |
|--------|-----------|-------|
| `WinExist()` | `WinExist([Title, Text, ExTitle, ExText])` | HWND or `0` |
| `WinWait()` / `WinWaitActive()` | `(Title, Text, Timeout, ...)` | HWND on success, `0` on timeout |
| `WinWaitClose()` | `(Title, Text, Timeout, ...)` | Nonzero once closed, `0` on timeout |

### Registry and environment

| Symbol | Signature | Notes |
|--------|-----------|-------|
| `RegRead()` | `RegRead([KeyName, ValueName, Default])` | Throws `OSError` for a missing key/value unless a `Default` is given |
| `RegWrite()` | `RegWrite(Value, Type, KeyName [, ValueName])` | Type: `REG_SZ`, `REG_EXPAND_SZ`, `REG_MULTI_SZ`, `REG_DWORD`, `REG_QWORD`, `REG_BINARY` |
| `RegDelete()` | `RegDelete([KeyName, ValueName])` | One value; use `RegDeleteKey` to remove a key |
| `RegDeleteKey()` | `RegDeleteKey([KeyName])` | The key, its subkeys and values |
| `SetRegView()` | `SetRegView(32 / 64 / "Default")` | Chooses the 32-bit or 64-bit registry view for later calls |
| `EnvGet()` / `EnvSet()` | `EnvGet(Name)` / `EnvSet(Name, Value)` | Process environment only; `EnvSet` does not persist or reach other processes |
| `Shutdown()` | `Shutdown(Flags)` | `0` logoff, `1` shutdown, `2` reboot, `+4` force, `+8` power down |

## AHK V2 CONSTRAINTS

- The clipboard variable is `A_Clipboard`; `Clipboard` does not exist in v2.
- Clear `A_Clipboard` before issuing the copy, then `ClipWait(timeout)` and test the result
  before reading. Without the clear, stale content satisfies the wait immediately.
- Give every `WinWait*`, `ProcessWait` and `ProcessWaitClose` a timeout. Without one, a target
  that never appears blocks the thread indefinitely.
- Take the exit status from `RunWait`'s return value; v2 does not report it through `ErrorLevel`.
- `Run` throws when it cannot launch; wrap it in `try` when the target may be absent. A
  successful `Run` only means the process started — wait for its window or an output file before
  acting.
- Registry access throws `OSError` on a missing key or insufficient rights. Use the `Default`
  argument of `RegRead` for "absent is fine"; reserve `try/catch` for real failures and log them.
- A 32-bit program's keys live under `HKLM\SOFTWARE\WOW6432Node` in the 64-bit view. Call
  `SetRegView(32)` before reading them and `SetRegView("Default")` afterwards.
- `HKLM` writes and most service changes need elevation. Test `A_IsAdmin` and relaunch with
  the pattern in `Module_ScriptEnvironment.md`; never loop on `*RunAs`.
- Quote a path that may contain spaces inside the command string: `Run('"' path '"')`.

✗ / ✓ pairs:

- ✗ `text := Clipboard` — undefined in v2
- ✓ `text := A_Clipboard`

- ✗ `Send("^c")` then `Sleep(200)` and read — races the target application
- ✓ `A_Clipboard := ""`, `Send("^c")`, `if ClipWait(2)` then read

- ✗ `Run(path)` then immediately `WinActivate(title)` — the window may not exist yet and the
  call does nothing visible
- ✓ `Run(path)` then `WinWaitActive(title,, 5)` and test the result

- ✗ `WinWait("ahk_pid " pid)` with no timeout — hangs if the process crashed
- ✓ `WinWait("ahk_pid " pid,, 10)`

## TIER 1 — Clipboard capture and restore
> COVERED: A_Clipboard · ClipWait · ClipboardAll

Save the user's clipboard, do the transfer, restore it. `ClipboardAll` keeps images and rich
text that a plain string copy would destroy.

```ahk
CopySelectionUpper() {
    saved := ClipboardAll()                 ; every format
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(2) {
        A_Clipboard := saved                ; nothing arrived; put it back
        return false
    }
    upper := StrUpper(A_Clipboard)
    A_Clipboard := upper
    Send("^v")
    Sleep(150)                              ; let the paste read the clipboard first
    A_Clipboard := saved
    return true
}
```

## TIER 2 — Launching programs and reading exit codes
> COVERED: Run · RunWait · A_ComSpec · PID capture · WinWaitActive

```ahk
; RunWait returns the exit code directly
RunCommand(cmd) {
    return RunWait(A_ComSpec ' /c "' cmd '"',, "Hide")
}

; Run, capture the PID, wait for the window with a bounded timeout
LaunchAndWait(exe) {
    try
        Run(exe,,, &pid)
    catch OSError as err {
        Print("launch failed: {}", err.Message)
        return 0
    }
    return WinWaitActive("ahk_pid " pid,, 10)    ; HWND, or 0 on timeout
}
```

## TIER 3 — Process presence and cleanup
> COVERED: ProcessExist · ProcessWait · ProcessClose · ProcessWaitClose

```ahk
; Reuse a running instance, otherwise start one and wait for its window
EnsureRunning(exeName) {
    pid := ProcessExist(exeName)
    if pid
        return pid
    Run(exeName,,, &pid)
    if !WinWait("ahk_pid " pid,, 10)
        throw TimeoutError("window did not appear for " exeName)
    return pid
}

; Ask nicely first, then force
StopProcess(name, graceMs := 3000) {
    if !ProcessExist(name)
        return
    WinClose("ahk_exe " name)
    if ProcessWaitClose(name, graceMs / 1000)    ; still running after the grace period
        ProcessClose(name)
}
```

## TIER 4 — Registry
> COVERED: RegRead default · RegWrite · RegDelete · run-at-login entry · SetRegView

```ahk
RunKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"

SetStartup(enable, name := "MyAhkScript") {
    if enable {
        try
            RegWrite('"' A_ScriptFullPath '"', "REG_SZ", RunKey, name)
        catch OSError as err
            Print("startup entry not written: {}", err.Message)
        return
    }
    try RegDelete(RunKey, name)         ; an absent entry already is the wanted end state
}

IsStartupEnabled(name := "MyAhkScript") {
    return RegRead(RunKey, name, "") != ""     ; Default means a missing value does not throw
}

; A 32-bit program's keys live in the 32-bit view
Read32BitValue(key, value) {
    SetRegView(32)
    try
        return RegRead(key, value, "")
    finally
        SetRegView("Default")
}
```

`A_ScriptFullPath` is the `.ahk` file, which starts at login only if `.ahk` is associated with
the interpreter you want. To pin the interpreter, store
`'"' A_AhkPath '" "' A_ScriptFullPath '"'` instead.

## TIER 5 — Environment and shutdown
> COVERED: EnvGet · EnvSet · Shutdown

```ahk
; Process-local environment: visible to children started afterwards, not to the system
EnvSet("MY_TOOL_MODE", "batch")
Print("path entries: {}", StrSplit(EnvGet("PATH"), ";").Length)

; Shutdown(1) powers off; add 4 to force apps closed. Guard it behind explicit consent.
ConfirmedShutdown() {
    if MsgBox("Shut down now?", "Confirm", "YesNo Icon!") = "Yes"
        Shutdown(1)
}
```

To change a user-wide or machine-wide variable, write `HKCU\Environment` (or the `HKLM`
Session Manager key) with `RegWrite`, then broadcast `WM_SETTINGCHANGE` so new processes see it —
see `Module_WinAPI.md` for `SendMessage`/`PostMessage` and `Module_DllCall.md` for calling
`SendMessageTimeout`.

## SEE ALSO

> This module does NOT cover: COM automation, WMI queries, SafeArrays → see Module_COM.md
> This module does NOT cover: script directives, A_ path variables, elevation relaunch, tray, OnExit → see Module_ScriptEnvironment.md
> This module does NOT cover: raw Win32 calls and structs → see Module_DllCall.md
> This module does NOT cover: error-class design and logging → see Module_Errors.md

- `Module_COM.md` — WMI for services and hardware; Office automation lifecycle.
- `Module_ScriptEnvironment.md` — the `A_IsAdmin` relaunch pattern that registry-write and service changes need.
- `Module_DllCall.md` — `SendMessageTimeout` for the environment-change broadcast.
- `Module_Errors.md` — `OSError` handling and what to log when a system call fails.

<!-- Adapted in part from hsinming/AutoHotkey-V2-vibe-coding-tools (no license file upstream); see THIRD-PARTY.md -->
