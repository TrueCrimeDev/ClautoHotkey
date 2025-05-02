<ahk_components>
  <gui_framework>
    <gui_class_template>

```cpp
SimpleGui()
class SimpleGui {
  __New() {
      this.gui := Gui()
      this.gui.SetFont("s10")
      this.gui.OnEvent("Close", (*) => this.gui.Hide())
      this.gui.OnEvent("Escape", (*) => this.gui.Hide())
      this.gui.AddEdit("vUserInput w200")
      this.gui.AddButton("Default w200", "Submit").OnEvent("Click", this.Submit.Bind(this))
      this.SetupHotkeys()
  }
  Submit(*) {
      saved := this.gui.Submit()
      MsgBox(saved.UserInput)
      this.gui.Hide()
  }
  Toggle(*) {
      if WinExist("ahk_id " this.gui.Hwnd)
          this.gui.Hide()
      else
          this.gui.Show()
  }
  SetupHotkeys() {
      HotKey("^m", this.Toggle.Bind(this))
      HotIfWinExist("ahk_id " this.gui.Hwnd)
      Hotkey("^Escape", this.Toggle.Bind(this), "On")
      HotIfWinExist()
  }
}
```
    </gui_class_template>
    
    <controls>
```cpp
; Valid GUI control methods in AHK v2
myGui := Gui("+Resize", "Control Examples")

; Text control
myGui.AddText("w200", "This is a text label")

; Edit control - for user text input
myGui.AddEdit("vUserInput w200 h60", "Default text")

; Button control
myGui.AddButton("w200", "Click Me").OnEvent("Click", OnButtonClick)

; Dropdown list
myGui.AddDropDownList("vSelectedItem w200", ["Option 1", "Option 2", "Option 3"])

; List box
myGui.AddListBox("vListSelection w200 h100", ["Item 1", "Item 2", "Item 3"])

; Checkbox
myGui.AddCheckbox("vIsEnabled", "Enable feature")

; Radio buttons in a group
myGui.AddRadio("vRadioOption", "Option A")
myGui.AddRadio("", "Option B")
myGui.AddRadio("", "Option C")

; Progress bar
myGui.AddProgress("vProgressBar w200 h20", 50)

; Event binding for button
OnButtonClick(*) {
    MsgBox "Button clicked!"
}
```
    </controls>
    
    <event_handling>
```cpp
#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

EventDemo()
class EventDemo {
    __New() {
        this.gui := Gui("+Resize", "Event Handling Demo")
        this.gui.SetFont("s10")
        
        ; Add controls with event handling
        this.gui.AddText("", "Enter some text:")
        this.editBox := this.gui.AddEdit("vUserInput w300")
        
        ; Button with explicitly bound callback method
        this.gui.AddButton("Default w100", "Submit")
            .OnEvent("Click", this.OnSubmit.Bind(this))
        
        ; Button with arrow function for simple actions
        this.gui.AddButton("w100", "Clear")
            .OnEvent("Click", (*) => this.editBox.Value := "")
        
        ; Window events
        this.gui.OnEvent("Close", this.OnClose.Bind(this))
        this.gui.OnEvent("Escape", this.OnClose.Bind(this))
        this.gui.OnEvent("Size", this.OnResize.Bind(this))
        
        ; Show the GUI
        this.gui.Show()
    }
    
    OnSubmit(*) {
        saved := this.gui.Submit(false)  ; false to keep GUI visible
        MsgBox("You entered: " saved.UserInput)
    }
    
    OnClose(*) {
        this.gui.Hide()
    }
    
    OnResize(gui, minMax, width, height) {
        ; Resize controls based on new dimensions
        if (minMax != -1) {  ; -1 means window was minimized
            this.editBox.Move(, , width - 20)  ; Adjust width based on window size
        }
    }
}
```
    </event_handling>
    
    <layout>
```cpp
#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

LayoutDemo()
class LayoutDemo {
    __New() {
        this.gui := Gui("+Resize", "Layout Example")
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        
        ; Basic positional layout (x, y coordinates)
        this.gui.AddText("x10 y10", "Name:")
        this.gui.AddEdit("x100 y10 w200", "")
        
        ; Relative positioning with x+n, y+n
        this.gui.AddText("x10 y+20", "Email:")  ; 20 pixels below previous control
        this.gui.AddEdit("x100 y+0 w200", "")   ; Same y as previous control
        
        ; Width and height parameters
        this.gui.AddText("x10 y+20", "Comments:")
        this.gui.AddEdit("x10 y+5 w290 h100", "")  ; Wide and tall edit control
        
        ; Grouping with sections
        this.gui.AddGroupBox("x10 y+20 w290 h100", "Options")
        this.gui.AddCheckbox("x20 y+10", "Enable feature 1")
        this.gui.AddCheckbox("x20 y+10", "Enable feature 2")
        this.gui.AddCheckbox("x20 y+10", "Enable feature 3")
        
        ; Right-aligned controls
        this.gui.AddButton("x200 y+30 w100", "Cancel").OnEvent("Click", (*) => this.gui.Hide())
        this.gui.AddButton("x+10 w100", "OK").OnEvent("Click", (*) => this.gui.Hide())
        
        this.gui.Show()
    }
}
```
    </layout>
  </gui_framework>

  <advanced_components>
    <hotkey_manager>
```cpp
#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

HotkeyManager()
class HotkeyManager {
    static Config := Map(
        "copyText", "^c",
        "pasteText", "^v",
        "customAction", "^+z",
        "toggleApp", "!t"
    )
    
    __New() {
        this.active := true
        this.SetupHotkeys()
    }
    
    SetupHotkeys() {
        ; Register all hotkeys from config
        Hotkey(HotkeyManager.Config["copyText"], this.CopyEnhanced.Bind(this))
        Hotkey(HotkeyManager.Config["pasteText"], this.PasteEnhanced.Bind(this))
        Hotkey(HotkeyManager.Config["customAction"], this.CustomAction.Bind(this))
        Hotkey(HotkeyManager.Config["toggleApp"], this.ToggleActive.Bind(this))
    }
    
    CopyEnhanced(*) {
        if (!this.active)
            return
            
        ; Send native copy command
        Send("^c")
        Sleep(50)  ; Give system time to process
        
        ; Get text from clipboard and enhance it
        clipText := A_Clipboard
        if (clipText = "")
            return
            
        ; Example enhancement: trim whitespace
        A_Clipboard := Trim(clipText)
        ToolTip("Enhanced copy: Whitespace trimmed")
        SetTimer(() => ToolTip(), -2000)  ; Clear tooltip after 2 seconds
    }
    
    PasteEnhanced(*) {
        if (!this.active)
            return
            
        ; Example enhancement: paste without formatting
        clipText := A_Clipboard
        if (clipText = "")
            return
            
        ; Send raw text instead of clipboard paste to avoid formatting
        SendText(clipText)
    }
    
    CustomAction(*) {
        if (!this.active)
            return
            
        MsgBox("Custom action triggered")
    }
    
    ToggleActive(*) {
        this.active := !this.active
        state := this.active ? "enabled" : "disabled"
        ToolTip("Hotkey enhancements " state)
        SetTimer(() => ToolTip(), -2000)
    }
}
```
    </hotkey_manager>
    
    <file_operations>
```cpp
#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

FileManager()
class FileManager {
    static Config := Map(
        "defaultDir", A_ScriptDir,
        "backupDir", A_ScriptDir "\Backup",
        "logFile", A_ScriptDir "\log.txt"
    )
    
    __New() {
        ; Ensure backup directory exists
        if !DirExist(FileManager.Config["backupDir"])
            DirCreate(FileManager.Config["backupDir"])
            
        ; Initialize log file
        this.LogMessage("FileManager initialized")
    }
    
    ReadTextFile(filePath) {
        if (!FileExist(filePath))
            throw Error("File not found: " filePath)
            
        try {
            return FileRead(filePath)
        } catch as err {
            this.LogMessage("Error reading file: " err.Message)
            return ""
        }
    }
    
    WriteTextFile(filePath, content) {
        try {
            FileDelete(filePath)
            FileAppend(content, filePath)
            return true
        } catch as err {
            this.LogMessage("Error writing file: " err.Message)
            return false
        }
    }
    
    BackupFile(filePath) {
        if (!FileExist(filePath))
            return false
            
        ; Extract filename from path
        SplitPath(filePath, &fileName)
        
        ; Create backup filename with timestamp
        timestamp := FormatTime(, "yyyyMMdd_HHmmss")
        backupFile := FileManager.Config["backupDir"] "\" fileName "_" timestamp
        
        try {
            FileCopy(filePath, backupFile)
            this.LogMessage("Backed up: " filePath " to " backupFile)
            return true
        } catch as err {
            this.LogMessage("Backup failed: " err.Message)
            return false
        }
    }
    
    LogMessage(message) {
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        logEntry := timestamp ": " message "`n"
        
        try {
            FileAppend(logEntry, FileManager.Config["logFile"])
        } catch {
            ; Silent failure for logging
        }
    }
}
```
    </file_operations>
    
    <api_integration>
```cpp
#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

ApiClient()
class ApiClient {
    static Config := Map(
        "baseUrl", "https://api.example.com",
        "timeout", 30000,
        "userAgent", "AutoHotkey/2.0 ApiClient/1.0"
    )
    
    __New(apiKey := "") {
        this.headers := Map(
            "Content-Type", "application/json",
            "User-Agent", ApiClient.Config["userAgent"]
        )
        
        if (apiKey != "")
            this.headers["Authorization"] := "Bearer " apiKey
    }
    
    Get(endpoint, params := "") {
        url := this.BuildUrl(endpoint, params)
        return this.SendRequest("GET", url)
    }
    
    Post(endpoint, data) {
        url := this.BuildUrl(endpoint)
        return this.SendRequest("POST", url, data)
    }
    
    Put(endpoint, data) {
        url := this.BuildUrl(endpoint)
        return this.SendRequest("PUT", url, data)
    }
    
    Delete(endpoint) {
        url := this.BuildUrl(endpoint)
        return this.SendRequest("DELETE", url)
    }
    
    BuildUrl(endpoint, params := "") {
        url := ApiClient.Config["baseUrl"] endpoint
        
        if (params != "") {
            url .= "?"
            if (Type(params) = "Map") {
                for key, value in params
                    url .= key "=" value "&"
                url := RTrim(url, "&")
            } else {
                url .= params
            }
        }
        
        return url
    }
    
    SendRequest(method, url, data := "") {
        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open(method, url, true)
            whr.SetTimeouts(10000, 10000, 10000, ApiClient.Config["timeout"])
            
            ; Set headers
            for header, value in this.headers
                whr.SetRequestHeader(header, value)
            
            ; Send the request
            if (method = "POST" || method = "PUT") && (data != "") {
                jsonData := data is Map ? this.MapToJson(data) : data
                whr.Send(jsonData)
            } else {
                whr.Send()
            }
            
            ; Wait for the response
            whr.WaitForResponse()
            
            ; Parse response
            status := whr.Status
            responseText := whr.ResponseText
            
            return Map(
                "status", status,
                "ok", status >= 200 && status < 300,
                "data", this.ParseJson(responseText)
            )
            
        } catch as err {
            return Map(
                "status", 0,
                "ok", false,
                "error", err.Message
            )
        }
    }
    
    ParseJson(jsonString) {
        try {
            ; Basic JSON parsing (in real app, use a proper JSON library)
            parsed := this.JsonToMap(jsonString)
            return parsed
        } catch {
            return jsonString
        }
    }
    
    MapToJson(map) {
        if !(map is Map)
            return ""
            
        json := "{"
        for key, value in map {
            json .= '"' key '": '
            
            if (value is String)
                json .= '"' value '"'
            else if (value is Integer || value is Float)
                json .= value
            else if (value is Map)
                json .= this.MapToJson(value)
            else if (value is Array)
                json .= this.ArrayToJson(value)
            else if (value = true)
                json .= "true"
            else if (value = false)
                json .= "false"
            else if (value = "")
                json .= "null"
                
            json .= ", "
        }
        
        json := RTrim(json, ", ") "}"
        return json
    }
    
    ArrayToJson(array) {
        if !(array is Array)
            return "[]"
            
        json := "["
        for value in array {
            if (value is String)
                json .= '"' value '"'
            else if (value is Integer || value is Float)
                json .= value
            else if (value is Map)
                json .= this.MapToJson(value)
            else if (value is Array)
                json .= this.ArrayToJson(value)
            else if (value = true)
                json .= "true"
            else if (value = false)
                json .= "false"
            else if (value = "")
                json .= "null"
                
            json .= ", "
        }
        
        json := RTrim(json, ", ") "]"
        return json
    }
    
    JsonToMap(jsonString) {
        ; This is a placeholder - in a real application, use a proper JSON library
        ; Simple JSON parsing isn't easily done in pure AHK
        ; This method would implement parsing JSON to Map objects
        return Map("warning", "JSON parsing requires external library")
    }
}
```
    </api_integration>
  </advanced_components>

  <practical_examples>
    <notes_app>
    
```cpp
#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

NotesApp()
class NotesApp {
    static Config := Map(
        "appName", "Simple Notes",
        "saveDir", A_ScriptDir "\Notes",
        "fileExt", ".txt"
    )
    
    __New() {
        ; Initialize storage
        this.notes := Map()
        this.currentNoteTitle := ""
        
        ; Create save directory if it doesn't exist
        if !DirExist(NotesApp.Config["saveDir"])
            DirCreate(NotesApp.Config["saveDir"])
            
        ; Load existing notes
        this.LoadNotes()
        
        ; Create the GUI
        this.CreateGui()
    }
    
    CreateGui() {
        ; Main window
        this.gui := Gui("+Resize", NotesApp.Config["appName"])
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        
        ; Add menu
        this.CreateMenu()
        
        ; Note selection sidebar
        this.gui.AddText("x10 y10", "Your Notes:")
        this.notesList := this.gui.AddListBox("x10 y30 w150 h300 vNotesList")
        this.notesList.OnEvent("Change", this.OnNoteSelect.Bind(this))
        
        ; Add note button
        this.gui.AddButton("x10 y+10 w150", "New Note").OnEvent("Click", this.OnNewNote.Bind(this))
        
        ; Note content area
        this.gui.AddText("x170 y10", "Title:")
        this.titleEdit := this.gui.AddEdit("x210 y10 w400 vNoteTitle")
        
        this.gui.AddText("x170 y+10", "Content:")
        this.contentEdit := this.gui.AddEdit("x170 y+5 w400 h290 vNoteContent Multi")
        
        ; Save and delete buttons
        this.gui.AddButton("x170 y+10 w100", "Save").OnEvent("Click", this.OnSave.Bind(this))
        this.gui.AddButton("x+20 w100", "Delete").OnEvent("Click", this.OnDelete.Bind(this))
        
        ; Populate note list
        this.RefreshNotesList()
        
        ; Setup hotkeys
        this.SetupHotkeys()
        
        ; Show GUI
        this.gui.Show("w600 h400")
    }
    
    CreateMenu() {
        noteMenu := Menu()
        noteMenu.Add("New Note", this.OnNewNote.Bind(this))
        noteMenu.Add("Save", this.OnSave.Bind(this))
        noteMenu.Add() ; Separator
        noteMenu.Add("Exit", (*) => ExitApp())
        
        helpMenu := Menu()
        helpMenu.Add("About", (*) => MsgBox("Simple Notes App`nCreated with AutoHotkey v2"))
        
        mainMenu := MenuBar()
        mainMenu.Add("&File", noteMenu)
        mainMenu.Add("&Help", helpMenu)
        
        this.gui.MenuBar := mainMenu
    }
    
    SetupHotkeys() {
        ; Global hotkey to show the app
        Hotkey("^!n", this.Show.Bind(this))
        
        ; Window-specific hotkeys
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("^s", this.OnSave.Bind(this))
        Hotkey("^n", this.OnNewNote.Bind(this))
        Hotkey("Delete", this.OnDelete.Bind(this))
        HotIfWinActive()
    }
    
    Show(*) {
        this.gui.Show()
        this.gui.Maximize()
    }
    
    LoadNotes() {
        ; Clear existing notes
        this.notes := Map()
        
        ; Get all note files
        files := ""
        Loop Files, NotesApp.Config["saveDir"] "\*" NotesApp.Config["fileExt"] {
            ; Extract note title from filename
            SplitPath(A_LoopFilePath, , , , &title)
            
            ; Read note content
            content := FileRead(A_LoopFilePath)
            
            ; Add to notes map
            this.notes[title] := content
        }
    }
    
    RefreshNotesList() {
        ; Clear the current list
        this.notesList.Delete()
        
        ; Add all note titles to the list
        noteItems := []
        for title, content in this.notes
            noteItems.Push(title)
        
        ; Sort alphabetically
        noteItems := this.SortArray(noteItems)
        
        ; Add to listbox
        for index, title in noteItems
            this.notesList.Add([title])
    }
    
    SortArray(array) {
        ; Simple bubble sort
        for i in array.Length {
            for j in array.Length - i {
                if (array[j] > array[j + 1]) {
                    temp := array[j]
                    array[j] := array[j + 1]
                    array[j + 1] := temp
                }
            }
        }
        return array
    }
    
    OnNoteSelect(*) {
        selected := this.notesList.Text
        if (selected != "") {
            this.currentNoteTitle := selected
            this.titleEdit.Value := selected
            this.contentEdit.Value := this.notes[selected]
        }
    }
    
    OnNewNote(*) {
        ; Clear input fields
        this.currentNoteTitle := ""
        this.titleEdit.Value := ""
        this.contentEdit.Value := ""
        this.titleEdit.Focus()
    }
    
    OnSave(*) {
        ; Get values from controls
        saved := this.gui.Submit(false)
        title := saved.NoteTitle
        content := saved.NoteContent
        
        ; Validate title
        if (title = "") {
            MsgBox("Please enter a title for your note.")
            return
        }
        
        ; Handle renamed notes
        if (this.currentNoteTitle != "" && this.currentNoteTitle != title) {
            ; Delete old file if it exists
            oldFile := NotesApp.Config["saveDir"] "\" this.currentNoteTitle NotesApp.Config["fileExt"]
            if FileExist(oldFile)
                FileDelete(oldFile)
            
            ; Remove from map
            this.notes.Delete(this.currentNoteTitle)
        }
        
        ; Save note to file
        filePath := NotesApp.Config["saveDir"] "\" title NotesApp.Config["fileExt"]
        try {
            FileDelete(filePath)
            FileAppend(content, filePath)
            
            ; Update in-memory notes
            this.notes[title] := content
            this.currentNoteTitle := title
            
            ; Refresh list
            this.RefreshNotesList()
            
            ; Show success message
            ToolTip("Note saved")
            SetTimer(() => ToolTip(), -2000)
            
        } catch as err {
            MsgBox("Error saving note: " err.Message)
        }
    }
    
    OnDelete(*) {
        if (this.currentNoteTitle = "")
            return
            
        ; Ask for confirmation
        result := MsgBox("Are you sure you want to delete this note?", "Delete Note", "YesNo")
        if (result != "Yes")
            return
            
        ; Delete file
        filePath := NotesApp.Config["saveDir"] "\" this.currentNoteTitle NotesApp.Config["fileExt"]
        if FileExist(filePath)
            FileDelete(filePath)
            
        ; Remove from map
        this.notes.Delete(this.currentNoteTitle)
        
        ; Clear fields
        this.currentNoteTitle := ""
        this.titleEdit.Value := ""
        this.contentEdit.Value := ""
        
        ; Refresh list
        this.RefreshNotesList()
        
        ; Show success message
        ToolTip("Note deleted")
        SetTimer(() => ToolTip(), -2000)
    }
}
```
    </notes_app>
    
    <text_processor>

```cpp
#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

TextProcessor()
class TextProcessor {
    static Config := Map(
        "maxHistory", 10,
        "defaultCaseSensitive", false
    )
    
    __New() {
        ; Initialize properties
        this.history := []
        this.caseSensitive := TextProcessor.Config["defaultCaseSensitive"]
        
        ; Create GUI
        this.CreateGui()
    }
    
    CreateGui() {
        this.gui := Gui("+Resize", "Text Processor")
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        
        ; Input area
        this.gui.AddText("x10 y10 w100", "Input Text:")
        this.inputEdit := this.gui.AddEdit("x10 y30 w600 h150 vInputText Multi")
        
        ; Options group
        this.gui.AddGroupBox("x10 y190 w600 h90", "Processing Options")
        
        ; Case sensitive option
        this.caseSensitiveCheck := this.gui.AddCheckbox("x20 y210 vCaseSensitive", "Case Sensitive")
        this.caseSensitiveCheck.Value := this.caseSensitive
        
        ; Operation buttons
        this.gui.AddButton("x20 y240 w100", "Uppercase").OnEvent("Click", this.OnUppercase.Bind(this))
        this.gui.AddButton("x130 y240 w100", "Lowercase").OnEvent("Click", this.OnLowercase.Bind(this))
        this.gui.AddButton("x240 y240 w100", "Title Case").OnEvent("Click", this.OnTitleCase.Bind(this))
        this.gui.AddButton("x350 y240 w100", "Remove Spaces").OnEvent("Click", this.OnRemoveSpaces.Bind(this))
        this.gui.AddButton("x460 y240 w100", "Line Sort").OnEvent("Click", this.OnLineSort.Bind(this))
        
        ; Find/Replace area
        this.gui.AddText("x10 y290 w100", "Find:")
        this.findEdit := this.gui.AddEdit("x120 y290 w200 vFindText")
        
        this.gui.AddText("x10 y320 w100", "Replace:")
        this.replaceEdit := this.gui.AddEdit("x120 y320 w200 vReplaceText")
        
        this.gui.AddButton("x330 y320 w100", "Replace").OnEvent("Click", this.OnReplace.Bind(this))
        
        ; Output area
        this.gui.AddText("x10 y350 w100", "Output Text:")
        this.outputEdit := this.gui.AddEdit("x10 y370 w600 h150 vOutputText Multi ReadOnly")
        
        ; Operation buttons
        this.gui.AddButton("x10 y530 w100", "Copy Output").OnEvent("Click", this.OnCopyOutput.Bind(this))
        this.gui.AddButton("x120 y530 w100", "Clear All").OnEvent("Click", this.OnClearAll.Bind(this))
        this.gui.AddButton("x510 y530 w100", "Close").OnEvent("Click", (*) => this.gui.Hide())
        
        ; Setup hotkeys
        this.SetupHotkeys()
        
        this.gui.Show("w620 h570")
    }
    
    SetupHotkeys() {
        ; Global hotkey to show the app
        Hotkey("^!t", this.Show.Bind(this))
        
        ; Window-specific hotkeys
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("^c", this.OnCopyOutput.Bind(this))
        Hotkey("^r", this.OnReplace.Bind(this))
        HotIfWinActive()
    }
    
    Show(*) {
        this.gui.Show()
    }
    
    ProcessText(operation) {
        ; Get current input text
        saved := this.gui.Submit(false)
        inputText := saved.InputText
        
        ; Update case sensitive flag
        this.caseSensitive := saved.CaseSensitive
        
        ; Skip processing if empty
        if (inputText = "")
            return ""
            
        ; Process according to operation
        result := inputText
        
        switch operation {
            case "uppercase":
                result := this.ToUpperCase(inputText)
            case "lowercase":
                result := this.ToLowerCase(inputText)
            case "titlecase":
                result := this.ToTitleCase(inputText)
            case "removespaces":
                result := this.RemoveSpaces(inputText)
            case "linesort":
                result := this.SortLines(inputText)
            case "replace":
                findText := saved.FindText
                replaceText := saved.ReplaceText
                result := this.ReplaceText(inputText, findText, replaceText)
        }
        
        ; Add to history
        this.AddToHistory(result)
        
        ; Update output
        this.outputEdit.Value := result
        
        return result
    }
    
    AddToHistory(text) {
        if (text = "")
            return
            
        ; Add to history
        this.history.Push(text)
        
        ; Trim history if needed
        while (this.history.Length > TextProcessor.Config["maxHistory"])
            this.history.RemoveAt(1)
    }
    
    ToUpperCase(text) {
        return StrUpper(text)
    }
    
    ToLowerCase(text) {
        return StrLower(text)
    }
    
    ToTitleCase(text) {
        return this.TitleCaseText(text)
    }
    
    TitleCaseText(text) {
        result := ""
        inWord := false
        
        Loop Parse, text {
            char := A_LoopField
            
            if char is alpha {
                if (!inWord) {
                    char := StrUpper(char)
                    inWord := true
                } else {
                    char := StrLower(char)
                }
            } else if (char = " " || char = "`n" || char = "`t") {
                inWord := false
            }
            
            result .= char
        }
        
        return result
    }
    
    RemoveSpaces(text) {
        return StrReplace(text, " ", "")
    }
    
    SortLines(text) {
        ; Split text into lines
        lines := []
        Loop Parse, text, "`n", "`r" {
            lines.Push(A_LoopField)
        }
        
        ; Sort lines
        lines := this.SortArray(lines)
        
        ; Join lines back together
        result := ""
        for index, line in lines {
            if (index > 1)
                result .= "`n"
            result .= line
        }
        
        return result
    }
    
    SortArray(array) {
        ; Simple bubble sort
        for i in array.Length {
            for j in array.Length - i {
                if (array[j] > array[j + 1]) {
                    temp := array[j]
                    array[j] := array[j + 1]
                    array[j + 1] := temp
                }
            }
        }
        return array
    }
    
    ReplaceText(text, findStr, replaceStr) {
        if (findStr = "")
            return text
            
        if (this.caseSensitive)
            return StrReplace(text, findStr, replaceStr, , , "C")
        else
            return StrReplace(text, findStr, replaceStr)
    }
    
    OnUppercase(*) {
        this.ProcessText("uppercase")
    }
    
    OnLowercase(*) {
        this.ProcessText("lowercase")
    }
    
    OnTitleCase(*) {
        this.ProcessText("titlecase")
    }
    
    OnRemoveSpaces(*) {
        this.ProcessText("removespaces")
    }
    
    OnLineSort(*) {
        this.ProcessText("linesort")
    }
    
    OnReplace(*) {
        this.ProcessText("replace")
    }
    
    OnCopyOutput(*) {
        ; Copy output text to clipboard
        saved := this.gui.Submit(false)
        if (saved.OutputText != "")
            A_Clipboard := saved.OutputText
            
        ToolTip("Output copied to clipboard")
        SetTimer(() => ToolTip(), -2000)
    }
    
    OnClearAll(*) {
        ; Clear all text fields
        this.inputEdit.Value := ""
        this.findEdit.Value := ""
        this.replaceEdit.Value := ""
        this.outputEdit.Value := ""
    }
}
```
    </text_processor>
    
    <app_launcher>

```cpp
#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

AppLauncher()
class AppLauncher {
    static Config := Map(
        "configFile", A_ScriptDir "\launcher_config.ini",
        "maxHistory", 20,
        "launchHotkey", "#Space"  ; Win+Space
    )
    
    __New() {
        ; Initialize properties
        this.apps := Map()
        this.history := []
        
        ; Load configuration
        this.LoadConfig()
        
        ; Create GUI
        this.CreateGui()
        
        ; Setup global hotkey
        this.SetupHotkeys()
    }
    
    CreateGui() {
        ; Main launcher window
        this.gui := Gui("+AlwaysOnTop -Caption +Border", "App Launcher")
        this.gui.SetFont("s12")
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        
        ; Search box
        this.searchEdit := this.gui.AddEdit("w400 h30 vSearchText")
        this.searchEdit.OnEvent("Change", this.OnSearchChange.Bind(this))
        
        ; Results list
        this.resultsList := this.gui.AddListBox("w400 h300 vResultsList")
        this.resultsList.OnEvent("DoubleClick", this.OnListDoubleClick.Bind(this))
        
        ; Setup hotkeys for list navigation
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("Enter", this.OnEnterPressed.Bind(this))
        Hotkey("Up", this.OnUpPressed.Bind(this))
        Hotkey("Down", this.OnDownPressed.Bind(this))
        HotIfWinActive()
        
        ; Create settings button
        this.gui.AddButton("w80 h30", "Settings").OnEvent("Click", this.ShowSettings.Bind(this))
    }
    
    ShowSettings(*) {
        ; Create settings GUI
        settingsGui := Gui("+Owner" this.gui.Hwnd, "App Launcher Settings")
        settingsGui.SetFont("s10")
        settingsGui.OnEvent("Close", (*) => settingsGui.Destroy())
        
        ; Add app section
        settingsGui.AddText("x10 y10", "Add New Application:")
        settingsGui.AddText("x10 y40", "Name:")
        nameEdit := settingsGui.AddEdit("x100 y40 w200 vAppName")
        
        settingsGui.AddText("x10 y70", "Path:")
        pathEdit := settingsGui.AddEdit("x100 y70 w200 vAppPath")
        browseBtn := settingsGui.AddButton("x310 y70 w80", "Browse...")
        browseBtn.OnEvent("Click", (*) => {
            selectedFile := FileSelect("3", , "Select Application")
            if (selectedFile)
                pathEdit.Value := selectedFile
        })
        
        addBtn := settingsGui.AddButton("x100 y110 w100", "Add App")
        addBtn.OnEvent("Click", (*) => {
            saved := settingsGui.Submit(false)
            if (saved.AppName != "" && saved.AppPath != "") {
                this.AddApp(saved.AppName, saved.AppPath)
                MsgBox("Application added: " saved.AppName)
                nameEdit.Value := ""
                pathEdit.Value := ""
            } else {
                MsgBox("Please enter both name and path")
            }
        })
        
        ; Existing apps section
        settingsGui.AddText("x10 y150", "Existing Applications:")
        appsList := settingsGui.AddListBox("x10 y170 w300 h200 vExistingApps")
        
        ; Populate apps list
        for name, path in this.apps
            appsList.Add([name])
        
        removeBtn := settingsGui.AddButton("x320 y200 w80", "Remove")
        removeBtn.OnEvent("Click", (*) => {
            selected := appsList.Text
            if (selected != "") {
                result := MsgBox("Remove '" selected "' from applications?", , "YesNo")
                if (result = "Yes") {
                    this.apps.Delete(selected)
                    appsList.Delete(appsList.Value)
                    this.SaveConfig()
                }
            } else {
                MsgBox("Please select an application to remove")
            }
        })
        
        settingsGui.AddButton("x150 y380 w100", "Close").OnEvent("Click", (*) => settingsGui.Destroy())
        
        ; Show settings dialog
        settingsGui.Show()
    }
    
    SetupHotkeys() {
        ; Global hotkey to show launcher
        Hotkey(AppLauncher.Config["launchHotkey"], this.Toggle.Bind(this))
    }
    
    Toggle(*) {
        if WinExist("ahk_id " this.gui.Hwnd)
            this.gui.Hide()
        else {
            ; Position in center of screen
            this.CenterWindow()
            this.gui.Show()
            
            ; Clear and focus search box
            this.searchEdit.Value := ""
            this.searchEdit.Focus()
            
            ; Show all apps initially
            this.FilterApps("")
        }
    }
    
    CenterWindow() {
        ; Get screen dimensions
        screenWidth := A_ScreenWidth
        screenHeight := A_ScreenHeight
        
        ; Calculate position
        xPos := (screenWidth - 400) / 2
        yPos := (screenHeight - 330) / 2
        
        ; Position window
        this.gui.Show("x" xPos " y" yPos " w400 h330")
    }
    
    LoadConfig() {
        ; Load app configuration
        if FileExist(AppLauncher.Config["configFile"]) {
            Loop Read, AppLauncher.Config["configFile"] {
                if (A_LoopReadLine = "" || SubStr(A_LoopReadLine, 1, 1) = ";")
                    continue
                    
                parts := StrSplit(A_LoopReadLine, "=", , 2)
                if (parts.Length = 2)
                    this.apps[parts[1]] := parts[2]
            }
        } else {
            ; Create default config with some common apps
            this.apps["Calculator"] := "calc.exe"
            this.apps["Notepad"] := "notepad.exe"
            this.apps["Explorer"] := "explorer.exe"
            this.SaveConfig()
        }
    }
    
    SaveConfig() {
        ; Save app configuration
        configContent := "; App Launcher Configuration`n"
        configContent .= "; Format: AppName=AppPath`n`n"
        
        for name, path in this.apps
            configContent .= name "=" path "`n"
            
        try {
            FileDelete(AppLauncher.Config["configFile"])
            FileAppend(configContent, AppLauncher.Config["configFile"])
        } catch as err {
            MsgBox("Error saving configuration: " err.Message)
        }
    }
    
    AddApp(name, path) {
        this.apps[name] := path
        this.SaveConfig()
    }
    
    FilterApps(searchText) {
        ; Clear results list
        this.resultsList.Delete()
        
        ; Filter apps based on search text
        results := []
        
        if (searchText = "") {
            ; Show all apps ordered by most recently used
            for name, path in this.apps
                results.Push(name)
                
            ; Sort by usage history
            this.SortByHistory(results)
        } else {
            ; Filter by search text
            for name, path in this.apps {
                if InStr(StrLower(name), StrLower(searchText))
                    results.Push(name)
            }
            
            ; Sort results by relevance
            this.SortByRelevance(results, searchText)
        }
        
        ; Add to results list
        for index, name in results
            this.resultsList.Add([name])
            
        ; Select first item if available
        if (this.resultsList.Count > 0)
            this.resultsList.Choose(1)
    }
    
    SortByHistory(results) {
        ; First get items in history
        sortedResults := []
        
        ; Add items from history in order
        for index, name in this.history {
            if results.HasValue(name) {
                sortedResults.Push(name)
                results.RemoveValue(name)
            }
        }
        
        ; Add remaining items alphabetically
        results := this.SortArray(results)
        for index, name in results
            sortedResults.Push(name)
            
        return sortedResults
    }
    
    SortByRelevance(results, searchText) {
        ; Sort by how closely the app name matches the search text
        relevanceMap := Map()
        
        for index, name in results {
            ; Calculate relevance score
            if (StrLower(SubStr(name, 1, StrLen(searchText))) = StrLower(searchText)) {
                ; Starts with search text - highest relevance
                relevanceMap[name] := 100 - StrLen(name)
            } else {
                ; Contains search text - lower relevance
                relevanceMap[name] := 50 - StrLen(name)
            }
        }
        
        ; Sort by relevance score
        sortedResults := []
        
        while (results.Length > 0) {
            highestScore := -1
            highestItem := ""
            highestIndex := 0
            
            for index, name in results {
                score := relevanceMap[name]
                if (score > highestScore) {
                    highestScore := score
                    highestItem := name
                    highestIndex := index
                }
            }
            
            if (highestItem != "") {
                sortedResults.Push(highestItem)
                results.RemoveAt(highestIndex)
            } else {
                break
            }
        }
        
        return sortedResults
    }
    
    SortArray(array) {
        ; Simple bubble sort
        for i in array.Length {
            for j in array.Length - i {
                if (array[j] > array[j + 1]) {
                    temp := array[j]
                    array[j] := array[j + 1]
                    array[j + 1] := temp
                }
            }
        }
        return array
    }
    
    LaunchApp(appName) {
        if !this.apps.Has(appName)
            return
            
        ; Launch the application
        try {
            Run(this.apps[appName])
            
            ; Add to history
            this.AddToHistory(appName)
            
            ; Hide launcher
            this.gui.Hide()
        } catch as err {
            MsgBox("Error launching application: " err.Message)
        }
    }
    
    AddToHistory(appName) {
        ; Remove if already in history
        this.history.RemoveValue(appName)
        
        ; Add to front of history
        this.history.InsertAt(1, appName)
        
        ; Trim history if needed
        while (this.history.Length > AppLauncher.Config["maxHistory"])
            this.history.Pop()
    }
    
    OnSearchChange(*) {
        ; Get search text
        saved := this.gui.Submit(false)
        this.FilterApps(saved.SearchText)
    }
    
    OnListDoubleClick(*) {
        selected := this.resultsList.Text
        if (selected != "")
            this.LaunchApp(selected)
    }
    
    OnEnterPressed(*) {
        selected := this.resultsList.Text
        if (selected != "")
            this.LaunchApp(selected)
    }
    
    OnUpPressed(*) {
        ; Move selection up
        currentIndex := this.resultsList.Value
        if (currentIndex > 1)
            this.resultsList.Choose(currentIndex - 1)
    }
    
    OnDownPressed(*) {
        ; Move selection down
        currentIndex := this.resultsList.Value
        if (currentIndex < this.resultsList.Count)
            this.resultsList.Choose(currentIndex + 1)
    }
}
```
    </app_launcher>
  </practical_examples>
</ahk_components>

These examples demonstrate proper AutoHotkey v2 Object-Oriented Programming techniques following the guidelines from the provided documents. Key points from the implementation include:

1. Classes are properly initialized without using the "new" keyword
2. Maps are used for key-value data storage instead of object literals
3. Event handlers are bound correctly using .Bind(this)
4. Arrow functions are used appropriately for simple, single-line expressions
5. Variables are explicitly declared and properly scoped
6. Proper error handling techniques are employed
7. All GUI controls use modern object-oriented syntax

The examples cover a range of practical applications from simple GUI interfaces to complex text processing tools and file management utilities, all following AutoHotkey v2's best practices.