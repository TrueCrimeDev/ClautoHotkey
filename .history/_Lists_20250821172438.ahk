#Requires AutoHotkey v2
#SingleInstance Force

#Include <UIA>

EntryParser()

class TSVParser {
    Parse(tsvData) {
        rows := []
        lines := StrSplit(tsvData, "`n", "`r")

        for line in lines {
            if Trim(line) {
                columns := StrSplit(line, "`t")
                rows.Push(columns)
            }
        }
        return rows
    }
}

class EditValueDialog {
    __New(parentGui, categoryName, currentValue, callback) {
        this.parentGui := parentGui
        this.categoryName := categoryName
        this.currentValue := currentValue
        this.callback := callback
        this.CreateDialog()
    }

    CreateDialog() {
        this.gui := Gui("+AlwaysOnTop +Owner" . this.parentGui.Hwnd, "Edit Field Value")
        this.darkMode := _Dark(this.gui)

        margin := 10
        currentY := margin

        this.darkMode.AddDarkText("x" . margin . " y" . currentY . " w300 h20", "Field: " . this.categoryName)
        currentY += 25

        displayValue := this.currentValue = "[Unassigned]" ? "" : this.currentValue
        this.valueEdit := this.darkMode.AddDarkEdit("x" . margin . " y" . currentY . " w300 h25", displayValue)
        this.valueEdit.Focus()
        currentY += 35

        this.btnOK := this.darkMode.AddDarkButton("x" . margin . " y" . currentY . " w80 h30 Default", "OK")
        this.btnOK.OnEvent("Click", this.HandleOK.Bind(this))

        this.btnCancel := this.darkMode.AddDarkButton("x" . (margin + 90) . " y" . currentY . " w80 h30", "Cancel")
        this.btnCancel.OnEvent("Click", this.HandleCancel.Bind(this))

        this.gui.OnEvent("Close", this.HandleCancel.Bind(this))
        this.gui.OnEvent("Escape", this.HandleCancel.Bind(this))

        if displayValue {
            SetTimer(() => this.SelectAllText(), -50)
        }

        this.gui.Show("w320 h" . (currentY + 40))
    }

    SelectAllText() {
        if this.valueEdit {
            try {
                SendMessage(0x00B1, 0, -1, this.valueEdit.Hwnd)
            }
        }
    }

    HandleOK(*) {
        newValue := Trim(this.valueEdit.Value)
        if newValue = "" {
            newValue := "[Unassigned]"
        }

        this.callback.Call(newValue)
        this.gui.Destroy()
    }

    HandleCancel(*) {
        this.gui.Destroy()
    }
}

class EntryParser {
    static DesiredColumns := [
        "Name of Event",
        "Event Date",
        "Host or Main Participating Organization Name",
        "Event Description",
        "Event City",
        "Event State",
        "Event Zip",
        "Region",
        "Will media be present?",
        "Will the event be recorded?",
        "Congressional attendance or interest?",
        "Per Diem/Overnight Travel Required?"
    ]

    __New() {
        this.parsedData := []
        this.parsedColumns := []
        this.categoryAssignments := Map()
        this.jsonData := ""
        this.fullStatusMessage := ""
        this.CreateGUI()
    }

    CreateGUI() {
        this.gui := Gui("+Resize +AlwaysOnTop", "TSV to JSON Converter with Field Mapping")
        this.darkMode := _Dark(this.gui)

        margin := 10
        currentY := margin

        this.tsvEdit := this.darkMode.AddDarkEdit("x" . margin . " y" . currentY . " w770 h120 Multi", "Van De Bogart, Nicole - WHD	03/18/25	School District 131	03/26/25	School District 131	Meeting with school district public relations officer for district serving 22 schools in Western Chicago suburban area to share FLSA/CL information and resources 	Aurora 	IL 	60505	Midwest	No	No	No	No	Yes")
        currentY += 130

        this.btnParse := this.darkMode.AddDarkButton("x" . margin . " y" . currentY . " w100 h30", "Parse TSV")
        this.btnParse.OnEvent("Click", this.ParseTSV.Bind(this))

        this.btnAutoMap := this.darkMode.AddDarkButton("x" . (margin + 110) . " y" . currentY . " w80 h30", "Auto Map")
        this.btnAutoMap.OnEvent("Click", this.AutoMapFields.Bind(this))

        this.btnClearMap := this.darkMode.AddDarkButton("x" . (margin + 200) . " y" . currentY . " w80 h30", "Clear Map")
        this.btnClearMap.OnEvent("Click", this.ClearMapping.Bind(this))

        this.btnGenerate := this.darkMode.AddDarkButton("x" . (margin + 290) . " y" . currentY . " w100 h30", "Generate JSON")
        this.btnGenerate.OnEvent("Click", this.GenerateJSON.Bind(this))

        this.btnCopy := this.darkMode.AddDarkButton("x" . (margin + 400) . " y" . currentY . " w80 h30", "Copy JSON")
        this.btnCopy.OnEvent("Click", this.CopyJSON.Bind(this))

        this.btnFillForm := this.darkMode.AddDarkButton("x" . (margin + 490) . " y" . currentY . " w100 h30", "Fill Form")
        this.btnFillForm.OnEvent("Click", this.OpenAutoFiller.Bind(this))

        this.statusText := this.darkMode.AddDarkText("x" . (margin + 600) . " y" . (currentY + 5) . " w150 h20", "Ready")
        this.statusText.OnEvent("ContextMenu", this.ShowFullStatus.Bind(this))
        currentY += 40

        this.darkMode.AddDarkText("x" . margin . " y" . currentY . " w250 h20", "Field Categories (Click to select)")
        this.darkMode.AddDarkText("x" . (margin + 260) . " y" . currentY . " w250 h20", "TSV Data (Click to assign category)")
        this.darkMode.AddDarkText("x" . (margin + 520) . " y" . currentY . " w250 h20", "Field Assignments (Double-click to edit)")
        currentY += 25

        this.categoryList := this.darkMode.AddListView("x" . margin . " y" . currentY . " w250 h270 R18 +Grid", ["#", "Field Category"])
        this.categoryList.ModifyCol(1, 30)
        this.categoryList.ModifyCol(2, 200)
        this.categoryList.OnEvent("Click", this.HandleCategoryClick.Bind(this))

        this.dataList := this.darkMode.AddListView("x" . (margin + 260) . " y" . currentY . " w250 h270 R18 +Grid", ["#", "TSV Data", "Categories"])
        this.dataList.ModifyCol(1, 30)
        this.dataList.ModifyCol(2, 130)
        this.dataList.ModifyCol(3, 90)
        this.dataList.OnEvent("Click", this.HandleDataClick.Bind(this))
        this.dataList.OnEvent("DoubleClick", this.HandleDataDoubleClick.Bind(this))

        this.assignmentList := this.darkMode.AddListView("x" . (margin + 520) . " y" . currentY . " w250 h270 R18 +Grid", ["Field Category", "Assigned Data"])
        this.assignmentList.ModifyCol(1, 130)
        this.assignmentList.ModifyCol(2, 100)
        this.assignmentList.OnEvent("DoubleClick", this.HandleAssignmentDoubleClick.Bind(this))

        this.jsonEdit := this.darkMode.AddDarkEdit("xm yp w0 h0 Hidden", "")

        this.PopulateCategoryList()
        this.PopulateInitialAssignmentList()
        this.selectedCategory := 0

        this.gui.Show("w800 h" . (currentY + 280))
    }

    OpenAutoFiller(*) {
        if !Trim(this.jsonData) {
            this.UpdateStatus("No JSON available. Generate JSON first.")
            return
        }

        try {
            this.UpdateStatus("Opening AutoFiller...")
            autoFiller := AutoFiller(this.jsonData)
            this.UpdateStatus("AutoFiller opened successfully")
        } catch Error as e {
            this.UpdateStatus("Error: " . e.Message)
        }
    }

    PopulateCategoryList() {
        for index, fieldName in EntryParser.DesiredColumns {
            this.categoryList.Add("", index, fieldName)
        }
    }

    PopulateInitialAssignmentList() {
        for index, fieldName in EntryParser.DesiredColumns {
            this.categoryAssignments[fieldName] := Map("dataIndex", 0, "data", "[Unassigned]", "customData", "")
            this.assignmentList.Add("", fieldName, "[Unassigned]")
        }
    }

    HandleAssignmentDoubleClick(*) {
        selectedRow := this.assignmentList.GetNext()
        if selectedRow && selectedRow > 0 {
            categoryName := EntryParser.DesiredColumns[selectedRow]
            currentValue := this.categoryAssignments[categoryName]["data"]

            editDialog := EditValueDialog(this.gui, categoryName, currentValue, this.UpdateFieldValue.Bind(this, categoryName))
        }
    }

    UpdateFieldValue(categoryName, newValue) {
        if newValue = "[Unassigned]" {
            this.categoryAssignments[categoryName]["customData"] := ""
        } else {
            this.categoryAssignments[categoryName]["customData"] := newValue
        }

        this.categoryAssignments[categoryName]["data"] := newValue

        this.UpdateAssignmentList()
    }

    ParseTSV(*) {
        tsvData := this.tsvEdit.Value
        if !Trim(tsvData) {
            this.UpdateStatus("Please enter TSV data first")
            return
        }

        try {
            this.UpdateStatus("Parsing TSV data...")
            parser := TSVParser()
            this.parsedData := parser.Parse(tsvData)
            this.ParseColumns()
            this.PopulateDataList()
            this.UpdateStatus("TSV parsed: " . this.parsedData.Length . " rows")
        } catch Error as e {
            this.UpdateStatus("Parse error: " . e.Message)
        }
    }

    ParseColumns() {
        this.parsedColumns := []

        if !this.parsedData.Length {
            return
        }

        firstRow := this.parsedData[1]

        startIndex := 1
        if firstRow.Length >= 1 {
            firstVal := Trim(firstRow.Get(1, ""))
            if StrLen(firstVal) = 2 && firstVal = StrUpper(firstVal) && RegExMatch(firstVal, "^[A-Z]{2}$") {
                startIndex := 2
            }
        }

        Loop firstRow.Length - startIndex + 1 {
            colIndex := startIndex + A_Index - 1
            if colIndex <= firstRow.Length {
                value := Trim(firstRow.Get(colIndex, ""))
                if value {
                    columnData := Map()
                    columnData["index"] := colIndex
                    columnData["value"] := value
                    columnData["preview"] := this.GetPreviewText(value)
                    columnData["isEmpty"] := false
                    columnData["assignedCategories"] := []
                    this.parsedColumns.Push(columnData)
                }
            }
        }

        this.EnsureMinimumRows()
    }

    EnsureMinimumRows() {
        minRows := EntryParser.DesiredColumns.Length
        currentRows := this.parsedColumns.Length

        if currentRows < minRows {
            Loop minRows - currentRows {
                blankIndex := currentRows + A_Index
                columnData := Map()
                columnData["index"] := blankIndex
                columnData["value"] := ""
                columnData["preview"] := "[Empty Row " . blankIndex . "]"
                columnData["isEmpty"] := true
                columnData["assignedCategories"] := []
                this.parsedColumns.Push(columnData)
            }
        }
    }

    GetPreviewText(value) {
        if StrLen(value) > 25 {
            return SubStr(value, 1, 25) . "..."
        }
        return value
    }

    PopulateDataList() {
        this.dataList.Delete()

        for index, columnData in this.parsedColumns {
            displayData := columnData["isEmpty"] ? "[Empty]" : columnData["preview"]
            categoryCount := columnData["assignedCategories"].Length
            categoryDisplay := categoryCount > 0 ? categoryCount . " assigned" : "[Unassigned]"
            this.dataList.Add("", index, displayData, categoryDisplay)
        }
    }

    HandleCategoryClick(*) {
        this.selectedCategory := this.categoryList.GetNext()
        if this.selectedCategory {
            this.categoryList.Modify(this.selectedCategory, "Select")
            categoryName := EntryParser.DesiredColumns[this.selectedCategory]
            this.UpdateStatus("Selected: " . categoryName . " - Click data to assign")
        }
    }

    HandleDataClick(*) {
        selectedData := this.dataList.GetNext()
        if selectedData && this.selectedCategory > 0 {
            this.AssignCategory(selectedData, this.selectedCategory)
            this.selectedCategory := 0
            this.UpdateAssignmentList()
            this.UpdateDataListDisplay()
        }
    }

    HandleDataDoubleClick(*) {
        selectedData := this.dataList.GetNext()
        if selectedData {
            nextCategory := this.FindNextUnassignedCategory()
            if nextCategory {
                this.AssignCategory(selectedData, nextCategory)
                this.UpdateAssignmentList()
                this.UpdateDataListDisplay()
            } else {
                this.UpdateStatus("All categories are assigned")
            }
        }
    }

    AssignCategory(dataIndex, categoryIndex) {
        if dataIndex <= this.parsedColumns.Length {
            categoryName := EntryParser.DesiredColumns[categoryIndex]
            columnData := this.parsedColumns[dataIndex]

            alreadyAssigned := false
            for assignedCategory in columnData["assignedCategories"] {
                if assignedCategory = categoryName {
                    alreadyAssigned := true
                    break
                }
            }

            if !alreadyAssigned {
                columnData["assignedCategories"].Push(categoryName)

                displayData := columnData["isEmpty"] ? "[Empty]" : columnData["preview"]
                this.categoryAssignments[categoryName]["dataIndex"] := dataIndex

                if this.categoryAssignments[categoryName]["customData"] = "" {
                    this.categoryAssignments[categoryName]["data"] := displayData
                }
            }
        }
    }

    FindNextUnassignedCategory() {
        for index, categoryName in EntryParser.DesiredColumns {
            if this.categoryAssignments[categoryName]["dataIndex"] = 0 {
                return index
            }
        }
        return 0
    }

    AutoMapFields(*) {
        this.ClearMapping()

        realColumnsCount := 0
        for columnData in this.parsedColumns {
            if !columnData["isEmpty"] {
                realColumnsCount++
            }
        }

        maxMappings := Min(EntryParser.DesiredColumns.Length, realColumnsCount)

        Loop maxMappings {
            categoryIndex := A_Index
            dataIndex := A_Index
            if dataIndex <= this.parsedColumns.Length {
                this.AssignCategory(dataIndex, categoryIndex)
            }
        }

        this.UpdateDataListDisplay()
        this.UpdateAssignmentList()

        this.UpdateStatus("Auto-assigned " . maxMappings . " categories")
    }

    ClearMapping(*) {
        for columnData in this.parsedColumns {
            columnData["assignedCategories"] := []
        }

        for categoryName in EntryParser.DesiredColumns {
            this.categoryAssignments[categoryName]["dataIndex"] := 0
            if this.categoryAssignments[categoryName]["customData"] = "" {
                this.categoryAssignments[categoryName]["data"] := "[Unassigned]"
            }
        }

        this.UpdateDataListDisplay()
        this.UpdateAssignmentList()
    }

    UpdateDataListDisplay() {
        for index, columnData in this.parsedColumns {
            categoryCount := columnData["assignedCategories"].Length
            categoryDisplay := categoryCount > 0 ? categoryCount . " assigned" : "[Unassigned]"
            this.dataList.Modify(index, "Col3", categoryDisplay)
        }
    }

    UpdateAssignmentList() {
        this.assignmentList.Delete()

        for index, categoryName in EntryParser.DesiredColumns {
            assignedData := this.categoryAssignments[categoryName]["data"]
            this.assignmentList.Add("", categoryName, assignedData)
        }
    }

    GenerateJSON(*) {
        if !this.parsedData.Length {
            this.UpdateStatus("No TSV data. Parse TSV first")
            return
        }

        assignedCount := 0
        for categoryName in EntryParser.DesiredColumns {
            if this.categoryAssignments[categoryName]["dataIndex"] > 0 || this.categoryAssignments[categoryName]["customData"] != "" {
                assignedCount++
            }
        }

        if assignedCount = 0 {
            this.UpdateStatus("No assignments. Assign categories first")
            return
        }

        this.UpdateStatus("Generating JSON...")

        json := "[`n"

        for rIdx, row in this.parsedData {
            json .= "  {`n"

            addedFields := 0
            for categoryName in EntryParser.DesiredColumns {
                assignment := this.categoryAssignments[categoryName]
                value := ""

                if assignment["customData"] != "" {
                    value := assignment["customData"]
                } else if assignment["dataIndex"] > 0 {
                    dataIndex := assignment["dataIndex"]
                    if dataIndex <= this.parsedColumns.Length {
                        columnData := this.parsedColumns[dataIndex]
                        if !columnData["isEmpty"] {
                            columnIndex := columnData["index"]
                            value := Trim(row.Get(columnIndex, ""))
                        }
                    }
                }

                if value != "" && value != "[Unassigned]" {
                    key := this.EscapeJSON(categoryName)
                    val := this.EscapeJSON(value)

                    if addedFields > 0
                        json .= ","
                    json .= Format('`n    `"{1}`": `"{2}`"', key, val)
                    addedFields++
                }
            }

            json .= "`n  }"
            if rIdx < this.parsedData.Length
                json .= ","
            json .= "`n"
        }

        json .= "]"

        this.jsonEdit.Value := json
        this.jsonData := json
        this.UpdateStatus("JSON generated: " . assignedCount . " fields")
    }

    EscapeJSON(str) {
        str := StrReplace(str, "\", "\\")
        str := StrReplace(str, "`"", "`\`"")
        str := StrReplace(str, "`r`n", "\n")
        str := StrReplace(str, "`n", "\n")
        str := StrReplace(str, "`r", "\n")
        str := StrReplace(str, "`t", "\\t")
        return str
    }

    UpdateStatus(message) {
        this.fullStatusMessage := message

        displayMessage := message
        if StrLen(message) > 25 {
            displayMessage := SubStr(message, 1, 22) . "..."
        }

        this.statusText.Value := displayMessage

        if StrLen(message) > 25 {
            this.statusText.ToolTip := message
        } else {
            this.statusText.ToolTip := ""
        }
    }

    ShowFullStatus(*) {
        if this.fullStatusMessage {
            MsgBox(this.fullStatusMessage, "Full Status Message", "Iconi")
        }
    }

    CopyJSON(*) {
        if !Trim(this.jsonEdit.Value) {
            this.UpdateStatus("No JSON to copy. Generate first")
            return
        }

        A_Clipboard := this.jsonEdit.Value
        this.UpdateStatus("JSON copied to clipboard")
    }
}

class AutoFiller {
    static Config := Map(
        "title", "Form Filler",
        "width", 680,
        "height", 720
    )

    static DesiredColumns := [
        "Name of Event",
        "Event Date",
        "Host or Main Participating Organization Name",
        "Event Description",
        "Event City",
        "Event State",
        "Event Zip",
        "Region",
        "Will media be present?",
        "Will the event be recorded?",
        "Congressional attendance or interest?",
        "Per Diem/Overnight Travel Required?"
    ]

    static Instance := ""

    __New(jsonData := "") {
        AutoFiller.Instance := this
        this.designer := GuiDesigner()
        this.state := Map("tsv", "", "json", jsonData, "parsedData", [])
        this.fullStatusMessage := ""

        if jsonData && Trim(jsonData) {
            try {
                this.state["parsedData"] := this.ParseJSONToStructuredData(jsonData)
                this.UpdateStatus("JSON data loaded: " . this.state["parsedData"].Length . " records")
            } catch Error as e {
                this.UpdateStatus("Parse error: " . e.Message)
            }
        } else {
            this.UpdateStatus("No JSON data provided")
        }

        this.InitializeFormSettings()
        this.CreateGUI()
        this.SetupEvents()
        this.SetupHotkeys()
        this.ShowGUI()
    }

    InitializeFormSettings() {
        this.formSettings := Map(
            "fieldDelay", 200,
            "navigationDelay", 200,
            "initialDelay", 500,
            "showTooltips", true,
            "tooltipDuration", 1000,
            "searchTimeout", 3000
        )

        this.fieldNavigation := Map(
            2, "ENTER_TAB",
            8, "ENTER_TAB",
            9, "ENTER_TAB",
            10, "ENTER_TAB",
            11, "ENTER_TAB",
            12, "ENTER_TAB"
        )
    }

    SetupHotkeys() {
        Hotkey("^+f", this.HotkeyFillForm.Bind(this))
        Hotkey("^+a", this.HotkeyAdvancedFill.Bind(this))
        Hotkey("^+s", this.HotkeySmartFill.Bind(this))
    }

    HotkeyFillForm(*) {
        this.FillForm()
    }

    HotkeyAdvancedFill(*) {
        this.AdvancedFillForm()
    }

    HotkeySmartFill(*) {
        this.SmartFillForm()
    }

    CreateGUI() {
        this.designer.gui.Title := AutoFiller.Config["title"]
        this.designer.gui.Opt("+Resize +MinSize450x580")
        this.darkMode := _Dark(this.designer.gui)

        margin := 10
        buttonWidth := 105
        buttonSpacing := 8
        currentY := margin

        this.designer.AddButton("btnFillForm", "Fill Form`n(Ctrl+Shift+F)")
            .Position(margin, currentY)
            .Size(buttonWidth, 30)
            .OnEvent("Click", this.FillForm.Bind(this))
            .Build()

        this.designer.AddButton("btnSmartFill", "Smart Fill`n(Ctrl+Shift+S)")
            .Position(margin + buttonWidth + buttonSpacing, currentY)
            .Size(buttonWidth, 30)
            .OnEvent("Click", this.SmartFillForm.Bind(this))
            .Build()

        this.designer.AddButton("btnAdvancedFill", "Advanced Fill`n(Ctrl+Shift+A)")
            .Position(margin + (buttonWidth + buttonSpacing) * 2, currentY)
            .Size(buttonWidth, 30)
            .OnEvent("Click", this.AdvancedFillForm.Bind(this))
            .Build()

        this.designer.AddButton("btnSave", "Save JSON")
            .Position(margin + (buttonWidth + buttonSpacing) * 3, currentY)
            .Size(buttonWidth, 30)
            .OnEvent("Click", this.SaveJSON.Bind(this))
            .Build()

        this.designer.AddText("statusText", "Ready")
            .Position(margin + (buttonWidth + buttonSpacing) * 4 + 10, currentY + 8)
            .Size(150, 15)
            .Build()

        currentY += 50
        this.CreateConfigurationSection(currentY)

        currentY += 110
        this.CreateDataSection(currentY)
    }

    CreateConfigurationSection(startY) {
        margin := 10

        this.designer.AddText("lblConfigHeader", "Form Filling Configuration")
            .Position(margin, startY)
            .Size(200, 20)
            .Build()

        this.designer.Get("lblConfigHeader").SetFont("s9 Bold cFFFFFF", "Segoe UI")

        rowY := startY + 25

        this.designer.AddText("lblFieldDelay", "Field Delay (ms):")
            .Position(margin, rowY)
            .Size(90, 20)
            .Build()

        this.designer.AddEdit("edtFieldDelay", String(this.formSettings["fieldDelay"]))
            .Position(margin + 95, rowY - 2)
            .Size(50, 20)
            .OnEvent("Change", this.UpdateFieldDelay.Bind(this))
            .Build()

        this.designer.AddText("lblNavDelay", "Navigation Delay (ms):")
            .Position(margin + 160, rowY)
            .Size(130, 20)
            .Build()

        this.designer.AddEdit("edtNavDelay", String(this.formSettings["navigationDelay"]))
            .Position(margin + 295, rowY - 2)
            .Size(50, 20)
            .OnEvent("Change", this.UpdateNavDelay.Bind(this))
            .Build()

        rowY += 30

        this.designer.AddCheckbox("chkTooltips", "Show Progress Tooltips")
            .Position(margin, rowY)
            .Size(140, 20)
            .OnEvent("Click", this.ToggleTooltips.Bind(this))
            .Build()

        this.designer.Get("chkTooltips").Value := this.formSettings["showTooltips"]

        this.designer.AddText("lblTooltipDuration", "Tooltip Duration (ms):")
            .Position(margin + 160, rowY)
            .Size(130, 20)
            .Build()

        this.designer.AddEdit("edtTooltipDuration", String(this.formSettings["tooltipDuration"]))
            .Position(margin + 295, rowY - 2)
            .Size(50, 20)
            .OnEvent("Change", this.UpdateTooltipDuration.Bind(this))
            .Build()

        rowY += 30

        this.designer.AddText("lblFieldConfig", "Field Navigation:")
            .Position(margin, rowY)
            .Size(100, 20)
            .Build()

        this.designer.AddButton("btnConfigFields", "Edit Configuration")
            .Position(margin + 105, rowY - 2)
            .Size(110, 25)
            .OnEvent("Click", this.ShowFieldConfigDialog.Bind(this))
            .Build()

        this.designer.AddButton("btnPreview", "Preview Sequence")
            .Position(margin + 225, rowY - 2)
            .Size(110, 25)
            .OnEvent("Click", this.PreviewSequence.Bind(this))
            .Build()
    }

    CreateDataSection(startY) {
        margin := 10
        leftPanelWidth := (AutoFiller.Config["width"] - 30) // 2
        rightPanelWidth := leftPanelWidth
        panelHeight := AutoFiller.Config["height"] - 250

        this.designer.AddText("lblTSVData", "JSON Input Data:")
            .Position(margin, startY)
            .Size(120, 20)
            .Build()

        this.designer.AddEdit("edtTSV", this.state["json"])
            .Position(margin, startY + 25)
            .Size(leftPanelWidth, panelHeight - 25)
            .Multi()
            .ReadOnly()
            .Build()

        this.designer.AddText("lblDataView", "Data View:")
            .Position(margin + leftPanelWidth + 10, startY)
            .Size(80, 20)
            .Build()

        this.designer.AddDropDownList("ddlDataView", ["All Records", "Field Summary", "Validation View"])
            .Position(margin + leftPanelWidth + 90, startY - 2)
            .Size(120, 100)
            .Choose(1)
            .OnEvent("Change", this.UpdateDataView.Bind(this))
            .Build()

        this.designer.AddListView("lvData", "")
            .Position(margin + leftPanelWidth + 10, startY + 25)
            .Size(rightPanelWidth, panelHeight - 25)
            .Build()

        if this.state["parsedData"].Length > 0
            this.UpdateDataView()
    }

    UpdateFieldDelay(*) {
        try {
            delay := Integer(this.designer.Get("edtFieldDelay").Value)
            if delay >= 50 && delay <= 5000
                this.formSettings["fieldDelay"] := delay
        } catch {
            this.designer.Get("edtFieldDelay").Value := String(this.formSettings["fieldDelay"])
        }
    }

    UpdateNavDelay(*) {
        try {
            delay := Integer(this.designer.Get("edtNavDelay").Value)
            if delay >= 50 && delay <= 5000
                this.formSettings["navigationDelay"] := delay
        } catch {
            this.designer.Get("edtNavDelay").Value := String(this.formSettings["navigationDelay"])
        }
    }

    UpdateTooltipDuration(*) {
        try {
            duration := Integer(this.designer.Get("edtTooltipDuration").Value)
            if duration >= 500 && duration <= 5000
                this.formSettings["tooltipDuration"] := duration
        } catch {
            this.designer.Get("edtTooltipDuration").Value := String(this.formSettings["tooltipDuration"])
        }
    }

    ToggleTooltips(*) {
        this.formSettings["showTooltips"] := this.designer.Get("chkTooltips").Value
    }

    ShowFieldConfigDialog(*) {
        configDialog := FieldConfigDialog(this.fieldNavigation, AutoFiller.DesiredColumns, this.UpdateFieldNavigation.Bind(this))
        configDialog.Show()
    }

    UpdateFieldNavigation(newConfig) {
        this.fieldNavigation := newConfig
    }

    UpdateDataView(*) {
        if !this.state["parsedData"] || !this.state["parsedData"].Length
            return

        listView := this.designer.Get("lvData")
        viewType := this.designer.Get("ddlDataView").Value

        listView.Delete()

        loop listView.GetCount("Col")
            listView.DeleteCol(1)

        switch viewType {
            case 1:
                this.ShowAllRecords(listView)
            case 2:
                this.ShowFieldSummary(listView)
            case 3:
                this.ShowValidationView(listView)
        }
    }

    ShowAllRecords(listView) {
        if !this.state["parsedData"].Length
            return

        columns := []
        for col in AutoFiller.DesiredColumns
            columns.Push(col)

        for index, col in columns {
            listView.InsertCol(index, 120, col)
        }

        for rowData in this.state["parsedData"] {
            values := []
            for col in AutoFiller.DesiredColumns {
                value := rowData.Get(col, "")
                values.Push(StrLen(value) > 40 ? SubStr(value, 1, 40) . "..." : value)
            }
            listView.Add("", values*)
        }
    }

    ShowFieldSummary(listView) {
        if !this.state["parsedData"].Length
            return

        listView.InsertCol(1, 200, "Field Name")
        listView.InsertCol(2, 100, "Navigation")
        listView.InsertCol(3, 120, "Sample Value")
        listView.InsertCol(4, 80, "Length")

        for index, fieldName in AutoFiller.DesiredColumns {
            navType := this.fieldNavigation.Get(index, "TAB_ONLY")
            sampleValue := ""
            avgLength := 0

            if this.state["parsedData"].Length > 0 {
                sampleValue := this.state["parsedData"][1].Get(fieldName, "")
                totalLength := 0
                for rowData in this.state["parsedData"] {
                    totalLength += StrLen(rowData.Get(fieldName, ""))
                }
                avgLength := totalLength // this.state["parsedData"].Length
            }

            displayValue := StrLen(sampleValue) > 30 ? SubStr(sampleValue, 1, 30) . "..." : sampleValue
            listView.Add("", fieldName, navType, displayValue, avgLength . " chars")
        }
    }

    ShowValidationView(listView) {
        if !this.state["parsedData"].Length
            return

        listView.InsertCol(1, 200, "Field Name")
        listView.InsertCol(2, 100, "Status")
        listView.InsertCol(3, 120, "Issues")
        listView.InsertCol(4, 80, "Records")

        for index, fieldName in AutoFiller.DesiredColumns {
            emptyCount := 0
            longCount := 0

            for rowData in this.state["parsedData"] {
                value := rowData.Get(fieldName, "")
                if !Trim(value)
                    emptyCount++
                if StrLen(value) > 100
                    longCount++
            }

            issues := []
            if emptyCount > 0
                issues.Push(emptyCount . " empty")
            if longCount > 0
                issues.Push(longCount . " long")

            status := issues.Length > 0 ? "Warning" : "OK"
            issueText := issues.Length > 0 ? issues.Join(", ") : "None"

            listView.Add("", fieldName, status, issueText, this.state["parsedData"].Length)
        }
    }

    PreviewSequence(*) {
        if !this.state["json"] {
            this.UpdateStatus("No JSON data available")
            return
        }

        formData := this.ExtractFormData()
        if !formData.Length {
            this.UpdateStatus("No form data extracted")
            return
        }

        preview := "Form Fill Sequence Preview:`n`n"
        for index, value in formData {
            fieldName := AutoFiller.DesiredColumns.Get(index, "Field " . index)
            navType := this.fieldNavigation.Get(index, "TAB_ONLY")

            preview .= "Step " . index . ": " . fieldName . "`n"
            preview .= "  Value: " . (StrLen(value) > 50 ? SubStr(value, 1, 50) . "..." : value) . "`n"
            preview .= "  Navigation: " . navType . "`n"
            preview .= "  Delays: Field=" . this.formSettings["fieldDelay"] . "ms, Nav=" . this.formSettings["navigationDelay"] . "ms`n`n"
        }

        MsgBox(preview, "Form Fill Preview", "Iconi")
    }

    ShowProgressTooltip(fieldName, value, currentIndex, totalFields) {
        if !this.formSettings["showTooltips"]
            return

        progress := "(" . currentIndex . "/" . totalFields . ")"
        message := "Filling: " . fieldName . " " . progress
        this.UpdateStatus(message)
    }

    SetupEvents() {
        this.designer.OnEvent("Size", this.HandleResize.Bind(this))
        this.designer.OnEvent("Close", (*) => this.designer.gui.Destroy())
    }

    ShowGUI() {
        this.designer.Build()
    }

    ValidateEdgeWindow() {
        if !WinExist("ahk_exe msedge.exe") {
            this.UpdateStatus("Edge browser not found")
            return false
        }

        if !WinActive("ahk_exe msedge.exe") {
            this.UpdateStatus("Edge window not active")
            return false
        }

        activeTitle := WinGetTitle("A")
        if !InStr(activeTitle, "Public Outreach and Compliance Assistance Event Clearance Request") {
            this.UpdateStatus("Navigate to correct form in Edge")
            return false
        }

        return true
    }

    ShowFailureTooltip(message) {
        this.UpdateStatus(message)
    }

    SaveJSON(*) {
        if !this.state["json"] {
            this.UpdateStatus("Nothing to save")
            return
        }

        outFile := FileSelect("S", , "Save JSON as", "JSON (*.json)")
        if !outFile
            return

        try {
            FileDelete(outFile)
            FileAppend(this.state["json"], outFile, "UTF-8")
            this.UpdateStatus("Saved: " . outFile)
        } catch Error as e {
            this.UpdateStatus("Save failed: " . e.Message)
        }
    }

    FillForm(*) {
        if !this.state["json"] || !Trim(this.state["json"]) {
            this.UpdateStatus("No JSON data available")
            return
        }

        if !this.ValidateEdgeWindow() {
            return
        }

        try {
            formData := this.ExtractFormData()
            if !formData.Length {
                this.UpdateStatus("No form data extracted from JSON")
                return
            }

            this.UpdateStatus("Starting form fill...")
            Sleep(this.formSettings["initialDelay"])

            if !this.ValidateEdgeWindow() {
                return
            }

            Send("{Tab}")
            Sleep(this.formSettings["navigationDelay"])

            for index, value in formData {
                if !this.ValidateEdgeWindow() {
                    this.UpdateStatus("Edge window lost focus")
                    return
                }

                fieldName := AutoFiller.DesiredColumns.Get(index, "Field " . index)
                this.UpdateStatus("Filling field " . index . "/" . formData.Length . ": " . fieldName)

                oldClipboard := A_Clipboard
                Send("^a")
                Sleep(50)
                A_Clipboard := value
                ClipWait(2)
                Send("^v")
                Sleep(this.formSettings["fieldDelay"])
                A_Clipboard := oldClipboard

                if this.fieldNavigation.Has(index) && this.fieldNavigation[index] = "ENTER_TAB" {
                    Send("{Enter}")
                    Sleep(this.formSettings["navigationDelay"])
                    Send("{Tab}")
                } else {
                    Send("{Tab}")
                }
                Sleep(this.formSettings["navigationDelay"])
            }

            this.UpdateStatus("Form filling completed successfully")

        } catch Error as e {
            this.UpdateStatus("Form filling failed: " . e.Message)
        }
    }

    SmartFillForm(*) {
        if !this.state["json"] {
            this.ShowFailureTooltip("No JSON data available.")
            return
        }

        if !this.ValidateEdgeWindow() {
            return
        }

        try {
            formDataMap := this.ExtractFormDataMap()
            if !formDataMap.Count {
                this.ShowFailureTooltip("No form data extracted from JSON.")
                return
            }

            edge := UIA.GetBrowser("msedge.exe")
            if !edge {
                this.ShowFailureTooltip("Could not connect to Edge browser using UIA.")
                return
            }

            document := edge.GetCurrentDocumentElement()
            if !document {
                this.ShowFailureTooltip("Could not find the document element.")
                return
            }

            Sleep(this.formSettings["initialDelay"])

            currentIndex := 0
            totalFields := formDataMap.Count
            successfullyFilled := []
            failedFields := []

            for fieldName, fieldValue in formDataMap {
                try {
                    currentIndex++

                    if !this.ValidateEdgeWindow() {
                        this.ShowFailureTooltip("Edge window lost focus during form filling.")
                        return
                    }

                    this.ShowProgressTooltip("Searching for: " . fieldName, fieldValue, currentIndex, totalFields)

                    labelElement := this.FindFieldLabel(document, fieldName)
                    if !labelElement {
                        failedFields.Push(fieldName . " (label not found)")
                        continue
                    }

                    labelElement.Highlight()
                    Sleep(300)

                    inputElement := this.FindInputForLabel(labelElement, fieldName, fieldValue)
                    if !inputElement {
                        failedFields.Push(fieldName . " (input not found)")
                        continue
                    }

                    this.ShowProgressTooltip("Filling: " . fieldName, fieldValue, currentIndex, totalFields)

                    inputElement.SetFocus()
                    Sleep(this.formSettings["navigationDelay"])

                    if InStr(fieldName, "?") {
                        this.HandleRadioSelection(inputElement, fieldValue)
                    } else {
                        inputElement.Value := fieldValue
                    }

                    Sleep(this.formSettings["fieldDelay"])
                    successfullyFilled.Push(fieldName)

                } catch Error as e {
                    failedFields.Push(fieldName . " (error: " . e.Message . ")")
                    continue
                }
            }

            summary := "Smart Form Fill Complete!`n`n"
            summary .= "Successfully filled: " . successfullyFilled.Length . "/" . totalFields . " fields`n`n"

            if successfullyFilled.Length > 0 {
                summary .= "Successful fields:`n"
                for field in successfullyFilled
                    summary .= "  ✓ " . field . "`n"
            }

            if failedFields.Length > 0 {
                summary .= "`nFailed fields:`n"
                for field in failedFields
                    summary .= "  ✗ " . field . "`n"
            }

            MsgBox(summary, "Smart Fill Results", "Iconi")

        } catch Error as e {
            this.ShowFailureTooltip("Smart form filling failed: " . e.Message)
        }
    }

    FindFieldLabel(document, fieldName) {
        searchTerms := [fieldName]

        if InStr(fieldName, "?")
            searchTerms.Push(StrReplace(fieldName, "?", ""))

        for term in searchTerms {
            try {
                labelElement := document.FindElement({ Name: term, matchMode: 2 })
                if labelElement
                    return labelElement
            } catch {
                continue
            }
        }

        try {
            allElements := document.FindElements({ matchMode: 2 })
            for element in allElements {
                try {
                    if element.Name && InStr(element.Name, fieldName) {
                        return element
                    }
                } catch {
                    continue
                }
            }
        } catch {
        }

        return ""
    }

    FindInputForLabel(labelElement, fieldName, fieldValue) {
        searchRadius := 5

        try {
            if InStr(fieldName, "?") {
                radioGroup := labelElement.FindElement({ Type: "RadioButton" }, searchRadius)
                if radioGroup
                    return radioGroup
            } else {
                inputElement := labelElement.FindElement({ Type: "Edit" }, searchRadius)
                if inputElement
                    return inputElement

                comboElement := labelElement.FindElement({ Type: "ComboBox" }, searchRadius)
                if comboElement
                    return comboElement
            }
        } catch {
        }

        try {
            walker := UIA.TreeWalkerTrue
            current := labelElement

            loop searchRadius {
                current := walker.GetNextSiblingElement(current)
                if !current
                    break

                if InStr(fieldName, "?") {
                    if current.Type = UIA.Type.RadioButton
                        return current
                } else {
                    if current.Type = UIA.Type.Edit || current.Type = UIA.Type.ComboBox
                        return current
                }
            }
        } catch {
        }

        return ""
    }

    HandleRadioSelection(radioElement, value) {
        try {
            parent := UIA.TreeWalkerTrue.GetParentElement(radioElement)
            if parent {
                allRadios := parent.FindElements({ Type: "RadioButton" })
                for radio in allRadios {
                    try {
                        if InStr(radio.Name, value) {
                            radio.Select()
                            return
                        }
                    } catch {
                        continue
                    }
                }
            }
        } catch {
        }

        try {
            radioElement.Select()
        } catch {
        }
    }

    AdvancedFillForm(*) {
        if !this.state["json"] {
            this.ShowFailureTooltip("No JSON data available.")
            return
        }

        if !this.ValidateEdgeWindow() {
            return
        }

        try {
            formData := this.ExtractFormDataMap()
            if !formData.Count {
                this.ShowFailureTooltip("No form data extracted from JSON.")
                return
            }

            edge := UIA.GetBrowser("msedge.exe")
            if !edge {
                this.ShowFailureTooltip("Could not connect to Edge browser.")
                return
            }

            form := edge.WaitElement({ Name: "Public Outreach and Compliance Assistance Event Clearance Request" }, 5000)
            if !form {
                this.ShowFailureTooltip("Could not find the form. Please ensure you're on the correct page.")
                return
            }

            if !this.ValidateEdgeWindow() {
                return
            }

            currentIndex := 0
            totalFields := formData.Count

            for fieldName, fieldValue in formData {
                try {
                    currentIndex++

                    if !this.ValidateEdgeWindow() {
                        this.ShowFailureTooltip("Edge window lost focus during form filling.")
                        return
                    }

                    this.ShowProgressTooltip(fieldName, fieldValue, currentIndex, totalFields)

                    if InStr(fieldName, "?") {
                        radioGroup := form.FindFirst({ Name: fieldName })
                        if radioGroup {
                            radioOption := radioGroup.FindFirst({ Name: fieldValue })
                            if radioOption
                                radioOption.Select()
                        }
                    } else {
                        ctrl := form.FindFirst({ Name: fieldName })
                        if ctrl {
                            inputField := ctrl.GetNext("Edit,ComboBox")
                            if inputField {
                                inputField.Value := fieldValue
                            }
                        }
                    }
                    Sleep(this.formSettings["fieldDelay"])
                } catch {
                    continue
                }
            }

            try {
                submitBtn := form.FindFirst({ Name: "Submit", ControlType: "Button" })
                if submitBtn {
                    result := MsgBox("Form filled successfully! Click Yes to submit or No to review.", "Advanced Fill", 4)
                    if result = "Yes"
                        submitBtn.Invoke()
                }
            } catch {
                ToolTip("Form filled but could not find submit button. Please submit manually.", A_ScreenWidth // 2, A_ScreenHeight // 2)
                SetTimer(() => ToolTip(), -3000)
            }

        } catch Error as e {
            this.ShowFailureTooltip("Advanced form filling failed: " . e.Message)
        }
    }

    ExtractFormData() {
        formData := []
        jsonText := this.state["json"]

        if !jsonText
            return formData

        try {
            jsonLines := StrSplit(jsonText, "`n")
            for line in jsonLines {
                line := Trim(line)
                if !line || line = "[" || line = "]" || line = "{" || line = "}" || line = ","
                    continue

                if InStr(line, ":") {
                    parts := StrSplit(line, ":", 2)
                    if parts.Length >= 2 {
                        value := Trim(parts[2])
                        value := StrReplace(value, "`"", "")
                        value := StrReplace(value, ",", "")
                        value := Trim(value)
                        if value
                            formData.Push(value)
                    }
                }
            }
        } catch Error as e {
            throw Error("Failed to parse JSON: " . e.Message)
        }

        return formData
    }

    ExtractFormDataMap() {
        formData := Map()
        jsonText := this.state["json"]

        if !jsonText
            return formData

        try {
            jsonLines := StrSplit(jsonText, "`n")
            for line in jsonLines {
                line := Trim(line)
                if !line || line = "[" || line = "]" || line = "{" || line = "}" || line = ","
                    continue

                if InStr(line, ":") {
                    parts := StrSplit(line, ":", 2)
                    if parts.Length >= 2 {
                        key := Trim(parts[1])
                        key := StrReplace(key, "`"", "")
                        key := Trim(key)

                        value := Trim(parts[2])
                        value := StrReplace(value, "`"", "")
                        value := StrReplace(value, ",", "")
                        value := Trim(value)

                        if key && value
                            formData[key] := value
                    }
                }
            }
        } catch Error as e {
            throw Error("Failed to parse JSON: " . e.Message)
        }

        return formData
    }

    ParseJSONToStructuredData(jsonText) {
        parsedData := []

        try {
            jsonLines := StrSplit(jsonText, "`n")
            currentRecord := Map()

            for line in jsonLines {
                line := Trim(line)
                if !line || line = "[" || line = "]" || line = "{" || line = "}"
                    continue

                if line = "," {
                    if currentRecord.Count > 0 {
                        parsedData.Push(currentRecord)
                        currentRecord := Map()
                    }
                    continue
                }

                if InStr(line, ":") {
                    parts := StrSplit(line, ":", 2)
                    if parts.Length >= 2 {
                        key := Trim(parts[1])
                        key := StrReplace(key, "`"", "")
                        key := Trim(key)

                        value := Trim(parts[2])
                        value := StrReplace(value, "`"", "")
                        value := StrReplace(value, ",", "")
                        value := Trim(value)

                        if key
                            currentRecord[key] := value
                    }
                }
            }

            if currentRecord.Count > 0
                parsedData.Push(currentRecord)

        } catch Error as e {
            throw Error("Failed to parse JSON: " . e.Message)
        }

        return parsedData
    }

    UpdateStatus(message) {
        this.fullStatusMessage := message

        displayMessage := message
        if StrLen(message) > 25 {
            displayMessage := SubStr(message, 1, 22) . "..."
        }

        if this.designer.controls.Has("statusText") {
            this.designer.Get("statusText").Value := displayMessage

            if StrLen(message) > 25 {
                this.designer.Get("statusText").ToolTip := message
            } else {
                this.designer.Get("statusText").ToolTip := ""
            }
        }
    }

    HandleResize(g, minMax, w, h) {
        if (minMax = -1)
            return

        margin := 10
        leftPanelWidth := (w - 30) // 2
        rightPanelWidth := leftPanelWidth
        panelHeight := h - 250

        configY := 80
        dataY := configY + 110

        this.designer.Get("edtTSV").Move(margin, dataY + 25, leftPanelWidth, panelHeight - 25)
        this.designer.Get("lblTSVData").Move(margin, dataY)
        this.designer.Get("lblDataView").Move(margin + leftPanelWidth + 10, dataY)
        this.designer.Get("ddlDataView").Move(margin + leftPanelWidth + 90, dataY - 2)
        this.designer.Get("lvData").Move(margin + leftPanelWidth + 10, dataY + 25, rightPanelWidth, panelHeight - 25)
    }
}

class FieldConfigDialog {
    __New(fieldNavigation, columnNames, updateCallback) {
        this.fieldNavigation := fieldNavigation.Clone()
        this.columnNames := columnNames
        this.updateCallback := updateCallback
        this.CreateDialog()
    }

    CreateDialog() {
        this.gui := Gui("+Resize +MinSize400x300", "Field Navigation Configuration")
        this.darkMode := _Dark(this.gui)

        this.darkMode.AddDarkText("", "Configure navigation type for each field:")
        this.darkMode.AddDarkText("", "• TAB_ONLY: Send value then press Tab")
        this.darkMode.AddDarkText("", "• ENTER_TAB: Send value, press Enter, then Tab")

        this.listView := this.darkMode.AddListView("w450 h300 +Grid", ["#", "Field Name", "Navigation Type"])
        this.listView.ModifyCol(1, 40)
        this.listView.ModifyCol(2, 280)
        this.listView.ModifyCol(3, 120)

        this.PopulateListView()

        buttonPanel := this.darkMode.AddDarkText("w450 h40", "")
        this.darkMode.AddDarkButton("x10 y+10 w80 h25", "Toggle").OnEvent("Click", this.ToggleNavigation.Bind(this))
        this.darkMode.AddDarkButton("x100 y+-25 w80 h25", "Reset").OnEvent("Click", this.ResetToDefaults.Bind(this))
        this.darkMode.AddDarkButton("x290 y+-25 w80 h25", "Apply").OnEvent("Click", this.ApplyChanges.Bind(this))
        this.darkMode.AddDarkButton("x380 y+-25 w80 h25", "Close").OnEvent("Click", this.CloseDialog.Bind(this))

        this.gui.OnEvent("Close", this.CloseDialog.Bind(this))
    }

    PopulateListView() {
        this.listView.Delete()

        for index, fieldName in this.columnNames {
            navType := this.fieldNavigation.Get(index, "TAB_ONLY")
            this.listView.Add("", index, fieldName, navType)
        }
    }

    ToggleNavigation(*) {
        selectedRow := this.listView.GetNext()
        if !selectedRow
            return

        fieldIndex := Integer(this.listView.GetText(selectedRow, 1))
        currentNav := this.fieldNavigation.Get(fieldIndex, "TAB_ONLY")

        newNav := currentNav = "TAB_ONLY" ? "ENTER_TAB" : "TAB_ONLY"
        this.fieldNavigation[fieldIndex] := newNav

        this.listView.Modify(selectedRow, "Col3", newNav)
    }

    ResetToDefaults(*) {
        this.fieldNavigation := Map(
            2, "ENTER_TAB",
            8, "ENTER_TAB",
            9, "ENTER_TAB",
            10, "ENTER_TAB",
            11, "ENTER_TAB",
            12, "ENTER_TAB"
        )
        this.PopulateListView()
    }

    ApplyChanges(*) {
        this.updateCallback(this.fieldNavigation)
        MsgBox("Configuration updated successfully!", "Field Configuration", "Iconi")
    }

    CloseDialog(*) {
        this.gui.Destroy()
    }

    Show() {
        this.gui.Show("w470 h400")
    }
}

class GuiDesigner {
    __New() {
        this.gui := Gui()
        this.controls := Map()
        this.formatBuilder := GuiFormatBuilder()
    }

    AddControl(controlType, name, text := "", options := "") {
        builder := ControlChainBuilder(this, controlType, name, text, options)
        return builder
    }

    AddText(name, text := "", options := "") {
        return this.AddControl("Text", name, text, options)
    }

    AddButton(name, text := "", options := "") {
        return this.AddControl("Button", name, text, options)
    }

    AddEdit(name, text := "", options := "") {
        return this.AddControl("Edit", name, text, options)
    }

    AddListBox(name, items := [], options := "") {
        return this.AddControl("ListBox", name, items, options)
    }

    AddDropDownList(name, items := [], options := "") {
        return this.AddControl("DropDownList", name, items, options)
    }

    AddListView(name, columns := "", options := "") {
        return this.AddControl("ListView", name, columns, options)
    }

    AddCheckbox(name, text := "", options := "") {
        return this.AddControl("Checkbox", name, text, options)
    }

    AddRadio(name, text := "", options := "") {
        return this.AddControl("Radio", name, text, options)
    }

    AddGroupBox(name, text := "", options := "") {
        return this.AddControl("GroupBox", name, text, options)
    }

    AddPicture(name, filename := "", options := "") {
        return this.AddControl("Picture", name, filename, options)
    }

    Format(x := "", y := "", w := "", h := "", options := "") {
        this.formatBuilder.Reset()
        if IsSet(x) && x !== ""
            this.formatBuilder.Position(x, y)
        if IsSet(w) && w !== ""
            this.formatBuilder.Size(w, h)
        if IsSet(options) && options !== ""
            this.formatBuilder.ExtraParams(options)
        return this.formatBuilder
    }

    Build() {
        this.gui.Show()
        return this
    }

    Hide() {
        this.gui.Hide()
        return this
    }

    OnEvent(eventName, callback) {
        this.gui.OnEvent(eventName, callback)
        return this
    }

    Get(name) {
        return this.controls.Has(name) ? this.controls[name] : ""
    }
}

class ControlChainBuilder {
    __New(designer, type, name, text := "", options := "") {
        this.designer := designer
        this.type := type
        this.name := name
        this.text := text
        this.options := options
        this._position := Map("x", "", "y", "")
        this.dimensions := Map("w", "", "h", "")
        this.events := []
        this.styles := []
        this.extraOptions := []
    }

    Position(x, y) {
        this._position["x"] := x
        this._position["y"] := y
        return this
    }

    Size(w, h) {
        this.dimensions["w"] := w
        this.dimensions["h"] := h
        return this
    }

    Pos(x, y) {
        return this.Position(x, y)
    }

    Default() {
        this.styles.Push("Default")
        return this
    }

    Center() {
        this.styles.Push("Center")
        return this
    }

    ReadOnly() {
        this.styles.Push("ReadOnly")
        return this
    }

    Password() {
        this.styles.Push("Password")
        return this
    }

    Multi() {
        this.styles.Push("Multi")
        return this
    }

    Hidden() {
        this.styles.Push("Hidden")
        return this
    }

    Background(color) {
        this.styles.Push("Background" color)
        return this
    }

    Color(color) {
        this.styles.Push("c" color)
        return this
    }

    Font(name, size := "", options := "") {
        fontOpt := "" size " " name
        if options
            fontOpt .= " " options
        this.styles.Push(fontOpt)
        return this
    }

    OnEvent(eventName, callback) {
        this.events.Push([eventName, callback])
        return this
    }

    Var(varName) {
        this.extraOptions.Push("v" varName)
        return this
    }

    WantReturn() {
        this.extraOptions.Push("WantReturn")
        return this
    }

    WantTab() {
        this.extraOptions.Push("WantTab")
        return this
    }

    Choose(n) {
        this.extraOptions.Push("Choose" n)
        return this
    }

    Build() {
        format := ""

        if this._position["x"] !== "" && this._position["y"] !== ""
            format .= "x" this._position["x"] " y" this._position["y"] " "

        if this.dimensions["w"] !== ""
            format .= "w" this.dimensions["w"] " "
        if this.dimensions["h"] !== ""
            format .= "h" this.dimensions["h"] " "

        for _, style in this.styles
            format .= style " "

        for _, option in this.extraOptions
            format .= option " "

        if this.options
            format .= this.options " "

        format := Trim(format)

        darkMode := _Dark.Instances[this.designer.gui.Hwnd]

        ctrl := ""
        switch this.type {
            case "Text":
                ctrl := darkMode ? darkMode.AddDarkText(format, this.text) : this.designer.gui.AddText(format, this.text)
            case "Button":
                ctrl := darkMode ? darkMode.AddDarkButton(format, this.text) : this.designer.gui.AddButton(format, this.text)
            case "Edit":
                ctrl := darkMode ? darkMode.AddDarkEdit(format, this.text) : this.designer.gui.AddEdit(format, this.text)
            case "ListBox":
                ctrl := darkMode ? darkMode.AddDarkListBox(format, this.text) : this.designer.gui.AddListBox(format, this.text)
            case "DropDownList":
                ctrl := darkMode ? darkMode.AddDarkComboBox(format, this.text) : this.designer.gui.AddDropDownList(format, this.text)
            case "ListView":
                if this.text = ""
                    ctrl := darkMode ? darkMode.AddListView(format) : this.designer.gui.AddListView(format)
                else
                    ctrl := darkMode ? darkMode.AddListView(format, this.text) : this.designer.gui.AddListView(format, this.text)
            case "Checkbox":
                ctrl := darkMode ? darkMode.AddDarkCheckBox(format, this.text) : this.designer.gui.AddCheckbox(format, this.text)
            case "Radio":
                ctrl := darkMode ? darkMode.AddDarkRadio(format, this.text) : this.designer.gui.AddRadio(format, this.text)
            case "GroupBox":
                ctrl := darkMode ? darkMode.AddDarkGroupBox(format, this.text) : this.designer.gui.AddGroupBox(format, this.text)
            case "Picture":
                ctrl := this.designer.gui.AddPicture(format, this.text)
        }

        for _, event in this.events
            ctrl.OnEvent(event[1], event[2])

        this.designer.controls[this.name] := ctrl

        return this.designer
    }
}

class GuiFormatBuilder {
    __New() {
        this._x := ""
        this._y := ""
        this._w := ""
        this._h := ""
        this._extraParams := ""
    }

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
        if this._x !== "" && this._y !== ""
            params .= "x" this._x " y" this._y " "
        if this._w !== ""
            params .= "w" this._w " "
        if this._h !== ""
            params .= "h" this._h " "
        if this._extraParams
            params .= this._extraParams " "
        return Trim(params)
    }

    Reset() {
        this._x := ""
        this._y := ""
        this._w := ""
        this._h := ""
        this._extraParams := ""
        return this
    }
}

; Include the dark mode classes and functions
_DarkSliderCustomDrawCallback(hWnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) {
    static WM_PAINT := 0x000F
    static WM_MOUSEMOVE := 0x0200
    static WM_MOUSELEAVE := 0x02A3
    static WM_LBUTTONDOWN := 0x0201
    static WM_LBUTTONUP := 0x0202
    static TME_LEAVE := 0x00000002
    if (uMsg = WM_MOUSEMOVE) {
        if !_Dark.SliderControls[hWnd].Has("tracking") {
            trackStruct := Buffer(16, 0)
            NumPut("UInt", 16, trackStruct, 0)
            NumPut("UInt", TME_LEAVE, trackStruct, 4)
            NumPut("Ptr", hWnd, trackStruct, 8)
            DllCall("TrackMouseEvent", "Ptr", trackStruct)
            _Dark.SliderControls[hWnd]["tracking"] := true
            _Dark.SliderControls[hWnd]["state"] := "hover"
            DllCall("InvalidateRect", "Ptr", hWnd, "Ptr", 0, "Int", true)
        }
    } else if (uMsg = WM_MOUSELEAVE) {
        _Dark.SliderControls[hWnd].Delete("tracking")
        _Dark.SliderControls[hWnd]["state"] := "normal"
        DllCall("InvalidateRect", "Ptr", hWnd, "Ptr", 0, "Int", true)
    } else if (uMsg = WM_LBUTTONDOWN) {
        _Dark.SliderControls[hWnd]["state"] := "active"
        DllCall("InvalidateRect", "Ptr", hWnd, "Ptr", 0, "Int", true)
    } else if (uMsg = WM_LBUTTONUP) {
        if _Dark.SliderControls[hWnd].Has("tracking") {
            _Dark.SliderControls[hWnd]["state"] := "hover"
        } else {
            _Dark.SliderControls[hWnd]["state"] := "normal"
        }
        DllCall("InvalidateRect", "Ptr", hWnd, "Ptr", 0, "Int", true)
    } else if (uMsg = 0x02) {
        if _Dark.ControlCallbacks.Has(hWnd) {
            callback := _Dark.ControlCallbacks[hWnd]
            DllCall("RemoveWindowSubclass", "Ptr", hWnd, "Ptr", callback, "Ptr", hWnd)
            CallbackFree(callback)
            _Dark.ControlCallbacks.Delete(hWnd)
        }
    }
    return DllCall("DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}

_DarkHeaderCustomDrawCallback(hWnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) {
    static HDM_GETITEM := 0x120B
    static NM_CUSTOMDRAW := -12
    static CDRF_DODEFAULT := 0x00000000
    static CDRF_SKIPDEFAULT := 0x00000004
    static CDRF_NOTIFYITEMDRAW := 0x00000020
    static CDRF_NOTIFYPOSTPAINT := 0x00000010
    static CDDS_PREPAINT := 0x00000001
    static CDDS_ITEMPREPAINT := 0x00010001
    static CDDS_POSTPAINT := 0x00000002
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
        if _Dark.HeaderColors.Has(HWND) && HC := _Dark.HeaderColors[HWND] {
            Code := NumGet(lParam + OMsg, "Int")
            if (Code = NM_CUSTOMDRAW) {
                DrawStage := NumGet(lParam + ODrawStage, "UInt")
                HDC := NumGet(lParam + OHDC, "Ptr")

                if (DrawStage = CDDS_PREPAINT) {
                    headerRect := Buffer(16, 0)
                    DllCall("GetClientRect", "Ptr", HWND, "Ptr", headerRect)
                    dcBrush := DllCall("GetStockObject", "UInt", DC_BRUSH, "ptr")
                    DllCall("SetDCBrushColor", "Ptr", HDC, "UInt", HC["Bkg"])
                    DllCall("FillRect", "Ptr", HDC, "Ptr", headerRect, "Ptr", dcBrush)
                    return CDRF_NOTIFYITEMDRAW | CDRF_NOTIFYPOSTPAINT
                }

                if (DrawStage = CDDS_POSTPAINT) {
                    headerRect := Buffer(16, 0)
                    DllCall("GetClientRect", "Ptr", HWND, "Ptr", headerRect)

                    columnCount := DllCall("SendMessage", "Ptr", HWND, "UInt", 0x1200, "Ptr", 0, "Ptr", 0, "Int")
                    if (columnCount > 0) {
                        lastItemRect := Buffer(16, 0)
                        DllCall("SendMessage", "Ptr", HWND, "UInt", 0x1207, "Ptr", columnCount - 1, "Ptr", lastItemRect)

                        rightEdge := NumGet(lastItemRect, 8, "Int")
                        clientWidth := NumGet(headerRect, 8, "Int")

                        if (rightEdge < clientWidth) {
                            emptyRect := Buffer(16, 0)
                            NumPut("Int", rightEdge, emptyRect, 0)
                            NumPut("Int", 0, emptyRect, 4)
                            NumPut("Int", clientWidth, emptyRect, 8)
                            NumPut("Int", NumGet(headerRect, 12, "Int"), emptyRect, 12)

                            dcBrush := DllCall("GetStockObject", "UInt", DC_BRUSH, "ptr")
                            DllCall("SetDCBrushColor", "Ptr", HDC, "UInt", HC["Bkg"])
                            DllCall("FillRect", "Ptr", HDC, "Ptr", emptyRect, "Ptr", dcBrush)
                        }
                    }
                    return CDRF_SKIPDEFAULT
                }

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

                    if (Item = 0) && (Order = 0)
                        NumPut("Int", NumGet(lParam, ORect, "Int") + LM, lParam + ORect)
                    dcBrush := DllCall("GetStockObject", "UInt", DC_BRUSH, "ptr")
                    DllCall("SetDCBrushColor", "Ptr", HDC, "UInt", HC["Bkg"])
                    DllCall("FillRect", "Ptr", HDC, "Ptr", lParam + ORect, "Ptr", dcBrush)
                    if (Item = 0) && (Order = 0)
                        NumPut("Int", NumGet(lParam, ORect, "Int") - LM, lParam, ORect)
                    DllCall("SetBkMode", "Ptr", HDC, "UInt", TRANSPARENT)
                    DllCall("SetTextColor", "Ptr", HDC, "UInt", 0xFFFFFF)
                    DllCall("InflateRect", "Ptr", lParam + ORect, "Int", -TM, "Int", 0)
                    DT_ALIGN := 0x0224 + ((Fmt & 1) ? 2 : (Fmt & 2) ? 1 : 0)
                    DllCall("DrawText", "Ptr", HDC, "Ptr", ItemTxt, "Int", -1, "Ptr", lParam + ORect, "UInt", DT_ALIGN)
                    return CDRF_SKIPDEFAULT
                }
                return CDRF_DODEFAULT
            }
        }
    } else if (uMsg = 0x02) {
        if _Dark.ControlCallbacks.Has(hWnd) {
            callback := _Dark.ControlCallbacks[hWnd]
            DllCall("RemoveWindowSubclass", "Ptr", hWnd, "Ptr", callback, "Ptr", hWnd)
            CallbackFree(callback)
            _Dark.ControlCallbacks.Delete(hWnd)
        }
    }
    return DllCall("DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}

class _Dark {
    class RECT {
        left := 0
        top := 0
        right := 0
        bottom := 0
    }

    class NMHDR {
        hwndFrom := 0
        idFrom := 0
        code := 0
    }

    class NMCUSTOMDRAW {
        hdr := 0
        dwDrawStage := 0
        hdc := 0
        rc := 0
        dwItemSpec := 0
        uItemState := 0
        lItemlParam := 0
        __New() {
            this.hdr := _Dark.NMHDR()
            this.rc := _Dark.RECT()
        }
    }

    static StructFromPtr(StructClass, ptr) {
        obj := StructClass()
        if (StructClass.Prototype.__Class = "NMHDR") {
            obj.hwndFrom := NumGet(ptr, 0, "UPtr")
            obj.idFrom := NumGet(ptr, A_PtrSize, "UPtr")
            obj.code := NumGet(ptr, A_PtrSize * 2, "Int")
        } else if (StructClass.Prototype.__Class = "NMCUSTOMDRAW") {
            obj.hdr := _Dark.NMHDR()
            obj.hdr.hwndFrom := NumGet(ptr, 0, "UPtr")
            obj.hdr.idFrom := NumGet(ptr, A_PtrSize, "UPtr")
            obj.hdr.code := NumGet(ptr, A_PtrSize * 2, "Int")
            obj.dwDrawStage := NumGet(ptr, A_PtrSize * 3, "UInt")
            obj.hdc := NumGet(ptr, A_PtrSize * 3 + 4, "UPtr")
            obj.rc := _Dark.RECT()
            rectOffset := A_PtrSize * 3 + 4 + A_PtrSize
            obj.rc.left := NumGet(ptr, rectOffset, "Int")
            obj.rc.top := NumGet(ptr, rectOffset + 4, "Int")
            obj.rc.right := NumGet(ptr, rectOffset + 8, "Int")
            obj.rc.bottom := NumGet(ptr, rectOffset + 12, "Int")
            obj.dwItemSpec := NumGet(ptr, rectOffset + 16, "UPtr")
            obj.uItemState := NumGet(ptr, rectOffset + 16 + A_PtrSize, "UInt")
            obj.lItemlParam := NumGet(ptr, rectOffset + 16 + A_PtrSize + 4, "IPtr")
        }
        return obj
    }

    static DarkColors := Map("Background", 0x171717, "Controls", 0x202020, "Font", 0xFFFFFF)
    static Dark := Map("Background", 0x171717, "Controls", 0x1b1b1b, "ComboBoxBg", 0x1E1E1E, "Font", 0xE0E0E0, "SliderThumb", 0x3E3E3E, "SliderTrack", 0x2D2D2D, "ProgressFill", 0x0078D7)
    static Instances := Map()
    static WindowProcOldMap := Map()
    static WindowProcCallbacks := Map()
    static TextBackgroundBrush := 0
    static ControlsBackgroundBrush := 0
    static ButtonColors := Map()
    static ComboBoxes := Map()
    static ListViewHeaders := Map()
    static HeaderCallbacks := Map()
    static CheckboxTextControls := Map()
    static TextControls := Map()
    static DarkCheckboxPairs := Map()
    static DarkRadioPairs := Map()
    static GroupBoxes := Map()
    static RadioButtons := Map()
    static SliderControls := Map()
    static ProgressControls := Map()
    static DateTimeControls := Map()
    static TabControls := Map()
    static ListBoxControls := Map()
    static TreeViewControls := Map()
    static ControlCallbacks := Map()
    static HeaderColors := Map()
    static WM_CTLCOLOREDIT := 0x0133
    static WM_CTLCOLORLISTBOX := 0x0134
    static WM_CTLCOLORBTN := 0x0135
    static WM_CTLCOLORSTATIC := 0x0138
    static WM_NOTIFY := 0x004E
    static WM_PAINT := 0x000F
    static WM_ERASEBKGND := 0x0014
    static DC_BRUSH := 18
    static GWL_WNDPROC := -4
    static GWL_STYLE := -16
    static GetWindowLong := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
    static SetWindowLong := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"

    static __New() {
        global _Dark_WindowProc := ObjBindMethod(_Dark, "ProcessWindowMessage")
        if (!_Dark.TextBackgroundBrush)
            _Dark.TextBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Background"], "Ptr")
        if (!_Dark.ControlsBackgroundBrush)
            _Dark.ControlsBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Controls"], "Ptr")
    }

    static ProcessWindowMessage(hwnd, msg, wParam, lParam, *) {
        static WM_CTLCOLOREDIT := 0x0133
        static WM_CTLCOLORLISTBOX := 0x0134
        static WM_CTLCOLORBTN := 0x0135
        static WM_CTLCOLORSTATIC := 0x0138
        static WM_NOTIFY := 0x004E
        static TRANSPARENT := 1
        static NM_CUSTOMDRAW := -12
        static CDDS_PREPAINT := 0x00000001
        static CDDS_ITEMPREPAINT := 0x00010001
        static CDRF_DODEFAULT := 0x0
        static CDRF_NOTIFYITEMDRAW := 0x00000020
        if _Dark.WindowProcOldMap.Has(hwnd) {
            oldProc := _Dark.WindowProcOldMap[hwnd]
        } else {
            return DllCall("DefWindowProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
        }
        ctrlHwnd := lParam
        switch msg {
            case WM_CTLCOLOREDIT, WM_CTLCOLORLISTBOX:
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Controls"])
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                return _Dark.ControlsBackgroundBrush
            case WM_CTLCOLORBTN:
                if _Dark.ButtonColors.Has(ctrlHwnd) {
                    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.ButtonColors[ctrlHwnd]["bg"])
                    DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                    return _Dark.ControlsBackgroundBrush
                }
            case WM_CTLCOLORSTATIC:
                if _Dark.TextControls.Has(ctrlHwnd) || _Dark.GroupBoxes.Has(ctrlHwnd) || _Dark.DarkCheckboxPairs.Has(ctrlHwnd) || _Dark.DarkRadioPairs.Has(ctrlHwnd) {
                    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Background"])
                    DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                    return _Dark.TextBackgroundBrush
                }
        }
        return DllCall("CallWindowProc", "Ptr", oldProc, "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    static SetWindowPos(hWnd, hWndInsertAfter, X := 0, Y := 0, cx := 0, cy := 0, uFlags := 0x40) {
        return DllCall("User32\SetWindowPos", "ptr", hWnd, "ptr", hWndInsertAfter, "int", X, "int", Y, "int", cx, "int", cy, "uint", uFlags, "int")
    }

    static SendMessage(msg, wParam, lParam, hwndOrControl) {
        hwnd := HasProp(hwndOrControl, "Hwnd") ? hwndOrControl.Hwnd : hwndOrControl
        return DllCall("user32\SendMessage", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    static SetTextColor(hdc, color) {
        return DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", color)
    }

    static SetBkMode(hdc, mode) {
        return DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", mode)
    }

    __New(GuiObj) {
        _Dark.__New()
        this.Gui := GuiObj
        this.darkCheckboxes := Map()
        this.darkRadios := Map()
        this.radioGroups := Map()
        this.Gui.BackColor := _Dark.Dark["Background"]
        if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
            DWMWA_USE_IMMERSIVE_DARK_MODE := 19
            if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
                DWMWA_USE_IMMERSIVE_DARK_MODE := 20
            uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
            SetPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
            FlushMenuThemes := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Gui.hWnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", true, "Int", 4)
            DllCall(SetPreferredAppMode, "Int", 2)
            DllCall(FlushMenuThemes)
        }
        this.SetControlsTheme()
        this.SetupWindowProc()
        this.RedrawAllControls()
        _Dark.Instances[this.Gui.Hwnd] := this
        return this
    }

    SetupWindowProc() {
        hwnd := this.Gui.Hwnd
        if _Dark.WindowProcOldMap.Has(hwnd)
            return
        callback := CallbackCreate(_Dark_WindowProc, , 4)
        _Dark.WindowProcCallbacks[hwnd] := callback
        originalProc := DllCall(_Dark.SetWindowLong, "Ptr", hwnd, "Int", _Dark.GWL_WNDPROC, "Ptr", callback, "Ptr")
        _Dark.WindowProcOldMap[hwnd] := originalProc
    }

    SetTheme(themeMap) {
        if themeMap.Has("Background")
            _Dark.Dark["Background"] := themeMap["Background"]
        if themeMap.Has("Controls")
            _Dark.Dark["Controls"] := themeMap["Controls"]
        if themeMap.Has("Font")
            _Dark.Dark["Font"] := themeMap["Font"]
        this.Gui.BackColor := _Dark.Dark["Background"]
        if (_Dark.TextBackgroundBrush) {
            DllCall("DeleteObject", "Ptr", _Dark.TextBackgroundBrush)
            _Dark.TextBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Background"], "Ptr")
        }
        if (_Dark.ControlsBackgroundBrush) {
            DllCall("DeleteObject", "Ptr", _Dark.ControlsBackgroundBrush)
            _Dark.ControlsBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Controls"], "Ptr")
        }
        this.RedrawAllControls()
    }

    AddDarkCheckBox(Options, Text) {
        static SM_CXMENUCHECK := 71
        static SM_CYMENUCHECK := 72
        static checkBoxW := SysGet(SM_CXMENUCHECK)
        static checkBoxH := SysGet(SM_CYMENUCHECK)
        chbox := this.Gui.AddCheckBox(Options " r1.5 +0x4000000", "")
        if !InStr(Options, "right")
            txt := this.Gui.AddText("xp+" (checkBoxW + 8) " yp+2 HP-4 +0x4000200 cFFFFFF", Text)
        else
            txt := this.Gui.AddText("xp+8 yp+2 HP-4 +0x4000200 cFFFFFF", Text)
        this.darkCheckboxes[chbox.Hwnd] := txt
        chbox.DeleteProp("Text")
        chbox.DefineProp("Text", { Get: ObjBindMethod(txt, "GetText"), Set: ObjBindMethod(txt, "SetText") })
        _Dark.SetWindowPos(txt.Hwnd, 0, 0, 0, 0, 0, 0x43)
        DllCall("uxtheme\SetWindowTheme", "Ptr", chbox.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        pair := Map()
        pair["checkbox"] := chbox
        pair["text"] := txt
        _Dark.DarkCheckboxPairs[chbox.Hwnd] := pair
        DllCall("InvalidateRect", "Ptr", chbox.Hwnd, "Ptr", 0, "Int", true)
        DllCall("InvalidateRect", "Ptr", txt.Hwnd, "Ptr", 0, "Int", true)
        return chbox
    }

    AddListView(Options, Headers) {
        lv := this.Gui.Add("ListView", Options, Headers)
        static LVM_SETBKCOLOR := 0x1001
        static LVM_SETTEXTCOLOR := 0x1033
        static LVM_SETTEXTBKCOLOR := 0x1026
        static LVM_GETHEADER := 0x101F
        static LVM_SETOUTLINECOLOR := 0x10B1
        static LVS_EX_DOUBLEBUFFER := 0x10000
        static LVS_EX_GRIDLINES := 0x00000001
        static LVM_SETEXTENDEDLISTVIEWSTYLE := 0x1036
        static UIS_SET := 1
        static UISF_HIDEFOCUS := 0x1
        static WM_CHANGEUISTATE := 0x0127
        static WM_THEMECHANGED := 0x031A

        Background := _Dark.Dark["Background"]
        Foreground := 0xFFFFFF
        GridColor := 0x1A1A1A  ; Very dark grey for grid lines

        ; Set basic colors (don't change these - user specified)
        _Dark.SendMessage(LVM_SETBKCOLOR, 0, Background, lv.hWnd)
        _Dark.SendMessage(LVM_SETTEXTCOLOR, 0, Foreground, lv.hWnd)
        _Dark.SendMessage(LVM_SETTEXTBKCOLOR, 0, Background, lv.hWnd)

        ; Enable gridlines first, then set color
        _Dark.SendMessage(LVM_SETEXTENDEDLISTVIEWSTYLE, LVS_EX_GRIDLINES, LVS_EX_GRIDLINES, lv.hWnd)
        _Dark.SendMessage(LVM_SETOUTLINECOLOR, 0, GridColor, lv.hWnd)

        HeaderHwnd := _Dark.SendMessage(LVM_GETHEADER, 0, 0, lv.Hwnd)
        lv.Header := HeaderHwnd
        DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        DllCall("uxtheme\SetWindowTheme", "Ptr", HeaderHwnd, "Str", "", "Ptr", 0)
        lv.Opt("+Grid +LV" LVS_EX_DOUBLEBUFFER)
        _Dark.SendMessage(WM_CHANGEUISTATE, (UIS_SET << 8) | UISF_HIDEFOCUS, 0, lv.Hwnd)
        lv.OnMessage(WM_THEMECHANGED, (*) => 0)
        _Dark.SetListViewHeaderColors(lv, _Dark.Dark["Controls"], 0xFFFFFF)
        lv.SetFont("cFFFFFF")

        ; Force grid color update after everything is set up
        SetTimer(() => _Dark.SendMessage(LVM_SETOUTLINECOLOR, 0, GridColor, lv.hWnd), -100)

        DllCall("InvalidateRect", "Ptr", HeaderHwnd, "Ptr", 0, "Int", true)
        DllCall("InvalidateRect", "Ptr", lv.Hwnd, "Ptr", 0, "Int", true)
        DllCall("UpdateWindow", "Ptr", HeaderHwnd)
        DllCall("UpdateWindow", "Ptr", lv.Hwnd)
        return lv
    }

    static SetListViewHeaderColors(ListViewCtrl, BackgroundColor?, TextColor?) {
        HHDR := _Dark.SendMessage(0x101F, 0, 0, ListViewCtrl.Hwnd)
        if !(IsSet(BackgroundColor) || IsSet(TextColor)) && (_Dark.HeaderColors.Has(HHDR)) {
            return (_Dark.HeaderColors.Delete(HHDR), DllCall("RedrawWindow", "Ptr", ListViewCtrl.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0001))
        } else if (IsSet(BackgroundColor) && IsSet(TextColor)) {
            if !(_Dark.HeaderColors.Has(HHDR)) {
                _Dark.SubclassControl(ListViewCtrl, _DarkHeaderCustomDrawCallback)
            }
            BackgroundColor := _Dark.RGBtoBGR(BackgroundColor)
            TextColor := TextColor = 0xFFFFFF ? 0xFFFFFF : _Dark.RGBtoBGR(TextColor)
            _Dark.HeaderColors[HHDR] := Map("Txt", TextColor, "Bkg", BackgroundColor)
        }
        DllCall("RedrawWindow", "Ptr", ListViewCtrl.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0001)
    }

    static SubclassSlider(sliderControl) {
        if _Dark.ControlCallbacks.Has(sliderControl.Hwnd) {
            DllCall("RemoveWindowSubclass", "Ptr", sliderControl.Hwnd, "Ptr", _Dark.ControlCallbacks[sliderControl.Hwnd], "Ptr", sliderControl.Hwnd)
            CallbackFree(_Dark.ControlCallbacks[sliderControl.Hwnd])
            _Dark.ControlCallbacks.Delete(sliderControl.Hwnd)
        }
        _Dark.SliderControls[sliderControl.Hwnd]["state"] := "normal"
        CB := CallbackCreate(_DarkSliderCustomDrawCallback, "F", 6)
        if CB && DllCall("SetWindowSubclass", "Ptr", sliderControl.Hwnd, "Ptr", CB, "Ptr", sliderControl.Hwnd, "Ptr", 0) {
            _Dark.ControlCallbacks[sliderControl.Hwnd] := CB
            return true
        }
        if CB
            CallbackFree(CB)
        return false
    }

    static SubclassControl(HCTL, FuncObj, Data := 0) {
        if _Dark.ControlCallbacks.Has(HCTL) {
            DllCall("RemoveWindowSubclass", "Ptr", HCTL.Hwnd, "Ptr", _Dark.ControlCallbacks[HCTL], "Ptr", HCTL.Hwnd)
            CallbackFree(_Dark.ControlCallbacks[HCTL])
            _Dark.ControlCallbacks.Delete(HCTL)
        }
        if !(FuncObj is Func && FuncObj.MaxParams == 6) && FuncObj != "" {
            return false
        }
        if FuncObj == "" {
            return true
        }
        CB := CallbackCreate(FuncObj, "F", 6)
        if !CB {
            return false
        }
        if !DllCall("SetWindowSubclass", "Ptr", HCTL.Hwnd, "Ptr", CB, "Ptr", HCTL.Hwnd, "Ptr", Data) {
            CallbackFree(CB)
            return false
        }
        return (_Dark.ControlCallbacks[HCTL] := CB)
    }

    static RGBtoBGR(RGB) {
        if (!IsNumber(RGB)) {
            RGB := "0x" . RGB
        }
        return ((RGB & 0xFF) << 16) | (RGB & 0xFF00) | ((RGB & 0xFF0000) >> 16)
    }

    AddDarkButton(Options, Text) {
        btn := this.Gui.AddButton(Options, Text)
        DllCall("uxtheme\SetWindowTheme", "Ptr", btn.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        buttonColorMap := Map("bg", _Dark.Dark["Controls"], "text", _Dark.Dark["Font"])
        _Dark.ButtonColors[btn.Hwnd] := buttonColorMap
        btn.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", btn.hWnd, "Ptr", 0, "Int", true)
        return btn
    }

    AddDarkEdit(Options, Text := "") {
        edit := this.Gui.AddEdit(Options, Text)
        DllCall("uxtheme\SetWindowTheme", "Ptr", edit.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        edit.SetFont("cFFFFFF")
        if InStr(Options, "ReadOnly") {
            DllCall("SendMessage", "Ptr", edit.hWnd, "UInt", 0x000C, "Ptr", 0, "AStr", Text)
            static SWP_FRAMECHANGED := 0x0020
            static SWP_NOMOVE := 0x0002
            static SWP_NOSIZE := 0x0001
            _Dark.SetWindowPos(edit.hWnd, 0, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE)
        }
        DllCall("InvalidateRect", "Ptr", edit.hWnd, "Ptr", 0, "Int", true)
        return edit
    }

    AddDarkComboBox(Options, Items := "") {
        ; Calculate dropdown height based on number of items
        itemCount := Items is Array ? Items.Length : (Items != "" ? StrSplit(Items, "|").Length : 0)
        itemHeight := 18  ; Height per item in dropdown
        baseHeight := 25  ; Base height for edit portion
        dropdownHeight := baseHeight + (itemCount * itemHeight) + 6  ; Add padding

        ; Remove h0 if present and replace with calculated height
        Options := RegExReplace(Options, "\bh0\b", "")
        if RegExMatch(Options, "h\d+", &match) {
            Options := StrReplace(Options, match[0], "h" . dropdownHeight)
        } else {
            Options .= " h" . dropdownHeight
        }

        combo := this.Gui.AddComboBox(Options, Items)
        DllCall("uxtheme\SetWindowTheme", "Ptr", combo.hWnd, "Str", "DarkMode_CFD", "Ptr", 0)
        _Dark.ComboBoxes[combo.Hwnd] := true
        combo.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", combo.hWnd, "Ptr", 0, "Int", true)
        return combo
    }

    AddDarkText(Options, Text := "") {
        txt := this.Gui.AddText(Options " cFFFFFF", Text)
        _Dark.TextControls[txt.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", txt.Hwnd, "Ptr", 0, "Int", true)
        return txt
    }

    AddDarkGroupBox(Options, Text := "") {
        groupBox := this.Gui.AddGroupBox(Options, Text)
        DllCall("uxtheme\SetWindowTheme", "Ptr", groupBox.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        groupBox.SetFont("cFFFFFF")
        _Dark.GroupBoxes[groupBox.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", groupBox.hWnd, "Ptr", 0, "Int", true)
        DllCall("UpdateWindow", "Ptr", groupBox.hWnd)
        return groupBox
    }

    AddDarkRadio(Options, Text := "", GroupName := "DefaultRadioGroup", GuiInstance := "") {
        static SM_CXMENUCHECK := 71
        static SM_CYMENUCHECK := 72
        static radioW := SysGet(SM_CXMENUCHECK)
        static radioH := SysGet(SM_CYMENUCHECK)
        radio := this.Gui.AddRadio(Options " r1.5 +0x4000000", "")
        if !InStr(Options, "right")
            txt := this.Gui.AddText("xp+" (radioW + 8) " yp+2 HP-4 +0x4000200 cFFFFFF", Text)
        else
            txt := this.Gui.AddText("xp+8 yp+2 HP-4 +0x4000200 cFFFFFF", Text)
        this.darkRadios[radio.Hwnd] := txt
        radio.DeleteProp("Text")
        radio.DefineProp("Text", { Get: GetRadioText, Set: SetRadioText })
        GetRadioText(*) {
            return txt.Text
        }
        SetRadioText(value) {
            txt.Text := value
        }
        _Dark.SetWindowPos(txt.Hwnd, 0, 0, 0, 0, 0, 0x43)
        DllCall("uxtheme\SetWindowTheme", "Ptr", radio.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        pair := Map()
        pair["radio"] := radio
        pair["text"] := txt
        pair["group"] := GroupName
        _Dark.DarkRadioPairs[radio.Hwnd] := pair
        _Dark.RadioButtons[radio.Hwnd] := true
        if !this.radioGroups.Has(GroupName)
            this.radioGroups[GroupName] := []
        this.radioGroups[GroupName].Push(radio)
        if GuiInstance && GuiInstance.HasMethod("HandleRadioClick") {
            radio.OnEvent("Click", GuiInstance.HandleRadioClick.Bind(GuiInstance, radio, GroupName))
            txt.OnEvent("Click", (*) => this.HandleTextClick(radio, GroupName, GuiInstance))
        } else {
            radio.OnEvent("Click", this.HandleRadioClick.Bind(this, radio, GroupName))
            txt.OnEvent("Click", (*) => this.HandleTextClick(radio, GroupName, ""))
        }
        DllCall("InvalidateRect", "Ptr", radio.Hwnd, "Ptr", 0, "Int", true)
        DllCall("InvalidateRect", "Ptr", txt.Hwnd, "Ptr", 0, "Int", true)
        return radio
    }

    HandleRadioClick(clickedRadio, groupName, *) {
        if this.radioGroups.Has(groupName) {
            for radio in this.radioGroups[groupName] {
                if radio != clickedRadio {
                    radio.Value := 0
                }
            }
        }
    }

    HandleTextClick(radio, groupName, GuiInstance, *) {
        radio.Value := 1
        if GuiInstance && GuiInstance.HasMethod("HandleRadioClick") {
            GuiInstance.HandleRadioClick(radio, groupName)
        } else {
            this.HandleRadioClick(radio, groupName)
        }
    }

    AddDarkListBox(Options, Items := "") {
        listBox := this.Gui.AddListBox(Options, Items)
        DllCall("uxtheme\SetWindowTheme", "Ptr", listBox.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        _Dark.ListBoxControls[listBox.Hwnd] := true
        listBox.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", listBox.hWnd, "Ptr", 0, "Int", true)
        return listBox
    }

    AddDarkSlider(Options, StartingValue := 0) {
        slider := this.Gui.AddSlider(Options, StartingValue)
        DllCall("uxtheme\SetWindowTheme", "Ptr", slider.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        _Dark.SliderControls[slider.Hwnd] := Map("hover", 0x3A3A3A, "active", 0x2A2A2A, "normal", 0x1A1A1A)
        _Dark.SubclassSlider(slider)
        DllCall("InvalidateRect", "Ptr", slider.hWnd, "Ptr", 0, "Int", true)
        return slider
    }

    AddDarkProgress(Options, StartingValue := 0) {
        progress := this.Gui.AddProgress(Options, StartingValue)

        ; Remove default theming first
        DllCall("uxtheme\SetWindowTheme", "Ptr", progress.hWnd, "Str", "", "Ptr", 0)

        ; Set lighter background color for progress bar
        lightBackgroundColor := 0x2A2A2A  ; Lighter than controls (0x1b1b1b)
        bgBGR := ((lightBackgroundColor & 0xFF) << 16) | (lightBackgroundColor & 0xFF00) | ((lightBackgroundColor & 0xFF0000) >> 16)

        ; Set progress bar background
        static PBM_SETBKCOLOR := 0x2001
        DllCall("SendMessage", "Ptr", progress.hWnd, "UInt", PBM_SETBKCOLOR, "Ptr", 0, "UInt", bgBGR)

        ; Set initial progress bar color (blue theme)
        startColorRGB := 0x0078D7
        progress.Opt("c" Format("{:X}", startColorRGB))

        ; Set up color changing for gradient effect
        endColorRGB := 0x34C1FB
        _Dark.ProgressControls[progress.Hwnd] := ChangeProgressColor(progress, endColorRGB)

        ; Force redraw
        DllCall("InvalidateRect", "Ptr", progress.hWnd, "Ptr", 0, "Int", true)
        DllCall("UpdateWindow", "Ptr", progress.hWnd)

        return progress
    }

    AddDarkDateTime(Options := "") {
        dateTime := this.Gui.AddDateTime(Options)
        DllCall("uxtheme\SetWindowTheme", "Ptr", dateTime.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        _Dark.DateTimeControls[dateTime.Hwnd] := true
        dateTime.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", dateTime.hWnd, "Ptr", 0, "Int", true)
        return dateTime
    }

    AddDarkTab3(Options, Tabs) {
        tab := this.Gui.AddTab3(Options, Tabs)
        DllCall("uxtheme\SetWindowTheme", "Ptr", tab.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        _Dark.TabControls[tab.Hwnd] := true
        tab.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", tab.hWnd, "Ptr", 0, "Int", true)
        return tab
    }

    AddDarkTreeView(Options := "") {
        treeView := this.Gui.AddTreeView(Options)
        static TVM_SETBKCOLOR := 0x111D
        static TVM_SETTEXTCOLOR := 0x111E
        static TVM_SETLINECOLOR := 0x1128
        DllCall("uxtheme\SetWindowTheme", "Ptr", treeView.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        _Dark.SendMessage(TVM_SETBKCOLOR, 0, 0x202020, treeView.hWnd)
        _Dark.SendMessage(TVM_SETTEXTCOLOR, 0, 0xFFFFFF, treeView.hWnd)
        _Dark.SendMessage(TVM_SETLINECOLOR, 0, 0x404040, treeView.hWnd)
        treeView.SetFont("cFFFFFF")
        _Dark.TreeViewControls[treeView.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", treeView.hWnd, "Ptr", 0, "Int", true)
        DllCall("UpdateWindow", "Ptr", treeView.hWnd)
        return treeView
    }

    RedrawAllControls() {
        DllCall("RedrawWindow", "Ptr", this.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0285)
        for hWnd, GuiCtrlObj in this.Gui {
            DllCall("RedrawWindow", "Ptr", GuiCtrlObj.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0001)
            DllCall("InvalidateRect", "Ptr", GuiCtrlObj.Hwnd, "Ptr", 0, "Int", true)
        }
    }

    SetControlsTheme() {
        for hWnd, GuiCtrlObj in this.Gui {
            switch GuiCtrlObj.Type {
                case "Button":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    buttonColorMap := Map("bg", _Dark.Dark["Controls"], "text", _Dark.Dark["Font"])
                    _Dark.ButtonColors[GuiCtrlObj.Hwnd] := buttonColorMap
                case "CheckBox", "Radio":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    if (GuiCtrlObj.Type == "Radio") {
                        _Dark.RadioButtons[GuiCtrlObj.Hwnd] := true
                    }
                case "ComboBox", "DDL":
                    _Dark.ComboBoxes[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_CFD", "Ptr", 0)
                case "Edit":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    GuiCtrlObj.SetFont("cFFFFFF")
                    style := DllCall(_Dark.GetWindowLong, "Ptr", GuiCtrlObj.hWnd, "Int", _Dark.GWL_STYLE, "Ptr")
                    if (style & 0x800) {
                        DllCall("InvalidateRect", "Ptr", GuiCtrlObj.hWnd, "Ptr", 0, "Int", true)
                        DllCall("UpdateWindow", "Ptr", GuiCtrlObj.hWnd)
                        static SWP_FRAMECHANGED := 0x0020, SWP_NOMOVE := 0x0002, SWP_NOSIZE := 0x0001
                        _Dark.SetWindowPos(GuiCtrlObj.hWnd, 0, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE)
                    }
                case "ListView":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    GuiCtrlObj.SetFont("cFFFFFF")
                case "ListBox", "UpDown":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                case "Text", "Link":
                    _Dark.TextControls[GuiCtrlObj.Hwnd] := true
                    GuiCtrlObj.Opt("cFFFFFF")
                case "GroupBox":
                    _Dark.GroupBoxes[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    GuiCtrlObj.SetFont("cFFFFFF")
                    DllCall("InvalidateRect", "Ptr", GuiCtrlObj.hWnd, "Ptr", 0, "Int", true)
                    DllCall("UpdateWindow", "Ptr", GuiCtrlObj.hWnd)
                case "Slider":
                    _Dark.SliderControls[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                case "Progress":
                    _Dark.ProgressControls[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                case "DateTime":
                    _Dark.DateTimeControls[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    GuiCtrlObj.SetFont("cFFFFFF")
                case "Tab3":
                    _Dark.TabControls[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    GuiCtrlObj.SetFont("cFFFFFF")
                case "TreeView":
                    static TVM_SETBKCOLOR := 0x111D
                    static TVM_SETTEXTCOLOR := 0x111E
                    static TVM_SETLINECOLOR := 0x1128
                    _Dark.TreeViewControls[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    _Dark.SendMessage(TVM_SETBKCOLOR, 0, 0x202020, GuiCtrlObj.hWnd)
                    _Dark.SendMessage(TVM_SETTEXTCOLOR, 0, 0xFFFFFF, GuiCtrlObj.hWnd)
                    _Dark.SendMessage(TVM_SETLINECOLOR, 0, 0x404040, GuiCtrlObj.hWnd)
                    GuiCtrlObj.SetFont("cFFFFFF")
                    DllCall("UpdateWindow", "Ptr", GuiCtrlObj.hWnd)
            }
            DllCall("InvalidateRect", "Ptr", GuiCtrlObj.Hwnd, "Ptr", 0, "Int", true)
        }
    }
}

class ChangeProgressColor {
    static info := Map()
    static EVENT_OBJECT_DESTROY := 0x8001
    static EVENT_OBJECT_VALUECHANGE := 0x800E
    static Hook := ""

    __New(ProgressObj, secondColorRGB) {
        static PBM_GETRANGE := 0x407
        static PBM_GETBARCOLOR := 0x40F

        ; Store reference to the class
        classRef := ChangeProgressColor

        ; Initialize the data Map for this progress control
        data := Map()
        data.hGui := ProgressObj.Gui.hwnd
        data.CtrlObj := ProgressObj

        ; Store hwnd and add to class info
        this.hwnd := ProgressObj.hwnd
        classRef.info[this.hwnd] := data

        ; Get progress range
        SendMessage(PBM_GETRANGE, , PBRANGE := Buffer(8), ProgressObj)
        data.start := NumGet(PBRANGE, 0, 'Int')
        range := NumGet(PBRANGE, 4, 'Int') - data.start

        ; Get current color and calculate color steps
        startColorBGR := SendMessage(PBM_GETBARCOLOR, , , ProgressObj)
        classRef.SplitColor(startColorBGR, &rStart, &gStart, &bStart, 'BGR')
        classRef.SplitColor(secondColorRGB, &rEnd, &gEnd, &bEnd)

        ; Calculate color steps for gradient
        for v in ['r', 'g', 'b'] {
            data[v "Start"] := %v%Start
            data[v "Step"] := (%v%End - %v%Start) / range
        }

        ; Set up hook if this is the first progress control
        if classRef.info.Count = 1 {
            classRef.Hook := WinEventHook(
                classRef.EVENT_OBJECT_DESTROY,
                classRef.EVENT_OBJECT_VALUECHANGE,
                ObjBindMethod(classRef, 'HookProc'),
                'F',
                DllCall('GetCurrentProcessId')
            )
        }
    }

    __Delete() {
        classRef := ChangeProgressColor
        if !classRef.info.Has(this.hwnd)
            return
        classRef.info.Delete(this.hwnd)
        if !classRef.info.Count
            classRef.Hook := ''
    }

    static SplitColor(colorRGBorBGR, &r := 0, &g := 0, &b := 0, mode := 'RGB') {
        g := (colorRGBorBGR >> 8) & 0xFF
        r := (mode = 'RGB' ? colorRGBorBGR >> 16 : colorRGBorBGR & 0xFF)
        b := (mode = 'BGR' ? colorRGBorBGR >> 16 : colorRGBorBGR & 0xFF)
    }

    static HookProc(hWinEventHook, event, hwnd, idObject, *) {
        static OBJID_WINDOW := 0
        classRef := ChangeProgressColor

        if (event = classRef.EVENT_OBJECT_VALUECHANGE && classRef.info.Has(hwnd)) {
            data := classRef.info[hwnd]
            try
                value := data.CtrlObj.Value
            catch
                return
            r := g := b := 0
            for v in ['r', 'g', 'b'] {
                %v% := Round(data[v "Start"] + data[v "Step"] * (value - data.start))
                if (%v% > 255)
                    %v% := 255
                if (%v% < 0)
                    %v% := 0
            }
            data.CtrlObj.Opt(Format('c{:X}', r << 16 | g << 8 | b))
        }
        if (event = classRef.EVENT_OBJECT_DESTROY && idObject = OBJID_WINDOW) {
            found := []
            for hProgress, data in classRef.info {
                if (data.hGui = hwnd)
                    found.Push(hProgress)
            }
            for hProgress in found
                classRef.info.Delete(hProgress)
            if !classRef.info.Count
                classRef.Hook := ''
        }
    }
}

class WinEventHook {
    __New(eventMin, eventMax, hookProc, options := '', idProcess := 0, idThread := 0, dwFlags := 0) {
        this.pCallback := CallbackCreate(hookProc, options, 7)
        this.hHook := DllCall('SetWinEventHook', 'UInt', eventMin, 'UInt', eventMax, 'Ptr', 0, 'Ptr', this.pCallback, 'UInt', idProcess, 'UInt', idThread, 'UInt', dwFlags, 'Ptr')
    }
    __Delete() {
        DllCall('UnhookWinEvent', 'Ptr', this.hHook)
        CallbackFree(this.pCallback)
    }
}