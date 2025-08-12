# AutoHotkey v2 Coding Standards

This document outlines comprehensive coding standards and best practices for AutoHotkey v2 development. Following these guidelines will help ensure your code is maintainable, efficient, and follows proper AHK v2 idioms.

## Table of Contents

1. [Core Syntax Rules](#core-syntax-rules)
2. [Object-Oriented Programming](#object-oriented-programming)
3. [GUI Development](#gui-development)
4. [Error Handling](#error-handling)
5. [Data Structures](#data-structures)
6. [Hotkeys and Hotstrings](#hotkeys-and-hotstrings)
7. [Code Organization](#code-organization)
8. [Performance Considerations](#performance-considerations)

## Core Syntax Rules

### Script Header

Always include the appropriate headers in your scripts:

```autohotkey
#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force
```

### Variable Declaration

- Always declare your variables explicitly with appropriate scope
- Use `global` for truly global variables
- Use `static` for variables that persist between function calls
- Local variables are automatically declared when they are first used within a function

```autohotkey
; Good
global appName := "MyApp"
MyFunction() {
    static counter := 0
    counter++
    local result := counter * 2
    return result
}

; Bad - implicit globals
appName := "MyApp"  ; Creates an implicit global variable
```

### Comments

- Use semicolons for comments, not C-style comments
- Include a space after the semicolon

```autohotkey
; Good - single line comment
x := 10  ; Inline comment

; Bad
//This is a C-style comment
/*
  This is a C-style block comment
*/
```

### String Handling

- Use double quotes for strings
- Escape double quotes within strings using backtick (`), not backslash
- Use Format() for complex string formatting

```autohotkey
; Good
message := "User said: `"Hello!`""
formatted := Format("Value is {1}, Name is {2}", value, name)

; Bad
message := "User said: \"Hello!\""  ; Backslash escaping
```

## Object-Oriented Programming

### Class Definition

Define classes with proper syntax and structure:

```autohotkey
class MyClass {
    ; Static properties (shared across all instances)
    static Config := Map(
        "version", "1.0.0",
        "name", "MyClass"
    )
    
    ; Instance properties with initial values
    value := 0
    name := ""
    
    ; Constructor
    __New(name := "") {
        this.name := name
    }
    
    ; Methods
    Increment(amount := 1) {
        this.value += amount
        return this.value
    }
    
    ; Property with accessors
    Value {
        get => this.value
        set => this.value := value
    }
}
```

### Class Initialization

- Initialize classes without using the `new` keyword
- Store the instance if you need to reference it

```autohotkey
; Good
myInstance := MyClass()

; Bad
myInstance := new MyClass()  ; 'new' keyword is not needed
```

### Method Binding

Always bind methods when used as callbacks:

```autohotkey
; Good
button.OnEvent("Click", this.HandleClick.Bind(this))
SetTimer(this.UpdateStatus.Bind(this), 1000)

; Bad
button.OnEvent("Click", this.HandleClick)  ; Will lose 'this' context
```

### Arrow Functions

Use arrow functions only for simple, single-line expressions:

```autohotkey
; Good - single line arrow function
callback := (x, y) => x + y
button.OnEvent("Click", (*) => MsgBox("Clicked"))

; Bad - complex logic in arrow function
callback := (x, y) => {
    result := x * 2
    result += y
    return result
}
```

### Inheritance

Properly implement inheritance using the `extends` keyword:

```autohotkey
class Parent {
    __New() {
        this.value := 100
    }
    
    Method() {
        return this.value
    }
}

class Child extends Parent {
    __New() {
        super.__New()  ; Call parent constructor
        this.childValue := 200
    }
    
    Method() {
        return super.Method() + this.childValue  ; Call parent method
    }
}
```

## GUI Development

### GUI Creation

Create GUIs using proper object-oriented syntax:

```autohotkey
myGui := Gui("+Resize", "Window Title")
myGui.SetFont("s10")
```

### Control Addition

Add controls with appropriate options and store references if needed:

```autohotkey
; Add a control and store it for later reference
myEdit := myGui.AddEdit("w200 h100 vUserInput")

; Add a control with an event handler
myButton := myGui.AddButton("w100", "Submit")
myButton.OnEvent("Click", HandleSubmit)
```

### GUI Events

Use OnEvent for handling GUI events:

```autohotkey
myGui.OnEvent("Close", GuiClose)
myGui.OnEvent("Size", GuiSize)
```

### GUI in Classes

Properly structure GUI code in classes:

```autohotkey
class MyApplication {
    gui := ""
    controls := Map()
    
    __New() {
        this.CreateGui()
    }
    
    CreateGui() {
        this.gui := Gui("+Resize", "My Application")
        
        ; Store controls in a Map for easy access
        this.controls["edit"] := this.gui.AddEdit("w200")
        this.controls["button"] := this.gui.AddButton("w100", "Submit")
        this.controls["button"].OnEvent("Click", this.HandleSubmit.Bind(this))
        
        ; Set up events
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
    }
    
    HandleSubmit(*) {
        MsgBox("Button was clicked")
    }
}
```

## Error Handling

### Try-Catch Blocks

Use try-catch for operations that might fail:

```autohotkey
try {
    file := FileOpen(path, "r")
    content := file.Read()
    file.Close()
} catch Error as e {
    MsgBox("Error reading file: " e.Message)
}
```

### Custom Error Handling

Create structured error handling:

```autohotkey
class MyErrors {
    static Messages := Map(
        "FileNotFound", "The specified file could not be found.",
        "InvalidInput", "The input provided is not valid."
    )
}

MyFunction() {
    if !FileExist(path)
        throw Error(MyErrors.Messages["FileNotFound"], -1)
}
```

## Data Structures

### Maps for Key-Value Data

Always use Map() for key-value data, not object literals:

```autohotkey
; Good
config := Map(
    "width", 800,
    "height", 600,
    "title", "My Application"
)

; Bad
config := { width: 800, height: 600, title: "My Application" }
```

### Arrays

Use arrays for sequential data:

```autohotkey
; Create an array
fruits := ["apple", "banana", "orange"]

; Loop through array
for index, fruit in fruits
    MsgBox(index ": " fruit)
```

### Static Configuration

Use static Maps in classes for configuration data:

```autohotkey
class Config {
    static Settings := Map(
        "appName", "MyApp",
        "version", "1.0.0",
        "paths", Map(
            "config", A_AppData "\MyApp\config.ini",
            "logs", A_AppData "\MyApp\logs\"
        )
    )
}
```

## Hotkeys and Hotstrings

### Hotkey Definition

Use proper object-oriented hotkey definition:

```autohotkey
; For dynamic hotkeys in a class
class HotkeyManager {
    __New() {
        Hotkey("^s", this.SaveFile.Bind(this))
        Hotkey("#t", this.ToggleWindow.Bind(this))
    }
    
    SaveFile(*) {
        MsgBox("Saving file...")
    }
    
    ToggleWindow(*) {
        MsgBox("Toggling window...")
    }
}
```

### Context-Sensitive Hotkeys

Use HotIf directives for context-sensitive hotkeys:

```autohotkey
; Hotkeys that only work in Notepad
HotIfWinActive("ahk_class Notepad")
Hotkey("^b", MakeBold)
Hotkey("^i", MakeItalic)
HotIf()  ; End context

; Hotkeys that only work when a specific variable is true
HotIf(*) => isEditing
Hotkey("Escape", CancelEdit)
HotIf()
```

## Code Organization

### Script Structure

Organize your scripts in a logical manner:

```autohotkey
#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force
#Include lib\Utils.ahk  ; Include external files

; Initialize main application class
MyApp()

; Define classes
class MyApp {
    ; Class implementation
}

; Define functions
UtilityFunction() {
    ; Function implementation
}
```

### Project Organization

For larger projects, organize files by functionality:

```
/MyProject
  main.ahk        ; Entry point script
  /lib            ; Library files
    Utils.ahk
    Network.ahk
  /ui             ; User interface modules
    MainWindow.ahk
    SettingsDialog.ahk
  /data           ; Data handling
    Config.ahk
    Storage.ahk
```

## Performance Considerations

### Variable Access

- Avoid repeatedly accessing the same property or calculating the same value
- Cache values that are used multiple times

```autohotkey
; Good
length := array.Length
for i := 1 to length
    DoSomething(array[i])

; Bad
for i := 1 to array.Length  ; Recalculates length on each iteration
    DoSomething(array[i])
```

### Resource Cleanup

Always clean up resources when done:

```autohotkey
file := FileOpen(path, "r")
try {
    content := file.Read()
} finally {
    file.Close()  ; This runs even if Read() throws an error
}
```

### Avoid Global Variables

Minimize the use of global variables:

```autohotkey
; Better
class AppState {
    static Config := Map(
        "setting1", value1,
        "setting2", value2
    )
}

; Then access via:
AppState.Config["setting1"]
