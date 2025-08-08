#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

; Initialize class for our example
ExampleApplication()

class ExampleApplication {
    ; Static properties for app configuration
    static Config := Map(
        "appName", "AHKv2 Example Application",
        "version", "1.0.0",
        "theme", Map(
            "background", "White",
            "foreground", "202020",
            "accent", "#0078D7"
        )
    )

    ; Instance properties
    gui := ""
    controls := Map()

    ; Constructor
    __New() {
        ; Create and configure the GUI
        this.CreateGui()

        ; Set up hotkeys
        this.SetupHotkeys()

        ; Show the GUI
        this.gui.Show()
    }

    ; GUI creation method
    CreateGui() {
        ; Create the main GUI
        this.gui := Gui("+Resize", ExampleApplication.Config["appName"])
        this.gui.SetFont("s10")

        ; Set up events
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())

        ; Add controls
        this.gui.AddText("xm y10 w400", "Enter a message:")

        ; Store the edit control in our controls map
        this.controls["edit"] := this.gui.AddEdit("xm y30 w400 h100 vUserMessage")

        ; Add a button and bind the click event properly
        this.controls["btnSubmit"] := this.gui.AddButton("xm y140 w120", "Show Message")
        this.controls["btnSubmit"].OnEvent("Click", this.ShowMessage.Bind(this))

        ; Add a button to clear the input
        this.controls["btnClear"] := this.gui.AddButton("x+10 y140 w120", "Clear")
        this.controls["btnClear"].OnEvent("Click", this.ClearInput.Bind(this))

        ; Add a status bar
        this.controls["statusBar"] := this.gui.AddStatusBar()
        this.controls["statusBar"].SetText("Ready")
    }

    ; Event handler for the Show Message button
    ShowMessage(*) {
        ; Submit the form to get values from the controls
        submitted := this.gui.Submit(false)

        ; Check if message is empty
        if (submitted.UserMessage = "") {
            MsgBox("Please enter a message.", "Error", "Icon!")
            return
        }

        ; Show the message with proper quote escaping
        MsgBox("Your message: `"" submitted.UserMessage "`"", "Message", "Icon")

        ; Update status bar
        this.controls["statusBar"].SetText("Message displayed at " A_Now)
    }

    ; Event handler for the Clear button
    ClearInput(*) {
        ; Clear the edit control
        this.controls["edit"].Value := ""

        ; Update status bar
        this.controls["statusBar"].SetText("Input cleared")
    }

    ; Set up global hotkeys
    SetupHotkeys() {
        ; Toggle GUI visibility with Win+E
        Hotkey("#e", this.ToggleGui.Bind(this))

        ; Add hotkeys that only work when the GUI is active
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("^s", this.ShowMessage.Bind(this))     ; Ctrl+S shows the message
        Hotkey("^d", this.ClearInput.Bind(this))      ; Ctrl+D clears the input
        HotIf()
    }

    ; Toggle GUI visibility
    ToggleGui(*) {
        if WinExist("ahk_id " this.gui.Hwnd)
            this.gui.Hide()
        else
            this.gui.Show()
    }

    ; Destructor - clean up resources
    __Delete() {
        try {
            ; Clean up hotkeys
            Hotkey("#e", "Off")

            ; Destroy GUI if it exists
            if IsObject(this.gui)
                this.gui.Destroy()
        } catch Error as e {
            ; Log any errors during cleanup
            FileAppend "Cleanup error: " e.Message "`n", "error_log.txt"
        }
    }
}