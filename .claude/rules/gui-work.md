---
paths:
  - "Lib/*GUI*.ahk"
  - "Lib/*Dark*.ahk"
  - "Lib/GuiEnhancerKit.ahk"
  - "Lib/GuiReSizer.ahk"
  - "Lib/GuiLayoutHelpers.ahk"
  - "GuiTesting/**/*.ahk"
  - "QuickTodo/*Gui*.ahk"
  - "QuickTodo/*Dialog*.ahk"
---

# GUI Rules

- Use `DarkGui()` from `DarkModeModular.ahk` for dark-themed windows.
- Mathematical positioning: explicit x, y, w, h on every control. No implicit stacking.
- `OnSize` must reposition ALL controls with absolute coordinates derived from width/height params.
- Clamp minimum dimensions so controls never collapse to zero.
- `+Accent` on primary action buttons for blue accent.
- Single-line event: `ctrl.OnEvent("Click", (*) => this.DoThing())` is fine.
- Multi-line event: extract to `this.OnClick.Bind(this)`. Never inline blocks.
