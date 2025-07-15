# Topic: MouseRawInputHook Class

## Category

Snippet

## Overview

The MouseRawInputHook class provides a clean, object-oriented approach to monitoring mouse movement using the Windows RawInput API. This implementation allows for event-driven mouse tracking without the performance overhead of polling or the potential input lag of keyboard hooks. It can detect both physical and artificial input, and can distinguish between different input devices.

## Key Points

- Uses RawInput for event-driven mouse movement detection
- Can filter events by type (movement, clicks, or both)
- Automatically buffers and processes multiple input events
- Handles device identification for multi-device setups
- Properly cleans up resources when the object is destroyed

## Syntax and Parameters

```cpp
mouseMoveHook := MouseRawInputHook(Callback, EventType, UsagePage, UsageId)
```

- `Callback`: Function to call when mouse movement is detected
- `EventType`: Optional, 1=movement only, 2=clicks only, 3=both (default)
- `UsagePage`: Optional, device class (default=1 for generic desktop controls)
- `UsageId`: Optional, specific device type (default=2 for mouse)

## Code Examples

```cpp
; Basic usage example
#Requires AutoHotkey v2.0 

; Initialize the hook, only detecting movements (not clicks)
g_RawInputHook := MouseRawInputHook(MouseMovedEvent, 1)

; Toggle hook on/off with F1
F1::global g_RawInputHook := g_RawInputHook ? 0 : MouseRawInputHook(MouseMovedEvent, 1)
Esc::ExitApp

; Callback function
MouseMovedEvent(x, y, info) {
    ToolTip "Mouse moved: " x " " y "`nusFlags: " info.flags 
        . ", usButtonFlags: " info.buttonFlags 
        . ", usButtonData: " info.buttonData 
        . ", device: " info.device
}

; Class implementation follows
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

- The class handles proper initialization and cleanup of the RawInput device registration
- It manages multiple input events in a queue to ensure all movements are processed
- Uses relative mouse movement data which indicates direction and amount, not absolute position
- To get absolute position, combine with MouseGetPos in the callback function
- Works with AHK v2.0 and above; in v2.1 the WM_INPUT message can be registered to a custom GUI
- Special handling for reference counting (ObjRelease/ObjAddRef) ensures proper garbage collection
- The __MouseRawInputProc method optimizes performance by:
  * Processing multiple buffered events in a single call
  * Separating devices and their inputs
  * Only creating callbacks for events that match the requested EventType

## Related AHK Concepts

- OnMessage - Used to capture the WM_INPUT (0x00FF) messages
- CallbackCreate/CallbackFree - Used for performance-critical callback functions
- Buffer - For creating structured memory for Windows API interaction
- DllCall - Used for direct Windows API access
- MouseGetPos - Can be combined with this class for absolute positioning

## Tags

#AutoHotkey #RawInput #MouseTracking #EventDriven #InputDetection #Class