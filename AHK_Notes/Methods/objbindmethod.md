# Topic: ObjBindMethod

## Category

Method

## Overview

ObjBindMethod is a built-in function in AutoHotkey v2 that binds a method to an object instance, creating a function object that preserves the context when called later. This is essential for event callbacks, timers, and any scenario where a method needs to be called with its proper "this" context preserved.

## Key Points

- Creates a callable function object that maintains the original object's context (this reference)
- Allows methods to be used as callbacks without losing their object binding
- Can pre-bind parameters, effectively creating partial application of functions
- Returns a BoundFunc object which can be called or passed to functions expecting callbacks
- Critical for event-driven programming with classes in AutoHotkey v2

## Syntax and Parameters

```cpp
BoundFunc := ObjBindMethod(Object, MethodName [, Param1, Param2, ...])
```

- **Object**: The object instance whose method will be bound
- **MethodName**: String containing the name of the method to bind
- **Param1, Param2, ...**: Optional parameters to pre-bind to the method call
- **Return Value**: A function object (BoundFunc) that can be called later

## Code Examples

```cpp
; Example 1: Basic method binding for a timer
class Counter {
    count := 0
    
    Increment() {
        this.count++
        ToolTip("Count: " this.count)
    }
    
    StartCounting() {
        ; Without binding, "this" would not refer to the Counter instance when called by SetTimer
        boundIncrement := ObjBindMethod(this, "Increment")
        SetTimer(boundIncrement, 1000)  ; Call every second
        return boundIncrement  ; Return the bound function for later use (to stop the timer)
    }
    
    StopCounting(timerFunc) {
        SetTimer(timerFunc, 0)  ; Stop the timer
    }
}

; Usage
myCounter := Counter()
boundFunc := myCounter.StartCounting()

; Later, to stop counting
Sleep(5000)  ; Let it count for 5 seconds
myCounter.StopCounting(boundFunc)

; Example 2: Using bound methods for GUI events
class MyApp {
    gui := ""
    status := ""
    
    __New() {
        this.gui := Gui("+Resize", "Bound Method Example")
        this.gui.SetFont("s10")
        
        ; Add controls
        this.gui.Add("Button", "w200 h30", "Click Me").OnEvent("Click", ObjBindMethod(this, "HandleClick"))
        this.status := this.gui.Add("Text", "w200 h30 y+10", "Status: Ready")
        
        ; Binding methods with parameters
        this.gui.Add("Button", "w200 h30 y+10", "Say Hello").OnEvent("Click", 
            ObjBindMethod(this, "ShowMessage", "Hello", "World"))
        
        this.gui.Add("Button", "w200 h30 y+10", "Say Goodbye").OnEvent("Click", 
            ObjBindMethod(this, "ShowMessage", "Goodbye", "Friend"))
    }
    
    HandleClick(ctrl, info) {
        ; Here, "this" correctly refers to the MyApp instance
        this.status.Value := "Status: Button clicked at " FormatTime(, "HH:mm:ss")
    }
    
    ShowMessage(message1, message2, ctrl := "", info := "") {
        ; Pre-bound parameters come first, followed by any parameters from the event
        MsgBox(message1 " " message2 "!")
        
        ; We can still access the control that triggered this if needed
        if (ctrl != "")
            this.status.Value := "Status: Clicked '" ctrl.Text "' button"
    }
    
    Show() {
        this.gui.Show()
    }
}

; Create and show the app
app := MyApp()
app.Show()

; Example 3: Creating a callback collection with parameter binding
class CallbackManager {
    callbacks := Map()
    
    RegisterCallback(name, callback) {
        this.callbacks[name] := callback
    }
    
    ExecuteCallback(name, params*) {
        if (this.callbacks.Has(name))
            return this.callbacks[name](params*)
        return false
    }
}

; Usage
manager := CallbackManager()

; Create an object with a method
dataProcessor := {
    ProcessData(data, extraInfo := "") {
        result := "Processed: " data
        if (extraInfo)
            result .= " (" extraInfo ")"
        return result
    }
}

; Register a bound method with pre-bound parameter
manager.RegisterCallback("processWithTimestamp", 
    ObjBindMethod(dataProcessor, "ProcessData", , "timestamp: " FormatTime(, "HH:mm:ss")))

; Execute the callback later
result := manager.ExecuteCallback("processWithTimestamp", "Sample data")
MsgBox(result)  ; Shows "Processed: Sample data (timestamp: HH:MM:SS)"
```

## Implementation Notes

- **Memory Management**: Bound methods create references to the original object, which prevents it from being garbage collected as long as the bound method exists
- **Parameter Handling**: 
  - Pre-bound parameters from ObjBindMethod are passed first, followed by runtime parameters
  - To skip a parameter when pre-binding, use commas with no value between them (as shown in Example 3)
- **Return Value**: When the bound method is called, it returns whatever the original method returns
- **Performance Considerations**: There is a small performance overhead when using bound methods compared to direct function calls
- **Comparison**: Two bound methods to the same object and method are considered distinct objects, even if they bind the same parameters
- **Method Lookup**: The method is looked up by name at binding time, not at call time, so subsequent changes to the object's method won't affect already bound methods
- **Error Handling**: If the method doesn't exist, an exception is thrown at binding time, not at call time

## Related AHK Concepts

- [Method Binding and Context](../Concepts/method-binding-and-context.md)
- [Callback Functions](../Concepts/callback-functions.md)
- [First Class Functions](../Concepts/First_Class_Functions.md)
- [Event-Driven GUI](../Snippets/event-driven-gui.md)
- [__Call Method](../Methods/__call-method.md)

## Tags

#AutoHotkey #OOP #Method #Binding #Callbacks #Functions #EventHandling