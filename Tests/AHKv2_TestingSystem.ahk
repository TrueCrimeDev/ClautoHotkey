#Requires AutoHotkey v2.0
; AHKv2 Testing System
; Demonstrates the testing system for ClautoHotkey AHK v2 scripts

class TestRunner {
    ; Class variables
    testScripts := []
    testPath := ""
    runCount := 0
    successCount := 0
    
    ; Constructor
    __New(testPath) {
        this.testPath := testPath
    }
    
    ; Find all test scripts in test directory
    FindTestScripts() {
        if (this.testPath = "")
            throw ValueError("Test path not set")
            
        this.testScripts := []
        
        ; Find all .ahk files in test path
        loop files, this.testPath "\*.ahk" {
            this.testScripts.Push(A_LoopFileFullPath)
        }
        
        return this.testScripts.Length
    }
    
    ; Run an individual test
    RunTest(scriptPath) {
        if (!FileExist(scriptPath))
            throw ValueError("Script does not exist: " scriptPath)
            
        this.runCount++
        
        try {
            ; Using the standard AHK v2 execution command
            RunWait '"c:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 "' scriptPath '"',, "Hide"
            
            if (A_LastError = 0) {
                this.successCount++
                return true
            } else {
                return false
            }
        } catch Error as e {
            return false
        }
    }
    
    ; Run all tests
    RunAllTests(guiObj := "") {
        if (this.testScripts.Length = 0)
            this.FindTestScripts()
            
        if (this.testScripts.Length = 0)
            throw ValueError("No test scripts found")
            
        ; Reset counters
        this.runCount := 0
        this.successCount := 0
        
        ; Run each test script
        results := []
        
        for i, scriptPath in this.testScripts {
            ; Get script name for display
            SplitPath scriptPath, &scriptName
            
            ; Update GUI if provided
            if (IsObject(guiObj) && guiObj.HasProp("Text"))
                guiObj.Text := "Running: " scriptName
                
            ; Run the test
            success := this.RunTest(scriptPath)
            
            ; Store result
            results.Push({
                name: scriptName,
                path: scriptPath,
                success: success
            })
        }
        
        return {
            total: this.runCount,
            success: this.successCount,
            results: results
        }
    }
    
    ; Get result summary
    GetSummary(results) {
        summary := "Test Results Summary:`n"
            . "========================`n"
            . "Total Tests: " results.total "`n"
            . "Successful: " results.success "`n"
            . "Failed: " (results.total - results.success) "`n`n"
            
        summary .= "Details:`n"
        
        for i, result in results.results {
            summary .= (i) ". " result.name ": " (result.success ? "✓" : "✗") "`n"
        }
        
        return summary
    }
}

; GUI to display test results
class TestRunnerGUI {
    gui := ""
    testRunner := ""
    outputCtrl := ""
    statusCtrl := ""
    
    ; Constructor
    __New(testRunner) {
        this.testRunner := testRunner
        this._setupGUI()
    }
    
    ; Set up GUI components
    _setupGUI() {
        ; Create main window
        this.gui := Gui(, "ClautoHotkey AHK v2 Test Runner")
        this.gui.SetFont("s10")
        this.gui.OnEvent("Close", (*) => ExitApp())
        
        ; Add controls
        this.gui.AddText("w400", "AHK v2 Testing System for ClautoHotkey")
        this.gui.AddText("w400", "All tests must be located in ClautoHotkey\Tests folder")
        
        ; Path display
        this.gui.AddText("xm w100", "Test Path:")
        pathEdit := this.gui.AddEdit("x+5 w295 Disabled", this.testRunner.testPath)
        
        ; Status display
        this.gui.AddText("xm w100", "Status:")
        this.statusCtrl := this.gui.AddText("x+5 w295", "Ready")
        
        ; Buttons
        runBtn := this.gui.AddButton("xm w100", "Run Tests")
        runBtn.OnEvent("Click", (*) => this._runTests())
        
        reportBtn := this.gui.AddButton("x+10 w100", "Clear")
        reportBtn.OnEvent("Click", (*) => this._clearOutput())
        
        ; Output area
        this.gui.AddText("xm w400", "Test Results:")
        this.outputCtrl := this.gui.AddEdit("xm w400 h300 Disabled -Wrap")
    }
    
    ; Run tests and display results
    _runTests() {
        try {
            ; Update status
            this.statusCtrl.Text := "Scanning for tests..."
            
            ; Find test scripts
            testCount := this.testRunner.FindTestScripts()
            this.statusCtrl.Text := "Found " testCount " test scripts"
            
            if (testCount = 0) {
                this.outputCtrl.Value := "No test scripts found in " this.testRunner.testPath
                return
            }
            
            ; Run tests
            this.statusCtrl.Text := "Running tests..."
            results := this.testRunner.RunAllTests(this.statusCtrl)
            
            ; Display results
            summary := this.testRunner.GetSummary(results)
            this.outputCtrl.Value := summary
            
            ; Update status
            this.statusCtrl.Text := "Completed: " results.success "/" results.total " tests passed"
        } catch Error as e {
            this.outputCtrl.Value := "Error: " e.Message
            this.statusCtrl.Text := "Error occurred"
        }
    }
    
    ; Clear the output area
    _clearOutput() {
        this.outputCtrl.Value := ""
        this.statusCtrl.Text := "Ready"
    }
    
    ; Show the GUI
    Show() {
        this.gui.Show()
    }
}

; Main program
try {
    ; Set up test runner with path to test scripts
    testPath := A_ScriptDir "\Tests"
    
    ; Initialize objects properly
    myRunner := TestRunner(testPath)
    
    ; Create and show GUI
    myGui := TestRunnerGUI(myRunner)
    myGui.Show()
} catch Error as e {
    MsgBox "Error: " e.Message "`n" e.Stack
    ExitApp
}
