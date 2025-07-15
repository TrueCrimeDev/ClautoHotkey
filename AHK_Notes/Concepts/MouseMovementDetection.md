# Topic: Mouse Movement Detection Methods

## Category

Concept

## Overview

Detecting mouse movement in AutoHotkey can be implemented through multiple methods, each with different capabilities and trade-offs. This document outlines six approaches: SetTimer polling, RawInput event handling, low-level mouse hooks (SetWindowsHookEx), GUI message monitoring (WM_MOUSEMOVE), external window hooks, and AutoHotInterception. Understanding these methods helps in selecting the appropriate approach based on performance needs and specific use cases.

## Key Points

- SetTimer polling is simplest but may miss rapid movements and consumes resources unnecessarily
- RawInput provides true event-driven detection and can distinguish between different input devices
- Low-level mouse hooks can intercept and block mouse events but may introduce input lag
- WM_MOUSEMOVE only works within AHK GUI windows but is lightweight
- AutoHotInterception offers advanced capabilities but requires administrator rights
- Performance considerations are critical, especially when using hook-based methods

## Syntax and Parameters

```cpp
; Method 1: SetTimer polling
SetTimer(CheckMouseMoved, 50)  ; Check every 50ms

; Method 2: RawInput
mouseHook := MouseRawInputHook(CallbackFunction, EventType)
; EventType: 1=movement only, 2=clicks only, 3=both

; Method 3: Low-level mouse hook
mouseHook := LLMH(CallbackFunction, EventType)
; EventType: 1=movement only, 2=clicks only, 3=both

; Method 4: WM_MOUSEMOVE (GUI only)
OnMessage(0x0200, WM_MOUSEMOVE, Priority)
```

## Code Examples

```cpp
; Example 1: SetTimer polling method
CheckMouseMoved() {
    static prevX, prevY
    local x, y, hWnd
    CoordMode "Mouse", "Screen"
    MouseGetPos(&x, &y, &hWnd)
    if IsSet(prevX) && !(x = prevX && y = prevY)
        MouseMovedEvent(x, y, hWnd, prevX, prevY)
    else
        prevX := x, prevY := y
}

; Example 2: RawInput method
mouseHook := MouseRawInputHook(MouseMovedEvent, 1)

MouseMovedEvent(x, y, info) {
    ToolTip "Mouse moved: " x " " y "`nFlags: " info.flags 
        . ", ButtonFlags: " info.buttonFlags 
        . ", Device: " info.device
}

; Example 3: WM_MOUSEMOVE method for GUI windows
WM_MOUSEMOVE(wParam, lParam, msg, hWnd) {
    if msg != 0x0200
        return
    x := lParam << 48 >> 48, y := lParam << 32 >> 48
    ToolTip "Mouse moved to client coords x" x " y" y
}

; Example 4: Toggle event monitoring on/off
F1::Toggle(CheckMouseMoved, 50)  ; Toggle SetTimer monitoring

Toggle(F, P, I:=0) {
    static A := Map()
    return SetTimer(F, !P ? !(A.Delete(F) ?? 1) 
        : A.Has(F) && A[F] = P ? !A.Delete(F) 
        : (I && F(), A[F] := P))
}
```

## Implementation Notes

- Choosing the right method depends on the specific requirements:
  * For simple monitoring, use SetTimer (Method 1) or GUI message monitoring (Method 4)
  * For detecting input from multiple devices, use RawInput (Method 2) or AutoHotInterception (Method 6)
  * For intercepting/blocking mouse events, use low-level mouse hooks (Method 3 or 5)
  * For monitoring only specific windows, use window-specific hooks (Method 5)

- Low-level hooks have significant considerations:
  * They process all mouse events before they reach applications
  * A malfunctioning hook can effectively disable mouse input (except Ctrl+Alt+Del)
  * AHK being a relatively slow language can introduce noticeable input lag
  * Multiple hooks compound processing time, increasing potential lag
  * Consider using compiled C/C++ for hook callbacks (see example in original post)

- RawInput (Method 2) provides:
  * Relative movement data (direction and distance)
  * Device identification for multi-device setups
  * No ability to block events, only monitor them

- The fastest and most reliable methods for blocking mouse events are:
  * Low-level hooks implemented in C/C++ (Method 3 with compiled callback)
  * AutoHotInterception (Method 6) which operates at driver level

## Related AHK Concepts

- MouseGetPos - Used with polling to detect position changes
- SetTimer - For implementing polling-based detection
- OnMessage - For GUI-based mouse event detection
- CallbackCreate - Used in hook-based implementations
- DllCall - For direct Windows API access in hook implementations
- InstallMouseHook - AHK's built-in (but limited) mouse hook function

## Tags

#AutoHotkey #MouseInput #EventHandling #WindowsHooks #RawInput #InputDetection #GUI