
<<<>>>
 
Description:
 
By enclosing the two statements MsgBox "test1" and Sleep 5 with braces, the If statement knows that it should execute both if x is equal to 1.
 
 
Code:
 
```ahkv2
if (x = 1)
{
    MsgBox "test1"
    Sleep 5
}
else
    MsgBox "test2"
```
 
<<<>>>
 
Description:
 
Breaks the loop if var is greater than 25.
 
 
Code:
 
```ahkv2
Loop
{
 
    if (var > 25)
        break
 
    if (var <= 5)
        continue
}
```
 
<<<>>>
 
Description:
 
Breaks the outer loop from within a nested loop.
 
 
Code:
 
```ahkv2
outer:
Loop 3
{
    x := A_Index
    Loop 3
    {
        if (x*A_Index = 6)
            break outer  
        MsgBox x "," A_Index
    }
}
break_outer: 
```
 
<<<>>>
 
Description:
 
Allows the user to move the caret around to see its current position displayed in an auto-update tooltip.
 
 
Code:
 
```ahkv2
SetTimer WatchCaret, 100
WatchCaret() {
    if CaretGetPos(&x, &y)
        ToolTip "X" x " Y" y, x, y - 20
    else
        ToolTip "No caret"
}
```
 
<<<>>>
 
Description:
 
Clicks the left mouse button at the mouse cursor's current position.
 
 
Code:
 
```ahkv2
Click
```
 
<<<>>>
 
Description:
 
Clicks the left mouse button at a specific position.
 
 
Code:
 
```ahkv2
Click 100, 200
```
 
<<<>>>
 
Description:
 
Moves the mouse cursor to a specific position without clicking.
 
 
Code:
 
```ahkv2
Click 100, 200, 0
```
 
<<<>>>
 
Description:
 
Clicks the right mouse button at a specific position.
 
 
Code:
 
```ahkv2
Click 100, 200, "Right"
```
 
<<<>>>
 
Description:
 
Performs a double-click at the mouse cursor's current position.
 
 
Code:
 
```ahkv2
Click 2
```
 
<<<>>>
 
Description:
 
Presses down the left mouse button and holds it.
 
 
Code:
 
```ahkv2
Click "Down"
```
 
<<<>>>
 
Description:
 
Releases the right mouse button.
 
 
Code:
 
```ahkv2
Click "Up Right"
```
 
<<<>>>
 
Description:
 
Saves and restores everything on the clipboard using a variable.
 
 
Code:
 
```ahkv2
ClipSaved := ClipboardAll()   
A_Clipboard := ClipSaved   
ClipSaved := ""  
```
 
<<<>>>
 
Description:
 
Saves and restores everything on the clipboard using a file.
 
 
Code:
 
```ahkv2
FileDelete "Company Logo.clip"
FileAppend ClipboardAll(), "Company Logo.clip" 
ClipData := ClipboardAll()
FileOpen("Company Logo.clip", "w").RawWrite(ClipData)
```
 
<<<>>>
 
Description:
 
Empties the clipboard, copies the current selection into the clipboard and waits a maximum of 2 seconds until the clipboard contains data. If ClipWait times out, an error message is shown, otherwise the clipboard contents is shown.
 
 
Code:
 
```ahkv2
A_Clipboard := "" 
Send "^c"
if !ClipWait(2)
{
    MsgBox "The attempt to copy text onto the clipboard failed."
    return
}
MsgBox "clipboard = " A_Clipboard
return
```
 
<<<>>>
 
Description:
 
Gives the clipboard entirely new contents.
 
 
Code:
 
```ahkv2
A_Clipboard := "my text"
```
 
<<<>>>
 
Description:
 
Empties the clipboard.
 
 
Code:
 
```ahkv2
A_Clipboard := ""
```
 
<<<>>>
 
Description:
 
Converts any copied files, HTML, or other formatted text to plain text.
 
 
Code:
 
```ahkv2
A_Clipboard := A_Clipboard
```
 
<<<>>>
 
Description:
 
Appends some text to the clipboard.
 
 
Code:
 
```ahkv2
A_Clipboard .= " Text to append."
```
 
<<<>>>
 
Description:
 
Replaces all occurrences of ABC with DEF (also converts the clipboard to plain text).
 
 
Code:
 
```ahkv2
A_Clipboard := StrReplace(A_Clipboard, "ABC", "DEF")
```
 
<<<>>>
 
Description:
 
Displays 5 message boxes, one for each number between 6 and 10. Note that in the first 5 iterations of the loop, the Continue statement causes the loop to start over before it reaches the MsgBox line.
 
 
Code:
 
```ahkv2
Loop 10
{
    if (A_Index <= 5)
        continue
    MsgBox A_Index
}
```
 
<<<>>>
 
Description:
 
Continues the outer loop from within a nested loop.
 
 
Code:
 
```ahkv2
outer:
Loop 3
{
    x := A_Index
    Loop 3
    {
        if (x*A_Index = 4)
            continue outer  
        MsgBox x "," A_Index
    }
    continue_outer: 
}
```
 
<<<>>>
 
Description:
 
Places tooltips at absolute screen coordinates.
 
 
Code:
 
```ahkv2
CoordMode "ToolTip", "Screen"
```
 
<<<>>>
 
Description:
 
Same effect as the above because "Screen" is the default.
 
 
Code:
 
```ahkv2
CoordMode "ToolTip"
```
 
<<<>>>
 
Description:
 
Press a hotkey to display a tooltip for 3 seconds. Due to Critical, any new thread that is launched during this time (e.g. by pressing the hotkey again) will be postponed until the tooltip disappears.
 
 
Code:
 
```ahkv2
#space::  
{
    Critical
    ToolTip "No new threads will launch until after this ToolTip disappears."
    Sleep 3000
    ToolTip  
    return 
}
```
 
<<<>>>
 
Description:
 
Calculates the date 31 days from now and reports the result in human-readable form.
 
 
Code:
 
```ahkv2
later := DateAdd(A_Now, 31, "days")
MsgBox FormatTime(later)
```
 
<<<>>>
 
Description:
 
Calculates the number of days between two timestamps and reports the result.
 
 
Code:
 
```ahkv2
var1 := "20050126"
var2 := "20040126"
MsgBox DateDiff(var1, var2, "days")  
```
 
<<<>>>
 
Description:
 
Turns off the detection of hidden text.
 
 
Code:
 
```ahkv2
DetectHiddenText false
```
 
<<<>>>
 
Description:
 
Activates either Notepad or another window, depending on which of them was found by the WinExist functions above. Note that the space between an "ahk_" keyword and its criterion value can be omitted; this is especially useful when using variables, as shown by the second WinExist.
 
 
Code:
 
```ahkv2
if WinExist("ahk_class Notepad") or WinExist("ahk_class" ClassName)
    WinActivate 
```
 
<<<>>>
 
Description:
 
Retrieves and reports the unique ID (HWND) of the active window.
 
 
Code:
 
```ahkv2
MsgBox "The active window's ID is " WinExist("A")
```
 
<<<>>>
 
Description:
 
Returns if the calculator does not exist.
 
 
Code:
 
```ahkv2
if not WinExist("Calculator")
    return
```
 
<<<>>>
 
Description:
 
Turns on the detection of hidden windows.
 
 
Code:
 
```ahkv2
DetectHiddenWindows true
```
 
<<<>>>
 
Description:
 
Copies a directory to a new location.
 
 
Code:
 
```ahkv2
DirCopy "C:\My Folder", "C:\Copy of My Folder"
```
 
<<<>>>
 
Description:
 
Prompts the user to copy a folder.
 
 
Code:
 
```ahkv2
SourceFolder := DirSelect(, 3, "Select the folder to copy")
if SourceFolder = ""
    return
TargetFolder := DirSelect(, 3, "Select the folder IN WHICH to create the duplicate folder.")
if TargetFolder = ""
    return
Result := MsgBox("A copy of the folder '" SourceFolder "' will be put into '" TargetFolder "'. Continue?",, 4)
if Result = "No"
    return
SplitPath SourceFolder, &SourceFolderName  
try
    DirCopy SourceFolder, TargetFolder "\" SourceFolderName
catch
    MsgBox "The folder could not be copied, perhaps because a folder of that name already exists in '" TargetFolder "'."
return
```
 
<<<>>>
 
Description:
 
Creates a new directory, including its parent directories if necessary.
 
 
Code:
 
```ahkv2
DirCreate "C:\Test1\My Images\Folder2"
```
 
<<<>>>
 
Description:
 
Removes the directory, but only if it is empty.
 
 
Code:
 
```ahkv2
DirDelete "C:\Download Temp"
```
 
<<<>>>
 
Description:
 
Removes the directory including its files and subdirectories.
 
 
Code:
 
```ahkv2
DirDelete "C:\Download Temp", true
```
 
<<<>>>
 
Description:
 
Shows a message box if a folder does exist.
 
 
Code:
 
```ahkv2
if DirExist("C:\Windows")
    MsgBox "The target folder does exist."
```
 
<<<>>>
 
Description:
 
Shows a message box if at least one program folder does exist.
 
 
Code:
 
```ahkv2
if DirExist("C:\Program*")
    MsgBox "At least one program folder exists."
```
 
<<<>>>
 
Description:
 
Shows a message box if a folder does not exist.
 
 
Code:
 
```ahkv2
if not DirExist("C:\Temp")
    MsgBox "The target folder does not exist."
```
 
<<<>>>
 
Description:
 
Demonstrates how to check a folder for a specific attribute.
 
 
Code:
 
```ahkv2
if InStr(DirExist("C:\System Volume Information"), "H")
    MsgBox "The folder is hidden."
```
 
<<<>>>
 
Description:
 
Moves a directory to a new drive.
 
 
Code:
 
```ahkv2
DirMove "C:\My Folder", "D:\My Folder"
```
 
<<<>>>
 
Description:
 
Performs a simple rename.
 
 
Code:
 
```ahkv2
DirMove "C:\My Folder", "C:\My Folder (renamed)", "R"
```
 
<<<>>>
 
Description:
 
Directories can be "renamed into" another location as long as it's on the same volume.
 
 
Code:
 
```ahkv2
DirMove "C:\My Folder", "C:\New Location\My Folder", "R"
```
 
<<<>>>
 
Description:
 
Allows the user to select a folder and provides both an edit field and a "make new folder" button.
 
 
Code:
 
```ahkv2
SelectedFolder := DirSelect(, 3)
if SelectedFolder = ""
    MsgBox "You didn't select a folder."
else
    MsgBox "You selected folder '" SelectedFolder "'."
```
 
<<<>>>
 
Description:
 
A CLSID example. Allows the user to select a folder in This PC (formerly My Computer or Computer).
 
 
Code:
 
```ahkv2
SelectedFolder := DirSelect("::{20D04FE0-3AEA-1069-A2D8-08002B30309D}")
```
 
<<<>>>
 
Description:
 
Downloads a text file.
 
 
Code:
 
```ahkv2
Download "https://www.autohotkey.com/download/2.0/version.txt", "C:\AutoHotkey Latest Version.txt"
```
 
<<<>>>
 
Description:
 
Downloads a zip file.
 
 
Code:
 
```ahkv2
Download "https://someorg.org/archive.zip", "C:\SomeOrg's Archive.zip"
```
 
<<<>>>
 
Description:
 
Downloads text to a variable.
 
 
Code:
 
```ahkv2
whr := ComObject("WinHttp.WinHttpRequest.5.1")
whr.Open("GET", "https://www.autohotkey.com/download/2.0/version.txt", true)
whr.Send()
whr.WaitForResponse()
version := whr.ResponseText
MsgBox version
```
 
<<<>>>
 
Description:
 
Makes an asynchronous HTTP request.
 
 
Code:
 
```ahkv2
req := ComObject("Msxml2.XMLHTTP")
req.open("GET", "https://www.autohotkey.com/download/2.0/version.txt", true)
req.onreadystatechange := Ready
req.send()
Persistent
Ready() {
    if (req.readyState != 4)  
        return
    if (req.status == 200) 
        MsgBox "Latest AutoHotkey version: " req.responseText
    else
        MsgBox "Status " req.status,, 16
    ExitApp
}
```
 
<<<>>>
 
Description:
 
Opens the script for editing.
 
 
Code:
 
```ahkv2
Edit
```
 
<<<>>>
 
Description:
 
If your editor's command-line usage is something like Editor.exe "Full path of script.ahk", the following can be used to set it as the default editor for ahk files. When you run the script, it will prompt you to select the executable file of your editor.
 
 
Code:
 
```ahkv2
Editor := FileSelect(2,, "Select your editor", "Programs (*.exe)")
if Editor = ""
    ExitApp
RegWrite Format('"{1}" "%L"', Editor), "REG_SZ", "HKCR\AutoHotkeyScript\Shell\Edit\Command"
```
 
<<<>>>
 
Description:
 
Retrieves the first line of the Notepad's Edit control.
 
 
Code:
 
```ahkv2
line1 := EditGetLine(1, "Edit1", "ahk_class Notepad")
```
 
<<<>>>
 
Description:
 
Common usage of an  statement. This example is executed as follows:
  If Notepad exists:
 
      Activate it
      Send the string "This is a test." followed by Enter.
 
 
  Otherwise (that is, if Notepad does not exist):
 
      Activate another window
      Left-click at the coordinates 100, 200
 
 
if WinExist("Untitled - Notepad")
{
    WinActivate
    Send "This is a test.{Enter}"
}
else
{
    WinActivate "Some Other Window"
    MouseClick "Left", 100, 200
}
 Demonstrates different styles of how the  statement can be used too.
 
 
Code:
 
```ahkv2
if (x = 1)
    firstFunction()
else if (x = 2) 
    secondFunction()
else if x = 3
{
    thirdFunction()
    Sleep 1
}
else defaultFunction()  
```
 
<<<>>>
 
Description:
 
Executes some code if a loop had zero iterations.
 
 
Code:
 
```ahkv2
for window in ComObject("Shell.Application").Windows
    MsgBox "Window #" A_Index ": " window.LocationName
else
    MsgBox "No shell windows found."
```
 
<<<>>>
 
Description:
 
In this example, the Exit function terminates the call_exit function as well as the calling function.
 
 
Code:
 
```ahkv2
#z::
{
    call_exit
    MsgBox "This MsgBox will never happen because of the Exit."
    call_exit() 
    {
        Exit 
    }
}
```
 
<<<>>>
 
Description:
 
Press a hotkey to terminate the script.
 
 
Code:
 
```ahkv2
#x::ExitApp  
```
 
<<<>>>
 
Description:
 
Creates a file, if necessary, and appends a line.
 
 
Code:
 
```ahkv2
FileAppend "Another line.`n", "C:\My Documents\Test.txt"
```
 
<<<>>>
 
Description:
 
Use a continuation section to enhance readability and maintainability.
 
 
Code:
 
```ahkv2
FileAppend "
(
A line of text.
By default, the hard carriage return (Enter) between the previous line and this one will be written to the file.
	This line is indented with a tab; by default, that tab will also be written to the file.
)", A_Desktop "\My File.txt"
```
 
<<<>>>
 
Description:
 
Demonstrates how to automate FTP uploading using the operating system's built-in FTP command.
 
 
Code:
 
```ahkv2
FTPCommandFile := A_ScriptDir "\FTPCommands.txt"
FTPLogFile := A_ScriptDir "\FTPLog.txt"
try FileDelete FTPCommandFile  
FileAppend
(
"open host.domain.com
username
password
binary
cd htdocs
put " VarContainingNameOfTargetFile "
delete SomeOtherFile.htm
rename OldFileName.htm NewFileName.htm
ls -l
quit"
), FTPCommandFile
RunWait Format('{1} /c ftp.exe -s:"{2}" >"{3}"', A_ComSpec, FTPCommandFile, FTPLogFile)
FileDelete FTPCommandFile  
Run FTPLogFile  
```
 
<<<>>>
 
Description:
 
Makes a copy but keep the original file name.
 
 
Code:
 
```ahkv2
FileCopy "C:\My Documents\List1.txt", "D:\Main Backup\"
```
 
<<<>>>
 
Description:
 
Copies a file into the same directory by providing a new name.
 
 
Code:
 
```ahkv2
FileCopy "C:\My File.txt", "C:\My File New.txt"
```
 
<<<>>>
 
Description:
 
Copies text files to a new location and gives them a new extension.
 
 
Code:
 
```ahkv2
FileCopy "C:\Folder1\*.txt", "D:\New Folder\*.bkp"
```
 
<<<>>>
 
Description:
 
Copies all files and folders inside a folder to a different folder.
 
 
Code:
 
```ahkv2
ErrorCount := CopyFilesAndFolders("C:\My Folder\*.*", "D:\Folder to receive all files & folders")
if ErrorCount != 0
    MsgBox ErrorCount " files/folders could not be copied."
CopyFilesAndFolders(SourcePattern, DestinationFolder, DoOverwrite := false)
{
    ErrorCount := 0
 
    try
        FileCopy SourcePattern, DestinationFolder, DoOverwrite
    catch as Err
        ErrorCount := Err.Extra
 
    Loop Files, SourcePattern, "D"  
    {
        try
            DirCopy A_LoopFilePath, DestinationFolder "\" A_LoopFileName, DoOverwrite
        catch
        {
            ErrorCount += 1
 
            MsgBox "Could not copy " A_LoopFilePath " into " DestinationFolder
        }
    }
    return ErrorCount
}
```
 
<<<>>>
 
Description:
 
The letter "i" in the last parameter makes the shortcut key be Ctrl+Alt+I.
 
 
Code:
 
```ahkv2
FileCreateShortcut "Notepad.exe", A_Desktop "\My Shortcut.lnk", "C:\", A_ScriptFullPath, "My Description", "C:\My Icon.ico", "i"
```
 
<<<>>>
 
Description:
 
Deletes all .tmp files in a directory.
 
 
Code:
 
```ahkv2
FileDelete "C:\temp files\*.tmp"
```
 
<<<>>>
 
Description:
 
Only those lines of the 1st file that contain the word FAMILY will be written to the 2nd file. Uncomment the first line to overwrite rather than append to any existing file.
 
 
Code:
 
```ahkv2
Loop read, "C:\Docs\Address List.txt", "C:\Docs\Family Addresses.txt"
{
    if InStr(A_LoopReadLine, "family")
        FileAppend(A_LoopReadLine "`n")
}
else
    MsgBox "Address List.txt was completely empty or not found."
```
 
<<<>>>
 
Description:
 
Retrieves the last line from a text file.
 
 
Code:
 
```ahkv2
Loop read, "C:\Log File.txt"
    last_line := A_LoopReadLine  
```
 
<<<>>>
 
Description:
 
Attempts to extract all FTP and HTTP URLs from a text or HTML file.
 
 
Code:
 
```ahkv2
SourceFile := FileSelect(3,, "Pick a text or HTML file to analyze.")
if SourceFile = ""
    return  
SplitPath SourceFile,, &SourceFilePath,, &SourceFileNoExt
DestFile := SourceFilePath "\" SourceFileNoExt " Extracted Links.txt"
if FileExist(DestFile)
{
    Result := MsgBox("Overwrite the existing links file? Press No to append to it.`n`nFILE: " DestFile,, 4)
    if Result = "Yes"
        FileDelete DestFile
}
LinkCount := 0
Loop read, SourceFile, DestFile
{
    URLSearch(A_LoopReadLine)
}
MsgBox LinkCount ' links were found and written to "' DestFile '".'
return
URLSearch(URLSearchString)
{
 
    URLStart := 0  
    for URLPrefix in ["https://", "http://", "ftp://", "www."]
    {
        ThisPos := InStr(URLSearchString, URLPrefix)
        if !ThisPos  
            continue
        if !URLStart
            URLStart := ThisPos
        else 
        {
            if ThisPos && ThisPos < URLStart
                URLStart := ThisPos
        }
    }
    if !URLStart  
        return
 
    URL := SubStr(URLSearchString, URLStart)  
    Loop parse, URL, " `t<>"  
    {
        URL := A_LoopField
        break  
    }
 
    URLCleansed := StrReplace(URL, '"')
    FileAppend URLCleansed "`n"
    global LinkCount += 1
 
    CharactersToOmit := StrLen(URL)
    CharactersToOmit += URLStart
    URLSearchString := SubStr(URLSearchString, CharactersToOmit)
 
 
    URLSearch(URLSearchString)
}
```
 
<<<>>>
 
Description:
 
Shows a message box if the D drive does exist.
 
 
Code:
 
```ahkv2
if FileExist("D:\")
    MsgBox "The drive exists."
```
 
<<<>>>
 
Description:
 
Shows a message box if at least one text file does exist in a directory.
 
 
Code:
 
```ahkv2
if FileExist("D:\Docs\*.txt")
    MsgBox "At least one .txt file exists."
```
 
<<<>>>
 
Description:
 
Shows a message box if a file does not exist.
 
 
Code:
 
```ahkv2
if not FileExist("C:\Temp\FlagFile.txt")
    MsgBox "The target file does not exist."
```
 
<<<>>>
 
Description:
 
Demonstrates how to check a file for a specific attribute.
 
 
Code:
 
```ahkv2
if InStr(FileExist("C:\My File.txt"), "H")
    MsgBox "The file is hidden."
```
 
<<<>>>
 
Description:
 
Moves a file without renaming it.
 
 
Code:
 
```ahkv2
FileMove "C:\My Documents\List1.txt", "D:\Main Backup\"
```
 
<<<>>>
 
Description:
 
Renames a single file.
 
 
Code:
 
```ahkv2
FileMove "C:\File Before.txt", "C:\File After.txt"
```
 
<<<>>>
 
Description:
 
Moves text files to a new location and gives them a new extension.
 
 
Code:
 
```ahkv2
FileMove "C:\Folder1\*.txt", "D:\New Folder\*.bkp"
```
 
<<<>>>
 
Description:
 
Moves all files and folders inside a folder to a different folder.
 
 
Code:
 
```ahkv2
ErrorCount := MoveFilesAndFolders("C:\My Folder\*.*", "D:\Folder to receive all files & folders")
if ErrorCount != 0
    MsgBox ErrorCount " files/folders could not be moved."
MoveFilesAndFolders(SourcePattern, DestinationFolder, DoOverwrite := false)
{
    ErrorCount := 0
    if DoOverwrite = 1
        DoOverwrite := 2  
 
    try
        FileMove SourcePattern, DestinationFolder, DoOverwrite
    catch as Err
        ErrorCount := Err.Extra
 
    Loop Files, SourcePattern, "D"  
    {
        try
            DirMove A_LoopFilePath, DestinationFolder "\" A_LoopFileName, DoOverwrite
        catch
        {
            ErrorCount += 1
 
            MsgBox "Could not move " A_LoopFilePath " into " DestinationFolder
        }
    }
    return ErrorCount
}
```
 
<<<>>>
 
Description:
 
Writes some text to a file then reads it back into memory (it provides the same functionality as this DllCall example).
 
 
Code:
 
```ahkv2
FileName := FileSelect("S16",, "Create a new file:")
if (FileName = "")
    return
try
    FileObj := FileOpen(FileName, "w")
catch as Err
{
    MsgBox "Can't open '" FileName "' for writing."
        . "`n`n" Type(Err) ": " Err.Message
    return
}
TestString := "This is a test string.`r`n"  
FileObj.Write(TestString)
FileObj.Close()
try
    FileObj := FileOpen(FileName, "r-d") 
catch as Err
{
    MsgBox "Can't open '" FileName "' for reading."
        . "`n`n" Type(Err) ": " Err.Message
    return
}
CharsToRead := StrLen(TestString)
TestString := FileObj.Read(CharsToRead)
FileObj.Close()
MsgBox "The following string was read from the file: " TestString
```
 
<<<>>>
 
Description:
 
Opens the script in read-only mode and read its first line.
 
 
Code:
 
```ahkv2
Script := FileOpen(A_ScriptFullPath, "r")
MsgBox Script.ReadLine()
```
 
<<<>>>
 
Description:
 
Demonstrates the usage of the standard input/output streams.
 
 
Code:
 
```ahkv2
DllCall("AllocConsole")
stdin  := FileOpen("*", "r")
stdout := FileOpen("*", "w")
stdout.Write("Enter your query.`n\> ")
stdout.Read(0) 
query := RTrim(stdin.ReadLine(), "`n")
stdout.WriteLine("Your query was '" query "'. Have a nice day.")
stdout.Read(0) 
Sleep 5000
```
 
<<<>>>
 
Description:
 
Reads a text file into .
 
 
Code:
 
```ahkv2
MyText := FileRead("C:\My Documents\My File.txt")
```
 
<<<>>>
 
Description:
 
Quickly sorts the contents of a file.
 
 
Code:
 
```ahkv2
Contents := FileRead("C:\Address List.txt")
Contents := Sort(Contents)
FileDelete "C:\Address List (alphabetical).txt"
FileAppend Contents, "C:\Address List (alphabetical).txt"
Contents := "" 
```
 
<<<>>>
 
Description:
 
Allows the user to select an existing .txt or .doc file.
 
 
Code:
 
```ahkv2
SelectedFile := FileSelect(3, , "Open a file", "Text Documents (*.txt; *.doc)")
if SelectedFile = ""
    MsgBox "The dialog was canceled."
else
    MsgBox "The following file was selected:`n" SelectedFile
```
 
<<<>>>
 
Description:
 
Allows the user to select multiple existing files.
 
 
Code:
 
```ahkv2
SelectedFiles := FileSelect("M3")  
if SelectedFiles.Length = 0
{
    MsgBox "The dialog was canceled."
    return
}
for FileName in SelectedFiles
{
    Result := MsgBox("File #" A_Index " of " SelectedFiles.Length ":`n" FileName "`n`nContinue?",, "YN")
    if Result = "No"
        break
}
```
 
<<<>>>
 
Description:
 
Allows the user to select a folder.
 
 
Code:
 
```ahkv2
SelectedFolder := FileSelect("D", , "Select a folder")
if SelectedFolder = ""
    MsgBox "The dialog was canceled."
else
    MsgBox "The following folder was selected:`n" SelectedFolder
```
 
<<<>>>
 
Description:
 
Demonstrates the behavior of  in detail.
 
 
Code:
 
```ahkv2
try
{
    ToolTip "Working..."
    Example1()
}
catch as e
{
 
    MsgBox(Type(e) " thrown!`n`nwhat: " e.what "`nfile: " e.file
        . "`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra,, 16)
}
finally
{
    ToolTip 
}
MsgBox "Done!"
Example1()
{
    try
        Example2()
    finally
        MsgBox "This is always executed regardless of exceptions"
}
Example2()
{
    if Mod(A_Min, 2)
        throw Error("That's odd...")
    MsgBox "Example2 did not fail"
}
```
 
<<<>>>
 
Description:
 
Lists the properties owned by an object.
 
 
Code:
 
```ahkv2
colours := {red: 0xFF0000, blue: 0x0000FF, green: 0x00FF00}
s := ""
for k, v in colours.OwnProps()
    s .= k "=" v "`n"
MsgBox s
```
 
<<<>>>
 
Description:
 
Lists all open Explorer and Internet Explorer windows, using the Shell object.
 
 
Code:
 
```ahkv2
windows := ""
for window in ComObject("Shell.Application").Windows
    windows .= window.LocationName " :: " window.LocationURL "`n"
MsgBox windows
```
 
<<<>>>
 
Description:
 
Defines an enumerator as a fat arrow function. Returns numbers from the Fibonacci sequence, indefinitely or until stopped.
 
 
Code:
 
```ahkv2
for n in FibF()
    if MsgBox("#" A_Index " = " n "`nContinue?",, "y/n") = "No"
        break
FibF() {
    a := 0, b := 1
    return (&n) => (
        n := c := b, b += a, a := c,
        true
    )
}
```
 
<<<>>>
 
Description:
 
Defines an enumerator as a class. Equivalent to the previous example.
 
 
Code:
 
```ahkv2
for n in FibC()
    if MsgBox("#" A_Index " = " n "`nContinue?",, "y/n") = "No"
        break
class FibC {
    a := 0, b := 1
    Call(&n) {
        n := c := this.b, this.b += this.a, this.a := c
        return true
    }
}
```
 
<<<>>>
 
Description:
 
Demonstrates different usages.
 
 
Code:
 
```ahkv2
s := ""
s .= Format("{2}, {1}!`r`n", "World", "Hello")
s .= Format("|{:-10}|`r`n|{:10}|`r`n", "Left", "Right")
s .= Format("{1:#x} {2:X} 0x{3:x}`r`n", 3735928559, 195948557, 0)
s .= Format("{1:0.3f} {1:.10f}", 4*ATan(1))
ListVars  
WinWaitActive "ahk_class AutoHotkey"
ControlSetText(s, "Edit1")
WinWaitClose
```
 
<<<>>>
 
Description:
 
Demonstrates different usages.
 
 
Code:
 
```ahkv2
TimeString := FormatTime()
MsgBox "The current time and date (time first) is " TimeString
TimeString := FormatTime("R")
MsgBox "The current time and date (date first) is " TimeString
TimeString := FormatTime(, "Time")
MsgBox "The current time is " TimeString
TimeString := FormatTime("T12", "Time")
MsgBox "The current 24-hour time is " TimeString
TimeString := FormatTime(, "LongDate")
MsgBox "The current date (long format) is " TimeString
TimeString := FormatTime(20050423220133, "dddd MMMM d, yyyy hh:mm:ss tt")
MsgBox "The specified date and time, when formatted, is " TimeString
MsgBox FormatTime(200504, "'Month Name': MMMM`n'Day Name': dddd")
YearWeek := FormatTime(20050101, "YWeek")
MsgBox "January 1st of 2005 is in the following ISO year and week number: " YearWeek
```
 
<<<>>>
 
Description:
 
Changes the date-time stamp of a file.
 
 
Code:
 
```ahkv2
FileName := FileSelect(3,, "Pick a file")
if FileName = "" 
    return
FileTime := FileGetTime(FileName)
FileTime := FormatTime(FileTime)   
MsgBox "The selected file was last modified at " FileTime
```
 
<<<>>>
 
Description:
 
Converts the specified number of seconds into the corresponding number of hours, minutes, and seconds (hh:mm:ss format).
 
 
Code:
 
```ahkv2
MsgBox FormatSeconds(7384)  
FormatSeconds(NumberOfSeconds)  
{
    time := 19990101  
    time := DateAdd(time, NumberOfSeconds, "Seconds")
    return NumberOfSeconds//3600 ":" FormatTime(time, "mm:ss")
 
}
```
 
<<<>>>
 
Description:
 
Retrieves and reports the English name of Esc.
 
 
Code:
 
```ahkv2
MsgBox GetKeyName("Esc") 
MsgBox GetKeyName("vk1B") 
```
 
<<<>>>
 
Description:
 
Retrieves and reports the hexadecimal virtual key code of Esc.
 
 
Code:
 
```ahkv2
vk_code := GetKeyVK("Esc")
MsgBox Format("vk{:X}", vk_code) 
```
 
<<<>>>
 
Description:
 
Retrieves and reports the hexadecimal scan code of the left Ctrl.
 
 
Code:
 
```ahkv2
sc_code := GetKeySC("LControl")
MsgBox Format("sc{:X}", sc_code) 
```
 
<<<>>>
 
Description:
 
Retrieves the current state of the right mouse button.
 
 
Code:
 
```ahkv2
state := GetKeyState("RButton")
```
 
<<<>>>
 
Description:
 
Retrieves the current state of the first controller's second button.
 
 
Code:
 
```ahkv2
state := GetKeyState("Joy2")
```
 
<<<>>>
 
Description:
 
Checks if at least one Shift is down.
 
 
Code:
 
```ahkv2
if GetKeyState("Shift")
    MsgBox "At least one Shift key is down."
else
    MsgBox "Neither Shift key is down."
```
 
<<<>>>
 
Description:
 
Retrieves the current toggle state of CapsLock.
 
 
Code:
 
```ahkv2
state := GetKeyState("CapsLock", "T")
```
 
<<<>>>
 
Description:
 
Remapping. (This example is only for illustration because it would be easier to use the built-in remapping feature.) In the following hotkey, the mouse button is kept held down while NumpadAdd is down, which effectively transforms NumpadAdd into a mouse button. This method can also be used to repeat an action while the user is holding down a key or button.
 
 
Code:
 
```ahkv2
*NumpadAdd::
{
    MouseClick "left",,, 1, 0, "D"  
    Loop
    {
        Sleep 10
        if !GetKeyState("NumpadAdd", "P")  
            break
 
    }
    MouseClick "left",,, 1, 0, "U"  
}
```
 
<<<>>>
 
Description:
 
Makes controller button behavior depend on stick axis position.
 
 
Code:
 
```ahkv2
joy2::
{
    JoyX := GetKeyState("JoyX")
    if JoyX > 75
        MsgBox "Action #1 (button pressed while stick was pushed to the right)."
    else if JoyX < 25
        MsgBox "Action #2 (button pressed while stick was pushed to the left)."
    else
        MsgBox "Action #3 (button pressed while stick was centered horizontally)."
}
```
 
<<<>>>
 
Description:
 
Creates a popup window.
 
 
Code:
 
```ahkv2
MyGui := Gui(, "Title of Window")
MyGui.Opt("+AlwaysOnTop +Disabled -SysMenu +Owner")  
MyGui.Add("Text",, "Some text to display.")
MyGui.Show("NoActivate")  
```
 
<<<>>>
 
Description:
 
Creates a simple input-box that asks for the first and last name.
 
 
Code:
 
```ahkv2
MyGui := Gui(, "Simple Input Example")
MyGui.Add("Text",, "First name:")
MyGui.Add("Text",, "Last name:")
MyGui.Add("Edit", "vFirstName ym")  
MyGui.Add("Edit", "vLastName")
MyGui.Add("Button", "default", "OK").OnEvent("Click", ProcessUserInput)
MyGui.OnEvent("Close", ProcessUserInput)
MyGui.Show()
ProcessUserInput(*)
{
    Saved := MyGui.Submit()  
    MsgBox("You entered '" Saved.FirstName " " Saved.LastName "'.")
}
```
 
<<<>>>
 
Description:
 
Creates a tab control with multiple tabs, each containing different controls to interact with.
 
 
Code:
 
```ahkv2
MyGui := Gui()
Tab := MyGui.Add("Tab3",, ["First Tab", "Second Tab", "Third Tab"])
MyGui.Add("CheckBox", "vMyCheckBox", "Sample checkbox") 
Tab.UseTab(2)
MyGui.Add("Radio", "vMyRadio", "Sample radio1")
MyGui.Add("Radio",, "Sample radio2")
Tab.UseTab(3)
MyGui.Add("Edit", "vMyEdit r5")  
Tab.UseTab()  
Btn := MyGui.Add("Button", "default xm", "OK")  
Btn.OnEvent("Click", ProcessUserInput)
MyGui.OnEvent("Close", ProcessUserInput)
MyGui.OnEvent("Escape", ProcessUserInput)
MyGui.Show()
ProcessUserInput(*)
{
    Saved := MyGui.Submit()  
    MsgBox("You entered:`n" Saved.MyCheckBox "`n" Saved.MyRadio "`n" Saved.MyEdit)
}
```
 
<<<>>>
 
Description:
 
Creates a ListBox control containing files in a directory.
 
 
Code:
 
```ahkv2
MyGui := Gui()
MyGui.Add("Text",, "Pick a file to launch from the list below.")
LB := MyGui.Add("ListBox", "w640 r10")
LB.OnEvent("DoubleClick", LaunchFile)
Loop Files, "C:\*.*"  
    LB.Add([A_LoopFilePath])
MyGui.Add("Button", "Default", "OK").OnEvent("Click", LaunchFile)
MyGui.Show()
LaunchFile(*)
{
    if MsgBox("Would you like to launch the file or document below?`n`n" LB.Text,, 4) = "No"
        return
 
    try Run(LB.Text)
    if A_LastError
        MsgBox("Could not launch the specified file. Perhaps it is not associated with anything.")
}
```
 
<<<>>>
 
Description:
 
Displays a context-sensitive help (via ToolTip) whenever the user moves the mouse over a particular control.
 
 
Code:
 
```ahkv2
MyGui := Gui()
MyEdit := MyGui.Add("Edit")
MyEdit.ToolTip := "This is a tooltip for the control whose name is MyEdit."
MyDDL := MyGui.Add("DropDownList",, ["Red", "Green", "Blue"])
MyDDL.ToolTip := "Choose a color from the drop-down list."
MyGui.Add("CheckBox",, "This control has no tooltip.")
MyGui.Show()
OnMessage(0x0200, On_WM_MOUSEMOVE)
On_WM_MOUSEMOVE(wParam, lParam, msg, Hwnd)
{
    static PrevHwnd := 0
    if (Hwnd != PrevHwnd)
    {
        Text := "", ToolTip() 
        CurrControl := GuiCtrlFromHwnd(Hwnd)
        if CurrControl
        {
            if !CurrControl.HasProp("ToolTip")
                return 
            Text := CurrControl.ToolTip
            SetTimer () => ToolTip(Text), -1000
            SetTimer () => ToolTip(), -4000 
        }
        PrevHwnd := Hwnd
    }
}
```
 
<<<>>>
 
Description:
 
Creates an On-screen display (OSD) via transparent window.
 
 
Code:
 
```ahkv2
MyGui := Gui()
MyGui.Opt("+AlwaysOnTop -Caption +ToolWindow")  
MyGui.BackColor := "EEAA99"  
MyGui.SetFont("s32")  
CoordText := MyGui.Add("Text", "cLime", "XXXXX YYYYY")  
WinSetTransColor(MyGui.BackColor " 150", MyGui)
SetTimer(UpdateOSD, 200)
UpdateOSD()  
MyGui.Show("x0 y400 NoActivate")  
UpdateOSD(*)
{
    MouseGetPos &MouseX, &MouseY
    CoordText.Value := "X" MouseX ", Y" MouseY
}
```
 
<<<>>>
 
Description:
 
Creates a moving progress bar overlayed on a background image.
 
 
Code:
 
```ahkv2
MyGui := Gui()
MyGui.BackColor := "White"
MyGui.Add("Picture", "x0 y0 h350 w450", A_WinDir "\Web\Wallpaper\Windows\img0.jpg")
MyBtn := MyGui.Add("Button", "Default xp+20 yp+250", "Start the Bar Moving")
MyBtn.OnEvent("Click", MoveBar)
MyProgress := MyGui.Add("Progress", "w416")
MyText := MyGui.Add("Text", "wp")  
MyGui.Show()
MoveBar(*)
{
    Loop Files, A_WinDir "\*.*", "R"
    {
        if (A_Index > 100)
            break
        MyProgress.Value := A_Index
        MyText.Value := A_LoopFileName
        Sleep 50
    }
    MyText.Value := "Bar finished."
}
```
 
<<<>>>
 
Description:
 
Creates a simple image viewer.
 
 
Code:
 
```ahkv2
MyGui := Gui("+Resize")
MyBtn := MyGui.Add("Button", "default", "&Load New Image")
MyBtn.OnEvent("Click", LoadNewImage)
MyRadio := MyGui.Add("Radio", "ym+5 x+10 checked", "Load &actual size")
MyGui.Add("Radio", "ym+5 x+10", "Load to &fit screen")
MyPic := MyGui.Add("Pic", "xm")
MyGui.Show()
LoadNewImage(*)
{
    Image := FileSelect(,, "Select an image:", "Images (*.gif; *.jpg; *.bmp; *.png; *.tif; *.ico; *.cur; *.ani; *.exe; *.dll)")
    if Image = ""
        return
    if (MyRadio.Value)  
    {
        Width := 0
        Height := 0
    }
    else 
    {
        Width := A_ScreenWidth - 28  
        Height := -1  
    }
    MyPic.Value := Format("*w{1} *h{2} {3}", Width, Height, Image)  
    MyGui.Title := Image
    MyGui.Show("xCenter y0 AutoSize")  
}
```
 
<<<>>>
 
Description:
 
Creates a simple text editor with menu bar.
 
 
Code:
 
```ahkv2
MyGui := Gui("+Resize", "Untitled")  
FileMenu := Menu()
FileMenu.Add("&New", MenuFileNew)
FileMenu.Add("&Open", MenuFileOpen)
FileMenu.Add("&Save", MenuFileSave)
FileMenu.Add("Save &As", MenuFileSaveAs)
FileMenu.Add() 
FileMenu.Add("E&xit", MenuFileExit)
HelpMenu := Menu()
HelpMenu.Add("&About", MenuHelpAbout)
MyMenuBar := MenuBar()
MyMenuBar.Add("&File", FileMenu)
MyMenuBar.Add("&Help", HelpMenu)
MyGui.MenuBar := MyMenuBar
MainEdit := MyGui.Add("Edit", "WantTab W600 R20")
MyGui.OnEvent("DropFiles", Gui_DropFiles)
MyGui.OnEvent("Size", Gui_Size)
MenuFileNew()  
MyGui.Show()  
MenuFileNew(*)
{
    MainEdit.Value := ""  
    FileMenu.Disable("3&")  
    MyGui.Title := "Untitled"
}
MenuFileOpen(*)
{
    MyGui.Opt("+OwnDialogs")  
    SelectedFileName := FileSelect(3,, "Open File", "Text Documents (*.txt)")
    if SelectedFileName = "" 
        return
    global CurrentFileName := readContent(SelectedFileName)
}
MenuFileSave(*)
{
    saveContent(CurrentFileName)
}
MenuFileSaveAs(*)
{
    MyGui.Opt("+OwnDialogs")  
    SelectedFileName := FileSelect("S16",, "Save File", "Text Documents (*.txt)")
    if SelectedFileName = "" 
        return
    global CurrentFileName := saveContent(SelectedFileName)
}
MenuFileExit(*)  
{
    WinClose()
}
MenuHelpAbout(*)
{
    About := Gui("+owner" MyGui.Hwnd)  
    MyGui.Opt("+Disabled")  
    About.Add("Text",, "Text for about box.")
    About.Add("Button", "Default", "OK").OnEvent("Click", About_Close)
    About.OnEvent("Close", About_Close)
    About.OnEvent("Escape", About_Close)
    About.Show()
    About_Close(*)
    {
        MyGui.Opt("-Disabled")  
        About.Destroy()  
    }
}
readContent(FileName)
{
    try
        FileContent := FileRead(FileName)  
    catch
    {
        MsgBox("Could not open '" FileName "'.")
        return
    }
    MainEdit.Value := FileContent  
    FileMenu.Enable("3&")  
    MyGui.Title := FileName  
    return FileName
}
saveContent(FileName)
{
    try
    {
        if FileExist(FileName)
            FileDelete(FileName)
        FileAppend(MainEdit.Value, FileName)  
    }
    catch
    {
        MsgBox("The attempt to overwrite '" FileName "' failed.")
        return
    }
 
    MyGui.Title := FileName
    return FileName
}
Gui_DropFiles(thisGui, Ctrl, FileArray, *)  
{
    CurrentFileName := readContent(FileArray[1])  
}
Gui_Size(thisGui, MinMax, Width, Height)
{
    if MinMax = -1  
        return
 
    MainEdit.Move(,, Width-20, Height-20)
}
```
 
<<<>>>
 
Description:
 
Demonstrates problems caused by reference cycles.
 
 
Code:
 
```ahkv2
; Click Open or double-click tray icon to show another GUI.
; Use the menu items, Escape or Close button to see how it responds.
A_TrayMenu.Add("&Open", ShowRefCycleGui)
Persistent
ShowRefCycleGui(*) {
    static n := 0
    g := Gui(, "GUI #" (++n)), g.n := n
    g.MenuBar := mb := MenuBar()   
    mb.Add("Gui", m := Menu())     
    m.Add("Hide", (*) => g.Hide()) 
    m.Add("Destroy", (*) => g.Destroy())
 
    g.OnEvent("Escape", (g, *) => g.Hide())
 
    g.OnEvent("Close", (*) => g := unset)
    g.Show("w300 h200")
 
    g.__Delete := this => MsgBox("GUI #" this.n " deleted")
}
```
 
<<<>>>
 
Description:
 
Similar to #HotIf example #1, this creates two hotkeys and one hotstring which only work when Notepad is active, and one hotkey which works for any window except Notepad. The main difference is that this example creates context-sensitive hotkeys and hotstrings at runtime, while the #HotIf example creates them at loadtime.
 
 
Code:
 
```ahkv2
HotIfWinActive "ahk_class Notepad"
Hotkey "^!a", ShowMsgBox
Hotkey "#c", ShowMsgBox
Hotstring "::btw", "This replacement text will occur only in Notepad."
HotIfWinActive
Hotkey "#c", (*) => MsgBox("You pressed Win-C in a window other than Notepad.")
ShowMsgBox(HotkeyName)
{
    MsgBox "You pressed " HotkeyName " while Notepad is active."
}
```
 
<<<>>>
 
Description:
 
Similar to the example above, but with a callback.
 
 
Code:
 
```ahkv2
HotIf MyCallback
Hotkey "^!a", ShowMsgBox
Hotkey "#c", ShowMsgBox
Hotstring "::btw", "This replacement text will occur only in Notepad."
HotIf
Hotkey "#c", (*) => MsgBox("You pressed Win-C in a window other than Notepad.")
MyCallback(*)
{
    if WinActive("ahk_class Notepad")
        return true
    else
        return false
}
ShowMsgBox(HotkeyName)
{
    MsgBox "You pressed " HotkeyName " while Notepad is active."
}
```
 
<<<>>>
 
Description:
 
Creates a Ctrl-Alt-Z hotkey.
 
 
Code:
 
```ahkv2
Hotkey "^!z", MyFunc
MyFunc(ThisHotkey)
{
    MsgBox "You pressed " ThisHotkey
}
```
 
<<<>>>
 
Description:
 
Makes RCtrl & RShift operate like Alt-Tab.
 
 
Code:
 
```ahkv2
Hotkey "RCtrl & RShift", "AltTab"
```
 
<<<>>>
 
Description:
 
Disables the Shift-Win-C hotkey.
 
 
Code:
 
```ahkv2
Hotkey "$+#c", "Off"
```
 
<<<>>>
 
Description:
 
Changes a hotkey to allow 5 threads.
 
 
Code:
 
```ahkv2
Hotkey "^!a",, "T5"
```
 
<<<>>>
 
Description:
 
Creates Alt+W as a hotkey that works only in Notepad.
 
 
Code:
 
```ahkv2
HotIfWinActive "ahk_class Notepad"
Hotkey "!w", ToggleWordWrap  
ToggleWordWrap(ThisHotkey)
{
    MenuSelect "A",, "Format", "Word Wrap"
}
```
 
<<<>>>
 
Description:
 
Creates a GUI that allows to register primitive three-key combination hotkeys.
 
 
Code:
 
```ahkv2
HkGui := Gui()
HkGui.Add("Text", "xm", "Prefix key:")
HkGui.Add("Edit", "yp x100 w100 vPrefix", "Space")
HkGui.Add("Text", "xm", "Suffix hotkey:")
HkGui.Add("Edit", "yp x100 w100 vSuffix", "f & j")
HkGui.Add("Button", "Default", "Register").OnEvent("Click", RegisterHotkey)
HkGui.OnEvent("Close", (*) => ExitApp())
HkGui.OnEvent("Escape", (*) => ExitApp())
HkGui.Show()
RegisterHotkey(*)
{
    Saved := HkGui.Submit(false)
    HotIf (*) => GetKeyState(Saved.Prefix)
    Hotkey Saved.Suffix, (ThisHotkey) => MsgBox(ThisHotkey)
}
```
 
<<<>>>
 
Description:
 
Hotstring Helper. The following script might be useful if you are a heavy user of hotstrings. It's based on the v1 script created by Andreas Borutta. By pressing Win+H (or another hotkey of your choice), the currently selected text can be turned into a hotstring. For example, if you have "by the way" selected in a word processor, pressing Win+H will prompt you for its abbreviation (e.g. btw), add the new hotstring to the script and activate it.
 
 
Code:
 
```ahkv2
#h::  
{
 
    ClipboardOld := A_Clipboard
    A_Clipboard := "" 
    Send "^c"
    if !ClipWait(1)  
    {
        A_Clipboard := ClipboardOld 
        return
    }
 
    ClipContent := StrReplace(A_Clipboard, "``", "````")  
    ClipContent := StrReplace(ClipContent, "`r`n", "``n")
    ClipContent := StrReplace(ClipContent, "`n", "``n")
    ClipContent := StrReplace(ClipContent, "`t", "``t")
    ClipContent := StrReplace(ClipContent, "`;", "```;")
    A_Clipboard := ClipboardOld  
    ShowInputBox(":T:::" ClipContent)
}
ShowInputBox(DefaultValue)
{
 
    SetTimer MoveCaret, 10
 
    IB := InputBox("
    (
    Type your abbreviation at the indicated insertion point. You can also edit the replacement text if you wish.
    Example entry: :T:btw::by the way
    )", "New Hotstring",, DefaultValue)
    if IB.Result = "Cancel"  
        return
    if RegExMatch(IB.Value, "(?P<Label>:.*?:(?P<Abbreviation>.*?))::(?P<Replacement>.*)", &Entered)
    {
        if !Entered.Abbreviation
            MsgText := "You didn't provide an abbreviation"
        else if !Entered.Replacement
            MsgText := "You didn't provide a replacement"
        else
        {
            Hotstring Entered.Label, Entered.Replacement  
            FileAppend "`n" IB.Value, A_ScriptFullPath  
        }
    }
    else
        MsgText := "The hotstring appears to be improperly formatted"
    if IsSet(MsgText)
    {
        Result := MsgBox(MsgText ". Would you like to try again?",, 4)
        if Result = "Yes"
            ShowInputBox(DefaultValue)
    }
 
    MoveCaret()
    {
        WinWait "New Hotstring"
 
        Send "{Home}{Right 3}"
        SetTimer , 0
    }
}
```
 
<<<>>>
 
Description:
 
If A_Index is greater than 100, return.
 
 
Code:
 
```ahkv2
if (A_Index > 100)
    return
```
 
<<<>>>
 
Description:
 
If the result of A_TickCount - StartTime is greater than the result of 2*MaxTime + 100, show "Too much time has passed." and terminate the script.
 
 
Code:
 
```ahkv2
if (A_TickCount - StartTime > 2*MaxTime + 100)
{
    MsgBox "Too much time has passed."
    ExitApp
}
```
 
<<<>>>
 
Description:
 
This example is executed as follows:
  If Color is the word "Blue" or "White":
 
      Show "The color is one of the allowed values.".
      Terminate the script.
 
 
  Otherwise if Color is the word "Silver":
 
      Show "Silver is not an allowed color.".
      Stop further checks.
 
 
  Otherwise:
 
      Show "This color is not recognized.".
      Terminate the script.
 
 
if (Color = "Blue" or Color = "White")
{
    MsgBox "The color is one of the allowed values."
    ExitApp
}
else if (Color = "Silver")
{
    MsgBox "Silver is not an allowed color."
    return
}
else
{
    MsgBox "This color is not recognized."
    ExitApp
}
 A single multi-statement line does not need to be enclosed in braces.
 
 
Code:
 
```ahkv2
MyVar := 3
if (MyVar > 2)
    MyVar++, MyVar := MyVar - 4, MyVar .= " test"
MsgBox MyVar  
```
 
<<<>>>
 
Description:
 
Similar to AutoHotkey v1's If Var [not] between Lower and Upper, the following examples check whether a variable's contents are numerically or alphabetically between two values (inclusive).
Checks whether var is in the range 1 to 5:
 
 
Code:
 
```ahkv2
if (var >= 1 and var <= 5)
    MsgBox var " is in the range 1 to 5, inclusive."
```
 
<<<>>>
 
Description:
 
Similar to AutoHotkey v1's If Var [not] in/contains MatchList, the following examples check whether a variable's contents match one of the items in a list.
Checks whether var is the file extension exe, bat or com:
 
 
Code:
 
```ahkv2
if (var ~= "i)\A(exe|bat|com)\z")
    MsgBox "The file extension is an executable type."
```
 
<<<>>>
 
Description:
 
Selects or de-selects all rows by specifying 0 as the row number.
 
 
Code:
 
```ahkv2
LV.Modify(0, "Select")   
LV.Modify(0, "-Select")  
LV.Modify(0, "-Check")  
```
 
<<<>>>
 
Description:
 
Auto-sizes all columns to fit their contents.
 
 
Code:
 
```ahkv2
LV.ModifyCol()  
```
 
<<<>>>
 
Description:
 
Displays the files in a folder chosen by the user, with each file assigned the icon associated with its type. The user can double-click a file, or right-click one or more files to display a context menu.
 
 
Code:
 
```ahkv2
MyGui := Gui("+Resize")  
B1 := MyGui.Add("Button", "Default", "Load a folder")
B2 := MyGui.Add("Button", "x+20", "Clear List")
B3 := MyGui.Add("Button", "x+20", "Switch View")
LV := MyGui.Add("ListView", "xm r20 w700", ["Name", "In Folder", "Size (KB)", "Type"])
LV.ModifyCol(3, "Integer")  
ImageListID1 := IL_Create(10)
ImageListID2 := IL_Create(10, 10, true)  
LV.SetImageList(ImageListID1)
LV.SetImageList(ImageListID2)
LV.OnEvent("DoubleClick", RunFile)
LV.OnEvent("ContextMenu", ShowContextMenu)
B1.OnEvent("Click", LoadFolder)
B2.OnEvent("Click", (*) => LV.Delete())
B3.OnEvent("Click", SwitchView)
MyGui.OnEvent("Size", Gui_Size)
ContextMenu := Menu()
ContextMenu.Add("Open", ContextOpenOrProperties)
ContextMenu.Add("Properties", ContextOpenOrProperties)
ContextMenu.Add("Clear from ListView", ContextClearRows)
ContextMenu.Default := "Open"  
MyGui.Show()
LoadFolder(*)
{
    static IconMap := Map()
    MyGui.Opt("+OwnDialogs")  
    Folder := DirSelect(, 3, "Select a folder to read:")
    if not Folder  
        return
 
    if SubStr(Folder, -1, 1) = "\"
        Folder := SubStr(Folder, 1, -1)  
 
    sfi_size := A_PtrSize + 688
    sfi := Buffer(sfi_size)
 
    LV.Opt("-Redraw")  
    Loop Files, Folder "\*.*"
    {
        FileName := A_LoopFilePath  
 
        SplitPath(FileName,,, &FileExt)  
        if FileExt ~= "i)\A(EXE|ICO|ANI|CUR)\z"
        {
            ExtID := FileExt  
            IconNumber := 0  
        }
        else  
        {
            ExtID := 0  
            Loop 7     
            {
                ExtChar := SubStr(FileExt, A_Index, 1)
                if not ExtChar  
                    break
 
                ExtID := ExtID | (Ord(ExtChar) << (8 * (A_Index - 1)))
            }
 
            IconNumber := IconMap.Has(ExtID) ? IconMap[ExtID] : 0
        }
        if not IconNumber  
        {
 
            if not DllCall("Shell32\SHGetFileInfoW", "Str", FileName
            , "Uint", 0, "Ptr", sfi, "UInt", sfi_size, "UInt", 0x101)  
                IconNumber := 9999999  
            else 
            {
 
                hIcon := NumGet(sfi, 0, "Ptr")
 
                IconNumber := DllCall("ImageList_ReplaceIcon", "Ptr", ImageListID1, "Int", -1, "Ptr", hIcon) + 1
                DllCall("ImageList_ReplaceIcon", "Ptr", ImageListID2, "Int", -1, "Ptr", hIcon)
 
                DllCall("DestroyIcon", "Ptr", hIcon)
 
                IconMap[ExtID] := IconNumber
            }
        }
 
        LV.Add("Icon" . IconNumber, A_LoopFileName, A_LoopFileDir, A_LoopFileSizeKB, FileExt)
    }
    LV.Opt("+Redraw")  
    LV.ModifyCol()  
    LV.ModifyCol(3, 60)  
}
SwitchView(*)
{
    static IconView := false
    if not IconView
        LV.Opt("+Icon")        
    else
        LV.Opt("+Report")      
    IconView := not IconView   
}
RunFile(LV, RowNumber)
{
    FileName := LV.GetText(RowNumber, 1) 
    FileDir := LV.GetText(RowNumber, 2)  
    try
        Run(FileDir "\" FileName)
    catch
        MsgBox("Could not open " FileDir "\" FileName ".")
}
ShowContextMenu(LV, Item, IsRightClick, X, Y)  
{
 
    ContextMenu.Show(X, Y)
}
ContextOpenOrProperties(ItemName, *)  
{
 
    FocusedRowNumber := LV.GetNext(0, "F")  
    if not FocusedRowNumber  
        return
    FileName := LV.GetText(FocusedRowNumber, 1) 
    FileDir := LV.GetText(FocusedRowNumber, 2)  
    try
    {
        if (ItemName = "Open")  
            Run(FileDir "\" FileName)
        else
            Run("properties " FileDir "\" FileName)
    }
    catch
        MsgBox("Could not perform requested action on " FileDir "\" FileName ".")
}
ContextClearRows(*)  
{
    RowNumber := 0  
    Loop
    {
 
        RowNumber := LV.GetNext(RowNumber - 1)
        if not RowNumber  
            break
        LV.Delete(RowNumber)  
    }
}
Gui_Size(thisGui, MinMax, Width, Height)  
{
    if MinMax = -1  
        return
 
    LV.Move(,, Width - 20, Height - 40)
}
```
 
<<<>>>
 
Description:
 
The following is a working script that is more elaborate than the one near the top of this page. It creates and displays a TreeView containing all folders in the all-users Start Menu. When the user selects a folder, its contents are shown in a ListView to the right (like Windows Explorer). In addition, a StatusBar control shows information about the currently selected folder.
 
 
Code:
 
```ahkv2
TreeRoot := A_MyDocuments
TreeViewWidth := 280
ListViewWidth := A_ScreenWidth/2 - TreeViewWidth - 30
MyGui := Gui("+Resize", TreeRoot)  
ImageListID := IL_Create(5)
Loop 5 
    IL_Add(ImageListID, "shell32.dll", A_Index)
TV := MyGui.Add("TreeView", "r20 w" TreeViewWidth " ImageList" ImageListID)
LV := MyGui.Add("ListView", "r20 w" ListViewWidth " x+10", ["Name", "Modified"])
SB := MyGui.Add("StatusBar")
SB.SetParts(60, 85)  
M := Gui("ToolWindow -SysMenu Disabled AlwaysOnTop", "Loading the tree..."), M.Show("w200 h0")
DirList := AddSubFoldersToTree(TreeRoot, Map())
M.Hide()
TV.OnEvent("ItemSelect", TV_ItemSelect)
MyGui.OnEvent("Size", Gui_Size)
Col2Width := 70  
LV.ModifyCol(1, ListViewWidth - Col2Width - 30)  
LV.ModifyCol(2, Col2Width)
MyGui.Show()
AddSubFoldersToTree(Folder, DirList, ParentItemID := 0)
{
 
    Loop Files, Folder "\*.*", "D"  
    {
        ItemID := TV.Add(A_LoopFileName, ParentItemID, "Icon4")
        DirList[ItemID] := A_LoopFilePath
        DirList := AddSubFoldersToTree(A_LoopFilePath, DirList, ItemID)
    }
    return DirList
}
TV_ItemSelect(thisCtrl, Item)  
{
 
    LV.Delete()  
    LV.Opt("-Redraw")  
    TotalSize := 0  
    Loop Files, DirList[Item] "\*.*"  
    {
        LV.Add(, A_LoopFileName, A_LoopFileTimeModified)
        TotalSize += A_LoopFileSize
    }
    LV.Opt("+Redraw")
 
    SB.SetText(LV.GetCount() " files", 1)
    SB.SetText(Round(TotalSize / 1024, 1) " KB", 2)
    SB.SetText(DirList[Item], 3)
}
Gui_Size(thisGui, MinMax, Width, Height)  
{
    if MinMax = -1  
        return
 
    TV.GetPos(,, &TV_W)
    TV.Move(,,, Height - 30)  
    LV.Move(,, Width - TV_W - 30, Height - 30)
}
```
 
<<<>>>
 
Description:
 
Searches a region of the active window for an image and stores in FoundX and FoundY the X and Y coordinates of the upper-left pixel of where the image was found.
 
 
Code:
 
```ahkv2
ImageSearch &FoundX, &FoundY, 40, 40, 300, 300, "C:\My Images\test.bmp"
```
 
<<<>>>
 
Description:
 
Searches a region of the screen for an image and stores in FoundX and FoundY the X and Y coordinates of the upper-left pixel of where the image was found, including advanced error handling.
 
 
Code:
 
```ahkv2
CoordMode "Pixel"  
try
{
    if ImageSearch(&FoundX, &FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, "*Icon3 " A_ProgramFiles "\SomeApp\SomeApp.exe")
        MsgBox "The icon was found at " FoundX "x" FoundY
    else
        MsgBox "Icon could not be found on the screen."
}
catch as exc
    MsgBox "Could not conduct the search due to the following error:`n" exc.Message
```
 
<<<>>>
 
Description:
 
Deletes a key and its value located in section2 from a standard format .ini file.
 
 
Code:
 
```ahkv2
IniDelete "C:\Temp\myfile.ini", "section2", "key"
```
 
<<<>>>
 
Description:
 
Reads the value of a key located in section2 from a standard format .ini file and stores it in Value.
 
 
Code:
 
```ahkv2
Value := IniRead("C:\Temp\myfile.ini", "section2", "key")
MsgBox "The value is " Value
```
 
<<<>>>
 
Description:
 
Writes a value to a key located in section2 of a standard format .ini file.
 
 
Code:
 
```ahkv2
IniWrite "this is a new value", "C:\Temp\myfile.ini", "section2", "key"
```
 
<<<>>>
 
Description:
 
Allows the user to enter a hidden password.
 
 
Code:
 
```ahkv2
password := InputBox("(your input will be hidden)", "Enter Password", "password").value
```
 
<<<>>>
 
Description:
 
Allows the user to enter a phone number.
 
 
Code:
 
```ahkv2
IB := InputBox("Please enter a phone number.", "Phone Number", "w640 h480")
if IB.Result = "Cancel"
    MsgBox "You entered '" IB.Value "' but then cancelled."
else
    MsgBox "You entered '" IB.Value "'."
```
 
<<<>>>
 
Description:
 
Waits for the user to press any single key.
 
 
Code:
 
```ahkv2
MsgBox KeyWaitAny()
MsgBox KeyWaitAny("V")
KeyWaitAny(Options:="")
{
    ih := InputHook(Options)
    if !InStr(Options, "V")
        ih.VisibleNonText := false
    ih.KeyOpt("{All}", "E")  
    ih.Start()
    ih.Wait()
    return ih.EndKey  
}
```
 
<<<>>>
 
Description:
 
Waits for any key in combination with Ctrl/Alt/Shift/Win.
 
 
Code:
 
```ahkv2
MsgBox KeyWaitCombo()
KeyWaitCombo(Options:="")
{
    ih := InputHook(Options)
    if !InStr(Options, "V")
        ih.VisibleNonText := false
    ih.KeyOpt("{All}", "E")  
 
    ih.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-E")
    ih.Start()
    ih.Wait()
    return ih.EndMods . ih.EndKey  
}
```
 
<<<>>>
 
Description:
 
Simple auto-complete: any day of the week.  Pun aside, this is a mostly functional example.  Simply run the script and start typing today, press Tab to complete or press Esc to exit.
 
 
Code:
 
```ahkv2
WordList := "Monday`nTuesday`nWednesday`nThursday`nFriday`nSaturday`nSunday"
Suffix := ""
SacHook := InputHook("V", "{Esc}")
SacHook.OnChar := SacChar
SacHook.OnKeyDown := SacKeyDown
SacHook.KeyOpt("{Backspace}", "N")
SacHook.Start()
SacChar(ih, char)  
{
    global Suffix := ""
    if RegExMatch(ih.Input, "`nm)\w+$", &prefix)
        && RegExMatch(WordList, "`nmi)^" prefix[0] "\K.*", &Suffix)
        Suffix := Suffix[0]
 
    if CaretGetPos(&cx, &cy)
        ToolTip Suffix, cx + 15, cy
    else
        ToolTip Suffix
 
    ih.KeyOpt("{Tab}", Suffix = "" ? "-NS" : "+NS")
}
SacKeyDown(ih, vk, sc)
{
    if (vk = 8) 
        SacChar(ih, "")
    else if (vk = 9) 
        Send "{Text}" Suffix
}
```
 
<<<>>>
 
Description:
 
Waits for the user to press any key. Keys that produce no visible character -- such as the modifier keys, function keys, and arrow keys -- are listed as end keys so that they will be detected too.
 
 
Code:
 
```ahkv2
ih := InputHook("L1", "{LControl}{RControl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}{AppsKey}{F1}{F2}{F3}{F4}{F5}{F6}{F7}{F8}{F9}{F10}{F11}{F12}{Left}{Right}{Up}{Down}{Home}{End}{PgUp}{PgDn}{Del}{Ins}{BS}{CapsLock}{NumLock}{PrintScreen}{Pause}")
ih.Start()
ih.Wait()
```
 
<<<>>>
 
Description:
 
This is a working hotkey example. Since the hotkey has the tilde (~) prefix, its own keystroke will pass through to the active window. Thus, if you type [btw (or one of the other match phrases) in any editor, the script will automatically perform an action of your choice (such as replacing the typed text). For an alternative version of this example, see Switch.
 
 
Code:
 
```ahkv2
~[::
{
    msg := ""
    ih := InputHook("V T5 L4 C", "{enter}.{esc}{tab}", "btw,otoh,fl,ahk,ca")
    ih.Start()
    ih.Wait()
    if (ih.EndReason = "Max")
        msg := 'You entered "{1}", which is the maximum length of text.'
    else if (ih.EndReason = "Timeout")
        msg := 'You entered "{1}" at which time the input timed out.'
    else if (ih.EndReason = "EndKey")
        msg := 'You entered "{1}" and terminated the input with {2}.'
    if msg  
    {
        MsgBox Format(msg, ih.Input, ih.EndKey)
        return
    }
 
    if (ih.Input = "btw")
        Send("{backspace 4}by the way")
    else if (ih.Input = "otoh")
        Send("{backspace 5}on the other hand")
    else if (ih.Input = "fl")
        Send("{backspace 3}Florida")
    else if (ih.Input = "ca")
        Send("{backspace 3}California")
    else if (ih.Input = "ahk")
        Run("https://www.autohotkey.com")
}
```
 
<<<>>>
 
Description:
 
Installs the keyboard hook unconditionally.
 
 
Code:
 
```ahkv2
InstallKeybdHook
```
 
<<<>>>
 
Description:
 
Installs the mouse hook unconditionally.
 
 
Code:
 
```ahkv2
InstallMouseHook
```
 
<<<>>>
 
Description:
 
Reports the 1-based position of the substring "abc" in the string "123abc789".
 
 
Code:
 
```ahkv2
MsgBox InStr("123abc789", "abc") 
```
 
<<<>>>
 
Description:
 
Searches for Needle in Haystack.
 
 
Code:
 
```ahkv2
Haystack := "The Quick Brown Fox Jumps Over the Lazy Dog"
Needle := "Fox"
If InStr(Haystack, Needle)
    MsgBox "The string was found."
Else
    MsgBox "The string was not found."
```
 
<<<>>>
 
Description:
 
Demonstrates the difference between a case-insensitive and case-sensitive search.
 
 
Code:
 
```ahkv2
Haystack := "The Quick Brown Fox Jumps Over the Lazy Dog"
Needle := "the"
MsgBox InStr(Haystack, Needle, false, 1, 2) 
MsgBox InStr(Haystack, Needle, true) 
```
 
<<<>>>
 
Description:
 
Displays the history info in a window.
 
 
Code:
 
```ahkv2
KeyHistory
```
 
<<<>>>
 
Description:
 
Causes KeyHistory to display the last 100 instead 40 keyboard and mouse events.
 
 
Code:
 
```ahkv2
KeyHistory 100
```
 
<<<>>>
 
Description:
 
Disables key history entirely.
 
 
Code:
 
```ahkv2
KeyHistory 0
```
 
<<<>>>
 
Description:
 
Waits for the A key to be released.
 
 
Code:
 
```ahkv2
KeyWait "a"
```
 
<<<>>>
 
Description:
 
Waits for the left mouse button to be pressed down.
 
 
Code:
 
```ahkv2
KeyWait "LButton", "D"
```
 
<<<>>>
 
Description:
 
Waits up to 3 seconds for the first controller button to be pressed down.
 
 
Code:
 
```ahkv2
KeyWait "Joy1", "D T3"
```
 
<<<>>>
 
Description:
 
Waits for the left Alt key to be logically released.
 
 
Code:
 
```ahkv2
KeyWait "LAlt", "L"
```
 
<<<>>>
 
Description:
 
When pressing this hotkey, KeyWait waits for the user to physically release the CapsLock key. As a result, subsequent statements are performed on release instead of press. This behavior is similar to ~CapsLock up::.
 
 
Code:
 
```ahkv2
~CapsLock::
{
    KeyWait "CapsLock"  
    MsgBox "You pressed and released the CapsLock key."
}
```
 
<<<>>>
 
Description:
 
Remaps a key or mouse button. (This example is only for illustration because it would be easier to use the built-in remapping feature.) In the following hotkey, the mouse button is kept held down while NumpadAdd is down, which effectively transforms NumpadAdd into a mouse button.
 
 
Code:
 
```ahkv2
*NumpadAdd::
{
    MouseClick "left",,, 1, 0, "D"  
    KeyWait "NumpadAdd"  
    MouseClick "left",,, 1, 0, "U"  
}
```
 
<<<>>>
 
Description:
 
Detects when a key has been double-pressed (similar to double-click). KeyWait is used to stop the keyboard's auto-repeat feature from creating an unwanted double-press when you hold down the RControl key to modify another key. It does this by keeping the hotkey's thread running, which blocks the auto-repeats by relying upon #MaxThreadsPerHotkey being at its default setting of 1. For a more elaborate script that distinguishes between single, double and triple-presses, see SetTimer example #3.
 
 
Code:
 
```ahkv2
~RControl::
{
    if (A_PriorHotkey != ThisHotkey or A_TimeSincePriorHotkey > 400)
    {
 
        KeyWait "RControl"
        return
    }
    MsgBox "You double-pressed the right control key."
}
```
 
<<<>>>
 
Description:
 
Displays information about the hotkeys used by the current script.
 
 
Code:
 
```ahkv2
ListHotkeys
```
 
<<<>>>
 
Description:
 
Installs the keyboard hook unconditionally.
 
 
Code:
 
```ahkv2
InstallKeybdHook
```
 
<<<>>>
 
Description:
 
Installs the mouse hook unconditionally.
 
 
Code:
 
```ahkv2
InstallMouseHook
```
 
<<<>>>
 
Description:
 
Enables and disables line logging for specific lines and then displays the result.
 
 
Code:
 
```ahkv2
x := "This line is logged"
ListLines False
x := "This line is not logged"
ListLines True
ListLines
MsgBox
```
 
<<<>>>
 
Description:
 
Displays information about the script's variables.
 
 
Code:
 
```ahkv2
var1 := "foo"
var2 := "bar"
obj := []
ListVars
Pause
```
 
<<<>>>
 
Description:
 
Extracts the individual rows and fields out of a ListView.
 
 
Code:
 
```ahkv2
List := ListViewGetContent("Selected", "SysListView321", WinTitle)
Loop Parse, List, "`n"  
{
    RowNumber := A_Index
    Loop Parse, A_LoopField, A_Tab  
        MsgBox "Row #" RowNumber " Col #" A_Index " is " A_LoopField
}
```
 
<<<>>>
 
Description:
 
Pre-loads and reuses some images.
 
 
Code:
 
```ahkv2
Pics := []
Loop Files, A_WinDir "\Web\Wallpaper\*.jpg", "R"
{
 
    Pics.Push(LoadPicture(A_LoopFileFullPath))
}
if !Pics.Length
{
 
    MsgBox("No pictures found! Try a different directory.")
    ExitApp
}
MyGui := Gui()
Pic := MyGui.Add("Pic", "w600 h-1 +Border", "HBITMAP:*" Pics[1])
MyGui.OnEvent("Escape", (*) => ExitApp())
MyGui.OnEvent("Close", (*) => ExitApp())
MyGui.Show()
Loop 
{
 
    Pic.Value := "HBITMAP:*" Pics[Mod(A_Index, Pics.Length)+1]
    Sleep 3000
}
```
 
<<<>>>
 
Description:
 
Creates a loop with 3 iterations.
 
 
Code:
 
```ahkv2
Loop 3
{
    MsgBox "Iteration number is " A_Index  
    Sleep 100
}
```
 
<<<>>>
 
Description:
 
Creates an infinite loop, but it will be terminated after the 25th iteration.
 
 
Code:
 
```ahkv2
Loop
{
    if (A_Index > 25)
        break  
    if (A_Index < 20)
        continue 
    MsgBox "A_Index = " A_Index 
}
```
 
<<<>>>
 
Description:
 
Reports the full path of each text file located in a directory and in its subdirectories.
 
 
Code:
 
```ahkv2
Loop Files, A_ProgramFiles "\*.txt", "R"  
{
    Result := MsgBox("Filename = " A_LoopFilePath "`n`nContinue?",, "y/n")
    if Result = "No"
        break
}
```
 
<<<>>>
 
Description:
 
Calculates the size of a folder, including the files in all its subfolders.
 
 
Code:
 
```ahkv2
FolderSizeKB := 0
WhichFolder := DirSelect()  
Loop Files, WhichFolder "\*.*", "R"
    FolderSizeKB += A_LoopFileSizeKB
MsgBox "Size of " WhichFolder " is " FolderSizeKB " KB."
```
 
<<<>>>
 
Description:
 
Retrieves file names sorted by name (see next example to sort by date).
 
 
Code:
 
```ahkv2
FileList := ""  
Loop Files, "C:\*.*"
    FileList .= A_LoopFileName "`n"
FileList := Sort(FileList, "R")  
Loop Parse, FileList, "`n"
{
    if A_LoopField = ""  
        continue
    Result := MsgBox("File number " A_Index " is " A_LoopField ".  Continue?",, "y/n")
    if Result = "No"
        break
}
```
 
<<<>>>
 
Description:
 
Retrieves file names sorted by modification date.
 
 
Code:
 
```ahkv2
FileList := ""
Loop Files, A_MyDocuments "\Photos\*.*", "FD"  
    FileList .= A_LoopFileTimeModified "`t" A_LoopFileName "`n"
FileList := Sort(FileList)  
Loop Parse, FileList, "`n"
{
    if A_LoopField = "" 
        continue
    FileItem := StrSplit(A_LoopField, A_Tab)  
    Result := MsgBox("The next file (modified at " FileItem[1] ") is:`n" FileItem[2] "`n`nContinue?",, "y/n")
    if Result = "No"
        break
}
```
 
<<<>>>
 
Description:
 
Copies only the source files that are newer than their counterparts in the destination. Call this function with a source pattern like "A:\Scripts\*.ahk" and an  destination directory like "B:\Script Backup".
 
 
Code:
 
```ahkv2
CopyIfNewer(SourcePattern, Dest)
{
    Loop Files, SourcePattern
    {
        copy_it := false
        if !FileExist(Dest "\" A_LoopFileName)  
            copy_it := true
        else
        {
            time := FileGetTime(Dest "\" A_LoopFileName)
            time := DateDiff(time, A_LoopFileTimeModified, "Seconds")  
            if time < 0  
                copy_it := true
        }
        if copy_it
        {
            try
                FileCopy A_LoopFilePath, Dest "\" A_LoopFileName, 1   
            catch
                MsgBox 'Could not copy "' A_LoopFilePath '" to "' Dest '\' A_LoopFileName '".'
        }
    }
}
```
 
<<<>>>
 
Description:
 
Converts filenames passed in via command-line parameters to long names, complete path, and correct uppercase/lowercase characters as stored in the file system.
 
 
Code:
 
```ahkv2
for GivenPath in A_Args  
{
    Loop Files, GivenPath, "FD"  
        LongPath := A_LoopFilePath
    MsgBox "The case-corrected long path name of file`n" GivenPath "`nis:`n" LongPath
}
```
 
<<<>>>
 
Description:
 
Parses a comma-separated string.
 
 
Code:
 
```ahkv2
Colors := "red,green,blue"
Loop parse, Colors, ","
{
    MsgBox "Color number " A_Index " is " A_LoopField
}
```
 
<<<>>>
 
Description:
 
Reads the lines inside a variable, one by one (similar to a file-reading loop). A file can be loaded into a variable via FileRead.
 
 
Code:
 
```ahkv2
Loop parse, FileContents, "`n", "`r"  
{
    Result := MsgBox("Line number " A_Index " is " A_LoopField ".`n`nContinue?",, "y/n")
}
until Result = "No"
```
 
<<<>>>
 
Description:
 
This is the same as the example above except that it's for the clipboard. It's useful whenever the clipboard contains files, such as those copied from an open Explorer window (the program automatically converts such files to their file names).
 
 
Code:
 
```ahkv2
Loop parse, A_Clipboard, "`n", "`r"
{
    Result := MsgBox("File number " A_Index " is " A_LoopField ".`n`nContinue?",, "y/n")
}
until Result = "No"
```
 
<<<>>>
 
Description:
 
Parses a comma separated value (CSV) file.
 
 
Code:
 
```ahkv2
Loop read, "C:\Database Export.csv"
{
    LineNumber := A_Index
    Loop parse, A_LoopReadLine, "CSV"
    {
        Result := MsgBox("Field " LineNumber "-" A_Index " is:`n" A_LoopField "`n`nContinue?",, "y/n")
        if Result = "No"
            return
    }
}
```
 
<<<>>>
 
Description:
 
Determines which delimiter character was encountered.
 
 
Code:
 
```ahkv2
Colors := "red,green|blue;yellow|cyan,magenta"
Position := 0
Loop Parse, Colors, ",|;"
{
 
    Position += StrLen(A_LoopField) + 1
 
    DelimiterChar := SubStr(Colors, Position, 1)
    MsgBox "Field: " A_LoopField "`nDelimiter character: " DelimiterChar
}
```
 
<<<>>>
 
Description:
 
Adds a new menu item to the bottom of the tray icon menu.
 
 
Code:
 
```ahkv2
A_TrayMenu.Add()  
A_TrayMenu.Add("Item1", MenuHandler)  
Persistent
MenuHandler(ItemName, ItemPos, MyMenu) {
    MsgBox "You selected " ItemName " (position " ItemPos ")"
}
```
 
<<<>>>
 
Description:
 
Creates a popup menu that is displayed when the user presses a hotkey.
 
 
Code:
 
```ahkv2
MyMenu := Menu()
MyMenu.Add("Item 1", MenuHandler)
MyMenu.Add("Item 2", MenuHandler)
MyMenu.Add()  
Submenu1 := Menu()
Submenu1.Add("Item A", MenuHandler)
Submenu1.Add("Item B", MenuHandler)
MyMenu.Add("My Submenu", Submenu1)
MyMenu.Add()  
MyMenu.Add("Item 3", MenuHandler)  
MenuHandler(Item, *) {
    MsgBox("You selected " Item)
}
#z::MyMenu.Show()  
```
 
<<<>>>
 
Description:
 
Demonstrates some of the various menu object members.
 
 
Code:
 
```ahkv2
#SingleInstance
Persistent
Tray := A_TrayMenu 
Tray.Delete() 
Tray.Add() 
Tray.Add("TestToggleCheck", TestToggleCheck)
Tray.Add("TestToggleEnable", TestToggleEnable)
Tray.Add("TestDefault", TestDefault)
Tray.Add("TestAddStandard", TestAddStandard)
Tray.Add("TestDelete", TestDelete)
Tray.Add("TestDeleteAll", TestDeleteAll)
Tray.Add("TestRename", TestRename)
Tray.Add("Test", Test)
TestToggleCheck(*)
{
    Tray.ToggleCheck("TestToggleCheck")
    Tray.Enable("TestToggleEnable") 
    Tray.Add("TestDelete", TestDelete) 
}
TestToggleEnable(*)
{
    Tray.ToggleEnable("TestToggleEnable")
}
TestDefault(*)
{
    if Tray.Default = "TestDefault"
        Tray.Default := ""
    else
        Tray.Default := "TestDefault"
}
TestAddStandard(*)
{
    Tray.AddStandard()
}
TestDelete(*)
{
    Tray.Delete("TestDelete")
}
TestDeleteAll(*)
{
    Tray.Delete()
}
TestRename(*)
{
    static OldName := "", NewName := ""
    if NewName != "renamed"
    {
        OldName := "TestRename"
        NewName := "renamed"
    }
    else
    {
        OldName := "renamed"
        NewName := "TestRename"
    }
    Tray.Rename(OldName, NewName)
}
Test(Item, *)
{
    MsgBox("You selected " Item)
}
```
 
<<<>>>
 
Description:
 
Demonstrates how to add icons to menu items.
 
 
Code:
 
```ahkv2
FileMenu := Menu()
FileMenu.Add("Script Icon", MenuHandler)
FileMenu.Add("Suspend Icon", MenuHandler)
FileMenu.Add("Pause Icon", MenuHandler)
FileMenu.SetIcon("Script Icon", A_AhkPath, 2) 
FileMenu.SetIcon("Suspend Icon", A_AhkPath, -206) 
FileMenu.SetIcon("Pause Icon", A_AhkPath, -207) 
MyMenuBar := MenuBar()
MyMenuBar.Add("&File", FileMenu)
MyGui := Gui()
MyGui.MenuBar := MyMenuBar
MyGui.Add("Button",, "Exit This Example").OnEvent("Click", (*) => WinClose())
MyGui.Show()
MenuHandler(*) {
 
}
```
 
<<<>>>
 
Description:
 
Reports the number of items in a menu and the ID of the last item.
 
 
Code:
 
```ahkv2
MyMenu := Menu()
MyMenu.Add("Item 1", NoAction)
MyMenu.Add("Item 2", NoAction)
MyMenu.Add("Item B", NoAction)
item_count := DllCall("GetMenuItemCount", "ptr", MyMenu.Handle)
last_id := DllCall("GetMenuItemID", "ptr", MyMenu.Handle, "int", item_count-1)
MsgBox("MyMenu has " item_count " items, and its last item has ID " last_id)
NoAction(*) {
 
}
```
 
<<<>>>
 
Description:
 
Selects File -> Open in Notepad. This example may fail on Windows 11 or later, as it requires the classic version of Notepad.
 
 
Code:
 
```ahkv2
MenuSelect "Untitled - Notepad",, "File", "Open"
```
 
<<<>>>
 
Description:
 
Same as above except it is done by position instead of name. On Windows 10, 2& must be replaced with 3& due to the new "New Window" menu item. This example may fail on Windows 11 or later, as it requires the classic version of Notepad.
 
 
Code:
 
```ahkv2
MenuSelect "Untitled - Notepad",, "1&", "2&"
```
 
<<<>>>
 
Description:
 
Selects View -> Lines most recently executed in the main window.
 
 
Code:
 
```ahkv2
WinShow "ahk_class AutoHotkey"
MenuSelect "ahk_class AutoHotkey",, "View", "Lines most recently executed"
```
 
<<<>>>
 
Description:
 
Double-clicks at the current mouse position.
 
 
Code:
 
```ahkv2
MouseClick "left"
MouseClick "left"
```
 
<<<>>>
 
Description:
 
Same as above.
 
 
Code:
 
```ahkv2
MouseClick "left",,, 2
```
 
<<<>>>
 
Description:
 
Moves the mouse cursor to a specific position, then right-clicks once.
 
 
Code:
 
```ahkv2
MouseClick "right", 200, 300
```
 
<<<>>>
 
Description:
 
Simulates the turning of the mouse wheel.
 
 
Code:
 
```ahkv2
#up::MouseClick "WheelUp",,, 2  
#down::MouseClick "WheelDown",,, 2
```
 
<<<>>>
 
Description:
 
Clicks and holds the left mouse button, moves the mouse cursor to the destination coordinates, then releases the button.
 
 
Code:
 
```ahkv2
MouseClickDrag "left", 0, 200, 600, 400
```
 
<<<>>>
 
Description:
 
Opens MS Paint and draws a little house.
 
 
Code:
 
```ahkv2
Run "mspaint.exe"
if !WinWaitActive("ahk_class MSPaintApp",, 2)
    return
MouseClickDrag "L", 150, 450, 150, 350
MouseClickDrag "L", 150, 350, 200, 300
MouseClickDrag "L", 200, 300, 250, 350
MouseClickDrag "L", 250, 350, 150, 350
MouseClickDrag "L", 150, 350, 250, 450
MouseClickDrag "L", 250, 450, 250, 350
MouseClickDrag "L", 250, 350, 150, 450
MouseClickDrag "L", 150, 450, 250, 450
```
 
<<<>>>
 
Description:
 
Reports the position of the mouse cursor.
 
 
Code:
 
```ahkv2
MouseGetPos &xpos, &ypos 
MsgBox "The cursor is at X" xpos " Y" ypos
```
 
<<<>>>
 
Description:
 
Shows the HWND, class name, title and controls of the window currently under the mouse cursor.
 
 
Code:
 
```ahkv2
SetTimer WatchCursor, 100
WatchCursor()
{
    MouseGetPos , , &id, &control
    ToolTip
    (
        "ahk_id " id "
        ahk_class " WinGetClass(id) "
        " WinGetTitle(id) "
        Control: " control
    )
}
```
 
<<<>>>
 
Description:
 
Moves the mouse cursor to a new position.
 
 
Code:
 
```ahkv2
MouseMove 200, 100
```
 
<<<>>>
 
Description:
 
Moves the mouse cursor slowly (speed 50 vs. 2) by 20 pixels to the right and 30 pixels down from its current location.
 
 
Code:
 
```ahkv2
MouseMove 20, 30, 50, "R"
```
 
<<<>>>
 
Description:
 
Shows a message box with specific text. A quick and easy way to show information. The user can press an OK button to close the message box and continue execution.
 
 
Code:
 
```ahkv2
MsgBox "This is a string."
```
 
<<<>>>
 
Description:
 
Shows a message box with specific text and a title.
 
 
Code:
 
```ahkv2
MsgBox "This MsgBox has a custom title.", "A Custom Title"
```
 
<<<>>>
 
Description:
 
Shows a message box with default text. Mainly useful for debugging purposes, for example to quickly set a breakpoint in the script.
 
 
Code:
 
```ahkv2
MsgBox 
```
 
<<<>>>
 
Description:
 
Shows a message box with specific text, a title and an info icon. Besides, a continuation section is used to display the multi-line text in a more clear manner.
 
 
Code:
 
```ahkv2
MsgBox "
  (
    The first parameter is displayed as the message.
    The second parameter becomes the window title.
    The third parameter determines the type of message box.
  )", "Window Title", "iconi"
```
 
<<<>>>
 
Description:
 
Use the return value to determine which button the user pressed in the message box. Note that in this case the MsgBox function call must be specified with parentheses.
 
 
Code:
 
```ahkv2
result := MsgBox("Do you want to continue? (Press YES or NO)",, "YesNo")
if (result = "No")
    return
```
 
<<<>>>
 
Description:
 
Use the T (timeout) option to automatically close the message box after a certain number of seconds.
 
 
Code:
 
```ahkv2
result := MsgBox("This MsgBox will time out in 5 seconds.  Continue?",, "Y/N T5")
if (result = "Timeout")
    MsgBox "You didn't press YES or NO within the 5-second period."
else if (result = "No")
    return
```
 
<<<>>>
 
Description:
 
Include a variable or sub-expression in the message. See also: Concatenation
 
 
Code:
 
```ahkv2
var := 10
MsgBox "The initial value is: " var
MsgBox "The result is: " var * 2
MsgBox Format("The result is: {1}", var * 2)
```
 
<<<>>>
 
Description:
 
Briefly displays a tooltip for each clipboard change.
 
 
Code:
 
```ahkv2
OnClipboardChange ClipChanged
ClipChanged(DataType) {
    ToolTip "Clipboard data type: " DataType
    Sleep 1000
    ToolTip  
}
```
 
<<<>>>
 
Description:
 
Logs errors caused by the script into a text file instead of displaying them to the user.
 
 
Code:
 
```ahkv2
OnError LogError
i := Integer("cause_error")
LogError(exception, mode) {
    FileAppend "Error on line " exception.Line ": " exception.Message "`n"
        , "errorlog.txt"
    return true
}
```
 
<<<>>>
 
Description:
 
Use OnError to implement alternative error handling methods. Caveat: OnError is ineffective while Try is active.
 
 
Code:
 
```ahkv2
AccumulateErrors()
{
    local ea := ErrorAccumulator()
    ea.Start()
    return ea
}
class ErrorAccumulator
{
    Errors := []                        
    _cb := AccumulateError.Bind(this.Errors)
    Start() => OnError(this._cb, -1)    
    Stop() => OnError(this._cb, 0)      
    Last => this.Errors[-1]             
    Count => this.Errors.Length         
    __item[i] => this.Errors[i]         
    __delete() => this.Stop()           
}
AccumulateError(errors, e, mode)
{
    if mode != "Return" 
        return
    if e.What = "" 
        return
    try {
 
        FileAppend Format("{1} ({2}) : ({3}) {4}`n", e.File, e.Line, e.What, e.Message), "*"
        if HasProp(e, "extra")
            FileAppend "     Specifically: " e.Extra "`n", "*"
    }
    errors.Push(e)
    return -1 
}
RearrangeWindows()
{
 
    local err := AccumulateErrors()
 
    MonitorGetWorkArea , &left, &top, &right, &bottom
    width := (right-left)//2, height := bottom-top
    WinMove left, top, width, height, A_ScriptFullPath
    WinMove left+width, top, width, height, "AutoHotkey v2 Help"
 
    if err.Count
        MsgBox err.Count " error(s); last error at line #" err.Last.Line
    else
        MsgBox "No errors"
 
}
RearrangeWindows()
WinMove 0, 0, 0, 0, "non-existent window"
```
 
<<<>>>
 
Description:
 
Asks the user before exiting the script. To test this example, right-click the tray icon and click Exit.
Persistent  
OnExit ExitFunc
ExitFunc(ExitReason, ExitCode)
{
    if ExitReason != "Logoff" and ExitReason != "Shutdown"
    {
        Result := MsgBox("Are you sure you want to exit?",, 4)
        if Result = "No"
            return 1  
    }
 
}
 Registers a method to be called on exit.
 
 
Code:
 
```ahkv2
Persistent  
OnExit MyObject.Exiting
class MyObject
{
    static Exiting(*)
    {
        MsgBox "MyObject is cleaning up prior to exiting..."
 
    }
}
```
 
<<<>>>
 
Description:
 
Monitors mouse clicks in a GUI window. Related topic: ContextMenu event
 
 
Code:
 
```ahkv2
MyGui := Gui(, "Example Window")
MyGui.Add("Text",, "Click anywhere in this window.")
MyGui.Add("Edit", "w200")
MyGui.Show()
OnMessage 0x0201, WM_LBUTTONDOWN
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd)
{
    X := lParam & 0xFFFF
    Y := lParam >> 16
    Control := ""
    thisGui := GuiFromHwnd(hwnd)
    thisGuiControl := GuiCtrlFromHwnd(hwnd)
    if thisGuiControl
    {
        thisGui := thisGuiControl.Gui
        Control := "`n(in control " . thisGuiControl.ClassNN . ")"
    }
    ToolTip "You left-clicked in Gui window '" thisGui.Title "' at client coordinates " X "x" Y "." Control
}
```
 
<<<>>>
 
Description:
 
Detects system shutdown/logoff and allows the user to abort it. On Windows Vista and later, the system displays a user interface showing which program is blocking shutdown/logoff and allowing the user to force shutdown/logoff. On older OSes, the script displays a confirmation prompt. Related topic: OnExit
 
 
Code:
 
```ahkv2
DllCall("kernel32.dll\SetProcessShutdownParameters", "UInt", 0x4FF, "UInt", 0)
OnMessage(0x0011, On_WM_QUERYENDSESSION)
Persistent
On_WM_QUERYENDSESSION(wParam, lParam, *)
{
    ENDSESSION_LOGOFF := 0x80000000
    if (lParam & ENDSESSION_LOGOFF)  
        EventType := "Logoff"
    else  
        EventType := "Shutdown"
    try
    {
 
        BlockShutdown("Example script attempting to prevent " EventType ".")
        return false
    }
    catch
    {
 
        Result := MsgBox(EventType " in progress. Allow it?",, "YN")
        if (Result = "Yes")
            return true  
        else
            return false  
    }
}
BlockShutdown(Reason)
{
 
    DllCall("ShutdownBlockReasonCreate", "ptr", A_ScriptHwnd, "wstr", Reason)
    OnExit StopBlockingShutdown
}
StopBlockingShutdown(*)
{
    OnExit StopBlockingShutdown, 0
    DllCall("ShutdownBlockReasonDestroy", "ptr", A_ScriptHwnd)
}
```
 
<<<>>>
 
Description:
 
Receives a custom message and up to two numbers from some other script or program (to send strings rather than numbers, see the example after this one).
 
 
Code:
 
```ahkv2
OnMessage 0x5555, MsgMonitor
Persistent
MsgMonitor(wParam, lParam, msg, *)
{
 
 
    ToolTip "Message " msg " arrived:`nWPARAM: " wParam "`nLPARAM: " lParam
}
SetTitleMatchMode 2
DetectHiddenWindows True
if WinExist("Name of Receiving Script.ahk ahk_class AutoHotkey")
    PostMessage 0x5555, 11, 22  
DetectHiddenWindows False  
```
 
<<<>>>
 
Description:
 
Use Pause to halt the script, such as to inspect variables.
 
 
Code:
 
```ahkv2
ListVars
Pause
ExitApp 
```
 
<<<>>>
 
Description:
 
Press a hotkey once to pause the script. Press it again to unpause.
 
 
Code:
 
```ahkv2
Pause::Pause -1  
#p::Pause -1  
```
 
<<<>>>
 
Description:
 
Sends a Pause command to another script.
 
 
Code:
 
```ahkv2
DetectHiddenWindows True
WM_COMMAND := 0x0111
ID_FILE_PAUSE := 65403
PostMessage WM_COMMAND, ID_FILE_PAUSE,,, "C:\YourScript.ahk ahk_class AutoHotkey"
```
 
<<<>>>
 
Description:
 
Press a hotkey to show the color of the pixel located at the current position of the mouse cursor.
 
 
Code:
 
```ahkv2
^!z::  
{
    MouseGetPos &MouseX, &MouseY
    MsgBox "The color at the current cursor position is " PixelGetColor(MouseX, MouseY)
}
```
 
<<<>>>
 
Description:
 
Searches a region of the active window for a pixel and stores in  and  the X and Y coordinates of the first pixel that matches the specified color with 3 shades of variation.
 
 
Code:
 
```ahkv2
if PixelSearch(&Px, &Py, 200, 200, 300, 300, 0x9d6346, 3)
    MsgBox "A color within 3 shades of variation was found at X" Px " Y" Py
else
    MsgBox "That color was not found in the specified region."
```
 
<<<>>>
 
Description:
 
Generates a random integer in the range 1 to 10 and stores it in N.
 
 
Code:
 
```ahkv2
N := Random(1, 10)
```
 
<<<>>>
 
Description:
 
Generates a random integer in the range 0 to 9 and stores it in N.
 
 
Code:
 
```ahkv2
N := Random(9)
```
 
<<<>>>
 
Description:
 
Generates a random floating point number in the range 0.0 to 1.0 and stores it in fraction.
 
 
Code:
 
```ahkv2
fraction := Random(0.0, 1.0)
fraction := Random()  
```
 
<<<>>>
 
Description:
 
Reports 4, which is the position where the match was found.
 
 
Code:
 
```ahkv2
MsgBox RegExMatch("xxxabc123xyz", "abc.*xyz")
```
 
<<<>>>
 
Description:
 
Reports 7 because the $ requires the match to be at the end.
 
 
Code:
 
```ahkv2
MsgBox RegExMatch("abc123123", "123$")
```
 
<<<>>>
 
Description:
 
Reports 1 because a match was achieved via the case-insensitive option.
 
 
Code:
 
```ahkv2
MsgBox RegExMatch("abc123", "i)^ABC")
```
 
<<<>>>
 
Description:
 
Reports 1 and stores "XYZ" in SubPat[1].
 
 
Code:
 
```ahkv2
MsgBox RegExMatch("abcXYZ123", "abc(.*)123", &SubPat)
```
 
<<<>>>
 
Description:
 
Reports 7 instead of 1 due to the starting position 2 instead of 1.
 
 
Code:
 
```ahkv2
MsgBox RegExMatch("abc123abc456", "abc\d+",, 2)
```
 
<<<>>>
 
Description:
 
Demonstrates the usage of the Match object.
 
 
Code:
 
```ahkv2
FoundPos := RegExMatch("Michiganroad 72", "(.*) (?<nr>\d+)", &SubPat)
MsgBox SubPat.Count ": " SubPat[1] " " SubPat.Name[2] "=" SubPat.nr  
```
 
<<<>>>
 
Description:
 
Retrieves the extension of a file. Note that SplitPath can also be used for this, which is more reliable.
 
 
Code:
 
```ahkv2
Path := "C:\Foo\Bar\Baz.txt"
RegExMatch(Path, "\w+$", &Extension)
MsgBox Extension[]  
```
 
<<<>>>
 
Description:
 
Similar to AutoHotkey v1's Transform Deref, the following function expands variable references and escape sequences contained inside other variables. Furthermore, this example shows how to find all matches in a string rather than stopping at the first match (similar to the g flag in JavaScript's RegEx).
 
 
Code:
 
```ahkv2
var1 := "abc"
var2 := 123
MsgBox Deref("%var1%def%var2%")  
Deref(Str)
{
    spo := 1
    out := ""
    while (fpo:=RegexMatch(Str, "(%(.*?)%)|``(.)", &m, spo))
    {
        out .= SubStr(Str, spo, fpo-spo)
        spo := fpo + StrLen(m[0])
        if (m[1])
            out .= %m[2]%
        else switch (m[3])
        {
            case "a": out .= "`a"
            case "b": out .= "`b"
            case "f": out .= "`f"
            case "n": out .= "`n"
            case "r": out .= "`r"
            case "t": out .= "`t"
            case "v": out .= "`v"
            default: out .= m[3]
        }
    }
    return out SubStr(Str, spo)
}
```
 
<<<>>>
 
Description:
 
Reports "abc123xyz" because the $ allows a match only at the end.
 
 
Code:
 
```ahkv2
MsgBox RegExReplace("abc123123", "123$", "xyz")
```
 
<<<>>>
 
Description:
 
Reports "123" because a match was achieved via the case-insensitive option.
 
 
Code:
 
```ahkv2
MsgBox RegExReplace("abc123", "i)^ABC")
```
 
<<<>>>
 
Description:
 
Reports "aaaXYZzzz" by means of the $1 backreference.
 
 
Code:
 
```ahkv2
MsgBox RegExReplace("abcXYZ123", "abc(.*)123", "aaa$1zzz")
```
 
<<<>>>
 
Description:
 
Reports an empty string and stores 2 in ReplacementCount.
 
 
Code:
 
```ahkv2
MsgBox RegExReplace("abc123abc456", "abc\d+", "", &ReplacementCount)
```
 
<<<>>>
 
Description:
 
Press a hotkey to restart the script.
 
 
Code:
 
```ahkv2
^!r::Reload  
```
 
<<<>>>
 
Description:
 
Reports the value returned by the function.
 
 
Code:
 
```ahkv2
MsgBox returnTest() 
returnTest() {
    return 123
}
```
 
<<<>>>
 
Description:
 
The first Return ensures that the subsequent function call is skipped if the preceding condition is true. The second Return is redundant when used at the end of a function like this.
 
 
Code:
 
```ahkv2
#z::  
^#z::  
{
    MsgBox "A Win-Z hotkey was pressed."
    if GetKeyState("Ctrl")
        return  
    MyFunction()
}
MyFunction()
{
    Sleep 1000
    return  
}
```
 
<<<>>>
 
Description:
 
Run is able to launch Windows system programs from any directory. Note that executable file extensions such as .exe can be omitted.
 
 
Code:
 
```ahkv2
Run "notepad"
```
 
<<<>>>
 
Description:
 
Run is able to launch URLs:
The following opens an internet address in the user's default web browser.
 
 
Code:
 
```ahkv2
Run "https://www.google.com"
```
 
<<<>>>
 
Description:
 
Opens a document in a maximized application and displays a custom error message on failure.
 
 
Code:
 
```ahkv2
try Run("ReadMe.doc", , "Max")
if A_LastError
    MsgBox "The document could not be launched."
```
 
<<<>>>
 
Description:
 
Runs the dir command in minimized state and stores the output in a text file. After that, the text file and its properties dialog will be opened.
 
 
Code:
 
```ahkv2
RunWait A_ComSpec " /c dir C:\ >>C:\DirTest.txt", , "Min"
Run "C:\DirTest.txt"
Run "properties C:\DirTest.txt"
Persistent  
```
 
<<<>>>
 
Description:
 
Run is able to launch CLSIDs:
The following opens the Recycle Bin.
 
 
Code:
 
```ahkv2
Run "::{645FF040-5081-101B-9F08-00AA002F954E}"
```
 
<<<>>>
 
Description:
 
To run multiple commands consecutively, use "&&" between each.
 
 
Code:
 
```ahkv2
Run A_ComSpec "/c dir /b > C:\list.txt && type C:\list.txt && pause"
```
 
<<<>>>
 
Description:
 
The following custom functions can be used to run a command and retrieve its output or to run multiple commands in one go and retrieve their output. For the WshShell object, see Microsoft Docs.
 
 
Code:
 
```ahkv2
MsgBox RunWaitOne("dir " A_ScriptDir)
MsgBox RunWaitMany("
(
echo Put your commands here,
echo each one will be run,
echo and you'll get the output.
)")
RunWaitOne(command) {
    shell := ComObject("WScript.Shell")
 
    exec := shell.Exec(A_ComSpec " /C " command)
 
    return exec.StdOut.ReadAll()
}
RunWaitMany(commands) {
    shell := ComObject("WScript.Shell")
 
    exec := shell.Exec(A_ComSpec " /Q /K echo off")
 
    exec.StdIn.WriteLine(commands "`nexit")  
 
    return exec.StdOut.ReadAll()
}
```
 
<<<>>>
 
Description:
 
Executes the given code as a new AutoHotkey process.
 
 
Code:
 
```ahkv2
ExecScript(Script, Wait:=true)
{
    shell := ComObject("WScript.Shell")
    exec := shell.Exec("AutoHotkey.exe /ErrorStdOut *")
    exec.StdIn.Write(Script)
    exec.StdIn.Close()
    if Wait
        return exec.StdOut.ReadAll()
}
ib := InputBox("Enter an expression to evaluate as a new script.",,, 'Ord("*")')
if ib.result = "Cancel"
    return
result := ExecScript('FileAppend ' ib.value ', "*"')
MsgBox "Result: " result
```
 
<<<>>>
 
Description:
 
Opens the registry editor as administrator.
 
 
Code:
 
```ahkv2
RunAs "Administrator", "MyPassword"
Run "RegEdit.exe"
RunAs  
```
 
<<<>>>
 
Description:
 
Types a two-line signature.
 
 
Code:
 
```ahkv2
Send "Sincerely,{enter}John Smith"
```
 
<<<>>>
 
Description:
 
Selects the File->Save menu (Alt+F followed by S).
 
 
Code:
 
```ahkv2
Send "!fs"
```
 
<<<>>>
 
Description:
 
Jumps to the end of the text then send four shift+left-arrow keystrokes.
 
 
Code:
 
```ahkv2
Send "{End}+{Left 4}"
```
 
<<<>>>
 
Description:
 
Sends a long series of raw characters via the fastest method.
 
 
Code:
 
```ahkv2
SendInput "{Raw}A long series of raw characters sent via the fastest method."
```
 
<<<>>>
 
Description:
 
Holds down a key contained in a variable.
 
 
Code:
 
```ahkv2
MyKey := "Shift"
Send "{" MyKey " down}"  
```
 
<<<>>>
 
Description:
 
Makes Send synonymous with SendInput, but falls back to SendPlay if SendInput is not available.
 
 
Code:
 
```ahkv2
SendMode "InputThenPlay"
```
 
<<<>>>
 
Description:
 
Types a two-line signature.
 
 
Code:
 
```ahkv2
Send "Sincerely,{enter}John Smith"
```
 
<<<>>>
 
Description:
 
Selects the File->Save menu (Alt+F followed by S).
 
 
Code:
 
```ahkv2
Send "!fs"
```
 
<<<>>>
 
Description:
 
Jumps to the end of the text then send four shift+left-arrow keystrokes.
 
 
Code:
 
```ahkv2
Send "{End}+{Left 4}"
```
 
<<<>>>
 
Description:
 
Sends a long series of raw characters via the fastest method.
 
 
Code:
 
```ahkv2
SendInput "{Raw}A long series of raw characters sent via the fastest method."
```
 
<<<>>>
 
Description:
 
Holds down a key contained in a variable.
 
 
Code:
 
```ahkv2
MyKey := "Shift"
Send "{" MyKey " down}"  
```
 
<<<>>>
 
Description:
 
Causes the smallest possible delay to occur after each control-modifying function.
 
 
Code:
 
```ahkv2
SetControlDelay 0
```
 
<<<>>>
 
Description:
 
Causes the mouse cursor to be moved instantly.
 
 
Code:
 
```ahkv2
SetDefaultMouseSpeed 0
```
 
<<<>>>
 
Description:
 
Moves the mouse cursor to a new position.
 
 
Code:
 
```ahkv2
MouseMove 200, 100
```
 
<<<>>>
 
Description:
 
Moves the mouse cursor slowly (speed 50 vs. 2) by 20 pixels to the right and 30 pixels down from its current location.
 
 
Code:
 
```ahkv2
MouseMove 20, 30, 50, "R"
```
 
<<<>>>
 
Description:
 
Double-clicks at the current mouse position.
 
 
Code:
 
```ahkv2
MouseClick "left"
MouseClick "left"
```
 
<<<>>>
 
Description:
 
Same as above.
 
 
Code:
 
```ahkv2
MouseClick "left",,, 2
```
 
<<<>>>
 
Description:
 
Moves the mouse cursor to a specific position, then right-clicks once.
 
 
Code:
 
```ahkv2
MouseClick "right", 200, 300
```
 
<<<>>>
 
Description:
 
Simulates the turning of the mouse wheel.
 
 
Code:
 
```ahkv2
#up::MouseClick "WheelUp",,, 2  
#down::MouseClick "WheelDown",,, 2
```
 
<<<>>>
 
Description:
 
Clicks and holds the left mouse button, moves the mouse cursor to the destination coordinates, then releases the button.
 
 
Code:
 
```ahkv2
MouseClickDrag "left", 0, 200, 600, 400
```
 
<<<>>>
 
Description:
 
Opens MS Paint and draws a little house.
 
 
Code:
 
```ahkv2
Run "mspaint.exe"
if !WinWaitActive("ahk_class MSPaintApp",, 2)
    return
MouseClickDrag "L", 150, 450, 150, 350
MouseClickDrag "L", 150, 350, 200, 300
MouseClickDrag "L", 200, 300, 250, 350
MouseClickDrag "L", 250, 350, 150, 350
MouseClickDrag "L", 150, 350, 250, 450
MouseClickDrag "L", 250, 450, 250, 350
MouseClickDrag "L", 250, 350, 150, 450
MouseClickDrag "L", 150, 450, 250, 450
```
 
<<<>>>
 
Description:
 
Causes the smallest possible delay to occur after each keystroke sent via Send or ControlSend.
 
 
Code:
 
```ahkv2
SetKeyDelay 0
```
 
<<<>>>
 
Description:
 
Types a two-line signature.
 
 
Code:
 
```ahkv2
Send "Sincerely,{enter}John Smith"
```
 
<<<>>>
 
Description:
 
Selects the File->Save menu (Alt+F followed by S).
 
 
Code:
 
```ahkv2
Send "!fs"
```
 
<<<>>>
 
Description:
 
Jumps to the end of the text then send four shift+left-arrow keystrokes.
 
 
Code:
 
```ahkv2
Send "{End}+{Left 4}"
```
 
<<<>>>
 
Description:
 
Sends a long series of raw characters via the fastest method.
 
 
Code:
 
```ahkv2
SendInput "{Raw}A long series of raw characters sent via the fastest method."
```
 
<<<>>>
 
Description:
 
Holds down a key contained in a variable.
 
 
Code:
 
```ahkv2
MyKey := "Shift"
Send "{" MyKey " down}"  
```
 
<<<>>>
 
Description:
 
Opens Notepad minimized and send it some text. This example may fail on Windows 11 or later, as it requires the classic version of Notepad.
 
 
Code:
 
```ahkv2
Run "Notepad",, "Min", &PID  
WinWait "ahk_pid " PID  
ControlSend "This is a line of text in the notepad window.{Enter}", "Edit1"
ControlSendText "Notice that {Enter} is not sent as an Enter keystroke with ControlSendText.", "Edit1"
Msgbox "Press OK to activate the window to see the result."
WinActivate "ahk_pid " PID  
```
 
<<<>>>
 
Description:
 
Opens the command prompt and sent it some text. This example may fail on Windows 11 or later, as it requires the classic version of the command prompt.
 
 
Code:
 
```ahkv2
SetTitleMatchMode 2
Run A_ComSpec,,, &PID  
WinWait "ahk_pid " PID  
ControlSend "ipconfig{Enter}",, "cmd.exe"  
```
 
<<<>>>
 
Description:
 
Creates a GUI with an edit control and sent it some text.
 
 
Code:
 
```ahkv2
MyGui := Gui()
MyGui.Add("Edit", "r10 w500")
MyGui.Show()
ControlSend "This is a line of text in the edit control.{Enter}", "Edit1", MyGui
ControlSendText "Notice that {Enter} is not sent as an Enter keystroke with ControlSendText.", "Edit1", MyGui
```
 
<<<>>>
 
Description:
 
Causes the smallest possible delay to occur after each mouse movement or click.
 
 
Code:
 
```ahkv2
SetMouseDelay 0
```
 
<<<>>>
 
Description:
 
Types a two-line signature.
 
 
Code:
 
```ahkv2
Send "Sincerely,{enter}John Smith"
```
 
<<<>>>
 
Description:
 
Selects the File->Save menu (Alt+F followed by S).
 
 
Code:
 
```ahkv2
Send "!fs"
```
 
<<<>>>
 
Description:
 
Jumps to the end of the text then send four shift+left-arrow keystrokes.
 
 
Code:
 
```ahkv2
Send "{End}+{Left 4}"
```
 
<<<>>>
 
Description:
 
Sends a long series of raw characters via the fastest method.
 
 
Code:
 
```ahkv2
SendInput "{Raw}A long series of raw characters sent via the fastest method."
```
 
<<<>>>
 
Description:
 
Holds down a key contained in a variable.
 
 
Code:
 
```ahkv2
MyKey := "Shift"
Send "{" MyKey " down}"  
```
 
<<<>>>
 
Description:
 
Closes unwanted windows whenever they appear.
 
 
Code:
 
```ahkv2
SetTimer CloseMailWarnings, 250
CloseMailWarnings()
{
    WinClose "Microsoft Outlook", "A timeout occured while communicating"
    WinClose "Microsoft Outlook", "A connection to the server could not be established"
}
```
 
<<<>>>
 
Description:
 
Waits for a certain window to appear and then alerts the user.
 
 
Code:
 
```ahkv2
SetTimer Alert1, 500
Alert1()
{
    if not WinExist("Video Conversion", "Process Complete")
        return
 
    SetTimer , 0  
    MsgBox "The video conversion is finished."
}
```
 
<<<>>>
 
Description:
 
Detects single, double, and triple-presses of a hotkey. This allows a hotkey to perform a different operation depending on how many times you press it.
 
 
Code:
 
```ahkv2
#c::
KeyWinC(ThisHotkey)  
{
    static winc_presses := 0
    if winc_presses > 0 
    {
        winc_presses += 1
        return
    }
 
    winc_presses := 1
    SetTimer After400, -400 
    After400()  
    {
        if winc_presses = 1 
        {
            Run "m:\"  
        }
        else if winc_presses = 2 
        {
            Run "m:\multimedia"  
        }
        else if winc_presses > 2
        {
            MsgBox "Three or more clicks detected."
        }
 
        winc_presses := 0
    }
}
```
 
<<<>>>
 
Description:
 
Uses a method as the timer function.
 
 
Code:
 
```ahkv2
counter := SecondCounter()
counter.Start()
Sleep 5000
counter.Stop()
Sleep 2000
class SecondCounter {
    __New() {
        this.interval := 1000
        this.count := 0
 
        this.timer := ObjBindMethod(this, "Tick")
    }
    Start() {
        SetTimer this.timer, this.interval
        ToolTip "Counter started"
    }
    Stop() {
 
        SetTimer this.timer, 0
        ToolTip "Counter stopped at " this.count
    }
 
    Tick() {
        ToolTip ++this.count
    }
}
```
 
<<<>>>
 
Description:
 
Forces windowing functions to operate upon windows whose titles contain WinTitle at the beginning instead of anywhere.
 
 
Code:
 
```ahkv2
SetTitleMatchMode 1
```
 
<<<>>>
 
Description:
 
Allows windowing functions to possibly detect more control types, but with lower performance. Note that Slow/Fast can be set independently of all the other modes.
 
 
Code:
 
```ahkv2
SetTitleMatchMode "Slow"
```
 
<<<>>>
 
Description:
 
Use RegEx mode to easily exclude multiple windows. Replace the following ExcludeTitles with actual window titles that you want to exclude from counting.
 
 
Code:
 
```ahkv2
SetTitleMatchMode "RegEx"
CountAll := WinGetCount()
CountExcluded := WinGetCount(,, "ExcludeTitle1|ExcludeTitle2")
MsgBox CountExcluded " out of " CountAll " windows were counted"
```
 
<<<>>>
 
Description:
 
Opens Notepad and waits a maximum of 3 seconds until it exists. If WinWait times out, an error message is shown, otherwise Notepad is minimized.
 
 
Code:
 
```ahkv2
Run "notepad.exe"
if WinWait("Untitled - Notepad", , 3)
    WinMinimize 
else
    MsgBox "WinWait timed out."
```
 
<<<>>>
 
Description:
 
Causes a delay of 10ms to occur after each windowing function.
 
 
Code:
 
```ahkv2
SetWinDelay 10
```
 
<<<>>>
 
Description:
 
If Notepad does exist, activate it, otherwise activate the calculator.
 
 
Code:
 
```ahkv2
if WinExist("Untitled - Notepad")
    WinActivate 
else
    WinActivate "Calculator"
```
 
<<<>>>
 
Description:
 
Changes the script's current working directory.
 
 
Code:
 
```ahkv2
SetWorkingDir "D:\My Folder\Temp"
```
 
<<<>>>
 
Description:
 
Forces the script to use the folder it was initially launched from as its working directory.
 
 
Code:
 
```ahkv2
SetWorkingDir A_InitialWorkingDir
```
 
<<<>>>
 
Description:
 
Waits 1 second before continuing execution.
 
 
Code:
 
```ahkv2
Sleep 1000
```
 
<<<>>>
 
Description:
 
Waits 30 minutes before continuing execution.
 
 
Code:
 
```ahkv2
MyVar := 30 * 60000 
Sleep MyVar 
```
 
<<<>>>
 
Description:
 
Demonstrates how to sleep for less time than the normal 10 or 15.6 milliseconds. Note: While a script like this is running, the entire operating system and all applications are affected by timeBeginPeriod below.
 
 
Code:
 
```ahkv2
SleepDuration := 1  
TimePeriod := 3 
DllCall("Winmm\timeBeginPeriod", "UInt", TimePeriod)  
Iterations := 50
StartTime := A_TickCount
Loop Iterations
    DllCall("Sleep", "UInt", SleepDuration)  
DllCall("Winmm\timeEndPeriod", "UInt", TimePeriod)  
MsgBox "Sleep duration = " . (A_TickCount - StartTime) / Iterations
```
 
<<<>>>
 
Description:
 
Sorts a comma-separated list of numbers.
 
 
Code:
 
```ahkv2
MyVar := "5,3,7,9,1,13,999,-4"
MyVar := Sort(MyVar, "N D,")  
MsgBox MyVar   
```
 
<<<>>>
 
Description:
 
Sorts the contents of a file.
 
 
Code:
 
```ahkv2
Contents := FileRead("C:\Address List.txt")
FileDelete "C:\Address List (alphabetical).txt"
FileAppend Sort(Contents), "C:\Address List (alphabetical).txt"
Contents := ""  
```
 
<<<>>>
 
Description:
 
Makes a hotkey to copy files from an open Explorer window and put their sorted filenames onto the clipboard.
 
 
Code:
 
```ahkv2
#c:: 
{
    A_Clipboard := "" 
    Send "^c"
    if !ClipWait(2)
        return
    MsgBox "Ready to be pasted:`n" Sort(A_Clipboard)
}
```
 
<<<>>>
 
Description:
 
Demonstrates custom sorting via a callback function.
 
 
Code:
 
```ahkv2
MyVar := "This`nis`nan`nexample`nstring`nto`nbe`nsorted"
MsgBox Sort(MyVar,, LengthSort)
LengthSort(a1, a2, *)
{
    a1 := StrLen(a1), a2 := StrLen(a2)
    return a1 > a2 ? 1 : a1 < a2 ? -1 : 0  
}
MyVar := "5,3,7,9,1,13,999,-4"
MsgBox Sort(MyVar, "D,", IntegerSort)
IntegerSort(a1, a2, *)
{
    return a1 - a2  
}
MyVar := "1,2,3,4"
MsgBox Sort(MyVar, "D,", ReverseDirection)  
ReverseDirection(a1, a2, offset)
{
    return offset  
}
MyVar := "a bbb cc"
MsgBox Sort(MyVar, "D ", (a,b,*) => StrLen(a) - StrLen(b))
```
 
<<<>>>
 
Description:
 
Plays the default pitch and duration.
 
 
Code:
 
```ahkv2
SoundBeep
```
 
<<<>>>
 
Description:
 
Plays a higher pitch for half a second.
 
 
Code:
 
```ahkv2
SoundBeep 750, 500
```
 
<<<>>>
 
Description:
 
Plays a .wav file located in the Windows directory.
 
 
Code:
 
```ahkv2
SoundPlay A_WinDir "\Media\ding.wav"
```
 
<<<>>>
 
Description:
 
Generates a simple beep.
 
 
Code:
 
```ahkv2
SoundPlay "*-1"
```
 
<<<>>>
 
Description:
 
Turns on the master mute.
 
 
Code:
 
```ahkv2
SoundSetMute true
```
 
<<<>>>
 
Description:
 
Turns off the master mute.
 
 
Code:
 
```ahkv2
SoundSetMute false
```
 
<<<>>>
 
Description:
 
Toggles the master mute (sets it to the opposite of its current state).
 
 
Code:
 
```ahkv2
SoundSetMute -1
```
 
<<<>>>
 
Description:
 
Mutes Line In.
 
 
Code:
 
```ahkv2
SoundSetMute true, "Line In"
```
 
<<<>>>
 
Description:
 
Mutes microphone recording.
 
 
Code:
 
```ahkv2
SoundSetMute true,, "Microphone"
```
 
<<<>>>
 
Description:
 
Sets the master volume to 50 percent. Quotation marks can be omitted.
 
 
Code:
 
```ahkv2
SoundSetVolume "50"
```
 
<<<>>>
 
Description:
 
Increases the master volume by 10 percent. Quotation marks cannot be omitted.
 
 
Code:
 
```ahkv2
SoundSetVolume "+10"
```
 
<<<>>>
 
Description:
 
Decreases the master volume by 10 percent. Quotation marks can be omitted.
 
 
Code:
 
```ahkv2
SoundSetVolume "-10"
```
 
<<<>>>
 
Description:
 
Increases microphone recording volume by 20 percent.
 
 
Code:
 
```ahkv2
SoundSetVolume "+20", , "Microphone"
```
 
<<<>>>
 
Description:
 
Demonstrates different usages.
 
 
Code:
 
```ahkv2
FullFileName := "C:\My Documents\Address List.txt"
 
SplitPath FullFileName, &name
SplitPath FullFileName,, &dir
SplitPath FullFileName, &name, &dir, &ext, &name_no_ext, &drive
 
```
 
<<<>>>
 
Description:
 
Retrieves and analyzes the text from the first part of a status bar.
 
 
Code:
 
```ahkv2
RetrievedText := StatusBarGetText(1, "Search Results")
if InStr(RetrievedText, "found")
    MsgBox "Search results have been found."
```
 
<<<>>>
 
Description:
 
Enters a new search pattern into an existing Explorer/Search window.
 
 
Code:
 
```ahkv2
if WinExist("Search Results") 
{
    WinActivate
    Send "{tab 2}!o*.txt{enter}"  
    Sleep 400  
    if StatusBarWait("found", 30)
        MsgBox "The search successfully completed."
    else
        MsgBox "The function timed out."
}
```
 
<<<>>>
 
Description:
 
Waits for the status bar of the active window to change.
 
 
Code:
 
```ahkv2
SetTitleMatchMode "RegEx"  
if WinExist("A")  
{
    OrigText := StatusBarGetText()
    StatusBarWait "^(?!^\Q" OrigText "\E$)"  
}
```
 
<<<>>>
 
Description:
 
Demonstrates the difference between a case-insensitive and case-sensitive comparison.
 
 
Code:
 
```ahkv2
MsgBox StrCompare("Abc", "abc") 
MsgBox StrCompare("Abc", "abc", true) 
```
 
<<<>>>
 
Description:
 
Either  or  may be specified directly after , but in those cases  must be non-numeric.
 
 
Code:
 
```ahkv2
str := StrGet(address, "cp0")  
str := StrGet(address, n, 0)   
str := StrGet(address, 0)      
```
 
<<<>>>
 
Description:
 
Retrieves and reports the count of how many characters are in a string.
 
 
Code:
 
```ahkv2
StrValue := "The quick brown fox jumps over the lazy dog"
MsgBox "The length of the string is " StrLen(StrValue) 
```
 
<<<>>>
 
Description:
 
Converts the string to lowercase and stores "this is a test." in String1.
 
 
Code:
 
```ahkv2
String1 := "This is a test."
String1 := StrLower(String1)  
```
 
<<<>>>
 
Description:
 
Converts the string to uppercase and stores "THIS IS A TEST." in String2.
 
 
Code:
 
```ahkv2
String2 := "This is a test."
String2 := StrUpper(String2)
```
 
<<<>>>
 
Description:
 
Converts the string to title case and stores "This Is A Test." in String3.
 
 
Code:
 
```ahkv2
String3 := "This is a test."
String3 := StrTitle(String3)
```
 
<<<>>>
 
Description:
 
Removes all CR-LF pairs from the clipboard contents.
 
 
Code:
 
```ahkv2
A_Clipboard := StrReplace(A_Clipboard, "`r`n")
```
 
<<<>>>
 
Description:
 
Replaces all spaces with pluses.
 
 
Code:
 
```ahkv2
NewStr := StrReplace(OldStr, A_Space, "+")
```
 
<<<>>>
 
Description:
 
Removes all blank lines from the text in a variable.
 
 
Code:
 
```ahkv2
Loop
{
    MyString := StrReplace(MyString, "`r`n`r`n", "`r`n",, &Count)
    if (Count = 0)  
        break
}
```
 
<<<>>>
 
Description:
 
Separates a sentence into an array of words and reports the fourth word.
 
 
Code:
 
```ahkv2
TestString := "This is a test."
word_array := StrSplit(TestString, A_Space, ".")  
MsgBox "The 4th word is " word_array[4]
```
 
<<<>>>
 
Description:
 
Separates a comma-separated list of colors into an array of substrings and traverses them, one by one.
 
 
Code:
 
```ahkv2
colors := "red,green,blue"
For index, color in StrSplit(colors, ",")
    MsgBox "Color number " index " is " color
```
 
<<<>>>
 
Description:
 
Retrieves a substring with a length of 3 characters at position 4.
 
 
Code:
 
```ahkv2
MsgBox SubStr("123abc789", 4, 3) 
```
 
<<<>>>
 
Description:
 
Retrieves a substring from the beginning and end of a string.
 
 
Code:
 
```ahkv2
Str := "The Quick Brown Fox Jumps Over the Lazy Dog"
MsgBox SubStr(Str, 1, 19)  
MsgBox SubStr(Str, -8)  
```
 
<<<>>>
 
Description:
 
Press a hotkey once to suspend all hotkeys and hotstrings. Press it again to unsuspend.
 
 
Code:
 
```ahkv2
#SuspendExempt
^!s::Suspend  
#SuspendExempt False
```
 
<<<>>>
 
Description:
 
Sends a Suspend command to another script.
 
 
Code:
 
```ahkv2
DetectHiddenWindows True
WM_COMMAND := 0x0111
ID_FILE_SUSPEND := 65404
PostMessage WM_COMMAND, ID_FILE_SUSPEND,,, "C:\YourScript.ahk ahk_class AutoHotkey"
```
 
<<<>>>
 
Description:
 
Compares a number with multiple cases and shows the message box of the first match.
 
 
Code:
 
```ahkv2
switch 2
{
case 1: MsgBox "no match"
case 2: MsgBox "match"
case 3: MsgBox "no match"
}
```
 
<<<>>>
 
Description:
 
The  parameter can be omitted to execute the first case which evaluates to true.
 
 
Code:
 
```ahkv2
str := "The quick brown fox jumps over the lazy dog"
switch
{
case InStr(str, "blue"): MsgBox "false"
case InStr(str, "brown"): MsgBox "true"
case InStr(str, "green"): MsgBox "false"
}
```
 
<<<>>>
 
Description:
 
To test this example, type [ followed by one of the abbreviations listed below, any other 5 characters, or Enter/Esc/Tab/.; or wait for 4 seconds.
 
 
Code:
 
```ahkv2
~[::
{
    ih := InputHook("V T5 L4 C", "{enter}.{esc}{tab}", "btw,otoh,fl,ahk,ca")
    ih.Start()
    ih.Wait()
    switch ih.EndReason
    {
    case "Max":
        MsgBox 'You entered "' ih.Input '", which is the maximum length of text'
    case "Timeout":
        MsgBox 'You entered "' ih.Input '" at which time the input timed out'
    case "EndKey":
        MsgBox 'You entered "' ih.Input '" and terminated it with ' ih.EndKey
    default:  
        switch ih.Input
        {
        case "btw":   Send "{backspace 3}by the way"
        case "otoh":  Send "{backspace 4}on the other hand"
        case "fl":    Send "{backspace 2}Florida"
        case "ca":    Send "{backspace 2}California"
        case "ahk":
            Send "{backspace 3}"
            Run "https://www.autohotkey.com"
        }
    }
}
```
 
<<<>>>
 
Description:
 
Closes unwanted windows whenever they appear.
 
 
Code:
 
```ahkv2
SetTimer CloseMailWarnings, 250
CloseMailWarnings()
{
    WinClose "Microsoft Outlook", "A timeout occured while communicating"
    WinClose "Microsoft Outlook", "A connection to the server could not be established"
}
```
 
<<<>>>
 
Description:
 
Waits for a certain window to appear and then alerts the user.
 
 
Code:
 
```ahkv2
SetTimer Alert1, 500
Alert1()
{
    if not WinExist("Video Conversion", "Process Complete")
        return
 
    SetTimer , 0  
    MsgBox "The video conversion is finished."
}
```
 
<<<>>>
 
Description:
 
Detects single, double, and triple-presses of a hotkey. This allows a hotkey to perform a different operation depending on how many times you press it.
 
 
Code:
 
```ahkv2
#c::
KeyWinC(ThisHotkey)  
{
    static winc_presses := 0
    if winc_presses > 0 
    {
        winc_presses += 1
        return
    }
 
    winc_presses := 1
    SetTimer After400, -400 
    After400()  
    {
        if winc_presses = 1 
        {
            Run "m:\"  
        }
        else if winc_presses = 2 
        {
            Run "m:\multimedia"  
        }
        else if winc_presses > 2
        {
            MsgBox "Three or more clicks detected."
        }
 
        winc_presses := 0
    }
}
```
 
<<<>>>
 
Description:
 
Uses a method as the timer function.
 
 
Code:
 
```ahkv2
counter := SecondCounter()
counter.Start()
Sleep 5000
counter.Stop()
Sleep 2000
class SecondCounter {
    __New() {
        this.interval := 1000
        this.count := 0
 
        this.timer := ObjBindMethod(this, "Tick")
    }
    Start() {
        SetTimer this.timer, this.interval
        ToolTip "Counter started"
    }
    Stop() {
 
        SetTimer this.timer, 0
        ToolTip "Counter stopped at " this.count
    }
 
    Tick() {
        ToolTip ++this.count
    }
}
```
 
<<<>>>
 
Description:
 
Demonstrates the basic concept of  and .
 
 
Code:
 
```ahkv2
try  
{
    HelloWorld
    MakeToast
}
catch as e  
{
    MsgBox "An error was thrown!`nSpecifically: " e.Message
    Exit
}
HelloWorld()  
{
    MsgBox "Hello, world!"
}
MakeToast()  
{
 
    throw Error(A_ThisFunc " is not implemented, sorry")
}
```
 
<<<>>>
 
Description:
 
Demonstrates basic error handling of built-in functions.
 
 
Code:
 
```ahkv2
try
{
 
    FileCopy A_MyDocuments "\*.txt", "D:\Backup\Text documents"
    FileCopy A_MyDocuments "\*.doc", "D:\Backup\Text documents"
    FileCopy A_MyDocuments "\*.jpg", "D:\Backup\Photos"
}
catch
{
    MsgBox "There was a problem while backing the files up!",, "IconX"
    ExitApp 1
}
else
{
    MsgBox "Backup successful."
    ExitApp 0
}
```
 
<<<>>>
 
Description:
 
Demonstrates the use of  dealing with COM errors. For details about the COM object used below, see Using the ScriptControl (Microsoft Docs).
 
 
Code:
 
```ahkv2
try
{
    obj := ComObject("ScriptControl")
    obj.ExecuteStatement('MsgBox "This is embedded VBScript"')  
    obj.InvalidMethod()  
}
catch MemberError  
{
    MsgBox "We tried to invoke a member that doesn't exist."
}
catch as e
{
 
    MsgBox("Exception thrown!`n`nwhat: " e.what "`nfile: " e.file 
        . "`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra,, 16) 
}
```
 
<<<>>>
 
Description:
 
Demonstrates nesting  statements.
 
 
Code:
 
```ahkv2
try Example1 
catch Number as e
    MsgBox "Example1() threw " e
Example1()
{
    try Example2
    catch Number as e
    {
        if (e = 1)
            throw 
        else
            MsgBox "Example2() threw " e
    }
}
Example2()
{
    throw Random(1, 2)
}
```
 
<<<>>>
 
Description:
 
Shows a multiline tooltip at a specific position in the active window.
 
 
Code:
 
```ahkv2
ToolTip "Multiline`nTooltip", 100, 150
```
 
<<<>>>
 
Description:
 
Hides a tooltip after a certain amount of time without having to use Sleep (which would stop the current thread).
 
 
Code:
 
```ahkv2
ToolTip "Timed ToolTip`nThis will be displayed for 5 seconds."
SetTimer () => ToolTip(), -5000
```
 
<<<>>>
 
Description:
 
Trims all spaces from the left and right side of a string.
 
 
Code:
 
```ahkv2
text := "  text  "
MsgBox
(
    "No trim:`t'" text "'
    Trim:`t'" Trim(text) "'
    LTrim:`t'" LTrim(text) "'
    RTrim:`t'" RTrim(text) "'"
)
```
 
<<<>>>
 
Description:
 
Trims all zeros from the left side of a string.
 
 
Code:
 
```ahkv2
MsgBox LTrim("00000123", "0")
```
 
<<<>>>
 
Description:
 
Retrieves and reports the exact type of the values stored in a, b and c.
 
 
Code:
 
```ahkv2
a := 1, b := 2.0, c := "3"
MsgBox Type(a)  
MsgBox Type(b)  
MsgBox Type(c)  
```
 
<<<>>>
 
Description:
 
Turns off the monitor via hotkey. In the SendMessage line, replace the number 2 with -1 to turn on the monitor, or replace it with 1 to activate the monitor's low-power mode.
 
 
Code:
 
```ahkv2
#o::  
{
    Sleep 1000  
    SendMessage 0x0112, 0xF170, 2,, "Program Manager"  
}
```
 
<<<>>>
 
Description:
 
Starts the user's chosen screen saver.
 
 
Code:
 
```ahkv2
SendMessage 0x0112, 0xF140, 0,, "Program Manager"  
```
 
<<<>>>
 
Description:
 
Scrolls up by one line (for a control that has a vertical scroll bar).
 
 
Code:
 
```ahkv2
SendMessage 0x0115, 0, 0, ControlGetFocus("A")
```
 
<<<>>>
 
Description:
 
Scrolls down by one line (for a control that has a vertical scroll bar).
 
 
Code:
 
```ahkv2
SendMessage 0x0115, 1, 0, ControlGetFocus("A")
```
 
<<<>>>
 
Description:
 
Asks Winamp which track number is currently active (see Automating Winamp for more information).
 
 
Code:
 
```ahkv2
SetTitleMatchMode 2
TrackNumber := SendMessage(0x0400, 0, 120,, "- Winamp")
TrackNumber++  
MsgBox "Track #" TrackNumber " is active or playing."
```
 
<<<>>>
 
Description:
 
Finds the process ID of an AHK script (an alternative to WinGetPID).
 
 
Code:
 
```ahkv2
SetTitleMatchMode 2
DetectHiddenWindows true
PID := SendMessage(0x0044, 0x405, 0, , "SomeOtherScript.ahk - AutoHotkey v")
MsgBox PID " is the process id."
```
 
<<<>>>
 
Description:
 
As the user drags the left mouse button, a tooltip displays the size of the region inside the drag-area.
 
 
Code:
 
```ahkv2
CoordMode "Mouse", "Screen"
~LButton::
{
    MouseGetPos &begin_x, &begin_y
    while GetKeyState("LButton")
    {
        MouseGetPos &x, &y
        ToolTip begin_x ", " begin_y "`n" Abs(begin_x-x) " x " Abs(begin_y-y)
        Sleep 10
    }
    ToolTip
}
```
 
<<<>>>
 
Description:
 
Closes either Notepad or another window, depending on which of them was found by the WinActive functions above. Note that the space between an "ahk_" keyword and its criterion value can be omitted; this is especially useful when using variables, as shown by the second WinActive.
 
 
Code:
 
```ahkv2
if WinActive("ahk_class Notepad") or WinActive("ahk_class" ClassName)
    WinClose 
```
 
<<<>>>
 
Description:
 
If Notepad does exist, close it, otherwise close the calculator.
 
 
Code:
 
```ahkv2
if WinExist("Untitled - Notepad")
    WinClose 
else
    WinClose "Calculator"
```
 
<<<>>>
 
Description:
 
Activates either Notepad or another window, depending on which of them was found by the WinExist functions above. Note that the space between an "ahk_" keyword and its criterion value can be omitted; this is especially useful when using variables, as shown by the second WinExist.
 
 
Code:
 
```ahkv2
if WinExist("ahk_class Notepad") or WinExist("ahk_class" ClassName)
    WinActivate 
```
 
<<<>>>
 
Description:
 
Retrieves and reports the unique ID (HWND) of the active window.
 
 
Code:
 
```ahkv2
MsgBox "The active window's ID is " WinExist("A")
```
 
<<<>>>
 
Description:
 
Returns if the calculator does not exist.
 
 
Code:
 
```ahkv2
if not WinExist("Calculator")
    return
```
 
<<<>>>
 
Description:
 
Retrieves and reports the class name of the active window.
 
 
Code:
 
```ahkv2
MsgBox "The active window's class is " WinGetClass("A")
```
 
<<<>>>
 
Description:
 
Retrieves and reports the position and size of the calculator's client area.
 
 
Code:
 
```ahkv2
WinGetClientPos &X, &Y, &W, &H, "Calculator"
MsgBox "Calculator's client area is at " X "," Y " and its size is " W "x" H
```
 
<<<>>>
 
Description:
 
Retrieves and reports the position of the active window's client area.
 
 
Code:
 
```ahkv2
WinGetClientPos &X, &Y,,, "A"
MsgBox "The active window's client area is at " X "," Y
```
 
<<<>>>
 
Description:
 
If Notepad does exist, retrieve and report the position of its client area.
 
 
Code:
 
```ahkv2
if WinExist("Untitled - Notepad")
{
    WinGetClientPos &Xpos, &Ypos 
    MsgBox "Notepad's client area is at " Xpos "," Ypos
}
```
 
<<<>>>
 
Description:
 
Extracts the individual control names from the active window's control list.
 
 
Code:
 
```ahkv2
for n, ctrl in WinGetControls("A")
{
    Result := MsgBox("Control #" n " is '" ctrl "'. Continue?",, 4)
    if (Result = "No")
        break
}
```
 
<<<>>>
 
Description:
 
Displays in real time the active window's control list.
 
 
Code:
 
```ahkv2
SetTimer WatchActiveWindow, 200
WatchActiveWindow()
{
    try
    {
        Controls := WinGetControls("A")
        ControlList := ""
        for ClassNN in Controls
            ControlList .= ClassNN . "`n"
        if (ControlList = "")
            ToolTip "The active window has no controls."
        else
            ToolTip ControlList
    }
    catch TargetError
        ToolTip "No visible window is active."
}
```
 
<<<>>>
 
Description:
 
Maximizes the active window and reports its unique ID.
 
 
Code:
 
```ahkv2
active_id := WinGetID("A")
WinMaximize active_id
MsgBox "The active window's ID is " active_id
```
 
<<<>>>
 
Description:
 
Visits all windows on the entire system and displays info about each of them.
 
 
Code:
 
```ahkv2
ids := WinGetList(,, "Program Manager")
for this_id in ids
{
    WinActivate this_id
    this_class := WinGetClass(this_id)
    this_title := WinGetTitle(this_id)
    Result := MsgBox(
    (
        "Visiting All Windows
        " A_Index " of " ids.Length "
        ahk_id " this_id "
        ahk_class " this_class "
        " this_title "
        Continue?"
    ),, 4)
    if (Result = "No")
        break
}
```
 
<<<>>>
 
Description:
 
Retrieves and reports the position and size of the calculator.
 
 
Code:
 
```ahkv2
WinGetPos &X, &Y, &W, &H, "Calculator"
MsgBox "Calculator is at " X "," Y " and its size is " W "x" H
```
 
<<<>>>
 
Description:
 
Retrieves and reports the position of the active window.
 
 
Code:
 
```ahkv2
WinGetPos &X, &Y,,, "A"
MsgBox "The active window is at " X "," Y
```
 
<<<>>>
 
Description:
 
If Notepad does exist, retrieve and report its position.
 
 
Code:
 
```ahkv2
if WinExist("Untitled - Notepad")
{
    WinGetPos &Xpos, &Ypos 
    MsgBox "Notepad is at " Xpos "," Ypos
}
```
 
<<<>>>
 
Description:
 
Opens the calculator, waits until it exists, and retrieves and reports its text.
 
 
Code:
 
```ahkv2
Run "calc.exe"
WinWait "Calculator"
MsgBox "The text is:`n" WinGetText() 
```
 
<<<>>>
 
Description:
 
Retrieves and reports the title of the active window.
 
 
Code:
 
```ahkv2
MsgBox "The active window is '" WinGetTitle("A") "'."
```
 
<<<>>>
 
Description:
 
Retrieves the transparent color of a window under the mouse cursor.
 
 
Code:
 
```ahkv2
MouseGetPos ,, &MouseWin
TransColor := WinGetTransColor(MouseWin)
```
 
<<<>>>
 
Description:
 
Retrieves the degree of transparency of the window under the mouse cursor.
 
 
Code:
 
```ahkv2
MouseGetPos ,, &MouseWin
TransDegree := WinGetTransparent(MouseWin)
```
 
<<<>>>
 
Description:
 
Opens Notepad, waits until it exists, hides it for a short time and unhides it.
 
 
Code:
 
```ahkv2
Run "notepad.exe"
WinWait "Untitled - Notepad"
Sleep 500
WinHide 
Sleep 1000
WinShow 
```
 
<<<>>>
 
Description:
 
Temporarily hides the taskbar.
 
 
Code:
 
```ahkv2
WinHide "ahk_class Shell_TrayWnd"
Sleep 1000
WinShow "ahk_class Shell_TrayWnd"
```
 
<<<>>>
 
Description:
 
Opens Notepad, waits until it exists and maximizes it.
 
 
Code:
 
```ahkv2
Run "notepad.exe"
WinWait "Untitled - Notepad"
WinMaximize 
```
 
<<<>>>
 
Description:
 
Press a hotkey to maximize the active window.
 
 
Code:
 
```ahkv2
^Up::WinMaximize "A"  
```
 
<<<>>>
 
Description:
 
Opens Notepad, waits until it exists and minimizes it.
 
 
Code:
 
```ahkv2
Run "notepad.exe"
WinWait "Untitled - Notepad"
WinMinimize 
```
 
<<<>>>
 
Description:
 
Press a hotkey to minimize the active window.
 
 
Code:
 
```ahkv2
^Down::WinMinimize "A"  
```
 
<<<>>>
 
Description:
 
Minimizes all windows for 1 second and unminimizes them.
 
 
Code:
 
```ahkv2
WinMinimizeAll
Sleep 1000
WinMinimizeAllUndo
```
 
<<<>>>
 
Description:
 
Opens the calculator, waits until it exists and moves it to the upper-left corner of the screen.
 
 
Code:
 
```ahkv2
Run "calc.exe"
WinWait "Calculator"
WinMove 0, 0 
```
 
<<<>>>
 
Description:
 
Creates a fixed-size popup window that shows the contents of the clipboard, and moves it to the upper-left corner of the screen.
 
 
Code:
 
```ahkv2
MyGui := Gui("ToolWindow -Sysmenu Disabled", "The clipboard contains:")
MyGui.Add("Text",, A_Clipboard)
MyGui.Show("w400 h300")
WinMove 0, 0,,, MyGui
MsgBox "Press OK to dismiss the popup window"
MyGui.Destroy()
```
 
<<<>>>
 
Description:
 
Centers a window on the screen.
 
 
Code:
 
```ahkv2
CenterWindow("ahk_class Notepad")
CenterWindow(WinTitle)
{
    WinGetPos ,, &Width, &Height, WinTitle
    WinMove (A_ScreenWidth/2)-(Width/2), (A_ScreenHeight/2)-(Height/2),,, WinTitle
}
```
 
<<<>>>
 
Description:
 
Unminimizes or unmaximizes Notepad if it is minimized or maximized.
 
 
Code:
 
```ahkv2
WinRestore "Untitled - Notepad"
```
 
<<<>>>
 
Description:
 
Toggles the always-on-top status of the calculator.
 
 
Code:
 
```ahkv2
WinSetAlwaysOnTop -1, "Calculator"
```
 
<<<>>>
 
Description:
 
Changes the title of Notepad. This example may fail on Windows 11 or later, as it requires the classic version of Notepad.
 
 
Code:
 
```ahkv2
WinSetTitle("This is a new title", "Untitled - Notepad")
```
 
<<<>>>
 
Description:
 
Opens Notepad, waits until it is active and changes its title. This example may fail on Windows 11 or later, as it requires the classic version of Notepad.
 
 
Code:
 
```ahkv2
Run "notepad.exe"
WinWaitActive "Untitled - Notepad"
WinSetTitle "This is a new title" 
```
 
<<<>>>
 
Description:
 
Opens the main window, waits until it is active and changes its title.
 
 
Code:
 
```ahkv2
ListVars
WinWaitActive "ahk_class AutoHotkey"
WinSetTitle "This is a new title" 
```
 
<<<>>>
 
Description:
 
Makes all white pixels in Notepad invisible. This example may not work well with the new Notepad on Windows 11 or later.
 
 
Code:
 
```ahkv2
WinSetTransColor "White", "Untitled - Notepad"
```
 
<<<>>>
 
Description:
 
Makes Notepad a little bit transparent.
 
 
Code:
 
```ahkv2
WinSetTransparent 200, "Untitled - Notepad"
```
 
<<<>>>
 
Description:
 
Makes the classic Start Menu transparent (to additionally make the Start Menu's submenus transparent, see example #3).
 
 
Code:
 
```ahkv2
DetectHiddenWindows True
WinSetTransparent 150, "ahk_class BaseBar"
```
 
<<<>>>
 
Description:
 
Makes all or selected menus transparent throughout the system as soon as they appear. Note that although such a script cannot make its own menus transparent, it can make those of other scripts transparent.
 
 
Code:
 
```ahkv2
SetTimer WatchForMenu, 5
WatchForMenu()
{
    DetectHiddenWindows True  
    if WinExist("ahk_class #32768")
        WinSetTransparent 150  
}
```
 
<<<>>>
 
Description:
 
Demonstrates the effects of WinSetTransparent and WinSetTransColor. Note: If you press one of the hotkeys while the mouse cursor is hovering over a pixel that is invisible as a result of TransColor, the window visible beneath that pixel will be acted upon instead!
 
 
Code:
 
```ahkv2
#t::  
{
    MouseGetPos &MouseX, &MouseY, &MouseWin
    MouseRGB := PixelGetColor(MouseX, MouseY)
 
    WinSetTransColor "Off", MouseWin
    WinSetTransColor MouseRGB " 220", MouseWin
}
#o::  
{
    MouseGetPos ,, &MouseWin
    WinSetTransColor "Off", MouseWin
}
#g::  
{
    MouseGetPos ,, &MouseWin
    TransDegree := WinGetTransparent(MouseWin)
    TransColor := WinGetTransColor(MouseWin)
    ToolTip "Translucency:`t" TransDegree "`nTransColor:`t" TransColor
}
```
 
<<<>>>
 
Description:
 
Opens Notepad, waits until it exists, hides it for a short time and unhides it.
 
 
Code:
 
```ahkv2
Run "notepad.exe"
WinWait "Untitled - Notepad"
Sleep 500
WinHide 
Sleep 1000
WinShow 
```
 
<<<>>>
 
Description:
 
Opens Notepad and waits a maximum of 3 seconds until it exists. If WinWait times out, an error message is shown, otherwise Notepad is minimized.
 
 
Code:
 
```ahkv2
Run "notepad.exe"
if WinWait("Untitled - Notepad", , 3)
    WinMinimize 
else
    MsgBox "WinWait timed out."
```
 
<<<>>>
 
Description:
 
Opens Notepad and waits a maximum of 2 seconds until it is active. If WinWait times out, an error message is shown, otherwise Notepad is minimized.
 
 
Code:
 
```ahkv2
Run "notepad.exe"
if WinWaitActive("Untitled - Notepad", , 2)
    WinMinimize 
else
    MsgBox "WinWaitActive timed out."
```
 
<<<>>>
 
Description:
 
Opens Notepad, waits until it exists and then waits until it is closed.
 
 
Code:
 
```ahkv2
Run "notepad.exe"
WinWait "Untitled - Notepad"
WinWaitClose 
MsgBox "Notepad is now closed."
```
 
<<<>>>