# Topic: Using super in Class Inheritance

## Category

Method

## Overview

The `super` keyword in AutoHotkey v2 provides access to methods and properties of a parent class from within a child class. It's essential for properly implementing inheritance hierarchies, enabling subclasses to extend parent functionality while still leveraging the base implementation, particularly in constructor chaining and method overriding scenarios.

## Key Points

- `super.__New()` calls the parent class constructor, ensuring proper initialization
- `super.MethodName()` calls the parent class implementation of an overridden method
- Using `super` prevents infinite recursion when overriding methods
- `super` is only valid within methods of classes that extend another class
- Unlike `this`, `super` refers to the parent class prototype, not the current instance

## Syntax and Parameters

```cpp
; Basic syntax for using super
class ChildClass extends ParentClass {
    __New(params*) {
        super.__New(params*)  ; Call parent constructor
    }
    
    OverriddenMethod(params*) {
        ; Do something before parent implementation
        result := super.OverriddenMethod(params*)  ; Call parent implementation
        ; Do something after parent implementation
        return result
    }
}
```

## Code Examples

```cpp
; Example 1: Basic super usage with constructor chaining
class Vehicle {
    Make := ""
    Model := ""
    Year := 0
    
    __New(make, model, year) {
        this.Make := make
        this.Model := model
        this.Year := year
    }
    
    GetInfo() {
        return this.Year " " this.Make " " this.Model
    }
    
    Start() {
        return "Vehicle started"
    }
}

class Car extends Vehicle {
    NumDoors := 4
    
    __New(make, model, year, numDoors := 4) {
        super.__New(make, model, year)  ; Call parent constructor first
        this.NumDoors := numDoors
    }
    
    GetInfo() {
        return super.GetInfo() " (" this.NumDoors " doors)"
    }
    
    Start() {
        return super.Start() " - Engine purring"
    }
}

class ElectricCar extends Car {
    BatteryCapacity := 0
    
    __New(make, model, year, batteryCapacity, numDoors := 4) {
        super.__New(make, model, year, numDoors)  ; Chain constructor calls
        this.BatteryCapacity := batteryCapacity
    }
    
    GetInfo() {
        return super.GetInfo() " - " this.BatteryCapacity " kWh battery"
    }
    
    Start() {
        return "Electric " super.Start() " silently"
    }
}

; Create instances
myCar := Car("Toyota", "Camry", 2020, 4)
myTesla := ElectricCar("Tesla", "Model 3", 2022, 75)

; Display info
MsgBox(myCar.GetInfo())   ; Output: 2020 Toyota Camry (4 doors)
MsgBox(myCar.Start())     ; Output: Vehicle started - Engine purring

MsgBox(myTesla.GetInfo()) ; Output: 2022 Tesla Model 3 (4 doors) - 75 kWh battery
MsgBox(myTesla.Start())   ; Output: Electric Vehicle started - Engine purring silently
```

```cpp
; Example 2: Using super to create decorators
class Logger {
    Log(message) {
        OutputDebug("LOG: " message)
        return message
    }
}

class TimestampLogger extends Logger {
    Log(message) {
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        return super.Log("[" timestamp "] " message)
    }
}

class LevelLogger extends TimestampLogger {
    Level := "INFO"
    
    __New(level := "INFO") {
        this.Level := level
    }
    
    Log(message) {
        return super.Log("[" this.Level "] " message)
    }
}

; Create logger instances
basicLogger := Logger()
timestampLogger := TimestampLogger()
debugLogger := LevelLogger("DEBUG")
errorLogger := LevelLogger("ERROR")

; Log messages
basicLogger.Log("Basic message")           ; LOG: Basic message
timestampLogger.Log("With timestamp")      ; LOG: [2025-05-18 14:30:45] With timestamp
debugLogger.Log("Debug information")       ; LOG: [2025-05-18 14:30:45] [DEBUG] Debug information
errorLogger.Log("Critical system error")   ; LOG: [2025-05-18 14:30:45] [ERROR] Critical system error
```

## Implementation Notes

- Always call `super.__New()` in a subclass constructor to ensure the parent class is properly initialized before adding subclass-specific initializations.
- If you override a method and don't call the parent implementation using `super`, you're completely replacing the parent's behavior rather than extending it.
- If a method uses recursion and also needs to call its parent method, be careful to avoid infinite recursion. The parent call via `super` should generally be outside the recursive path.
- Unlike some other languages, AutoHotkey doesn't allow using `super` outside of class methods or in classes that don't extend another class.
- Be aware that calling `super.Method()` within a method always calls the parent class's implementation, even if you're calling it from a method in a grandchild class. It doesn't traverse the entire inheritance chain.
- If you need to access static methods or properties of a parent class, use the parent class name directly (e.g., `ParentClass.StaticMethod()`) rather than `super`.
- The behavior of `super` is different from changing the base object using `Base` assignment, as it specifically refers to the parent class.

## Related AHK Concepts

- Class Inheritance
- Method Overriding
- Constructor Chaining
- Base Objects
- Object Prototypes
- Polymorphism

## Tags

#AutoHotkey #OOP #Inheritance #Super #MethodOverriding #ConstructorChaining