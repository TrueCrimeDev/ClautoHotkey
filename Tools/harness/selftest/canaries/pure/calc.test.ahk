#Requires AutoHotkey v2.1-alpha.30

; calc.test.ahk — passing TestKit tests for calc.ahk: 12 assertions in five
; cases, covering DeepEq on an Array, a Map and a class instance, and Throws
; with an error class and with a message substring. Pure, so launching it
; directly is harmless: it prints its records and exits 0.

#Include %A_LineFile%\..\..\..\..\TestKit.ahk
#Include %A_LineFile%\..\calc.ahk

TestKit.Test("adds and multiplies", Arithmetic)
TestKit.Test("divides, and refuses zero", Division)
TestKit.Test("splits a list", Splitting)
TestKit.Test("tallies words", Tallying)
TestKit.Test("finds bounds", Bounding)
TestKit.Summary()

Arithmetic() {
    TestKit.Eq(Calc.Add(2, 3), 5, "2 + 3")
    TestKit.Eq(Calc.Mul(3, 4), 12, "3 * 4")
    TestKit.Ne(Calc.Add(2, 2), 5, "2 + 2 is not 5")
}

Division() {
    TestKit.Near(Calc.Div(1, 3), 0.333333, 1e-6, "1 / 3")
    TestKit.Throws(() => Calc.Div(1, 0), "1 / 0", ZeroDivisionError)
    TestKit.Throws(() => Calc.Div(1, 0), "1 / 0 message", "by zero")
}

Splitting() {
    TestKit.DeepEq(Calc.Split("3, 1, ,2"), [3, 1, 2], "blank items skipped")
    TestKit.Throws(() => Calc.Split("1,x"), "text rejected", ValueError)
    TestKit.Truthy(Calc.Split("").Length = 0, "empty text, empty list")
}

Tallying() {
    expected := Map()
    expected["apple"] := 2
    expected["pear"] := 1
    TestKit.DeepEq(Calc.Tally(["apple", "pear", "apple"]), expected, "counts per word")
}

Bounding() {
    TestKit.DeepEq(Calc.Bounds([3, 1, 2]), CalcRange(1, 3), "low and high")
    TestKit.Throws(() => Calc.Bounds([]), "empty list", ValueError)
}
