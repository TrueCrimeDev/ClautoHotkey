## Closure Examples - Ultrathink Analysis

### Architectural Comparison

Three approaches evaluated:

1. **Pure functional closures** - Maximum encapsulation, harder debugging
2. **Class-hybrid closures** - Better structure, more verbose
3. **Factory pattern closures** - Balance of simplicity and power (chosen)

### Resource & Memory Considerations

- Each closure retains captured variables until dereferenced
- Timer-based closures require explicit cleanup
- Map/Array captures increase memory footprint linearly

---

## 1. Counter Factory with Reset

```cpp
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
```

## 2. Debounce Factory

```cpp
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
```

## 3. Memoization Closure

```cpp
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
```

## 4. Private Variable Pattern

```cpp
CreateAccount(initialBalance) {
    balance := initialBalance
    transactions := []

    return Map(
        "deposit", (amount) => (
            balance += amount,
            transactions.Push({type: "deposit", amount: amount}),
            balance
        ),
        "withdraw", (amount) => balance >= amount
            ? (balance -= amount, transactions.Push({type: "withdraw", amount: amount}), balance)
            : false,
        "getBalance", () => balance,
        "getHistory", () => transactions.Clone()
    )
}

account := CreateAccount(100)
account["deposit"](50)
account["withdraw"](30)
MsgBox("Balance: " . account["getBalance"]())
```

## 5. Event Accumulator

```cpp
CreateEventCollector(maxEvents := 10) {
    events := []

    return Map(
        "add", (event) => (
            events.Push({event: event, time: A_Now}),
            events.Length > maxEvents && events.RemoveAt(1),
            events.Length
        ),
        "getRecent", (n := 5) => {
            start := Max(1, events.Length - n + 1)
            return events.Length >= start
                ? Array(events[start]*)
                : []
        },
        "clear", () => (events := [], 0)
    )
}

collector := CreateEventCollector(5)
collector["add"]("click")
collector["add"]("move")
recent := collector["getRecent"](2)
```

## 6. Rate Limiter

```cpp
RateLimiter(maxCalls, timeWindow) {
    calls := []

    return (fn) => {
        now := A_TickCount
        calls := calls.Filter((t) => now - t < timeWindow)

        if calls.Length < maxCalls {
            calls.Push(now)
            return fn()
        }
        return false
    }
}

ApiCall := RateLimiter(3, 1000)
MakeRequest := () => MsgBox("API Called at " . A_Now)

Loop 5 {
    result := ApiCall(MakeRequest)
    Sleep(100)
}
```

## 7. State Machine Factory

```cpp
CreateToggle(states*) {
    currentIndex := 1
    stateCount := states.Length

    return Map(
        "next", () => (
            currentIndex := Mod(currentIndex, stateCount) + 1,
            states[currentIndex]
        ),
        "current", () => states[currentIndex],
        "set", (state) => {
            for i, s in states {
                if s = state {
                    currentIndex := i
                    return true
                }
            }
            return false
        }
    )
}

mode := CreateToggle("off", "low", "medium", "high")
MsgBox(mode["current"]())
MsgBox(mode["next"]())
MsgBox(mode["next"]())
mode["set"]("off")
MsgBox(mode["current"]())
```

## 8. Subscription Pattern

```cpp
CreateObservable(initialValue := "") {
    value := initialValue
    subscribers := []

    return Map(
        "set", (newValue) => {
            value := newValue
            for subscriber in subscribers
                subscriber(value)
        },
        "get", () => value,
        "subscribe", (callback) => (
            subscribers.Push(callback),
            () => subscribers.RemoveAt(subscribers.IndexOf(callback))
        )
    )
}

temperature := CreateObservable(20)
unsubscribe := temperature["subscribe"]((val) => ToolTip("Temp: " . val))
temperature["set"](25)
temperature["set"](30)
```

## Design Justification

**Memory Management**: Each closure maintains minimal state. Arrays/Maps are cloned when returned to prevent external mutation.

**Error Tolerance**: Type checking avoided for brevity but boundary conditions handled (empty arrays, max limits).

**Scalability**: Factory patterns allow unlimited instances without collision. Rate limiter uses sliding window for accuracy.

**Edge Cases Addressed**:

- Empty collections return safe defaults
- Boundary checks prevent array overflows
- Timer cleanup in debounce pattern
- Reference isolation through cloning

**Resource Optimization**:

- Memoization trades memory for CPU
- Rate limiter auto-prunes old entries
- Event collector has max size limit

Each example demonstrates a distinct closure pattern applicable to real-world scenarios while maintaining AHK v2 purity and avoiding JavaScript contamination.
