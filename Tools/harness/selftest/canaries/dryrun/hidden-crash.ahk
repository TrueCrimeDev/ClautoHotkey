#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

; The handler hides the error from stderr, but it is raised in the
; auto-execute section, which dies anyway: a crash the gate must still see.
OnError(SwallowEverything)
holder := ""
holder.Missing()
Print("never reached")

SwallowEverything(thrown, mode) {
    return 1
}
