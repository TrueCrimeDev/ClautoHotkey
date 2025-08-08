The array joining code breaks down into 3 parts:

```cpp
; Initialize empty result string
result := ""

; Loop through array items
For item in Example_Array

; Append each item with comma if not last element    
result .= item (A_Index < Example_Array.Length ? ", " : "")
```

Full example script:
```cpp
Example_Array := ["apple", "banana", "orange"]
result := ""
For item in Example_Array
    result .= item (A_Index < Example_Array.Length ? ", " : "")
MsgBox result
```

The key part is the ternary operator: `(condition ? valueIfTrue : valueIfFalse)`
If not last item: adds ", " after element
If last item: adds nothing

Alternative shorter syntax:
```cpp
result := ""
For item in Example_Array
    result .= item ", "
result := RTrim(result, ", ")
```