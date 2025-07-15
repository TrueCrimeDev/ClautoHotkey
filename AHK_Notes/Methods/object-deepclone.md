# Topic: Object.Prototype.DeepClone

## Category

Method

## Overview

DeepClone is a method for Object.Prototype that creates a complete copy of an object, including all nested objects and their properties. Unlike shallow copying, which only copies references to nested objects, DeepClone creates new instances of all nested objects, ensuring that modifications to the clone don't affect the original.

## Key Points

- Creates an identical copy of an object with the same type and methods
- Handles nested objects recursively at any depth
- Preserves the object's inheritance chain and prototype methods
- Correctly handles circular references to prevent infinite recursion
- Works with custom classes, Arrays, Maps, and base Objects
- Has a variant (DeepCloneA) that handles objects with required constructor parameters

## Syntax and Parameters

```cpp
; Basic usage
clone := sourceObject.DeepClone([Depth])

; Parameters
; {Object} Self - The object to be deep cloned (implicit when called as a method)
; {Integer} [Depth=-1] - Maximum recursion depth, -1 for unlimited depth

; Advanced usage with DeepCloneA (for objects with required constructor parameters)
clone := sourceObject.DeepCloneA(ConstructorParams [, Depth])

; ConstructorParams
; {Map} - Map where keys are class names (Type(object)) and values are arrays of constructor parameters
```

## Code Examples

### Example 1: Basic DeepClone Usage

```cpp
; Include the DeepClone method
#Include Object.Prototype.DeepClone.ahk
#Include GetObjectFromString.ahk

; Create a nested object structure
originalObj := {
    name: "Parent",
    child: {
        name: "Child",
        data: [1, 2, 3],
        settings: Map("enabled", true, "color", "blue")
    }
}

; Create circular reference
originalObj.self := originalObj

; Create a deep clone
clonedObj := originalObj.DeepClone()

; Modify the clone without affecting the original
clonedObj.child.name := "Modified Child"
clonedObj.child.data.Push(4)
clonedObj.child.settings["color"] := "red"

; Original is unchanged
MsgBox("Original child name: " originalObj.child.name)  ; Still "Child"
MsgBox("Original data length: " originalObj.child.data.Length)  ; Still 3
MsgBox("Original color: " originalObj.child.settings["color"])  ; Still "blue"
```

### Example 2: Using DeepCloneA for Objects with Constructor Parameters

```cpp
#Include Object.Prototype.DeepCloneA.ahk
#Include GetObjectFromString.ahk

; Define a class that requires constructor parameters
class Person {
    __New(name, age) {
        this.name := name
        this.age := age
    }
    
    SayHello() {
        return "Hello, my name is " this.name " and I'm " this.age " years old."
    }
}

; Create an instance
originalPerson := Person("John", 30)

; Set up constructor parameters for deep cloning
constructorParams := Map(
    "Person", ["Jane", 25]  ; Parameters for Person constructor
)

; Create a deep clone with new constructor parameters
clonedPerson := originalPerson.DeepCloneA(constructorParams)

; Verify the clone has the right properties and methods
MsgBox(clonedPerson.SayHello())  ; "Hello, my name is Jane and I'm 25 years old."
```

### Example 3: Complex Object with Limited Clone Depth

```cpp
; Create a deeply nested object
deepObj := {
    level1: {
        level2: {
            level3: {
                level4: {
                    data: "Deep data"
                }
            }
        }
    }
}

; Clone only to depth 2
shallowClone := deepObj.DeepClone(2)

; The first two levels are cloned objects
MsgBox(IsObject(shallowClone.level1))  ; true (new object)
MsgBox(IsObject(shallowClone.level1.level2))  ; true (new object)

; But deeper levels are references to the original
MsgBox(shallowClone.level1.level2.level3 == deepObj.level1.level2.level3)  ; true (same reference)
```

## Implementation Notes

- Relies on a helper function `GetObjectFromString` to properly handle class references with dots in the name
- The standard DeepClone may fail to set the correct type for objects with required constructor parameters
- Object type is determined using the following sequence:
  1. Try to create a new instance of the object's class
  2. If that fails, check if the object inherits from Map or Array
  3. If neither applies, create a base Object
  4. Set the new object's base to match the original's base
- Uses the `ObjPtr()` function to track already-cloned objects and handle circular references
- For Arrays, the function properly handles sparse arrays (arrays with non-consecutive indices)
- Property descriptors (including getters, setters, and callable methods) are preserved in the clone

## Related AHK Concepts

- Object Prototypes
- Property Descriptors
- Class Inheritance
- Maps and Arrays
- Circular References
- Constructor Parameters
- Type Detection

## Tags

#AutoHotkey #OOP #DeepClone #ObjectCopy #Prototyping #Utility #Methods