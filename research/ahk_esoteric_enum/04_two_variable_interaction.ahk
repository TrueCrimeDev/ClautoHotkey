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

Join(values) {
    text := ""
    for value in values
        text .= (text = "" ? "" : ",") value
    return text
}

Print(text) {
    FileAppend(text "`n", "*")
}

gen := LazySquares()
pairs := []
for index, value in gen {
    pairs.Push(index ":" value)
    if index >= 4
        break
}
Print("version=" A_AhkVersion)
Print("pairs=" Join(pairs))
Print("produced=" gen.Produced)
Print("enumerators=" gen.Enumerators)
Print("last_num_vars=" gen.LastNumVars)

; Expected for either target version:
; pairs=1:1,2:4,3:9,4:16
; produced=4
; enumerators=1
; last_num_vars=2
