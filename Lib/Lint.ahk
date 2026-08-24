#Requires AutoHotkey v2.1-alpha.30

#Include %A_LineFile%\..\TreeSitter.ahk

/**
 * Lint.ahk — a structural AHK v2 linter built on TreeSitter.ahk.
 *
 * Instead of regex over text (which trips on comments, strings, and nesting),
 * each rule matches the *shape* of the syntax tree, so it only fires on real
 * code constructs. Parse once, walk once, collect issues:
 *
 *   for iss in Lint.Run(FileRead("MyScript.ahk", "UTF-8"))
 *       Print(iss.ToString())
 *
 *   Print(Lint.Format(Lint.File("C:\path\MyScript.ahk")))   ; ready-made report
 *
 * Rules (each a LintIssue with .Rule / .Severity / .Message / .Line / .Col):
 *
 *   empty-catch         (warning) — a catch block with no body swallows errors.
 *   unreachable-code    (warning) — a statement after return/throw/break/continue.
 *   assign-in-condition (warning) — ':=' inside an if/while condition (meant '='?).
 *   empty-function      (info)    — a function/method with an empty body.
 *   long-function       (info)    — a function/method over opts["maxLines"] lines.
 *   todo-comment        (info)    — TODO / FIXME / HACK / XXX left in a comment.
 *
 * Opts is a Map; pass any subset to override the defaults (all rules on,
 * maxLines := 60). Set a rule key to false to disable it, e.g.
 * Lint.Run(src, Map("todo", false, "maxLines", 40)).
 *
 * .Line is 1-based. .Col is a 1-based UTF-8 BYTE column (tree-sitter's unit) — on
 * lines with multibyte characters it will not equal an AHK SubStr() index.
 *
 * The grammar is intentionally more permissive than the interpreter, so Lint
 * reports style/structure problems, not a full semantic check — pair it with the
 * real interpreter's /validate for syntax/semantic errors. Heavily broken source
 * can produce ERROR nodes that suppress some rules in the damaged region.
 */

class LintError extends Error {
}

/**
 * One linter finding. ToString() renders an aligned `line:col severity message
 * (rule)` row suitable for a console report.
 */
class LintIssue {
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

class Lint {
    static Version := "1.0.0"

    ; Every rule on; functions longer than maxLines flagged. Callers override a
    ; subset by passing a Map to Run/File.
    static _Defaults() {
        o := Map()
        o["maxLines"] := 60
        o["emptyCatch"] := true
        o["unreachable"] := true
        o["assignInCondition"] := true
        o["emptyFunction"] := true
        o["longFunction"] := true
        o["todo"] := true
        return o
    }

    ; Statements that make whatever follows them in the same block unreachable.
    static _Terminal := Lint._TermSet()
    static _TermSet() {
        m := Map()
        m["return_statement"] := true
        m["throw_statement"] := true
        m["break_statement"] := true
        m["continue_statement"] := true
        return m
    }

    /** Lint a file by path. Reads it as UTF-8 and delegates to Run. */
    static File(path, opts := unset) {
        if !FileExist(path)
            throw LintError("File not found: " path, -1)
        src := FileRead(path, "UTF-8")
        return IsSet(opts) ? Lint.Run(src, opts) : Lint.Run(src)
    }

    /**
     * Parse `source` and return an array of LintIssue, sorted by line then column.
     */
    static Run(source, opts := unset) {
        cfg := Lint._Defaults()
        if IsSet(opts) {
            for k, v in opts
                cfg[k] := v
        }
        issues := []
        tree := TreeSitter.Parse(source)
        tree.Root.Walk(Visit)
        return Lint._Sort(issues)

        Visit(node, depth) {
            t := node.Type
            if (t = "catch_clause" && cfg["emptyCatch"]) {
                blk := Lint._DirectChild(node, "block")
                if (blk && blk.NamedChildCount = 0)
                    issues.Push(LintIssue("empty-catch", "warning"
                        , "Empty catch block silently swallows the error."
                        , node.StartRow + 1, node.StartCol + 1))
            } else if (t = "function_declaration" || t = "method_declaration") {
                name := Lint._NameOf(node)
                blk := Lint._BodyBlock(node)
                if (cfg["emptyFunction"] && blk && blk.NamedChildCount = 0)
                    issues.Push(LintIssue("empty-function", "info"
                        , "Function '" name "' has an empty body."
                        , node.StartRow + 1, node.StartCol + 1))
                if cfg["longFunction"] {
                    span := node.EndRow - node.StartRow + 1
                    if (span > cfg["maxLines"])
                        issues.Push(LintIssue("long-function", "info"
                            , "Function '" name "' is " span " lines (over " cfg["maxLines"] ")."
                            , node.StartRow + 1, node.StartCol + 1))
                }
            } else if (t = "block" && cfg["unreachable"]) {
                ; KNOWN LIMITATION: when a brace-less if/loop condition contains
                ; '&' (ambiguous with address-of), the grammar attributes the
                ; body's `return` to this block instead of the conditional, so a
                ; plain `if x & FLAG` guard clause reads as dead code. Node
                ; columns come back as 0 here, so indentation can't disambiguate
                ; it either. The rule is off by default in the post-edit hook
                ; (.claude/hooks/lint-runner.ahk) until the grammar is fixed.
                seenAt := ""
                for child in node.NamedChildren() {
                    ; Nested function/class declarations are hoisted, not run in
                    ; sequence. Declaring a closure helper below the block's
                    ; `return` is the idiomatic v2 pattern, not dead code.
                    if (child.Type = "function_declaration"
                        || child.Type = "method_declaration"
                        || child.Type = "class_declaration")
                        continue
                    if (seenAt != "") {
                        issues.Push(LintIssue("unreachable-code", "warning"
                            , "Code after a " seenAt " is unreachable."
                            , child.StartRow + 1, child.StartCol + 1))
                        break
                    }
                    if Lint._Terminal.Has(child.Type)
                        seenAt := StrReplace(child.Type, "_statement")
                }
            } else if ((t = "if_statement" || t = "while_statement") && cfg["assignInCondition"]) {
                cond := Lint._ConditionOf(node)
                if cond {
                    hit := Lint._FindAssign(cond)
                    if hit
                        issues.Push(LintIssue("assign-in-condition", "warning"
                            , "Assignment ':=' inside a condition — did you mean '=' (compare)?"
                            , hit.StartRow + 1, hit.StartCol + 1))
                }
            } else if ((t = "line_comment" || t = "block_comment") && cfg["todo"]) {
                if RegExMatch(node.Text, "i)\b(TODO|FIXME|HACK|XXX)\b", &m)
                    issues.Push(LintIssue("todo-comment", "info"
                        , "Unresolved marker: " StrUpper(m[1])
                        , node.StartRow + 1, node.StartCol + 1))
            }
            return true
        }
    }

    /** Render issues as a newline-joined report; a friendly line when empty. */
    static Format(issues) {
        if !issues.Length
            return "No issues found."
        out := ""
        for iss in issues
            out .= iss.ToString() "`n"
        return RTrim(out, "`n")
    }

    /** Count issues by severity → Map("error"|"warning"|"info" => count). */
    static Summary(issues) {
        m := Map()
        m["error"] := 0, m["warning"] := 0, m["info"] := 0
        for iss in issues
            m[iss.Severity] := m.Get(iss.Severity, 0) + 1
        return m
    }

    ; First direct named child of a given type, or "" (falsy) if none.
    static _DirectChild(node, type) {
        for child in node.NamedChildren()
            if (child.Type = type)
                return child
        return ""
    }

    ; The block that holds a function/method body (function_body → block), or "".
    static _BodyBlock(node) {
        body := Lint._DirectChild(node, "function_body")
        return body ? Lint._DirectChild(body, "block") : ""
    }

    ; A function/method's declared name (its first identifier child), or "?".
    static _NameOf(node) {
        id := Lint._DirectChild(node, "identifier")
        return id ? id.Text : "?"
    }

    ; The condition node of an if/while — the named child right after the keyword.
    ; The grammar wraps an `if` condition in expression_sequence but leaves a
    ; `while` condition bare, so isolate by position rather than by node type
    ; (and never reach into the body, where a real ':=' is fine).
    static _ConditionOf(node) {
        kids := node.NamedChildren()
        idx := (kids.Length >= 1 && (kids[1].Type = "if" || kids[1].Type = "while")) ? 2 : 1
        return kids.Length >= idx ? kids[idx] : ""
    }

    ; First assignment_operation anywhere in a subtree (used to scan a condition),
    ; or "" if none.
    static _FindAssign(node) {
        if (node.Type = "assignment_operation")
            return node
        for child in node.NamedChildren() {
            hit := Lint._FindAssign(child)
            if hit
                return hit
        }
        return ""
    }

    ; Stable-enough insertion sort by line then column (issue counts are small).
    static _Sort(arr) {
        loop arr.Length {
            i := A_Index
            while (i > 1) {
                a := arr[i - 1], b := arr[i]
                if (a.Line < b.Line || (a.Line = b.Line && a.Col <= b.Col))
                    break
                arr[i - 1] := b, arr[i] := a
                i -= 1
            }
        }
        return arr
    }
}
