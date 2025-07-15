# Topic: Extending Built-in Objects with Prototype Methods

## Category

Snippet

## Overview

This collection of snippets demonstrates how to extend AutoHotkey's built-in objects (Array, Map, String, etc.) with custom methods using prototype-based programming. These extensions can significantly improve code readability and reduce redundancy by adding commonly needed functionality to core data types.

## Key Points

- Prototype methods affect all instances of a data type
- Added methods persist for the lifetime of the script
- Can significantly improve code readability and reduce boilerplate
- Useful for implementing methods from other languages (Python, JavaScript, etc.)
- Helps maintain a more consistent and expressive API

## Syntax and Parameters

```cpp
; Basic syntax for adding methods to built-in types
BuiltInType.Prototype.DefineProp("MethodName", {Call: ImplementationFunction})

; Implementation function with object as first parameter
ImplementationFunction(obj, param1, param2, ...) {
    ; Method implementation
    return result
}
```

## Code Examples

### Array Extensions

```cpp
; Add Contains method to check if an item exists in array
Array.Prototype.DefineProp("Contains", {Call: array_contains})

array_contains(arr, search, casesense:=0) {
    for index, value in arr {
        if !IsSet(value)
            continue
        else if (value == search)
            return index
        else if (value = search && !casesense)
            return index
    }
    return 0
}

; Add Sum method to calculate total of array values
Array.Prototype.DefineProp("Sum", {Call: array_sum})

array_sum(arr) {
    total := 0
    for value in arr {
        if IsNumber(value)
            total += value
    }
    return total
}

; Add First and Last methods for easy access to endpoints
Array.Prototype.DefineProp("First", {Call: (arr) => arr.Length ? arr[1] : ""})
Array.Prototype.DefineProp("Last", {Call: (arr) => arr.Length ? arr[arr.Length] : ""})

; Add Join method to concatenate array elements
Array.Prototype.DefineProp("Join", {Call: array_join})

array_join(arr, delimiter:=",") {
    result := ""
    for index, value in arr {
        result .= value (index < arr.Length ? delimiter : "")
    }
    return result
}

; Usage examples
myArray := [1, 2, 3, 4, 5]
MsgBox(myArray.Contains(3))      ; Returns 3 (index position)
MsgBox(myArray.Sum())            ; Returns 15
MsgBox(myArray.First())          ; Returns 1
MsgBox(myArray.Last())           ; Returns 5
MsgBox(myArray.Join(" - "))      ; Returns "1 - 2 - 3 - 4 - 5"
```

### Map Extensions

```cpp
; Add Keys method to get an array of map keys
Map.Prototype.DefineProp("Keys", {Call: map_keys})

map_keys(mp) {
    keyArray := []
    for k, v in mp {
        if !IsSet(k)
            continue
        keyArray.Push(k)
    }
    return keyArray
}

; Add Values method to get an array of map values
Map.Prototype.DefineProp("Values", {Call: map_values})

map_values(mp) {
    valueArray := []
    for k, v in mp {
        if !IsSet(v)
            continue
        valueArray.Push(v)
    }
    return valueArray
}

; Add HasKey method to check if key exists
Map.Prototype.DefineProp("HasKey", {Call: (mp, key) => mp.Has(key)})

; Add GetOrDefault method to safely retrieve values
Map.Prototype.DefineProp("GetOrDefault", {Call: map_get_or_default})

map_get_or_default(mp, key, defaultValue:="") {
    return mp.Has(key) ? mp[key] : defaultValue
}

; Usage examples
myMap := Map("name", "John", "age", 30, "city", "New York")
MsgBox(myMap.Keys().Join(", "))                ; Returns "name, age, city"
MsgBox(myMap.Values().Join(", "))              ; Returns "John, 30, New York"
MsgBox(myMap.HasKey("name"))                   ; Returns 1 (true)
MsgBox(myMap.GetOrDefault("country", "USA"))   ; Returns "USA" (default)
```

### String Extensions

```cpp
; Add Reverse method to reverse a string
String.Prototype.DefineProp("Reverse", {Call: string_reverse})

string_reverse(str) {
    reversed := ""
    Loop Parse, str
        reversed := A_LoopField reversed
    return reversed
}

; Add IsEmpty method to check if string is empty or whitespace
String.Prototype.DefineProp("IsEmpty", {Call: string_is_empty})

string_is_empty(str) {
    return str = "" || RegExMatch(str, "^\s*$")
}

; Add Truncate method to limit string length with ellipsis
String.Prototype.DefineProp("Truncate", {Call: string_truncate})

string_truncate(str, maxLength:=10, ellipsis:="...") {
    if (StrLen(str) <= maxLength)
        return str
    return SubStr(str, 1, maxLength) ellipsis
}

; Add PadLeft and PadRight methods
String.Prototype.DefineProp("PadLeft", {Call: string_pad_left})
String.Prototype.DefineProp("PadRight", {Call: string_pad_right})

string_pad_left(str, totalWidth, padChar:=" ") {
    if (StrLen(str) >= totalWidth)
        return str
    return padChar.Repeat(totalWidth - StrLen(str)) str
}

string_pad_right(str, totalWidth, padChar:=" ") {
    if (StrLen(str) >= totalWidth)
        return str
    return str padChar.Repeat(totalWidth - StrLen(str))
}

; Add Repeat method
String.Prototype.DefineProp("Repeat", {Call: string_repeat})

string_repeat(str, count) {
    result := ""
    Loop count
        result .= str
    return result
}

; Usage examples
myString := "Hello, World!"
MsgBox(myString.Reverse())          ; Returns "!dlroW ,olleH"
MsgBox(myString.Truncate(5))        ; Returns "Hello..."
MsgBox("42".PadLeft(5, "0"))        ; Returns "00042"
MsgBox("Hi".PadRight(5))            ; Returns "Hi   "
MsgBox("-".Repeat(10))              ; Returns "----------"
MsgBox("".IsEmpty())                ; Returns 1 (true)
MsgBox(" ".IsEmpty())               ; Returns 1 (true)
```

### GUI ListView Extensions

```cpp
; Add GetRow method to retrieve all values from a row
Gui.ListView.Prototype.DefineProp("GetRow", {Call: listview_get_row})

listview_get_row(LV) {
    if not LV.Focused
        return 0
    FocusedRow := []
    Loop LV.GetCount("Column") {
        FocusedRow.Push(LV.GetText(LV.GetNext(), A_Index))
    }
    return FocusedRow
}

; Add SetCell method for easier cell manipulation
Gui.ListView.Prototype.DefineProp("SetCell", {Call: listview_set_cell})

listview_set_cell(LV, row, col, value) {
    LV.Modify(row, "Col" col, value)
}

; Usage example
; myGui := Gui()
; LV := myGui.Add("ListView", "r10 w400", ["Name", "Value"])
; LV.Add(, "Item1", "100")
; LV.Add(, "Item2", "200")
; 
; ; Later, to set a value
; LV.SetCell(2, 2, "250")
; 
; ; And to get a row's values
; selectedRow := LV.GetRow()
; if selectedRow
;     MsgBox("Selected: " selectedRow[1] " - " selectedRow[2])
```

### Number Extensions

```cpp
; Add IsBetween method to check if number is in range
Number.Prototype.DefineProp("IsBetween", {Call: number_is_between})

number_is_between(num, min, max, inclusive:=true) {
    return inclusive ? (num >= min && num <= max) : (num > min && num < max)
}

; Add Format method for number formatting
Number.Prototype.DefineProp("Format", {Call: number_format})

number_format(num, decimals:=0, decPoint:=".", thousandsSep:=",") {
    ; Format with specified decimal places
    result := Round(num, decimals)
    
    ; Convert to string
    result := String(result)
    
    ; Handle decimal point
    if (InStr(result, ".")) {
        resultParts := StrSplit(result, ".")
        integer := resultParts[1]
        decimal := resultParts[2]
        
        ; Add thousands separator
        formattedInt := ""
        Loop Parse, integer
        {
            if (A_Index > 1 && Mod(StrLen(integer) - A_Index + 1, 3) = 0)
                formattedInt .= thousandsSep
            formattedInt .= A_LoopField
        }
        
        result := formattedInt decPoint decimal
    } else {
        ; Add thousands separator
        formattedInt := ""
        Loop Parse, result
        {
            if (A_Index > 1 && Mod(StrLen(result) - A_Index + 1, 3) = 0)
                formattedInt .= thousandsSep
            formattedInt .= A_LoopField
        }
        
        result := formattedInt
    }
    
    return result
}

; Usage examples
myNumber := 1234567.89
MsgBox(myNumber.IsBetween(1000000, 2000000))  ; Returns 1 (true)
MsgBox(myNumber.Format(2))                    ; Returns "1,234,567.89"
MsgBox((42).Format())                         ; Returns "42"
```

## Implementation Notes

- When extending built-in types, consider using a dedicated initialization function to ensure all extensions are loaded
- Add descriptive comments to document parameters and expected behavior
- Consider prefixing method names if there's risk of collision with future AHK updates
- Methods should return a sensible value or the object itself to enable method chaining
- Test extensions thoroughly, especially with edge cases (empty values, large values, etc.)
- For methods that might be called frequently, optimize for performance

## Related AHK Concepts

- Prototype-Based OOP
- Descriptors and Property Definitions
- Method Binding and Context
- Array and Map Operations
- String Manipulation
- GUI Control Extensions

## Tags

#AutoHotkey #Prototyping #Extensions #Snippets #Arrays #Maps #Strings #BuiltInObjects #ListView