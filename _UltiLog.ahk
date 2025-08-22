#Requires AutoHotkey v2.1-alpha.17 64-bit
#SingleInstance Force

#Include ..\Lib\cJson.ahk
#Include ..\Lib\DarkListView.ahk

Esc:: ExitApp

Lg()

class Lg {
    static PAD := 10
    static LBL_W := 80
    static INP_W := 460
    static INP_H := 24
    static TXT_H := 100
    static CODE_H := 200
    static BTN_W := 130
    static BTN_H := 30
    static LEFT_W := 400
    static LVW_H := 608
    static COL_CO := 1
    static COL_MDL := 2
    static COL_TTL := 3
    static COL_NOTE := 4
    static COMPANIES := ["OpenAI", "Anthropic", "DeepSeek", "Google", "Microsoft", "Mistral", "Grok", "Meta", "Qwen", "Other"]
    static RATING_OPTIONS := ["★★★★★", "★★★★", "★★★", "★★", "★"]

    __New() {
        this.logFile := A_ScriptDir "\Lib\test_log.json"
        this.pmtFile := A_ScriptDir "\Lib\common_prompts.json"
        this.entries := []
        this.pmts := Map()
        this.running := false
        this.runPath := A_Temp "\LLMLoggerRun.ahk"
        this.outBuf := ""
        this.monCb := this.MonitorRunningProcess.Bind(this)
        this.curIdx := -1
        this.cmdMgr := CommandManager()
        this.RegCmds()
        this.InitializePromptsFile()
        this.LoadData()
        this.InitGui()
        this.RefreshList()
        this.gui.Show()
    }

    RegCmds() {
        this.cmdMgr.Register("save", this.SaveEntry.Bind(this))
            .Register("load", this.LoadEntry.Bind(this))
            .Register("delete", this.DeleteEntry.Bind(this))
            .Register("clear", this.ClearForm.Bind(this))
            .Register("runCode", this.RunCode.Bind(this))
            .Register("savePrompt", this.SavePmt.Bind(this))
            .Register("deletePrompt", this.DeletePmt.Bind(this))
            .Register("newPrompt", this.NewPmt.Bind(this))
    }

    InitGui() {
        this.gui := Gui("+Resize", "LLM Test Logger")
        this.gui.SetFont("s10")
        this.gui.BackColor := 0x1E1E1E
        _Dark.Apply(this.gui)
        this.form := GuiForm(this.gui)
        this.CreateLeftPanel()
        this.CreateRightPanel()
        this.gui.OnEvent("Close", (*) => ExitApp())
    }

    CreateLeftPanel() {
        this.CreateLvw()
        this.CreateBtns()
    }

    CreateLvw() {
        static LVM_SETTEXTCOLOR := 0x1024
        static LVM_SETTEXTBKCOLOR := 0x1026
        static LVM_SETBKCOLOR := 0x1001
        static LVM_SETOUTLINECOLOR := 0x10B1
        this.lvw := this.gui.AddListView(Format("x{} y{} w{} h{} {}", Lg.PAD, Lg.PAD, Lg.LEFT_W, 620, "Grid cWhite"), ["Company", "Model", "Prompt", "Notes"])
        this.lvw.Opt("-Redraw")
        SendMessage(LVM_SETTEXTCOLOR, 0, 0xFFFFFF, this.lvw.Hwnd)
        SendMessage(LVM_SETTEXTBKCOLOR, 0, 0x202020, this.lvw.Hwnd)
        SendMessage(LVM_SETBKCOLOR, 0, 0x202020, this.lvw.Hwnd)
        ; Darker gridline color
        try SendMessage(LVM_SETOUTLINECOLOR, 0, 0x1E1E1E, this.lvw.Hwnd)
        this.lvw.Opt("+Redraw")
        if (this.lvw.HasMethod("SetDarkMode"))
            this.lvw.SetDarkMode()
        this.lvw.ModifyCol(Lg.COL_CO, 75)
        this.lvw.ModifyCol(Lg.COL_MDL, 75)
        this.lvw.ModifyCol(Lg.COL_TTL, 75)
        this.lvw.ModifyCol(Lg.COL_NOTE, 150)
        this.lvw.OnEvent("DoubleClick", (*) => this.cmdMgr.Execute("load"))
    }

    CreateBtns() {
        btnY := Lg.PAD + Lg.LVW_H + Lg.PAD + Lg.PAD
        btnW := ((Lg.LEFT_W - (Lg.PAD * 5)) / 4) + 5
        this.btnLoad := this.CreateBtn(Lg.PAD, btnY, btnW, "Load Entry", (*) => this.cmdMgr.Execute("load"))
        this.btnClear := this.CreateBtn(Lg.PAD * 2 + btnW, btnY, btnW, "Clear Form", (*) => this.cmdMgr.Execute("clear"))
        this.btnDel := this.CreateBtn(Lg.PAD * 3 + btnW * 2, btnY, btnW, "Delete Entry", (*) => this.cmdMgr.Execute("delete"))
        this.btnSave := this.CreateBtn(Lg.PAD * 4 + btnW * 3, btnY, btnW, "Save Entry", (*) => this.cmdMgr.Execute("save"))
    }

    CreateBtn(x, y, w, txt, cb) {
        btn := this.gui.AddButton(GuiFormat(x, y, w, Lg.BTN_H, "Background171717 cFFFFFF"), txt)
        btn.OnEvent("Click", cb)
        ApplyDarkModeToBtn(btn)
        return btn
    }

    CreateRightPanel() {
        this.CreateFormCtrls()
        this.gui.OnEvent("Size", this.ResizeRightPanel.Bind(this))
    }

    AddDarkDdl(x, y, w, h, opts := "", items := "") {
        options := GuiFormat(x, y, w, h, opts)

        if (items = "")
            ddl := this.gui.AddDropDownList(options)
        else
            ddl := this.gui.AddDropDownList(options, items)

        ApplyDarkModeToDdl(ddl)
        return ddl
    }

    ResizeRightPanel(GuiObj, MinMax, Width, Height) {
        if (MinMax = -1)
            return
        rightX := Lg.LEFT_W + Lg.PAD * 2

        this.UpdateControlPositions(rightX)
    }

    UpdateControlPositions(rightX) {
        for ctrl, obj in this.gui {
            try {
                x := 0, y := 0, w := 0, h := 0
                if (ControlGetPos(&x, &y, &w, &h, ctrl)) {
                    if (x > Lg.LEFT_W) {
                        offset := x - (Lg.LEFT_W + Lg.PAD * 2)
                        ControlMove(ctrl, rightX + offset, y)
                    }
                }
            }
        }
    }

    CreateFormCtrls() {
        g := this.gui
        rightX := Lg.LEFT_W + Lg.PAD * 2
        yOffset := -10

        this.AddLbl(
            rightX,
            Lg.PAD + yOffset + 12,
            "Model:")
        halfWidth := (Lg.INP_W - Lg.PAD) / 2

        this.coDdl :=
            this.AddDarkDdl(
                rightX + Lg.LBL_W + Lg.PAD,
                Lg.PAD * 2 + yOffset,
                halfWidth,
                Lg.INP_H * 8,
                "",
                Lg.COMPANIES
            )
        this.coDdl.Choose(1)

        this.mdlEdit :=
            this.AddDarkEdit(
                rightX + Lg.LBL_W + Lg.PAD + halfWidth + Lg.PAD,
                Lg.PAD * 2 + yOffset,
                halfWidth,
                Lg.INP_H)

        this.AddLbl(
            rightX,
            Lg.PAD * 3 + Lg.INP_H + yOffset,
            "Prompt:")

        this.pmtBox :=
            this.AddDarkDdl(
                rightX + Lg.LBL_W + Lg.PAD,
                Lg.PAD * 3 + Lg.INP_H + yOffset,
                Lg.INP_W - Lg.BTN_H * 2 - Lg.PAD * 2,
                Lg.INP_H * 8)

        this.PopulatePmtDdl()
        this.pmtBox.OnEvent(
            "Change",
            this.OnPmtSelect.Bind(this))

        this.btnNewPmt := this.CreateBtn(
            rightX + Lg.LBL_W + Lg.PAD + Lg.INP_W - Lg.BTN_H * 2 - Lg.PAD, Lg.PAD * 3 + Lg.INP_H + yOffset,
            Lg.BTN_H,
            "✚",
            (*) => this.cmdMgr.Execute("newPrompt"))

        this.btnSavePmt :=
            this.CreateBtn(rightX + Lg.LBL_W + Lg.PAD + Lg.INP_W - Lg.BTN_H,
                Lg.PAD * 3 + Lg.INP_H + yOffset,
                Lg.BTN_H,
                "💾",
                (*) => this.cmdMgr.Execute("savePrompt"))

        this.AddLbl(
            rightX,
            Lg.PAD * 4 + Lg.INP_H * 2 + yOffset,
            "Body:")

        this.pmtEdit :=
            this.AddDarkEdit(
                rightX + Lg.LBL_W + Lg.PAD,
                Lg.PAD * 4 + Lg.INP_H * 2 + yOffset,
                Lg.INP_W,
                Lg.TXT_H,
                "Multi VScroll")

        this.AddLbl(
            rightX,
            Lg.PAD * 5 + Lg.INP_H * 2 + Lg.TXT_H + yOffset,
            "Code:")
        this.btnRunCode := this.CreateBtn(
            rightX + Lg.LBL_W - Lg.PAD - Lg.PAD - Lg.PAD, Lg.PAD * 5 + Lg.INP_H * 2 + Lg.TXT_H + yOffset,
            Lg.BTN_H,
            "⏵︎",
            (*) => this.cmdMgr.Execute("runCode"))

        this.codeEdit :=
            this.AddDarkEdit(
                rightX + Lg.LBL_W + Lg.PAD,
                Lg.PAD * 5 + Lg.INP_H * 2 + Lg.TXT_H + yOffset,
                Lg.INP_W,
                Lg.CODE_H,
                "Multi VScroll")
        this.codeEdit.Value := 'MsgBox("LOL")'

        this.AddLbl(
            rightX,
            Lg.PAD * 6 + Lg.INP_H * 2 + Lg.TXT_H + Lg.CODE_H + yOffset, "Errors:")
        this.errEdit :=
            this.AddDarkEdit(
                rightX + Lg.LBL_W + Lg.PAD,
                Lg.PAD * 6 + Lg.INP_H * 2 + Lg.TXT_H + Lg.CODE_H + yOffset,
                Lg.INP_W,
                Lg.TXT_H,
                "Multi VScroll")

        notesY := Lg.PAD * 7 + Lg.INP_H * 2 + Lg.TXT_H * 2 + Lg.CODE_H + yOffset
        this.AddLbl(rightX, notesY, "Notes:")
        this.noteEdit := this.AddDarkEdit(
            rightX + Lg.LBL_W + Lg.PAD,
            notesY,
            Lg.INP_W,
            Lg.TXT_H, "Multi VScroll")

        ratingY := notesY + Lg.TXT_H + Lg.PAD
        this.AddLbl(
            rightX,
            ratingY + 25,
            "Rating:")

        ddlWidth := (Lg.INP_W - Lg.PAD * 5 - 80) / 4
        ddlX := rightX + Lg.LBL_W + Lg.PAD

        labelY := ratingY
        ddlY := labelY + Lg.INP_H

        this.funcLabel := this.AddLbl(ddlX, labelY, "Functionality", ddlWidth, "Center")
        this.syntaxLabel := this.AddLbl(ddlX + ddlWidth + Lg.PAD, labelY, "Syntax Usage", ddlWidth, "Center")
        this.appearLabel := this.AddLbl(ddlX + (ddlWidth + Lg.PAD) * 2, labelY, "Appearance", ddlWidth, "Center")
        this.stabilityLabel := this.AddLbl(ddlX + (ddlWidth + Lg.PAD) * 3, labelY, "Stability", ddlWidth, "Center")
        this.totalLabel := this.AddLbl(ddlX + (ddlWidth + Lg.PAD) * 4, labelY, "Total Score:", 85, "Center")
        this.rateDdl1 := this.AddDarkDdl(ddlX, ddlY, ddlWidth, Lg.INP_H * 8, "Choose1", Lg.RATING_OPTIONS)
        this.rateDdl1.OnEvent("Change", this.RatingChanged.Bind(this))

        this.rateDdl2 :=
            this.AddDarkDdl(
                ddlX + ddlWidth + Lg.PAD,
                ddlY, ddlWidth,
                Lg.INP_H * 8,
                "Choose1",
                Lg.RATING_OPTIONS)

        this.rateDdl2.OnEvent(
            "Change",
            this.RatingChanged.Bind(this))

        this.rateDdl3 := this.AddDarkDdl(
            ddlX + (ddlWidth + Lg.PAD) * 2,
            ddlY,
            ddlWidth,
            Lg.INP_H * 8,
            "Choose1",
            Lg.RATING_OPTIONS)
        this.rateDdl3.OnEvent(
            "Change",
            this.RatingChanged.Bind(this))

        this.rateDdl4 := this.AddDarkDdl(ddlX + (ddlWidth + Lg.PAD) * 3, ddlY, ddlWidth, Lg.INP_H * 8, "Choose1", Lg.RATING_OPTIONS)
        this.rateDdl4.OnEvent(
            "Change",
            this.RatingChanged.Bind(this))

        this.totalLabel := this.AddLbl(
            ddlX + (ddlWidth + Lg.PAD) * 4,
            labelY,
            "Total Score:")

        this.totalLabel.Opt("w80 Center")

        this.totalEdit := this.AddDarkEdit(
            ddlX + (ddlWidth + Lg.PAD) * 4,
            ddlY,
            80,
            Lg.INP_H, "Center ReadOnly")
        this.totalEdit.Value := "0%"

        this.rateDdl1.Choose(1)
        this.rateDdl2.Choose(1)
        this.rateDdl3.Choose(1)
        this.rateDdl4.Choose(1)
        this.RatingChanged()

        HotKey("F5", (*) => this.cmdMgr.Execute("runCode"))
    }

    RatingChanged(*) {
        totalStars := 0
        starCounts := Map()

        if (this.rateDdl1.Text) {
            starCount := StrLen(RegExReplace(this.rateDdl1.Text, "[^★]", ""))
            starCounts[1] := starCount
            totalStars += starCount
        }

        if (this.rateDdl2.Text) {
            starCount := StrLen(RegExReplace(this.rateDdl2.Text, "[^★]", ""))
            starCounts[2] := starCount
            totalStars += starCount
        }

        if (this.rateDdl3.Text) {
            starCount := StrLen(RegExReplace(this.rateDdl3.Text, "[^★]", ""))
            starCounts[3] := starCount
            totalStars += starCount
        }

        if (this.rateDdl4.Text) {
            starCount := StrLen(RegExReplace(this.rateDdl4.Text, "[^★]", ""))
            starCounts[4] := starCount
            totalStars += starCount
        }

        percentage := totalStars * 5

        this.totalEdit.Value := percentage . "%"
    }

    SelectCompanyByName(name) {
        if (!name)
            return

        try {
            if (this.coDdl.HasProp("Items") && this.coDdl.Items.Length > 0) {
                Loop this.coDdl.Items.Length {
                    if (this.coDdl.Items[A_Index] = name) {
                        this.coDdl.Choose(A_Index)
                        return
                    }
                }
            }

            Loop this.coDdl.GetCount() {
                if (this.coDdl.GetText(A_Index) = name) {
                    this.coDdl.Choose(A_Index)
                    return
                }
            }

            for index, company in Lg.COMPANIES {
                if (company = name) {
                    this.coDdl.Choose(index)
                    return
                }
            }
        } catch Error as err {
            OutputDebug("SelectCompanyByName error: " err.Message)
        }
    }

    AddLbl(x, y, txt, width := 0, align := "") {
        width := width ? width : Lg.LBL_W
        opts := "cFFFFFF"

        if (align != "")
            opts .= " " align

        lbl := this.gui.AddText(GuiFormat(x, y, width, Lg.INP_H, opts), txt)
        return lbl
    }

    AddDarkEdit(x, y, w, h, opts := "") {
        return _Dark.AddDarkEdit(this.gui, GuiFormat(x, y, w, h, opts))
    }

    NewPmt(*) {
        res := InputBox("Enter a title for the new prompt template:", "New Prompt Template", "w300 h130")
        if (res.Result = "Cancel")
            return
        newTtl := res.Value
        if (newTtl = "") {
            MsgBox("Please enter a title for the prompt template.", "Validation Error", "Icon!")
            return
        }
        this.pmtEdit.Value := ""
        if (this.pmts.Has(newTtl)) {
            this.pmtEdit.Value := this.pmts[newTtl]
            MsgBox("Prompt with this title already exists. You can edit the existing template.", "Information", "Icon!")
        } else {
            this.pmts[newTtl] := ""
            this.SavePmts()
            this.PopulatePmtDdl()
        }
        this.SelectPmtByName(newTtl)
    }

    SelectPmtByName(name) {
        if (!name)
            return

        try {
            if (this.pmtBox.HasProp("Items") && this.pmtBox.Items.Length > 0) {
                Loop this.pmtBox.Items.Length {
                    if (this.pmtBox.Items[A_Index] = name) {
                        this.pmtBox.Choose(A_Index)
                        return
                    }
                }
            }

            Loop this.pmtBox.GetCount() {
                if (this.pmtBox.GetText(A_Index) = name) {
                    this.pmtBox.Choose(A_Index)
                    return
                }
            }

            for ttl, _ in this.pmts {
                if (ttl = name) {
                    this.PopulatePmtDdl()
                    Loop this.pmtBox.GetCount() {
                        if (this.pmtBox.GetText(A_Index) = name) {
                            this.pmtBox.Choose(A_Index)
                            return
                        }
                    }
                }
            }
        } catch Error as err {
            OutputDebug("SelectPmtByName error: " err.Message)
        }
    }

    OnPmtSelect(*) {
        selPmt := this.pmtBox.Text
        this.pmtEdit.Value := this.pmts.Has(selPmt) ? this.pmts[selPmt] : ""
    }

    PopulatePmtDdl() {
        this.pmtBox.Delete()
        ttls := []
        for ttl, _ in this.pmts
            ttls.Push(ttl)
        if (ttls.Length > 0) {
            this.pmtBox.Add(ttls)
            this.pmtBox.Choose(1)
        }
    }

    SavePmt(*) {
        ttl := this.pmtBox.Text
        body := this.pmtEdit.Value
        if (ttl = "") {
            inpBox := InputBox("Enter a title for the prompt template:", "Save Prompt Template", "w300 h130")
            if (inpBox.Result = "Cancel")
                return
            ttl := inpBox.Value
            if (ttl = "") {
                MsgBox("Please enter a title for the prompt template.", "Validation Error", "Icon!")
                return
            }
        }
        if (body = "") {
            MsgBox("Please enter a body for the prompt template.", "Validation Error", "Icon!")
            return
        }
        this.pmts[ttl] := body
        this.SavePmts()
        this.PopulatePmtDdl()
        this.SelectPmtByName(ttl)
        MsgBox("Prompt template saved.", "Success", "Icon!")
    }

    DeletePmt(*) {
        ttl := this.pmtBox.Text
        if (ttl = "") {
            MsgBox("Please select a prompt template to delete.", "Validation Error", "Icon!")
            return
        }
        if (!this.pmts.Has(ttl)) {
            MsgBox("This prompt template does not exist.", "Validation Error", "Icon!")
            return
        }
        if (MsgBox("Are you sure you want to delete this prompt template?", "Confirm Delete", "YesNo Icon!") = "Yes") {
            this.pmts.Delete(ttl)
            this.SavePmts()
            this.PopulatePmtDdl()
        }
    }

    SavePmts() {
        try {
            pmtArr := []
            for ttl, body in this.pmts
                pmtArr.Push(Map("title", ttl, "body", body))
            jsonTxt := JSON.Dump(pmtArr, 1)
            FileDelete(this.pmtFile)
            FileAppend(jsonTxt, this.pmtFile)
        } catch Error as err {
            MsgBox("Error saving prompt templates: " err.Message "`nFile: " this.pmtFile, "Error", "Icon!")
        }
    }

    LoadData() {
        if FileExist(this.logFile) {
            try {
                jsonTxt := FileRead(this.logFile)
                if (jsonTxt = "" || RegExMatch(jsonTxt, "^\s*$")) {
                    this.entries := []
                    return
                }
                this.entries := JSON.Load(jsonTxt)
                if (!IsObject(this.entries) || !HasMethod(this.entries, "Push")) {
                    this.entries := []
                    MsgBox("Log file exists but is not a valid array.", "Warning", "Icon!")
                }
            } catch Error as err {
                MsgBox("Error loading data: " err.Message "`nFile: " this.logFile, "Error", "Icon!")
                this.entries := []
            }
        } else {
            try {
                FileAppend("[]", this.logFile)
                this.entries := []
            } catch Error as err {
                MsgBox("Error creating log file: " err.Message "`nFile: " this.logFile, "Error", "Icon!")
                this.entries := []
            }
        }

        this.LoadPmts()
    }

    LoadPmts() {
        if FileExist(this.pmtFile) {
            try {
                jsonTxt := FileRead(this.pmtFile)
                if (jsonTxt = "" || RegExMatch(jsonTxt, "^\s*$")) {
                    this.pmts := Map()
                    return
                }
                try {
                    pmtArr := JSON.Load(jsonTxt)
                    this.pmts := Map()

                    for i, pmt in pmtArr {
                        if (IsObject(pmt) && pmt.Has("title") && pmt.Has("body"))
                            this.pmts[pmt["title"]] := pmt["body"]
                    }
                } catch Error as err {
                    MsgBox("Error processing JSON: " err.Message, "Error", "Icon!")
                    this.pmts := Map()
                }
            } catch Error as err {
                MsgBox("Error loading prompts: " err.Message, "Error", "Icon!")
                this.pmts := Map()
            }
        } else {
            try {
                FileAppend("[]", this.pmtFile)
                this.pmts := Map()
            } catch Error as err {
                MsgBox("Error creating prompts file: " err.Message, "Error", "Icon!")
                this.pmts := Map()
            }
        }
    }

    InitializePromptsFile() {
        if !FileExist(this.pmtFile) || FileRead(this.pmtFile) == "" {
            initialPrompts := [
                Map("title", "Basic Prompt", "body", "Write a hello world script in AutoHotkey"),
                Map("title", "GUI Template", "body", "Create a basic GUI with a button and text field")
            ]

            jsonTxt := JSON.Dump(initialPrompts, 1)
            try {
                FileDelete(this.pmtFile)
                FileAppend(jsonTxt, this.pmtFile)
                MsgBox("Created initial prompts file.", "Success", "Icon!")
            } catch Error as err {
                MsgBox("Error creating prompts file: " err.Message, "Error", "Icon!")
            }
        }
    }


    RunCode(*) {
        if (this.running)
            return this.StopRunningCode()
        code := this.codeEdit.Value
        if (!code) {
            MsgBox("No code to run.", "Run Code", "Icon!")
            return
        }
        this.errEdit.Value := ""
        this.outBuf := ""
        try {
            this.PrepScriptFile(code)
            this.ExecScript()
            this.running := true
            this.btnRunCode.Text := "⏸︎"
            this.btnRunCode.Opt("BackgroundCC3030")
            SetTimer(this.monCb, 100)
        } catch Error as err {
            this.errEdit.Value := "Error: " err.Message
            MsgBox("Error: " err.Message, "Code Execution Failed", "Icon!")
        }
    }

    ExecScript() {
        try {
            shell := ComObject("WScript.Shell")
            this.proc := shell.Exec(A_AhkPath " " this.runPath)
        } catch Error as err {
            throw Error("Failed to execute script: " err.Message, "ExecScript")
        }
    }

    StopRunningCode() {
        try {
            if this.proc {
                try {
                    pid := this.proc.ProcessID
                    if pid
                        ProcessClose(pid)
                } catch {
                }
            }
        } catch Error as err {
            this.errEdit.Value := "Error stopping code: " err.Message
        }
        this.running := false
        this.btnRunCode.Text := "⏵︎"
        this.btnRunCode.Opt("Background171717")
        SetTimer(this.monCb, 0)
    }

    PrepScriptFile(code) {
        try {
            if FileExist(this.runPath)
                FileDelete(this.runPath)
            scriptHdr := "#Requires AutoHotkey v2.1-alpha.17 64-bit`n" "#SingleInstance Force`n" "#Warn All`n`n" "OnExit((*) => ExitApp())`n`n" "#HotIf WinActive(A_ScriptName)`n" "Esc::ExitApp`n" "#HotIf`n`n"
            FileAppend(scriptHdr . code, this.runPath)
        } catch Error as err {
            throw Error("Failed to prepare script file: " err.Message, "PrepScriptFile")
        }
    }

    MonitorRunningProcess() {
        if (!this.running) {
            SetTimer(this.monCb, 0)
            return
        }
        exited := true
        try {
            if (!this.proc)
                exited := true
            else {
                try {
                    exited := this.proc.Status != 0
                } catch {
                    try {
                        pid := this.proc.ProcessID
                        exited := !ProcessExist(pid)
                    } catch {
                        exited := true
                    }
                }
            }
        } catch {
            exited := true
        }
        try {
            this.ReadProcOutput()
        } catch {
        }
        if (exited) {
            try {
                this.ReadProcOutput()
            } catch {
            }
            this.running := false
            this.btnRunCode.Text := "⏵︎"
            this.btnRunCode.Opt("Background171717")
            SetTimer(this.monCb, 0)
        }
    }

    ReadProcOutput() {
        try {
            if (!this.proc)
                return
            try {
                if (this.proc.HasOwnProp("StdOut") && this.proc.StdOut && !this.proc.StdOut.AtEndOfStream) {
                    while (!this.proc.StdOut.AtEndOfStream)
                        this.outBuf .= this.proc.StdOut.ReadLine() "`n"
                    if (this.outBuf)
                        this.errEdit.Value := RTrim(this.outBuf, "`n")
                }
            } catch {
            }
            try {
                if (this.proc.HasOwnProp("StdErr") && this.proc.StdErr && !this.proc.StdErr.AtEndOfStream) {
                    errTxt := ""
                    while (!this.proc.StdErr.AtEndOfStream)
                        errTxt .= this.proc.StdErr.ReadLine() "`n"
                    if (errTxt) {
                        this.errEdit.Value := this.errEdit.Value ? this.errEdit.Value "`n" RTrim(errTxt, "`n") : RTrim(errTxt, "`n")
                    }
                }
            } catch {
            }
        } catch {
        }
    }

    SaveData() {
        try {
            if (!IsObject(this.entries) || !HasMethod(this.entries, "Push"))
                this.entries := []
            jsonTxt := JSON.Dump(this.entries, 1)
            FileDelete(this.logFile)
            FileAppend(jsonTxt, this.logFile)
        } catch Error as err {
            MsgBox("Error saving data: " err.Message "`nFile: " this.logFile, "Error", "Icon!")
        }
    }

    RefreshList() {
        this.lvw.Delete()
        for ent in this.entries {
            co := IsObject(ent) && ent.Has("Company") ? ent["Company"] : ""
            mdl := IsObject(ent) && ent.Has("Model") ? ent["Model"] : ""
            ttl := ""
            if (IsObject(ent)) {
                if (ent.Has("PromptTitle"))
                    ttl := ent["PromptTitle"]
                else if (ent.Has("Prompt"))
                    ttl := ent["Prompt"]
            }
            notes := IsObject(ent) && ent.Has("Notes") ? ent["Notes"] : ""
            this.lvw.Add(, co, mdl, ttl, notes)
        }
    }

    LoadEntry(*) {
        static loading := false
        if (loading)
            return
        loading := true
        try {
            row := this.lvw.GetNext()

            if (!row) {
                MsgBox("Please select an entry to load.", "Information", "Icon!")
                loading := false
                return
            }
            try {
                co := this.lvw.GetText(row, Lg.COL_CO)
                mdl := this.lvw.GetText(row, Lg.COL_MDL)
                pmtTtl := this.lvw.GetText(row, Lg.COL_TTL)
            } catch Error as err {
                MsgBox("Error getting entry data: " err.Message, "Error", "Icon!")
                loading := false
                return
            }
            found := false
            for i, ent in this.entries {
                if (!IsObject(ent) || !HasMethod(ent, "Has"))
                    continue
                entCo := ent.Has("Company") ? ent["Company"] : ""
                entMdl := ent.Has("Model") ? ent["Model"] : ""
                entTtl := ""
                if (ent.Has("PromptTitle"))
                    entTtl := ent["PromptTitle"]
                else if (ent.Has("Prompt"))
                    entTtl := ent["Prompt"]
                if (entCo = co && entMdl = mdl && entTtl = pmtTtl) {
                    this.ClearForm()

                    this.SelectCompanyByName(entCo)
                    this.mdlEdit.Value := entMdl

                    if (!this.pmts.Has(entTtl) && ent.Has("PromptBody")) {
                        this.pmts[entTtl] := ent["PromptBody"]
                        this.SavePmts()
                        this.PopulatePmtDdl()
                    }

                    this.SelectPmtByName(entTtl)
                    this.pmtEdit.Value := ent.Has("PromptBody") ? ent["PromptBody"] : (ent.Has("Prompt") ? ent["Prompt"] : "")
                    this.codeEdit.Value := ent.Has("Code") ? ent["Code"] : ""
                    this.errEdit.Value := ent.Has("Errors") ? ent["Errors"] : ""
                    this.noteEdit.Value := ent.Has("Notes") ? ent["Notes"] : ""

                    if (ent.Has("Ratings")) {
                        ratings := ent["Ratings"]
                        if (ratings.Has(1))
                            this.SetRatingByValue(this.rateDdl1, ratings[1])
                        if (ratings.Has(2))
                            this.SetRatingByValue(this.rateDdl2, ratings[2])
                        if (ratings.Has(3))
                            this.SetRatingByValue(this.rateDdl3, ratings[3])
                        if (ratings.Has(4))
                            this.SetRatingByValue(this.rateDdl4, ratings[4])
                        this.RatingChanged()
                    }

                    this.curIdx := i
                    this.btnSave.Text := "Update Entry"
                    found := true
                    break
                }
            }
            if (!found)
                MsgBox("Entry not found or could not be loaded.", "Information", "Icon!")
        } catch Error as err {
            MsgBox("Error loading entry: " err.Message, "Error", "Icon!")
        } finally {
            loading := false
        }
    }

    SetRatingByValue(ddl, value) {
        if (!IsInteger(value) || value < 1 || value > 5)
            return

        count := Lg.RATING_OPTIONS.Length
        ddl.Choose(count - value + 1)
    }

    SaveEntry(*) {
        co := this.coDdl.Text
        mdl := this.mdlEdit.Value
        pmtTtl := this.pmtBox.Text
        pmtBody := this.pmtEdit.Value
        code := this.codeEdit.Value
        errs := this.errEdit.Value
        notes := this.noteEdit.Value

        ratings := Map()
        if (this.rateDdl1.Text)
            ratings[1] := StrLen(RegExReplace(this.rateDdl1.Text, "[^★]", ""))
        if (this.rateDdl2.Text)
            ratings[2] := StrLen(RegExReplace(this.rateDdl2.Text, "[^★]", ""))
        if (this.rateDdl3.Text)
            ratings[3] := StrLen(RegExReplace(this.rateDdl3.Text, "[^★]", ""))
        if (this.rateDdl4.Text)
            ratings[4] := StrLen(RegExReplace(this.rateDdl4.Text, "[^★]", ""))

        if (co = "" || mdl = "") {
            MsgBox("Company and Model are required.", "Validation Error", "Icon!")
            return
        }
        fmt := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        ent := Map("Company", co, "Model", mdl, "PromptTitle", pmtTtl, "PromptBody", pmtBody, "Code", code, "Errors", errs, "Notes", notes, "Timestamp", fmt, "Ratings", ratings)

        if (this.curIdx >= 1 && this.curIdx <= this.entries.Length) {
            if (this.entries[this.curIdx].Has("Timestamp"))
                ent["Timestamp"] := this.entries[this.curIdx]["Timestamp"]
            this.entries[this.curIdx] := ent
            this.btnSave.Text := "Save Entry"
            MsgBox("Entry updated.", "Success", "Icon!")
        } else {
            this.entries.Push(ent)
            MsgBox("New entry saved.", "Success", "Icon!")
        }
        this.SaveData()
        this.RefreshList()
        this.ClearForm()
    }

    DeleteEntry(*) {
        row := this.lvw.GetNext()
        if (!row) {
            MsgBox("Please select an entry to delete.", "Information", "Icon!")
            return
        }
        co := this.lvw.GetText(row, Lg.COL_CO)
        mdl := this.lvw.GetText(row, Lg.COL_MDL)
        pmtTtl := this.lvw.GetText(row, Lg.COL_TTL)
        for i, ent in this.entries {
            if (!IsObject(ent) || !HasMethod(ent, "Has"))
                continue
            entCo := ent.Has("Company") ? ent["Company"] : ""
            entMdl := ent.Has("Model") ? ent["Model"] : ""
            entTtl := ""
            if (ent.Has("PromptTitle"))
                entTtl := ent["PromptTitle"]
            else if (ent.Has("Prompt"))
                entTtl := ent["Prompt"]
            if (entCo = co && entMdl = mdl && entTtl = pmtTtl) {
                this.entries.RemoveAt(i)
                if (this.curIdx = i)
                    this.curIdx := -1
                this.SaveData()
                this.RefreshList()
                this.ClearForm()
                return
            }
        }
        MsgBox("Entry not found.", "Information", "Icon!")
    }

    ClearForm(*) {
        this.coDdl.Choose(0)
        this.mdlEdit.Value := ""
        this.pmtBox.Choose(0)
        this.pmtEdit.Value := ""
        this.codeEdit.Value := ""
        this.errEdit.Value := ""
        this.noteEdit.Value := ""
        this.curIdx := -1
        this.btnSave.Text := "Save Entry"
    }
}

ApplyDarkModeToBtn(btn) {
    DllCall("uxtheme\SetWindowTheme", "Ptr", btn.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
    btn.Opt("Background171717 cFFFFFF")
    return btn
}

ApplyDarkModeToDdl(ddl) {
    DllCall("uxtheme\SetWindowTheme", "Ptr", ddl.Hwnd, "Str", "DarkMode_CFD", "Ptr", 0)
    ddl.SetFont("cFFFFFF")
    return ddl
}

GuiFormat(x, y, w, h, opts := "") {
    return Trim(Format("x{} y{} w{} h{}", x, y, w, h) " " opts)
}

class CommandManager {
    __New() {
        this.cmds := Map()
    }

    Register(name, cb) {
        this.cmds[name] := cb
        return this
    }

    Execute(name, params*) {
        if (this.cmds.Has(name))
            return this.cmds[name](params*)
        return false
    }
}

class GuiForm {
    __New(gui) {
        this.gui := gui
    }

    Edit(opts := "", txt := "") {
        return ControlBuilder(this.gui, "Edit", txt, opts)
    }

    Button(text, opts := "") {
        return ControlBuilder(this.gui, "Button", text, opts)
    }

    Text(text, opts := "") {
        return ControlBuilder(this.gui, "Text", text, opts)
    }

    DropDownList(opts := "", items := "") {
        return ControlBuilder(this.gui, "DropDownList", items, opts)
    }

    Show() {
        this.gui.Show()
    }
}

class ControlBuilder {
    __New(gui, type, text := "", opts := "") {
        this.gui := gui
        this.type := type
        this.text := text
        this.opts := opts
        this.dim := Map("x", 0, "y", 0, "w", 0, "h", 0)
        this.events := []
    }

    Pos(x?, y?) {
        if IsSet(x)
            this.dim["x"] := x
        if IsSet(y)
            this.dim["y"] := y
        return this
    }

    Size(w?, h?) {
        if IsSet(w)
            this.dim["w"] := w
        if IsSet(h)
            this.dim["h"] := h
        return this
    }

    Opt(opt) {
        if opt
            this.opts := Trim(this.opts " " opt)
        return this
    }

    Default() {
        this.opts := Trim(this.opts " Default")
        return this
    }

    OnEvent(evt, cb) {
        this.events.Push([evt, cb])
        return this
    }

    Add() {
        spec := Trim(Format("x{1} y{2} w{3} h{4}", this.dim["x"], this.dim["y"], this.dim["w"], this.dim["h"]) " " this.opts)
        ctrl := ""
        switch this.type {
            case "Edit":
                ctrl := this.gui.AddEdit(spec, this.text)
            case "Button":
                ctrl := this.gui.AddButton(spec, this.text)
            case "Text":
                ctrl := this.gui.AddText(spec, this.text)
            case "DropDownList":
                ctrl := this.gui.AddDropDownList(spec, this.text)
        }
        if IsObject(ctrl) {
            try _Dark.ThemeCtrl(ctrl)
            if (ctrl.Type = "Edit" || ctrl.Type = "Text" || ctrl.Type = "DDL" || ctrl.Type = "ComboBox")
                ctrl.SetFont("cFFFFFF")
            for _, evt in this.events
                ctrl.OnEvent(evt[1], evt[2])
        }
        return GuiForm(this.gui)
    }
}


class _Dark {
    static Instances := Map()
    static WindowProcOldMap := Map()
    static WindowProcCallbacks := Map()
    static TextBackgroundBrush := 0
    static ControlsBackgroundBrush := 0
    static ButtonColors := Map()
    static ComboBoxes := Map()
    static ListViewHeaders := Map()
    static TextControls := Map()
    static DarkCheckboxPairs := Map()
    static GroupBoxes := Map()
    static RadioButtons := Map()

    ; Theme colors
    static Colors := Map(
        "Background", 0x171717,
        "Controls", 0x202020,
        "Button", 0x171717,
        "ButtonText", 0xFFFFFF,
        "EditText", 0xFFFFFF
    )

    ; Window message constants
    static WM_CTLCOLOREDIT := 0x0133
    static WM_CTLCOLORLISTBOX := 0x0134
    static WM_CTLCOLORBTN := 0x0135
    static WM_CTLCOLORSTATIC := 0x0138
    static WM_NOTIFY := 0x004E
    static LVM_SETTEXTCOLOR := 0x1024
    static LVM_SETTEXTBKCOLOR := 0x1026
    static LVM_SETBKCOLOR := 0x1001

    ; Static Apply method to create or retrieve a _Dark instance
    static Apply(gui) {
        if _Dark.Instances.Has(gui.Hwnd)
            return _Dark.Instances[gui.Hwnd]

        ; Initialize brushes if not already created
        if (!_Dark.TextBackgroundBrush)
            _Dark.TextBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Colors["Background"], "Ptr")
        if (!_Dark.ControlsBackgroundBrush)
            _Dark.ControlsBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Colors["Controls"], "Ptr")

        return _Dark(gui)
    }

    ; Static method for creating dark edit controls
    static AddDarkEdit(gui, options, text := "") {
        edit := gui.AddEdit(options, text)
        DllCall("uxtheme\SetWindowTheme", "Ptr", edit.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        edit.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", edit.hWnd, "Ptr", 0, "Int", true)
        return edit
    }

    ; Static method for theming a control
    static ThemeCtrl(ctrl) {
        if (ctrl.Type = "Edit") {
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
            ctrl.SetFont("cFFFFFF")
        }
        else if (ctrl.Type = "Button") {
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
            ctrl.Opt("Background171717 cFFFFFF")
        }
        else if (ctrl.Type = "Text") {
            ctrl.SetFont("cFFFFFF")
        }
        else if (ctrl.Type = "DDL" || ctrl.Type = "ComboBox") {
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", "DarkMode_CFD", "Ptr", 0)
            ctrl.SetFont("cFFFFFF")
        }

        DllCall("InvalidateRect", "Ptr", ctrl.hWnd, "Ptr", 0, "Int", true)
        return ctrl
    }

    ; Constructor for _Dark instance
    __New(GuiObj) {
        this.Gui := GuiObj
        this.Gui.BackColor := _Dark.Colors["Background"]

        ; Apply dark mode to the window
        if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
            DWMWA_USE_IMMERSIVE_DARK_MODE := 19
            if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
                DWMWA_USE_IMMERSIVE_DARK_MODE := 20

            uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
            if (uxtheme) {
                SetPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
                FlushMenuThemes := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")

                if (SetPreferredAppMode && FlushMenuThemes) {
                    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Gui.hWnd,
                        "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", true, "Int", 4)
                    DllCall(SetPreferredAppMode, "Int", 2)  ; ForceDark mode
                    DllCall(FlushMenuThemes)
                }
            }
        }

        ; Set up window procedure for message handling
        this.SetupWindowProc()

        ; Apply themes to all controls
        this.SetControlsTheme()

        ; Store instance
        _Dark.Instances[this.Gui.Hwnd] := this

        return this
    }

    ; Set up window procedure for handling window messages
    SetupWindowProc() {
        hwnd := this.Gui.Hwnd
        if _Dark.WindowProcOldMap.Has(hwnd)
            return

        global _Dark_WindowProc := ObjBindMethod(_Dark, "ProcessWindowMessage")
        callback := CallbackCreate(_Dark_WindowProc, , 4)
        _Dark.WindowProcCallbacks[hwnd] := callback

        originalProc := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -4, "Ptr")
        DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -4, "Ptr", callback)
        _Dark.WindowProcOldMap[hwnd] := originalProc
    }

    ; Static method for processing window messages
    static ProcessWindowMessage(hwnd, msg, wParam, lParam) {
        static TRANSPARENT := 1

        ; Get original window procedure
        if _Dark.WindowProcOldMap.Has(hwnd) {
            oldProc := _Dark.WindowProcOldMap[hwnd]
        } else {
            return DllCall("DefWindowProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
        }

        ctrlHwnd := lParam

        ; Handle control coloring messages
        if (msg = _Dark.WM_CTLCOLOREDIT || msg = _Dark.WM_CTLCOLORLISTBOX) {
            DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", _Dark.Colors["EditText"])
            DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Colors["Controls"])
            return _Dark.ControlsBackgroundBrush
        }
        else if (msg = _Dark.WM_CTLCOLORBTN) {
            if _Dark.ButtonColors.Has(ctrlHwnd) {
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", _Dark.ButtonColors[ctrlHwnd]["text"])
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.ButtonColors[ctrlHwnd]["bg"])
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                return _Dark.ControlsBackgroundBrush
            }
        }
        else if (msg = _Dark.WM_CTLCOLORSTATIC) {
            if _Dark.TextControls.Has(ctrlHwnd) || _Dark.GroupBoxes.Has(ctrlHwnd) ||
                _Dark.DarkCheckboxPairs.Has(ctrlHwnd) || _Dark.RadioButtons.Has(ctrlHwnd) {
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", _Dark.Colors["EditText"])
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Colors["Background"])
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                return _Dark.TextBackgroundBrush
            }
        }

        ; Call original window procedure for other messages
        return DllCall("CallWindowProc", "Ptr", oldProc, "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    ; Apply themes to all controls in the GUI
    SetControlsTheme() {
        for hWnd, GuiCtrlObj in this.Gui {
            switch GuiCtrlObj.Type {
                case "Button":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    _Dark.ButtonColors[GuiCtrlObj.Hwnd] := Map("bg", _Dark.Colors["Button"], "text", _Dark.Colors["ButtonText"])

                case "CheckBox", "Radio":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    _Dark.ButtonColors[GuiCtrlObj.Hwnd] := Map("bg", _Dark.Colors["Background"], "text", _Dark.Colors["EditText"])
                    if (GuiCtrlObj.Type = "Radio")
                        _Dark.RadioButtons[GuiCtrlObj.Hwnd] := true
                    GuiCtrlObj.SetFont("cFFFFFF")

                case "ComboBox", "DDL":
                    _Dark.ComboBoxes[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_CFD", "Ptr", 0)
                    GuiCtrlObj.SetFont("cFFFFFF")

                case "Edit":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    GuiCtrlObj.SetFont("cFFFFFF")

                case "ListView":
                    SendMessage(_Dark.LVM_SETTEXTCOLOR, 0, _Dark.Colors["EditText"], GuiCtrlObj.Hwnd)
                    SendMessage(_Dark.LVM_SETTEXTBKCOLOR, 0, _Dark.Colors["Background"], GuiCtrlObj.Hwnd)
                    SendMessage(_Dark.LVM_SETBKCOLOR, 0, _Dark.Colors["Background"], GuiCtrlObj.Hwnd)
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)

                case "Text", "Link":
                    _Dark.TextControls[GuiCtrlObj.Hwnd] := true
                    GuiCtrlObj.SetFont("cFFFFFF")

                case "GroupBox":
                    _Dark.GroupBoxes[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "", "Ptr", 0)
                    GuiCtrlObj.SetFont("cFFFFFF")
            }

            DllCall("InvalidateRect", "Ptr", GuiCtrlObj.Hwnd, "Ptr", 0, "Int", true)
        }
    }
}