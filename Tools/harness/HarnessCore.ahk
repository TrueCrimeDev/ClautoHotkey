#Requires AutoHotkey v2.1-alpha.30

; HarnessCore.ahk — the pieces every tier of the grading harness shares.
;
; The result contract is the only thing holding the graph together: a tier-1
; agent and a tier-3 agent never talk to each other, they only agree on the
; shape of what they write. Emitting that shape from one place is what keeps
; them agreeing. See CONTRACT.md.
;
; Every child process any tier starts goes through Harness.Launch, so they all
; share one containment story: a suspended start, a kill-on-close job object,
; file-backed stdio, a real deadline, and an optional per-tick watcher.

; An object with a remembered key order. A JSON object is unordered by spec, but
; a stable order makes the NDJSON stream diffable and readable by eye.
class JObj {
    __New() {
        this.Pairs := []
    }
    Set(key, value) {
        for pair in this.Pairs {
            if (pair[1] = key) {
                pair[2] := value
                return this
            }
        }
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
    Has(key) {
        for pair in this.Pairs {
            if (pair[1] = key)
                return true
        }
        return false
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

    ; A small JSON reader. The fork's native JSON class is missing from some
    ; alpha.30 builds the harness has to run on (measured: the 2026-08-29
    ; build has none), so the harness carries its own. Objects become Maps
    ; with case-sensitive keys, arrays Arrays, true/false/null 1/0/"".
    ; Malformed input throws ValueError naming the offset, which callers
    ; report as a tool error rather than a verdict.
    static Parse(text) {
        pos := 1
        value := this.ParseValue(text, &pos, 0)
        this.SkipWs(text, &pos)
        if (pos <= StrLen(text))
            throw ValueError("unexpected trailing text at offset " pos)
        return value
    }

    static SkipWs(text, &pos) {
        len := StrLen(text)
        while (pos <= len) {
            ch := SubStr(text, pos, 1)
            if (ch != " " && ch != "`t" && ch != "`r" && ch != "`n")
                return
            pos++
        }
    }

    static ParseValue(text, &pos, depth) {
        if (depth > 200)
            throw ValueError("nesting deeper than 200 at offset " pos)
        this.SkipWs(text, &pos)
        ch := SubStr(text, pos, 1)
        if (ch = "{")
            return this.ParseObject(text, &pos, depth + 1)
        if (ch = "[")
            return this.ParseArray(text, &pos, depth + 1)
        if (ch = '"')
            return this.ParseString(text, &pos)
        if (SubStr(text, pos, 4) == "true") {
            pos += 4
            return 1
        }
        if (SubStr(text, pos, 5) == "false") {
            pos += 5
            return 0
        }
        if (SubStr(text, pos, 4) == "null") {
            pos += 4
            return ""
        }
        if (ch = "-" || IsDigit(ch)) && RegExMatch(text, "-?\d+(\.\d+)?([eE][+-]?\d+)?", &m, pos) && m.Pos = pos {
            pos += m.Len
            ; Integer() wraps silently past Int64 (measured: 24 digits came
            ; back negative), so long integers keep their magnitude as Float.
            if (m[1] != "" || m[2] != "" || StrLen(LTrim(m[0], "-")) > 18)
                return Float(m[0])
            return Integer(m[0])
        }
        throw ValueError("unexpected input at offset " pos)
    }

    static ParseObject(text, &pos, depth) {
        obj := Map()
        pos++
        this.SkipWs(text, &pos)
        if (SubStr(text, pos, 1) = "}") {
            pos++
            return obj
        }
        loop {
            this.SkipWs(text, &pos)
            if (SubStr(text, pos, 1) != '"')
                throw ValueError("expected an object key at offset " pos)
            key := this.ParseString(text, &pos)
            this.SkipWs(text, &pos)
            if (SubStr(text, pos, 1) != ":")
                throw ValueError("expected ':' at offset " pos)
            pos++
            obj[key] := this.ParseValue(text, &pos, depth)
            this.SkipWs(text, &pos)
            ch := SubStr(text, pos, 1)
            pos++
            if (ch = "}")
                return obj
            if (ch != ",")
                throw ValueError("expected ',' or '}' at offset " (pos - 1))
        }
    }

    static ParseArray(text, &pos, depth) {
        arr := []
        pos++
        this.SkipWs(text, &pos)
        if (SubStr(text, pos, 1) = "]") {
            pos++
            return arr
        }
        loop {
            arr.Push(this.ParseValue(text, &pos, depth))
            this.SkipWs(text, &pos)
            ch := SubStr(text, pos, 1)
            pos++
            if (ch = "]")
                return arr
            if (ch != ",")
                throw ValueError("expected ',' or ']' at offset " (pos - 1))
        }
    }

    static ParseString(text, &pos) {
        pos++
        out := ""
        loop {
            quote := InStr(text, '"', true, pos)
            if !quote
                throw ValueError("unterminated string at offset " pos)
            slash := InStr(text, "\", true, pos)
            if (!slash || slash > quote) {
                out .= SubStr(text, pos, quote - pos)
                pos := quote + 1
                return out
            }
            out .= SubStr(text, pos, slash - pos)
            esc := SubStr(text, slash + 1, 1)
            pos := slash + 2
            switch esc, true {
                case '"': out .= '"'
                case "\": out .= "\"
                case "/": out .= "/"
                case "b": out .= "`b"
                case "f": out .= "`f"
                case "n": out .= "`n"
                case "r": out .= "`r"
                case "t": out .= "`t"
                case "u":
                    hex := SubStr(text, pos, 4)
                    if !RegExMatch(hex, "^[0-9A-Fa-f]{4}$")
                        throw ValueError("bad \u escape at offset " slash)
                    out .= Chr(Integer("0x" hex))
                    pos += 4
                default:
                    throw ValueError("bad escape at offset " slash)
            }
        }
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
    static Schema := "ahk-harness/result@2"
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

    ; Runs a tool through the interpreter that is running the gate, so a gate
    ; can never grade against a different binary than the one it reports.
    ; stdout and stderr share outFile. A timed-out tool comes back as exit 137
    ; with the reason in the output, so the caller's check row fails rather
    ; than silently skipping; the job kill takes the interpreter's whole tree.
    static RunTool(args, outFile, timeoutMs := 0) {
        opts := Map()
        opts["stdout"] := outFile
        opts["merge"] := true
        opts["timeoutMs"] := timeoutMs > 0 ? timeoutMs : 120000
        ; Tools are never meant to sit idle, so a deadline is always a hang.
        opts["probe"] := false
        launch := this.Launch('"' A_AhkPath '" ' args, opts)

        result := Map()
        result["ms"] := launch["ms"]
        if launch.Has("note") {
            result["exit"] := -1
            result["output"] := launch["note"] " " this.ReadOutput(outFile)
            return result
        }
        if launch["timedOut"] {
            result["exit"] := 137
            result["output"] := "timeout after " opts["timeoutMs"] "ms — tool killed. "
                . this.ReadOutput(outFile)
            return result
        }
        result["exit"] := launch["exit"]
        result["output"] := this.ReadOutput(outFile)
        return result
    }

    ; Every child any tier starts goes through here. It is created suspended,
    ; assigned to a kill-on-close job, and only then resumed, so nothing it
    ; spawns can escape before it is contained. Closing the job handle kills
    ; the whole tree — grandchildren included, which a cmd.exe wrapper plus a
    ; taskkill sweep used to orphan when the sweep raced the exit.
    ;
    ; stdio goes to files, never pipes: a pipe that fills while the child is
    ; still writing deadlocks, and tool output is unbounded. A child's stdout
    ; therefore never reaches the gate's own stdout, which is the NDJSON stream.
    ;
    ; The wait is sliced (tickMs) so opts["onTick"] can run between slices — the
    ; dry-run gate watches for dialogs and clipboard writes that way while the
    ; candidate is alive. A watcher asks for termination by setting
    ; state["kill"] (a reason) and optionally state["killCode"].
    ;
    ; On the deadline the child's message loop is probed before the kill: 124
    ; means it was still answering (an idle persistent script), 137 that it was
    ; not. opts["probe"] := false skips the probe and always reports 137.
    ;
    ; opts: cwd, app, stdout, stderr, merge, timeoutMs, tickMs, onTick, probe,
    ;       env (Map), memoryMB, uiLimits
    static Launch(cmdLine, opts := Map()) {
        static CREATE_SUSPENDED := 0x4, CREATE_NO_WINDOW := 0x08000000
        static STARTF_USESHOWWINDOW := 0x1, STARTF_USESTDHANDLES := 0x100
        static WAIT_TIMEOUT := 0x102

        timeoutMs := opts.Get("timeoutMs", 120000)
        if (timeoutMs <= 0)
            timeoutMs := 120000
        tickMs := Max(10, opts.Get("tickMs", 100))
        onTick := opts.Get("onTick", "")

        result := Map()
        result["exit"] := -1
        result["ms"] := 0
        result["pid"] := 0
        result["killed"] := false
        result["timedOut"] := false
        result["responsive"] := false
        result["killReason"] := ""
        result["jobbed"] := false

        started := A_TickCount
        job := 0, process := 0, thread := 0, hIn := 0, hOut := 0, hErr := 0
        priorEnv := Map()
        try {
            if opts.Has("env") {
                for name, value in opts["env"] {
                    priorEnv[name] := EnvGet(name)
                    EnvSet(name, value)
                }
            }
            try {
                job := this.CreateJob(opts.Get("memoryMB", 0), opts.Get("uiLimits", false))
                hIn := this.OpenStd("", false)
                hOut := this.OpenStd(opts.Get("stdout", ""), true)
                hErr := opts.Get("merge", false) ? hOut : this.OpenStd(opts.Get("stderr", ""), true)
            } catch Error as err {
                result["note"] := "launch failed: " err.Message
                return result
            }

            si := Buffer(A_PtrSize = 8 ? 104 : 68, 0)
            NumPut("UInt", si.Size, si, 0)
            NumPut("UInt", STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES, si, A_PtrSize = 8 ? 60 : 44)
            NumPut("UShort", 0, si, A_PtrSize = 8 ? 64 : 48)
            NumPut("Ptr", hIn, "Ptr", hOut, "Ptr", hErr, si, A_PtrSize = 8 ? 80 : 56)
            pi := Buffer(A_PtrSize * 2 + 8, 0)
            cmdBuf := Buffer((StrLen(cmdLine) + 1) * 2, 0)
            StrPut(cmdLine, cmdBuf, "UTF-16")
            app := opts.Get("app", "")
            cwd := opts.Get("cwd", "")
            ok := DllCall("CreateProcessW"
                , app = "" ? "Ptr" : "WStr", app = "" ? 0 : app
                , "Ptr", cmdBuf, "Ptr", 0, "Ptr", 0, "Int", true
                , "UInt", CREATE_SUSPENDED | CREATE_NO_WINDOW, "Ptr", 0
                , cwd = "" ? "Ptr" : "WStr", cwd = "" ? 0 : cwd
                , "Ptr", si, "Ptr", pi, "Int")
            if !ok {
                result["note"] := "launch failed: " OSError(A_LastError).Message
                return result
            }
            process := NumGet(pi, 0, "Ptr")
            thread := NumGet(pi, A_PtrSize, "Ptr")
            pid := NumGet(pi, A_PtrSize * 2, "UInt")
            result["pid"] := pid

            ; Assigning can only fail on a pre-Windows-8 nested-job refusal.
            ; The child still runs then, under the deadline and TerminateProcess,
            ; and the row says so through "jobbed".
            result["jobbed"] := DllCall("AssignProcessToJobObject", "Ptr", job, "Ptr", process, "Int") != 0
            if (DllCall("ResumeThread", "Ptr", thread, "UInt") = 0xFFFFFFFF) {
                result["note"] := "launch failed: could not resume the child (" A_LastError ")"
                this.Terminate(job, process, result["jobbed"], 1)
                return result
            }

            state := Map()
            state["pid"] := pid
            state["started"] := started
            deadline := started + timeoutMs
            loop {
                remaining := deadline - A_TickCount
                if (remaining <= 0)
                    break
                wait := DllCall("WaitForSingleObject", "Ptr", process, "UInt", Min(tickMs, remaining), "UInt")
                if (wait = 0)
                    break
                if (wait != WAIT_TIMEOUT) {
                    result["note"] := "wait failed (" A_LastError ")"
                    break
                }
                if !HasMethod(onTick)
                    continue
                state["elapsed"] := A_TickCount - started
                state["pids"] := this.JobPids(job, pid, result["jobbed"])
                try {
                    onTick(state)
                } catch Error as err {
                    ; A watcher bug must not wedge the run or vanish: the
                    ; candidate keeps going and the reason travels in the result.
                    result["tickError"] := err.Message
                }
                if state.Has("kill") {
                    result["killed"] := true
                    result["killReason"] := state["kill"]
                    this.Terminate(job, process, result["jobbed"], state.Get("killCode", 1))
                    break
                }
            }

            if (DllCall("WaitForSingleObject", "Ptr", process, "UInt", 0, "UInt") = WAIT_TIMEOUT) {
                result["timedOut"] := !result["killed"]
                result["killed"] := true
                responsive := opts.Get("probe", true) ? this.Responsive(pid) : false
                result["responsive"] := responsive
                this.Terminate(job, process, result["jobbed"], responsive ? 124 : 137)
            }
            code := 0
            DllCall("GetExitCodeProcess", "Ptr", process, "UInt*", &code)
            result["exit"] := code
            return result
        } finally {
            result["ms"] := A_TickCount - started
            for handle in [thread, process, hIn, hOut]
                this.CloseHandle(handle)
            if (hErr != hOut)
                this.CloseHandle(hErr)
            ; Last, so a descendant still alive past the child's exit dies here.
            this.CloseHandle(job)
            for name, value in priorEnv
                EnvSet(name, value)
        }
    }

    ; KILL_ON_JOB_CLOSE makes the handle the tree's lifetime. DIE_ON_UNHANDLED_
    ; EXCEPTION suppresses the Windows Error Reporting dialog, which would
    ; otherwise keep a crashed child alive until the deadline. The UI limits
    ; (opt-in) stop a candidate from changing system parameters or display
    ; settings, switching desktops, or calling ExitWindowsEx — a Shutdown()
    ; that slipped past every other layer still cannot log the user off.
    static CreateJob(memoryMB := 0, uiLimits := false) {
        job := DllCall("CreateJobObjectW", "Ptr", 0, "Ptr", 0, "Ptr")
        if !job
            throw OSError(A_LastError, -1, "CreateJobObjectW")
        size := A_PtrSize = 8 ? 144 : 112
        info := Buffer(size, 0)
        flags := 0x2000 | 0x400
        if (memoryMB > 0) {
            flags |= 0x100
            NumPut("UPtr", memoryMB * 1024 * 1024, info, A_PtrSize = 8 ? 112 : 96)
        }
        NumPut("UInt", flags, info, 16)
        if !DllCall("SetInformationJobObject", "Ptr", job, "Int", 9, "Ptr", info, "UInt", size, "Int") {
            err := OSError(A_LastError, -1, "SetInformationJobObject")
            DllCall("CloseHandle", "Ptr", job)
            throw err
        }
        if uiLimits {
            ui := Buffer(4, 0)
            NumPut("UInt", 0x08 | 0x10 | 0x40 | 0x80, ui)
            if !DllCall("SetInformationJobObject", "Ptr", job, "Int", 4, "Ptr", ui, "UInt", 4, "Int") {
                err := OSError(A_LastError, -1, "SetInformationJobObject(UI limits)")
                DllCall("CloseHandle", "Ptr", job)
                throw err
            }
        }
        return job
    }

    ; An empty path means NUL. Handles are inheritable so the child can use
    ; them as its stdio; every share flag is set so the gate can read a log the
    ; child still holds open.
    static OpenStd(path, write) {
        sa := Buffer(A_PtrSize = 8 ? 24 : 12, 0)
        NumPut("UInt", sa.Size, sa, 0)
        NumPut("Int", 1, sa, A_PtrSize * 2)
        target := (path = "") ? "NUL" : path
        disposition := (write && path != "") ? 2 : 3
        handle := DllCall("CreateFileW", "WStr", target
            , "UInt", write ? 0x40000000 : 0x80000000, "UInt", 0x7, "Ptr", sa
            , "UInt", disposition, "UInt", 0x80, "Ptr", 0, "Ptr")
        if (handle = -1)
            throw OSError(A_LastError, -1, "cannot open " target)
        return handle
    }

    static Terminate(job, process, jobbed, code) {
        if (jobbed && job)
            DllCall("TerminateJobObject", "Ptr", job, "UInt", code)
        else
            DllCall("TerminateProcess", "Ptr", process, "UInt", code)
        DllCall("WaitForSingleObject", "Ptr", process, "UInt", 5000, "UInt")
    }

    static CloseHandle(handle) {
        if (handle && handle != -1)
            DllCall("CloseHandle", "Ptr", handle)
    }

    ; Every pid currently in the job, so watchers also see what the child
    ; spawned. Falls back to the child alone when it could not be jobbed.
    static JobPids(job, pid, jobbed := true) {
        pids := []
        if (!job || !jobbed) {
            pids.Push(pid)
            return pids
        }
        size := 8 + 256 * A_PtrSize
        buf := Buffer(size, 0)
        if !DllCall("QueryInformationJobObject", "Ptr", job, "Int", 3, "Ptr", buf, "UInt", size, "Ptr", 0, "Int") {
            pids.Push(pid)
            return pids
        }
        loop NumGet(buf, 4, "UInt")
            pids.Push(NumGet(buf, 8 + (A_Index - 1) * A_PtrSize, "UPtr"))
        if !pids.Length
            pids.Push(pid)
        return pids
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
        for entry in this.DiagEntries(text) {
            if entry["warning"]
                findings.Push(this.Finding("medium", "warn", entry["line"], entry["message"], source))
            else
                findings.Push(this.Finding("critical", fatalRule, entry["line"], entry["message"], source))
        }
        return findings
    }

    ; The parsed diagnostics, file included, for callers that have to tell
    ; whose code a diagnostic points at — the dry-run gate must not blame a
    ; candidate for a warning raised inside the shim it was injected with.
    static DiagEntries(text) {
        entries := []
        if (text = "")
            return entries
        current := ""
        for line in StrSplit(text, "`n", "`r") {
            if RegExMatch(line, "^(.+?) \((\d+)\) : ==> (.+)$", &m) {
                current := Map()
                current["file"] := m[1]
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
        for entry in entries
            entry["warning"] := SubStr(entry["message"], 1, 8) = "Warning:"
        return entries
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

    ; A pre-run text scan of the candidate and the files it includes. Two
    ; questions only: does it touch the clipboard (so the gate serialises it
    ; against other agents' clipboard users), and does it use the module
    ; system (which walks straight past the shim). Plain text by design — it
    ; has to answer for files that do not load.
    ;
    ; The shim's shadows are declarations in the main module. Every module
    ; implicitly imports the built-ins from the AHK module, and no module sees
    ; another's names unless it imports them — so:
    ;   - an import that names AHK, in any spelling (#Import AHK {...},
    ;     #Import {...} from AHK, the Import statement forms), hands the main
    ;     module the original built-in under a name no shadow covers;
    ;   - code under #Module, or in a module file reached by an import, never
    ;     sees the shadows at all: its Send is the real Send.
    ; The first sets "importsAhk", the second "modules". Either one means the
    ; candidate cannot be dry-run safely, and ShimRun refuses to run it.
    ;
    ; Includes are followed when they resolve to a plain path: relative to the
    ; including file, through %A_ScriptDir% / %A_LineFile%, or <Lib> in the
    ; candidate's own Lib folder. Bounded so a pathological include graph
    ; cannot stall a gate.
    static ScanSource(path) {
        found := Map()
        found["clipboard"] := false
        found["importsAhk"] := false
        found["modules"] := false
        found["files"] := 0
        SplitPath(path, , &scriptDir)
        seen := Map()
        seen.CaseSense := "Off"
        queue := [path]
        while (queue.Length && found["files"] < 60) {
            file := queue.RemoveAt(1)
            if seen.Has(file)
                continue
            seen[file] := true
            ; The harness's own files are infrastructure, not candidate code:
            ; HarnessCore names ClipboardAll for its clipboard guard, and
            ; following a test's TestKit include into it marked every unit
            ; test a clipboard user — serialising the whole pure tier behind
            ; one lock (measured: clipboard=1 for a pure arithmetic test).
            if (file != path && this.IsHarnessFile(file))
                continue
            try {
                if !FileExist(file) || InStr(FileExist(file), "D")
                    continue
                text := FileRead(file, "UTF-8")
            } catch Error as err {
                OutputDebug("Harness: scan cannot read " file ": " err.Message)
                continue
            }
            found["files"] += 1
            SplitPath(file, , &fileDir)
            includeDir := fileDir
            inBlock := false
            for line in StrSplit(text, "`n", "`r") {
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
                ; Raw text minus a trailing comment: DllCall("OpenClipboard")
                ; keeps its API name inside a string literal.
                raw := RegExReplace(trimmed, "\s;.*$")
                if RegExMatch(raw, "i)\b(A_Clipboard|ClipboardAll|ClipWait|OnClipboardChange|OpenClipboard|SetClipboardData|EmptyClipboard)\b")
                    found["clipboard"] := true
                if RegExMatch(raw, "i)^(?:#Import\b|#Module\b|(?:export\s+)?import\s+[`"'{*\w])") {
                    if RegExMatch(raw, "i)\bAHK\b")
                        found["importsAhk"] := true
                    else
                        found["modules"] := true
                }
                if !RegExMatch(raw, "i)^#Include(?:Again)?\s+(?:\*i\s+)?(.+)$", &m)
                    continue
                target := Trim(m[1], " `t`"'")
                if RegExMatch(target, "^<(.+)>$", &lib) {
                    target := scriptDir "\Lib\" lib[1] ".ahk"
                } else {
                    target := StrReplace(target, "%A_ScriptDir%", scriptDir)
                    target := StrReplace(target, "%A_LineFile%", file)
                    target := StrReplace(target, "%A_AppData%", A_AppData)
                    target := StrReplace(target, "%A_MyDocuments%", A_MyDocuments)
                    if InStr(target, "%")
                        continue
                    if !RegExMatch(target, "^(?:[A-Za-z]:[\\/]|[\\/]{2})")
                        target := includeDir "\" target
                }
                target := this.FullPath(target)
                if InStr(FileExist(target), "D") {
                    includeDir := target
                    continue
                }
                if (seen.Count < 200)
                    queue.Push(target)
            }
        }
        return found
    }

    ; One of the harness's own library files: a known name sitting beside a
    ; HarnessCore.ahk, whichever copy of the harness it belongs to.
    static IsHarnessFile(file) {
        SplitPath(file, &name, &dir)
        for known in ["HarnessCore.ahk", "TestKit.ahk", "ShimRun.ahk", "DryRunShim.ahk"] {
            if (name = known)
                return FileExist(dir "\HarnessCore.ahk") != ""
        }
        return false
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
        if (path = "" || !FileExist(path))
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

    ; A path given on the command line. AutoHotkey v2 starts every script with
    ; its working directory set to A_ScriptDir, so a relative argument resolved
    ; with GetFullPathName lands in the harness folder rather than where the
    ; caller ran the command — measured: GateDryRun.ahk Tests\x.ahk reported a
    ; missing file. A_InitialWorkingDir is where the caller was.
    ;
    ; MSYS (/c/x) and WSL (/mnt/c/x) spellings arrive unconverted when the
    ; shell's own path conversion is off, so they are mapped to drive paths.
    static ResolveArg(path) {
        if RegExMatch(path, "^/(?:mnt/)?([A-Za-z])(?:/(.*))?$", &m)
            path := StrUpper(m[1]) ":\" StrReplace(m[2], "/", "\")
        if RegExMatch(path, "^(?:[A-Za-z]:[\\/]|[\\/]{2})")
            return this.FullPath(path)
        if (SubStr(path, 1, 1) = "\" || SubStr(path, 1, 1) = "/")
            return this.FullPath(SubStr(A_InitialWorkingDir, 1, 2) path)
        return this.FullPath(A_InitialWorkingDir "\" path)
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
        else
            outDir := this.ResolveArg(outDir)
        DirCreate(outDir)
        ctx := Map()
        ctx["run"] := runId
        ctx["label"] := label
        ctx["out"] := outDir
        return ctx
    }
}

; Named mutexes in the session namespace. Abandoned counts as acquired: the
; previous holder died, and whatever it guarded is free again.
class HarnessLock {
    static Acquire(name, timeoutMs) {
        handle := DllCall("CreateMutexW", "Ptr", 0, "Int", 0, "WStr", "Local\" name, "Ptr")
        if !handle
            return 0
        wait := DllCall("WaitForSingleObject", "Ptr", handle, "UInt", timeoutMs, "UInt")
        if (wait = 0 || wait = 0x80)
            return handle
        DllCall("CloseHandle", "Ptr", handle)
        return 0
    }

    static Release(handle) {
        if !handle
            return
        DllCall("ReleaseMutex", "Ptr", handle)
        DllCall("CloseHandle", "Ptr", handle)
    }
}

; A_Clipboard is a built-in variable no shim can shadow, so a candidate that
; writes it reaches the real clipboard. The guard snapshots the user's data
; and watches the clipboard sequence number between wait slices. A write by
; the candidate marks the snapshot for restoring once the candidate is gone —
; not at once, because a candidate that writes the clipboard and reads it back
; would otherwise read the user's data and fail for a reason that is not its
; own. A write by anyone else is the user copying something mid-run; it
; becomes the new snapshot, so the restore never clobbers it.
;
; The writer is identified by the clipboard owner window's process. No owner
; at all counts as the candidate: AutoHotkey opens the clipboard with its own
; main window, which is destroyed when the candidate exits — so a write made
; just before exit shows up ownerless. Restores happen only when something
; changed, so an untouched clipboard (and the user's clipboard history) sees
; nothing.
;
; Candidates that use the clipboard are serialised across parallel agents
; through a named mutex, so two of them cannot interleave writes and read
; back each other's data.
class HarnessClipGuard {
    __New(serialize := false, lockTimeoutMs := 120000) {
        this.Lock := 0
        this.LockState := "not-needed"
        if serialize {
            this.Lock := HarnessLock.Acquire("AHKHarness-Clipboard", lockTimeoutMs)
            this.LockState := this.Lock ? "held" : "timeout"
        }
        this.State := "untouched"
        this.Touches := 0
        this.Pending := false
        this.Note := ""
        this.Seq := DllCall("GetClipboardSequenceNumber", "UInt")
        this.Saved := ""
        this.HaveSnapshot := false
        try {
            this.Saved := ClipboardAll()
            this.HaveSnapshot := true
        } catch Error as err {
            this.Note := "snapshot failed: " err.Message
        }
    }

    Tick(pids) {
        seq := DllCall("GetClipboardSequenceNumber", "UInt")
        if (seq = this.Seq)
            return
        owner := DllCall("GetClipboardOwner", "Ptr")
        ownerPid := 0
        if owner
            DllCall("GetWindowThreadProcessId", "Ptr", owner, "UInt*", &ownerPid)
        ours := !owner
        for pid in pids {
            if (pid = ownerPid)
                ours := true
        }
        this.Seq := seq
        if !ours {
            this.Pending := false
            try {
                this.Saved := ClipboardAll()
                this.HaveSnapshot := true
            } catch Error as err {
                this.Note := "re-snapshot failed: " err.Message
            }
            return
        }
        this.Touches += 1
        this.Pending := true
    }

    Restore() {
        if !this.HaveSnapshot {
            this.State := "restore-failed"
            this.Seq := DllCall("GetClipboardSequenceNumber", "UInt")
            return
        }
        try {
            A_Clipboard := this.Saved
            if (this.State != "restore-failed")
                this.State := "restored"
        } catch Error as err {
            this.State := "restore-failed"
            this.Note := "restore failed: " err.Message
        }
        this.Seq := DllCall("GetClipboardSequenceNumber", "UInt")
    }

    ; One last look after the child is gone, the restore if the candidate was
    ; the last writer, then the lock goes.
    Finish(pids) {
        try {
            this.Tick(pids)
            if this.Pending
                this.Restore()
            this.Pending := false
        } finally {
            HarnessLock.Release(this.Lock)
            this.Lock := 0
        }
    }
}

; Watches the candidate's top-level windows between wait slices. In a dry run
; every visible window is unexpected — Gui is stubbed and dialogs are shimmed —
; so whatever appears got there by a route the shim does not cover, and is
; recorded. Classification follows the window's structure rather than its
; English text: AutoHotkey's error dialog owns fixed button ids (65400-65411)
; whatever the locale. An error dialog is the one that matters most: it keeps
; the script alive and its message loop answering, so without this a crashed
; candidate sat to the deadline and was scored as an idle, passing script.
;
; Error dialogs end the run. Other dialogs are dismissed with their default
; button (or Cancel / Continue), plain windows are closed, so the candidate
; keeps running down the path a user clicking through would take.
class HarnessWindowWatch {
    __New(scriptName := "") {
        this.ScriptName := scriptName
        this.Seen := Map()
        this.Events := []
        this.Windows := 0
        this.Dialogs := 0
        this.FocusStolen := false
    }

    Tick(pids, state) {
        prior := A_DetectHiddenWindows
        DetectHiddenWindows(false)
        try {
            for pid in pids {
                for hwnd in WinGetList("ahk_pid " pid) {
                    if this.Seen.Has(hwnd)
                        continue
                    this.Seen[hwnd] := true
                    this.Handle(hwnd, pid, state)
                }
            }
            if !this.FocusStolen {
                fg := DllCall("GetForegroundWindow", "Ptr")
                fgPid := 0
                if fg
                    DllCall("GetWindowThreadProcessId", "Ptr", fg, "UInt*", &fgPid)
                for pid in pids {
                    if (fgPid && pid = fgPid) {
                        this.FocusStolen := true
                        break
                    }
                }
            }
        } finally {
            DetectHiddenWindows(prior)
        }
    }

    Handle(hwnd, pid, state) {
        info := HarnessDialog.Describe(hwnd)
        kind := HarnessDialog.Classify(info, this.ScriptName)
        if (kind = "tooltip" || kind = "ahk-main")
            return
        event := Map()
        event["kind"] := kind
        event["class"] := info["class"]
        event["title"] := info["title"]
        event["text"] := info["text"]
        event["pid"] := pid
        if (kind = "ahk-error") {
            event["action"] := "killed"
            state["kill"] := "AutoHotkey error dialog"
            state["killCode"] := 10
        } else if (kind = "ahk-warning") {
            event["action"] := HarnessDialog.Press(hwnd, 11)
        } else if (kind = "inputbox") {
            event["action"] := HarnessDialog.Press(hwnd, 2)
        } else if (kind = "msgbox") {
            event["action"] := HarnessDialog.Press(hwnd, HarnessDialog.DefaultId(hwnd))
        } else {
            DllCall("PostMessageW", "Ptr", hwnd, "UInt", 0x10, "Ptr", 0, "Ptr", 0)
            event["action"] := "closed"
        }
        isDialog := (kind = "ahk-error" || kind = "ahk-warning" || kind = "msgbox"
            || kind = "inputbox" || kind = "fileselect")
        if isDialog
            this.Dialogs += 1
        else
            this.Windows += 1
        this.Events.Push(event)
    }
}

class HarnessDialog {
    static Describe(hwnd) {
        info := Map()
        info["class"] := ""
        info["title"] := ""
        info["text"] := ""
        info["controls"] := []
        try {
            info["class"] := WinGetClass("ahk_id " hwnd)
            info["title"] := WinGetTitle("ahk_id " hwnd)
        } catch Error as err {
            info["error"] := err.Message
            return info
        }
        texts := []
        try {
            for ctl in WinGetControlsHwnd("ahk_id " hwnd) {
                control := Map()
                control["hwnd"] := ctl
                control["id"] := DllCall("GetDlgCtrlID", "Ptr", ctl, "Int")
                control["visible"] := DllCall("IsWindowVisible", "Ptr", ctl, "Int") != 0
                try {
                    control["class"] := WinGetClass("ahk_id " ctl)
                    control["text"] := ControlGetText(ctl)
                } catch Error as err {
                    control["class"] := ""
                    control["text"] := ""
                }
                info["controls"].Push(control)
                if (control["text"] != "" && control["visible"] && control["class"] != "Button" && control["class"] != "Edit")
                    texts.Push(control["text"])
            }
        } catch Error as err {
            info["error"] := err.Message
        }
        joined := ""
        for text in texts
            joined .= (A_Index = 1 ? "" : "`n") text
        info["text"] := joined
        return info
    }

    static Classify(info, scriptName := "") {
        cls := info["class"]
        if (SubStr(cls, 1, 13) = "AutoHotkeyGUI")
            return "ahk-gui"
        if (cls = "AutoHotkey")
            return "ahk-main"
        if (SubStr(cls, 1, 14) = "tooltips_class")
            return "tooltip"
        if (cls != "#32770")
            return "window"

        ids := Map(), buttons := [], hasEdit := false, fileish := false
        for control in info["controls"] {
            ids[control["id"]] := control
            if (control["class"] = "Button")
                buttons.Push(StrReplace(control["text"], "&"))
            if (control["class"] = "Edit")
                hasEdit := true
            if (control["class"] = "DUIViewWndClassName" || control["class"] = "SHELLDLL_DefView"
                || control["class"] = "ComboBoxEx32" || control["class"] = "DirectUIHWND")
                fileish := true
        }
        body := LTrim(info["text"], " `t`r`n")
        warnWord := RegExMatch(body, "^Warning\b")
        if (ids.Has(65400) || ids.Has(65401) || ids.Has(65405) || ids.Has(65411)) {
            ; Warnings hide the Abort button; errors show it.
            abortHidden := ids.Has(2) && !ids[2]["visible"]
            return (abortHidden || warnWord) ? "ahk-warning" : "ahk-error"
        }
        titleIsScript := scriptName != "" && info["title"] = scriptName
        marker := InStr(body, Chr(0x25B6))
        exitBtn := false
        for label in buttons {
            if (label = "ExitApp" || label = "Exit")
                exitBtn := true
        }
        errWord := RegExMatch(body, "^(Error|Critical Error)\b")
        if (warnWord && (titleIsScript || marker))
            return "ahk-warning"
        if (marker && (titleIsScript || errWord || exitBtn))
            return "ahk-error"
        if ((exitBtn || errWord) && titleIsScript)
            return "ahk-error"
        if fileish
            return "fileselect"
        if (hasEdit && buttons.Length >= 2)
            return "inputbox"
        return "msgbox"
    }

    ; DM_GETDEFID answers MAKELONG(id, DC_HASDEFID) when the dialog has a
    ; default button; without one, Cancel is the least committal answer.
    static DefaultId(hwnd) {
        answer := 0
        ok := DllCall("SendMessageTimeoutW", "Ptr", hwnd, "UInt", 0x0400, "Ptr", 0, "Ptr", 0
            , "UInt", 0x2, "UInt", 500, "Ptr*", &answer, "Ptr")
        if (ok && (answer >> 16) = 0x534B)
            return answer & 0xFFFF
        return 2
    }

    ; Posted, never sent: a dialog's modal loop answers WM_COMMAND without the
    ; gate having to own focus or synthesise input.
    static Press(hwnd, id) {
        DllCall("PostMessageW", "Ptr", hwnd, "UInt", 0x0111, "Ptr", id & 0xFFFF, "Ptr", 0)
        return "pressed " id
    }
}
