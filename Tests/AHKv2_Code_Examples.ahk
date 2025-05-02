#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

; This file contains practical code examples demonstrating AHK v2 best practices
; These examples can be copied and adapted for your own scripts

;---------------------------
; INITIALIZATION SECTION
;---------------------------

; Initialize all classes at the top of your script
BasicGUI()
HotkeyManager()
ConfigManager()
FileHandler()
TooltipTimer()

;--------------------------------------
; EXAMPLE 1: BASIC GUI APPLICATION
;--------------------------------------

class BasicGUI {
    ; Static properties for configuration
    static Config := Map(
        "title", "Example Application",
        "width", 400,
        "height", 300,
        "font", "Segoe UI",
        "fontSize", 10
    )
    
    __New() {
        ; Initialize instance variables
        this.gui := Gui("Resize", BasicGUI.Config["title"])
        this.gui.SetFont("s" BasicGUI.Config["fontSize"], BasicGUI.Config["font"])
        this.gui.MarginX := 10
        this.gui.MarginY := 10
        
        ; Add controls
        this.gui.AddText("w" BasicGUI.Config["width"] - 20, "Enter your name:")
        this.nameEdit := this.gui.AddEdit("w" BasicGUI.Config["width"] - 20 " vUserName")
        
        this.gui.AddText("w" BasicGUI.Config["width"] - 20 " y+10", "Select an option:")
        this.optionsList := this.gui.AddDropDownList("w" BasicGUI.Config["width"] - 20 " vSelectedOption", ["Option 1", "Option 2", "Option 3"])
        
        ; Add buttons with proper event binding
        this.gui.AddButton("w120 y+15 Default", "Submit").OnEvent("Click", this.Submit.Bind(this))
        this.gui.AddButton("w120 x+10", "Cancel").OnEvent("Click", this.Cancel.Bind(this))
        
        ; Set up window events
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        
        ; Setup hotkeys
        this.SetupHotkeys()
    }
    
    SetupHotkeys() {
        ; Global hotkey to show the GUI
        HotKey("^F1", this.Show.Bind(this))
        
        ; Window-specific hotkeys (only active when GUI is visible)
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("^s", this.Submit.Bind(this), "On")
        HotIfWinActive()
    }
    
    Show(*) {
        ; Center the GUI on screen
        this.gui.Show("w" BasicGUI.Config["width"] " h" BasicGUI.Config["height"] " Center")
    }
    
    Submit(*) {
        ; Get and process form data
        formData := this.gui.Submit(false)  ; false = don't hide the GUI
        
        ; Validate data
        if formData.UserName = "" {
            MsgBox("Please enter your name.", BasicGUI.Config["title"], "Icon!")
            return
        }
        
        ; Display results
        resultText := "Name: " formData.UserName "`nSelection: " formData.SelectedOption
        MsgBox(resultText, "Form Submitted", "Icon!")
    }
    
    Cancel(*) {
        ; Reset form and hide GUI
        this.nameEdit.Value := ""
        this.optionsList.Choose(1)
        this.gui.Hide()
    }
}

;--------------------------------------
; EXAMPLE 2: HOTKEY MANAGER
;--------------------------------------

class HotkeyManager {
    ; Store registered hotkeys
    static Hotkeys := Map()
    
    ; Error messages
    static Errors := Map(
        "duplicate", "Hotkey already registered: {1}",
        "invalid", "Invalid hotkey: {1}",
        "not_found", "Hotkey not found: {1}"
    )
    
    __New() {
        ; Initialize state
        this.isEnabled := true
        this.tooltipEnabled := true
    }
    
    Register(hotkeyString, callback, options := "") {
        ; Validate inputs
        if !hotkeyString || !IsFunc(callback) && !IsObject(callback) {
            MsgBox(Format("Invalid hotkey or callback: {1}", hotkeyString))
            return false
        }
        
        try {
            ; Register the hotkey
            Hotkey(hotkeyString, callback, options)
            
            ; Store in our registry
            HotkeyManager.Hotkeys[hotkeyString] := Map(
                "callback", callback,
                "options", options,
                "enabled", true
            )
            
            return true
        } catch Error as e {
            MsgBox("Error registering hotkey: " e.Message)
            return false
        }
    }
    
    Unregister(hotkeyString) {
        if HotkeyManager.Hotkeys.Has(hotkeyString) {
            try {
                ; Disable the hotkey
                Hotkey(hotkeyString, "Off")
                
                ; Remove from registry
                HotkeyManager.Hotkeys.Delete(hotkeyString)
                return true
            } catch Error as e {
                MsgBox("Error unregistering hotkey: " e.Message)
                return false
            }
        }
        
        MsgBox(Format(HotkeyManager.Errors["not_found"], hotkeyString))
        return false
    }
    
    Enable(hotkeyString := "") {
        if hotkeyString = "" {
            ; Enable all hotkeys
            for key, data in HotkeyManager.Hotkeys {
                try {
                    Hotkey(key, "On")
                    HotkeyManager.Hotkeys[key]["enabled"] := true
                }
            }
            this.isEnabled := true
        } else if HotkeyManager.Hotkeys.Has(hotkeyString) {
            ; Enable specific hotkey
            try {
                Hotkey(hotkeyString, "On")
                HotkeyManager.Hotkeys[hotkeyString]["enabled"] := true
                return true
            } catch Error as e {
                MsgBox("Error enabling hotkey: " e.Message)
                return false
            }
        } else {
            MsgBox(Format(HotkeyManager.Errors["not_found"], hotkeyString))
            return false
        }
    }
    
    Disable(hotkeyString := "") {
        if hotkeyString = "" {
            ; Disable all hotkeys
            for key, data in HotkeyManager.Hotkeys {
                try {
                    Hotkey(key, "Off")
                    HotkeyManager.Hotkeys[key]["enabled"] := false
                }
            }
            this.isEnabled := false
        } else if HotkeyManager.Hotkeys.Has(hotkeyString) {
            ; Disable specific hotkey
            try {
                Hotkey(hotkeyString, "Off")
                HotkeyManager.Hotkeys[hotkeyString]["enabled"] := false
                return true
            } catch Error as e {
                MsgBox("Error disabling hotkey: " e.Message)
                return false
            }
        } else {
            MsgBox(Format(HotkeyManager.Errors["not_found"], hotkeyString))
            return false
        }
    }
    
    ShowTooltip(text, duration := 2000) {
        if this.tooltipEnabled {
            ToolTip(text)
            SetTimer(() => ToolTip(), -duration)
        }
    }
}

;--------------------------------------
; EXAMPLE 3: CONFIG MANAGER
;--------------------------------------

class ConfigManager {
    ; Default config
    static Defaults := Map(
        "app", Map(
            "name", "MyApp",
            "version", "1.0.0",
            "author", "AHK Developer"
        ),
        "ui", Map(
            "theme", "light",
            "fontSize", 10,
            "showToolbar", true
        ),
        "data", Map(
            "savePath", A_MyDocuments "\MyApp",
            "autoSave", true,
            "backups", 3
        )
    )
    
    __New(configFile := "") {
        ; Set config file path
        this.configFile := configFile || A_ScriptDir "\config.ini"
        this.config := this.LoadConfig()
    }
    
    LoadConfig() {
        config := Map()
        
        ; Start with defaults
        for section, values in ConfigManager.Defaults {
            config[section] := Map()
            for key, value in values {
                config[section][key] := value
            }
        }
        
        ; If config file exists, load saved values
        if FileExist(this.configFile) {
            try {
                for section, values in ConfigManager.Defaults {
                    for key, defaultValue in values {
                        ; Read the value, use appropriate type conversion
                        if IsInteger(defaultValue) {
                            value := Integer(IniRead(this.configFile, section, key, defaultValue))
                        } else if IsFloat(defaultValue) {
                            value := Float(IniRead(this.configFile, section, key, defaultValue))
                        } else if defaultValue = "true" || defaultValue = "false" {
                            value := IniRead(this.configFile, section, key, defaultValue) = "true"
                        } else {
                            value := IniRead(this.configFile, section, key, defaultValue)
                        }
                        
                        config[section][key] := value
                    }
                }
            } catch Error as e {
                MsgBox("Error loading config: " e.Message)
            }
        } else {
            ; Create the config file with defaults
            this.SaveConfig(config)
        }
        
        return config
    }
    
    SaveConfig(configToSave := "") {
        if configToSave = "" {
            configToSave := this.config
        }
        
        try {
            ; Ensure directory exists
            configDir := SubStr(this.configFile, 1, InStr(this.configFile, "\", , , 0) - 1)
            if !DirExist(configDir) {
                DirCreate(configDir)
            }
            
            ; Write each section
            for section, values in configToSave {
                for key, value in values {
                    ; Convert boolean to string
                    if IsType(value, "Integer") || IsType(value, "Float") || IsType(value, "String") {
                        IniWrite(value, this.configFile, section, key)
                    } else if IsType(value, "Bool") {
                        IniWrite(value ? "true" : "false", this.configFile, section, key)
                    }
                }
            }
            return true
        } catch Error as e {
            MsgBox("Error saving config: " e.Message)
            return false
        }
    }
    
    GetValue(section, key, defaultValue := "") {
        if this.config.Has(section) && this.config[section].Has(key) {
            return this.config[section][key]
        }
        return defaultValue
    }
    
    SetValue(section, key, value) {
        ; Ensure section exists
        if !this.config.Has(section) {
            this.config[section] := Map()
        }
        
        ; Set the value
        this.config[section][key] := value
        
        ; Auto-save if enabled
        if this.GetValue("data", "autoSave", true) {
            return this.SaveConfig()
        }
        return true
    }
    
    Reset() {
        ; Reset to defaults
        this.config := Map()
        
        for section, values in ConfigManager.Defaults {
            this.config[section] := Map()
            for key, value in values {
                this.config[section][key] := value
            }
        }
        
        return this.SaveConfig()
    }
}

;--------------------------------------
; EXAMPLE 4: FILE HANDLER
;--------------------------------------

class FileHandler {
    ; Error messages
    static ErrorMessages := Map(
        "file_not_found", "File not found: {1}",
        "permission", "Permission denied: {1}",
        "io_error", "I/O error: {1}",
        "invalid_path", "Invalid path: {1}",
        "exists", "File exists and overwrite is disabled"
    )
    
    __New() {
        ; Nothing to initialize
    }
    
    ; Creates a standardized result object
    CreateResult(success, content := "", errorCode := "", errorParam := "") {
        result := Map()
        result["success"] := success
        
        if (success && content != "")
            result["content"] := content
            
        if (!success && errorCode != "") {
            if (errorParam != "")
                result["error"] := Format(FileHandler.ErrorMessages[errorCode], errorParam)
            else
                result["error"] := FileHandler.ErrorMessages[errorCode]
        }
            
        return result
    }
    
    ReadTextFile(filePath) {
        ; Validate file exists
        if !FileExist(filePath)
            return this.CreateResult(false, "", "file_not_found", filePath)
        
        try {
            fileContent := FileRead(filePath, "UTF-8")
            return this.CreateResult(true, fileContent)
        } catch Error as e {
            return this.CreateResult(false, "", "io_error", e.Message)
        }
    }
    
    WriteTextFile(filePath, content, overwrite := true) {
        ; Check if file exists and overwrite flag
        if FileExist(filePath) && !overwrite
            return this.CreateResult(false, "", "exists")
        
        try {
            ; Ensure directory exists
            fileDir := SubStr(filePath, 1, InStr(filePath, "\", , , 0) - 1)
            if fileDir && !DirExist(fileDir)
                DirCreate(fileDir)
            
            ; Write the file
            FileDelete(filePath)
            FileAppend(content, filePath, "UTF-8")
            return this.CreateResult(true)
        } catch Error as e {
            return this.CreateResult(false, "", "io_error", e.Message)
        }
    }
    
    AppendTextFile(filePath, content) {
        try {
            ; Ensure directory exists
            fileDir := SubStr(filePath, 1, InStr(filePath, "\", , , 0) - 1)
            if fileDir && !DirExist(fileDir)
                DirCreate(fileDir)
            
            ; Append to the file
            FileAppend(content, filePath, "UTF-8")
            return this.CreateResult(true)
        } catch Error as e {
            return this.CreateResult(false, "", "io_error", e.Message)
        }
    }
    
    CopyFile(sourcePath, destPath, overwrite := true) {
        ; Validate source
        if !FileExist(sourcePath)
            return this.CreateResult(false, "", "file_not_found", sourcePath)
        
        try {
            ; Ensure destination directory exists
            destDir := SubStr(destPath, 1, InStr(destPath, "\", , , 0) - 1)
            if destDir && !DirExist(destDir)
                DirCreate(destDir)
            
            ; Copy the file
            FileCopy(sourcePath, destPath, overwrite)
            return this.CreateResult(true)
        } catch Error as e {
            return this.CreateResult(false, "", "io_error", e.Message)
        }
    }
    
    DeleteFile(filePath) {
        ; Validate file exists
        if !FileExist(filePath)
            return this.CreateResult(false, "", "file_not_found", filePath)
        
        try {
            FileDelete(filePath)
            return this.CreateResult(true)
        } catch Error as e {
            return this.CreateResult(false, "", "io_error", e.Message)
        }
    }
}

;--------------------------------------
; EXAMPLE 5: TOOLTIP TIMER
;--------------------------------------

class TooltipTimer {
    ; Configuration
    static Config := Map(
        "interval", 1000,
        "startDelay", 0,
        "initialText", "Timer started",
        "format", "Time elapsed: {1} seconds"
    )
    
    __New() {
        ; Initialize state
        this.state := Map(
            "seconds", 0,
            "isActive", false
        )
        
        ; Bind the callback
        this.timerCallback := this.UpdateDisplay.Bind(this)
    }
    
    Start() {
        if !this.state["isActive"] {
            ; Reset seconds and show initial tooltip
            this.state["seconds"] := 0
            ToolTip(TooltipTimer.Config["initialText"])
            
            ; Start the timer
            SetTimer(this.timerCallback, TooltipTimer.Config["interval"])
            this.state["isActive"] := true
        }
    }
    
    Stop() {
        if this.state["isActive"] {
            ; Stop the timer and clear tooltip
            SetTimer(this.timerCallback, 0)
            ToolTip()
            this.state["isActive"] := false
        }
    }
    
    UpdateDisplay() {
        ; Increment seconds and update tooltip
        this.state["seconds"]++
        ToolTip(Format(TooltipTimer.Config["format"], this.state["seconds"]))
    }
    
    ; Auto-cleanup when the object is destroyed
    __Delete() {
        this.Stop()
    }
}

;--------------------------------------
; EXAMPLE USAGE DEMO
;--------------------------------------

; Create a simple demo button
demoGui := Gui("+AlwaysOnTop", "AHK v2 Examples Demo")
demoGui.SetFont("s10")
demoGui.AddText("w300", "Click buttons to see examples in action:")

; Basic GUI demo
demoGui.AddButton("w300 h30", "Show Basic GUI Example").OnEvent("Click", (*) => BasicGUI().Show())

; Hotkey Management demo
hotkeyButton := demoGui.AddButton("w300 h30", "Register Ctrl+Shift+T Hotkey")
hotkeyButton.OnEvent("Click", (*) {
    static registered := false
    local hkm := HotkeyManager()
    
    if !registered {
        hkm.Register("^+t", (*) {
            hkm.ShowTooltip("Hotkey Triggered: Ctrl+Shift+T")
        })
        hotkeyButton.Text := "Unregister Ctrl+Shift+T Hotkey"
        registered := true
    } else {
        hkm.Unregister("^+t")
        hotkeyButton.Text := "Register Ctrl+Shift+T Hotkey"
        registered := false
    }
})

; Timer demo
timerButton := demoGui.AddButton("w300 h30", "Start Tooltip Timer")
timerButton.OnEvent("Click", (*) {
    static timer := TooltipTimer()
    static active := false
    
    if !active {
        timer.Start()
        timerButton.Text := "Stop Tooltip Timer"
        active := true
    } else {
        timer.Stop()
        timerButton.Text := "Start Tooltip Timer"
        active := false
    }
})

; File operations demo
demoGui.AddButton("w300 h30", "Write Sample File").OnEvent("Click", (*) {
    fh := FileHandler()
    result := fh.WriteTextFile(A_ScriptDir "\sample.txt", "This is a sample file created by AHK v2.`nTimestamp: " A_Now)
    if result["success"] {
        MsgBox("File created successfully!", "File Handler Demo")
    } else {
        MsgBox("Error: " result["error"], "File Handler Demo", "Icon!")
    }
})

; Show the demo UI
demoGui.Show()
