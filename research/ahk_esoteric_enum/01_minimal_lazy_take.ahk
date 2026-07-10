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

Take(enumerable, count) {
    values := []
    if count <= 0
        return values
    for value in enumerable {
        values.Push(value)
        if values.Length >= count
            break
    }
    return values
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
Print("version=" A_AhkVersion)
Print("before=" gen.Produced)
values := Take(gen, 5)
Print("values=" Join(values))
Print("produced=" gen.Produced)
Print("enumerators=" gen.Enumerators)

; Expected for either target version:
; before=0
; values=1,4,9,16,25
; produced=5
; enumerators=1
