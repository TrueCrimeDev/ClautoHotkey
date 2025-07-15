# Topic: Class Basics in AHK v2

## Category

Class

## Overview

AutoHotkey v2 implements prototype-based object-oriented programming similar to JavaScript, allowing developers to create reusable class blueprints for objects. Classes in AHK v2 support instance methods, static properties and methods, constructors, and inheritance, making them powerful tools for organizing code and data.

## Key Points

- AHK v2 uses prototype-based OOP, making it similar to JavaScript's class implementation
- Classes can have instance properties, instance methods, static properties, and static methods
- The `__New()` method serves as a constructor that runs when objects are instantiated
- AHK v2 supports method chaining, inheritance, and property getters/setters

## Syntax and Parameters

```cpp
class ClassName {
    ; Static properties (shared across all instances)
    static StaticProperty := value
    
    ; Constructor
    __New(param1, param2) {
        ; Initialize instance properties
        this.Property1 := param1
        this.Property2 := param2
    }
    
    ; Instance method (standard syntax)
    InstanceMethod(param) {
        return result
    }
    
    ; Instance method (arrow syntax)
    ArrowMethod(param) => expression
    
    ; Static method
    static StaticMethod(param) {
        return result
    }
}
```

## Code Examples

```cpp
; Basic class definition
class Rectangle {
    ; Static property shared by all Rectangle instances
    static ShapeType := "Rectangle"
    
    ; Constructor
    __New(width, height) {
        this.width := width
        this.height := height
    }
    
    ; Regular instance method
    Area() {
        return this.width * this.height
    }
    
    ; Arrow function instance method
    Perimeter() => 2 * (this.width + this.height)
    
    ; Static method
    static CreateSquare(side) {
        return Rectangle(side, side)
    }
}

; Creating an instance
rect := Rectangle(5, 10)

; Using instance properties and methods
MsgBox "Width: " rect.width
MsgBox "Area: " rect.Area()
MsgBox "Perimeter: " rect.Perimeter()

; Using static properties and methods
MsgBox "Shape type: " Rectangle.ShapeType
square := Rectangle.CreateSquare(5)
MsgBox "Square area: " square.Area()

; Inheritance example
class ColoredRectangle extends Rectangle {
    __New(width, height, color) {
        ; Call parent constructor
        super.__New(width, height)
        this.color := color
    }
    
    Description() {
        return "A " this.color " rectangle with area " this.Area()
    }
}

; Creating an instance of the child class
coloredRect := ColoredRectangle(4, 6, "red")
MsgBox coloredRect.Description()
```

## Implementation Notes

- Unlike traditional class-based OOP languages, AHK v2's prototype-based approach allows for more dynamic manipulation of object structures
- The `this` keyword refers to the current instance within instance methods
- Static methods and properties are accessed through the class name (not instances)
- Property getters and setters can be implemented using methods with special naming patterns
- Class inheritance is achieved using the `extends` keyword, and parent methods can be called using `super`
- Classes are reference types, so passing an object to a function passes a reference, not a copy

## Related AHK Concepts

- Object Literals
- Prototype Inheritance
- Method Chaining
- Closures
- Property Getters and Setters

## Tags

#AutoHotkey #OOP #Classes #Inheritance #Prototype