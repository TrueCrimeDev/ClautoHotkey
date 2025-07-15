# Topic: Method Chaining Pattern

## Category

Pattern

## Overview

Method chaining is a programming pattern in AutoHotkey v2 that allows multiple method calls to be chained together in a single statement. This pattern works by having each method return the object instance itself (`this`), allowing subsequent methods to be called on the result. Method chaining creates more readable, concise code and enables a fluent interface for configuring and working with objects.

## Key Points

- Methods return `this` (the object instance) to enable chaining
- Reduces code verbosity by eliminating repeated object references
- Creates a fluent, readable interface for working with objects
- Commonly used in builder patterns and object configuration
- Can be implemented in any class that needs sequential operations

## Syntax and Parameters

```cpp
class ChainableClass {
    ; Property to store state
    Name := ""
    Value := 0
    
    ; Methods that return this for chaining
    SetName(name) {
        this.Name := name
        return this  ; Return this to enable chaining
    }
    
    SetValue(value) {
        this.Value := value
        return this  ; Return this to enable chaining
    }
    
    Reset() {
        this.Name := ""
        this.Value := 0
        return this  ; Return this to enable chaining
    }
}

; Usage syntax
result := myObject.Method1(param1).Method2(param2).Method3(param3)
```

## Code Examples

```cpp
; Example of a chainable configuration class
class ConfigBuilder {
    ; Internal properties
    Width := 800
    Height := 600
    Title := "My Window"
    Theme := "Default"
    FontSize := 10
    
    ; Chainable methods
    SetSize(width, height) {
        this.Width := width
        this.Height := height
        return this
    }
    
    SetTitle(title) {
        this.Title := title
        return this
    }
    
    SetTheme(theme) {
        this.Theme := theme
        return this
    }
    
    SetFontSize(size) {
        this.FontSize := size
        return this
    }
    
    ; Method to build the final configuration
    Build() {
        return {
            Width: this.Width,
            Height: this.Height,
            Title: this.Title,
            Theme: this.Theme,
            FontSize: this.FontSize
        }
    }
}

; Usage example
config := ConfigBuilder()
    .SetSize(1024, 768)
    .SetTitle("Configuration Example")
    .SetTheme("Dark")
    .SetFontSize(12)
    .Build()

; Create a GUI with the configuration
myGui := Gui("+Resize", config.Title)
myGui.BackColor := (config.Theme = "Dark") ? "333333" : "FFFFFF"
myGui.SetFont("s" config.FontSize)
myGui.Show("w" config.Width " h" config.Height)
```

## Implementation Notes

- Always return `this` from methods that should be chainable
- Terminal methods (like `Build()` in the example) should return the final result, not `this`
- Consider creating dedicated builder classes for complex object construction
- Method chaining can make debugging more difficult if you're not sure which method in the chain caused an error
- For error handling, consider making methods check conditions and throw errors early in the chain
- Avoid excessive method chaining that reduces readability (more than 5-7 methods in a chain)
- Documentation should clearly indicate which methods are chainable and which are terminal

## Related AHK Concepts

- [Builder Pattern](./builder-pattern.md)
- [Fluent Interface](./fluent-interface.md)
- [Method Return Values](../Concepts/method-return-values.md)
- [Class Method Context](../Concepts/method-binding-and-context.md)

## Tags

#AutoHotkey #OOP #Pattern #MethodChaining #FluentInterface #Builder #v2