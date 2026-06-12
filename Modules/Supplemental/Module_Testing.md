<TESTING_FRAMEWORK>

```cpp
class TestFramework {
    static Tests := Map()
    static Results := Map()

    static __New() {
        TestFramework.Results["passed"] := 0
        TestFramework.Results["failed"] := 0
    }

    static AddTest(name, testFunc) {
        TestFramework.Tests[name] := testFunc
    }

    static RunTests() {
        for name, test in TestFramework.Tests {
            try {
                result := test()
                if (result) {
                    TestFramework.Results["passed"]++
                    Print("Test '{}' passed", name)
                } else {
                    TestFramework.Results["failed"]++
                    Print("Test '{}' failed", name)
                }
            } catch Error as e {
                TestFramework.Results["failed"]++
                Print("Test '{}' threw an exception: {}", name, e.Message)
            }
        }

        Print("Test results - passed: {}, failed: {}"
            , TestFramework.Results["passed"], TestFramework.Results["failed"])

        return TestFramework.Results["failed"] = 0
    }

    static Assert(condition, message := "") {
        if (!condition) {
            if (message)
                Print("Assertion failed: {}", message)
            return false
        }
        return true
    }
}

; Usage example — multi-statement test bodies need a named function,
; never a block-body fat arrow (`() => { ... }` is a syntax error)
TestStringManipulation() {
    result := StrReplace("Hello World", "World", "AHK")
    return TestFramework.Assert(result = "Hello AHK", "String replacement failed")
}

TestFramework.AddTest("StringManipulation", TestStringManipulation)
TestFramework.RunTests()
```

`Print` is a +Console fork BIF (variadic, stdout). On stock AutoHotkey v2 substitute `OutputDebug`; test runs in this project target the fork.
</TESTING_FRAMEWORK>

<MEMORY_MANAGEMENT>
When writing AHK v2 scripts that manage resources:

Always release COM objects:

```cpp
comObj := ComObject("Excel.Application")
try {
    ; Use COM object
} finally {
    comObj := ""  ; Release COM object
}
```

Properly handle file handles:

```cpp
file := FileOpen(A_ScriptDir "\data.txt", "r")
try {
    content := file.Read()
} finally {
    file.Close()
}
```

Cancel timers when objects are destroyed:

```cpp
class TimerExample {
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
```

Use explicit object cleanup in long-running scripts:

```cpp
ProcessLargeData() {
    largeArray := Array()
    Loop 10000 {
        largeArray.Push(GetComplexData())
    }

    result := ProcessArray(largeArray)
    largeArray := ""  ; Release memory earlier

    return result
}
```
</MEMORY_MANAGEMENT>

<MODULAR_ARCHITECTURE>

```cpp
; Main script: Main.ahk
#Requires AutoHotkey v2.1-alpha.30
#SingleInstance Force

; Include modules
#Include Modules\Config.ahk
#Include Modules\Utils.ahk
#Include Modules\GUI.ahk

; Initialize application
app := Application()

class Application {
    __New() {
        ; Initialize modules
        this.config := ConfigModule()
        this.utils := UtilsModule()
        this.gui := GUIModule(this)

        ; Setup event handlers
        this.SetupEvents()
    }

    SetupEvents() {
        ; Register hotkeys
        Hotkey "^!r", (*) => Reload()
        Hotkey "^!e", (*) => ExitApp()
    }
}
```

```cpp
; Modules\Config.ahk
class ConfigModule {
    __New() {
        this.settings := Map()
        this.settings["appName"] := "ModularApp"
        this.settings["version"] := "1.0.0"
        this.settings["dataPath"] := A_ScriptDir "\Data"
    }

    GetSetting(key) {
        return this.settings.Has(key) ? this.settings[key] : ""
    }
}

; Modules\Utils.ahk - Implement utility functions
; Modules\GUI.ahk - Implement GUI components
```
</MODULAR_ARCHITECTURE>

<PERFORMANCE_OPTIMIZATION>
When optimizing AutoHotkey v2 scripts:

- Prefer SetTimer over loops for recurring tasks
- Use native AHK functions instead of custom implementations
- Minimize COM object creation and destruction in loops
- Cache values accessed repeatedly instead of recalculating
- Use Map() and Array() efficiently without unnecessary rebuilding
- Optimize string operations by pre-allocating when possible
- Limit GUI redraws during batch updates: build/populate controls before calling `.Show()`, and wrap bulk control fills (e.g. ListView) with WM_SETREDRAW — `SendMessage(0x000B, 0, 0, ctl.Hwnd)` before, `SendMessage(0x000B, 1, 0, ctl.Hwnd)` plus a redraw after
- Prefer local variables over global for faster access
- Use IniRead/IniWrite with caching when appropriate instead of FileRead/FileWrite
- Consider using DllCall for performance-critical operations

Performance Example:

```cpp
; Inefficient: no pre-allocation, array grows repeatedly
results := []
Loop 1000 {
    randVal := Random(1, 100)
    if InStr(randVal, "5")
        results.Push(randVal)
}

; Optimized: pre-allocate when the approximate size is known
results := []
results.Capacity := 200
Loop 1000 {
    randVal := Random(1, 100)
    if InStr(randVal, "5")
        results.Push(randVal)
}
```
</PERFORMANCE_OPTIMIZATION>

<ERROR_HANDLING_FRAMEWORK>

```cpp
class ErrorHandler {
    static ErrorCodes := Map()

    static __New() {
        ErrorHandler.ErrorCodes["FILE_NOT_FOUND"] := "The specified file could not be found"
        ErrorHandler.ErrorCodes["INVALID_PARAMETER"] := "An invalid parameter was passed to the function"
        ErrorHandler.ErrorCodes["GUI_CREATION_FAILED"] := "Failed to create GUI element"
        ErrorHandler.ErrorCodes["HOTKEY_REGISTRATION_FAILED"] := "Failed to register hotkey"
    }

    static Log(errorType, additionalInfo := "") {
        errorMessage := ErrorHandler.ErrorCodes.Has(errorType)
            ? ErrorHandler.ErrorCodes[errorType]
            : "Unknown error"

        logEntry := FormatTime(, "yyyy-MM-dd HH:mm:ss") " - " errorType ": " errorMessage
        if (additionalInfo)
            logEntry .= " - " additionalInfo

        try {
            FileAppend logEntry "`n", A_ScriptDir "\error.log"
        } catch OSError as err {
            Print("Could not write error log: {}", err.Message)
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

; Usage example — throw Error objects, never bare strings
; (`throw "X"` is not caught by `catch Error`)
try {
    if !FileExist(filePath)
        throw Error("FILE_NOT_FOUND")
    file := FileOpen(filePath, "r")
    content := file.Read()
    file.Close()
} catch Error as e {
    if (e.Message = "FILE_NOT_FOUND")
        ErrorHandler.Handle("FILE_NOT_FOUND", "Path: " filePath)
    else
        ErrorHandler.Handle("UNKNOWN", "Details: " e.Message)
}
```
</ERROR_HANDLING_FRAMEWORK>
