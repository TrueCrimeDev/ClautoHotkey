#Requires AutoHotkey v2.1-alpha.30

; brokencalc.ahk — pure functions with one planted bug, so the pure-tier
; selftest has exactly one failing assertion to find. Nothing runs at load
; time, so launching it directly does nothing and exits 0.

class BrokenCalc {
    static Add(a, b) => a + b

    ; The planted bug: adds instead of multiplying.
    static Mul(a, b) => a + b
}
