#Requires AutoHotkey v2.1-alpha.30

#Include %A_LineFile%\..\HarnessCore.ahk
#Include %A_LineFile%\..\..\..\Lib\Lint.ahk
#Include %A_LineFile%\..\..\..\Lib\CodeIntel.ahk

; GateStatic.ahk — tier-1 static gate for the AHK v2 grading harness.
;
; Runs the desktop-free checks on each script and writes exactly one NDJSON
; result object per script to stdout: the fork's `check` subcommand, the
; /validate flag as an independent cross-check, Lint.ahk, and CodeIntel.ahk.
;
; A parse failure ends that script's branch. Linting a file the interpreter
; cannot load produces noise, not findings, so the later checks are skipped and
; the result records them as "skipped" rather than reporting zero problems —
; the difference matters to the checker, which treats an empty result as a bug.
;
; Every check runs through the interpreter that is running this script
; (A_AhkPath), so the gate cannot silently grade against the wrong binary.
;
;   AutoHotkey64.exe GateStatic.ahk <script.ahk> [more.ahk ...] [options]
;
;     --label <name>   agent label; echoed into every result and used to keep
;                      parallel agents' scratch files from colliding
;     --run <id>       run id, default is a timestamp
;     --out <dir>      scratch dir, default %A_Temp%\ahk-harness\<run>\<label>
;     --quiet          suppress the trailing human summary on stderr
;
; Exit: 0 = every script passed, 1 = at least one failed, 2 = usage/tool error.

; Bare invocation is not an error — it is how the editor's post-edit check runs
; the file, and how a reader discovers the flags.
if !A_Args.Length {
    Print("usage: GateStatic.ahk <script.ahk> [more.ahk ...] [--label N] [--run ID] [--out DIR] [--quiet]")
    ExitApp(0)
}

scripts := [], label := "gate", runId := "", outDir := "", quiet := false
i := 0
while (++i <= A_Args.Length) {
    arg := A_Args[i]
    if (arg = "--quiet") {
        quiet := true
        continue
    }
    if (arg = "--label" || arg = "--run" || arg = "--out") {
        if (i = A_Args.Length) {
            Print("missing value for " arg)
            ExitApp(2)
        }
        value := A_Args[++i]
        if (arg = "--label")
            label := value
        else if (arg = "--run")
            runId := value
        else
            outDir := value
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

failed := 0
for path in scripts {
    result := StaticGate.Grade(path, ctx, A_Index)
    Harness.Emit(result)
    if (result.Get("status") != "pass")
        failed++
}

if !quiet
    FileAppend(Format("{} script(s): {} passed, {} failed`n"
        , scripts.Length, scripts.Length - failed, failed), "**")

ExitApp(failed ? 1 : 0)

class StaticGate {
    static Grade(path, ctx, index) {
        started := A_TickCount
        full := Harness.FullPath(path)
        res := Harness.Result(ctx, "static", full)
        checks := [], findings := []

        if !FileExist(full) {
            checks.Push(Harness.CheckRow("exists", "fail", -1, 0, "file not found"))
            findings.Push(Harness.Finding("critical", "missing-file", 0
                , "script not found: " path))
            return Harness.Finish(res, checks, findings, "fail", started
                , [["parse", "not-parsed"]])
        }
        checks.Push(Harness.CheckRow("exists", "pass", 0, 0, ""))

        ; Runs before the parse gate on purpose: it is a text scan, so it still
        ; reports on a file the parser cannot load — and those files never reach
        ; Lint or CodeIntel at all.
        v1Start := A_TickCount
        v1 := Harness.V1Isms(full)
        for item in v1
            findings.Push(Harness.Finding("high", item["rule"], item["line"]
                , item["message"], "gate"))
        checks.Push(Harness.CheckRow("v1scan", "pass", 0, A_TickCount - v1Start
            , v1.Length ? v1.Length " v1 API use(s)" : ""))

        prefix := ctx["out"] "\" Format("{:03}", index) "-" Harness.Slug(Harness.NameOf(full))

        ; The fork's purpose-built parse gate. 0 = loadable, 13 = parse failure.
        parse := Harness.RunTool('check "' full '"', prefix ".check.out")
        parseOk := (parse["exit"] = 0)
        checks.Push(Harness.CheckRow("check", parseOk ? "pass" : "fail"
            , parse["exit"], parse["ms"], parse["output"]))

        ; /validate is a second, independent path to the same verdict. Running
        ; both is cheap, and a disagreement is a real finding: it means one of
        ; the two gates is lying about this file.
        valid := Harness.RunTool('/ErrorStdOut /validate "' full '"', prefix ".validate.out")
        validOk := (valid["exit"] = 0)
        checks.Push(Harness.CheckRow("validate", validOk ? "pass" : "fail"
            , valid["exit"], valid["ms"], valid["output"]))

        if (parseOk != validOk)
            findings.Push(Harness.Finding("high", "gate-disagreement", 0
                , Format("check exit {} but /validate exit {} — the two load gates disagree"
                    , parse["exit"], valid["exit"])))

        if !parseOk || !validOk {
            source := parseOk ? valid : parse
            diag := Harness.DiagFindings(source["output"], "gate", "parse")
            ; The gate said this file will not load, so the result has to carry a
            ; critical reason. Warnings alone do not explain a failed load.
            if !Harness.HasCritical(diag)
                diag.Push(Harness.Finding("critical", "parse", 0
                    , source["output"] != "" ? source["output"]
                        : "load failed with no diagnostic output"))
            for f in diag
                findings.Push(f)
            ; Branch ends here: lint and semantic analysis of an unloadable file
            ; would report against a broken parse tree.
            checks.Push(Harness.CheckRow("lint", "skipped", 0, 0, "skipped: parse gate failed"))
            checks.Push(Harness.CheckRow("codeintel", "skipped", 0, 0, "skipped: parse gate failed"))
            return Harness.Finish(res, checks, findings, "fail", started
                , [["parse", "failed"]])
        }

        ; CodeIntel runs first because its HasParseError reports on the shared
        ; tree-sitter parse that Lint uses too. When the grammar hits an error
        ; region both tools reason over a broken tree and invent structural
        ; findings — measured: SyncDrift.ahk drew a bogus "code after a return
        ; is unreachable" that way, while the same rule is clean on a sound
        ; parse. So the flag has to be read before either tool's output is
        ; believed, not reported alongside it.
        raw := [], partial := false, parseState := "clean"

        ciStart := A_TickCount
        try {
            ci := CodeIntel.File(full)
            if ci.HasParseError {
                partial := true
                parseState := "partial"
            }
            for issue in ci.Diagnostics()
                raw.Push(this.Raw("codeintel", issue))
            checks.Push(Harness.CheckRow("codeintel", "pass", 0, A_TickCount - ciStart
                , partial ? "grammar hit error regions — findings marked partial" : ""))
        } catch Error as err {
            ; CodeIntel is the only HasParseError detector, so when it throws
            ; the tree's parse state was never assessed — treat everything that
            ; follows as partial rather than shipping it at full confidence.
            partial := true
            parseState := "error"
            checks.Push(Harness.CheckRow("codeintel", "error", -1, A_TickCount - ciStart
                , err.Message))
        }

        lintStart := A_TickCount
        try {
            for issue in Lint.File(full)
                raw.Push(this.Raw("lint", issue))
            checks.Push(Harness.CheckRow("lint", "pass", 0, A_TickCount - lintStart
                , partial ? "shared parse was partial — findings marked partial" : ""))
        } catch Error as err {
            ; A linter crash is a tool error, not a verdict on the script — say
            ; so, so the checker can flag it instead of scoring a phantom pass.
            checks.Push(Harness.CheckRow("lint", "error", -1, A_TickCount - lintStart
                , err.Message))
        }

        for item in raw {
            severity := this.Severity(item["rule"], item["severity"])
            if partial
                severity := this.Demote(severity)
            findings.Push(Harness.Finding(severity, item["rule"], item["line"]
                , item["message"], item["source"], partial ? "partial" : "full"))
        }

        status := "pass"
        for row in checks {
            if (row.Get("status") = "error")
                status := "error"
        }
        for f in findings {
            if (f.Get("severity") = "critical")
                status := "fail"
        }
        return Harness.Finish(res, checks, findings, status, started
            , [["parse", parseState]])
    }

    static Raw(source, issue) {
        item := Map()
        item["source"] := source
        item["rule"] := issue.Rule
        item["severity"] := issue.Severity
        item["message"] := issue.Message
        item["line"] := issue.Line
        return item
    }

    ; empty-catch is a defect rather than style and is a purely syntactic
    ; judgement, so it outranks the linter's own "warning" tier.
    ;
    ; unreachable-code is capped at medium. It catches genuine dead code, but it
    ; also fires on `for … { if (x) return y }` followed by `return default` —
    ; the search-a-collection idiom — because a loop whose body ends in a return
    ; is treated as terminal for the block around it. Measured on a clean parse,
    ; so this is a rule bug, not the partial-parse effect. Nothing in the message
    ; distinguishes the two cases, so it can be reported but not trusted to drive
    ; an unattended fix.
    ;
    ; undefined-call goes the other way. CodeIntel sees one file, so it cannot
    ; know about a name defined in an #Include, and its built-in table is
    ; incomplete — it flags the built-in error classes (ValueError, TypeError,
    ; …) and even OutputDebug and FileGetSize on a parse it handled perfectly.
    ; It is a lead, not a defect, and ranking it any higher sends a fix loop
    ; chasing working code.
    static Severity(rule, native) {
        graded := Map()
        graded["empty-catch"] := "high"
        graded["unreachable-code"] := "medium"
        graded["undefined-call"] := "low"
        if graded.Has(rule)
            return graded[rule]
        if (native = "error")
            return "high"
        if (native = "warning")
            return "medium"
        return "low"
    }

    ; Findings drawn from a partial parse describe a tree the tooling failed to
    ; build, so they drop a rank rather than being dropped outright — still
    ; visible, never load-bearing enough to drive a fix on their own.
    static Demote(severity) {
        if (severity = "critical")
            return "high"
        if (severity = "high")
            return "medium"
        if (severity = "medium")
            return "low"
        return "low"
    }

}
