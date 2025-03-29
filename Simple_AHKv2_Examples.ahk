#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

; This file contains simplified examples of AHK v2 best practices

;---------------------------
; INITIALIZATION SECTION
;---------------------------
SimpleGui()
SimpleTooltip()

;---------------------------
; SIMPLE GUI EXAMPLE
;---------------------------
class SimpleGui {
    static Config := Map(
        "title", "Simple GUI Example",
        "width", 300,
        "height", 200
    )
    
    __New() {
        ; Initialize GUI
        this.gui := Gui("+Resize", SimpleGui.Config["title"])
        this.gui.SetFont("s10")
        this.gui.MarginX := 10
        this.gui.MarginY := 10
        
        ; Add controls
        this.gui.AddText("w280", "Enter your name:")
        this.nameEdit := this.gui.AddEdit("w280 vUserName")
        
        ; Add buttons with proper event binding
        this.submitBtn := this.gui.AddButton("w120 y+10 Default", "Submit")
        this.submitBtn.OnEvent("Click", this.Submit.Bind(this))
        
        this.cancelBtn := this.gui.AddButton("w120 x+10", "Cancel")
        this.cancelBtn.OnEvent("Click", this.Cancel.Bind(this))
        
        ; Set up window events
        this.gui.OnEvent("Close", this.CloseWindow.Bind(this))
        this.gui.OnEvent("Escape", this.CloseWindow.Bind(this))
    }
    
    CloseWindow(*) {
        this.gui.Hide()
    }
    
    Show(*) {
        this.gui.Show("w" SimpleGui.Config["width"] " h" SimpleGui.Config["height"] " Center")
    }
    
    Submit(*) {
        formData := this.gui.Submit(false)
        
        if (formData.UserName = "") {
            MsgBox("Please enter your name")
            return
        }
        
        MsgBox("Hello, " formData.UserName "!")
    }
    
    Cancel(*) {
        this.nameEdit.Value := ""
        this.gui.Hide()
    }
}

;---------------------------
; SIMPLE TOOLTIP TIMER
;---------------------------
class SimpleTooltip {
    static Config := Map(
        "interval", 1000,
        "format", "Time running: {1} seconds"
    )
    
    __New() {
        this.running := false
        this.seconds := 0
        this.timerFunc := this.UpdateTooltip.Bind(this)
        
        ; Create a demo button to control the tooltip
        this.demoGui := Gui("+AlwaysOnTop", "Tooltip Demo")
        this.demoGui.SetFont("s10")
        
        this.btn := this.demoGui.AddButton("w200 h30", "Start Timer")
        this.btn.OnEvent("Click", this.ToggleTimer.Bind(this))
        
        this.demoGui.Show("Center")
    }
    
    ToggleTimer(*) {
        if (!this.running) {
            this.StartTimer()
            this.btn.Text := "Stop Timer"
        } else {
            this.StopTimer()
            this.btn.Text := "Start Timer"
        }
    }
    
    StartTimer() {
        this.seconds := 0
        SetTimer(this.timerFunc, SimpleTooltip.Config["interval"])
        this.running := true
        this.UpdateTooltip()
    }
    
    StopTimer() {
        SetTimer(this.timerFunc, 0)
        ToolTip()
        this.running := false
    }
    
    UpdateTooltip() {
        this.seconds++
        ToolTip(Format(SimpleTooltip.Config["format"], this.seconds))
    }
}

;---------------------------
; SIMPLE CONFIG MANAGER
;---------------------------
class SimpleConfig {
    static Defaults := Map(
        "theme", "light",
        "fontSize", 12,
        "autoSave", true
    )
    
    __New(configFile := A_ScriptDir "\config.ini") {
        this.configFile := configFile
        this.settings := this.LoadConfig()
    }
    
    LoadConfig() {
        settings := Map()
        
        ; Start with defaults
        for key, value in SimpleConfig.Defaults {
            settings[key] := value
        }
        
        ; Load from file if exists
        if FileExist(this.configFile) {
            for key, defaultValue in SimpleConfig.Defaults {
                if IsInteger(defaultValue) {
                    settings[key] := Integer(IniRead(this.configFile, "Settings", key, defaultValue))
                } else if (defaultValue = true || defaultValue = false) {
                    settings[key] := IniRead(this.configFile, "Settings", key, defaultValue ? "true" : "false") = "true"
                } else {
                    settings[key] := IniRead(this.configFile, "Settings", key, defaultValue)
                }
            }
        }
        
        return settings
    }
    
    SaveConfig() {
        for key, value in this.settings {
            if (value = true || value = false) {
                IniWrite(value ? "true" : "false", this.configFile, "Settings", key)
            } else {
                IniWrite(value, this.configFile, "Settings", key)
            }
        }
        return true
    }
    
    GetValue(key, defaultValue := "") {
        return this.settings.Has(key) ? this.settings[key] : defaultValue
    }
    
    SetValue(key, value) {
        this.settings[key] := value
        return this.SaveConfig()
    }
}

;---------------------------
; SIMPLE FILE HANDLER
;---------------------------
class SimpleFile {
    ReadFile(filePath) {
        if !FileExist(filePath) {
            return ""
        }
        
        try {
            return FileRead(filePath, "UTF-8")
        } catch {
            return ""
        }
    }
    
    WriteFile(filePath, content) {
        try {
            ; Create directory if it doesn't exist
            SplitPath(filePath, , &dirPath)
            if (dirPath && !DirExist(dirPath)) {
                DirCreate(dirPath)
            }
            
            ; Write file
            FileDelete(filePath)
            FileAppend(content, filePath, "UTF-8")
            return true
        } catch {
            return false
        }
    }
}

;---------------------------
; SIMPLE HOTKEY MANAGER
;---------------------------
class SimpleHotkeys {
    static Bindings := Map()
    
    __New() {
        ; Create a simple demo
        this.demoGui := Gui("+AlwaysOnTop", "Hotkey Demo")
        this.demoGui.SetFont("s10")
        this.demoGui.AddText("w200", "Press buttons to register hotkeys:")
        
        this.demoGui.AddButton("w200", "Register Ctrl+1").OnEvent("Click", this.RegisterHotkey1.Bind(this))
        this.demoGui.AddButton("w200", "Register Ctrl+2").OnEvent("Click", this.RegisterHotkey2.Bind(this))
        this.demoGui.AddButton("w200", "Unregister All").OnEvent("Click", this.UnregisterAll.Bind(this))
        
        this.demoGui.Show("Center")
    }
    
    RegisterHotkey1(*) {
        this.Register("^1", (*) => MsgBox("Hotkey Ctrl+1 was pressed!"))
    }
    
    RegisterHotkey2(*) {
        this.Register("^2", (*) => MsgBox("Hotkey Ctrl+2 was pressed!"))
    }
    
    Register(hotkeyString, callback) {
        try {
            Hotkey(hotkeyString, callback)
            SimpleHotkeys.Bindings[hotkeyString] := callback
            MsgBox("Registered: " hotkeyString)
            return true
        } catch as e {
            MsgBox("Failed to register: " e.Message)
            return false
        }
    }
    
    Unregister(hotkeyString) {
        if SimpleHotkeys.Bindings.Has(hotkeyString) {
            try {
                Hotkey(hotkeyString, "Off")
                SimpleHotkeys.Bindings.Delete(hotkeyString)
                return true
            } catch {
                return false
            }
        }
        return false
    }
    
    UnregisterAll(*) {
        for hotkeyString, callback in SimpleHotkeys.Bindings {
            this.Unregister(hotkeyString)
        }
        MsgBox("All hotkeys unregistered")
    }
}

; Main demo launcher
demoLauncher := Gui("+AlwaysOnTop", "AHK v2 Simple Examples")
demoLauncher.SetFont("s10")
demoLauncher.AddText("w300", "Click a button to run an example:")

btnGui := demoLauncher.AddButton("w300 h30", "Show Simple GUI Example")
btnGui.OnEvent("Click", ShowGuiExample)

btnHotkeys := demoLauncher.AddButton("w300 h30", "Show Hotkey Manager Example")
btnHotkeys.OnEvent("Click", ShowHotkeyExample)

btnTooltip := demoLauncher.AddButton("w300 h30", "Show Tooltip Timer Example")
btnTooltip.OnEvent("Click", ShowTooltipExample)

demoLauncher.Show("Center")

; Callback functions for demo launcher
ShowGuiExample(*) {
    SimpleGui().Show()
}

ShowHotkeyExample(*) {
    SimpleHotkeys()
}

ShowTooltipExample(*) {
    SimpleTooltip()
}
