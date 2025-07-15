# Topic: AutoHotkey v2 Debugging Checklist

## Category

Snippet

## Overview

A quick reference checklist for debugging AutoHotkey v2 errors systematically. This snippet provides a step-by-step workflow that can be followed when encountering compilation errors, warnings, or runtime issues, ensuring no critical debugging steps are missed.

## Key Points

- Follows the three-step debugging process: Identify → Locate → Resolve
- Provides specific patterns to look for in AHK v2 error messages
- Includes common error types and their typical solutions
- Optimized for rapid debugging cycles during development

## Syntax and Parameters

```cpp
// Debugging Workflow Template
1. IDENTIFY ERROR TYPE
   □ Critical (red): Script won't run
   □ Warning (yellow): Potential issue
   □ Note (blue): Code quality suggestion

2. EXTRACT SYMBOL INFORMATION
   □ Find "Specifically: <symbol_name>"
   □ Note exact case and spelling
   □ Check if symbol exists in scope

3. LOCATE ERROR CONTEXT
   □ Find arrow (▶) indicator
   □ Review 5 lines above/below
   □ Identify scope (global/function/class)
```

## Code Examples

```cpp
// Debugging Checklist Implementation
class DebugHelper {
    static CheckCommonIssues(errorMsg, lineNum, codeContext) {
        ; Step 1: Parse error type
        if InStr(errorMsg, "not found")
            return this.HandleUndefinedSymbol(errorMsg, codeContext)
        else if InStr(errorMsg, "unexpected")
            return this.HandleSyntaxError(errorMsg, lineNum)
        else if InStr(errorMsg, "type mismatch")
            return this.HandleTypeError(errorMsg, codeContext)
    }
    
    static HandleUndefinedSymbol(errorMsg, context) {
        ; Extract symbol name from "Specifically: symbol"
        symbolStart := InStr(errorMsg, "Specifically: ") + 14
        symbolName := SubStr(errorMsg, symbolStart)
        
        suggestions := []
        
        ; Check for common issues
        if !InStr(context, "global " . symbolName)
            suggestions.Push("Add 'global " . symbolName "' declaration")
        
        if !InStr(context, symbolName . " :=")
            suggestions.Push("Initialize variable: " . symbolName . " := value")
            
        return suggestions
    }
}

// Quick Error Analysis Function
AnalyzeError(errorText) {
    ; Parse error components
    errorType := RegExReplace(errorText, "s)^(\w+):.*", "$1")
    
    ; Extract specifically mentioned symbol
    if RegExMatch(errorText, "Specifically: (.+)$", &match)
        problemSymbol := match[1]
    
    ; Find line number
    if RegExMatch(errorText, "▶ (\d+):", &lineMatch)
        errorLine := Integer(lineMatch[1])
    
    return {type: errorType, symbol: problemSymbol, line: errorLine}
}
```

## Implementation Notes

**Quick Reference Patterns:**

**Variable Not Found:**
- Check for `global` declaration in functions
- Verify variable initialization in auto-execute section
- Confirm spelling and case match exactly

**Method Not Found:**
- Verify object instantiation before method calls
- Check class inheritance chain for method availability
- Ensure proper `this` context in class methods

**Syntax Errors:**
- Look for missing brackets, parentheses, or braces
- Check for AHK v1 syntax being used in v2 script
- Verify proper string escaping and concatenation

**Type Mismatches:**
- Confirm string vs numeric operations
- Check array/object property access syntax
- Validate function parameter types

**Performance Tips:**
- Use IDE with AHK v2 syntax highlighting
- Enable all warnings during development
- Keep error log for pattern recognition
- Test small code sections incrementally

## Related AHK Concepts

- [Error Handling Patterns](../Patterns/error-handling-patterns.md)
- [AHK v2 Debugging Methodology](../Concepts/ahk-v2-debugging-methodology.md)
- [Variable Scope Rules](../Concepts/variable-scope-rules.md)
- [Class Error Debugging](../Classes/class-error-debugging.md)

## Tags

#AutoHotkey #Debugging #Checklist #QuickReference #ErrorAnalysis #Workflow #AHKv2