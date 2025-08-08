#Requires AutoHotkey v2.1-alpha.14
#SingleInstance Force

app := LinkManagerApp()

class LinkManagerApp {
  __New() {
    this.cfg := LinkConfig()
    this.gui := Gui("+Resize +MinSize420x320", "Link Manager")
    this.controls := Map()
    this.BuildGUI()
    this.BindEvents()
    this.LoadLinksToList()
    this.SetupHotkeys()
    this.gui.Show("w520 h420")
    this.WatchConfig()
  }

  BuildGUI() {
    this.gui.MarginX := 10
    this.gui.MarginY := 10
    this.controls["lbl"] := this.gui.AddText("xm ym", "Links")
    this.controls["list"] := this.gui.AddListBox("xm w480 r14 vLinksList")
    this.controls["btnOpen"] := this.gui.AddButton("xm w100", "Open")
    this.controls["btnEdit"] := this.gui.AddButton("x+10 w100", "Edit")
    this.controls["btnReload"] := this.gui.AddButton("x+10 w100", "Reload")
    this.controls["status"] := this.gui.AddText("xm w480 +0x200", "")
    this.gui.OnEvent("Close", this.OnClose.Bind(this))
    this.gui.OnEvent("Escape", this.OnClose.Bind(this))
    this.gui.OnEvent("Size", this.OnResize.Bind(this))
  }

  BindEvents() {
    this.controls["list"].OnEvent("DoubleClick", this.OnOpenSelected.Bind(this))
    this.controls["btnOpen"].OnEvent("Click", this.OnOpenSelected.Bind(this))
    this.controls["btnEdit"].OnEvent("Click", this.OnEditConfig.Bind(this))
    this.controls["btnReload"].OnEvent("Click", this.OnReload.Bind(this))
    this.controls["list"].OnEvent("Change", this.OnListChange.Bind(this))
  }

  SetupHotkeys() {
    HotIf(this._HotIfActive.Bind(this))
    Hotkey("Enter", this.OnOpenSelected.Bind(this))
    Hotkey("^r", this.OnReload.Bind(this))
    Hotkey("^e", this.OnEditConfig.Bind(this))
    HotIf()
  }

  _HotIfActive() {
    return WinActive("ahk_id " . this.gui.Hwnd)
  }

  LoadLinksToList() {
    this.controls["list"].Delete()
    local items := this.cfg.GetAllKeys()
    if (items.Length > 0) {
      this.controls["list"].Add(items)
      this.controls["list"].Choose(1)
      this.HighlightActive()
      this.SetStatus("Loaded " . items.Length . " links")
    } else {
      this.SetStatus("No links found. Click Edit to add links.")
    }
  }

  OnOpenSelected(*) {
    local key := this.controls["list"].Text
    if (key = "") {
      this.ShowTip("No link selected", 1200)
      return
    }
    local url := this.cfg.GetUrl(key)
    if !this.IsValidUrl(url) {
      this.ShowTip("Invalid URL", 1500)
      this.SetStatus("Invalid URL for key: " . key)
      return
    }
    try {
      this.OpenInEdge(url)
      this.ShowTip("Opened in Edge", 1000)
      this.SetStatus("Opened: " . key)
    } catch as err {
      this.ShowTip("Open failed", 1500)
      this.SetStatus("Error: " . err.Message)
    }
  }

  OnEditConfig(*) {
    try {
      this.cfg.EnsureExists()
      Run('notepad.exe "' . this.cfg.Path . '"')
      this.ShowTip("Editing config", 1000)
      this.SetStatus("Editing: " . this.cfg.Path)
    } catch as err {
      this.ShowTip("Cannot open config", 1500)
      this.SetStatus("Config error: " . err.Message)
    }
  }

  OnReload(*) {
    try {
      this.cfg.Reload()
      this.LoadLinksToList()
      this.ShowTip("Reloaded", 900)
    } catch as err {
      this.ShowTip("Reload failed", 1500)
      this.SetStatus("Reload error: " . err.Message)
    }
  }

  OnListChange(*) {
    this.HighlightActive()
  }

  HighlightActive() {
    local idx := this.controls["list"].Value
    if (idx <= 0)
      return
    local hCtl := this.controls["list"].Hwnd
    try {
      DllCall("SendMessage", "ptr", hCtl, "uint", 0x0186, "ptr", idx - 1, "ptr", 1, "ptr")
    } catch as err {
    }
  }

  OpenInEdge(url) {
    local edgeExe := this.FindEdge()
    if (edgeExe != "") {
      Run('"' . edgeExe . '" --new-tab "' . url . '"')
      return
    }
    local hwnd := this.FindMostRecentEdge()
    if (hwnd) {
      WinActivate("ahk_id " . hwnd)
      WinWaitActive("ahk_id " . hwnd, , 2)
      if WinActive("ahk_id " . hwnd) {
        Send("^t")
        Sleep(150)
        SendText(url)
        Send("{Enter}")
        return
      }
    }
    Run('"' . A_ComSpec . '" /c start microsoft-edge:"' . url . '"', , "Hide")
  }

  FindEdge() {
    local pf := A_ProgramFiles
    local pfx86 := EnvGet("ProgramFiles(x86)")
    local lad := EnvGet("LocalAppData")
    local candidates := [
      pf . "\Microsoft\Edge\Application\msedge.exe",
      (pfx86 ? pfx86 : pf) . "\Microsoft\Edge\Application\msedge.exe",
      lad . "\Microsoft\Edge\Application\msedge.exe"
    ]
    for p in candidates
      if FileExist(p)
        return p
    return ""
  }

  FindMostRecentEdge() {
    local hwnd := WinExist("ahk_exe msedge.exe")
    if (hwnd)
      return hwnd
    return 0
  }

  IsValidUrl(s) {
    if (s = "")
      return false
    return RegExMatch(s, "i)^(https?|ftp)://[^\s]+$")
  }

  ShowTip(message, duration := 1200) {
    ToolTip(message)
    SetTimer(this.ClearTip.Bind(this), -Abs(duration))
  }

  ClearTip() {
    ToolTip()
  }

  SetStatus(text) {
    this.controls["status"].Value := text
  }

  OnResize(guiObj, minMax, width, height) {
    if (minMax = -1)
      return
    local mx := this.gui.MarginX
    local my := this.gui.MarginY
    local spacing := 10
    this.controls["lbl"].Move(mx, my)
    local lblX := 0, lblY := 0, lblW := 0, lblH := 0
    this.controls["lbl"].GetPos(&lblX, &lblY, &lblW, &lblH)
    local listH := height - my - lblH - 70
    if (listH < 60)
      listH := 60
    this.controls["list"].Move(mx, my + lblH + 4, width - (mx * 2), listH)
    local btnY := my + lblH + 4 + listH + 6
    this.controls["btnOpen"].Move(mx, btnY, 100)
    this.controls["btnEdit"].Move(mx + 110, btnY, 100)
    this.controls["btnReload"].Move(mx + 220, btnY, 100)
    this.controls["status"].Move(mx, height - my - 22, width - (mx * 2), 22)
  }

  OnClose(*) {
    ExitApp
  }

  WatchConfig() {
    SetTimer(this._onWatch.Bind(this), 700)
  }

  _onWatch() {
    if (this.cfg.HasChanged()) {
      try {
        this.cfg.Reload()
        this.LoadLinksToList()
        this.SetStatus("Config changed, reloaded")
      } catch as err {
        this.SetStatus("Watch error: " . err.Message)
      }
    }
  }
}

class LinkConfig {
  __New() {
    this.Path := A_ScriptDir . "\links.ini"
    this.Section := "Links"
    this._lastWrite := 0
    this.data := Map()
    this.EnsureExists()
    this.Reload()
  }

  EnsureExists() {
    if !FileExist(this.Path) {
      local sample := "[Links]`n" .
        "Google=https://www.google.com`n" .
        "Bing=https://www.bing.com`n" .
        "GitHub=https://github.com`n"
      FileDelete(this.Path)
      FileAppend(sample, this.Path, "UTF-8-RAW")
    }
  }

  Reload() {
    this.data := Map()
    local content := ""
    try {
      content := FileRead(this.Path, "UTF-8-RAW")
    } catch as err {
      throw Error("Cannot read ini: " . this.Path)
    }
    local inSection := false
    for line in StrSplit(content, "`n", "`r") {
      line := Trim(line)
      if (line = "" || SubStr(line, 1, 1) = ";")
        continue
      if (RegExMatch(line, "^\[(.+)\]$", &m)) {
        inSection := (m[1] = this.Section)
        continue
      }
      if (!inSection)
        continue
      if RegExMatch(line, "^(.*?)=(.*)$", &kv) {
        local k := Trim(kv[1])
        local v := Trim(kv[2])
        if (k != "")
          this.data[k] := v
      }
    }
    this._lastWrite := this.GetWriteTime()
  }

  GetAllKeys() {
    local arr := []
    for k, v in this.data
      arr.Push(k)
    if (arr.Length > 1) {
      local s := ""
      for _, n in arr
        s .= n . "`n"
      s := RTrim(s, "`n")
      s := Sort(s)
      return StrSplit(s, "`n")
    }
    return arr
  }

  GetUrl(key) {
    if this.data.Has(key)
      return this.data[key]
    return ""
  }

  HasChanged() {
    local wt := this.GetWriteTime()
    return wt != this._lastWrite
  }

  GetWriteTime() {
    try {
      local f := FileOpen(this.Path, "r")
      if !f
        return 0
      f.Close()
      local ft := FileGetTime(this.Path, "M")
      return ft
    } catch as err {
      return 0
    }
  }
}