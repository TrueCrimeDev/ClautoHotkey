#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

; This example demonstrates proper AHK v2 coding following .clinerules standards

; Initialize main application class
ExampleApp()

; Define main application class
class ExampleApp {
    ; Static configuration using Map (not object literals)
    static Config := Map(
        "title", "Example Application",
        "version", "1.0.0",
        "defaultWidth", 600,
        "defaultHeight", 400,
        "errorMessages", Map(
            "FILE_NOT_FOUND", "The specified file could not be found: {1}",
            "INVALID_INPUT", "Invalid input provided: {1}"
        )
    )
    
    ; Instance properties with proper initialization
    settings := Map()
    dataStorage := []
    
    ; Constructor
    __New() {
        ; Initialize instance properties
        this.settings := Map(
            "width", ExampleApp.Config["defaultWidth"],
            "height", ExampleApp.Config["defaultHeight"],
            "isDarkMode", true
        )
        
        ; Setup GUI with proper OOP construction
        this.InitializeGUI()
        
        ; Setup hotkeys
        this.SetupHotkeys()
        
        ; Show the interface
        this.Show()
    }
    
    ; GUI initialization with proper OOP patterns
    InitializeGUI() {
        ; Create GUI instance
        this.gui := Gui("+Resize", ExampleApp.Config["title"])
        this.gui.SetFont("s10")
        
        ; Add controls
        this.gui.AddText("w200", "Enter some text:")
        this.gui.AddEdit("w400 h100 vUserInput")
        
        ; Add buttons with proper event binding
        this.gui.AddButton("w100 Default", "Save").OnEvent("Click", this.SaveData.Bind(this))
        this.gui.AddButton("w100", "Clear").OnEvent("Click", this.ClearData.Bind(this))
        
        ; Add status bar
        this.statusBar := this.gui.AddStatusBar()
        this.statusBar.SetText("Ready")
        
        ; Set up GUI events with proper binding
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
    }
    
    ; Method for setting up hotkeys
    SetupHotkeys() {
        ; Use proper hotkey binding
        HotKey("^t", this.ToggleInterface.Bind(this))
        
        ; Context-sensitive hotkeys
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        HotKey("^s", this.SaveData.Bind(this))
        HotKey("^n", this.ClearData.Bind(this))
        HotIfWinActive()
    }
    
    ; Simple method for showing interface with arrow function
    Show(*) => this.gui.Show("w" this.settings["width"] " h" this.settings["height"])
    
    ; Toggle method with proper implementation
    ToggleInterface(*) {
        if WinExist("ahk_id " this.gui.Hwnd)
            this.gui.Hide()
        else
            this.Show()
    }
    
    ; Data operations with error handling
    SaveData(*) {
        try {
            ; Get data from GUI
            saved := this.gui.Submit(false)
            
            if (saved.UserInput == "") {
                MsgBox ExampleApp.Config["errorMessages"]["INVALID_INPUT"].Replace("{1}", "Empty input")
                return
            }
            
            ; Store in data array
            this.dataStorage.Push(Map(
                "text", saved.UserInput,
                "timestamp", A_Now
            ))
            
            this.statusBar.SetText("Data saved - " this.dataStorage.Length " entries")
        } catch Error as e {
            MsgBox "Error saving data: " e.Message
        }
    }
    
    ; Clear form data
    ClearData(*) {
        this.gui["UserInput"].Value := ""
        this.statusBar.SetText("Form cleared")
    }
    
    ; Property accessor demonstrating arrow syntax
    totalEntries {
        get => this.dataStorage.Length
    }
    
    ; Cleanup method
    __Delete() {
        ; Clean up resources as needed
        this.dataStorage := []
    }
}
