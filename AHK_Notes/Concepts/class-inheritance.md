# Topic: Class Inheritance in AutoHotkey v2

## Category

Concept

## Overview

Class inheritance is a fundamental object-oriented programming mechanism in AutoHotkey v2 that allows one class (the subclass) to inherit properties and methods from another class (the base class). This enables code reuse, promotes a hierarchical organization of code, and supports polymorphism, making it easier to maintain and extend complex programs.

## Key Points

- Inheritance is implemented using the `extends` keyword when defining a class
- Subclasses inherit all instance properties and methods from their parent class
- Static/class variables belong to the class itself, but their values can be inherited by subclasses
- The `super` keyword is used to call methods of the parent class
- Properties must be properly initialized in the parent class to be inherited by subclasses

## Syntax and Parameters

```cpp
class ChildClass extends ParentClass {
    __New([param1, param2, ...]) {
        super.__New([param1, param2, ...])  ; Call parent constructor
        this.additionalProperty := value    ; Initialize child-specific properties
    }
    
    ChildMethod() {
        ; Child-specific method
    }
    
    OverrideMethod() {
        ; Override parent method
        super.OverrideMethod()  ; Optionally call parent implementation
    }
}
```

## Code Examples

```cpp
; Basic inheritance example
class Animal {
    Name := ""
    Sound := ""
    
    __New(name, sound) {
        this.Name := name
        this.Sound := sound
    }
    
    Speak() {
        return this.Name " says " this.Sound
    }
}

class Dog extends Animal {
    Breed := ""
    
    __New(name, breed) {
        super.__New(name, "Woof!")  ; Call parent constructor
        this.Breed := breed
    }
    
    Fetch() {
        return this.Name " is fetching the ball!"
    }
    
    ; Override parent method
    Speak() {
        return super.Speak() " (enthusiastically)"
    }
}

; Create instances
myDog := Dog("Buddy", "Golden Retriever")
MsgBox(myDog.Speak())           ; Output: Buddy says Woof! (enthusiastically)
MsgBox(myDog.Fetch())           ; Output: Buddy is fetching the ball!
MsgBox("Breed: " myDog.Breed)   ; Output: Breed: Golden Retriever
```

```cpp
; Example with static properties
class BaseConfig {
    static Version := "1.0"
    static Author := "Default Author"
    
    GetInfo() {
        return "Version: " this.Version ", Author: " this.Author
    }
}

class ExtendedConfig extends BaseConfig {
    static Version := "2.0"  ; Override parent static property
}

MsgBox(BaseConfig.Version)     ; Output: 1.0
MsgBox(ExtendedConfig.Version) ; Output: 2.0
MsgBox(ExtendedConfig.Author)  ; Output: Default Author (inherited from BaseConfig)

baseObj := BaseConfig()
extObj := ExtendedConfig()
MsgBox(baseObj.GetInfo())      ; Output: Version: 1.0, Author: Default Author
MsgBox(extObj.GetInfo())       ; Output: Version: 2.0, Author: Default Author
```

## Implementation Notes

- In AutoHotkey v2, instance variables must be properly initialized in the parent class to be inherited by child classes. This can be done either by defining them with default values in the class body or initializing them in the `__New()` constructor.
- When overriding a parent method, use `super.MethodName()` to call the parent's implementation if needed.
- Unlike some other languages, AutoHotkey v2 does not support multiple inheritance (a class can only extend one parent class).
- If a subclass defines its own `__New()` constructor and needs to use parent class properties or methods, it should call `super.__New()` to ensure proper initialization.
- In AutoHotkey v2, static properties defined in the parent class are accessible from the child class, but if the child class defines a static property with the same name, it will override the parent's value.
- Property access is dynamic, so changing a parent class's prototype can affect all instances of child classes.

## Related AHK Concepts

- Classes and Objects
- Constructors (`__New()` method)
- Class Methods and Properties
- Static Methods and Properties
- Prototypes and Base Objects
- Method Overriding

## Tags

#AutoHotkey #OOP #Inheritance #Classes #Extends #Polymorphism