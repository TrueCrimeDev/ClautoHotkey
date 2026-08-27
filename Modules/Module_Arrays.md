---
name: Module_Arrays
description: 'Arrays in AHK v2 — 1-based indexing, creation and Capacity pre-allocation, in-place mutation,
  search predicates, ArrayMap/Filter/Reduce transformations, DeepClone, QuickSort and multi-field SortBy,
  Map-backed deduplication, and set operations. TRIGGER when the request involves: array, list, collection,
  sort, filter, reduce, Push, Pop, InsertAt, RemoveAt, Length, Capacity, Default,
  "store ordered items", "store multiple values", "iterate collection", "remove duplicates", "deep copy",
  "transform elements", ArrayMap, QuickSort, Unique, IndexOf. Not covered: key-value storage with Map() —
  see Module_DataStructures.md; GUI control binding — see Module_GUI.md.'
---

# Module_Arrays

## API QUICK-REFERENCE

### Array (built-in)
| Method / Property | Signature | Notes |
|-------------------|-----------|-------|
| `[]` literal | `[val1, val2, ...]` | Preferred creation syntax for known values |
| `Array()` | `Array(val*)` | Constructor; `Array()` with no args creates empty array — `Array(N)` creates `[N]`, not N slots |
| `.Push()` | `.Push(val*)` | Appends one or more values; no return value |
| `.Pop()` | `.Pop()` | Removes and returns the last element; throws if empty |
| `.InsertAt()` | `.InsertAt(index, val*)` | Inserts at 1-based position; negative index counts from end |
| `.RemoveAt()` | `.RemoveAt(index, Length?)` | Removes `Length` elements starting at `index`; returns removed value when `Length` omitted |
| `.Get()` | `.Get(index, default?)` | Returns `default` only for an in-range unset slot; an out-of-range index still throws `IndexError`, with or without `default` |
| `.Has()` | `.Has(index)` | Returns `true` if index exists and is not unset |
| `.Delete()` | `.Delete(index)` | Marks element at index as unset without shifting other elements |
| `.Clone()` | `.Clone()` | Shallow copy — nested objects are shared, not duplicated |
| `.Default` | `.Default` | Value returned for an in-range **unset** slot instead of throwing `UnsetItemError`; out-of-range still throws `IndexError` |
| `.Length` | `.Length` | Readable and writable; setting lower truncates, setting higher adds unset slots |
| `.Capacity` | `.Capacity` | Pre-allocate backing storage without adding elements; avoids repeated realloc on `.Push()` |
| `__Enum` | `for index, value in array` | 2-var enumeration yields 1-based index and value; `for value in array` yields value only |

### Global Functions Used with Arrays
| Function | Signature | Notes |
|----------|-----------|-------|
| `Type()` | `Type(obj)` | Returns `"Array"` for Array objects — the canonical type guard |
| `IsObject()` | `IsObject(val)` | Returns `true` for any object including Array, Map, user classes |
| `IsSet()` | `IsSet(var)` | Tests whether a variable or optional parameter was assigned a value |
| `Mod()` | `Mod(dividend, divisor)` | Integer modulus — used in filter predicates and chunking |

### Module Utility Functions (defined in this module)
| Function | Signature | Notes |
|----------|-----------|-------|
| `IsValidIndex()` | `IsValidIndex(arr, index)` | Returns `true` if `index` is in the 1-based valid range |
| `GetRange()` | `GetRange(arr, start, end)` | Returns a new array slice from `start` to `end` (inclusive, 1-based) |
| `SafeInsert()` | `SafeInsert(arr, index, value)` | Clamps `index` to valid range then calls `.InsertAt()` |
| `RemoveValue()` | `RemoveValue(arr, value)` | Removes all occurrences of `value` in-place; returns the mutated array |
| `IndexOf()` | `IndexOf(arr, value, fromIndex?)` | Returns 1-based index or `0` if not found |
| `LastIndexOf()` | `LastIndexOf(arr, value)` | Scans right-to-left; returns 1-based index or `0` |
| `HasValue()` | `HasValue(arr, value)` | Boolean wrapper around `IndexOf()` — `Contains` is a reserved word and cannot be a function name |
| `FindIndex()` | `FindIndex(arr, callback)` | Returns first index where `callback(value, index, array)` is truthy, else `0` |
| `ArrayMap()` | `ArrayMap(arr, callback)` | Returns new array of `callback(value, index, array)` results — immutable style |
| `Filter()` | `Filter(arr, callback)` | Returns new array of elements where `callback(value, index, array)` is truthy |
| `Reduce()` | `Reduce(arr, callback, initialValue?)` | Folds array into single value; throws `ValueError` if array empty and no `initialValue` |
| `DeepClone()` | `DeepClone(obj)` | Recursively copies Array, Map, and Object graphs — does not handle circular references |
| `QuickSort()` | `QuickSort(arr, callback?, left?, right?)` | In-place sort; `callback(a, b)` returns negative/zero/positive |
| `SortBy()` | `SortBy(arr, fields*)` | Multi-field sort on arrays of Map objects |
| `Unique()` | `Unique(arr)` | Returns new array with duplicates removed, preserving first-seen order |
| `UniqueBy()` | `UniqueBy(arr, keyFunc)` | Deduplication using a custom key extractor callback |
| `MakeLookup()` | `MakeLookup(arr, caseSense?)` | Builds the Map lookup **once** and returns a closure for O(1) membership tests — rebuilding per call is slower than `IndexOf()` |
| `ModifyInPlace()` | `ModifyInPlace(arr, modifier)` | Applies `modifier(value)` to every element without allocating a new array |
| `Difference()` | `Difference(array1, array2)` | Elements in `array1` not present in `array2` |
| `Intersection()` | `Intersection(array1, array2)` | Elements present in both arrays; each pair matched once |
| `Union()` | `Union(arrays*)` | Merged unique elements from all input arrays |
| `Without()` | `Without(arr, excludeValues*)` | Array minus the explicitly listed values |

## AHK V2 CONSTRAINTS

- **1-based indexing is mandatory** — `array[1]` is the first element; `array[0]` is always wrong and always throws `IndexError` — every loop counter, range boundary, and index calculation must start from 1.
- **No built-in `.Sort()`** — calling `array.Sort()` throws `MethodError`; use the module's `QuickSort(arr, comparator?)` with an optional `(a, b) => a - b` numeric comparator or `(a, b) => b - a` for reverse.
- **`Array(N)` ≠ pre-allocation** — `Array(10)` creates a one-element array `[10]`; pre-allocate with `arr := [], arr.Capacity := 10` to reserve backing storage without inserting elements.
- **No fat-arrow block bodies on any v2 build** — `(x) => { return x * 2 }` is a load-time syntax error everywhere, including v2.1-alpha.30; any multi-statement callback must be a named nested function (closure), or v2.1's arrowless function expression `(x) { ... }`.
- **Never name a variable, parameter, or function `Array`, `Map`, `Gui`, `Menu`, or `Random`** — identifiers shadow built-in classes case-insensitively; a later `Array(...)` call then throws `This value of type "Array" has no method named "Call"`. The same applies to any script-defined class or function in scope (`union := Union(...)` fails at load time with `This Func cannot be used as an output variable`).
- **A user function named `Map` is not silently wrong in every case** — every `Map(...)` call whose argument count matches your function silently invokes it instead; a call with a different argument count — including the canonical empty `Map()` — fails at load time with `Too few parameters passed to function. Specifically: Map` (exit 12). Either way the built-in class is unreachable in scope.
- **`Contains` is a reserved word on v2.1-alpha.30** — defining `Contains(...)` is a load-time error (exit 12): `The following reserved word must not be used as a function name`. Name the presence helper `HasValue()`.
- **`.Clone()` is shallow** — nested arrays or Map objects share the same reference; mutating a nested element in the clone also mutates the original — use `DeepClone()` for full independence.
- **Do not modify an array while iterating it with `for`** — removing elements during `for index, value in array` corrupts the enumeration; use a `while`-loop with manual index management or iterate over `.Clone()`.

Safe-access priority order for Array elements:
```
1. .Get(index, default)   — one-line resolution for in-range unset slots; out-of-range still throws IndexError
1b. arr.Default := val    — set once when EVERY unset slot should resolve the same way
2. .Has(index)            — when the present/absent branch logic differs meaningfully
3. arr.Length guard       — when IsValidIndex check before direct access is clearest
4. try/catch              — only when the exception itself carries diagnostic information
```

Pair every prohibition with its consequence and positive alternative:

- ✗ `val := array[idx]` — `UnsetItemError` if the in-range slot was `.Delete()`d or never set; `IndexError` if `idx` is out of range  
- ✓ `val := array.Get(idx, "fallback")` — one line, covers the unset-slot case (out-of-range still throws `IndexError`)

- ✗ `arr.Sort()` — `MethodError`: no such method on Array  
- ✓ `QuickSort(arr)` or `QuickSort(arr, (a,b) => a - b)` for numeric order

- ✗ `arr := Array(10)` — creates `[10]`, not 10 empty slots  
- ✓ `arr := [], arr.Capacity := 10` — reserves 10 slots, `.Length` stays 0

## TIER 1 — Fundamentals: Creation, Access, and Type Verification
> METHODS COVERED: `[]` · `Array()` · `.Length` · `.Capacity` · `.Get()` · `Type()` · `IsValidIndex()` · `GetRange()`

Arrays are 1-based dynamic collections that hold variant-typed values. Use `[]` literals for known values and `Array()` for programmatic construction. Pre-allocate backing storage with `.Capacity` when the final size is known; this avoids repeated heap reallocation during sequential `.Push()` calls. Always verify type with `Type(obj) = "Array"` — never rely on duck typing or `IsObject()` alone when the code path must reject Maps and plain Objects.
```ahk
; ✓ [] literal is the canonical v2 creation syntax for known values
numbers := [1, 2, 3, 4, 5]
strings := ["alpha", "beta", "gamma"]
mixed   := ["text", 42, true, [1, 2]]    ; mixed types are supported
empty   := []
dynamic := Array()

; ✓ Capacity pre-allocates backing storage without inserting elements
preAllocated := []
preAllocated.Capacity := 10              ; .Length stays 0 — no elements added

; ✗ Array(N) does NOT pre-allocate N slots — it inserts N as a value
; dynamic := Array(10)                  ; → creates [10], .Length = 1

; ✓ Type() is the authoritative guard — distinguishes Array from Map and Object
isArray  := Type(numbers) = "Array"
length   := numbers.Length
hasItems := numbers.Length > 0

; ✓ 1-based indexing — [1] is always the first element
first  := numbers[1]
last   := numbers[numbers.Length]
middle := numbers[numbers.Length // 2]

; ✓ .Get() returns the fallback for an IN-RANGE unset slot — out-of-range still throws IndexError
sparse := ["a", , "c"]                   ; index 2 exists but is unset
safe   := sparse.Get(2, "default")       ; "default"
; bad  := sparse.Get(10, "default")     ; → IndexError — 10 is out of range, default does not apply

; ✓ .Default covers EVERY unset slot at once — plain [] access stops throwing UnsetItemError
sparse.Default := "N/A"
fallback := sparse[2]                    ; "N/A" — no UnsetItemError
; bad    := sparse[99]                  ; → IndexError — .Default does not apply out of range

; ✗ Direct out-of-range access throws IndexError; an in-range unset slot throws UnsetItemError
; val := numbers[99]                    ; → IndexError — index out of range
; val := sparse[2]                      ; → UnsetItemError — in range, but the slot has no value

IsValidIndex(arr, index) {
    return index >= 1 && index <= arr.Length
}

GetRange(arr, start, end) {
    result := []
    loop end - start + 1 {
        if IsValidIndex(arr, start + A_Index - 1)
            result.Push(arr[start + A_Index - 1])
    }
    return result
}
```

## TIER 2 — Mutation: Add, Remove, and Clear
> METHODS COVERED: `.Push()` · `.Pop()` · `.InsertAt()` · `.RemoveAt()` · `.Length` (setter) · `SafeInsert()` · `RemoveValue()`

All built-in mutation methods operate in-place and shift elements automatically. `.Push()` and `.Pop()` are O(1) amortised at the tail. `.InsertAt()` and `.RemoveAt()` are O(n) because they shift subsequent elements. Setting `.Length := 0` clears in-place (preferred over reassignment when other references to the same array must also see it emptied).
```ahk
; ✓ Push appends one or multiple values in a single call
arr.Push(value)
arr.Push(val1, val2, val3)

; ✓ InsertAt uses 1-based position; negative index counts from end
arr.InsertAt(1, "first")          ; prepend
arr.InsertAt(3, "middle")         ; insert before index 3
arr.InsertAt(-1, "beforeLast")    ; insert before last element

; ✓ Pop removes and returns the last element — use for stack patterns
lastItem := arr.Pop()

; ✓ RemoveAt with count removes a range in one call
arr.RemoveAt(1)                   ; remove first element
arr.RemoveAt(3, 2)                ; remove elements at index 3 and 4
arr.RemoveAt(-1)                  ; remove last element

; ✓ Length := 0 clears in-place — other references to the same array also see empty
arr.Length := 0

; ✓ Reassignment creates a new array object — old reference is abandoned
arr := []

SafeInsert(arr, index, value) {
    if index < 1
        index := 1
    else if index > arr.Length + 1
        index := arr.Length + 1
    arr.InsertAt(index, value)
    return arr
}

RemoveValue(arr, value) {
    ; ✓ while-loop with manual index handles removal during iteration correctly
    index := 1
    while index <= arr.Length {
        if arr[index] = value
            arr.RemoveAt(index)   ; index stays the same after removal — next element shifts down
        else
            index++
    }
    return arr
}

; ✗ Removing elements inside a for-in loop corrupts enumeration
; for index, value in arr {
;     if value = target
;         arr.RemoveAt(index)     ; → skips elements and may throw IndexError
; }
```

## TIER 3 — Search, Predicates, and Type Guards
> METHODS COVERED: `IndexOf()` · `LastIndexOf()` · `HasValue()` · `FindIndex()` · `IsSet()` · `Type()`

AHK v2 Array objects have no built-in search method. These module functions implement the standard search contract: return a 1-based index on success, `0` on failure — never `-1`, which is the JavaScript convention. `FindIndex()` accepts a predicate callback, enabling arbitrary search criteria without writing a custom loop at the call site.
```ahk
; ✓ IndexOf returns 1-based index or 0 — never -1 (not the AHK v2 convention)
IndexOf(arr, value, fromIndex := 1) {
    loop arr.Length - fromIndex + 1 {
        currentIndex := fromIndex + A_Index - 1
        if arr[currentIndex] = value
            return currentIndex
    }
    return 0
}

LastIndexOf(arr, value) {
    loop arr.Length {
        currentIndex := arr.Length - A_Index + 1
        if arr[currentIndex] = value
            return currentIndex
    }
    return 0
}

; ✓ HasValue is a boolean wrapper — use when only presence matters, not position
; ✗ Do NOT name it Contains — Contains is a reserved word (load-time error, exit 12)
HasValue(arr, value) {
    return IndexOf(arr, value) > 0
}

; ✓ FindIndex takes a predicate callback — no need to write a custom loop per criterion
FindIndex(arr, callback) {
    for index, value in arr {
        if callback(value, index, arr)
            return index
    }
    return 0
}

; ✓ Single-line fat-arrow callbacks are valid in v2.0
predicate        := (val, idx, arr) => val > 10
firstLargeIndex  := FindIndex(numbers, predicate)

; ✗ Fat-arrow block bodies are invalid on every v2 build, including v2.1-alpha.30
; predicate := (val, idx, arr) => {    ; → load-time syntax error on all v2 builds
;     return val > 10
; }
; v2.1's multi-statement function expression is ARROWLESS: (val, idx, arr) { ... }
```

## TIER 4 — Transformations: Clone, DeepClone, Map, Filter, Reduce
> METHODS COVERED: `.Clone()` · `DeepClone()` · `ArrayMap()` · `Filter()` · `Reduce()` · `IsObject()` · `IsSet()` · `Type()`

`.Clone()` produces a shallow copy — sufficient when nested objects are read-only. `DeepClone()` recursively copies Array, Map, and plain Object graphs; it does not handle circular references. `ArrayMap()`, `Filter()`, and `Reduce()` follow an immutable style, each returning a new array rather than mutating the input. Name the map function `ArrayMap` — never `Map` — to avoid shadowing the built-in `Map` class.
```ahk
; ✓ .Clone() is the built-in shallow copy — prefer it over manual loop copies
shallowCopy := arr.Clone()

; ✓ DeepClone recurses through Array, Map, and Object — not circular-reference safe
DeepClone(obj) {
    if !IsObject(obj)
        return obj

    switch Type(obj) {
        case "Array":
            result := []
            for value in obj
                result.Push(DeepClone(value))
            return result
        case "Map":
            result := Map()
            for key, value in obj
                result[key] := DeepClone(value)
            return result
        default:
            result := {}
            for key, value in obj.OwnProps()
                result.%key% := DeepClone(value)
            return result
    }
}

; ✓ ArrayMap returns a new array — the original is never mutated
ArrayMap(arr, callback) {
    result := []
    for index, value in arr
        result.Push(callback(value, index, arr))
    return result
}

; ✓ Filter returns elements for which the predicate returns truthy
Filter(arr, callback) {
    result := []
    for index, value in arr {
        if callback(value, index, arr)
            result.Push(value)
    }
    return result
}

; ✓ Reduce with IsSet(initialValue) handles both seeded and unseeded forms
Reduce(arr, callback, initialValue := unset) {
    startIndex := 1
    if !IsSet(initialValue) {
        if arr.Length = 0
            throw ValueError("Reduce of empty array with no initial value", -1)
        accumulator := arr[1]
        startIndex  := 2
    } else {
        accumulator := initialValue
    }

    loop arr.Length - startIndex + 1 {
        index       := startIndex + A_Index - 1
        accumulator := callback(accumulator, arr[index], index, arr)
    }
    return accumulator
}

; ✓ The variadic tail `*` is REQUIRED — ArrayMap/Filter pass (value, index, arr) and
;   Reduce passes (acc, value, index, arr); a callback declaring fewer parameters and
;   no `*` throws "Too many parameters passed to function".
numbers := [1, 2, 3, 4, 5]
doubled := ArrayMap(numbers, (x, *) => x * 2)
evens   := Filter(numbers, (x, *) => Mod(x, 2) = 0)
sum     := Reduce(numbers, (acc, x, *) => acc + x)

; ✗ Never name a function "Map" — it shadows the built-in Map class in scope
; Map(arr, fn) { ... }               ; → matching-arity Map(...) calls invoke this silently;
;                                   ;   empty Map() then fails at load time (exit 12)
```

## TIER 5 — Sorting, Deduplication, and Performance Patterns
> METHODS COVERED: `QuickSort()` · `SortBy()` · `Unique()` · `UniqueBy()` · `Map.Has()` · `Map.Delete()` · `MakeLookup()` · `ModifyInPlace()`

Array objects have no built-in sort. `QuickSort()` sorts in-place using the Lomuto partition scheme; the optional comparator `(a, b)` must return negative for a-before-b, zero for equal, positive for b-before-a. `Unique()` and `UniqueBy()` use a Map as a seen-set, giving O(n) deduplication rather than O(n²) nested loops.
```ahk
QuickSort(arr, callback := "", left := 1, right := unset) {
    if !IsSet(right)
        right := arr.Length
    if left >= right
        return arr
    pivot := arr[right]
    i     := left - 1
    loop right - left {
        j   := left + A_Index - 1
        cmp := callback ? callback(arr[j], pivot) : ((IsNumber(arr[j]) && IsNumber(pivot)) ? (arr[j] <= pivot ? -1 : 1) : StrCompare(arr[j], pivot))
        if cmp <= 0 {
            i++
            temp     := arr[i]
            arr[i] := arr[j]
            arr[j] := temp
        }
    }
    i++
    temp         := arr[i]
    arr[i]     := arr[right]
    arr[right] := temp
    QuickSort(arr, callback, left, i - 1)
    QuickSort(arr, callback, i + 1, right)
    return arr
}

numbers := [3, 1, 4, 1, 5]
QuickSort(numbers)                              ; default: numeric compare for numbers, StrCompare fallback for strings
QuickSort(numbers, (a, b) => a - b)             ; ascending numeric
QuickSort(numbers, (a, b) => b - a)             ; descending numeric
QuickSort(numbers, (a, b) => (b - a) != 0 ? b - a : 0)

; Records are Maps built empty with individual key assignment — never constructor pairs
MakeStudent(name, grade) {
    s := Map()
    s["name"]  := name
    s["grade"] := grade
    return s
}
students := [MakeStudent("Alice", 85), MakeStudent("Bob", 92), MakeStudent("Charlie", 85)]   ; tied grade exercises the second sort field
QuickSort(students, (a, b) => a["grade"] - b["grade"])

; ✓ SortBy uses a named nested closure — valid multi-statement callback in v2.0
SortBy(arr, fields*) {
    Comparator(a, b) {
        for field in fields {
            aVal := a[field]
            bVal := b[field]
            if aVal != bVal
                return (IsNumber(aVal) && IsNumber(bVal)) ? (aVal < bVal ? -1 : 1) : StrCompare(aVal, bVal)
        }
        return 0
    }
    return QuickSort(arr, Comparator)
}

SortBy(students, "grade", "name")

; ✓ Unique uses Map as O(n) seen-set — never use nested loops for deduplication
Unique(arr) {
    result := []
    seen   := Map()
    for item in arr {
        if !seen.Has(item) {
            seen[item] := true
            result.Push(item)
        }
    }
    return result
}

UniqueBy(arr, keyFunc) {
    result := []
    seen   := Map()
    for item in arr {
        key := keyFunc(item)
        if !seen.Has(key) {
            seen[key] := true
            result.Push(item)
        }
    }
    return result
}

MakePerson(id, name) {
    p := Map()
    p["id"]   := id
    p["name"] := name
    return p
}
people := [MakePerson(1, "Alice"), MakePerson(2, "Bob"), MakePerson(1, "Alice")]
uniquePeople := UniqueBy(people, (p) => p["id"])

; ✓ MakeLookup builds the Map ONCE and returns a closure — rebuilding it per call
;   would be strictly slower than the linear IndexOf() it replaces.
MakeLookup(arr, caseSense := "On") {
    seen := Map()
    seen.CaseSense := caseSense      ; must be set before the first key
    for item in arr
        seen[item] := true
    return (v) => seen.Has(v)
}
hasColor := MakeLookup(["red", "green", "blue"])
found    := hasColor("green")        ; true — O(1), no rebuild

; ✓ ModifyInPlace avoids allocating a new array when mutation is intentional
ModifyInPlace(arr, modifier) {
    for index, value in arr
        arr[index] := modifier(value)
    return arr
}
```

### Performance Notes

**O(1) vs O(n) access:**  `.Push()` and `.Pop()` at the tail are O(1) amortised. `.InsertAt(1, …)` and `.RemoveAt(1)` at the head are O(n) — avoid them in tight loops on large arrays. Membership testing with a bare loop (`HasValue()`) is O(n) per call; if the same array is queried repeatedly, build a `Map` lookup once (`MakeLookup()`) and reuse the returned closure for O(1) per subsequent test — rebuilding the Map inside every call is strictly *slower* than `IndexOf()`. Map-backed membership is case-sensitive unless `CaseSense := "Off"` is set before the first key, and never equates Integer `1` with String `"1"` — unlike the loose `=` used by `IndexOf()`.

**In-place vs copy:** `ArrayMap()`, `Filter()`, and `Reduce()` always allocate a new array — appropriate for pipelines where the original must be preserved. When the original is no longer needed, `ModifyInPlace()` eliminates the allocation. For sorting, `QuickSort()` always sorts in-place; call `array.Clone()` first if the original order must be preserved.

**Pre-allocation:** Set `arr.Capacity := expectedSize` before a loop that calls `.Push()` repeatedly. This avoids the exponential reallocation series that occurs when `.Capacity` is allowed to grow automatically. The `.Length` remains 0 until elements are actually pushed.

**DeepClone cost:** `DeepClone()` is O(n) in total graph nodes and allocates one new container per node. Avoid calling it in hot loops or on large nested structures — share read-only sub-arrays as references using `.Clone()` when the nested data will not be mutated.

**Map-backed deduplication:** `Unique()` and set operations (`Difference`, `Intersection`, `Union`) all build a Map as their seen-set, giving O(n + m) total complexity rather than O(n × m) for naive nested-loop implementations. This is the preferred pattern for any uniqueness or membership operation on arrays larger than a handful of elements.

## TIER 6 — Set Operations: Difference, Intersection, Union, Without
> METHODS COVERED: `Difference()` · `Intersection()` · `Union()` · `Without()` · `Map.Has()` · `Map.Delete()`

Set operations are implemented with Map-backed seen-sets rather than nested loops, keeping time complexity O(n + m). `Intersection()` calls `.Delete()` on the seen-set after each match to prevent the same element from being counted twice when duplicates appear in `array2`. `Union()` accepts a variadic argument list so any number of arrays can be merged in one call.
```ahk
; ✓ Difference: elements in array1 that do not appear in array2 — O(n + m)
Difference(array1, array2) {
    result := []
    set2   := Map()
    for item in array2
        set2[item] := true

    for item in array1 {
        if !set2.Has(item)
            result.Push(item)
    }
    return result
}

; ✓ Intersection: .Delete() after match prevents double-counting array2 duplicates
Intersection(array1, array2) {
    result := []
    set2   := Map()
    for item in array2
        set2[item] := true

    for item in array1 {
        if set2.Has(item) {
            result.Push(item)
            set2.Delete(item)       ; consume the match — each pair matched once
        }
    }
    return result
}

; ✓ Union accepts variadic arrays — all inputs merged into one deduplicated result
Union(arrays*) {
    result := []
    seen   := Map()
    for src in arrays {
        for item in src {
            if !seen.Has(item) {
                seen[item] := true
                result.Push(item)
            }
        }
    }
    return result
}

; ✓ Without excludes a variadic list of values in a single pass
Without(arr, excludeValues*) {
    excludeSet := Map()
    for value in excludeValues
        excludeSet[value] := true

    result := []
    for item in arr {
        if !excludeSet.Has(item)
            result.Push(item)
    }
    return result
}

arr1     := [1, 2, 3, 4]
arr2     := [3, 4, 5, 6]
diff     := Difference(arr1, arr2)       ; [1, 2]
inter    := Intersection(arr1, arr2)     ; [3, 4]
merged   := Union(arr1, arr2)            ; [1, 2, 3, 4, 5, 6]
filtered := Without(arr1, 2, 4)         ; [1, 3]

; ✗ Nested-loop membership test is O(n × m) — use Map seen-set for large arrays
; Difference_Slow(a1, a2) {
;     result := []
;     for item in a1 {
;         found := false
;         for x in a2 {
;             if x = item {
;                 found := true
;                 break
;             }
;         }
;         if !found
;             result.Push(item)   ; → O(n × m) — degrades severely with large inputs
;     }
;     return result
; }
```

## ANTI-PATTERNS

| Pattern | Wrong | Correct | LLM Common Cause |
|---------|-------|---------|------------------|
| Zero-based indexing | `array[0]` | `array[1]` / `array[array.Length]` | Dominant habit from JavaScript, Python, C training data |
| Built-in sort assumed | `arr.Sort()` | `QuickSort(arr, (a,b) => a - b)` | Missing v2 API knowledge — LLM infers `.Sort()` by analogy with String |
| Array(N) pre-allocation | `Array(10)` | `arr := [], arr.Capacity := 10` | Missing v2 constructor semantics — `Array(N)` parallels `Array(val)` not `new Array(n)` |
| Fat-arrow block body | `(x) => { return x * 2 }` | Named nested function, or arrowless `(x) { ... }` (v2.1) | JS/C# arrow habit; `=> { }` is a syntax error on every v2 build — v2.1's multi-statement form is arrowless |
| Shadowing Map class | `Map(arr, fn) { ... }` | `ArrayMap(arr, fn) { ... }` | JavaScript `Array.prototype.map` naming convention transferred to AHK |
| Mutating during for-in | `for i, v in arr { arr.RemoveAt(i) }` | `while`-loop with manual index | Cross-language habit; Python/JS raise RuntimeError — AHK silently corrupts |
| Nested-loop membership | `for x in a1 { for y in a2 { if x=y ... } }` | `Map`-backed seen-set (`Unique`, `Difference`) | O(n²) pattern learned from algorithm examples without performance annotations |

## SEE ALSO

> This module does NOT cover: key-value storage and the Map() API — see Module_DataStructures.md
> This module does NOT cover: try/catch patterns for out-of-bounds access and type errors — see Module_Errors.md
> This module does NOT cover: GUI control binding (ListView, ComboBox population from arrays) — see Module_GUI.md
> This module does NOT cover: file-path batch operations and directory listing into arrays — use built-in AHK v2 knowledge (no dedicated file-system module yet).

- `Module_DataStructures.md` — Map() as the canonical key-value store, Map vs Array selection, Map CaseSense/Default/Count.
- `Module_Objects.md` — the Any → Object → Array/Map hierarchy, property descriptors, DefineProp, BoundFunc.
- `Module_Errors.md` — try/catch patterns for `IndexError`, `UnsetItemError`, and `TypeError` thrown by Array methods.
- Closures, variadic functions, and `.Bind()` callback patterns used with ArrayMap/Filter/Reduce — see Module_DynamicProperties.md and Module_Objects.md (no dedicated functions module yet).
- `Module_GUI.md` — populating ListViews, ComboBoxes, and DropDownLists from Array data sources.