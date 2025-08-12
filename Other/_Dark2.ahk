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
  static LVW_H := 583

  static COL_CO := 1
  static COL_MDL := 2
  static COL_TTL := 3
  static COL_NOTE := 4

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

    this.LoadData()
    this.InitGui()
    this.LoadPmts()
    this.RefreshList()
    this.gui.Show()
  }

  RegCmds() {
    this.cmdMgr
      .Register("save", this.SaveEntry.Bind(this))
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

    this.lvw := this.gui.AddListView(
      Format("x{} y{} w{} h{} {}",
        Lg.PAD, Lg.PAD, Lg.LEFT_W, 595, "Grid cWhite"),
      ["Company", "Model", "Prompt", "Notes"]
    )

    this.lvw.Opt("-Redraw")
    SendMessage(LVM_SETTEXTCOLOR, 0, 0xFFFFFF, this.lvw.Hwnd)
    SendMessage(LVM_SETTEXTBKCOLOR, 0, 0x202020, this.lvw.Hwnd)
    SendMessage(LVM_SETBKCOLOR, 0, 0x202020, this.lvw.Hwnd)
    this.lvw.Opt("+Redraw")

    if (this.lvw.HasMethod("SetDarkMode"))
      this.lvw.SetDarkMode()

    this.lvw.ModifyCol(Lg.COL_CO, 70)
    this.lvw.ModifyCol(Lg.COL_MDL, 50)
    this.lvw.ModifyCol(Lg.COL_TTL, 80)
    this.lvw.ModifyCol(Lg.COL_NOTE, 150)

    this.lvw.OnEvent("DoubleClick", (*) => this.cmdMgr.Execute("load"))
  }

  CreateBtns() {
    btnY := Lg.PAD + Lg.LVW_H + Lg.PAD + Lg.PAD
    btnW := ((Lg.LEFT_W - (Lg.PAD * 5)) / 4) + 5

    this.btnLoad := this.CreateBtn(
      Lg.PAD, btnY, btnW, "Load Entry",
      (*) => this.cmdMgr.Execute("load")
    )

    this.btnClear := this.CreateBtn(
      Lg.PAD * 2 + btnW, btnY, btnW, "Clear Form",
      (*) => this.cmdMgr.Execute("clear")
    )

    this.btnDel := this.CreateBtn(
      Lg.PAD * 3 + btnW * 2, btnY, btnW, "Delete Entry",
      (*) => this.cmdMgr.Execute("delete")
    )

    this.btnSave := this.CreateBtn(
      Lg.PAD * 4 + btnW * 3, btnY, btnW, "Save Entry",
      (*) => this.cmdMgr.Execute("save")
    )
  }

  CreateBtn(x, y, w, txt, cb) {
    btn := this.gui.AddButton(
      Format("x{} y{} w{} h{} {}",
        x, y, w, Lg.BTN_H, "Background171717 cFFFFFF"),
      txt
    )
    btn.OnEvent("Click", cb)
    ApplyDarkModeToBtn(btn)
    return btn
  }

  CreateRightPanel() {
    this.CreateFormCtrls()
  }

  CreateFormCtrls() {
    rightX := Lg.LEFT_W + Lg.PAD * 2

    this.AddLbl(rightX, Lg.PAD, "Company:")
    this.coEdit := this.AddDarkEdit(
      rightX + Lg.LBL_W + Lg.PAD,
      Lg.PAD,
      Lg.INP_W,
      Lg.INP_H
    )

    this.AddLbl(rightX, Lg.PAD * 2 + Lg.INP_H, "Model:")
    this.mdlEdit := this.AddDarkEdit(
      rightX + Lg.LBL_W + Lg.PAD,
      Lg.PAD * 2 + Lg.INP_H,
      Lg.INP_W,
      Lg.INP_H
    )

    this.AddLbl(rightX, Lg.PAD * 3 + Lg.INP_H * 2, "Prompt:")

    this.pmtBox := this.gui.AddDropDownList(
      Format("x{} y{} w{} h{}",
        rightX + Lg.LBL_W + Lg.PAD,
        Lg.PAD * 3 + Lg.INP_H * 2,
        Lg.INP_W - Lg.BTN_H * 2 - Lg.PAD * 2,
        Lg.INP_H * 8
      )
    )
    this.PopulatePmtDdl()
    this.pmtBox.OnEvent("Change", this.OnPmtSelect.Bind(this))
    ApplyDarkModeToDdl(this.pmtBox)

    this.btnSavePmt := this.CreateBtn(
      rightX + Lg.LBL_W + Lg.PAD + Lg.INP_W - Lg.BTN_H * 2 - Lg.PAD,
      Lg.PAD * 3 + Lg.INP_H * 2,
      Lg.BTN_H,
      "💾",
      (*) => this.cmdMgr.Execute("savePrompt")
    )

    this.btnNewPmt := this.CreateBtn(
      rightX + Lg.LBL_W + Lg.PAD + Lg.INP_W - Lg.BTN_H,
      Lg.PAD * 3 + Lg.INP_H * 2,
      Lg.BTN_H,
      "✚",
      (*) => this.cmdMgr.Execute("newPrompt")
    )

    this.AddLbl(rightX, Lg.PAD * 4 + Lg.INP_H * 3, "Body:")
    this.pmtEdit := this.AddDarkEdit(
      rightX + Lg.LBL_W + Lg.PAD,
      Lg.PAD * 4 + Lg.INP_H * 3,
      Lg.INP_W,
      Lg.TXT_H,
      "Multi VScroll"
    )

    this.AddLbl(rightX, Lg.PAD * 5 + Lg.INP_H * 3 + Lg.TXT_H, "Code:")
    this.btnRunCode := this.CreateBtn(
      rightX + Lg.LBL_W - Lg.PAD - Lg.PAD - Lg.PAD,
      Lg.PAD * 5 + Lg.INP_H * 3 + Lg.TXT_H,
      Lg.BTN_H,
      "⏵︎",
      (*) => this.cmdMgr.Execute("runCode")
    )

    this.codeEdit := this.AddDarkEdit(
      rightX + Lg.LBL_W + Lg.PAD,
      Lg.PAD * 5 + Lg.INP_H * 3 + Lg.TXT_H,
      Lg.INP_W,
      Lg.CODE_H,
      "Multi VScroll"
    )
    this.codeEdit.Value := 'MsgBox("LOL")'

    this.AddLbl(rightX, Lg.PAD * 6 + Lg.INP_H * 3 + Lg.TXT_H + Lg.CODE_H, "Errors:")
    this.errEdit := this.AddDarkEdit(
      rightX + Lg.LBL_W + Lg.PAD,
      Lg.PAD * 6 + Lg.INP_H * 3 + Lg.TXT_H + Lg.CODE_H,
      Lg.INP_W,
      Lg.TXT_H,
      "Multi VScroll"
    )

    this.AddLbl(rightX, Lg.PAD * 7 + Lg.INP_H * 3 + Lg.TXT_H * 2 + Lg.CODE_H, "Notes:")
    this.noteEdit := this.AddDarkEdit(
      rightX + Lg.LBL_W + Lg.PAD,
      Lg.PAD * 7 + Lg.INP_H * 3 + Lg.TXT_H * 2 + Lg.CODE_H,
      Lg.INP_W,
      Lg.TXT_H,
      "Multi VScroll"
    )

    HotKey("F5", (*) => this.cmdMgr.Execute("runCode"))
  }

  AddLbl(x, y, txt) {
    return this.gui.AddText(
      Format("x{} y{} w{} h{} {}",
        x, y, Lg.LBL_W, Lg.INP_H, "cFFFFFF"),
      txt
    )
  }

  AddDarkEdit(x, y, w, h, opts := "") {
    return _Dark.AddDarkEdit(
      this.gui,
      Format("x{} y{} w{} h{} {}", x, y, w, h, opts)
    )
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
    if (this.pmtBox.HasProp("Items") && this.pmtBox.Items.Length > 0) {
      Loop this.pmtBox.Items.Length {
        if (this.pmtBox.Items[A_Index] = name) {
          this.pmtBox.Choose(A_Index)
          break
        }
      }
    } else {
      Loop 100 {
        try {
          if (this.pmtBox.GetText(A_Index) = name) {
            this.pmtBox.Choose(A_Index)
            break
          }
        } catch {
          break
        }
      }
    }
  }

  OnPmtSelect(*) {
    selPmt := this.pmtBox.Text
    this.pmtEdit.Value := this.pmts.Has(selPmt)
      ? this.pmts[selPmt]
      : ""
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

  LoadPmts() {
    this.pmts := Map()
    fileExists := FileExist(this.pmtFile)

    if fileExists {
      try {
        jsonTxt := FileRead(this.pmtFile)
        if (jsonTxt != "" && !RegExMatch(jsonTxt, "^\s*$")) {
          prompts := JSON.Load(jsonTxt)

          if (IsObject(prompts) && HasMethod(prompts, "Push")) {
            loadCnt := 0
            for i, pmt in prompts {
              if (IsObject(pmt) && pmt.Has("title") && pmt.Has("body")) {
                this.pmts[pmt["title"]] := pmt["body"]
                loadCnt++
              }
            }

            if (loadCnt = 0)
              MsgBox("Prompts file '" this.pmtFile "' exists but contains no valid prompts.", "Warning", "Icon!")
          } else if (IsObject(prompts)) {
            MsgBox("Prompts file '" this.pmtFile "' exists but is not an array of prompts.", "Warning", "Icon!")
          } else {
            MsgBox("Prompts file '" this.pmtFile "' exists but contains invalid JSON.", "Warning", "Icon!")
          }
        }
      } catch Error as err {
        MsgBox("Error loading prompt templates from '" this.pmtFile "': " err.Message, "Error", "Icon!")
      }
    } else {
      try {
        FileAppend("[]", this.pmtFile)
      } catch Error as err {
        MsgBox("Error creating prompts file '" this.pmtFile "': " err.Message, "Error", "Icon!")
      }
    }

    this.PopulatePmtDdl()
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

      scriptHdr := "#Requires AutoHotkey v2.1-alpha.17 64-bit`n"
        . "#SingleInstance Force`n"
        . "#Warn All`n`n"
        . "OnExit((*) => ExitApp())`n`n"
        . "#HotIf WinActive(A_ScriptName)`n"
        . "Esc::ExitApp`n"
        . "#HotIf`n`n"

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
            this.errEdit.Value := this.errEdit.Value
              ? this.errEdit.Value "`n" RTrim(errTxt, "`n")
              : RTrim(errTxt, "`n")
          }
        }
      } catch {
      }
    } catch {
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
          this.coEdit.Value := entCo
          this.mdlEdit.Value := entMdl

          this.SelectPmtByName(entTtl)

          this.pmtEdit.Value := ent.Has("PromptBody")
            ? ent["PromptBody"]
            : (ent.Has("Prompt") ? ent["Prompt"] : "")

          this.codeEdit.Value := ent.Has("Code") ? ent["Code"] : ""
          this.errEdit.Value := ent.Has("Errors") ? ent["Errors"] : ""
          this.noteEdit.Value := ent.Has("Notes") ? ent["Notes"] : ""

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

  SaveEntry(*) {
    co := this.coEdit.Value
    mdl := this.mdlEdit.Value
    pmtTtl := this.pmtBox.Text
    pmtBody := this.pmtEdit.Value
    code := this.codeEdit.Value
    errs := this.errEdit.Value
    notes := this.noteEdit.Value

    if (co = "" || mdl = "") {
      MsgBox("Company and Model are required.", "Validation Error", "Icon!")
      return
    }

    fmt := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    ent := Map(
      "Company", co,
      "Model", mdl,
      "PromptTitle", pmtTtl,
      "PromptBody", pmtBody,
      "Code", code,
      "Errors", errs,
      "Notes", notes,
      "Timestamp", fmt
    )

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
    this.coEdit.Value := ""
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

class _Dark {
  static Colors := Map(
    "Bg", "0x202020",
    "Ctrl", "0x303030",
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

  static LVM_GETTEXTCOLOR := 0x1023
  static LVM_SETTEXTCOLOR := 0x1024
  static LVM_GETTEXTBKCOLOR := 0x1025
  static LVM_SETTEXTBKCOLOR := 0x1026
  static LVM_GETBKCOLOR := 0x1000
  static LVM_SETBKCOLOR := 0x1001
  static LVM_GETHEADER := 0x101F

  static AddDarkEdit(gui, opts, txt := "") {
    edit := gui.AddEdit(opts, txt)
    DllCall("uxtheme\SetWindowTheme", "Ptr", edit.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
    edit.SetFont("cFFFFFF")
    DllCall("InvalidateRect", "Ptr", edit.hWnd, "Ptr", 0, "Int", true)
    return edit
  }

  static Apply(gui) {
    static txtBgBrush := 0, ctrlBrush := 0, procNew := 0, procOld := 0, guiHwnd := 0

    if (!txtBgBrush) {
      txtBgBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Colors["Bg"], "Ptr")
      ctrlBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Colors["Ctrl"], "Ptr")

      if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        DWMWA_USE_IMMERSIVE_DARK_MODE := 19
        if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
          DWMWA_USE_IMMERSIVE_DARK_MODE := 20

        uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
        SetPrefAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
        FlushMenuThemes := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")

        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", gui.hWnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", true, "Int", 4)
        DllCall(SetPrefAppMode, "Int", 2)
        DllCall(FlushMenuThemes)
      }

      gui.BackColor := _Dark.Colors["Bg"]
      guiHwnd := gui.hWnd

      for hWnd, ctrl in gui
        _Dark.ThemeCtrl(ctrl)

      WinProc := _Dark_WindowProc
      procNew := CallbackCreate(WinProc)
      procOld := DllCall("user32\" (A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"),
        "Ptr", gui.Hwnd, "Int", _Dark.GWL_WNDPROC, "Ptr", procNew, "Ptr")
    }

    _Dark_WindowProc(hwnd, uMsg, wParam, lParam) {
      if (hwnd = guiHwnd) {
        switch uMsg {
          case _Dark.WM_CTLCOLOREDIT, _Dark.WM_CTLCOLORLISTBOX:
            DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", _Dark.Colors["Font"])
            DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Colors["Ctrl"])
            DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", _Dark.Colors["Ctrl"], "UInt")
            return ctrlBrush

          case _Dark.WM_CTLCOLORBTN:
            DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", _Dark.Colors["Bg"], "UInt")
            return DllCall("gdi32\GetStockObject", "Int", _Dark.DC_BRUSH, "Ptr")

          case _Dark.WM_CTLCOLORSTATIC:
            DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", _Dark.Colors["Font"])
            DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Colors["Bg"])
            return txtBgBrush
        }
      }

      return DllCall("user32\CallWindowProc", "Ptr", procOld, "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam)
    }
  }

  static ThemeCtrl(ctrl) {
    expMode := "DarkMode_Explorer"
    cfdMode := "DarkMode_CFD"
    itemsMode := "DarkMode_ItemsView"

    switch ctrl.Type {
      case "Button", "CheckBox", "ListBox", "UpDown":
        DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", expMode, "Ptr", 0)

      case "ComboBox", "DDL":
        DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", cfdMode, "Ptr", 0)

      case "Edit":
        isMulti := DllCall("user32\" (A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"),
          "Ptr", ctrl.hWnd, "Int", _Dark.GWL_STYLE) & _Dark.ES_MULTILINE

        themeMode := isMulti ? expMode : cfdMode
        DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", themeMode, "Ptr", 0)

      case "ListView":
        ctrl.Opt("-Redraw")
        SendMessage(_Dark.LVM_SETTEXTCOLOR, 0, _Dark.Colors["Font"], ctrl.hWnd)
        SendMessage(_Dark.LVM_SETTEXTBKCOLOR, 0, _Dark.Colors["Bg"], ctrl.hWnd)
        SendMessage(_Dark.LVM_SETBKCOLOR, 0, _Dark.Colors["Bg"], ctrl.hWnd)

        DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", expMode, "Ptr", 0)

        LV_Hdr := SendMessage(_Dark.LVM_GETHEADER, 0, 0, ctrl.hWnd)
        DllCall("uxtheme\SetWindowTheme", "Ptr", LV_Hdr, "Str", itemsMode, "Ptr", 0)

        ctrl.Opt("+Redraw")
    }
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