#Requires AutoHotkey v2.1-alpha.30
#SingleInstance Off ; the default prompts "replace the older instance?" even when not persistent; parallel reducers must never block on it

#Include %A_LineFile%\..\ShimRun.ahk

; Reduce.ahk — delta-debugging reducer for the grading harness.
;
; Shrinks a failing script to the fewest lines that still fail THE SAME WAY,
; so a failure found in a 600-line candidate can be read, filed and fixed
; from a handful of lines.
;
;   AutoHotkey64.exe Reduce.ahk <script.ahk> [options]
;
;     --tier static|dryrun  what failing means. static (default): the fork's
;                           check verb exits non-zero. dryrun: a run under
;                           DryRunShim.ahk (see ShimRun.ahk) raises a critical
;                           diagnostic from the script's own code, or wedges
;                           past the deadline when the original wedged
;     --match <regex>       target the first failing diagnostic whose message
;                           matches (case-insensitive) instead of the first
;     --out <file>          the reduced script, default
;                           <scratch>\<name>.reduced.ahk
;     --budget <s>          wall-clock budget for the whole reduction, default
;                           120; it is checked between trials
;     --timeout <s>         deadline for each trial run, default 10
;     --isolated            write trial files to the scratch dir instead of
;                           next to the script
;     --run <id>            run id, default is a timestamp
;     --label <name>        agent label, default reduce
;     --quiet               suppress the human summary on stderr
;
; Relative paths resolve against the directory the command was run from. The
; scratch dir is %A_Temp%\ahk-harness\<run>\<label>, as for the gates.
;
; On success stdout carries exactly one JSON line:
;   {"schema":"ahk-harness/reduce@1","script":...,"tier":...,"signature":...,
;    "original_lines":N,"reduced_lines":M,"trials":T,"budget_exhausted":bool,
;    "out":...}
; trials counts every trial run, the unmodified-copy check included.
; Exit: 0 = a reduced script was written, 2 = usage error, nothing to reduce,
; or a tool error — the reason is printed in place of the JSON line.
;
; What "the same way" means. The target is a signature taken from the
; ORIGINAL run: the failing diagnostic's headline and its Specifically:
; token, with the script's path and name, every run of digits and every run
; of whitespace normalised away, and the echoed source context and call stack
; dropped — those quote neighbouring lines, paths and line numbers, which
; every trial changes. A trial reproduces only when one of its own failing
; diagnostics carries exactly that signature, so a reduction cannot drift
; into a different bug that happens to survive more deletions.
;
; One exception, measured: a load error's Specifically is not a token but an
; echo of the failing statement, and an unclosed "(" makes the parser join
; every following line into that echo — to the end of the file. Kept
; verbatim, it would pin every later line in place. Such an echo is cut back
; to the failing line's own text, which pins the failure to that line and
; nothing else.
;
; The search is complement-based ddmin over lines, as in ahkh's reducer,
; alternated with a pass that tries each brace-balanced block whole. Every
; removal it keeps was a trial that failed the same way, so the output is
; exactly a text that was seen to fail. "minimal" is claimed only when the
; search ran to its end: no single remaining line, and no brace block, can
; go. A run cut short by --budget says so in budget_exhausted.
;
; Trials are written next to the original as .<name>.reduce-<pid>.ahk, so
; relative #Includes and A_ScriptDir resolve exactly as for the original;
; --isolated writes them to the scratch dir instead. Before reducing, the
; unmodified text is run once from the trial path: if it does not fail the
; same way there, no trial could be trusted, so the tool stops and says why.
; The trial file is deleted when the run ends, error or not. The original is
; only ever read.

; A bare launch is not an error — it is how the editor's post-edit check runs
; the file, and how a reader discovers the flags.
if !A_Args.Length {
    Print("usage: Reduce.ahk <script.ahk> [--tier static|dryrun] [--match REGEX] [--out FILE] [--budget S] [--timeout S] [--isolated] [--run ID] [--label N] [--quiet]")
    ExitApp(0)
}

script := "", tier := "static", match := "", outFile := "", runId := "", label := "reduce"
budget := 120, timeout := 10, isolated := false, quiet := false
i := 0
while (++i <= A_Args.Length) {
    arg := A_Args[i]
    if (arg = "--quiet") {
        quiet := true
        continue
    }
    if (arg = "--isolated") {
        isolated := true
        continue
    }
    if (arg = "--tier" || arg = "--match" || arg = "--out" || arg = "--budget"
        || arg = "--timeout" || arg = "--run" || arg = "--label") {
        if (i = A_Args.Length) {
            Print("missing value for " arg)
            ExitApp(2)
        }
        value := A_Args[++i]
        if (arg = "--tier") {
            if (value != "static" && value != "dryrun") {
                Print("invalid value for --tier: " value " (static or dryrun)")
                ExitApp(2)
            }
            tier := StrLower(value)
        } else if (arg = "--match") {
            match := value
        } else if (arg = "--out") {
            outFile := value
        } else if (arg = "--run") {
            runId := value
        } else if (arg = "--label") {
            label := value
        } else {
            ; Validated here so a malformed number lands on the usage exit
            ; rather than an uncaught TypeError dump.
            if (!IsInteger(value) || Integer(value) < 1) {
                Print("invalid value for " arg ": " value " (whole seconds, minimum 1)")
                ExitApp(2)
            }
            if (arg = "--budget")
                budget := Integer(value)
            else
                timeout := Integer(value)
        }
        continue
    }
    if (SubStr(arg, 1, 2) = "--") {
        Print("unknown option: " arg)
        ExitApp(2)
    }
    if (script != "") {
        Print("one script per run: got " script " and " arg)
        ExitApp(2)
    }
    script := arg
}

if (script = "") {
    Print("no script given")
    ExitApp(2)
}

matchRx := ""
if (match != "") {
    matchRx := Reducer.MatchPattern(match)
    try {
        RegExMatch("", matchRx)
    } catch Error as err {
        Print("invalid --match regex: " err.Message)
        ExitApp(2)
    }
}

try {
    ctx := Harness.Context(label, runId, "")
} catch Error as err {
    Print("cannot prepare run context: " err.Message)
    ExitApp(2)
}

cfg := Map()
cfg["given"] := script
cfg["script"] := Harness.ResolveArg(script)
cfg["tier"] := tier
cfg["match"] := match
cfg["matchRx"] := matchRx
cfg["out"] := (outFile != "") ? Harness.ResolveArg(outFile) : ""
cfg["budgetMs"] := budget * 1000
cfg["timeoutMs"] := timeout * 1000
cfg["isolated"] := isolated
cfg["quiet"] := quiet
cfg["ctx"] := ctx

try {
    code := Reducer(cfg).Run()
} catch Error as err {
    ; Run reports every expected failure itself, and its finally has already
    ; removed the trial file. Reaching here is a bug in this tool — it still
    ; has to end on the tool-error exit, never on a dialog.
    Print("reduce: internal error: " err.Message " (" Harness.NameOf(err.File) " line " err.Line ")")
    code := 2
}
ExitApp(code)

; Stops a reduction with a reason for the caller: nothing to reduce, a result
; that could not be trusted, or a tool that could not run. Never a verdict on
; the script, and always exit 2.
class ReduceHalt extends Error {
}

class Reducer {
    __New(cfg) {
        this.Cfg := cfg
        this.Full := cfg["script"]
        SplitPath(this.Full, &name, &dir, , &stem)
        this.ScriptName := name
        this.ScriptDir := dir
        this.ScriptStem := stem
        out := cfg["ctx"]["out"]
        this.Scratch := out "\" Harness.Slug(name)
        ; The pid keeps two reducers working on one script from sharing a
        ; trial, and lets a later run tell an orphan from a live one. The
        ; leading dot marks it as a tool's scratch file, not the user's.
        this.TrialFile := (cfg["isolated"] ? out : dir) "\." stem ".reduce-" ProcessExist() ".ahk"
        this.OutFile := (cfg["out"] != "") ? cfg["out"] : out "\" stem ".reduced.ahk"
        this.Lines := []
        this.Eol := "`r`n"
        this.FinalEol := true
        this.Bom := false
        this.Target := ""
        this.Trials := 0
        this.Hung := 0
        ; Each full path goes before the bare name it ends with; apart from
        ; those pairs no needle contains another, so no other order matters.
        this.Needles := [this.TrialFile, this.Full, Harness.NameOf(this.TrialFile), name]
    }

    Run() {
        started := A_TickCount
        if (!FileExist(this.Full) || InStr(FileExist(this.Full), "D")) {
            Print("script not found: " this.Cfg["given"])
            return 2
        }
        if (this.OutFile = this.Full || this.TrialFile = this.Full) {
            Print("refusing to write over the script being reduced: " this.Full)
            return 2
        }
        if InStr(FileExist(this.OutFile), "D") {
            Print("--out names a directory, not a file: " this.OutFile)
            return 2
        }
        try {
            this.Load()
        } catch Error as err {
            Print("cannot read " this.Full ": " err.Message)
            return 2
        }
        if !this.Cfg["isolated"]
            this.SweepOrphans()

        ; finally covers every exception; the exit callback covers an exit
        ; that unwinds nothing, such as the tray menu's Exit mid-trial.
        cleanup := ObjBindMethod(this, "OnExitCleanup")
        OnExit(cleanup)
        try {
            result := this.Reduce(started)
        } catch ReduceHalt as err {
            Print(err.Message)
            return 2
        } finally {
            this.RemoveTrial()
            OnExit(cleanup, 0)
        }
        this.Report(result, started)
        return 0
    }

    Reduce(started) {
        deadline := started + this.Cfg["budgetMs"]
        original := this.Observe(this.Full, this.Lines, "original")
        target := this.PickTarget(original)
        if !(target is Map)
            throw ReduceHalt(this.NoRepro(original))
        this.Target := target["signature"]

        copy := this.Trial(this.Lines)
        if !this.Matches(copy)
            throw ReduceHalt(this.Diverged(copy))

        ; ddmin alone only guarantees that no single line can go, and code
        ; nests: measured on the runtime canary, it stopped at seven lines —
        ; the failing call plus an emptied class whose six lines can only go
        ; together and never fell into one chunk. So a converged ddmin is
        ; followed by a pass over brace-balanced blocks, and the two alternate
        ; until a block pass finds nothing. The last ddmin before that ended
        ; on its own, so the result keeps ddmin's guarantee.
        reduced := Map()
        reduced["lines"] := this.Lines
        reduced["exhausted"] := false
        loop {
            pass := this.DDMin(reduced["lines"], deadline)
            reduced["lines"] := pass["lines"]
            if pass["exhausted"] {
                reduced["exhausted"] := true
                break
            }
            blocks := this.BlockPass(reduced["lines"], deadline)
            progress := blocks["lines"].Length < reduced["lines"].Length
            reduced["lines"] := blocks["lines"]
            if blocks["exhausted"] {
                reduced["exhausted"] := true
                break
            }
            if !progress
                break
        }
        try {
            SplitPath(this.OutFile, , &outDir)
            if (outDir != "" && !InStr(FileExist(outDir), "D"))
                DirCreate(outDir)
            this.WriteText(this.OutFile, this.Compose(reduced["lines"]))
        } catch Error as err {
            throw ReduceHalt("reduce: cannot write " this.OutFile ": " err.Message)
        }
        return reduced
    }

    ; Complement-based ddmin over lines, as in ahkh's reducer: split the
    ; current set into n chunks and try dropping each in turn. A drop that
    ; still fails the same way is kept and the granularity eases back (n - 1,
    ; floor 2); a full pass that drops nothing doubles n. A pass at one line
    ; per chunk that drops nothing is the stopping proof — no single remaining
    ; line can go — and the only claim of minimality this tool makes. Running
    ; out of budget at any other point is reported as exactly that.
    DDMin(items, deadline) {
        cur := items
        n := 2
        exhausted := false
        while (cur.Length >= 2) {
            if (A_TickCount >= deadline) {
                exhausted := true
                break
            }
            size := Ceil(cur.Length / n)
            dropped := false
            start := 1
            while (start <= cur.Length) {
                if (A_TickCount >= deadline) {
                    exhausted := true
                    break
                }
                rest := this.Without(cur, start, size)
                if (rest.Length && this.Matches(this.Trial(rest))) {
                    cur := rest
                    n := Max(n - 1, 2)
                    dropped := true
                    break
                }
                start += size
            }
            if exhausted
                break
            if !dropped {
                if (n >= cur.Length)
                    break
                n := Min(cur.Length, n * 2)
            }
        }
        result := Map()
        result["lines"] := cur
        result["exhausted"] := exhausted
        return result
    }

    ; One trial per block, largest first, so a whole class goes before its
    ; methods are tried one by one; a block inside one already removed is
    ; skipped. Every removal is still a verified trial, so a span the brace
    ; count got wrong — braces inside a continuation section, say — costs a
    ; trial and nothing else.
    BlockPass(lines, deadline) {
        gone := Map()
        exhausted := false
        for span in this.Blocks(lines) {
            if (A_TickCount >= deadline) {
                exhausted := true
                break
            }
            covered := false
            loop span[2] - span[1] + 1 {
                if gone.Has(span[1] + A_Index - 1)
                    covered := true
            }
            if covered
                continue
            rest := []
            for line in lines {
                if (!gone.Has(A_Index) && (A_Index < span[1] || A_Index > span[2]))
                    rest.Push(line)
            }
            if (rest.Length && this.Matches(this.Trial(rest))) {
                loop span[2] - span[1] + 1
                    gone[span[1] + A_Index - 1] := true
            }
        }
        kept := []
        for line in lines {
            if !gone.Has(A_Index)
                kept.Push(line)
        }
        result := Map()
        result["lines"] := kept
        result["exhausted"] := exhausted
        return result
    }

    ; [first, last] line spans, largest first: a line that opens more braces
    ; than it closes, through the line where the depth comes back down — so
    ; an if / } else { / } chain is one block. Literals and trailing comments
    ; are blanked first (Harness.StripCode), so a "{" in a message is not a
    ; block, and block comments are skipped. A brace alone on its line
    ; (Allman style) takes the header line above it along, or the header
    ; would be left dangling.
    Blocks(lines) {
        before := [], after := [], codes := []
        depth := 0, inComment := false
        for line in lines {
            trimmed := Trim(line, " `t")
            code := ""
            if inComment {
                if (SubStr(trimmed, 1, 2) = "*/")
                    inComment := false
            } else if (SubStr(trimmed, 1, 2) = "/*") {
                inComment := !InStr(SubStr(trimmed, 3), "*/")
            } else {
                code := Trim(Harness.StripCode(trimmed), " `t")
            }
            codes.Push(code)
            before.Push(depth)
            StrReplace(code, "{", , , &opens)
            StrReplace(code, "}", , , &closes)
            depth += opens - closes
            after.Push(depth)
        }
        spans := []
        for code in codes {
            first := A_Index
            if (after[first] <= before[first])
                continue
            last := 0
            loop lines.Length - first {
                if (after[first + A_Index] <= before[first]) {
                    last := first + A_Index
                    break
                }
            }
            if !last
                continue
            if (code = "{") {
                while (first > 1 && codes[first - 1] = "")
                    first--
                if (first > 1)
                    first--
            }
            ; Insertion keeps the list largest first; a handful of blocks
            ; per script does not warrant a sort routine.
            size := last - first + 1
            at := spans.Length + 1
            for span in spans {
                if (size > span[2] - span[1] + 1) {
                    at := A_Index
                    break
                }
            }
            spans.InsertAt(at, [first, last])
        }
        return spans
    }

    Without(items, start, size) {
        kept := []
        stop := start + size - 1
        for item in items {
            if (A_Index < start || A_Index > stop)
                kept.Push(item)
        }
        return kept
    }

    Trial(lines) {
        this.Trials += 1
        try {
            this.WriteText(this.TrialFile, this.Compose(lines))
        } catch Error as err {
            hint := this.Cfg["isolated"] ? "" : "; rerun with --isolated to keep trials in the scratch dir"
            throw ReduceHalt("reduce: cannot write the trial file " this.TrialFile ": " err.Message hint)
        }
        return this.Observe(this.TrialFile, lines, "trial")
    }

    Matches(seen) {
        for failure in seen["failures"] {
            if (failure["signature"] == this.Target)
                return true
        }
        return false
    }

    PickTarget(seen) {
        for failure in seen["failures"] {
            if (this.Cfg["matchRx"] = "" || RegExMatch(failure["message"], this.Cfg["matchRx"]))
                return failure
        }
        return ""
    }

    ; One run of the tier on a file whose text is `lines`. Returns a Map:
    ; failures (Array of Map(message, signature), in the order the run
    ; reported them) and detail (a short account of how the run ended).
    Observe(path, lines, role) {
        if (this.Cfg["tier"] = "dryrun")
            return this.ObserveDryRun(path, lines, role)
        return this.ObserveStatic(path, lines, role)
    }

    ObserveStatic(path, lines, role) {
        seen := Map()
        seen["failures"] := []
        tool := Harness.RunTool('check "' path '"', this.Scratch "." role ".check.out", this.Cfg["timeoutMs"])
        code := tool["exit"]
        if (code = -1)
            throw ReduceHalt("reduce: check could not be launched: " tool["output"])
        if (code = 137) {
            ; RunTool's own deadline, never an answer from check. A load that
            ; hangs on the original is a tool problem; on a trial it is simply
            ; not this failure, counted so the summary can say so.
            if (role = "original")
                throw ReduceHalt("reduce: check did not finish on the original within "
                    . this.Cfg["timeoutMs"] // 1000 " s; raise --timeout")
            this.Hung += 1
            seen["detail"] := "check timed out"
            return seen
        }
        seen["detail"] := "check exit " code
        if (code = 0)
            return seen
        for entry in Harness.DiagEntries(tool["output"]) {
            if !entry["warning"]
                seen["failures"].Push(this.Failure(entry, path, lines))
        }
        ; A failed check with no diagnostic in the usual shape still failed;
        ; its first line of output is the only description there is.
        if !seen["failures"].Length
            seen["failures"].Push(this.Pseudo("check exit " code ": " this.FirstLine(tool["output"])))
        return seen
    }

    ; Diagnostics raised inside the shim are the tool's, not the script's, so
    ; they never become a target or a match. A wedge — killed at the deadline
    ; with its message loop not answering — is appended after the real
    ; diagnostics as a failure of its own, so it is the target only when the
    ; original produced nothing else or --match asks for it. An idle script
    ; still answering at the deadline (exit 124) is the contracted pass.
    ObserveDryRun(path, lines, role) {
        seen := Map()
        seen["failures"] := []
        seen["shim"] := ""
        opts := Map()
        opts["stem"] := this.Scratch "." role
        opts["timeoutMs"] := this.Cfg["timeoutMs"]
        dry := ShimRun.Run(path, opts)
        if (dry["refused"] != "")
            throw ReduceHalt("reduce: " dry["refused"])
        if dry.Has("note")
            throw ReduceHalt("reduce: the dry run could not be launched: " dry["note"])
        if dry.Has("tickError")
            throw ReduceHalt("reduce: the dry-run watcher failed, so the run cannot be trusted: " dry["tickError"])
        shim := dry["shim"]
        for entry in Harness.DiagEntries(dry["stderr"]) {
            if (shim != "" && entry["file"] = shim) {
                if !entry["warning"]
                    seen["shim"] := entry["message"]
                continue
            }
            if !entry["warning"]
                seen["failures"].Push(this.Failure(entry, path, lines))
        }
        wedged := (dry["timedOut"] && dry["exit"] = 137)
        if wedged
            seen["failures"].Push(this.Pseudo("timeout: wedged, no response at the deadline (hard killed)"))
        detail := "exit " dry["exit"]
        if dry["timedOut"]
            detail .= wedged ? ", wedged at the deadline" : ", idle at the deadline"
        if (dry["killReason"] != "")
            detail .= ", killed: " dry["killReason"]
        seen["detail"] := detail
        return seen
    }

    Failure(entry, path, lines) {
        failure := Map()
        failure["message"] := entry["message"]
        if (entry["file"] != path)
            failure["message"] .= " [in " Harness.NameOf(entry["file"]) "]"
        failure["signature"] := this.Signature(entry, path, lines)
        return failure
    }

    Pseudo(message) {
        failure := Map()
        failure["message"] := message
        failure["signature"] := this.Normalise(message)
        return failure
    }

    ; DiagEntries folds a headline's continuation lines into its message with
    ; " | ": the Specifically token, then the echoed source lines ("5| code",
    ; "> 7| code") and the call stack. Only the headline and the token
    ; identify the failure.
    Signature(entry, path, lines) {
        head := entry["message"], spec := ""
        if RegExMatch(entry["message"], "^(.*?)(?: \| Specifically: (.*?))?(?: \| (?:(?:> ?)?\d+\||Call stack:).*)?$", &m) {
            head := m[1]
            spec := m[2]
        }
        own := (entry["file"] = path)
        if (spec != "" && own) {
            code := this.CodeAt(lines, entry["line"])
            if (code != "" && SubStr(this.Squash(spec), 1, StrLen(code)) = code)
                spec := code
        }
        sig := head
        if (spec != "")
            sig .= " | Specifically: " spec
        if !own
            sig .= " [in " Harness.NameOf(entry["file"]) "]"
        return this.Normalise(sig)
    }

    ; The failing line as the interpreter echoes it: trimmed, whitespace
    ; runs squashed, a trailing comment cut — the echo arrives without one.
    CodeAt(lines, n) {
        if (n < 1 || n > lines.Length)
            return ""
        return this.Squash(RegExReplace(lines[n], "(^|\s);.*$"))
    }

    Normalise(text) {
        for needle in this.Needles
            text := StrReplace(text, needle, "<script>", false)
        return this.Squash(RegExReplace(text, "\d+", "#"))
    }

    Squash(text) {
        return Trim(RegExReplace(text, "\s+", " "))
    }

    FirstLine(text) {
        for line in StrSplit(text, "`n", "`r") {
            if (Trim(line) != "")
                return Trim(line)
        }
        return "no output"
    }

    NoRepro(seen) {
        if !seen["failures"].Length {
            text := "nothing to reduce: " this.ScriptName " does not fail at the " this.Cfg["tier"]
                . " tier (" seen["detail"] ")"
            if (seen.Has("shim") && seen["shim"] != "")
                text .= "; note that the shim itself raised: " Harness.Clip(seen["shim"], 300)
            return text
        }
        text := "nothing to reduce: no failing diagnostic of " this.ScriptName
            . " matches --match " this.Cfg["match"] "; it fails with:"
        for failure in seen["failures"] {
            if (A_Index > 5) {
                text .= "`n  ...and " (seen["failures"].Length - 5) " more"
                break
            }
            text .= "`n  " Harness.Clip(failure["message"], 300)
        }
        return text
    }

    Diverged(copy) {
        text := "cannot reduce: " this.ScriptName " fails with`n  " this.Target
            . "`nbut the same text run as " this.TrialFile
        if copy["failures"].Length
            text .= " fails differently:`n  " copy["failures"][1]["signature"]
        else
            text .= " does not fail (" copy["detail"] ")"
        if this.Cfg["isolated"]
            text .= "`n--isolated moved the trial away from the script's relative #Include targets and A_ScriptDir; run without it"
        else
            text .= "`nthe script depends on its own file name or path, or its failure is not deterministic"
        return text
    }

    ; BOM, line ending and final newline are all kept as found, so every
    ; trial differs from the original only in the lines it leaves out.
    Load() {
        if (FileGetSize(this.Full) = 0) {
            ; FileRead and File.Read both throw on an empty file on alpha.30.
            this.Lines := []
            this.FinalEol := false
            return
        }
        file := FileOpen(this.Full, "r", "UTF-8")
        if !IsObject(file)
            throw OSError(A_LastError, -1, "cannot open " this.Full)
        try {
            ; Opening skips a byte-order mark and leaves Pos after it, which
            ; is the cheapest way to know whether to write one back.
            this.Bom := file.Pos > 0
            text := file.Read()
        } finally {
            file.Close()
        }
        this.Eol := InStr(text, "`r`n") ? "`r`n" : "`n"
        this.FinalEol := (SubStr(text, -1) = "`n")
        lines := StrSplit(text, "`n", "`r")
        if this.FinalEol
            lines.Pop()
        this.Lines := lines
    }

    Compose(lines) {
        text := ""
        for line in lines
            text .= (A_Index = 1 ? "" : this.Eol) line
        if (this.FinalEol && lines.Length)
            text .= this.Eol
        return text
    }

    WriteText(path, text) {
        file := FileOpen(path, "w", this.Bom ? "UTF-8" : "UTF-8-RAW")
        if !IsObject(file)
            throw OSError(A_LastError, -1, "cannot open " path)
        try {
            file.Write(text)
        } finally {
            file.Close()
        }
    }

    ; A reducer killed outright — an outer deadline, Ctrl+C — never reaches
    ; its finally, so its trial outlives it. The pid in the name says whose
    ; it was; one whose owner is gone is litter, and goes now. A live owner
    ; is another reducer at work and is left alone.
    SweepOrphans() {
        pattern := "^\.\Q" this.ScriptStem "\E\.reduce-(\d+)\.ahk$"
        loop files this.ScriptDir "\." this.ScriptStem ".reduce-*.ahk" {
            if !RegExMatch(A_LoopFileName, pattern, &m)
                continue
            if ProcessExist(Integer(m[1]))
                continue
            try {
                FileDelete(A_LoopFileFullPath)
            } catch Error as err {
                FileAppend("reduce: cannot remove the stale trial " A_LoopFileFullPath ": " err.Message "`n", "**")
            }
        }
    }

    ; Said out loud when it fails: a trial left next to the user's script is
    ; a file they never asked for.
    RemoveTrial() {
        if !FileExist(this.TrialFile)
            return
        try {
            FileDelete(this.TrialFile)
        } catch Error as err {
            FileAppend("reduce: cannot remove the trial file " this.TrialFile ": " err.Message "`n", "**")
        }
    }

    OnExitCleanup(reason, code) {
        this.RemoveTrial()
        return 0
    }

    ; HarnessJson has no boolean — AutoHotkey has none either, true is 1 — so
    ; the line is assembled from encoded values and the one boolean field is
    ; written as a JSON literal.
    Report(result, started) {
        fields := []
        fields.Push(["schema", HarnessJson.Dump("ahk-harness/reduce@1")])
        fields.Push(["script", HarnessJson.Dump(this.Full)])
        fields.Push(["tier", HarnessJson.Dump(this.Cfg["tier"])])
        fields.Push(["signature", HarnessJson.Dump(this.Target)])
        fields.Push(["original_lines", HarnessJson.Dump(this.Lines.Length)])
        fields.Push(["reduced_lines", HarnessJson.Dump(result["lines"].Length)])
        fields.Push(["trials", HarnessJson.Dump(this.Trials)])
        fields.Push(["budget_exhausted", result["exhausted"] ? "true" : "false"])
        fields.Push(["out", HarnessJson.Dump(this.OutFile)])
        parts := []
        for field in fields
            parts.Push(HarnessJson.Str(field[1]) ":" field[2])
        Print("{" HarnessJson.Join(parts) "}")
        if this.Cfg["quiet"]
            return

        seconds := Round((A_TickCount - started) / 1000, 1)
        text := Format("{} [{}]: {} -> {} line(s), {} trial(s), {} s`n"
            , this.ScriptName, this.Cfg["tier"], this.Lines.Length, result["lines"].Length, this.Trials, seconds)
        text .= "  failure: " this.Target "`n"
        if result["exhausted"]
            text .= "  NOT minimal: the " this.Cfg["budgetMs"] // 1000 " s budget ran out. The result still fails"
                . " the same way, but more lines may go; rerun on it or raise --budget`n"
        else
            text .= "  minimal: no single remaining line, and no brace block, can be removed without losing this failure`n"
        if this.Hung
            text .= "  note: " this.Hung " trial(s) hit --timeout and counted as not reproducing`n"
        text .= "  reduced: " this.OutFile "`n"
        FileAppend(text, "**")
    }

    ; AutoHotkey writers put options in front ("i)..."): a prefix that is
    ; already there is kept and gains the i the flag promises; anything else
    ; is prefixed with "i)".
    static MatchPattern(text) {
        if RegExMatch(text, "^([imsxADJUXPSC``nra]+)\)", &m)
            return InStr(m[1], "i", true) ? text : "i" text
        return "i)" text
    }
}
