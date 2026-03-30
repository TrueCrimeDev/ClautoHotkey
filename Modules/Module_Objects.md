# Module_Objects.md
<!-- DOMAIN: Objects and OOP -->
<!-- SCOPE: Advanced meta-functions (__Get/__Set/__Call/__Delete/__Enum), mixin patterns, and deep class hierarchies are not covered — see Module_Classes.md. -->
<!-- TRIGGERS: object, class, property, method, inheritance, extends, descriptor, prototype, DefineProp, HasProp, HasMethod, HasBase, GetMethod, ObjBindMethod, BoundFunc, "create object", "property validation", "method binding", "computed property", "callback context", "check object type", "read-only property" -->
<!-- CONSTRAINTS: Instantiate classes with ClassName() — never `new ClassName()`; the keyword was removed in v2 and throws TypeError. Arrow syntax (=>) is valid only for single-expression DefineProp descriptor bodies; multi-line descriptor bodies require named function references or AHK v2 throws a parse error. -->
<!-- CROSS-REF: Module_Classes.md, Module_DataStructures.md, Module_GUI.md, Module_Errors.md, Module_Arrays.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `new ClassName()` | `ClassName()` | TypeError at runtime — `new` keyword removed entirely in AHK v2 |
| `{key: val}` as a data container | `Map("key", val)` | Object literals lack `.Has()`, `.Get()`, `.Delete()` — missing keys throw UnsetError with no safe fallback |
| `IsObject(x)` for type checking | `x is Object` or `Type(x)` | `IsObject()` still exists in v2 and returns non-zero for any object; `is Object` and `Type()` are preferred alternatives when finer-grained type discrimination is needed |
| `SetTimer, % this.Method, 1000` | `SetTimer(this.Method.Bind(this), 1000)` | v1 percent-expression syntax gone; unbound method loses `this` context at callback time — UnsetError in the callback body |
| `obj.__Set := func` (v1 meta-function assignment) | `obj.DefineProp("prop", {set: func})` | Meta-function assignment removed — `DefineProp()` is the only v2 hook for intercepting property behavior |
| `(this, value) => { ... multiline ... }` in DefineProp | Named function reference passed to descriptor key | Parse error at the opening brace — arrow syntax cannot open a multi-line block body in AHK v2 |
| `Object().DefineProp(SomeProto, "x", d)` | `SomeProto.DefineProp("x", d)` | `DefineProp()` is an instance method; calling it on an anonymous `Object()` with a prototype as argument has no effect on that prototype |

## API QUICK-REFERENCE

### Any Class (root — every AHK v2 value inherits these)
| Method / Property | Signature | Notes |
|-------------------|-----------|-------|
| `.HasProp()` | `.HasProp(name)` | Returns 1 if the instance or any prototype in the chain owns named property; never throws |
| `.HasMethod()` | `.HasMethod(name, paramCount?)` | Returns 1 if a callable method exists; optionally validates expected arity |
| `.HasBase()` | `.HasBase(baseObj)` | Returns 1 if `baseObj` appears anywhere in the prototype chain |
| `.GetMethod()` | `.GetMethod(name, paramCount?)` | Returns the method Func object; throws MethodError if not found |
| `.Base` | `.Base` | Readable and writable reference to the object's direct prototype |

### Object (instance methods — available on plain objects and class instances)
| Method / Property | Signature | Notes |
|-------------------|-----------|-------|
| `.DefineProp()` | `.DefineProp(name, descriptor)` | Defines or replaces a property; descriptor is an object literal with `get`, `set`, `call`, or `value` keys |
| `.DeleteProp()` | `.DeleteProp(name)` | Removes an own property and returns its last value |
| `.GetOwnPropDesc()` | `.GetOwnPropDesc(name)` | Returns the descriptor object for an own property; useful for inspection |
| `.OwnProps()` | `.OwnProps()` | Returns an enumerator over own property name–value pairs (excludes prototype chain) |

### Func / BoundFunc
| Method / Property | Signature | Notes |
|-------------------|-----------|-------|
| `.Bind()` | `.Bind(args*)` | Returns a BoundFunc with leading arguments pre-filled; primary tool for capturing `this` in callbacks |
| `ObjBindMethod()` | `ObjBindMethod(obj, methodName, args*)` | Returns a BoundFunc that calls `obj.methodName`; preferred over `.Bind()` for SetTimer and GUI events |

### Type Introspection
| Function / Operator | Signature | Notes |
|---------------------|-----------|-------|
| `Type()` | `Type(value)` | Returns type name string: `"Integer"`, `"Float"`, `"String"`, `"Object"`, or the class name |
| `is` operator | `expr is TypeOrClass` | Returns 1 if `expr` is an instance of the named type or class; traverses the full prototype chain |

### Supporting Functions (used in examples — defined in other modules)
| Function | Primary Module | Role in examples |
|----------|---------------|-----------------|
| `SetTimer()` | Module_AsyncAndTimers.md | Registers BoundFunc callbacks |
| `Gui.OnEvent()` | Module_GUI.md | Wires GUI control events to bound methods |
| `FormatTime()` | Module_TextProcessing.md | Used in computed property examples |
| `RegExMatch()` | Module_TextProcessing.md | Used in validation helper examples |
| `StrSplit()` | Module_TextProcessing.md | Used in prototype extension example |

## AHK V2 CONSTRAINTS

- `ClassName()` — never `new ClassName()` — the `new` keyword was removed in AHK v2 and throws TypeError; every class instantiation in v2 is a plain function call.
- Arrow syntax (`=>`) is valid only for single-expression descriptor bodies — any descriptor body requiring more than one statement must use a named function reference; mixing arrow with a brace block (`=> { ... }`) is a parse error.
- Class body property descriptors use `get => expr` / `set { ... }` syntax — do NOT write `set => { ... }` (arrow + block); this form is rejected by the AHK v2 parser inside class bodies.
- Use `Map()` for key-value data storage, not object literals — object literals lack `.Has()`, `.Get()`, and `.Delete()`, making safe missing-key access impossible.
- `ObjBindMethod()` or `.Bind(this)` is required whenever passing a method as a callback — a raw `this.Method` reference passed to `SetTimer` or `OnEvent` loses `this` context at invocation time, causing UnsetError inside the method body.
- Prototype extension via `DefineProp` is global — it applies to every instance of that type across the entire script; use judiciously to avoid hidden coupling between unrelated call sites.

Safe-access priority order for object property reads:

1. `.HasProp(name)` before access — when absent vs. present requires different branch logic
2. `Map.Get(key, default)` — for dynamic key-value data; always prefer Map over plain Object for data bags
3. `.GetOwnPropDesc(name)` — only when you need the descriptor itself, not the property value
4. `try/catch` on property access — only when the thrown error carries diagnostic information beyond "key absent"

✗ / ✓ pairs:

- ✗ `val := obj.missingKey` — UnsetError if property not set
- ✓ `val := obj.HasProp("missingKey") ? obj.missingKey : defaultVal` — safe, never throws

- ✗ `john := new Person("John", 30)` — TypeError, `new` removed in AHK v2
- ✓ `john := Person("John", 30)` — correct v2 instantiation

- ✗ `obj.DefineProp("x", {set: (this, v) => { if v < 0 ... }})` — parse error, arrow + block
- ✓ Named function reference passed as the `set` descriptor value for multi-line bodies

- ✗ `SetTimer(this.Tick, 1000)` — `this` lost at callback time
- ✓ `SetTimer(this.Tick.Bind(this), 1000)` — BoundFunc preserves object context

## TIER 1 — Object Fundamentals, Creation, and the Any Root
> METHODS COVERED: Type · HasProp · HasMethod · Map (constructor) · DefineProp (class body __New)

Every value in AHK v2 — strings, integers, functions, class instances — is an object inheriting from the `Any` root class. This tier establishes the object hierarchy, the introspection methods available on every value, and the two primary creation forms: class instantiation (no `new`) and plain object literals for ad-hoc structures.
```ahk
; ✓ Type() reveals the runtime type of any value — everything is a typed object in AHK v2
greeting := "Hello"
MsgBox(Type(greeting))   ; "String"

number := 42
MsgBox(Type(number))     ; "Integer" — primitives are typed objects, not raw values

; ✓ HasProp/HasMethod from Any are available on every value — never throw, return 0 or 1
obj := {}
MsgBox(obj.HasProp("SomeProperty"))   ; 0
MsgBox(obj.HasMethod("ToString"))     ; 0

; ✓ Class instantiation is a plain function call — 'new' keyword removed in AHK v2
class Person {
    __New(name, age) {
        this.name := name
        this.age  := age
    }

    Greet() {
        MsgBox("Hello, I'm " . this.name)
    }
}

john := Person("John", 30)   ; Correct v2 form — no 'new'
john.Greet()

; ✓ Object literal for ad-hoc structured data with known, fixed properties
person := {
    name: "John",
    age:  30
}

; ✓ Map() for dynamic key-value storage — provides .Has(), .Get(), .Delete()
settings := Map("theme", "dark", "volume", 80)

; ✗ 'new' keyword removed — TypeError at runtime
; john := new Person("John", 30)   ; → TypeError

; ✗ Object literal for data with unknown or dynamic keys — no safe missing-key access
; data := {theme: "dark"}
; MsgBox(data["nonexistent"])      ; → UnsetError
```

## TIER 2 — Property Descriptors: get, set, call, and DefineProp
> METHODS COVERED: DefineProp · GetOwnPropDesc · OwnProps · DeleteProp

Descriptors control exactly how a property behaves when read (`get`), assigned (`set`), or invoked (`call`). `DefineProp()` is the runtime API for any object instance; class body `get`/`set` blocks are the compile-time equivalent with slightly different but compatible syntax. Arrow syntax is valid only for single-expression bodies — multi-line bodies require named function references.
```ahk
; ✓ Single-line arrow descriptor — valid because the body is one expression
obj := {}
obj.DefineProp("currentTime", {
    get: (*) => FormatTime(, "yyyy-MM-dd HH:mm:ss")
})
MsgBox(obj.currentTime)   ; Always computes fresh on each read

; ✓ Multi-line descriptor body requires a named function reference
;   Arrow + brace block is a parse error — use this pattern instead
SetAge(this, value) {
    if (value < 0 || value > 150)
        throw ValueError("Invalid age: " . value)
    this._age := value
}
obj.DefineProp("age", {
    set: SetAge,
    get: (this) => this._age ?? 0
})
obj.age := 25   ; Validated; out-of-range throws ValueError

; ✓ Full get+set in DefineProp with separate named setter
SetComplexValue(this, value) {
    if (value < 0)
        throw ValueError("Value must be positive")
    this._value := value
}
obj.DefineProp("complex", {
    get: (this) => this._value ?? 0,
    set: SetComplexValue
})

; ✗ Arrow syntax with multi-line block — parse error in AHK v2
; obj.DefineProp("broken", {
;     set: (this, value) => {    ; → Parse error: arrow cannot open a brace block
;         if (value < 0)
;             throw ValueError("Invalid")
;         this._value := value
;     }
; })

; ✓ Call descriptor — transforms a property into a callable method
CalculateOp(this, operation, a, b) {
    switch operation {
        case "add":      return a + b
        case "multiply": return a * b
        default:         throw ValueError("Unknown operation: " . operation)
    }
}
obj.DefineProp("calculate", {call: CalculateOp})
result := obj.calculate("add", 5, 3)   ; Returns 8

; ✓ Class body get/set syntax — different form, semantically equivalent to DefineProp
;   Use 'set { }' NOT 'set => { }' inside a class body
class Rectangle {
    __New(width, height) {
        this._width  := width
        this._height := height
    }

    ; Validated set + simple get — private backing property _width
    Width {
        get => this._width
        set {
            if (value <= 0)
                throw ValueError("Width must be positive")
            this._width := value
        }
    }

    ; Computed read-only property — get-only descriptor
    Area {
        get => this._width * this._height
    }
}

rect := Rectangle(10, 5)
MsgBox("Area: " . rect.Area)   ; 50

; ✓ Class methods are automatically call descriptors — no manual DefineProp needed
class Calculator {
    Add(a, b)      => a + b
    Multiply(a, b) => a * b
}
calc   := Calculator()
result := calc.Add(10, 5)   ; 15

; ✗ 'set => { }' inside class body — not valid class body syntax
; Width {
;     set => { this._width := value }   ; → Parse error inside class body
; }
```

## TIER 3 — Class Inheritance and Prototype Extension
> METHODS COVERED: extends · super.__New · is operator · HasBase · String.Prototype.DefineProp

`extends` builds a prototype chain; `super` reaches the parent constructor and methods. The `is` operator traverses the full chain for type checking. Prototype extension via `DefineProp` on a shared prototype adds a method globally to all instances of that type.
```ahk
; ✓ extends + super.__New delegates to the parent constructor without duplication
class Animal {
    __New(name, species) {
        this.name    := name
        this.species := species
    }

    Speak() {
        MsgBox(this.name . " makes a sound")
    }
}

class Dog extends Animal {
    __New(name, breed) {
        super.__New(name, "Dog")   ; Delegate to Animal.__New — sets name and species
        this.breed := breed
    }

    ; Override parent method — super.Speak() still accessible if needed
    Speak() {
        MsgBox(this.name . " barks: Woof!")
    }
}

buddy := Dog("Buddy", "Golden Retriever")
buddy.Speak()   ; "Buddy barks: Woof!"

; ✓ 'is' operator traverses the full prototype chain
if (buddy is Animal)
    MsgBox("Buddy is an Animal")   ; Shows — Dog → Animal is a valid chain

; ✓ HasBase() for programmatic prototype chain inspection
MsgBox(buddy.HasBase(Animal.Prototype))   ; 1

; ✓ Prototype extension — String.Prototype is not Object-derived; call DefineProp via Object.Prototype
ReverseStr(this) {
    chars    := StrSplit(this)
    reversed := ""
    Loop chars.Length
        reversed .= chars[chars.Length - A_Index + 1]
    return reversed
}
ObjDefineProp := Object.Prototype.DefineProp
ObjDefineProp(String.Prototype, "Reverse", {call: ReverseStr})

text := "Hello World"
MsgBox("Reversed: " . text.Reverse())   ; "dlroW olleH"

; ✗ Wrong prototype extension syntax — String.Prototype does not inherit from Object.Prototype and has no DefineProp
; Object().DefineProp(String.Prototype, "Reverse", {call: ReverseStr})   ; → No effect on String.Prototype

; Warning: Prototype extension is global — affects every call site using that type in the script
```

## TIER 4 — BoundFunc and Callback Context Management
> METHODS COVERED: .Bind() · ObjBindMethod · SetTimer · Gui.OnEvent

Raw method references (`this.Method`) passed to `SetTimer` or GUI `OnEvent` lose their `this` binding at invocation time because the callback fires outside the object context. `.Bind(this)` or `ObjBindMethod()` must capture the object before the callback is registered — not at invocation time.
```ahk
; ✓ .Bind(this) creates a BoundFunc that carries object context into the callback
class Timer {
    __New(name) {
        this.name  := name
        this.count := 0
    }

    Start() {
        ; ✓ Bind captures 'this' — SetTimer receives a BoundFunc, not a raw method reference
        this.boundTick := this.Tick.Bind(this)
        SetTimer(this.boundTick, 1000)
    }

    Tick() {
        this.count++
        MsgBox(this.name . " tick #" . this.count)
    }
}

timer := Timer("MyTimer")
timer.Start()

; ✗ Unbound method — 'this' inside Tick() is undefined at callback time
; SetTimer(this.Tick, 1000)   ; → UnsetError when Tick() accesses this.name

; ✓ GUI event binding — bind every OnEvent handler so class methods access instance state
class SimpleGUI {
    __New() {
        this.CreateGUI()
    }

    CreateGUI() {
        this.gui       := Gui("+Resize", "My Application")
        this.nameEdit  := this.gui.AddEdit("w200")
        this.submitBtn := this.gui.AddButton("w100", "Submit")

        ; ✓ Bind this before registering — handler fires with correct instance context
        this.submitBtn.OnEvent("Click", this.OnSubmit.Bind(this))
        this.gui.OnEvent("Close",       this.OnClose.Bind(this))

        this.gui.Show("w300 h150")
    }

    OnSubmit(*) {
        name := this.nameEdit.Value
        if (name.Length > 0) {
            MsgBox("Hello, " . name . "!")
            this.nameEdit.Value := ""
        }
    }

    OnClose(*) {
        ExitApp()
    }
}

app := SimpleGUI()
```

## TIER 5 — Dynamic Properties and Object Composition
> METHODS COVERED: DefineProp · Map.Set · Map.Get · Map.Has · Map (constructor)

`DefineProp` at runtime enables plugin-style architectures and configuration-driven objects where property names are not known at compile time. Composition — assembling objects from focused collaborator instances — scales more flexibly than deep inheritance for complex domains and produces flatter, faster prototype chains.
```ahk
; ✓ Runtime property creation with per-property validator via DefineProp
class DynamicObject {
    __New() {
        this.properties := Map()
    }

    AddProperty(name, initialValue := "", validator := "") {
        if (validator != "") {
            SetValidated(this, value) {
                if (validator.Call(value))
                    this.properties.Set(name, value)
                else
                    throw ValueError("Invalid value for " . name . ": " . value)
            }
            this.DefineProp(name, {
                get: (this) => this.properties.Get(name, ""),
                set: SetValidated
            })
        } else {
            this.DefineProp(name, {
                get: (this) => this.properties.Get(name, ""),
                set: (this, value) => this.properties.Set(name, value)
            })
        }

        this.properties.Set(name, initialValue)
    }
}

obj := DynamicObject()
obj.AddProperty("age", 0, (value) => value >= 0 && value <= 150)
obj.age := 25
MsgBox("Age: " . obj.age)

; ✓ Composition — complex objects built from focused single-responsibility collaborators
class Logger {
    __New(level := "INFO") {
        this.level := level
    }

    Log(message, level := "INFO") {
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        MsgBox("[" . timestamp . "] " . level . ": " . message)
    }
}

class Database {
    __New(connectionString) {
        this.connectionString := connectionString
        this.connected        := false
    }

    Connect() {
        this.connected := true
        return true
    }

    Query(sql) {
        if (!this.connected)
            throw Error("Not connected to database")
        return "Result for: " . sql
    }
}

; ✓ DataService composes Logger + Database + Map cache — no inheritance needed
class DataService {
    __New(connectionString, logLevel := "INFO") {
        this.logger   := Logger(logLevel)
        this.database := Database(connectionString)
        this.cache    := Map()
    }

    Initialize() {
        this.logger.Log("Initializing data service")
        return this.database.Connect()
    }

    GetData(query, useCache := true) {
        ; ✓ Map.Has() before Map.Get() — when cache-hit and cache-miss paths differ
        if (useCache && this.cache.Has(query))
            return this.cache.Get(query)

        result := this.database.Query(query)

        if (useCache)
            this.cache.Set(query, result)

        return result
    }
}

service := DataService("server=localhost;db=test")
if (service.Initialize()) {
    result := service.GetData("SELECT * FROM users")
    MsgBox("Query result: " . result)
}
```

### Performance Notes

- **Descriptor get/set is not free.** Each `DefineProp` get/set invokes a closure on every property read or write. For inner-loop hot paths, compute the value once and cache it in a plain backing property; invalidate on `set` rather than recomputing on every `get`.
- **Flat prototype chains.** Deep inheritance chains (5+ levels) increase property lookup time proportionally. Composition with single-level collaborator objects is both faster to look up and easier to profile — prefer it for performance-sensitive code.
- **BoundFunc allocation.** Each `.Bind()` call allocates a new BoundFunc. Create bound callbacks once in `__New` and store them as instance properties; never call `.Bind()` inside event handlers or timer ticks that fire repeatedly.
- **`OwnProps()` enumerator cost.** Enumerating own properties on objects with many `DefineProp` descriptors is O(n). Avoid enumerating inside tight loops; cache the key set in a Map if repeated iteration is required.
- **Map over Object for data.** Map lookup is hash-based O(1). Iterating object own properties via `OwnProps()` has overhead proportional to the number of descriptors. Map is not only semantically correct for key-value data — it is also faster.

## TIER 6 — Validated Objects and Config Patterns
> METHODS COVERED: DefineProp · Map.Get · Map.Set · RegExMatch · ValueError (class)

Combining descriptor-level validation with structured config classes creates a self-enforcing data layer — each property rejects invalid input at assignment time, eliminating repeated defensive checks at every call site that consumes the config.
```ahk
; ✓ ValidatedConfig uses set descriptors for per-property validation — callers need no guards
class ValidatedConfig {
    __New() {
        this._settings := Map()
        this.SetupValidation()
    }

    SetupValidation() {
        ; Database host — rejects empty string at assignment time
        SetDatabaseHost(this, value) {
            if (value == "")
                throw ValueError("Database host cannot be empty")
            this._settings.Set("DatabaseHost", value)
        }
        this.DefineProp("DatabaseHost", {
            get: (this) => this._settings.Get("DatabaseHost", "localhost"),
            set: SetDatabaseHost
        })

        ; Database port — type and range validated in the descriptor, not at call sites
        SetDatabasePort(this, value) {
            if (!(value is Integer) || value < 1 || value > 65535)
                throw ValueError("Port must be between 1 and 65535")
            this._settings.Set("DatabasePort", value)
        }
        this.DefineProp("DatabasePort", {
            get: (this) => this._settings.Get("DatabasePort", 5432),
            set: SetDatabasePort
        })
    }

    ; Reusable validation helper — callable from any set descriptor in this class
    IsValidEmail(email) {
        return RegExMatch(email, "i)^[^@\s]+@[^@\s]+\.[^@\s]+$") > 0
    }
}

; ✓ Errors surface at assignment boundary — one try/catch, not scattered guards
try {
    config := ValidatedConfig()
    config.DatabaseHost := "production.db.company.com"
    config.DatabasePort := 5432

    MsgBox("Configuration valid - Host: " . config.DatabaseHost)

} catch ValueError as e {
    MsgBox("Configuration error: " . e.Message)
}

; ✗ Defensive checking at every call site — fragile, repeated, easy to miss
; host := GetConfig("host")
; if (host == "")                          ; → Must repeat this guard everywhere
;     throw ValueError("Host empty")
; port := GetConfig("port")
; if (port < 1 || port > 65535)           ; → Duplicated validation logic
;     throw ValueError("Invalid port")
```

## ANTI-PATTERNS

| Pattern | Wrong | Correct | LLM Common Cause |
|---------|-------|---------|------------------|
| `new` keyword for instantiation | `new Person("John", 30)` | `Person("John", 30)` | AHK v1 and every mainstream OOP language require `new`; v2 dropped it silently |
| Object literal as data container | `{key: val}` for dynamic storage | `Map("key", val)` | AHK v1 used object literals for all key-value data; v2 Map() is the designated replacement with full API |
| Arrow + block in DefineProp descriptor | `set: (this, v) => { if v < 0 ... }` | Named function reference for any multi-line body | JS/Python lambda syntax allows multi-line bodies; AHK v2 arrow syntax does not — mixed-language training data causes this |
| Unbound method as callback | `SetTimer(this.Tick, 1000)` | `SetTimer(this.Tick.Bind(this), 1000)` | AHK v1 percent-expression syntax obscured binding mechanics; LLMs trained on v1 omit `.Bind()` entirely |
| `IsObject()` for type checking | `if IsObject(x)` | `if x is Object` or `Type(x) != "Integer"` | `IsObject()` still exists in v2; however `is Object` offers chain-aware type checking and `Type()` returns the exact class name, making them more precise alternatives for new v2 code |
| Wrong prototype extension site | `Object().DefineProp(String.Prototype, "x", d)` | `ObjDefineProp(String.Prototype, "x", d)` where `ObjDefineProp := Object.Prototype.DefineProp` | `String` is not a subclass of `Object` — `String.Prototype` has no `DefineProp` instance method; the underlying implementation must be extracted from `Object.Prototype.DefineProp` and called with `String.Prototype` as the explicit receiver |
| `set => { }` block in class body | `Width { set => { this._w := value } }` | `Width { set { this._w := value } }` | Conflating DefineProp arrow descriptor syntax with class body `set` block syntax — two different parse contexts |

## SEE ALSO

> This module does NOT cover: meta-functions (`__Get`, `__Set`, `__Call`, `__Delete`, `__Enum`), abstract base classes, and mixin composition patterns — see Module_Classes.md.
> This module does NOT cover: Map vs Object selection criteria, nested structure patterns, and serialization — see Module_DataStructures.md.
> This module does NOT cover: try/catch design in object methods, custom exception classes, and error propagation chains — see Module_Errors.md.

- `Module_Classes.md` — advanced class hierarchies, meta-functions, abstract bases, and mixin patterns.
- `Module_DataStructures.md` — authoritative Map vs Object selection, nested structures, and data serialization.
- `Module_GUI.md` — complete GUI object integration, control event wiring, and GUI lifecycle management.
- `Module_Errors.md` — try/catch patterns for descriptor-level validation, custom exception classes, and propagation.
- `Module_Arrays.md` — Array iteration, transformation, and storage of object collections.