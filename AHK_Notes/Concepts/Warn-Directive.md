# Topic: #Warn Directive

## Category

Concept

## Overview

The `#Warn` directive enables or disables warnings for specific conditions that may indicate errors in AutoHotkey scripts. It's a powerful debugging tool that can help identify problems like typos, missing variable declarations, or unreachable code before they cause runtime errors.

## Key Points

- Controls warning behavior for variable usage problems, local/global conflicts, and unreachable code
- Warnings can be displayed via message boxes, standard output, or debug output
- Different warning types can be controlled independently
- Warnings are checked before script execution, so placement in the script doesn't matter

## Syntax and Parameters

```cpp
#Warn [WarningType, WarningMode]
```

### Parameters

**WarningType**:
- `All`: Apply the warning mode to all supported warning types
- `VarUnset`: Warn about variables that are referenced but never assigned a value
- `LocalSameAsGlobal`: Warn about local variables with the same name as globals (disabled by default)
- `Unreachable`: Warn about code that can never execute (follows Return, Break, Continue, etc.)

**WarningMode**:
- `MsgBox`: Show warning in a message box (default)
- `StdOut`: Send warning to standard output (useful with editors like SciTE)
- `OutputDebug`: Send warning to the debugger
- `Off`: Disable warnings of the specified type

## Code Examples

```cpp
; Enable all warnings (default behavior if no #Warn is specified)
#Warn

; Disable all warnings (not recommended)
#Warn All, Off

; Enable specific warning with custom output mode
#Warn LocalSameAsGlobal, OutputDebug

; Example that would trigger a LocalSameAsGlobal warning
g := 1
ShowG() {
    ; global g  ; <-- Missing declaration would cause a warning
    g := 2  ; This creates a local g variable, not modifying the global one
}
ShowG()
MsgBox g  ; Still shows 1, not 2
```

## Implementation Notes

- If multiple `#Warn` directives exist, the last occurrence for a given warning type takes precedence
- The directive is processed before script execution, so it cannot be conditionally executed
- `LocalSameAsGlobal` warnings are disabled by default, but all other warnings are enabled
- To suppress warnings for intentional code patterns:
  - For `Unreachable` code, add a label before the unreachable code
  - For `LocalSameAsGlobal`, explicitly declare variables with `local` or `global`
  - For `VarUnset`, initialize variables before use or use `IsSet()` to check them

## Related AHK Concepts

- Local and Global Variables
- Variable Scope
- Debugging Techniques
- IsSet() Function

## Tags

#AutoHotkey #Directive #Debugging #ErrorHandling #ScriptOptimization