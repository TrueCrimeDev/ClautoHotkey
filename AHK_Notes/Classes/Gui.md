# Topic: Gui Class in AutoHotkey

## Category
Class

## Overview
The Gui class in AutoHotkey provides a comprehensive way to create and manage graphical user interfaces. It allows for creating windows with various controls like buttons, text fields, list boxes, and more, enabling the development of sophisticated visual applications.

## Key Points
- The Gui class creates window objects that can contain multiple controls
- Events like button clicks can trigger callbacks or methods
- Controls are added using methods like .Add()
- Multiple GUI windows can be created independently

## Syntax and Parameters
```cpp
; Creating a GUI
MyGui := Gui([Options, Title])

; Adding controls
Control := MyGui.Add(ControlType, Options, Text)

; Showing the GUI
MyGui.Show([Options, Title])

; Handling events
ButtonOK := MyGui.Add("Button", "Default", "OK")
ButtonOK.OnEvent("Click", OnOKClick)

OnOKClick(GuiCtrlObj, Info) {
    ; Handle button click
}
```

## Code Examples
```cpp
; Create a simple form
MyGui := Gui(, "My Application")

; Add text and input controls
MyGui.Add("Text",, "Enter your name:")
EditName := MyGui.Add("Edit", "w200")

MyGui.Add("Text",, "Select your age:")
ComboAge := MyGui.Add("ComboBox", "w200", "18|25|30|40|50|60+")

; Add buttons
ButtonOK := MyGui.Add("Button", "Default w100", "OK")
ButtonCancel := MyGui.Add("Button", "x+10 w100", "Cancel")

; Set up event handlers
ButtonOK.OnEvent("Click", OnOKClick)
ButtonCancel.OnEvent("Click", OnCancelClick)

; Show the GUI
MyGui.Show()

; Event handlers
OnOKClick(*)
{
    global EditName, ComboAge, MyGui
    name := EditName.Value
    age := ComboAge.Value
    MsgBox("Hello, " name "! You are " age " years old.")
    MyGui.Destroy()
}

OnCancelClick(*)
{
    global MyGui
    MyGui.Destroy()
}
```

## Implementation Notes
- Gui is exclusive to AutoHotkey v2; v1 uses a different syntax
- Controls need to be stored in variables if you want to access their properties later
- Use proper layouts (x, y coordinates or x/y+/- relative positioning) for controls
- Event-driven programming is the recommended approach for GUI applications
- Destroy GUI objects when they're no longer needed to free resources
- The "Opt" method can be used to modify controls after creation

## Related AHK Concepts
- Events and Callbacks
- Control Types and Options
- GUI Styles and Themes
- Message Boxes and Dialogs
- ListViews and TreeViews

## Tags
#AutoHotkey #OOP #GUI #Controls #UserInterface #WindowManagement
