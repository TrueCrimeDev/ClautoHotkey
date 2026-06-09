---
name: ahk-gui-gen
description: >
  Generate a complete AHK v2 GUI from a natural language description.
  Creates class-based, mathematically positioned GUIs with proper event binding.
  TRIGGER when: user says "generate a GUI", "build me a window", "create a dialog",
  "make a form", "design a settings panel", "build a tool with UI".
---

# AHK v2 GUI Generator

Generate complete, production-quality GUIs from natural language descriptions.

## Before Generating

1. **Invoke** `/ahk-gui` skill to load GUI module knowledge
2. **Read** `Modules/Module_GUI.md` for patterns
3. **Read** `Modules/Supplemental/Module_GUI_Layout.md` for positioning rules

## Generation Workflow

1. **Parse** the natural language description
2. **Identify** required controls (buttons, edits, lists, dropdowns, etc.)
3. **Plan** the layout mathematically (compute all positions)
4. **Generate** a complete class-based GUI
5. **Validate** with `check /Diag=json`
6. **Run** briefly to capture a screenshot (optional)

## GUI Template

```autohotkey
#Requires AutoHotkey v2.0
#SingleInstance Force

class <AppName> {
    static margin := 10
    static spacing := 10

    __New() {
        this.gui := Gui("+Resize", "<Window Title>")
        this.gui.BackColor := "0x1a1a2e"
        this.gui.SetFont("s10 c0xe0e0e0", "Segoe UI")
        this.BuildControls()
        this.gui.OnEvent("Close", (*) => ExitApp())
        this.gui.OnEvent("Size", this.OnSize.Bind(this))
        this.gui.Show("w<width> h<height>")
    }

    BuildControls() {
        m := <AppName>.margin
        s := <AppName>.spacing
        w := <width> - m * 2
        currentY := m

        ; === Controls with mathematical positioning ===
        this.gui.AddText("x" . m . " y" . currentY . " w" . w . " h25", "Label")
        currentY += 25 + s

        this.editCtrl := this.gui.AddEdit("x" . m . " y" . currentY . " w" . w . " h100")
        currentY += 100 + s

        btnW := 100
        btnX := <width> - m - btnW
        this.gui.AddButton("x" . btnX . " y" . currentY . " w" . btnW . " h30", "OK")
            .OnEvent("Click", this.OnOK.Bind(this))
    }

    OnSize(guiObj, minMax, width, height) {
        if minMax = -1
            return
        ; Reposition ALL controls based on new dimensions
    }

    OnOK(*) {
        ; Handle button click
    }

    __Delete() {
        if this.HasProp("gui") && this.gui
            this.gui.Destroy()
    }
}

<AppName>()
```

## Checklist

- [ ] All controls use computed positions (no hard-coded Y)
- [ ] `currentY += height + spacing` after every control
- [ ] All event handlers use `.Bind(this)`
- [ ] Class encapsulates all GUI logic
- [ ] `__Delete()` cleans up the GUI
- [ ] OnSize handler repositions ALL controls
- [ ] Dark mode colors applied if requested
- [ ] `#Requires` and `#SingleInstance` at top
- [ ] Class instantiated at bottom: `<AppName>()`
