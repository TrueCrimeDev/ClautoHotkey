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