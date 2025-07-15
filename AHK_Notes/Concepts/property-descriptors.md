# Topic: Property Descriptors in AutoHotkey

## Category

Concept

## Overview

Property descriptors in AutoHotkey v2 define how properties behave when accessed, assigned, or called. They are the foundation of AutoHotkey's dynamic property system and enable features like getters, setters, callable properties, and more. Understanding descriptors is crucial for advanced prototype-based programming in AHK.

## Key Points

- Descriptors are objects that define property behavior
- Four main descriptor types: `Get`, `Set`, `Call`, and `Value`
- Descriptors allow for computed properties with custom logic
- They can be used to create method-like behavior for properties
- Applied using the `DefineProp` method on any object or prototype
- Enable modification of built-in objects like Array and Map
- Can implement property validation, transformation, and proxying

## Syntax and Parameters

```cpp
; Basic syntax for defining a property with a descriptor
Object.DefineProp(PropertyName, DescriptorObject)

; Example descriptor object with all possible properties
DescriptorObject := {
    Get: GetterFunction,    ; Function called when property is read
    Set: SetterFunction,    ; Function called when property is assigned
    Call: CallableFunction, ; Function called when property is invoked
    Value: StaticValue      ; Fixed value for the property
}

; Adding a property to an object
myObject.DefineProp("PropertyName", {Get: Getter, Set: Setter})

; Adding a method to a class prototype (affects all instances)
MyClass.Prototype.DefineProp("MethodName", {Call: MethodFunction})

; Adding a method to a built-in type
Array.Prototype.DefineProp("NewMethod", {Call: ArrayMethodFunction})
```

## Code Examples

### Example 1: Basic Getter and Setter

```cpp
; Create an object with a private storage field
person := {_name: ""}

; Define getter function
getName(this) {
    return this._name
}

; Define setter function with validation
setName(this, value) {
    if (value = "")
        throw ValueError("Name cannot be empty")
    this._name := value
}

; Define the property with getter and setter
person.DefineProp("Name", {
    Get: getName,
    Set: setName
})

; Using the property
person.Name := "John"  ; Uses setter
MsgBox(person.Name)    ; Uses getter, shows "John"

try {
    person.Name := ""  ; Throws error due to validation
} catch as e {
    MsgBox("Error: " e.Message)
}
```

### Example 2: Computed Property

```cpp
; Create rectangle object
rect := {Width: 10, Height: 5}

; Define an area getter (computed property)
getArea(this) {
    return this.Width * this.Height
}

; Define the property
rect.DefineProp("Area", {Get: getArea})

; Using the property
MsgBox("Rectangle area: " rect.Area)  ; Shows 50
rect.Width := 20
MsgBox("New area: " rect.Area)        ; Shows 100 (recalculated)
```

### Example 3: Callable Property (Method)

```cpp
; Create a calculator object
calc := {}

; Define a function for the callable property
addFunction(this, a, b) {
    return a + b
}

; Define the callable property
calc.DefineProp("Add", {Call: addFunction})

; Use the callable property (method)
result := calc.Add(5, 3)  ; Returns 8
MsgBox("5 + 3 = " result)
```

### Example 4: Extending Built-in Types

```cpp
; Add a method to all arrays
Array.Prototype.DefineProp("Sum", {Call: arraySum})

; Implementation
arraySum(arr) {
    total := 0
    for value in arr
        total += value
    return total
}

; Using the new method
numbers := [1, 2, 3, 4, 5]
MsgBox("Sum: " numbers.Sum())  ; Shows 15
```

### Example 5: Property with Both Value and Getter

```cpp
; Create an object
config := {}

; Define a counter property with initial value and custom getter
config.DefineProp("Counter", {
    Value: 0,
    Get: (this) => this.Counter + 1
})

; Each access increments the counter
MsgBox(config.Counter)  ; Shows 1
MsgBox(config.Counter)  ; Shows 2
MsgBox(config.Counter)  ; Shows 3
```

## Implementation Notes

- When defining a method with `{Call: func}`, the target object is always passed as the first parameter
- Getter functions receive the object (`this`) as their only parameter
- Setter functions receive the object (`this`) as first parameter and the new value as second
- Call descriptors can have any number of parameters after the first (object) parameter
- Properties with only a `Value` descriptor behave like normal properties
- Using `DefineProp` on a prototype affects all existing and future instances
- Descriptors allow for powerful metaprogramming techniques
- The `Get`, `Set`, and `Call` properties can be function objects or function references
- Descriptors cannot be enumerated directly; they're part of JavaScript's internal property system

## Related AHK Concepts

- Prototype-Based OOP
- Method Binding and Context
- Function Types in AHK v2
- Object Lifecycle and Memory Management
- Class Definition and Inheritance
- Property Access and Assignment
- Dynamic Object Modification

## Tags

#AutoHotkey #OOP #Descriptors #Properties #DynamicProperties #Getters #Setters #Prototyping