#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it, and then
; only ever aims at the sandbox folder SelfTest.ahk created for it. If the
; shim regressed, the damage would stay inside that folder.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)
sandbox := EnvGet("AHK_HARNESS_SELFTEST_SANDBOX")
if (sandbox = "" || !InStr(FileExist(sandbox), "D"))
    ExitApp(0)

FileDelete(sandbox "\sentinel.txt")
out := FileOpen(sandbox "\created.txt", "w")
out.Write("this belongs in the sink")
out.Close()
IniWrite("value", sandbox "\settings.ini", "section", "key")
RegWrite("canary", "REG_SZ", "HKCU\Software\AhkHarnessSelftest", "value")
Run(A_ComSpec " /c exit 3", , "Hide")
DllCall("user32\MessageBoxW", "Ptr", 0, "Str", "a dry run must never show this", "Str", "canary", "UInt", 0)
ComObject("WScript.Shell").Run(A_ComSpec " /c exit 4", 0)
Print("side effects attempted")
