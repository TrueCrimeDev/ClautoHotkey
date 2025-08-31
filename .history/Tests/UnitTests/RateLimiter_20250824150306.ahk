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