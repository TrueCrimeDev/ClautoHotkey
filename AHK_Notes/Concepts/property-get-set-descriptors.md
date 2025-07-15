# Topic: Property Get/Set Descriptors

## Category

Concept

## Overview

Property get/set descriptors in AutoHotkey v2 allow developers to define custom behavior when getting or setting object properties. These descriptors enable the creation of computed properties, validation of property values, and integration of property access with other operations like data binding or logging. By using property descriptors, you can create more sophisticated interfaces that maintain clean API design while implementing complex behind-the-scenes logic.

## Key Points

- Property descriptors let you define custom behavior for property access
- The `get` descriptor determines what happens when a property is read
- The `set` descriptor determines what happens when a property is assigned a new value
- Properties defined with descriptors can compute values dynamically
- Descriptors can implement validation, conversion, or triggering side effects
- Well-designed descriptors help maintain encapsulation while providing flexible interfaces

## Syntax and Parameters

```cpp
; Defining a property with get/set descriptors
Object.DefineProp("PropertyName", {
    get: (this) => Expression,  ; Function that returns the property value
    set: (this, value) => Expression  ; Function to handle setting the value
})

; Alternative more verbose syntax
Object.DefineProp("PropertyName", {
    get: (this) {
        return computedValue
    },
    set: (this, value) {
        ; Validation, conversion, and assignment logic
    }
})
```

## Code Examples

```cpp
; Example of a Temperature class with Celsius/Fahrenheit conversion
class Temperature {
    ; Private variable to store the temperature in Celsius
    _celsius := 0
    
    __New(celsius := 0) {
        this._celsius := celsius
    }
    
    ; Define properties with get/set descriptors
    static __New() {
        ; Celsius property
        this.Prototype.DefineProp("Celsius", {
            get: (this) => this._celsius,
            set: (this, value) {
                if (value < -273.15)
                    throw ValueError("Temperature cannot be below absolute zero (-273.15°C)")
                this._celsius := value
            }
        })
        
        ; Fahrenheit property (computed from Celsius)
        this.Prototype.DefineProp("Fahrenheit", {
            get: (this) => (this._celsius * 9/5) + 32,
            set: (this, value) {
                ; Convert Fahrenheit to Celsius
                celsius := (value - 32) * 5/9
                
                if (celsius < -273.15)
                    throw ValueError("Temperature cannot be below absolute zero (-273.15°C)")
                    
                this._celsius := celsius
            }
        })
        
        ; Kelvin property (computed from Celsius)
        this.Prototype.DefineProp("Kelvin", {
            get: (this) => this._celsius + 273.15,
            set: (this, value) {
                celsius := value - 273.15
                
                if (celsius < -273.15)
                    throw ValueError("Temperature cannot be below absolute zero (0K)")
                    
                this._celsius := celsius
            }
        })
    }
    
    ToString() {
        return this._celsius "°C"
    }
}

; Usage example
temp := Temperature(25)  ; Create with 25°C
MsgBox("Celsius: " temp.Celsius)
MsgBox("Fahrenheit: " temp.Fahrenheit)
MsgBox("Kelvin: " temp.Kelvin)

temp.Fahrenheit := 68  ; Set temperature in Fahrenheit
MsgBox("After setting to 68°F:`nCelsius: " temp.Celsius)

; Will throw an error because it's below absolute zero
try {
    temp.Celsius := -300
} catch as err {
    MsgBox("Error: " err.Message)
}
```

## Implementation Notes

- Property descriptors are defined using `Object.DefineProp()` or the static initializer (`static __New()`) for class-wide properties
- The `this` parameter in descriptor functions refers to the object containing the property
- The property name should not conflict with existing methods or properties to avoid confusion
- Keep descriptor functions small and focused for better readability and maintenance
- Use property descriptors for:
  - Validating input values
  - Computed/derived properties
  - Lazy-loading expensive values
  - Implementing data binding
  - Maintaining internal consistency between related properties
- For simple computed properties, fat arrow syntax `(this) => expression` is more concise
- For complex logic with multiple statements, use a full function body with curly braces
- Be cautious about side effects in getters; they should ideally be pure functions
- Property descriptors add some overhead, so use them judiciously for performance-critical code

## Related AHK Concepts

- [Object.DefineProp Method](../Methods/object-defineprop.md)
- [Class Static Initializer](../Classes/class-static-initializer.md)
- [Property Descriptors Overview](./property-descriptors.md)
- [Extending Built-in Objects](../Snippets/extending-builtin-objects.md)
- [Encapsulation Patterns](../Patterns/encapsulation-patterns.md)

## Tags

#AutoHotkey #OOP #Properties #Descriptors #GetterSetter #Encapsulation #v2