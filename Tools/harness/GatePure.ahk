#Requires AutoHotkey v2.1-alpha.30
; Parallel agents run this file at once; the default Prompt would raise a "replace it?" dialog.
#SingleInstance Off

#Include %A_LineFile%\..\ShimRun.ahk

; GatePure.ahk — tier-2 gate: run a script's unit tests and grade them.
;
; "Pure" means deterministic: a unit test calls the script's functions and
; checks what comes back. Tests are written against TestKit.ahk (or the
; fork's qa Assert), which prints machine-readable records and a summary
; line. This gate finds a script's tests, runs each one, and turns those
; records into one NDJSON result per script.
;
; Each test file runs through ShimRun exactly as a dry-run candidate does —
; in place, DryRunShim.ahk injected, inside a kill-on-close job with a memory
; cap, stdout and stderr captured, dialogs and the clipboard watched — so a
; test that reaches for Send, FileDelete or MsgBox records the intent instead
; of touching the machine. --no-shim runs tests unshimmed (still jobbed and
; watched), for a test that has to call the real built-ins.
;
; Discovery, per candidate:
;   - a candidate that is itself a test (*.test.ahk, Test_*.ahk, *_Test.ahk)
;     is its own only test;
;   - otherwise <stem>.test.ahk, Test_<stem>.ahk and <stem>_Test.ahk, looked
;     for next to the script, in its Tests\, tests\ and !Tests\ folders, and
;     in those three folders under its parent;
;   - plus every --tests FILE, which applies to every candidate given.
; Finding none is a pass with tests: 0 — a coverage gap the checker reports
; on its own, never a verdict on the script.
;
; Grading one test file:
;   - an AHKTEST|summary line that agrees with the exit code (exit = failed,
;     or 99 once failed reaches 99) gives the counts; one that disagrees is a
;     critical test-crash;
;   - without one, the fork's qa line "qa: P passed, F failed" stands in;
;   - TestKit records but no summary means the file stopped before Summary()
;     — a critical test-crash whatever the exit code;
;   - no protocol output at all: exit 0 passes, "graded by exit code"; any
;     other exit is a critical test-crash plus the interpreter's diagnostics;
;   - a deadline is a critical "hung" finding and status timeout;
;   - every AHKTEST|fail line, in any of these cases, is one high "assert"
;     finding at the assertion's line — a line in the test file (or, for an
;     uncaught error, wherever it was raised), which the message names.
; A row is fail when any file failed, else timeout when any timed out, else
; error when any could not be run, else pass.
;
;   AutoHotkey64.exe GatePure.ahk <script.ahk> [more.ahk ...] [options]
;
;     --label <name>     agent label, keeps parallel agents' files apart
;     --run <id>         run id, default is a timestamp
;     --out <dir>        scratch dir, default %A_Temp%\ahk-harness\<run>\<label>
;     --timeout <s>      deadline per test file, default 30
;     --maxsleep <ms>    longest honoured Sleep, default 2000 — tests may
;                        legitimately wait; 0 skips sleeping
;     --tests <file>     an extra test file run for every candidate; repeatable
;     --no-shim          run tests without the dry-run shim
;     --quiet            suppress the trailing human summary on stderr
;
; Rows follow contract @2 with tier "pure" and two extras on every row, early
; errors included: tests (test files run) and assertions {passed, failed},
; summed over them. parse is "failed" when a test file could not load
; (exit 12) and "not-parsed" otherwise — this tier never parses the
; candidate itself.
;
; Relative paths resolve against the directory the command was run from.
; Exit: 0 = every script passed, 1 = at least one did not, 2 = usage/tool error.

if !A_Args.Length {
    Print("usage: GatePure.ahk <script.ahk> [more.ahk ...] [--label N] [--run ID] [--out DIR] [--timeout S] [--maxsleep MS] [--tests FILE]... [--no-shim] [--quiet]")
    ExitApp(0)
}

scripts := [], testFiles := [], label := "pure", runId := "", outDir := ""
timeout := 30, maxSleep := 2000, noShim := false, quiet := false
i := 0
while (++i <= A_Args.Length) {
    arg := A_Args[i]
    if (arg = "--quiet") {
        quiet := true
        continue
    }
    if (arg = "--no-shim") {
        noShim := true
        continue
    }
    if (arg = "--label" || arg = "--run" || arg = "--out" || arg = "--timeout"
        || arg = "--maxsleep" || arg = "--tests") {
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
        } else if (arg = "--maxsleep") {
            ; An explicit 0 is meaningful — the shim skips sleeping entirely —
            ; so it must reach the child as 0, never be defaulted away.
            if (!IsInteger(value) || Integer(value) < 0) {
                Print("invalid value for --maxsleep: " value " (whole milliseconds, 0 skips sleeping)")
                ExitApp(2)
            }
            maxSleep := Integer(value)
        } else {
            ; Checked up front: a named test file that does not exist is a
            ; bad invocation, not something to report against every script.
            testPath := Harness.ResolveArg(value)
            attr := FileExist(testPath)
            if (attr = "" || InStr(attr, "D")) {
                Print("test file not found: " value)
                ExitApp(2)
            }
            testFiles.Push(testPath)
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

try {
    ctx := Harness.Context(label, runId, outDir)
} catch Error as err {
    Print("cannot prepare run context: " err.Message)
    ExitApp(2)
}
ctx["timeout"] := timeout
ctx["maxsleep"] := maxSleep
ctx["noshim"] := noShim
ctx["tests"] := testFiles

failed := 0, testsRun := 0, assertsPassed := 0, assertsFailed := 0, uncovered := 0
for path in scripts {
    result := PureGate.Grade(path, ctx, A_Index)
    Harness.Emit(result)
    if (result.Get("status") != "pass")
        failed++
    else if (result.Get("tests") = 0)
        uncovered++
    testsRun += result.Get("tests")
    assertsPassed += result.Get("assertions").Get("passed")
    assertsFailed += result.Get("assertions").Get("failed")
}

; Plain ASCII: FileAppend to "**" writes the ANSI code page, which turned an
; em dash here into mojibake (measured).
if !quiet
    FileAppend(Format("{} script(s): {} passed, {} failed; {} test file(s) run, "
        . "{} assertion(s) passed, {} failed; {} script(s) without unit tests`n"
        , scripts.Length, scripts.Length - failed, failed, testsRun
        , assertsPassed, assertsFailed, uncovered), "**")

ExitApp(failed ? 1 : 0)

class PureGate {
    static Grade(path, ctx, index) {
        started := A_TickCount
        full := Harness.ResolveArg(path)
        res := Harness.Result(ctx, "pure", full)
        checks := [], findings := []

        attr := FileExist(full)
        if (attr = "" || InStr(attr, "D")) {
            ; As at the dry-run tier: the static tier is where "script not
            ; found" is a verdict. By this tier the file has been seen once,
            ; so a path that no longer resolves is an environment problem — a
            ; tool error, not a statement about the script.
            checks.Push(Harness.CheckRow("exists", "error", -1, 0, "file not found"))
            findings.Push(Harness.Finding("critical", "missing-file", 0
                , "script not found: " path, "pure"))
            return this.Done(res, checks, findings, "error", started, 0, 0, 0, "not-parsed")
        }
        checks.Push(Harness.CheckRow("exists", "pass", 0, 0, ""))

        found := this.Discover(full, ctx["tests"])
        if !found["files"].Length {
            ; Coverage, not a verdict: the row passes with tests: 0 and the
            ; checker lists the script as uncovered.
            checks.Push(Harness.CheckRow("discover", "skipped", 0, 0
                , "no unit tests exist — " found["detail"]))
            return this.Done(res, checks, findings, "pass", started, 0, 0, 0, "not-parsed")
        }
        checks.Push(Harness.CheckRow("discover", "pass", 0, 0, found["detail"]))

        statuses := [], ran := 0, passed := 0, failed := 0, loadFailed := false
        for testPath in found["files"] {
            opts := Map()
            opts["stem"] := Format("{}\{:03}-{}.t{}-{}", ctx["out"], index
                , Harness.Slug(Harness.NameOf(full)), A_Index, Harness.Slug(Harness.NameOf(testPath)))
            opts["timeoutMs"] := ctx["timeout"] * 1000
            opts["maxSleep"] := ctx["maxsleep"]
            opts["noShim"] := ctx["noshim"]
            graded := this.GradeFile(ShimRun.Run(testPath, opts), testPath, ctx)
            for row in graded["checks"]
                checks.Push(row)
            for f in graded["findings"]
                findings.Push(f)
            statuses.Push(graded["status"])
            if graded["ran"]
                ran++
            passed += graded["passed"]
            failed += graded["failed"]
            if (graded["exit"] = 12)
                loadFailed := true
        }
        return this.Done(res, checks, findings, this.Overall(statuses), started
            , ran, passed, failed, loadFailed ? "failed" : "not-parsed")
    }

    ; A definite failure says more about the script than a timeout, and a
    ; timeout more than a test that could not be run at all. The lesser
    ; outcomes stay visible in their own test rows.
    static Overall(statuses) {
        for wanted in ["fail", "timeout", "error"] {
            for status in statuses {
                if (status = wanted)
                    return wanted
            }
        }
        return "pass"
    }

    static IsTest(name) => RegExMatch(name, "i)(\.test\.ahk|_test\.ahk)$|^test_.+\.ahk$") > 0

    static Discover(full, extra) {
        SplitPath(full, &name, &dir, , &stem)
        found := Map()
        found["files"] := []
        seen := Map()
        seen.CaseSense := "Off"
        if this.IsTest(name) {
            this.AddFile(found["files"], seen, full)
            detail := name " is itself a test file"
        } else {
            names := [stem ".test.ahk", "Test_" stem ".ahk", stem "_Test.ahk"]
            looked := []
            for place in this.Places(dir) {
                looked.Push(place)
                for testName in names {
                    candidate := place "\" testName
                    attr := FileExist(candidate)
                    if (attr != "" && !InStr(attr, "D"))
                        this.AddFile(found["files"], seen, Harness.FullPath(candidate))
                }
            }
            detail := "looked in " this.Join(looked, "; ") " for " this.Join(names, " | ")
        }
        if extra.Length {
            for testPath in extra
                this.AddFile(found["files"], seen, testPath)
            detail .= "; --tests " this.Join(this.Names(extra), ", ")
        }
        if found["files"].Length
            detail := "found " this.Join(found["files"], ", ") " — " detail
        found["detail"] := detail
        return found
    }

    ; The script's folder, its test folders, and the same test folders one
    ; level up. Spellings that name one folder on a case-insensitive file
    ; system (Tests, tests) are visited — and reported — once.
    static Places(dir) {
        wanted := [dir, dir "\Tests", dir "\tests", dir "\!Tests"]
        SplitPath(dir, , &parent)
        if (parent != "" && parent != dir) {
            wanted.Push(parent "\Tests")
            wanted.Push(parent "\tests")
            wanted.Push(parent "\!Tests")
        }
        places := [], seen := Map()
        seen.CaseSense := "Off"
        for place in wanted {
            place := Harness.FullPath(place)
            if seen.Has(place)
                continue
            seen[place] := true
            places.Push(place)
        }
        return places
    }

    static AddFile(files, seen, path) {
        if seen.Has(path)
            return
        seen[path] := true
        files.Push(path)
    }

    static GradeFile(run, testPath, ctx) {
        name := Harness.NameOf(testPath)
        graded := Map()
        graded["checks"] := []
        graded["findings"] := []
        graded["passed"] := 0
        graded["failed"] := 0
        graded["ran"] := false
        graded["exit"] := -1
        graded["status"] := "error"

        if (run["refused"] != "") {
            graded["checks"].Push(Harness.CheckRow("preflight", "error", -1, 0, name ": " run["refused"]))
            graded["checks"].Push(Harness.CheckRow("test:" name, "error", -1, 0
                , "not run — refused by the preflight scan"))
            graded["findings"].Push(Harness.Finding("high", "shim-bypass", 0
                , name " was not run: " run["refused"] ". --no-shim runs it without the shim.", "pure"))
            return graded
        }
        if run.Has("note") {
            graded["checks"].Push(Harness.CheckRow("test:" name, "error", run.Get("exit", -1)
                , run.Get("ms", 0), run["note"]))
            graded["findings"].Push(Harness.Finding("medium", "test-not-run", 0
                , name " could not be run: " run["note"], "pure"))
            return graded
        }

        graded["ran"] := true
        exitCode := run["exit"]
        graded["exit"] := exitCode
        protocol := this.ReadProtocol(run["stdout"])
        toolError := ""
        diag := this.Diagnostics(run, &toolError)
        crash := []
        status := "pass"

        summary := protocol["summary"]
        source := "AHKTEST"
        if (!(summary is Map) && protocol["qa"] is Map) {
            summary := protocol["qa"]
            source := "qa"
        }
        if (summary is Map) {
            graded["passed"] := summary["passed"]
            graded["failed"] := summary["failed"]
        } else {
            graded["failed"] := protocol["fails"].Length
        }

        if run["timedOut"] {
            ; Unlike the dry-run tier, an answering message loop is no pass
            ; here: a test is meant to end, and one still looping, waiting or
            ; held resident by a timer or GUI never reached Summary().
            status := "timeout"
            crash.Push(Harness.Finding("critical", "hung", 0
                , Format("{} did not finish within {} s and was killed — {}", name, ctx["timeout"]
                    , run["responsive"]
                        ? "it was still running and answering messages (looping, waiting, or held resident by a timer, GUI or hotkey), so Summary() was never reached"
                        : "its message loop was blocked"), "pure"))
            detail := Format("timeout after {} s", ctx["timeout"])
        } else if run["killed"] {
            status := "fail"
            crash.Push(Harness.Finding("critical", "test-crash", 0
                , name " was stopped by the harness: " run["killReason"], "pure"))
            detail := "killed: " run["killReason"]
        } else if (summary is Map) {
            detail := this.SummaryLine(summary, source)
            if !this.Agrees(exitCode, summary["failed"]) {
                status := "fail"
                crash.Push(Harness.Finding("critical", "test-crash", 0
                    , Format("{}: the summary says {} passed, {} failed, but the process exited {} — "
                        . "something ran after Summary(), or the summary was printed by hand"
                        , name, summary["passed"], summary["failed"], exitCode), "pure"))
                detail .= " — disagrees with exit " exitCode
            } else if (summary["failed"] > 0 || protocol["fails"].Length) {
                status := "fail"
            }
        } else if protocol["tagged"] {
            ; TestKit announces itself on load and always ends with
            ; Summary(); records without one mean the file stopped part-way,
            ; even if whatever stopped it exited 0.
            status := "fail"
            crash.Push(Harness.Finding("critical", "test-crash", 0
                , Format("{} started TestKit but never reached Summary() — it stopped early (exit {})"
                    , name, exitCode), "pure"))
            detail := Format("no summary line — stopped before Summary(), exit {}", exitCode)
        } else if (exitCode = 0) {
            detail := "no summary line — graded by exit code"
        } else {
            status := "fail"
            crash.Push(Harness.Finding("critical", "test-crash", 0
                , Format("{} exited {} without a summary line{}", name, exitCode
                    , exitCode = 12 ? " — it failed to load" : ""), "pure"))
            detail := Format("no summary line — exit {}", exitCode)
        }

        ; Every assertion record is a finding whatever else happened: the
        ; failures a file reported before it crashed or hung are still real.
        for record in protocol["fails"]
            graded["findings"].Push(Harness.Finding("high", "assert", this.LineOf(record)
                , this.AssertMessage(name, record), "pure"))
        if (source = "qa" && !protocol["fails"].Length) {
            for text in protocol["qaFails"]
                graded["findings"].Push(Harness.Finding("high", "assert", 0, name ": " text, "pure"))
        }
        if (status = "fail" && !crash.Length && !graded["findings"].Length)
            graded["findings"].Push(Harness.Finding("high", "assert", 0
                , Format("{}: {} assertion(s) failed, but no failure records were printed"
                    , name, graded["failed"]), "pure"))
        if crash.Length {
            for f in crash
                graded["findings"].Push(f)
            ; The interpreter's own diagnostics say where it stopped; the
            ; shim's structured error records stand in when stderr is empty.
            for f in (diag.Length ? diag : this.ErrorRecords(run))
                graded["findings"].Push(f)
        }
        for f in protocol["malformed"]
            graded["findings"].Push(Harness.Finding("medium", "protocol", 0, name ": " f, "pure"))
        this.WatchFindings(run, name, graded["findings"])

        if run["actions"].Length
            detail .= " — " this.Intercepted(run["actions"])
        if run["dropped"].Length
            detail .= " — shim shadows dropped (the test defines them): " this.Join(run["dropped"], ", ")
        if run.Has("tickError") {
            detail .= " — watcher error: " run["tickError"]
            if (status = "pass")
                status := "error"
        }
        if (toolError != "")
            status := "error"
        graded["status"] := status
        rowStatus := (status = "pass") ? "pass" : (status = "error") ? "error" : "fail"
        graded["checks"].Push(Harness.CheckRow("test:" name, rowStatus, exitCode, run["ms"], detail))
        if (toolError != "")
            graded["checks"].Push(Harness.CheckRow("shim", "error", -1, 0, name ": " toolError))
        ; The raw streams ride along as informational rows — status pass with
        ; exit 0 keeps the checker from reading them as contradictions.
        if (run["stderr"] != "")
            graded["checks"].Push(Harness.CheckRow("stderr:" name, "pass", 0, 0, run["stderr"]))
        if (crash.Length && run["stdout"] != "")
            graded["checks"].Push(Harness.CheckRow("stdout:" name, "pass", 0, 0, run["stdout"]))
        return graded
    }

    ; A unit test that reaches for the desktop or the disk is worth knowing
    ; about even when the shim kept it harmless: "2 side effect(s)
    ; intercepted: fs FileDelete, ui MsgBox".
    static Intercepted(actions) {
        names := [], seen := Map()
        for action in actions {
            key := action["kind"] " " action["name"]
            if seen.Has(key)
                continue
            seen[key] := true
            if (names.Length < 8)
                names.Push(key)
        }
        more := (seen.Count > names.Length) ? ", ..." : ""
        return Format("{} side effect(s) intercepted by the shim: {}{}", actions.Length, this.Join(names, ", "), more)
    }

    ; TestKit exits with failed capped at 99; the fork's qa Assert exits with
    ; failed itself. Either one agrees.
    static Agrees(exitCode, failed) => exitCode = failed || (failed >= 99 && exitCode = 99)

    static SummaryLine(summary, source) {
        line := Format("qa: {} passed, {} failed", summary["passed"], summary["failed"])
        if (source = "qa")
            return line " (qa summary line, no TestKit records)"
        return line Format(" — {} case(s), {} error(s)", summary["cases"], summary["errors"])
    }

    ; The protocol lines TestKit prints, plus the fork's qa summary and its
    ; "  FAIL ..." lines for qa-style tests. A tagged line whose JSON does not
    ; parse is reported, and a damaged fail record still counts as a failure.
    ; Any tagged line — start included — marks a TestKit file, which owes a
    ; summary.
    static ReadProtocol(text) {
        protocol := Map()
        protocol["fails"] := []
        protocol["summary"] := ""
        protocol["qa"] := ""
        protocol["qaFails"] := []
        protocol["malformed"] := []
        protocol["tagged"] := false
        for line in StrSplit(text, "`n", "`r") {
            if RegExMatch(line, "^AHKTEST\|(start|fail|case|summary)\|(.*)$", &m) {
                protocol["tagged"] := true
                try {
                    record := HarnessJson.Parse(m[2])
                    if !(record is Map)
                        throw ValueError("not a JSON object")
                    if (m[1] = "summary" && !this.CountsOk(record, ["passed", "failed", "cases", "errors"]))
                        throw ValueError("summary counts are not non-negative integers")
                } catch Error as err {
                    protocol["malformed"].Push("unreadable AHKTEST|" m[1] " record (" err.Message "): "
                        . Harness.Clip(m[2], 300))
                    if (m[1] = "fail") {
                        damaged := Map()
                        damaged["message"] := "unreadable failure record: " Harness.Clip(m[2], 300)
                        protocol["fails"].Push(damaged)
                    }
                    continue
                }
                if (m[1] = "fail")
                    protocol["fails"].Push(record)
                else if (m[1] = "summary")
                    protocol["summary"] := record
                continue
            }
            if RegExMatch(line, "^qa: (\d+) passed, (\d+) failed\s*$", &m) {
                qa := Map()
                qa["passed"] := Integer(m[1])
                qa["failed"] := Integer(m[2])
                protocol["qa"] := qa
                continue
            }
            if RegExMatch(line, "^\s*FAIL (.+)$", &m)
                protocol["qaFails"].Push(Trim(m[1]))
        }
        return protocol
    }

    static CountsOk(record, keys) {
        for key in keys {
            if (!record.Has(key) || !IsInteger(record[key]) || record[key] < 0)
                return false
        }
        return true
    }

    ; "brokencalc.test.ahk, case "multiplies", Mul(3, 4): Eq: values differ
    ; — expected 12, actual 7 (brokencalc.test.ahk:12)"
    static AssertMessage(testName, record) {
        text := testName
        caseName := this.Field(record, "test")
        if (caseName != "")
            text .= ", case `"" caseName "`""
        label := this.Field(record, "label")
        if (label != "")
            text .= ", " label
        message := this.Field(record, "message")
        text .= ": " (message != "" ? message : "assertion failed")
        expected := this.Field(record, "expected")
        actual := this.Field(record, "actual")
        if (expected != "" || actual != "")
            text .= " — expected " expected ", actual " actual
        file := this.Field(record, "file")
        if (file != "")
            text .= " (" Harness.NameOf(file) ":" this.LineOf(record) ")"
        return text
    }

    static Field(record, key) {
        if !record.Has(key)
            return ""
        value := record[key]
        return IsObject(value) ? "" : String(value)
    }

    static LineOf(record) {
        value := record.Get("line", 0)
        return (!IsObject(value) && IsInteger(value)) ? Integer(value) : 0
    }

    ; The interpreter's diagnostics, split the way the dry-run gate splits
    ; them: one raised inside the shim belongs to the tool — a warning there
    ; is noise to drop, an error means the run cannot be trusted — and every
    ; other one belongs to the test or the code it loaded.
    static Diagnostics(run, &toolError) {
        shimFile := run["shim"]
        found := []
        for entry in Harness.DiagEntries(run["stderr"]) {
            if (shimFile != "" && entry["file"] = shimFile) {
                if !entry["warning"]
                    toolError := "the shim itself raised: " entry["message"]
                continue
            }
            message := entry["message"] " [in " Harness.NameOf(entry["file"]) "]"
            if entry["warning"]
                found.Push(Harness.Finding("medium", "warn", entry["line"], message, "pure"))
            else
                found.Push(Harness.Finding("critical", "runtime", entry["line"], message, "pure"))
        }
        for err in run["errors"] {
            if (shimFile != "" && err["file"] = shimFile)
                toolError := "the shim itself threw " err["type"] ": " err["message"]
        }
        return found
    }

    ; The shim's OnError records: the exact type, file and line of every
    ; error the test let escape. Only consulted when stderr said nothing.
    static ErrorRecords(run) {
        found := []
        for err in run["errors"] {
            if (run["shim"] != "" && err["file"] = run["shim"])
                continue
            message := err["type"] ": " err["message"]
            if (err["extra"] != "")
                message .= " | Specifically: " err["extra"]
            if (err["file"] != "")
                message .= " [in " Harness.NameOf(err["file"]) "]"
            found.Push(Harness.Finding("critical", "runtime", err["line"], message, "pure"))
        }
        return found
    }

    ; What the shim cannot catch, ShimRun's watch and clipboard guard see. A
    ; unit test has no business opening a window or writing the clipboard,
    ; so each sighting is reported against the test file that caused it.
    static WatchFindings(run, name, findings) {
        for event in run["events"] {
            what := Format("{} `"{}`" ({}): {}", event["kind"], event["title"], event["class"]
                , Harness.Clip(event["text"], 400))
            if (event["kind"] = "ahk-error")
                findings.Push(Harness.Finding("critical", "error-dialog", 0
                    , name ": AutoHotkey error dialog — run ended: " what, "pure"))
            else if (event["kind"] = "ahk-warning")
                findings.Push(Harness.Finding("medium", "warn-dialog", 0
                    , name ": AutoHotkey warning dialog, " event["action"] ": " what, "pure"))
            else if (event["kind"] = "msgbox" || event["kind"] = "inputbox" || event["kind"] = "fileselect")
                findings.Push(Harness.Finding("high", "dialog", 0
                    , name ": a dialog got past the shim, " event["action"] ": " what, "pure"))
            else
                findings.Push(Harness.Finding("medium", "window-leak", 0
                    , name ": a window appeared, " event["action"] ": " what, "pure"))
        }
        if run["watch"].FocusStolen
            findings.Push(Harness.Finding("high", "focus-stolen", 0
                , name " took the foreground window during its run", "pure"))
        if (run["guard"].State = "restore-failed")
            findings.Push(Harness.Finding("high", "clipboard-restore-failed", 0
                , name " wrote the clipboard and the user's data could not be put back: " run["guard"].Note, "pure"))
    }

    static Names(paths) {
        names := []
        for path in paths
            names.Push(Harness.NameOf(path))
        return names
    }

    static Join(items, separator) {
        out := ""
        for item in items
            out .= (A_Index = 1 ? "" : separator) item
        return out
    }

    static Done(res, checks, findings, status, started, tests, passed, failed, parse) {
        assertions := JObj()
        assertions.Set("passed", passed)
        assertions.Set("failed", failed)
        extra := []
        extra.Push(["parse", parse])
        extra.Push(["tests", tests])
        extra.Push(["assertions", assertions])
        return Harness.Finish(res, checks, findings, status, started, extra)
    }
}
