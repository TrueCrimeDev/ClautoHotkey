# Topic: AutoHotkey v2 Programming Paradigms

## Category
Concept

## Overview
AutoHotkey v2 implements multiple programming paradigms that mirror features found in other modern languages. It combines prototype-based OOP, first-class functions, and functional programming patterns that make it both flexible and powerful for scripting and application development.

## Key Points
- AHK v2 uses prototype-based OOP similar to JavaScript, with classes, inheritance, and static properties
- Functions are first-class citizens that can be passed as arguments, returned from other functions, or assigned to variables
- AHK v2 supports multiple function definition styles including named functions, anonymous functions, and arrow functions
- Array and Map objects provide collection functionality similar to JavaScript arrays and Python dictionaries

## Syntax and Parameters

```cpp
; Class definition
class MyClass {
    static Config := "default"  ; Static property
    __New(param) {              ; Constructor
        this.value := param
    }
    Method() => "result"        ; Method using arrow function syntax
}

; Function definition styles
; Named function
MyFunction(x) {
    return x * 2
}

; Anonymous function
foo := (x) {
    return x * 2
}

; Arrow function
bar := (x) => x * 2

; Array and Map usage
myArray := [1, 2, 3]
myArray.Push(4)

myMap := Map("key", "value")
myMap["newKey"] := "newValue"
```

## Code Examples

```cpp
; Example of class usage and inheritance
class Animal {
    static Kingdom := "Animalia"
    
    __New(name) {
        this.Name := name
    }
    
    Speak() {
        return "Animal sound"
    }
}

class Dog extends Animal {
    __New(name, breed) {
        super.__New(name)
        this.Breed := breed
    }
    
    Speak() {
        return "Woof!"
    }
}

; First-class functions example
CalculateArea(shape, dimensionCallback) {
    dimensions := dimensionCallback()
    if (shape = "rectangle")
        return dimensions.length * dimensions.width
    else if (shape = "circle")
        return 3.14159 * dimensions.radius * dimensions.radius
}

GetRectangleDimensions := () => {
    return {length: 10, width: 5}
}

area := CalculateArea("rectangle", GetRectangleDimensions)
```

## Implementation Notes
- AHK v2 uses 1-based indexing for arrays (like Lua), unlike the 0-based indexing common in most programming languages
- Reference counting is used for garbage collection, similar to Python and PHP
- String concatenation is implicit (e.g., `msg := "Hello " name`) rather than using interpolation (like JavaScript's template literals)
- The ability to compile scripts to executables (via AHK2EXE) is a standout feature not common in scripting languages

## Related AHK Concepts
- Class Definition and Inheritance
- Function Closures
- Array and Map Methods
- Reference Counting and Memory Management
- Expression Syntax (expressions vs. legacy commands)

## Tags
#AutoHotkey #OOP #Programming #Paradigms #Functions #Classes #FirstClassFunctions #Prototype
