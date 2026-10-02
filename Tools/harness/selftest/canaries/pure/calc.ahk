#Requires AutoHotkey v2.1-alpha.30

; calc.ahk — pure functions for the pure-tier selftest. Nothing runs at load
; time, so launching it directly does nothing and exits 0. Its tests are
; calc.test.ahk, which GatePure finds by name next to it.

class Calc {
    static Add(a, b) => a + b

    static Mul(a, b) => a * b

    static Div(a, b) {
        if (b = 0)
            throw ZeroDivisionError("division by zero")
        return a / b
    }

    ; "3, 1, ,2" -> [3, 1, 2]. Blank items are skipped; anything else that is
    ; not a number is the caller's mistake.
    static Split(text) {
        out := []
        for part in StrSplit(text, ",", " `t") {
            if (part = "")
                continue
            if !IsNumber(part)
                throw ValueError("not a number", -1, part)
            out.Push(Number(part))
        }
        return out
    }

    ; How often each word occurs: word -> count.
    static Tally(words) {
        counts := Map()
        for word in words
            counts[word] := counts.Get(word, 0) + 1
        return counts
    }

    static Bounds(numbers) {
        if !numbers.Length
            throw ValueError("no numbers to bound", -1)
        low := numbers[1]
        high := numbers[1]
        for value in numbers {
            low := Min(low, value)
            high := Max(high, value)
        }
        return CalcRange(low, high)
    }
}

class CalcRange {
    __New(low, high) {
        this.Low := low
        this.High := high
    }
}
