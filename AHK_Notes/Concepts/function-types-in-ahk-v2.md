# Topic: Function Types in AHK v2

## Category

Concept

## Overview

AutoHotkey v2 supports multiple function definition styles that enhance code flexibility and expressiveness. These function types include named functions, anonymous functions, and arrow functions, similar to modern languages like JavaScript and Python, making AHK v2 capable of both procedural and functional programming approaches.

## Key Points

- AHK v2 supports three main function types: named functions, anonymous functions, and arrow functions
- Functions in AHK v2 are first-class citizens, meaning they can be assigned to variables and passed as arguments
- Arrow functions provide a concise syntax for simple operations, enhancing code readability
- AHK v2 supports implicit closures, allowing functions to "remember" their creation environment

## Syntax and Parameters

```cpp
; Named Function Syntax
NamedFunction(param1, param2 := "default") {
    ; Function body
    return result
}

; Anonymous Function Syntax
anonymousFunc := function(param1, param2 := "default") {
    ; Function body
    return result
}

; Arrow Function Syntax
arrowFunc := (param1, param2 := "default") => expression

; Function with variable number of parameters
variadicFunc(firstParam, params*) {
    ; Access params as an array
}
```

## Code Examples

```cpp
; Named Function Example
Multiply(x, y) {
    return x * y
}
result := Multiply(5, 10)  ; result = 50

; Anonymous Function Example
add := function(x, y) {
    return x + y
}
result := add(5, 10)  ; result = 15

; Arrow Function Example - implicit return
double := (x) => x * 2
result := double(5)  ; result = 10

; Passing a function as an argument
ProcessNumbers(numbers, operation) {
    result := []
    for number in numbers
        result.Push(operation(number))
    return result
}

; Using the function with different operations
numbers := [1, 2, 3, 4, 5]
doubled := ProcessNumbers(numbers, (x) => x * 2)  ; [2, 4, 6, 8, 10]
squared := ProcessNumbers(numbers, (x) => x * x)  ; [1, 4, 9, 16, 25]

; Closure example - function that remembers its environment
CreateCounter(startValue := 0) {
    current := startValue
    return {
        Increment: () => ++current,
        Decrement: () => --current,
        GetValue: () => current
    }
}

counter := CreateCounter(10)
counter.Increment()  ; Returns 11
counter.Increment()  ; Returns 12
value := counter.GetValue()  ; value = 12
```

## Implementation Notes

- Arrow functions using the `=>` syntax are more concise but limited to expressions that can be evaluated directly
- Closures in AHK v2 automatically capture variables from the outer scope, which can lead to unexpected behavior if not well understood
- The `function` keyword for anonymous functions is available but the more concise syntax using parentheses and curly braces is more common
- Unlike some other languages, AHK v2 function parameters cannot have type annotations, so type checking must be done manually if needed

## Related AHK Concepts

- Closures and Variable Scope
- Callback Functions
- Objects and Methods
- First-Class Functions
- Function Chaining

## Tags

#AutoHotkey #OOP #Functions #FunctionalProgramming #Closures #Callbacks