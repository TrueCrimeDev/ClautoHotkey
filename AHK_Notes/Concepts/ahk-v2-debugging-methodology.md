# Topic: AutoHotkey v2 Debugging Methodology

## Category

Concept

## Overview

A systematic approach to debugging AutoHotkey v2 scripts that leverages error message analysis, symbol identification, and context mapping. This methodology is optimized for use with AI assistants like Claude 4 to provide structured debugging workflows that quickly identify and resolve compilation errors, warnings, and runtime issues.

## Key Points

- Error classification distinguishes between critical compilation failures, warnings, and informational notes
- Symbol identification focuses on extracting exact variable/method names from error messages with case-sensitivity awareness
- Location analysis uses arrow indicators and context review to pinpoint error scope and surrounding code structure
- Root cause analysis targets common AHK v2 patterns like scope violations, type mismatches, and OOP inheritance issues

## Syntax and Parameters

```cpp
// Error Message Pattern Recognition
Error: Variable or property not found: "VariableName"
    ▶ 047:     result := g_ErrorLogFile.Write(message)
    
Specifically: g_ErrorLogFile

// Debugging Request Format
**Error Context:** [Complete error message]
**Code Section:** [10-15 lines around error]
**Expected Behavior:** [Intended functionality]
**Tags:** #ahk-error #ahk-oop
```

## Code Examples

```cpp
// Common Error Pattern: Undefined Variable
; Problematic code
MyFunction() {
    result := g_Logger.Write("test")  ; Error: g_Logger not found
}

; Corrected code
MyFunction() {
    global g_Logger  ; Declare global access
    result := g_Logger.Write("test")
}

// Alternative: Initialize in auto-execute section
g_Logger := FileLogger("debug.log")

MyFunction() {
    result := g_Logger.Write("test")  ; Now accessible
}
```

## Implementation Notes

**Critical Considerations:**
- AHK v2 requires explicit variable declarations in function scope
- Case sensitivity matters for all identifiers in AHK v2
- Class property access needs proper instantiation and scope management
- Error messages provide specific symbol names in "Specifically:" lines
- Arrow indicators (▶) show exact line numbers where errors occur

**Common Pitfalls:**
- Forgetting `global` declarations for variables defined outside functions
- Mixing AHK v1 and v2 syntax patterns
- Incorrect super() calls in class inheritance
- Scope confusion between class methods and global functions

**Performance Notes:**
- Use structured error handling with try/catch blocks for runtime error management
- Implement logging systems for debugging complex OOP hierarchies
- Leverage AHK v2's improved error messaging for faster debugging cycles

## Related AHK Concepts

- [Error Handling Patterns](../Patterns/error-handling-patterns.md)
- [Variable Scope Management](../Concepts/variable-scope-management.md)
- [Class Inheritance Debugging](../Classes/class-inheritance-debugging.md)
- [AHK v2 Compilation Process](../Concepts/ahk-v2-compilation.md)

## Tags

#AutoHotkey #Debugging #ErrorHandling #Methodology #Troubleshooting #AHKv2