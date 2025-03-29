#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

; ========================================================================
; SIMPLE AUTOHOTKEY V2 EXAMPLES
; This file contains beginner-friendly examples of common AHK v2 patterns
; ========================================================================

; ------------------------------------------------------------
; Basic Hotkeys
; ------------------------------------------------------------

; Simple hotkey to show a message when you press Win+Z
#z:: MsgBox("You pressed Win+Z!")

; Ctrl+Alt+T to display the current time
^!t::ShowCurrentTime()

ShowCurrentTime() {
    currentTime := FormatTime(, "h:mm:ss tt")
    MsgBox("The current time is " currentTime, "Time Display")
}

; ------------------------------------------------------------
; Basic GUI Example
; ------------------------------------------------------------

; Win+G to show a simple GUI
#g::ShowSimpleGui()

ShowSimpleGui() {
    ; Create a GUI
    myGui := Gui(, "Simple Example")
    myGui.SetFont("s10")
    
    ; Add some controls
    myGui.AddText(, "Enter your name:")
    nameEdit := myGui.AddEdit("w200 vUserName")
    
    ; Add a button with a callback
    submitBtn := myGui.AddButton("Default w100", "OK")
    submitBtn.OnEvent("Click", SubmitForm)
    
    ; Add event to handle when the GUI is closed
    myGui.OnEvent("Close", (*) => myGui.Destroy())
    
    ; Show the GUI
    myGui.Show()
    
    ; Function to handle the button click
    SubmitForm(*) {
        saved := myGui.Submit()
        if (saved.UserName = "")
            MsgBox("Please enter your name.")
        else
            MsgBox("Hello, " saved.UserName "!")
    }
}

; ------------------------------------------------------------
; Simple Text Manipulation
; ------------------------------------------------------------

; Ctrl+Shift+U to convert selected text to uppercase
^+u::ConvertSelectedText("upper")

; Ctrl+Shift+L to convert selected text to lowercase
^+l::ConvertSelectedText("lower")

ConvertSelectedText(textCase) {
    ; Save the current clipboard content
    savedClip := ClipboardAll()
    
    ; Clear the clipboard and copy the selected text
    A_Clipboard := ""
    Send("^c")
    ClipWait(1)
    
    ; If text was selected and copied
    if (A_Clipboard != "") {
        ; Convert the text based on the textCase parameter
        if (textCase = "upper")
            A_Clipboard := StrUpper(A_Clipboard)
        else if (textCase = "lower")
            A_Clipboard := StrLower(A_Clipboard)
        
        ; Paste the converted text
        Send("^v")
    }
    
    ; Restore the original clipboard
    A_Clipboard := savedClip
}

; ------------------------------------------------------------
; Simple Application Launcher
; ------------------------------------------------------------

; Win+N to launch Notepad
#n::Run("notepad.exe")

; Win+C to launch Calculator
#c::Run("calc.exe")

; ------------------------------------------------------------
; Working with Arrays and Maps (Modern Data Structures)
; ------------------------------------------------------------

; Ctrl+Alt+A to demonstrate arrays
^!a::DemonstrateArray()

DemonstrateArray() {
    ; Create an array of fruits
    fruits := ["Apple", "Banana", "Cherry", "Date", "Elderberry"]
    
    ; Build a message with all fruits
    message := "Fruits in the array:`n`n"
    
    ; Loop through the array
    for index, fruit in fruits
        message .= index ": " fruit "`n"
    
    ; Add an item
    fruits.Push("Fig")
    message .= "`nAdded 'Fig' to the array.`n"
    
    ; Remove an item
    fruits.RemoveAt(2)  ; Remove Banana (index 2)
    message .= "Removed 'Banana' from the array.`n"
    
    ; Display the updated array
    message .= "`nUpdated array:`n"
    for index, fruit in fruits
        message .= index ": " fruit "`n"
    
    MsgBox(message, "Array Example")
}

; Ctrl+Alt+M to demonstrate maps
^!m::DemonstrateMap()

DemonstrateMap() {
    ; Create a map of person details
    person := Map(
        "name", "John Smith",
        "age", 35,
        "city", "New York",
        "occupation", "Software Developer"
    )
    
    ; Build a message with all details
    message := "Person details:`n`n"
    
    ; Loop through the map
    for key, value in person
        message .= key ": " value "`n"
    
    ; Add an item
    person["email"] := "john@example.com"
    message .= "`nAdded 'email' to the map.`n"
    
    ; Remove an item
    person.Delete("age")
    message .= "Removed 'age' from the map.`n"
    
    ; Display the updated map
    message .= "`nUpdated map:`n"
    for key, value in person
        message .= key ": " value "`n"
    
    MsgBox(message, "Map Example")
}

; ------------------------------------------------------------
; Simple File Operations
; ------------------------------------------------------------

; Ctrl+Alt+F to demonstrate file operations
^!f::DemonstrateFileOperations()

DemonstrateFileOperations() {
    ; Define file path in Documents folder
    filePath := A_MyDocuments "\AHKTest.txt"
    
    ; Write to a file
    try {
        file := FileOpen(filePath, "w")
        file.WriteLine("This is line 1")
        file.WriteLine("This is line 2")
        file.WriteLine("This is line 3")
        file.Close()
        
        MsgBox("Successfully wrote to file: " filePath)
        
        ; Read from the file
        file := FileOpen(filePath, "r")
        fileContent := file.Read()
        file.Close()
        
        MsgBox("File content:`n`n" fileContent)
        
    } catch Error as e {
        MsgBox("Error: " e.Message)
    }
}

; ------------------------------------------------------------
; Simple Timer Example
; ------------------------------------------------------------

; Ctrl+Alt+T to start/stop a simple timer
^!t::ToggleTimer()

; Global to track timer state
global timerRunning := false
global startTime := 0

ToggleTimer() {
    global timerRunning, startTime
    
    if (!timerRunning) {
        ; Start the timer
        startTime := A_TickCount
        SetTimer(UpdateTimerDisplay, 1000)
        timerRunning := true
        
        ; Show initial display
        UpdateTimerDisplay()
    } else {
        ; Stop the timer
        SetTimer(UpdateTimerDisplay, 0)
        timerRunning := false
        
        ; Clear the tooltip
        ToolTip()
    }
}

UpdateTimerDisplay() {
    global startTime
    
    ; Calculate elapsed time
    elapsedSeconds := Floor((A_TickCount - startTime) / 1000)
    elapsedMinutes := Floor(elapsedSeconds / 60)
    elapsedSeconds := Mod(elapsedSeconds, 60)
    
    ; Format nicely with leading zeros
    timeDisplay := Format("{:02}:{:02}", elapsedMinutes, elapsedSeconds)
    
    ; Display in tooltip
    ToolTip("Timer: " timeDisplay)
}
