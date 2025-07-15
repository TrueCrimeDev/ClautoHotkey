# Topic: First-Class Functions in AutoHotkey v2

## Category
Concept

## Overview
First-class functions are a core programming feature in AutoHotkey v2 where functions are treated as values that can be assigned to variables, passed as arguments, returned from other functions, and stored in data structures. This paradigm enables more flexible, modular, and functional programming approaches.

## Key Points
- Functions can be assigned to variables and stored in arrays or maps
- Functions can be passed as arguments to other functions (callbacks)
- Functions can be returned from other functions (function factories)
- AHK v2 supports multiple function definition styles: named functions, anonymous functions, and arrow functions
- Closures are supported, allowing functions to "remember" their creation environment

## Syntax and Parameters
```cpp
; Named function
NamedFunction(param1, param2) {
    return param1 + param2
}

; Anonymous function assigned to variable
anonFunc := (param1, param2) {
    return param1 * param2
}

; Arrow function (compact syntax)
arrowFunc := (param1, param2) => param1 / param2

; Function with optional parameters
funcWithDefaults(required, optional := 10) {
    return required + optional
}

; Variadic function (accepts variable number of parameters)
variadicFunc(required, params*) {
    result := required
    for param in params
        result += param
    return result
}
```

## Code Examples
```cpp
; Example 1: Functions as callback arguments
ProcessItems(items, processor) {
    results := []
    for item in items
        results.Push(processor(item))
    return results
}

; Different processors can be passed in
double := (x) => x * 2
square := (x) => x * x

numbers := [1, 2, 3, 4, 5]
doubledNumbers := ProcessItems(numbers, double)    ; [2, 4, 6, 8, 10]
squaredNumbers := ProcessItems(numbers, square)    ; [1, 4, 9, 16, 25]

; Example 2: Function factory (returns a function)
CreateMultiplier(factor) {
    return (x) => x * factor
}

multiplyByTwo := CreateMultiplier(2)
multiplyByTen := CreateMultiplier(10)

result1 := multiplyByTwo(5)    ; 10
result2 := multiplyByTen(5)    ; 50

; Example 3: Storing functions in data structures
operations := Map(
    "add", (x, y) => x + y,
    "subtract", (x, y) => x - y,
    "multiply", (x, y) => x * y,
    "divide", (x, y) => x / y
)

result := operations["multiply"](6, 7)    ; 42
```

## Implementation Notes
- AHK v2's implementation of closures allows functions to retain access to their parent scope
- Anonymous functions and arrow functions are particularly useful for short callbacks
- Arrow function syntax `=>` works best for simple, single-expression functions
- When functions are passed as callbacks, consider error handling since errors inside callbacks can be harder to debug
- Function references are different from function calls - omit the parentheses when passing a function as a value

## Related AHK Concepts
- Closures and Variable Scope
- Event Handling with Callbacks
- Object Methods
- Functional Programming Patterns
- Class Methods vs Standalone Functions

## Tags
#AutoHotkey #FirstClassFunctions #Callbacks #FunctionFactory #ArrowFunctions #Closures #FunctionalProgramming
