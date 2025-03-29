# Test Prompts

These are the test prompts I've used to evaluate the peformance of my AHK v2 coding agents. Feel free to add or suggest any tests or expected results should be. I am looking for lots of input to help create the most pristine desired responses to help train the models.  


## Create a GUI Clipboard manager

Prompt:
```md
Create a clipboard text editor that:
Opens the GUI when the script starts
Shows the clipboard contents when the GUI opens in an edit box
Create three buttons to change the case and format of the code
Save the newly edited version to the users clipboard
```

Desired Result:
```cpp
#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

ClipboardManager()

class ClipboardManager {
    __New() {
        this.gui := Gui("+Resize", "Clipboard Manager")
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        
        this.editor := this.gui.AddEdit("vContent w400 h300 Multi")
        this.editor.Value := A_Clipboard
        
        this.gui.AddButton("w100", "UPPERCASE").OnEvent("Click", this.ConvertCase.Bind(this, "upper"))
        this.gui.AddButton("w100 x+5", "lowercase").OnEvent("Click", this.ConvertCase.Bind(this, "lower"))
        this.gui.AddButton("w100 x+5", "Title Case").OnEvent("Click", this.ConvertCase.Bind(this, "title"))
        
        this.gui.Show()
    }
    
    ConvertCase(caseType, *) {
        text := this.editor.Value
        switch caseType {
            case "upper": text := StrUpper(text)
            case "lower": text := StrLower(text)
            case "title": text := StrTitle(text)
        }
        this.editor.Value := text
        A_Clipboard := text
    }
}
```

## Method Testing

Prompt:
```md
What will be the output of obj.method() based on the code below?
```

```cpp
#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

class Base {
    __New(val) {
        this.val := val
    }
    method() {
        return "Base: " . this.val
    }
}

class Derived extends Base {
    __New(val) {
        super.__New(val * 2)
    }
    method() {
        return super.method() . ", Derived: " . this.val
    }
}

obj := Derived(5)
```

Desired Result:

```md
10
```



## Object Testing Timer 

Prompt:

```md
Create an AutoHotkey v2 class called TooltipTimer that:
Shows a persistent tooltip using ObjPtr reference counting
Updates tooltip every 1000ms while managing object lifetime
Handles cleanup properly with __Delete
Uses proper timer binding pattern with .Bind(this)
```

Desired Result: 
```cpp
#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

TooltipTimer()
class TooltipTimer {
    __New() {
        this.Timer := this.Update.Bind(this)
        SetTimer(this.Timer, 1000)
        this.ptr := ObjPtr(this)
        ObjAddRef(this.ptr)
    }
    
    __Delete() {
        SetTimer(this.Timer, 0)
        ObjRelease(this.ptr)
        this.Timer := unset
    }
    
    Update() {
        ToolTip("Updating...")
    }
}
```
