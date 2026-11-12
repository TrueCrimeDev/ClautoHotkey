#Requires AutoHotkey v2.1-alpha.30

; Selftest canary: does nothing unless SelfTest.ahk launched it.
if (EnvGet("AHK_HARNESS_SELFTEST") != "1")
    ExitApp(0)

; Layout code reads sizes back through ByRef parameters and does arithmetic on
; them. Under the dry-run stand-in none of these may come back unset, and the
; numbers are the ones this script itself passed to Show, Add and Move.
main := Gui("+Resize", "Canary")
button := main.Add("Button", "x10 y10 w80", "OK")
main.Show("w640 h480")
main.GetPos(&winX, &winY, &winW, &winH)
main.GetClientPos(, , &clientW, &clientH)
button.GetPos(&btnX, &btnY, &btnW, &btnH)
button.Move(, , 120, 30)
button.GetPos(, , &movedW, &movedH)
margin := clientW - (btnX + btnW)
Print("window " winW "x" winH " client " clientW "x" clientH " button " btnW "x" btnH
    . " moved " movedW "x" movedH " margin " margin)
