#Requires AutoHotkey v2.0
#SingleInstance Force

class SnippetManager {
  static snippets := Map(
    "Greeting", "Hello, I hope this message finds you well.",
    "Closing", "Best regards,`n[Your Name]",
    "Reminder", "This is a friendly reminder about our upcoming meeting.",
    "Follow-up", "Just following up on our previous conversation."
  )

  __New() {
    try {
      this.prevHwnd := WinExist("A")
      this.gui := Gui(, "Snippet Manager")
      this.gui.SetFont("s10")

      keys := []
      for key in SnippetManager.snippets
        keys.Push(key)

      this.listBox := this.gui.Add("ListBox", "w300 h200 vSnippetList", keys)
      this.listBox.OnEvent("DoubleClick", this.CopyToClipboard.Bind(this))

      this.btnCopy := this.gui.Add("Button", "x10 y+10 w140", "Copy to Clipboard")
      this.btnCopy.OnEvent("Click", this.CopyToClipboard.Bind(this))

      this.btnSend := this.gui.Add("Button", "x160 yp w140", "Send to Active Window")
      this.btnSend.OnEvent("Click", this.SendToWindow.Bind(this))

      this.gui.OnEvent("Close", this.Close.Bind(this))
      this.gui.OnEvent("Size", this.Resize.Bind(this))
      this.gui.Show("w320")
    } catch Error as e {
      MsgBox("Error initializing Snippet Manager: " . e.Message)
    }
  }

  CopyToClipboard(*) {
    try {
      if !this.listBox.Text {
        this.ShowTooltip("No snippet selected")
        return
      }

      snippetName := this.listBox.Text
      if !SnippetManager.snippets.Has(snippetName) {
        this.ShowTooltip("Snippet not found")
        return
      }

      A_Clipboard := SnippetManager.snippets.Get(snippetName)
      this.ShowTooltip("Copied to clipboard!")
    } catch Error as e {
      this.ShowTooltip("Error: " . e.Message)
    }
  }

  SendToWindow(*) {
    try {
      if !this.listBox.Text {
        this.ShowTooltip("No snippet selected")
        return
      }

      snippetName := this.listBox.Text
      if !SnippetManager.snippets.Has(snippetName) {
        this.ShowTooltip("Snippet not found")
        return
      }

      snippetText := SnippetManager.snippets.Get(snippetName)
      if !this.prevHwnd || !WinExist("ahk_id " . this.prevHwnd) {
        this.ShowTooltip("Previous window no longer exists")
        return
      }

      WinActivate(this.prevHwnd)
      SendText(snippetText)
      this.ShowTooltip("Sent to active window!")
    } catch Error as e {
      this.ShowTooltip("Error: " . e.Message)
    }
  }

  ShowTooltip(text, duration := 1500) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -duration)
  }

  Resize(gui, minMax, width, height) {
    try {
      static margin := 10
      btnWidth := (width - margin * 3) // 2
      btnY := height - 40

      this.listBox.Move(margin, margin, width - margin * 2, height - 60)
      this.btnCopy.Move(margin, btnY, btnWidth)
      this.btnSend.Move(margin * 2 + btnWidth, btnY, btnWidth)
    } catch Error as e {
      OutputDebug("Resize error: " . e.Message)
    }
  }

  Close(*) {
    try {
      this.gui.Destroy()
    } catch Error as e {
      OutputDebug("Cleanup error: " . e.Message)
    }
  }
}

#s:: {
  try {
    manager := SnippetManager()
  } catch Error as e {
    MsgBox("Failed to launch Snippet Manager: " . e.Message)
  }
}