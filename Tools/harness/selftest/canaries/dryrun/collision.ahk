#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

; Defines a name the shim shadows; the gate must drop that shadow
; rather than fail the load on a duplicate definition.
MsgBox(text := "", title := "", options := "") {
    Print("own msgbox: " text)
    return "OK"
}

MsgBox("from the candidate")
