#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

SnippetManager()

class SnippetManager {
    static Snippets := Map(
        "Greeting", "Hello, I hope this message finds you well.",
        "Closing", "Best regards,`n[Your Name]",
        "Reminder", "This is a gentle reminder regarding our previous discussion.",
        "Follow-up", "I am following up to see if you had a chance to review my last message."
    )

    __New() {
        this.activeWin := 0
        this.timer := this.SaveActiveWindow.Bind(this)
        SetTimer(this.timer, 500)
        this.CreateGui()
    }

    GetSnippetKeys() {
        keys := []
        for key in SnippetManager.Snippets
            keys.Push(key)
        return keys
    }

    CreateGui() {
        this.gui := Gui("+Resize", "Snippet Manager")
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close", this.HideGui.Bind(this))
        this.gui.OnEvent("Escape", this.HideGui.Bind(this))
        this.gui.OnEvent("Size", this.OnResize.Bind(this))

        keys := this.GetSnippetKeys()
        this.listBox := this.gui.AddListBox("vSnippetListBox w300 h160", keys)
        this.listBox.OnEvent("DoubleClick", this.OnCopy.Bind(this))
        this.listBox.OnEvent("Change", this.OnSelect.Bind(this))

        this.copyBtn := this.gui.AddButton("Default w140", "Copy to Clipboard")
        this.copyBtn.OnEvent("Click", this.OnCopy.Bind(this))

        this.sendBtn := this.gui.AddButton("w140 x+10", "Send to Window")
        this.sendBtn.OnEvent("Click", this.OnSend.Bind(this))

        this.gui.Show("w320 h250")
    }

    OnResize(gui, minMax, w, h) {
        this.listBox.Move(, , w - 20, h - 80)
        this.copyBtn.Move(10, h - 60, 140)
        this.sendBtn.Move(170, h - 60, 140)
    }

    SaveActiveWindow() {
        if WinExist("A")
            this.activeWin := WinGetID("A")
    }

    GetSelectedSnippet() {
        idx := this.listBox.Value
        if idx = 0
            return ""
        keys := this.GetSnippetKeys()
        if idx > keys.Length
            return ""
        key := keys[idx]
        return SnippetManager.Snippets.Has(key) ? SnippetManager.Snippets[key] : ""
    }

    OnSelect(ctrl, *) {
        ; No-op, for event signature completeness
    }

    OnCopy(*) {
        snippet := this.GetSelectedSnippet()
        if snippet {
            A_Clipboard := snippet
            this.ShowTooltip("Snippet copied to clipboard")
        } else {
            this.ShowTooltip("No snippet selected")
        }
    }

    OnSend(*) {
        snippet := this.GetSelectedSnippet()
        if snippet && this.activeWin
        {
            this.gui.Hide()
            WinActivate("ahk_id " this.activeWin)
            Sleep(100)
            SendText(snippet)
            this.ShowTooltip("Snippet sent to window")
            this.gui.Show()
        }
        else if !snippet {
            this.ShowTooltip("No snippet selected")
        } else {
            this.ShowTooltip("No previous window to send to")
        }
    }

    ShowTooltip(msg) {
        ToolTip(msg)
        SetTimer(this.ClearTooltip.Bind(this), -1200)
    }

    ClearTooltip() {
        ToolTip()
    }

    HideGui(*) {
        this.gui.Hide()
    }
}
