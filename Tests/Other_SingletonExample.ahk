#Requires AutoHotkey v2.0
; Singleton pattern demonstration in AHKv2

class Logger {
    static instance := ""

    logFile := ""
    isEnabled := true

    ; Standard constructor
    __New(logFilePath) {
        this.logFile := logFilePath
        this.Log("Logger initialized")
    }

    ; Get singleton instance (static factory method)
    static GetInstance(logFilePath := "") {
        if !Logger.instance {
            if (logFilePath = "")
                logFilePath := A_ScriptDir "\log.txt"
            Logger.instance := Logger(logFilePath)
        }
        return Logger.instance
    }

    ; Log a message
    Log(message) {
        if (!this.isEnabled)
            return

        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        logEntry := timestamp ": " message "`n"

        try {
            FileAppend(logEntry, this.logFile)
        }
        catch Error as e {
            MsgBox "Error writing to log: " e.Message
        }
    }

    ; Enable/disable logging
    Enable(value := true) {
        prevState := this.isEnabled
        this.isEnabled := value
        this.Log("Logging " (value ? "enabled" : "disabled"))
        return prevState
    }
}

; Application code that uses the singleton
class Application {
    logger := ""
    name := ""

    __New(name) {
        this.name := name
        this.logger := Logger.GetInstance()
        this.logger.Log("Application created: " name)
    }

    Run() {
        this.logger.Log("Application running: " this.name)
        MsgBox "Application " this.name " is now running"
    }

    Stop() {
        this.logger.Log("Application stopped: " this.name)
        MsgBox "Application " this.name " stopped"
    }
}

; Test singleton pattern
try {
    ; Create a logger directly (not using singleton)
    directLogger := Logger(A_ScriptDir "\direct.log")
    directLogger.Log("This is from direct logger")

    ; Use the singleton pattern
    logger1 := Logger.GetInstance(A_ScriptDir "\singleton.log")
    logger1.Log("This is from logger1")

    ; Get instance again, should be the same object
    logger2 := Logger.GetInstance()
    logger2.Log("This is from logger2")

    ; Verify both logger1 and logger2 point to the same instance
    if (logger1 == logger2)
        MsgBox "Singleton verified: Both loggers are the same instance"
    else
        MsgBox "Singleton failed: Different instances"

    ; Create applications that use the logger
    app1 := Application("Calculator")
    app2 := Application("Notepad")

    ; Run applications
    app1.Run()
    app2.Run()

    ; Stop applications
    app1.Stop()
    app2.Stop()

    ; Show completion message
    MsgBox "Test completed. Log files created:`n- " A_ScriptDir "\direct.log`n- " A_ScriptDir "\singleton.log"
} catch Error as e {
    MsgBox "Error: " e.Message "`n" e.Stack
}