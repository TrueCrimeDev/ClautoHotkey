#Requires AutoHotkey v2.1-alpha.30

; HarnessCore.ahk — the pieces every tier of the grading harness shares.
;
; The result contract is the only thing holding the graph together: a tier-1
; agent and a tier-3 agent never talk to each other, they only agree on the
; shape of what they write. Emitting that shape from one place is what keeps
; them agreeing. See CONTRACT.md.

; An object with a remembered key order. A JSON object is unordered by spec, but
; a stable order makes the NDJSON stream diffable and readable by eye.
class JObj {
    __New() {
        this.Pairs := []
    }
    Set(key, value) {
        this.Pairs.Push([key, value])
        return this
    }
    Get(key, default := "") {
        for pair in this.Pairs {
            if (pair[1] = key)
                return pair[2]
        }
        return default
    }
}

class HarnessJson {
    static Dump(value) {
        if (value is JObj) {
            parts := []
            for pair in value.Pairs
                parts.Push(this.Str(pair[1]) ":" this.Dump(pair[2]))
            return "{" this.Join(parts) "}"
        }
        if (value is Array) {
            parts := []
            for item in value
                parts.Push(this.Dump(item))
            return "[" this.Join(parts) "]"
        }
        if (value is Integer)
            return String(value)
        if (value is Float)
            return String(value)
        return this.Str(value)
    }

    static Join(parts) {
        out := ""
        for part in parts
            out .= (A_Index = 1 ? "" : ",") part
        return out
    }

    static Str(text) {
        out := '"'
        for char in StrSplit(String(text)) {
            code := Ord(char)
            if (char = '"')
                out .= '\"'
            else if (char = "\")
                out .= "\\"
            else if (code = 10)
                out .= "\n"
            else if (code = 13)
                out .= "\r"
            else if (code = 9)
                out .= "\t"
            else if (code < 32)
                out .= Format("\u{:04x}", code)
            else
                out .= char
        }
        return out '"'
    }
}

class Harness {
    static Schema := "ahk-harness/result@1"
    static Sentinel := "AHKHARNESS-END"

    ; The head of every result, identical across tiers.
    static Result(ctx, tier, scriptPath) {
        res := JObj()
        res.Set("schema", this.Schema)
        res.Set("run", ctx["run"])
        res.Set("label", ctx["label"])
        res.Set("tier", tier)
        res.Set("script", scriptPath)
        res.Set("name", this.NameOf(scriptPath))
        return res
    }

    ; The tail of every result. Counts are derived here rather than by each
    ; tier, so a tier cannot report a total that disagrees with its own list.
    static Finish(res, checks, findings, status, started, extra := unset) {
        ; Capped here rather than at any call site: every tier and every early
        ; return funnels through Finish, and the first attempt missed the
        ; parse-failure path, which is exactly where an all-v1 file lands.
        findings := this.CapPerRule(findings)
        if IsSet(extra) {
            for pair in extra
                res.Set(pair[1], pair[2])
        }
        counts := JObj()
        for severity in ["critical", "high", "medium", "low"] {
            total := 0
            for f in findings {
                if (f.Get("severity") = severity)
                    total++
            }
            counts.Set(severity, total)
        }
        res.Set("status", status)
        res.Set("ms", A_TickCount - started)
        res.Set("checks", checks)
        res.Set("findings", findings)
        res.Set("counts", counts)
        res.Set("sentinel", this.Sentinel)
        return res
    }

    static CheckRow(name, status, exitCode, ms, detail) {
        row := JObj()
        row.Set("name", name)
        row.Set("status", status)
        row.Set("exit", exitCode)
        row.Set("ms", ms)
        row.Set("detail", this.Clip(detail, 2000))
        return row
    }

    static Finding(severity, rule, line, message, source := "gate", confidence := "full") {
        f := JObj()
        f.Set("severity", severity)
        f.Set("rule", rule)
        f.Set("line", line)
        f.Set("source", source)
        f.Set("confidence", confidence)
        f.Set("message", this.Clip(message, 1000))
        return f
    }

    ; Single-argument Print is passed through verbatim; a format pass would eat
    ; the braces in the JSON.
    static Emit(res) {
        Print(HarnessJson.Dump(res))
    }

    ; Redirecting to a file rather than reading a pipe: a pipe that fills while
    ; the child is still writing deadlocks, and tool output is unbounded.
    ;
    ; The deadline is real: a wedged interpreter would otherwise hang the gate
    ; forever with no NDJSON at all. timeoutMs <= 0 gets a generous ceiling
    ; rather than no ceiling — no static tool legitimately runs two minutes.
    ; The pid Run hands back is the cmd.exe wrapper, not the tool, so the kill
    ; sweeps the tree; terminating the shell alone would orphan the interpreter.
    ; A timeout comes back as exit 137 with the reason in the output, so the
    ; caller's check row fails rather than silently skipping.
    static RunTool(args, outFile, timeoutMs := 0) {
        static SYNCHRONIZE := 0x00100000, QUERY_INFORMATION := 0x0400, TERMINATE := 0x0001
        static WAIT_TIMEOUT := 0x102
        if (timeoutMs <= 0)
            timeoutMs := 120000
        result := Map()
        started := A_TickCount
        cmd := A_ComSpec ' /c ""' A_AhkPath '" ' args ' > "' outFile '" 2>&1"'
        try
            Run(cmd, , "Hide", &pid)
        catch Error as err {
            result["exit"] := -1
            result["ms"] := A_TickCount - started
            result["output"] := "launch failed: " err.Message
            return result
        }

        handle := DllCall("OpenProcess", "UInt", SYNCHRONIZE | QUERY_INFORMATION | TERMINATE
            , "Int", 0, "UInt", pid, "Ptr")
        if !handle
            return this.RunToolPoll(pid, outFile, timeoutMs, started, result)

        if (DllCall("WaitForSingleObject", "Ptr", handle, "UInt", timeoutMs, "UInt") = WAIT_TIMEOUT) {
            this.KillTree(pid)
            if (DllCall("WaitForSingleObject", "Ptr", handle, "UInt", 3000, "UInt") = WAIT_TIMEOUT)
                DllCall("TerminateProcess", "Ptr", handle, "UInt", 137)
            DllCall("CloseHandle", "Ptr", handle)
            result["exit"] := 137
            result["ms"] := A_TickCount - started
            result["output"] := "timeout after " timeoutMs "ms — tool killed. " this.ReadOutput(outFile)
            return result
        }

        code := 0
        DllCall("GetExitCodeProcess", "Ptr", handle, "UInt*", &code)
        DllCall("CloseHandle", "Ptr", handle)
        result["exit"] := code
        result["ms"] := A_TickCount - started
        result["output"] := this.ReadOutput(outFile)
        return result
    }

    ; OpenProcess can lose the race with a fast tool. Polling still enforces
    ; the deadline; what it cannot recover is the exit code, and an unobserved
    ; exit is reported as a tool error rather than scored as a pass.
    static RunToolPoll(pid, outFile, timeoutMs, started, result) {
        while (A_TickCount - started < timeoutMs) {
            if !ProcessExist(pid) {
                result["exit"] := -1
                result["ms"] := A_TickCount - started
                result["output"] := "no process handle for pid " pid
                    . " and it exited unobserved. " this.ReadOutput(outFile)
                return result
            }
            Sleep(50)
        }
        this.KillTree(pid)
        result["exit"] := 137
        result["ms"] := A_TickCount - started
        result["output"] := "timeout after " timeoutMs "ms — tool killed (no handle, tree kill). "
            . this.ReadOutput(outFile)
        return result
    }

    static KillTree(pid) {
        try
            RunWait(A_ComSpec ' /c taskkill /F /T /PID ' pid, , "Hide")
        catch Error as err
            OutputDebug("Harness: taskkill /T of pid " pid " failed: " err.Message)
    }

    ; Spawn the interpreter directly and wait with a deadline. RunWait cannot be
    ; interrupted, and routing through cmd.exe to get redirection means the
    ; process we can kill is the shell, not the script under test — so this uses
    ; /StdErrFile for capture and keeps a real handle on the child.
    ;
    ; A timeout is a result, never a skip. The kill uses 137 rather than 124 so
    ; it stays distinguishable from a script that timed itself out from the
    ; inside: 124 means the script's own watchdog fired, which proves its
    ; message loop was still responsive, and 137 means we had to terminate it,
    ; which proves it was not. That difference separates a persistent script
    ; sitting idle from one genuinely wedged.
    static RunTimed(args, timeoutMs) {
        static SYNCHRONIZE := 0x00100000, QUERY_INFORMATION := 0x0400, TERMINATE := 0x0001
        static WAIT_TIMEOUT := 0x102

        result := Map()
        result["killed"] := false
        started := A_TickCount
        try
            Run('"' A_AhkPath '" ' args, , "Hide", &pid)
        catch Error as err {
            result["exit"] := -1
            result["ms"] := A_TickCount - started
            result["killed"] := false
            result["note"] := "launch failed: " err.Message
            return result
        }

        handle := DllCall("OpenProcess", "UInt", SYNCHRONIZE | QUERY_INFORMATION | TERMINATE
            , "Int", 0, "UInt", pid, "Ptr")
        if !handle {
            ; Without a handle the kernel wait is unavailable, but the deadline
            ; still has to be enforced — leaving the candidate running
            ; unsupervised is worse than an unobserved exit code. The kill path
            ; below produces the normal timeout shape (killed/responsive/124 or
            ; 137, no note), so downstream classifies it exactly like a
            ; handle-supervised timeout; only an exit we could not observe is a
            ; tool error.
            while (A_TickCount - started < timeoutMs) {
                if !ProcessExist(pid) {
                    result["exit"] := -1
                    result["ms"] := A_TickCount - started
                    result["note"] := "could not open process handle for pid " pid
                        . "; it exited before the deadline but its exit code was unobservable"
                    return result
                }
                Sleep(50)
            }
            responsive := this.Responsive(pid)
            result["responsive"] := responsive
            try
                ProcessClose(pid)
            catch Error as err
                OutputDebug("Harness: ProcessClose(" pid ") failed: " err.Message)
            if ProcessExist(pid) {
                try
                    RunWait(A_ComSpec ' /c taskkill /F /PID ' pid, , "Hide")
                catch Error as err
                    OutputDebug("Harness: taskkill of pid " pid " failed: " err.Message)
            }
            result["killed"] := true
            result["exit"] := responsive ? 124 : 137
            result["ms"] := A_TickCount - started
            return result
        }

        if (DllCall("WaitForSingleObject", "Ptr", handle, "UInt", timeoutMs, "UInt") = WAIT_TIMEOUT) {
            ; Ask the script's message window whether it is still pumping before
            ; deciding what its silence meant. An idle hotkey script answers at
            ; once; one stuck in a blocking call cannot answer at all.
            responsive := this.Responsive(pid)
            result["responsive"] := responsive
            DllCall("TerminateProcess", "Ptr", handle, "UInt", responsive ? 124 : 137)
            DllCall("WaitForSingleObject", "Ptr", handle, "UInt", 3000, "UInt")
            result["killed"] := true
        }

        code := 0
        DllCall("GetExitCodeProcess", "Ptr", handle, "UInt*", &code)
        DllCall("CloseHandle", "Ptr", handle)

        result["exit"] := code
        result["ms"] := A_TickCount - started
        return result
    }

    ; The interpreter reports diagnostics as: path (line) : ==> message
    ;
    ; A "Warning:" prefix is #Warn output — advisory, and emitted for every
    ; suspicious variable in the file. The line that actually killed the script
    ; carries no prefix. Ranking them all critical buries the one that matters:
    ; measured on Mistral_Large_3.ahk, 10 of 11 findings were warnings.
    ; A headline's continuation lines — "Specifically: <name>" and indented
    ; stack lines, up to the next headline or a blank line — carry the variable
    ; name the headline omits, so they are folded into the message.
    static DiagFindings(text, source, fatalRule := "runtime") {
        findings := []
        if (text = "")
            return findings
        entries := []
        current := ""
        for line in StrSplit(text, "`n", "`r") {
            if RegExMatch(line, "^(.+?) \((\d+)\) : ==> (.+)$", &m) {
                current := Map()
                current["line"] := Integer(m[2])
                current["message"] := Trim(m[3], " `t")
                entries.Push(current)
                continue
            }
            if !(current is Map)
                continue
            detail := Trim(line, " `t")
            if (detail = "") {
                current := ""
                continue
            }
            if !(RegExMatch(line, "^[ `t]") || SubStr(detail, 1, 13) = "Specifically:") {
                current := ""
                continue
            }
            if (StrLen(current["message"]) < 900)
                current["message"] .= " | " detail
        }
        for entry in entries {
            message := entry["message"]
            if (SubStr(message, 1, 8) = "Warning:")
                findings.Push(this.Finding("medium", "warn", entry["line"], message, source))
            else
                findings.Push(this.Finding("critical", fatalRule, entry["line"], message, source))
        }
        return findings
    }

    static HasCritical(findings) {
        for f in findings {
            if (f.Get("severity") = "critical")
                return true
        }
        return false
    }

    ; One wholly-v1 file produced 589 v1-command findings, which buries every
    ; other script in an aggregate. Keep the first `max` of each rule and fold
    ; the rest into a single row that states how many there were — capped, but
    ; never silently, so the total is still recoverable from the report.
    static CapPerRule(findings, max := 10) {
        counts := Map(), kept := [], folded := Map()
        severities := Map(), confidences := Map()
        for f in findings {
            rule := f.Get("rule")
            if !severities.Has(rule)
                severities[rule] := f.Get("severity")
            seen := counts.Get(rule, 0) + 1
            counts[rule] := seen
            if (seen <= max) {
                kept.Push(f)
                continue
            }
            folded[rule] := folded.Get(rule, 0) + 1
            ; The folded row speaks for these findings, so it inherits their
            ; confidence — "partial" wins when the fold mixes both.
            if (f.Get("confidence", "full") = "partial")
                confidences[rule] := "partial"
            else if !confidences.Has(rule)
                confidences[rule] := f.Get("confidence", "full")
        }
        for rule, extra in folded
            kept.Push(this.Finding(severities[rule], rule, 0
                , extra " further occurrence(s) in this file, not listed individually"
                , "gate", confidences[rule]))
        return kept
    }

    ; v1 APIs that still load under v2 and then do nothing. Returned as plain
    ; Maps so both the gate and the editor's lint runner can consume them
    ; without agreeing on the result schema.
    ;
    ; The clipboard case is why this exists. Assigning to Clipboard sets an
    ; ordinary variable in v2 — the real one is A_Clipboard — so a clipboard
    ; tool's whole purpose silently no-ops. Measured on the .ai corpus: 46 of
    ; 161 scripts, every one reported until now as an "unused local" ranked low.
    ;
    ; It is a text scan on purpose, so it still reports on a file the parser
    ; cannot load — and those files never reach Lint or CodeIntel at all.
    ; String literals and trailing comments are stripped before matching, so a
    ; mention of `new Config()` inside a message string is not an instantiation.
    ; A brace counter tracks class bodies: `Clipboard := ""` directly inside a
    ; class is a field named Clipboard, not a v1 clipboard write — but the same
    ; line one level deeper, in a method body, still is.
    static V1Isms(path) {
        found := []
        try {
            if (!FileExist(path) || FileGetSize(path) = 0)
                return found
            text := FileRead(path, "UTF-8")
        } catch Error as err {
            OutputDebug("Harness: v1 scan cannot read " path ": " err.Message)
            return found
        }

        inBlock := false, lineNo := 0
        depth := 0, classDepths := [], pendingClass := false
        for line in StrSplit(text, "`n", "`r") {
            lineNo++
            trimmed := Trim(line, " `t")
            if inBlock {
                if (SubStr(trimmed, 1, 2) = "*/")
                    inBlock := false
                continue
            }
            if (SubStr(trimmed, 1, 2) = "/*") {
                if !InStr(SubStr(trimmed, 3), "*/")
                    inBlock := true
                continue
            }
            if (trimmed = "" || SubStr(trimmed, 1, 1) = ";")
                continue
            code := Trim(this.StripCode(trimmed), " `t")
            if (code = "")
                continue
            if RegExMatch(code, "i)^class\s+\w")
                pendingClass := true
            atField := (classDepths.Length > 0 && depth = classDepths[classDepths.Length])
            for rule in this.V1Rules() {
                if (rule[2] = "v1-clipboard" && atField)
                    continue
                if !RegExMatch(code, rule[1])
                    continue
                item := Map()
                item["rule"] := rule[2]
                item["line"] := lineNo
                item["message"] := rule[3]
                found.Push(item)
            }
            for ch in StrSplit(code) {
                if (ch = "{") {
                    depth++
                    if pendingClass {
                        classDepths.Push(depth)
                        pendingClass := false
                    }
                } else if (ch = "}" && depth > 0) {
                    if (classDepths.Length > 0 && classDepths[classDepths.Length] = depth)
                        classDepths.Pop()
                    depth--
                }
            }
        }
        return found
    }

    ; Empties every quoted literal (both quote styles, backtick escapes
    ; honoured) and cuts a trailing whitespace-preceded `;` comment. Plain text
    ; in, plain text out — the scan must keep working on files the parser
    ; cannot load, so this must never grow a parser dependency.
    static StripCode(line) {
        out := "", quote := "", i := 1
        chars := StrSplit(line)
        len := chars.Length
        while (i <= len) {
            ch := chars[i]
            if (quote != "") {
                if (ch = "``") {
                    i += 2
                    continue
                }
                if (ch = quote)
                    quote := ""
                i++
                continue
            }
            if (ch = '"' || ch = "'") {
                quote := ch
                out .= ch ch
                i++
                continue
            }
            if (ch = ";" && (i = 1 || chars[i - 1] = " " || chars[i - 1] = "`t"))
                break
            out .= ch
            i++
        }
        return out
    }

    ; Anchored at line start where possible, so A_Clipboard and this.Clipboard
    ; are never mistaken for the v1 name.
    static V1Rules() {
        rules := []
        rules.Push(["i)^Clipboard\s*:?=[^=]", "v1-clipboard"
            , "Assigns an ordinary variable named Clipboard. v2 uses A_Clipboard, so this copy silently does nothing."])
        rules.Push(["i)(^|[^.\w])new\s+[A-Z_]\w*\s*\(", "v1-new"
            , "Instantiation with new is v1 syntax. v2 calls the class directly."])
        rules.Push(["i)^(Gui|MsgBox|StringReplace|StringSplit|SetFormat|IfEqual|IfExist|EnvSet)\s*,", "v1-command"
            , "v1 command syntax. v2 calls functions with parentheses."])
        return rules
    }

    ; True if the script's hidden message window answers a WM_NULL. AHK's own
    ; window is hidden, so detection has to be enabled first or every script
    ; reads as wedged.
    static Responsive(pid, waitMs := 1500) {
        static WM_NULL := 0x0000, SMTO_ABORTIFHUNG := 0x0002
        prior := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        try {
            hwnd := WinExist("ahk_pid " pid " ahk_class AutoHotkey") ?? 0
            if !hwnd
                return false
            answer := 0
            ok := DllCall("SendMessageTimeoutW", "Ptr", hwnd, "UInt", WM_NULL
                , "Ptr", 0, "Ptr", 0, "UInt", SMTO_ABORTIFHUNG, "UInt", waitMs
                , "Ptr*", &answer, "Ptr")
            return ok != 0
        } catch Error as err {
            OutputDebug("Harness: responsiveness probe failed: " err.Message)
            return false
        } finally {
            DetectHiddenWindows(prior)
        }
    }

    ; FileRead on a zero-byte file throws "No value was returned." on
    ; alpha.30, and a tool that passes cleanly is exactly the case that writes
    ; nothing — so the size check has to come first or every success reads back
    ; as a tool error.
    static ReadOutput(path) {
        if !FileExist(path)
            return ""
        try {
            if (FileGetSize(path) = 0)
                return ""
            return Trim(FileRead(path, "UTF-8"), " `t`r`n")
        } catch Error as err {
            ; Braced deliberately: the bundled tree-sitter grammar fails on a
            ; brace-less catch body, and a file it cannot parse gets every
            ; Lint/CodeIntel finding demoted to "partial".
            return "unreadable tool output: " err.Message
        }
    }

    static FullPath(path) {
        buf := Buffer(1040, 0)
        len := DllCall("GetFullPathNameW", "WStr", path, "UInt", 520, "Ptr", buf.Ptr
            , "Ptr", 0, "UInt")
        if (len = 0 || len >= 520)
            return path
        return StrGet(buf.Ptr, "UTF-16")
    }

    static NameOf(path) {
        SplitPath(path, &name)
        return name
    }

    static Slug(text) {
        return RegExReplace(text, "[^A-Za-z0-9._-]", "_")
    }

    static Clip(text, max) {
        text := String(text)
        if (StrLen(text) <= max)
            return text
        return SubStr(text, 1, max) " ...[truncated]"
    }

    ; Shared CLI plumbing: every gate takes the same run/label/out triple.
    ; The default id carries pid and tick suffixes: A_Now alone is one-second
    ; resolution, and two agents starting in the same second must not share a
    ; run directory. Consumers treat the id as an opaque string.
    static Context(label, runId, outDir) {
        if (runId = "")
            runId := A_Now "-" ProcessExist() "-" Mod(A_TickCount, 1000000)
        if (outDir = "")
            outDir := A_Temp "\ahk-harness\" runId "\" this.Slug(label)
        DirCreate(outDir)
        ctx := Map()
        ctx["run"] := runId
        ctx["label"] := label
        ctx["out"] := outDir
        return ctx
    }
}
