# AHKv2 Class Instantiation Guidelines

This document provides guidelines on how to properly instantiate classes in AutoHotkey v2, which differs significantly from AHK v1 and many other programming languages.

## Basic Class Instantiation

In AutoHotkey v2, classes are instantiated directly by calling them as functions, without using the `new` keyword:

```autohotkey
; Correct way to instantiate a class in AHK v2
myInstance := MyClass(param1, param2)

; Incorrect - do not use 'new' keyword
; myInstance := new MyClass(param1, param2)  ; WRONG!
```

## Class Constructor Methods

The constructor method in AHK v2 classes is named `__New`:

```autohotkey
class MyClass {
    ; Properties
    name := ""
    value := 0
    
    ; Constructor
    __New(name, value := 0) {
        this.name := name
        this.value := value
    }
}
```

## Implementing Singleton Pattern

When implementing a singleton pattern, avoid using direct class instantiation within static methods:

```autohotkey
; INCORRECT
class MySingleton {
    static _instance := ""
    
    static GetInstance() {
        if !this._instance
            this._instance := MySingleton()  ; Will cause errors
        return this._instance
    }
}

; CORRECT
class MySingleton {
    static _instance := ""
    
    static GetInstance() {
        if !this._instance {
            ; Create empty object then initialize it
            this._instance := {}
            this.Prototype.__Init(this._instance)
        }
        return this._instance
    }
    
    __Init() {
        ; Initialize the instance
    }
}
```

## Factory Methods

For factory patterns or when you need to create class instances dynamically:

```autohotkey
class Factory {
    static CreateObject(className, params*) {
        if className = "Config"
            return Config(params*)
        else if className = "Logger"
            return Logger(params*)
        else
            throw ValueError("Unknown class: " className)
    }
}
```

## Common Errors

1. **"This Class cannot be used as an output variable"** - Occurs when trying to assign a value to a class or attempting to use a class name instead of an instance
2. **"Expected 0 parameters, but got X"** - Typically occurs when trying to use incorrect instantiation patterns

## Best Practices

1. Always use direct invocation (no `new` keyword)
2. Initialize properties within the class definition or constructor
3. Use Map() objects for associative data structures
4. Use fat arrow functions (`=>`) only for simple, single-line handlers
5. For complex class relationships, prefer composition over inheritance
