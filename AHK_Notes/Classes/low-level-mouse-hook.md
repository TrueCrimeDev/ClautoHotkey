# Topic: Low Level Mouse Hook Class

## Category

Class

## Overview

The LLMH (Low Level Mouse Hook) class provides a more sophisticated approach to detecting mouse movement with the ability to block or intercept mouse events. It uses Windows' SetWindowsHookEx system with compiled C code for performance, avoiding the lag issues associated with pure AHK implementations.

## Key Points

- Provides event-driven mouse movement detection
- Can block physical and/or artificial mouse movements
- Can selectively block specific mouse buttons/actions
- Maintains good performance using compiled C code
- Supports discriminating between movement types

## Syntax and Parameters

```cpp
; Initialize the hook
mouseHook := LLMH(callbackFunction, eventType)

; Parameters
; callbackFunction: Function to call when mouse event is detected
; eventType: 1 = only mouse movement, 2 = only mouse clicks, 3 = both (default)

; BlockMouseMove property
; 1 = block physical movement, 2 = block artificial movement, 3 = block both
LLMH.BlockMouseMove := value

; BlockMouseClick property
; 1 = block physical clicks, 2 = block artificial clicks, 3 = block both
; Or use specific values for particular buttons:
; LButton = 4, RButton = 8, MButton = 16, XButton1 = 32, XButton2 = 64, wheel = 128, horizontal wheel = 256
LLMH.BlockMouseClick := value
```

## Code Examples

```cpp
#Requires AutoHotkey v2.0

g_LLMouseHook := 0
F1::global g_LLMouseHook := g_LLMouseHook ? 0 : LLMH(MouseMovedEvent, 1)
Esc::ExitApp

MouseMovedEvent(X, Y, info) {
    ToolTip "Mouse moved to x" X " y" Y "`nmsg: " info.msg ", mouseData: " info.mouseData ", flags: " info.flags ", time: " info.time ", dwExtraInfo: " info.extraInfo
}

; Example: Block left mouse button clicks
; g_LLMouseHook := LLMH(MouseMovedEvent, 3)
; LLMH.BlockMouseClick := 4  ; Block only LButton

class LLMH {
    static __RegisteredCallbacks := Map()
    static __New() {
        this.Prototype.__Static := this
        this.hHeap := DllCall("GetProcessHeap", "ptr")
        this.MCode := this.__InitMCode()
        this.MCode.g_hWnd := A_ScriptHwnd
        this.MCode.g_Msg := DllCall("RegisterWindowMessage", "str", "AHK_LowLevelMouseEvent", "uint")
        OnMessage(this.MCode.g_Msg, this.__LowLevelMouseEvent.Bind(this))
    }
    __New(Callback, EventType:=3) {
        this.__Static.__RegisteredCallbacks[ObjPtr(this)] := 1
        this.EventType := EventType, this.Callback := Callback
        if this.__Static.__RegisteredCallbacks.Count = 1 {
            DllCall("CreateThread", "ptr", 0, "uint", 0, "ptr", this.__Static.MCode.exports.Main, "ptr", 0, "uint", 0, "uint*", &threadId:=0)
            if !threadId
                throw Error("Failed to create low level mouse hook thread")
            this.__Static.MCode.threadId := threadId
        }
    } 
    __Delete() {
        this.__Static.__RegisteredCallbacks.Delete(ObjPtr(this))
        if !this.__Static.__RegisteredCallbacks.Count {
            DllCall("UnhookWindowsHookEx", "ptr", this.__Static.MCode.g_hHook)
            this.__Static.MCode.g_hHook := 0
        }
    }
    ; 1 = block physical movement, 2 = block artificial movement, 3 = block both
    static BlockMouseMove {
        get => this.MCode.g_dwBlockMouseMove
        set => this.MCode.g_dwBlockMouseMove := value
    }
    ; 1 = block physical clicks, 2 = block artificial clicks, 3 = block both
    ; Default is to block all mouse keys, but for specific keys use a bitwise combination of these:
    ; LButton = 4, RButton = 8, MButton = 16, XButton1 = 32, XButton2 = 64, wheel = 128, horizontal wheel = 256
    static BlockMouseClick {
        get => this.MCode.g_dwBlockMouseClick
        set => this.MCode.g_dwBlockMouseClick := value
    }
    static __LowLevelMouseEvent(wParam, lParam, msg, hwnd) {
        local p, EventObj, x := NumGet(lParam, 'Int'), y := NumGet(lParam + 4, 'Int'), info := {msg: wParam, mouseData: NumGet(lParam + 8, 'UInt') << 32 >> 48, flags: NumGet(lParam + 12, 'UInt'), time: NumGet(lParam + 16, 'UInt'), extraInfo: NumGet(lParam + 20, 'Ptr')}
        for p in this.__RegisteredCallbacks {
            EventObj := ObjFromPtrAddRef(p)
            if (EventObj.EventType = 3 || (EventObj.EventType & 1 && info.msg == 0x200) || (EventObj.EventType & 2 && info.msg != 0x200))
                pCallback := CallbackCreate(EventObj.Callback.Bind(x, y, info)), DllCall(pCallback), CallbackFree(pCallback)
        }
        DllCall("HeapFree", "ptr", this.hHeap, "UInt", 0, "Ptr", lParam)
    }
    static __InitMCode() {
        /* Compiled C code omitted for brevity - see full implementation in the source */
        /* See original source for complete MCode implementation */
    }
}
```

## Implementation Notes

- The class uses a hybrid approach with AHK code calling compiled C functions
- Multiple instances can be created for different event types or callbacks
- Blocking mouse events is powerful but should be used with caution
- The thread-based implementation avoids freezing the mouse if script hangs
- Lower-level than pure AHK, providing more reliable interception

## Related AHK Concepts

- Windows Hooks
- DllCall and CallbackCreate
- Compiled code integration
- Mouse event handling
- OnMessage

## Tags

#AutoHotkey #OOP #Mouse #LowLevelHook #SetWindowsHookEx #InputBlocking