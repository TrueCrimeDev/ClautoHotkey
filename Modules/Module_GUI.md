<GUI_KNOWLEDGE>
This is reference knowledge for AHK v2 GUI's. Please use this information when making a GUI.

<CRITICAL_WARNING>
NEVER use object literal syntax (e.g., {key: value}) for data storage.
ALWAYS use Map() for key-value data structures:
config := Map("width", 800, "height", 600) ;// CORRECT
config := {width: 800, height: 600} ;// INCORRECT - will cause issues
Curly braces ARE still used for:
Function/method bodies
Class definitions
Control flow blocks
</CRITICAL_WARNING>

## GUI Controls Standards
Valid GUI control methods:
| Control Type | Method Name       | Valid Parameters  |
| ------------ | ----------------- | ----------------- |
| Text         | AddText()         | text, options     |
| Edit         | AddEdit()         | options, text     |
| Button       | AddButton()       | options, text     |
| ListBox      | AddListBox()      | options, items    |
| DropDownList | AddDropDownList() | options, items    |
| ComboBox     | AddComboBox()     | options, items    |
| ListView     | AddListView()     | options, titles   |
| TreeView     | AddTreeView()     | options           |
| Picture      | AddPicture()      | options, filename |
| GroupBox     | AddGroupBox()     | options, text     |
| Tab3         | AddTab3()         | options, titles   |
| Progress     | AddProgress()     | options, value    |
| UpDown       | AddUpDown()       | options, value    |
| Hotkey       | AddHotkey()       | options           |
| MonthCal     | AddMonthCal()     | options           |
| Link         | AddLink()         | options, text     |
\*items can be array or comma-separated string
## Global Options Validation
All controls accept these standard options:
| Option | Format     | Example      | Description   |
| ------ | ---------- | ------------ | ------------- |
| x/y    | xn or x+n  | x100 or x+10 | Position      |
| w/h    | wn or w+n  | w200 or w+20 | Size          |
| v      | vVarName   | vMyControl   | Variable name |
| t      | tTabNumber | t2           | Tab number    |
| g      | gLabel     | gMyLabel     | Legacy event  |
## Control-Specific Options
## Edit
ReadOnly
Password
Multi
WantReturn
WantTab
Center
## Button
Default
Wrap
## ListBox/DDL/ComboBox
Sort
Multi (ListBox only)
ReadOnly
Choose[n]
## ListView
Grid
NoSortHdr
NoSort
Multi
ReadOnly
## Progress
Background
Smooth
Range0-n
## Size/Position Rules
Absolute: x100 y200
Relative: x+10 y+20
Previous: xp yp
Width/Height: wp hp
Section: xs ys
## Variable Naming Rules
Must:
Start with letter
Contain only A-Z, 0-9, \_
No spaces
Case sensitive
## Event Binding Rules
Prefer:
```cpp
control.OnEvent("EventName", Callback)
```
Over:
```cpp
gLabel option
```
## Code Style Validation
Initialize gui with capitalized Gui()
Chain control methods
Use := for assignments
Store controls in properties
Bind callbacks with .Bind(this)
Use descriptive variable names
GUI Event Model Structure
```cpp
class AdvancedGui {
    __New() {
        this.gui := Gui()

        this.gui.OnEvent("Close", this.GuiClose.Bind(this))
        this.gui.OnEvent("Escape", this.GuiEscape.Bind(this))
        this.controls := Map() 
    }

    GuiClose(*) => this.gui.Hide()
    GuiEscape(*) => this.gui.Hide()
}
```
Control Management Pattern
```cpp
class AdvancedGui {
    AddControls() {

        this.controls["input"] := this.gui.AddEdit("w200")
        this.controls["submit"] := this.gui.AddButton("Default", "Submit")
            .OnEvent("Click", this.Submit.Bind(this))
    }

    Submit(*) {
        value := this.controls["input"].Value
    }
}
```
State Management
```cpp
class AdvancedGui {
static DEFAULT_STATE := Map(
    "width", 800,
    "height", 600,
    "title", "Advanced GUI"
)
    __New() {
        this.state := this.DEFAULT_STATE.Clone()
        this.gui := Gui("+Resize", this.state.title)
        this.gui.OnEvent("Size", this.HandleResize.Bind(this))
    }
    HandleResize(thisGui, minMax, width, height) {
        this.state.width := width
        this.state.height := height
        this.UpdateLayout()
    }
}
```
Code Organization Pattern
```cpp
class GuiName {
    __New() {
        this.InitializeGui()
        this.SetupControls()
        this.SetupEvents()
    }
    InitializeGui() {
        this.gui := Gui()
    }
    SetupControls() {
        this.controls := Map()
    }
    SetupEvents() {
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
    }
}
```
List GUI Actions
```cpp
ItemList := ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5"]
Loop
{
    item := "You selected " OpenListSelectionGui(ItemList, "Select an Item")
    info := "Do you want to continue the tests?"
    test := MsgBox(item "`n`n" info, "AutoHotkey v2 GUI Testing", "OKCancel")
    if (test == "Cancel")
        ExitApp
}
OpenListSelectionGui(pList, pGuiTitle)
{
    SelectedValue := ""
    ListGui := Gui("ToolWindow", pGuiTitle)
    ListGui.OnEvent("Close", Gui_Close)
    ListCtrl := ListGui.AddListBox("Choose1 r5", pList)
    ListGui.AddButton("Default", "Select").OnEvent("Click", Gui_Close)
    ListGui.Show()
    While (!SelectedValue)
    {
        Sleep 222
    }
    Return SelectedValue
    Gui_Close(*)
    {
        SelectedValue := ListCtrl.Text
        ListGui.Destroy
    }
}
```
## Code Structure Requirements

Use .Bind(this) for all event handlers
Store control references for easy access
Manage state independently of GUI
Handle window events properly
Use proper scoping with this
Use event-driven architecture
The most critical aspect is maintaining proper object scope and event binding while keeping the code organized and maintainable.

## 5. Advanced GUI Patterns

Enhance the GUI section with modern design patterns:

<ADVANCED_GUI_PATTERNS>


Model-View-Controller Pattern for AHK GUIs


```cpp
MVCExampleApp()
class MVCExampleApp {
__New() {
this.model := MVCModel()
Copy    
    this.view := MVCView()

    this.controller := MVCController(this.model, this.view)

    this.view.Show()
}
}
```


```cpp
class MVCModel {
__New() {
this.data := Map("count", 0)
}
CopyIncrementCount() {
    this.data["count"]++
    return this.data["count"]
}
GetCount() {
    return this.data["count"]
}
}
```

```cpp
class MVCView {
__New() {
this.gui := Gui("+Resize", "MVC Example")
this.gui.SetFont("s10")
this.counterText := this.gui.AddText("w200 h30", "Count: 0")
this.incrementButton := this.gui.AddButton("w200", "Increment")
    this.onIncrementHandler := ""
}
UpdateCounter(count) {
    this.counterText.Value := "Count: " count
}
SetIncrementHandler(handler) {
    this.onIncrementHandler := handler
    this.incrementButton.OnEvent("Click", this.onIncrementHandler)
}
Show() {
    this.gui.Show()
}
}
```

```cpp
class MVCController {
__New(model, view) {
this.model := model
this.view := view
Copy    
    this.view.SetIncrementHandler(this.HandleIncrement.Bind(this))
}
HandleIncrement(*) {

    newCount := this.model.IncrementCount()

    this.view.UpdateCounter(newCount)
}
}
```
</ADVANCED_GUI_PATTERNS>
</GUI_KNOWLEDGE>
