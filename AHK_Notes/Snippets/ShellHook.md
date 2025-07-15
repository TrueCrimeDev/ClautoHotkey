# Topic: ShellHook for Window Event Detection

## Category

Snippet

## Overview

The ShellHook technique allows scripts to detect window creation, destruction, activation, and other shell-related events through the Windows Shell Hook mechanism. This approach is event-driven, making it more efficient than polling methods. While Microsoft has documented this method as deprecated, it remains functional and provides a relatively simple way to monitor window events.

## Key Points

- Event-driven approach that doesn't require polling
- Can detect window creation, destruction, activation, and other shell events
- Relatively simple implementation compared to some alternatives
- Uses RegisterShellHookWindow and SHELLHOOK message
- Documented by Microsoft as deprecated, but still functional

## Syntax and Parameters

```cpp
; Register for shell hook messages
DllCall("RegisterShellHookWindow", "UInt", A_ScriptHwnd)
msgNumber := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
OnMessage(msgNumber, ShellMessageHandler)

; Optional: De-register when script exits
OnExit((*) => DllCall("DeregisterShellHookWindow", "UInt", A_ScriptHwnd))
```

- `A_ScriptHwnd`: Handle to the script's window that will receive messages
- `msgNumber`: Message ID for SHELLHOOK messages
- `ShellMessageHandler`: Callback function to process shell events

## Code Examples

```cpp
; Example: Basic shell hook implementation for monitoring window events
#Requires AutoHotkey v2

; Track open windows to maintain their information after closure
global gOpenWindows := Map()
for hwnd in WinGetList()
    try gOpenWindows[hwnd] := {title: WinGetTitle(hwnd), class: WinGetClass(hwnd), processName: WinGetProcessName(hwnd)}

; Register for shell hook notifications
DllCall("RegisterShellHookWindow", "UInt", A_ScriptHwnd)
OnMessage(DllCall("RegisterWindowMessage", "Str", "SHELLHOOK"), ShellProc)

; Unregister on script exit
OnExit((*) => DllCall("DeregisterShellHookWindow", "UInt", A_ScriptHwnd))
Persistent()

ShellProc(wParam, lParam, *) {
    global gOpenWindows
    
    ; Handle different shell hook message types
    switch wParam {
        case 1: ; HSHELL_WINDOWCREATED
            gOpenWindows[lParam] := {
                title: WinGetTitle(lParam), 
                class: WinGetClass(lParam), 
                processName: WinGetProcessName(lParam)
            }
            
            if gOpenWindows[lParam].processName = "notepad.exe" {
                ToolTip("Notepad window opened")
                SetTimer(() => ToolTip(), -3000)  ; Clear tooltip after 3 seconds
            }
            
        case 2: ; HSHELL_WINDOWDESTROYED
            if gOpenWindows.Has(lParam) {
                if gOpenWindows[lParam].processName = "notepad.exe" {
                    ToolTip("Notepad window closed")
                    SetTimer(() => ToolTip(), -3000)  ; Clear tooltip after 3 seconds
                }
                
                ; Remove the window from our tracking map
                gOpenWindows.Delete(lParam)
            }
            
        case 3: ; HSHELL_ACTIVATESHELLWINDOW
            ToolTip("Shell window activated")
            SetTimer(() => ToolTip(), -3000)
            
        case 4: ; HSHELL_WINDOWACTIVATED
        case 32772: ; HSHELL_WINDOWACTIVATED + HSHELL_HIGHBIT (topmost windows)
            if WinExist("ahk_id " lParam) {
                activeTitle := WinGetTitle(lParam)
                ToolTip("Window activated: " activeTitle)
                SetTimer(() => ToolTip(), -3000)
            }
            
        case 5: ; HSHELL_GETMINRECT
            ; Not commonly used
            
        case 6: ; HSHELL_REDRAW
            ; Window title changed or visual update
            
        case 7: ; HSHELL_TASKMAN
            ToolTip("Windows Task Manager requested")
            SetTimer(() => ToolTip(), -3000)
            
        case 8: ; HSHELL_LANGUAGE
            ToolTip("Input language changed")
            SetTimer(() => ToolTip(), -3000)
            
        case 9: ; HSHELL_SYSMENU
            ToolTip("System menu called")
            SetTimer(() => ToolTip(), -3000)
            
        case 10: ; HSHELL_ENDTASK
            ToolTip("End Task called on a window")
            SetTimer(() => ToolTip(), -3000)
    }
}
```

## Implementation Notes

### Shell Hook Message Types

The `wParam` parameter in the shell hook callback represents the type of event:

1. `HSHELL_WINDOWCREATED (1)`: Window created
2. `HSHELL_WINDOWDESTROYED (2)`: Window destroyed
3. `HSHELL_ACTIVATESHELLWINDOW (3)`: Shell window activated
4. `HSHELL_WINDOWACTIVATED (4)`: Window activated
5. `HSHELL_GETMINRECT (5)`: Request for a window's minimized rectangle
6. `HSHELL_REDRAW (6)`: Window title changed
7. `HSHELL_TASKMAN (7)`: Windows Task Manager requested
8. `HSHELL_LANGUAGE (8)`: Input language changed
9. `HSHELL_SYSMENU (9)`: System menu called
10. `HSHELL_ENDTASK (10)`: End Task dialog shown
11. `HSHELL_RUDEAPPACTIVATED (32772)`: Activated topmost window (HSHELL_WINDOWACTIVATED + HSHELL_HIGHBIT)

The `lParam` parameter usually contains the window handle (HWND) of the window associated with the event.

### Important Implementation Details:

1. **Window Tracking**:
   - After a window is destroyed, its properties can no longer be queried
   - Store window information when created to reference after destruction
   - Keep track of all windows you're interested in via a Map or other collection

2. **Registration and Cleanup**:
   - RegisterShellHookWindow registers your script to receive shell messages
   - OnMessage sets up the message handler
   - DeregisterShellHookWindow removes the hook when your script exits
   - Always clean up hooks to prevent system resource leaks

3. **Message Processing**:
   - Use a switch statement to handle different event types
   - Process only the events you're interested in for better performance
   - Remember that shell hook messages are sent asynchronously

4. **Limitations**:
   - Microsoft has marked this API as deprecated
   - May not catch all window events in all circumstances
   - Some system windows might not trigger events properly
   - No guarantee of future compatibility in Windows updates

5. **Performance Considerations**:
   - Much more efficient than polling with SetTimer/WinExist
   - Can generate many events on a busy system
   - Avoid heavy processing in the message handler to prevent script slowdown

### Comparison with Other Methods:

- **vs. WinWait**: ShellHook is non-blocking and event-driven
- **vs. SetTimer/WinExist**: Much more efficient as it doesn't constantly poll
- **vs. SetWinEventHook**: Slightly simpler to implement but fewer event types
- **vs. UIAutomation**: Less comprehensive but easier to set up

## Related AHK Concepts

- OnMessage - For setting up the message handler
- DllCall - For interfacing with Windows API functions
- OnExit - For proper cleanup when the script exits
- WinGetTitle/WinGetClass/WinGetProcessName - For retrieving window information
- Map - For tracking window properties between events
- RegisterWindowMessage - For obtaining a unique message identifier

## Tags

#AutoHotkey #ShellHook #WindowEvents #EventDetection #WindowsAPI #ShellMessages