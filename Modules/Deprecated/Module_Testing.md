<TESTING_FRAMEWORK>
class TestFramework {
static Tests := Map()
static Results := Map(
"passed", 0,
"failed", 0
)
Copystatic AddTest(name, testFunc) {
    TestFramework.Tests[name] := testFunc
}

static RunTests() {
    for name, test in TestFramework.Tests {
        try {
            result := test()
            if (result) {
                TestFramework.Results["passed"]++
                OutputDebug "Test '" name "' passed"
            } else {
                TestFramework.Results["failed"]++
                OutputDebug "Test '" name "' failed"
            }
        } catch Error as e {
            TestFramework.Results["failed"]++
            OutputDebug "Test '" name "' threw an exception: " e.Message
        }
    }
    
    OutputDebug "------- Test Results -------"
    OutputDebug "Passed: " TestFramework.Results["passed"]
    OutputDebug "Failed: " TestFramework.Results["failed"]
    
    return TestFramework.Results["failed"] = 0
}

static Assert(condition, message := "") {
    if (!condition) {
        if (message)
            OutputDebug "Assertion failed: " message
        return false
    }
    return true
}
}
; Usage example
TestFramework.AddTest("StringManipulation", () => {
result := StrReplace("Hello World", "World", "AHK")
return TestFramework.Assert(result = "Hello AHK", "String replacement failed")
})
TestFramework.RunTests()
</TESTING_FRAMEWORK>

<MEMORY_MANAGEMENT>
When writing AHK v2 scripts that manage resources:

Always release COM objects:

cppCopycomObj := ComObject("Excel.Application")
try {
    ; Use COM object
} finally {
    comObj := ""  ; Release COM object
}

Properly handle file handles:

cppCopyfile := FileOpen(A_ScriptDir "\data.txt", "r")
try {
    content := file.Read()
} finally {
    file.Close()
}

Cancel timers when objects are destroyed:

cppCopyclass TimerExample {
    __New() {
        this.timerCallback := this.Update.Bind(this)
        SetTimer(this.timerCallback, 1000)
    }
    
    Update() {
        ; Do something
    }
    
    __Delete() {
        SetTimer(this.timerCallback, 0)  ; Cancel timer
    }
}

Use explicit object cleanup in long-running scripts:

cppCopyProcessLargeData() {
    largeArray := Array()
    Loop 10000 {
        largeArray.Push(GetComplexData())
    }
    
    result := ProcessArray(largeArray)
    largeArray := ""  ; Release memory earlier
    
    return result
}
</MEMORY_MANAGEMENT>

<MODULAR_ARCHITECTURE>
; Main script: Main.ahk
#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force
; Include modules
#Include Modules\Config.ahk
#Include Modules\Utils.ahk
#Include Modules\GUI.ahk
; Initialize application
app := Application()
return
; Application class
Application() {
class Application {
__New() {
; Initialize modules
this.config := ConfigModule()
this.utils := UtilsModule()
this.gui := GUIModule(this)
Copy        ; Setup event handlers
        this.SetupEvents()
    }
    
    SetupEvents() {
        ; Register hotkeys
        Hotkey "^!r", (*) => this.Reload()
        Hotkey "^!e", (*) => this.Exit()
    }
    
    Reload() {
        Reload
    }
    
    Exit() {
        ExitApp
    }
}
}
; Modules\Config.ahk
ConfigModule() {
class ConfigModule {
__New() {
this.settings := Map(
"appName", "ModularApp",
"version", "1.0.0",
"dataPath", A_ScriptDir "\Data"
)
}
Copy    GetSetting(key) {
        return this.settings.Has(key) ? this.settings[key] : ""
    }
}
}
; Modules\Utils.ahk - Implement utility functions
; Modules\GUI.ahk - Implement GUI components
</MODULAR_ARCHITECTURE>


<PERFORMANCE_OPTIMIZATION>
When optimizing AutoHotkey v2 scripts:

- Prefer SetTimer over loops for recurring tasks
- Use native AHK functions instead of custom implementations
- Minimize COM object creation and destruction in loops
- Cache values accessed repeatedly instead of recalculating
- Use Map() and Array() efficiently without unnecessary rebuilding
- Optimize string operations by pre-allocating when possible
- Limit GUI redraws during batch updates using Gui.Opt("+OwnDialogs")
- Prefer local variables over global for faster access
- Use IniRead/IniWrite with caching when appropriate instead of FileRead/FileWrite
- Consider using DllCall for performance-critical operations

Performance Example:
```cpp
; Inefficient
Loop 1000 {
    Random randVal, 1, 100
    if InStr(A_LoopField, "5")
        results.Push(A_LoopField)
}

; Optimized
results := []
results.Capacity := 200  ; Pre-allocate if approximate size known
Loop 1000 {
    if InStr(A_LoopField, "5")
        results.Push(A_LoopField)
}
</PERFORMANCE_OPTIMIZATION>


<ERROR_HANDLING_FRAMEWORK>
class ErrorHandler {
static ErrorCodes := Map(
"FILE_NOT_FOUND", "The specified file could not be found",
"INVALID_PARAMETER", "An invalid parameter was passed to the function",
"GUI_CREATION_FAILED", "Failed to create GUI element",
"HOTKEY_REGISTRATION_FAILED", "Failed to register hotkey"
)
static Log(errorType, additionalInfo := "") {
    errorMessage := ErrorHandler.ErrorCodes.Has(errorType) ? 
                    ErrorHandler.ErrorCodes[errorType] : 
                    "Unknown error"
    
    logEntry := FormatTime(, "yyyy-MM-dd HH:mm:ss") " - " errorType ": " errorMessage
    if (additionalInfo)
        logEntry .= " - " additionalInfo
        
    try {
        FileAppend logEntry "`n", A_ScriptDir "\error.log"
    }
    return errorMessage
}

static Handle(errorType, additionalInfo := "", showMessage := true) {
    errorMessage := ErrorHandler.Log(errorType, additionalInfo)
    if (showMessage)
        MsgBox "Error: " errorMessage, "Error", 16
    return false
}
}
; Usage example
try {
file := FileOpen(filePath, "r")
if !IsObject(file)
throw "FILE_NOT_FOUND"
} catch Error as e {
if (e = "FILE_NOT_FOUND")
ErrorHandler.Handle("FILE_NOT_FOUND", "Path: " filePath)
else
ErrorHandler.Handle("UNKNOWN", "Details: " e.Message)
}
</ERROR_HANDLING_FRAMEWORK>
