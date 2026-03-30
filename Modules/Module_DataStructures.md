# Module_DataStructures.md
<!-- DOMAIN: Data Structures -->
<!-- SCOPE: Deep copy via DeepClone, functional Map/Filter/Reduce helpers, Sort algorithms, and set operations (Union/Intersection/Difference) are not covered here — see Module_Arrays.md. -->
<!-- TRIGGERS: Array, Map, Push, Pop, InsertAt, RemoveAt, Delete, Has, Get, Set, Clear, Clone, Count, Length, Capacity, CaseSense, Default, __Enum, "key-value", "dictionary", "list", "collection", "store ordered items", "store named settings", "iterate all elements", "check key existence", "case-insensitive lookup", "nested data", "data storage" -->
<!-- CONSTRAINTS: Never use {key: val} object literals for data — {} creates an Object lacking Map's method set (.Has, .Get, .Count, .CaseSense, .Delete, .Clear, for-loop enumeration); use Map() exclusively. Array indices are 1-based (arr[0] always throws IndexError); negative indices are valid (arr[-1] = last element). Set Map.CaseSense before inserting any keys — changing it on a non-empty Map throws. Clone() is always shallow. -->
<!-- CROSS-REF: Module_Arrays.md, Module_Objects.md, Module_Classes.md, Module_Errors.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `{key: val}` as data container | `Map("key", val)` | Object lacks `.Has()`, `.Get()`, `.Count`, `.CaseSense`, `.Delete()`, `.Clear()`, and direct for-loop enumeration — silent data loss and runtime errors |
| `arr[0]` zero-based first element | `arr[1]` or `arr[-1]` for last | `IndexError` always thrown — AHK v2 arrays are strictly 1-based with no zero slot |
| `new Map()` / `new Array()` constructor | `Map()` / `Array()` / `[]` | `new` keyword is not used for built-in types in v2 — `TypeError` at runtime |
| `val := m["key"]` without existence guard | `val := m.Get("key", default)` | `UnsetItemError` when key absent — v1 returned blank string; v2 throws |
| `m.CaseSense := "Off"` after inserting keys | Set `CaseSense` on a freshly constructed empty Map before any key insertion | Exception thrown — the internal sorted array is built at insertion time; post-hoc reconfiguration is invalid |
| Calling `m.Keys()` directly as built-in | `for k in m` or `Map.Prototype.DefineProp("Keys", ...)` | `Map` has no built-in `.Keys()` method — `MethodError` at runtime |
| Assuming Map enumerates in insertion order | Enumerate via an auxiliary Array of keys to preserve order | Map enumeration follows sorted alphanumeric key order, not insertion order |

## API QUICK-REFERENCE

### Array
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `.Push()` | `.Push(val1, val2, ...)` | Append one or more values; no return value |
| `.Pop()` | `.Pop()` | Remove and return last element; throws if empty |
| `.InsertAt()` | `.InsertAt(index, val1, ...)` | Insert at position, shifting existing elements right |
| `.RemoveAt()` | `.RemoveAt(index, length?)` | Remove one or more elements shifting left; returns removed value when length omitted |
| `.Delete()` | `.Delete(index)` | Clear element value without changing Length — element becomes unset, not removed |
| `.Has()` | `.Has(index)` | True only if index is within bounds AND the element has a value (not unset) |
| `.Get()` | `.Get(index, default)` | Return default if element is unset (index must be in range); throws IndexError for zero or out-of-range index |
| `.Clone()` | `.Clone()` | Shallow copy — nested Array/Map objects share the same reference |
| `.Capacity` | `.Capacity` | Read or pre-set the number of allocated slots to avoid repeated reallocation |
| `.Length` | `.Length` | Current element count (read-write — truncates or extends the array) |

### Map
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `.Set()` | `.Set(key1, val1, ...)` | Batch-assign multiple key-value pairs; more efficient than repeated `m[k] := v` |
| `.Get()` | `.Get(key, default)` | Return default if key absent; never throws — primary safe-access pattern |
| `.Has()` | `.Has(key)` | True if key exists in the Map — use for branching logic that differs on presence vs absence |
| `.Delete()` | `.Delete(key)` | Remove key; returns its former value |
| `.Clear()` | `.Clear()` | Remove all key-value pairs; Count becomes 0 |
| `.Clone()` | `.Clone()` | Shallow copy — nested objects share the same reference |
| `.Count` | `.Count` | Number of key-value pairs currently stored (read-only) |
| `.Capacity` | `.Capacity` | Read or pre-set allocated bucket count for bulk-insert performance |
| `.CaseSense` | `"On" / "Off" / "Locale"` | Must be set before inserting any keys; "Locale" is 1–8× slower, handles Ä/ü/etc. |
| `.Default` | `.Default` | Global fallback value returned for any absent key — eliminates UnsetItemError map-wide |

### Prototype Extension (Map)
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `Map.Prototype.DefineProp()` | `.DefineProp(name, {Call: fn})` | Add utility methods (e.g., `.Keys()`) — property descriptor object literal `{}` is correct here |

## AHK V2 CONSTRAINTS

- ✗ `{key: val}` — creates an Object instance, not a Map; Object lacks `.Has()`, `.Get()`, `.Count`, `.CaseSense`, `.Delete()`, `.Clear()`, and direct for-loop enumeration
- ✓ `Map("key", val)` — the only correct key-value container with the full method set

- ✗ `arr[0]` — `IndexError` always; zero is not a valid Array index in AHK v2
- ✓ `arr[1]` for first element, `arr[-1]` for last — negative indices are valid and idiomatic

- ✗ `m.CaseSense := "Off"` after key insertion — throws an exception; internal sorted array already built
- ✓ Set `CaseSense` on an empty Map before the first key is inserted

- ✗ `m["key"]` without a guard — `UnsetItemError` if key absent
- ✓ `m.Get("key", default)` — safe, never throws

- ✗ `arr.Clone()` then mutating nested Maps inside the copy — nested objects are shared references; mutations propagate to the original
- ✓ Use `DeepClone` from Module_Arrays.md for true independent nested copies

- Float keys in Map are silently converted to String — never rely on float key identity for equality checks (e.g., `m[1.0]` and `m["1.0"]` refer to the same slot)

- `Array.Delete(index)` clears the element value but does NOT change `.Length` — the slot remains, now unset; use `.RemoveAt(index)` when you need the array to shrink

- Map has no built-in `.Keys()` method — iterate with `for k in map` or add `.Keys()` via `Map.Prototype.DefineProp` as shown in TIER 4

Safe-access priority order for Array and Map:
  1. `.Get(key/index, default)` — one-line resolution; for Map, never throws; for Array, returns default only for in-range unset elements — still throws IndexError for out-of-range access; preferred default for unset-element access
  2. `.Has(key/index)` — when if/else branch logic genuinely differs for present vs absent
  3. `.Default` — when the entire Map or Array needs a universal fallback for all absent accesses
  4. `try/catch IndexError / UnsetItemError` — only when the exception message itself carries diagnostic information not available otherwise

## TIER 1 — Data Storage Fundamentals: Map vs Object Literal; Choosing Array vs Map
> METHODS COVERED: Map() · Array · [] literal

AHK v2 provides two primary data-container types: `Array` (ordered, 1-based integer-indexed) and `Map` (unordered, any-typed key-value). Both extend `Object`. Object literals `{key: val}` create plain Object instances — not Maps — and must never be used as data containers. The only safe data-container literals are `[]` for Arrays and `Map()` for key-value data.

Choose Array when access is positional (ordered sequence, push/pop stack); choose Map when access is by name or arbitrary key. Compose them freely for nested structures.
```ahk
; ✓ Map() is the only correct key-value container in AHK v2
config := Map("width", 800, "height", 600)

; ✓ Static Map inside a class — centralises config and magic strings
class AppConfig {
    static Settings := Map(
        "theme",   "dark",
        "lang",    "en",
        "version", "2.0"
    )
}

; ✗ Object literal as data storage — Object lacks Map's method set
; config := {width: 800, height: 600}   ; → no .Has(), .Get(), .Count, for-loop fails

; Array vs Map selection reference:
; Need                         | Use   | Example
; Ordered sequence             | Array | steps := ["init", "run", "cleanup"]
; Named/keyed lookup           | Map   | cfg := Map("host", "localhost")
; Integer index, 1-based       | Array | arr[1], arr[-1]
; Any-typed key                | Map   | m["key"], m[42], m[objRef]
; Push / Pop stack behaviour   | Array | arr.Push(x) / arr.Pop()
; Dynamic key enumeration      | Map   | for k, v in myMap
```

## TIER 2 — Array Construction, Mutation, and Safe Access
> METHODS COVERED: Push · Pop · InsertAt · RemoveAt · Delete · Has · Get · Clone · Capacity · Length

Arrays are 1-based ordered sequences. Out-of-bounds access (including index 0) throws `IndexError`. Negative indices (`arr[-1]` = last, `arr[-2]` = second-last) are valid and idiomatic. `Delete()` unsets a value without shrinking the array; `RemoveAt()` shifts elements and shrinks.
```ahk
; ✓ Array literal and constructor — both are valid
fruits := ["apple", "banana", "orange"]
nums   := Array(10, 20, 30)

; ✓ Positive and negative indexing — negative indices avoid computing Length manually
MsgBox(fruits[1])    ; "apple"
MsgBox(fruits[-1])   ; "orange"  (last element)
MsgBox(fruits[-2])   ; "banana"  (second-last)
MsgBox(fruits.Length) ; 3

; ✗ Zero-based access — IndexError always thrown; zero slot does not exist
; MsgBox(fruits[0])   ; → IndexError

; --- Mutation methods ---

arr := ["A", "B", "C"]

; ✓ Push — append one or more values
arr.Push("D", "E")        ; ["A","B","C","D","E"]

; ✓ Pop — remove and return last element
last := arr.Pop()         ; last = "E", arr = ["A","B","C","D"]

; ✓ InsertAt — insert at specific position (shifts right)
arr.InsertAt(2, "X")      ; ["A","X","B","C","D"]

; ✓ RemoveAt — remove one element (shifts left), returns removed value
removed := arr.RemoveAt(2)  ; removed = "X", arr = ["A","B","C","D"]

; ✓ RemoveAt with length — remove a range (no return value when length given)
arr.RemoveAt(2, 2)          ; removes indices 2–3, arr = ["A","D"]

; ✓ Delete — clears element value without changing Length (slot becomes unset)
arr.Delete(1)               ; arr[1] has no value, Length unchanged

; --- Safe access ---

arr2 := ["alpha", , "gamma"]  ; index 2 has no value (unset)

; ✓ Has — true only if index is in range AND element has a value
MsgBox(arr2.Has(1))   ; 1 (true)
MsgBox(arr2.Has(2))   ; 0 (false — unset element)
MsgBox(arr2.Has(99))  ; 0 (false — out of range)

; ✓ Get — returns default when element is unset (index in range); still throws IndexError for out-of-range index
val := arr2.Get(2, "default")   ; "default"
val := arr2.Get(1, "default")   ; "alpha"

; ✓ Default property — global fallback for every unset access on this array
arr2.Default := "N/A"
MsgBox(arr2[2])   ; "N/A"  (no UnsetItemError)

; --- Clone and Capacity ---

; ✓ Clone — shallow copy; mutations to the copy do not affect the original's structure
original := [1, 2, 3]
copy := original.Clone()
copy.Push(4)
MsgBox(original.Length)    ; still 3

; ✓ Capacity — pre-allocate to avoid repeated memory reallocation in bulk loops
bigArr := Array()
bigArr.Capacity := 1000
Loop 1000
    bigArr.Push(A_Index)
```

## TIER 3 — Map Construction, Safe Access, Mutation, and CaseSense
> METHODS COVERED: Map() · Has · Get · Set · Delete · Clear · Clone · Capacity · Count · CaseSense · Default

Maps are unordered key-value stores. Keys can be any Integer, String, or Object reference. Float keys are silently converted to String. Accessing a missing key throws `UnsetItemError` unless `.Default` is set or `.Get()` is used.
```ahk
; ✓ Inline construction — each pair is key then value
colours := Map("red", "ff0000", "green", "00ff00", "blue", "0000ff")

; ✓ Multi-line construction — preferred for Maps with more than three pairs
settings := Map(
    "host",    "localhost",
    "port",    5432,
    "timeout", 30
)

; ✓ Reading and writing
MsgBox(colours["red"])        ; "ff0000"
settings["timeout"] := 60    ; update existing key
settings["user"] := "admin"  ; add new key
MsgBox(settings.Count)        ; 4

; --- Safe access ---

cfg := Map("theme", "dark", "lang", "en")

; ✓ Has — check existence before access to avoid UnsetItemError
if cfg.Has("theme")
    MsgBox(cfg["theme"])  ; "dark"

; ✓ Get — return default when key is absent; never throws
font := cfg.Get("font", "Segoe UI")   ; "Segoe UI" (key absent)
lang := cfg.Get("lang", "en")         ; "en"       (key present)

; ✓ Default property — global fallback for entire Map
cfg.Default := "unknown"
MsgBox(cfg["missing_key"])   ; "unknown" (no exception)

; ✗ Bare bracket access without guard — UnsetItemError if key absent
; val := cfg["nonexistent"]   ; → UnsetItemError

; --- Mutation methods ---

m := Map("a", 1, "b", 2)

; ✓ Set — batch-assign multiple pairs (single Capacity adjustment, more efficient than loop)
m.Set("c", 3, "d", 4)     ; m now has a, b, c, d

; ✓ Delete — remove a key, returns its value
removed := m.Delete("a")   ; removed = 1, "a" gone from Map

; ✓ Clear — remove all pairs
m.Clear()
MsgBox(m.Count)  ; 0

; --- CaseSense — MUST be set before any key insertion ---

; Default: case-sensitive ("On")
m1 := Map("Hello", 1)
MsgBox(m1.Has("hello"))   ; 0 (false)

; ✓ Case-insensitive — configure on an empty Map before the first key
m2 := Map()
m2.CaseSense := "Off"    ; set BEFORE adding keys
m2["Hello"] := 1
MsgBox(m2.Has("hello"))  ; 1 (true)

; ✓ Locale-aware — correct for Ä/ü/ñ etc., but 1–8× slower than "Off"
m3 := Map()
m3.CaseSense := "Locale"

; ✗ CaseSense after key insertion — exception thrown
; m4 := Map("key", 1)
; m4.CaseSense := "Off"   ; → exception: cannot change on non-empty Map

; --- Clone and Capacity ---

; ✓ Clone — shallow copy; key-value pairs are independent, but nested objects are shared
original := Map("x", 10, "y", 20)
copy := original.Clone()
copy["z"] := 30
MsgBox(original.Count)   ; still 2

; ✓ Capacity — pre-allocate buckets before bulk insert to avoid repeated reallocation
bulk := Map()
bulk.Capacity := 500
Loop 500
    bulk.Set("key" . A_Index, A_Index)
```

## TIER 4 — Iteration Patterns: Array and Map Enumeration
> METHODS COVERED: __Enum (via for-loop) · Map.Prototype.DefineProp

AHK v2 `for` loops call `__Enum` on the container. Array `for` loops can capture value only or index + value; Map `for` loops capture key + value. Map enumeration order follows sorted alphanumeric key order — not insertion order. To preserve insertion order, maintain an auxiliary Array of keys alongside the Map.
```ahk
; --- Array iteration ---

colours := ["red", "green", "blue"]

; ✓ Value-only iteration — when index is not needed
for colour in colours
    MsgBox(colour)

; ✓ Index + value — when position matters
for index, colour in colours
    MsgBox("colours[" . index . "] = " . colour)

; ✓ Classic Loop with A_Index — useful when index arithmetic is needed
Loop colours.Length
    MsgBox(colours[A_Index])

; ✓ Reverse iteration using negative index — no need to compute Length for offset
i := 0
while (i < colours.Length) {
    i++
    MsgBox(colours[-i])   ; last -> first
}

; Note: if an element is unset, the for-loop variable is uninitialized for that iteration

; --- Map iteration ---

scores := Map("Alice", 95, "Bob", 87, "Carol", 92)

; ✓ Key + value — standard Map enumeration
for name, score in scores
    MsgBox(name . ": " . score)

; ✓ Key-only iteration
for name in scores
    MsgBox("Player: " . name)

; ✓ Prototype extension — add a utility .Keys() method that Map does not provide natively
Map.Prototype.DefineProp("Keys", { Call: _MapGetKeys })  ; descriptor {} is correct here

_MapGetKeys(mp) {
    keys := []
    for k in mp
        keys.Push(k)
    return keys
}

allKeys := scores.Keys()   ; ["Alice", "Bob", "Carol"]

; ✗ Calling .Keys() without prototype extension — MethodError
; keys := scores.Keys()    ; → MethodError: Map has no built-in Keys method
```

## TIER 5 — Advanced Patterns: Nested Structures, Static Class Maps, Filtering
> METHODS COVERED: Push · Map() · static · Get

Compose Arrays and Maps freely: use Array as the outer ordered container (rows) and Map as the inner named-field container (fields per row). This mirrors relational table rows and prevents silent positional-index bugs. Static Maps inside classes centralise configuration and error-code lookup tables. AHK v2 has no built-in functional methods (filter/map/reduce) — build them via for-loop accumulation.
```ahk
; --- Array of Maps — nested record structure ---

; ✓ Each row is a Map() — named field access prevents positional index errors
class UserManager {
    static _users := []

    static AddUser(name, role) {
        UserManager._users.Push(Map(
            "name",      name,
            "role",      role,
            "loginTime", A_Now
        ))
    }

    static ShowAll() {
        for index, user in UserManager._users
            MsgBox("User " . index . ": "
                . user["name"] . " (" . user["role"] . ")"
                . " @ " . user["loginTime"])
    }
}

UserManager.AddUser("Alice", "admin")
UserManager.AddUser("Bob",   "viewer")
UserManager.ShowAll()

; --- Static class Maps — centralise config and error messages ---

; ✓ Static Maps as class-level lookup tables; .Get() provides safe access with fallback
class AppSettings {
    static Defaults := Map(
        "width",    1280,
        "height",   720,
        "theme",    "dark",
        "language", "en"
    )

    static ErrorMessages := Map(
        "NOT_FOUND",   "Resource not found.",
        "PERMISSION",  "Access denied.",
        "TIMEOUT",     "Connection timed out."
    )

    static Get(key) {
        return AppSettings.Defaults.Get(key, "")
    }

    static Error(code) {
        return AppSettings.ErrorMessages.Get(code, "Unknown error.")
    }
}

MsgBox(AppSettings.Get("theme"))         ; "dark"
MsgBox(AppSettings.Error("NOT_FOUND"))   ; "Resource not found."

; --- Array filtering and transformation — for-loop accumulation pattern ---

; Note: AHK v2 has no built-in filter/map/reduce — see Module_Arrays.md for full helpers

numbers := [1, 2, 3, 4, 5, 6, 7, 8, 9]

; ✓ Filter — accumulate matching elements into a new Array
evens := []
for n in numbers
    if (Mod(n, 2) = 0)
        evens.Push(n)

; ✓ Transform — project each element into a new value
squared := []
for n in numbers
    squared.Push(n ** 2)  ; [1, 4, 9, 16, 25, ...]

; ✓ Reduce — aggregate all elements into a single value
total := 0
for n in numbers
    total += n   ; 45
```

### Performance Notes

**Capacity pre-allocation.** Set `.Capacity` before bulk `Push` or `Set` loops to avoid repeated internal reallocation. Each reallocation copies the entire backing array; a single pre-set eliminates all intermediate copies.
```ahk
; ✓ Pre-allocate Array Capacity before bulk Push — single allocation
rows := Array()
rows.Capacity := 5000
Loop 5000
    rows.Push(Map("id", A_Index, "value", A_Index * 2))

; ✓ Pre-allocate Map Capacity before bulk Set — single bucket allocation
lookup := Map()
lookup.Capacity := 1000
Loop 1000
    lookup.Set("item" . A_Index, A_Index)
```

**Map for O(1) keyed lookup vs Array O(n) linear scan.** Build a Map index once and look up by key rather than scanning an Array on every access.
```ahk
; ✓ Build a Map index once — O(1) access by id thereafter
index := Map()
for i, user in users
    index[user["id"]] := i
row := users[index[targetId]]   ; O(1)

; ✗ Linear scan every access — O(n) cost multiplied by access count
; for i, user in users
;     if (user["id"] = targetId)   ; → O(n) repeated scan
;         result := user
```

**In-place mutation vs unnecessary Clone.** `RemoveAt` shifts in place without copying; cloning an Array solely to iterate read-only is always wasteful.
```ahk
; ✓ In-place RemoveAt — no copy, shifts in place
arr.RemoveAt(badIndex)

; ✗ Unnecessary Clone for read-only iteration — doubles memory, no benefit
; copy := arr.Clone()
; for v in copy   ; → clone wasted; iterate original directly
;     MsgBox(v)

; ✓ Iterate original directly when no mutation occurs during the loop
for v in arr
    MsgBox(v)
```

**Avoid repeated `.Length` calls in tight loops.** Cache the value once before the loop to avoid a property lookup on every iteration.
```ahk
; ✓ Cache Length before tight loop
len := arr.Length
Loop len
    Process(arr[A_Index])
```

**Method preference.** Always prefer built-in methods (`.Push`, `.Set`, `.Get`, `.Has`) over custom reimplementations — built-ins are implemented in C++ and incur no AHK parse overhead.

## TIER 6 — Error Handling: IndexError, UnsetItemError, Defensive Guards
> METHODS COVERED: Get · Has · Default · try/catch IndexError · UnsetItemError

AHK v2 throws `IndexError` for out-of-bounds Array access (including index 0) and `UnsetItemError` for accessing an absent Map key or an unset Array element. Prefer `.Get(index/key, default)` over `try/catch` for simple fallback scenarios — it is faster and more readable. Use `try/catch` only when the exception message carries diagnostic information not otherwise available.
```ahk
; --- Array error handling ---

arr := ["a", "b", "c"]

; ✓ Helper function for multi-condition safe access (bounds + unset check)
SafeGet(arr, index, default := "") {
    if (index >= 1 && index <= arr.Length && arr.Has(index))
        return arr[index]
    return default
}

MsgBox(SafeGet(arr, 2))     ; "b"
MsgBox(SafeGet(arr, 99))    ; ""  (no IndexError)

; ✓ Built-in Get() returns default for in-range unset elements; still throws IndexError for out-of-range
arr2 := ["a", , "c"]            ; element 2 is unset
val := arr2.Get(2, "fallback")   ; "fallback" (unset in-range element)

; ✓ try/catch for diagnostic recovery when error detail matters
try {
    MsgBox(arr[0])   ; IndexError — zero is never valid
} catch IndexError as e {
    MsgBox("Index error: " . e.Message)
}

; ✗ Unguarded access — IndexError thrown immediately
; MsgBox(arr[0])    ; → IndexError

; --- Map error handling ---

cfg := Map("host", "localhost", "port", 5432)

; ✓ Has() guard — use when branch logic differs for present vs absent
if cfg.Has("user")
    MsgBox(cfg["user"])
else
    MsgBox("Key 'user' not configured.")

; ✓ Get() — primary pattern for optional keys with a default
timeout := cfg.Get("timeout", 30)   ; 30 if "timeout" not present

; ✓ Map.Default — global fallback; eliminates UnsetItemError for the entire Map
cfg.Default := ""
MsgBox(cfg["missing"])   ; "" instead of UnsetItemError

; ✓ try/catch UnsetItemError — when the exception message itself is needed for diagnosis
try {
    val := cfg["nonexistent"]
} catch UnsetItemError as e {
    MsgBox("Missing key: " . e.Message)
}

; ✗ Bare bracket access on unknown key — UnsetItemError if key absent and no Default set
; val := cfg["nonexistent"]   ; → UnsetItemError
```

## ANTI-PATTERNS

| Pattern | Wrong | Correct | LLM Common Cause |
|---------|-------|---------|------------------|
| Object literal as data container | `config := {width: 800, height: 600}` | `config := Map("width", 800, "height", 600)` | AHK v1 training data — v1 object literals behaved more like Maps |
| Zero-based Array access | `arr[0]` | `arr[1]` for first element, `arr[-1]` for last | Dominant 0-based indexing habit from most language training data (C, Python, JS) |
| Unguarded Map key access | `val := m["key"]` | `val := m.Get("key", default)` or `if m.Has("key")` | v1 returned blank string on missing key; v2 throws UnsetItemError — regression to v1 behaviour |
| CaseSense set after key insertion | `m["key"] := 1` then `m.CaseSense := "Off"` | Set `CaseSense` on an empty Map before the first key | Missing API knowledge — insertion-time constraint is not obvious from method names |
| Assuming Clone() is deep | `deep := nested.Clone()` then mutating inner Maps | Use `DeepClone` from Module_Arrays.md | Cross-language habit — Python/JS `.copy()` / spread also produce shallow copies but the consequence is less visible |
| Calling .Keys() as built-in | `m.Keys()` | `for k in m` or `Map.Prototype.DefineProp("Keys", ...)` | Missing v2 API knowledge — Python and JS both provide `.keys()` natively on their dict/Map types |

## SEE ALSO

> This module does NOT cover: functional Map/Filter/Reduce helpers, DeepClone, Sort algorithms, and set operations (Union/Intersection/Difference/Without) → see Module_Arrays.md
> This module does NOT cover: DefineProp property descriptor rules (get/set/call) and the full Any → Object → Array/Map inheritance hierarchy → see Module_Objects.md
> This module does NOT cover: static Map patterns scoped to class lifecycle, `__Delete` cleanup of Map/Array references → see Module_Classes.md
> This module does NOT cover: IndexError/UnsetItemError diagnosis beyond the guards shown here, structured error recovery patterns → see Module_Errors.md

- `Module_Arrays.md` — extended Array operations: functional Map/Filter/Reduce helpers, Sort with custom callbacks, set operations (Union/Intersection/Difference/Without), and DeepClone for fully independent nested copies.
- `Module_Objects.md` — the `Any → Object → Array / Map` inheritance hierarchy; `DefineProp` property descriptor rules (`get` / `set` / `call`) that apply when extending Array or Map prototypes.
- `Module_Classes.md` — static Map patterns inside classes for config and error-message storage; `__Delete` for cleaning up Map/Array references; instance vs static collection property scoping.
- `Module_Errors.md` — `IndexError` and `UnsetItemError` diagnosis and recovery; object-literal-as-storage error classification; runtime diagnostic checklist for Map/Array-related failures.