# Topic: Low-Level Mouse Hook Implementation

## Category

Snippet

## Overview

This implementation provides a robust way to detect and optionally block mouse movements and clicks using Windows' low-level mouse hook system. It includes two versions: a high-performance implementation using compiled C code, and a pure AutoHotkey implementation. The compiled version offers significantly better performance and reliability for real-time applications and can selectively block specific types of mouse events.

## Key Points

- Intercepts all mouse events before they reach applications
- Can monitor mouse movement, clicks, or both
- Compiled C version offers superior performance with minimal input lag
- Ability to selectively block physical or artificial mouse movements/clicks
- Includes safe cleanup on script exit to restore normal mouse functionality

## Syntax and Parameters

```cpp
; Compiled C version (recommended for performance)
mouseHook := LLMH(CallbackFunction, EventType)

; Pure AHK version
mouseHook := LowLevelMouseEvent(CallbackFunction, EventType)

; Parameters:
; CallbackFunction: Function to call with mouse data
; EventType: 1=movement only, 2=clicks only, 3=both (default)
```

## Code Examples

```cpp
; Basic usage example of the high-performance compiled C version
#Requires AutoHotkey v2.0

; Initialize or toggle the hook with F1
g_LLMouseHook := 0
F1::global g_LLMouseHook := g_LLMouseHook ? 0 : LLMH(MouseMovedEvent, 1)
Esc::ExitApp

; Callback to handle mouse movement events
MouseMovedEvent(X, Y, info) {
    ToolTip "Mouse moved to x" X " y" Y "`n"
        . "msg: " info.msg 
        . ", mouseData: " info.mouseData 
        . ", flags: " info.flags 
        . ", time: " info.time 
        . ", dwExtraInfo: " info.extraInfo
}

; Example of blocking specific mouse events
BlockPhysicalMouseMovements() {
    ; Block only physical mouse movements (artificial ones still work)
    LLMH.BlockMouseMove := 1
    
    ; Block only left and right mouse clicks (not middle or wheel)
    LLMH.BlockMouseClick := 12  ; 4 (left) + 8 (right)
}

; Example of the pure AHK version (slower but simpler)
LowLevelMouseHook() {
    return LowLevelMouseEvent(MouseMovedEvent, 1)
}
```

## Implementation Notes

- When using the compiled C version (LLMH):
  * The hook runs in a separate thread to minimize impact on script performance
  * Mouse events are detected and processed before they reach applications
  * Static properties control blocking behavior:
    - BlockMouseMove: 1=block physical, 2=block artificial, 3=block both
    - BlockMouseClick: For specific buttons, use combinations of:
      * LButton=4, RButton=8, MButton=16, XButton1=32, XButton2=64
      * Wheel=128, Horizontal wheel=256, or 3 for all buttons

- Advantages of compiled version over pure AHK:
  * Much lower input latency (microseconds vs milliseconds)
  * More reliable when script is busy with other tasks
  * Doesn't freeze when script hits breakpoints during debugging
  * Uses fast, dedicated thread to process events
  * Can selectively block specific types of mouse movements and buttons

- Limitations and considerations:
  * If the hook misbehaves, mouse input could be effectively disabled
    (though Ctrl+Alt+Del still works as Windows bypasses hooks)
  * Using multiple mouse hooks compounds processing time
  * Install only when needed and remove when not in use
  * The pure AHK version uses SetTimer for callbacks, which may delay processing

## Related AHK Concepts

- CallbackCreate/CallbackFree - Used for Windows hook callbacks
- DllCall - For interacting with Windows API functions
- SetWindowsHookEx/UnhookWindowsHookEx - Core Windows hook functions
- OnMessage - Alternative for GUI-only mouse tracking
- GetKeyState - For checking mouse button states

## Tags

#AutoHotkey #WindowsHooks #MouseInput #InputBlocking #LowLevelHook #CompiledCode