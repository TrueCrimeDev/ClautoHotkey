#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

; The names-first spelling of an import from the AHK module. It reaches the
; original MsgBox exactly as `#Import AHK {...}` does, so the gate must refuse
; this file too.
#Import {MsgBox as RealMsgBox} from AHK
RealMsgBox("a dry run must never show this")
