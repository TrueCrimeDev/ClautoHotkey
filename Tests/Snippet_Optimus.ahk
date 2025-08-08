#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

TextManager()

class TextManager {
    static Snippets := Map(
        "Header",          "; --------- HEADER ---------`n; Author: User`n; Date: YYYY-MM-DD`n",
        "Function",        "; Function:`n;   Purpose: `n;   Params: `n;   Returns: `n",
        "TODO",            "; TODO: Describe task`n",
        "Note",            "; NOTE: `n",
        "Section Divider", ";========================= Section =========================`n"
    )

    __New() {
        this.gui := ""
        this.lbSnippets := ""
        this.cbSend := ""
        this.BuildGui()
        this.SetupHotkeys()
    }

    BuildGui() {
        this.gui := Gui("+Resize")
        this.gui.Title := "Text Manager"
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close", this.Hide.Bind(this))
        this.gui.OnEvent("Escape", this.Hide.Bind(this))
        this.gui.OnEvent("Size", this.OnResize.Bind(this))

        names := []
        for k in TextManager.Snippets
            names.Push(k)
        this.gui.AddText("x10 y12", "Snippets:")
        this.lbSnippets := this.gui.AddListBox("x10 y35 w230 h150 vSnippetList", names)
        this.lbSnippets.Choose(1)
        this.lbSnippets.OnEvent("DoubleClick", this.InsertSnippet.Bind(this))

        this.cbSend := this.gui.AddCheckBox("x10 y195", "Send to Active Window")
        this.cbSend.Value := false

        btnInsert := this.gui.AddButton("x130 y190 w110 h30", "Insert Snippet")
        btnInsert.OnEvent("Click", this.InsertSnippet.Bind(this))

        this.gui.Show("w250 h235")
    }

    OnResize(guiObj, minMax, w, h) {
        this.lbSnippets.Move(10, 35, w-20, h-85)
        this.cbSend.Move(10, h-35)
        this.gui["Button1"].Move(w-120, h-40, 110, 30)
    }

    InsertSnippet(*) {
        idx := this.lbSnippets.Value
        if !idx {
            ToolTip("Please select a snippet")
            SetTimer(() => ToolTip(), -1100)
            return
        }
        name := this.lbSnippets.Text
        if !TextManager.Snippets.Has(name) {
            ToolTip("Snippet not found")
            SetTimer(() => ToolTip(), -1100)
            return
        }
        val := TextManager.Snippets[name]
        A_Clipboard := val
        ClipWait(0.5)
        ToolTip("Snippet copied to clipboard")
        SetTimer(() => ToolTip(), -1200)
        if this.cbSend.Value
            this.SendToActiveWindow(val)
    }

    SendToActiveWindow(val) {
        win := WinExist("A")
        if !win
            return
        if win = this.gui.Hwnd
            return

        if !(DllCall("IsClipboardFormatAvailable", "uint", 1)) {
            ; If clipboard does not contain text, skip backup/restore
            backupClip := ""
        } else {
            backupClip := ""
            try backupClip := A_Clipboard
        }
        try {
            A_Clipboard := val
            ClipWait(0.5, 1)
            Send("^v")
        }
        finally {
            Sleep(40)
            if IsSet(backupClip) && backupClip !== ""
                A_Clipboard := backupClip
        }
    }

    Hide(*) {
        this.gui.Hide()
    }

    SetupHotkeys() {
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("Enter", this.InsertSnippet.Bind(this), "On")
        HotIfWinActive()
    }
}
