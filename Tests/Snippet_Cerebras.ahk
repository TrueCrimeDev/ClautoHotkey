#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

SnippetManager()

class SnippetManager {
  static Snippets := Map(
    "Greeting", "Hello, how can I help you today?",
    "Closing", "Thank you for your time. Best regards,",
    "Reminder", "Just a quick reminder about our meeting.",
    "Follow-up", "Following up on our previous conversation."
  )

  __New() {
    this.gui := Gui("+Resize +LastFound", "Snippet Manager")
    this.gui.SetFont("s10")
    this.gui.MarginX := 10
    this.gui.MarginY := 10
    this.controls := Map()

    this.CreateControls()
    this.SetupEvents()
    this.SetupHotkeys()
  }

  CreateControls() {
    snippetKeys := []
    for key in SnippetManager.Snippets.Keys
      snippetKeys.Push(key)

    this.gui.AddText("xm Section", "Available Snippets:")
    this.controls["snippetList"] := this.gui.AddListBox("xm w300 r10 vSnippetList", snippetKeys)

    this.gui.AddText("xm Section ys+20", "Actions:")
    this.controls["copyBtn"] := this.gui.AddButton("xm w140", "Copy to Clipboard")
    this.controls["sendBtn"] := this.gui.AddButton("x+10 w140", "Send to Window")
  }

  SetupEvents() {
    this.gui.OnEvent("Close", this.OnClose.Bind(this))
    this.gui.OnEvent("Escape", this.OnClose.Bind(this))
    this.gui.OnEvent("Size", this.OnResize.Bind(this))

    this.controls["copyBtn"].OnEvent("Click", this.OnCopy.Bind(this))
    this.controls["sendBtn"].OnEvent("Click", this.OnSend.Bind(this))
  }

  SetupHotkeys() {
    ; Create a proper callback function
    checkWindow := Func("WinActive").Bind("ahk_id " . this.gui.Hwnd)
    HotIf(checkWindow)
    Hotkey("Enter", this.OnCopy.Bind(this))
    Hotkey("Space", this.OnSend.Bind(this))
    HotIf()  ; Reset to default
  }

  OnCopy(*) {
    try {
      selected := this.controls["snippetList"].Text
      if selected = ""
        throw ValueError("No snippet selected")

      content := SnippetManager.Snippets[selected]
      A_Clipboard := content
      this.ShowTooltip("Copied to clipboard: " . selected)

    } catch as err {
      this.ShowTooltip("Error: " . err.Message)
    }
  }

  OnSend(*) {
    try {
      selected := this.controls["snippetList"].Text
      if selected = ""
        throw ValueError("No snippet selected")

      content := SnippetManager.Snippets[selected]
      this.SendToPreviousWindow(content)
      this.ShowTooltip("Sent snippet: " . selected)

    } catch as err {
      this.ShowTooltip("Error: " . err.Message)
    }
  }

  SendToPreviousWindow(text) {
    ; Get previous active window
    WinGetPos(&prevX, &prevY, &prevW, &prevH, "A")
    prevHwnd := WinExist("A")

    if !prevHwnd
      throw Error("No previous window found")

    ; Activate previous window
    WinActivate("ahk_id " . prevHwnd)
    WinWaitActive("ahk_id " . prevHwnd, , 2)

    ; Send text
    SendText(text)
  }

  ShowTooltip(message) {
    ToolTip(message)
    SetTimer(() => ToolTip(), -2000)  ; Hide after 2 seconds
  }

  OnResize(guiObj, minMax, width, height) {
    if minMax = -1
      return

    margin := this.gui.MarginX
    listWidth := width - (margin * 2)
    listHeight := height - 120

    this.controls["snippetList"].Move(, , listWidth, listHeight)
    this.controls["copyBtn"].Move(, height - 60)
    this.controls["sendBtn"].Move(, height - 60)
  }

  OnClose(*) {
    this.gui.Destroy()
  }

  Show() {
    this.gui.Show("w400 h300")
  }
}