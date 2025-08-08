#Requires AutoHotkey v2.0

class ConfigManager {
    _configMap := Map()
    _configPath := ""

    static _instance := ""

    __New(configPath) {
        this._configPath := configPath
        this._loadConfig()
    }

    static GetInstance(configPath := "") {
        if !this._instance {
            if configPath = ""
                throw ValueError("First call to GetInstance must provide a config path")

            this._instance := ConfigManager(configPath)
        }
        return this._instance
    }

    _loadConfig() {
        try {
            if FileExist(this._configPath) {
                fileContent := FileRead(this._configPath)

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
        } catch Error as err {
            MsgBox "Error loading configuration: " err.Message
            throw err
        }
    }

    SaveConfig() {
        try {
            fileContent := ""
            for key, value in this._configMap
                fileContent .= key "=" value "`n"

            FileOpen(this._configPath, "w").Write(fileContent).Close()
            return true
        } catch Error as err {
            MsgBox "Error saving configuration: " err.Message
            return false
        }
    }

    GetValue(key, defaultValue := "") {
        return this._configMap.Has(key) ? this._configMap[key] : defaultValue
    }

    SetValue(key, value) {
        this._configMap[key] := value
    }
}

class UserInterface {
    config := ""
    mainGui := ""
    controls := Map()

    __New(config) {
        this.config := config
        this._createGui()
    }

    _createGui() {
        this.mainGui := Gui(, "AHK v2 OOP Example")
        this.mainGui.SetFont("s10")
        this.mainGui.OnEvent("Close", this._handleExit.Bind(this))

        this.mainGui.AddText(, "Username:")
        this.controls["username"] := this.mainGui.AddEdit("vUsername w200", this.config.GetValue("username", ""))

        this.mainGui.AddText(, "API Key:")
        this.controls["apikey"] := this.mainGui.AddEdit("vApiKey w200", this.config.GetValue("apikey", ""))

        this.mainGui.AddText(, "Auto Login:")
        this.controls["autologin"] := this.mainGui.AddCheckbox("vAutoLogin", this.config.GetValue("autologin", "0"))

        saveBtn := this.mainGui.AddButton("w100", "Save")
        saveBtn.OnEvent("Click", this._saveSettings.Bind(this))

        testBtn := this.mainGui.AddButton("w100 x+10", "Test Connection")
        testBtn.OnEvent("Click", this._testConnection.Bind(this))
    }

    Show() {
        this.mainGui.Show()
    }

    _saveSettings(*) {
        try {
            this.config.SetValue("username", this.controls["username"].Value)
            this.config.SetValue("apikey", this.controls["apikey"].Value)
            this.config.SetValue("autologin", this.controls["autologin"].Value)

            if this.config.SaveConfig()
                MsgBox "Settings saved successfully."
            else
                MsgBox "Failed to save settings."
        } catch Error as err {
            MsgBox "Error saving settings: " err.Message
        }
    }

    _testConnection(*) {
        username := this.controls["username"].Value
        apikey := this.controls["apikey"].Value

        if username = "" || apikey = "" {
            MsgBox "Please enter both username and API key."
            return
        }

        MsgBox "Testing connection with:`nUsername: " username "`nAPI Key: " apikey
    }

    _handleExit(*) {
        result := MsgBox("Do you want to save settings before exiting?", "Confirm Exit", "YesNoCancel")

        if result = "Yes" {
            this._saveSettings()
            ExitApp()
        } else if result = "No" {
            ExitApp()
        }
        return true
    }
}

try {
    appDir := A_ScriptDir
    configPath := appDir "\config.ini"

    config := ConfigManager.GetInstance(configPath)

    ui := UserInterface(config)

    ui.Show()
} catch Error as err {
    MsgBox "Application initialization error: " err.Message "`n" err.Stack
    ExitApp()
}