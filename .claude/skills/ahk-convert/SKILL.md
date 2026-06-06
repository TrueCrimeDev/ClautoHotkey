---
name: ahk-convert
description: >
  Convert AHK v1 code to AHK v2. Applies comprehensive v1-to-v2 conversion rules
  including command syntax, expression changes, GUI rewrites, and object model updates.
  TRIGGER when: user says "convert to v2", "v1 to v2", "upgrade script", "migrate from v1",
  "convert this old script", "make this v2".
---

# AHK v1 → v2 Converter

Convert AutoHotkey v1 code to v2 syntax.

## Usage

`/ahk-convert <code_or_file>` — converts v1 code to v2.

## Conversion Rules

Apply these transformations in order:

### Commands → Functions

```diff
- MsgBox, Hello World
+ MsgBox("Hello World")

- MsgBox, 4, Title, Text
+ result := MsgBox("Text", "Title", 4)

- InputBox, output, Title, Prompt
+ output := InputBox("Prompt", "Title")

- FileRead, content, file.txt
+ content := FileRead("file.txt")

- FileAppend, text, file.txt
+ FileAppend("text", "file.txt")

- Run, notepad.exe
+ Run("notepad.exe")

- Sleep, 1000
+ Sleep(1000)

- SetTimer, Label, 1000
+ SetTimer(Label, 1000)

- IfExist, file.txt
+ if FileExist("file.txt")

- StringReplace, output, input, old, new, All
+ output := StrReplace(input, "old", "new")

- StringLeft, output, input, 5
+ output := SubStr(input, 1, 5)

- StringMid, output, input, 3, 5
+ output := SubStr(input, 3, 5)

- StringLen, length, input
+ length := StrLen(input)
```

### Variables and Expressions

```diff
- x = literal string
+ x := "literal string"

- x := %varName%
+ x := %varName%  ; (dynamic ref — use variable directly)

- if (x = "text")     ; case-insensitive
+ if (x = "text")     ; still case-insensitive in v2

- if x between 1 and 10
+ if (x >= 1 && x <= 10)

- Transform, output, HTML, %input%
+ ; No direct equivalent, use StrReplace chain
```

### GUI (Major Rewrite)

```diff
- Gui, Add, Text,, Hello
- Gui, Add, Edit, vMyEdit w200
- Gui, Add, Button, gBtnClick, OK
- Gui, Show, w300 h200, My Window
+ myGui := Gui(, "My Window")
+ myGui.AddText(, "Hello")
+ myGui.AddEdit("w200 vMyEdit")
+ myGui.AddButton(, "OK").OnEvent("Click", BtnClick)
+ myGui.Show("w300 h200")

- Gui, Submit
+ saved := myGui.Submit()

- GuiControl,, MyEdit, new text
+ myGui["MyEdit"].Value := "new text"
```

### Objects

```diff
- obj := new MyClass()
+ obj := MyClass()

- obj := ComObjCreate("Excel.Application")
+ obj := ComObject("Excel.Application")

- obj := {key: "value"}         ; as data store
+ obj := Map("key", "value")    ; use Map for data

- for key, val in obj
+ for key, val in obj            ; same syntax but Map uses different iteration
```

### Loop Changes

```diff
- Loop, Parse, text, `,
+ Loop Parse, text, ","

- Loop, Read, file.txt
+ Loop Read, "file.txt"

- Loop, Files, *.txt
+ Loop Files, "*.txt"

- Loop, 10
+ Loop 10
```

### Hotkeys and Directives

```diff
- #IfWinActive, ahk_exe notepad.exe
+ #HotIf WinActive("ahk_exe notepad.exe")

- #IfWinActive
+ #HotIf

- Hotkey, ^a, MyLabel
+ Hotkey("^a", MyFunc)
```

### Error Handling

```diff
- try
-     something()
- catch e
-     MsgBox % e.Message
+ try
+     something()
+ catch as e
+     MsgBox(e.Message)
```

## Workflow

1. **Detect** v1 patterns in the input
2. **Apply** all conversion rules
3. **Add** `#Requires AutoHotkey v2.0` at top
4. **Add** `#SingleInstance Force` if not present
5. **Validate** with `check /Diag=json`
6. **Report** conversion summary: "Converted N patterns across M lines"

## Rules

- Always add `#Requires AutoHotkey v2.0` to converted output
- Validate converted code with `check` before returning
- Preserve comments and formatting where possible
- Flag any patterns that need manual review (e.g., OnMessage, DllCall signatures)
- Wrap class-based GUIs if the original used multiple Gui commands
