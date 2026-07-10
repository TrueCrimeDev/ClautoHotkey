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
zero := Take(gen, 0)
Print("version=" A_AhkVersion)
Print("zero_length=" zero.Length)
Print("after_zero_produced=" gen.Produced)
Print("after_zero_enumerators=" gen.Enumerators)
negative := Take(gen, -3)
Print("negative_length=" negative.Length)
Print("after_negative_produced=" gen.Produced)
Print("after_negative_enumerators=" gen.Enumerators)
one := Take(gen, 1)
Print("one_values=" Join(one))
Print("after_one_produced=" gen.Produced)
Print("after_one_enumerators=" gen.Enumerators)

; Expected for either target version:
; zero_length=0
; after_zero_produced=0
; after_zero_enumerators=0
; negative_length=0
; after_negative_produced=0
; after_negative_enumerators=0
; one_values=1
; after_one_produced=1
; after_one_enumerators=1
