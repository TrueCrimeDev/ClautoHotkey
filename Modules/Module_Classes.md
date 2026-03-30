# Module_Classes.md
<!-- DOMAIN: Classes -->
<!-- SCOPE: Prototype chain manipulation, raw ObjPtr arithmetic, and GUI control subclassing belong in Module_ClassPrototyping.md and Module_GUI.md — this module covers class definition, inheritance, meta-functions, factory patterns, resource lifecycle, and observer patterns only. -->
<!-- TRIGGERS: class, extends, __New, __Delete, __Get, __Set, __Call, __Enum, super, static, inheritance, "create object", "object-oriented", "instantiate", "constructor", "destructor", "method chaining", "factory pattern", "observer pattern", "resource cleanup", "weak reference" -->
<!-- CONSTRAINTS: Instantiate classes with ClassName() — never `new ClassName()` (TypeError in v2). Always call .Bind(this) on event/timer callbacks — raw method references lose `this` context. Use super.__New(args*) not super() in derived constructors. Never rely on __Delete() timing — always provide an explicit dispose() method for deterministic cleanup. -->
<!-- CROSS-REF: Module_ClassPrototyping.md, Module_GUI.md, Module_Errors.md, Module_Arrays.md, Module_Objects.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `new ClassName()` | `ClassName()` | TypeError — `new` is not a keyword in AHK v2; bare instantiation is the only form |
| `super()` in derived `__New` | `super.__New(args*)` | Parent constructor never runs; instance fields from base class are uninitialised |
| Raw method reference as callback: `SetTimer(this.Update, 1000)` | `SetTimer(this.Update.Bind(this), 1000)` | `this` inside the callback resolves to the wrong object or throws |
| `__Get(name)` / `__Set(name, val)` (two-param v1 signatures) | `__Get(name, params)` / `__Set(name, params, value)` (three-param v2) | Meta-function never fires — wrong arity silently skips the intercept |
| `{key: val}` object literal as data container | `Map("key", val)` | Object literals lack `.Has()`, `.Delete()`, `.Clear()` — silent data loss on key checks |
| Static member access via instance: `this.StaticProp` | `ClassName.StaticProp` | Reads or shadows the instance, not the shared class-level value |
| Multi-line fat-arrow callback: `(x) => { return x*2 }` | Named function or traditional closure | AHK v2 fat arrows accept a single expression only — block bodies are a syntax error |

## API QUICK-REFERENCE

### Class Meta-Functions
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `__New()` | `__New(params*)` | Constructor; called automatically on `ClassName(args)` |
| `__Delete()` | `__Delete()` | Destructor; GC timing is non-deterministic — pair with explicit `dispose()` |
| `__Get()` | `__Get(name, params)` | Intercepts undefined property reads; throw `PropertyError` if unhandled |
| `__Set()` | `__Set(name, params, value)` | Intercepts undefined property writes; `params` is an Array of bracket parameters |
| `__Call()` | `__Call(name, params)` | Intercepts undefined method calls; `params` is an Array of arguments |
| `__Enum()` | `__Enum(numberOfVars)` | Called by `for` loop; must return an enumerator object |
| `__Item` | `__Item[key] { get; set }` | Parameterised bracket-access: `obj["key"]` dispatches here |

### Instance / Object Methods
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `.HasProp()` | `.HasProp(name)` | True if instance or any prototype owns the named property |
| `.HasMethod()` | `.HasMethod(name?)` | True if named method is defined; omit name to test if object itself is callable |
| `.DefineProp()` | `.DefineProp(name, desc)` | Define or replace a property; `desc` is `{value:}`, `{get:}`, `{set:}`, or `{call:}` |
| `.Bind()` | `method.Bind(thisArg, params*)` | Returns bound callable with fixed `this`; mandatory for all timer/event callbacks |
| `.__Class` | `obj.__Class` | Returns class name string; useful for pool key lookup and debug logging |
| `super.__New()` | `super.__New(args*)` | Calls base-class constructor from a derived `__New`; must be called before using base fields |
| `super.method()` | `super.methodName(args*)` | Calls base-class method from an override; works in any derived method, not just `__New` |

### Object Utility Functions
| Function | Signature | Notes |
|----------|-----------|-------|
| `ObjPtr()` | `ObjPtr(obj)` | Returns raw memory address (integer) without incrementing ref count; use for weak-reference tracking |
| `ObjFromPtrAddRef()` | `ObjFromPtrAddRef(ptr)` | Retrieves object from pointer and increments ref count; valid only while the object has not been freed |
| `IsSet()` | `IsSet(varOrProp)` | Returns true if variable/property has a value — use instead of `!= unset` comparisons |

### Map (preferred class state container)
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `Map()` | `Map(k, v, ...)` | Preferred key-value container for class state; never use `{k: v}` object literals |
| `.Has()` | `.Has(key)` | Existence check — always use before direct `[key]` access |
| `.Get()` | `.Get(key, default)` | Safe access — `default` must be a concrete value, never `unset` |
| `.Clear()` | `.Clear()` | Remove all entries; call in `__Delete()` or `dispose()` |
| `.Delete()` | `.Delete(key)` | Remove a single key; returns the removed value |
| `.Count` | `.Count` | Number of key-value pairs currently stored |

## AHK V2 CONSTRAINTS

- ✗ `new ClassName()` — TypeError; `new` is not a keyword in AHK v2
- ✓ `ClassName(args*)` — bare call is the only valid instantiation form

- ✗ `SetTimer(this.Method, 1000)` — `this` is wrong or missing inside the callback
- ✓ `SetTimer(this.Method.Bind(this), 1000)` — `.Bind(this)` is mandatory for any timer, GUI event, or hotkey handler that references instance state

- ✗ `super()` in a derived `__New` — base constructor is never executed
- ✓ `super.__New(args*)` — explicit method call on the base class prototype

- ✗ Relying on `__Delete()` alone for resource release — GC timing is non-deterministic; resources leak on exception paths
- ✓ Always provide a named `dispose()` that is called explicitly in a `try/finally` block; let `__Delete()` delegate to `dispose()` as a safety net

- ✗ `__Get(name)` / `__Set(name, val)` two-parameter meta-function signatures from v1
- ✓ `__Get(name, params)` / `__Set(name, params, value)` — the `params` Array argument is required in v2 even if unused

- ✗ `this.ClassName.StaticMethod()` or `this.StaticProp` for class-level members
- ✓ `ClassName.StaticMethod()` / `ClassName.StaticProp` — static members belong to the class object, not instances

- ✗ `Map.Get(key, unset)` as a "safe optional return" — passing `unset` removes the default, making Get throw on absent keys
- ✓ `if map.Has(key) { return map[key] }` — use an explicit `.Has()` guard when the absent case should return unset

Safe-access priority order for class state Maps:
  1. `.Get(key, default)` — optional key, one-line resolution, never throws when default is a concrete value
  2. `.Has(key)` — when present/absent branches differ significantly in logic
  3. `.Default` — when the entire Map should share one universal fallback value
  4. `try/catch` — only when the exception itself carries diagnostic information needed at the call site

## TIER 1 — Class Fundamentals: Constructors, Properties, and Static Members
> METHODS COVERED: `__New` · `static` · property `get`/`set` · fat-arrow property · `.Bind()` · `SetTimer`

A class is a prototype-based blueprint: `class Name { }` at the top level, instantiated by calling `Name(args)` without `new`. Instance fields declared at class scope (outside any method) are per-instance defaults. Static fields declared with the `static` keyword are shared across all instances and accessed via `ClassName.Field`. AHK v2 properties use `get`/`set` accessor blocks inside a named property declaration; single-expression accessors may use the fat-arrow shorthand.
```ahk
; ✓ Basic class: declare fields at class scope, initialise in __New
class Animal {
    name := ""
    age  := 0

    __New(name, age) {
        this.name := name
        this.age  := age
    }

    speak() {
        MsgBox("Generic animal sound from " this.name)
    }

    getInfo() {
        return this.name " is " this.age " years old"
    }
}

; ✓ Static members belong to the class, not to any instance — access via ClassName.Prop
class MathUtils {
    static PI      := 3.14159
    static version := "1.0"

    static calculateArea(radius) {
        return MathUtils.PI * radius * radius
    }

    static getVersion() {
        return MathUtils.version
    }
}

; ✓ Instantiate without "new" — ClassName() is the only valid form in AHK v2
animal  := Animal("Buddy", 5)
area    := MathUtils.calculateArea(10)
version := MathUtils.getVersion()

; ✗ "new" keyword is not valid in AHK v2 — TypeError at runtime
; animal := new Animal("Buddy", 5)    ; → TypeError

; ✓ Properties with full get/set accessor blocks — setter enforces invariants at assignment time
class Person {
    _name := ""
    _age  := 0

    name {
        get {
            return this._name
        }
        set {
            if Type(value) != "String" || value = ""
                throw ValueError("Name must be a non-empty string")
            this._name := value
        }
    }

    ; ✓ Fat-arrow shorthand for simple get/set — single expression only, no block body
    age {
        get => this._age
        set => this._age := Max(0, Integer(value))
    }

    ; ✓ Fat-arrow read-only computed property
    displayName => this._name " (" this._age " years old)"

    ; ✓ Parameterised property — bracket key selects which sub-value to read/write
    phoneNumber[type] {
        get {
            return this.phoneNumbers.Get(type, "")
        }
        set {
            if !this.HasProp("phoneNumbers")
                this.phoneNumbers := Map()
            this.phoneNumbers[type] := value
        }
    }

    __New(name, age) {
        this.name := name    ; Calls the setter — validation runs here
        this.age  := age     ; Calls the setter — clamps negative values
    }
}

person := Person("John", 25)
person.phoneNumber["mobile"] := "555-1234"
displayText := person.displayName

; ✓ Timer callback with .Bind(this) — the critical pattern for any method used as a callback
class TooltipTimer {
    static Config := Map(
        "interval",    1000,
        "startDelay",  0,
        "initialText", "Timer started",
        "format",      "Time elapsed: {1} seconds"
    )

    __New() {
        this.state         := Map("seconds", 0, "isActive", true)
        this.timerCallback := this.UpdateDisplay.Bind(this)  ; .Bind(this) stores context — mandatory for all callbacks
        this.Start()
    }

    Start() {
        ToolTip(TooltipTimer.Config["initialText"])
        SetTimer(this.timerCallback, TooltipTimer.Config["interval"])
    }

    UpdateDisplay() {
        this.state["seconds"]++
        ToolTip(Format(TooltipTimer.Config["format"], this.state["seconds"]))
    }

    __Delete() {
        if this.state["isActive"] {
            SetTimer(this.timerCallback, 0)
            this.state["isActive"] := false
            ToolTip()
        }
    }
}

; ✗ Raw method reference without .Bind — "this" inside UpdateDisplay will be wrong
; SetTimer(this.UpdateDisplay, 1000)    ; → wrong "this" context, likely MethodError

timer := TooltipTimer()
```

## TIER 2 — Inheritance and Polymorphism
> METHODS COVERED: `extends` · `super.__New()` · `super.method()` · abstract method pattern

A derived class inherits all methods and properties of its base using `class Child extends Parent`. The derived `__New` must call `super.__New(args*)` explicitly — AHK v2 does not auto-chain constructors. `super.method()` dispatches to the base-class implementation from inside any override, not just the constructor. Declaring a method in the base that always throws creates an enforced abstract interface: any derived class that omits the implementation will receive a descriptive error at call time.
```ahk
; ✓ Base class defines shared state and a virtual method via explicit throw
class Vehicle {
    make  := ""
    model := ""
    year  := 0

    __New(make, model, year) {
        this.make  := make
        this.model := model
        this.year  := year
    }

    getDescription() {
        return this.year " " this.make " " this.model
    }

    start() {
        MsgBox("Starting " this.getDescription())
    }

    ; ✓ Abstract method pattern — force derived classes to implement by throwing in base
    getMaxSpeed() {
        throw Error("getMaxSpeed must be implemented by derived class")
    }
}

; ✓ Derived class: extends base, calls super.__New() to initialise shared fields
class Car extends Vehicle {
    doors    := 4
    fuelType := "gasoline"

    __New(make, model, year, doors, fuelType) {
        super.__New(make, model, year)  ; Initialises make/model/year from base — must come first
        this.doors    := doors
        this.fuelType := fuelType
    }

    ; ✓ Override calls super.start() first, then adds Car-specific behaviour
    start() {
        super.start()
        MsgBox("Car engine started")
    }

    getMaxSpeed() {
        return 120  ; mph
    }

    openTrunk() {
        MsgBox("Trunk opened")
    }
}

class Motorcycle extends Vehicle {
    hasSidecar := false

    __New(make, model, year, hasSidecar := false) {
        super.__New(make, model, year)
        this.hasSidecar := hasSidecar
    }

    start() {
        super.start()
        MsgBox("Motorcycle engine roared to life")
    }

    getMaxSpeed() {
        return 180  ; mph
    }

    wheelie() {
        MsgBox("Performing wheelie!")
    }
}

; ✓ Polymorphism: the for-loop calls start()/getMaxSpeed() on each concrete type
vehicles := [
    Car("Toyota", "Camry", 2023, 4, "hybrid"),
    Motorcycle("Harley", "Sportster", 2023, false)
]

for vehicle in vehicles {
    vehicle.start()
    speed := vehicle.getMaxSpeed()
    MsgBox(vehicle.getDescription() " - Max Speed: " speed " mph")
}

; ✗ super() is not a constructor call in AHK v2 — only super.__New(args*) is valid
; super()    ; → syntax error
```

## TIER 3 — Meta-Functions and Fluent Interfaces
> METHODS COVERED: `__Get` · `__Set` · `__Call` · `__Enum` · `__Item` · `.DefineProp()` · `.HasProp()` · `.Has()` · `.Get()` · `RegExMatch()`

Meta-functions intercept property/method access at the prototype level. `__Get(name, params)` fires on reads of undefined properties; `__Set(name, params, value)` fires on writes; `__Call(name, params)` fires on calls of undefined methods. `params` is an Array of bracket-notation parameters (e.g., `obj["a","b"]` passes `["a","b"]`). `__Enum(n)` is called by `for` loops — return an enumerator matching the loop variable count. `__Item` defines bracket-access with a parameterised property. The fluent-interface (method-chaining) pattern requires every builder method to `return this`.
```ahk
; ✓ Meta-functions intercept undefined access — always handle or throw a named error
class ConfigManager {
    _settings := Map()
    _defaults := Map("theme", "dark", "language", "en", "autoSave", true)

    __New() {
        for key, value in this._defaults
            this._settings[key] := value
    }

    ; ✓ __Get(name, params) — v2 requires params argument even if unused
    __Get(name, params) {
        if this._settings.Has(name)
            return this._settings[name]

        if name = "configCount"
            return this._settings.Count
        if name = "allKeys" {
            allKeys := []
            for k in this._settings
                allKeys.Push(k)
            return allKeys
        }

        throw PropertyError("Unknown configuration: " name)
    }

    ; ✓ __Set(name, params, value) — three-parameter v2 signature is mandatory
    __Set(name, params, value) {
        if !RegExMatch(name, "^[a-zA-Z][a-zA-Z0-9_]*$")
            throw ValueError("Invalid setting name: " name)

        this._settings[name] := value
        ; ✓ DefineProp descriptor uses object literal {value:} — correct: this is a property descriptor, not a data Map
        this.DefineProp(name, {value: value})
    }

    ; ✓ __Call(name, params) — params is an Array of call arguments
    __Call(name, params) {
        if RegExMatch(name, "^get(.+)$", &match) {
            settingName := StrLower(SubStr(match[1], 1, 1)) SubStr(match[1], 2)
            return this._settings.Get(settingName, "")
        }

        if RegExMatch(name, "^set(.+)$", &match) && params.Length = 1 {
            settingName := StrLower(SubStr(match[1], 1, 1)) SubStr(match[1], 2)
            this._settings[settingName] := params[1]
            return this
        }

        throw MethodError("Unknown method: " name)
    }

    ; ✓ __Enum enables for-in iteration — delegate to the Map's own enumerator
    __Enum(numberOfVars) {
        return this._settings.__Enum(numberOfVars)
    }

    ; ✓ __Item defines bracket-access: config["key"] dispatches get/set here
    __Item[key] {
        get => this._settings[key]
        set => this._settings[key] := value
    }
}

config := ConfigManager()
config.newSetting := "value"    ; __Set fires
value  := config.newSetting     ; __Get fires
config.setTheme("light")        ; __Call fires
theme  := config.getTheme()     ; __Call fires
config["debug"] := true         ; __Item set fires

for key, value in config
    MsgBox(key ": " value)

; ✗ v1 two-parameter meta-function signatures — interceptors silently never fire in v2
; __Get(name)         ; → wrong arity, AHK v2 skips this
; __Set(name, value)  ; → wrong arity, AHK v2 skips this

; ✓ Fluent interface: every builder method returns this, enabling dot-chained calls
class QueryBuilder {
    _table      := ""
    _columns    := []
    _conditions := []
    _orderBy    := []
    _limit      := 0

    from(table) {
        this._table := table
        return this
    }

    select(columns*) {
        for column in columns
            this._columns.Push(column)
        return this
    }

    where(condition) {
        this._conditions.Push(condition)
        return this
    }

    orderBy(column, direction := "ASC") {
        this._orderBy.Push(column " " direction)
        return this
    }

    limit(count) {
        this._limit := count
        return this
    }

    build() {
        if this._table = ""
            throw ValueError("Table name is required")

        query  := "SELECT "
        query .= this._columns.Length > 0 ?
            this._joinArray(this._columns, ", ") : "*"
        query .= " FROM " this._table

        if this._conditions.Length > 0
            query .= " WHERE " this._joinArray(this._conditions, " AND ")

        if this._orderBy.Length > 0
            query .= " ORDER BY " this._joinArray(this._orderBy, ", ")

        if this._limit > 0
            query .= " LIMIT " this._limit

        return query
    }

    _joinArray(array, separator) {
        result := ""
        for i, item in array {
            if i > 1
                result .= separator
            result .= item
        }
        return result
    }
}

; ✓ All builder methods return this — chain resolves left-to-right
query := QueryBuilder()
    .from("users")
    .select("id", "name", "email")
    .where("active = 1")
    .where("age >= 18")
    .orderBy("name")
    .limit(10)
    .build()

MsgBox(query)
```

## TIER 4 — Nested Classes and Factory Patterns
> METHODS COVERED: nested class access via `Outer.Inner()` · `static` factory methods · `Map()` for component specs · `.Push()` · `.Has()` · `switch`

Nested class declarations (`class Inner { }` inside `class Outer { }`) are accessed as `Outer.Inner()`. They do not capture any implicit reference to the outer class — all shared state must be reached through `Outer.StaticProp`. Factory methods are static methods that centralise object creation and apply shared configuration before returning instances. Component specification Maps should use `Map()` not object literals so `.Has()` checks remain reliable for optional keys.
```ahk
class UIComponentFactory {
    static theme := "default"

    static setTheme(newTheme) {
        UIComponentFactory.theme := newTheme
    }

    ; ✓ Nested class — accessed as UIComponentFactory.Button(), not Button()
    class Button {
        text   := ""
        x      := 0
        y      := 0
        width  := 100
        height := 30

        __New(text, x, y, width := 100, height := 30) {
            this.text   := text
            this.x      := x
            this.y      := y
            this.width  := width
            this.height := height
        }

        render(gui) {
            options := "x" this.x " y" this.y " w" this.width " h" this.height
            return gui.AddButton(options, this.text)
        }

        ; ✓ Access outer class config via ClassName.StaticProp — never via this
        getThemedColor() {
            switch UIComponentFactory.theme {
                case "dark":  return 0x333333
                case "light": return 0xFFFFFF
                default:      return 0xF0F0F0
            }
        }
    }

    class TextInput {
        placeholder := ""
        x           := 0
        y           := 0
        width       := 200
        height      := 25

        __New(placeholder, x, y, width := 200, height := 25) {
            this.placeholder := placeholder
            this.x           := x
            this.y           := y
            this.width       := width
            this.height      := height
        }

        render(gui) {
            options := "x" this.x " y" this.y " w" this.width " h" this.height
            return gui.AddEdit(options, this.placeholder)
        }
    }

    static createButton(text, x, y, width?, height?) {
        return UIComponentFactory.Button(text, x, y, width?, height?)
    }

    static createTextInput(placeholder, x, y, width?, height?) {
        return UIComponentFactory.TextInput(placeholder, x, y, width?, height?)
    }

    ; ✓ Factory reads component specs from Map — .Has() reliable for optional keys
    static createForm(components) {
        result := []
        for component in components {
            switch component["type"] {
                case "button":
                    w := component.Has("width")  ? component["width"]  : unset
                    h := component.Has("height") ? component["height"] : unset
                    result.Push(UIComponentFactory.createButton(
                        component["text"], component["x"], component["y"], w?, h?))
                case "input":
                    w := component.Has("width")  ? component["width"]  : unset
                    h := component.Has("height") ? component["height"] : unset
                    result.Push(UIComponentFactory.createTextInput(
                        component["placeholder"], component["x"], component["y"], w?, h?))
            }
        }
        return result
    }
}

UIComponentFactory.setTheme("dark")

; ✓ Component specs as Map() — .Has() remains reliable for optional width/height keys
formSpec := [
    Map("type", "input",  "placeholder", "Enter name",  "x", 10, "y", 10),
    Map("type", "input",  "placeholder", "Enter email", "x", 10, "y", 40),
    Map("type", "button", "text",        "Submit",      "x", 10, "y", 70, "width", 80)
]

components := UIComponentFactory.createForm(formSpec)

; ✗ Object literals as data containers — .Has() / .Delete() / .Clear() unavailable
; formSpec := [{type: "input", placeholder: "Enter name", x: 10, y: 10}]  ; → no .Has("width") possible
```

## TIER 5 — Resource Management and Lifecycle
> METHODS COVERED: `__Delete` · `dispose()` · `.HasMethod()` · `.HasProp()` · `Map.Clear()` · `FileDelete()` · `FileAppend()` · `A_Temp` · `A_TickCount`

`__Delete()` is the AHK v2 destructor, but its execution time is non-deterministic — the garbage collector may defer it or skip it on abnormal exit. The pattern is: implement a named `dispose()` method containing all cleanup logic, wrap every resource acquisition in `try/finally { resource.dispose() }`, and let `__Delete()` delegate to `dispose()` as a safety net. The `ResourceManager.use()` static utility encodes this discipline as a reusable RAII idiom.
```ahk
; ✓ Explicit dispose() + __Delete() delegation — deterministic cleanup on all code paths
class DatabaseConnection {
    _connectionString := ""
    _isConnected      := false
    _queryCache       := Map()
    _tempFiles        := []

    __New(connectionString) {
        this._connectionString := connectionString
        this.connect()
    }

    connect() {
        if this._isConnected
            return

        try {
            this._isConnected := true
            MsgBox("Connected to database")
        } catch as err {
            throw Error("Failed to connect: " err.Message)
        }
    }

    query(sql, params*) {
        if !this._isConnected
            throw Error("Not connected to database")

        cacheKey := sql
        if this._queryCache.Has(cacheKey)
            return this._queryCache[cacheKey]

        result := this._executeQuery(sql, params*)
        this._queryCache[cacheKey] := result
        return result
    }

    _executeQuery(sql, params*) {
        return ["result1", "result2", "result3"]
    }

    createTempFile() {
        tempFile := A_Temp "\db_temp_" A_TickCount ".tmp"
        FileAppend("temp data", tempFile)
        this._tempFiles.Push(tempFile)
        return tempFile
    }

    ; ✓ dispose() is explicit and idempotent — safe to call multiple times
    dispose() {
        if !this._isConnected
            return

        this._queryCache.Clear()

        for tempFile in this._tempFiles {
            try {
                FileDelete(tempFile)
            } catch {
                ; Continue cleanup even if individual file deletion fails
            }
        }
        this._tempFiles   := []
        this._isConnected := false
        MsgBox("Database connection closed")
    }

    ; ✓ __Delete delegates to dispose() — GC safety net, not the primary cleanup path
    __Delete() {
        this.dispose()
    }
}

; ✓ RAII helper — callback receives resource; finally block always calls dispose()
class ResourceManager {
    static use(resource, callback) {
        try {
            return callback(resource)
        } finally {
            if resource.HasMethod("dispose")
                resource.dispose()
        }
    }
}

; ✓ Explicit try/finally — dispose() runs even if query throws
db := DatabaseConnection("server=localhost;database=test")
try {
    results  := db.query("SELECT * FROM users")
    tempFile := db.createTempFile()
} finally {
    db.dispose()
}

; ✓ RAII usage — named function replaces block-body fat-arrow (invalid in AHK v2)
_runDbQuery(db) {
    return db.query("SELECT * FROM users")
}
ResourceManager.use(DatabaseConnection("server=localhost;database=test"), _runDbQuery)

; ✗ Multi-line fat-arrow body is invalid AHK v2 syntax
; ResourceManager.use(conn, (db) => {    ; → syntax error — block body not valid after =>
;     results := db.query("SELECT * FROM users")
;     return results
; })
```

### Performance Notes

**Object pooling** eliminates repeated allocation for frequently created short-lived objects. The `ObjectPool` class maintains per-type queues (`_pools` Map keyed by `.__Class`). `acquire()` pops from the pool or creates a new instance with `%className%(params*)` (dynamic class call by name string). `release()` calls `cleanup()` if it exists, then pushes back. Pool objects must implement `reset(params*)` and `cleanup()` rather than relying on `__New`/`__Delete`, to avoid lifecycle interference with the pool.

**Lazy initialisation** defers expensive computation until first access. A property getter checks an `_initialized` flag and caches the result — subsequent reads return the cached value in O(1). An `invalidate()` method clears the flag to force recomputation. This is strictly better than computing in `__New` when the property may never be accessed.

**Copy-on-write** defers array copying until a mutation occurs. `clone()` returns a new instance sharing the same `_data` Array reference and sets `_isShared := true` on both. The first write on either copy calls `_ensureUnique()` which calls `.Clone()` (O(n) once), then clears the flag — reads are always O(1); subsequent writes are O(1).

**General class performance rules:**
- Prefer `Map` over nested object literals for class state — Map lookup is O(1) and `.Has()` is reliable.
- Cache `.Bind(this)` results as instance fields in `__New` rather than re-binding on every event fire.
- Avoid calling `DefineProp()` repeatedly inside hot loops — it modifies the prototype on every call.
- Static Maps and lookup tables should be initialised once at class scope, not reconstructed per-instance.
```ahk
; ✓ Object pooling — acquire/release instead of repeated ClassName() construction
class ObjectPool {
    static _pools := Map()

    static getPool(className) {
        if !ObjectPool._pools.Has(className)
            ObjectPool._pools[className] := []
        return ObjectPool._pools[className]
    }

    static acquire(className, initParams*) {
        pool := ObjectPool.getPool(className)
        if pool.Length > 0 {
            obj := pool.Pop()
            if obj.HasMethod("reset")
                obj.reset(initParams*)
            return obj
        }
        return %className%(initParams*)  ; Dynamic class instantiation by name
    }

    static release(obj) {
        className := obj.__Class
        pool      := ObjectPool.getPool(className)

        if obj.HasMethod("cleanup")
            obj.cleanup()

        pool.Push(obj)
    }
}

class PooledWorker {
    data     := unset
    isActive := false

    __New() {
        ; Minimal — pool manages lifecycle via reset()/cleanup()
    }

    reset(newData) {
        this.data     := newData
        this.isActive := true
    }

    process() {
        if !this.isActive
            throw Error("Worker not active")
        return "Processed: " this.data
    }

    cleanup() {
        this.data     := unset
        this.isActive := false
    }
}

; ✓ Lazy initialisation — expensive computation deferred to first access, then cached
class ExpensiveResource {
    _initialized := false
    _cache       := unset

    expensiveData {
        get {
            if !this._initialized {
                this._cache       := this._computeExpensiveData()
                this._initialized := true
            }
            return this._cache
        }
    }

    _computeExpensiveData() {
        Sleep(100)
        return "Expensive computed result"
    }

    invalidate() {
        this._initialized := false
        this._cache       := unset
    }
}

; ✓ Copy-on-write — clones backing array only when a mutation occurs
class CopyOnWriteArray {
    _data     := []
    _isShared := false

    __New(initialData := []) {
        this._data := initialData
    }

    clone() {
        newInstance           := CopyOnWriteArray()
        newInstance._data     := this._data
        newInstance._isShared := true
        this._isShared        := true
        return newInstance
    }

    get(index) {
        return this._data[index]
    }

    set(index, value) {
        this._ensureUnique()
        this._data[index] := value
    }

    push(value) {
        this._ensureUnique()
        this._data.Push(value)
    }

    _ensureUnique() {
        if this._isShared {
            this._data    := this._data.Clone()  ; O(n) copy happens only once per modification
            this._isShared := false
        }
    }

    length => this._data.Length
}

; Usage
worker := ObjectPool.acquire("PooledWorker", "some data")
result := worker.process()
ObjectPool.release(worker)

resource := ExpensiveResource()
data     := resource.expensiveData    ; Computed once; cached on all subsequent reads

array1 := CopyOnWriteArray()
array2 := array1.clone()              ; Shares backing array — O(1)
array2.push(4)                        ; Triggers copy — array1 unchanged
```

## TIER 6 — Observer Pattern and Weak References
> METHODS COVERED: `ObjPtr()` · `ObjFromPtrAddRef()` · `.Clone()` · `.Clear()` · `.Delete()` · `RemoveAt()` · `IsSet()` · `OutputDebug()`

Circular references prevent garbage collection: if Model holds a strong reference to View and View holds a strong reference to Model, neither is freed when both go out of scope. The weak-reference pattern stores `ObjPtr(target)` (an integer, not a reference) instead of the object itself. On each `emit()`, call `ObjFromPtrAddRef(ptr)` inside `try/catch` to test liveness — if the object was collected, the call throws and the dead listener is removed. This allows the emitter to outlive its subscribers without leaking them.
```ahk
; ✓ EventEmitter with weak-reference subscriber tracking — prevents circular reference leaks
class EventEmitter {
    _listeners := Map()
    _weakRefs  := Map()

    ; ✓ Pass target object to store weak reference — emitter does not own the subscriber
    on(event, callback, target := unset) {
        if !this._listeners.Has(event)
            this._listeners[event] := []

        listener := {callback: callback}

        if IsSet(target) {
            listener.targetPtr := ObjPtr(target)   ; Integer pointer — not a reference; does not prevent GC
            listener.weakRef   := true

            if !this._weakRefs.Has(listener.targetPtr)
                this._weakRefs[listener.targetPtr] := []
            this._weakRefs[listener.targetPtr].Push(listener)
        }

        this._listeners[event].Push(listener)
        return this
    }

    off(event, callback := unset) {
        if !this._listeners.Has(event)
            return this

        listeners := this._listeners[event]
        if !IsSet(callback) {
            for listener in listeners
                this._cleanupWeakRef(listener)
            this._listeners[event] := []
        } else {
            for i, listener in listeners {
                if listener.callback = callback {
                    this._cleanupWeakRef(listener)
                    listeners.RemoveAt(i)
                    break
                }
            }
        }
        return this
    }

    ; ✓ Clone listener list before iterating — allows safe removal of dead entries during emit
    emit(event, args*) {
        if !this._listeners.Has(event)
            return this

        listeners := this._listeners[event].Clone()

        for i, listener in listeners {
            if listener.HasProp("weakRef") {
                try {
                    ObjFromPtrAddRef(listener.targetPtr)
                } catch {
                    this._removeDeadListener(event, listener)
                    continue
                }
            }

            try {
                listener.callback(args*)
            } catch as err {
                OutputDebug("Event listener error: " err.Message)
            }
        }
        return this
    }

    _cleanupWeakRef(listener) {
        if !listener.HasProp("weakRef")
            return

        if this._weakRefs.Has(listener.targetPtr) {
            refs := this._weakRefs[listener.targetPtr]
            for i, ref in refs {
                if ref = listener {
                    refs.RemoveAt(i)
                    break
                }
            }
            if refs.Length = 0
                this._weakRefs.Delete(listener.targetPtr)
        }
    }

    _removeDeadListener(event, deadListener) {
        if !this._listeners.Has(event)
            return

        listeners := this._listeners[event]
        for i, listener in listeners {
            if listener = deadListener {
                listeners.RemoveAt(i)
                this._cleanupWeakRef(listener)
                break
            }
        }
    }

    __Delete() {
        for event, listeners in this._listeners {
            for listener in listeners
                this._cleanupWeakRef(listener)
        }
        this._listeners.Clear()
        this._weakRefs.Clear()
    }
}

; ✓ Model extends EventEmitter — broadcasts changes to all registered subscribers
class Model extends EventEmitter {
    _data := Map()

    set(key, value) {
        oldValue := this._data.Has(key) ? this._data[key] : unset
        this._data[key] := value
        this.emit("change", {key: key, value: value, oldValue: oldValue})
    }

    ; ✓ Has() guard before access — returns unset cleanly when key is absent
    get(key) {
        if this._data.Has(key)
            return this._data[key]
        ; Implicit: returns unset (no value) if key is absent
    }
}

; ✓ View registers with weak reference — Model does not hold a strong ref back to View
class View {
    model := unset

    __New(model) {
        this.model := model
        this.model.on("change", this.onModelChange.Bind(this), this)
        ; ✓ Passing "this" as third arg stores ObjPtr(this) — not a strong reference; GC can still collect View
    }

    onModelChange(data) {
        MsgBox("View updated: " data.key " = " data.value)
    }

    __Delete() {
        MsgBox("View destroyed")
    }
}

; No memory leak: when view is unset, the weak reference allows GC to collect it
model := Model()
view  := View(model)
model.set("name", "John")   ; View receives change notification
view  := unset              ; View is GC'd; emitter cleans up dead listener on next emit

; ✗ Omitting the target arg stores no weak reference — strong ref creates circular ref
; this.model.on("change", this.onModelChange.Bind(this))  ; → strong ref → circular ref → neither frees
```

## ANTI-PATTERNS

| Pattern | Wrong | Correct | LLM Common Cause |
|---------|-------|---------|------------------|
| Class instantiation with `new` | `obj := new ClassName()` | `obj := ClassName()` | AHK v1 and almost all OOP language training data use `new` |
| Object literal as data container | `state := {x: 0, y: 0}` | `state := Map("x", 0, "y", 0)` | AHK v1 training data — object literals were the only container pre-v2 |
| Raw method reference as callback | `SetTimer(this.Update, 1000)` | `SetTimer(this.Update.Bind(this), 1000)` | Global-function paradigm habit — free functions do not need context binding |
| `super()` as constructor call | `super(args*)` in `__New` | `super.__New(args*)` | Python/Java training data where `super().__init__()` is idiomatic |
| Static access via `this` | `this.StaticProp := val` | `ClassName.StaticProp := val` | Python (`cls.prop`) / Java (`this.field` for both) training data conflation |
| Multi-line fat-arrow callback | `(x) => { return x * 2 }` | Named top-level function | JavaScript training data — JS allows block bodies after `=>`; AHK v2 requires single expression |
| `Map.Get(key, unset)` as safe optional return | `return map.Get(k, unset)` | `if map.Has(k) { return map[k] }` | Mistaken belief that `unset` is a valid default sentinel — it removes the default argument instead |

## SEE ALSO

> This module does NOT cover: prototype chain manipulation, `ObjSetBase()`, raw prototype property injection → see Module_ClassPrototyping.md
> This module does NOT cover: GUI control subclassing, `Gui()` constructor patterns, control event binding specifics → see Module_GUI.md
> This module does NOT cover: custom exception class design, `Error` subclassing for domain errors → see Module_Errors.md

- `Module_ClassPrototyping.md` — direct prototype manipulation with `ObjSetBase()`, `__mro`, and runtime class graph surgery beyond what `extends` provides.
- `Module_Objects.md` — raw object creation with `{}`, property enumeration, `OwnProps()`, and the distinction between own properties and inherited prototype properties.
- `Module_GUI.md` — connecting class methods to GUI events, `Gui.AddButton().OnEvent()`, and managing GUI lifetimes inside class destructors.
- `Module_Errors.md` — defining custom exception hierarchies by subclassing `Error`, `ValueError`, `TypeError`, and structuring `try/catch/finally` inside class methods.
- `Module_Arrays.md` — Array methods (`.Push()`, `.Pop()`, `.RemoveAt()`, `.Clone()`) used extensively inside class state containers.
