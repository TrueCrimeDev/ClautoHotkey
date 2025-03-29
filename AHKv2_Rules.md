# AutoHotkey v2 Coding Rules and Best Practices

## Core Syntax Rules

1. **Always use proper version header**
   ```autohotkey
   #Requires AutoHotkey v2.1-alpha.16
   #SingleInstance Force
   ```

2. **Require explicit variable declarations**
   - Use `global` for global variables
   - Define variables before use
   - Avoid implicit global variables

3. **Initialize classes correctly**
   ```autohotkey
   MyClass() ; Correct - creates an instance
   myVar := MyClass() ; Also correct - assigns the instance
   new MyClass() ; Incorrect - "new" keyword not needed in AHK v2
   ```

4. **Never use object literals for data storage**
   ```autohotkey
   ; CORRECT
   config := Map("width", 800, "height", 600)
   
   ; INCORRECT - will cause issues
   config := {width: 800, height: 600}
   ```

5. **Use proper comment syntax**
   ```autohotkey
   ; Use semicolons for comments
   /* 
     Multi-line comments are OK
   */
   // NEVER use C-style single-line comments
   ```

## OOP and Class Design

1. **Class Initialization**
   ```autohotkey
   MyClass() ; Always initialize classes at the top of the script
   
   class MyClass {
       __New() {
           ; Constructor code here
       }
   }
   ```

2. **Method Binding**
   ```autohotkey
   ; CORRECT - binding 'this' context to the method
   button.OnEvent("Click", this.HandleClick.Bind(this))
   
   ; INCORRECT - will lose 'this' context
   button.OnEvent("Click", this.HandleClick)
   ```

3. **Property Accessors**
   ```autohotkey
   property {
       get => this._property ; Use arrow for simple accessors
       set => this._property := value
   }
   ```

4. **Arrow Function Usage**
   - Use arrow functions (`=>`) **ONLY** for simple, single-line expressions
   - **NEVER** use arrow functions for multiline logic or when `{}` would be needed
   ```autohotkey
   ; CORRECT - simple arrow function
   button.OnEvent("Click", (*) => this.gui.Hide())
   
   ; INCORRECT - complex logic should use normal function syntax
   button.OnEvent("Click", (*) => {
       this.SaveData()
       this.gui.Hide()
   })
   ```

5. **Static Properties**
   ```autohotkey
   class Config {
       ; Static config maps are preferred
       static Settings := Map(
           "width", 800,
           "height", 600
       )
   }
   ```

## Data Structures

1. **Maps for Key-Value Data**
   ```autohotkey
   settings := Map(
       "title", "My Application",
       "version", "1.0.0",
       "debug", true
   )
   
   ; Access via key
   MsgBox "Version: " settings["version"]
   ```

2. **Arrays for Sequential Data**
   ```autohotkey
   fruits := ["apple", "banana", "orange"]
   
   ; Arrays are 1-indexed in AHK
   MsgBox "First fruit: " fruits[1]
   
   ; Adding items
   fruits.Push("grape")
   ```

3. **Classes for Complex Data**
   ```autohotkey
   class User {
       Name := ""
       Email := ""
       
       __New(name, email) {
           this.Name := name
           this.Email := email
       }
   }
   
   users := []
   users.Push(User("John", "john@example.com"))
   ```

## GUI Best Practices

1. **GUI Construction**
   ```autohotkey
   class MyGui {
       __New() {
           this.gui := Gui("+Resize", "My Application")
           this.gui.SetFont("s10")
           
           ; Add controls
           this.gui.AddText("w200", "Enter your name:")
           this.gui.AddEdit("w200 vUserName")
           this.gui.AddButton("w100 Default", "Submit").OnEvent("Click", this.Submit.Bind(this))
           
           ; Set events
           this.gui.OnEvent("Close", (*) => this.gui.Hide())
           this.gui.OnEvent("Escape", (*) => this.gui.Hide())
       }
       
       Submit(*) {
           saved := this.gui.Submit()
           MsgBox "Hello, " saved.UserName
       }
       
       Show(*) => this.gui.Show()
   }
   ```

2. **Event Handling**
   - Always bind event callbacks to preserve `this` context
   - Use descriptive method names for handlers
   - Consider using `HotIfWinActive` for GUI-specific hotkeys

## Error Handling

1. **Try/Catch Blocks**
   ```autohotkey
   try {
       result := RiskyOperation()
   } catch Error as e {
       MsgBox "Error: " e.Message
   }
   ```

2. **Error Messages**
   - Store error messages in static Maps
   - Use descriptive error codes
   - Include context in error messages

## Common Pitfalls to Avoid

1. **V1 vs V2 Syntax**
   - AHK v2 uses function call syntax with parentheses
   - `MsgBox("Text")` not `MsgBox Text`
   - `FileExist()` returns string, not 1/0

2. **String Escaping**
   - Use backtick (`` ` ``) to escape quotes, not backslash
   ```autohotkey
   MsgBox "He said `"Hello`" to me" ; CORRECT
   MsgBox "He said \"Hello\" to me" ; INCORRECT
   ```

3. **Variable References**
   - No `%var%` syntax in v2
   - Use direct variable references: `MsgBox var`

4. **Function Parameters**
   - Always provide the correct number of parameters
   - Use optional parameters with default values when appropriate

5. **Object Access**
   - Use dot notation for methods and properties: `obj.Method()`
   - Use bracket notation for Maps: `map["key"]`

## Documentation and Style

1. **Code Organization**
   - Place initialization at the top
   - Group related functions and methods
   - Order methods logically (constructor, public methods, private methods)

2. **Naming Conventions**
   - `ClassName` - PascalCase for class names
   - `methodName` - camelCase for methods and functions
   - `_privateMember` - underscore prefix for private variables

3. **Clear Structure**
   - Break complex tasks into smaller, reusable functions
   - Use descriptive names that explain what the code does
   - Keep methods focused on a single responsibility

## Performance Tips

1. **Avoid unnecessary object creation**
   - Reuse objects when possible
   - Consider using static methods for utility functions

2. **Optimize loops**
   - Use `for key, value in array` instead of indexed access in loops
   - Exit loops early when possible

3. **Cache repeated calculations**
   - Store results of expensive operations rather than recomputing

## Resources

- [Official AHK v2 Documentation](https://www.autohotkey.com/docs/v2/)
- [AHK v2 Migration Guide](https://www.autohotkey.com/docs/v2/v1-changes.htm)
- [Common AHK v2 Patterns](https://www.autohotkey.com/docs/v2/lib/Object.htm)
