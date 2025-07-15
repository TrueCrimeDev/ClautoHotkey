# Topic: Class Creation in AutoHotkey

## Category
Concept

## Overview
Creating classes in AutoHotkey enables object-oriented programming patterns for more modular, reusable, and maintainable code. Classes were introduced in AutoHotkey v2 and provide a way to combine related data and functionality into self-contained units.

## Key Points
- Classes are defined using the `class` keyword followed by the class name
- Constructor methods named `__New()` initialize new instances of the class
- Properties store data while methods perform actions
- Classes can inherit from parent classes using the `extends` keyword

## Syntax and Parameters

```cpp
class ClassName [extends ParentClass] {
    ; Static properties
    static StaticProperty := Value
    
    ; Constructor
    __New(Parameters*) {
        ; Initialize instance properties
        this.Property := Value
    }
    
    ; Methods
    MethodName(Parameters*) {
        ; Method code
        return Value
    }
}

; Creating an instance
MyObject := new ClassName(Parameters*)
```

## Code Examples

```cpp
; Simple person class
class Person {
    ; Static property shared across all instances
    static Count := 0
    
    ; Constructor
    __New(name, age) {
        this.Name := name
        this.Age := age
        ; Increment the count of people
        Person.Count++
    }
    
    ; Instance method
    SayHello() {
        MsgBox("Hello, my name is " this.Name " and I am " this.Age " years old.")
    }
    
    ; Static method
    static GetCount() {
        return Person.Count
    }
}

; Create instances
john := new Person("John", 30)
jane := new Person("Jane", 28)

; Use instance methods
john.SayHello()  ; Shows: Hello, my name is John and I am 30 years old.

; Access static property/method
MsgBox("Total people created: " Person.Count)  ; Shows: Total people created: 2
MsgBox("Total people created: " Person.GetCount())  ; Same result using method
```

## Implementation Notes
- Classes are only available in AutoHotkey v2, not v1
- Properties are referenced within methods using `this.PropertyName`
- Use static properties/methods for data shared across all instances
- Avoid circular references which can cause memory leaks
- Class names should use PascalCase by convention
- The `base` property can be used to access the parent class

## Related AHK Concepts
- Object Methods and Properties
- Inheritance and Polymorphism
- Event Handling with Objects
- Error Handling in Classes

## Tags
#AutoHotkey #OOP #Class #Constructor #Inheritance
