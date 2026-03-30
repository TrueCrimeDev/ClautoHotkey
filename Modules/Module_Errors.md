# Module_Errors.md
<!-- DOMAIN: Errors — syntax errors, runtime errors, v1→v2 migration, exception handling -->
<!-- SCOPE: COM-specific error propagation, HRESULT codes, and deep GUI event-binding diagnostics are not covered — see Module_SystemAndCOM.md and Module_GUI.md. -->
<!-- TRIGGERS: error, exception, try, catch, throw, OnError, debug, crash, "syntax error", "runtime error", "not working", "script won't run", "unknown command", "variable not assigned", ErrorLevel, UnsetError, "v1 to v2 migration", "old script broken", "unexpected behavior", "throws exception" -->
<!-- CONSTRAINTS: Use `:=` for assignment — `=` alone in an expression is case-insensitive string comparison, not assignment; all built-in commands require function syntax with parentheses and quoted strings; `ErrorLevel` is removed in v2 — use `try/catch as err` instead; fat-arrow functions are single-expression only, never multi-line blocks; `new ClassName()` is invalid in v2 — call the class directly; register `OnError()` as the first executable statement so early throws are captured. -->
<!-- CROSS-REF: Module_Instructions.md, Module_Classes.md, Module_GUI.md, Module_Arrays.md, Module_DataStructures.md, Module_SystemAndCOM.md, Module_FileSystem.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `x = 5 + 2` (assignment) | `x := 5 + 2` | In v2 expressions `=` is case-insensitive string comparison — silent logic error, not an assignment |
| `MsgBox Hello, World!` / `Run notepad.exe` | `MsgBox("Hello, World!")` / `Run("notepad.exe")` | "Unknown command" parse error — every built-in is a function in v2 |
| `%Var%` inside strings or expressions | `Var` directly; concatenate with `.` | `%Var%` is a literal six-character string in v2 expressions, not variable expansion |
| `#If WinActive("Title")` | `#HotIf WinActive("Title")` | Context directive not recognized — context-sensitive hotkeys silently non-functional |
| `if (ErrorLevel)` after any function call | `try { } catch as err { }` | `ErrorLevel` removed in v2; most functions never set it — condition always evaluates an unset variable |
| `new MyClass()` | `MyClass()` | `new` is invalid in v2 — parse error, or `__New` constructor is bypassed entirely |
| `Gui, Add, Edit, vMyEdit` / `Gui, Show` | `gui := Gui("", "Title")` → `gui.Add("Edit", "vMyEdit")` → `gui.Show()` | "Unknown command" — GUI is fully object-based in v2; command-style is not recognized |
| `return, total` | `return total` | Parse error — comma after `return` is a v1-only holdover, invalid in v2 |
| `SetTimer, MyFunc, 2000` | `SetTimer(MyFunc, 2000)` | "Unknown command" — `SetTimer` is a function call, not a command |
| Passing method reference without `.Bind()` | `obj.Method.Bind(obj)` | "this has not been assigned a value" at runtime — method callbacks lose `this` context unless explicitly bound |

## API QUICK-REFERENCE

### Built-in Error Classes
| Class | Constructor Signature | Notes |
|-------|-----------------------|-------|
| `Error` | `Error(message, what?, extra?)` | Base class for all exceptions; `.File`, `.Line`, `.Stack` populated automatically |
| `ValueError` | `ValueError(message, what?, extra?)` | Wrong value type or out-of-range argument |
| `TypeError` | `TypeError(message, what?, extra?)` | Wrong object type passed to a function or operator |
| `OSError` | `OSError(code?)` | OS-level I/O failure; `code` is a numeric Windows error code (defaults to `A_LastError`); sets `.Number` and `.Message` automatically |
| `MemoryError` | `MemoryError(message?)` | Memory allocation failure |
| `UnsetError` | `UnsetError(message, what?)` | Uninitialized variable or unset function parameter |
| `UnsetItemError` | `UnsetItemError(message, what?)` | Array index or Map key not found |
| `MemberError` | `MemberError(message, what?)` | Property or method does not exist on an object |
| `IndexError` | `IndexError(message, what?)` | Array index out of bounds |
| `KeyError` | `KeyError(message, what?)` | Map key absent when direct access `m[k]` is used |
| `TargetError` | `TargetError(message, what?)` | Target window or control not found |

### Error Object Properties
| Property | Type | Notes |
|----------|------|-------|
| `.Message` | String | Human-readable description — always present |
| `.What` | String | Name of the function/method that threw |
| `.Extra` | String | Supplementary information, if provided |
| `.File` | String | Full path to the source file where the error occurred |
| `.Line` | Integer | Line number in the source file |
| `.Stack` | String | Multi-line call-stack trace string |

### Exception Control Flow
| Keyword / Function | Syntax | Notes |
|-------------------|--------|-------|
| `throw` | `throw ExpressionOrObject` | Throws any value; `Error`-derived objects gain `.File`/`.Line` automatically |
| `try` | `try { ... }` | Guards the block; jumps to matching `catch` on exception |
| `catch` | `catch [ErrorClass] as varName { }` | Type clause is optional; most-specific subclass must come **first** |
| `finally` | `finally { }` | Always runs after try/catch regardless of outcome — use for guaranteed cleanup |
| `OnError()` | `OnError(callback, addRemove?)` | Register global uncaught-exception handler; call before any throwable code |

### Supporting Functions Used in Error Patterns
| Function | Signature | Notes |
|----------|-----------|-------|
| `Type()` | `Type(value)` | Returns the type name as a string — use in OnError to identify exception class |
| `FormatTime()` | `FormatTime(time?, format?)` | Format timestamps for crash logs |
| `FileAppend()` | `FileAppend(text, filename, encoding?)` | Append structured entries to persistent crash log |
| `MouseGetPos()` | `MouseGetPos(&x?, &y?, &win?, &ctrl?)` | All four output parameters require `&` prefix |
| `ProcessExist()` | `ProcessExist(pidOrName?)` | Returns PID if running, 0 if not — use in completion-check timers |
| `Run()` | `Run(target, workingDir?, options?, &pidVarName?)` | Non-blocking process launch; capture PID via `&pidVarName` |
| `RunWait()` | `RunWait(target, workingDir?, options?, &pidVarName?)` | Blocking launch — freezes GUI; prefer `Run()` + timer for GUI scripts |
| `StrSplit()` | `StrSplit(string, delimiters?, omitChars?, maxParts?)` | Returns Array; replaces v1 `Loop, Parse` |
| `WinActivate()` | `WinActivate(winTitle?, ...)` | Bring target window to foreground before sending input |
| `WinWaitActive()` | `WinWaitActive(winTitle?, ..., timeout?)` | Block until window is active — pair with `WinActivate()` |
| `ControlSend()` | `ControlSend(keys, control?, winTitle?, ...)` | Send keystrokes to a specific control without activating the window |

## AHK V2 CONSTRAINTS

- `:=` is always assignment; `=` in an expression is always case-insensitive string comparison; never use `=` to assign — the script runs without error but produces wrong values silently.
- All AHK built-in commands require function syntax: parentheses, quoted string arguments. `MsgBox text` is a parse error; `MsgBox("text")` is correct.
- `%Var%` inside quoted strings or expressions is never variable expansion in v2 — it resolves to a literal string. Use `Var` directly in expressions or concatenate with `.`.
- All functions and hotkeys have **local scope by default** — global variables referenced inside them must be declared with `global varName`; omitting this causes UnsetError at runtime.
- `ErrorLevel` is removed in v2 — it is never set by built-in functions. Checking it produces UnsetError or always-false logic. Use `try/catch as err` exclusively.
- Fat-arrow functions `=>` accept exactly one expression, never a brace-enclosed block of statements — using `() => { multiple; lines }` is a parse error.
- `new ClassName()` is invalid in AHK v2 under any circumstances — instantiate by calling the class: `obj := MyClass()`.
- `catch` clauses must be ordered **most-specific subclass first** — a broad `catch Error` placed before `catch NetworkError` swallows all typed exceptions, preventing targeted recovery.
- `OnError()` must be registered **before** any throwable code — exceptions thrown during initialization are not captured by a handler registered afterward.
- `return` and its value must appear on the **same physical line** — a line break between them is parsed as a bare `return` followed by a stray expression (parse error or dead code).
- `#HotIf` replaces `#If` — using the old directive causes the context block to be silently ignored; hotkeys fire unconditionally.

Safe-access priority order for exception handling:
1. `??` null-coalescing — one-line resolution for unset variables, never throws
2. `try/catch as err { }` — when the exception carries diagnostic information needed for recovery
3. `try/catch ErrorClass as err { }` — typed catch for branching on specific failure categories
4. `OnError(handler)` — last-resort net for uncaught exceptions; not a substitute for local try/catch

Pair every prohibition with its positive alternative:
- ✗ `x = 5` — silent case-insensitive comparison, not assignment
- ✓ `x := 5` — unambiguous assignment in all contexts
- ✗ `if (ErrorLevel)` — variable never set in v2; always UnsetError or wrong
- ✓ `try { risky() } catch as err { handle(err) }` — explicit, typed exception capture
- ✗ `obj := new MyClass()` — `new` keyword invalid in v2
- ✓ `obj := MyClass()` — direct class call invokes `__New` correctly
- ✗ `fn := (x) => { doA(x); return doB(x) }` — multi-line fat-arrow is a parse error
- ✓ Named function with `{ }` braces for multi-statement logic

## TIER 1 — Syntax, Built-in Variable and Escaping Errors
> METHODS COVERED: `MsgBox()` · `Run()` · `A_Clipboard` · `A_ScreenWidth` · `A_Index`

The most common first-contact errors when writing or migrating AHK v2 code are purely syntactic: wrong assignment operator, command-style function calls without parentheses, percent-sign variable expansion, and missing `A_` prefixes on built-ins. These errors are CRITICAL severity — the script refuses to run or produces immediately wrong output. Every item in this tier is a direct v1 habit that must be unlearned.
```ahk
; ── ASSIGNMENT OPERATOR ──────────────────────────────────────────────────────

; ✓ := is the only assignment operator in v2 expressions
x := 5 + 2

; ✗ = alone is case-insensitive string comparison, never assignment
; x = 5 + 2   ; → silent logic error — condition result discarded

; ── FUNCTION CALL SYNTAX ─────────────────────────────────────────────────────

; ✓ All built-ins are functions in v2: parentheses + quoted strings required
MsgBox("Hello, World!")
Run('notepad.exe "C:\file.txt"')

; ✗ v1 command-style — parse error in v2
; MsgBox Hello, World!   ; → "Unknown command"
; Run notepad.exe        ; → "Unknown command"

; ── SPACE BEFORE PARENTHESIS ─────────────────────────────────────────────────

; ✓ Function name and opening parenthesis must be adjacent — no space
MyFunc(param)
MsgBox("Hello World")

; ✗ Space before parenthesis — parse error
; MyFunc (param)          ; → "Missing operator"
; MsgBox ("Hello World")  ; → parse error

; ── PERCENT SIGNS ────────────────────────────────────────────────────────────

; ✓ Variables are used directly in expressions — no percent signs
MsgBox("Value is " . Var)
result := Var + 1

; ✓ % inside a quoted string is always a literal percent — no escape needed
MsgBox("Progress: 50%")

; ✗ v1 percent expansion — Var is treated as literal text
; MsgBox("Value is %Var%")   ; → displays "%Var%" literally
; result := %Var% + 1        ; → syntax error

; ✗ Unnecessary comma escape inside expression strings
; MsgBox("Hello`, World")    ; → commas never need escaping in v2 strings

; ── A_ PREFIX ON BUILT-IN VARIABLES ─────────────────────────────────────────

; ✓ All built-in variables require the A_ prefix in v2
A_Clipboard := "Hello"
width  := A_ScreenWidth
index  := A_Index

; ✗ Missing A_ prefix — unset variable error at runtime
; Clipboard := "Hello"   ; → assigns to a user variable, never the clipboard
; width := ScreenWidth   ; → UnsetError: "Variable has not been assigned a value"
```

## TIER 2 — Scope, Control Flow and Return Statement Errors
> METHODS COVERED: `global` declaration · `??` null-coalescing operator

Errors in this tier arise once the script starts executing: uninitialized variables, incorrect variable scope inside hotkeys and functions, missing braces around multi-line blocks, and v1-style return syntax. These are HIGH severity — the script runs but produces wrong results or throws UnsetError at the point of first use.
```ahk
; ── UNINITIALIZED VARIABLES ──────────────────────────────────────────────────

; ✓ Initialize before use; ?? coalesces unset to a default in one expression
count  := 0
result := count ?? 0   ; Safe: returns 0 if count is unset

; ✗ Reading before assignment — UnsetError at the if condition
; if (count > 0)   ; → "Variable 'count' has not been assigned a value"

; ── VARIABLE SCOPE IN HOTKEYS / FUNCTIONS ────────────────────────────────────

; ✓ Declare global inside the function/hotkey body that needs access
globalCounter := 0

F1:: {
    global globalCounter
    globalCounter += 1
}

; ✗ Hotkeys and functions are local by default — global not visible without declaration
; F1:: {
;     globalCounter += 1   ; → UnsetError: globalCounter not in local scope
; }

; ── MISSING CURLY BRACES ─────────────────────────────────────────────────────

; ✓ Braces required for multi-line blocks — all statements execute conditionally
if (x > 10) {
    MsgBox("High")
    MsgBox("Done")   ; inside braces — only runs when condition is true
}

; ✗ Without braces only the first line is conditional
; if (x > 10)
;     MsgBox("High")
;     MsgBox("Done")   ; → always executes regardless of condition

; ── RETURN STATEMENT SYNTAX ──────────────────────────────────────────────────

; ✓ return and its value must be on the same physical line
return total

; ✓ Assign to a variable first, then return — readable and safe
finalResult := BuildResult()
return finalResult

; ✗ v1 comma after return — parse error in v2
; return, total   ; → parse error

; ✗ Line break between return and value — bare return executes, value is dead code
; return
; result          ; → never reached; function returns empty

; ── FAT-ARROW FUNCTIONS ──────────────────────────────────────────────────────

; ✓ Fat-arrow is valid for a single expression only
onClick := () => MsgBox("Hi")
double  := (x) => x * 2

; ✓ Multiple statements require a named function with braces
HandleClick() {
    MsgBox("Hi")
    DoMore()
}

; ✗ Fat-arrow with brace block — parse error
; onClick := () => { MsgBox("Hi"); DoMore() }   ; → parse error
```

## TIER 3 — Logic, Operator, Event and Callback Errors
> METHODS COVERED: `StrSplit()` · `Loop Read` · `.Bind()` · `WinActivate()` · `WinWaitActive()` · `ControlSend()` · `Send()` · `SendInput()`

These are HIGH-severity logic errors that arise from operator confusion, v1 loop syntax, and missing callback binding — the script compiles and runs but produces wrong results or fires in the wrong window. The operator distinction (`=` vs `==` vs `:=`) is a frequent source of subtle bugs because all three forms are syntactically legal in v2.
```ahk
; ── COMPARISON OPERATORS ─────────────────────────────────────────────────────

; ✓ == is case-sensitive string comparison — use when case matters
if (x == "hello")       ; matches only exact lowercase "hello"
    MsgBox("Exact match")

; ✓ = is case-insensitive string comparison — intentional when case is irrelevant
if (x = "HELLO")        ; matches "hello", "Hello", "HELLO", etc.
    MsgBox("Case-insensitive match")

; ✗ Confusing = with := — = never assigns; using it here creates a comparison, not a store
; x = 5   ; → evaluates "does x equal 5?", discards the result; x is still unset

; ── LOOP SYNTAX ──────────────────────────────────────────────────────────────

; ✓ v2 string splitting — StrSplit returns an Array, iterate with for...in
for index, part in StrSplit(Str, ",") {
    MsgBox(part)
}

; ✓ v2 file-reading loop — Loop Read is the correct construct for line iteration
Loop Read, "myfile.txt" {
    MsgBox(A_LoopReadLine)
}

; ✗ v1 Loop Parse command syntax — "Unknown command" in v2
; Loop, Parse, Str, ,
;     MsgBox(A_LoopField)   ; → parse error

; ✗ FileOpen does not support for-in line iteration
; for lineNum, lineText in FileOpen("myfile.txt")
;     MsgBox(lineText)   ; → MemberError: no __Enum on file object

; ── CALLBACK BINDING ─────────────────────────────────────────────────────────

; ✓ .Bind(this) propagates the instance reference into the callback context
button.OnEvent("Click", MyGui.ButtonHandler.Bind(MyGui))
SetTimer(MyClass.TimerMethod.Bind(MyClass), 1000)

; ✓ Inside a method, bind to the current instance
button.OnEvent("Click", this.ButtonHandler.Bind(this))

; ✗ Unbound method reference — this is unset when the callback fires
; button.OnEvent("Click", MyGui.ButtonHandler)       ; → UnsetError: "this has not been assigned"
; SetTimer(MyClass.TimerMethod, 1000)                ; → same UnsetError on first fire

; ── SEND MODE AND WINDOW TARGETING ───────────────────────────────────────────

; ✓ Choose Send variant based on target application requirements
SendInput("Hello World")    ; Most modern apps
SendPlay("Hello World")     ; Games and stubborn apps
SendEvent("Hello World")    ; Legacy applications

; ✓ Always ensure correct window is active before sending, or target the control directly
WinActivate("MyApp")
WinWaitActive("MyApp")
Send("Hello")

; ✓ Preferred: target a specific control — no window activation required
ControlSend("Hello", "Edit1", "MyApp")

; ✗ Bare Send with no targeting — keystrokes go to whichever window has focus
; Send("Hello")   ; → may type into the wrong application
```

## TIER 4 — Context, Hotkey, Automation and Path Errors
> METHODS COVERED: `#HotIf` · `Gui()` · `.Add()` · `.Show()` · `Run()` · `RunWait()` · `SetTimer()` · `ProcessExist()` · `FileRead()` · `FileSelect()`

MEDIUM-severity errors that prevent entire feature areas from working: wrong hotkey context directive, legacy GUI command syntax, missing string quotes around Send arguments, blocking calls that freeze the GUI, and hard-coded paths that break on any machine other than the developer's. These errors are typically silent at parse time but immediately visible at runtime.
```ahk
; ── HOTKEY CONTEXT DIRECTIVE ─────────────────────────────────────────────────

; ✓ v2 context-sensitive hotkey — #HotIf with braces around multi-line body
#HotIf WinActive("MyWindow")
F1:: {
    MsgBox("Context hotkey")
}
#HotIf   ; reset context

; ✗ v1 directive — silently ignored in v2; hotkey fires unconditionally
; #If WinActive("MyWindow")   ; → directive not recognized in v2
; F1::MsgBox("Context hotkey")

; ── GUI CREATION ─────────────────────────────────────────────────────────────

; ✓ v2 object-based GUI — constructor at creation, methods for controls and display
gui := Gui("", "Title")
gui.Add("Edit", "vMyEdit")
gui.Show()

; ✗ v1 command-style GUI — "Unknown command" or "This class does not support" in v2
; Gui, Add, Edit, vMyEdit   ; → parse error
; Gui, Show, , Title        ; → parse error

; ── STRING QUOTING IN SEND ───────────────────────────────────────────────────

; ✓ Keys must be quoted strings — bare braces are object literal syntax
Send("{Media_Play_Pause}")

; ✗ Missing quotes — AHK v2 parses {Media_Play_Pause} as an object literal
; Send({Media_Play_Pause})   ; → "Missing propertyname" parse error

; ── HARD-CODED ABSOLUTE PATHS ────────────────────────────────────────────────

; ✓ Build paths from built-in path variables — works on any machine
FileRead(A_MyDocuments . "\config.txt")
FileRead(A_ScriptDir    . "\settings.ini")

; ✓ Prompt the user when the path cannot be known at write time
configPath := FileSelect(1, , "Select config file")
if (configPath)
    FileRead(configPath)

; ✗ Hard-coded absolute path — file not found on any machine except the author's
; FileRead("C:\Users\Alice\Documents\config.txt")   ; → OSError on all other machines

; ── BLOCKING vs NON-BLOCKING CALLS ───────────────────────────────────────────

; ✓ Non-blocking: Run() returns immediately; named function checks completion via timer
Run("longprocess.exe",,, &pid)

MonitorProcess(targetPid) {
    if !ProcessExist(targetPid)
        SetTimer(, 0)   ; Stop this timer — no more checks needed
}
SetTimer(MonitorProcess.Bind(pid), 100)   ; Poll every 100 ms
; <!-- CONVERTED: replaced multi-line fat-arrow callback `() => { if (!ProcessExist(pid)) { SetTimer(, 0) } }` with named function + .Bind(pid); multi-line fat-arrow block bodies are invalid in AHK v2 -->

; ✓ Auto-closing MsgBox for non-blocking user notification
MsgBox("Process started", "Info", "T3")   ; Auto-closes after 3 seconds

; ✗ RunWait blocks the entire script — GUI freezes until process exits
; RunWait("longprocess.exe")   ; → GUI unresponsive for the entire duration
```

## TIER 5 — Exception Handling: try/catch, Custom Exceptions and OnError
> METHODS COVERED: `try/catch/finally/throw` · `OnError()` · `MouseGetPos()` · `SetTimer()` · `FileAppend()` · `FormatTime()` · `Type()` · `.Bind()` · `super.__New()`

HIGH-severity errors in exception architecture: omitting `&` on output parameters, leaving operations unwrapped in try/catch, swallowing errors with empty catch blocks, throwing generic `Error` instead of typed subclasses, and failing to register a global safety net. This tier also covers the full custom exception hierarchy pattern and the `OnError` crash-log idiom.
```ahk
; ── BYREF OUTPUT PARAMETERS ──────────────────────────────────────────────────

; ✓ Output parameters require & prefix — all four vars are populated by the function
MouseGetPos(&x, &y, &win, &ctrl)

; ✗ Missing & — output variables are never written; x and y remain unset
; MouseGetPos(x, y)   ; → no error thrown, but x/y are silently empty

; ── SETTIMER SYNTAX ──────────────────────────────────────────────────────────

; ✓ SetTimer takes a function reference or string name
SetTimer(MyFunc, 2000)
SetTimer("MyFunc", 2000)

; ✓ Object methods require .Bind() so the correct instance is captured
SetTimer(ObjRef.Method.Bind(ObjRef), 1000)

; ✗ v1 command syntax — "Unknown command" in v2
; SetTimer, MyFunc, 2000   ; → parse error

; ── TRY / CATCH / FINALLY ────────────────────────────────────────────────────

; ✓ Wrap risky calls; finally guarantees cleanup even when an exception fires
try {
    content := FileRead("config.txt")
    ProcessContent(content)
} catch as err {
    MsgBox("Failed to read config: " . err.Message)
    UseDefaultConfig()
}

; ✓ finally runs regardless of outcome — correct pattern for resource cleanup
file := FileOpen("data.txt", "r", "UTF-8")
try {
    content := file.Read()
    ProcessContent(content)
} finally {
    file.Close()   ; Always executes — handle is never leaked
}

; ✗ No try/catch around a throwable call — uncaught exception kills the script
; content := FileRead("nonexistent.txt")   ; → OSError terminates script

; ✗ Empty catch swallows all errors silently — impossible to debug
; try {
;     RiskyOperation()
; } catch { }   ; → error is hidden; root cause is lost forever

; ── CUSTOM EXCEPTION HIERARCHY ───────────────────────────────────────────────

; ✓ Define domain-specific exception classes extending the built-in Error base
class AppError extends Error {
    __New(message, code := 0) {
        super.__New(message)   ; populates .Message, .File, .Line automatically
        this.Code := code
    }
}

class NetworkError extends AppError {
    __New(message, url := "", statusCode := 0) {
        super.__New(message, statusCode)
        this.URL        := url
        this.StatusCode := statusCode
    }
}

class ValidationError extends AppError {
    __New(message, fieldName := "", value := "") {
        super.__New(message, 422)
        this.FieldName := fieldName
        this.Value     := value
    }
}

; ✓ Throw typed exceptions so callers can recover with precision
FetchData(url) {
    if !url
        throw ValidationError("URL cannot be empty", "url", url)
    ; ... HTTP logic ...
    throw NetworkError("Connection refused", url, 503)
}

; ✓ Catch clauses ordered most-specific first — broad Error must come last
try {
    FetchData("https://example.com/api")
} catch NetworkError as err {
    MsgBox("Network [" . err.StatusCode . "]: " . err.Message
         . "`nURL: " . err.URL)
} catch ValidationError as err {
    MsgBox("Bad input on '" . err.FieldName . "': " . err.Message)
} catch AppError as err {
    MsgBox("App error (code " . err.Code . "): " . err.Message)
} catch Error as err {
    MsgBox("Unexpected error: " . err.Message)   ; fallback for all others
}

; ✗ Generic throw loses all context — caller cannot distinguish failure categories
; throw Error("something went wrong")   ; → caller can't branch on network vs validation

; ── GLOBAL ERROR HANDLER (OnError) ───────────────────────────────────────────

; ✓ Register as the very first executable statement — captures initialization throws
OnError(GlobalCrashHandler)

GlobalCrashHandler(err, mode) {
    ; mode values: "Return" | "Exit" | "ExitApp"
    static logPath := A_ScriptDir . "\crash.log"

    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    errType   := Type(err)                          ; e.g. "NetworkError", "Error"
    location  := err.File . ":" . err.Line

    entry := timestamp . " [" . errType . "] " . err.Message
           . " @ " . location . "`n"

    FileAppend(entry, logPath)

    MsgBox("An unexpected error occurred.`n"
         . "Details saved to: " . logPath, "Error", 16)

    return 1   ; 1 = suppress default AHK crash dialog; 0 = show it afterward
}

; ✓ OnError stacks — multiple handlers can coexist; pass 0 to unregister
; OnError(GlobalCrashHandler, 0)   ; remove when no longer needed

; ✗ Registering OnError after startup code — early throws are missed entirely
; ConnectToDatabase()    ; throws before handler is set
; OnError(GlobalCrashHandler)   ; → handler never sees the database error
```

### Performance Notes

**`try/catch` overhead:** The overhead of a `try` block on the happy path is negligible in AHK v2. The cost is paid only when an exception is actually thrown and caught — exception-path performance is irrelevant when the path is genuinely exceptional. Never use `try/catch` as a substitute for conditional checks on predictable outcomes (e.g., file existence) because the throw+catch cycle is measurably slower than `FileExist()` followed by a branch.

**`OnError` handler cost:** The `OnError` callback runs on the main thread in an already-faulted state. Keep the handler lightweight: write the log entry, show a single notification, return. Do not perform network calls, COM operations, or long loops inside an `OnError` handler — the script state is undefined and secondary exceptions may occur.

**Typed catch clause matching:** AHK v2 resolves `catch` clauses by `instanceof` check in order. Placing a broad `catch Error` first forces every exception — including typed subclasses — to be checked against it first. Ordering most-specific first both ensures correct recovery logic and marginally reduces matching work for the common case.

**Custom exception class allocation:** Creating custom `Error` subclasses adds one object allocation per thrown exception. This is inconsequential on any exception path. The readability and recovery-precision benefit of typed exceptions far outweighs the allocation cost.

## TIER 6 — Version, Compatibility and Diagnostic Patterns
> METHODS COVERED: `#Requires` · `Map()` · `FileOpen()` · `.Read()` · `.Close()` · `ProcessExist()`

<!-- merged: TIER 6+7, reason: TIER_7 "Advanced Diagnostic Patterns" (object literals, comma errors, infinite loops) are peer severity to TIER_6 version/compatibility patterns; merging keeps tier count at exactly 6 -->

LOW-to-MEDIUM severity errors relating to version pinning, removed globals (`ErrorLevel`), the `new` keyword, object literal misuse, comma placement, and infinite-loop patterns. These errors are especially common in scripts ported from AHK v1 or generated by AI tools trained on mixed-version data.
```ahk
; ── #REQUIRES DIRECTIVE ───────────────────────────────────────────────────────

; ✓ First line of every v2 script declares the minimum interpreter version
#Requires AutoHotkey v2.0

; ✗ No directive — script may run under v1 and produce cascading parse errors
; (no directive)   ; → "This line does not contain a recognized action" under v1

; ── ERRORLEVEL (REMOVED IN v2) ───────────────────────────────────────────────

; ✓ Use try/catch — the only exception mechanism in v2
try {
    content := FileRead("nonexistent.txt")
} catch as err {
    MsgBox("Error: " . err.Message)
}

; ✗ ErrorLevel check — variable is never set by v2 functions; logic is always wrong
; FileRead("nonexistent.txt")
; if (ErrorLevel) { }   ; → ErrorLevel is unset; condition is always false or throws

; ── INSTANTIATION WITHOUT new ────────────────────────────────────────────────

; ✓ Class instantiation is a direct function call in v2 — no new keyword
obj := MyClass()

; ✗ new keyword — invalid in AHK v2; parse error or bypasses __New
; obj := new MyClass()   ; → parse error

; ── OBJECT LITERALS vs MAP ───────────────────────────────────────────────────

; ✓ Map() for dynamic key-value storage — supports .Has(), .Get(), .Delete()
settings := Map("theme", "dark", "volume", 80)

; ✓ Dedicated class for structured data with fixed, named properties
class Settings {
    __New() {
        this.theme  := "dark"
        this.volume := 80
    }
}
settings := Settings()

; ✗ Object literal as a general-purpose data container
; settings := {theme: "dark", volume: 80}   ; → no .Has()/.Get()/.Delete() support

; ── RESOURCE MANAGEMENT (OOP UNFAMILIARITY) ──────────────────────────────────

; ✓ Explicit try/finally guarantees file handle is closed even on exception
file := FileOpen("data.txt", "r", "UTF-8")
try {
    content := file.Read()
    ProcessContent(content)
} finally {
    file.Close()   ; Always runs — handle is never leaked
}

; ✗ Chaining .Read() on a bare FileOpen result — handle is never closed
; content := FileOpen("data.txt").Read()   ; → handle leaks; __Delete timing not guaranteed

; ── OBJECT LITERAL SYNTAX ────────────────────────────────────────────────────

; ✓ Object literals require proper key: value pairs
obj := {key: "value", setting: true}

; ✓ Map() for dynamic or string-keyed data
obj := Map("key", "value", "setting", true)

; ✗ Malformed object literal — missing property name
; obj := { , value}   ; → "Missing propertyname" parse error

; ── COMMA AND ARGUMENT LIST ERRORS ───────────────────────────────────────────

; ✓ Separate arguments with exactly one comma each
MsgBox("Hello", "World")

; ✓ Double comma skips an optional parameter (leaves it at its default)
MsgBox("Hello",, 64)   ; Text="Hello", Title=default, Options=64

; ✗ Missing comma between string arguments — concatenation, not two args
; MsgBox("Hello" "World")   ; → parse error or unintended concatenation

; ── INFINITE LOOPS ───────────────────────────────────────────────────────────

; ✓ Include an exit condition and Sleep() to yield execution
counter := 0
while (counter < 100) {
    ; Do work
    counter++
    Sleep(10)   ; Yield — prevents 100% CPU burn
}

; ✗ Busy-wait with no exit condition or sleep — 100% CPU, script never responds
; while (true) { }   ; → hangs entire thread; GUI becomes unresponsive

; ── AI-GENERATED CODE VALIDATION ─────────────────────────────────────────────

; ✓ Validated v2 syntax — every statement uses v2 function form
Send(var)
MsgBox("Hello")

; ✗ AI mixing v1 commands and v2 functions in the same script
; Send, %var%     ; → v1 syntax; "Unknown command" in v2
; MsgBox("Hello") ; → v2 syntax; correct
; (mixing causes cascade of parse errors)
```

## ANTI-PATTERNS

| Pattern | Wrong | Correct | LLM Common Cause |
|---------|-------|---------|------------------|
| Assignment with `=` | `x = 5 + 2` | `x := 5 + 2` | AHK v1 training data: `=` was the assignment operator in v1 expressions |
| Percent-sign variable expansion | `MsgBox("Value: %Var%")` | `MsgBox("Value: " . Var)` | AHK v1 training data: `%Var%` was standard variable interpolation |
| ErrorLevel check after function call | `Run("x.exe")` then `if ErrorLevel` | `try { Run("x.exe") } catch as err { }` | AHK v1 training data: ErrorLevel was the universal return-status mechanism |
| Unbound method callback | `button.OnEvent("Click", MyGui.Handler)` | `button.OnEvent("Click", MyGui.Handler.Bind(MyGui))` | Cross-language habit: Python/JS closures capture `self`/`this` automatically |
| Empty catch block | `try { } catch { }` | `try { } catch as err { MsgBox(err.Message) }` | Copy-paste habit from other languages; silences errors instead of handling them |
| Multi-line fat-arrow callback | `fn := (x) => { doA(x); return doB(x) }` | Named function with `{ }` braces for multi-statement logic | Cross-language lambda habit: JS/Python allow multi-statement arrow/lambda bodies |
| `new` keyword for instantiation | `obj := new MyClass()` | `obj := MyClass()` | Cross-language habit: Java, C#, JS, Python all use `new` or a constructor call |
| Generic throw without typed class | `throw Error("connection failed")` | `throw NetworkError("connection failed", url, 503)` | Missing AHK v2 exception hierarchy knowledge; only `Error` is known from training data |
| Object literal for key-value storage | `data := {name: "Alice", age: 30}` | `data := Map("name", "Alice", "age", 30)` | AHK v1 training data: object literals were the standard key-value container |
| `#If` context directive | `#If WinActive("Title")` | `#HotIf WinActive("Title")` | AHK v1 training data: `#If` was the v1 context directive; renamed in v2 |

## SEE ALSO

> This module does NOT cover: COM-specific exception propagation and HRESULT error codes → see Module_SystemAndCOM.md
> This module does NOT cover: GUI event-binding errors and GUI-specific diagnostic patterns in depth → see Module_GUI.md
> This module does NOT cover: Array and Map iteration error patterns → see Module_Arrays.md and Module_DataStructures.md

- `Module_Instructions.md` — Core AHK v2 syntax rules and validation patterns; the canonical reference for operator precedence, expression syntax, and script structure.
- `Module_Classes.md` — `extends`, `super.__New()`, `__Delete`, and full OOP lifecycle patterns; required reading before authoring custom exception hierarchies.
- `Module_GUI.md` — GUI object creation, event binding, and control-specific error patterns that go beyond the quick reference in TIER 4.
- `Module_Arrays.md` — Array indexing, iteration, and UnsetItemError patterns from incorrect index access.
- `Module_DataStructures.md` — Map vs Object decision guide and `.Has()`/`.Get()` safe-access patterns referenced in TIER 6.
- `Module_SystemAndCOM.md` — COM object lifecycle, `ComCall` error handling, and HRESULT propagation patterns.
- `Module_FileSystem.md` — FileOpen/FileRead exception patterns, encoding errors, and file-handle lifecycle management.

## ERROR DIAGNOSTIC CHECKLIST

**Immediate checks** when encountering any error:
1. Check `#Requires` directive is present and correct
2. Verify all assignments use `:=` not `=`
3. Confirm all function calls have parentheses and quotes
4. Check all variables are initialized before use
5. Verify braces around multi-line blocks
6. Confirm comparison uses `==` not `=` (unless intentional case-insensitive)
7. Check for ByRef parameters needing `&`
8. Verify object properties have proper names
9. Ensure no space before function parentheses
10. Check `A_` prefix on built-in variables
11. Verify return statements are on single lines
12. Confirm fat-arrow functions are single-line only
13. Check callback binding with `.Bind(this)`
14. Verify `try/catch` around risky operations
15. Ensure classes instantiated without `new` keyword

**Scope checks** for variable-related errors:
1. Check if variable is declared in correct scope
2. Verify `global` declarations in functions/hotkeys
3. Confirm variable initialization before use
4. Check for variable name typos

**Syntax checks** for syntax errors:
1. Verify v2 function syntax (not v1 commands)
2. Check proper string quoting
3. Confirm proper loop syntax
4. Verify hotkey context syntax (`#HotIf` not `#If`)
5. Check GUI object syntax (not legacy commands)

## TIER 8 — Library and Method Errors
> METHODS COVERED: `#Include <Array>` · `#Include <JSON>` · `.Join()` · `.Filter()` · `.Map()` · `JSON.Load()` · `JSON.Dump()` · `Map.Keys()`

Library-dependent methods are among the most common sources of LLM-generated errors. AHK v2 arrays have no built-in `.Join()`, `.Filter()`, or `.Map()` — these require `#Include <Array>`. JSON methods use `JSON.Load()` / `JSON.Dump()`, not JavaScript's `.parse()` / `.stringify()`. Map objects have no `.Keys()` method — use a `for` loop instead.

```ahk
; ✗ Missing library include — Array has no built-in .Join()
arr := [1, 2, 3]
result := arr.Join(",")  ; → MethodError: no method named 'Join'

; ✓ Include the library first
#Include <Array>
arr := [1, 2, 3]
result := arr.Join(",")  ; Works with Array.ahk loaded

; ✗ JavaScript-style method names — wrong casing
arr.join(",")       ; → should be .Join()
arr.filter(fn)      ; → should be .Filter()
arr.map(fn)         ; → should be .Map()
json.parse(str)     ; → should be JSON.Load()

; ✓ AHK v2 method names use PascalCase
arr.Join(",")
arr.Filter(fn)
arr.Map(fn)
JSON.Load(str)

; ✗ Map.Keys() does not exist
myMap := Map("a", 1, "b", 2)
keys := myMap.Keys()  ; → MethodError

; ✓ Use for-loop iteration
keys := []
for key in myMap
    keys.Push(key)

; ✓ Or extend prototype if needed frequently
Map.Prototype.DefineProp("Keys", {
    Call: (this) {
        arr := []
        for k in this
            arr.Push(k)
        return arr
    }
})

; ✗ JavaScript JSON method names
data := JSON.parse(jsonString)     ; → wrong method name
output := JSON.stringify(obj)      ; → wrong method name

; ✓ AHK v2 JSON library methods
#Include <JSON>
data := JSON.Load(jsonString)      ; Parse JSON string to object
output := JSON.Dump(obj)           ; Convert object to JSON string
```