#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

ArrayExtensions.Init()

class ArrayExtensions {
  static Init() {
    Array.Prototype.DefineProp("Join", { Call: this.Join })
    Array.Prototype.DefineProp("Map", { Call: this.Map })
    Array.Prototype.DefineProp("Filter", { Call: this.Filter })
    Array.Prototype.DefineProp("ForEach", { Call: this.ForEach })
    Array.Prototype.DefineProp("Find", { Call: this.Find })
    Array.Prototype.DefineProp("IndexOf", { Call: this.IndexOf })
    Array.Prototype.DefineProp("Contains", { Call: this.Contains })
    Array.Prototype.DefineProp("Unique", { Call: this.Unique })
    Array.Prototype.DefineProp("Reverse", { Call: this.Reverse })
    Array.Prototype.DefineProp("Reduce", { Call: this.Reduce })
    Array.Prototype.DefineProp("Sum", { Call: this.Sum })
    Array.Prototype.DefineProp("Average", { Call: this.Average })
    Array.Prototype.DefineProp("Max", { Call: this.Max })
    Array.Prototype.DefineProp("Min", { Call: this.Min })
    Array.Prototype.DefineProp("IsEmpty", { Get: (*) => !this.Length })
  }

  static Join(delimiter := ", ") {
    result := ""
    for index, value in this {
      if IsSet(value)
        result .= String(value) . delimiter
    }
    return delimiter != "" ? SubStr(result, 1, -StrLen(delimiter)) : result
  }

  static Map(mapper, args*) {
    result := []
    result.Capacity := this.Length

    for value in this {
      if IsSet(value)
        result.Push(mapper(value, args*))
      else
        result.Length++
    }
    return result
  }

  static Filter(predicate, args*) {
    result := []

    for value in this {
      if IsSet(value) && predicate(value, args*)
        result.Push(value)
    }
    return result
  }

  static ForEach(action, args*) {
    for value in this {
      if IsSet(value)
        action(value, args*)
    }
    return this
  }

  static Find(predicate, args*) {
    for value in this {
      if IsSet(value) && predicate(value, args*)
        return value
    }
  }

  static IndexOf(searchValue) {
    for index, value in this {
      if IsSet(value) && value = searchValue
        return index
    }
    return 0
  }

  static Contains(searchValue) {
    return this.IndexOf(searchValue) > 0
  }

  static Unique(caseSense := true) {
    seen := Map()
    seen.CaseSense := caseSense
    result := []

    for value in this {
      if IsSet(value) && !seen.Has(value) {
        seen[value] := true
        result.Push(value)
      }
    }
    return result
  }

  static Reverse() {
    result := []
    result.Length := this.Length

    loop this.Length {
      if this.Has(this.Length - A_Index + 1)
        result[A_Index] := this[this.Length - A_Index + 1]
    }
    return result
  }

  static Reduce(combiner, identity?) {
    if !this.Length {
      if IsSet(identity)
        return identity
      throw Error("Cannot reduce empty array without initial value")
    }

    startIndex := 1
    if IsSet(identity) {
      accumulator := identity
    } else {
      found := false
      for value in this {
        if IsSet(value) {
          accumulator := value
          found := true
          startIndex := A_Index + 1
          break
        }
      }
      if !found
        throw Error("Cannot reduce array with all unset values")
    }

    loop this.Length - startIndex + 1 {
      index := startIndex + A_Index - 1
      if this.Has(index)
        accumulator := combiner(accumulator, this[index])
    }
    return accumulator
  }

  static Sum() {
    result := 0.0
    for value in this {
      if IsSet(value) && IsNumber(value)
        result += value
    }
    return result
  }

  static Average() {
    sum := 0.0
    count := 0
    for value in this {
      if IsSet(value) && IsNumber(value) {
        sum += value
        count++
      }
    }
    return count > 0 ? sum / count : 0
  }

  static Max() {
    if !this.Length
      throw Error("Cannot get max of empty array")

    max := unset
    for value in this {
      if IsSet(value) && IsNumber(value) {
        if !IsSet(max) || value > max
          max := value
      }
    }

    if !IsSet(max)
      throw Error("No numeric values in array")
    return max
  }

  static Min() {
    if !this.Length
      throw Error("Cannot get min of empty array")

    min := unset
    for value in this {
      if IsSet(value) && IsNumber(value) {
        if !IsSet(min) || value < min
          min := value
      }
    }

    if !IsSet(min)
      throw Error("No numeric values in array")
    return min
  }
}

TestArrayExtensions()

TestArrayExtensions() {
  numbers := [1, 2, 3, 4, 5]

  joined := numbers.Join(", ")
  MsgBox("Joined: " . joined)

  doubled := numbers.Map((x) => x * 2)
  MsgBox("Doubled: " . doubled.Join(", "))

  evens := numbers.Filter((x) => Mod(x, 2) = 0)
  MsgBox("Evens: " . evens.Join(", "))

  sum := numbers.Sum()
  MsgBox("Sum: " . sum)

  avg := numbers.Average()
  MsgBox("Average: " . avg)

  fruits := ["apple", "banana", "apple", "orange", "banana"]
  unique := fruits.Unique()
  MsgBox("Unique: " . unique.Join(", "))

  reversed := numbers.Reverse()
  MsgBox("Reversed: " . reversed.Join(", "))

  product := numbers.Reduce((acc, x) => acc * x, 1)
  MsgBox("Product: " . product)

  found := numbers.Find((x) => x > 3)
  MsgBox("First > 3: " . found)

  max := numbers.Max()
  min := numbers.Min()
  MsgBox("Max: " . max . ", Min: " . min)
}