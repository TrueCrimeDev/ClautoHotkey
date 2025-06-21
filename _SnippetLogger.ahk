#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

ClipboardLogger()

class ClipboardLogger {
    static Config := Map(
        "SaveFolder", A_ScriptDir . "\AHK_Notes\Snippets",
        "MaxEntries", 100,
        "DefaultTitle", "Clipboard Logger"
    )
    
    __New() {
        this.entries := Map()
        this.selectedIndex := 0
        this.setupGui()
        this.loadExistingEntries()
    }
    
    setupGui() {
        this.gui := Gui("+Resize", ClipboardLogger.Config["DefaultTitle"])
        this.gui.SetFont("s10")
        
        this.listView := this.gui.AddListView("r15 w700 Grid", ["Date/Time", "Preview", "FileName"])
        this.listView.OnEvent("ItemSelect", this.onItemSelect.Bind(this))
        this.listView.OnEvent("DoubleClick", this.viewSelected.Bind(this))
        
        this.listView.ModifyCol(3, 0)
        this.listView.ModifyCol(1, 180)
        this.listView.ModifyCol(2, 500)
        
        this.gui.AddText("xm", "Add Note (Optional):")
        this.noteInput := this.gui.AddEdit("xm w700 r3")
        
        this.btnSave := this.gui.AddButton("xm w150", "Save Current Clipboard")
            .OnEvent("Click", this.saveClipboard.Bind(this))
        
        this.btnDelete := this.gui.AddButton("x+10 w150", "Delete Selected")
            .OnEvent("Click", this.deleteSelected.Bind(this))
        
        this.btnView := this.gui.AddButton("x+10 w150", "View Selected")
            .OnEvent("Click", this.viewSelected.Bind(this))
        
        this.statusText := this.gui.AddText("xm w700", "Ready")
        
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        Hotkey("^+c", this.Show.Bind(this))
        
        this.gui.Show()
    }
    
    Show(*) => this.gui.Show()
    
    getFullPath(filename) => ClipboardLogger.Config["SaveFolder"] . "\" . filename
    
    loadExistingEntries() {
        try {
            if !DirExist(ClipboardLogger.Config["SaveFolder"])
                DirCreate(ClipboardLogger.Config["SaveFolder"])
            
            loop Files, ClipboardLogger.Config["SaveFolder"] . "\*.txt" {
                filename := A_LoopFileName
                
                content := FileRead(this.getFullPath(filename))
                previewText := SubStr(content, 1, 50) . (StrLen(content) > 50 ? "..." : "")
                
                if RegExMatch(filename, "(\d{8})_(\d{6})", &match) {
                    dateStr := SubStr(match[1], 1, 4) . "-" . SubStr(match[1], 5, 2) . "-" . SubStr(match[1], 7, 2)
                    timeStr := SubStr(match[2], 1, 2) . ":" . SubStr(match[2], 3, 2) . ":" . SubStr(match[2], 5, 2)
                    dateTimeStr := dateStr . " " . timeStr
                } else {
                    dateTimeStr := "Unknown"
                }
                
                rowNum := this.listView.Add(, dateTimeStr, previewText, filename)
                this.entries[rowNum] := filename
            }
            
            this.listView.ModifyCol(1, "Sort Desc")
            this.statusText.Value := "Loaded " this.listView.GetCount() " entries"
        } catch Error as err {
            this.statusText.Value := "Error loading entries: " err.Message
        }
    }
    
    saveClipboard(*) {
        ; Using A_Clipboard (the built-in variable)
        clipContent := A_Clipboard
        
        if !clipContent {
            this.statusText.Value := "Clipboard is empty!"
            return
        }
        
        try {
            timestamp := FormatTime(, "yyyyMMdd_HHmmss")
            note := this.noteInput.Value
            filename := timestamp . ".txt"
            
            if !DirExist(ClipboardLogger.Config["SaveFolder"])
                DirCreate(ClipboardLogger.Config["SaveFolder"])
            
            FileAppend(clipContent . "`n`n--- NOTE ---`n" . note, this.getFullPath(filename))
            
            previewText := SubStr(clipContent, 1, 50) . (StrLen(clipContent) > 50 ? "..." : "")
            dateTimeStr := FormatTime(, "yyyy-MM-dd HH:mm:ss")
            rowNum := this.listView.Add(, dateTimeStr, previewText, filename)
            this.entries[rowNum] := filename
            
            this.listView.ModifyCol(1, "Sort Desc")
            this.noteInput.Value := ""
            this.statusText.Value := "Clipboard saved to: " filename
        } catch Error as err {
            this.statusText.Value := "Error saving clipboard: " err.Message
        }
    }
    
    onItemSelect(ctrl, rowNumber) {
        this.selectedIndex := rowNumber
    }
    
    deleteSelected(*) {
        if !this.selectedIndex {
            this.statusText.Value := "No item selected"
            return
        }
        
        try {
            filename := this.entries[this.selectedIndex]
            if MsgBox("Delete this entry?", "Confirm Delete", "YesNo") != "Yes"
                return
            
            FileDelete(this.getFullPath(filename))
            this.listView.Delete(this.selectedIndex)
            this.rebuildEntries()
            this.selectedIndex := 0
            this.statusText.Value := "Entry deleted: " filename
        } catch Error as err {
            this.statusText.Value := "Error deleting entry: " err.Message
        }
    }

    rebuildEntries() {
        newEntries := Map()
        Loop this.listView.GetCount() {
            idx := A_Index
            newEntries[idx] := this.listView.GetText(idx, 3)
        }
        this.entries := newEntries
    }
    
    viewSelected(*) {
        if !this.selectedIndex {
            this.statusText.Value := "No item selected"
            return
        }
        
        try {
            filename := this.entries[this.selectedIndex]
            content := FileRead(this.getFullPath(filename))
            
            viewerGui := Gui("+Resize", "Viewing: " filename)
            viewerGui.SetFont("s10")
            viewerGui.AddEdit("r20 w700 vContentEdit ReadOnly", content)
            
            viewerGui.AddButton("w100", "Copy All").OnEvent("Click", (*) {
                A_Clipboard := content
                MsgBox("Content copied to clipboard!", "Copied", "T2")
            })
            
            viewerGui.AddButton("x+10 w100 Default", "Close").OnEvent("Click", (*) => viewerGui.Destroy())
            viewerGui.OnEvent("Escape", (*) => viewerGui.Destroy())
            viewerGui.Show()
            
            this.statusText.Value := "Viewing entry: " filename
        } catch Error as err {
            this.statusText.Value := "Error viewing entry: " err.Message
        }
    }
}