#Requires AutoHotkey v2.0

class LazySquares {
    __New() {
        this.Produced := 0
        this.Enumerators := 0
        this.LastNumVars := 0
    }

    __Enum(numVars) {
        this.Enumerators += 1
        this.LastNumVars := numVars
        state := [0]
        if numVars = 1
            return ObjBindMethod(this, "_YieldOne", state)
        if numVars = 2
            return ObjBindMethod(this, "_YieldTwo", state)
        throw ValueError("LazySquares supports one or two loop variables.", -1, numVars)
    }

    _YieldOne(state, &value) {
        state[1] += 1
        this.Produced += 1
        value := state[1] * state[1]
        return true
    }

    _YieldTwo(state, &index, &value) {
        state[1] += 1
        this.Produced += 1
        index := state[1]
        value := state[1] * state[1]
        return true
    }
}

Print(text) {
    FileAppend(text "`n", "*")
}

gen := LazySquares()
limit := 100000
count := 0
last := 0
for value in gen {
    count += 1
    last := value
    if count >= limit
        break
}
Print("version=" A_AhkVersion)
Print("count=" count)
Print("last=" last)
Print("produced=" gen.Produced)
Print("enumerators=" gen.Enumerators)

; Expected for either target version:
; count=100000
; last=10000000000
; produced=100000
; enumerators=1
