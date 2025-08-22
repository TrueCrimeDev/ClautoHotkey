#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

ArrayExtensions.Init()
ArrayDemoGui()

class ArrayExtensions {
    static Init() {
        Array.Prototype.DefineProp("Join", {Call: this.Join})
        Array.Prototype.DefineProp("Map", {Call: this.Map})
        Array.Prototype.DefineProp("Filter", {Call: this.Filter})
        Array.Prototype.DefineProp("ForEach", {Call: this.ForEach})
        Array.Prototype.DefineProp("Find", {Call: this.Find})
        Array.Prototype.DefineProp("IndexOf", {Call: this.IndexOf})
        Array.Prototype.DefineProp("Contains", {Call: this.Contains})
        Array.Prototype.DefineProp("Unique", {Call: this.Unique})
        Array.Prototype.DefineProp("Reverse", {Call: this.Reverse})
        Array.Prototype.DefineProp("Reduce", {Call: this.Reduce})
        Array.Prototype.DefineProp("Sum", {Call: this.Sum})
        Array.Prototype.DefineProp("Average", {Call: this.Average})
        Array.Prototype.DefineProp("Max", {Call: this.Max})
        Array.Prototype.DefineProp("Min", {Call: this.Min})
        Array.Prototype.DefineProp("IsEmpty", {Get: (*) => !this.Length})
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

class ArrayDemoGui {
    __New() {
        this.currentArray := []
        this.presets := Map(
            "Numbers", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            "Fruits", ["apple", "banana", "orange", "apple", "grape", "banana"],
            "Mixed", [1, "hello", 3.14, "world", 42, "test"],
            "With Gaps", [1, , 3, , 5, , 7],
            "Empty", []
        )
        
        this.CreateGUI()
        this.LoadPreset("Numbers")
    }
    
    CreateGUI() {
        this.gui := Gui("+Resize", "Array Operations Visualizer")
        this.gui.SetFont("s9")
        this.gui.MarginX := 10
        this.gui.MarginY := 8
        this.gui.OnEvent("Close", (*) => ExitApp())
        
        this.controls := Map()
        
        this.gui.AddText("xm Section", "Input Array:")
        this.controls["inputEdit"] := this.gui.AddEdit("xm w500 r2")
        
        this.gui.AddText("xm y+8 Section", "Presets:")
        this.controls["emptyBtn"] := this.gui.AddButton("xm w95 h23", "Empty")
        this.controls["emptyBtn"].OnEvent("Click", this.LoadPresetHandler.Bind(this, "Empty"))
        
        this.controls["fruitsBtn"] := this.gui.AddButton("x+5 w95 h23", "Fruits")
        this.controls["fruitsBtn"].OnEvent("Click", this.LoadPresetHandler.Bind(this, "Fruits"))
        
        this.controls["mixedBtn"] := this.gui.AddButton("x+5 w95 h23", "Mixed")
        this.controls["mixedBtn"].OnEvent("Click", this.LoadPresetHandler.Bind(this, "Mixed"))
        
        this.controls["numbersBtn"] := this.gui.AddButton("x+5 w95 h23", "Numbers")
        this.controls["numbersBtn"].OnEvent("Click", this.LoadPresetHandler.Bind(this, "Numbers"))
        
        this.controls["gapsBtn"] := this.gui.AddButton("x+5 w95 h23", "With Gaps")
        this.controls["gapsBtn"].OnEvent("Click", this.LoadPresetHandler.Bind(this, "With Gaps"))
        
        this.gui.AddText("xm y+10 Section", "Transform Operations:")
        this.controls["mapBtn"] := this.gui.AddButton("xm w120 h23", "Map (x*2)")
        this.controls["mapBtn"].OnEvent("Click", this.DoMap.Bind(this))
        
        this.controls["filterBtn"] := this.gui.AddButton("x+5 w120 h23", "Filter (>5)")
        this.controls["filterBtn"].OnEvent("Click", this.DoFilter.Bind(this))
        
        this.controls["uniqueBtn"] := this.gui.AddButton("x+5 w120 h23", "Unique")
        this.controls["uniqueBtn"].OnEvent("Click", this.DoUnique.Bind(this))
        
        this.controls["reverseBtn"] := this.gui.AddButton("x+5 w120 h23", "Reverse")
        this.controls["reverseBtn"].OnEvent("Click", this.DoReverse.Bind(this))
        
        this.gui.AddText("xm y+10 Section", "Aggregate Operations:")
        this.controls["sumBtn"] := this.gui.AddButton("xm w95 h23", "Sum")
        this.controls["sumBtn"].OnEvent("Click", this.DoSum.Bind(this))
        
        this.controls["avgBtn"] := this.gui.AddButton("x+5 w95 h23", "Average")
        this.controls["avgBtn"].OnEvent("Click", this.DoAverage.Bind(this))
        
        this.controls["minBtn"] := this.gui.AddButton("x+5 w95 h23", "Min")
        this.controls["minBtn"].OnEvent("Click", this.DoMin.Bind(this))
        
        this.controls["maxBtn"] := this.gui.AddButton("x+5 w95 h23", "Max")
        this.controls["maxBtn"].OnEvent("Click", this.DoMax.Bind(this))
        
        this.controls["reduceBtn"] := this.gui.AddButton("x+5 w95 h23", "Product")
        this.controls["reduceBtn"].OnEvent("Click", this.DoProduct.Bind(this))
        
        this.gui.AddText("xm y+10 Section", "Search Operations:")
        this.controls["searchEdit"] := this.gui.AddEdit("xm w120 h21", "3")
        
        this.controls["findBtn"] := this.gui.AddButton("x+5 w120 h23", "Find (>n)")
        this.controls["findBtn"].OnEvent("Click", this.DoFind.Bind(this))
        
        this.controls["indexBtn"] := this.gui.AddButton("x+5 w120 h23", "IndexOf")
        this.controls["indexBtn"].OnEvent("Click", this.DoIndexOf.Bind(this))
        
        this.controls["containsBtn"] := this.gui.AddButton("x+5 w120 h23", "Contains")
        this.controls["containsBtn"].OnEvent("Click", this.DoContains.Bind(this))
        
        this.gui.AddText("xm y+10 Section", "Join Operation:")
        this.controls["delimiterEdit"] := this.gui.AddEdit("xm w120 h21", ", ")
        
        this.controls["joinBtn"] := this.gui.AddButton("x+5 w120 h23", "Join")
        this.controls["joinBtn"].OnEvent("Click", this.DoJoin.Bind(this))
        
        this.gui.AddText("xm y+10 Section", "Current Array Visualization:")
        this.controls["arrayDisplay"] := this.gui.AddListView("xm w500 r6", ["Index", "Value", "Type"])
        this.controls["arrayDisplay"].ModifyCol(1, 60)
        this.controls["arrayDisplay"].ModifyCol(2, 300)
        this.controls["arrayDisplay"].ModifyCol(3, 120)
        
        this.gui.AddText("xm y+8 Section", "Result:")
        this.controls["resultEdit"] := this.gui.AddEdit("xm w500 r3 ReadOnly")
        
        this.gui.AddText("xm y+8 Section", "Operation Log:")
        this.controls["logEdit"] := this.gui.AddEdit("xm w500 r2 ReadOnly")
        
        this.controls["updateBtn"] := this.gui.AddButton("xm y+8 w245 h25", "Update from Input")
        this.controls["updateBtn"].OnEvent("Click", this.UpdateFromInput.Bind(this))
        
        this.controls["clearBtn"] := this.gui.AddButton("x+10 w245 h25", "Clear All")
        this.controls["clearBtn"].OnEvent("Click", this.ClearAll.Bind(this))
        
        this.gui.Show("w520")
    }
    
    LoadPresetHandler(name, *) {
        this.LoadPreset(name)
    }
    
    LoadPreset(name) {
        this.currentArray := this.presets[name].Clone()
        this.UpdateDisplay()
        this.LogOperation("Loaded preset: " . name)
    }
    
    UpdateFromInput(*) {
        try {
            input := this.controls["inputEdit"].Value
            input := Trim(input, " []")
            
            if input = "" {
                this.currentArray := []
            } else {
                parts := StrSplit(input, ",")
                this.currentArray := []
                
                for part in parts {
                    part := Trim(part, " `"`'")
                    if part = "" || part = "unset"
                        this.currentArray.Push(unset)
                    else if IsNumber(part)
                        this.currentArray.Push(Number(part))
                    else
                        this.currentArray.Push(part)
                }
            }
            
            this.UpdateDisplay()
            this.LogOperation("Updated array from input")
        } catch as e {
            this.LogOperation("Error: " . e.Message)
        }
    }
    
    UpdateDisplay() {
        this.controls["arrayDisplay"].Delete()
        
        arrayStr := "["
        for index, value in this.currentArray {
            if IsSet(value) {
                valueStr := Type(value) = "String" ? '"' . value . '"' : String(value)
                typeStr := Type(value)
            } else {
                valueStr := "unset"
                typeStr := "Unset"
            }
            
            this.controls["arrayDisplay"].Add("", index, valueStr, typeStr)
            
            arrayStr .= valueStr
            if index < this.currentArray.Length
                arrayStr .= ", "
        }
        arrayStr .= "]"
        
        this.controls["inputEdit"].Value := arrayStr
    }
    
    LogOperation(msg) {
        timestamp := FormatTime(, "HH:mm:ss")
        currentLog := this.controls["logEdit"].Value
        newLog := "[" . timestamp . "] " . msg
        if currentLog != ""
            newLog .= "`n" . currentLog
        this.controls["logEdit"].Value := newLog
    }
    
    ShowResult(result) {
        if Type(result) = "Array" {
            resultStr := "Result Array: ["
            for index, value in result {
                if IsSet(value)
                    resultStr .= (Type(value) = "String" ? '"' . value . '"' : String(value))
                else
                    resultStr .= "unset"
                if index < result.Length
                    resultStr .= ", "
            }
            resultStr .= "]"
        } else {
            resultStr := "Result: " . String(result)
        }
        
        this.controls["resultEdit"].Value := resultStr
    }
    
    DoMap(*) {
        try {
            result := this.currentArray.Map((x) => IsNumber(x) ? x * 2 : x . x)
            this.ShowResult(result)
            this.LogOperation("Map: doubled numbers, repeated strings")
        } catch as e {
            this.LogOperation("Map Error: " . e.Message)
        }
    }
    
    DoFilter(*) {
        try {
            result := this.currentArray.Filter((x) => IsNumber(x) && x > 5)
            this.ShowResult(result)
            this.LogOperation("Filter: values > 5")
        } catch as e {
            this.LogOperation("Filter Error: " . e.Message)
        }
    }
    
    DoUnique(*) {
        try {
            result := this.currentArray.Unique()
            this.ShowResult(result)
            this.LogOperation("Unique: removed duplicates")
        } catch as e {
            this.LogOperation("Unique Error: " . e.Message)
        }
    }
    
    DoReverse(*) {
        try {
            result := this.currentArray.Reverse()
            this.ShowResult(result)
            this.LogOperation("Reverse: reversed array order")
        } catch as e {
            this.LogOperation("Reverse Error: " . e.Message)
        }
    }
    
    DoSum(*) {
        try {
            result := this.currentArray.Sum()
            this.ShowResult(result)
            this.LogOperation("Sum: " . result)
        } catch as e {
            this.LogOperation("Sum Error: " . e.Message)
        }
    }
    
    DoAverage(*) {
        try {
            result := this.currentArray.Average()
            this.ShowResult(Round(result, 2))
            this.LogOperation("Average: " . Round(result, 2))
        } catch as e {
            this.LogOperation("Average Error: " . e.Message)
        }
    }
    
    DoMin(*) {
        try {
            result := this.currentArray.Min()
            this.ShowResult(result)
            this.LogOperation("Min: " . result)
        } catch as e {
            this.LogOperation("Min Error: " . e.Message)
        }
    }
    
    DoMax(*) {
        try {
            result := this.currentArray.Max()
            this.ShowResult(result)
            this.LogOperation("Max: " . result)
        } catch as e {
            this.LogOperation("Max Error: " . e.Message)
        }
    }
    
    DoProduct(*) {
        try {
            nums := this.currentArray.Filter((x) => IsNumber(x))
            if nums.Length > 0 {
                result := nums.Reduce((acc, x) => acc * x, 1)
                this.ShowResult(result)
                this.LogOperation("Product: " . result)
            } else {
                this.LogOperation("Product: No numbers in array")
            }
        } catch as e {
            this.LogOperation("Product Error: " . e.Message)
        }
    }
    
    DoFind(*) {
        try {
            searchVal := Number(this.controls["searchEdit"].Value)
            result := this.currentArray.Find((x) => IsNumber(x) && x > searchVal)
            if IsSet(result) {
                this.ShowResult(result)
                this.LogOperation("Find > " . searchVal . ": " . result)
            } else {
                this.ShowResult("Not found")
                this.LogOperation("Find > " . searchVal . ": Not found")
            }
        } catch as e {
            this.LogOperation("Find Error: " . e.Message)
        }
    }
    
    DoIndexOf(*) {
        try {
            searchVal := this.controls["searchEdit"].Value
            if IsNumber(searchVal)
                searchVal := Number(searchVal)
            
            result := this.currentArray.IndexOf(searchVal)
            this.ShowResult(result > 0 ? "Index: " . result : "Not found")
            this.LogOperation("IndexOf " . searchVal . ": " . (result > 0 ? result : "Not found"))
        } catch as e {
            this.LogOperation("IndexOf Error: " . e.Message)
        }
    }
    
    DoContains(*) {
        try {
            searchVal := this.controls["searchEdit"].Value
            if IsNumber(searchVal)
                searchVal := Number(searchVal)
            
            result := this.currentArray.Contains(searchVal)
            this.ShowResult(result ? "Yes" : "No")
            this.LogOperation("Contains " . searchVal . ": " . (result ? "Yes" : "No"))
        } catch as e {
            this.LogOperation("Contains Error: " . e.Message)
        }
    }
    
    DoJoin(*) {
        try {
            delimiter := this.controls["delimiterEdit"].Value
            result := this.currentArray.Join(delimiter)
            this.ShowResult('"' . result . '"')
            this.LogOperation("Join with '" . delimiter . "'")
        } catch as e {
            this.LogOperation("Join Error: " . e.Message)
        }
    }
    
    ClearAll(*) {
        this.currentArray := []
        this.UpdateDisplay()
        this.controls["resultEdit"].Value := ""
        this.controls["logEdit"].Value := ""
        this.LogOperation("Cleared all")
    }
}