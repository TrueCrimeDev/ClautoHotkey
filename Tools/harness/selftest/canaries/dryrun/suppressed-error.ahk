#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

; The error is raised in a timer thread and hidden by the script's own
; handler; the script stays resident. Reported, but not fatal.
OnError(SwallowEverything)
SetTimer(Faulty, -10)
Persistent

Faulty() {
    holder := ""
    holder.Missing()
}

SwallowEverything(thrown, mode) {
    return 1
}
