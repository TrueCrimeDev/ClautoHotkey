#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

; The statement form, with no leading #. Whether a given build still accepts
; it is beside the point: the gate decides from the text, before any load.
Import {MsgBox as RealMsgBox} from AHK
RealMsgBox("a dry run must never show this")
