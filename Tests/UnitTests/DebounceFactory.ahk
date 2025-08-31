Debounce(fn, delay) {
    timerRef := 0

    return (args*) => (
        timerRef && SetTimer(timerRef, 0),
        timerRef := SetTimer(() => fn(args*), -delay)
    )
}

SearchHandler := Debounce((text) => MsgBox("Searching: " . text), 500)
SearchHandler("a")
SearchHandler("ab")
SearchHandler("abc")