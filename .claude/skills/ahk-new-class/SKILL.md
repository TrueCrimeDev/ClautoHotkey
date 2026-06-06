---
name: ahk-new-class
description: >
  Scaffold a new AHK v2 class with proper structure, constructor, destructor, and property stubs.
  TRIGGER when: user says "new class", "create a class", "scaffold class", "class template",
  "start a new class".
---

# AHK v2 Class Scaffold

Generate a properly structured AHK v2 class skeleton.

## Usage

`/ahk-new-class <ClassName>` — creates `<ClassName>.ahk` with full structure.

Optional arguments:
- `gui` — includes GUI boilerplate with mathematical positioning
- `extends <ParentClass>` — adds inheritance

## Template (Standard)

```autohotkey
#Requires AutoHotkey v2.0
#SingleInstance Force

class <ClassName> {
    __New() {
        this.data := Map()
    }

    __Delete() {
        this.data := ""
    }
}

<ClassName>()
```

## Template (GUI)

```autohotkey
#Requires AutoHotkey v2.0
#SingleInstance Force

class <ClassName> {
    static margin := 10
    static spacing := 10

    __New() {
        this.gui := Gui("+Resize", "<ClassName>")
        this.BuildControls()
        this.gui.OnEvent("Close", (*) => ExitApp())
        this.gui.Show("w500 h400")
    }

    BuildControls() {
        m := <ClassName>.margin
        s := <ClassName>.spacing
        currentY := m
        w := 500 - m * 2
    }

    __Delete() {
        if this.HasProp("gui") && this.gui
            this.gui.Destroy()
    }
}

<ClassName>()
```

## Template (Inheritance)

```autohotkey
#Requires AutoHotkey v2.0

class <ClassName> extends <ParentClass> {
    __New() {
        super.__New()
    }

    __Delete() {
        super.__Delete()
    }
}
```

## After Generating

1. Write file to project root or specified path
2. Validate with `check /Diag=json`
3. Report: "Created `<ClassName>.ahk` — <N> lines"
