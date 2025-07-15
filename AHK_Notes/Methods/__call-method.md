# Topic: Error Handling with __Call Method

## Category

Method

## Overview

The __Call method is a special meta-method in AutoHotkey v2 that intercepts calls to undefined methods in a class. It provides an elegant way to catch programming errors such as misspelled method names or missing method declarations, allowing for robust error handling and debugging.

## Key Points

- __Call automatically receives the name of the attempted method call and any parameters
- Useful for detecting undefined method calls to prevent silent failures
- Can be used to implement dynamic method dispatching or fallback behavior
- Improves code robustness and error detection

## Syntax and Parameters

```cpp
class ClassName {
    __Call(Method, Params*) {
        ; Method - String containing the name of the called method
        ; Params - All parameters passed to the nonexistent method
    }
}
```

## Code Examples

```cpp
MenuSystem()

class MenuSystem {
    static Name := "MenuSystem"
    
    __New() {
        this.SetupProperties()
    }
    
    __Call(Method, Args*) {
        MsgBox "Error: The method '" . Method . "' does not exist in class " . MenuSystem.Name
        return
    }
    
    SetupProperties() {
        MsgBox "SetupProperties executed successfully"
    }
    
    CreateMenus() {
        MsgBox "CreateMenus executed successfully"
    }
}

; Usage examples:
menu := MenuSystem()
menu.SetupProperties() ; Works correctly
menu.CreateMenus()    ; Works correctly
menu.SetupPropertie() ; Typo - will trigger __Call with error message
```

## Implementation Notes

- __Call only triggers for undefined methods, not for accessing undefined properties
- Be careful not to create infinite recursion by calling nonexistent methods within __Call
- Consider logging errors to a file rather than displaying messages for production code
- The Method parameter is case-sensitive, matching the exact case used in the call
- Can be combined with exception handling for more sophisticated error reporting

## Related AHK Concepts

- Method Context and Binding
- Class Meta-Methods
- Exception Handling
- Object Prototypes

## Tags

#AutoHotkey #OOP #ErrorHandling #MetaMethods #__Call