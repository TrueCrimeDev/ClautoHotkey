#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

#Include Lib/cJSON.ahk

jsonEditor := ResponsiveListManager()

Esc:: ExitApp()

class ResponsiveListManager {
  static MARGIN := 10
  static PADDING := 10
  static SECTION_SPACING := 10
  static CONTROL_HEIGHT := 28
  static BUTTON_HEIGHT := 32
  static ICON_BTN_SIZE := 32
  static TEXT_BTN_WIDTH := 100
  static BUTTON_GAP := 12
  static COMBO_WIDTH := 150
  static LEFT_PANEL_WIDTH := 235
  static RIGHT_PANEL_WIDTH := 265
  static MIN_GUI_WIDTH := 560
  static MIN_GUI_HEIGHT := 450

  __New() {
    this.InitializeState()
    this.CreateResponsiveGUI()
    this.ApplyDarkTheme()
    this.SetupAllEvents()
    this.LoadInitialData()
    this.gui.Show()
  }

  InitializeState() {
    this.state := Map(
      "currentFile", A_WorkingDir . "\_Lists.json",
      "currentSection", "Calculations",
      "hasUnsavedChanges", false,
      "searchTerm", "",
      "nextId", 1
    )

    this.collections := Map(
      "jsonData", Map(),
      "filteredData", [],
      "undoStack", [],
      "redoStack", []
    )

    this.settings := Map(
      "maxUndoSteps", 50,
      "sections", ["Calculations", "Links", "Prompts", "Snippets"],
      "sectionNames", ["Calculations", "Links", "Prompts", "Snippets"]
    )

    this.controls := Map()
    this.layout := Map()
  }

  CreateResponsiveGUI() {
    this.gui := Gui("+Resize +AlwaysOnTop", "JSON List Editor")
    this.gui.SetFont("s9", "Segoe UI")
    this.gui.MarginX := ResponsiveListManager.MARGIN
    this.gui.MarginY := ResponsiveListManager.MARGIN

    this.CreateHeaderSection()
    this.CreateMainSection()

    this.CalculateInitialDimensions()
  }

  CreateHeaderSection() {
    margin := ResponsiveListManager.MARGIN
    currentY := margin

    this.controls["sectionSelector"] := this.gui.AddComboBox(
      Format("x{} y{} w{} h150",
        margin,
        currentY,
        ResponsiveListManager.COMBO_WIDTH
      ),
      this.settings["sectionNames"]
    )
    this.controls["sectionSelector"].Choose(1)

    buttonX := margin + ResponsiveListManager.COMBO_WIDTH + ResponsiveListManager.BUTTON_GAP

    this.controls["addBtn"] := this.gui.AddButton(
      Format("x{} y{} w{} h{}",
        buttonX,
        currentY,
        ResponsiveListManager.ICON_BTN_SIZE,
        ResponsiveListManager.CONTROL_HEIGHT
      ),
      "+"
    )

    buttonX += ResponsiveListManager.ICON_BTN_SIZE + ResponsiveListManager.BUTTON_GAP

    this.controls["duplicateBtn"] := this.gui.AddButton(
      Format("x{} y{} w{} h{}",
        buttonX,
        currentY,
        ResponsiveListManager.ICON_BTN_SIZE,
        ResponsiveListManager.CONTROL_HEIGHT
      ),
      "⮺"
    )

    buttonX += ResponsiveListManager.ICON_BTN_SIZE + ResponsiveListManager.BUTTON_GAP


    searchX := margin + ResponsiveListManager.LEFT_PANEL_WIDTH + ResponsiveListManager.PADDING
    searchWidth := 180

    this.controls["searchEdit"] := this.gui.AddEdit(
      Format("x{} y{} w{} h{}",
        searchX,
        currentY,
        searchWidth,
        ResponsiveListManager.CONTROL_HEIGHT
      ),
      "Search..."
    )

    this.layout["headerY"] := currentY
    this.layout["headerHeight"] := ResponsiveListManager.CONTROL_HEIGHT
  }

  CreateMainSection() {
    margin := ResponsiveListManager.MARGIN
    mainY := margin + ResponsiveListManager.CONTROL_HEIGHT + ResponsiveListManager.SECTION_SPACING

    this.layout["mainY"] := mainY

    mainContentHeight := ResponsiveListManager.MIN_GUI_HEIGHT - mainY - ResponsiveListManager.MARGIN

    this.controls["bodyEdit"] := this.gui.AddEdit(
      Format("x{} y{} w{} h{} +Multi +WantReturn",
        margin + ResponsiveListManager.LEFT_PANEL_WIDTH + ResponsiveListManager.PADDING,
        mainY,
        ResponsiveListManager.RIGHT_PANEL_WIDTH,
        mainContentHeight
      ),
      ""
    )
  }

  ApplyDarkTheme() {
    this.darkTheme := _Dark(this.gui)

    mainContentHeight := ResponsiveListManager.MIN_GUI_HEIGHT - this.layout["mainY"] - ResponsiveListManager.MARGIN

    this.listView := this.darkTheme.AddListView(
      Format("x{} y{} w{} h{} +LV0x10000",
        ResponsiveListManager.MARGIN,
        this.layout["mainY"],
        ResponsiveListManager.LEFT_PANEL_WIDTH,
        mainContentHeight
      ),
      ["#", "Title", "Body Preview"]
    )

    this.ConfigureListView()
    this.ApplyControlTheming()

    _Dark.ColorEditBorder(this.listView, 0x2D2D2D)
  }

  ConfigureListView() {
    col1Width := 25
    col2Width := 85
    col3Width := ResponsiveListManager.LEFT_PANEL_WIDTH - col1Width - col2Width + 2

    this.listView.ModifyCol(1, col1Width)
    this.listView.ModifyCol(2, col2Width)
    this.listView.ModifyCol(3, col3Width)

    Loop 20 {
      this.listView.Add("", "", "", "")
    }
    this.listView.Delete()

    this.listView.OnEvent("ItemSelect", this.OnItemSelect.Bind(this))
    this.listView.OnEvent("DoubleClick", this.OnItemDoubleClick.Bind(this))
  }

  ApplyControlTheming() {
    _Dark.ColorEditBorder(this.controls["searchEdit"], 0x505050)
    _Dark.ColorEditBorder(this.controls["bodyEdit"], 0x505050)

    this.controls["addBtn"].SetFont("s18 Bold")
    this.controls["duplicateBtn"].SetFont("s14 Bold")

    this.controls["addBtn"].ToolTip := "Add Item (Ctrl+N)"
    this.controls["duplicateBtn"].ToolTip := "Duplicate Item (Ctrl+D)"
    this.controls["searchEdit"].ToolTip := "Search items (Escape to clear)"
    this.controls["sectionSelector"].ToolTip := "Select section"
    this.controls["bodyEdit"].ToolTip := "First line with // becomes the title (shown in list)"

    this.listView.ToolTip := "Double-click to edit item (Tab/Shift+Tab to navigate)"

    this.ApplyComboBoxDarkTheme()
  }

  ApplyComboBoxDarkTheme() {
    static CB_SETITEMHEIGHT := 0x0153
    static CB_SETDROPPEDWIDTH := 0x0160

    DllCall("uxtheme\SetWindowTheme", "Ptr", this.controls["sectionSelector"].hWnd, "Str", "DarkMode_CFD", "Ptr", 0)

    PostMessage(CB_SETITEMHEIGHT, -1, ResponsiveListManager.CONTROL_HEIGHT, this.controls["sectionSelector"])
    PostMessage(CB_SETITEMHEIGHT, 0, 22, this.controls["sectionSelector"])
    DllCall("user32\SendMessage", "Ptr", this.controls["sectionSelector"].hWnd, "UInt", CB_SETDROPPEDWIDTH, "Ptr", 200, "Ptr", 0)

    this.controls["sectionSelector"].SetFont("cFFFFFF")
    DllCall("InvalidateRect", "Ptr", this.controls["sectionSelector"].hWnd, "Ptr", 0, "Int", true)
  }

  CalculateInitialDimensions() {
    totalHeight := ResponsiveListManager.MIN_GUI_HEIGHT
    totalWidth := ResponsiveListManager.MIN_GUI_WIDTH

    this.gui.Show(Format("w{} h{}", totalWidth, totalHeight))
  }

  SetupAllEvents() {
    this.SetupControlEvents()
    this.SetupHotkeys()
    this.gui.OnEvent("Close", this.OnClose.Bind(this))
    this.gui.OnEvent("Size", this.OnResize.Bind(this))
  }

  SetupControlEvents() {
    this.controls["sectionSelector"].OnEvent("Change", this.OnSectionChange.Bind(this))
    this.controls["searchEdit"].OnEvent("Change", this.OnSearchChange.Bind(this))
    this.controls["searchEdit"].OnEvent("Focus", this.OnSearchFocus.Bind(this))
    this.controls["searchEdit"].OnEvent("LoseFocus", this.OnSearchLoseFocus.Bind(this))
    this.controls["bodyEdit"].OnEvent("Change", this.OnBodyChange.Bind(this))

    this.controls["addBtn"].OnEvent("Click", this.OnAddItem.Bind(this))
    this.controls["duplicateBtn"].OnEvent("Click", this.OnDuplicateItem.Bind(this))
  }

  SetupHotkeys() {
    HotIfWinActive("ahk_id " . this.gui.Hwnd)
    Hotkey("Tab", this.OnTabNavigation.Bind(this))
    Hotkey("+Tab", this.OnShiftTabNavigation.Bind(this))
    Hotkey("^z", this.OnUndo.Bind(this))
    Hotkey("^y", this.OnRedo.Bind(this))
    Hotkey("^n", this.OnAddItem.Bind(this))
    Hotkey("^d", this.OnDuplicateItem.Bind(this))
    Hotkey("F5", this.OnReloadFile.Bind(this))
    Hotkey("Escape", this.OnEscapeKey.Bind(this))
    HotIfWinActive()
  }

  OnResize(guiObj, minMax, width, height) {
    if minMax = -1
      return

    margin := ResponsiveListManager.MARGIN
    padding := ResponsiveListManager.PADDING

    searchX := margin + ResponsiveListManager.LEFT_PANEL_WIDTH + padding
    searchWidth := 180
    this.controls["searchEdit"].Move(searchX, , searchWidth)

    mainContentHeight := height - this.layout["mainY"] - margin

    this.listView.Move(, , , mainContentHeight)

    rightPanelX := margin + ResponsiveListManager.LEFT_PANEL_WIDTH + padding
    rightPanelWidth := width - rightPanelX - margin

    this.controls["bodyEdit"].Move(rightPanelX, , rightPanelWidth, mainContentHeight)
  }

  LoadInitialData() {
    this.LoadJSONFile()
    if A_Clipboard != "" {
      this.controls["bodyEdit"].Value := "// " . A_Clipboard . "`n`n"
    }
  }

  GenerateID() {
    return this.state["nextId"]++
  }

  ParseTitleFromBody(body) {
    lines := StrSplit(body, "`n", "`r")
    if lines.Length > 0 {
      firstLine := Trim(lines[1])
      if SubStr(firstLine, 1, 2) = "//" {
        return Trim(SubStr(firstLine, 3))
      }
    }
    return "Untitled"
  }

  UpdateTitleFromBody(item) {
    if item.Has("body") {
      item["title"] := this.ParseTitleFromBody(item["body"])
    }
  }

  OnSectionChange(*) {
    if this.state["hasUnsavedChanges"] {
      result := MsgBox("You have unsaved changes. Save before switching sections?",
        "Unsaved Changes", "YesNoCancel")
      if result = "Yes" {
        this.SaveJSONFile()
      } else if result = "Cancel" {
        return
      }
    }

    selectedIndex := this.controls["sectionSelector"].Value
    this.state["currentSection"] := this.settings["sections"][selectedIndex]
    this.LoadCurrentSection()
  }

  OnAddItem(*) {
    this.SaveState()
    newBody := "// New Item`n`nEnter description here..."
    newItem := Map(
      "id", this.GenerateID(),
      "title", "New Item",
      "body", newBody
    )

    if !this.collections["jsonData"].Has(this.state["currentSection"])
      this.collections["jsonData"][this.state["currentSection"]] := []

    this.collections["jsonData"][this.state["currentSection"]].Push(newItem)
    this.state["hasUnsavedChanges"] := true
    this.ApplyFilter()

    newIndex := this.collections["filteredData"].Length
    if newIndex > 0 {
      this.listView.Modify(newIndex, "Select Focus")
      this.controls["bodyEdit"].Value := newItem["body"]
      this.controls["bodyEdit"].Focus()
    }
  }

  SaveState() {
    currentData := this.GetCurrentSectionData()
    this.collections["undoStack"].Push(this.CloneArray(currentData))
    if this.collections["undoStack"].Length > this.settings["maxUndoSteps"] {
      this.collections["undoStack"].RemoveAt(1)
    }
    this.collections["redoStack"] := []
  }

  GetCurrentSectionData() {
    if this.collections["jsonData"].Has(this.state["currentSection"]) {
      result := []
      for item in this.collections["jsonData"][this.state["currentSection"]] {
        result.Push(Map("title", item["title"], "body", item["body"]))
      }
      return result
    }
    return []
  }

  CloneArray(arr) {
    result := []
    for item in arr {
      newItem := Map("title", item["title"], "body", item["body"])
      if item.Has("id")
        newItem["id"] := item["id"]
      result.Push(newItem)
    }
    return result
  }

  OnClose(*) {
    if this.state["hasUnsavedChanges"] {
      result := MsgBox("You have unsaved changes. Save before closing?",
        "Unsaved Changes", "YesNoCancel")
      if result = "Yes" {
        this.SaveJSONFile()
      } else if result = "Cancel" {
        return
      }
    }

    this.darkTheme.Destroy()
    this.gui.Destroy()
  }

  OnTabNavigation(*) {
    if this.collections["filteredData"].Length = 0
      return

    selected := this.listView.GetNext()
    if selected = 0 {
      this.listView.Modify(1, "Select Focus")
    } else if selected >= this.collections["filteredData"].Length {
      this.listView.Modify(1, "Select Focus")
    } else {
      this.listView.Modify(selected + 1, "Select Focus")
    }
  }

  OnShiftTabNavigation(*) {
    if this.collections["filteredData"].Length = 0
      return

    selected := this.listView.GetNext()
    if selected = 0 || selected = 1 {
      this.listView.Modify(this.collections["filteredData"].Length, "Select Focus")
    } else {
      this.listView.Modify(selected - 1, "Select Focus")
    }
  }

  OnSearchChange(*) {
    searchValue := this.controls["searchEdit"].Value
    if searchValue = "Search..." {
      searchValue := ""
    }
    this.state["searchTerm"] := searchValue
    this.ApplyFilter()
  }

  OnSearchFocus(*) {
    if this.controls["searchEdit"].Value = "Search..." {
      this.controls["searchEdit"].Value := ""
    }
  }

  OnSearchLoseFocus(*) {
    if this.controls["searchEdit"].Value = "" && this.state["searchTerm"] = "" {
      this.controls["searchEdit"].Value := "Search..."
    }
  }

  OnEscapeKey(*) {
    if this.gui.FocusedCtrl = this.controls["searchEdit"] {
      this.controls["searchEdit"].Value := "Search..."
      this.state["searchTerm"] := ""
      this.ApplyFilter()
      this.controls["searchEdit"].Focus()
    }
  }

  OnItemSelect(*) {
    selected := this.listView.GetNext()
    if selected > 0 && selected <= this.collections["filteredData"].Length {
      item := this.collections["filteredData"][selected]
      this.controls["bodyEdit"].Value := item["body"]
    }
  }

  OnItemDoubleClick(*) {
    selected := this.listView.GetNext()
    if selected > 0 && selected <= this.collections["filteredData"].Length {
      item := this.collections["filteredData"][selected]
      this.controls["bodyEdit"].Value := item["body"]
      this.controls["bodyEdit"].Focus()
    }
  }

  OnBodyChange(*) {
    selected := this.listView.GetNext()
    if selected > 0 && selected <= this.collections["filteredData"].Length {
      selectedItem := this.collections["filteredData"][selected]
      newBody := this.controls["bodyEdit"].Value

      selectedItem["body"] := newBody
      this.UpdateTitleFromBody(selectedItem)

      if selectedItem.Has("id") {
        mainIndex := this.FindItemInMainData(selectedItem["id"])
        if mainIndex > 0 {
          this.collections["jsonData"][this.state["currentSection"]][mainIndex]["body"] := newBody
          this.UpdateTitleFromBody(this.collections["jsonData"][this.state["currentSection"]][mainIndex])
        }
      }

      this.state["hasUnsavedChanges"] := true
      this.RefreshListViewItem(selected)
    }
  }

  OnDeleteItem(*) {
    selected := this.listView.GetNext()
    if selected = 0 || selected > this.collections["filteredData"].Length
      return

    result := MsgBox("Are you sure you want to delete this item?",
      "Confirm Delete", "YesNo")
    if result = "Yes" {
      this.SaveState()
      selectedItem := this.collections["filteredData"][selected]

      if selectedItem.Has("id") {
        mainIndex := this.FindItemInMainData(selectedItem["id"])
        if mainIndex > 0 {
          this.collections["jsonData"][this.state["currentSection"]].RemoveAt(mainIndex)
        }
      }

      this.state["hasUnsavedChanges"] := true
      this.ApplyFilter()
      this.controls["bodyEdit"].Value := ""
    }
  }

  OnDuplicateItem(*) {
    selected := this.listView.GetNext()
    if selected > 0 && selected <= this.collections["filteredData"].Length {
      this.SaveState()
      originalItem := this.collections["filteredData"][selected]

      originalTitle := this.ParseTitleFromBody(originalItem["body"])
      newTitle := originalTitle . " (Copy)"
      bodyLines := StrSplit(originalItem["body"], "`n", "`r")
      if bodyLines.Length > 0 && SubStr(Trim(bodyLines[1]), 1, 2) = "//" {
        bodyLines[1] := "// " . newTitle
      } else {
        bodyLines.InsertAt(1, "// " . newTitle)
      }
      newBody := ""
      for line in bodyLines {
        newBody .= line . "`n"
      }
      newBody := RTrim(newBody, "`n")

      newItem := Map(
        "id", this.GenerateID(),
        "title", newTitle,
        "body", newBody
      )

      if originalItem.Has("id") {
        mainIndex := this.FindItemInMainData(originalItem["id"])
        if mainIndex > 0 {
          this.collections["jsonData"][this.state["currentSection"]].InsertAt(mainIndex + 1, newItem)
        } else {
          this.collections["jsonData"][this.state["currentSection"]].Push(newItem)
        }
      } else {
        this.collections["jsonData"][this.state["currentSection"]].Push(newItem)
      }

      this.state["hasUnsavedChanges"] := true
      this.ApplyFilter()

      newSelectedIndex := 0
      for index, item in this.collections["filteredData"] {
        if item.Has("id") && item["id"] = newItem["id"] {
          newSelectedIndex := index
          break
        }
      }

      if newSelectedIndex > 0 {
        this.listView.Modify(newSelectedIndex, "Select Focus")
        this.controls["bodyEdit"].Value := newItem["body"]
        this.controls["bodyEdit"].Focus()
      }
    }
  }

  OnUndo(*) {
    if this.collections["undoStack"].Length > 0 {
      currentData := this.GetCurrentSectionData()
      this.collections["redoStack"].Push(this.CloneArray(currentData))
      restoredData := this.collections["undoStack"].Pop()
      this.collections["jsonData"][this.state["currentSection"]] := this.CloneArray(restoredData)
      this.state["hasUnsavedChanges"] := true
      this.LoadCurrentSection()
    }
  }

  OnRedo(*) {
    if this.collections["redoStack"].Length > 0 {
      currentData := this.GetCurrentSectionData()
      this.collections["undoStack"].Push(this.CloneArray(currentData))
      restoredData := this.collections["redoStack"].Pop()
      this.collections["jsonData"][this.state["currentSection"]] := this.CloneArray(restoredData)
      this.state["hasUnsavedChanges"] := true
      this.LoadCurrentSection()
    }
  }


  OnReloadFile(*) {
    if this.state["hasUnsavedChanges"] {
      result := MsgBox("You have unsaved changes. Reload anyway?",
        "Unsaved Changes", "YesNo")
      if result = "No"
        return
    }
    this.LoadJSONFile()
  }

  LoadJSONFile() {
    try {
      if FileExist(this.state["currentFile"]) {
        content := FileRead(this.state["currentFile"])
        if content = "" {
          this.CreateEmptyStructure()
        } else {
          parsedData := JSON.Load(content)
          this.collections["jsonData"] := this.ConvertParsedDataToMap(parsedData)
          this.ValidateStructure()
          this.AssignMissingIDs()
        }
      } else {
        this.CreateEmptyStructure()
      }

      this.state["hasUnsavedChanges"] := false
      this.collections["undoStack"] := []
      this.collections["redoStack"] := []
      this.LoadCurrentSection()

    } catch Error as e {
      this.CreateEmptyStructure()
      this.LoadCurrentSection()
    }
  }

  SaveJSONFile() {
    try {
      saveData := Map()
      saveData["_metadata"] := Map(
        "version", "1.0",
        "lastModified", FormatTime(, "yyyy-MM-dd"),
        "customCategories", []
      )

      for section in this.settings["sections"] {
        if this.collections["jsonData"].Has(section) {
          cleanedData := []
          for item in this.collections["jsonData"][section] {
            cleanItem := Map("title", item["title"], "body", item["body"])
            cleanedData.Push(cleanItem)
          }
          saveData[section] := cleanedData
        } else {
          saveData[section] := []
        }
      }

      jsonString := JSON.Dump(saveData, 2)

      if FileExist(this.state["currentFile"]) {
        backupPath := this.state["currentFile"] . ".bak"
        FileCopy(this.state["currentFile"], backupPath, 1)
      }

      FileDelete(this.state["currentFile"])
      FileAppend(jsonString, this.state["currentFile"])

      this.state["hasUnsavedChanges"] := false

    } catch Error as e {
      MsgBox("Error saving file: " . e.Message, "Save Error", "Icon_Error")
    }
  }

  CreateEmptyStructure() {
    this.collections["jsonData"] := Map()
    for section in this.settings["sections"] {
      this.collections["jsonData"][section] := []
    }
  }

  ValidateStructure() {
    for section in this.settings["sections"] {
      if !this.collections["jsonData"].Has(section) {
        this.collections["jsonData"][section] := []
      }
    }
  }

  ConvertParsedDataToMap(parsedData) {
    result := Map()

    if Type(parsedData) = "Map" {
      for key, value in parsedData {
        if key != "_metadata" {
          result[key] := this.ConvertToInternalArray(value)
        }
      }
    } else if Type(parsedData) = "Object" {
      for prop in parsedData.OwnProps() {
        if prop != "_metadata" {
          result[prop] := this.ConvertToInternalArray(parsedData.%prop%)
        }
      }
    }

    return result
  }

  ConvertToInternalArray(data) {
    result := []

    if Type(data) = "Array" {
      for item in data {
        if Type(item) = "Map" || Type(item) = "Object" {
          newItem := Map()
          newItem["id"] := this.GetProperty(item, "id", this.GenerateID())
          newItem["body"] := this.GetProperty(item, "body", "")
          newItem["title"] := this.GetProperty(item, "title", "")

          if newItem["body"] != "" {
            parsedTitle := this.ParseTitleFromBody(newItem["body"])
            if parsedTitle != "Untitled" {
              newItem["title"] := parsedTitle
            } else if newItem["title"] != "" {
              newItem["body"] := "// " . newItem["title"] . "`n" . newItem["body"]
            }
          } else if newItem["title"] != "" {
            newItem["body"] := "// " . newItem["title"]
          }

          result.Push(newItem)
        }
      }
    }

    return result
  }

  GetProperty(obj, prop, default := "") {
    if Type(obj) = "Map" {
      return obj.Has(prop) ? obj[prop] : default
    } else if Type(obj) = "Object" {
      return obj.HasOwnProp(prop) ? obj.%prop% : default
    }
    return default
  }

  AssignMissingIDs() {
    for sectionName, sectionData in this.collections["jsonData"] {
      if Type(sectionData) = "Array" {
        for item in sectionData {
          if !item.Has("id") {
            item["id"] := this.GenerateID()
          } else {
            if item["id"] >= this.state["nextId"] {
              this.state["nextId"] := item["id"] + 1
            }
          }
        }
      }
    }
  }

  LoadCurrentSection() {
    if this.collections["jsonData"].Has(this.state["currentSection"]) {
      this.ApplyFilter()
    } else {
      this.collections["filteredData"] := []
      this.RefreshListView()
    }

    this.controls["bodyEdit"].Value := ""
  }

  ApplyFilter() {
    if !this.collections["jsonData"].Has(this.state["currentSection"]) {
      this.collections["filteredData"] := []
      this.RefreshListView()
      return
    }

    unfilteredData := this.ConvertToArray(this.collections["jsonData"][this.state["currentSection"]])
    this.collections["filteredData"] := []

    if this.state["searchTerm"] = "" {
      for item in unfilteredData {
        this.collections["filteredData"].Push(item)
      }
    } else {
      searchLower := StrLower(this.state["searchTerm"])
      for item in unfilteredData {
        titleLower := StrLower(item["title"])

        bodyText := item["body"]
        lines := StrSplit(bodyText, "`n", "`r")
        if lines.Length > 0 && SubStr(Trim(lines[1]), 1, 2) = "//" {
          bodyWithoutTitle := ""
          for i, line in lines {
            if i > 1 {
              if bodyWithoutTitle != ""
                bodyWithoutTitle .= "`n"
              bodyWithoutTitle .= line
            }
          }
          bodyLower := StrLower(bodyWithoutTitle)
        } else {
          bodyLower := StrLower(bodyText)
        }

        if InStr(titleLower, searchLower) || InStr(bodyLower, searchLower) {
          this.collections["filteredData"].Push(item)
        }
      }
    }

    this.RefreshListView()
  }

  ConvertToArray(data) {
    result := []
    if Type(data) = "Array" {
      for item in data {
        if Type(item) = "Map" || Type(item) = "Object" {
          if this.HasProperty(item, "title") && this.HasProperty(item, "body") {
            newItem := Map()
            newItem["id"] := this.GetProperty(item, "id", this.GenerateID())
            newItem["title"] := this.GetProperty(item, "title")
            newItem["body"] := this.GetProperty(item, "body")
            result.Push(newItem)
          } else {
            newItem := Map()
            newItem["id"] := this.GenerateID()
            newItem["title"] := ""
            newItem["body"] := ""
            result.Push(newItem)
          }
        }
      }
    }
    return result
  }

  HasProperty(obj, prop) {
    if Type(obj) = "Map" {
      return obj.Has(prop)
    } else if Type(obj) = "Object" {
      return obj.HasOwnProp(prop)
    }
    return false
  }

  FindItemInMainData(itemId) {
    if !this.collections["jsonData"].Has(this.state["currentSection"])
      return 0

    mainData := this.collections["jsonData"][this.state["currentSection"]]
    for index, item in mainData {
      if item.Has("id") && item["id"] = itemId
        return index
    }
    return 0
  }

  RefreshListView() {
    this.listView.Delete()

    col1Width := 25
    col2Width := 85
    col3Width := ResponsiveListManager.LEFT_PANEL_WIDTH - col1Width - col2Width + 2

    Loop this.collections["filteredData"].Length {
      item := this.collections["filteredData"][A_Index]
      bodyPreview := this.TruncateText(item["body"], 25)
      this.listView.Add("", A_Index, item["title"], bodyPreview)
    }
  }

  RefreshListViewItem(index) {
    if index > 0 && index <= this.collections["filteredData"].Length {
      col1Width := 25
      col2Width := 85
      col3Width := ResponsiveListManager.LEFT_PANEL_WIDTH - col1Width - col2Width + 2

      item := this.collections["filteredData"][index]
      bodyPreview := this.TruncateText(item["body"], 25)
      this.listView.Modify(index, "", index, item["title"], bodyPreview)
    }
  }

  TruncateText(text, maxLength) {
    lines := StrSplit(text, "`n", "`r")

    startLine := 1
    if lines.Length > 0 && SubStr(Trim(lines[1]), 1, 2) = "//" {
      startLine := 2
    }

    previewText := ""
    for i, line in lines {
      if i < startLine
        continue
      lineTrimmed := Trim(line)
      if lineTrimmed = ""
        continue
      if previewText != ""
        previewText .= " "
      previewText .= lineTrimmed
      if StrLen(previewText) > maxLength
        break
    }

    cleanText := Trim(previewText)
    if cleanText = ""
      return ""
    if StrLen(cleanText) > maxLength {
      return SubStr(cleanText, 1, maxLength)
    }
    return cleanText
  }
}

_DarkHeaderCustomDrawCallback(hWnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) {
  static HDM_GETITEM := 0x120B
  static NM_CUSTOMDRAW := -12
  static CDRF_DODEFAULT := 0x00000000
  static CDRF_SKIPDEFAULT := 0x00000004
  static CDRF_NOTIFYITEMDRAW := 0x00000020
  static CDDS_PREPAINT := 0x00000001
  static CDDS_ITEMPREPAINT := 0x00010001
  static DC_BRUSH := 18
  static OHWND := 0
  static OMsg := (2 * A_PtrSize)
  static ODrawStage := OMsg + A_PtrSize
  static OHDC := ODrawStage + A_PtrSize
  static ORect := OHDC + A_PtrSize
  static OItemSpec := OHDC + 16 + A_PtrSize
  static LM := 4
  static TM := 6
  static TRANSPARENT := 1

  if (uMsg = 0x4E) {
    HWND := NumGet(lParam + OHWND, "UPtr")
    if _Dark.ControlMaps["HeaderColors"].Has(HWND) && HC := _Dark.ControlMaps["HeaderColors"][HWND] {
      Code := NumGet(lParam + OMsg, "Int")
      if (Code = NM_CUSTOMDRAW) {
        DrawStage := NumGet(lParam + ODrawStage, "UInt")
        if (DrawStage = CDDS_ITEMPREPAINT) {
          Item := NumGet(lParam + OItemSpec, "Ptr")
          HDITEM := Buffer(24 + (6 * A_PtrSize), 0)
          ItemTxt := Buffer(520, 0)
          NumPut("UInt", 0x86, HDITEM, 0)
          NumPut("ptr", ItemTxt.Ptr, HDITEM, 8)
          NumPut("int", 260, HDITEM, 8 + (2 * A_PtrSize))
          DllCall("SendMessage", "Ptr", HWND, "UInt", HDM_GETITEM, "Ptr", Item, "Ptr", HDITEM)
          Fmt := NumGet(HDITEM, 12 + (2 * A_PtrSize), "UInt") & 3
          Order := NumGet(HDITEM, 20 + (3 * A_PtrSize), "Int")
          HDC := NumGet(lParam + OHDC, "Ptr")

          dcBrush := DllCall("GetStockObject", "UInt", DC_BRUSH, "ptr")
          DllCall("SetDCBrushColor", "Ptr", HDC, "UInt", HC["Bkg"])
          DllCall("FillRect", "Ptr", HDC, "Ptr", lParam + ORect, "Ptr", dcBrush)

          DllCall("SetBkMode", "Ptr", HDC, "UInt", TRANSPARENT)
          DllCall("SetTextColor", "Ptr", HDC, "UInt", 0xFFFFFF)
          DllCall("InflateRect", "Ptr", lParam + ORect, "Int", -TM, "Int", 0)
          DT_ALIGN := 0x0224 + ((Fmt & 1) ? 2 : (Fmt & 2) ? 1 : 0)
          DllCall("DrawText", "Ptr", HDC, "Ptr", ItemTxt, "Int", -1, "Ptr", lParam + ORect, "UInt", DT_ALIGN)
          return CDRF_SKIPDEFAULT
        }
        if (DrawStage = CDDS_PREPAINT) {
          HDC := NumGet(lParam + OHDC, "Ptr")
          dcBrush := DllCall("GetStockObject", "UInt", DC_BRUSH, "ptr")
          DllCall("SetDCBrushColor", "Ptr", HDC, "UInt", HC["Bkg"])
          DllCall("FillRect", "Ptr", HDC, "Ptr", lParam + ORect, "Ptr", dcBrush)
          return CDRF_NOTIFYITEMDRAW
        }
        return CDRF_DODEFAULT
      }
    }
  } else if (uMsg = 0x02) {
    if _Dark.ControlMaps["ControlCallbacks"].Has(hWnd) {
      callback := _Dark.ControlMaps["ControlCallbacks"][hWnd]
      DllCall("RemoveWindowSubclass", "Ptr", hWnd, "Ptr", callback, "Ptr", hWnd)
      CallbackFree(callback)
      _Dark.ControlMaps["ControlCallbacks"].Delete(hWnd)
    }
  }
  return DllCall("DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}

class _Dark {

  static Dark := Map(
    "Background", 0x171717,
    "Controls", 0x1b1b1b,
    "Font", 0xE0E0E0,
    "Accent", 0x0078D7
  )

  static SystemData := Map(
    "Instances", Map(),
    "WindowProcOldMap", Map(),
    "WindowProcCallbacks", Map(),
    "TextBackgroundBrush", 0,
    "ControlsBackgroundBrush", 0
  )

  static ControlMaps := Map(
    "ButtonColors", Map(),
    "ComboBoxes", Map(),
    "TextControls", Map(),
    "GroupBoxes", Map(),
    "HeaderColors", Map(),
    "ControlCallbacks", Map(),
    "EditBorderData", Map(),
    "ComboBoxMonitors", Map(),
    "MonitorTimers", Map()
  )

  static Constants := Map(
    "WM_CTLCOLOREDIT", 0x0133,
    "WM_CTLCOLORLISTBOX", 0x0134,
    "WM_CTLCOLORBTN", 0x0135,
    "WM_CTLCOLORSTATIC", 0x0138,
    "WM_COMMAND", 0x0111,
    "WM_NOTIFY", 0x004E,
    "GWL_WNDPROC", -4
  )

  static GetWindowLong := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
  static SetWindowLong := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"

  static __New() {
    global _Dark_WindowProc := ObjBindMethod(_Dark, "ProcessWindowMessage")
    if !_Dark.SystemData["TextBackgroundBrush"]
      _Dark.SystemData["TextBackgroundBrush"] := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Background"], "Ptr")
    if !_Dark.SystemData["ControlsBackgroundBrush"]
      _Dark.SystemData["ControlsBackgroundBrush"] := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Controls"], "Ptr")
  }

  __New(GuiObj) {
    _Dark.__New()
    this.Gui := GuiObj
    this.Gui.BackColor := _Dark.Dark["Background"]
    this.IsDestroyed := false

    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
      attr := 19
      if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
        attr := 20
      try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Gui.hWnd, "Int", attr, "Int*", true, "Int", 4)
      try _Dark.TryEnableAppDarkMode()
    }

    this.SetControlsTheme()
    this.SetupWindowProc()
    this.RedrawAllControls()
    _Dark.SystemData["Instances"][this.Gui.Hwnd] := this
    return this
  }

  static TryEnableAppDarkMode() {
    try {
      hUx := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
      pSetPref := DllCall("kernel32\GetProcAddress", "Ptr", hUx, "Ptr", 135, "Ptr")
      pFlush := DllCall("kernel32\GetProcAddress", "Ptr", hUx, "Ptr", 136, "Ptr")
      if (pSetPref)
        DllCall(pSetPref, "Int", 2)
      if (pFlush)
        DllCall(pFlush)
    }
  }

  SetupWindowProc() {
    hwnd := this.Gui.Hwnd
    if _Dark.SystemData["WindowProcOldMap"].Has(hwnd)
      return
    cb := CallbackCreate(_Dark_WindowProc, , 4)
    _Dark.SystemData["WindowProcCallbacks"][hwnd] := cb
    orig := DllCall(_Dark.SetWindowLong, "Ptr", hwnd, "Int", _Dark.Constants["GWL_WNDPROC"], "Ptr", cb, "Ptr")
    _Dark.SystemData["WindowProcOldMap"][hwnd] := orig
  }

  static ProcessWindowMessage(hwnd, msg, wParam, lParam, *) {
    if !_Dark.SystemData["WindowProcOldMap"].Has(hwnd)
      return DllCall("DefWindowProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")

    oldProc := _Dark.SystemData["WindowProcOldMap"][hwnd]

    switch msg {
      case _Dark.Constants["WM_COMMAND"]:
        code := (wParam >> 16) & 0xFFFF
        if (code = 7) {
          combo := lParam
          if _Dark.ControlMaps["ComboBoxes"].Has(combo)
            _Dark.RefreshComboBoxTheme(combo)
        }
      case _Dark.Constants["WM_CTLCOLOREDIT"]:
        DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Controls"])
        DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
        return _Dark.SystemData["ControlsBackgroundBrush"]
      case _Dark.Constants["WM_CTLCOLORLISTBOX"]:
        DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Controls"])
        DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
        return _Dark.SystemData["ControlsBackgroundBrush"]
      case _Dark.Constants["WM_CTLCOLORBTN"]:
        DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Controls"])
        DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
        return _Dark.SystemData["ControlsBackgroundBrush"]
      case _Dark.Constants["WM_CTLCOLORSTATIC"]:
        DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Background"])
        DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
        return _Dark.SystemData["TextBackgroundBrush"]
    }
    return DllCall("CallWindowProc", "Ptr", oldProc, "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
  }

  static RegisterComboBoxForMonitoring(control) {
    if !control || !control.HasOwnProp("Hwnd")
      return false

    controlHwnd := control.Hwnd
    _Dark.ControlMaps["ComboBoxMonitors"][controlHwnd] := control

    monitorCallback := _Dark.MonitorComboBoxDropdown.Bind(controlHwnd)
    _Dark.ControlMaps["MonitorTimers"][controlHwnd] := monitorCallback
    SetTimer(monitorCallback, 50)

    control.OnEvent("Focus", (*) => _Dark.RefreshComboTheme(control))
    return true
  }

  static UnregisterComboBoxMonitoring(controlHwnd) {
    if _Dark.ControlMaps["MonitorTimers"].Has(controlHwnd) {
      SetTimer(_Dark.ControlMaps["MonitorTimers"][controlHwnd], 0)
      _Dark.ControlMaps["MonitorTimers"].Delete(controlHwnd)
    }
    if _Dark.ControlMaps["ComboBoxMonitors"].Has(controlHwnd) {
      _Dark.ControlMaps["ComboBoxMonitors"].Delete(controlHwnd)
    }
  }

  static RefreshComboTheme(control) {
    if !_Dark.ValidateControl(control)
      return

    SetTimer(_Dark.DelayedComboThemeRefresh.Bind(control), -10)
  }

  static DelayedComboThemeRefresh(control) {
    if !_Dark.ValidateControl(control)
      return

    static CB_GETCOMBOBOXINFO := 0x164

    try {
      comboInfo := Buffer(60, 0)
      NumPut("UInt", 60, comboInfo, 0)
      controlHwnd := control.hWnd

      if !controlHwnd || controlHwnd = ""
        return

      if DllCall("user32\GetComboBoxInfo", "Ptr", controlHwnd, "Ptr", comboInfo) {
        editHwnd := NumGet(comboInfo, A_PtrSize + 4, "Ptr")
        listHwnd := NumGet(comboInfo, A_PtrSize + 8, "Ptr")
        buttonHwnd := NumGet(comboInfo, A_PtrSize + 12, "Ptr")

        if editHwnd {
          DllCall("uxtheme\SetWindowTheme", "Ptr", editHwnd, "Str", "DarkMode_CFD", "Ptr", 0)
        }

        if buttonHwnd {
          DllCall("uxtheme\SetWindowTheme", "Ptr", buttonHwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        }

        if listHwnd {
          _Dark.ControlMaps["ComboBoxes"][listHwnd] := true
          DllCall("uxtheme\SetWindowTheme", "Ptr", listHwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
          DllCall("InvalidateRect", "Ptr", listHwnd, "Ptr", 0, "Int", true)
        }
      }
    } catch {
      return
    }
  }

  static MonitorComboBoxDropdown(controlHwnd) {
    if !_Dark.ControlMaps["ComboBoxMonitors"].Has(controlHwnd)
      return

    control := _Dark.ControlMaps["ComboBoxMonitors"][controlHwnd]
    if !_Dark.ValidateControl(control)
      return

    static CB_GETCOMBOBOXINFO := 0x164
    static CB_GETDROPPEDSTATE := 0x0157

    try {
      if !controlHwnd || controlHwnd = ""
        return

      isDropped := DllCall("user32\SendMessage", "Ptr", controlHwnd, "UInt", CB_GETDROPPEDSTATE, "Ptr", 0, "Ptr", 0)

      if isDropped {
        comboInfo := Buffer(60, 0)
        NumPut("UInt", 60, comboInfo, 0)
        if DllCall("user32\GetComboBoxInfo", "Ptr", controlHwnd, "Ptr", comboInfo) {
          listHwnd := NumGet(comboInfo, A_PtrSize + 8, "Ptr")
          if listHwnd && !_Dark.ControlMaps["ComboBoxes"].Has(listHwnd) {
            _Dark.ControlMaps["ComboBoxes"][listHwnd] := true
            DllCall("uxtheme\SetWindowTheme", "Ptr", listHwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
            DllCall("InvalidateRect", "Ptr", listHwnd, "Ptr", 0, "Int", true)
          }
        }
      }
    } catch {
      return
    }
  }

  static ValidateControl(control) {
    if !control
      return false

    try {
      hwnd := control.hWnd
      return hwnd && hwnd != ""
    } catch {
      return false
    }
  }

  static ColorEditBorder(control, color) {
    static WM_NCPAINT := 0x0085

    if _Dark.ControlMaps["EditBorderData"].Has(control.Hwnd)
      return control

    prevProc := DllCall("GetWindowLongPtr", "Ptr", control.Hwnd, "Int", -4, "Ptr")
    if !prevProc
      return control

    borderData := Map(
      "color", color,
      "prevProc", prevProc
    )
    _Dark.ControlMaps["EditBorderData"][control.Hwnd] := borderData

    EditProc(hwnd, uMsg, wParam, lParam) {
      if !_Dark.ControlMaps["EditBorderData"].Has(hwnd)
        return DllCall("DefWindowProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")

      if (uMsg = WM_NCPAINT) {
        hdc := DllCall("GetWindowDC", "Ptr", hwnd, "Ptr")
        if (hdc) {
          rect := Buffer(16, 0)
          DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect)
          w := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")
          h := NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")

          data := _Dark.ControlMaps["EditBorderData"][hwnd]
          pen := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", data["color"], "Ptr")
          old := DllCall("SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")

          DllCall("MoveToEx", "Ptr", hdc, "Int", 0, "Int", 0, "Ptr", 0)
          DllCall("LineTo", "Ptr", hdc, "Int", w - 1, "Int", 0)
          DllCall("LineTo", "Ptr", hdc, "Int", w - 1, "Int", h - 1)
          DllCall("LineTo", "Ptr", hdc, "Int", 0, "Int", h - 1)
          DllCall("LineTo", "Ptr", hdc, "Int", 0, "Int", 0)

          DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
          DllCall("DeleteObject", "Ptr", pen)
          DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
          return 0
        }
      }

      data := _Dark.ControlMaps["EditBorderData"][hwnd]
      return DllCall("CallWindowProc", "Ptr", data["prevProc"], "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    cb := CallbackCreate(EditProc, , 4)
    if cb {
      if DllCall("SetWindowLongPtr", "Ptr", control.Hwnd, "Int", -4, "Ptr", cb, "Ptr") {
        borderData["callback"] := cb
        DllCall("SendMessage", "Ptr", control.Hwnd, "UInt", WM_NCPAINT, "Ptr", 1, "Ptr", 0)
      } else {
        CallbackFree(cb)
        _Dark.ControlMaps["EditBorderData"].Delete(control.Hwnd)
      }
    }
    return control
  }

  AddListView(opts, headers) {
    lv := this.Gui.Add("ListView", opts, headers)

    static ListViewConstants := Map(
      "LVM_SETBKCOLOR", 0x1001,
      "LVM_SETTEXTCOLOR", 0x1033,
      "LVM_SETTEXTBKCOLOR", 0x1026,
      "LVM_SETOUTLINECOLOR", 0x10B1,
      "LVM_SETEXTENDEDLISTVIEWSTYLE", 0x1036,
      "LVS_EX_DOUBLEBUFFER", 0x10000,
      "LVS_EX_GRIDLINES", 0x0001,
      "LVS_EX_FULLROWSELECT", 0x00000020,
      "WM_CHANGEUISTATE", 0x0127,
      "UIS_SET", 1,
      "UISF_HIDEFOCUS", 0x1,
      "LVM_GETHEADER", 0x101F
    )

    bg := _Dark.Dark["Background"]
    fg := 0xFFFFFF
    grid := 0x3A3A3A

    _Dark.SendMessage(ListViewConstants["LVM_SETBKCOLOR"], 0, bg, lv.Hwnd)
    _Dark.SendMessage(ListViewConstants["LVM_SETTEXTCOLOR"], 0, fg, lv.Hwnd)
    _Dark.SendMessage(ListViewConstants["LVM_SETTEXTBKCOLOR"], 0, bg, lv.Hwnd)
    _Dark.SendMessage(ListViewConstants["LVM_SETEXTENDEDLISTVIEWSTYLE"],
      ListViewConstants["LVS_EX_DOUBLEBUFFER"] | ListViewConstants["LVS_EX_FULLROWSELECT"],
      ListViewConstants["LVS_EX_DOUBLEBUFFER"] | ListViewConstants["LVS_EX_FULLROWSELECT"], lv.Hwnd)
    _Dark.SendMessage(ListViewConstants["LVM_SETOUTLINECOLOR"], 0, grid, lv.Hwnd)

    DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
    lv.SetFont("cFFFFFF")

    headerHwnd := _Dark.SendMessage(ListViewConstants["LVM_GETHEADER"], 0, 0, lv.Hwnd)
    if headerHwnd {
      DllCall("uxtheme\SetWindowTheme", "Ptr", headerHwnd, "Str", "", "Ptr", 0)

      static HDM_LAYOUT := 0x1205
      _Dark.SendMessage(HDM_LAYOUT, 0, 0, headerHwnd)
    }

    _Dark.SetListViewHeaderColors(lv, 0x1b1b1b, 0xFFFFFF)
    _Dark.SendMessage(ListViewConstants["WM_CHANGEUISTATE"],
      (ListViewConstants["UIS_SET"] << 8) | ListViewConstants["UISF_HIDEFOCUS"], 0, lv.Hwnd)

    DllCall("InvalidateRect", "Ptr", lv.Hwnd, "Ptr", 0, "Int", true)
    if headerHwnd {
      DllCall("InvalidateRect", "Ptr", headerHwnd, "Ptr", 0, "Int", true)
      DllCall("UpdateWindow", "Ptr", headerHwnd)
    }
    return lv
  }

  static SetListViewHeaderColors(ListViewCtrl, BackgroundColor?, TextColor?) {
    HHDR := _Dark.SendMessage(0x101F, 0, 0, ListViewCtrl.Hwnd)
    if !(IsSet(BackgroundColor) || IsSet(TextColor)) && (_Dark.ControlMaps["HeaderColors"].Has(HHDR)) {
      return (_Dark.ControlMaps["HeaderColors"].Delete(HHDR), DllCall("RedrawWindow", "Ptr", ListViewCtrl.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0001))
    } else if (IsSet(BackgroundColor) && IsSet(TextColor)) {
      if !(_Dark.ControlMaps["HeaderColors"].Has(HHDR)) {
        _Dark.SubclassControl(ListViewCtrl, _DarkHeaderCustomDrawCallback)
      }
      BackgroundColor := _Dark.RGBtoBGR(BackgroundColor)
      TextColor := TextColor = 0xFFFFFF ? 0xFFFFFF : _Dark.RGBtoBGR(TextColor)
      _Dark.ControlMaps["HeaderColors"][HHDR] := Map("Txt", TextColor, "Bkg", BackgroundColor)
    }
    DllCall("RedrawWindow", "Ptr", ListViewCtrl.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0001)
  }

  static SubclassControl(ctrl, func6, data := 0) {
    hwnd := HasProp(ctrl, "Hwnd") ? ctrl.Hwnd : ctrl

    if _Dark.ControlMaps["ControlCallbacks"].Has(hwnd) {
      DllCall("RemoveWindowSubclass", "Ptr", hwnd, "Ptr", _Dark.ControlMaps["ControlCallbacks"][hwnd], "Ptr", hwnd)
      CallbackFree(_Dark.ControlMaps["ControlCallbacks"][hwnd])
      _Dark.ControlMaps["ControlCallbacks"].Delete(hwnd)
    }
    if !(func6 is Func && func6.MaxParams = 6)
      return false
    cb := CallbackCreate(func6, "F", 6)
    if !cb
      return false
    if !DllCall("SetWindowSubclass", "Ptr", hwnd, "Ptr", cb, "Ptr", hwnd, "Ptr", data) {
      CallbackFree(cb)
      return false
    }
    _Dark.ControlMaps["ControlCallbacks"][hwnd] := cb
    return true
  }

  static SendMessage(msg, wParam, lParam, hwndOrCtrl) {
    hwnd := HasProp(hwndOrCtrl, "Hwnd") ? hwndOrCtrl.Hwnd : hwndOrCtrl
    return DllCall("user32\SendMessage", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
  }

  static RGBtoBGR(rgb) {
    if (!IsNumber(rgb))
      rgb := Integer("0x" . rgb)
    if (rgb = 0xFFFFFF)
      return 0xFFFFFF
    return ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb & 0xFF0000) >> 16)
  }

  static RefreshComboBoxTheme(comboHwnd) {
    static CB_GETCOMBOBOXINFO := 0x164
    info := Buffer(60, 0)
    NumPut("UInt", 60, info, 0)
    if DllCall("user32\GetComboBoxInfo", "Ptr", comboHwnd, "Ptr", info) {
      listH := NumGet(info, A_PtrSize + 8, "Ptr")
      if listH {
        _Dark.ControlMaps["ComboBoxes"][listH] := true
        DllCall("uxtheme\SetWindowTheme", "Ptr", listH, "Str", "DarkMode_Explorer", "Ptr", 0)
        DllCall("InvalidateRect", "Ptr", listH, "Ptr", 0, "Int", true)
      }
    }
  }

  SetControlsTheme() {
    for _, c in this.Gui {
      switch c.Type {
        case "Edit":
          DllCall("uxtheme\SetWindowTheme", "Ptr", c.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
          c.SetFont("cFFFFFF")
        case "ComboBox", "DDL":
          DllCall("uxtheme\SetWindowTheme", "Ptr", c.Hwnd, "Str", "DarkMode_CFD", "Ptr", 0)
          _Dark.ControlMaps["ComboBoxes"][c.Hwnd] := true
          c.SetFont("cFFFFFF")
          _Dark.RegisterComboBoxForMonitoring(c)
        case "Button", "CheckBox", "Radio", "DateTime", "Tab3", "TreeView", "ListBox", "UpDown", "GroupBox":
          DllCall("uxtheme\SetWindowTheme", "Ptr", c.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
          c.SetFont("cFFFFFF")
        case "Text", "Link":
          c.Opt("cFFFFFF")
      }
      DllCall("InvalidateRect", "Ptr", c.Hwnd, "Ptr", 0, "Int", true)
    }
  }

  RedrawAllControls() {
    DllCall("RedrawWindow", "Ptr", this.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0285)
    for _, c in this.Gui {
      DllCall("InvalidateRect", "Ptr", c.Hwnd, "Ptr", 0, "Int", true)
    }
  }

  Destroy() {
    this.IsDestroyed := true

    for controlHwnd in _Dark.ControlMaps["ComboBoxMonitors"].Clone() {
      _Dark.UnregisterComboBoxMonitoring(controlHwnd)
    }

    Sleep(20)
    if _Dark.SystemData["Instances"].Has(this.Gui.Hwnd) {
      _Dark.SystemData["Instances"].Delete(this.Gui.Hwnd)
    }
  }
}