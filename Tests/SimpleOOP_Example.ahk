#Requires AutoHotkey v2.0
; Simple OOP Example demonstrating proper AHKv2 class instantiation

class SimpleConfig {
    ; Instance properties
    configPath := ""
    settings := Map()
    
    ; Constructor
    __New(path) {
        this.configPath := path
        this.settings["defaultTheme"] := "dark"
        this.settings["fontSize"] := 12
        this.settings["autoSave"] := true
    }
    
    ; Get setting with optional default value
    GetSetting(key, defaultValue := "") {
        return this.settings.Has(key) ? this.settings[key] : defaultValue
    }
    
    ; Update a setting
    SetSetting(key, value) {
        this.settings[key] := value
        return true
    }
    
    ; Display all settings
    DisplaySettings() {
        result := "Current Settings:`n"
        for key, value in this.settings
            result .= key ": " value "`n"
        return result
    }
}

; Main program
try {
    ; Create config object properly in AHK v2
    config := SimpleConfig("settings.ini")
    
    ; Display initial settings
    MsgBox(config.DisplaySettings())
    
    ; Update a setting
    config.SetSetting("fontSize", 14)
    
    ; Display updated settings
    MsgBox(config.DisplaySettings())
    
    ; Get a setting
    theme := config.GetSetting("defaultTheme")
    MsgBox("Current theme is: " theme)
} catch Error as e {
    MsgBox("Error: " e.Message)
}
