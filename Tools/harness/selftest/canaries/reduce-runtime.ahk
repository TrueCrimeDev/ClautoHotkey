#Requires AutoHotkey v2.1-alpha.30

; Reduce.ahk canary for the dryrun tier. It loads cleanly; its auto-execute
; section computes a few values in memory, then calls a method on a variable
; that is only assigned on a branch never taken. Nothing touches files, the
; registry, the network, the clipboard or any window, so launching it
; directly is harmless: it stops at that call with an UnsetError.

class Ring {
    __New(size) {
        this.Items := []
        this.Size := size
    }

    Push(item) {
        this.Items.Push(item)
        if (this.Items.Length > this.Size)
            this.Items.RemoveAt(1)
        return this
    }
}

Square(n) => n * n

recent := Ring(3)
loop 5
    recent.Push(Square(A_Index))
total := 0
for item in recent.Items
    total += item
if (total > 1000)
    best := Ring(1).Push(total)
best.Push(0)
done := true
