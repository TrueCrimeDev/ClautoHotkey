# Topic: Deep Object Comparison Method

## Category

Method

## Overview

The `DeepCompare` method provides a way to compare two AutoHotkey objects deeply, checking if they have identical structure and values, rather than just comparing references. This method is essential when working with complex nested objects, as the standard equality operator (`=`) only compares object references, not their contents. Deep comparison helps ensure data integrity, validate configuration changes, and implement advanced testing frameworks.

## Key Points

- Recursively compares all properties and their values in two objects
- Handles nested objects, arrays, and maps
- Returns true only if objects are structurally identical
- Properly compares primitive values, arrays, objects, and maps
- Can be added to Object.Prototype for universal availability
- Works with circular references by tracking objects already compared

## Syntax and Parameters

```cpp
; As a standalone function
result := DeepCompare(obj1, obj2)

; Or as a method on Object.Prototype
Object.Prototype.DefineProp("DeepCompare", {
    call: (this, obj) => DeepCompare(this, obj)
})

; Then used as
result := obj1.DeepCompare(obj2)
```

## Code Examples

```cpp
; Deep comparison function for AutoHotkey objects
DeepCompare(a, b, seen := Map()) {
    ; If either a or b is not an object, simple comparison
    if (!IsObject(a) || !IsObject(b))
        return a = b
    
    ; Different object types can't be equal
    if (Type(a) != Type(b))
        return false
    
    ; Check for circular references
    if seen.Has(a) && seen[a].Has(b)
        return true  ; We've seen this pair before, assume they're equal
    
    ; Add to seen map
    if !seen.Has(a)
        seen[a] := Map()
    seen[a][b] := true
    
    ; For arrays, check length then compare each element
    if (a is Array) {
        if (a.Length != b.Length)
            return false
        
        loop a.Length {
            if !DeepCompare(a[A_Index], b[A_Index], seen)
                return false
        }
        return true
    }
    
    ; For maps, check entry count, then compare each key-value pair
    if (a is Map) {
        if (a.Count != b.Count)
            return false
        
        for key, val in a {
            if (!b.Has(key) || !DeepCompare(val, b[key], seen))
                return false
        }
        return true
    }
    
    ; For other objects, get all properties and compare
    aKeys := GetObjKeys(a)
    bKeys := GetObjKeys(b)
    
    ; Different property count means not equal
    if (aKeys.Length != bKeys.Length)
        return false
    
    ; Check each property in a exists in b with same value
    for key in aKeys {
        if (!HasProp(b, key) || !DeepCompare(a.%key%, b.%key%, seen))
            return false
    }
    
    return true
    
    ; Helper function to get all properties of an object
    GetObjKeys(obj) {
        result := []
        for prop in obj.OwnProps()
            result.Push(prop)
        return result
    }
    
    ; Helper function to safely check if an object has a property
    HasProp(obj, propName) {
        try return obj.HasOwnProp(propName)
        catch
            return false
    }
}

; Usage example
; Create two similar object structures
obj1 := {
    name: "Configuration",
    settings: {
        darkMode: true,
        fontSize: 12,
        colors: ["#000000", "#FFFFFF", "#FF0000"]
    },
    enabled: true
}

obj2 := {
    name: "Configuration",
    settings: {
        darkMode: true,
        fontSize: 12,
        colors: ["#000000", "#FFFFFF", "#FF0000"]
    },
    enabled: true
}

obj3 := {
    name: "Configuration",
    settings: {
        darkMode: false,  ; Different value here
        fontSize: 12,
        colors: ["#000000", "#FFFFFF", "#FF0000"]
    },
    enabled: true
}

; Compare the objects
MsgBox("obj1 equals obj2: " DeepCompare(obj1, obj2))  ; Should be true
MsgBox("obj1 equals obj3: " DeepCompare(obj1, obj3))  ; Should be false

; Add as a method to Object.Prototype
Object.Prototype.DefineProp("DeepCompare", {
    call: (this, obj) => DeepCompare(this, obj)
})

; Then use it as a method
MsgBox("Using method - obj1 equals obj2: " obj1.DeepCompare(obj2))  ; Should be true
```

## Implementation Notes

- The function uses a "seen" map to track already compared objects, preventing infinite recursion with circular references
- For Maps, the function checks if all keys in one map exist in the other and have the same values
- When comparing Arrays, both the length and the values at each index must match
- For regular Objects, all properties must match in name and value
- The function handles different object types (Array, Map, Object) appropriately
- Performance may degrade with very large or deeply nested objects
- Consider implementing a maxDepth parameter to limit recursion for very deep structures
- The implementation handles AHK-specific object types but could be extended for custom classes
- When adding to Object.Prototype, be aware this affects all objects in your application

## Related AHK Concepts

- [Deep Cloning Objects](../Snippets/deep-cloning-objects.md)
- [Object.Prototype Extensions](../Snippets/extending-builtin-objects.md)
- [Map Usage Best Practices](../Concepts/map-usage-best-practices.md)
- [Type Checking](../Concepts/type-checking.md)
- [Circular References](../Concepts/circular-references.md)

## Tags

#AutoHotkey #OOP #DeepComparison #Objects #Arrays #Maps #Recursion #Utility #v2