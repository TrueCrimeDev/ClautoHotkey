#Requires AutoHotkey v2.1-alpha.30

#Include %A_LineFile%\..\TreeSitter.ahk

/**
 * CodeIntel.ahk — a scope-aware semantic analyzer for AutoHotkey v2, built on
 * TreeSitter.ahk. Where Lint.ahk matches surface patterns, this builds the model
 * an IDE language server runs on: a scope tree, a symbol table (every definition
 * and every reference), and a call graph — then answers questions about them.
 *
 *   intel := CodeIntel.File("C:\path\MyScript.ahk")
 *   intel.Callers("Parse")          ; functions that call Parse()
 *   intel.Callees("Main")           ; functions Main() calls
 *   intel.References("total")       ; every read of `total`, with line:col
 *   intel.Definition("Greet")       ; the CISymbol where Greet is defined
 *   for iss in intel.Diagnostics()  ; unused functions/locals, calls to unknowns
 *       Print(iss.ToString())
 *
 * The query side (Definition / References / Callers / Callees / CallGraph) is
 * exact for the constructs the grammar resolves. The diagnostics are static
 * heuristics — AHK resolves names dynamically (`%name%()`, `Func()` objects,
 * super-globals, dynamic properties), so treat findings as leads, not proof.
 *
 * Scope model: a global scope, a child scope per function/method, and a class
 * scope per class. AHK is assume-local, so a bare assignment inside a function
 * defines a local; `global`/`static`/`local` declarations are honored. Function
 * names resolve globally (AHK hoists them). Identifiers are case-insensitive,
 * matching AHK. `this`/`super` and `A_*` builtins are known and never flagged.
 *
 * Known limits (documented, not bugs): nested-function / fat-arrow closure
 * capture of outer locals is not modeled (a nested function's scope parents to
 * global); method calls resolve by name across all classes (no receiver typing);
 * dynamic dispatch and dynamically-built names are invisible to static analysis.
 */

class CodeIntelError extends Error {
}

/** A semantic finding (unused symbol, call to an unknown, …). */
class CIIssue {
    __New(rule, severity, message, line, col) {
        this.Rule := rule
        this.Severity := severity
        this.Message := message
        this.Line := line
        this.Col := col
    }
    ToString() {
        return Format("{1:4}:{2:-3} {3:-8} {4} ({5})"
            , this.Line, this.Col, this.Severity, this.Message, this.Rule)
    }
}

/** A named entity: variable, param, function, method, class, or scope decl. */
class CISymbol {
    __New(name, kind, scope) {
        this.Name := name
        this.Kind := kind                 ; variable|param|function|method|class|global|static
        this.Scope := scope
        this.Defs := []                   ; [{line,col}] definition sites
        this.Refs := []                   ; [{line,col}] read sites
        this.OutCalls := []               ; for functions: [{name,line,col,method?}] it calls
        this.InCalls := []                ; for functions: [callerName] resolved callers
    }
    DefLine => this.Defs.Length ? this.Defs[1].line : 0
    DefCol => this.Defs.Length ? this.Defs[1].col : 0
    ; Total uses = read references + resolved inbound calls (for functions).
    UseCount => this.Refs.Length + this.InCalls.Length
}

/** A lexical scope holding a case-insensitive name→CISymbol table. */
class CIScope {
    __New(name, kind, parent := "") {
        this.Name := name
        this.Kind := kind                 ; global|function|method|class
        this.Parent := parent
        this.Children := []
        this.Symbols := Map()
        this.Symbols.CaseSense := false   ; AHK identifiers are case-insensitive
        this.OwnerFunc := ""              ; the function/method CISymbol this scope is the body of
    }

    ; Define (or fetch-and-extend) a symbol in THIS scope.
    Define(name, kind, line, col, isDef := true) {
        if this.Symbols.Has(name) {
            sym := this.Symbols[name]
        } else {
            sym := CISymbol(name, kind, this)
            this.Symbols[name] := sym
        }
        if isDef
            sym.Defs.Push({ line: line, col: col })
        return sym
    }

    ; Find a symbol by name in this scope or any ancestor; "" if unresolved.
    Lookup(name) {
        s := this
        while s {
            if s.Symbols.Has(name)
                return s.Symbols[name]
            s := s.Parent
        }
        return ""
    }
}

class CodeIntel {
    static Version := "1.0.0"
    static _MemberCache := ""         ; built-in member sets, built once per process
    static _GetOwnPropDesc := Object.Prototype.GetOwnPropDesc

    /** Analyze a file by path. */
    static File(path) {
        if !FileExist(path)
            throw CodeIntelError("File not found: " path, -1)
        return CodeIntel(FileRead(path, "UTF-8"))
    }

    __New(source) {
        this.Global := CIScope("(global)", "global")
        this.AllScopes := [this.Global]
        this.Calls := []                  ; flat [{caller,name,line,col,method}] for the call graph
        this._BuildBuiltins()
        this._BuildMemberSets()
        tree := TreeSitter.Parse(source)
        this.HasParseError := tree.Root.HasError
        for child in tree.Root.NamedChildren()
            this._Visit(child, this.Global)
        this._ResolveCalls()
    }

    ; Recursive descent. Definitions happen only in specific syntactic positions;
    ; every other bare identifier reached here is a read reference.
    _Visit(node, scope) {
        switch node.Type {
            case "function_declaration", "method_declaration":
                this._VisitFunction(node, scope)
            case "class_declaration":
                this._VisitClass(node, scope)
            case "for_statement":
                this._VisitFor(node, scope)
            case "variable_declaration":
                this._VisitDeclaration(node, scope)
            case "assignment_operation":
                this._VisitAssignment(node, scope)
            case "member_access":
                ; object is a read; the member name is a property, not a free var
                kids := node.NamedChildren()
                if kids.Length >= 1
                    this._Visit(kids[1], scope)
            case "function_call":
                this._VisitCall(node, scope)
            case "identifier":
                this._Reference(node, scope)
            default:
                for child in node.NamedChildren()
                    this._Visit(child, scope)
        }
    }

    _VisitFunction(node, scope) {
        kids := node.NamedChildren()
        kind := (node.Type = "method_declaration") ? "method" : "function"
        id := (kids.Length >= 1 && kids[1].Type = "identifier")
            ? CodeIntel._Ident(kids[1])
            : { name: "?", line: node.StartRow + 1, col: node.StartCol + 1 }
        name := id.name
        sym := scope.Define(name, kind, id.line, id.col)
        funcScope := CIScope(name, kind = "method" ? "method" : "function", scope)
        funcScope.OwnerFunc := sym
        this.AllScopes.Push(funcScope)
        for k in kids {
            if k.Type = "function_head"
                this._BindParams(k, funcScope)
            else if k.Type = "function_body"
                for stmt in k.NamedChildren()
                    this._Visit(stmt, funcScope)
        }
    }

    _BindParams(head, funcScope) {
        for ps in head.NamedChildren() {
            if ps.Type != "param_sequence"
                continue
            for p in ps.NamedChildren() {
                if p.Type = "identifier" {
                    pid := CodeIntel._Ident(p)
                    funcScope.Define(pid.name, "param", pid.line, pid.col)
                } else if p.Type = "assignment_operation" {
                    pk := p.NamedChildren()
                    if (pk.Length >= 1 && pk[1].Type = "identifier") {
                        pid := CodeIntel._Ident(pk[1])
                        funcScope.Define(pid.name, "param", pid.line, pid.col)
                    }
                    if pk.Length >= 1                       ; default value is a read
                        for i, sub in pk
                            if (i > 1)
                                this._Visit(sub, funcScope)
                } else {
                    this._Visit(p, funcScope)               ; &ref / variadic wrappers — recover reads
                }
            }
        }
    }

    _VisitClass(node, scope) {
        kids := node.NamedChildren()
        name := ""
        for k in kids {
            if (name = "" && k.Type = "identifier") {
                id := CodeIntel._Ident(k)
                name := id.name
                scope.Define(name, "class", id.line, id.col)
            }
        }
        classScope := CIScope(name, "class", scope)
        this.AllScopes.Push(classScope)
        for k in kids {
            if k.Type = "class_body"
                for member in k.NamedChildren()
                    this._Visit(member, classScope)
        }
    }

    ; for k, v in expr  →  k and v are defs in the current scope (the loop vars are
    ; the identifiers before the `in` node); everything after `in` is a read/body.
    _VisitFor(node, scope) {
        kids := node.NamedChildren()
        pastIn := false
        for k in kids {
            if k.Type = "in" {
                pastIn := true
                continue
            }
            if k.Type = "for"
                continue
            if !pastIn {
                if k.Type = "identifier" {
                    id := CodeIntel._Ident(k)
                    scope.Define(id.name, "variable", id.line, id.col)
                }
            } else {
                this._Visit(k, scope)
            }
        }
    }

    ; A standalone `global x` / `static y` / `local z` declaration.
    _VisitDeclaration(node, scope) {
        kids := node.NamedChildren()
        kindWord := ""
        for k in kids {
            if k.Type = "scope_identifier"
                kindWord := Trim(StrLower(k.Text), " `t`r`n")
            else if k.Type = "identifier" {
                id := CodeIntel._Ident(k)
                scope.Define(id.name, InStr(kindWord, "static") ? "static" : kindWord, id.line, id.col)
            }
        }
    }

    _VisitAssignment(node, scope) {
        kids := node.NamedChildren()
        if !kids.Length
            return
        lhs := kids[1]
        if lhs.Type = "identifier" {
            ; bare assignment → assume-local definition (or write to an existing symbol)
            id := CodeIntel._Ident(lhs)
            scope.Define(id.name, "variable", id.line, id.col)
        } else if lhs.Type = "variable_declaration" {
            this._VisitDeclaration(lhs, scope)
        } else {
            this._Visit(lhs, scope)             ; member/indexed target → reads only
        }
        ; RHS and operator: recurse everything after the LHS as reads
        for i, k in kids
            if (i > 1 && k.Type != "assignment_operator")
                this._Visit(k, scope)
    }

    _VisitCall(node, scope) {
        kids := node.NamedChildren()
        if !kids.Length
            return
        callee := kids[1]
        caller := this._EnclosingFunc(scope)
        callerName := caller ? caller.Name : "(global)"
        if callee.Type = "identifier" {
            id := CodeIntel._Ident(callee)
            rec := { caller: callerName, name: id.name, line: id.line, col: id.col, method: false }
            this.Calls.Push(rec)
            if caller
                caller.OutCalls.Push(rec)
        } else if callee.Type = "member_access" {
            mk := callee.NamedChildren()
            if mk.Length >= 1
                this._Visit(mk[1], scope)       ; receiver is a read
            if mk.Length >= 2 {
                id := CodeIntel._Ident(mk[2])
                rec := { caller: callerName, name: id.name, line: id.line, col: id.col, method: true }
                this.Calls.Push(rec)
                if caller
                    caller.OutCalls.Push(rec)
            }
        } else {
            this._Visit(callee, scope)
        }
        for i, k in kids
            if (i > 1)
                this._Visit(k, scope)            ; arguments are reads
    }

    _Reference(node, scope) {
        id := CodeIntel._Ident(node)
        if this._IsBuiltin(id.name)
            return
        site := { line: id.line, col: id.col }
        sym := scope.Lookup(id.name)
        if sym
            sym.Refs.Push(site)
        else
            scope.Define(id.name, "variable", id.line, id.col, false).Refs.Push(site)
    }

    ; Nearest enclosing function/method symbol, walking up the scope chain; "".
    _EnclosingFunc(scope) {
        s := scope
        while s {
            if s.OwnerFunc
                return s.OwnerFunc
            s := s.Parent
        }
        return ""
    }

    ; Match each call to a declared function/method by name and wire the edges.
    _ResolveCalls() {
        byName := Map()
        byName.CaseSense := false
        for s in this.AllScopes
            for name, sym in s.Symbols
                if (sym.Kind = "function" || sym.Kind = "method")
                    byName[name] := sym
        for c in this.Calls {
            if byName.Has(c.name) {
                target := byName[c.name]
                target.InCalls.Push(c.caller)
            }
        }
    }

    ; -- Queries ---------------------------------------------------------------

    /** All symbols across every scope, flattened. */
    Symbols() {
        out := []
        for s in this.AllScopes
            for name, sym in s.Symbols
                out.Push(sym)
        return out
    }

    /** Function and method symbols only. */
    Functions() {
        out := []
        for sym in this.Symbols()
            if (sym.Kind = "function" || sym.Kind = "method")
                out.Push(sym)
        return out
    }

    /** First symbol defined under `name` (any scope), or "". */
    Definition(name) {
        for sym in this.Symbols()
            if (StrLower(sym.Name) = StrLower(name) && sym.Defs.Length)
                return sym
        return ""
    }

    /** Every read reference of `name`, as [{line,col}], across scopes. */
    References(name) {
        out := []
        for sym in this.Symbols()
            if (StrLower(sym.Name) = StrLower(name))
                for r in sym.Refs
                    out.Push(r)
        return out
    }

    /** Names of functions that call `name` (deduped). */
    Callers(name) {
        seen := Map(), seen.CaseSense := false
        out := []
        for c in this.Calls
            if (StrLower(c.name) = StrLower(name) && !seen.Has(c.caller))
                seen[c.caller] := true, out.Push(c.caller)
        return out
    }

    /** Names of functions/methods that `name` calls (deduped). */
    Callees(name) {
        seen := Map(), seen.CaseSense := false
        out := []
        for c in this.Calls
            if (StrLower(c.caller) = StrLower(name) && !seen.Has(c.name))
                seen[c.name] := true, out.Push(c.name)
        return out
    }

    /** Map(functionName → [callee names]) for the whole program. */
    CallGraph() {
        g := Map(), g.CaseSense := false
        for c in this.Calls {
            if !g.Has(c.caller)
                g[c.caller] := []
            arr := g[c.caller]
            dup := false
            for n in arr
                if (StrLower(n) = StrLower(c.name))
                    dup := true
            if !dup
                arr.Push(c.name)
        }
        return g
    }

    /**
     * Static diagnostics. opts (Map) toggles rules:
     *   unusedFunction (default true)  — a function never referenced or called.
     *   unusedLocal    (default true)  — a function-local var assigned, never read.
     *   undefinedCall  (default true)  — a direct call to an unknown name (heuristic).
     *   propertyCalledAsMethod (default true) — `arr.Length()`, where the name is
     *                                  a built-in property, never a method.
     *   unknownMember  (default false) — `arr.Join()`, where no built-in type and
     *                                  no class in this file defines the member.
     *                                  Off by default: a receiver reached through
     *                                  #Include, COM or ComObject is invisible
     *                                  here, so this over-reports on files that
     *                                  call into other units. Turn it on for
     *                                  self-contained files — grading candidates,
     *                                  single-file tools — where it is exact.
     * Returns CIIssue[] sorted by line.
     */
    Diagnostics(opts := unset) {
        cfg := Map()
        cfg["unusedFunction"] := true, cfg["unusedLocal"] := true, cfg["undefinedCall"] := true
        cfg["propertyCalledAsMethod"] := true, cfg["unknownMember"] := false
        if IsSet(opts)
            for k, v in opts
                cfg[k] := v
        issues := []

        if cfg["unusedFunction"] {
            for sym in this.Functions() {
                ; only top-level (global-scope) functions — methods dispatch dynamically
                if (sym.Kind = "function" && sym.Scope.Kind = "global" && sym.UseCount = 0)
                    issues.Push(CIIssue("unused-function", "info"
                        , "Function '" sym.Name "' is never called.", sym.DefLine, sym.DefCol))
            }
        }

        if cfg["unusedLocal"] {
            for s in this.AllScopes {
                if (s.Kind != "function" && s.Kind != "method")
                    continue
                for name, sym in s.Symbols {
                    if (sym.Kind = "variable" && sym.Defs.Length && sym.Refs.Length = 0)
                        issues.Push(CIIssue("unused-local", "info"
                            , "Local '" sym.Name "' in '" s.Name "' is assigned but never read."
                            , sym.DefLine, sym.DefCol))
                }
            }
        }

        if cfg["undefinedCall"] {
            known := Map(), known.CaseSense := false
            ; Classes count as callable: `Widget()` is instantiation, not an
            ; undefined function. Building this from Functions() alone reported
            ; every class in the file as undefined — 364 of 967 findings on the
            ; .ai corpus, one name (ButtonWrap) accounting for 113 of them.
            for sym in this.Symbols()
                if (sym.Kind = "function" || sym.Kind = "method" || sym.Kind = "class")
                    known[sym.Name] := true
            for c in this.Calls {
                if (!c.method && !known.Has(c.name) && !this._IsBuiltin(c.name))
                    issues.Push(CIIssue("undefined-call", "warning"
                        , "Call to '" c.name "' — no such function defined (or it's dynamic/external).", c.line, c.col))
            }
        }

        if (cfg["unknownMember"] || cfg["propertyCalledAsMethod"]) {
            declared := this._FileMembers()
            for c in this.Calls {
                if !c.method
                    continue
                if (declared.Has(c.name) || this._BuiltinMethods.Has(c.name))
                    continue
                if this._BuiltinProps.Has(c.name) {
                    ; The name exists, but as a property: `arr.Length()` throws
                    ; where `arr.Length` is what was meant.
                    if cfg["propertyCalledAsMethod"]
                        issues.Push(CIIssue("property-called-as-method", "warning"
                            , "'" c.name "' is a property on the built-in types, not a method — "
                            . "did you mean '." c.name "' without the call?", c.line, c.col))
                } else if cfg["unknownMember"] {
                    issues.Push(CIIssue("unknown-member", "warning"
                        , "Call to '." c.name "()' — no built-in type or class in this file "
                        . "defines it (or the receiver is external/dynamic).", c.line, c.col))
                }
            }
        }

        ; insertion sort by line then col
        loop issues.Length {
            i := A_Index
            while (i > 1) {
                a := issues[i - 1], b := issues[i]
                if (a.Line < b.Line || (a.Line = b.Line && a.Col <= b.Col))
                    break
                issues[i - 1] := b, issues[i] := a
                i -= 1
            }
        }
        return issues
    }

    /** Render Diagnostics() (or any CIIssue[]) as a report. */
    static Format(issues) {
        if !issues.Length
            return "No issues found."
        out := ""
        for iss in issues
            out .= iss.ToString() "`n"
        return RTrim(out, "`n")
    }

    ; -- Internals -------------------------------------------------------------

    ; Identifier name + position, robust to the grammar folding leading whitespace
    ; into a non-first statement's first token (its .Text then carries the indent
    ; and .StartCol is 0). Identifiers never contain whitespace, so trimming is
    ; safe; the reported column is shifted past the trimmed lead.
    static _Ident(node) {
        raw := node.Text
        lead := StrLen(raw) - StrLen(LTrim(raw, " `t`r`n"))
        return { name: Trim(raw, " `t`r`n"), line: node.StartRow + 1, col: node.StartCol + lead + 1 }
    }

    _IsBuiltin(name) {
        if SubStr(name, 1, 2) = "A_"            ; A_Index, A_ScriptDir, …
            return true
        return this._Builtins.Has(name)
    }

    _BuildBuiltins() {
        this._Builtins := Map()
        this._Builtins.CaseSense := false
        for n in StrSplit(
            "true,false,unset,this,super,MsgBox,Print,Eval,Send,SendText,SendInput,Sleep,Click,"
            . "StrLen,SubStr,InStr,Format,Trim,LTrim,RTrim,StrReplace,StrSplit,StrUpper,StrLower,"
            . "RegExMatch,RegExReplace,Ord,Chr,Round,Floor,Ceil,Abs,Mod,Min,Max,Sqrt,Exp,Ln,Log,"
            . "Sin,Cos,Tan,ASin,ACos,ATan,Random,Sort,Type,IsObject,IsSet,IsInteger,IsNumber,"
            . "IsFloat,IsAlpha,IsAlnum,IsDigit,IsSpace,IsUpper,IsLower,IsTime,Integer,Float,String,"
            . "Number,Map,Array,Object,Buffer,Gui,Menu,MenuBar,ComObject,ComValue,ComCall,DllCall,"
            . "CallbackCreate,CallbackFree,NumGet,NumPut,StrGet,StrPut,VarSetStrCapacity,ObjBindMethod,"
            . "GetMethod,HasMethod,HasProp,ObjGetBase,ObjSetBase,ObjOwnProps,ObjHasOwnProp,"
            . "FileRead,FileAppend,FileOpen,FileDelete,FileExist,FileMove,FileCopy,FileGetTime,"
            . "DirExist,DirCreate,DirDelete,SplitPath,A_Clipboard,Hotkey,Hotstring,SetTimer,OnExit,"
            . "OnError,OnMessage,OnClipboardChange,GetKeyState,KeyWait,MouseMove,MouseClick,MouseGetPos,"
            . "WinExist,WinActive,WinActivate,WinWait,WinWaitActive,WinClose,WinKill,WinShow,WinHide,"
            . "WinGetTitle,WinGetID,WinGetPos,WinGetClass,WinSetTitle,WinMove,ControlSend,ControlGetText,"
            . "ControlSetText,ControlClick,SendMessage,PostMessage,ProcessExist,ProcessClose,ProcessWait,"
            . "Run,RunWait,ExitApp,Exit,Reload,Persistent,SetWorkingDir,EnvGet,EnvSet,SysGet,"
            . "Tooltip,TrayTip,InputBox,FileSelect,DirSelect,SetCapsLockState,Critical,Thread,"
            . "GuiCtrlFromHwnd,GuiFromHwnd,WinGetText,ControlGetFocus,ComObjGet,ComObjActive,ComObjConnect,"
            ; The error classes were missing entirely, so every `throw ValueError(...)`
            ; read as a call to nothing. These names were measured against the .ai
            ; corpus — 194 findings across 17 of them.
            . "Error,ValueError,TypeError,MemoryError,OSError,TargetError,TimeoutError,UnsetError,"
            . "UnsetItemError,ZeroDivisionError,IndexError,KeyError,MethodError,PropertyError,"
            . "OutputDebug,FileGetSize,FileGetAttrib,FileSetAttrib,FileGetVersion,FileSetTime,"
            . "DirMove,DirCopy,StrCompare,StrTitle,StrPtr,VerCompare,DateAdd,DateDiff,FormatTime,"
            . "ClipWait,ClipboardAll,MonitorGet,MonitorGetCount,MonitorGetWorkArea,MonitorGetPrimary,"
            . "HotIf,HotIfWinActive,HotIfWinExist,WinGetPID,WinGetProcessName,WinGetProcessPath,"
            . "WinGetMinMax,WinGetStyle,WinGetExStyle,WinGetList,WinGetCount,WinGetControls,"
            . "WinGetControlsHwnd,WinRestore,WinMinimize,WinMaximize,WinWaitClose,WinSetEnabled,"
            . "ControlGetPos,ControlGetHwnd,ControlGetChecked,ControlGetItems,ControlChooseIndex,"
            . "ControlGetIndex,EditGetLine,ListViewGetContent,StatusBarGetText,Download,FileInstall,"
            . "FileEncoding,FileCreateShortcut,FileRecycle,IniRead,IniWrite,IniDelete,RegRead,"
            . "RegWrite,RegDelete,RegCreateKey,ProcessSetPriority,TraySetIcon,SetKeyDelay,"
            . "SetMouseDelay,SetWinDelay,SetControlDelay,SetTitleMatchMode,DetectHiddenWindows,"
            . "DetectHiddenText,CoordMode,BlockInput,SoundBeep,SoundPlay,PixelGetColor,PixelSearch,"
            . "ImageSearch,CaretGetPos,InputHook,Func,ObjPtr,ObjAddRef,ObjRelease,ObjGetDataPtr,"
            . "ObjOwnPropCount,SendLevel,SendMode,InstallKeybdHook,InstallMouseHook,StrPut"
            , ",")
            this._Builtins[n] := true
    }

    ; Member names of the built-in types, read off the running interpreter rather
    ; than hand-listed, so the sets cannot drift from the binary being analyzed.
    ; Methods and properties are kept apart: `arr.Length` is legal, `arr.Length()`
    ; is not, and only the split tells those two apart.
    _BuildMemberSets() {
        ; The interpreter's own type set is fixed for the life of the process, so
        ; this is built once and shared; analyzing a tree of files otherwise pays
        ; the whole prototype walk per file.
        if CodeIntel._MemberCache {
            this._BuiltinMethods := CodeIntel._MemberCache.methods
            this._BuiltinProps := CodeIntel._MemberCache.props
            return
        }
        this._BuiltinMethods := Map(), this._BuiltinMethods.CaseSense := false
        this._BuiltinProps := Map(), this._BuiltinProps.CaseSense := false
        ; Any is the root of the type tree and carries HasProp/HasMethod/GetMethod/
        ; HasBase — omitting it reported those four on every object in the repo.
        types := [Any, Object, Primitive, String, Number, Integer, Float, VarRef
                , Array, Map, Buffer, Error, Func, Class, File, Menu, MenuBar
                , Gui, RegExMatchInfo, InputHook, ComValue, ComObject]
        ; Gui's control classes carry OnEvent/Add/Value/Text — the most-called
        ; members in this repo. They are nested classes, not globals.
        for sub in ["Control", "Button", "CheckBox", "ComboBox", "DateTime", "Edit", "Hotkey"
                  , "Link", "ListBox", "ListView", "MonthCal", "Pic", "Progress", "Radio"
                  , "Slider", "StatusBar", "Tab", "Text", "TreeView", "UpDown"] {
            try types.Push(Gui.%sub%)
            catch as e
                continue                  ; control class absent on this build
        }
        for t in types {
            proto := ""
            try proto := t.Prototype
            catch as e
                continue                  ; not a class object
            ; Walk the base chain so inherited members count as known.
            while IsObject(proto) {
                names := []
                try names := [ObjOwnProps(proto)*]
                catch as e
                    break                 ; prototype refused enumeration
                for k in names {
                    ; Borrowed, not `proto.GetOwnPropDesc(k)`: Any.Prototype sits
                    ; above Object in the type tree and so has no such method —
                    ; calling it directly threw and silently dropped the root
                    ; type, reporting HasProp/HasMethod/GetMethod/HasBase as
                    ; unknown on every object in the repo.
                    desc := ""
                    try desc := CodeIntel._GetOwnPropDesc.Call(proto, k)
                    catch as e {
                        this._BuiltinProps[k] := true   ; exists; kind unknown
                        continue
                    }
                    if (IsObject(desc) && desc.HasProp("Call"))
                        this._BuiltinMethods[k] := true
                    else
                        this._BuiltinProps[k] := true
                }
                proto := ObjGetBase(proto) ?? 0
            }
        }
        CodeIntel._MemberCache := { methods: this._BuiltinMethods, props: this._BuiltinProps }
    }

    ; Member names this file declares itself — class methods, nested class names
    ; and class fields. A call to one of these is resolved, not unknown.
    _FileMembers() {
        out := Map(), out.CaseSense := false
        for sym in this.Symbols() {
            if (sym.Kind = "method" || sym.Kind = "class")
                out[sym.Name] := true
            else if (sym.Kind = "variable" && sym.Scope.Kind = "class")
                out[sym.Name] := true
        }
        return out
    }
}
