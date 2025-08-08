#Requires AutoHotkey v2.0
#SingleInstance Force

main := SnippetManager()
main.Show()

class SnippetManager {
    static Config := Map("width", 640, "height", 360, "title", "Snippet Manager")
    static Snippets := Map(
        "Greeting", "Hello [Name],`n`nI hope you're doing well.",
        "Closing", "Best regards,`n[Your Name]",
        "Reminder", "Friendly reminder about our upcoming meeting on [Date] at [Time]. Please confirm your availability.",
        "Follow-up", "Following up on my previous message regarding [Topic]. When you have a moment, please share an update. Thank you."
    )
    controls := Map()
    prevHwnd := 0
    __New() {
        this.gui := Gui("+Resize", SnippetManager.Config["title"])
        this.gui.MarginX := 12
        this.gui.MarginY := 12
        this.gui.MinSize := "520x280"
        this.gui.BackColor := 0x202020
        this.gui.SetFont("s10 cWhite", "Segoe UI")
        this.CreateControls()
        this.SetupEvents()
        this.ApplyDarkMode()
    }
    CreateControls() {
        this.controls["titleL"] := this.gui.AddText("xm ym Section cWhite", "Snippets")
        items := []
        for k, _ in SnippetManager.Snippets
            items.Push(k)
        this.controls["list"] := this.gui.AddListBox("xm w240 h220 cWhite Background2b2b2b", items)
        this.controls["previewL"] := this.gui.AddText("x+10 ys cWhite", "Preview")
        this.controls["preview"] := this.gui.AddEdit("x+0 ys w320 h220 ReadOnly -Wrap cWhite Background1e1e1e", "")
        this.controls["copyBtn"] := this.gui.AddButton("xm w150 h28", "Copy to Clipboard")
        this.controls["sendBtn"] := this.gui.AddButton("x+10 w200 h28", "Send to Previous Window")
    }
    SetupEvents() {
        this.gui.OnEvent("Close", this.OnClose.Bind(this))
        this.gui.OnEvent("Escape", this.OnClose.Bind(this))
        this.gui.OnEvent("Size", this.OnResize.Bind(this))
        this.controls["copyBtn"].OnEvent("Click", this.OnCopy.Bind(this))
        this.controls["sendBtn"].OnEvent("Click", this.OnSend.Bind(this))
        this.controls["list"].OnEvent("Change", this.OnSelect.Bind(this))
        this.controls["list"].OnEvent("DoubleClick", this.OnCopy.Bind(this))
    }
    ApplyDarkMode() {
        try {
            v := 1
            DllCall("Dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.Hwnd, "UInt", 20, "Ptr*", v, "UInt", 4)
        } catch as e {
            OutputDebug("DWM dark mode not applied: " . e.Message)
        }
        this._SetWindowTheme(this.gui.Hwnd, "DarkMode_Explorer")
        for , ctrl in this.controls
            this._SetWindowTheme(ctrl.Hwnd, "DarkMode_Explorer")
    }
    _SetWindowTheme(hwnd, app) {
        try {
            DllCall("uxtheme\SetWindowTheme", "ptr", hwnd, "ptr", StrPtr(app), "ptr", 0)
        } catch as e {
            OutputDebug("SetWindowTheme failed: " . e.Message)
        }
    }
    Show() {
        try {
            this.prevHwnd := WinExist("A")
        } catch as e {
            OutputDebug("Failed to capture previous window: " . e.Message)
            this.prevHwnd := 0
        }
        this.gui.Show("w" . SnippetManager.Config["width"] . " h" . SnippetManager.Config["height"])
        if (this.controls["list"].Text = "") {
            this.controls["list"].Choose(1)
            this.UpdatePreview()
        }
    }
    OnSelect(*) {
        this.UpdatePreview()
    }
    UpdatePreview() {
        key := this.controls["list"].Text
        text := SnippetManager.Snippets.Has(key) ? SnippetManager.Snippets[key] : ""
        this.controls["preview"].Value := text
    }
    OnCopy(*) {
        try {
            text := this.GetSelectedSnippetText()
            if (text = "") {
                this.ShowTip("Select a snippet")
                return
            }
            A_Clipboard := text
            this.ShowTip("Copied to clipboard")
        } catch as e {
            this.ShowTip("Error: " . e.Message)
        }
    }
    OnSend(*) {
        try {
            text := this.GetSelectedSnippetText()
            if (text = "") {
                this.ShowTip("Select a snippet")
                return
            }
            this.SendToPrevious(text)
            this.ShowTip("Snippet sent")
        } catch as e {
            this.ShowTip("Error: " . e.Message)
        }
    }
    GetSelectedSnippetText() {
        key := this.controls["list"].Text
        if (key = "")
            return ""
        if !SnippetManager.Snippets.Has(key)
            return ""
        return SnippetManager.Snippets[key]
    }
    SendToPrevious(text) {
        if (this.prevHwnd = 0)
            throw Error("No previous window recorded")
        if !WinExist("ahk_id " . this.prevHwnd)
            throw Error("Previous window no longer exists")
        WinActivate("ahk_id " . this.prevHwnd)
        if !WinWaitActive("ahk_id " . this.prevHwnd, , 2)
            throw Error("Failed to activate target window")
        try {
            SendText(text)
        } catch as e {
            OutputDebug("SendText failed, fallback to SendInput: " . e.Message)
            SendInput(text)
        }
    }
    OnResize(guiObj, minMax, width, height) {
        if (minMax = -1)
            return
        mx := this.gui.MarginX
        my := this.gui.MarginY
        this.controls["copyBtn"].GetPos(, , &btnW, &btnH)
        areaTop := my + 20
        areaBottom := height - my - btnH - 8
        areaH := Max(areaBottom - areaTop, 60)
        leftW := Max(Floor((width - mx*3) * 0.45), 180)
        rightW := width - mx*3 - leftW
        this.controls["titleL"].Move(mx, my)
        this.controls["list"].Move(mx, areaTop, leftW, areaH)
        this.controls["previewL"].Move(mx*2 + leftW, my)
        this.controls["preview"].Move(mx*2 + leftW, areaTop, rightW, areaH)
        this.controls["copyBtn"].Move(mx, areaTop + areaH + 8, 160, btnH)
        this.controls["sendBtn"].Move(width - mx - 220, areaTop + areaH + 8, 220, btnH)
    }
    ShowTip(msg, ms := 1400) {
        ToolTip(msg)
        SetTimer(this._HideTip.Bind(this), -ms)
    }
    _HideTip(*) {
        ToolTip()
    }
    OnClose(*) {
        this.gui.Hide()
    }
}