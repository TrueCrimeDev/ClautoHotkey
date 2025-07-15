# Topic: Prototype-Based OOP in AutoHotkey v2

## Category
Concept

## Overview

AutoHotkey v2 implements prototype-based Object-Oriented Programming (OOP), similar to JavaScript's approach. This paradigm allows objects to inherit directly from other objects rather than requiring rigid class hierarchies, though AHK does provide a class syntax for convenience and readability. The powerful prototyping system enables dynamic addition of methods and properties to existing objects at runtime.

## Key Points

- Objects inherit properties and methods directly from other objects (their prototypes)
- The `class` syntax provides a convenient way to define object templates
- Classes can extend other classes using the `extends` keyword
- Static properties and methods are shared across all instances
- The `this` keyword refers to the current instance within methods
- The `super` keyword allows access to parent class methods
- The `Prototype` property allows dynamic extension of existing objects and classes
- Descriptors define how properties should behave when accessed, assigned, or called

## Syntax and Parameters
```cpp
; Basic class definition
class MyClass {
    ; Static property (shared across all instances)
    static DefaultValue := 100
    
    ; Constructor
    __New(param1, param2 := "default") {
        this.Property1 := param1
        this.Property2 := param2
    }
    
    ; Instance method
    InstanceMethod(param) {
        return this.Property1 + param
    }
    
    ; Arrow function method (compact syntax)
    ArrowMethod() => this.Property1 * 2
    
    ; Static method
    static StaticMethod() {
        return MyClass.DefaultValue * 2
    }
}

; Class inheritance
class ChildClass extends MyClass {
    __New(param1, param2, extraParam) {
        ; Call parent constructor
        super.__New(param1, param2)
        this.ExtraProperty := extraParam
    }
    
    ; Override parent method
    InstanceMethod(param) {
        ; Call parent method
        parentResult := super.InstanceMethod(param)
        return parentResult + this.ExtraProperty
    }
}

; Instance creation
instance := MyClass("value")

; Adding a method to an existing prototype
Array.Prototype.DefineProp("Contains", {Call: array_contains})

; Descriptor options
MyObject.DefineProp("PropertyName", {
    Get: getterFunction,   ; Function called when property is accessed
    Set: setterFunction,   ; Function called when property is assigned a value
    Call: callFunction,    ; Function called when property is called as a method
    Value: defaultValue    ; Static value assigned to the property
})
```

## Code Examples

### Example 1: Basic class with properties and methods
```cpp
class Rectangle {
    __New(width, height) {
        this.Width := width
        this.Height := height
    }
    
    Area() {
        return this.Width * this.Height
    }
    
    Perimeter() {
        return 2 * (this.Width + this.Height)
    }
}

rect := Rectangle(10, 5)
MsgBox("Area: " rect.Area())        ; 50
MsgBox("Perimeter: " rect.Perimeter())  ; 30
```

### Example 2: Inheritance
```cpp
class Square extends Rectangle {
    __New(side) {
        super.__New(side, side)
        this.Side := side
    }
    
    ; Additional method specific to squares
    Diagonal() {
        return this.Side * Sqrt(2)
    }
}

square := Square(5)
MsgBox("Area: " square.Area())          ; 25
MsgBox("Diagonal: " square.Diagonal())  ; ~7.07
```

### Example 3: Dynamic prototyping - Adding 'Contains' to Arrays
```cpp
; Add a Contains method to all Arrays
Array.Prototype.DefineProp("Contains", {Call: array_contains})

; Implementation of the Contains method
array_contains(arr, search, casesense:=0) {
    for index, value in arr {
        if !IsSet(value)
            continue
        else if (value == search)
            return index
        else if (value = search && !casesense)
            return index
    }
    return 0
}

; Using the new method
arr := ['apple', 'banana', 'cherry']
if arr.Contains('Cherry')
    MsgBox('Found it!')  ; Shows if case-insensitive (default)
else 
    MsgBox('Not found.')

; Using with case sensitivity
if arr.Contains('Cherry', 1)
    MsgBox('Found it!')
else 
    MsgBox('Not found.') ; Shows when case-sensitive
```

### Example 4: Adding methods to Maps
```cpp
; Add a Keys method to all Maps
Map.Prototype.DefineProp("Keys", {Call: get_keys})

; Implementation of the Keys method
get_keys(mp) {
    mapKeys := []
    for k, v in mp {
        if !IsSet(k)
            continue
        else if k is string or k is number
            mapKeys.Push(k)
    }
    return mapKeys
}

; Add a Values method to all Maps
Map.Prototype.DefineProp("Values", {Call: get_values})

get_values(mp) {
    mapValues := []
    for k, v in mp {
        if !IsSet(v)
            continue
        else
            mapValues.Push(v)
    }
    return mapValues
}

; Using the new methods
myMap := Map("Key1", "Value1", "Key2", "Value2", "Key3", "Value3")
keys := myMap.Keys()   ; Returns ["Key1", "Key2", "Key3"]
values := myMap.Values() ; Returns ["Value1", "Value2", "Value3"]

; Looping through keys
for key in myMap.Keys() {
    MsgBox(key)
}
```

### Example 5: Custom getters and setters
```cpp
; Create an object and a hidden field to store the property value
myObject := {_hiddenValue: ""}

; Helper Function for 'get'
getFunction(this) {
    return this._hiddenValue  ; Return the internally stored value
}

; Helper Function for 'set'
setFunction(this, value) {
    this._hiddenValue := value  ; Update the internally stored value
}

; Define a dynamic property with both getter and setter
myObject.DefineProp("DynamicProperty", {
    Get: getFunction,
    Set: setFunction
})

; Now you can get and set the value of DynamicProperty
myObject.DynamicProperty := "Hello, World"  ; Setter is called
MsgBox(myObject.DynamicProperty)  ; Getter is called and displays "Hello, World"
```

## Implementation Notes

- Behind the scenes, AHK v2's class system is built on prototypal inheritance
- Unlike classical OOP, you can modify an object's prototype at runtime using `DefineProp`
- Properties are created dynamically when first assigned - there's no need to declare them upfront
- Method calls require parentheses even when no arguments are passed (e.g., `obj.Method()`)
- Static properties are accessed through the class name (e.g., `MyClass.StaticProperty`) or within the class using the class name
- The `base` property of an object refers to its prototype
- When a prototype method is called, the calling object is always passed as the first parameter
- Descriptors allow for powerful property behaviors:
  - `Get`: Function called when property is read
  - `Set`: Function called when property is assigned
  - `Call`: Function called when property is used as a method
  - `Value`: Static value assigned to the property

## Related AHK Concepts

- Object Methods and Properties
- Class Inheritance
- Static vs Instance Members
- Method Overriding
- Constructor Patterns
- Using Objects as Associative Arrays
- Descriptor Objects
- Dynamic Method Addition

## Tags

#AutoHotkey #OOP #PrototypalInheritance #Classes #Objects #Inheritance #StaticMembers #Prototyping #Descriptors