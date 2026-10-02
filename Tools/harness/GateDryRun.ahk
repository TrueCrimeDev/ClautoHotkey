#Requires AutoHotkey v2.1-alpha.30

; Parallel agents run this same file at once. Without this the interpreter's
; default (Prompt) asks whether to replace the running copy — a dialog on the
; desktop, or a killed run — measured in the fork's CheckPriorInstance.
#SingleInstance Off

#Include %A_LineFile%\..\ShimRun.ahk

; GateDryRun.ahk — tier-3 gate: run a script without giving it the desktop.
;
; Each candidate runs in place with DryRunShim.ahk injected ahead of it (see
; ShimRun.ahk), so its Send, Click, WinActivate, FileDelete and RegWrite
; calls are recorded instead of performed while the script itself executes
; for real. Its run is held in a kill-on-close job with a memory cap and UI
; limits, its stdout and stderr go to scratch files, and between wait slices
; a window watch and a clipboard guard catch what the shim cannot.
;
; Because nothing here competes for focus or synthetic input, this tier fans out
; as wide as the runtime allows. Tier 4 is the serial one. Clipboard users are
; the one exception: they are serialised against each other through a named
; lock, because the clipboard is shared.
;
;   AutoHotkey64.exe GateDryRun.ahk <script.ahk> [more.ahk ...] [options]
;
;     --label <name>     agent label, keeps parallel agents' files apart
;     --run <id>         run id, default is a timestamp
;     --out <dir>        scratch dir, default %A_Temp%\ahk-harness\<run>\<label>
;     --timeout <s>      deadline before the script is killed, default 20
;     --maxsleep <ms>    longest honoured Sleep, default 50; 0 skips sleeping
;     --memory <MB>      per-process memory cap, default 1024; 0 disables it
;     --quiet            suppress the trailing human summary on stderr
;
; Relative paths resolve against the directory the command was run from.
; Exit: 0 = every script passed, 1 = at least one failed, 2 = usage/tool error.

if !A_Args.Length {
    Print("usage: GateDryRun.ahk <script.ahk> [more.ahk ...] [--label N] [--run ID] [--out DIR] [--timeout S] [--maxsleep MS] [--memory MB] [--quiet]")
    ExitApp(0)
}

scripts := [], label := "dryrun", runId := "", outDir := ""
timeout := 20, maxSleep := 50, memory := 1024, quiet := false
i := 0
while (++i <= A_Args.Length) {
    arg := A_Args[i]
    if (arg = "--quiet") {
        quiet := true
        continue
    }
    if (arg = "--label" || arg = "--run" || arg = "--out"
        || arg = "--timeout" || arg = "--maxsleep" || arg = "--memory") {
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
        } else if (arg = "--memory") {
            if (!IsInteger(value) || Integer(value) < 0) {
                Print("invalid value for --memory: " value " (whole megabytes, 0 disables the cap)")
                ExitApp(2)
            }
            memory := Integer(value)
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
ctx["memory"] := memory

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
    static Grade(path, ctx, index) {
        started := A_TickCount
        full := Harness.ResolveArg(path)
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
            return this.Done(res, checks, findings, "error", started, "", Map(), "not-parsed")
        }
        checks.Push(Harness.CheckRow("exists", "pass", 0, 0, ""))

        opts := Map()
        opts["stem"] := ctx["out"] "\" Format("{:03}", index) "-" Harness.Slug(Harness.NameOf(full))
        opts["timeoutMs"] := ctx["timeout"] * 1000
        opts["maxSleep"] := ctx["maxsleep"]
        opts["memoryMB"] := ctx["memory"]
        run := ShimRun.Run(full, opts)

        if (run["refused"] != "") {
            checks.Push(Harness.CheckRow("preflight", "error", -1, 0, run["refused"]))
            findings.Push(Harness.Finding("high", "shim-bypass", 0, run["refused"], "dryrun"))
            return this.Done(res, checks, findings, "error", started, "", run, "not-parsed")
        }
        checks.Push(Harness.CheckRow("preflight", "pass", 0, 0
            , run["scan"]["clipboard"] ? "uses the clipboard — serialised against other agents' clipboard users" : ""))

        if run["dropped"].Length {
            names := ""
            for name in run["dropped"]
                names .= (A_Index = 1 ? "" : ", ") name
            checks.Push(Harness.CheckRow("shim", "pass", 0, 0
                , "the candidate defines " names " itself; those shadows were dropped (its own definition already hides the built-in)"))
        }

        if run.Has("note") {
            checks.Push(Harness.CheckRow("launch", "error", run.Get("exit", -1), run.Get("ms", 0), run["note"]))
            checks.Push(Harness.CheckRow("stderr", "pass", 0, 0, run.Get("stderr", "")))
            return this.Done(res, checks, findings, "error", started, "", run, "not-parsed")
        }

        exitCode := run["exit"]
        status := "pass"
        residency := "exited"
        toolError := ""

        ; Diagnostics raised inside the shim are the tool's, not the
        ; candidate's: a warning there is noise to drop, an error there means
        ; this run cannot be trusted either way.
        shimFile := run["shim"]
        shimNotes := 0
        diag := []
        for entry in Harness.DiagEntries(run["stderr"]) {
            if (shimFile != "" && entry["file"] = shimFile) {
                shimNotes++
                if !entry["warning"]
                    toolError := "the shim itself raised: " entry["message"]
                continue
            }
            message := entry["message"]
            if (entry["file"] != full)
                message .= " [in " Harness.NameOf(entry["file"]) "]"
            if entry["warning"]
                diag.Push(Harness.Finding("medium", "warn", entry["line"], message, "dryrun"))
            else
                diag.Push(Harness.Finding("critical", "runtime", entry["line"], message, "dryrun"))
        }

        if (exitCode = 137 && run["timedOut"]) {
            ; We had to terminate it: its message loop never came back, so its
            ; own watchdog could not fire either.
            status := "timeout"
            residency := "wedged"
            findings.Push(Harness.Finding("critical", "hung", 0
                , Format("no response for {} s — hard killed; message loop blocked"
                    , ctx["timeout"]), "dryrun"))
        } else if (exitCode = 124 && run["timedOut"]) {
            ; Its own message loop was still answering at the deadline. That is
            ; what a hotkey or GUI script is supposed to do, so it is only a
            ; failure if it also reported a problem — and warnings alone do not
            ; condemn a resident script: #Warn fires on every suspicious
            ; variable, and staying resident is the job.
            residency := "idle"
        } else if (exitCode != 0) {
            status := "fail"
        }

        for f in diag
            findings.Push(f)
        this.ErrorFindings(run, full, diag, exitCode, findings, &toolError)
        this.WatchFindings(run, findings)

        guard := run["guard"]
        if (guard.State = "restore-failed")
            findings.Push(Harness.Finding("high", "clipboard-restore-failed", 0
                , "the candidate wrote the clipboard and the user's data could not be put back: " guard.Note, "dryrun"))

        if (run["killed"] && !run["timedOut"])
            status := "fail"
        if (status = "pass" && Harness.HasCritical(findings))
            status := "fail"
        if (status = "fail" && exitCode != 0 && !Harness.HasCritical(findings))
            findings.Push(Harness.Finding("high", "nonzero-exit", 0
                , Format("exited {} with no diagnostic output", exitCode), "dryrun"))
        if (toolError != "")
            status := "error"

        detail := Format("residency={} actions={} exit={}", residency, this.ActionCount(run), exitCode)
        if (run["killReason"] != "")
            detail .= " killed: " run["killReason"]
        checks.Push(Harness.CheckRow("execute"
            , status = "pass" ? "pass" : (status = "timeout" ? "fail" : status)
            , exitCode, run["ms"], detail))

        watchDetail := Format("dialogs={} windows={} focus={} clipboard={} lock={}"
            , run["watch"].Dialogs, run["watch"].Windows, run["watch"].FocusStolen ? "stolen" : "kept"
            , guard.State, guard.LockState)
        if run.Has("tickError")
            watchDetail .= " watcher error: " run["tickError"]
        if !run["jobbed"]
            watchDetail .= " — not jobbed: descendants are not contained"
        checks.Push(Harness.CheckRow("watch", run.Has("tickError") ? "error" : "pass"
            , run.Has("tickError") ? -1 : 0, 0, watchDetail))
        if run.Has("tickError")
            status := "error"
        if (toolError != "")
            checks.Push(Harness.CheckRow("shim", "error", -1, 0, toolError))
        else if shimNotes
            checks.Push(Harness.CheckRow("shim-notes", "pass", 0, 0
                , shimNotes " warning(s) raised inside the shim were dropped"))

        ; The raw streams travel in their own informational rows — status pass
        ; with exit 0 keeps the checker from reading them as contradictions;
        ; CheckRow clips them.
        checks.Push(Harness.CheckRow("stdout", "pass", 0, 0, run["stdout"]))
        checks.Push(Harness.CheckRow("stderr", "pass", 0, 0, run["stderr"]))

        return this.Done(res, checks, findings, status, started, residency, run
            , exitCode = 12 ? "failed" : "not-parsed")
    }

    ; The shim's OnError records carry the exact file and line of every error
    ; the candidate raised. One that also reached stderr is already a
    ; critical finding. One that did not was hidden by the candidate's own
    ; OnError handler. Hiding it does not save the thread it was raised in:
    ; in the auto-execute section the fork still exits 10 (measured), so a
    ; failed run with nothing on stderr makes these records the critical
    ; findings. In a later thread of a script that stays resident, the error
    ; ended only that thread — reported, not fatal. An error raised inside the
    ; shim is a tool fault.
    static ErrorFindings(run, full, diag, exitCode, findings, &toolError) {
        shimFile := run["shim"]
        unmatched := []
        for err in run["errors"] {
            if (shimFile != "" && err["file"] = shimFile) {
                toolError := "the shim itself threw " err["type"] ": " err["message"]
                continue
            }
            matched := false
            for f in diag {
                if (f.Get("severity") = "critical" && f.Get("line") = err["line"])
                    matched := true
            }
            if !matched
                unmatched.Push(err)
        }
        promote := (exitCode != 0 && exitCode != 124 && !Harness.HasCritical(diag))
        for err in unmatched {
            message := err["type"] ": " err["message"]
            if (err["extra"] != "")
                message .= " | Specifically: " err["extra"]
            if (err["file"] != "" && err["file"] != full)
                message .= " [in " Harness.NameOf(err["file"]) "]"
            if promote
                findings.Push(Harness.Finding("critical", "runtime", err["line"]
                    , message " — hidden from stderr by the script's own OnError handler, but the thread still died"
                    , "dryrun"))
            else
                findings.Push(Harness.Finding("medium", "error-suppressed", err["line"]
                    , message " — suppressed by the script's own OnError handler; the thread it was raised in ended"
                    , "dryrun"))
        }
    }

    ; In a dry run every visible window is unexpected — Gui is stubbed and
    ; dialogs are shimmed — so each one is reported by what it was.
    static WatchFindings(run, findings) {
        for event in run["events"] {
            what := Format("{} `"{}`" ({}): {}", event["kind"], event["title"], event["class"]
                , Harness.Clip(event["text"], 400))
            switch event["kind"] {
                case "ahk-error":
                    findings.Push(Harness.Finding("critical", "error-dialog", 0
                        , "AutoHotkey error dialog — run ended: " what, "dryrun"))
                case "ahk-warning":
                    findings.Push(Harness.Finding("medium", "warn-dialog", 0
                        , "AutoHotkey warning dialog, " event["action"] ": " what, "dryrun"))
                case "msgbox", "inputbox", "fileselect":
                    findings.Push(Harness.Finding("high", "dialog", 0
                        , "a dialog got past the shim, " event["action"] ": " what, "dryrun"))
                default:
                    findings.Push(Harness.Finding("medium", "window-leak", 0
                        , "a window appeared despite the stubbed Gui, " event["action"] ": " what, "dryrun"))
            }
        }
        if run["watch"].FocusStolen
            findings.Push(Harness.Finding("high", "focus-stolen", 0
                , "the candidate's process took the foreground window during a dry run", "dryrun"))
    }

    static ActionCount(run) {
        return run.Has("actions") ? run["actions"].Length : 0
    }

    static Done(res, checks, findings, status, started, residency, run, parse) {
        kinds := JObj()
        seen := Map()
        if run.Has("actions") {
            for action in run["actions"]
                seen[action["kind"]] := seen.Get(action["kind"], 0) + 1
        }
        if (run.Has("guard") && run["guard"].Touches)
            seen["clipboard"] := run["guard"].Touches
        for kind, total in seen
            kinds.Set(kind, total)

        guard := JObj()
        guard.Set("clipboard", run.Has("guard") ? run["guard"].State : "untouched")
        guard.Set("dialogs", run.Has("watch") ? run["watch"].Dialogs : 0)
        guard.Set("windows", run.Has("watch") ? run["watch"].Windows : 0)
        guard.Set("focus", (run.Has("watch") && run["watch"].FocusStolen) ? "stolen" : "kept")

        extra := []
        ; This tier never parses the candidate itself: "failed" is the child's
        ; own load failure (exit 12), everything else is "not-parsed".
        extra.Push(["parse", parse])
        ; "unknown" appears only on status "error" rows, where the child never
        ; ran or its exit was unobservable; every real outcome maps to
        ; exited / idle / wedged.
        extra.Push(["residency", residency != "" ? residency : "unknown"])
        extra.Push(["actions", this.ActionCount(run)])
        extra.Push(["intent", kinds])
        extra.Push(["guard", guard])
        return Harness.Finish(res, checks, findings, status, started, extra)
    }
}
