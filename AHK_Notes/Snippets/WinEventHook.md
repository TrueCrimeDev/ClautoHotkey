# Topic: WinEventHook Class

## Category

Snippet

## Overview

The WinEventHook class provides a clean, object-oriented wrapper for the Windows SetWinEventHook API function. This powerful class allows scripts to receive notifications about window-related events such as creation, destruction, movement, focus changes, and many more. The event-driven approach is much more efficient than polling techniques, making it ideal for applications that need to monitor window activity.

## Key Points

- Event-driven approach to window event detection
- No polling required, minimizing resource usage
- Can monitor specific windows or all windows system-wide
- Supports all window event types defined by Microsoft's UI Automation framework
- Automatically cleans up hooks when the object is destroyed

## Syntax and Parameters

```cpp
; Create a new window event hook
hook := WinEventHook(callback, eventMin, eventMax, winTitle, PID, skipOwnProcess)

; To stop the hook explicitly (also happens automatically when object is destroyed)
hook.Stop()
```

- `callback`: Function to call when an event occurs (must accept 7 parameters)
- `eventMin`: Lowest event ID to monitor (default: EVENT_OBJECT_CREATE = 0x8000)
- `eventMax`: Highest event ID to monitor (default: EVENT_OBJECT_DESTROY = 0x8001)
- `winTitle`: Optional window title to monitor (default: 0 = all windows)
- `PID`: Optional process ID to monitor (default: 0 = all processes)
- `skipOwnProcess`: Whether to ignore events from the script's own process (default: false)

## Code Examples

```cpp
; Example 1: Basic window creation/destruction detection
#Requires AutoHotkey v2

; Track all windows that currently exist
global gOpenWindows := Map()
for hwnd in WinGetList()
    try gOpenWindows[hwnd] := {title: WinGetTitle(hwnd), class: WinGetClass(hwnd), processName: WinGetProcessName(hwnd)}

; Set up event hook for window creation and destruction
global EVENT_OBJECT_CREATE := 0x8000, EVENT_OBJECT_DESTROY := 0x8001, OBJID_WINDOW := 0, INDEXID_CONTAINER := 0
hook := WinEventHook(HandleWinEvent, EVENT_OBJECT_CREATE, EVENT_OBJECT_DESTROY)
Persistent()

HandleWinEvent(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    Critical -1
    global gOpenWindows, EVENT_OBJECT_CREATE, EVENT_OBJECT_DESTROY, OBJID_WINDOW, INDEXID_CONTAINER
    
    ; Filter for window events only (not controls)
    if (idObject = OBJID_WINDOW && idChild = INDEXID_CONTAINER) {
        if (event = EVENT_OBJECT_CREATE && DllCall("IsTopLevelWindow", "Ptr", hwnd)) {
            try {
                ; Store information about the new window
                gOpenWindows[hwnd] := {title: WinGetTitle(hwnd), class: WinGetClass(hwnd), processName: WinGetProcessName(hwnd)}
                
                if (gOpenWindows[hwnd].processName = "notepad.exe")
                    ToolTip("Notepad window created")
            }
        } else if (event = EVENT_OBJECT_DESTROY && gOpenWindows.Has(hwnd)) {
            if (gOpenWindows[hwnd].processName = "notepad.exe")
                ToolTip("Notepad window destroyed")
                
            ; Remove destroyed window from our tracking map
            gOpenWindows.Delete(hwnd)
        }
    }
}

; Example 2: Monitor window state changes (minimize, maximize, etc.)
#Requires AutoHotkey v2

; Event constants
EVENT_SYSTEM_MINIMIZESTART := 0x0016
EVENT_SYSTEM_MINIMIZEEND := 0x0017
EVENT_SYSTEM_MOVESIZESTART := 0x000A
EVENT_SYSTEM_MOVESIZEEND := 0x000B

; Create hooks for different event types
minimizeHook := WinEventHook(MinimizeHandler, EVENT_SYSTEM_MINIMIZESTART, EVENT_SYSTEM_MINIMIZEEND)
moveSizeHook := WinEventHook(MoveSizeHandler, EVENT_SYSTEM_MOVESIZESTART, EVENT_SYSTEM_MOVESIZEEND)
Persistent()

MinimizeHandler(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    if (event = EVENT_SYSTEM_MINIMIZESTART)
        ToolTip("Window minimizing: " WinGetTitle(hwnd))
    else if (event = EVENT_SYSTEM_MINIMIZEEND)
        ToolTip("Window restored from minimized state: " WinGetTitle(hwnd))
}

MoveSizeHandler(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    if (event = EVENT_SYSTEM_MOVESIZESTART)
        ToolTip("Window move/resize started: " WinGetTitle(hwnd))
    else if (event = EVENT_SYSTEM_MOVESIZEEND)
        ToolTip("Window move/resize ended: " WinGetTitle(hwnd))
}
```

## Implementation Notes

```cpp
class WinEventHook {
    /**
     * Sets a new WinEventHook and returns on object describing the hook. 
     * When the object is released, the hook is also released. Alternatively use WinEventHook.Stop()
     * to stop the hook.
     * @param callback The function that will be called, which needs to accept 7 arguments:
     *    hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime
     * @param eventMin Optional: Specifies the event constant for the lowest event value in the range of events that are handled by the hook function.
     *  Default is the lowest possible event value.
     *  See more about event constants: https://learn.microsoft.com/en-us/windows/win32/winauto/event-constants
     *  Msaa Events List: Https://Msdn.Microsoft.Com/En-Us/Library/Windows/Desktop/Dd318066(V=Vs.85).Aspx
     *  System-Level And Object-Level Events: Https://Msdn.Microsoft.Com/En-Us/Library/Windows/Desktop/Dd373657(V=Vs.85).Aspx
     *  Console Accessibility: Https://Msdn.Microsoft.Com/En-Us/Library/Ms971319.Aspx
     * @param eventMax Optional: Specifies the event constant for the highest event value in the range of events that are handled by the hook function.
     *  If eventMin is omitted then the default is the highest possible event value.
     *  If eventMin is specified then the default is eventMin.
     * @param winTitle Optional: WinTitle of a certain window to hook to. Default is system-wide hook.
     * @param PID Optional: process ID of the process for which threads to hook to. Default is system-wide hook.
     * @param skipOwnProcess Optional: whether to skip windows (eg Tooltips) from the running script. 
     *  Default is not to skip.
     * @returns {WinEventHook} 
     */
    __New(callback, eventMin?, eventMax?, winTitle := 0, PID := 0, skipOwnProcess := false) {
        if !HasMethod(callback)
            throw ValueError("The callback argument must be a function", -1)
        if !IsSet(eventMin)
            eventMin := 0x00000001, eventMax := IsSet(eventMax) ? eventMax : 0x7fffffff
        else if !IsSet(eventMax)
            eventMax := eventMin
        this.callback := callback, this.winTitle := winTitle, this.flags := skipOwnProcess ? 2 : 0, this.eventMin := eventMin, this.eventMax := eventMax, this.threadId := 0
        if winTitle != 0 {
            if !(this.winTitle := WinExist(winTitle))
                throw TargetError("Window not found", -1)
            this.threadId := DllCall("GetWindowThreadProcessId", "Ptr", this.winTitle, "UInt*", &PID)
        }
        this.pCallback := CallbackCreate(callback, "C", 7)
        , this.hHook := DllCall("SetWinEventHook", "UInt", eventMin, "UInt", eventMax, "Ptr", 0, "Ptr", this.pCallback, "UInt", this.PID := PID, "UInt", this.threadId, "UInt", this.flags)
    }
    Stop() => this.__Delete()
    __Delete() {
        if (this.pCallback)
            DllCall("UnhookWinEvent", "Ptr", this.hHook), CallbackFree(this.pCallback), this.hHook := 0, this.pCallback := 0
    }
}
```

### Key Implementation Details:

1. **Event Filtering**:
   - The class allows filtering events by type, window, and process
   - Event types are specified by their numeric constants (see Microsoft documentation)
   - Filtering by window title or PID reduces overhead for targeted monitoring

2. **Callback Function**:
   - The callback must accept 7 parameters corresponding to the WinEventProc structure:
     - `hWinEventHook`: Handle to the event hook function
     - `event`: The event code that triggered the callback
     - `hwnd`: Handle to the window that generated the event
     - `idObject`: ID of the object associated with the event
     - `idChild`: ID of the child element if relevant
     - `idEventThread`: Thread ID that triggered the event
     - `dwmsEventTime`: Time when the event was generated

3. **Window Information Tracking**:
   - After a window is destroyed, you can no longer query its properties
   - Store window information when windows are created for reference when they're destroyed
   - Remember to clean up stored information to avoid memory leaks

4. **Resource Management**:
   - The class automatically frees resources when the object is destroyed
   - Use `Stop()` to explicitly unhook if needed before object destruction
   - The hook remains active as long as the object reference exists

5. **Common Issues and Solutions**:
   - Some windows don't update their titles immediately after creation
   - Solution: Use a short delay (40-100ms) before reading window properties
   - Alternative: Monitor EVENT_OBJECT_SHOW instead of EVENT_OBJECT_CREATE
   - Top-level windows vs. controls: Use `DllCall("IsTopLevelWindow", "Ptr", hwnd)` to distinguish

## Related AHK Concepts

- CallbackCreate/CallbackFree - For creating C-compatible callback functions
- DllCall - For interfacing with Windows API functions
- Critical - For managing thread priority during callback execution
- WinExist/WinGetTitle/WinGetProcessName - For retrieving window information
- Map - For tracking window properties between events
- Event constants - Microsoft UI Automation event codes

## Tags

#AutoHotkey #WindowEvents #SetWinEventHook #EventDriven #WindowMonitoring #Accessibility #WindowsAPI