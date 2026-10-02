#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

; Label hotkeys register at load time; the shim suspends them before
; this line runs, so the dry run never owns the keyboard.
Print("suspended=" A_IsSuspended)

F13::Print("F13 fired")
::zqxcanary::should never expand
