# Module_ClassPrototyping.md
<!-- DOMAIN: Class Prototyping -->
<!-- SCOPE: Static class definitions using the `class` keyword, standard inheritance via `extends`, and __Item / __Enum meta-function patterns are not covered — see Module_Classes.md and Module_Objects.md. -->
<!-- TRIGGERS: DefineProp, ObjSetBase, HasProp, HasMethod, "property descriptor", "descriptor object", "dynamic getter", "readonly property", "intercept property assignment", "change method at runtime", "add property to instance", "runtime class generation", "method decorator", "class generator", "prototyping" -->
<!-- CONSTRAINTS: Prefer creating descriptor objects with Object() over {}; while both produce an Object instance of the same type and both are accepted by DefineProp, Object() is the explicit, unambiguous convention for descriptor containers in this module series. Every Get/Set/Call descriptor function must accept the object instance as its first parameter — omitting it causes the function to receive shifted arguments with no runtime error. -->
<!-- CROSS-REF: Module_Classes.md, Module_Objects.md, Module_Errors.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `new ClassName()` | `ClassName()` | `new` keyword does not exist in AHK v2 — immediate parse error |
| `{Get: MyFunc}` as descriptor literal | `d := Object()` then `d.Get := MyFunc` | Object literal descriptors are technically accepted by DefineProp, but Object() is the explicit convention in this module for descriptor construction |
| `Class(BaseObj)` (v2.1-alpha) | Manual prototype chain via `ObjSetBase()` | v2.0 `Class()` produces an incomplete object with no `Call` method and is not a subclass of Object — unusable as a class factory in stable releases |
| Getter/Setter function with no leading parameter | `GetterFunc(Obj)` / `SetterFunc(Obj, Val)` | AHK v2 always injects the object instance as the first argument — omitting it silently shifts all arguments, causing wrong values or property-not-found errors |
| `(this) => { x := 1 \| return x }` multi-line fat-arrow | Named function block `MyFunc(this) { ... }` | AHK v2 fat-arrow functions are single-expression only — multi-line body is a syntax error |
| Modifying `Array.Prototype` or `String.Prototype` directly | Wrapper object or subclass with `extends` | Pollutes the global namespace; affects every Array/String in the script silently |

## API QUICK-REFERENCE

### Object — Descriptor Construction and Prototype Manipulation
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `Object()` | `Object()` | Creates a plain Object instance with no initial own properties — the preferred form for descriptor containers; `{}` creates an Object instance of the same type but Object() makes the descriptor role explicit |
| `.DefineProp()` | `obj.DefineProp(Name, Descriptor)` | Assigns a property descriptor to `obj`; Descriptor must be an Object with `.Get`, `.Set`, `.Call`, or `.Value` |
| `.HasProp()` | `obj.HasProp(Name)` | Returns true if the named property exists on `obj` or its prototype chain; does not invoke the getter |
| `.HasMethod()` | `obj.HasMethod(Name)` | Returns true if the named Call descriptor is resolvable on `obj` or its prototype chain |
| `ObjSetBase()` | `ObjSetBase(obj, BaseObj)` | Sets `obj`'s prototype to `BaseObj`; used to link instances to a dynamically constructed class prototype |

### Descriptor Object Keys
| Key | Expected value | Notes |
|-----|----------------|-------|
| `.Get` | `GetFunc(Obj)` | Called when the property is read; first param is always the target object |
| `.Set` | `SetFunc(Obj, Value)` | Called when the property is assigned; second param is the assigned value |
| `.Call` | `CallFunc(Obj, Args*)` | Called when the property is invoked as a method; first param is always the target object |
| `.Value` | Any AHK value | Simple static value — no function is executed; cannot coexist with `.Get`/`.Set` on the same descriptor |

### Func — Binding for Static Call Descriptors
| Method/Property | Signature | Notes |
|----------------|-----------|-------|
| `.Bind()` | `FuncRef.Bind(BoundArgs*)` | Returns a new BoundFunc with leading parameters pre-filled; use to attach a static function as a Call descriptor while passing context through a bound prefix argument |

### Type Inspection
| Function | Signature | Notes |
|----------|-----------|-------|
| `Type()` | `Type(Value)` | Returns a string: `"Integer"`, `"String"`, `"Float"`, `"Object"`, `"Array"`, `"Map"`, etc.; use for type guards inside Set descriptors |
| `IsObject()` | `IsObject(Value)` | Returns true for any object reference — preliminary guard before calling `.DefineProp()` |

## AHK V2 CONSTRAINTS

- **Prefer `Object()` for descriptor objects over `{}`** — although both produce an Object instance of the same type and both are accepted by DefineProp, `Object()` is the explicit convention in this module to keep descriptor construction unambiguous and separated from general object literal usage.
- **Every Get descriptor function must have exactly one parameter: the object instance** — `GetterFunc(Obj)`. AHK v2 injects the target object as the first argument unconditionally; a zero-parameter getter will receive the object and discard it, returning unpredictable results.
- **Every Set descriptor function must have exactly two parameters: the object instance and the assigned value** — `SetterFunc(Obj, Value)`. Omitting `Obj` shifts `Value` into the wrong slot.
- **Every Call descriptor function must accept the object instance as its first parameter** — `MethodFunc(Obj, Args*)`. The invocation `myObj.Prop(x)` internally becomes `Desc.Call(myObj, x)`.
- **Do not use `Class(BaseObj)` in v2.0 scripts** — it is a v2.1-alpha feature; the resulting object lacks a `.Call` method and cannot act as a class factory. Use manual prototype chain construction with `ObjSetBase()` instead.
- **Do not modify built-in prototypes (`Array.Prototype`, `Map.Prototype`, etc.) unless explicitly required** — changes propagate globally to every instance of that type in the script, creating invisible coupling and name collision risk.
- **Fat-arrow functions assigned to descriptors must be single-expression** — `(Obj) => Obj.Name` is valid; `(Obj) => { x := 1 \| return x }` is a syntax error. Use a named function block for any multi-statement descriptor logic.

Safe-access priority order for prototype manipulation:
  1. `.HasProp(Name)` — check existence before reading or redefining; avoids UnsetError on absent properties
  2. `.HasMethod(Name)` — call-specific guard; confirms a Call descriptor is present before invoking
  3. `IsObject(Target)` — preliminary guard before calling any Object method; prevents MethodError on non-objects
  4. `try/catch` — only when the DefineProp call itself may fail and the exception message carries diagnostic information

Pair of every prohibition with its consequence and positive alternative:
- ✗ `desc := {Get: MyFunc}` — object literal descriptors are avoided in this module; Object() is the explicit convention for descriptor containers
- ✓ `desc := Object()` then `desc.Get := MyFunc` — Object() is the preferred descriptor container in this module series
- ✗ `GetterFunc()` with no parameters — object instance silently discarded; returns wrong value
- ✓ `GetterFunc(Obj)` — receives the target object as first argument
- ✗ `(Obj) => { x := 1 \| return x }` — syntax error; multi-line fat-arrow is not valid in AHK v2
- ✓ Named function block `MyFunc(Obj) { x := 1 \| return x }` — full function body supported

## TIER 1 — Descriptor Object Fundamentals: Dynamic Call Assignment
> METHODS COVERED: Object() · DefineProp() · .Call (descriptor key)

A Call descriptor turns any function into a method on a specific object instance. The descriptor must be a raw `Object()` — not an object literal — and the function it holds must accept the target object as its first parameter. This tier covers the minimal DefineProp pattern: create descriptor, assign function, attach to instance.
```ahk
CustomMethod(Obj, Prefix) {
    return Prefix . ": " . Obj.Name
}

; Create the object
MyObj := Object()
MyObj.Name := "Alpha"

; ✓ Object() produces a plain Object instance — the preferred form for descriptor containers
PropDesc := Object()
PropDesc.Call := CustomMethod

; ✓ DefineProp attaches the descriptor; MyObj.Greet now resolves as a callable method
MyObj.DefineProp("Greet", PropDesc)

; ✓ Implicitly calls CustomMethod(MyObj, "Status") — AHK injects MyObj as first argument
Result := MyObj.Greet("Status")

; ✗ Avoid {} as the descriptor object in this module — use Object() for explicit descriptor construction
; PropDesc := {Call: CustomMethod}    ; → avoided by convention; Object() is preferred
```

## TIER 2 — Dynamic Getters and Setters: Computed and Validated Properties
> METHODS COVERED: Object() · DefineProp() · .Get (descriptor key) · .Set (descriptor key) · Type()

Get descriptors execute when a property is read; Set descriptors execute on assignment. Together they create computed, validated, or read-only property behaviour without storing the logic-driven value directly on the object. Both functions must accept the object instance as their first parameter.
```ahk
GetterFunc(Obj) {
    return Obj._HiddenValue * 2
}

SetterFunc(Obj, AssignedValue) {
    ; ✓ Type() returns a string — != is the correct AHK v2 not-equal operator
    if (Type(AssignedValue) != "Integer") {
        throw TypeError("Only integers allowed.")
    }
    Obj._HiddenValue := AssignedValue
}

MyData := Object()
MyData._HiddenValue := 10

; ✓ Separate descriptor keys for Get and Set on the same property
PropDesc := Object()
PropDesc.Get := GetterFunc
PropDesc.Set := SetterFunc

MyData.DefineProp("Doubled", PropDesc)

; ✓ Triggers GetterFunc(MyData) — returns _HiddenValue * 2
CurrentVal := MyData.Doubled

; ✓ Triggers SetterFunc(MyData, 50) — validates then stores in _HiddenValue
MyData.Doubled := 50

; ✗ Assigning a non-integer raises TypeError via SetterFunc — expected behaviour
; MyData.Doubled := "String"          ; → TypeError("Only integers allowed.")

; ✗ Omitting the Obj parameter shifts AssignedValue into the wrong slot
; SetterFunc(AssignedValue) { ... }   ; → AssignedValue receives the object instance silently
```

## TIER 3 — Existence Guards: Safe Property and Method Validation
> METHODS COVERED: HasProp() · HasMethod() · IsObject() · DefineProp() · Object()

Before mutating a prototype or redefining a property, always validate that the target is an object and that the property does not already exist. `HasProp` and `HasMethod` prevent destructive overwrites; `IsObject` prevents MethodError when the target arrives from an untyped source.
```ahk
SafeDefineMethod(TargetObj, MethodName, FuncRef) {
    ; ✓ IsObject() guards against non-object inputs before any property access
    if !IsObject(TargetObj) {
        throw TypeError("Target must be an object.")
    }

    ; ✓ HasMethod() checks for an existing Call descriptor before overwriting
    if TargetObj.HasMethod(MethodName) {
        return false
    }

    Desc := Object()
    Desc.Call := FuncRef
    TargetObj.DefineProp(MethodName, Desc)
    return true
}

SayHello(Obj) {
    return "Hello"
}

TestObj := Object()
; ✓ Returns true and defines "Speak" — method was absent
Success := SafeDefineMethod(TestObj, "Speak", SayHello)

; ✓ Returns false without overwriting — method is now present
Success2 := SafeDefineMethod(TestObj, "Speak", SayHello)

; ✗ Calling DefineProp without HasMethod guard silently overwrites existing methods
; TargetObj.DefineProp(MethodName, Desc)  ; → destroys existing Call descriptor with no warning
```

## TIER 4 — Closure Factories: Context-Aware Properties Without State Pollution
> METHODS COVERED: Object() · DefineProp() · .Get (descriptor key)

Closures let a descriptor function capture outer variables at definition time, keeping captured state isolated from the object instance. The factory function returns an inner function that closes over the factory's parameters. This tier demonstrates injecting read-only context (such as a version string) into a property without storing it as a visible field on the object.
```ahk
; ✓ Factory returns a closure — the inner function captures ReturnValue at call time
CreateConstantGetter(ReturnValue) {
    return ConstantGetter

    ; ✓ Inner function closes over ReturnValue; Obj is the mandatory first param
    ConstantGetter(Obj) {
        return ReturnValue
    }
}

ApplyVersion(TargetObj, VersionStr) {
    Desc := Object()
    ; ✓ Desc.Get holds the closure — each call to ApplyVersion captures its own VersionStr
    Desc.Get := CreateConstantGetter(VersionStr)
    TargetObj.DefineProp("Version", Desc)
}

AppObj := Object()
ApplyVersion(AppObj, "1.0.4")

; ✓ Triggers ConstantGetter(AppObj) — returns "1.0.4" without AppObj._Version existing
CurrentVer := AppObj.Version

; ✗ Storing state directly on the instance leaks implementation details to callers
; AppObj._Version := "1.0.4"          ; → caller can read and modify _Version directly
```

## TIER 5 — Method Decorators: Non-Destructive Interception and Augmentation
> METHODS COVERED: HasProp() · DefineProp() · Object() · .Call (descriptor key) · .Bind()

Decorators wrap an existing function in a new closure that injects pre- or post-execution logic (logging, timing, access control) without touching the original function's source. The decorator returns a new function that calls the original internally, preserving its semantics while extending its behaviour.
```ahk
WithCallCounter(OriginalMethod) {
    return LoggedMethod

    ; ✓ LoggedMethod captures OriginalMethod from the outer scope via closure
    LoggedMethod(Obj, Args*) {
        ; ✓ HasProp() guard prevents overwriting an existing counter
        if !Obj.HasProp("CallCount") {
            Obj.CallCount := 0
        }

        ; Side-effect: increment counter on every invocation
        Obj.CallCount++

        ; ✓ Forwards all arguments to OriginalMethod — decorator is fully transparent
        return OriginalMethod(Obj, Args*)
    }
}

BaseAction(Obj, Val) {
    return Val * 10
}

Worker := Object()
Desc := Object()
; ✓ Wraps BaseAction — Worker.Process now counts calls without modifying BaseAction
Desc.Call := WithCallCounter(BaseAction)
Worker.DefineProp("Process", Desc)

Worker.Process(5)
Worker.Process(10)
; ✓ Worker.CallCount is now 2

; ✗ Modifying BaseAction directly to add logging destroys the original implementation
; BaseAction(Obj, Val) { Obj.CallCount++ \| return Val * 10 }  ; → not reversible, mixes concerns
```

### Performance Notes

`DefineProp` carries a one-time overhead at the moment of assignment — not per access. Once attached, property lookup through a descriptor follows the normal prototype chain with no additional cost beyond the function call itself.

**Closure memory cost:** Every closure object allocates a separate activation record capturing its outer variables. Creating a new closure inside a per-instance factory (e.g., inside a loop over thousands of objects) multiplies this allocation. Prefer defining the function statically and binding context via `.Bind()` instead.
```ahk
; ✗ New closure per instance — high memory footprint when called thousands of times
AttachSlowMethod(Obj, Prefix) {
    Desc := Object()
    ; Each call to AttachSlowMethod allocates a new anonymous function object
    Desc.Call := (this) => Prefix . this.Name
    Obj.DefineProp("Read", Desc)
}

; ✓ Static function + Bind — one function object shared; only the BoundFunc is allocated per instance
StaticReader(Prefix, this) {
    return Prefix . this.Name
}

AttachFastMethod(Obj, Prefix) {
    Desc := Object()
    ; ✓ Bind(Prefix) produces a lightweight BoundFunc; StaticReader itself is allocated once
    Desc.Call := StaticReader.Bind(Prefix)
    Obj.DefineProp("Read", Desc)
}
```

**Prototype chain depth:** Each property lookup walks the prototype chain from instance to base. Dynamically constructed chains that are 4+ levels deep degrade lookup to O(N) where N is chain depth. Keep runtime-generated hierarchies shallow; prefer composition (attaching methods to a single prototype) over deep inheritance.

**Built-in method preference:** AHK v2's native `HasProp` and `HasMethod` are implemented in native code and are faster than any custom existence-check loop. Always prefer them over manual property enumeration.

## TIER 6 — Runtime Class Generation: v2.0-Compatible Dynamic Class Factory
> METHODS COVERED: Object() · ObjSetBase() · DefineProp() · HasMethod() · .Call (descriptor key)

Because `Class()` in AHK v2.0 produces an incomplete object with no `Call` method and is not a subclass of Object, a fully functional dynamic class requires manual prototype chain construction. A plain `Object()` acts as the class object; a separate `Object()` acts as its prototype. A custom `Call` descriptor on the class object handles instantiation — replicating the behaviour AHK normally performs when a compiled class is invoked.
```ahk
; ✓ v2.0-compatible runtime class factory — no alpha features required
CreateDynamicClass(ClassName) {
    DynamicClass := Object()
    DynamicClass.Prototype := Object()
    DynamicClass.Prototype.__Class := ClassName

    ; ✓ Call descriptor makes DynamicClass() callable as a constructor
    ConstructorDesc := Object()
    ConstructorDesc.Call := DynamicClass_Call
    DynamicClass.DefineProp("Call", ConstructorDesc)

    return DynamicClass
}

; ✓ Replicates AHK's standard instance creation workflow
DynamicClass_Call(Cls, Args*) {
    Instance := Object()
    ; ✓ ObjSetBase links the instance to the class prototype — enables method lookup
    ObjSetBase(Instance, Cls.Prototype)

    ; ✓ HasMethod() guards — only call if defined; avoids MethodError on bare instances
    if Instance.HasMethod("__Init") {
        Instance.__Init()
    }
    if Instance.HasMethod("__New") {
        Instance.__New(Args*)
    }
    return Instance
}

; Usage: create a new type at runtime
MyDynamicType := CreateDynamicClass("RuntimeEntity")

; ✓ Attach a method to the shared prototype — all instances inherit it
MethodDesc := Object()
MethodDesc.Call := (this) => "I am a " . this.__Class
MyDynamicType.Prototype.DefineProp("Identify", MethodDesc)

; ✓ Instantiate via the Call descriptor — no 'new' keyword
EntityInst := MyDynamicType()
EntityClass := EntityInst.__Class   ; "RuntimeEntity"
EntityId    := EntityInst.Identify() ; "I am a RuntimeEntity"

; ✗ Class(BaseObj) is a v2.1-alpha feature — produces unusable object in v2.0 stable
; DynamicClass := Class(BaseObj)      ; → no .Call method; cannot be invoked as constructor

; ✗ 'new' keyword does not exist in AHK v2
; EntityInst := new MyDynamicType()   ; → parse error
```

## ANTI-PATTERNS

| Pattern | Wrong | Correct | LLM Common Cause |
|---------|-------|---------|------------------|
| Object literal as descriptor | `DefineProp("X", {Get: MyFunc})` | `d := Object()` then `d.Get := MyFunc` then `DefineProp("X", d)` | AHK v1 and general OOP training data treat `{}` as universal object constructor; this module mandates Object() for descriptor clarity, even though both are accepted by DefineProp in AHK v2 |
| Missing `this` parameter in descriptor function | `GetterFunc()` with no params | `GetterFunc(Obj)` where `Obj` is the injected instance | Cross-language habit — Python/JS descriptors often use implicit self/this binding; AHK v2 passes it explicitly as first arg |
| Using `Class(BaseObj)` in stable scripts | `DynamicClass := Class(BaseObj)` | Manual prototype chain with `ObjSetBase()` | LLM training data includes v2.1-alpha documentation; model cannot distinguish alpha from stable features |
| Multi-line fat-arrow in descriptor | `(Obj) => { x := 1 \| return x }` | Named function block `MyFunc(Obj) { x := 1 \| return x }` | JavaScript and Python both support multi-line lambda/arrow bodies; AHK v2 fat-arrow is single-expression only |
| Overusing DefineProp where `extends` suffices | Copying methods via DefineProp loop to share behaviour | `class Child extends Parent { }` | LLM pattern-matches "runtime flexibility" to metaprogramming even when static inheritance is simpler and faster |
| Using `new` keyword | `new ClassName()` | `ClassName()` | AHK v1 required `new`; dominant OOP training data (Java, C#, JS) reinforces the keyword |
| Modifying built-in prototypes | `Array.Prototype.DefineProp("Sum", d)` | Wrapper class or standalone function | LLM training data includes JavaScript prototype extension patterns; AHK v2 built-in pollution is global and irreversible |

## SEE ALSO

> This module does NOT cover: static `class` definitions, `extends` inheritance, or `__Item` / `__Enum` meta-function patterns → see Module_Classes.md
> This module does NOT cover: base Object API, prototype chain inspection, or ObjGetBase() traversal → see Module_Objects.md
> This module does NOT cover: try/catch patterns for DefineProp failures, TypeError construction, or custom error hierarchies → see Module_Errors.md

- `Module_Classes.md` — static class definitions, `extends` inheritance, meta-functions (`__New`, `__Delete`, `__Get`, `__Set`), and `super` dispatch.
- `Module_Objects.md` — base Object API (`ObjGetBase`, `ObjSetBase`, `ObjOwnProps`), prototype chain traversal, and raw object construction patterns.
- `Module_Errors.md` — try/catch patterns for runtime DefineProp failures, TypeError and ValueError construction, and custom exception class hierarchies.