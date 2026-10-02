#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

main := Gui(, "Canary")
main.Add("Text", , "hello")
main.Add("Button", "w80", "OK").OnEvent("Click", (*) => 0)
main.Show()
Print("hwnd=" main.Hwnd)
