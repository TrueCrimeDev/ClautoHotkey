# Topic: Inheritance Design Patterns in AutoHotkey v2

## Category

Pattern

## Overview

Inheritance design patterns are specific implementations of class inheritance that solve common programming challenges in AutoHotkey v2. These patterns demonstrate best practices for creating flexible, reusable class hierarchies, enabling developers to create more maintainable and extensible code structures through proven inheritance techniques.

## Key Points

- Method overriding allows subclasses to provide specific implementations of methods defined in parent classes
- Abstract base classes define interfaces that subclasses must implement
- Mixin inheritance allows for combining functionality from multiple sources
- Factory patterns can be used to dynamically create specific subclass instances
- Composition can be used alongside inheritance to create more flexible designs

## Syntax and Parameters

```cpp
; Abstract base class pattern
class AbstractBase {
    RequiredMethod() {
        throw Error("RequiredMethod must be implemented by subclass")
    }
    
    TemplateMethod() {
        ; Common functionality for all subclasses
        this.RequiredMethod()  ; Will call the subclass implementation
    }
}
```

## Code Examples

```cpp
; Example 1: UI Control hierarchy with method overriding
class Control {
    X := 0
    Y := 0
    Width := 100
    Height := 30
    Type := "Generic"
    
    __New(x, y, width := 100, height := 30) {
        this.X := x
        this.Y := y
        this.Width := width
        this.Height := height
    }
    
    Render() {
        return "Rendering " this.Type " control at (" this.X "," this.Y ") with size " this.Width "x" this.Height
    }
    
    HandleEvent(event) {
        return "Generic event handling for " event
    }
}

class Button extends Control {
    Text := "Button"
    
    __New(x, y, text := "Button", width := 100, height := 30) {
        super.__New(x, y, width, height)
        this.Type := "Button"
        this.Text := text
    }
    
    ; Override parent method
    Render() {
        return super.Render() " with text '" this.Text "'"
    }
    
    ; Override event handling
    HandleEvent(event) {
        if (event = "click")
            return "Button '" this.Text "' clicked"
        return super.HandleEvent(event)  ; Fall back to parent method for other events
    }
    
    ; Add button-specific method
    SetText(text) {
        this.Text := text
        return this
    }
}

class TextBox extends Control {
    Value := ""
    
    __New(x, y, value := "", width := 100, height := 30) {
        super.__New(x, y, width, height)
        this.Type := "TextBox"
        this.Value := value
    }
    
    ; Override parent method
    Render() {
        return super.Render() " with value '" this.Value "'"
    }
    
    ; Override event handling
    HandleEvent(event) {
        if (event = "change")
            return "TextBox value changed to '" this.Value "'"
        return super.HandleEvent(event)
    }
    
    ; Add textbox-specific method
    SetValue(value) {
        this.Value := value
        return this
    }
}

; Create control instances
btn := Button(10, 10, "Submit")
txt := TextBox(10, 50, "Enter your name")

; Use the controls polymorphically
MsgBox(btn.Render())            ; Rendering Button control at (10,10) with size 100x30 with text 'Submit'
MsgBox(txt.Render())            ; Rendering TextBox control at (10,50) with size 100x30 with value 'Enter your name'

MsgBox(btn.HandleEvent("click")) ; Button 'Submit' clicked
MsgBox(txt.HandleEvent("change")); TextBox value changed to 'Enter your name'

; Use specific methods
btn.SetText("Save")
txt.SetValue("John Doe")
```

```cpp
; Example 2: Factory pattern with inheritance
class ShapeFactory {
    static Create(type, params*) {
        switch type {
            case "circle": return Circle(params*)
            case "rectangle": return Rectangle(params*)
            case "triangle": return Triangle(params*)
            default: throw Error("Unknown shape type: " type)
        }
    }
}

class Shape {
    Color := "Black"
    
    __New(color := "Black") {
        this.Color := color
    }
    
    Area() {
        throw Error("Area method must be implemented by subclass")
    }
    
    Describe() {
        return "A " this.Color " shape with area " this.Area()
    }
}

class Circle extends Shape {
    Radius := 0
    
    __New(radius, color := "Black") {
        super.__New(color)
        this.Radius := radius
    }
    
    Area() {
        return 3.14159 * this.Radius * this.Radius
    }
    
    Describe() {
        return super.Describe() " (Circle with radius " this.Radius ")"
    }
}

class Rectangle extends Shape {
    Width := 0
    Height := 0
    
    __New(width, height, color := "Black") {
        super.__New(color)
        this.Width := width
        this.Height := height
    }
    
    Area() {
        return this.Width * this.Height
    }
    
    Describe() {
        return super.Describe() " (Rectangle " this.Width "x" this.Height ")"
    }
}

class Triangle extends Shape {
    Base := 0
    Height := 0
    
    __New(base, height, color := "Black") {
        super.__New(color)
        this.Base := base
        this.Height := height
    }
    
    Area() {
        return 0.5 * this.Base * this.Height
    }
    
    Describe() {
        return super.Describe() " (Triangle with base " this.Base " and height " this.Height ")"
    }
}

; Use factory to create shapes
circle := ShapeFactory.Create("circle", 5, "Red")
rectangle := ShapeFactory.Create("rectangle", 4, 6, "Blue")
triangle := ShapeFactory.Create("triangle", 3, 4, "Green")

; Display information
MsgBox(circle.Describe())    ; A Red shape with area 78.5398 (Circle with radius 5)
MsgBox(rectangle.Describe()) ; A Blue shape with area 24 (Rectangle 4x6)
MsgBox(triangle.Describe())  ; A Green shape with area 6 (Triangle with base 3 and height 4)
```

## Implementation Notes

- When using inheritance, be cautious of deep inheritance chains which can make code harder to understand and maintain. A general rule is to keep inheritance hierarchies no more than 2-3 levels deep.
- Consider using composition (has-a) alongside inheritance (is-a) for more flexible designs. For example, a `Car` class might inherit from `Vehicle` but have a `Engine` object as a component.
- When a subclass overrides a method, it should generally maintain the same interface (parameter list) as the parent method to ensure polymorphic usage works correctly.
- In AutoHotkey v2, properties at the class level are initialized before the constructor is called. This means that property values set in the class body serve as default values.
- If a subclass needs to reference its own properties that have the same name as parent properties, use `this.PropertyName` explicitly to avoid ambiguity.
- AutoHotkey v2 does not support interfaces as a language feature, but you can implement interface-like patterns using abstract base classes with methods that throw errors if not implemented by subclasses.

## Related AHK Concepts

- Polymorphism
- Method Overriding
- Abstract Classes
- Factory Patterns
- Constructor Chaining
- Class Hierarchies

## Tags

#AutoHotkey #OOP #Inheritance #DesignPatterns #Polymorphism #AbstractClasses #FactoryPattern