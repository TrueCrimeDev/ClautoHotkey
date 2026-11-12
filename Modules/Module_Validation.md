---
name: Module_Validation
description: >
  Defensive parameter validation for AHK v2 — guard clauses at the top of a function, TypeError vs
  ValueError, optional-parameter (IsSet) handling, constructor guards, duck-type capability probes with
  HasMethod / HasProp, environment pre-flight checks, cost-ordered guard stacks, and a collect-all
  fluent validator for form input. Targets v2.1-alpha.33+Console and prefers the fork built-ins
  (JSON.Validate, Check) over hand-rolled equivalents.
  TRIGGER when the request involves: validate, validation, guard clause, "type check", "fail early",
  precondition, "defensive programming", "input validation", sanitize, TypeError, ValueError,
  "is Integer", "is Number", IsSet, "unset parameter", "optional parameter", HasMethod, HasProp,
  "duck typing", "interface check", "constructor guard", "__New validation", "pre-flight check",
  "fluent validator", "form validation", "validate JSON", "validate email", "validate filename".
  Not covered: custom error class hierarchies, try/catch/finally structure and OnError — see
  Module_Errors.md; validator base classes, inheritance and prototype sharing — see Module_Classes.md;
  core syntax rules — see Module_Instructions.md.
---

# Module_Validation

Guard clauses for public and external API boundaries. The goal is that bad input fails at the
boundary with an error that names the actual value, the expected contract, and the caller's line —
not three calls deeper as a `MethodError` or a silently wrong result.

## API QUICK-REFERENCE

### Type and presence checks
| Construct | Form | Notes |
|-----------|------|-------|
| `is` operator | `v is Integer`, `v is Float`, `v is Number`, `v is String`, `v is Array`, `v is MyClass` | Works for primitives and objects; follows the whole inheritance chain. `5 is Number` is true, `"5" is Number` is false — a string is a String even when it looks numeric |
| `Type()` | `Type(v)` returns `"Integer"`, `"Float"`, `"String"`, `"Map"`, or the class name | Exact class name, no inheritance — use for messages and diagnostics, not for capability checks |
| `IsInteger` / `IsFloat` / `IsNumber` | `IsNumber("3.5")` | Test the *content* of a string; use these for text that came from an Edit control, file, or registry |
| `IsObject()` | `IsObject(v)` | True for every reference type; false for Integer, Float, String |
| `IsSet()` | `IsSet(param)` | True once a variable or optional parameter has a value, including `""` and `0`. Takes a variable, not a property — test properties with `HasProp` |
| `??` | `v ?? fallback` | Fallback is used only when `v` is unset. It never throws and never rejects bad values |

### Capability probes
| Construct | Form | Notes |
|-----------|------|-------|
| `HasMethod()` | `HasMethod(obj, "Name")` | True if the name resolves to a callable. `HasMethod(f, "Call")` is true for functions, closures, bound funcs and arrow functions |
| `HasProp()` | `HasProp(obj, "Name")` | True if the property resolves on the object or its base chain |
| `__Enum` | `HasMethod(c, "__Enum")` | Array, Map and custom iterables expose it; this is the "can I `for` over it" test |

### Error classes for validation
| Class | Use for | Form |
|-------|---------|------|
| `TypeError` | Wrong type passed | `throw TypeError("x must be Integer, got " Type(x), -1)` |
| `ValueError` | Right type, value outside the contract | `throw ValueError("level must be 0-100, got " n, -1)` |
| `TargetError` | A window or process the call needs is absent | `throw TargetError("window not found: " title, -1)` |
| `Error` | Environment failures with no better class (missing file, copy did not land) | `throw Error("file not found: " path, -1)` |
| `OSError` | Wrapping a real Win32 failure | `throw OSError(A_LastError)` — takes a numeric code, not a message |

### Fork built-ins for validation
| Built-in | Use |
|----------|-----|
| `JSON.Validate(text)` | Gate untrusted JSON before parsing. Never throws; returns an object with `Valid`, `Line`, `Col`, `Message` |
| `Check(source)` | Real-engine "does this AHK source parse?" for code strings. Not `TSParse(...).HasError` |
| `Print(fmt, values*)` | Report validation results on stdout instead of `MsgBox` in tests and CLI tools |

## AHK V2 CONSTRAINTS

- Guards go at the very top of the function, before the first line of logic. Logic that runs before a
  failing guard may already have changed state.
- Always pass `-1` as the second argument of `throw`: `throw TypeError("msg", -1)`. The error then
  reports the *caller's* line instead of the throw line inside the guard helper.
- Every message carries the actual value or type and the expected contract. `"bad type"` is not
  actionable; `"age must be Integer, got String"` is.
- `TypeError` is for the wrong type, `ValueError` for the right type with a bad value. Callers can
  then `catch TypeError` and `catch ValueError` separately.
- `x is String` is true for string primitives, and `x is Number` is false for numeric text. Pick the
  check that matches the question: `is Number` for a real number, `IsNumber(s)` for text that must
  parse as one.
- Never use `param = ""` to detect an omitted optional parameter. Unset and empty are different
  states; use `IsSet(param)`.
- `??` resolves defaults, it does not guard. Reject bad provided values with `IsSet` plus a type check
  first, then apply `??` on the assignment line.
- In `__New`, finish the whole guard block before the first `this.Prop :=` assignment. AHK has no
  constructor rollback, so a throw after a partial initialisation leaves a half-built object that a
  caller-held reference can still reach.
- Validate external objects by capability: `HasMethod` / `HasProp`. Comparing `Type(obj)` to a class
  name rejects every valid subclass and every unrelated object that satisfies the same contract.
- Guard public and external boundaries only. Private helpers called from already-validated code do
  not need their own guard stack.
- `Integer("abc")` throws a `TypeError`; guard with `IsInteger()` when the text is untrusted.
- `FileExist()` and `DirExist()` return an attribute string or `""`, not a boolean. Truthiness works,
  but compare with `!= ""` when the result is stored or printed.
- Prefer a probe over `try obj.Method() catch MethodError`. The probe states the intent and the
  catch form also swallows a `MethodError` raised from deeper inside a method that does exist.

Guard order, cheapest first, so wrong input is rejected before expensive work runs:

1. `is`, `Type()`, `IsSet()`, `IsObject()` — scalar checks
2. `StrLen()`, `.Length`, `.Count` — size screening
3. `HasMethod()`, `HasProp()` — object capability
4. `RegExMatch()` — only after type and length pass
5. `FileExist()`, `DirExist()`, `WinExist()`, `ProcessExist()` — one OS call each, last

## TIER 1 — Type and unset fundamentals
> METHODS COVERED: `is` · `Type()` · `IsSet()` · `IsObject()` · `IsNumber()` · `??`

Each primitive answers one question. Mixing them up produces guards that pass everything or reject
valid input.
```ahk
#Requires AutoHotkey v2.1-alpha.30

Describe(v) {
    if v is Integer
        return "integer " v
    if v is Float
        return "float " v
    if v is String
        return "string of length " StrLen(v)
    if IsObject(v)
        return "object of type " Type(v)
    return "other"
}

; A numeric-looking string is a String, not a Number
Print("{} {} {}", "5" is Number, 5 is Number, IsNumber("5"))   ; 0 1 1

; Subclass instances satisfy `is` for every ancestor
class Shape {
}
class Circle extends Shape {
}
c := Circle()
Print("{} {} {}", c is Circle, c is Shape, Type(c))             ; 1 1 Circle

; Optional parameter: IsSet, not an empty-string comparison
Compute(a, b, label?) {
    if !(a is Number)
        throw TypeError("a must be Number, got " Type(a), -1)
    if !(b is Number)
        throw TypeError("b must be Number, got " Type(b), -1)
    if IsSet(label) && !(label is String)
        throw TypeError("label must be String when provided, got " Type(label), -1)
    return (label ?? "result") ": " (a + b)
}
Print("{}", Compute(10, 20))
Print("{}", Compute(10, 20, "sum"))

; ?? resolves defaults after the guards have passed
ApplyDefaults(title?, timeout?) {
    if IsSet(timeout) && !(timeout is Integer)
        throw TypeError("timeout must be Integer when provided, got " Type(timeout), -1)
    resolvedTitle := title ?? "Untitled"
    resolvedTimeout := timeout ?? 3000
    return resolvedTitle " / " resolvedTimeout
}
Print("{}", ApplyDefaults())
Print("{}", ApplyDefaults("Report", 5000))

; ✗ Wrong: "" is a set value, so this does not detect an omitted parameter
; if label = ""
```

## TIER 2 — Guard clauses and constructors
> METHODS COVERED: `throw TypeError()` · `throw ValueError()` · `IsSet()` · `StrLen()` · `Trim()` · `__New`

Stack the guards at the top, type first and constraint second, then resolve defaults and run the
logic. A constructor is an API boundary like any other.
```ahk
#Requires AutoHotkey v2.1-alpha.30

SetVolume(level, channel := "master") {
    if !(level is Integer)
        throw TypeError("level must be Integer, got " Type(level), -1)
    if level < 0 || level > 100
        throw ValueError("level must be 0-100, got " level, -1)
    if !(channel is String)
        throw TypeError("channel must be String, got " Type(channel), -1)
    if Trim(channel) = ""
        throw ValueError("channel must not be blank", -1)

    Print("volume '{}' = {}", channel, level)
}

ProcessBatch(items) {
    if !(items is Array)
        throw TypeError("items must be Array, got " Type(items), -1)
    if items.Length = 0
        throw ValueError("items must not be empty", -1)
    if items.Length > 1000
        throw ValueError("items exceeds 1000 entries (got " items.Length ")", -1)
    for item in items
        Print("item: {}", item)
}

try {
    SetVolume(150)
} catch ValueError as err {
    Print("rejected: {}", err.Message)
}

try {
    ProcessBatch(Map())
} catch TypeError as err {
    Print("rejected: {}", err.Message)
}

; The whole guard block comes before the first property assignment
class UserRecord {
    Name := ""
    Age := 0
    Email := ""

    __New(name, age, email?) {
        if !(name is String)
            throw TypeError("name must be String, got " Type(name), -1)
        if Trim(name) = ""
            throw ValueError("name must not be blank", -1)
        if !(age is Integer)
            throw TypeError("age must be Integer, got " Type(age), -1)
        if age < 0 || age > 150
            throw ValueError("age must be 0-150, got " age, -1)
        if IsSet(email) && !RegExMatch(email, "i)^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$")
            throw ValueError("email format invalid: '" email "'", -1)

        this.Name := name
        this.Age := age
        this.Email := email ?? ""
    }

    Describe() => this.Name " (age " this.Age ")" (this.Email != "" ? " <" this.Email ">" : "")
}

try {
    UserRecord("", 25)
} catch ValueError as err {
    Print("rejected: {}", err.Message)
}

Print("{}", UserRecord("Bob", 30, "bob@example.com").Describe())

; ✗ Wrong: an unhelpful message, and no -1 so the dialog points inside the guard
; throw TypeError("bad type")
```

## TIER 3 — String and business-rule validation
> METHODS COVERED: `RegExMatch()` · `IsInteger()` · `StrLen()` · `Trim()` · `.Push()` · `.Length`

Domain rules are collected into a list when the caller benefits from seeing every failure at once
(password rules, form fields), and thrown immediately when one failure is enough.
```ahk
#Requires AutoHotkey v2.1-alpha.30

ValidateFilename(name) {
    if !(name is String)
        throw TypeError("filename must be String, got " Type(name), -1)
    if Trim(name) = ""
        throw ValueError("filename must not be blank", -1)
    if RegExMatch(name, '[\\/:*?"<>|]')
        throw ValueError("filename contains an illegal character: '" name "'", -1)
    if StrLen(name) > 255
        throw ValueError("filename exceeds 255 characters (got " StrLen(name) ")", -1)
    return true
}

; Text from an Edit control, file or registry is a String: check content, then convert
ParsePort(text) {
    if !IsInteger(text)
        throw ValueError("port must be an integer, got '" text "'", -1)
    port := Integer(text)
    if port < 1 || port > 65535
        throw ValueError("port must be 1-65535, got " port, -1)
    return port
}

; Collect every failure for one field, then report them together
PasswordErrors(pw) {
    if !(pw is String)
        throw TypeError("password must be String, got " Type(pw), -1)
    errors := []
    if StrLen(pw) < 8
        errors.Push("must be at least 8 characters")
    if !RegExMatch(pw, "[A-Z]")
        errors.Push("must contain an uppercase letter")
    if !RegExMatch(pw, "\d")
        errors.Push("must contain a digit")
    if !RegExMatch(pw, "[^a-zA-Z0-9]")
        errors.Push("must contain a special character")
    return errors
}

JoinLines(items) {
    text := ""
    for i, item in items
        text .= (i > 1 ? "`n" : "") "- " item
    return text
}

problems := PasswordErrors("weak")
if problems.Length
    Print("password rejected:`n{}", JoinLines(problems))

try {
    ValidateFilename("file?.txt")
} catch ValueError as err {
    Print("rejected: {}", err.Message)
}

try {
    ParsePort("80x")
} catch ValueError as err {
    Print("rejected: {}", err.Message)
}

; Untrusted JSON: gate it with the fork built-in, do not hand-roll a bracket scanner
res := JSON.Validate('{"a": 1,}')
if !res.Valid
    Print("json rejected at line {} col {}: {}", res.Line, res.Col, res.Message)
```

## TIER 4 — Duck-typed object validation
> METHODS COVERED: `HasMethod()` · `HasProp()` · `IsObject()` · `__Enum`

Require what the function uses, not a class name. Two unrelated classes that both have `Process()`
must both pass.
```ahk
#Requires AutoHotkey v2.1-alpha.30

SafeProcess(processor) {
    if !HasMethod(processor, "Process")
        throw TypeError("processor needs a Process() method; got " Type(processor), -1)
    processor.Process()
}

EnsureInterface(obj, requiredMethods, requiredProps) {
    if !IsObject(obj)
        throw TypeError("obj must be an object, got " Type(obj), -1)
    for name in requiredMethods
        if !HasMethod(obj, name)
            throw TypeError("missing method '" name "' on " Type(obj), -1)
    for name in requiredProps
        if !HasProp(obj, name)
            throw TypeError("missing property '" name "' on " Type(obj), -1)
}

EnsureCallable(handler, label := "handler") {
    if !HasMethod(handler, "Call")
        throw TypeError(label " must be callable, got " Type(handler), -1)
}

EnsureIterable(collection, label := "collection") {
    if !HasMethod(collection, "__Enum")
        throw TypeError(label " must be iterable, got " Type(collection), -1)
}

class TextRenderer {
    Name := "TextRenderer"
    Process() => Print("rendering text")
    Reset() => Print("reset text")
}

class ImageRenderer {
    Name := "ImageRenderer"
    Process() => Print("rendering image")
    Reset() => Print("reset image")
}

SafeProcess(TextRenderer())
SafeProcess(ImageRenderer())
EnsureInterface(TextRenderer(), ["Process", "Reset"], ["Name"])
EnsureCallable(() => 1)
EnsureCallable(Print, "printer")
EnsureIterable([1, 2])
EnsureIterable(Map())

try {
    EnsureCallable("not a function")
} catch TypeError as err {
    Print("rejected: {}", err.Message)
}

; ✗ Wrong: rejects every subclass and every other implementor of Process()
; if Type(processor) != "TextRenderer"
;     throw TypeError("must be TextRenderer")
```

## TIER 5 — Environment pre-flight
> METHODS COVERED: `FileExist()` · `DirExist()` · `DirCreate()` · `WinExist()` · `ProcessExist()` · `FileCopy()` · `SplitPath()` · `throw TargetError()`

Check the outside world before an irreversible action, and verify the result of calls that can
fail without throwing. Cache results when a batch touches the same location repeatedly.
```ahk
#Requires AutoHotkey v2.1-alpha.30

ReadTextFile(path) {
    if !(path is String) || Trim(path) = ""
        throw ValueError("path must be a non-empty String", -1)
    if FileExist(path) = ""
        throw Error("file not found: '" path "'", -1)
    return FileRead(path, "UTF-8")
}

FocusWindow(winTitle) {
    if !WinExist(winTitle)
        throw TargetError("window not found: '" winTitle "'", -1)
    WinActivate(winTitle)
}

CloseProcess(name) {
    pid := ProcessExist(name)
    if !pid
        throw TargetError("process not running: '" name "'", -1)
    ProcessClose(pid)
    if ProcessWaitClose(pid, 3) != 0
        throw Error("process did not exit: '" name "' (PID " pid ")", -1)
    return pid
}

; One DirExist call per distinct directory, not per file
AppendToAll(paths, text) {
    dirOk := Map()
    for path in paths {
        SplitPath(path, , &dir)
        if !dirOk.Has(dir)
            dirOk[dir] := DirExist(dir) != ""
        if !dirOk[dir]
            throw Error("directory missing: '" dir "'", -1)
        FileAppend(text, path, "UTF-8")
    }
}

try {
    ReadTextFile(A_ScriptDir "\definitely-missing.txt")
} catch Error as err {
    Print("rejected: {}", err.Message)
}

try {
    FocusWindow("ahk_class NoSuchWindowClass")
} catch TargetError as err {
    Print("rejected: {}", err.Message)
}
```

Cost notes:

- Compile a hot regex once and keep it in a `static` property rather than rebuilding the string per call.
- Build a fluent validator's rules once at form creation and re-run it on submit; do not rebuild it per keystroke.
- A probe (`HasMethod`) is cheaper than an exception on the miss path.

## TIER 6 — Collect-all fluent validator
> METHODS COVERED: `static` factory · method chaining · `HasMethod()` · `RegExMatch()` · `.Push()`

For forms the user should fix in one pass, rules accumulate errors instead of throwing on the first
one. `Validate()` is the single throwing exit; `Errors` allows non-throwing use.
```ahk
#Requires AutoHotkey v2.1-alpha.30

class FieldRules {
    Errors := []
    Value := ""
    Field := "value"

    static Of(value, fieldName := "value") {
        rules := FieldRules()
        rules.Value := value
        rules.Field := fieldName
        return rules
    }

    Required() {
        if !(this.Value is String) || Trim(this.Value) = ""
            this.Errors.Push(this.Field ": is required")
        return this
    }

    IsInteger() {
        if !(this.Value is Integer)
            this.Errors.Push(this.Field ": must be Integer (got " Type(this.Value) ")")
        return this
    }

    InRange(lo, hi) {
        if (this.Value is Integer) && (this.Value < lo || this.Value > hi)
            this.Errors.Push(this.Field ": must be " lo "-" hi " (got " this.Value ")")
        return this
    }

    Length(lo, hi) {
        if this.Value is String {
            n := StrLen(this.Value)
            if n < lo || n > hi
                this.Errors.Push(this.Field ": length must be " lo "-" hi " (got " n ")")
        }
        return this
    }

    Matches(pattern, description := "a valid format") {
        if (this.Value is String) && !RegExMatch(this.Value, pattern)
            this.Errors.Push(this.Field ": must be " description)
        return this
    }

    Satisfies(pred, description := "the custom rule") {
        if !HasMethod(pred, "Call")
            throw TypeError("pred must be callable, got " Type(pred), -1)
        if !pred(this.Value)
            this.Errors.Push(this.Field ": must satisfy " description)
        return this
    }

    HasErrors => this.Errors.Length > 0
}

class FormCheck {
    Fields := []

    Add(rules) {
        this.Fields.Push(rules)
        return this
    }

    AllErrors() {
        all := []
        for rules in this.Fields
            for err in rules.Errors
                all.Push(err)
        return all
    }

    Validate() {
        errors := this.AllErrors()
        if errors.Length = 0
            return true
        text := ""
        for i, err in errors
            text .= (i > 1 ? "`n" : "") "- " err
        throw ValueError("form validation failed:`n" text, -1)
    }
}

SubmitRegistration(username, email, age) {
    form := FormCheck()
    form.Add(FieldRules.Of(username, "username").Required().Length(3, 20).Matches("^\w+$", "letters, digits or underscore"))
    form.Add(FieldRules.Of(email, "email").Required().Matches("i)^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$", "an email address"))
    form.Add(FieldRules.Of(age, "age").IsInteger().InRange(13, 120))
    try {
        form.Validate()
        Print("accepted: {}", username)
    } catch ValueError as err {
        Print("{}", err.Message)
    }
}

SubmitRegistration("AB", "not-an-email", 200)
SubmitRegistration("valid_user", "user@example.com", 30)
```

## ANTI-PATTERNS

| Pattern | Wrong | Correct | Why it happens |
|---------|-------|---------|----------------|
| Unset test by comparison | `if param = ""` | `if !IsSet(param)` | Other languages treat missing and empty as one state |
| Base class for a type violation | `throw Error("bad type")` | `throw TypeError("x must be Integer, got " Type(x), -1)` | Callers cannot `catch TypeError`, and the message has no values |
| Missing stack offset | `throw TypeError("msg")` | `throw TypeError("msg", -1)` | The error points at the guard line, not at the bad call |
| Class-name assertion | `if Type(obj) = "MyClass"` | `if !HasMethod(obj, "Process")` | Breaks subclasses and polymorphic callers |
| Exception as capability probe | `try obj.Run() catch MethodError` | `HasMethod(obj, "Run")` | The catch also hides a `MethodError` from deeper inside `Run` |
| `??` as a guard | `x := param ?? throw ...` | Guard with `IsSet` and a type check, then `x := param ?? fallback` | `??` resolves defaults and never rejects a bad provided value |
| Assignment before the guard in `__New` | `this.X := x` then validate | Full guard block, then assignments | No constructor rollback; a half-built object is reachable |
| Numeric text checked with `is Number` | `if text is Number` on Edit input | `if IsNumber(text)` | Control text is always a String |
| Hand-rolled JSON well-formedness check | Bracket counting | `JSON.Validate(text)` | The native validator reports line, column and reason |
| Hand-rolled "is this AHK code valid" check | Regex on source text | `Check(source)` | Only the real parser agrees with the CLI |

## SEE ALSO

- `Module_Errors.md` — error class hierarchy, try/catch/else/finally ordering, `OnError`, and the
  existing parameter-validation example under TIER 8.
- `Module_Classes.md` — validator base classes, `__New` lifecycle, and prototype-level sharing.
- `Module_Instructions.md` — core syntax rules and coding standards.
- `Module_Versions.md` — which of the fork built-ins used here exist on stock AHK.

<!-- Adapted from hsinming/AutoHotkey-V2-vibe-coding-tools (no license file upstream); see THIRD-PARTY.md -->
