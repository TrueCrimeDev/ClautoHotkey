# Topic: Map Usage Best Practices

## Category

Concept

## Overview

Maps are key-value data structures in AutoHotkey v2 that replace object literals for data storage. They provide a safer and more consistent way to store and retrieve data with string or number keys, avoiding common errors associated with object literal syntax.

## Key Points

- Always use Map() for key-value data storage instead of object literal syntax
- Access Map values using square bracket notation: `map["key"]` rather than dot notation
- Use the Keys method to retrieve all keys from a Map
- Implement proper type checking when working with Map keys

## Syntax and Parameters

```cpp
; Creating a Map
myMap := Map(Key1, Value1, Key2, Value2, ...)

; Accessing values
value := myMap["key"]

; Adding or modifying values
myMap["newKey"] := "newValue"

; Getting all keys from a Map
keys := myMap.Keys()
```

## Code Examples

```cpp
; Define method to get keys from Map
Map.Prototype.DefineProp("Keys", { Call: get_keys })

; Create Maps with proper variable names
configMap := Map(
    "width", 800,
    "height", 600,
    "title", "My Application",
    "version", 1.0
)

; Access Map values consistently with your Map variable name
windowWidth := configMap["width"]
windowHeight := configMap["height"]

; Get all keys from the Map
allKeys := configMap.Keys()

; Iterate through a Map
for key, value in configMap
    MsgBox "Key: " key "`nValue: " value

; Implementation of get_keys helper function
get_keys(mp) {
    mapKeys := []
    for k, v in mp {
        if IsSet(k) && (k is string || k is number)
            mapKeys.Push(k)
    }
    return mapKeys
}
```

## Implementation Notes

- Never use object literal syntax (curly braces) for data storage as it can lead to unpredictable behavior
- Curly braces are still used for function/method bodies, class definitions, and control flow blocks
- Always check if a key exists with `mp.Has(key)` before trying to access it
- Store configuration data in static class Maps for better organization
- For class configuration, use `ClassName.Config["key"]` to access static Map values

## Related AHK Concepts

- Arrays in AHK v2
- Class Static Properties
- Object-Oriented Programming in AHK v2
- Data Structures

## Tags

#AutoHotkey #OOP #Map #DataStructures #BestPractices