# Topic: Callback Functions in AutoHotkey v2

## Category

Concept

## Overview

Callback functions are functions that are passed as arguments to other functions and are executed at a later time or in response to events. In AutoHotkey v2, callbacks are a fundamental concept for event-driven programming, GUI development, timers, and asynchronous operations, enabling powerful and flexible programming patterns.

## Key Points

- Callbacks can be traditional functions, methods, bound methods, or function objects (including arrow functions)
- Event handling in GUIs relies heavily on callbacks through the OnEvent method
- Callbacks may need to be properly bound to preserve context when used as methods
- Arrow functions (`=>`) provide a concise syntax for simple callbacks with lexical `this` binding
- Understanding parameter passing and return values is crucial for effective callback usage

## Syntax and Parameters

```cpp
; Traditional function as callback
MyCallback(param1, param2) {
    ; Function body
}

; Using function as callback with SetTimer
SetTimer(MyCallback, 1000)  ; Call MyCallback every 1000ms

; Method as callback (requires binding to preserve context)
class MyClass {
    MyMethod(param1, param2) {
        ; Method body
    }
}
obj := MyClass()
boundMethod := ObjBindMethod(obj, "MyMethod", fixedParam)
SetTimer(boundMethod, 1000)

; Arrow function as callback (anonymous function with lexical this)
myCallback := (param1, param2) => {
    ; Function body
}

; Arrow function directly as event handler
myButton.OnEvent("Click", (ctrl) => MsgBox("Button was clicked!"))
```

## Code Examples

```cpp
; Example 1: GUI with various callback styles
MyGui := Gui("+Resize", "Callback Examples")
MyGui.SetFont("s10")

; Example using traditional function
MyGui.Add("Button", "w200 h30", "Traditional Callback").OnEvent("Click", TraditionalCallback)

TraditionalCallback(ctrl, info) {
    MsgBox("Button clicked using traditional function callback")
}

; Example using bound method
class ButtonHandler {
    guiRef := ""
    
    __New(gui) {
        this.guiRef := gui
    }
    
    HandleClick(ctrl, info) {
        MsgBox("Button clicked using bound method callback")
        ; Can access the class instance via this
        this.guiRef.Opt("+AlwaysOnTop")
    }
}

handler := ButtonHandler(MyGui)
boundCallback := ObjBindMethod(handler, "HandleClick")
MyGui.Add("Button", "w200 h30 y+10", "Bound Method Callback").OnEvent("Click", boundCallback)

; Example using arrow function (concise for simple callbacks)
MyGui.Add("Button", "w200 h30 y+10", "Arrow Function Callback")
       .OnEvent("Click", (ctrl, info) => MsgBox("Button clicked using arrow function"))

; Example using SetTimer with different callback types
MyGui.Add("Button", "w200 h30 y+10", "Start Timer (Traditional)").OnEvent("Click", (*) => 
    SetTimer(TimerCallback, 1000)
)

TimerCallback() {
    ToolTip("Timer running... " A_TickCount)
}

MyGui.Add("Button", "w200 h30 y+10", "Start Timer (Arrow)").OnEvent("Click", (*) => {
    timerFn := () => ToolTip("Arrow timer: " A_TickCount)
    SetTimer(timerFn, 1000)
})

; Example using callbacks with parameters
MyGui.Add("Button", "w200 h30 y+10", "Parameterized Callback").OnEvent("Click", (*) => {
    ; Parameters can be fixed via ObjBindMethod
    boundWithParams := ObjBindMethod(MyMessageClass, "ShowMessage", "Hello", "World")
    SetTimer(boundWithParams, -100)  ; -100 means run once after 100ms
})

class MyMessageClass {
    static ShowMessage(param1, param2) {
        MsgBox(param1 " " param2 "!")
    }
}

; Show the GUI
MyGui.Show()

; Example 2: Creating a custom event system with callbacks
class EventSystem {
    static events := Map()
    
    static Subscribe(eventName, callback) {
        if (!this.events.Has(eventName))
            this.events[eventName] := []
            
        this.events[eventName].Push(callback)
    }
    
    static Unsubscribe(eventName, callback) {
        if (!this.events.Has(eventName))
            return
            
        for i, cb in this.events[eventName] {
            if (cb == callback) {
                this.events[eventName].RemoveAt(i)
                break
            }
        }
    }
    
    static Trigger(eventName, params*) {
        if (!this.events.Has(eventName))
            return
            
        for i, callback in this.events[eventName].Clone() {
            try {
                callback(params*)
            } catch as err {
                OutputDebug("Error in event callback: " err.Message)
            }
        }
    }
}

; Usage example
logToConsole := (text) => OutputDebug("LOG: " text)
showMessage := (text) => MsgBox("NOTIFICATION: " text)

; Subscribe to "notification" event with multiple callbacks
EventSystem.Subscribe("notification", logToConsole)
EventSystem.Subscribe("notification", showMessage)

; Trigger an event (all registered callbacks will be called)
EventSystem.Trigger("notification", "This is a test notification")
```

## Implementation Notes

- **Context Preservation**: When using methods as callbacks, remember that the method loses its class context (`this`) unless properly bound with `ObjBindMethod`
- **Memory Management**: Callbacks create references that persist until explicitly cleared, potentially causing memory leaks if not managed properly
- **Performance Considerations**: 
  - Arrow functions are convenient but create new objects each time, which can impact performance in tight loops
  - `ObjBindMethod` has slightly higher overhead than direct function references
- **Error Handling**: Errors in callbacks can be difficult to trace; consider wrapping callback execution in try-catch blocks
- **Debugging Tips**: For debugging complex callback chains, consider adding debug information to callbacks or using OutputDebug to trace execution flow
- **Parameter Passing**: Be aware of how parameters are passed to callbacks, especially with GUI events where the control and event info are provided automatically

## Related AHK Concepts

- [Method Binding and Context](./method-binding-and-context.md)
- [First Class Functions](./First_Class_Functions.md)
- [GUI Controls and Patterns](./GUI_Controls_and_Patterns.md)
- [Closures in AHK v2](../Patterns/closures-in-ahk-v2.md)
- [Event-Driven GUI](../Snippets/event-driven-gui.md)

## Tags

#AutoHotkey #OOP #Callbacks #Functions #EventDriven #GUI #Methods #ArrowFunctions