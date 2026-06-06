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

When this skill is invoked, load the following module files:

1. **Read** `ClautoHotkey/Modules/Module_GUI.md` — GUI construction, Gui() constructor, control types, event binding, color handling
2. **Read** `ClautoHotkey/Modules/Supplemental/Module_GUI_Layout.md` — Mathematical positioning system, sequential Y-tracking
3. **Read** `ClautoHotkey/Modules/Supplemental/Module_GUI_Extensive.md` — Advanced GUI patterns, complex layouts

## Critical GUI Rules (Always Apply)

```
POSITIONING:      Sequential Y-position tracking — NEVER hard-coded Y values
FORMULA:          nextY := currentY + controlHeight + spacing
SETUP:            margin := 10, spacing := 10, currentY := margin, windowWidth := 650
EVENT HANDLERS:   gui.OnEvent("Close", this.OnClose.Bind(this)) — always .Bind(this)
INSTANTIATION:    myGui := Gui("+Resize", "Title") — object syntax, NOT commands
CONTROLS:         gui.AddText(), gui.AddEdit(), gui.AddButton() — method syntax
SIDE-BY-SIDE:     Calculate widths: leftW := (windowWidth - margin*2 - gap) / 2
ENCAPSULATION:    All GUI code in classes — never bare top-level GUI code
DARK MODE:        Use DllCall for dark title bar, custom colors via gui.BackColor
LISTVIEW:         lv.Modify(row, "", col1..colN) for in-place updates
UPDOWN:           gui.AddUpDown("Range1-5000", initialVal) — attaches to preceding Edit
CENTERING:        +0x200 on Text controls = SS_CENTERIMAGE (vertical centering)
```

## Layout Method Priority

1. **Primary (95% of cases)**: Mathematical `currentY` tracking — pre-calculated, stateless
2. **Secondary (simple cases)**: Manual `xm` reset pattern — AHK relative positioning with discipline
3. **FORBIDDEN**: Unmanaged chaining without resets — causes cumulative drift

## GUI Checklist Before Submitting Code

- [ ] Every control has explicit x, y, w, h values (computed, not hard-coded)
- [ ] `currentY` incremented after every control: `currentY += height + spacing`
- [ ] Side-by-side controls use computed widths and x-offsets
- [ ] All event handlers use `.Bind(this)`
- [ ] OnSize handler repositions ALL controls (not just some)
- [ ] No overlapping controls (mental execution pass)
