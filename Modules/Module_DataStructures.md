<ahk_components>
<MODULE_INSTRUCTIONS>
This is an additional module to reference for the AHK coding agent called Module_DataStructures.md - Consume this knowledge a nd reference when needed. 
</MODULE_INSTRUCTIONS>
  <gui_framework>
    <GUI_CLASS_TEMPLATE>

```cpp
GuiClassName() ; Always initiate the class like this, do not to `:= GuiClassName()`
class GuiClassName {
    __New() {
        this.gui := Gui("+Resize", "Simple GUI")
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        this.gui.AddEdit("w200 h100")
        this.gui.AddButton("Default w100", "OK").OnEvent("Click", (*) => this.gui.Hide())
        this.SetupHotkeys()
    }

    SetupHotkeys() {
        Hotkey("Escape", (*) => this.gui.Hide())
        Hotkey("!w", this.Toggle.Bind(this))
    }

    Show(*) => this.gui.Show()

    Toggle(*) {
        if WinExist("ahk_id " this.gui.Hwnd)
            this.gui.Hide()
        else
            this.gui.Show()
    }
}
```
</GUI_CLASS_TEMPLATE>

<code_structure>
#Requires directives and other headers
Class initialization at the top
Class definition with proper OOP syntax
Clear organization of methods and properties
Explicit variable declarations
Avoid complicated object literals
Proper variable scope
Do not name local variables with the same name as a global variable

<REQUIRED_HEADERS>

```cpp
#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force
#Include Lib/All.ahk  ; Only when needed
```

</REQUIRED_HEADERS>
</CODE_STRUCTURE>

<BASE_CLASS_TEMPLATE>

```cpp
ClassName()  ; Initialize class properly
class ClassName {
    __New() {
        this._property := "new-init"  ; Use backing field with underscore
    }

    property {
        set => this._property := value  ; Use arrow syntax for cleaner accessors
        get => this._property
    }

    method(x, y) {
        return x + y
    }
}
```

</BASE_CLASS_TEMPLATE>

<CODE_VALIDATION>
Variables declared
OOP patterns used
Naming conventions
Pure v2 syntax
Ensure all functions have the appropriate amount of parameters
Prefer using class made GUIs instead of functions
Do not use "new" before the class name before initializing it
Initialize the class at the top of the script before the class code

<CRITICAL_WARNING>
NEVER use object literal syntax (e.g., {key: value}) for data storage.
ALWAYS use Map() for key-value data structures:
Curly braces ARE still used for:
Function/method bodies
Class definitions
Control flow blocks
</CRITICAL_WARNING>
</CODE_VALIDATION>
</CORE_REQUIREMENTS>

<CODE_QUALITY_STANDARDS>


<REQUIRED_CODE_HEADER>

```cpp
#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force
#Include Lib/All.ahk
```

</REQUIRED_CODE_HEADER>

<AHK_DATA_STRUCTURES>
<DATA_STORAGE_REQUIREMENTS>
Data Storage Rules:
- ALWAYS use Map() for key-value data structures
- NEVER use object literals (curly brace syntax) for data storage
- Store configuration data in static class Maps
- Use proper class structures for grouping related functionality

<PROPER_DATA_STORAGE>
```cpp
config := Map("width", 800, "height", 600)
```
OR
```cpp
class Config {
    static Settings := Map(
        "key", "value",
        "error", "message"
    )
}
```
</PROPER_DATA_STORAGE>

<IMPROPER_DATA_STORAGE>
```cpp
config := {key: "value", error: "message"}` ; CORRECT
```
OR
```cpp
config := {width: 800, height: 600} ; INCORRECT - will cause issues
```
</IMPROPER_DATA_STORAGE>
<DATA_STORAGE_REQUIREMENTS>

<ERROR_HANDLING_RULES>
NEVER use throw Error() or throw ValueError() directly
AVOID "throw" if you can
ALWAYS encapsulate error messages in static class Maps
Use proper error handling classes and methods
Do not write empty catch statements like " catch {}"

The assistant should validate all generated code against these rules before providing it to the user.
</ERROR_HANDLING_RULES>
</AHK_DATA_STRUCTURES>

<STANDARD_CLASS_EXAMPLE>

```cpp
TooltipTimer()

class TooltipTimer {
    ; Store configuration in static Map
    static Config := Map(
        "interval", 1000,
        "startDelay", 0,
        "initialText", "Timer started",
        "format", "Time elapsed: {1} seconds"
    )

    __New() {
        ; Initialize state Map
        this.state := Map(
            "seconds", 0,
            "isActive", true
        )

        this.timerCallback := this.UpdateDisplay.Bind(this) ; Initialize with proper method binding
        this.Start() ; Start the timer
    }

    Start() {
        ToolTip(TooltipTimer.Config["initialText"])
        SetTimer(this.timerCallback, TooltipTimer.Config["interval"])
    }

    UpdateDisplay() {
        this.state["seconds"]++
        ToolTip(Format(TooltipTimer.Config["format"], this.state["seconds"]))
    }

    __Delete() {
        if this.state["isActive"] {
            SetTimer(this.timerCallback, 0)
            this.state["isActive"] := false
            ToolTip()  ; Clear the tooltip
        }
    }
}
```

</STANDARD_CLASS_EXAMPLE>

GUI class:

<GUI_CLASS_EXAMPLE>

```cpp
SimpleGui()
class SimpleGui {
  __New() {
      this.gui := Gui()
      this.gui.SetFont("s10")
      this.gui.OnEvent("Close", (*) => this.gui.Hide())
      this.gui.OnEvent("Escape", (*) => this.gui.Hide())
      this.gui.AddEdit("vUserInput w200")
      this.gui.AddButton("Default w200", "Submit").OnEvent("Click", this.Submit.Bind(this))
      this.SetupHotkeys()
  }
  Submit(*) {
      saved := this.gui.Submit()
      MsgBox(saved.UserInput)
      this.gui.Hide()
  }
  Toggle(*) {
      if WinExist("ahk_id " this.gui.Hwnd)
          this.gui.Hide()
      else
          this.gui.Show()
  }
  SetupHotkeys() {
      HotKey("^m", this.Toggle.Bind(this))
      HotIfWinExist("ahk_id " this.gui.Hwnd)
      Hotkey("^Escape", this.Toggle.Bind(this), "On")
      HotIfWinExist()
  }
}
```

</GUI_CLASS_EXAMPLE>
</CODE_QUALITY_STANDARDS>

## Special Cases

<GUI_REQUIREMENTS>
Reference "Module_GUI.md" for additional reference

Use modern GUI object-oriented syntax like the GUI class example
Implement proper event handling like in the GUI output example
Only cleanup and optimize the code if you know something is unneeded when asking for help with an error

<GUI_CONTROLS_STANDARDS>


<GUI_CONTROL_METHODS>
AddText()
AddEdit()
AddButton()
AddListBox()
AddDropDownList()
AddComboBox()
AddListView()
AddTreeView()
AddPicture()
AddGroupBox()
AddTab3()
AddProgress()
AddUpDown()
AddHotkey()
AddMonthCal()
AddLink()
</GUI_CONTROL_METHODS>

Layout is controlled through options like:

- x, y coordinates
- w, h dimensions
- x+n, y+n relative positioning
</GUI_REQUIREMENTS>

<OBJECT_ORIENTED_PRINCICPLES>

<MAP_REQUIREMENTS>
Grabbing Keys and Values from a Map

Example 1:
<MAP_EXAMPLE>

```cpp
; 1. Define method to get keys from Map
Map.Prototype.DefineProp("Keys", { Call: get_keys })

; 2. Create Maps with proper variable names
myMap := Map("Key1", "Value1", "Key2", "Value2")

; 3. Access Map keys consistently with your Map variable name
myKeys := myMap.Keys() ; ["Key1", "Key2"]

; Implementation of get_keys helper function
get_keys(mp) {
    mapKeys := []
    for k, v in mp {
        if IsSet(k) && (k is string || k is number)
            mapKeys.Push(k)
    }
    return mapKeys
}
```

</MAP_EXAMPLE>

Key points:
| Rule | Why |
|------|-----|
| Match variable names | Prevents "might not have member" errors |
| Check IsSet() | Validates key existence |
| Type check keys | Ensures valid key types |
</MAP_REQUIREMENTS>

</OBJECT_ORIENTED_PRINCICPLES>

## Key Concepts and Syntax

### Basic Usage:

Creating, accessing, and modifying properties and methods.
Syntax examples for arrays, maps, and object literals.
Demonstrate how to create and manipulate these objects using concise code snippets.

<AHK_DATA_STRUCTURES>

  <MULTI-DIMENSIONAL_ARRAY>
    <!-- An array whose elements can themselves be arrays -->
    <MULTI-DIMENSIONAL_ARRAY_EXAMPLE>

```cpp
app := MyApp()
app.AddUser("John")
app.AddUser("Doe")
app.ShowUsers()

class MyApp {
    static Version := "1.0"
    Users := []

    AddUser(name) {
        this.Users.Push({ Name: name, LoginTime: A_Now })
    }

    ShowUsers() {
        for index, user in this.Users
            MsgBox "User " index ": " user.Name " logged in at " user.LoginTime
    }
}
```
    </MULTI-DIMENSIONAL_ARRAY_EXAMPLE>
  </MULTI-DIMENSIONAL_ARRAY>

  <PROPERTY_STORE>
    <!-- Use Map() for named properties; avoid object literals for storage -->
    <PROPERTY_STORE_EXAMPLE>
      <!-- Incorrect: object literal -->
      <INCORRECT>

```cpp
box := {
   width: 57,
   length: 70,
   height: 12
}
box.width += 1
```
      </INCORRECT>
      <!-- Correct: Map-based -->
      <CORRECT>

```cpp
box := Map(
    "width",  57,
    "length", 70,
    "height", 12
)
box["width"] += 1
MsgBox box["width"]
```
      </CORRECT>
    </PROPERTY_STORE_EXAMPLE>
  </PROPERTY_STORE>

  <ARRAY_REQUIREMENTS>
    <!-- Ordered list, 1‑based index -->
    <DESCRIPTION>
      Arrays store lists of items. Index starts at 1.
    </DESCRIPTION>
    <EXAMPLE>
```cpp
fruits := [
   "apple",
   "banana",
   "orange"
]
```
    </EXAMPLE>
  </ARRAY_REQUIREMENTS>

  <MAP_REQUIREMENTS>
    <!-- Unordered key→value pairs -->
    <DESCRIPTION>
      Maps store values under text or numeric keys.
    </DESCRIPTION>
    <EXAMPLE>

```cpp
fruits := Map(
   "apple",  "A sweet, crisp fruit.",
   "banana", "A curved yellow fruit.",
   "orange", "A citrus fruit with tough rind."
)
```
    </EXAMPLE>
  </MAP_REQUIREMENTS>

  <FUNCTION_CLASS_SYSTEM>
    <FUNCTION_CLASS_SYSTEM_EXPLANATION>
      <!-- Core ideas about functions and classes -->
      <![CDATA[
– Functions can be traditional, arrow (=>), or stored in objects. 
– Do not use arrow or dynamic functions when generating code.
– Classes use __New() as constructor.
– Static members belong to the class; instance members to each object.
      ]]>
    </FUNCTION_CLASS_SYSTEM_EXPLANATION>
    <FUNCTION_CLASS_SYSTEM_EXAMPLE>
```cpp
#Requires AutoHotkey v2
#SingleInstance Force

; Traditional function
MyFunction() {
    MsgBox "Called Traditional Function"
}

; Arrow function
callback := () => MsgBox("Called Arrow Function")

; Function in an object
obj := { method: (a, b) => a + b }

; Example class
class Example {
    static config := "default"
    data := ""

    __New() {
        this.data := "instance"
        MyFunction()
        callback()
        result := obj.method(2, 3)
        MsgBox "Result: " result
    }
}

instance := Example()
```
    </FUNCTION_CLASS_SYSTEM_EXAMPLE>
    <KEY_POINTS>
      <!-- Quick bullet list -->
      – First‑class functions: store and pass around.<br/>
      – __New() runs once per instance.<br/>
      – Static vs instance: accessed by ClassName vs this.
    </KEY_POINTS>
  </FUNCTION_CLASS_SYSTEM>

  <METHOD_CONTEXT>
    <!-- How methods work -->
    <![CDATA[
– Methods get `this` automatically.<br/>
– `this` is the calling instance.<br/>
– Static methods use the class name.
    ]]>
  </METHOD_CONTEXT>

  <OBJECT_PROTOTYPING>
    <!-- Inheritance via `base` -->
    <DESCRIPTION>
      Child classes inherit from Parent using `extends`.
    </DESCRIPTION>
    <EXAMPLE>
```cpp
class Child extends Parent {
    ; This links base internally
}
```
    </EXAMPLE>
  </OBJECT_PROTOTYPING>

  <METHOD_CALLS>
    <!-- Rules for calling methods -->
    <DESCRIPTION>
      Always use dot syntax. Bind event handlers to `this`.
    </DESCRIPTION>
    <TYPES>
      <INSTANCE>object.Method()</INSTANCE>
      <STATIC>ClassName.Method()</STATIC>
      <CHAINED>object.Method1().Method2()</CHAINED>
      <EVENT>control.OnEvent("Event", this.Handler.Bind(this))</EVENT>
    </TYPES>
    <RULES>
      <![CDATA[
– Use .Bind(this) for event callbacks.<br/>
– Avoid inline anonymous callbacks when reuse is needed.<br/>
– Implement __Call() to catch undefined methods.
      ]]>
    </RULES>
    <CODE_EXAMPLE>

```cpp
MenuSystem()
class MenuSystem {
    static Name := "MenuSystem"

    __New() {
        this.SetupMenus()
    }

    SetupMenus() {
        MsgBox "Menus initialized"
    }

    __Call(methodName, args*) {
        MsgBox "Error: Method '" methodName "' not found in " MenuSystem.Name
    }
}
```
    </CODE_EXAMPLE>
  </METHOD_CALLS>

</AHK_DATA_STRUCTURES>

<PATTERN_RULE>
Always use dot syntax for methods: `object.Method()`
Use for static methods: `Class.Method()`
Always bind callbacks to this: `control.OnEvent(..., handler.Bind(this))`	
Implement to catch typos or undefined methods: `__Call()`
Do not use	Bracket notation or ()-less calls for methods
</PATTERN_RULE>

<LINTING_SAFETY>
If a method is not defined, LLM should either:
Suggest defining the method
Or implement a __Call() block that logs the missing method
Never assume a method exists unless declared
Never bind an event handler without checking that the target method is implemented
</LINTING_SAFETY>

</METHOD_CALLS>