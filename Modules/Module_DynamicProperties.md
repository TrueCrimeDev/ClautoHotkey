# AutoHotkey v2 Fat Arrow Functions: Training Module

## Introduction to Fat Arrow Functions

```cpp
#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

; Traditional function vs fat arrow
TraditionalAdd(a, b) {
    return a + b
}

; Equivalent fat arrow function
arrowAdd := (a, b) => a + b

MsgBox "Traditional: " TraditionalAdd(5, 3) "`nFat arrow: " arrowAdd(5, 3)
```

## Basic Syntax and Variations

```cpp
; Basic syntax: (parameters) => expression
multiply := (x, y) => x * y

; No parameters
greet := () => "Hello, world!"

; Single parameter (parentheses optional)
square := x => x * x

; Multiple parameters (parentheses required)
average := (a, b, c) => (a + b + c) / 3

MsgBox multiply(4, 5) "`n" greet() "`n" square(4) "`n" average(3, 5, 8)
```

## Named Fat Arrow Functions

```cpp
; Named fat arrow function (enables recursion)
factorial := Fact(n) => n <= 1 ? 1 : n * Fact(n-1)

; Equivalent traditional function
Factorial(n) {
    return n <= 1 ? 1 : n * Factorial(n-1)
}

MsgBox "Fat arrow factorial: " factorial(5) "`nTraditional: " Factorial(5)
```

## Multi-line Fat Arrow Functions

```cpp
; Multi-line with curly braces
processUser := (name, age) => {
    greeting := "Hello, " name
    status := age >= 18 ? "adult" : "minor"
    return greeting ". You are an " status "."
}

MsgBox processUser("Alex", 25)
```

## Closures and Variable Capture

```cpp
; Fat arrow functions capture their environment
CreateCounter() {
    count := 0
    return {
        increment: () => ++count,
        decrement: () => --count,
        getValue: () => count
    }
}

counter := CreateCounter()
counter.increment()
counter.increment()
counter.increment()
counter.decrement()

MsgBox "Current count: " counter.getValue()
```

## Callbacks with Fat Arrow Functions

```cpp
; As event handlers
myGui := Gui()
myButton := myGui.AddButton("w200", "Click Me")
myButton.OnEvent("Click", (*) => MsgBox("Button clicked!"))

; As timer callbacks
callCount := 0
SetTimer(() => {
    callCount++
    ToolTip "Timer called " callCount " times"
}, 1000)
```

## Fat Arrow Methods in Classes and Objects

```cpp
class Calculator {
    ; Class with fat arrow methods
    add => (a, b) => a + b
    
    ; Shorthand property (getter only)
    version => "1.0"
    
    ; Fat arrow method capturing this
    multiply => (a, b) => {
        this.logOperation("multiply", a, b)
        return a * b
    }
    
    logOperation(op, a, b) {
        FileAppend "Operation: " op "(" a ", " b ")`n", "calc_log.txt"
    }
}

calc := Calculator()
MsgBox "5 + 3 = " calc.add(5, 3) "`nVersion: " calc.version
```

## Best Practices

```cpp
; DO: Use for simple, focused operations
isEven := n => Mod(n, 2) = 0

; DO: Use descriptive names for named functions
validateInput := ValidateEmail(email) => RegExMatch(email, "i)^[^@\s]+@[^@\s]+\.[^@\s]+$")

; DO: Use for event handlers to avoid scoping issues
button.OnEvent("Click", (*) => this.HandleClick())

; DON'T: Overuse for complex multi-line functions
; Better as a traditional function if complex
```

## Common Pitfalls and Solutions

```cpp
; PITFALL: Missing parentheses with multiple parameters
; Wrong:
subtract := a, b => a - b  ; This will fail

; Correct:
subtract := (a, b) => a - b

; PITFALL: Recursive anonymous functions
; This won't work as expected:
badFactorial := (n) => n <= 1 ? 1 : n * badFactorial(n-1)

; Solution - use named version:
goodFactorial := Fact(n) => n <= 1 ? 1 : n * Fact(n-1)

; PITFALL: Expecting 'this' to work like in traditional methods
; Fix by using .Bind(this) for callbacks
```

## Advanced Techniques

```cpp
; Function composition
compose := (f, g) => (x) => f(g(x))
addOne := x => x + 1
double := x => x * 2
addThenDouble := compose(double, addOne)
MsgBox addThenDouble(5)  ; (5+1)*2 = 12

; Partial application
partial := (fn, x) => (y) => fn(x, y)
add10 := partial((a, b) => a + b, 10)
MsgBox add10(5)  ; 10+5 = 15

; Currying
curriedAdd := (a) => (b) => (c) => a + b + c
MsgBox curriedAdd(1)(2)(3)  ; 1+2+3 = 6
```

## Prompt Engineering Guidance

When writing fat arrow functions:

1. Keep them focused on a single operation when possible
2. Use named functions when recursion is needed
3. Maintain consistent arrow syntax throughout your codebase
4. Capture parent scope variables intentionally, not accidentally
5. Handle 'this' binding carefully in class methods
6. Prefer single-line expressions for readability
7. Use multi-line fat arrows only when necessary
8. Consider optimization implications in performance-critical code
9. Document the purpose when using advanced techniques
10. Test edge cases thoroughly, especially with closures


# Dynamic Properties in AutoHotkey v2

Yes, AutoHotkey v2 has two related concepts: fat arrow properties and dynamic properties.

## Fat Arrow Properties

```cpp
#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

DynamicPropertyExample()
class DynamicPropertyExample {
    ; Simple fat arrow property (getter only)
    name => "DynamicPropertyExample"
    
    ; Fat arrow property that computes its value
    currentTime => FormatTime(, "HH:mm:ss")
    
    ; Fat arrow property with parameter
    squareOf[x] => x * x
    
    ; Fat arrow property with get/set
    _counter := 0
    counter {
        get => this._counter
        set => this._counter := value
    }
}

example := DynamicPropertyExample()
MsgBox "Class name: " example.name
MsgBox "Current time: " example.currentTime
MsgBox "Square of 5: " example.squareOf[5]

; Counter with getter/setter
example.counter := 10
MsgBox "Counter value: " example.counter
```

## True Dynamic Properties (Runtime Properties)

```cpp
#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

TrueDynamicProps()
class TrueDynamicProps {
    ; Storage for dynamic properties
    _props := Map()
    
    ; Meta-function called when undefined property is accessed
    __Get(name, params) {
        if this._props.Has(name)
            return this._props[name]
        return "Property '" name "' not found"
    }
    
    ; Meta-function called when undefined property is set
    __Set(name, params, value) {
        this._props[name] := value
    }
    
    ; Function to show all dynamic properties
    ListProperties() {
        result := ""
        for name, value in this._props
            result .= name ": " value "`n"
        return result
    }
}

; Create instance
dynObj := TrueDynamicProps()

; Set properties that don't exist in the class definition
dynObj.color := "Blue"
dynObj.size := "Large"
dynObj.created := FormatTime(, "yyyy-MM-dd")

; Access the dynamic properties
MsgBox "Dynamic properties:`n" dynObj.ListProperties()
MsgBox "Accessing undefined property: " dynObj.nonexistent
```

## Key Differences

| Feature | Fat Arrow Properties | True Dynamic Properties |
|---------|---------------------|------------------------|
| Definition | Defined at class creation | Created at runtime |
| Syntax | `prop => expression` | Handled via `__Get`/`__Set` |
| Computation | Can be computed each time | Can implement any logic |
| Parameters | Can have parameters | Can have parameters via meta-functions |
| Storage | No extra storage needed | Usually requires storage (like Map) |
| Use case | Computed/derived values | Fully dynamic property creation |

Fat arrow properties provide a concise syntax for defining computed properties or shorthand getters and setters, while true dynamic properties allow creating completely new properties at runtime through meta-functions.

