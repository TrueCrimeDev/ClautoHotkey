#Requires AutoHotkey v2.1-alpha.30

; brokencalc.test.ahk — one passing and exactly one failing assertion. The
; failure is the "multiplies" case on line 12; the selftest checks that
; GatePure reports it at that line. Pure, so launching it directly is
; harmless; it exits 1 — one failed assertion — by design.

#Include %A_LineFile%\..\..\..\..\TestKit.ahk
#Include %A_LineFile%\..\brokencalc.ahk

TestKit.Test("adds", () => TestKit.Eq(BrokenCalc.Add(2, 3), 5, "Add(2, 3)"))
TestKit.Test("multiplies", () => TestKit.Eq(BrokenCalc.Mul(3, 4), 12, "Mul(3, 4)"))
TestKit.Summary()
