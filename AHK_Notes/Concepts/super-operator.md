# Topic: Super Operator in AutoHotkey

## Category

Keyword/Operator

## Overview

The `super` keyword is a special operator used in object-oriented programming in AutoHotkey that allows access to superclass (base class) versions of methods and properties that have been overridden in derived classes. It provides a way to explicitly reference the parent class's implementation within a method or property of a child class.

## Key Points

- Only available inside methods or property getter/setter functions of a class
- Always references the immediate base class of the current method's definition
- Automatically passes `this` as the first (hidden) parameter
- Resolves to the base class at script load time
- Can access both instance and static members, depending on context
- Throws an error if the referenced property doesn't exist in the superclass
- Must be followed by one of these symbols: `.[()`

## Syntax and Parameters

```cpp
; Basic syntax for accessing superclass properties and methods
super.PropertyName
super.MethodName(Parameters)
super[PropertyName]

; Alternative notation for calling methods
super(Parameters)  ; Equivalent to super.Call(Parameters)
```

## Code Examples

```cpp
class Animal {
    Name := "Generic Animal"
    
    Speak() {
        MsgBox this.Name " makes a sound"
    }
    
    Eat(food) {
        MsgBox this.Name " eats " food
    }
}

class Dog extends Animal {
    Name := "Dog"
    
    ; Override the Speak method but still call the base implementation
    Speak() {
        super.Speak()  ; Calls Animal.Speak()
        MsgBox this.Name " barks!"
    }
    
    ; Extend the Eat method to add specific Dog behavior
    Eat(food) {
        super.Eat(food)  ; Calls Animal.Eat()
        if (food = "bone")
            MsgBox this.Name " wags tail happily!"
    }
}

; Creating and testing the classes
dog := Dog()
dog.Speak()  ; Shows both generic animal sound and barking
dog.Eat("bone")  ; Shows eating and tail wagging

; Static methods example
class Calculator {
    static version := "1.0"
    
    static Calculate(a, b) {
        return a + b
    }
}

class AdvancedCalculator extends Calculator {
    static version := "2.0"
    
    static Calculate(a, b) {
        ; Call base implementation first
        result := super.Calculate(a, b)
        ; Add logging functionality
        FileAppend("Calculated: " a " + " b " = " result "`n", "calc.log")
        return result
    }
}

; Property getter/setter example
class Vehicle {
    speed := 0
    
    Speed {
        get => this.speed
        set => this.speed := value
    }
}

class Car extends Vehicle {
    maxSpeed := 120
    
    Speed {
        get => this.speed
        set {
            if (value > this.maxSpeed)
                value := this.maxSpeed
            super.Speed := value  ; Use the base class setter
        }
    }
}
```

## Implementation Notes

1. **Scope Resolution**: `super` always looks at the base of the class where the method was originally defined, not the dynamic base of the current instance
2. **Binding**: The `this` context is automatically passed to superclass methods, so they operate on the current instance
3. **Load Time Resolution**: The base class is resolved when the script loads, not at runtime
4. **Error Handling**: Attempting to access non-existent properties/methods in the superclass throws an error
5. **No Multiple Inheritance**: Since AHK doesn't support multiple inheritance, `super` always refers to a single base class
6. **Performance**: `super` calls have minimal overhead compared to direct method calls

Common pitfalls:
- Forgetting that `super` references the original class's base, not the dynamic base chain
- Using `super` outside of methods or property accessors
- Expecting `super` to work with dynamically resolved base classes

## Related AHK Concepts

- Class inheritance (`extends` keyword)
- Method overriding
- Property accessors (`get` and `set`)
- The `this` keyword
- Dynamic vs static properties

## Tags

#AutoHotkey #OOP #Inheritance #super #Methods #Properties #Classes