# Topic: SetWindowsHookEx for Window Event Interception

## Category

Snippet

## Overview

SetWindowsHookEx provides a powerful but potentially dangerous method for not just detecting but also intercepting and modifying window events. This advanced technique allows scripts to filter, block, or alter window messages before they reach their target applications. Unlike other detection methods, SetWindowsHookEx can prevent windows from opening or closing, intercept keyboard/mouse input, and modify window behavior at a fundamental level.

## Key Points

- Can intercept and modify window events, not just detect them
- Requires a compiled DLL for efficient implementation
- Potentially dangerous - improper implementation can freeze the system
- Different hook types for various events (CBT, CallWndProc, GetMessage, etc.)
- More complex to implement than other window detection methods
- Requires administrative privileges for some scenarios

## Syntax and Parameters

```cpp
; Using a wrapper class for SetWindowsHookEx
hook := WindowsHookEx(idHook, msgNumber, nCodes, targetWindow, timeout, receiverWindow)

; Remove the hook when done
hook.Unhook()  ; or simply let the object be destroyed
```

- `idHook`: Hook type constant (WH_CBT=5, WH_CALLWNDPROC=4, etc.)
- `msgNumber`: Custom message ID for communication
- `nCodes`: Array of event codes or message IDs to monitor
- `targetWindow`: Optional window title or handle to hook (0 for all windows)
- `timeout`: Timeout in milliseconds for event processing
- `receiverWindow`: Window that receives hook messages (default: script window)

## Code Examples

```cpp
; Example 1: Block Notepad from opening or closing
#Requires AutoHotkey v2.0
Persistent()

; Hook constants
WH_CBT := 5
HCBT_CREATEWND := 3
HCBT_DESTROYWND := 4

; Register a custom message for hook communication
msg := DllCall("RegisterWindowMessage", "str", "CBTProc", "uint")
OnMessage(msg, CBTProc)

; Set up the hook
hHook := WindowsHookEx(WH_CBT, msg, [HCBT_CREATEWND, HCBT_DESTROYWND], 0, 0)

; Callback to handle hook events
CBTProc(hProcess, lParam, msg, hWnd) {
    ; Read hook data from the target process
    if !TryReadProcessMemory(hProcess, lParam, info := Buffer(24))
        return -1
        
    nCode := NumGet(info, "int")
    wParam := NumGet(info, A_PtrSize, "ptr")
    lParam := NumGet(info, A_PtrSize*2, "ptr")
    
    ; Check if this is a Notepad window
    if WinExist(wParam) && InStr(WinGetProcessName(wParam), "notepad.exe") {
        if (nCode == HCBT_CREATEWND) {
            ; For window creation, verify it's a top-level window
            if !TryReadProcessMemory(hProcess, lParam, CBT_CREATEWND := Buffer(A_PtrSize*2))
                return -1
                
            lpcs := NumGet(CBT_CREATEWND, "ptr")
            if !lpcs
                return -1
                
            if !TryReadProcessMemory(hProcess, lpcs, CREATESTRUCT := Buffer(6*A_PtrSize + 6*4))
                return -1
                
            hwndParent := NumGet(CREATESTRUCT, A_PtrSize*3, "ptr")
            
            if hwndParent == 0 {
                ; Important: Unhook before showing MsgBox to prevent deadlock
                global hHook := 0
                MsgBox("Creating Notepad has been blocked!")
                hHook := WindowsHookEx(WH_CBT, msg, [HCBT_CREATEWND, HCBT_DESTROYWND], 0, 0)
                return 1  ; Block window creation
            }
        } else if (nCode == HCBT_DESTROYWND) {
            ; Check if it's a top-level window
            if wParam = DllCall("GetAncestor", "ptr", wParam, "uint", 2, "ptr") {
                ; Important: Unhook before showing MsgBox to prevent deadlock
                global hHook := 0
                MsgBox("Closing Notepad has been blocked!")
                hHook := WindowsHookEx(WH_CBT, msg, [HCBT_CREATEWND, HCBT_DESTROYWND], 0, 0)
                return 1  ; Block window destruction
            }
        }
    }
    return -1  ; Allow other events to proceed normally
}

; Helper function to read memory from another process
TryReadProcessMemory(hProcess, lpBaseAddress, oBuffer, &nBytesRead?) {
    try 
        return DllCall("ReadProcessMemory", "ptr", hProcess, "ptr", lpBaseAddress, 
               "ptr", oBuffer, "int", oBuffer.Size, 
               "int*", IsSet(nBytesRead) ? &nBytesRead:=0 : 0, "int") != 0
    return 0
}

; Example 2: Intercept Paste operation in Notepad
#Requires AutoHotkey v2.0
Persistent()

; Hook constants
WH_CALLWNDPROC := 4
WM_PASTE := 0x0302

; Launch or activate Notepad
if !WinExist("ahk_exe notepad.exe") {
    Run "notepad.exe"
} else
    WinActivate "ahk_exe notepad.exe"
WinWaitActive "ahk_exe notepad.exe"
hWnd := WinExist()

; Register custom message and set up message handler
msg := DllCall("RegisterWindowMessage", "str", "WndProc", "uint")
OnMessage(msg, WndProc)

; Set up the hook for the WM_PASTE message only
hHook := WindowsHookEx(WH_CALLWNDPROC, msg, [WM_PASTE], hWnd, 0)

; Override Ctrl+V to show a message
#HotIf WinActive("ahk_exe notepad.exe")
^v::MsgBox("Ctrl+V doesn't send WM_PASTE, try right-clicking and select Paste")

; Message handler for intercepted window messages
WndProc(hProcess, lParam, msg, hWnd) {
    ; Read message data from the process
    if TryReadProcessMemory(hProcess, lParam, info := Buffer(32)) {
        hWnd := NumGet(info, "ptr")
        uMsg := NumGet(info, A_PtrSize, "ptr")
        wParam := NumGet(info, A_PtrSize*2, "ptr")
        lParam := NumGet(info, A_PtrSize*3, "ptr")
        
        if uMsg = WM_PASTE {
            ; Ask user if paste should be allowed
            return (MsgBox("Allow paste?", "AHK/Notepad", 0x4) = "Yes") ? -1 : 0
        }
    }
    return -1  ; Allow other messages to proceed normally
}
```

## Implementation Notes

### Windows Hook Types

SetWindowsHookEx supports various hook types, each intercepting different kinds of events:

1. **WH_CBT (5)**: Computer-Based Training - intercepts window creation, destruction, activation, etc.
   - HCBT_CREATEWND (3): Window creation
   - HCBT_DESTROYWND (4): Window destruction
   - HCBT_ACTIVATE (5): Window activation
   - HCBT_MINMAX (1): Window minimize/maximize

2. **WH_CALLWNDPROC (4)**: Intercepts messages being sent to windows
   - Can filter by window message IDs (WM_*)
   - Used for inspecting or modifying window messages

3. **WH_GETMESSAGE (3)**: Intercepts messages retrieved from message queue
   - Similar to WH_CALLWNDPROC but at a different point in message flow

4. **WH_KEYBOARD (2)**: Intercepts keyboard input
5. **WH_MOUSE (7)**: Intercepts mouse input

### Critical Implementation Details

1. **DLL Requirement**:
   - Hooks are implemented using an injected DLL
   - The DLL must match the bitness of the target process (32-bit or 64-bit)
   - A 64-bit AHK script with 64-bit DLL can only hook 64-bit processes
   - The example uses HookProc.dll from the HookProc GitHub repository

2. **Security and Privileges**:
   - Cannot hook processes running at higher privilege levels
   - To hook an elevated process, the script must also run elevated
   - Some hooks may require administrative privileges

3. **Resource Management**:
   - Hooks must be properly removed when no longer needed
   - Unremoved hooks can cause system instability
   - Use object destructors or OnExit to ensure cleanup

4. **Deadlock Prevention**:
   - Critical: Unhook before showing UI elements like MsgBox
   - Single-threaded AHK can't process other events during UI operations
   - Failure to unhook can freeze the entire system

5. **Performance Concerns**:
   - Hook callbacks should execute quickly
   - Slow hook processing can make the entire system feel sluggish
   - Consider using a compiled C/C++ DLL for hook processing

### Safety Precautions

1. **Message Handling**:
   - Return -1 to allow normal message processing
   - Return 0 or 1 to block messages (depending on hook type)
   - Be careful about which messages you block

2. **Error Recovery**:
   - Build in timeouts for message processing
   - Have a way to disable hooks in case of issues
   - Test thoroughly with non-critical applications first

3. **Avoid Common Pitfalls**:
   - Don't block essential system messages
   - Don't hook critical system processes
   - Be aware of SendMessage vs. PostMessage differences

### The WindowsHookEx Class

The implementation uses a `WindowsHookEx` class to simplify hook management:

```cpp
class WindowsHookEx {
    ; DLL name for hook implementation
    static DllName := "HookProc.dll"
    
    ; Initialize and load the DLL
    static __New() {
        for loc in [A_WorkingDir "\" this.DllName, A_ScriptDir "\" this.DllName, 
                   A_ScriptDir "\Lib\" this.DllName, A_ScriptDir "\Resources\" this.DllName] {
            if FileExist(loc) {
                this.hLib := DllCall("LoadLibrary", "str", loc, "ptr")
                return
            }
        }
        throw Error("Unable to find " this.DllName " file!", -1)
    }
    
    ; Create a new hook
    __New(idHook, msg, nCodes, HookedWinTitle := "", timeOut := 16, ReceiverWinTitle := A_ScriptHwnd) {
        ; [Implementation details omitted for brevity]
    }
    
    ; Remove the hook
    static Unhook(hHook) => DllCall(this.DllName "\UnHook", "ptr", 
                                   IsObject(hHook) ? hHook.hHook : hHook)
    
    ; Clean up shared memory
    static ClearSharedMemory() => DllCall(this.DllName "\ClearSharedMemory")
    
    ; Delete method for automatic cleanup
    __Delete() => WindowsHookEx.UnHook(this.hHook)
    
    ; Close all hooks created by this script
    static Close() => DllCall(this.DllName "\Close")
}
```

## Related AHK Concepts

- DllCall - Used to interface with Windows API functions
- OnMessage - For receiving hook messages
- CallbackCreate - For creating C-compatible callback functions
- Buffer - For handling memory structures
- ReadProcessMemory - For accessing memory in hooked processes
- MsgBox/UI handling - Critical to unhook before showing UI elements

## Tags

#AutoHotkey #SetWindowsHookEx #WindowHooking #WindowsAPI #Advanced #SystemHooks #MessageInterception