#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

; A native dialog the shim does not intercept (ShellAbout is harmless and
; modal). The window watch must see it, close it, and report it.
DllCall("shell32\ShellAboutW", "Ptr", 0, "Str", "AhkHarness canary", "Str", "", "Ptr", 0)
Print("dialog returned")
