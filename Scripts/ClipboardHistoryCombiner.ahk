#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

#Include Lib\ClipboardHistory.ahk

ClipboardHistoryViewer()

class ClipboardHistoryViewer {
  static HEADER_TEXT := "<ROLE>`nYou are an elite AutoHotkey v2 engineer. Debug the #Errors and #Warnings shown in the stack trace by following the three-step process defined in <THINKING>.`n</ROLE>`n<THINKING>`n<DEBUGGING_PROCESS>`n    <STEP_1>`n        <TITLE>Identify Error Type</TITLE>`n        Error   = Critical issue preventing execution`n        Warning = Potential issue or unused variable`n        Note    = Informational message`n    </STEP_1>`n    <STEP_2>`n        <TITLE>Extract the Problem Symbol</TITLE>`n        • Locate the line beginning with `"Specifically: <symbol>`"`n        • Record the exact, case-sensitive symbol name (e.g., g_ErrorLogFile, ErrorLoggerConfig)`n    </STEP_2>`n    <STEP_3>`n        <TITLE>Find the Location</TITLE>`n        • Find the arrow marker `"▶ <line#>`"`n        • Inspect that line plus several lines above and below for context`n        • Use this context to understand why the error or warning is raised`n    </STEP_3>`n</DEBUGGING_PROCESS>`n</THINKING>"

  __New() {
    this.items := []
    this.gui := Gui("+Resize +AlwaysOnTop", "Clipboard History Viewer")
    this.gui.SetFont("s10")

    this.controls := Map()
    this.SetupControls()
    this.SetupHotkeys()

    DarkTheme.Apply(this.gui)
    this.gui.Show()

    this.LoadClipboardHistory()
  }

  SetupControls() {
    local BTN_H := 30
    local BTN_W := 90
    local NUM_BUTTONS_IN_ROW := 5

    local X_MARGIN_OPTION := "xm"
    local Y_MARGIN_OPTION := "ym"

    local X_GAP := 10
    local Y_ROW_SPACING := 10

    local TOTAL_CONTENT_WIDTH := (NUM_BUTTONS_IN_ROW * BTN_W) + ((NUM_BUTTONS_IN_ROW - 1) * X_GAP + 2)

    local listHeight := 240
    this.listView := this.gui
      .AddListView(GuiFormat(X_MARGIN_OPTION, Y_MARGIN_OPTION, TOTAL_CONTENT_WIDTH, listHeight, "Checked -Hdr +Multi"), ["Content"])
    this.listView
      .OnEvent("DoubleClick", this.OnDoubleClick.Bind(this))

    local currentY_ForRow := "y+" Y_ROW_SPACING

    this.controls["refreshBtn"] := this.gui
      .AddButton(GuiFormat(X_MARGIN_OPTION, currentY_ForRow, BTN_W, BTN_H), "Refresh")

    this.controls["refreshBtn"]
      .OnEvent("Click", this.LoadClipboardHistory.Bind(this))

    this.controls["checkSelectedBtn"] := this.gui
      .AddButton(GuiFormat("x+" X_GAP, "yp", BTN_W, BTN_H), "Check")

    this.controls["checkSelectedBtn"]
      .OnEvent("Click", this.CheckSelectedRows.Bind(this))

    this.controls["copyBtn"] := this.gui
      .AddButton(GuiFormat("x+" X_GAP, "yp", BTN_W, BTN_H), "Copy")

    this.controls["copyBtn"]
      .OnEvent("Click", this.CopySelected.Bind(this))

    this.controls["combineBtn"] := this.gui
      .AddButton(GuiFormat("x+" X_GAP, "yp", BTN_W, BTN_H), "Combine")

    this.controls["combineBtn"]
      .OnEvent("Click", this.CombineSelected.Bind(this))

    this.controls["selectUntilHashBtn"] := this.gui
      .AddButton(GuiFormat("x+" X_GAP, "yp", BTN_W, BTN_H), "Copy Errors")

    this.controls["selectUntilHashBtn"]
      .OnEvent("Click", this.SelectUntilHashAndCombine.Bind(this))

    this.gui.OnEvent("Close", (*) => this.gui.Hide())
    this.gui.OnEvent("Escape", (*) => this.gui.Hide())
  }

  SetupHotkeys() {
    HotIfWinActive("ahk_id " this.gui.Hwnd)
    Hotkey("^c", this.CopySelected.Bind(this))
    Hotkey("^a", this.SelectAll.Bind(this))
    HotIfWinActive()
  }

  LoadClipboardHistory(*) {
    try {
      this.UpdateStatus("Checking clipboard history...")

      if !ClipboardHistory.IsEnabled {
        this.UpdateStatus("Windows Clipboard History is not enabled! Enable it in Windows Settings > Clipboard.")
        return
      }

      this.items := []
      this.listView.Delete()

      count := 0
      try {
        count := ClipboardHistory.Count
      } catch as err {
        this.UpdateStatus("Error accessing clipboard history count: " err.Message)
        return
      }

      if !count || count = 0 {
        this.UpdateStatus("No items found in clipboard history!")
        return
      }

      this.UpdateStatus("Loading " count " clipboard items...")

      itemsLoaded := 0

      Loop count {
        try {
          currentIndex := A_Index
          clipText := ""

          try {
            clipText := ClipboardHistory.GetText(currentIndex)
          }

          if clipText && clipText != "" {
            preview := this.TruncateText(clipText, 60)
            this.items.Push(Map(
              "index", currentIndex,
              "content", clipText
            ))
            this.listView.Add(, preview)
            itemsLoaded++
          }
        }
      }

      if itemsLoaded > 0 {
        this.listView.Modify(1, "Select Focus")
        this.UpdateStatus("Loaded " itemsLoaded " of " count " clipboard items")
      } else {
        this.UpdateStatus("No text items found in clipboard history")
      }
    } catch as err {
      this.UpdateStatus("Error loading clipboard history: " err.Message)
    }
  }

  TruncateText(text, maxLength) {
    text := RegExReplace(text, "[\r\n\t]+", " ")
    if StrLen(text) > maxLength
      return SubStr(text, 1, maxLength) "..."
    return text
  }

  OnDoubleClick(ctrl, rowNumber) {
    try {
      if rowNumber > 0 && rowNumber <= this.items.Length {
        this.CopyItemByRow(rowNumber)
      }
    } catch as err {
      this.UpdateStatus("Error on double-click: " err.Message)
    }
  }

  CopyItemByRow(rowNumber) {
    if rowNumber > 0 && rowNumber <= this.items.Length {
      A_Clipboard := this.items[rowNumber]["content"]
      this.UpdateStatus("Copied item #" rowNumber)
    }
  }

  SelectAll(*) {
    try {
      Loop this.listView.GetCount() {
        this.listView.Modify(A_Index, "Check")
      }
      this.UpdateStatus("All items selected via hotkey")
    } catch as err {
      this.UpdateStatus("Error selecting all: " err.Message)
    }
  }

  ClearAll(*) {
    try {
      Loop this.listView.GetCount() {
        this.listView.Modify(A_Index, "-Check")
      }
      this.UpdateStatus("All selections cleared")
    } catch as err {
      this.UpdateStatus("Error clearing selection: " err.Message)
    }
  }

  CheckSelectedRows(*) {
    try {
      this.ClearAll()

      selectedRows := []
      totalRows := this.listView.GetCount()
      checkedCount := 0

      static LVM_GETITEMSTATE := 0x102C
      static LVIS_SELECTED := 0x2

      Loop totalRows {
        i := A_Index
        isSelected := SendMessage(LVM_GETITEMSTATE, i - 1, LVIS_SELECTED, this.listView.hwnd) & LVIS_SELECTED
        if isSelected {
          selectedRows.Push(i)
          this.listView.Modify(i, "Check")
          checkedCount++
        }
      }

      if checkedCount > 0
        this.UpdateStatus("Checked " checkedCount " highlighted row(s)")
      else
        this.UpdateStatus("No rows highlighted to check")
    } catch as err {
      this.UpdateStatus("Error checking highlighted rows: " err.Message)
    }
  }

  CopySelected(*) {
    try {
      selectedItems := this.GetSelectedItems()

      if selectedItems.Length = 0 {
        this.UpdateStatus("No items selected!")
        return
      }

      if selectedItems.Length = 1 {
        A_Clipboard := selectedItems[1]["content"]
        this.UpdateStatus("Copied 1 clipboard item")
      } else {
        this.UpdateStatus("Please select only one item for copying or use Combine")
      }
    } catch as err {
      this.UpdateStatus("Error copying: " err.Message)
    }
  }

  RestoreSelected(*) {
    try {
      row := this.listView.GetNext(0, "Focused")
      if !row {
        this.UpdateStatus("No item selected to restore!")
        return
      }

      index := this.items[row]["index"]

      try {
        if ClipboardHistory.SetItemAsContent(index) {
          this.UpdateStatus("Restored item #" index " as current clipboard content")
        } else {
          this.UpdateStatus("Failed to restore clipboard item")
        }
      } catch as err {
        this.UpdateStatus("Error restoring item: " err.Message)
      }
    } catch as err {
      this.UpdateStatus("Error in restore operation: " err.Message)
    }
  }

  CombineSelected(*) {
    try {
      selectedItems := this.GetSelectedItems()

      if selectedItems.Length = 0 {
        this.UpdateStatus("No items selected!")
        return
      }
      combinedText := this.CombineClipboardItems(selectedItems)
      if combinedText = "" {
        this.UpdateStatus("No valid content to combine")
        return
      }
      A_Clipboard := combinedText
      this.UpdateStatus(selectedItems.Length " clipboard item(s) combined and copied")
    } catch as err {
      this.UpdateStatus("Error in combine operation: " err.Message)
    }
  }

  SelectUntilHashAndCombine(*) {
    try {
      this.ClearAll()

      local itemsToCombine := []
      local selectedCount := 0

      Loop this.items.Length {
        local rowNumber := A_Index
        local item := this.items[rowNumber]
        local content := item["content"]

        if StrLen(content) > 0 && SubStr(content, 1, 1) = "#" {
          break
        }
        itemsToCombine.Push(item)
        this.listView.Modify(rowNumber, "Check")
        selectedCount++
      }

      if selectedCount = 0 {
        this.UpdateStatus("No items found before a '#' item or first item starts with '#'.")
        return
      }

      local combinedText := this.CombineClipboardItems(itemsToCombine)

      if combinedText = "" {
        this.UpdateStatus("No valid content to combine from selected items.")
        return
      }

      A_Clipboard := ClipboardHistoryViewer.HEADER_TEXT "`r`n`r`n" combinedText
      this.UpdateStatus(selectedCount " item(s) selected and combined until '#'. Header added.")

    } catch as err {
      this.UpdateStatus("Error in 'Select & Combine Until #' operation: " err.Message)
    }
  }

  GetSelectedItems() {
    selectedItems := []
    checkedRow := 0

    Loop {
      checkedRow := this.listView.GetNext(checkedRow, "Checked")
      if !checkedRow
        break
      if checkedRow <= this.items.Length
        selectedItems.Push(this.items[checkedRow])
    }
    return selectedItems
  }

  CombineClipboardItems(selectedItems) {
    combinedText := ""
    separator := "`r`n`n    ======    Clip    ======    `r`n`n"

    for i, item in selectedItems {
      if item["content"] != "" {
        combinedText .= item["content"]
        if i < selectedItems.Length
          combinedText .= separator
      }
    }
    return combinedText
  }

  UpdateStatus(message) {
    return
  }
}

class DarkTheme {
  static Colors := Map(
    "Background", "0x202020",
    "Controls", "0x404040",
    "Font", "0xE0E0E0"
  )

  static WM_CTLCOLOREDIT := 0x0133
  static WM_CTLCOLORLISTBOX := 0x0134
  static WM_CTLCOLORBTN := 0x0135
  static WM_CTLCOLORSTATIC := 0x0138
  static DC_BRUSH := 18

  static GWL_WNDPROC := -4
  static GWL_STYLE := -16
  static ES_MULTILINE := 0x0004
  static BS_CHECKBOX := 0x0002

  static LVM_GETTEXTCOLOR := 0x1023
  static LVM_SETTEXTCOLOR := 0x1024
  static LVM_GETTEXTBKCOLOR := 0x1025
  static LVM_SETTEXTBKCOLOR := 0x1026
  static LVM_GETBKCOLOR := 0x1000
  static LVM_SETBKCOLOR := 0x1001
  static LVM_GETHEADER := 0x101F

  static TextBgBrush := 0

  static Apply(gui) {
    static procNew := 0, procOld := 0, guiHwnd := 0

    if (!DarkTheme.TextBgBrush) {
      DarkTheme.TextBgBrush := DllCall("gdi32\CreateSolidBrush", "UInt", DarkTheme.Colors["Background"], "Ptr")

      if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        DWMWA_USE_IMMERSIVE_DARK_MODE := 19
        if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
          DWMWA_USE_IMMERSIVE_DARK_MODE := 20

        uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
        SetPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
        FlushMenuThemes := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")

        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", gui.hWnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", true, "Int", 4)
        DllCall(SetPreferredAppMode, "Int", 2)
        DllCall(FlushMenuThemes)
      }

      gui.BackColor := DarkTheme.Colors["Background"]
      guiHwnd := gui.hWnd

      for hWnd, GuiCtrlObj in gui {
        DarkTheme.ThemeControl(GuiCtrlObj)
      }

      WinProc := DarkTheme_WindowProc
      procNew := CallbackCreate(WinProc)
      procOld := DllCall("user32\" (A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"),
        "Ptr", gui.Hwnd, "Int", DarkTheme.GWL_WNDPROC, "Ptr", procNew, "Ptr")
    }

    DarkTheme_WindowProc(hwnd, uMsg, wParam, lParam) {
      if (hwnd = guiHwnd) {
        switch uMsg {
          case DarkTheme.WM_CTLCOLOREDIT, DarkTheme.WM_CTLCOLORLISTBOX:
            DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Font"])
            DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Controls"])
            DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Controls"], "UInt")
            return DllCall("gdi32\GetStockObject", "Int", DarkTheme.DC_BRUSH, "Ptr")

          case DarkTheme.WM_CTLCOLORBTN:
            ctrlHwnd := lParam
            style := DllCall("GetWindowLong", "Ptr", ctrlHwnd, "Int", DarkTheme.GWL_STYLE)

            if (style & DarkTheme.BS_CHECKBOX) {
              DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Font"])
              DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Background"])
              return DarkTheme.TextBgBrush
            } else {
              DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Background"], "UInt")
              return DllCall("gdi32\GetStockObject", "Int", DarkTheme.DC_BRUSH, "Ptr")
            }

          case DarkTheme.WM_CTLCOLORSTATIC:
            DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Font"])
            DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Background"])
            return DarkTheme.TextBgBrush
        }
      }

      return DllCall("user32\CallWindowProc", "Ptr", procOld, "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam)
    }
  }

  static ThemeControl(ctrl) {
    explorerMode := "DarkMode_Explorer"
    cfdMode := "DarkMode_CFD"
    itemsViewMode := "DarkMode_ItemsView"

    switch ctrl.Type {
      case "Button", "ListBox", "UpDown":
        DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", explorerMode, "Ptr", 0)

      case "CheckBox":
        DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", explorerMode, "Ptr", 0)
        ctrl.SetFont("cE0E0E0")

        backBrush := DllCall("CreateSolidBrush", "UInt", DarkTheme.Colors["Background"])
        DllCall("SendMessage", "Ptr", ctrl.hWnd, "UInt", 0x0172, "Ptr", backBrush)

      case "ComboBox", "DDL":
        DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", cfdMode, "Ptr", 0)

      case "Edit":
        isMultiLine := DllCall("user32\" (A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"),
          "Ptr", ctrl.hWnd, "Int", DarkTheme.GWL_STYLE) & DarkTheme.ES_MULTILINE

        themeMode := isMultiLine ? explorerMode : cfdMode
        DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", themeMode, "Ptr", 0)

      case "ListView":
        ctrl.Opt("-Redraw")
        SendMessage(DarkTheme.LVM_SETTEXTCOLOR, 0, DarkTheme.Colors["Font"], ctrl.hWnd)
        SendMessage(DarkTheme.LVM_SETTEXTBKCOLOR, 0, DarkTheme.Colors["Background"], ctrl.hWnd)
        SendMessage(DarkTheme.LVM_SETBKCOLOR, 0, DarkTheme.Colors["Background"], ctrl.hWnd)

        DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", explorerMode, "Ptr", 0)

        LV_Header := SendMessage(DarkTheme.LVM_GETHEADER, 0, 0, ctrl.hWnd)
        DllCall("uxtheme\SetWindowTheme", "Ptr", LV_Header, "Str", itemsViewMode, "Ptr", 0)

        ctrl.Opt("+Redraw")
    }
  }
}

GuiFormat(x, y, w, h, extraParams := "") {
  return GuiFormatBuilder().Position(x, y).Size(w, h).ExtraParams(extraParams).Build()
}

class GuiFormatBuilder {
  _x := ""
  _y := ""
  _w := 0
  _h := 0
  _extraParams := ""

  Position(x, y) {
    this._x := x
    this._y := y
    return this
  }

  Size(w, h) {
    this._w := w
    this._h := h
    return this
  }

  ExtraParams(value) {
    this._extraParams := value
    return this
  }

  Build() {
    params := ""
    if (this._x != "") {
      params .= (IsNumber(this._x) ? "x" : "") this._x
    }

    if (this._y != "") {
      params .= (params == "" ? "" : " ") ((IsNumber(this._y) ? "y" : "") this._y)
    }

    params .= (params == "" ? "" : " ") "w" this._w
    params .= " h" this._h

    if this._extraParams {
      params .= " " this._extraParams
    }
    return Trim(params)
  }
}