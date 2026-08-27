---
name: ahk-gui
description: >
  Load AHK v2 GUI knowledge for window creation, layout, controls, events, and dark mode.
  Use when creating or modifying GUIs, positioning controls, handling events, or applying themes.
  TRIGGER when: user mentions gui, window, dialog, control, layout, button, ListView, ComboBox,
  dark mode, OnEvent, OnSize, positioning, resize, menu, toolbar, tab, checkbox, radio, edit, text,
  statusbar, form, modal, popup, theme, style, color.
  Examples: "create a GUI", "add a button", "fix overlapping controls", "dark mode window", "resize handler"
---

# AHK v2 GUI Knowledge Skill

## Start with the working reference

`${CLAUDE_PLUGIN_ROOT}/Lib/_Dark.ahk` is the bundled dark-mode library and its own
worked example — `class EnhancedDarkApp` at the top of the file shows the canonical
shape of a GUI in this project:

```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/_harness-env.sh"
"$AHK_BIN_WSL" "$(wslpath -w "${CLAUDE_PLUGIN_ROOT}/Lib/_Dark.ahk")"
```

Read it before writing a new GUI: `__New` → `InitializeGui` → `SetupControls` →
`Show`, controls held in a `Map()`, every handler bound with `.Bind(this)`. Match that
structure rather than inventing one.

Usage is wrap-then-add — build a normal `Gui()`, wrap it, then add controls through
the wrapper so they are themed on creation:

```ahk
myGui := Gui()
dm := _Dark(myGui)                    ; dark title bar, background, menus
dm.AddDarkButton("w120", "Save")
dm.AddDarkEdit("w200")
dm.AddDarkComboBox("w200", ["One", "Two"])
```

For a fuller control set — themed ListView, TreeView, tabs, DatePicker, MonthCal and
theme presets — see the standalone [DarkMode](https://github.com/TrueCrimeDev/DarkMode)
library, which is not bundled here.

## Deeper knowledge modules

Read when the showcase doesn't cover what you need:

1. `${CLAUDE_PLUGIN_ROOT}/Modules/Module_GUI.md` — the whole GUI domain: constructor, control types, event binding,
   the Positioning Options table, `gForm()`, dependency injection, the form-field component system and
   field validation. (Absorbed the former `Module_GUI_Extensive.md`.)

## Positioning — the one convention that isn't inferable

Controls get computed absolute coordinates, never implicit stacking. Unmanaged
chaining accumulates drift and produces overlaps that surface only on resize.

```ahk
margin := 10, spacing := 10, currentY := margin, windowWidth := 650
; after every control:
currentY += controlHeight + spacing
; side-by-side:
leftW := (windowWidth - margin * 2 - gap) / 2
```

`OnSize` must reposition **every** control from the width/height params — a
handler that moves only some of them is the most common GUI bug in this
codebase. Clamp minimum dimensions so nothing collapses to zero.

## Control gotchas

- `+0x200` on a Text control is `SS_CENTERIMAGE` — vertical centering.
- `AddUpDown("Range1-5000", initial)` attaches to the **preceding** Edit control.
- `lv.Modify(row, "", col1, ..., colN)` updates a ListView row in place.

General v2 syntax — `.Bind(this)`, `Map()`, `Gui()` instantiation, class
encapsulation — is covered by the auto-loading `ahk-v2-syntax.md` rule, already
in context whenever you edit an `.ahk` file.
