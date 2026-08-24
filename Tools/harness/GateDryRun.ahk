#Requires AutoHotkey v2.1-alpha.30

#Include %A_LineFile%\..\HarnessCore.ahk

; GateDryRun.ahk — tier-3 gate: run a UI script without giving it the desktop.
;
; For each candidate this writes a small wrapper that includes DryRunShim.ahk
; and then the candidate. The shim's function definitions shadow the built-ins,
; so the candidate's Send, Click, WinActivate, FileDelete and RegWrite calls are
; recorded instead of performed. The script executes for real; only its effects
; on the outside world are intercepted.
;
; The wrapper is written next to the candidate under a dot-prefixed per-agent
; name, so A_ScriptDir and relative includes resolve to the candidate's own
; directory, and removed as soon as the child is gone. A read-only candidate
; directory falls back to the scratch dir; either way the wrapper sets the
; working directory to the candidate's home.
;
; Because nothing here competes for focus or synthetic input, this tier fans out
; as wide as the runtime allows. Tier 4 is the serial one.
;
;   AutoHotkey64.exe GateDryRun.ahk <script.ahk> [more.ahk ...] [options]
;
;     --label <name>     agent label, keeps parallel agents' files apart
;     --run <id>         run id, default is a timestamp
;     --out <dir>        scratch dir, default %A_Temp%\ahk-harness\<run>\<label>
;     --timeout <s>      deadline before the script is killed, default 20
;     --maxsleep <ms>    longest honoured Sleep, default 50; 0 skips sleeping
;     --quiet            suppress the trailing human summary on stderr
;
; Exit: 0 = every script passed, 1 = at least one failed, 2 = usage/tool error.

if !A_Args.Length {
    Print("usage: GateDryRun.ahk <script.ahk> [more.ahk ...] [--label N] [--run ID] [--out DIR] [--timeout S] [--maxsleep MS] [--quiet]")
    ExitApp(0)
}

scripts := [], label := "dryrun", runId := "", outDir := ""
timeout := 20, maxSleep := 50, quiet := false
i := 0
while (++i <= A_Args.Length) {
    arg := A_Args[i]
    if (arg = "--quiet") {
        quiet := true
        continue
    }
    if (arg = "--label" || arg = "--run" || arg = "--out"
        || arg = "--timeout" || arg = "--maxsleep") {
        if (i = A_Args.Length) {
            Print("missing value for " arg)
            ExitApp(2)
        }
        value := A_Args[++i]
        if (arg = "--label")
            label := value
        else if (arg = "--run")
            runId := value
        else if (arg = "--out")
            outDir := value
        else if (arg = "--timeout") {
            ; Validated here so a malformed number lands on the usage exit
            ; rather than an uncaught TypeError dump.
            if (!IsInteger(value) || Integer(value) < 1) {
                Print("invalid value for --timeout: " value " (whole seconds, minimum 1)")
                ExitApp(2)
            }
            timeout := Integer(value)
        } else {
            ; An explicit 0 is meaningful — the shim skips sleeping entirely —
            ; so it must reach the child as 0, never be defaulted away.
            if (!IsInteger(value) || Integer(value) < 0) {
                Print("invalid value for --maxsleep: " value " (whole milliseconds, 0 skips sleeping)")
                ExitApp(2)
            }
            maxSleep := Integer(value)
        }
        continue
    }
    if (SubStr(arg, 1, 2) = "--") {
        Print("unknown option: " arg)
        ExitApp(2)
    }
    scripts.Push(arg)
}

if !scripts.Length {
    Print("no scripts given")
    ExitApp(2)
}

try
    ctx := Harness.Context(label, runId, outDir)
catch Error as err {
    Print("cannot prepare run context: " err.Message)
    ExitApp(2)
}
ctx["timeout"] := timeout
ctx["maxsleep"] := maxSleep

failed := 0
for path in scripts {
    result := DryRunGate.Grade(path, ctx, A_Index)
    Harness.Emit(result)
    if (result.Get("status") != "pass")
        failed++
}

if !quiet
    FileAppend(Format("{} script(s): {} passed, {} failed`n"
        , scripts.Length, scripts.Length - failed, failed), "**")

ExitApp(failed ? 1 : 0)

class DryRunGate {
    static Shim := A_LineFile "\..\DryRunShim.ahk"

    static Grade(path, ctx, index) {
        started := A_TickCount
        full := Harness.FullPath(path)
        res := Harness.Result(ctx, "dryrun", full)
        checks := [], findings := []

        if !FileExist(full) {
            ; The static tier is where "script not found" is a gradeable
            ; verdict. By this tier the file has already been seen once, so a
            ; path that no longer resolves is an environment problem — a tool
            ; error, not a statement about the script.
            checks.Push(Harness.CheckRow("exists", "error", -1, 0, "file not found"))
            findings.Push(Harness.Finding("critical", "missing-file", 0
                , "script not found: " path))
            return this.Done(res, checks, findings, "error", started, "", [], "not-parsed")
        }
        checks.Push(Harness.CheckRow("exists", "pass", 0, 0, ""))

        stem := ctx["out"] "\" Format("{:03}", index) "-" Harness.Slug(Harness.NameOf(full))
        logFile := stem ".intent.tsv"
        errFile := stem ".stderr.txt"
        safeCopy := stem ".candidate.ahk"
        SplitPath(full, , &candDir)
        ; Next to the candidate so A_ScriptDir resolves to the candidate's own
        ; directory. Dot-prefixed to stay out of most globs; label plus pid
        ; keeps two agents grading the same directory apart.
        wrapper := candDir "\.harness-" Harness.Slug(ctx["label"]) "-" ProcessExist() ".wrapper.ahk"
        scratchWrapper := stem ".wrapper.ahk"

        for stale in [wrapper, scratchWrapper, safeCopy, logFile, errFile] {
            if FileExist(stale) {
                try {
                    FileDelete(stale)
                } catch Error as err {
                    OutputDebug("GateDryRun: cannot clear " stale ": " err.Message)
                }
            }
        }

        ; #Include dereferences a paired %...% even inside quotes (verified:
        ; a directory named pre%A_ScriptDir%post expands and the load fails),
        ; so a candidate path carrying a literal % cannot be included in place.
        ; A copy under a %-free scratch name is included instead; the wrapper
        ; still sets the working directory to the candidate's real home.
        include := full, copied := ""
        if InStr(full, "%") {
            if InStr(safeCopy, "%") {
                checks.Push(Harness.CheckRow("wrapper", "error", -1, 0
                    , "candidate and scratch paths both contain % — nowhere to include from"))
                return this.Done(res, checks, findings, "error", started, "", [], "not-parsed")
            }
            try {
                FileCopy(full, safeCopy, 1)
            } catch Error as err {
                checks.Push(Harness.CheckRow("wrapper", "error", -1, 0
                    , "cannot copy %-path candidate to scratch: " err.Message))
                return this.Done(res, checks, findings, "error", started, "", [], "not-parsed")
            }
            include := safeCopy, copied := safeCopy
        }

        wrote := ""
        try {
            try {
                this.WriteWrapper(wrapper, include, candDir)
                wrote := wrapper
                checks.Push(Harness.CheckRow("wrapper", "pass", 0, 0, ""))
            } catch Error as err {
                try {
                    this.WriteWrapper(scratchWrapper, include, candDir)
                    wrote := scratchWrapper
                    checks.Push(Harness.CheckRow("wrapper", "pass", 0, 0
                        , "candidate dir not writable (" err.Message ") — wrapper in scratch"))
                } catch Error as err2 {
                    checks.Push(Harness.CheckRow("wrapper", "error", -1, 0, err2.Message))
                    return this.Done(res, checks, findings, "error", started, "", [], "not-parsed")
                }
            }

            EnvSet("AHK_HARNESS_LOG", logFile)
            EnvSet("AHK_HARNESS_MAXSLEEP", ctx["maxsleep"])

            ; A_Clipboard is a built-in variable the shim cannot shadow, so a
            ; clipboard-writing candidate reaches the real clipboard. Snapshot
            ; here, restore in the finally below. Accepted residual race:
            ; parallel dryrun agents share the one system clipboard, so a
            ; concurrent agent's candidate can still interleave between this
            ; snapshot and its restore.
            try {
                clipSaved := ClipboardAll()
            } catch Error as err {
                OutputDebug("GateDryRun: clipboard snapshot failed: " err.Message)
            }

            launch := Harness.RunTimed(Format('/ErrorStdOut "/StdErrFile={}" "{}"', errFile, wrote)
                , ctx["timeout"] * 1000)

            stderr := Harness.ReadOutput(errFile)
            actions := this.ReadLog(logFile)
            diag := Harness.DiagFindings(stderr, "dryrun", "runtime")

            exitCode := launch["exit"]
            status := "pass"
            residency := "exited"

            if launch.Has("note") {
                checks.Push(Harness.CheckRow("launch", "error", exitCode, launch["ms"], launch["note"]))
                checks.Push(Harness.CheckRow("stderr", "pass", 0, 0, stderr))
                return this.Done(res, checks, findings, "error", started, "", actions, "not-parsed")
            }

            if (exitCode = 137) {
                ; We had to terminate it: its message loop never came back, so its
                ; own watchdog could not fire either.
                status := "timeout"
                residency := "wedged"
                findings.Push(Harness.Finding("critical", "hung", 0
                    , Format("no response for {} s — hard killed; message loop blocked"
                        , ctx["timeout"]), "dryrun"))
            } else if (exitCode = 124) {
                ; Its own watchdog fired, which proves it was still pumping
                ; messages. That is what a hotkey or GUI script is supposed to do,
                ; so it is only a failure if it also reported a problem.
                residency := "idle"
                ; Warnings alone do not condemn a resident script — #Warn fires on
                ; every suspicious variable, and staying resident is the job.
                if Harness.HasCritical(diag) {
                    status := "fail"
                } else {
                    status := "pass"
                }
            } else if (exitCode != 0) {
                status := "fail"
            }

            checks.Push(Harness.CheckRow("execute"
                , status = "pass" ? "pass" : (status = "timeout" ? "fail" : status)
                , exitCode, launch["ms"]
                , Format("residency={} actions={}", residency, actions.Length)))

            ; GateStatic keeps each tool's raw output in its check rows;
            ; DiagFindings keeps only the headlines it can fold, so the raw
            ; stderr — the "Specifically:" detail included — travels in its own
            ; informational row. Status pass with exit 0 keeps the checker from
            ; reading it as a contradiction; CheckRow clips it to 2000 chars.
            checks.Push(Harness.CheckRow("stderr", "pass", 0, 0, stderr))

            for f in diag
                findings.Push(f)

            if (status = "fail" && !Harness.HasCritical(findings))
                findings.Push(Harness.Finding("high", "nonzero-exit", 0
                    , Format("exited {} with no diagnostic output", exitCode), "dryrun"))

            return this.Done(res, checks, findings, status, started, residency, actions
                , exitCode = 12 ? "failed" : "not-parsed")
        } finally {
            if IsSet(clipSaved) {
                try {
                    A_Clipboard := clipSaved
                } catch Error as err {
                    OutputDebug("GateDryRun: clipboard restore failed: " err.Message)
                }
            }
            ; RunTimed only returns once the child is dead or was never started,
            ; so deleting here covers every path, kill paths included. Both
            ; wrapper names go: a half-written first attempt must not linger
            ; next to the candidate.
            for leftover in [wrapper, scratchWrapper, copied] {
                if (leftover = "" || !FileExist(leftover))
                    continue
                try {
                    FileDelete(leftover)
                } catch Error as err {
                    OutputDebug("GateDryRun: cannot remove " leftover ": " err.Message)
                }
            }
        }
    }

    static Done(res, checks, findings, status, started, residency, actions, parse) {
        kinds := JObj()
        seen := Map()
        for action in actions
            seen[action["kind"]] := seen.Get(action["kind"], 0) + 1
        for kind, total in seen
            kinds.Set(kind, total)

        extra := []
        ; This tier never parses the candidate itself: "failed" is the child's
        ; own load failure (exit 12), everything else is "not-parsed".
        extra.Push(["parse", parse])
        ; "unknown" appears only on status "error" rows, where the child never
        ; ran or its exit was unobservable; every real outcome maps to
        ; exited / idle / wedged.
        extra.Push(["residency", residency != "" ? residency : "unknown"])
        extra.Push(["actions", actions.Length])
        extra.Push(["intent", kinds])
        return Harness.Finish(res, checks, findings, status, started, extra)
    }

    ; #SingleInstance Off keeps two dry runs of the same file from replacing
    ; each other. A candidate that sets the directive itself still wins, which
    ; is why agents are handed disjoint script lists.
    ;
    ; SetWorkingDir points at the candidate's directory unconditionally, so a
    ; candidate that resolves paths against the working directory behaves the
    ; same whether the wrapper sits next to it or fell back to scratch.
    static WriteWrapper(wrapperPath, includePath, workDir) {
        body := "#Requires AutoHotkey v2.1-alpha.30`n"
            . "#SingleInstance Off`n"
            . "SetWorkingDir(" this.StrLit(workDir) ")`n"
            . "#Include " this.IncLit(this.Shim) "`n"
            . "#Include " this.IncLit(includePath) "`n"
        file := FileOpen(wrapperPath, "w", "UTF-8")
        if !IsObject(file)
            throw OSError("cannot write wrapper: " wrapperPath)
        try {
            file.Write(body)
        } finally {
            file.Close()
        }
    }

    ; A double-quoted AHK expression literal. Backtick first so later escapes
    ; are not double-escaped; the semicolon needs its escape because the loader
    ; eats a whitespace-preceded ; as a comment even inside a quoted string
    ; (verified: a raw " ; " in the literal fails the load with Missing ").
    static StrLit(text) {
        out := StrReplace(text, "``", "````")
        out := StrReplace(out, '"', '``"')
        out := StrReplace(out, ";", "``;")
        return '"' out '"'
    }

    ; A quoted #Include path. The quotes carry spaces, but the loader still
    ; cuts the line at a whitespace-preceded ; unless it is escaped (verified:
    ; a directory named "a ; b" loads escaped and fails raw).
    static IncLit(path) {
        return '"' StrReplace(path, ";", "``;") '"'
    }

    static ReadLog(logFile) {
        actions := []
        text := Harness.ReadOutput(logFile)
        if (text = "")
            return actions
        for line in StrSplit(text, "`n", "`r") {
            if (line = "")
                continue
            parts := StrSplit(line, "`t")
            if (parts.Length < 3)
                continue
            if (parts[2] = "meta")
                continue
            entry := Map()
            entry["kind"] := parts[2]
            entry["name"] := parts[3]
            actions.Push(entry)
        }
        return actions
    }

}
