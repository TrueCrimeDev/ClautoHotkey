# Topic: ImportNs - Namespace Import Function

## Category

Method

## Overview

ImportNs is a function that facilitates importing static members from one class to another, simulating namespace behavior in AutoHotkey. It provides a solution to code sharing challenges by allowing selective importing, renaming, exclusion, and choice between copying or referencing values, creating a practical namespacing system without requiring language modification.

## Key Points

- Imports static properties, methods, and nested classes between namespace classes
- Supports selective imports with include/exclude modes and item renaming
- Can import by value (copy) or by reference
- Allows importing from nested namespace classes (e.g., `nestedNs.item3`)
- BETA support for importing into the global namespace

## Syntax and Parameters

```cpp
ImportNs(tgtNsClass, srcNsClass, items*)
```

Parameters:
- `tgtNsClass` - Target class to import into (or `GlobalNs` for global namespace)
- `srcNsClass` - Source class to import from
- `items*` - Optional variadic parameter with these possible values:
  - `"item"` - Include only this item
  - `"item1 as new1"` - Include and rename
  - `ImportNs.Exclude` - Switch to exclusion mode
  - `ImportNs.AsRef` - Switch to reference mode (default is copying)
  - `"nestedNs.item"` - Import from nested namespace

## Code Examples

Basic usage - import everything:

```cpp
class ConfigNamespace {
    static AppSettings := { theme: "dark", fontSize: 12 }
    static GetSetting(key) {
        return this.AppSettings.HasOwnProp(key) ? this.AppSettings.%key% : ""
    }
}

class AppNamespace {
    static Name := "MyApplication"
}

; Import all members from ConfigNamespace to AppNamespace
ImportNs(AppNamespace, ConfigNamespace)

; Now we can access ConfigNamespace members through AppNamespace
MsgBox AppNamespace.GetSetting("theme")  ; Shows "dark"
```

Selective import with renaming:

```cpp
class MathUtils {
    static Add(a, b) {
        return a + b
    }
    static Subtract(a, b) {
        return a - b
    }
    static Multiply(a, b) {
        return a * b
    }
}

class Calculator {
    static Calculate(op, a, b) {
        return this.%op%(a, b)
    }
}

; Import only Add and Multiply, renaming them
ImportNs(Calculator, MathUtils, "Add as Sum", "Multiply as Product")

; Now we can use the renamed functions
MsgBox Calculator.Sum(5, 3)      ; Shows 8
MsgBox Calculator.Product(4, 5)  ; Shows 20

; This would throw an error since Subtract wasn't imported
; MsgBox Calculator.Subtract(10, 4)
```

Import by reference:

```cpp
class SharedState {
    static Data := { count: 0 }
    static IncrementCount() {
        this.Data.count++
    }
}

class Worker {
    static ProcessItem() {
        this.Data.count++
        return "Processed item #" this.Data.count
    }
}

; Import Data by reference
ImportNs(Worker, SharedState, ImportNs.AsRef, "Data")

; Both classes now share the same Data object
SharedState.IncrementCount()
MsgBox Worker.Data.count      ; Shows 1
Worker.Data.count++
MsgBox SharedState.Data.count ; Shows 2
```

## Implementation Notes

- Internally uses class property definitions to create redirects or copies
- Maintains a record of imported items in `__Imported` to prevent conflicts
- Importing the same item from the same source is allowed and has no effect
- Importing an item with the same name from a different source throws an error
- Reference mode (`ImportNs.AsRef`) is more efficient but changes to values are visible in both namespaces
- Global namespace imports have limitations due to how AutoHotkey handles global variables
- Properties with custom getters, setters, and methods are properly handled during import

## Related AHK Concepts

- Static Class Members
- Property Definition
- Error Handling
- Global Variables
- Class Organization

## Tags

#AutoHotkey #OOP #Namespaces #ImportNs #CodeOrganization #StaticMembers