---
name: Module_Functions
description: 'Functions in AHK v2 - declaration and calling, parameter forms (default, unset ?, variadic *),
  ByRef & output parameters, local/global/static scope, function references and the Func properties,
  nested functions and closures, memoization, and multi-value returns. TRIGGER when the request involves:
  function, parameter, argument, return value, "optional parameter", default value, variadic, spread,
  "by reference", ByRef, "output parameter", IsSet, "unset parameter", global, static, local, scope,
  "variable shadowing", closure, "nested function", "function reference", "pass a function", callback,
  memoize, "return multiple values", MinParams, IsVariadic. Not covered: class methods, properties and
  inheritance - see Module_Classes.md; DllCall and CallbackCreate function pointers - see
  Module_DllCall.md; try/catch design - see Module_Errors.md; Array and Map APIs for consuming returned
  collections - see Module_Arrays.md and Module_DataStructures.md.'
---

# Module_Functions

Target: AutoHotkey v2.1-alpha.33+Console. The `(params) { ... }` function expression in Tier 5 is v2.1
only; everything else also runs on stock v2.0 (see Module_Versions.md).

## API QUICK-REFERENCE

### Parameter forms
| Form | Notes |
|------|-------|
| `param` | Required. Omitting it is a load-time error for a direct call and `Error` for a dynamic one. |
| `param := expr` | Default. The expression is evaluated at call time, only when the argument is absent. |
| `param?` | Unset. The caller may omit it, and reading it while unset throws UnsetError, so test `IsSet(param)` first or use `param ?? fallback`. |
| `param*` | Variadic. Collects the remaining arguments into an Array (empty when none). Must be last. |
| `&param` | ByRef. The caller passes `&var`; the function writes through `param`. |
| `&param := expr` | Optional ByRef output; the caller may skip it. |
| `fn(arr*)` | Call-site spread: each element of `arr` becomes one argument. |

Conventional parameter order is required, then defaulted, then `?`, then variadic. The parser also accepts
a required parameter after a defaulted one, but callers then have to skip it with an empty argument, for
example `F(, 2)`. Do not write that.

### Scope
| Keyword | Notes |
|---------|-------|
| (none) | Reading a name that is not assigned in the function reads an existing global. Assigning to it creates a local. |
| `global Name` | Needed before the first write to an outer global. Declare at the top of the function. |
| `local Name` | The default, but legal for clarity. |
| `static Name := init` | Persists across calls; the initializer runs once, on the first call. Not for values that must reset per call. |

### Function references and the Func object
| Item | Notes |
|------|-------|
| `fn := Name` | A bare function name (no parentheses) is a Func reference you can store, pass and return. |
| `fn(args*)` / `fn.Call(args*)` | Call it. |
| `%"Name"%(args*)` | Call by name from a string. |
| `fn.Name` | The declared name. |
| `fn.MinParams` | Count of required parameters. |
| `fn.MaxParams` | Formal parameter count, excluding the variadic collector. |
| `fn.IsVariadic` | `1` when the function has a `*` parameter. Use it, not `MaxParams`, to detect an open upper bound. |
| `fn.IsBuiltIn` | `1` for built-in functions such as `MsgBox`. |
| `fn.Bind(args*)` | New BoundFunc with leading arguments fixed. |
| `IsSet(var)` | `1` when the variable holds a value. |

## AHK V2 CONSTRAINTS

- Write the call with the name and `(` touching. `Sq (7)` is not a call: it is the variable `Sq` joined
  to `(7)` by implicit concatenation and fails or misbehaves at runtime.
- `=>` takes exactly one expression and never a `{ }` block. For several statements use a named
  function, or on v2.1 an arrowless function expression `(a) { ... }`.
- Assigning to a name inside a function makes it local. `total := 1` silently creates a local, leaving the
  global untouched. `total += 1` throws UnsetError because the local has no value. Declare `global total`
  at the top of the function.
- ByRef needs `&` on both sides: `Swap(&x, &y)`. Passing a plain value to an `&` parameter throws
  TypeError (it is not silently copied).
- `return` and its value go on one line. A bare `return` exits with an empty string; a value on the next
  line is a separate statement, which is either a load error or code that never runs.
- A function that never returns, or uses a bare `return`, yields an empty string / no value. Do not use the
  result of such a function in arithmetic.
- Guard every `?` parameter with `IsSet()` before reading it.
- `static x := init` runs `init` once. Anything that must start fresh each call is a plain local.
- A function stored as an object property and called as `obj.Fn(x)` receives `obj` as its first argument.
  Copy it to a local first (`fn := obj.Fn`, then `fn(x)`) or use a Map of functions.
- Closures share variables; they do not copy them. A closure made in a loop sees the variable's last
  value. Use `Fn.Bind(value)` to freeze one.
- Variable names are case-insensitive and share a namespace with functions and classes: `f` and `F`,
  or a local named after a function or class, collide.
- Multi-line logic in a callback is a named function or method with `.Bind(this)`, not a fat arrow.

Safe-access priority order for optional input:
  1. `param := default`: a safe default exists, no guard needed.
  2. `param?` with `IsSet(param)` or `param ?? fallback`: absent and present need different handling.
  3. `&out := default`: an optional output parameter.
  4. `try/catch` around the call: only when the exception message itself matters.

Pairing rules:
- ✗ `Sq (7)` (concatenation, not a call)
- ✓ `Sq(7)`
- ✗ `f := (a) => { return a + 1 }`
- ✓ `f(a) { return a + 1 }`, or `f := (a) => a + 1`
- ✗ `Inc() { count += 1 }` for a global `count`
- ✓ `Inc() { global count`, newline, `count += 1 }`
- ✗ `Swap(x, y)` for `Swap(&a, &b)`
- ✓ `Swap(&x, &y)`
- ✗ `return` on one line and the value on the next
- ✓ `return computed` on one line

## TIER 1 - Declaration and Calling
> METHODS COVERED: function definition · `return` · `IsSet` · `StrSplit`

A function is a name touching `(`, a parameter list and a braced body. File-scope functions are hoisted, so
a call may appear above the definition. Without a `return` value the result is empty.

```ahk
FunctionName(required, optional := "default", maybe?, extras*) {
    if !IsSet(maybe)
        maybe := ""
    static callCount := 0
    callCount += 1
    return required
}

Square(n) {
    return n * n
}

Clamp(value, lo, hi) {
    if value < lo
        return lo
    if value > hi
        return hi
    return value
}

FullName(first, last) {
    return first " " last
}

ParsePair(str, &outA, &outB) {
    parts := StrSplit(str, ",")
    outA := parts[1]
    outB := parts[2]
}

result := Square(7)
bounded := Clamp(15, 0, 10)
ParsePair("10,20", &valA, &valB)
doubled := Double(5)

Double(x) {
    return x * 2
}

; ✗ result2 := Square (7)   is concatenation of Square and (7), never a call
```

## TIER 2 - Scope: Local, Global, Static
> METHODS COVERED: `global` · `local` · `static`

Variables assigned in a function are local. An outer global that is only read needs no declaration. A write
needs `global Name` first. Each function has its own static variables, even when two use the same name.

```ahk
gCounter := 0

IncrementGlobal() {
    global gCounter
    gCounter += 1
}

; ✗ gCounter += 1 with no global declaration throws UnsetError: the write made a local
IncrementBroken() {
    gCounter += 1
}

ReadGlobal() {
    return gCounter
}

CountCalls() {
    static n := 0
    n += 1
    return n
}

OtherCounter() {
    static n := 0
    n += 1
    return n
}

Explicit() {
    local result := "defined locally"
    return result
}
```

## TIER 3 - Default, Unset and Variadic Parameters
> METHODS COVERED: `:=` default · `?` unset · `*` variadic · `arr*` spread · `IsSet` · `??` · `Trim`

A default fills in for an omitted argument. A `?` parameter stays genuinely unset when omitted, which lets
a function tell "not passed" from "passed empty". A `*` parameter collects the rest into an Array; at the
call site `arr*` expands an Array back into arguments.

```ahk
Repeat(str, times := 1) {
    result := ""
    loop times
        result .= str
    return result
}

Describe(name, age?) {
    if !IsSet(age)
        return name " (age unknown)"
    return name " age " age
}

Label(name, nickname?) {
    return name " aka " (nickname ?? name)
}

Sum(nums*) {
    total := 0
    for n in nums
        total += n
    return total
}

Prefix(label, values*) {
    out := label ": "
    for v in values
        out .= v " "
    return Trim(out)
}

args := [7, 8, 9]
total := Sum(args*)
text := Prefix("nums", 10, 20, 30)

Combined(req, opt := 0, maybe?, rest*) {
    result := req + opt
    if IsSet(maybe)
        result += maybe
    for v in rest
        result += v
    return result
}

; ✗ return name " " age   when age? may be unset throws UnsetError
```

## TIER 4 - ByRef Parameters and Output Values
> METHODS COVERED: `&` definition · `&` call site · `StrSplit` · `Integer` · `Float`

ByRef lets a function write into the caller's variable. Use it for a status result plus a value
(`TryParse`), for several outputs, or to rebind the caller's variable. The caller must pass `&var`.
An optional output takes a default.

```ahk
Swap(&a, &b) {
    temp := a
    a := b
    b := temp
}

x := 10, y := 20
Swap(&x, &y)

TryParseInt(str, &out) {
    if str ~= "^-?\d+$" {
        out := Integer(str)
        return true
    }
    out := 0
    return false
}

if TryParseInt("42", &parsed)
    MsgBox("Parsed: " parsed)

ParseCoord(str, &outX, &outY) {
    parts := StrSplit(str, ",")
    outX := Float(parts[1])
    outY := Float(parts[2])
}

DoubleAll(&arr) {
    doubled := []
    for v in arr
        doubled.Push(v * 2)
    arr := doubled
}

data := [1, 2, 3]
DoubleAll(&data)

GetBounds(items, &outMin := 0, &outMax := 0) {
    outMin := items[1]
    outMax := items[1]
    for v in items {
        if v < outMin
            outMin := v
        if v > outMax
            outMax := v
    }
}

GetBounds([3, 1, 4, 1, 5, 9], &lowest, &highest)
GetBounds([3, 1, 4])

; ✗ Swap(x, y) throws TypeError: "requires a variable reference, but received an Integer"
```

Objects are reference values, so a function that only mutates a passed Array or Map needs no `&`. Use
`&` on an object only when the function must replace the caller's variable, as `DoubleAll` does.

## TIER 5 - References, Nested Functions and Closures
> METHODS COVERED: function references · `.Bind` · nested functions · arrowless function expression · `IsVariadic`

A bare function name is a value. Pass it, store it, return it. A function defined inside another can read
and write the outer function's locals, and returning it makes a closure over them. Each call to the outer
function creates independent captured variables. Inner functions are invisible outside the outer one.

```ahk
ApplyTo(items, fn) {
    out := []
    for item in items
        out.Push(fn(item))
    return out
}

Triple(n) => n * 3
tripled := ApplyTo([1, 2, 3], Triple)

CallByName(name, args*) {
    return %name%(args*)
}
answer := CallByName("Triple", 14)

DescribeFunc(fn) {
    return fn.Name " min=" fn.MinParams " max=" fn.MaxParams " variadic=" fn.IsVariadic
}

ProcessPositive(data) {
    IsPositive(item) {
        return (item is Number) && (item > 0)
    }
    result := []
    for item in data {
        if IsPositive(item)
            result.Push(item)
    }
    return result
}

MakeAdder(n) {
    Add(x) {
        return x + n
    }
    return Add
}
Add5 := MakeAdder(5)
Add10 := MakeAdder(10)
sum := Add5(3) + Add10(3)

BuildAccumulator() {
    total := 0
    Accumulate(n) {
        total += n
    }
    GetTotal() => total
    api := Map()
    api["add"] := Accumulate
    api["get"] := GetTotal
    return api
}
acc := BuildAccumulator()
acc["add"](10)
acc["add"](25)
current := acc["get"]()

Scale := (factor) {
    return (x) => x * factor
}
double := Scale(2)

BindLoop(values) {
    fns := []
    for v in values
        fns.Push(Report.Bind(v))
    return fns
}
Report(v) => "value " v

; ✗ fns.Push(() => v) inside the loop: every closure reads the same v, which ends unset or at the last item
; ✗ IsPositive(5) outside ProcessPositive is an error: the nested function is not visible there
```

## TIER 6 - Caching, Constant Tables and Multiple Return Values
> METHODS COVERED: `static` · `Map` · Array and Map returns · `StrSplit` · pure and side-effect functions

`static cache := Map()` memoizes a pure function: the Map is built once and each repeat is a lookup. Do not
memoize a function with side effects. A `static` table is built once on first call. To return several
values, return a Map when there are three or more named fields, an Array for two or three positional
values, or use ByRef when the primary result is a status flag.

```ahk
Fibonacci(n) {
    static cache := Map()
    if cache.Has(n)
        return cache[n]
    if n <= 1 {
        cache[n] := n
        return n
    }
    result := Fibonacci(n - 1) + Fibonacci(n - 2)
    cache[n] := result
    return result
}

BuildDayNames() {
    names := Map()
    for i, day in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        names[i] := day
    return names
}

GetDayName(n) {
    static days := BuildDayNames()
    return days.Has(n) ? days[n] : "Unknown"
}

AnalyzeList(arr) {
    stats := Map()
    stats["count"] := arr.Length
    if arr.Length = 0 {
        stats["sum"] := 0
        stats["mean"] := 0
        return stats
    }
    low := arr[1], high := arr[1], total := 0
    for v in arr {
        total += v
        low := Min(low, v)
        high := Max(high, v)
    }
    stats["sum"] := total
    stats["mean"] := total / arr.Length
    stats["min"] := low
    stats["max"] := high
    return stats
}

SplitFullName(fullName) {
    parts := StrSplit(fullName, " ", , 2)
    return [parts[1], parts[2]]
}

FormatLogLine(level, msg) {
    return "[" FormatTime(, "yyyy-MM-dd HH:mm:ss") "] " level ": " msg
}

WriteLog(level, msg, logPath) {
    FileAppend(FormatLogLine(level, msg) "`n", logPath, "UTF-8")
}

Normalize(arr, &changed) {
    changed := false
    total := 0
    for v in arr
        total += v
    if total = 0
        return arr
    changed := true
    result := []
    for v in arr
        result.Push(v / total)
    return result
}
```

`FormatLogLine` is pure and testable on its own; `WriteLog` is the thin wrapper that does the I/O. Return
early for trivial inputs (empty array, zero) before the expensive path. Prefer built-ins such as `StrSplit`,
`RegExMatch` and `Sort` to hand-written character loops.

## ANTI-PATTERNS

| Pattern | Wrong | Correct | Why it happens |
|---------|-------|---------|----------------|
| Space before the paren | `MyFunc (x)` | `MyFunc(x)` | Most languages allow it; AHK reads concatenation |
| Block body after fat arrow | `f := (a) => { return a + 1 }` | `f(a) { return a + 1 }` | JavaScript habit |
| Global written without declaration | `count += 1` in a function | `global count` first | v1 let functions assign globals implicitly |
| Missing `&` at the call site | `Swap(x, y)` | `Swap(&x, &y)` | v1 marked ByRef only in the definition |
| `ByRef` keyword | `F(ByRef x)` | `F(&x)` | v1 syntax |
| Return split across lines | `return` then the value on the next line | `return value` | C and Python allow continuation |
| Unguarded `?` parameter | reading `age` when `age?` may be unset | `IsSet(age)` or `age ?? x` | v1 had no unset parameters |
| `static` for per-call state | `static result := ""` | `result := ""` | Both look like `var := init` |
| Loop closure | `fns.Push(() => v)` | `fns.Push(Fn.Bind(v))` | Closures capture the variable |
| Function property called as a method | `this.Handler(x)` where `Handler` is a plain function | `h := this.Handler`, then `h(x)` | The call passes `this` first |
| Names that differ only in case | a global `c` next to a function `C` | distinct names | AHK names are case-insensitive |

## SEE ALSO

> This module does NOT cover: class methods, property accessors and inheritance - see Module_Classes.md
> This module does NOT cover: DllCall, CallbackCreate and COM function pointers - see Module_DllCall.md and Module_COM.md
> This module does NOT cover: try/catch/finally and custom Error classes - see Module_Errors.md
> This module does NOT cover: iterating and transforming returned Arrays and Maps - see Module_Arrays.md and Module_DataStructures.md

- `Module_DynamicProperties.md` - closures, fat arrows and function-valued properties.
- `Module_Objects.md` - `.Bind()`, BoundFunc and `ObjBindMethod`.
- `Module_Classes.md` - methods that build on the function forms here.
- `Module_Errors.md` - error handling inside function bodies.
- `Module_Versions.md` - which constructs need v2.1.

<!-- Adapted from hsinming/AutoHotkey-V2-vibe-coding-tools (no license file upstream); see THIRD-PARTY.md -->
