#Requires AutoHotkey v2.1-alpha.14
#SingleInstance Force

app := SnippetManager()

class SnippetManager {
  static SNIPPETS := Map(
    "Greeting", "Hello! I hope you're having a wonderful day. Thank you for reaching out.",
    "Closing", "Thank you for your time and consideration. I look forward to hearing from you soon. Best regards.",
    "Reminder", "Just a friendly reminder about our upcoming meeting. Please let me know if you need to reschedule.",
    "Follow-up", "I wanted to follow up on our previous conversation. Do you have any updates or questions?"
  )

  constructor() {
    this.previousWindow := ""
    this.controls := Map()
    this.tooltipTimer := 0
    this.InitializeGui()
    this.SetupControls()
    this.SetupEvents()
    this.SetupHotkeys()
  }

  InitializeGui() {
    this.gui := Gui("+Resize -MaximizeBox", "Snippet Manager")
    this.gui.BackColor := "White"
    this.gui.SetFont("s10", "Segoe UI")
    this.gui.MarginX := 15
    this.gui.MarginY := 15
  }

  SetupControls() {
    this.gui.AddText("", "Available Snippets:")

    snippetList := []
    for name, content in this.SNIPPETS {
      snippetList.Push(name)
    }

    this.controls["listbox"] := this.gui.AddListBox("w400 h200 vSnippetList", snippetList)

    this.gui.AddText("xm y+15", "Actions:")
    this.controls["copyBtn"] := this.gui.AddButton("xm y+5 w100 h30", "&Copy")
    this.controls["sendBtn"] := this.gui.AddButton("x+10 w100 h30", "&Send")
    this.controls["previewBtn"] := this.gui.AddButton("x+10 w100 h30", "&Preview")

    this.gui.AddText("xm y+20", "Preview:")
    this.controls["preview"] := this.gui.AddEdit("xm y+5 w400 h100 ReadOnly Multi VScroll", "Select a snippet to see preview...")

    this.controls["listbox"].Choose(1)
    this.UpdatePreview()
  }

  SetupEvents() {
    this.gui.OnEvent("Close", this.GuiClose.Bind(this))
    this.gui.OnEvent("Escape", this.Hide.Bind(this))
    this.gui.OnEvent("Size", this.HandleResize.Bind(this))

    this.controls["listbox"].OnEvent("Change", this.UpdatePreview.Bind(this))
    this.controls["listbox"].OnEvent("DoubleClick", this.CopySnippet.Bind(this))
    this.controls["copyBtn"].OnEvent("Click", this.CopySnippet.Bind(this))
    this.controls["sendBtn"].OnEvent("Click", this.SendSnippet.Bind(this))
    this.controls["previewBtn"].OnEvent("Click", this.ShowFullPreview.Bind(this))
  }

  SetupHotkeys() {
    Hotkey("F9", this.Toggle.Bind(this))

    HotIfWinExist("ahk_id " . this.gui.Hwnd)
    Hotkey("Escape", this.Hide.Bind(this), "On")
    Hotkey("Enter", this.CopySnippet.Bind(this), "On")
    Hotkey("F1", this.SendSnippet.Bind(this), "On")
    HotIfWinExist()
  }

  Toggle() {
    if WinExist("ahk_id " . this.gui.Hwnd) {
      this.Hide()
    } else {
      this.Show()
    }
  }

  Show() {
    this.previousWindow := WinGetID("A")
    this.gui.Show("w430 h380")
    this.controls["listbox"].Focus()
  }

  Hide() {
    this.gui.Hide()
  }

  GuiClose() {
    this.Hide()
  }

  HandleResize(thisGui, minMax, width, height) {
    if minMax = -1
      return

    newWidth := width - 30
    newListHeight := height - 280
    newPreviewHeight := height - 200

    if newListHeight < 100
      newListHeight := 100
    if newPreviewHeight < 80
      newPreviewHeight := 80

    this.controls["listbox"].Move(, , newWidth, newListHeight)
    this.controls["preview"].Move(, height - newPreviewHeight - 15, newWidth, newPreviewHeight)
  }

  UpdatePreview() {
    selectedIndex := this.controls["listbox"].Value
    if selectedIndex > 0 {
      snippetList := []
      for name, content in this.SNIPPETS {
        snippetList.Push(name)
      }

      selectedName := snippetList[selectedIndex]
      content := this.SNIPPETS[selectedName]
      this.controls["preview"].Text := content
    } else {
      this.controls["preview"].Text := "No snippet selected..."
    }
  }

  GetSelectedSnippet() {
    selectedIndex := this.controls["listbox"].Value
    if selectedIndex = 0 {
      this.ShowTooltip("Please select a snippet first!")
      return ""
    }

    snippetList := []
    for name, content in this.SNIPPETS {
      snippetList.Push(name)
    }

    selectedName := snippetList[selectedIndex]
    return this.SNIPPETS[selectedName]
  }

  CopySnippet() {
    content := this.GetSelectedSnippet()
    if content != "" {
      A_Clipboard := content
      this.ShowTooltip("Snippet copied to clipboard!")
    }
  }

  SendSnippet() {
    content := this.GetSelectedSnippet()
    if content != "" {
      this.Hide()

      if this.previousWindow != "" {
        try {
          WinActivate("ahk_id " . this.previousWindow)
          Sleep(100)
        } catch {
          this.ShowTooltip("Could not activate previous window!")
          return
        }
      }

      A_Clipboard := content
      Sleep(50)
      Send("^v")
      this.ShowTooltip("Snippet sent to active window!")
    }
  }

  ShowFullPreview() {
    content := this.GetSelectedSnippet()
    if content != "" {
      MsgBox(content, "Snippet Preview", "OK")
    }
  }

  ShowTooltip(message) {
    if this.tooltipTimer != 0 {
      SetTimer(this.tooltipTimer, 0)
    }

    ToolTip(message)
    this.tooltipTimer := () => ToolTip()
    SetTimer(this.tooltipTimer, -2000)
  }
}