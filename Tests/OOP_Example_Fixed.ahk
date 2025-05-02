#Requires AutoHotkey v2.0
; OOP Example demonstrating proper AHKv2 coding standards

class ConfigManager {
    ; Private properties
    _configMap := Map()
    _configPath := ""
    
    ; Singleton instance
    static _instance := ""
    
    ; Constructor
    __New(configPath) {
        this._configPath := configPath
        this._loadConfig()
    }
    
    ; Public static method to get instance
    static GetInstance(configPath := "") {
        if !this._instance {
            if configPath = ""
                throw ValueError("First call to GetInstance must provide a config path")
            
            this._instance := {}  ; Create empty object first
            this.Prototype.__Init(this._instance, configPath)  ; Then initialize it
        }
        return this._instance
    }
    
    ; Load configuration from file
    _loadConfig() {
        try {
            if FileExist(this._configPath) {
                fileContent := FileRead(this._configPath)
                
                ; Parse config lines
                Loop Parse, fileContent, "`n", "`r" {
                    if A_LoopField = "" || SubStr(A_LoopField, 1, 1) = ";"
                        continue
                    
                    if InStr(A_LoopField, "=") {
                        parts := StrSplit(A_LoopField, "=", , 2)
                        key := Trim(parts[1])
                        value := Trim(parts[2])
                        this._configMap[key] := value
                    }
                }
            }
        } catch Error as e {
            MsgBox "Error loading configuration: " e.Message
            throw e
        }
    }
    
    ; Save configuration to file
    SaveConfig() {
        try {
            fileContent := ""
            for key, value in this._configMap
                fileContent .= key "=" value "`n"
            
            FileOpen(this._configPath, "w").Write(fileContent).Close()
            return true
        } catch Error as e {
            MsgBox "Error saving configuration: " e.Message
            return false
        }
    }
    
    ; Get a configuration value
    GetValue(key, defaultValue := "") {
        return this._configMap.Has(key) ? this._configMap[key] : defaultValue
    }
    
    ; Set a configuration value
    SetValue(key, value) {
        this._configMap[key] := value
    }
}

class UserInterface {
    ; Properties
    config := ""
    mainGui := ""
    controls := Map()
    
    ; Constructor
    __New(config) {
        this.config := config
        this._createGui()
    }
    
    ; Create the GUI
    _createGui() {
        ; Create the main window
        this.mainGui := Gui(, "AHK v2 OOP Example")
        this.mainGui.SetFont("s10")
        this.mainGui.OnEvent("Close", (*) => this._handleExit())
        
        ; Add controls
        this.mainGui.AddText(, "Username:")
        this.controls["username"] := this.mainGui.AddEdit("vUsername w200", this.config.GetValue("username", ""))
        
        this.mainGui.AddText(, "API Key:")
        this.controls["apikey"] := this.mainGui.AddEdit("vApiKey w200", this.config.GetValue("apikey", ""))
        
        this.mainGui.AddText(, "Auto Login:")
        this.controls["autologin"] := this.mainGui.AddCheckbox("vAutoLogin", this.config.GetValue("autologin", "0"))
        
        ; Add buttons with bound event handlers
        saveBtn := this.mainGui.AddButton("w100", "Save")
        saveBtn.OnEvent("Click", (*) => this._saveSettings())
        
        testBtn := this.mainGui.AddButton("w100 x+10", "Test Connection")
        testBtn.OnEvent("Click", (*) => this._testConnection())
    }
    
    ; Show the GUI
    Show() {
        this.mainGui.Show()
    }
    
    ; Save settings handler
    _saveSettings() {
        try {
            this.config.SetValue("username", this.controls["username"].Value)
            this.config.SetValue("apikey", this.controls["apikey"].Value)
            this.config.SetValue("autologin", this.controls["autologin"].Value)
            
            if this.config.SaveConfig()
                MsgBox "Settings saved successfully."
            else
                MsgBox "Failed to save settings."
        } catch Error as e {
            MsgBox "Error saving settings: " e.Message
        }
    }
    
    ; Test connection handler
    _testConnection() {
        username := this.controls["username"].Value
        apikey := this.controls["apikey"].Value
        
        if username = "" || apikey = "" {
            MsgBox "Please enter both username and API key."
            return
        }
        
        ; Simulate API call
        MsgBox "Testing connection with:`nUsername: " username "`nAPI Key: " apikey
    }
    
    ; Handle exit
    _handleExit() {
        result := MsgBox("Do you want to save settings before exiting?", "Confirm Exit", "YesNoCancel")
        
        if result = "Yes" {
            this._saveSettings()
            ExitApp
        } else if result = "No" {
            ExitApp
        }
        return 1  ; Prevent window from closing if Cancel
    }
}

; Initialize application
try {
    ; Determine script directory for config path
    appDir := A_ScriptDir
    configPath := appDir "\config.ini"
    
    ; Get configuration manager instance
    configManager := ConfigManager.GetInstance(configPath)
    
    ; Create UI properly - first create the empty object
    ui := {}
    
    ; Then initialize it
    UserInterface.Prototype.__Init(ui, configManager)
    
    ; Show the UI
    ui.Show()
} catch Error as e {
    MsgBox "Application initialization error: " e.Message "`n" e.Stack
    ExitApp
}
