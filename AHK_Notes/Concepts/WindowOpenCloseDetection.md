# Topic: Detecting Window Open and Close Events

## Category

Concept

## Overview

Detecting when specific windows are opened or closed is a common requirement in AutoHotkey scripts. Multiple methods exist to accomplish this, each with different strengths and weaknesses. This document outlines various approaches to window event detection, from simple blocking methods to advanced event-driven techniques with minimal resource usage.

## Key Points

- Multiple methods exist for detecting window open/close events
- Methods vary in complexity, resource usage, and functionality
- Some methods block script execution, while others are event-driven
- Some techniques can also detect other window events (minimize, maximize, move)
- Advanced methods can intercept and modify window behavior

## Syntax and Parameters

```cpp
; Method 1: WinWait and WinWaitClose
winId := WinWait("winTitle", "winText", timeout)
WinWaitClose("winTitle", "winText", timeout)

; Method 2: SetTimer with WinExist
SetTimer(CheckWindowFunction, period)

; Method 3: SetWinEventHook
hook := WinEventHook(CallbackFunction, EventType)

; Method 4: ShellHook
DllCall("RegisterShellHookWindow", "UInt", A_ScriptHwnd)
OnMessage(DllCall("RegisterWindowMessage", "Str", "SHELLHOOK"), ShellMessageHandler)

; Method 5: UIAutomation
handler := UIA.CreateAutomationEventHandler(CallbackFunction)
```

## Code Examples

```cpp
; Example 1: WinWait - Simplest approach but blocks script execution
#Requires AutoHotkey v2

Loop {
    winId := WinWait("ahk_exe notepad.exe")
    ToolTip(WinGetTitle(winId) " window created")
    WinWaitClose("ahk_exe notepad.exe")
    ToolTip("Notepad window closed")
}

; Example 2: SetTimer - Non-blocking but polls constantly
#Requires AutoHotkey v2

SetTimer(CheckNotepad, 250)  ; Check every 250ms
Persistent()

CheckNotepad() {
    static lastExist := !!WinExist("ahk_exe notepad.exe")
    if lastExist = !!WinExist("ahk_exe notepad.exe")
        return
    if (lastExist := !lastExist)
        ToolTip("Notepad opened")
    else
        ToolTip("Notepad closed")
}

; Example 3: SetWinEventHook - Event-driven, efficient approach
#Requires AutoHotkey v2

; Track open windows
global gOpenWindows := Map()
for hwnd in WinGetList()
    try gOpenWindows[hwnd] := {title: WinGetTitle(hwnd), processName: WinGetProcessName(hwnd)}

; Set up event hook
global EVENT_OBJECT_CREATE := 0x8000, EVENT_OBJECT_DESTROY := 0x8001
hook := WinEventHook(HandleWinEvent, EVENT_OBJECT_CREATE, EVENT_OBJECT_DESTROY)
Persistent()

HandleWinEvent(hWinEventHook, event, hwnd, idObject, idChild, *) {
    global gOpenWindows, EVENT_OBJECT_CREATE, EVENT_OBJECT_DESTROY
    
    if (event = EVENT_OBJECT_CREATE) {
        try {
            info := {title: WinGetTitle(hwnd), processName: WinGetProcessName(hwnd)}
            gOpenWindows[hwnd] := info
            
            if info.processName = "notepad.exe"
                ToolTip("Notepad window created")
        }
    } else if (event = EVENT_OBJECT_DESTROY) {
        if gOpenWindows.Has(hwnd) {
            if gOpenWindows[hwnd].processName = "notepad.exe"
                ToolTip("Notepad window closed")
                
            gOpenWindows.Delete(hwnd)
        }
    }
}
```

## Implementation Notes

### Method 1: WinWait and WinWaitClose
- **Pros**: Simplest to implement, minimal code required
- **Cons**: Blocks script execution until window appears/closes
- **Usage**: Best for sequential tasks where waiting is acceptable
- **Tip**: Use ahk_group to wait for multiple window types
- **Caution**: If using a timeout, check that WinWait returns a non-zero value before using it

### Method 2: SetTimer
- **Pros**: Non-blocking, works with any script
- **Cons**: Resource intensive, constant polling, may miss brief events
- **Usage**: Good for simple scripts where performance isn't critical
- **Tip**: Store the last known window state to detect changes
- **Note**: For multiple windows, requires tracking all windows and checking differences

### Method 3: SetWinEventHook
- **Pros**: Event-driven, efficient, no polling required
- **Cons**: More complex implementation
- **Usage**: Recommended for most scenarios, especially when monitoring many windows
- **Note**: Some windows don't update their titles immediately; may need a slight delay (40-100ms)
- **Events**: Can detect not just creation/destruction but also minimize/maximize/move/etc.

### Method 4: ShellHook
- **Pros**: Event-driven, simple implementation
- **Cons**: Microsoft documents it as deprecated
- **Usage**: Works well but SetWinEventHook is generally preferred
- **Note**: Requires tracking open windows to know their titles after closure

### Method 5: UIAutomation
- **Pros**: Modern accessibility interface with robust event detection
- **Cons**: Requires UIA library, more complex implementation
- **Usage**: Good for advanced accessibility scenarios
- **Note**: Window_WindowClosed event isn't reliably triggered by all windows

### Method 6: SetWindowsHookEx
- **Pros**: Can intercept and modify window events, not just detect them
- **Cons**: Complex implementation, potential system risks, requires DLL
- **Usage**: Advanced scenarios where intercepting/blocking window actions is needed
- **Caution**: Improper implementation can freeze the system

### Special Considerations
- **Window Titles**: Some windows don't update their titles immediately after creation
- **Multiple Windows**: For tracking multiple windows, maintain a list of open windows
- **Title Tracking**: After a window closes, its title is no longer available; track it beforehand
- **Resource Usage**: Event-driven methods (3-5) use minimal resources when idle
- **Reliability**: No single method works perfectly for all windows; test your specific target

## Related AHK Concepts

- WinExist/WinActive - Basic window detection functions
- WinGetList - Retrieve list of all windows
- WinGetTitle/WinGetProcessName - Get window information
- OnMessage - Process Windows messages
- CallbackCreate - Create callback functions for Windows API
- Critical - Control thread critical sections for event handlers
- DllCall - Interface with Windows API functions

## Tags

#AutoHotkey #WindowEvents #EventDetection #SetWinEventHook #ShellHook #UIAutomation #WindowsAPI