---
name: Module_DynamicProperties
description: 'Block-body arrow syntax (`=> { }`) is a syntax error on every AHK v2 build — multi-statement
  function expressions use the arrowless v2.1 `(params) { }` form or a named function; async/concurrent
  callback scheduling is not covered here (no dedicated async/timers module yet). TRIGGER when the request
  involves: =>, fat arrow, arrow function, lambda,
  closure, __Get, __Set, __Call, DefineProp, dynamic property, meta-function, functional programming,
  currying, composition, "short function syntax", "inline callback", "computed property", "property that
  calculates", "function remembers variables", "factory function"'
---

# Module_DynamicProperties

## API QUICK-REFERENCE

### Fat Arrow Syntax Forms
| Form | Signature | Notes |
|------|-----------|-------|
| Single-parameter | `param => expr` | Parentheses optional for exactly one parameter |
| Multi-parameter | `(p1, p2, ...) => expr` | Parentheses required for 0 or 2+ parameters |
| No-parameter | `() => expr` | Empty parens required |
| Named recursive | `varName := FuncName(params) => expr` | `FuncName` visible inside `expr` for self-reference; enables recursion |
| Fat arrow property | `propName => expr` inside class body | Defines a getter-only computed property; evaluated on every access |
| Parameterized property | `propName[key] => expr` inside class body | Getter with bracket parameter; `key` is available inside `expr` |

### Meta-Functions (Dynamic Property Interception)
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `__Get` | `__Get(name, params)` | Invoked when an undefined property is read; `params` is an Array of bracket arguments (empty Array for plain access) |
| `__Set` | `__Set(name, params, value)` | Invoked when an undefined property is assigned; `params` Array sits between `name` and `value` |
| `__Call` | `__Call(name, params)` | Invoked when an undefined method is called; `params` is an Array of all arguments passed |

### DefineProp — Programmatic Property Definition
| Function | Signature | Notes |
|----------|-----------|-------|
| `DefineProp()` | `obj.DefineProp(name, {get:fn, set:fn, call:fn})` | Attaches a property descriptor to any object; `get`/`set`/`call` keys are all optional |
| `GetOwnPropDesc()` | `obj.GetOwnPropDesc(name)` | Returns the existing descriptor object for an own property |
| `HasOwnProp()` | `obj.HasOwnProp(name)` | Tests own-property existence without triggering `__Get` |
| `OwnProps()` | `obj.OwnProps()` | Enumerates own properties only; does NOT enumerate properties intercepted by `__Get` |

### Functional Utilities
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `Func.Bind()` | `fn.Bind(args*)` | Partial application — returns a new Func with leading arguments pre-bound |
| `Func.Call()` | `fn.Call(args*)` | Explicit call; semantically equivalent to `fn(args*)` |
| `IsSet()` | `IsSet(var)` | Returns true if variable has been assigned; use for optional parameter detection |
| `IsObject()` | `IsObject(val)` | Returns true for any AHK object, including closures and Func objects |

### Built-in Functions Used in Examples
| Function | Signature | Notes |
|----------|-----------|-------|
| `StrLen()` | `StrLen(str)` | Returns character count of string |
| `FormatTime()` | `FormatTime(timestamp?, format?)` | Formats date/time; omit timestamp for current system time |
| `Mod()` | `Mod(dividend, divisor)` | Returns the remainder; use for even/odd and cyclic index checks |
| `IsInteger()` | `IsInteger(val)` | Returns true if val is an integer-valued number or numeric string |

## AHK V2 CONSTRAINTS

- Fat arrow functions evaluate **exactly one expression** — a block body `param => { stmt1; stmt2 }` is a parse error on every v2 build, including v2.1-alpha.30; for multi-statement logic use a named nested function, or v2.1's arrowless function expression `(params) { ... }`.
- `__Get(name, params)` and `__Set(name, params, value)` **must include the `params` parameter** — `params` is an Array of bracket arguments (e.g., `obj.prop[key]` passes `[key]`); the runtime always passes all of them, so a short-signature meta-function (`__Get(name)` or `__Set(name, value)`) throws `Error: Too many parameters passed to function` the first time a dynamic property is read or written.
- `__Get` and `__Set` are **invoked only for properties not defined on the class or its prototype** — own properties and prototype-defined methods bypass the meta-functions entirely — consequence: validators inside `__Set` are silently skipped for any property that was declared in the class body.
- Fat arrow **properties are getter-only** — a bare `propName => expr` in a class body defines no setter; assignment always throws a plain `Error` ("Property is read-only") — it never fails silently — consequence: use `propName { get => expr  set { ... } }` syntax when write access is required.
- Lambdas **stored as object properties and called as methods receive the object as the first argument** — always declare a leading parameter (e.g., `this`) to absorb the implicit argument — consequence: without the parameter, the implicit object argument over-fills the lambda's parameter list and every method-style call throws `Error: Too many parameters passed to function`.
- Variables captured in closures are captured **by reference, not by value** — the closure sees the current value of the outer variable at call time, not its value at closure-creation time — consequence: closures created inside a loop all share the same loop variable, a classic bug where every closure sees the loop's final value.

Safe-access priority order for dynamic properties:
  1. `obj.HasOwnProp(name)` — check own-property existence without triggering `__Get`
  2. `Map.Has(key)` inside `__Get` — safe lookup in backing store before returning a value or throwing
  3. `obj.DefineProp(name, descriptor)` — when property names and behavior are known at class-definition time
  4. `__Get` / `__Set` — only when the property namespace is genuinely open-ended and unknown at class-definition time

Pair every prohibition with its positive alternative:
- ✗ `__Get(name) { return this._store[name] }` — throws "Too many parameters passed to function" on the first dynamic property read
- ✓ `__Get(name, params) { return this._store[name] }` — correct v2 signature
- ✗ `fn := (x, y) => { result := x + y ; return result }` — block body parse error on every v2 build
- ✓ Named nested function assigned to a variable, or v2.1's arrowless function expression `(x, y) { ... }`

## TIER 1 — Basic Arrow Function Syntax
> METHODS COVERED: `=>` single-parameter form · `=>` multi-parameter form · `=>` no-parameter form

Fat arrow functions in AHK v2 are single-expression function literals using the `=>` operator. They are values — stored in variables, passed as arguments, returned from functions — not mere syntactic sugar for `return`. Parentheses around parameters are required when there are zero parameters or two or more; a single parameter name may appear bare.
```ahk
; ✓ Multi-parameter form requires parentheses — omitting them is a parse error
multiply := (x, y) => x * y

; ✓ Single-parameter form — parentheses optional but permitted for clarity
square := x => x * x

; ✓ Zero-parameter form — empty parens required; `() =>` is the correct spelling
greet := () => "Hello World"

; ✓ Arrow function is a first-class value: store, pass, call like any Func object
result := multiply(4, 5)   ; 20

; ✗ Block body after => is a load-time syntax error on EVERY v2 build, incl. v2.1-alpha.30
; add := (a, b) => {        ; → syntax error — => takes exactly one expression
;     return a + b
; }

; ✓ v2.1's multi-statement function expression is ARROWLESS — (params) { ... }
addBlock := (a, b) {
    c := a + b
    return c
}

; ✓ Traditional function for multi-statement logic — reference by bare name
Add(a, b) {
    return a + b
}

add := (a, b) => a + b   ; single-expression equivalent

result1 := Add(5, 3)     ; 8 — traditional call
result2 := add(5, 3)     ; 8 — arrow call, identical semantics
```

## TIER 2 — Named Arrow Functions and Recursion
> METHODS COVERED: Named recursive form · Named nested function reference pattern

An anonymous fat arrow *can* recurse through the variable it is assigned to — the body reads that variable at call time, after the assignment has completed, so the recursion works. The named recursive form `varName := FuncName(params) => expr` is still the preferred style: `FuncName` lives inside the function itself, so the recursion survives the outer variable being reassigned, shadowed, or passed somewhere else. For multi-statement logic that cannot collapse to a single expression, define a named nested function in the enclosing scope and reference its name as a value.
```ahk
; ✓ Named recursive form — FuncName is in scope inside the expression
factorial := Fact(n) => n <= 1 ? 1 : n * Fact(n-1)

fibonacci := Fib(n) => n <= 1 ? n : Fib(n-1) + Fib(n-2)

result := factorial(5)   ; 120

; ✓ Anonymous self-reference also runs — the body reads `anonFact` at call time, so once
;   assigned, anonFact(5) returns 120. Style note, not a necessity: prefer the named form,
;   which keeps working even if `anonFact` is later reassigned or shadowed.
anonFact := (n) => n <= 1 ? 1 : n * anonFact(n-1)

; ✓ Multi-statement logic: named nested function closes over enclosing scope, referenced by name
ProcessData(input) {
    validated := ValidateInput(input)
    if (!validated)
        throw ValueError("Invalid input")

    result := TransformData(validated)
    LogOperation("Process", input, result)
    return result
}
processData := ProcessData   ; processData holds the function reference; no () here
```

## TIER 3 — Closures and Variable Capture
> METHODS COVERED: Lexical capture · `StrLen()` · Closure factory pattern · Named nested function as closure

Arrow functions and named nested functions in AHK v2 automatically capture variables from their lexical enclosing scope. Captured variables are held by reference — the closure sees the current value of the outer variable at call time, not a snapshot from creation time. Project style: return a `Map` of flat named closures, not an object-literal lambda bag — `{}` is reserved for descriptors and option bags, and named functions read better than inline lambdas.
```ahk
; ✓ Four named closures all capture the same `count` variable by reference
CreateCounter() {
    count := 0
    Increment() {
        return ++count
    }
    Decrement() {
        return --count
    }
    GetValue() {
        return count
    }
    Reset() {
        return count := 0
    }
    actions := Map()
    actions["increment"] := Increment
    actions["decrement"] := Decrement
    actions["getValue"]  := GetValue
    actions["reset"]     := Reset
    return actions
}

counter := CreateCounter()
counter["increment"]()
counter["increment"]()
value := counter["getValue"]()   ; 2

; ✗ Lambda bag in an object literal — banned as a data record, and a method-call trap:
;   a property Func invoked as obj.increment() receives the object as an implicit first
;   argument. With no parameter declared, the call throws — it does not shift arguments.
; return {increment: () => ++count}   ; → counter.increment() throws Error: Too many parameters passed to function
;   If you must attach a Func to an object property, absorb the implicit argument with
;   a leading (this) parameter: {increment: (this) => ++count}

; ✓ Factory pattern — each CreateValidator call captures its own minLength/maxLength copy
CreateValidator(minLength, maxLength) {
    Validate(text) {
        len := StrLen(text)
        return len >= minLength && len <= maxLength
    }
    return Validate
}

emailValidator    := CreateValidator(5, 100)
passwordValidator := CreateValidator(8, 50)

isValidEmail    := emailValidator("user@domain.com")   ; true
isValidPassword := passwordValidator("abc")            ; false — StrLen("abc") = 3 < 8
```

## TIER 4 — Fat Arrow Properties
> METHODS COVERED: Getter fat arrow property · Parameterized property `prop[key]` · `get => / set { }` combined block · `FormatTime()`

Fat arrow properties inside a class body define computed getters: the expression is evaluated fresh on every property access and no backing field is allocated. For read-write properties, use the explicit `{ get => expr  set { ... } }` block syntax. Assignment to a pure fat arrow property — one defined with only `propName => expr` — always throws a plain `Error` ("Property is read-only") at runtime.
```ahk
; ✓ Each fat arrow property is re-evaluated on every access — no cached value
class DataProcessor {
    version => "2.0.1"

    ; ✓ FormatTime called on every read — always returns current timestamp
    timestamp => FormatTime(, "yyyy-MM-dd HH:mm:ss")

    ; ✓ Parameterized property — bracket argument available as `x` inside expr
    squareOf[x] => x * x

    _items := []
    ; ✓ Delegates to Array.Length — computed from backing field on each access
    count => this._items.Length
}

processor := DataProcessor()
MsgBox processor.version        ; "2.0.1"
MsgBox processor.timestamp      ; current date-time string
MsgBox processor.squareOf[5]    ; 25

; ✗ Assigning to a fat arrow property — no setter defined, throws a plain Error
; processor.version := "3.0"    ; → Error: Property is read-only.

; ✓ Combined get/set: fat arrow getter with validated traditional setter
class Counter {
    _value := 0

    value {
        get => this._value
        set {
            if (value < 0)
                throw ValueError("Counter cannot be negative")
            this._value := value
        }
    }

    isZero => this._value = 0
}
```

## TIER 5 — Dynamic Properties and Meta-Functions
> METHODS COVERED: `__Get` · `__Set` · `Map()` · `Map.Has()` · `HasOwnProp()` · `PropertyError()` · `ValueError()` · `IsInteger()`

`__Get` and `__Set` intercept reads and writes to properties that are not defined on the class or its prototype — enabling fully open-ended dynamic property bags. Both meta-functions in v2 carry a `params` parameter (an Array of bracket arguments) between the property name and, for `__Set`, the assigned value. Omitting `params` does not shift arguments — the runtime still passes them all, so a short-signature meta-function throws `Error: Too many parameters passed to function` the first time it fires.
```ahk
; ✓ Both meta-functions include the required `params` parameter
class DynamicObject {
    _props := Map()

    __Get(name, params) {
        if (this._props.Has(name))
            return this._props[name]
        throw PropertyError("Property '" name "' not found")
    }

    __Set(name, params, value) {
        this._props[name] := value
    }

    HasProperty(name) => this._props.Has(name)
    GetPropertyNames() => [this._props*]
}

obj := DynamicObject()
obj.color := "blue"
obj.size  := "large"
MsgBox obj.color   ; "blue"

; ✗ Legacy short signature — the runtime still passes (name, params), over-filling the method
; __Get(name) { return this._props[name] }   ; → Error: Too many parameters passed to function

; ✓ Advanced: meta-functions with per-key validation
class ConfigManager {
    _config     := Map()
    _validators := Map()

    __Get(key, params) {
        if (!this._config.Has(key))
            throw PropertyError("Configuration key '" key "' not found")
        return this._config[key]
    }

    __Set(key, params, value) {
        if (this._validators.Has(key)) {
            validator := this._validators[key]
            if (!validator(value))
                throw ValueError("Invalid value for '" key "'")
        }
        this._config[key] := value
    }

    SetValidator(key, validatorFunc) {
        this._validators[key] := validatorFunc
    }
}

config := ConfigManager()
config.SetValidator("port", (v) => IsInteger(v) && v > 0 && v <= 65535)
config.port := 8080   ; passes validation — IsInteger(8080) true, 8080 in range
```

### Performance Notes

**`__Get` / `__Set` dispatch overhead.** Every access to an undefined property passes through meta-function dispatch. For hot paths (tight loops over many property reads), prefer a `Map` accessed directly (`m[key]`) over a `DynamicObject` wrapper: direct Map access is O(1) with no function-call overhead; `__Get` adds at minimum one extra call frame per read. If all property names are known at class-definition time, `obj.DefineProp(name, descriptor)` with static descriptors costs nothing at access time.

**Closure allocation.** Each call to a factory function allocates a new closure environment that pins references to the captured variables. Avoid creating closures inside tight loops — create them once outside and reuse. AHK v2 has no JIT or closure inlining.

**Fat arrow property re-evaluation.** `timestamp => FormatTime(...)` calls `FormatTime` on every property read. Cache the result in a local variable when the same property is read multiple times in a single block.

**Composition depth.** `compose(compose(f, g), h)` allocates a new closure at every nesting level. For pipelines of more than three functions, an iterative approach (store functions in an Array, iterate with `for`) avoids deep closure chains and is more memory-efficient.

**Named recursive fat arrows.** `Fact(n) => n <= 1 ? 1 : n * Fact(n-1)` incurs standard function-call overhead per recursive call. AHK v2 has no tail-call optimization — prefer iterative implementations or memoization for large inputs.

## TIER 6 — Functional Programming Patterns
> METHODS COVERED: `compose` pattern · `Partial()` helper / `Func.Bind()` · `FunctionalArray.Map` · `FunctionalArray.Filter` · `FunctionalArray.Reduce` · `Mod()` · `IsSet()`

Fat arrows as first-class values enable composition, currying, and higher-order collection processing without naming every intermediate function. Composition chains transforms right-to-left; partial application specializes general functions; a custom `Array` subclass exposes `Map`/`Filter`/`Reduce` as a declarative pipeline API.
```ahk
; ✓ compose returns a new arrow that applies g first, then f — right-to-left application
compose := (f, g) => (x) => f(g(x))

addOne := x => x + 1
double := x => x * 2
square := x => x * x

addThenDouble    := compose(double, addOne)    ; double(addOne(x))
doubleThenSquare := compose(square, double)    ; square(double(x))

result1 := addThenDouble(5)     ; 12  — addOne(5)=6, double(6)=12
result2 := doubleThenSquare(3)  ; 36  — double(3)=6, square(6)=36

; ✗ Argument order reversal — compose(addOne, double) applies double first, not add
; wrongOrder := compose(addOne, double)   ; → addOne(double(x)), semantically reversed

; ✓ Currying — each call returns an arrow awaiting the next argument
curriedAdd := (a) => (b) => (c) => a + b + c

; ✓ Partial application — pre-bind leading arguments, append the rest at call time.
;   A spread may appear only once, in final position — fn(args*, remaining*) is a
;   load-time syntax error. Clone the bound args, push the remaining ones, then make
;   the single final spread.
Partial(fn, args*) {
    Invoke(remaining*) {
        callArgs := args.Clone()
        for item in remaining
            callArgs.Push(item)
        return fn(callArgs*)
    }
    return Invoke
}

multiply := (a, b, c) => a * b * c

multiplyBy2     := Partial(multiply, 2)
multiplyBy2And3 := Partial(multiply, 2, 3)

result1 := curriedAdd(1)(2)(3)     ; 6
result2 := multiplyBy2(5, 3)       ; 30
result3 := multiplyBy2And3(4)      ; 24

; ✓ Func.Bind does the same for the simple leading-args case
boundBy2 := multiply.Bind(2)
result4  := boundBy2(5, 3)         ; 30

; ✓ FunctionalArray subclass exposes Map/Filter/Reduce as chainable methods
class FunctionalArray extends Array {
    Map(fn) {
        result := FunctionalArray()
        for item in this
            result.Push(fn(item))
        return result
    }

    Filter(predicate) {
        result := FunctionalArray()
        for item in this
            if predicate(item)
                result.Push(item)
        return result
    }

    Reduce(fn, initial := unset) {
        result := IsSet(initial) ? initial : this[1]
        startIndex := IsSet(initial) ? 1 : 2

        Loop this.Length - startIndex + 1 {
            result := fn(result, this[startIndex + A_Index - 1])
        }
        return result
    }
}

numbers := FunctionalArray(1, 2, 3, 4, 5)
doubled := numbers.Map(x => x * 2)              ; [2, 4, 6, 8, 10]
evens   := numbers.Filter(x => Mod(x, 2) = 0)  ; [2, 4]
sum     := numbers.Reduce((a, b) => a + b)      ; 15
```

## ANTI-PATTERNS

| Pattern | Wrong | Correct | LLM Common Cause |
|---------|-------|---------|------------------|
| Block-body fat arrow | `` fn := x => { a := x*2 ; return a } `` | Named nested function, or arrowless `(x) { ... }` (v2.1) | JavaScript allows arrow block bodies; no AHK v2 build does — v2.1's multi-statement form is the arrowless `(params) { }` |
| `__Get` missing `params` | `__Get(name) { return this._store[name] }` | `__Get(name, params) { return this._store[name] }` | Legacy `__Get` took only `name`; v2 adds `params` — the short signature now throws "Too many parameters passed to function" instead of running |
| `__Set` missing `params` | `__Set(name, value) { this._store[name] := value }` | `__Set(name, params, value) { this._store[name] := value }` | Same legacy regression — the three-argument dispatch over-fills the two-parameter method and throws "Too many parameters passed to function" |
| Lambda property without leading param | `increment: () => ++count` stored in `{}` | `increment: (this) => ++count` — better: named closures in a Map (TIER 3) | LLMs model AHK like JavaScript, where arrow functions do not receive an implicit `this`; AHK v2 passes the object as first positional arg, and the over-filled call throws "Too many parameters" |
| Anonymous self-reference (style) | `` fact := (n) => n <= 1 ? 1 : n * fact(n-1) `` — works, but breaks if `fact` is reassigned or shadowed | `` fact := Fact(n) => n <= 1 ? 1 : n * Fact(n-1) `` — the name travels with the function | The variable is read at call time, so the recursion runs; the named form is preferred for robustness, not necessity |
| Assigning to fat arrow property | `obj.version := "3.0"` where `version => expr` | `version { get => expr  set { ... } }` combined block | Python `@property` is read-write by default; LLMs assume AHK fat arrow properties behave identically |

## SEE ALSO

> This module does NOT cover: traditional function syntax, default parameters, variadic `args*` params, and the full `Func` object API → use built-in AHK v2 knowledge (no dedicated functions module yet).
> This module does NOT cover: full class property declaration, inheritance, prototype chain, and `__New` constructor → see Module_Classes.md
> This module does NOT cover: `try/catch` wrapping for `PropertyError` and `ValueError` raised from `__Get`/`__Set` → see Module_Errors.md
> This module does NOT cover: built-in Array methods (`Push`, `Pop`, `RemoveAt`, `Sort`) and standard iteration patterns → see Module_Arrays.md
> This module does NOT cover: `SetTimer`/`OnMessage` async callback scheduling and timer closure patterns → use built-in AHK v2 knowledge (no dedicated async/timers module yet).

- Traditional function definitions, default parameters, variadic `args*`, and the `Func` object API (`Bind()`, `Call()`, `MinParams`, `MaxParams`) — use built-in AHK v2 knowledge (no dedicated functions module yet).
- `Module_Classes.md` — class property declaration with `{get/set}` blocks, inheritance, `__New` constructor, and prototype-chain OOP patterns that pair with the fat arrow property forms in TIER 4.
- `Module_Errors.md` — `try/catch` patterns for `PropertyError` and `ValueError` thrown from `__Get`/`__Set` validators; custom exception class definitions and error propagation.
- `Module_Arrays.md` — built-in Array methods and iteration; the `FunctionalArray` subclass in TIER 6 extends these primitives rather than replacing them.
- `Module_Objects.md` — plain object literals, `OwnProps()` enumeration, and `obj.DefineProp(name, descriptor)` as a static alternative to `__Get`/`__Set` for property interception when property names are known ahead of time.