# Topic: Mouse Raw Input Hook

## Category

Class

## Overview

The MouseRawInputHook class provides an event-driven approach to detecting mouse movements and clicks using the Windows Raw Input API. This method allows for detection of relative mouse movement data and can discriminate between multiple input devices, making it useful for multi-device setups.

## Key Points

- True event-driven (no polling)
- Receives relative mouse movement data (dx, dy)
- Can discriminate between multiple input devices
- Doesn't introduce lag to mouse movements
- Can detect input from other devices (pen, joystick, etc.)

## Syntax and Parameters

```cpp
; Initialize the hook
mouseHook := MouseRawInputHook(callbackFunction, eventType, usagePage, usageId)

; Parameters:
; callbackFunction: Function to call when mouse event is detected
; eventType: 1 = only mouse movement, 2 = only mouse clicks, 3 = both (default)
; usagePage: Raw input usage page (default: 1 for generic desktop controls)
; usageId: Raw input usage ID (default: 2 for mouse)
```

## Code Examples

```cpp
#Requires AutoHotkey v2.0

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

## Implementation Notes

- The RawInput API works at a lower level than window messages
- Returns relative movement (dx, dy) rather than absolute positions
- Use `MouseGetPos` to get absolute screen coordinates when needed
- Cannot block mouse events like SetWindowsHookEx
- Buffer management is important for reliable operation 
- Handles multiple sequential events per WM_INPUT message
- Properly cleanups resources in __Delete method

## Related AHK Concepts

- Windows Raw Input API
- OnMessage
- Buffer manipulation
- CallbackCreate/CallbackFree
- DllCall
- Object lifecycle management

## Tags

#AutoHotkey #OOP #Mouse #RawInput #InputDetection #MultiDevice