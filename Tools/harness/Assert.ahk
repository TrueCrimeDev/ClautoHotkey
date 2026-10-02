#Requires AutoHotkey v2.1-alpha.30

; Assert.ahk — the qa-style name for TestKit, for tests that read better as
; Assert.Eq(...) and for files written against the fork's qa\Assert.ahk.
; Everything is inherited: TestKit keeps its counters on itself and never
; refers to `this`, so Assert.Eq and TestKit.Eq in one file count once.
;
; If the code under test already defines a class named Assert, this file
; cannot be used — include TestKit.ahk directly and call TestKit.* instead.

#Include %A_LineFile%\..\TestKit.ahk

class Assert extends TestKit {
}
