#Requires AutoHotkey v2.1-alpha.30

/**
 * TreeSitter.ahk — a native AutoHotkey v2 binding to tree-sitter, parsing AHK v2
 * source into a real concrete syntax tree at runtime, in-process.
 *
 * tree-sitter is the incremental, error-tolerant parser that powers Neovim, Zed,
 * and GitHub code navigation. Its grammars compile to a C library; this binding
 * DllCalls a bundled Windows x64 build of the tree-sitter runtime + the
 * holy-tao/tree-sitter-autohotkey grammar (`tree-sitter-ahk.dll`, next to this
 * file). So an AHK script can parse AHK — for linting, refactoring tools, code
 * analysis, macros, or self-inspection — without any external toolchain.
 *
 *   tree := TreeSitter.Parse(FileRead("MyScript.ahk"))
 *   tree.Root.Type                       ; "source_file"
 *   for node in tree.Root.NamedChildren()
 *       Print("{} @ line {}: {}", node.Type, node.StartRow + 1, node.Text)
 *   tree.Root.Walk(VisitNode)            ; pre-order traversal
 *   Print(tree.Root.Dump())              ; indented S-expression of the whole tree
 *
 * Nodes are cheap wrappers over tree-sitter's 32-byte node handles; .Text is
 * sliced from the original source the tree keeps alive. The grammar is
 * deliberately MORE permissive than the AutoHotkey interpreter (tree-sitter
 * parses partial/broken code on purpose) — use .HasError / .IsError to detect
 * problems, and the real interpreter to validate semantics.
 *
 * Positions are UTF-8 BYTE units: .StartByte/.EndByte are byte offsets into the
 * source, and .StartCol/.EndCol are byte columns within a line — NOT AutoHotkey
 * (UTF-16) string indices. On lines with multibyte characters they differ. Use
 * .Text to recover a node's exact substring; do not map .StartCol onto an AHK
 * SubStr() position directly.
 *
 * Out-of-range Child(i)/NamedChild(i) throw a TreeSitterError; Field(name)
 * returns a node or "" (falsy) when the field is absent — guard with
 * `if f := node.Field("x")`. A null node answers only .IsNull; any other access
 * throws rather than faulting in the DLL.
 *
 * Requires the bundled tree-sitter-ahk.dll (x64), searched next to this file
 * first, then the AutoHotkey bin folder, then the main script's folder.
 * Lifetime: a TSTree frees its
 * native tree on __Delete (normally at GC; its nodes keep it alive). Do not call
 * __Delete() explicitly while you still hold nodes — accessing them afterward
 * throws a clean error rather than reading freed memory.
 */

class TreeSitterError extends Error {
}

class TreeSitter {
    static Version := "1.0.0"
    static DllPath := RegExReplace(A_LineFile, "[^\\/]+$", "") "tree-sitter-ahk.dll"
    static _h := 0
    static _proc := Map()
    static _lang := 0
    static _parser := 0

    ; Initialized iff _parser is set. Commit the statics ONLY after every step
    ; succeeds; on any failure, roll back (FreeLibrary, clear the proc cache) so a
    ; retry re-runs the full init and re-surfaces the real error instead of a
    ; later opaque crash from a half-initialized class.
    static _Init() {
        if TreeSitter._parser
            return
        path := TreeSitter._ResolveDll()
        if !path
            throw TreeSitterError("tree-sitter-ahk.dll (x64) not found. Searched: " TreeSitter._SearchList() ". Put it next to TreeSitter.ahk or in the AutoHotkey bin folder.", -1)
        TreeSitter.DllPath := path
        h := DllCall("LoadLibrary", "Str", path, "Ptr")
        if !h
            throw TreeSitterError("Could not load '" path "' (err " A_LastError "). Ensure it is the x64 build.", -1)
        TreeSitter._h := h
        try {
            lang := TreeSitter._Call("tree_sitter_autohotkey", "Ptr")
            parser := TreeSitter._Call("ts_parser_new", "Ptr")
            if !parser
                throw TreeSitterError("ts_parser_new returned null.", -1)
            ok := TreeSitter._Call("ts_parser_set_language", "Ptr", parser, "Ptr", lang, "Char")
            if !ok
                throw TreeSitterError("ts_parser_set_language failed — grammar/runtime ABI mismatch.", -1)
        } catch as e {
            TreeSitter._proc := Map()
            DllCall("FreeLibrary", "Ptr", h)
            TreeSitter._h := 0
            throw e
        }
        TreeSitter._lang := lang
        TreeSitter._parser := parser
    }

    ; Candidate DLL locations, in priority order: next to this file (Lib\), the
    ; running AutoHotkey binary's folder (bin\), then the main script's folder.
    static _DllCandidates() {
        here := RegExReplace(A_LineFile, "[^\\/]+$", "")
        bin := RegExReplace(A_AhkPath, "[^\\/]+$", "")
        return [here "tree-sitter-ahk.dll", bin "tree-sitter-ahk.dll", A_ScriptDir "\tree-sitter-ahk.dll"]
    }
    static _ResolveDll() {
        for c in TreeSitter._DllCandidates()
            if FileExist(c)
                return c
        return ""
    }
    static _SearchList() {
        s := ""
        for c in TreeSitter._DllCandidates()
            s .= (s = "" ? "" : "; ") c
        return s
    }

    ; Resolve and cache a proc address, then DllCall it. Args are the usual
    ; DllCall type/value pairs followed by the return type.
    static _Call(name, args*) {
        proc := TreeSitter._proc.Has(name) ? TreeSitter._proc[name]
            : TreeSitter._proc[name] := DllCall("GetProcAddress", "Ptr", TreeSitter._h, "AStr", name, "Ptr")
        if !proc
            throw TreeSitterError("tree-sitter export '" name "' not found in the DLL.", -1)
        return DllCall(proc, args*)
    }

    /**
     * Parse AHK source into a TSTree. The tree keeps a UTF-8 copy of the source
     * so node .Text works; it frees the native tree when collected.
     */
    static Parse(source) {
        TreeSitter._Init()
        size := StrPut(source, "UTF-8")
        src := Buffer(size)
        StrPut(source, src, "UTF-8")
        byteLen := size - 1
        tree := TreeSitter._Call("ts_parser_parse_string"
            , "Ptr", TreeSitter._parser, "Ptr", 0, "Ptr", src, "UInt", byteLen, "Ptr")
        if !tree
            throw TreeSitterError("ts_parser_parse_string returned null.", -1)
        return TSTree(tree, src, byteLen)
    }
}

class TSTree {
    __New(treePtr, src, byteLen) {
        this._ptr := treePtr
        this._src := src
        this._byteLen := byteLen
    }

    Root {
        get {
            if !this._ptr
                throw TreeSitterError("TSTree has been freed.", -1)
            node := Buffer(32, 0)
            TreeSitter._Call("ts_tree_root_node", "Ptr", node, "Ptr", this._ptr)
            return TSNode(this, node)
        }
    }

    ; Slice the original source by byte range (tree-sitter stores no text itself).
    TextRange(startByte, endByte) {
        if endByte <= startByte
            return ""
        return StrGet(this._src.Ptr + startByte, endByte - startByte, "UTF-8")
    }

    __Delete() {
        if this._ptr {
            TreeSitter._Call("ts_tree_delete", "Ptr", this._ptr)
            this._ptr := 0
        }
    }
}

/**
 * A node in the syntax tree. Wraps tree-sitter's 32-byte node handle; holds a
 * reference to its TSTree so the source and native tree stay alive.
 */
class TSNode {
    __New(tree, nodeBuf) {
        this._tree := tree
        this._buf := nodeBuf          ; 32-byte TSNode struct copy
    }

    ; A null node (e.g. from a field miss) has a zero id pointer at byte offset 16
    ; of the struct — checkable without a DllCall. Null nodes answer only IsNull.
    IsNull => !NumGet(this._buf, 16, "Ptr")

    ; Guard every data access. A null node, or a node whose tree was explicitly
    ; freed, would dereference null/freed memory inside the DLL (access violation);
    ; throw a clean TreeSitterError instead.
    _Require() {
        if !NumGet(this._buf, 16, "Ptr")
            throw TreeSitterError("Operation on a null node (out-of-range index or absent field); guard with .IsNull.", -2)
        if !this._tree._ptr
            throw TreeSitterError("Node used after its TSTree was freed; keep the tree alive while using its nodes.", -2)
    }

    Type {
        get => (this._Require(), StrGet(TreeSitter._Call("ts_node_type", "Ptr", this._buf, "Ptr"), "UTF-8"))
    }
    StartByte {
        get => (this._Require(), TreeSitter._Call("ts_node_start_byte", "Ptr", this._buf, "UInt"))
    }
    EndByte {
        get => (this._Require(), TreeSitter._Call("ts_node_end_byte", "Ptr", this._buf, "UInt"))
    }
    StartRow {
        get => (this._Require(), TreeSitter._Call("ts_node_start_point", "Ptr", this._buf, "Int64") & 0xFFFFFFFF)
    }
    StartCol {
        get => (this._Require(), (TreeSitter._Call("ts_node_start_point", "Ptr", this._buf, "Int64") >> 32) & 0xFFFFFFFF)
    }
    EndRow {
        get => (this._Require(), TreeSitter._Call("ts_node_end_point", "Ptr", this._buf, "Int64") & 0xFFFFFFFF)
    }
    EndCol {
        get => (this._Require(), (TreeSitter._Call("ts_node_end_point", "Ptr", this._buf, "Int64") >> 32) & 0xFFFFFFFF)
    }
    Text {
        get => (this._Require(), this._tree.TextRange(this.StartByte, this.EndByte))
    }
    ChildCount {
        get => (this._Require(), TreeSitter._Call("ts_node_child_count", "Ptr", this._buf, "UInt"))
    }
    NamedChildCount {
        get => (this._Require(), TreeSitter._Call("ts_node_named_child_count", "Ptr", this._buf, "UInt"))
    }
    IsNamed {
        get => (this._Require(), TreeSitter._Call("ts_node_is_named", "Ptr", this._buf, "Char") ? true : false)
    }
    IsMissing {
        get => (this._Require(), TreeSitter._Call("ts_node_is_missing", "Ptr", this._buf, "Char") ? true : false)
    }
    IsError {
        get => (this._Require(), TreeSitter._Call("ts_node_is_error", "Ptr", this._buf, "Char") ? true : false)
    }
    HasError {
        get => (this._Require(), TreeSitter._Call("ts_node_has_error", "Ptr", this._buf, "Char") ? true : false)
    }

    Child(index) {
        this._Require()
        count := this.ChildCount
        if index < 0 || index >= count
            throw TreeSitterError("Child index " index " out of range (node has " count " children).", -1)
        node := Buffer(32, 0)
        TreeSitter._Call("ts_node_child", "Ptr", node, "Ptr", this._buf, "UInt", index)
        return TSNode(this._tree, node)
    }
    NamedChild(index) {
        this._Require()
        count := this.NamedChildCount
        if index < 0 || index >= count
            throw TreeSitterError("NamedChild index " index " out of range (node has " count " named children).", -1)
        node := Buffer(32, 0)
        TreeSitter._Call("ts_node_named_child", "Ptr", node, "Ptr", this._buf, "UInt", index)
        return TSNode(this._tree, node)
    }

    ; Named child for a grammar field (e.g. a node's "left"/"right"); "" if absent.
    Field(name) {
        this._Require()
        size := StrPut(name, "UTF-8")
        nb := Buffer(size)
        StrPut(name, nb, "UTF-8")
        node := Buffer(32, 0)
        TreeSitter._Call("ts_node_child_by_field_name", "Ptr", node, "Ptr", this._buf, "Ptr", nb, "UInt", size - 1)
        n := TSNode(this._tree, node)
        return n.IsNull ? "" : n
    }

    Children() {
        out := []
        loop this.ChildCount
            out.Push(this.Child(A_Index - 1))
        return out
    }
    NamedChildren() {
        out := []
        loop this.NamedChildCount
            out.Push(this.NamedChild(A_Index - 1))
        return out
    }

    ; Iterative (explicit-stack) pre-order traversal — no native-recursion limit
    ; on deeply nested trees. The visitor receives (node, depth); return false to
    ; skip a node's subtree. A visitor that returns nothing simply descends.
    Walk(visitor, includeAnonymous := false) {
        stack := [[this, 0]]
        while stack.Length {
            frame := stack.Pop()
            node := frame[1], depth := frame[2]
            if (visitor(node, depth) ?? true) = false
                continue
            kids := includeAnonymous ? node.Children() : node.NamedChildren()
            i := kids.Length
            while i >= 1 {
                stack.Push([kids[i], depth + 1])
                i -= 1
            }
        }
    }

    ; Indented S-expression dump of this subtree (named nodes).
    Dump(includeAnonymous := false) {
        out := ""
        this.Walk(BuildLine, includeAnonymous)
        return RTrim(out, "`n")
        BuildLine(node, depth) {
            indent := ""
            loop depth
                indent .= "  "
            label := node.IsError ? "ERROR" : node.Type
            out .= indent label " [" node.StartRow ":" node.StartCol "-" node.EndRow ":" node.EndCol "]`n"
            return true
        }
    }
}
