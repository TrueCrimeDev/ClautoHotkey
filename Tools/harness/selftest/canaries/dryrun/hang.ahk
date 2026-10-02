#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

; A blocking native call: the message loop cannot answer, so the
; gate has to terminate it and report it wedged.
DllCall("Sleep", "UInt", 60000)
