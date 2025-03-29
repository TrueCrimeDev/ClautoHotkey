# Core Array Operations in Pure AHK v2

## Array Creation and Access

```cpp
array := [1, 2, 3]              ; Direct creation
array := Array("a", "b", "c")    ; Using Array() function
emptyArray := []                 ; Empty array

; Access elements (1-based indexing)
firstElement := array[1]         ; First element
lastElement := array[array.Length]  ; Last element

; Get array length
count := array.Length
```

## Modifying Arrays

```cpp
; Add elements
array.Push("new")               ; Add to end
array.InsertAt(1, "first")      ; Insert at beginning

; Remove elements
lastItem := array.Pop()         ; Remove & return last element
array.RemoveAt(1)               ; Remove first element
array.RemoveAt(1, 2)            ; Remove 2 elements starting at position 1

; Clear array
array := []                     ; Create new empty array
array.Length := 0               ; Clear existing array
```

## Finding Elements

```cpp
; Basic search function
HasValue(haystack, needle) {
    for index, value in haystack
        if (value = needle)
            return index
    return 0
}

; Usage
array := ["a", "b", "c"]
if foundIndex := HasValue(array, "b")
    MsgBox "Found at index: " foundIndex
```

## Copying Arrays

```cpp
; Shallow copy
newArray := array.Clone()

; Deep copy function
DeepClone(obj) {
    if !IsObject(obj)
        return obj
    
    if Type(obj) = "Array" {
        result := []
        for key, value in obj
            result.Push(DeepClone(value))
        return result
    }
    
    result := {}
    for key, value in obj.OwnProps()
        result.%key% := DeepClone(value)
    return result
}
```

# Array Transformations in Pure AHK v2

## Chunking Arrays

```cpp
ChunkArray(array, size) {
    result := []
    index := 1
    while index <= array.Length {
        chunk := []
        loop size {
            if index <= array.Length
                chunk.Push(array[index++])
        }
        result.Push(chunk)
    }
    return result
}

; Usage
array := [1, 2, 3, 4, 5, 6]
chunks := ChunkArray(array, 2)  ; [[1,2], [3,4], [5,6]]
```

## Taking Elements

```cpp
Take(array, count) {
    result := []
    loop Min(count, array.Length)
        result.Push(array[A_Index])
    return result
}

TakeRight(array, count) {
    result := []
    startIndex := Max(1, array.Length - count + 1)
    loop array.Length - startIndex + 1
        result.Push(array[startIndex + A_Index - 1])
    return result
}
```

## Flattening Arrays

```cpp
Flatten(array, depth := 1) {
    result := []
    for item in array {
        if IsObject(item) && Type(item) = "Array" && depth > 0
            result.Push(Flatten(item, depth - 1)*)
        else
            result.Push(item)
    }
    return result
}

; Usage
nested := [[1, 2], [3, [4, 5]]]
flat := Flatten(nested)      ; [1, 2, 3, [4, 5]]
deepFlat := Flatten(nested, 999)  ; [1, 2, 3, 4, 5]
```

## Compact Array (Remove Empty Values)

```cpp
Compact(array) {
    result := []
    for item in array {
        if item  ; Skip empty/false values
            result.Push(item)
    }
    return result
}

; Usage
array := [0, 1, "", false, 2, UnSet, 3]
clean := Compact(array)  ; [1, 2, 3]
```

# Array Search and Sort in Pure AHK v2

## Search Functions

```cpp
IndexOf(array, searchValue, fromIndex := 1) {
    loop array.Length - fromIndex + 1 {
        if array[A_Index + fromIndex - 1] = searchValue
            return A_Index + fromIndex - 1
    }
    return 0
}

LastIndexOf(array, searchValue) {
    loop array.Length
        if array[array.Length - A_Index + 1] = searchValue
            return array.Length - A_Index + 1
    return 0
}

Includes(array, searchValue) {
    return IndexOf(array, searchValue) > 0
}
```

## Unique Values

```cpp
Unique(array) {
    result := []
    for item in array {
        exists := false
        for unique in result {
            if unique = item {
                exists := true
                break
            }
        }
        if !exists
            result.Push(item)
    }
    return result
}
```

## Sort Array

```cpp
; AHK v2 has built-in array sorting
array := [3, 1, 4, 1, 5]
array.Sort()                ; Ascending
array.Sort("N")            ; Numeric sort
array.Sort((a, b) => a - b)  ; Custom sort function
```


# Array Set Operations in Pure AHK v2

## Difference

```cpp
Difference(array1, array2) {
    result := []
    for item in array1 {
        found := false
        for item2 in array2 {
            if item = item2 {
                found := true
                break
            }
        }
        if !found
            result.Push(item)
    }
    return result
}
```

## Intersection

```cpp
Intersection(array1, array2) {
    result := []
    for item in array1 {
        for item2 in array2 {
            if item = item2 {
                result.Push(item)
                break
            }
        }
    }
    return result
}
```

## Union

```cpp
Union(arrays*) {
    result := []
    for array in arrays {
        for item in array {
            exists := false
            for existing in result {
                if existing = item {
                    exists := true
                    break
                }
            }
            if !exists
                result.Push(item)
        }
    }
    return result
}
```

## Without

```cpp
Without(array, values*) {
    result := []
    for item in array {
        exclude := false
        for value in values {
            if item = value {
                exclude := true
                break
            }
        }
        if !exclude
            result.Push(item)
    }
    return result
}
```


# Array Combination Operations in Pure AHK v2

## Zip Arrays

```cpp
Zip(arrays*) {
    result := []
    maxLength := 0
    
    ; Find longest array
    for array in arrays
        maxLength := Max(maxLength, array.Length)
    
    ; Create paired arrays
    loop maxLength {
        currentIndex := A_Index
        pair := []
        for array in arrays
            pair.Push(currentIndex <= array.Length ? array[currentIndex] : "")
        result.Push(pair)
    }
    return result
}

; Usage
names := ["fred", "barney"]
ages := [30, 40]
zipped := Zip(names, ages)  ; [["fred", 30], ["barney", 40]]
```

## Unzip Arrays

```cpp
Unzip(array) {
    if !array.Length
        return []
    
    result := []
    ; Initialize result arrays
    loop array[1].Length
        result.Push([])
    
    ; Fill result arrays
    for pair in array {
        loop pair.Length {
            if IsSet(pair[A_Index])
                result[A_Index].Push(pair[A_Index])
        }
    }
    return result
}

; Usage
pairs := [["fred", 30], ["barney", 40]]
unzipped := Unzip(pairs)  ; [["fred", "barney"], [30, 40]]
```

## Create Object from Arrays

```cpp
ZipObject(keys, values) {
    result := {}
    loop Min(keys.Length, values.Length)
        result.%keys[A_Index]% := values[A_Index]
    return result
}

; Usage
keys := ["name", "age"]
values := ["fred", 30]
obj := ZipObject(keys, values)  ; {name: "fred", age: 30}
```