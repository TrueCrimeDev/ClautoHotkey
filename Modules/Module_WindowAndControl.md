---
name: Module_WindowAndControl
description: 'Driving windows and controls of other programs in AHK v2 - WinTitle forms and HWND handling, WinExist,
  WinActivate, WinWait, WinWaitClose, WinGetList and metadata, WinMove and tiling with MonitorGetWorkArea,
  hidden windows and DetectHiddenWindows, GroupAdd groups, SetTitleMatchMode, SetWinDelay, Control functions
  (ControlSend, ControlClick, ControlSetText, ControlGetItems, ControlChooseIndex), TargetError handling,
  and event-driven window monitoring with a SetWinEventHook class. TRIGGER when the request involves:
  WinExist, WinActive, WinActivate, WinClose, WinWait, WinWaitActive, WinWaitClose, WinGetList, WinGetPos,
  WinMove, WinHide, WinShow, WinSetAlwaysOnTop, WinSetTransparent, GroupAdd, GroupActivate, ahk_id,
  ahk_class, ahk_exe, ahk_group, HWND, ControlSend, ControlClick, ControlGetText, ControlSetText,
  ControlGetItems, ControlChooseIndex, TargetError, SetWinEventHook, "wait for a window", "detect when a
  window opens", "click a button in the background", "send keys to a background window", "tile windows",
  "list open windows". Not covered: SendMessage, PostMessage, OnMessage and subclassing - see Module_WinAPI.md;
  UI Automation for Chromium, WPF and UWP controls - see Module_UIA.md; Gui windows the script creates itself - see
  Module_GUI.md; hotkeys and Send - see Module_InputAndHotkeys.md; screen coordinates and DPI - see
  Module_GraphicsAndScreen.md.'
---

# Module_WindowAndControl

Targets AutoHotkey v2.1-alpha.33+Console. The blocks in this module act on other programs' windows, so
check them with the parser; do not run them unattended.

## Rules that decide most bugs

- Window functions accept a title string with criteria (`"Untitled ahk_class Notepad"`, `ahk_exe`,
  `ahk_pid`, `ahk_id`, `ahk_group`, `"A"` for the active window), a pure Integer HWND, or any object with
  an `Hwnd` property such as a Gui. Resolve once, keep the Integer, and pass it directly:
  `WinActivate(hwnd)`. There is no need to build `"ahk_id " hwnd` strings. A pure HWND also finds hidden
  windows regardless of `DetectHiddenWindows`.
- HWNDs are Integers. Test with `if hwnd` or `if (hwnd = 0)`; numeric strings compare equal to numbers, so
  string comparison is not the failure mode, but never keep a stale HWND and assume it is still valid.
- Failure behaviour differs by function:

| Function | Window not found |
|----------|------------------|
| `WinExist`, `WinActive` | returns 0 |
| `WinWait`, `WinWaitActive` | returns 0 on timeout (an invalid pure HWND returns at once) |
| `WinWaitClose` | returns 0 on timeout, 1 once the window is gone |
| `WinGetList` | returns an empty Array |
| `WinActivate`, `WinClose`, `WinMove`, `WinGetTitle`, `WinGetPos`, `WinSet...`, all `Control...` | throws `TargetError` |

- A window can vanish between any two statements. `WinExist` before the call narrows the race but does
  not remove it; wrap calls whose target you do not own in `try ... catch TargetError`, and handle the
  catch (return, retry, report) instead of leaving it empty.
- `WinClose` throws nothing when a window is found but refuses to close. Confirm with `WinWaitClose`.
- Omitting `WinTitle` means the Last Found Window, which is whatever the last successful `WinExist`,
  `WinWait` or `WinActivate` matched in this thread. Pass the HWND explicitly to avoid surprises.
- `SetTitleMatchMode` defaults to 2 (substring), is per thread, and each new hotkey or timer thread starts
  fresh from the value set in the auto-execute section. Title matching is case-sensitive. Only `RegEx` mode
  changes how `ahk_class` and `ahk_exe` match. Do not flip the mode inside shared helper functions.
- `DetectHiddenWindows` is also per thread and defaults to off; `DetectHiddenText` defaults to on.
- Most window functions sleep afterwards: `A_WinDelay` is 100 ms and `A_ControlDelay` is 20 ms. In a loop
  over many windows call `SetWinDelay(-1)` (and `SetControlDelay(-1)`), and restore it if the thread goes on.
- Elevated and UWP targets: a non-elevated script cannot drive an elevated window, and many UWP,
  Chromium and WPF controls do not answer `Control...` messages at all. Use UI Automation (Module_UIA.md).

## Finding, waiting and closing

```ahk
#Requires AutoHotkey v2.1-alpha.30

hwnd := WinExist("ahk_exe notepad.exe")
if hwnd {
    if (WinGetMinMax(hwnd) = -1) {
        WinRestore(hwnd)
    }
    WinActivate(hwnd)
    if !WinWaitActive(hwnd, , 3) {
        ToolTip("activation timed out")
        SetTimer(() => ToolTip(), -1500)
    }
}

; Start a program and block until its window exists
OpenAndWait(command, winTitle, seconds := 15) {
    Run(command)
    hwnd := WinWait(winTitle, , seconds)
    if !hwnd {
        throw TimeoutError("window did not appear: " winTitle)
    }
    return hwnd
}

; Close and confirm; a window that already vanished counts as closed
CloseAndConfirm(hwnd, seconds := 5) {
    try {
        WinClose(hwnd)
    } catch TargetError {
        return true
    }
    return WinWaitClose(hwnd, , seconds)
}
```

`WinGetMinMax` returns -1 minimized, 0 normal, 1 maximized. `WinMove` on a maximized or minimized window
does nothing useful; restore it first. `WinActivate` can be refused by the foreground lock; follow it with
`WinWaitActive`.

To wait for the next new window of a program, diff two `WinGetList` snapshots rather than polling for a
title:

```ahk
#Requires AutoHotkey v2.1-alpha.30

WaitForNewWindow(criteria, seconds := 10) {
    known := Map()
    for hwnd in WinGetList(criteria) {
        known[hwnd] := true
    }
    deadline := A_TickCount + seconds * 1000
    while (A_TickCount < deadline) {
        for hwnd in WinGetList(criteria) {
            if !known.Has(hwnd) {
                return hwnd
            }
        }
        Sleep(100)
    }
    return 0
}
```

For a one-off wait, `WinWait` is the right primitive and costs nothing while it waits; other threads
(hotkeys, timers) keep running. Use the diff above only when the title is unknown or already matches an
existing window. When the reaction must be instant for windows you cannot predict, use the event hook at
the end of this module.

## Metadata and listing

```ahk
#Requires AutoHotkey v2.1-alpha.30

DescribeWindow(hwnd) {
    info := Map()
    info["hwnd"] := hwnd
    info["title"] := WinGetTitle(hwnd)
    info["class"] := WinGetClass(hwnd)
    info["exe"] := WinGetProcessName(hwnd)
    info["pid"] := WinGetPID(hwnd)
    WinGetPos(&x, &y, &w, &h, hwnd)
    info["rect"] := [x, y, w, h]
    return info
}

; Array of Maps for every matching window with a title; criteria "" means all
ListWindows(criteria := "") {
    rows := []
    hwnds := (criteria = "") ? WinGetList() : WinGetList(criteria)
    for hwnd in hwnds {
        try {
            row := DescribeWindow(hwnd)
        } catch TargetError {
            continue
        }
        if (row["title"] != "") {
            rows.Push(row)
        }
    }
    return rows
}
```

- Match by `ahk_exe` or `ahk_class`; titles change with the document, locale and app version.
- `WinGetPos` returns the outer window rectangle in physical pixels, including the invisible resize
  frame that Windows 10 and 11 add on the left, right and bottom. `WinGetClientPos` gives the client area.
  `WinGetPos` on `"Program Manager"` returns the desktop size.
- `WinGetControls` and `WinGetControlsHwnd` list the child controls of a window.

## Moving, sizing and visibility

```ahk
#Requires AutoHotkey v2.1-alpha.30

; Tile windows side by side across one monitor's work area (the taskbar is excluded)
TileOnMonitor(hwnds, monitorN := 1) {
    if (hwnds.Length = 0) {
        return
    }
    MonitorGetWorkArea(monitorN, &left, &top, &right, &bottom)
    colW := (right - left) // hwnds.Length
    oldDelay := SetWinDelay(-1)
    for i, hwnd in hwnds {
        if (WinGetMinMax(hwnd) != 0) {
            WinRestore(hwnd)
        }
        WinMove(left + (i - 1) * colW, top, colW, bottom - top, hwnd)
    }
    SetWinDelay(oldDelay)
}

; Hide windows, then show them again later by HWND (hidden windows are invisible to
; WinGetList unless DetectHiddenWindows is on, but a pure HWND still finds them)
hiddenList := []

HideMatching(criteria) {
    global hiddenList
    for hwnd in WinGetList(criteria) {
        WinHide(hwnd)
        hiddenList.Push(hwnd)
    }
}

ShowHidden() {
    global hiddenList
    for hwnd in hiddenList {
        if WinExist(hwnd) {
            WinShow(hwnd)
        }
    }
    hiddenList := []
}
```

- `WinSetAlwaysOnTop(1, hwnd)` pins, `0` clears, `-1` toggles. `WinSetTransparent(200, hwnd)` sets alpha
  0-255; restore with `"Off"`, not 255, which keeps the layered-window overhead.
- `SetWinDelay` returns the previous value, which is what makes the save and restore above work.
- `WinMove` takes physical pixels. A Gui uses logical units scaled by DPI; do not mix them (see
  Module_GUI.md and Module_GraphicsAndScreen.md).
- Snapping windows to the visible edge: because of the invisible frame, a window moved to `left` looks a few
  pixels short of the edge. Read the visible bounds with `DwmGetWindowAttribute` (attribute 9) and offset.

## Window groups

A group stores criteria, not windows, and is evaluated each time it is used. Every window function
accepts `ahk_group Name`.

```ahk
#Requires AutoHotkey v2.1-alpha.30

GroupAdd("Editors", "ahk_exe notepad.exe")
GroupAdd("Editors", "ahk_exe Code.exe")

^!Tab::GroupActivate("Editors")
^!+Tab::GroupActivate("Editors", "R")

MinimizeEditors() {
    WinMinimize("ahk_group Editors")
}

CountEditors() {
    return WinGetList("ahk_group Editors").Length
}
```

- `WinMinimize`, `WinMaximize`, `WinRestore`, `WinHide`, `WinShow`, `WinClose` and `WinKill` operate on every
  member when given `ahk_group`, so a loop over `WinGetList` is only needed to do something per window.
  `WinActivate` and `WinExist` use only the topmost member.
- `GroupActivate(name)` activates the oldest member and steps on at each call. Mode `"R"` activates the most
  recently used member when no group member is active. It does not reverse the direction.
- `DetectHiddenWindows` and `SetTitleMatchMode` apply when the group is used, not when `GroupAdd` ran.

## Controls

The `Control` parameter is a ClassNN (`"Edit1"`), the control's text, an HWND, or an object with an `Hwnd`
property. ClassNN numbering changes with app version and window state, so resolve a control once and reuse
its HWND where you can.

```ahk
#Requires AutoHotkey v2.1-alpha.30

; Dump every control with its text, for finding stable identifiers
DumpControls(win) {
    rows := []
    for classNN in WinGetControls(win) {
        row := Map()
        row["classNN"] := classNN
        try {
            row["text"] := ControlGetText(classNN, win)
        } catch TargetError {
            row["text"] := ""
        }
        rows.Push(row)
    }
    return rows
}

; Edit controls: replace all text, or insert at the caret
SetEditText(win, text, ctrl := "Edit1") {
    ControlSetText(text, ctrl, win)
}

InsertAtCaret(win, text, ctrl := "Edit1") {
    EditPaste(text, ctrl, win)
}

; Background click that does not activate the window
ClickButton(win, ctrl := "Button1") {
    SetControlDelay(-1)
    ControlClick(ctrl, win, , "Left", 1, "NA")
}

; List and combo boxes
SelectByExactName(win, ctrl, name) {
    items := ControlGetItems(ctrl, win)
    for i, item in items {
        if (item = name) {
            ControlChooseIndex(i, ctrl, win)
            return i
        }
    }
    return 0
}

SetCheckbox(win, ctrl, checked) {
    ControlSetChecked(checked ? 1 : 0, ctrl, win)
}
```

- `ControlSetText` replaces the whole text and does not generate key events. Use `EditPaste` to insert,
  and `ControlSend` when the program must see keystrokes. Multi-line text in Edit controls needs `` `r`n ``
  line breaks. `ControlGetText` does not read ListView, ListBox or ComboBox contents; use `ControlGetItems`
  (an Array, 1-based).
- `ControlChooseIndex(n, ...)` is 1-based; `0` deselects. `ControlChooseString(str, ...)` selects the first
  entry that starts with the string (case-insensitive prefix, not substring) and returns its index. `ControlGetIndex`
  and `ControlGetChoice` read the selection.
- `ControlSend(keys, ctrl, win)` works without activating the window and uses `SetKeyDelay` for pacing. It
  cannot send mouse clicks; use `ControlClick`. `ControlSendText` sends literal text. With the `Control`
  argument omitted the keys go to the window's top control. When Alt would open a menu or a console window
  needs real modifier events, send explicit down and up: `ControlSend("{Alt down}f{Alt up}", ctrl, win)`.
- `ControlClick` with `"NA"` and `SetControlDelay(-1)` is the reliable pair when the user may be moving the
  mouse. Its options take click-relative `X` and `Y`; position mode (`"X55 Y33"` as the first argument)
  uses the window's client area. Click coordinates are never affected by `CoordMode`.
- A `Control...` call returns nothing about whether the program reacted. Confirm by reading state back
  (`ControlGetText`, `ControlGetChecked`) or by waiting for the expected window.
- For anything the Control functions cannot reach (menus, owner-drawn lists), send the window message
  yourself; see Module_WinAPI.md for `SendMessage` and `PostMessage`.

## Reacting to windows without polling

`SetWinEventHook` delivers window events to a callback with no polling cost. The class below owns the
hook and the machine-code callback. Measured on this build: an object that passes a bound method to
`CallbackCreate` keeps itself alive, so `__Delete` never runs on its own. Call `Dispose()` explicitly.

```ahk
#Requires AutoHotkey v2.1-alpha.30

class WinEventHook {
    static OUTOFCONTEXT := 0x0000
    static SKIPOWNPROCESS := 0x0002

    __New(eventMin, eventMax, handler, pid := 0) {
        this.handler := handler
        this.cb := CallbackCreate(this.Proc.Bind(this), "Fast", 7)
        this.hook := DllCall("user32\SetWinEventHook"
            , "UInt", eventMin, "UInt", eventMax, "Ptr", 0, "Ptr", this.cb
            , "UInt", pid, "UInt", 0
            , "UInt", WinEventHook.OUTOFCONTEXT | WinEventHook.SKIPOWNPROCESS, "Ptr")
        if !this.hook {
            CallbackFree(this.cb)
            this.cb := 0
            throw OSError("SetWinEventHook failed")
        }
    }

    ; WINEVENTPROC: seven arguments, idObject 0 means the window itself
    Proc(hHook, event, hwnd, idObject, idChild, threadId, timeMs) {
        if ((idObject & 0xFFFFFFFF) != 0 || !hwnd) {
            return
        }
        this.handler.Call(event & 0xFFFFFFFF, hwnd)
    }

    Dispose() {
        if this.hook {
            DllCall("user32\UnhookWinEvent", "Ptr", this.hook)
            this.hook := 0
        }
        if this.cb {
            CallbackFree(this.cb)
            this.cb := 0
        }
    }
}

OnForeground(event, hwnd) {
    try {
        OutputDebug("foreground: " WinGetTitle(hwnd))
    } catch TargetError {
        return
    }
}

OnWindowCreated(event, hwnd) {
    try {
        if (WinGetClass(hwnd) = "#32770") {
            OutputDebug("dialog opened: " WinGetTitle(hwnd))
        }
    } catch TargetError {
        return
    }
}

; EVENT_SYSTEM_FOREGROUND 0x0003, EVENT_OBJECT_CREATE 0x8000, EVENT_OBJECT_DESTROY 0x8001
foregroundHook := WinEventHook(0x0003, 0x0003, OnForeground)
createdHook := WinEventHook(0x8000, 0x8000, OnWindowCreated)

CleanUp(*) {
    foregroundHook.Dispose()
    createdHook.Dispose()
}
OnExit(CleanUp)
```

- Subscribe to the narrowest event range you need. `eventMin` to `eventMax` covers every id in between,
  and the range 0x0003 to 0x8001 would deliver thousands of unrelated events.
- Create events fire for every object, not just top-level windows; the `idObject = 0` filter keeps windows
  only, and a class check (`#32770` is the standard dialog class) narrows further.
- The callback runs on the script's message loop, so the script must be able to pump messages (a normal
  persistent script does). Keep the handler short.
- Windows removes the hook when the process exits, so `OnExit` cleanup is tidiness, not a leak fix.
- An alternative for create, destroy and activate notifications is a shell hook window with `OnMessage`;
  see Module_WinAPI.md for message handling.

## Mistakes seen in generated code

| Mistake | Fix |
|---------|-----|
| `WinActivate, ahk_id %hwnd%` | `WinActivate(hwnd)` |
| `ControlClick, Button1, Title` | `ControlClick("Button1", "Title")` |
| `GroupActivate(name, "R")` to cycle backwards | `"R"` means most recent; there is no reverse |
| `ControlChooseString` as a substring match | It is a case-insensitive prefix match |
| `ControlChooseIndex(0, ...)` to pick the first item | 1-based; 0 deselects |
| `WinGetList("ahk_group G")` then `WinShow` expecting hidden windows to be listed | Collect HWNDs before hiding, or turn on `DetectHiddenWindows` |
| `SetTitleMatchMode(1)` "restored" after a helper | The default is 2; read the old value from `A_TitleMatchMode` |
| No `TargetError` handling on another program's window | Catch it where the window is not yours |
| `CallbackCreate(this.Method, ...)` | `CallbackCreate(this.Method.Bind(this), ...)` and an explicit `Dispose()` |
| Relying on `__Delete` to unhook | Call `Dispose()` from `OnExit` or the owner |
| Poll loop `while !WinExist(...) Sleep(100)` | `WinWait(title, , seconds)` |

## See also

- Module_WinAPI.md - SendMessage, PostMessage, OnMessage, subclassing, DWM.
- Module_UIA.md - controls that expose no Win32 handles.
- Module_InputAndHotkeys.md - Send, SetKeyDelay, hotkeys that trigger window actions.
- Module_GraphicsAndScreen.md - monitors, work areas, DPI and CoordMode.
- Module_DllCall.md - DllCall, CallbackCreate and Buffer rules used by the hook class.
- Module_Errors.md - TargetError and error-handling structure.

<!-- Adapted from hsinming/AutoHotkey-V2-vibe-coding-tools (no license file upstream); see THIRD-PARTY.md -->
