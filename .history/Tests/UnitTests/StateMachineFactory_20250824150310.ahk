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