Memoize(fn) {
    cache := Map()

    return (arg) => cache.Has(arg)
        ? cache[arg]
        : cache[arg] := fn(arg)
}

ExpensiveCalc := (n) => (Sleep(1000), n * n)
FastCalc := Memoize(ExpensiveCalc)

MsgBox(FastCalc(5))
MsgBox(FastCalc(5))
MsgBox(FastCalc(10))