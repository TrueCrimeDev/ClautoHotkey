# Topic: ImportVarRef - Variable Reference Wrapper

## Category

Class

## Overview

ImportVarRef is a helper class used by the ClassNs system that creates wrapper objects to reference variables from another namespace. It's primarily used when importing items into the global namespace by reference, providing a workaround for AutoHotkey's limitations with global variable references.

## Key Points

- Creates a wrapper object that proxies access to the original variable
- Supports read-only or read-write access to the referenced variable
- Special handling for function references to ensure proper binding
- Access to wrapped variables requires using `[]` operator

## Syntax and Parameters

```cpp
; Not typically created directly, but through ImportNs
reference := ImportVarRef(srcNsClass, srcKey, readonly, function?)
```

Parameters:
- `srcNsClass` - Source namespace class containing the variable
- `srcKey` - Property name in the source class
- `readonly` - Boolean indicating if the reference should be read-only
- `function?` - Optional boolean indicating if the reference is a function

## Code Examples

This class is primarily used internally by ImportNs, but here's how it works in context:

```cpp
class Configuration {
    static Settings := { theme: "dark", fontSize: 12 }
    static UpdateSetting(key, value) {
        if this.Settings.HasOwnProp(key)
            this.Settings.%key% := value
    }
}

; Import by reference to global namespace
ImportNs(GlobalNs, Configuration, ImportNs.AsRef)

; Access the wrapped variable using []
MsgBox Settings[].theme  ; Shows "dark"

; Modify through the reference
Settings[].fontSize := 14

; Original source is also updated
MsgBox Configuration.Settings.fontSize  ; Shows 14

; Using imported function with proper binding
UpdateSetting.Call(0, "theme", "light")
MsgBox Settings[].theme  ; Shows "light"
```

## Implementation Notes

- Implemented using property definitions with getters and setters
- The `__Item` property handles variable access through the `[]` operator
- For functions, it adds a `Call` property that properly binds the function to its source class
- Read-only references only define a getter, no setter
- The `[]` dereferencing syntax is required only for global variables, not for functions
- This is an implementation detail of ImportNs and generally shouldn't be instantiated directly

## Related AHK Concepts

- ClassNs Pattern
- ImportNs Function
- GlobalNs Class
- Property Definition
- Function Binding

## Tags

#AutoHotkey #OOP #ReferenceWrapper #ImportNs #GlobalVariables