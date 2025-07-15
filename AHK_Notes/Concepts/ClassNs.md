# Topic: ClassNs - Namespace Simulation in AutoHotkey

## Category

Concept

## Overview

ClassNs is a pattern that uses static class members to simulate namespaces in AutoHotkey. It addresses the challenge of code sharing and symbol naming conflicts through a system that allows importing variables, functions, and other members from one namespace class into another, with options for copying or referencing values, including or excluding specific items, and even renaming during import.

## Key Points

- Uses classes with static members to simulate namespaces, addressing the lack of native namespace support in AutoHotkey
- Provides an `ImportNs` function to copy or reference items between namespace classes
- Supports selective importing, exclusion, and renaming of namespace members
- BETA support for importing into the global namespace

## Syntax and Parameters

```cpp
ImportNs(tgtNsClass, srcNsClass, items*)
```

- `tgtNsClass` - The class to import into (target namespace)
- `srcNsClass` - The class to import from (source namespace)
- `items*` - Optional variadic parameter specifying which items to include/exclude

Special items options:
- `"item"` - Include only this item
- `"item1 as new1"` - Include and rename
- `ImportNs.Exclude` - Switch to exclusion mode
- `ImportNs.AsRef` - Switch to reference mode (default is copying)

## Code Examples

```cpp
; Define a namespace class with static members
class MyNamespace {
    static Config := { version: "1.0" }
    static GetVersion() {
        return this.Config.version
    }
}

; Define another namespace with different functionality
class UtilsNamespace {
    static FormatTime(format) {
        return FormatTime(, format)
    }
    static GenerateID() {
        return "ID-" A_TickCount
    }
}

; Import specific functions from UtilsNamespace into MyNamespace
ImportNs(MyNamespace, UtilsNamespace, "GenerateID as CreateID")

; Now we can use the imported function through MyNamespace
MsgBox "Generated: " MyNamespace.CreateID()
```

Example with reference mode:

```cpp
; Create two namespace classes
class ConfigNs {
    static Settings := { debug: true, logLevel: "info" }
}

class AppNs {
    static Name := "MyApp"
}

; Import Settings from ConfigNs into AppNs by reference
ImportNs(AppNs, ConfigNs, ImportNs.AsRef, "Settings")

; Changes in the target namespace affect the source
AppNs.Settings.logLevel := "debug"
MsgBox ConfigNs.Settings.logLevel  ; Shows "debug"
```

## Implementation Notes

- Default import mode makes copies, so changes to imported items don't affect the original namespace
- Using `ImportNs.AsRef` creates references to the original items, meaning changes are reflected in both namespaces
- You cannot add properties to a preexisting class in AutoHotkey, but this pattern works around that limitation
- When importing into the global namespace (using `GlobalNs`), referenced imports are wrapped in `ImportVarRef` objects requiring `[]` to dereference
- Importing items that don't exist in the source namespace results in a `PropertyError`
- Attempting to import a name that already exists in the target namespace from a different source will throw an `ImportNsError`

## Related AHK Concepts

- Static Class Members
- Property Definition
- Class Extension
- Error Handling

## Tags

#AutoHotkey #OOP #Namespaces #ClassExtension #CodeOrganization