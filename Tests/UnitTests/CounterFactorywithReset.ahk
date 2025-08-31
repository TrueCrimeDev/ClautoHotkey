CreateCounter(initial := 0, step := 1) {
    current := initial

    operations := Map()

    operations["increment"] := () => current += step
    operations["decrement"] := () => current -= step
    operations["get"] := () => current
    operations["reset"] := () => current := initial

    return operations
}

counter := CreateCounter(10, 5)
MsgBox(counter["increment"]())
MsgBox(counter["increment"]())
MsgBox(counter["reset"]())
MsgBox(counter["get"]())