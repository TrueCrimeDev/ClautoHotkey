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