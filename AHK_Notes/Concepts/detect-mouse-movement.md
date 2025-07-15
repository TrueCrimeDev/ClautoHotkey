# Topic: Detecting Mouse Movement

## Category

Concept

## Overview

AutoHotkey offers multiple approaches to detect mouse movement, each with specific advantages and use cases. These methods range from simple polling solutions to advanced event-driven implementations that can differentiate between devices or block/intercept movements.

## Key Points

- Methods vary in complexity, from simple polling to low-level hooks
- Different approaches have trade-offs in performance, specificity, and capabilities
- Some methods (like SetWindowsHookEx) can block or modify mouse events
- Multi-device discrimination is possible with RawInput or AutoHotInterception

## Implementation Methods

### 1. SetTimer Polling Method

```cpp
F1::Toggle(CheckMouseMoved, 50, 1)
Esc::ExitApp

MouseMovedEvent(x, y, hWnd, prevX, prevY) {
    ToolTip "Mouse moved to x" x " y" y
}

Toggle(F, P, I:=0) => (A := Toggle.A ?? Toggle.A := Map(), SetTimer(F, !P ? !(A.Delete(F) ?? 1) : A.Has(F) && A[F] = P ? !A.Delete(F) : (I && F(), A[F] := P)))
CheckMouseMoved() {
    static prevX, prevY
    local x, y, pX, pY, hWnd
    CoordMode "Mouse", "Screen"
    MouseGetPos(&x, &y, &hWnd)
    if IsSet(prevX) && !(x = prevX && y = prevY)
        pX := prevX, pY := prevY, prevX := x, prevY := y, MouseMovedEvent(x, y, hWnd, pX, pY)
    else
        prevX := x, prevY := y
}
```

### 2. RawInput Method (Event-Driven)

```cpp
g_RawInputHook := 0
F1::global g_RawInputHook := g_RawInputHook ? 0 : MouseRawInputHook(MouseMovedEvent, 1)
Esc::ExitApp

MouseMovedEvent(x, y, info) {
    ToolTip "Mouse moved: " x " " y "`nusFlags: " info.flags ", usButtonFlags: " info.buttonFlags ", usButtonData: " info.buttonData ", device: " info.device
}

; Can be modified to get output from multiple input devices
; In AHK v2.1 the WM_INPUT message can be registered to a custom GUI, not the script itself (to prevent conflicts)
class MouseRawInputHook {
    ; EventType 1 = only mouse movement, 2 = only mouse clicks, 3 = both events
    __New(Callback, EventType:=3, UsagePage:=1, UsageId:=2) {
        static DevSize := 8 + A_PtrSize, RIDEV_INPUTSINK := 0x00000100
        this.RAWINPUTDEVICE := Buffer(DevSize, 0), this.EventType := EventType
        this.__Callback := this.__MouseRawInputProc.Bind(this), this.Callback := Callback
        NumPut("UShort", UsagePage, "UShort", UsageId, "UInt", RIDEV_INPUTSINK, "Ptr", A_ScriptHwnd, this.RAWINPUTDEVICE)
        DllCall("RegisterRawInputDevices", "Ptr", this.RAWINPUTDEVICE, "UInt", 1, "UInt", DevSize)
        OnMessage(0x00FF, this.__Callback)
        ObjRelease(ObjPtr(this)) ; Otherwise this object can't be destroyed because of the BoundFunc above
    }
    __Delete() {
        static RIDEV_REMOVE := 0x00000001, DevSize := 8 + A_PtrSize
        NumPut("Uint", RIDEV_REMOVE, this.RAWINPUTDEVICE, 4)
        DllCall("RegisterRawInputDevices", "Ptr", this.RAWINPUTDEVICE, "UInt", 1, "UInt", DevSize)
        ObjAddRef(ObjPtr(this))
        OnMessage(0x00FF, this.__Callback, 0)
        this.__Callback := 0
    }
    __MouseRawInputProc(wParam, lParam, *) {
        ; RawInput statics
        static DeviceSize := 2 * A_PtrSize, iSize := 0, sz := 0, pcbSize:=8+2*A_PtrSize, offsets := {usFlags: (8+2*A_PtrSize), usButtonFlags: (12+2*A_PtrSize), usButtonData: (14+2*A_PtrSize), x: (20+A_PtrSize*2), y: (24+A_PtrSize*2)}, uRawInput
        header := Buffer(pcbSize, 0)
        ; Find size of rawinput data - only needs to be run the first time.
        if (!iSize) {
            r := DllCall("GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", 0, "UInt*", &iSize, "UInt", 8 + (A_PtrSize * 2))
            uRawInput := Buffer(iSize, 0)
        }

        if !DllCall("GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", uRawInput, "UInt*", &sz := iSize, "UInt", 8 + (A_PtrSize * 2))
            return

        ; Read buffered RawInput data and accumulate the offsets
        device := NumGet(uRawInput, 8, "UPtr"), x_offset := 0, y_offset := 0, usButtonFlags := 0, usButtonData := 0, CallbackQueue := []

        ProcessInputBuffer:
        if NumGet(uRawInput, "UInt") = 1 ; Skip RIM_TYPEKEYBOARD
            goto ProcessCallbacks

        usFlags := NumGet(uRawInput, offsets.usFlags, "UShort")
        if (usButtonFlagsRaw := NumGet(uRawInput, offsets.usButtonFlags, "UShort")) {
            if (usButtonFlagsRaw & 0x400 || usButtonFlagsRaw & 0x800)
                usButtonData += NumGet(uRawInput, offsets.usButtonData, "Short")
            else if (this.EventType = 2) { ; Return if a mouse click is detected and callback only want clicks
                usButtonFlags |= usButtonFlagsRaw
                goto ProcessCallbacks
            }
        }
        usButtonFlags |= usButtonFlagsRaw, x_offset += NumGet(uRawInput, offsets.x, "Int"), y_offset += NumGet(uRawInput, offsets.y, "Int")

        if DllCall("GetRawInputBuffer", "Ptr", uRawInput, "UInt*", &sz := iSize, "UInt", 8 + (A_PtrSize * 2)) {
            if NumGet(uRawInput, 8, "UPtr") != device { ; If the message is from a different device then reset parameters
                AddCallbackToQueue()
                device := NumGet(uRawInput, 8, "UPtr"), x_offset := 0, y_offset := 0, usButtonFlags := 0, usButtonData := 0, usFlags := NumGet(uRawInput, offsets.usFlags, "ushort")
            }
            goto ProcessInputBuffer
        }

        ProcessCallbacks:
        AddCallbackToQueue()
        for Args in CallbackQueue
            pCallback := CallbackCreate(this.Callback.Bind(Args*)), DllCall(pCallback), CallbackFree(pCallback)
        
        AddCallbackToQueue() {
            if (this.EventType & 1 && !(x_offset = 0 && y_offset = 0)) || (this.EventType & 2 && usButtonFlags)
                CallbackQueue.Push([x_offset, y_offset, {flags: usFlags, buttonFlags: usButtonFlags, buttonData: usButtonData, device:device}])
        }
    }
}
```

### 3. WM_MOUSEMOVE Method (GUI Only)

```cpp
g := Gui()
g.Show("w400 h400")
g.OnEvent("Close", (*) => ExitApp())
g.MouseMoveActive := 0

F1::OnMessage(0x0200, WM_MOUSEMOVE, g.MouseMoveActive := !g.MouseMoveActive)
Esc::ExitApp

; More info: https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-mousemove
; wParam contains whether various virtual keys are down
WM_MOUSEMOVE(wParam, lParam, msg, hWnd) {
    if msg != 0x0200
        return
    x := lParam << 48 >> 48, y := lParam << 32 >> 48
    ToolTip "Mouse moved to client coords x" x " y" y
}
```

## Implementation Notes

- **SetTimer Method**: Simple but may miss fast movements or waste resources.
- **RawInput Method**: Event-driven, can discriminate between input devices, provides relative movement data.
- **SetWindowsHookEx Method**: Can block/intercept movements, but may introduce lag or conflicts with other hooks.
- **WM_MOUSEMOVE Method**: Limited to AHK GUI windows only.
- **AutoHotInterception**: Requires admin rights and external driver, but offers advanced detection and blocking.

## Related AHK Concepts

- MouseGetPos
- CoordMode
- OnMessage
- SetTimer
- Window Hooks

## Tags

#AutoHotkey #Mouse #InputDetection #EventHandling #Hooks