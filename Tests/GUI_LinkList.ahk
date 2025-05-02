#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

ClipboardURLOpener()

class ClipboardURLOpener {
    static Config := Map(
        "windowTitle", "Clipboard URL Opener",
        "windowWidth", 700,
        "windowHeight", 600,
        "browser", "msedge.exe",
        "defaultPrefix", "https://www.",
        "defaultAppend", ".com",
        "padX", 10,
        "padY", 10,
        "columns", Map(
            1, Map("name", "Prefix", "width", 100, "auto", false),
            2, Map("name", "Line Content", "width", 100, "auto", false),
            3, Map("name", "Append", "width", 100, "auto", false),
            4, Map("name", "Full URL", "width", 300, "auto", false)
        )
    )

    __New() {
        this.lines := []
        this.cmdManager := CommandManager()
        this.RegisterCommands()

        this.prefixEdit := ""
        this.appendEdit := ""
        this.loadButton := ""
        this.openButton := ""
        this.copyAllButton := ""
        this.previewTextCtrl := ""
        this.previewBox := ""
        this.listTextCtrl := ""
        this.listView := ""

        this.InitializeGUI()
        this.SetupHotkeys()
        this.gui.Show("w" ClipboardURLOpener.Config["windowWidth"] " h" ClipboardURLOpener.Config["windowHeight"])
        this.cmdManager.Execute("LoadClipboard", false)
    }

    RegisterCommands() {
        this.cmdManager
            .Register("LoadClipboard", this.LoadClipboard.Bind(this))
            .Register("UpdateSelectedPreview", this.UpdateSelectedPreview.Bind(this))
            .Register("UpdateAllPreviews", this.UpdateAllPreviews.Bind(this))
            .Register("OpenUrlInNewTab", this.OpenUrlInNewTab.Bind(this))
            .Register("OpenSelectedURL", this.OpenSelectedURL.Bind(this))
            .Register("CopyAllUrlsToClipboard", this.CopyAllUrlsToClipboard.Bind(this))
            .Register("CopySelectedUrlNoSpaces", this.CopySelectedUrlNoSpaces.Bind(this))
    }

    InitializeGUI() {
        local padX := ClipboardURLOpener.Config["padX"]
        local padY := ClipboardURLOpener.Config["padY"]
        local columnConfig := ClipboardURLOpener.Config["columns"]
        local columnNames := []
        local windowWidth := ClipboardURLOpener.Config["windowWidth"]

        for i, colInfo in columnConfig
            columnNames.Push(colInfo["name"])

        this.gui := Gui("+Resize", ClipboardURLOpener.Config["windowTitle"])
        this.gui.SetFont("s10")

        this.gui.OnEvent("Close", (*) => this.gui.Destroy())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        this.gui.OnEvent("Size", this.OnGuiSize.Bind(this))

        ; Row 1: Prefix and Append Edits
        this.gui.AddText("x" padX " y" padY, "Prefix:")
        this.prefixEdit := this.gui.AddEdit("x+10 y" padY " w200", ClipboardURLOpener.Config["defaultPrefix"])
        this.prefixEdit.OnEvent("Change", (*) => this.cmdManager.Execute("UpdateAllPreviews"))

        this.gui.AddText("x+10 y" padY, "Append:")
        this.appendEdit := this.gui.AddEdit("x+10 y" padY " w200", ClipboardURLOpener.Config["defaultAppend"])
        this.appendEdit.OnEvent("Change", (*) => this.cmdManager.Execute("UpdateAllPreviews"))

        ; Row 2: Buttons
        this.loadButton := this.gui.AddButton("x" padX " y+10 w120", "Load Clipboard")
        this.loadButton.OnEvent("Click", (*) => this.cmdManager.Execute("LoadClipboard", true))

        this.openButton := this.gui.AddButton("x+10 yp w120", "Open Selected")
        this.openButton.OnEvent("Click", (*) => this.cmdManager.Execute("OpenSelectedURL"))

        this.copyAllButton := this.gui.AddButton("x+10 yp w120", "Copy All URLs")
        this.copyAllButton.OnEvent("Click", (*) => this.cmdManager.Execute("CopyAllUrlsToClipboard"))

        ; Row 3: Preview
        this.previewTextCtrl := this.gui.AddText("x" padX " y+10", "Preview:")
        this.previewBox := this.gui.AddEdit("x" padX " y+5 w" (windowWidth - 2 * padX) " ReadOnly", "")

        ; Row 4: ListView
        this.listTextCtrl := this.gui.AddText("x" padX " y+10", "URL List:")
        this.listView := this.gui.AddListView("x" padX " y+5 w" (windowWidth - 2 * padX) " h400 Grid", columnNames)
        this.listView.OnEvent("ItemSelect", (*) => this.cmdManager.Execute("UpdateSelectedPreview"))
        this.listView.OnEvent("DoubleClick", (*) => this.cmdManager.Execute("OpenUrlInNewTab"))

        this.ApplyColumnWidths()
    }

    ApplyColumnWidths() {
        local columnConfig := ClipboardURLOpener.Config["columns"]

        for colNum, colInfo in columnConfig {
            if (colInfo["auto"])
                this.listView.ModifyCol(colNum, "AutoHdr")
            else
                this.listView.ModifyCol(colNum, colInfo["width"])
        }
    }

    SetupHotkeys() {
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("^c", (*) => this.cmdManager.Execute("CopySelectedUrlNoSpaces"))
        HotIf()
    }

    OnGuiSize(guiObj, minMax, width, height) {
        if (minMax = -1)
            return

        local padX := ClipboardURLOpener.Config["padX"]
        local padY := ClipboardURLOpener.Config["padY"]
        local availableWidth := width - 2 * padX
        local availableHeight := height

        local prefixPos := "", appendPos := "", previewTextPos := "", previewBoxPos := "", listTextPos := ""
        try prefixPos := this.prefixEdit.GetPos()
        try appendPos := this.appendEdit.GetPos()
        try previewTextPos := this.previewTextCtrl.GetPos()
        try previewBoxPos := this.previewBox.GetPos()
        try listTextPos := this.listTextCtrl.GetPos()

        if (!IsObject(prefixPos) || !IsObject(appendPos) || !IsObject(listTextPos) || !IsObject(previewTextPos)) {
            return
        }

        local interEditPadding := appendPos.X - (prefixPos.X + prefixPos.W)
        local totalNonEditWidth := prefixPos.X - padX + interEditPadding + (width - (appendPos.X + appendPos.W))
        local editWidth := Max(100, (availableWidth - totalNonEditWidth) // 2)
        local listViewHeight := availableHeight - (listTextPos.Y + listTextPos.H + padY) - padY

        try {
            this.prefixEdit.Move(prefixPos.X, prefixPos.Y, editWidth)
            prefixPos := this.prefixEdit.GetPos()
            this.appendEdit.Move(prefixPos.X + prefixPos.W + interEditPadding, appendPos.Y, editWidth)
            this.previewBox.Move(padX, previewTextPos.Y + previewTextPos.H + padY, availableWidth)
            this.listView.Move(padX, listTextPos.Y + listTextPos.H + padY, availableWidth, listViewHeight)
        } catch Error {
        }
    }

    LoadClipboard(forceClipboard := false, *) {
        this.listView.Delete()
        this.lines := []

        local clipContent := forceClipboard ? A_Clipboard : A_Clipboard

        if (!clipContent) {
            this.listView.Add(, "", "Clipboard is empty or contains no text.", "", "")
            this.previewBox.Value := ""
            return
        }

        local clipLines := StrSplit(clipContent, "`n", "`r")
        local prefix := this.prefixEdit.Value
        local append := this.appendEdit.Value
        local lineCount := 0

        this.listView.Opt("-Redraw")
        for i, line in clipLines {
            line := Trim(line)
            if (line = "")
                continue

            this.lines.Push(line)
            local fullURL := prefix . line . append
            this.listView.Add(, prefix, line, append, fullURL)
            lineCount++
        }
        this.listView.Opt("+Redraw")

        if (lineCount = 0) {
            this.listView.Add(, "", "No valid lines found in clipboard.", "", "")
            this.previewBox.Value := ""
        } else {
            this.listView.Modify(1, "Select Focus")
            this.cmdManager.Execute("UpdateSelectedPreview")
        }

        this.ApplyColumnWidths()
    }

    UpdateSelectedPreview(*) {
        local rowNumber := this.listView.GetNext(0, "Focused")
        if (rowNumber <= 0) {
            this.previewBox.Value := ""
            return
        }
        local fullURL := this.listView.GetText(rowNumber, 4)
        this.previewBox.Value := fullURL
    }

    UpdateAllPreviews(*) {
        local prefix := this.prefixEdit.Value
        local append := this.appendEdit.Value
        local selectedRow := this.listView.GetNext(0, "Focused")

        this.listView.Opt("-Redraw")
        loop this.listView.GetCount() {
            local currentLineContent := this.listView.GetText(A_Index, 2)
            if (currentLineContent = "")
                continue
            local newFullURL := prefix . currentLineContent . append
            this.listView.Modify(A_Index, , prefix, currentLineContent, append, newFullURL)
        }
        this.listView.Opt("+Redraw")

        if (selectedRow > 0 && selectedRow <= this.listView.GetCount()) {
            this.listView.Modify(selectedRow, "Select Focus")
        } else if (this.listView.GetCount() > 0) {
            this.listView.Modify(1, "Select Focus")
        }

        this.cmdManager.Execute("UpdateSelectedPreview")
        this.ApplyColumnWidths()
    }

    OpenUrlInNewTab(*) {
        local rowNumber := this.listView.GetNext(0, "Focused")
        if (rowNumber <= 0)
            return

        local url := this.listView.GetText(rowNumber, 4)
        if (url = "")
            return

        try {
            local browserPath := ClipboardURLOpener.Config["browser"]
            if (browserPath = "msedge.exe")
                Run(browserPath " --new-tab `"" url "`"")
            else if (browserPath = "chrome.exe")
                Run(browserPath " --new-tab `"" url "`"")
            else if (browserPath = "firefox.exe")
                Run(browserPath " -new-tab `"" url "`"")
            else
                Run(url)
        } catch Error as err {
            MsgBox("Error opening URL in new tab: " err.Message "`n`nURL: " url, "Error", "IconError")
        }
    }

    OpenSelectedURL(*) {
        local rowNumber := this.listView.GetNext(0, "Focused")
        if (rowNumber <= 0)
            return

        local url := this.listView.GetText(rowNumber, 4)
        if (url = "")
            return

        try {
            Run(url)
        } catch Error {
            try {
                local browserPath := ClipboardURLOpener.Config["browser"]
                if (browserPath != "")
                    Run(browserPath " `"" url "`"")
                else
                    MsgBox("Failed to open URL directly, and no fallback browser is specified in Config.", "Error", "IconWarning")
            } catch Error as err2 {
                MsgBox("Error opening URL with specified browser: " err2.Message "`n`nURL: " url, "Error", "IconError")
            }
        }
    }

    CopyAllUrlsToClipboard(*) {
        local count := this.listView.GetCount()
        if (count <= 0) {
            ToolTip("List is empty, nothing to copy.")
            SetTimer(ToolTip, -2000)
            return
        }

        local allUrls := []
        loop count {
            local url := this.listView.GetText(A_Index, 4)
            if (url != "")
                allUrls.Push(url)
        }

9
        if (allUrls.Length > 0) {
            local clipboardString := ""
            for index, url in allUrls {
                if (index > 1) {
                    clipboardString .= "`n"
                }
                clipboardString .= url
            }
            A_Clipboard := clipboardString
            ToolTip(allUrls.Length " URLs copied to clipboard.")
            SetTimer(ToolTip, -2000)
        } else {
            ToolTip("No valid URLs found to copy.")
            SetTimer(ToolTip, -2000)
        }
    }

    CopySelectedUrlNoSpaces(*) {
        local rowNumber := this.listView.GetNext(0, "Focused")
        if (rowNumber <= 0) {
            ToolTip("No item selected in the list.")
            SetTimer(ToolTip, -2000)
            return
        }

        local url := this.listView.GetText(rowNumber, 4)
        if (url = "") {
            ToolTip("Selected item has an empty URL.")
            SetTimer(ToolTip, -2000)
            return
        }

        local urlNoSpaces := StrReplace(url, " ")

        A_Clipboard := urlNoSpaces
        ToolTip("Selected URL (no spaces) copied.")
        SetTimer(ToolTip, -2000)
    }

    __Delete() {
    }
}


GuiFormat(x, y, w, h, extraParams := "") {
    return GuiFormatBuilder().Position(x, y).Size(w, h).ExtraParams(extraParams).Build()
}

class GuiFormatBuilder {
    _x := 0
    _y := 0
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
        local params := Format("x{} y{} w{} h{}", this._x, this._y, this._w, this._h)
        if this._extraParams {
            params .= " " this._extraParams
        }
        return params
    }
}

class CommandManager {
    __New() {
        this.commands := Map()
    }

    Register(name, callback) {
        this.commands[name] := callback
        return this
    }

    Execute(name, params*) {
        if (this.commands.Has(name))
            return this.commands[name](params*)
        return false
    }
}