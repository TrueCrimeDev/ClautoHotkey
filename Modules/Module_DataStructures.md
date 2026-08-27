---
name: Module_DataStructures
description: 'Key-value storage in AHK v2 — Map construction and safe access, CaseSense and Default,
  mutation and cloning, Map enumeration and prototype extension, nested Array-of-Map structures, static
  class Maps, and UnsetItemError handling. TRIGGER when the request involves: Map, Delete, Has, Get, Set,
  Clear, Clone, Count, Capacity, CaseSense, Default, __Enum, "key-value", "dictionary", "store named
  settings", "iterate all elements", "check key existence", "case-insensitive lookup", "nested data",
  "data storage", "Map of Maps", "Map of Arrays", "nested Map", "chained key access", "instance Map
  field", "registry", "lazy initialization", "cache", "event handler table". Not covered: the Array API, functional Map/Filter/Reduce helpers, DeepClone, Sort
  algorithms, and set operations (Union/Intersection/Difference) — see Module_Arrays.md.'
---

# Module_DataStructures

## API QUICK-REFERENCE

### Array

The Array API (`.Push` / `.Pop` / `.InsertAt` / `.RemoveAt` / `.Delete` / `.Has` / `.Get` / `.Clone` / `.Capacity` / `.Length`), 1-based indexing rules, and the Array safe-access ladder are owned by **Module_Arrays.md** — this module covers Arrays only where they nest inside or alongside Maps.

### Map
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `.Set()` | `.Set(key, val)` | Method form of assignment — `m.Set(k, v)` is equivalent to `m[k] := v`; project style is one assignment per key, no multi-pair batches |
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
- ✓ `m := Map()` then `m["key"] := val` — Map is the only correct key-value container with the full method set; build it empty and assign each key individually
- ✗ `Map("k1", v1, "k2", v2, ...)` — constructor pair form is banned in this project; positional pair lists obscure key-value structure and resist clean diffs

- ✗ `arr[0]` — `IndexError` always; zero is not a valid Array index in AHK v2
- ✓ `arr[1]` for first element, `arr[-1]` for last — negative indices are valid and idiomatic
  (Array indexing rules are owned by Module_Arrays.md; repeated here only because the
  Map-vs-Array choice below depends on them.)

- ✗ `m.CaseSense := "Off"` after key insertion — throws an exception; internal sorted array already built
- ✓ Set `CaseSense` on an empty Map before the first key is inserted

- ✗ `m["key"]` without a guard — `UnsetItemError` if key absent
- ✓ `m.Get("key", default)` — safe, never throws

- ✗ `arr.Clone()` then mutating nested Maps inside the copy — nested objects are shared references; mutations propagate to the original
- ✓ Use `DeepClone` from Module_Arrays.md for true independent nested copies

- Float keys in Map are silently converted to String — never rely on float key identity for equality checks (e.g., `m[1.0]` and `m["1.0"]` refer to the same slot)

- `Array.Delete(index)` clears the element value but does NOT change `.Length` — the slot remains, now unset; use `.RemoveAt(index)` when you need the array to shrink (full Array API: Module_Arrays.md)

- Map has no built-in `.Keys()` method — iterate with `for k in map` or add `.Keys()` via `Map.Prototype.DefineProp` as shown in TIER 4

- ✗ `m["outer"]["inner"]` unguarded — a chained lookup has two independent `UnsetItemError` sites; guard the outer key with `.Has()` first, or chain `.Get("outer", Map()).Get("inner", fallback)`

- A class-body initializer (`handlers := Map()`) and any `this.x := ...` in `__New` both route through `__Set` — in a class that defines `__Set`, initialise the backing store with `this.DefineProp("_data", { value: Map() })` instead

Safe-access priority order for Map keys (the Array ladder lives in Module_Arrays.md):
  1. `.Get(key, default)` — one-line resolution; never throws; preferred default for absent-key access
  2. `.Has(key)` — when if/else branch logic genuinely differs for present vs absent
  3. `.Default` — when the entire Map needs a universal fallback for all absent accesses
  4. `try/catch UnsetItemError` — only when the exception message itself carries diagnostic information not available otherwise

## TIER 1 — Data Storage Fundamentals: Map vs Object Literal; Choosing Array vs Map
> METHODS COVERED: Map() · Array · [] literal

AHK v2 provides two primary data-container types: `Array` (ordered, 1-based integer-indexed) and `Map` (unordered, any-typed key-value). Both extend `Object`. Object literals `{key: val}` create plain Object instances — not Maps — and must never be used as data containers. The only safe data-container forms are `[]` for Arrays and an empty `Map()` with keys assigned individually (`m["k"] := v`); the multi-pair constructor form `Map(k1, v1, k2, v2, ...)` is banned in this project.

Choose Array when access is positional (ordered sequence, push/pop stack); choose Map when access is by name or arbitrary key. Compose them freely for nested structures.
```ahk
; ✓ Map() is the only correct key-value container in AHK v2 — build empty, assign per key
config := Map()
config["width"]  := 800
config["height"] := 600

; ✗ Constructor pair form — banned; positional pairs hide which value belongs to which key
; config := Map("width", 800, "height", 600)

; ✓ Static Map inside a class — declare empty, populate in static __New
class AppConfig {
    static Settings := Map()

    static __New() {
        AppConfig.Settings["theme"]   := "dark"
        AppConfig.Settings["lang"]    := "en"
        AppConfig.Settings["version"] := "2.0"
    }
}

; ✗ Object literal as data storage — Object lacks Map's method set
; config := {width: 800, height: 600}   ; → no .Has(), .Get(), .Count, for-loop fails

; Array vs Map selection reference:
; Need                         | Use   | Example
; Ordered sequence             | Array | steps := ["init", "run", "cleanup"]
; Named/keyed lookup           | Map   | cfg := Map() then cfg["host"] := "localhost"
; Integer index, 1-based       | Array | arr[1], arr[-1]
; Any-typed key                | Map   | m["key"], m[42], m[objRef]
; Push / Pop stack behaviour   | Array | arr.Push(x) / arr.Pop()
; Dynamic key enumeration      | Map   | for k, v in myMap
```

## TIER 2 — Array Handling: Delegated to Module_Arrays
> METHODS COVERED: (none — the Array API is owned by Module_Arrays.md)

Arrays are 1-based ordered sequences and the correct container whenever access is positional. Their construction, mutation, safe access, cloning, capacity pre-allocation, and error ladder are taught in full — and maintained in one place — in `Module_Arrays.md`. Reach for this module instead the moment the data is keyed by name rather than by position, or when an Array holds `Map()` records (TIER 5).
```ahk
; Full Array API and safe-access ladder → Module_Arrays.md
;   .Push · .Pop · .InsertAt · .RemoveAt · .Delete · .Has · .Get · .Clone · .Capacity · .Length,
;   1-based and negative indexing, IndexError rules, and the functional helpers all live there.
```

## TIER 3 — Map Construction, Safe Access, Mutation, and CaseSense
> METHODS COVERED: Map() · Has · Get · Set · Delete · Clear · Clone · Capacity · Count · CaseSense · Default

Maps are unordered key-value stores. Keys can be any Integer, String, or Object reference. Float keys are silently converted to String. Accessing a missing key throws `UnsetItemError` unless `.Default` is set or `.Get()` is used.
```ahk
; ✓ Build empty, assign each key individually — one line per key, greppable, diff-friendly
colours := Map()
colours["red"]   := "ff0000"
colours["green"] := "00ff00"
colours["blue"]  := "0000ff"

; ✗ Constructor pair form — banned in this project; positional pairs obscure structure
; colours := Map("red", "ff0000", "green", "00ff00", "blue", "0000ff")

settings := Map()
settings["host"]    := "localhost"
settings["port"]    := 5432
settings["timeout"] := 30

; ✓ Reading and writing
MsgBox(colours["red"])        ; "ff0000"
settings["timeout"] := 60    ; update existing key
settings["user"] := "admin"  ; add new key
MsgBox(settings.Count)        ; 4

; Safe access

cfg := Map()
cfg["theme"] := "dark"
cfg["lang"]  := "en"

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

; Mutation methods

m := Map()
m["a"] := 1
m["b"] := 2

; ✓ Set — method form of assignment; one pair per call mirrors m[k] := v
m.Set("c", 3)
m["d"] := 4               ; m now has a, b, c, d

; ✓ Delete — remove a key, returns its value
removed := m.Delete("a")   ; removed = 1, "a" gone from Map

; ✓ Clear — remove all pairs
m.Clear()
MsgBox(m.Count)  ; 0

; CaseSense — MUST be set before any key insertion

; Default: case-sensitive ("On")
m1 := Map()
m1["Hello"] := 1
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
; m4 := Map()
; m4["key"] := 1
; m4.CaseSense := "Off"   ; → exception: cannot change on non-empty Map

; Clone and Capacity

; ✓ Clone — shallow copy; key-value pairs are independent, but nested objects are shared
original := Map()
original["x"] := 10
original["y"] := 20
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
; Array iteration

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

; Map iteration

scores := Map()
scores["Alice"] := 95
scores["Bob"]   := 87
scores["Carol"] := 92

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
; Array of Maps — nested record structure

; ✓ Each row is a Map() — named field access prevents positional index errors
class UserManager {
    static _users := []

    static AddUser(name, role) {
        user := Map()
        user["name"]      := name
        user["role"]      := role
        user["loginTime"] := A_Now
        UserManager._users.Push(user)
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

; Static class Maps — centralise config and error messages

; ✓ Static Maps as class-level lookup tables; declared empty, populated in static __New
class AppSettings {
    static Defaults      := Map()
    static ErrorMessages := Map()

    static __New() {
        AppSettings.Defaults["width"]    := 1280
        AppSettings.Defaults["height"]   := 720
        AppSettings.Defaults["theme"]    := "dark"
        AppSettings.Defaults["language"] := "en"

        AppSettings.ErrorMessages["NOT_FOUND"]  := "Resource not found."
        AppSettings.ErrorMessages["PERMISSION"] := "Access denied."
        AppSettings.ErrorMessages["TIMEOUT"]    := "Connection timed out."
    }

    static Get(key) {
        return AppSettings.Defaults.Get(key, "")
    }

    static Error(code) {
        return AppSettings.ErrorMessages.Get(code, "Unknown error.")
    }
}

MsgBox(AppSettings.Get("theme"))         ; "dark"
MsgBox(AppSettings.Error("NOT_FOUND"))   ; "Resource not found."

; Array filtering and transformation — for-loop accumulation pattern

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
Loop 5000 {
    row := Map()
    row["id"]    := A_Index
    row["value"] := A_Index * 2
    rows.Push(row)
}

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

## TIER 6 — Map Error Handling: UnsetItemError and Defensive Guards
> METHODS COVERED: Get · Has · Default · try/catch UnsetItemError

AHK v2 throws `UnsetItemError` when an absent Map key is read through bracket access and no `.Default` is set. Prefer `.Get(key, default)` over `try/catch` for simple fallback scenarios — it is faster and more readable. Use `try/catch` only when the exception message carries diagnostic information not otherwise available. (Array `IndexError` handling is covered in `Module_Arrays.md`.)
```ahk
cfg := Map()
cfg["host"] := "localhost"
cfg["port"] := 5432

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

## TIER 7 — Nested Map Composition: Map-of-Map, Map-of-Array, and Instance Map Fields
> METHODS COVERED: Map() · Has · Get · Push · DefineProp

TIER 5 nests Maps inside an Array (ordered rows of named fields). The mirror case is nesting *inside a Map*: a Map value that is itself a `Map()` (a settings branch, a cache entry) or an `Array` (all handlers registered for one event). Chained bracket access reads naturally but throws at two levels, so guard the outer key before descending — or chain `.Get()` with an empty `Map()` as the stand-in branch.

A Map declared in the class body (`handlers := Map()`) is an *instance* field: every object gets its own store, unlike the `static` lookup tables in TIER 5. Reach for an instance Map for per-object registries and caches, and for `static` only when the table is genuinely shared by the whole class. Both a class-body initializer and a `this.x := ...` assignment in `__New` route through `__Set`; in a class that defines `__Set`, create the backing store with `this.DefineProp("_data", { value: Map() })` so the meta-function is bypassed.
```ahk
; Map inside a Map — the inner value is itself a Map, reached by chained brackets

cache := Map()

prefs := Map()
prefs["theme"]    := "dark"
prefs["fontSize"] := 12

cache["user_prefs"]   := prefs
cache["recent_files"] := ["doc1.txt", "doc2.txt"]

; ✓ Guard the outer key first — a chained access has two independent throw sites
if cache.Has("user_prefs")
    MsgBox(cache["user_prefs"]["theme"])   ; "dark"

; ✓ Get() chains safely — an empty Map() stands in for the missing branch
theme := cache.Get("user_prefs", Map()).Get("theme", "light")

; ✗ Chained bare access — two UnsetItemError sites in one expression
; MsgBox(cache["missing"]["theme"])

; Map of Arrays — lazy-initialise the inner Array on first use

class EventEmitter {
    handlers := Map()          ; instance field: one Map per emitter

    On(event, callback) {
        if !this.handlers.Has(event)
            this.handlers[event] := []      ; create the bucket on first subscriber
        this.handlers[event].Push(callback)
    }

    Emit(event, data?) {
        if !this.handlers.Has(event)
            return
        for callback in this.handlers[event]
            callback(data?)
    }
}

; Instance Map field vs static Map — a registry per object, not per class

class WindowRegistry {
    windows := Map()

    __New() {
        this.windows["main"]     := Gui("+Resize", "Main")
        this.windows["settings"] := Gui("+Resize", "Settings")
    }

    Show(name) {
        if !this.windows.Has(name)
            throw ValueError("No window registered under that name", -1, name)
        this.windows[name].Show()
    }
}

; ✓ __Set-safe initialisation — bypasses the meta-function when the class defines one
class SafeStore {
    __New() {
        this.DefineProp("_data", { value: Map() })
    }

    __Set(name, params, value) {
        throw PropertyError("SafeStore is read-only", -1, name)
    }

    Put(key, value) {
        this._data[key] := value
    }
}
```

## ANTI-PATTERNS

| Pattern | Wrong | Correct | LLM Common Cause |
|---------|-------|---------|------------------|
| Object literal as data container | `config := {width: 800, height: 600}` | `config := Map()` then `config["width"] := 800` per key | Legacy habit from older AutoHotkey, where object literals behaved more like Maps |
| Map constructor pairs | `Map("k1", v1, "k2", v2)` | `m := Map()` then `m["k1"] := v1` per key | Pair form appears throughout AHK documentation; this project bans it — positional pairs obscure structure |
| Zero-based Array access | `arr[0]` | `arr[1]` for first element, `arr[-1]` for last | Dominant 0-based indexing habit from most language training data (C, Python, JS) |
| Unguarded Map key access | `val := m["key"]` | `val := m.Get("key", default)` or `if m.Has("key")` | Older AutoHotkey returned a blank string on a missing key; v2 throws UnsetItemError — legacy-habit regression |
| CaseSense set after key insertion | `m["key"] := 1` then `m.CaseSense := "Off"` | Set `CaseSense` on an empty Map before the first key | Missing API knowledge — insertion-time constraint is not obvious from method names |
| Assuming Clone() is deep | `deep := nested.Clone()` then mutating inner Maps | Use `DeepClone` from Module_Arrays.md | Cross-language habit — Python/JS `.copy()` / spread also produce shallow copies but the consequence is less visible |
| Calling .Keys() as built-in | `m.Keys()` | `for k in m` or `Map.Prototype.DefineProp("Keys", ...)` | Missing v2 API knowledge — Python and JS both provide `.keys()` natively on their dict/Map types |
| Unguarded chained Map access | `m["user_prefs"]["theme"]` | `if m.Has("user_prefs")` first, or `m.Get("user_prefs", Map()).Get("theme", fallback)` | Chained subscripting is safe-ish in JS (`undefined` propagates) and only throws once in Python; v2 throws `UnsetItemError` at each level |
| Missing lazy-init of a Map-of-Arrays bucket | `this.handlers[event].Push(cb)` on a new event | `if !this.handlers.Has(event)` then `this.handlers[event] := []`, then `.Push` | Python `defaultdict(list)` and JS `??=` auto-create the bucket; AHK v2 Map has no auto-vivification |
| Class-body Map initializer inside a `__Set` class | `data := Map()` in the class body of a class defining `__Set` | `this.DefineProp("_data", { value: Map() })` in `__New` | Initializers look like direct slot writes, but alpha.30 routes them through `__Set` — a `__Get` companion then recurses |

## SEE ALSO

> This module does NOT cover: the whole Array API and the Array safe-access ladder (including Array `.Default`), functional Map/Filter/Reduce helpers, DeepClone, Sort algorithms, and set operations (Union/Intersection/Difference/Without) → see Module_Arrays.md
> This module does NOT cover: DefineProp property descriptor rules (get/set/call) and the full Any → Object → Array/Map inheritance hierarchy → see Module_Objects.md
> This module does NOT cover: static Map patterns scoped to class lifecycle, `__Delete` cleanup of Map/Array references → see Module_Classes.md
> This module does NOT cover: IndexError/UnsetItemError diagnosis beyond the guards shown here, structured error recovery patterns → see Module_Errors.md

- `Module_Arrays.md` — the complete Array API: creation, indexing, mutation, `.Capacity`, `.Get`/`.Has`/`.Default` and the Array safe-access ladder, plus functional Map/Filter/Reduce helpers, Sort with custom callbacks, set operations (Union/Intersection/Difference/Without), and DeepClone for fully independent nested copies.
- `Module_Objects.md` — the `Any → Object → Array / Map` inheritance hierarchy; `DefineProp` property descriptor rules (`get` / `set` / `call`) that apply when extending Array or Map prototypes.
- `Module_Classes.md` — static Map patterns inside classes for config and error-message storage; `__Delete` for cleaning up Map/Array references; instance vs static collection property scoping.
- `Module_Errors.md` — `IndexError` and `UnsetItemError` diagnosis and recovery; object-literal-as-storage error classification; runtime diagnostic checklist for Map/Array-related failures.