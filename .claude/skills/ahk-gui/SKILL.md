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

`Lib/DarkModeModular_Alpha.ahk` ships its own showcase — `class DarkModeShowcase`
at line 6851, guarded by `if A_LineFile = A_ScriptFullPath` so it runs only when
the library is executed directly:

```bash
"$AHK_EXE" "C:\Scripts\Lib\DarkModeModular_Alpha.ahk"
```

Read that class before writing a new GUI. It is the canonical shape of a GUI in
this project — `__New` → `BuildMenuBar` → `BuildLayout` → `BindEvents` → `Show`,
controls held in a `Map()`, every handler `.Bind(this)`, palette changes routed
through `DarkTheme.OnThemeChanged`. Match it rather than inventing a structure.

The library header (lines 1–33) is the API summary: `DarkGui`, `DarkTheme`,
`DarkTitleBar`, `DarkMenu`, `DarkMenuBar`, `DarkScrollbar`, `DarkToolTip`.
Controls added via `DarkGui.Add()` are dark-styled automatically; `+Accent` on a
primary button gets the blue accent.

`DarkModeModular_Alpha.ahk` is canonical for alpha.30 work (role swap
2026-08-14: it absorbed the Fable revision). Classic `DarkModeModular.ahk` is
for alpha.17–.28 scripts, `_Fable.ahk` is a compatibility shim including
`_Alpha`, `_Fable_Gdip.ahk` an A/B experiment — not canonical.

## Deeper knowledge modules

Read when the showcase doesn't cover what you need:

1. `Modules/Module_GUI.md` — the whole GUI domain: constructor, control types, event binding,
   the Positioning Options table, `gForm()`, dependency injection, the form-field component system and
   field validation. (Absorbed the former `Module_GUI_Extensive.md` on 2026-08-26; `Module_GUI_Layout.md`
   was an agent-steering prompt and moved to `legacy/System_Prompts/`.)

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
