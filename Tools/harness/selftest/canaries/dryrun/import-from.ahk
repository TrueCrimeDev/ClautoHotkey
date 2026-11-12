#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

; The names-first spelling of an import from the AHK module. On a build that
; accepts it, it reaches the original MsgBox exactly as `#Import AHK {...}`
; does; alpha.38 calls it an invalid import. The gate decides from the text,
; before any load, so it must refuse this file on either.
#Import {MsgBox as RealMsgBox} from AHK
RealMsgBox("a dry run must never show this")
