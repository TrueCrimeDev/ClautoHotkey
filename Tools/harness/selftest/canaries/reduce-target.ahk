#Requires AutoHotkey v2.1-alpha.30

; Reduce.ahk canary: valid AutoHotkey v2 except for ONE deliberate parse
; error, the unclosed "(" in Summarise. The interpreter refuses to load the
; file, so launching it runs nothing. Reduce.ahk should cut it down to the
; failing line plus the "}" the error is reported against.

class Tally {
    __New() {
        this.Counts := Map()
    }

    Add(key) {
        this.Counts[key] := this.Counts.Get(key, 0) + 1
        return this
    }

    Total() {
        sum := 0
        for key, count in this.Counts
            sum += count
        return sum
    }
}

Summarise(tally) {
    share := Round(tally.Total() / Max(tally.Counts.Count, 1), 2
    return Format("{} keys, {} per key", tally.Counts.Count, share)
}

Clamp(value, low, high) {
    return Min(Max(value, low), high)
}

tally := Tally()
for word in StrSplit("red green red blue", " ")
    tally.Add(word)
loop 3
    tally.Add("pass" A_Index)
result := Clamp(tally.Total(), 0, 100)
