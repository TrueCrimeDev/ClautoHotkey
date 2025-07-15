#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

ModuleSelector()

class ModuleSelector {
    __New() {
        this.modulesPath := A_ScriptDir "\Modules"
        this.files := []
        this.gui := Gui("+Resize", "Module Content Merger")
        this.gui.SetFont("s10")
        this.gui.BackColor := 0x202020

        if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
            DWMWA_USE_IMMERSIVE_DARK_MODE := 19
            if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
                DWMWA_USE_IMMERSIVE_DARK_MODE := 20
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.hWnd,
                "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", true, "Int", 4)
        }

        this.gui.AddText("xm w400 cFFFFFF", "Select modules to include in clipboard:")
        this.listView := this.gui.AddListView("r10 w400 Checked -Hdr", ["Module Name"])
        this.ApplyDarkListView(this.listView)
        refreshBtn := this.CreateDarkButton("xm w90", "Refresh Files")
        refreshBtn.OnEvent("Click", this.LoadModules.Bind(this))

        selectAllBtn := this.CreateDarkButton("x+10 w90", "Select All")
        selectAllBtn.OnEvent("Click", this.SelectAll.Bind(this))

        clearAllBtn := this.CreateDarkButton("x+10 w90", "Clear All")
        clearAllBtn.OnEvent("Click", this.ClearAll.Bind(this))

        copyBtn := this.CreateDarkButton("x+10 w90 Default", "Copy")
        copyBtn.OnEvent("Click", this.CopyToClipboard.Bind(this))
        this.statusBar := this.gui.AddText("xm w400 h20 cFFFFFF vStatusBar", "Ready")
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())

        this.SetupHotkeys()
        this.LoadModules()
        this.gui.Show()
    }

    CreateDarkButton(options, text) {
        btn := this.gui.AddButton(options, text)
        btn.Opt("+Background202020")
        btn.SetFont("cFFFFFF")
        DllCall("uxtheme\SetWindowTheme", "Ptr", btn.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        return btn
    }

    ApplyDarkListView(lv) {
        static LVM_SETTEXTCOLOR := 0x1024
        static LVM_SETTEXTBKCOLOR := 0x1026
        static LVM_SETBKCOLOR := 0x1001
        SendMessage(LVM_SETTEXTCOLOR, 0, 0xFFFFFF, lv)
        SendMessage(LVM_SETTEXTBKCOLOR, 0, 0x202020, lv)
        SendMessage(LVM_SETBKCOLOR, 0, 0x202020, lv)
        lv.Opt("+Grid +LV0x10000")
        DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        DllCall("InvalidateRect", "Ptr", lv.Hwnd, "Ptr", 0, "Int", true)
        lv.ModifyCol(1, 400)
        return lv
    }

    SetupHotkeys() {
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("^Enter", this.CopyToClipboard.Bind(this))
        HotIfWinActive()
    }

    LoadModules(*) {
        try {
            this.files := []
            this.listView.Delete()

            Loop Files, this.modulesPath "\*.*" {
                if A_LoopFileExt != ""
                {
                    this.files.Push(Map(
                        "name", A_LoopFileName,
                        "path", A_LoopFileFullPath
                    ))
                    this.listView.Add(, A_LoopFileName)
                }
            }

            if this.files.Length = 0 {
                this.UpdateStatus("No files found in the Modules folder!")
            } else {
                this.UpdateStatus(this.files.Length " files loaded")
            }
        } catch as err {
            this.UpdateStatus("Error loading modules: " err.Message)
        }
    }

    SelectAll(*) {
        try {
            Loop this.listView.GetCount() {
                this.listView.Modify(A_Index, "Check")
            }
            this.UpdateStatus("All files selected")
        } catch as err {
            this.UpdateStatus("Error selecting all: " err.Message)
        }
    }

    ClearAll(*) {
        try {
            Loop this.listView.GetCount() {
                this.listView.Modify(A_Index, "-Check")
            }
            this.UpdateStatus("All selections cleared")
        } catch as err {
            this.UpdateStatus("Error clearing selection: " err.Message)
        }
    }

    CopyToClipboard(*) {
        try {
            selectedItems := []
            checkedRow := 0
            Loop {
                checkedRow := this.listView.GetNext(checkedRow, "Checked")
                if !checkedRow
                    break

                if checkedRow <= this.files.Length
                    selectedItems.Push(this.files[checkedRow])
            }

            if selectedItems.Length = 0 {
                this.UpdateStatus("No files selected!")
                return
            }
            try {
                combinedText := this.CombineFileContents(selectedItems)
                if (Type(combinedText) != "String" || combinedText == "") {
                    throw Error("Generated content is empty or invalid")
                }
                try {
                    A_Clipboard := combinedText
                    this.UpdateStatus("Content from " selectedItems.Length " file(s) copied to clipboard")
                } catch as clipErr {
                    this.UpdateStatus("Error setting clipboard: " clipErr.Message)
                }
            } catch as err {
                this.UpdateStatus("Error preparing content: " err.Message)
            }
        } catch as err {
            this.UpdateStatus("Error in copy operation: " err.Message)
        }
    }

    CombineFileContents(selectedItems) {
        local combinedText := ""
        local moduleBreak := "`r`n`r`n`r`n"
        for i, item in selectedItems {
            try {

                if !FileExist(item["path"]) {
                    combinedText .= "Error: File does not exist: " item["name"] "`n"
                    continue
                }
                fileContent := FileRead(item["path"])
                if (fileContent == "") {
                    fileContent := "(File is empty)"
                }
                local moduleName := ""
                try {
                    moduleName := RegExReplace(item["name"], "\.[^\.]+$", "")
                } catch {
                    moduleName := item["name"]
                }
                local tagName := ""
                try {
                    tagName := StrUpper(moduleName)
                } catch {
                    tagName := "MODULE"
                }
                local formattedContent := ""
                formattedContent .= "# " moduleName "`r`n`r`n"
                formattedContent .= "<" tagName ">`r`n`r`n"
                formattedContent .= fileContent
                formattedContent .= "`r`n`r`n</" tagName ">"
                combinedText .= formattedContent
                if i < selectedItems.Length {
                    combinedText .= moduleBreak
                }
            } catch as err {

                combinedText .= "Error reading file " item["name"] ": " err.Message "`n"
            }
        }
        return combinedText || "(No content available)"
    }

    UpdateStatus(message) {
        this.statusBar.Value := message
    }
}