#Requires AutoHotkey v2.0
#SingleInstance Force

;================================================================
;  CLASS: SnippetManager
;================================================================
class SnippetManager extends Object {
  ;----------------------------------------------------------------
  ;  Static data – the collection of snippets (shared by all instances)
  ;----------------------------------------------------------------
  static Snippets := Map(
    "Greeting", "Hello, how are you?",
    "Closing", "Best regards,`nYour Name",
    "Reminder", "Don't forget to submit the report by Friday.",
    "Follow‑up", "Following up on our previous conversation..."
  )

  ;----------------------------------------------------------------
  ;  Instance fields (created in __New)
  ;----------------------------------------------------------------
  gui := ""          ; Gui object
  lstBox := ""          ; ListBox control
  btnCopy := ""          ; “Copy” button
  btnSend := ""          ; “Send” button
  btnClose := ""          ; “Close” button
  prevWinId := 0           ; HWND of the window that was active before the GUI
  tooltipTimer := 0           ; Timer ID for auto‑hide tooltip

  ;----------------------------------------------------------------
  ;  Constructor – builds the GUI and binds events
  ;----------------------------------------------------------------
  __New() {
    ;--- Remember the window that had focus before we open the GUI
    this.prevWinId := WinGetID("A")

    ;--- Create the main GUI (resizable, with a minimum size)
    this.gui := Gui("+Resize +MinSize500x300", "Snippet Manager")
    this.gui.MarginX := 10, this.gui.MarginY := 10

    ;--- ListBox – will hold the snippet names
    this.lstBox := this.gui.Add("ListBox", "w380 h200 vSelectedSnippet", "")
    ; Populate it with the keys of the static Map
    for name in SnippetManager.Snippets.OwnProps()
      this.lstBox.Add(name)

    ;--- Buttons
    this.btnCopy := this.gui.Add("Button", "xp yp+210 w80 h30", "Copy")
    this.btnSend := this.gui.Add("Button", "xp+90 yp w80 h30", "Send")
    this.btnClose := this.gui.Add("Button", "xp+180 yp w80 h30", "Close")

    ;--- Event bindings -------------------------------------------------
    ; ListBox double‑click → copy to clipboard (convenient shortcut)
    this.lstBox.OnEvent("DoubleClick", (*) => this.CopyToClipboard())
    ; Buttons
    this.btnCopy.OnEvent("Click", (*) => this.CopyToClipboard())
    this.btnSend.OnEvent("Click", (*) => this.SendToPrevWindow())
    this.btnClose.OnEvent("Click", (*) => this.gui.Destroy())
    ; Resize handling – keep controls nicely aligned
    this.gui.OnEvent("Size", (*) => this.AdjustLayout())
    ;-------------------------------------------------------------------

    ;--- Show the GUI
    this.gui.Show()
  }

  ;----------------------------------------------------------------
  ;  AdjustLayout – called on every resize event
  ;----------------------------------------------------------------
  AdjustLayout() {
    ; Get the new client area size
    clientW := this.gui.ClientWidth, clientH := this.gui.ClientHeight

    ; ListBox occupies most of the area
    this.lstBox.Move(0, 0, clientW - 20, clientH - 60)

    ; Buttons stay at the bottom, left‑aligned
    btnY := clientH - 45
    this.btnCopy.Move(0, btnY, 80, 30)
    this.btnSend.Move(90, btnY, 80, 30)
    this.btnClose.Move(180, btnY, 80, 30)
  }

  ;----------------------------------------------------------------
  ;  GetSelectedSnippet – returns the text of the currently selected
  ;  entry (or an empty string if nothing is selected)
  ;----------------------------------------------------------------
  GetSelectedSnippet() {
    selected := this.lstBox.Value
    if (selected = "")
      return ""
    return SnippetManager.Snippets[selected]
  }

  ;----------------------------------------------------------------
  ;  CopyToClipboard – copies the selected snippet text to the clipboard
  ;----------------------------------------------------------------
  CopyToClipboard() {
    txt := this.GetSelectedSnippet()
    if (txt = "") {
      this.ShowTooltip("No snippet selected")
      return
    }
    A_Clipboard := txt
    this.ShowTooltip("Copied to clipboard")
  }

  ;----------------------------------------------------------------
  ;  SendToPrevWindow – sends the snippet to the window that was active
  ;  before the GUI opened (via simulated keystrokes)
  ;----------------------------------------------------------------
  SendToPrevWindow() {
    txt := this.GetSelectedSnippet()
    if (txt = "") {
      this.ShowTooltip("No snippet selected")
      return
    }
    ; Restore focus to the previous window
    if (WinExist("ahk_id " this.prevWinId))
      WinActivate("ahk_id " this.prevWinId)
    else {
      this.ShowTooltip("Previous window not found")
      return
    }
    ; Send the text (raw – no special characters interpreted)
    Send("{Raw}" txt)
    this.ShowTooltip("Sent to previous window")
  }

  ;----------------------------------------------------------------
  ;  ShowTooltip – displays a temporary tooltip near the mouse cursor.
  ;  The tooltip disappears after 1.5 seconds.
  ;----------------------------------------------------------------
  ShowTooltip(msg) {
    ; Cancel any previous hide‑timer
    if (this.tooltipTimer)
      SetTimer(this.tooltipTimer, "Off")
    ; Show the tooltip at the mouse position
    ToolTip(msg)   ; 1 = no title bar (modern style)
    ; Hide after 1500 ms
    this.tooltipTimer := SetTimer(() => ToolTip(), -1500)
  }
}

;================================================================
;  Script entry point – create a single manager instance
;================================================================
global manager := SnippetManager()