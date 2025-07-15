# Topic: Function Types in AutoHotkey v2

## Category

Concept

## Overview

AutoHotkey v2 supports multiple function types with unique syntax and behavior patterns. Understanding the differences between traditional functions, arrow functions, method definitions, and how they interact with objects is essential for effective AHK v2 programming, especially in object-oriented contexts.

## Key Points

- Traditional functions, arrow functions, and method definitions each have distinct syntax and use cases
- Functions are first-class objects that can be stored, passed, and invoked dynamically
- Method context (`this`) depends on how a function is defined and called
- Arrow functions automatically capture the lexical environment where they're defined

## Syntax and Parameters

```cpp
; Traditional function
FunctionName(param1, param2) {
    ; Function body
    return result
}

; Arrow function
arrowFunction := (param1, param2) => expression
arrowFunctionWithBody := (param1, param2) => {
    ; Multiple statements
    return result
}

; Method in a class
class ClassName {
    MethodName(param1, param2) {
        ; Method body
        return result
    }
    
    ; Method using arrow syntax (AHK v2 specific)
    ArrowMethod(param) => expression
}

; Function as object property
obj := { method: (a, b) => a + b }
```

## Code Examples

```cpp
#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

; Traditional named function
MyFunction(a, b) {
    return a * b
}

; Arrow function stored in a variable
multiply := (a, b) => a * b

; Function stored as object property
calculator := {
    add: (a, b) => a + b,
    subtract: (a, b) => a - b
}

; Class with various method types
class MathHelper {
    ; Regular method
    Multiply(a, b) {
        return a * b
    }
    
    ; Arrow syntax method (shorthand for simple methods)
    Add(a, b) => a + b
    
    ; Static method
    static Subtract(a, b) {
        return a - b
    }
    
    ; Demonstrating different function calls
    DemoFunctions() {
        ; Call traditional function
        result1 := MyFunction(5, 3)
        
        ; Call arrow function
        result2 := multiply(5, 3)
        
        ; Call object property function
        result3 := calculator.add(5, 3)
        
        ; Call instance method (with this context)
        result4 := this.Multiply(5, 3)
        
        ; Call static method
        result5 := MathHelper.Subtract(5, 3)
        
        return { r1: result1, r2: result2, r3: result3, r4: result4, r5: result5 }
    }
}

; Create instance and demo functions
math := MathHelper()
results := math.DemoFunctions()

; Display results
for key, value in results
    MsgBox key ": " value
```

## Implementation Notes

- Traditional functions preserve the `this` value based on how they're called
- Arrow functions capture the `this` value from their surrounding context
- When binding methods to events, use `this.Method.Bind(this)` to preserve context
- Arrow function alternative for events: `(*) => this.Method()`
- The asterisk (*) in arrow functions means accepting any arguments without using them
- Prefer arrow methods for simple expression-based returns
- Use `=>` for methods that return a single expression without needing a full block

## Related AHK Concepts

- Method Binding and Context
- Event Handling
- Class Definition and Method Types
- Function Objects and Callbacks
- `this` keyword behavior

## Tags

#AutoHotkey #OOP #Functions #ArrowFunctions #MethodDefinition #FirstClassFunctions