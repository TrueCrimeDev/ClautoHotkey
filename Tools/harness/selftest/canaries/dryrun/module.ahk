#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it, and then only
; ever aims at the sandbox folder SelfTest.ahk created for it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

; No import from AHK anywhere in this file. Wipe lives in a module of its own,
; and a module resolves FileDelete to the built-in: the shim's shadow is a
; declaration in the main module, which Worker cannot see. Run under the shim,
; this would delete the sandbox sentinel for real, so the gate must refuse it.
#Import Worker {Wipe}
Wipe()

#Module Worker
Wipe() {
    if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
        return 0
    sandbox := EnvGet("AHK_HARNESS_SELFTEST_SANDBOX")
    if (sandbox = "" || !InStr(FileExist(sandbox), "D"))
        return 0
    FileDelete(sandbox "\sentinel.txt")
    return 1
}
