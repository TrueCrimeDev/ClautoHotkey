# Topic: ImportNsError - Namespace Import Error

## Category

Class

## Overview

ImportNsError is a specialized error class used within the ClassNs system to indicate problems related to namespace imports. It extends the standard Error class and provides clearer error messages specific to namespace import operations, helping developers troubleshoot issues when using the ImportNs function.

## Key Points

- Extends the built-in Error class
- Used to differentiate namespace import errors from other error types
- Thrown when attempting to import items with name conflicts
- Part of the error handling system in the ClassNs pattern

## Syntax and Parameters

```cpp
; Typically thrown by ImportNs
throw ImportNsError("Error message")
```

## Code Examples

Error handling example:

```cpp
; Define two namespace classes with conflicting property names
class NamespaceA {
    static Config := { version: "1.0" }
}

class NamespaceB {
    static Config := { mode: "production" }
}

; Create a target namespace
class AppNamespace {
}

; Import from first namespace
ImportNs(AppNamespace, NamespaceA)

; Try to import the conflicting property and handle the error
try {
    ImportNs(AppNamespace, NamespaceB)
} catch ImportNsError as err {
    MsgBox "Import failed: " err.Message
    ; Shows: Import failed: "Config" already exists in namespace class "AppNamespace".
}
```

Selective import to avoid errors:

```cpp
class UtilsA {
    static FormatDate(date) {
        return FormatTime(date, "yyyy-MM-dd")
    }
    static ParseDate(str) {
        return DateParse(str)
    }
}

class UtilsB {
    static FormatDate(date) {
        return FormatTime(date, "MM/dd/yyyy")
    }
    static GenerateID() {
        return "ID-" A_TickCount
    }
}

; Import all from UtilsA
ImportNs(AppNamespace, UtilsA)

; Selectively import from UtilsB to avoid conflict
try {
    ImportNs(AppNamespace, UtilsB, ImportNs.Exclude, "FormatDate")
    ; This works because we excluded the conflicting method
} catch ImportNsError as err {
    MsgBox "Import failed: " err.Message
}
```

## Implementation Notes

- ImportNsError is thrown when:
  - Attempting to import an item with a name that already exists in the target namespace
  - Trying to import an item from a different source than was previously imported
  - Using invalid syntax in the import specification
  - Attempting to import from the GlobalNs (which is not supported)
- Distinguished from PropertyError (thrown when an imported item doesn't exist in the source)
- When catching errors during import operations, you can specifically catch ImportNsError for namespace-related issues

## Related AHK Concepts

- Error Handling
- ClassNs Pattern
- ImportNs Function
- Class Extension

## Tags

#AutoHotkey #OOP #ErrorHandling #ImportNs #Exceptions