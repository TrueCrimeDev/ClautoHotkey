#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

#Import AHK {MsgBox as RealMsgBox}
RealMsgBox("a dry run must never show this")
