#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

; The import sits one #Include away. The preflight scan follows includes, so
; this file is refused like the ones that import directly.
#Include inc\real-builtins.ahk
RealMsgBox("a dry run must never show this")
