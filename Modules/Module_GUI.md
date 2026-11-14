---
name: Module_GUI
description: 'GUI construction in AHK v2 — the Gui() object, adding and configuring controls, event
  binding with .Bind(this), ListView and TreeView CRUD, owner/owned modal windows, margin- and
  Section-based positioning, resize handling via OnEvent("Size"), mathematically computed layouts
  (LayoutCalculator, GuiForm, gForm), dependency-injected GUI classes, reusable form-field
  components (FormField, FormBuilder), and rule-based input validation (ValidationRule,
  FieldValidator). TRIGGER when the request involves: Gui(), AddText(), AddEdit(), AddButton(),
  AddListView(), AddTreeView(), AddGroupBox(), Submit(), OnEvent(), .Bind(), GuiForm, "make a window",
  "add a button", "create a form", "gui layout", "position controls", "dialog", "listview rows", "treeview
  nodes", "resizable window", "modal dialog", "currentY", "padding", gForm, FormField, FormBuilder,
  ValidationRule, FieldValidator, "form validation", "validate input", "required field",
  "error message", "reusable component", "dependency injection", "inject a service". Not covered: screen graphics
  (PixelSearch, ImageSearch, screen overlays, GDI+) and WebView2/IE-based browser controls embedded in a
  Gui — use built-in AHK v2 knowledge (no dedicated graphics/screen module yet).'
---

# Module_GUI

## API QUICK-REFERENCE

### Gui Constructor and Window Methods
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `Gui()` | `Gui(options?, title?, eventObj?)` | Constructor — returns Gui object; never use `new Gui()` |
| `.Show()` | `.Show(options?)` | Show window; options: `"w400 h300"`, `"Center"`, `"AutoSize"` |
| `.Hide()` | `.Hide()` | Hide window but keep object alive — preferred over Destroy for toggle patterns |
| `.Destroy()` | `.Destroy()` | Permanently remove window and all controls — object becomes invalid after |
| `.Submit()` | `.Submit(hide := true)` | Collect all v-named control values into an object; hides window by default; pass `false` to suppress hide |
| `.Opt()` | `.Opt(options)` | Apply or remove window options: `"+Resize"`, `"+Disabled"`, `"-Disabled"`, `"+Owner" . hwnd` |
| `.SetFont()` | `.SetFont(options?, fontName?)` | Set font for subsequently added controls: `"s10 bold"`, `"s9 norm"` |
| `.OnEvent()` | `.OnEvent(eventName, callback)` | Bind window-level events: `"Close"`, `"Escape"`, `"Size"` |
| `.Hwnd` | `.Hwnd` | Read-only window handle — use for `+Owner` and `WinExist("ahk_id " gui.Hwnd)` |
| `.MarginX` | `.MarginX := n` | Left/right margin for auto-positioned controls |
| `.MarginY` | `.MarginY := n` | Top/bottom margin for auto-positioned controls |

### Gui Control Add Methods
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `.AddText()` | `.AddText(options?, text?)` | Static label; use `"xm"` to reset left margin |
| `.AddEdit()` | `.AddEdit(options?, text?)` | Single or multi-line text input; `"vName"` binds to Submit() |
| `.AddButton()` | `.AddButton(options?, text?)` | Push button; `"Default"` = Enter key triggers it |
| `.AddCheckBox()` | `.AddCheckBox(options?, text?)` | Checkbox; `.Value` = 1/0; `"vName"` for Submit() |
| `.AddRadio()` | `.AddRadio(options?, text?)` | Radio button; first in group starts new group |
| `.AddListBox()` | `.AddListBox(options?, items?)` | Single/multi-select listbox |
| `.AddDropDownList()` | `.AddDropDownList(options?, items?)` | Dropdown; items passed as Array |
| `.AddComboBox()` | `.AddComboBox(options?, items?)` | Editable dropdown |
| `.AddSlider()` | `.AddSlider(options?)` | Slider; `.Value` = current position |
| `.AddListView()` | `.AddListView(options?, columns?)` | Multi-column list; columns = Array of strings |
| `.AddTreeView()` | `.AddTreeView(options?)` | Hierarchical tree |
| `.AddGroupBox()` | `.AddGroupBox(options?, text?)` | Visual grouping box; inner controls need `innerX/innerY` offsets |
| `.AddTab3()` | `.AddTab3(options?, tabNames?)` | Tabbed panel; tabNames = Array |
| `.AddPicture()` | `.AddPicture(options?, filename?)` | Image control |
| `.AddStatusBar()` | `.AddStatusBar(options?, text?)` | Bottom status bar |
| `.AddProgress()` | `.AddProgress(options?)` | Progress bar |
| `.AddHotkey()` | `.AddHotkey(options?, default?)` | Hotkey input control |

### Positioning Options (option-string prefixes accepted by every `Add*` method)
| Option | Meaning |
|--------|---------|
| `x`/`y` | Absolute client-area coordinate |
| `x+n` / `y+n` | Offset from the previous control's right edge / bottom edge |
| `xp` / `yp` | Reuse the previous control's x / y (`xp+n` offsets from it) |
| `xm` / `ym` | Return to the window's left / top margin (`MarginX` / `MarginY`) |
| `xs` / `ys` | Return to the x / y saved by the last control carrying `Section`; a bare `ys` starts a new column to the right of the section |
| `Section` | Mark this control as the anchor that later `xs`/`ys` return to |
| `wp` / `hp` | Reuse the previous control's width / height (`wp-20` adjusts from it) |

Default flow with no positioning option: the control is placed **below** the previous one at the same x. There is no rightward accumulation.

### Control Object Methods and Properties
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `.OnEvent()` | `.OnEvent(eventName, callback)` | Bind control-level events: `"Click"`, `"Change"`, `"DoubleClick"`, `"ItemSelect"` |
| `.Value` | `.Value` | Get or set control's current value; type varies by control |
| `.Opt()` | `.Opt(options)` | Add/remove options on existing control: `"+Disabled"`, `"-Visible"` |
| `.Move()` | `.Move(x?, y?, w?, h?)` | Reposition/resize control; **omit** a parameter (`ctrl.Move(, , w)`) to leave that axis unchanged — passing `""` throws TypeError ("requires a Number, but received an empty string") |
| `.Enabled` | `.Enabled := true/false` | Enable/disable control |
| `.Visible` | `.Visible := true/false` | Show/hide control without removing it |

### ListView Control Methods
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `lv.Add()` | `.Add(options?, col1?, col2?, ...)` | Add row; returns 1-based row number; `""` for no options |
| `lv.Delete()` | `.Delete(rowNum?)` | Delete specific row (1-based) or all rows if no arg |
| `lv.Modify()` | `.Modify(rowNum, options?, col1?, col2?, ...)` | Edit row text or options; `""` options to change text only |
| `lv.ModifyCol()` | `.ModifyCol(col?, options?)` | Resize/configure column; no args = auto-size all to content |
| `lv.GetNext()` | `.GetNext(startRow?, mode?)` | Find next selected/checked/focused row; mode: **omitted** = next selected (highlighted) row; `"C"`/`"Checked"`; `"F"`/`"Focused"`. `"Selected"` is NOT a valid mode — it throws ValueError. Returns 0 at end |
| `lv.GetText()` | `.GetText(row, col?)` | Get cell text; col is 1-based — row 0 retrieves column header text; col 0 does not exist |
| `lv.GetCount()` | `.GetCount(mode?)` | Row count; `"Col"` for column count |

### TreeView Control Methods
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `tv.Add()` | `.Add(text, parentId?, options?)` | Add node; parentId `0` = top-level; returns item ID integer |
| `tv.Delete()` | `.Delete(itemId?)` | Delete item and all descendants; no arg = delete all |
| `tv.Modify()` | `.Modify(itemId, options?, newText?)` | Change options or text of existing item: `"Expand"`, `"Select"`, `"Vis"` |
| `tv.GetNext()` | `.GetNext(itemId?, mode?)` | Traverse nodes; mode `"Full"` = depth-first all nodes; returns 0 at end |
| `tv.GetSelection()` | `.GetSelection()` | Return currently selected item ID; 0 if none |
| `tv.GetText()` | `.GetText(itemId)` | Return text label of item |
| `tv.GetParent()` | `.GetParent(itemId)` | Return parent item ID; 0 if top-level |

### GuiForm Helper (User-Defined — TIER 5+)
| Function | Signature | Notes |
|----------|-----------|-------|
| `GuiForm()` | `GuiForm(x, y, w, h, extraParams := "")` | Returns formatted position string `"x{} y{} w{} h{} extras"` for `gui.Add()` |
| `gForm()` | `gForm(x := "", y := "", w := 0, h := 0, extra := "")` | Same job, but `x`/`y` also accept relative keyword strings (`"xp"`, `"y+5"`, `"x+10"`) and `w`/`h` of `0` are omitted — TIER 7 |

## AHK V2 CONSTRAINTS

- **Class encapsulation is mandatory** — all GUI code must be inside a class or named function; never write bare top-level `Gui()` calls for TIER 2+ work (absence of class prevents `.Bind(this)` from resolving).
- **Map() for all control storage** — `this.controls := Map()` is the only safe container for named control references; a plain object exposes `HasOwnProp()`/`DeleteProp()` instead of the Map API, its keys are case-insensitive strings only (no integer keys, no object keys, no case distinction), and `obj.%key%` collides with real properties and with inherited base-chain members.
- **`.Bind(this)` is mandatory for class-method event handlers** — AHK v2 closures do not automatically capture the class instance; omitting `.Bind(this)` causes `this` to be undefined inside the handler, producing an UnsetError at call time.
- **`gui.Close()` does not exist** — calling it throws MethodError; use `gui.Hide()` to keep the window object alive for later `Show()`, or `gui.Destroy()` to permanently remove it.
- **Know the default positioning flow** — with no positioning option each control is placed *below* the previous one at the same x (the window margin); there is no rightward accumulation. Use `x+n`/`y+n` for relative offsets, `xp`/`yp` to reuse the previous control's coordinate, `xm`/`ym` to return to the window margin, and `xs`/`ys` to return to the last `Section` anchor.
- **Arrow syntax is single-expression only** — `(*) => expr` is valid; `=> {` is a syntax error on every build. v2.1 does provide an arrowless multi-statement function expression, `(params) { ... }`, but it is not valid inline inside an argument list — so an `OnEvent` callback with more than one statement must still be a named method bound with `.Bind(this)`.
- **Gui coordinates are LOGICAL units; WinGetPos/WinMove are PHYSICAL pixels** — `Gui.Show()`, `Gui.Move()` and `GuiCtrl.Move()` take logical units scaled by `A_ScreenDPI/96` (×1.25 at 125% scaling), while `WinGetPos()`/`WinMove()` operate in physical pixels. Never feed a `WinGetPos` result into `Gui.Move()`, and never feed a Gui coordinate into `WinMove()`. The `width`/`height` handed to an `OnEvent("Size")` callback are already in the Gui's own units, so arithmetic on them needs no conversion.
- **`GuiCtrlFromHwnd()` and `GuiFromHwnd()` return NO VALUE on no match** — `ctrl := GuiCtrlFromHwnd(h)` throws `UnsetError` ("No value was returned.") rather than yielding an empty string; guard every call with `?? 0`.
- **`gui.Submit()` hides the window by default** — `Submit()` without arguments collects v-named control values AND calls `Hide()`; pass `false` to suppress the hide; never call `Hide()` after `Submit()` — it is redundant.
- **Build controls once, guard with `_built`** — calling `CreateControls()` on every `Show()` duplicates controls; set `_built := true` after the first build and check before rebuilding (TIER 4+).
- **Owner window sequencing is order-sensitive** — call `ownerGui.Opt("+Disabled")` BEFORE showing the owned window; call `ownerGui.Opt("-Disabled")` BEFORE destroying or hiding the owned window — never after; the owner stays permanently disabled if it is still disabled when the owned window closes.
- **ListView and TreeView indices are 1-based** — `lv.GetText(1, 1)` is the first cell; col 0 does not exist; row 0 retrieves column header text; `lv.GetNext()` returns 0 only as an end-of-list sentinel.
- **Forward-loop ListView delete shifts row numbers** — deleting `A_Index` inside a `Loop GetCount()` skips rows because deletion shifts all indices; use a `while (rowNum := lv.GetNext(rowNum))` pattern and reset `rowNum := 0` after each delete.
- **HandleSize must guard against minimized state** — `minMax = -1` means minimized; calling `ctrl.Move()` while minimized causes controls to vanish on restore; always `return` early when `minMax = -1`.

Safe-access priority order for GUI control data:
  1. `ctrl.Value` — direct property read for known-present controls stored in `Map()`
  2. `this.controls.Get("key", "")` — when control existence may vary (dynamic builds)
  3. `this.controls.Has("key")` — when the if/else branch logic differs for present vs absent
  4. `try/catch` — only for `lv.GetText()` or `tv.GetText()` on IDs that may have been deleted

## TIER 1 — Basic GUI Creation
> METHODS COVERED: Gui() · SetFont() · AddText() · AddButton() · OnEvent() · Show() · Hide()

Covers the minimal `Gui()` constructor pattern: creating a window, setting font, handling Close/Escape events, adding one or two controls, and calling `Show()`. Use this tier for single-purpose dialogs, simple notifications, and prototype windows where layout precision is not required. Do not apply LayoutCalculator or Section patterns at this tier — that is over-engineering for 1–2 controls.
```ahk
; ✓ Correct: Minimal class-based GUI — TIER 1 pattern; class encapsulation is required even at this tier
SimpleDialog()

class SimpleDialog {
    __New() {
        this.gui := Gui(, "My Dialog")
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close",  (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        this.gui.AddText(, "Hello World!")
        this.gui.AddButton("Default w100", "OK").OnEvent("Click", (*) => this.gui.Hide())
        this.gui.Show()
    }
}

; ✗ legacy command-style GUI syntax (comma-separated arguments, no parentheses) does not
;   exist in v2 — every GUI operation is a method call on a Gui object
; new SimpleDialog()    ; → "new" is not a keyword in v2; it parses as a variable read
;                          (load-time warning) and throws UnsetError at runtime
```

## TIER 2 — Controls, Event Handling, ListView, TreeView, Multi-Window
> METHODS COVERED: Gui() · AddEdit() · AddCheckBox() · AddListView() · AddTreeView() · Submit() · OnEvent() · Bind() · Hotkey() · HotIfWinExist() · WinExist() · IsObject() · Opt() · lv.Add() · lv.Delete() · lv.Modify() · lv.ModifyCol() · lv.GetNext() · lv.GetText() · lv.GetCount() · tv.Add() · tv.Delete() · tv.Modify() · tv.GetNext() · tv.GetSelection() · tv.GetText() · tv.GetParent()

Introduces the full class-based GUI template: control references stored in `Map()`, named event handlers with `.Bind(this)`, `Submit()` for reading v-named control values, and hotkey integration for show/hide toggling. Also covers ListView and TreeView CRUD operations, and modal owned-window management with the owner-enable/disable sequence. Use this tier whenever the GUI needs to read user input, respond to multiple controls, or maintain state between interactions.
```ahk
; ✓ Correct: Full class template with Map() controls, events, and hotkeys
FormGui()

class FormGui {
    __New() {
        this.gui      := Gui("+Resize", "Input Form")
        this.controls := Map()                          ; ✓ Map() for storage, never {}
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close",  (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        this.CreateControls()
        this.SetupHotkeys()
    }

    CreateControls() {
        this.gui.AddText(, "Full Name:")
        this.controls["nameEdit"]  := this.gui.AddEdit("vUserName w200")
        this.gui.AddText(, "Email:")
        this.controls["emailEdit"] := this.gui.AddEdit("vUserEmail w200")

        this.controls["submitBtn"] := this.gui.AddButton("Default w200", "Submit")
        this.controls["submitBtn"].OnEvent("Click", this.HandleSubmit.Bind(this))
        this.gui.Show()
    }

    HandleSubmit(*) {
        ; Form A — let Submit() hide the window (preferred, concise):
        saved := this.gui.Submit()            ; ✓ hides window AND collects v-named controls
        MsgBox("Name: " saved.UserName "`nEmail: " saved.UserEmail)

        ; Form B — suppress Submit()'s auto-hide and hide manually:
        ; saved := this.gui.Submit(false)     ; false = do NOT hide yet
        ; MsgBox("Name: " saved.UserName "`nEmail: " saved.UserEmail)
        ; this.gui.Hide()
    }

    Toggle(*) {
        if WinExist("ahk_id " this.gui.Hwnd)
            this.gui.Hide()
        else
            this.gui.Show()
    }

    SetupHotkeys() {
        Hotkey("^m", this.Toggle.Bind(this))
        HotIfWinExist("ahk_id " this.gui.Hwnd)
        Hotkey("^Escape", this.Toggle.Bind(this), "On")
        HotIfWinExist()
    }
}

; ✗ Arrow syntax with multi-line block in event handler — INVALID in AHK v2
; this.controls["submitBtn"].OnEvent("Click", (*) => {
;     saved := this.gui.Submit()
;     MsgBox(saved.UserName)
; })                                          ; → load-time parse error (multi-line arrow block)

; ListView and TreeView CRUD
; ListView: columns, Add, Delete, Modify, GetNext loop, enumeration
class ListViewCrudDemo {
    __New() {
        this.gui      := Gui("+Resize", "ListView CRUD")
        this.controls := Map()
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close",  (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        this.CreateControls()
        this.gui.Show("w520 h360")
    }

    CreateControls() {
        ; ✓ Correct: column headers passed as an Array in the third parameter
        lv := this.gui.AddListView("xm w500 h260 Grid -ReadOnly",
                                    ["Name", "Age", "City"])
        this.controls["lv"] := lv
        lv.Add("", "Alice", "30", "Taipei")      ; ✓ Add() returns new row number (1-based)
        lv.Add("", "Bob",   "25", "Kaohsiung")
        lv.Add("", "Carol", "35", "Tainan")
        lv.ModifyCol()                            ; ✓ auto-size all columns to content

        this.controls["addBtn"] := this.gui.AddButton("xm   w118 h28", "Add Row")
        this.controls["delBtn"] := this.gui.AddButton("x+4  w118 h28", "Delete")
        this.controls["edtBtn"] := this.gui.AddButton("x+4  w118 h28", "Edit")
        this.controls["clrBtn"] := this.gui.AddButton("x+4  w118 h28", "Clear All")
        this.controls["addBtn"].OnEvent("Click", this.AddRow.Bind(this))
        this.controls["delBtn"].OnEvent("Click", this.DeleteRow.Bind(this))
        this.controls["edtBtn"].OnEvent("Click", this.EditRow.Bind(this))
        this.controls["clrBtn"].OnEvent("Click", this.ClearAll.Bind(this))
        this.controls["lv"].OnEvent("DoubleClick", this.HandleDoubleClick.Bind(this))
    }

    AddRow(*) {
        lv     := this.controls["lv"]
        rowNum := lv.Add("", "New Person", "0", "Unknown")   ; ✓ 1-based row number
        lv.Modify(rowNum, "Select Focus Vis")   ; ✓ select it and scroll into view
        lv.ModifyCol()
    }

    DeleteRow(*) {
        lv     := this.controls["lv"]
        rowNum := 0
        ; ✓ GetNext(start) with the mode omitted finds the next SELECTED row; reset to 0
        ; after each delete because row numbers shift downward after removal
        while (rowNum := lv.GetNext(rowNum)) {
            lv.Delete(rowNum)
            rowNum := 0
        }
    }

    EditRow(*) {
        lv     := this.controls["lv"]
        rowNum := lv.GetNext(0)      ; ✓ GetNext(0) = first selected row, searching from row 1
        if !rowNum
            return
        ; ✓ GetText(row, col): both row and col are 1-based integers
        ; ✓ Modify(row, opts, col1, col2, col3): pass "" for opts to change only text
        lv.Modify(rowNum, "",
                  "Edited: " lv.GetText(rowNum, 1),
                  lv.GetText(rowNum, 2),
                  lv.GetText(rowNum, 3))
        lv.ModifyCol()
    }

    ClearAll(*) {
        this.controls["lv"].Delete()             ; ✓ Delete() with no arg removes all rows
    }

    HandleDoubleClick(ctrlObj, rowNum, *) {
        if !rowNum
            return
        MsgBox("Row " rowNum ": " ctrlObj.GetText(rowNum, 1))
    }

    ; ✓ Sequential enumeration: Loop GetCount() gives A_Index = 1..N (1-based)
    EnumerateAll() {
        lv := this.controls["lv"]
        output := ""
        Loop lv.GetCount() {
            output .= A_Index ": "
                    . lv.GetText(A_Index, 1) ", "
                    . lv.GetText(A_Index, 2) "`n"
        }
        return output
    }
}

; TreeView: Add with parent IDs, GetNext traversal, Modify, Delete
class TreeViewCrudDemo {
    __New() {
        this.gui      := Gui("+Resize", "TreeView CRUD")
        this.controls := Map()
        this.nodeMap  := Map()             ; ✓ Map() to track label → item ID for later use
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close",  (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        this.CreateControls()
        this.gui.Show("w360 h420")
    }

    CreateControls() {
        tv := this.gui.AddTreeView("xm w340 h320")
        this.controls["tv"] := tv

        ; ✓ Add(text, parentItemID, options) — parentItemID 0 = top-level; returns item ID
        fruitsId := tv.Add("Fruits",     0,        "Expand")
        appleId  := tv.Add("Apple",      fruitsId, "")       ; child of Fruits
        tv.Add("Banana",     fruitsId, "")
        vegsId   := tv.Add("Vegetables", 0,        "Expand")
        tv.Add("Carrot",   vegsId, "")
        tv.Add("Broccoli", vegsId, "")

        ; ✓ Store IDs in Map() to retrieve or modify specific nodes later
        this.nodeMap["fruits"] := fruitsId
        this.nodeMap["apple"]  := appleId

        this.controls["addBtn"] := this.gui.AddButton("xm    w162 h28", "Add Child")
        this.controls["delBtn"] := this.gui.AddButton("x+10  w162 h28", "Delete Selected")
        this.controls["addBtn"].OnEvent("Click", this.AddChild.Bind(this))
        this.controls["delBtn"].OnEvent("Click", this.DeleteSelected.Bind(this))
        tv.OnEvent("ItemSelect", this.HandleSelect.Bind(this))
    }

    AddChild(*) {
        tv       := this.controls["tv"]
        parentId := tv.GetSelection()          ; ✓ GetSelection() returns selected item ID
        if !parentId
            return
        newId := tv.Add("New Item", parentId, "Select Vis")  ; ✓ Vis = scroll into view
        tv.Modify(parentId, "Expand")                         ; expand parent to show child
    }

    DeleteSelected(*) {
        tv    := this.controls["tv"]
        selId := tv.GetSelection()
        if !selId
            return
        tv.Delete(selId)                  ; ✓ Delete(itemID) removes item + all descendants
    }

    HandleSelect(ctrlObj, itemId, *) {
        if !itemId
            return
        MsgBox("Selected: " ctrlObj.GetText(itemId))   ; ✓ GetText(itemID) returns label
    }

    ; ✓ Depth-first traversal: GetNext(id, "Full") visits every node; 0 = end of tree
    TraverseAll() {
        tv     := this.controls["tv"]
        itemId := 0
        output := ""
        Loop {
            itemId := tv.GetNext(itemId, "Full")
            if !itemId
                break
            indent := tv.GetParent(itemId) ? "  " : ""
            output .= indent tv.GetText(itemId) "`n"
        }
        return output
    }
}

; ✗ 0-based column index in ListView
; lv.GetText(1, 0)            ; → col 0 does not exist; first column is 1
; ✓ row 0 is valid — retrieves column header text, not a data row:
; lv.GetText(0, 1)            ; → column 1 header text (row 0 = column headers, not a data row)
; ✗ Discarding the item ID returned by tv.Add()
; tv.Add("Child", parentId)   ; → cannot modify or delete later without the ID
; ✗ Forward-loop delete in ListView without resetting the row counter
; Loop lv.GetCount() { lv.Delete(A_Index) }   ; → row numbers shift after each delete;
;                                                  use GetNext while-loop instead

; Multi-Window Management — Owner / Owned Windows
;
; +Owner rules:
;   - childGui.Opt("+Owner" . parentGui.Hwnd) makes childGui owned by parentGui
;   - Owned window: no taskbar button; always on top of its owner
;   - Auto-destroyed when its owner is destroyed (requires same process)
;   - Must call parentGui.Opt("+Disabled") BEFORE showing child (blocks parent input)
;   - Must call parentGui.Opt("-Disabled") BEFORE destroying/hiding child — never after
;     (if owner is still disabled when the owned window closes, owner stays disabled)

MainAppWindow()

class MainAppWindow {
    __New() {
        this.gui    := Gui("+Resize", "Main Window")
        this.dialog := ""            ; ✓ sentinel value — replaced when dialog is open
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close",  (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        this.gui.AddText("xm w360", "Main application window.")
        this.gui.AddButton("xm w180 h30", "Open Settings...").OnEvent("Click",
            this.OpenSettings.Bind(this))
        this.gui.Show("w400 h150")
    }

    OpenSettings(*) {
        if IsObject(this.dialog)   ; ✓ prevent duplicate owned windows
            return
        ; ✓ CRITICAL: disable owner BEFORE showing owned window
        this.gui.Opt("+Disabled")
        this.dialog := OwnedSettingsDialog(this.gui, this.OnSettingsClosed.Bind(this))
    }

    ; Callback invoked by the owned dialog when it finishes
    OnSettingsClosed(*) {
        ; ✓ CRITICAL: re-enable owner BEFORE destroying owned window
        ;   Destroying while owner is still disabled leaves owner permanently disabled
        this.gui.Opt("-Disabled")
        if IsObject(this.dialog) {
            this.dialog.Destroy()
            this.dialog := ""
        }
    }
}

class OwnedSettingsDialog {
    __New(ownerGui, closeCb) {
        this.closeCb := closeCb
        this.gui     := Gui(, "Settings")
        ; ✓ Correct: pass owner's HWND to +Owner option string concatenation
        this.gui.Opt("+Owner" . ownerGui.Hwnd)
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close",  this.HandleClose.Bind(this))
        this.gui.OnEvent("Escape", this.HandleClose.Bind(this))
        this.gui.AddText("xm w280", "Settings for the application.")
        this.gui.AddButton("xm w130 h28 Default", "OK").OnEvent("Click",
            this.HandleClose.Bind(this))
        this.gui.AddButton("x+8 w130 h28", "Cancel").OnEvent("Click",
            this.HandleClose.Bind(this))
        this.gui.Show("w320 h160")
    }

    HandleClose(*) {
        ; ✓ Delegate close logic to owner — do NOT re-enable owner here;
        ;   the owner is responsible for its own Disabled state
        this.closeCb.Call()
    }

    Destroy() {
        this.gui.Destroy()
    }
}

; ✗ Re-enabling owner AFTER destroying the owned window
; ownedGui.Destroy()              ; → destroys while owner still disabled → stuck disabled
; ownerGui.Opt("-Disabled")       ; → too late; must come BEFORE Destroy() or Hide()
;
; ✗ Setting +Owner after the owned window is already shown
; ownedGui.Show()                 ; → must set +Owner before Show(), not after
; ownedGui.Opt("+Owner" ...)      ; → may have no effect once the window is visible
;
; ✗ Using WinExist to guard against duplicate owned windows
; if WinExist("Settings")         ; → unreliable for same-script windows; use an object ref
```

## TIER 3 — Layout and Positioning Management
> METHODS COVERED: AddText() · AddEdit() · AddCheckBox() · AddButton() · Section · xm · xs/ys · ctrl.Move() · OnEvent("Size") · PositionValidator.ValidatePositioning() · PositionValidator.ValidateArrowBlocks() · RegExMatch()

Covers AHK v2's relative positioning system: `xm`/`ym` margin resets, `Section` anchors with `xs`/`ys`, multi-column layouts with `x+n` relative offsets, the PositionValidator class for pre-output error detection, and responsive window resizing via `OnEvent("Size")`. Use this tier for any GUI with more than one logical section, more than five controls, or inline multi-column button rows. Always run PositionValidator mentally before outputting code at this tier.
```ahk
; POSITIONING RULES — apply before writing any multi-section GUI:
;
; ✓ Default flow: with no positioning option a control lands directly BELOW the
;   previous one at the same x. Nothing drifts rightward on its own.
;
; ✓ Correct: Section header uses xm to sit at the left margin and marks the anchor
;   this.gui.AddText("xm Section", "Section Header")
;
; ✓ Correct: First control in each section restates xm so the section is left-aligned
;   this.controls["ctrl"] := this.gui.AddEdit("xm w200")
;
; ✓ Correct: Sibling controls in same row use relative x+n offset
;   this.controls["btn1"] := this.gui.AddButton("xm w100",  "Save")
;   this.controls["btn2"] := this.gui.AddButton("x+10 w100", "Cancel")
;
; ✓ Correct: xs/ys return to the last Section anchor — this is what Section is FOR
;   this.controls["col2"] := this.gui.AddEdit("ys w200")   ; new column beside the section

MultiSectionGui()

class MultiSectionGui {
    __New() {
        this.gui      := Gui("+Resize", "Settings")
        this.controls := Map()
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close",  (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        this.CreateControls()
        this.gui.Show("w380")
    }

    CreateControls() {
        ; Section 1: User Info
        this.gui.AddText("xm Section", "User Information")         ; ✓ xm Section
        this.controls["nameEdit"]  := this.gui.AddEdit("xm w340 vUserName")
        this.gui.AddText("xm", "Email:")
        this.controls["emailEdit"] := this.gui.AddEdit("xm w340 vUserEmail")

        ; Section 2: Preferences
        this.gui.AddText("xm Section", "Preferences")              ; ✓ xm resets
        this.controls["notifyChk"]   := this.gui.AddCheckBox("xm", "Enable Notifications")
        this.controls["autoSaveChk"] := this.gui.AddCheckBox("xm", "Auto-save")

        ; Section 3: Actions (multi-column row)
        this.gui.AddText("xm Section", "")
        this.controls["saveBtn"]   := this.gui.AddButton("xm w160",    "Save")
        this.controls["cancelBtn"] := this.gui.AddButton("x+20 w160",  "Cancel") ; ✓ x+n
        this.controls["saveBtn"].OnEvent("Click",   this.HandleSave.Bind(this))
        this.controls["cancelBtn"].OnEvent("Click", (*) => this.gui.Hide())
    }

    HandleSave(*) {
        saved := this.gui.Submit(false)   ; ✓ false = keep window visible while saving
        MsgBox("Saved: " saved.UserName)
    }
}

; PositionValidator: run this mentally before outputting any TIER 3+ code
class PositionValidator {
    static ValidatePositioning(guiCode) {
        errors := []
        sectionCount := 0
        anchorRefCount := 0
        pos := 1
        while (pos := RegExMatch(guiCode, "\bSection\b", &m, pos)) {
            sectionCount++
            pos := m.Pos + m.Len
        }
        pos := 1
        while (pos := RegExMatch(guiCode, "\b(?:xm|xs|ys)\b", &m, pos)) {
            anchorRefCount++
            pos := m.Pos + m.Len
        }
        if (sectionCount > 0 && anchorRefCount = 0)
            errors.Push("WARNING: Section declared but no xm/xs/ys ever returns to an anchor")
        return errors
    }

    static ValidateArrowBlocks(code) {
        errors := []
        if RegExMatch(code, "=>\s*\{")
            errors.Push("CRITICAL: '=> {' is a syntax error — use a named method + .Bind(this)")
        return errors
    }
}

; Responsive Window — gui.OnEvent("Size", Handler)
;
; Size event callback signature (class method form):
;   HandleSize(guiObj, minMax, width, height)
;     guiObj:  the Gui object that was resized
;     minMax:  0 = normal/restored, 1 = maximized, -1 = minimized
;     width, height: new client-area size (title bar and borders excluded)
;
; Use ctrl.Move(x, y, w, h) to reposition or resize controls.
; OMIT any parameter you want to leave unchanged — ctrl.Move(, , w) resizes width only.
; Passing "" instead throws TypeError ("requires a Number, but received an empty string").
; width/height arrive in the Gui's own logical units — no A_ScreenDPI conversion needed.
; Always check (minMax = -1) first and return early — moving controls while the
; window is minimized causes them to disappear on restore.

ResizableLogGui()

class ResizableLogGui {
    __New() {
        this.pad      := 10
        this.gui      := Gui("+Resize +MinSize300x200", "Resizable Log Window")
        this.controls := Map()
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close",  (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        ; ✓ Correct: register Size handler with .Bind(this) before Show()
        this.gui.OnEvent("Size", this.HandleSize.Bind(this))
        this.CreateControls()
        this.gui.Show("w600 h400")
    }

    CreateControls() {
        pad := this.pad
        ; Log area — occupies most of the window; stretches both dimensions on resize
        this.controls["log"] := this.gui.AddEdit(
            "xm w580 h330 ReadOnly -Wrap", "")
        ; Status text — docked to bottom, stretches horizontally
        this.controls["status"] := this.gui.AddText(
            "xm w580 h20 +Border", "Ready")
        ; Clear button — anchored to bottom-right corner on resize
        this.controls["clearBtn"] := this.gui.AddButton(
            "xm w80 h28", "Clear")
        this.controls["clearBtn"].OnEvent("Click",
            (*) => (this.controls["log"].Value := ""))
    }

    ; ✓ Correct: multi-statement resize handler must be a named bound method
    HandleSize(guiObj, minMax, width, height) {
        if (minMax = -1)         ; minimized — skip layout recalculation
            return
        pad     := this.pad
        ; Log area fills available space, leaving rows for status bar and button
        logH    := height - pad * 5 - 20 - 28
        logW    := width  - pad * 2
        statusY := pad + logH + pad
        btnX    := width - pad - 80
        btnY    := statusY + 20 + pad
        ; ✓ Move(x, y, w, h): all four axes explicit; omit a parameter — Move(, , w) —
        ;   to leave that axis unchanged; never pass "" for an axis
        this.controls["log"].Move(pad, pad, logW, logH)
        this.controls["status"].Move(pad, statusY, logW, 20)
        this.controls["clearBtn"].Move(btnX, btnY, 80, 28)
    }
}

; ✗ Arrow syntax for multi-statement Size handler — INVALID in AHK v2
; this.gui.OnEvent("Size", (g, mm, w, h) => {   ; → load-time parse error (multi-line arrow block)
;     this.controls["log"].Move(...)
;     this.controls["clearBtn"].Move(...)
; })
;
; ✗ Not checking minMax = -1 before moving controls
; HandleSize(guiObj, minMax, width, height) {
;     this.controls["log"].Move(pad, pad, width - 20, height - 80)  ; → controls vanish on restore
; }
;
; ✗ Using hard-coded sizes instead of computing from the width/height parameters
; HandleSize(guiObj, minMax, width, height) {
;     this.controls["log"].Move(10, 10, 580, 330)  ; → ignores new width/height entirely
; }
```

## TIER 4 — Mathematical Layout System
> METHODS COVERED: LayoutCalculator.Calculate() · LayoutCalculator.Validate() · LayoutCalculator.FormatReport() · LayoutAwareGui.__New() · AddElement() · ParseDimension() · CalculateLayout() · CreateControls() · ShowLayoutReport() · Show() · MsgBox()

Introduces the `LayoutCalculator` static class and `LayoutAwareGui` base class for data-driven, mathematically validated GUI construction. Every element's x, y, width, and height is computed from window dimensions and padding; boundary checks run automatically and accumulate every violation; a layout report can be displayed on demand. Use this tier for forms with dynamic element lists, settings panels requiring pixel-perfect alignment, or any scenario where positions must be auditable and reproducible.
```ahk
; LayoutCalculator — static utility for coordinate calculation and validation
class LayoutCalculator {
    static Calculate(windowWidth, windowHeight, padding, elements) {
        result   := Map()
        currentY := padding

        for element in elements {
            elementResult := Map()
            elementResult["x"]            := padding
            elementResult["xReason"]      := "Left margin (xm)"
            elementResult["y"]            := currentY
            elementResult["yReason"]      := "Accumulated from previous elements + padding"
            elementResult["width"]        := element.Has("width")
                                             ? element["width"]
                                             : windowWidth - (padding * 2)
            elementResult["height"]       := element["height"]
            elementResult["widthReason"]  := element.Has("width")
                                             ? "Specified width"
                                             : "Full width minus left+right padding"
            elementResult["heightReason"] := "Specified height"
            elementResult["ahkPosition"]  := "xm"
            result[element["id"]] := elementResult
            currentY += element["height"] + (padding // 2)
        }
        return result
    }

    ; ✓ Accumulate EVERY violation — overwriting a single string loses all but the last
    static Validate(layout, windowWidth, windowHeight) {
        violations := []
        for elementId, element in layout {
            if (element["x"] + element["width"] > windowWidth)
                violations.Push("Element " elementId " exceeds right boundary")
            if (element["y"] + element["height"] > windowHeight)
                violations.Push("Element " elementId " exceeds bottom boundary")
        }
        ; ✓ Map() built empty then keyed — never the banned constructor-with-pairs form
        result := Map()
        result["boundary"] := violations
        return result
    }

    static FormatReport(layout, validation) {
        report := "GUI Layout Analysis`n`n"
        for elementId, element in layout {
            report .= "Element: " elementId "`n"
            report .= "  X:      " element["x"]      " px (" element["xReason"]      ")`n"
            report .= "  Y:      " element["y"]      " px (" element["yReason"]      ")`n"
            report .= "  Width:  " element["width"]  " px (" element["widthReason"]  ")`n"
            report .= "  Height: " element["height"] " px (" element["heightReason"] ")`n`n"
        }
        report .= "Validation:`n"
        if (validation["boundary"].Length) {
            for violation in validation["boundary"]
                report .= "  Boundary: " violation "`n"
        } else {
            report .= "  Boundary: All elements within boundaries`n"
        }
        return report
    }
}

; LayoutAwareGui — base class; extend this for data-driven GUIs
class LayoutAwareGui {
    __New(title := "Layout GUI", width := 400, height := 300, padding := 10) {
        this.windowWidth  := width
        this.windowHeight := height
        this.padding      := padding
        this.elements     := []
        this.layout       := Map()
        this.controls     := Map()
        this._built       := false
        this.gui          := Gui("+Resize", title)
        this.gui.MarginX  := 0
        this.gui.MarginY  := 0
        this.gui.OnEvent("Close",  (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
    }

    AddElement(id, type, options := "", text := "") {
        width  := this.ParseDimension(options, "w", this.windowWidth - (this.padding * 2))
        height := this.ParseDimension(options, "h", 25)
        ; ✓ empty Map() then per-key assignment — the constructor-with-pairs form is banned
        elementDef := Map()
        elementDef["id"]      := id
        elementDef["type"]    := type
        elementDef["width"]   := width
        elementDef["height"]  := height
        elementDef["options"] := options
        elementDef["text"]    := text
        this.elements.Push(elementDef)
        return this
    }

    ParseDimension(options, prefix, defaultVal) {
        if RegExMatch(options, prefix "(\d+)", &match)
            return Integer(match[1])
        return defaultVal
    }

    CalculateLayout() {
        this.layout := LayoutCalculator.Calculate(
            this.windowWidth, this.windowHeight, this.padding, this.elements
        )
        return this
    }

    CreateControls() {
        for element in this.elements {
            if !this.layout.Has(element["id"])
                continue
            pos     := this.layout[element["id"]]
            options := "x" pos["x"] " y" pos["y"] " w" pos["width"] " h" pos["height"]
            switch element["type"] {
                case "Text":     this.controls[element["id"]] := this.gui.AddText(options,     element["text"])
                case "Edit":     this.controls[element["id"]] := this.gui.AddEdit(options,     element["text"])
                case "Button":   this.controls[element["id"]] := this.gui.AddButton(options,   element["text"])
                case "CheckBox": this.controls[element["id"]] := this.gui.AddCheckBox(options, element["text"])
            }
        }
        return this
    }

    ShowLayoutReport() {
        validation := LayoutCalculator.Validate(this.layout, this.windowWidth, this.windowHeight)
        report     := LayoutCalculator.FormatReport(this.layout, validation)
        MsgBox(report, "Layout Analysis", "Iconi")
        return this
    }

    Show() {
        if !this._built {
            this.CalculateLayout()
            this.CreateControls()
            this._built := true
        }
        this.gui.Show("w" this.windowWidth " h" this.windowHeight)
        return this
    }
}

; Usage: extend LayoutAwareGui, build elements, wire events, then show
SettingsPanel()

class SettingsPanel extends LayoutAwareGui {
    __New() {
        super.__New("Application Settings", 400, 320, 12)
        this.AddElement("header",    "Text",   "h30",      "User Settings")
            .AddElement("nameLabel", "Text",   "h20",      "Full Name:")
            .AddElement("nameEdit",  "Edit",   "h25",      "")
            .AddElement("emailLbl",  "Text",   "h20",      "Email:")
            .AddElement("emailEdit", "Edit",   "h25",      "")
            .AddElement("saveBtn",   "Button", "w160 h32", "Save Settings")

        ; Build controls first, then wire events, then show — correct order
        this.CalculateLayout()
        this.CreateControls()
        this._built := true
        this.controls["saveBtn"].OnEvent("Click", this.HandleSave.Bind(this))
        this.gui.Show("w" this.windowWidth " h" this.windowHeight)
        this.ShowLayoutReport()    ; ✓ always show report in TIER 4 examples
    }

    HandleSave(*) {
        MsgBox("Settings saved!")
    }
}
```

## TIER 5 — GuiForm Mathematical Positioning
> METHODS COVERED: GuiForm() · gui.Add() · Format() · gui.Show() · gui.Submit() · gui.OnEvent() · gui.SetFont() · gui.Hide()

Introduces the `GuiForm()` helper function and the `pad`/`currentY` coordinate system for explicit, mathematically consistent GUI layouts. Every control position is derived from a single `pad` variable and a sequential `currentY` cursor — no hard-coded coordinates, no implicit AHK position accumulation. Use this tier when pixel-perfect alignment, easily adjustable spacing, or a visually professional result is required without the full overhead of `LayoutAwareGui`.
```ahk
; GuiForm helper — define once at the top of every TIER 5+ GUI function
GuiForm(x, y, w, h, extraParams := "") {
    params := Format("x{} y{} w{} h{}", x, y, w, h)
    return extraParams ? params " " extraParams : params
}

; ✓ Correct: TIER 5 layout foundation — single pad, currentY tracking
;   Never name a local or a parameter "gui" — identifiers shadow built-in class names
;   case-insensitively. If the shadowing name is still unassigned when the class is
;   called — including the canonical `gui := Gui()`, where the right-hand side resolves
;   to the not-yet-assigned local — you get UnsetError ("This local variable has not
;   been assigned a value"). If it already holds a value, you get MethodError instead
;   (This value of type "Gui" has no method named "Call"). Same trap for "menu",
;   "array", "map".
CreateSettingsGui() {
    g := Gui("+Resize", "Settings")
    g.OnEvent("Close",  (*) => g.Hide())
    g.OnEvent("Escape", (*) => g.Hide())

    pad          := 10          ; ✓ one variable controls ALL spacing
    currentY     := pad         ; ✓ Y cursor starts at top margin
    windowWidth  := 500
    contentWidth := windowWidth - (pad * 2)

    g.SetFont("s12 bold")
    g.Add("Text", GuiForm(pad, currentY, contentWidth, 25, "+Center"), "Application Settings")
    currentY += 25 + pad * 2    ; ✓ major section break uses pad*2
    g.SetFont("s9 norm")

    ; Inline label + edit row
    labelWidth := 80
    g.Add("Text", GuiForm(pad, currentY, labelWidth, 23), "Name:")
    g.Add("Edit", GuiForm(pad + labelWidth + pad, currentY,
            contentWidth - labelWidth - pad, 23, "vName"), "")
    currentY += 23 + pad

    g.Add("Text", GuiForm(pad, currentY, labelWidth, 23), "Email:")
    g.Add("Edit", GuiForm(pad + labelWidth + pad, currentY,
            contentWidth - labelWidth - pad, 23, "vEmail"), "")
    currentY += 23 + pad

    ; CheckBox group
    g.Add("CheckBox", GuiForm(pad, currentY, contentWidth, 23, "vAutoSave"),
            "Auto-save enabled")
    currentY += 23 + pad

    g.Add("CheckBox", GuiForm(pad, currentY, contentWidth, 23, "vDarkMode"),
            "Dark mode")
    currentY += 23 + pad * 2    ; ✓ section break before buttons

    ; OK button
    btnW := 100
    btnH := 28
    okBtn := g.Add("Button", GuiForm(pad, currentY, btnW, btnH, "Default"), "OK")
    okBtn.OnEvent("Click", (*) => g.Submit())
    currentY += btnH + pad

    ; ✓ window height = currentY + pad (bottom margin)
    g.Show(Format("w{} h{}", windowWidth, currentY + pad))
    return g
}

CreateSettingsGui()

; ✗ Hard-coded Y values break when spacing changes
; gui.Add("Text", "x10 y47 w100 h23", "Name:")     ; → brittle, unmaintainable
; gui.Add("Edit", "x10 y74 w380 h23")               ; → updating requires recalculating all
```

### Performance Notes

GUI performance in AHK v2 is most affected by control creation overhead, frequent redraws during Show/Hide cycles, and unnecessary `CalculateLayout()` or `GuiForm` recalculations on every `Show()`. Pre-compute layouts once during `__New()` or the creation function rather than recalculating dynamically. For GUIs that change element lists at runtime, invalidate the layout cache explicitly with a dirty-flag. Prefer `Map()` over repeated `HasProp()` lookups for O(1) control access by key name. For `GuiForm` layouts, pre-compute all derived values (`contentWidth`, column widths, button `startX`) once before the control-creation loop — never recompute per-control.
```ahk
class PerformantGui {
    __New() {
        this.gui          := Gui("+Resize", "Performant GUI")
        this.controls     := Map()    ; ✓ O(1) access by key, never linear search
        this._layoutDirty := true
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close",  (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        this.BuildControls()          ; ✓ build all controls once in __New()
    }

    BuildControls() {
        ; ✓ Correct: create all controls once; never rebuild on Show()
        this.controls["status"] := this.gui.AddText("xm w300 h20",       "Ready")
        this.controls["log"]    := this.gui.AddEdit("xm w300 h100 ReadOnly -Wrap")
        this.controls["clear"]  := this.gui.AddButton("xm w140",          "Clear Log")
        this.controls["close"]  := this.gui.AddButton("x+20 w140",        "Close")
        this.controls["clear"].OnEvent("Click", this.ClearLog.Bind(this))
        this.controls["close"].OnEvent("Click", (*) => this.gui.Hide())
    }

    ; ✓ Correct: update control value directly — no full control rebuild
    UpdateStatus(msg) {
        this.controls["status"].Value := msg
    }

    ; ✓ Correct: append to Edit value without recreating the control
    AppendLog(line) {
        this.controls["log"].Value .= line "`n"
    }

    ClearLog(*) {
        this.controls["log"].Value := ""
    }

    Show(*) => this.gui.Show()    ; ✓ single-expression arrow for simple delegation
}

; ✓ Correct: GuiForm performance — pre-compute derived layout values once
EfficientGuiFormLayout() {
    g := Gui(, "Efficient")
    pad          := 10
    currentY     := pad
    windowWidth  := 500
    contentWidth := windowWidth - (pad * 2)    ; ✓ computed once, reused everywhere

    ; ✓ column widths computed once before the loop
    numCols   := 3
    colWidth  := (contentWidth - pad * (numCols - 1)) / numCols

    Loop numCols {
        x := pad + (A_Index - 1) * (colWidth + pad)    ; ✓ formula, not literals
        g.Add("Edit", GuiForm(x, currentY, colWidth, 23), "Col " A_Index)
    }
    currentY += 23 + pad

    g.Show(Format("w{} h{}", windowWidth, currentY + pad))
    return g
}
```

**O(1) vs O(n) summary:**
- `Map()` key lookup → O(1) regardless of control count; `HasProp()` on plain objects → O(n) in worst case
- Pre-computing `contentWidth`, `colWidth`, `startX` once before a loop → O(1) setup; computing inside the loop → O(n) redundant arithmetic
- `CalculateLayout()` in `Show()` on every call → O(n) per display; guard with `_built` flag → O(1) after first build
- `ctrl.Value := newText` to update text → O(1) property write; rebuilding the control entirely → O(n) destroy + re-add overhead

## TIER 6 — Advanced Layout Compositions
> METHODS COVERED: GuiForm() · AddListView() · AddGroupBox() · AddCheckBox() · AddButton() · gui.Add() · Format() · gui.Show() · gui.Hide() · gui.Submit() · gui.OnEvent()

Applies the GuiForm system to production-grade layout patterns: multi-column grids with mathematically distributed widths, button rows aligned right/center/distributed, GroupBox controls with consistent inner padding, and a complete validated settings GUI. Use this tier when delivering a finished, professionally spaced GUI that must remain easily maintainable by adjusting a single `pad` value.
```ahk
GuiForm(x, y, w, h, extraParams := "") {
    params := Format("x{} y{} w{} h{}", x, y, w, h)
    return extraParams ? params " " extraParams : params
}

; PATTERN 1: Two-column side-by-side controls
TwoColumnDemo() {
    g := Gui(, "Two Columns")
    pad          := 10
    currentY     := pad
    windowWidth  := 650
    contentWidth := windowWidth - (pad * 2)

    leftWidth := (contentWidth - pad) / 2    ; ✓ gap between columns = pad
    rightX    := pad + leftWidth + pad

    g.Add("ListView", GuiForm(pad,   currentY, leftWidth, 200), ["Source"])
    g.Add("ListView", GuiForm(rightX, currentY, leftWidth, 200), ["Destination"])
    currentY += 200 + pad

    g.Show(Format("w{} h{}", windowWidth, currentY + pad))
    return g
}

; PATTERN 2: N equal columns
ThreeColumnDemo() {
    g := Gui(, "Three Columns")
    pad          := 10
    currentY     := pad
    windowWidth  := 650
    contentWidth := windowWidth - (pad * 2)

    numCols    := 3
    totalGaps  := pad * (numCols - 1)
    colWidth   := (contentWidth - totalGaps) / numCols

    Loop numCols {
        x := pad + (A_Index - 1) * (colWidth + pad)
        g.Add("ListView", GuiForm(x, currentY, colWidth, 150), ["Column " A_Index])
    }
    currentY += 150 + pad

    g.Show(Format("w{} h{}", windowWidth, currentY + pad))
    return g
}

; PATTERN 3: Right-aligned button row
RightAlignedButtons(g, currentY, windowWidth, pad) {
    labels  := ["OK", "Cancel", "Apply"]
    btnW    := 100
    btnH    := 30
    totalW  := labels.Length * btnW + (labels.Length - 1) * pad
    startX  := windowWidth - pad - totalW

    for idx, label in labels {
        x := startX + (idx - 1) * (btnW + pad)
        g.Add("Button", GuiForm(x, currentY, btnW, btnH), label)
    }
    return currentY + btnH + pad
}

; PATTERN 4: Centered button row
CenteredButtons(g, currentY, windowWidth, pad) {
    labels := ["Save", "Cancel"]
    btnW   := 110
    btnH   := 30
    totalW := labels.Length * btnW + (labels.Length - 1) * pad
    startX := (windowWidth - totalW) / 2

    for idx, label in labels {
        x := startX + (idx - 1) * (btnW + pad)
        g.Add("Button", GuiForm(x, currentY, btnW, btnH), label)
    }
    return currentY + btnH + pad
}

; PATTERN 5: Distributed button row (equal widths, full content width)
DistributedButtons(g, currentY, windowWidth, pad) {
    labels      := ["Back", "Next", "Finish"]
    btnH        := 30
    contentWidth := windowWidth - (pad * 2)
    btnW        := (contentWidth - pad * (labels.Length - 1)) / labels.Length

    for idx, label in labels {
        x := pad + (idx - 1) * (btnW + pad)
        g.Add("Button", GuiForm(x, currentY, btnW, btnH), label)
    }
    return currentY + btnH + pad
}

; PATTERN 6: GroupBox with nested inner padding
GroupBoxDemo() {
    g := Gui(, "Group Demo")
    pad          := 10
    currentY     := pad
    windowWidth  := 500
    contentWidth := windowWidth - (pad * 2)

    groupH := 110
    g.Add("GroupBox", GuiForm(pad, currentY, contentWidth, groupH), "Options")

    innerY     := currentY + 20           ; allow for GroupBox label height
    innerX     := pad * 2
    innerWidth := contentWidth - (pad * 2)

    g.Add("CheckBox", GuiForm(innerX, innerY, innerWidth, 23, "vAutoSave"),
            "Enable auto-save")
    innerY += 23 + pad

    g.Add("CheckBox", GuiForm(innerX, innerY, innerWidth, 23, "vNotifications"),
            "Enable notifications")
    innerY += 23 + pad

    g.Add("CheckBox", GuiForm(innerX, innerY, innerWidth, 23, "vDarkMode"),
            "Dark mode")

    currentY += groupH + pad

    g.Show(Format("w{} h{}", windowWidth, currentY + pad))
    return g
}

; COMPLETE PRODUCTION GUI: all patterns combined
CreateProductionGui() {
    g := Gui("+Resize", "Production Settings")
    g.OnEvent("Close",  (*) => g.Hide())
    g.OnEvent("Escape", (*) => g.Hide())

    pad          := 10
    currentY     := pad
    windowWidth  := 500
    contentWidth := windowWidth - (pad * 2)

    ; Title
    g.SetFont("s12 bold")
    g.Add("Text", GuiForm(pad, currentY, contentWidth, 25, "+Center"),
            "Application Settings")
    currentY += 25 + pad * 2
    g.SetFont("s9 norm")

    ; Label + edit pairs
    labelWidth := 80
    ; ✓ each field def built as an empty Map() plus per-key assignment
    nameField := Map()
    nameField["label"] := "Name:"
    nameField["vname"] := "vName"
    emailField := Map()
    emailField["label"] := "Email:"
    emailField["vname"] := "vEmail"
    for idx, fieldDef in [nameField, emailField] {
        g.Add("Text", GuiForm(pad, currentY, labelWidth, 23), fieldDef["label"])
        g.Add("Edit", GuiForm(pad + labelWidth + pad, currentY,
                contentWidth - labelWidth - pad, 23, fieldDef["vname"]), "")
        currentY += 23 + pad
    }

    currentY += pad    ; extra section gap

    ; GroupBox with checkboxes
    groupH := 100
    g.Add("GroupBox", GuiForm(pad, currentY, contentWidth, groupH), "Preferences")
    innerY     := currentY + 20
    innerX     := pad * 2
    innerWidth := contentWidth - (pad * 2)

    g.Add("CheckBox", GuiForm(innerX, innerY, innerWidth, 23, "vAutoSave"),
            "Auto-save")
    innerY += 23 + pad
    g.Add("CheckBox", GuiForm(innerX, innerY, innerWidth, 23, "vDarkMode"),
            "Dark mode")
    currentY += groupH + pad * 2

    ; Right-aligned button row
    labels := ["OK", "Cancel", "Apply"]
    btnW   := 80
    btnH   := 28
    totalW := labels.Length * btnW + (labels.Length - 1) * pad
    startX := windowWidth - pad - totalW

    for idx, label in labels {
        x   := startX + (idx - 1) * (btnW + pad)
        btn := g.Add("Button", GuiForm(x, currentY, btnW, btnH), label)
        if (label = "OK")
            btn.OnEvent("Click", (*) => g.Submit())
        else if (label = "Cancel")
            btn.OnEvent("Click", (*) => g.Hide())     ; ✓ Hide() — Close() does not exist on Gui
    }
    currentY += btnH + pad

    ; ✓ window height exactly matches content
    g.Show(Format("w{} h{}", windowWidth, currentY + pad))
    return g
}

CreateProductionGui()

; LAYOUT VALIDATION AUDIT (run mentally before finalizing any TIER 6 GUI)
; Check: single `pad` variable defined — no mixed spacing values
; Check: all control positions derived from pad and currentY
; Check: window height = final currentY + pad
; Check: GuiForm() used for every gui.Add() call
; Check: no gui.Close() calls — use gui.Hide() or gui.Destroy()
; Check: for-loop button rows use (idx - 1) * (btnW + pad) formula
```

## TIER 7 — gForm Relative/Absolute Option Builder
> METHODS COVERED: gForm() · IsNumber() · gui.AddText() · gui.AddEdit() · gui.AddButton() · gui.Submit() · OnEvent() · Bind()

`GuiForm()` (TIER 5) assumes every coordinate is a number computed from `pad`/`currentY`. `gForm()` is the mixed-mode variant: `x` and `y` accept either a number (emitted as `x100`/`y200`) or a string that already carries its own prefix (`"xp"`, `"y+5"`, `"x+10"`, `"ys"`), and `w`/`h` of `0` are dropped from the option string entirely. Use it for layouts that flow relatively from control to control but pin a few coordinates absolutely — a login panel, a toolbar strip, a small settings block. Use `GuiForm()` instead when the layout is fully computed and every value is numeric; do not mix the two helpers inside one window.
```ahk
; x and y accept a number or a string that already carries its own prefix.
; w and h are numbers only — pass 0 (the default) to omit that dimension.
gForm(x := "", y := "", w := 0, h := 0, extra := "") {
    result := ""
    if (x != "")
        result .= (IsNumber(x) ? "x" : "") x
    if (y != "")
        result .= (result ? " " : "") ((IsNumber(y) ? "y" : "") y)
    if (w > 0)
        result .= (result ? " " : "") "w" w
    if (h > 0)
        result .= (result ? " " : "") "h" h
    if (extra != "")
        result .= (result ? " " : "") extra
    return result
}

LoginGui()

class LoginGui {
    __New() {
        this.gui      := Gui("+Resize", "gForm Example")
        this.controls := Map()
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close",  (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        this.CreateControls()
        this.gui.Show()
    }

    CreateControls() {
        ; ✓ a LOCAL alias named "gu" is safe; a local named "gui" would shadow the
        ;   built-in Gui class. this.gui is member access and shadows nothing.
        gu := this.gui
        gu.AddText(gForm(10, 10, 200, 30), "Name:")
        this.controls["user"] := gu.AddEdit(gForm("xp", "y+5", 200, 25, "vUserName"))
        gu.AddText(gForm(10, "y+15", 200, 30), "Password:")
        this.controls["pass"] := gu.AddEdit(gForm("xp", "y+5", 200, 25, "Password vUserPass"))

        this.controls["login"] := gu.AddButton(gForm(10, "y+20", 100, 30, "Default"), "Login")
        this.controls["login"].OnEvent("Click", this.HandleLogin.Bind(this))
        this.controls["cancel"] := gu.AddButton(gForm("x+10", "yp", 100, 30), "Cancel")
        this.controls["cancel"].OnEvent("Click", (*) => this.gui.Hide())
        this.controls["status"] := gu.AddText(gForm(10, "y+20", 210, 20, "Center"), "Ready")
    }

    HandleLogin(*) {
        saved := this.gui.Submit(false)
        this.controls["status"].Value := "Login attempted with: " saved.UserName
    }
}
```

## TIER 8 — Dependency Injection for GUI Classes
> METHODS COVERED: __New() · Map() · Map.Clone() · Map.Get() · Map.Has() · RegExMatch() · OnEvent() · Bind() · try/catch · OutputDebug()

A GUI class that constructs its own data store, validator and logger cannot be exercised without those exact collaborators, and swapping one means editing the window. Pass them in through `__New()` instead: the GUI keeps the window and the wiring, the collaborators keep the behaviour, and a single composition root at the bottom of the script is the only place that names concrete classes. Optional collaborators default to `""` and are guarded once, in a private `Log()`-style wrapper, rather than at every call site. Use this tier whenever a window persists data, validates it, or reports to anything outside itself.
```ahk
; Collaborators are plain classes with no knowledge of the GUI.
class UserRecordService {
    __New() {
        this.records := Map()
        this.nextId  := 1
    }

    Save(userData) {
        if !(userData is Map)
            throw TypeError("Save expects a Map of field values, got " Type(userData))
        id := this.nextId++
        this.records[id] := userData.Clone()
        return id
    }

    Load(id) {
        if !this.records.Has(id)
            throw ValueError("No record with id " id)
        return this.records[id].Clone()
    }
}

class UserValidator {
    Validate(userData) {
        errors := []
        if (userData.Get("name", "") = "")
            errors.Push("Name is required")
        if !RegExMatch(userData.Get("email", ""), "^[^\s@]+@[^\s@]+\.[^\s@]+$")
            errors.Push("Email is not a valid address")
        return errors
    }
}

class DebugLogger {
    Log(message) {
        OutputDebug("[UserGui] " message)
    }
}

class UserGui {
    ; ✓ every collaborator arrives through the constructor; none is created inside
    __New(dataService, validator, logger := "") {
        this.dataService := dataService
        this.validator   := validator
        this.logger      := logger          ; "" = no logger injected
        this.controls    := Map()
        this.gui         := Gui(, "User Management")
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close",  (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        this.CreateControls()
        this.Log("UserGui initialized")
    }

    CreateControls() {
        this.gui.AddText("xm", "Name:")
        this.controls["name"]  := this.gui.AddEdit("xm w220 vName")
        this.gui.AddText("xm", "Email:")
        this.controls["email"] := this.gui.AddEdit("xm w220 vEmail")
        this.controls["save"]  := this.gui.AddButton("xm w220 Default", "Save")
        this.controls["save"].OnEvent("Click", this.HandleSave.Bind(this))
    }

    HandleSave(*) {
        userData := Map()
        userData["name"]  := this.controls["name"].Value
        userData["email"] := this.controls["email"].Value

        errors := this.validator.Validate(userData)
        if errors.Length {
            MsgBox("Cannot save:`n" this.JoinLines(errors), "Validation", "Icon!")
            return
        }
        try {
            id := this.dataService.Save(userData)
            this.Log("Saved record " id)
            MsgBox("Saved as record " id)
        } catch Error as e {
            this.Log("Save failed: " e.Message)
            MsgBox("Save failed: " e.Message, "Error", "Icon!")
        }
    }

    JoinLines(items) {
        out := ""
        for item in items
            out .= item "`n"
        return out
    }

    ; ✓ the optional collaborator is guarded once, here — not at every call site
    Log(message) {
        if this.logger
            this.logger.Log(message)
    }

    Show() {
        this.gui.Show()
    }
}

; ✓ the composition root is the only place that names the concrete classes;
;   swapping UserRecordService for an in-memory fake needs no change to UserGui
app := UserGui(UserRecordService(), UserValidator(), DebugLogger())
app.Show()
```

## TIER 9 — Form-Field Component System
> METHODS COVERED: FormField.CreateField() · FormField.GetValue() · FormField.SetValue() · FormField.AddItems() · FormField.SetEnabled() · FormBuilder.AddField() · FormBuilder.GetField() · FormBuilder.GetFieldValue() · FormBuilder.GetAllValues() · FormBuilder.SetAllValues() · AddText() · AddEdit() · AddComboBox() · AddCheckBox() · switch · RegExMatch()

Wraps label + input + error slot into one `FormField` object, and the collection of them into a `FormBuilder` that offers per-field and bulk get/set. A ten-field registration form becomes ten `AddField()` calls, and reading it back is one `GetAllValues()` returning a `Map()`. Use this tier when a window has more than about four input fields, when the same field set appears in more than one window, or when a validation layer (TIER 10) needs a uniform handle on every input. For a handful of controls, the plain `Map()` of controls from TIER 2 is less machinery for the same result.
```ahk
; FormField — one label + one input + one error slot, created as a unit.
class FormField {
    __New(parentGui, label, type := "Edit", options := "") {
        this.parent  := parentGui
        this.label   := label
        this.type    := type
        this.options := options
        this.CreateField()
    }

    ; ✓ read-only accessors so collaborators never reach into the internals
    Control   => this.inputCtrl
    ErrorCtrl => this.errorCtrl

    CreateField() {
        width := this.ParseWidth(this.options, 200)
        this.labelCtrl := this.parent.AddText("xm Section", this.label . ":")
        switch this.type {
            case "Edit":
                this.inputCtrl := this.parent.AddEdit("xs y+2 " this.options)
            case "ComboBox":
                this.inputCtrl := this.parent.AddComboBox("xs y+2 " this.options)
            case "CheckBox":
                ; the checkbox carries its own caption, so the separate label is redundant
                this.inputCtrl := this.parent.AddCheckBox("xs y+2 " this.options, this.label)
                this.labelCtrl.Visible := false
            default:
                ; ✓ never leave inputCtrl unset — an unknown type must fail loudly here,
                ;   not with an UnsetError the first time GetValue() is called
                throw ValueError('Unsupported FormField type "' this.type '"')
        }
        ; ✓ the error slot is created NOW, in document order. Adding it lazily at
        ;   validation time would place it after whatever control was added last.
        ;   An empty Text needs an explicit w and h or it collapses to nothing.
        this.errorCtrl := this.parent.AddText("xs y+2 h16 cRed w" width, "")
    }

    ParseWidth(options, defaultW) {
        if RegExMatch(options, "i)\bw(\d+)\b", &m)
            return Integer(m[1])
        return defaultW
    }

    GetValue() => this.inputCtrl.Value

    SetValue(value) {
        this.inputCtrl.Value := value
    }

    AddItems(items) {
        if (this.type != "ComboBox")
            throw ValueError("AddItems is only valid on a ComboBox field")
        this.inputCtrl.Add(items)
        return this                      ; ✓ returns this so AddField(...).AddItems(...) chains
    }

    SetEnabled(enabled) {
        this.inputCtrl.Enabled := enabled
    }

    OnEvent(eventName, callback) {
        this.inputCtrl.OnEvent(eventName, callback)
    }
}

; FormBuilder — owns the field collection and the bulk get/set operations.
class FormBuilder {
    __New(parentGui) {
        this.gui    := parentGui
        this.fields := Map()
    }

    AddField(name, label, type := "Edit", options := "") {
        if this.fields.Has(name)
            throw ValueError('Duplicate field name "' name '"')
        field := FormField(this.gui, label, type, options)
        this.fields[name] := field
        return field
    }

    ; ✓ one lookup guard, reused — this.fields[name] on a missing key throws a bare
    ;   UnsetItemError that names nothing useful
    GetField(name) {
        if !this.fields.Has(name)
            throw ValueError('No field named "' name '"')
        return this.fields[name]
    }

    GetFieldValue(name) => this.GetField(name).GetValue()

    SetFieldValue(name, value) {
        this.GetField(name).SetValue(value)
    }

    GetAllValues() {
        values := Map()
        for name, field in this.fields
            values[name] := field.GetValue()
        return values
    }

    SetAllValues(values) {
        for name, value in values {
            if this.fields.Has(name)
                this.fields[name].SetValue(value)
        }
    }
}

UserForm()

class UserForm {
    __New() {
        this.gui := Gui(, "User Registration")
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close",  (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        this.builder := FormBuilder(this.gui)
        this.CreateForm()
        this.gui.Show()
    }

    CreateForm() {
        this.builder.AddField("firstName",  "First Name", "Edit", "w200")
        this.builder.AddField("lastName",   "Last Name",  "Edit", "w200")
        this.builder.AddField("email",      "Email",      "Edit", "w200")
        this.builder.AddField("age",        "Age",        "Edit", "w100 Number")
        this.builder.AddField("gender",     "Gender",     "ComboBox", "w200")
                    .AddItems(["Male", "Female", "Other"])
        this.builder.AddField("newsletter", "Subscribe to newsletter", "CheckBox")

        this.submitBtn := this.gui.AddButton("xm w120 Default", "Submit")
        this.submitBtn.OnEvent("Click", this.SubmitForm.Bind(this))
    }

    SubmitForm(*) {
        formData := this.builder.GetAllValues()
        MsgBox("Form submitted with data:`n" this.FormatData(formData))
    }

    FormatData(data) {
        result := ""
        for key, value in data
            result .= key ": " value "`n"
        return result
    }
}
```

## TIER 10 — Field Validation System
> METHODS COVERED: ValidationRule.Validate() · FieldValidator.AddRule() · Required() · MinLength() · Email() · Number() · FieldValidator.Validate() · FieldValidator.ShowErrors() · StrLen() · IsNumber() · RegExMatch() · Bind()

A `ValidationRule` is a name, a predicate `Func`, and the message shown when the predicate fails. A `FieldValidator` holds an ordered list of them against one input control plus the Text control that displays its error, and exposes chainable shorthands — `.Required().MinLength(2)`. Validation runs on `Change` for live feedback and again over every field on submit. Use this tier for any form where a bad value must be caught before it reaches a data service; wire it to TIER 9 fields with `FieldValidator(field.Control, field.ErrorCtrl)`.
```ahk
; ValidationRule — a name, a predicate Func, and the message shown when it fails.
class ValidationRule {
    __New(name, validator, message) {
        this.name      := name
        this.validator := validator      ; a Func/closure held in a VALUE property
        this.message   := message
    }

    Validate(value) {
        ; ✓ pull the Func into a variable, then call the variable.
        fn := this.validator
        return fn(value)
        ; ✗ return this.validator(value)
        ;   AHK treats that as a METHOD call and prepends the instance as the first
        ;   argument. A one-parameter validator then dies with
        ;   "Error: Too many parameters passed to function"; a two-parameter one
        ;   silently receives the ValidationRule object as its first argument.
    }
}

; FieldValidator — an ordered rule list bound to one input control plus the Text
; control that displays its error. Taking the two controls directly (rather than a
; FormField) keeps it usable with hand-built controls; with the TIER 9 component
; system it is simply FieldValidator(field.Control, field.ErrorCtrl).
class FieldValidator {
    __New(inputCtrl, errorCtrl := "") {
        this.inputCtrl := inputCtrl
        this.errorCtrl := errorCtrl
        this.rules     := []
        this.isValid   := true
    }

    AddRule(name, validator, message) {
        this.rules.Push(ValidationRule(name, validator, message))
        return this                       ; ✓ returns this so rules chain
    }

    Required(message := "This field is required") {
        return this.AddRule("required", (value) => value != "", message)
    }

    MinLength(length, message := "") {
        if (message = "")
            message := "Minimum length is " length " characters"
        ; the fat arrow closes over `length` — each rule keeps its own bound value
        return this.AddRule("minLength", (value) => StrLen(value) >= length, message)
    }

    Email(message := "Please enter a valid email address") {
        return this.AddRule("email",
            (value) => RegExMatch(value, "^[^\s@]+@[^\s@]+\.[^\s@]+$") > 0,
            message)
    }

    ; ✓ A METHOD may be named Number. Built-in shadowing bites variables, parameters,
    ;   loop variables and function names — never a class member, which is resolved
    ;   by member access. Inside the body, Number() would still be the built-in.
    Number(message := "Please enter a valid number") {
        return this.AddRule("number", (value) => IsNumber(value), message)
    }

    Validate() {
        value  := this.inputCtrl.Value
        errors := []
        for rule in this.rules {
            if !rule.Validate(value)
                errors.Push(rule.message)
        }
        this.isValid := errors.Length = 0
        this.ShowErrors(errors)
        return this.isValid
    }

    ; Only the first failure is shown — a stack of messages reflows the whole form.
    ShowErrors(errors) {
        if !this.errorCtrl
            return
        this.errorCtrl.Value := errors.Length ? errors[1] : ""
    }
}

ValidatedForm()

class ValidatedForm {
    __New() {
        this.gui := Gui(, "Validated Form")
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close",  (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        this.controls   := Map()
        this.validators := Map()
        this.CreateForm()
        this.SetupValidation()
        this.gui.Show()
    }

    ; label, input and error slot are added together so the error text sits under
    ; its own field no matter how many fields follow
    AddValidatedField(key, label, options) {
        this.gui.AddText("xm", label . ":")
        this.controls[key]         := this.gui.AddEdit("xm " options)
        this.controls[key "Error"] := this.gui.AddText("xm h16 w220 cRed", "")
    }

    CreateForm() {
        this.AddValidatedField("name",  "Name",  "w220")
        this.AddValidatedField("email", "Email", "w220")
        this.AddValidatedField("age",   "Age",   "w120")
        this.controls["submit"] := this.gui.AddButton("xm w120 Default", "Submit")
        this.controls["submit"].OnEvent("Click", this.SubmitForm.Bind(this))
    }

    SetupValidation() {
        this.validators["name"] := FieldValidator(this.controls["name"], this.controls["nameError"])
            .Required()
            .MinLength(2)

        this.validators["email"] := FieldValidator(this.controls["email"], this.controls["emailError"])
            .Required()
            .Email()

        this.validators["age"] := FieldValidator(this.controls["age"], this.controls["ageError"])
            .Required()
            .Number()

        ; ✓ .Bind(this, validator) freezes THIS validator into the callback. A fat-arrow
        ;   closure over the loop variable would re-read it at call time and validate
        ;   whichever field the loop happened to finish on.
        for key, validator in this.validators
            this.controls[key].OnEvent("Change", this.ValidateOne.Bind(this, validator))
    }

    ValidateOne(validator, *) {
        validator.Validate()
    }

    SubmitForm(*) {
        allValid := true
        for key, validator in this.validators {
            ; ✓ validate every field — an early return would leave later fields
            ;   showing stale (or no) error text
            if !validator.Validate()
                allValid := false
        }
        if allValid
            MsgBox("Form is valid — submitting.")
        else
            MsgBox("Please correct the marked fields and try again.", "Validation", "Icon!")
    }
}
```

## ANTI-PATTERNS

| Pattern | Wrong | Correct | LLM Common Cause |
|---------|-------|---------|------------------|
| v1 command syntax | Comma-separated command-style GUI statements (legacy syntax — does not exist in v2) | `gui.AddText(, "Hello")` | legacy training data dominates; v2 method syntax is less represented |
| No class encapsulation | `g := Gui(...)` at top level with no class | All GUI code in a class `__New()` method | legacy scripts were procedural; LLM generates bare Gui() calls by default |
| Object literal for control storage | `this.ctrls := {btn: ctrl, edit: edit}` | `this.controls := Map()` then `this.controls["btn"] := ctrl` | legacy AutoHotkey used `{}` as dictionaries; LLM carries this habit into v2 |
| `new` keyword for instantiation | `new MyGui()` | `MyGui()` | All mainstream OOP languages (Java, C#, Python) use `new`; LLM defaults to it |
| `gui.Close()` to dismiss window | `gui.Close()` | `gui.Hide()` or `gui.Destroy()` | JavaScript `window.close()` / HTML dialog `.close()` habit |
| Multi-line arrow handler | `(*) => { saved := ...; MsgBox(...) }` | Separate named method + `.Bind(this)` | JavaScript/C# lambdas allow multi-statement bodies; LLM assumes same in AHK |
| Hard-coded Y coordinates | `gui.Add("Edit", "x10 y74 w380 h23")` | `currentY` tracking + `GuiForm()` | LLM doesn't know the GuiForm pattern; emulates raw pixel positioning from other toolkits |
| Zero-based column index in ListView | `lv.GetText(1, 0)` | `lv.GetText(1, 1)` (col is 1-based; row 0 retrieves column headers, not a data row) | Dominant 0-based indexing habit from most language training data |
| Re-enable owner after Destroy | `ownedGui.Destroy(); ownerGui.Opt("-Disabled")` | `ownerGui.Opt("-Disabled")` then `ownedGui.Destroy()` | Linear "close then cleanup" ordering from other modal dialog APIs (WinForms, Qt) |
| Forward-loop ListView delete | `Loop lv.GetCount() { lv.Delete(A_Index) }` | `while (rowNum := lv.GetNext(rowNum)) { lv.Delete(rowNum); rowNum := 0 }` | LLM doesn't model row-number shifting after each delete in indexed collections |
| `"Selected"` as a GetNext mode | `lv.GetNext(row, "Selected")` | `lv.GetNext(row)` — mode omitted already means "next selected"; only `"C"`/`"Checked"` and `"F"`/`"Focused"` are accepted | The word reads like a valid enum value; the real API spells selection as the default, not a mode |
| `""` to leave a Move axis unchanged | `ctrl.Move(x, y, "", "")` | `ctrl.Move(x, y)` — omit the parameter | `""` means "unset" in many APIs; AHK v2 type-checks it as a Number and throws |
| Mixing Gui and Win coordinate spaces | `WinGetPos(&x, &y, , , hwnd)` then `gui.Move(x, y)` | Keep Gui math in logical units; use `WinMove()` only with `WinGetPos()` values | Both look like "pixels"; DPI scaling makes them differ by `A_ScreenDPI/96` |
| Rebuilding controls on every Show() | `CreateControls()` called in `Show()` each time | Guard with `if !this._built` flag; build once in `__New()` | LLM follows a "setup → display" pattern without considering re-entrant calls |

## SEE ALSO

> This module does NOT cover: PixelSearch, ImageSearch, screen overlays, and GDI drawing — use built-in AHK v2 knowledge (no dedicated graphics/screen module yet).
> This module does NOT cover: Hotkey and HotIf rules outside the GUI context (global hotkeys, context-sensitivity beyond HotIfWinExist) — use built-in AHK v2 knowledge (no dedicated input/hotkeys module yet).
> This module does NOT cover: Class inheritance patterns, meta-functions, and OOP design for GUI base classes beyond LayoutAwareGui — see Module_Classes.md
> This module does NOT cover: try/catch wrapping for GUI creation failures and control-access errors — see Module_Errors.md

- PixelSearch, ImageSearch, GDI+, screen coordinate systems, and overlay windows — use built-in AHK v2 knowledge (no dedicated graphics/screen module yet).
- Hotkey(), HotIf(), HotIfWinActive/Exist(), Send(), and global keyboard/mouse input outside the GUI event system — use built-in AHK v2 knowledge (no dedicated input/hotkeys module yet).
- `Module_Classes.md` — Full OOP patterns for extending LayoutAwareGui, meta-function design (`__Get`/`__Set`/`__Call`), and class property declarations.
- `Module_Errors.md` — try/catch patterns for FileOpen, Gui creation failure, and catching MethodError from invalid control access.
- Dark mode and theming — see `.claude/skills/ahk-gui/SKILL.md`, `Lib/_Dark.ahk` (build a normal `Gui()`, wrap it with `dm := _Dark(myGui)`, then add controls via `dm.AddDarkButton()` / `dm.AddDarkEdit()` / `dm.AddDarkComboBox()`), and `Lib/DarkModeModular_Alpha.ahk` (canonical for alpha.30). The DWM title-bar DllCall lives in those libraries — do not duplicate it here.