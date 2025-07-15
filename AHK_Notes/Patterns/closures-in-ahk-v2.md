# Topic: Closures in AHK v2

## Category

Pattern

## Overview

Closures in AutoHotkey v2 are functions that "remember" the environment in which they were created. This powerful programming pattern allows for the creation of encapsulated state and the implementation of various advanced programming patterns, including data privacy, function factories, and callbacks with preserved context.

## Key Points

- Closures in AHK v2 automatically capture variables from their outer scope
- They can be used to create private state that persists between function calls
- Closures serve as a foundation for implementing advanced patterns like function factories and modules
- They allow for creating callbacks that maintain access to specific data contexts

## Syntax and Parameters

```cpp
; Basic closure syntax
OuterFunction(outerParam) {
    outerVar := "I'm from the outer scope"
    
    ; This inner function is a closure
    InnerFunction(innerParam) {
        ; Can access both its own variables and those from outer scope
        return outerParam " - " outerVar " - " innerParam
    }
    
    ; Return the inner function
    return InnerFunction
}
```

## Code Examples

```cpp
; Function factory example - creates a counter
CreateCounter(startValue := 0) {
    currentValue := startValue
    
    counter := {
        ; These methods form closures around currentValue
        Increment: () => ++currentValue,
        Decrement: () => --currentValue,
        GetValue: () => currentValue,
        Reset: (newStart := 0) => (currentValue := newStart)
    }
    
    return counter
}

; Create two independent counters
counterA := CreateCounter(10)
counterB := CreateCounter(100)

counterA.Increment()  ; Returns 11
counterA.Increment()  ; Returns 12
valueA := counterA.GetValue()  ; 12

counterB.Increment()  ; Returns 101
valueB := counterB.GetValue()  ; 101

; Function that returns a function with preset arguments
CreateMultiplier(factor) {
    return (x) => x * factor
}

double := CreateMultiplier(2)
triple := CreateMultiplier(3)

result1 := double(5)  ; Returns 10
result2 := triple(5)  ; Returns 15

; Event handler with preserved context
CreateButtonHandler(buttonName, action) {
    clickCount := 0
    
    return (*) => {
        clickCount++
        action.Call(buttonName, clickCount)
    }
}

HandleButtonClick(name, count) {
    MsgBox "Button " name " was clicked " count " times!"
}

; Buttons with their own counters
button1Handler := CreateButtonHandler("Button 1", HandleButtonClick)
button2Handler := CreateButtonHandler("Button 2", HandleButtonClick)

; Simulate button clicks
button1Handler()  ; Shows "Button Button 1 was clicked 1 times!"
button1Handler()  ; Shows "Button Button 1 was clicked 2 times!"
button2Handler()  ; Shows "Button Button 2 was clicked 1 times!"
```

## Implementation Notes

- Variables captured by closures are captured by reference, not by value
- The reference to the outer scope's environment persists as long as the closure exists
- Multiple closures from the same scope share access to the same variables
- Circular references between closures can cause memory leaks due to AHK's reference counting system
- Local variables in functions are not truly private - they're just harder to access from outside
- Closures can cause unexpected behavior if the developer doesn't understand variable lifetime and scope

## Related AHK Concepts

- First-Class Functions
- Anonymous Functions
- Object Methods
- Variable Scope
- Memory Management

## Tags

#AutoHotkey #OOP #Closures #FunctionFactory #Callbacks #AdvancedPatterns