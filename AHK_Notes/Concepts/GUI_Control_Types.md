# Topic: GUI Control Types and Options in AutoHotkey v2

## Category

Concept

## Overview

AutoHotkey v2 offers a rich set of GUI controls for creating user interfaces. This reference covers the standard control types, their specific options, and best practices for implementing them in a well-structured, object-oriented manner.

## Key Points

- Each control type has its own Add method (e.g., `AddText()`, `AddButton()`)
- Controls share common options like position (x/y), size (w/h), and variable binding (v)
- Control-specific options provide specialized functionality
- Prefer `.OnEvent()` over legacy g-label options for event handling
- Store controls in properties or Maps for easier access and management

## Syntax and Parameters

```cpp
; Common control syntax
control := gui.AddControlType(options, content)

; Control option format examples
"x100 y50 w200 h30 vMyVar" ; Position, size, and variable
"xp+10 yp w+20" ; Relative positioning
"xs ys" ; Section start
"Choose3" ; Control-specific option
```

## Code Examples

```cpp
class ControlDemoGui {
    __New() {
        this.gui := Gui("+Resize", "Control Types Demo")
        this.controls := Map()
        
        ; Text control - simple label
        this.controls["label"] := this.gui.AddText("x10 y10 w200", "This is a text label")
        
        ; Edit control - single line
        this.controls["edit"] := this.gui.AddEdit("x10 y+10 w200", "Editable text")
        
        ; Multi-line edit with scrollbars
        this.controls["multiEdit"] := this.gui.AddEdit("x10 y+10 w200 h100 Multi WantReturn", "Multi-line`neditable text")
        
        ; Button with default action
        this.controls["button"] := this.gui.AddButton("x10 y+10 w200 Default", "Click Me")
            .OnEvent("Click", this.ButtonClicked.Bind(this))
        
        ; Checkbox
        this.controls["checkbox"] := this.gui.AddCheckbox("x10 y+10 w200", "Enable feature")
            .OnEvent("Click", this.CheckboxToggled.Bind(this))
        
        ; Radio buttons
        this.controls["radio1"] := this.gui.AddRadio("x10 y+10 w200 Group", "Option 1")
        this.controls["radio2"] := this.gui.AddRadio("x10 y+5 w200", "Option 2")
        this.controls["radio3"] := this.gui.AddRadio("x10 y+5 w200", "Option 3")
        
        ; DropDownList
        this.controls["ddl"] := this.gui.AddDropDownList("x10 y+10 w200 Choose1", ["Item 1", "Item 2", "Item 3"])
            .OnEvent("Change", this.ItemSelected.Bind(this))
        
        ; ListBox with multi-select
        this.controls["listBox"] := this.gui.AddListBox("x10 y+10 w200 h100 Multi", ["Option A", "Option B", "Option C", "Option D"])
            .OnEvent("Change", this.ListBoxChanged.Bind(this))
        
        ; ListView
        this.controls["listView"] := this.gui.AddListView("x10 y+10 w400 h100 Grid", ["Column 1", "Column 2", "Column 3"])
        this.controls["listView"].Add(, "Row 1 Col 1", "Row 1 Col 2", "Row 1 Col 3")
        this.controls["listView"].Add(, "Row 2 Col 1", "Row 2 Col 2", "Row 2 Col 3")
        
        ; Progress bar
        this.controls["progress"] := this.gui.AddProgress("x10 y+10 w200 h20 Range0-100", 50)
        
        ; Slider
        this.controls["slider"] := this.gui.AddSlider("x10 y+10 w200 Range0-100 TickInterval10", 50)
            .OnEvent("Change", this.SliderChanged.Bind(this))
        
        ; GroupBox for organizing controls
        this.controls["group"] := this.gui.AddGroupBox("x10 y+20 w200 h100", "Grouped Controls")
        
        ; Controls inside the GroupBox
        this.controls["groupOption1"] := this.gui.AddCheckbox("x20 y+10 w180", "Group Option 1")
        this.controls["groupOption2"] := this.gui.AddCheckbox("x20 y+5 w180", "Group Option 2")
        
        ; Tab controls
        this.controls["tabs"] := this.gui.AddTab3("x10 y+30 w400 h200", ["Tab 1", "Tab 2", "Tab 3"])
        
        ; Controls on Tab 1
        this.controls["tab1Text"] := this.gui.AddText("x20 y+20 w380", "This content is on Tab 1")
        
        ; Switch to Tab 2 for its controls
        this.controls["tabs"].Value := 2
        this.controls["tab2Text"] := this.gui.AddText("x20 yp w380", "This content is on Tab 2")
        
        ; Switch to Tab 3 for its controls
        this.controls["tabs"].Value := 3
        this.controls["tab3Text"] := this.gui.AddText("x20 yp w380", "This content is on Tab 3")
        
        ; Switch back to Tab 1 for initial display
        this.controls["tabs"].Value := 1
        
        ; Show the GUI
        this.gui.Show("w420 h600")
    }
    
    ; Event handlers
    ButtonClicked(*) {
        MsgBox("Button was clicked!")
    }
    
    CheckboxToggled(*) {
        isChecked := this.controls["checkbox"].Value
        MsgBox("Checkbox is now: " (isChecked ? "Checked" : "Unchecked"))
    }
    
    ItemSelected(*) {
        selectedItem := this.controls["ddl"].Text
        MsgBox("Selected item: " selectedItem)
    }
    
    ListBoxChanged(*) {
        selectedItems := this.controls["listBox"].Text
        MsgBox("Selected in ListBox: " selectedItems)
    }
    
    SliderChanged(*) {
        sliderValue := this.controls["slider"].Value
        this.controls["progress"].Value := sliderValue  ; Update progress bar
    }
}

; Create the demo
demoGui := ControlDemoGui()
```

## Implementation Notes

### Common Control Options
- `x/y`: Position - absolute (x100), relative to previous (x+10), or previous position (xp)
- `w/h`: Width/height - absolute (w200) or relative (w+20)
- `v`: Variable name - used in Gui.Submit() to create variables
- `t`: Tab number - indicates which tab the control belongs to
- `g`: Legacy event handler label (prefer OnEvent instead)

### Control-Specific Options

**Edit Control**
- `ReadOnly`: Prevents user from changing content
- `Password`: Masks input characters
- `Multi`: Creates a multi-line edit field
- `WantReturn`: Allows Enter key to create new lines
- `WantTab`: Allows Tab key to insert tab characters
- `Center`: Centers the text horizontally

**Button**
- `Default`: Makes this the default action button (activated by Enter)
- `Wrap`: Wraps text within the button

**ListBox/DropDownList/ComboBox**
- `Sort`: Alphabetically sorts the items
- `Multi` (ListBox only): Allows multiple selections
- `ReadOnly`: Prevents modifying items (ComboBox)
- `Choose[n]`: Pre-selects the nth item

**ListView**
- `Grid`: Shows grid lines between cells
- `NoSortHdr`: Disables header sorting
- `NoSort`: Disables all sorting
- `Multi`: Allows selecting multiple rows
- `ReadOnly`: Prevents editing cell contents

**Progress**
- `Background[color]`: Sets background color
- `Smooth`: Creates a continuous bar without segments
- `Range0-n`: Sets the range (default is 0-100)

## Related AHK Concepts

- GUI Layout and Positioning
- Event Handling
- Object-Oriented GUI Design
- GUI Styling and Themes
- User Input Validation

## Tags

#AutoHotkey #GUI #Controls #OptionsReference #UserInterface #EventHandling #OOP