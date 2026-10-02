#Requires AutoHotkey v2.1-alpha.30
; Gates waiting on the live lock overlap with the instance holding it, and an
; unspecified #SingleInstance means Prompt: a second agent's gate would raise a
; dialog on the user's desktop or replace the running one.
#SingleInstance Off

#Include %A_LineFile%\..\HarnessCore.ahk

; GateLive.ahk — tier-4 live gate for the AHK v2 grading harness.
;
; The live tier runs the candidate for real: real windows, real dialogs, a real
; message loop. It never does that on the user's desktop. The run is handed to
; ahkh (github.com/owhs/AHKTestHarness), whose native host starts the script on
; a private hidden desktop inside a kill-on-close job, answers its dialogs by
; rule, screenshots them, and watches the user's own session for anything that
; leaks out. This file is only the adapter: it runs ahkh's `run` verb with
; --json and maps what comes back onto the harness contract.
;
; Focus and synthetic input are one shared resource, so live runs are serial by
; contract. That is enforced here rather than trusted to the scheduler: every
; backend run holds the AHKHarness-Live mutex, and a script that cannot get it
; is reported as a tool error, never run unlocked.
;
; The interpreter is pinned to the one running this gate. ahkh's findAhk reads
; ahkh.json's ahk.exe before the AHKH_AHK variable (lib/config.mjs:63-65) and
; finds that file by walking up from its working directory, so the variable
; alone can be overridden by a stray project file. The gate therefore writes its
; own ahkh.json into the scratch dir and passes it with --project, sets
; AHKH_AHK as well, and afterwards discards any result whose meta.ahk names a
; different binary.
;
;   AutoHotkey64.exe GateLive.ahk <script.ahk> [more.ahk ...] [options]
;
;     --label <name>       agent label, keeps parallel agents' files apart
;     --run <id>           run id, default is a timestamp
;     --out <dir>          scratch dir, default %A_Temp%\ahk-harness\<run>\<label>
;     --for <s>            observe a script expected to stay resident, default 8
;     --timeout <s>        instead: the script is expected to exit within s
;     --ahkh <dir>         AHKTestHarness clone, default %AHKH_HOME%
;     --node <path>        node.exe for ahkh, default %AHKH_NODE%, PATH, Program Files
;     --ahkh-cmd <prefix>  complete backend command prefix, used verbatim
;     --quiet              suppress the trailing human summary on stderr
;
; Verdicts map onto the contract as: PASS and DIALOG pass (DIALOG with a medium
; finding per dialog), FAIL ERROR CRASH fail, TIMEOUT HUNG time out, LEAK and
; FOCUS-STOLEN fail with a critical finding because the sandbox itself did not
; hold, and anything else is a tool error — as is an ERROR whose only errors
; are ahkh's own host-error findings, since the script was never judged.
;
; Exit: 0 = every script passed, 1 = at least one did not, 2 = usage/tool error
; (bad arguments, no run context, or no usable ahkh backend at all).

; Bare invocation is not an error — it is how the editor's post-edit check runs
; the file, and how a reader discovers the flags.
if !A_Args.Length {
    Print('usage: GateLive.ahk <script.ahk> [more.ahk ...] [--label N] [--run ID] [--out DIR] [--for S | --timeout S] [--ahkh PATH] [--node PATH] [--ahkh-cmd "COMMAND PREFIX"] [--quiet]')
    ExitApp(0)
}

scripts := [], label := "live", runId := "", outDir := "", quiet := false
forSec := 8, timeoutSec := 0, forGiven := false
ahkhRoot := "", nodePath := "", ahkhCmd := ""
i := 0
while (++i <= A_Args.Length) {
    arg := A_Args[i]
    if (arg = "--quiet") {
        quiet := true
        continue
    }
    if (arg = "--label" || arg = "--run" || arg = "--out" || arg = "--for" || arg = "--timeout"
        || arg = "--ahkh" || arg = "--node" || arg = "--ahkh-cmd") {
        if (i = A_Args.Length) {
            Print("missing value for " arg)
            ExitApp(2)
        }
        value := A_Args[++i]
        if (arg = "--label") {
            label := value
        } else if (arg = "--run") {
            runId := value
        } else if (arg = "--out") {
            outDir := value
        } else if (arg = "--ahkh") {
            ahkhRoot := value
        } else if (arg = "--node") {
            nodePath := value
        } else if (arg = "--ahkh-cmd") {
            ahkhCmd := value
        } else {
            ; Validated here so a malformed number lands on the usage exit
            ; rather than reaching ahkh, which would refuse it as BADARG.
            if (!IsInteger(value) || Integer(value) < 1) {
                Print("invalid value for " arg ": " value " (whole seconds, minimum 1)")
                ExitApp(2)
            }
            if (arg = "--for") {
                forSec := Integer(value)
                forGiven := true
            } else {
                timeoutSec := Integer(value)
            }
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
; The two ask ahkh different questions (lib/verbs/run.mjs:58-65): --for
; observes a resident script and stops it, --timeout fails one that does not
; exit. Accepting both would silently answer only one of them.
if (forGiven && timeoutSec) {
    Print("use --for or --timeout, not both")
    ExitApp(2)
}

try {
    ctx := Harness.Context(label, runId, outDir)
} catch Error as err {
    Print("cannot prepare run context: " err.Message)
    ExitApp(2)
}
ctx["for"] := forSec
ctx["timeout"] := timeoutSec
; ahkh's evidence folders go under this agent's scratch dir, never ahkh's
; shared default (<project>\.ahkh\runs), where parallel agents' retention
; pruning would delete each other's evidence.
ctx["evidence"] := ctx["out"] "\ahkh-runs"
ctx["project"] := ctx["out"] "\ahkh.json"

backend := LiveGate.ResolveBackend(ahkhCmd, ahkhRoot, nodePath)
if backend["ok"] {
    try {
        LiveGate.WriteProject(ctx["project"])
    } catch Error as err {
        backend["ok"] := false
        backend["problem"] := "cannot write the pinned ahkh project file " ctx["project"] ": " err.Message
    }
}

failed := 0
for path in scripts {
    ; Live is where the gate reads another tool's output, so it is where an
    ; unexpected shape could throw. That must still produce this script's row
    ; and must never reach an error dialog on the desktop.
    try {
        result := LiveGate.Grade(path, ctx, A_Index, backend)
    } catch Error as err {
        result := LiveGate.Crashed(path, ctx, err)
    }
    Harness.Emit(result)
    if (result.Get("status") != "pass")
        failed++
}

if !quiet {
    FileAppend(Format("{} script(s): {} passed, {} failed`n"
        , scripts.Length, scripts.Length - failed, failed), "**")
    if !backend["ok"]
        FileAppend("ahkh backend unavailable: " backend["problem"] "`n", "**")
}

; A missing backend means nothing was graded at all, which is a tool failure
; rather than a statement about any script; the rows still say why per script.
ExitApp(!backend["ok"] ? 2 : (failed ? 1 : 0))

class LiveGate {
    static LockName := "AHKHarness-Live"
    ; Generous on purpose: a waiting agent only ever waits out other agents'
    ; single script runs, and each of those is bounded by its own deadline.
    static LockTimeoutMs := 900000
    ; ahkh's own time on top of the observation window: host start (up to
    ; 15 s, lib/host.mjs:21), the final control-tree snapshot and screenshot of
    ; a still-running script (30 s and 40 s request timeouts), the kill, the
    ; guard report and host shutdown. Past this the backend itself is wedged.
    static OverheadMs := 90000
    ; ahkh finding kinds that are AutoHotkey itself failing: its error dialog,
    ; a load failure, an uncaught error the probe reported, a process crash,
    ; and a message loop that stopped answering.
    static CriticalKinds := ["ahk-error", "load-error", "runtime-error", "crash", "hung"]

    ; Where ahkh comes from, decided once per gate run. --ahkh-cmd is trusted
    ; verbatim; a repo root is checked for everything `run` needs, so a broken
    ; install is reported with the exact missing piece instead of surfacing as
    ; an unparseable crash on every script.
    static ResolveBackend(cmdPrefix, root, node) {
        found := Map()
        found["ok"] := false
        found["cmd"] := ""
        found["problem"] := ""
        if (cmdPrefix != "") {
            found["ok"] := true
            found["cmd"] := cmdPrefix
            return found
        }
        source := "--ahkh"
        if (root = "") {
            root := EnvGet("AHKH_HOME")
            source := "AHKH_HOME"
        }
        if (root = "") {
            found["problem"] := "ahkh backend not configured: no --ahkh-cmd, no --ahkh, and AHKH_HOME is not set. "
                . this.InstallHint()
            return found
        }
        root := RTrim(Harness.ResolveArg(root), "\/")
        problems := []
        entry := root "\bin\ahkh.mjs"
        if !this.IsFile(entry)
            problems.Push(entry " does not exist, so " source " is not the root of an AHKTestHarness clone")
        ; host.mjs:22 refuses to start without it, and .gitignore keeps it out
        ; of the clone, so a fresh checkout always needs build.ps1 first.
        hostExe := root "\bin\ahkh-host.exe"
        if !this.IsFile(hostExe)
            problems.Push("native host not built: " hostExe " is missing; build it with "
                . 'powershell -NoProfile -ExecutionPolicy Bypass -File "' root '\build.ps1"')
        nodeInfo := this.FindNode(node)
        if (nodeInfo["path"] = "")
            problems.Push(nodeInfo["problem"])
        if problems.Length {
            joined := ""
            for item in problems
                joined .= (A_Index = 1 ? "" : "; ") item
            found["problem"] := "ahkh backend at " root " (from " source ") is not usable: " joined ". "
                . this.InstallHint()
            return found
        }
        found["ok"] := true
        found["cmd"] := '"' nodeInfo["path"] '" "' entry '"'
        return found
    }

    static InstallHint() {
        return "Install: git clone https://github.com/owhs/AHKTestHarness <dir>, then run "
            . "powershell -NoProfile -ExecutionPolicy Bypass -File <dir>\build.ps1 (compiles "
            . "bin\ahkh-host.exe with the .NET Framework 4 csc.exe that ships with Windows), then "
            . "set AHKH_HOME=<dir> or pass --ahkh <dir>. ahkh runs on node >= 18 (--node, AHKH_NODE, "
            . "PATH or C:\Program Files\nodejs\node.exe)."
    }

    ; The same search order ahkh's own findNode uses (lib/config.mjs:92-98),
    ; minus its own process path, behind the two explicit overrides.
    static FindNode(explicit) {
        found := Map()
        found["path"] := ""
        found["problem"] := ""
        source := "--node"
        if (explicit = "") {
            explicit := EnvGet("AHKH_NODE")
            source := "AHKH_NODE"
        }
        if (explicit != "") {
            candidate := Harness.ResolveArg(explicit)
            if this.IsFile(candidate)
                found["path"] := candidate
            else
                found["problem"] := "node not found at " candidate " (from " source ")"
            return found
        }
        for dir in StrSplit(EnvGet("PATH"), ";") {
            dir := Trim(dir, ' "')
            if (dir != "" && this.IsFile(dir "\node.exe")) {
                found["path"] := Harness.FullPath(dir "\node.exe")
                return found
            }
        }
        if this.IsFile("C:\Program Files\nodejs\node.exe") {
            found["path"] := "C:\Program Files\nodejs\node.exe"
            return found
        }
        found["problem"] := "node.exe not found (checked --node, AHKH_NODE, PATH and C:\Program Files\nodejs)"
        return found
    }

    ; keepRuns 0 switches ahkh's retention off (lib/evidence.mjs:111-113): a
    ; batch longer than its default 60 runs would otherwise delete the evidence
    ; folders earlier rows still point at.
    static WriteProject(path) {
        exe := JObj()
        exe.Set("exe", A_AhkPath)
        proj := JObj()
        proj.Set("ahk", exe)
        proj.Set("keepRuns", 0)
        handle := FileOpen(path, "w", "UTF-8-RAW")
        if !IsObject(handle)
            throw OSError("cannot open " path " for writing")
        try {
            handle.Write(HarnessJson.Dump(proj))
        } finally {
            handle.Close()
        }
    }

    static Grade(path, ctx, index, backend) {
        started := A_TickCount
        full := Harness.ResolveArg(path)
        res := Harness.Result(ctx, "live", full)
        checks := [], findings := []

        if !this.IsFile(full) {
            ; The static tier is where "script not found" is a gradeable
            ; verdict. By tier 4 the file has been seen three times already, so
            ; a path that no longer resolves is an environment problem.
            checks.Push(Harness.CheckRow("exists", "error", -1, 0, "file not found"))
            checks.Push(this.Skipped("lock", "script not found"))
            checks.Push(this.Skipped("backend", "script not found"))
            checks.Push(this.Skipped("evidence", "script not found"))
            findings.Push(Harness.Finding("critical", "missing-file", 0
                , "script not found: " path, "live"))
            return this.Done(res, checks, findings, "error", started, "not-parsed", "unknown", "", "")
        }
        checks.Push(Harness.CheckRow("exists", "pass", 0, 0, ""))

        if !backend["ok"] {
            checks.Push(this.Skipped("lock", "no usable backend"))
            checks.Push(Harness.CheckRow("backend", "error", -1, 0, backend["problem"]))
            checks.Push(this.Skipped("evidence", "backend never ran"))
            return this.Done(res, checks, findings, "error", started, "not-parsed", "unknown", "", "")
        }

        waitStart := A_TickCount
        lock := HarnessLock.Acquire(this.LockName, this.LockTimeoutMs)
        waited := A_TickCount - waitStart
        if !lock {
            checks.Push(Harness.CheckRow("lock", "error", -1, waited, Format(
                "could not acquire Local\{} within {} s: another live run still holds the desktop, "
                . "or the mutex could not be created. Live runs are serial by contract, so this "
                . "script was not run unlocked.", this.LockName, this.LockTimeoutMs // 1000)))
            checks.Push(this.Skipped("backend", "not run without the live lock"))
            checks.Push(this.Skipped("evidence", "backend never ran"))
            return this.Done(res, checks, findings, "error", started, "not-parsed", "unknown", "", "")
        }
        try {
            checks.Push(Harness.CheckRow("lock", "pass", 0, waited
                , Format("held Local\{} (waited {} ms)", this.LockName, waited)))
            launch := this.RunBackend(full, ctx, index, backend)
        } catch Error as err {
            checks.Push(Harness.CheckRow("backend", "error", -1, 0, "backend launch threw: " err.Message))
            checks.Push(this.Skipped("evidence", "backend never ran"))
            return this.Done(res, checks, findings, "error", started, "not-parsed", "unknown", "", "")
        } finally {
            HarnessLock.Release(lock)
        }
        return this.Judge(res, checks, started, full, launch)
    }

    ; The row for a script whose grading threw inside the gate itself.
    static Crashed(path, ctx, err) {
        started := A_TickCount
        res := Harness.Result(ctx, "live", Harness.ResolveArg(path))
        checks := []
        checks.Push(Harness.CheckRow("gate", "error", -1, 0
            , Format("GateLive failed while grading: {} ({}, line {})", err.Message, err.What, err.Line)))
        return this.Done(res, checks, [], "error", started, "not-parsed", "unknown", "", "")
    }

    ; One `ahkh run --json`. stdout and stderr stay separate so a node warning
    ; on stderr can never corrupt the JSON the verdict is read from.
    static RunBackend(full, ctx, index, backend) {
        stem := ctx["out"] "\" Format("{:03}", index) "-" Harness.Slug(Harness.NameOf(full))
        SplitPath(full, , , , &nameNoExt)
        ; ahkh names its run folder after the label (lib/evidence.mjs:20), so
        ; label plus index ties every evidence folder to its harness row.
        tag := Harness.Slug(ctx["label"] "-" Format("{:03}", index) "-" nameNoExt)
        if (ctx["timeout"] > 0) {
            mode := " --timeout " ctx["timeout"]
            ; run.mjs:65 waits timeout + 6 s for an exiting script.
            windowMs := ctx["timeout"] * 1000 + 6000
        } else {
            mode := " --for " ctx["for"]
            windowMs := ctx["for"] * 1000
        }
        cmd := backend["cmd"] ' run "' full '" --json'
            . ' --project "' ctx["project"] '"'
            . ' --out "' ctx["evidence"] '"'
            . ' --label "' tag '"' mode

        opts := Map()
        opts["stdout"] := stem ".ahkh.out"
        opts["stderr"] := stem ".ahkh.err"
        opts["cwd"] := ctx["out"]
        opts["timeoutMs"] := windowMs + this.OverheadMs
        ; node is not an AutoHotkey script, so there is no message window to
        ; probe: a backend still running at this deadline is simply wedged.
        opts["probe"] := false
        ; The job's UI limits would forbid the desktop creation and switching
        ; ahkh's native host exists to do.
        opts["uiLimits"] := false
        env := Map()
        env["AHKH_AHK"] := A_AhkPath
        opts["env"] := env

        launch := Harness.Launch(cmd, opts)
        launch["cmd"] := cmd
        launch["deadlineMs"] := opts["timeoutMs"]
        launch["stdout"] := Harness.ReadOutput(opts["stdout"])
        launch["stderr"] := Harness.ReadOutput(opts["stderr"])
        return launch
    }

    static Judge(res, checks, started, full, launch) {
        findings := []
        raw := "stdout: " Harness.Clip(launch["stdout"], 900)
            . " | stderr: " Harness.Clip(launch["stderr"], 600)

        if launch.Has("note") {
            checks.Push(Harness.CheckRow("backend", "error", launch["exit"], launch["ms"]
                , launch["note"] " | cmd: " launch["cmd"] " | " raw))
            checks.Push(this.Skipped("evidence", "backend launch failed"))
            return this.Done(res, checks, findings, "error", started, "not-parsed", "unknown", "", "")
        }
        if launch["timedOut"] {
            ; ahkh enforces its own deadline on the script, so overrunning
            ; this one means the backend broke, not the candidate.
            checks.Push(Harness.CheckRow("backend", "error", 137, launch["ms"]
                , Format("timeout after {}ms — backend killed with its whole job. ", launch["deadlineMs"]) raw))
            checks.Push(this.Skipped("evidence", "backend was killed before it reported"))
            return this.Done(res, checks, findings, "error", started, "not-parsed", "unknown", "", "")
        }

        try {
            out := this.ParseOutput(launch["stdout"])
        } catch Error as err {
            checks.Push(Harness.CheckRow("backend", "error", launch["exit"], launch["ms"]
                , Format("no JSON result from ahkh ({}), exit {}. ", err.Message, launch["exit"]) raw))
            checks.Push(this.Skipped("evidence", "no result to read it from"))
            return this.Done(res, checks, findings, "error", started, "not-parsed", "unknown", "", "")
        }

        ; A thrown verb (missing script, unbuilt host, bad argument) prints
        ; {ok:false, error, code} instead of a run (lib/cli.mjs:65-69).
        if (out.Get("ok", 1) = 0 && !out.Has("verdict")) {
            checks.Push(Harness.CheckRow("backend", "error", launch["exit"], launch["ms"]
                , Format("ahkh refused the run [{}]: {} (exit {})", this.Text(out.Get("code", "ERROR"))
                    , this.Text(out.Get("error", "")), launch["exit"])))
            checks.Push(this.Skipped("evidence", "ahkh reported no run"))
            return this.Done(res, checks, findings, "error", started, "not-parsed", "unknown", "", "")
        }

        verdict := this.Text(out.Get("verdict", ""))
        data := out.Get("data", "")
        if !(data is Map)
            data := Map()
        runDir := this.Text(out.Get("runDir", data.Get("runDir", "")))
        status := this.StatusOf(verdict)
        notes := []
        if (verdict = "")
            notes.Push("ahkh's JSON carries no verdict")
        else if (status = "error")
            notes.Push("unrecognised verdict: the run verb only produces PASS DIALOG FAIL ERROR TIMEOUT HUNG CRASH LEAK FOCUS-STOLEN")

        ; The last line of the pin: whatever ahkh says it launched must be the
        ; binary running this gate, or the verdict belongs to another engine.
        meta := data.Get("meta", "")
        graded := (meta is Map) ? this.Text(meta.Get("ahk", "")) : ""
        if (graded = "") {
            notes.Push("ahkh did not report which interpreter it ran")
        } else if !this.SamePath(graded, A_AhkPath) {
            status := "error"
            notes.Push("ahkh ran " graded ", not the pinned " A_AhkPath " — result discarded")
        }

        expected := this.VerdictExit(verdict)
        if (expected != "" && launch["exit"] != expected)
            notes.Push(Format("exit {} disagrees with verdict {} (ahkh maps it to {})", launch["exit"], verdict, expected))

        errorKinds := [], loadFailed := false, guardDetail := "", hasDialog := false
        ahkhFindings := data.Get("findings", "")
        if (ahkhFindings is Array) {
            for f in ahkhFindings {
                if !(f is Map)
                    continue
                mapped := this.MapFinding(f, full)
                findings.Push(mapped)
                kind := mapped.Get("rule")
                if (this.Text(f.Get("severity", "error")) = "error")
                    errorKinds.Push(kind)
                if (kind = "load-error")
                    loadFailed := true
                if (kind = "dialog")
                    hasDialog := true
                if (guardDetail = "" && SubStr(kind, 1, 6) = "guard-")
                    guardDetail := this.Text(f.Get("message", ""))
            }
        }

        ; ahkh's ERROR also covers its own host failing (KIND_VERDICT maps
        ; host-error to ERROR, lib/session.mjs:11-15). When that is the only
        ; error, the tool broke and the script was never judged.
        if (verdict == "ERROR" && errorKinds.Length) {
            hostOnly := true
            for kind in errorKinds {
                if (kind != "host-error")
                    hostOnly := false
            }
            if hostOnly {
                status := "error"
                notes.Push("every error is ahkh's own host-error, so the script was never judged")
            }
        }

        if (verdict == "DIALOG" && !hasDialog)
            findings.Push(Harness.Finding("medium", "dialog", 0
                , Format("ahkh verdict DIALOG: {} dialog(s) answered; details in {}"
                    , this.Count(data.Get("dialogs", 0)), runDir), "live"))
        if (verdict == "LEAK")
            findings.Push(Harness.Finding("critical", "harness-leak", 0
                , "sandbox did not hold: ahkh verdict LEAK — a window from this run reached the "
                . "user's own desktop, so the run was not isolated" (guardDetail != "" ? " (" guardDetail ")" : ""), "live"))
        if (verdict == "FOCUS-STOLEN")
            findings.Push(Harness.Finding("critical", "focus-stolen", 0
                , "sandbox did not hold: ahkh verdict FOCUS-STOLEN — this run took the user's "
                . "foreground window or left the clipboard unrestored" (guardDetail != "" ? " (" guardDetail ")" : ""), "live"))
        ; The checker rejects a failure that carries nothing actionable.
        if ((status = "fail" || status = "timeout") && !findings.Length)
            findings.Push(Harness.Finding("high", "backend-verdict", 0
                , Format("ahkh returned {} with no findings (exit {}); see {}", verdict, launch["exit"], runDir), "live"))

        detail := Format("{} (exit {})", verdict != "" ? verdict : "no verdict", launch["exit"])
        for note in notes
            detail .= " — " note
        summary := this.Text(out.Get("summary", ""))
        if (summary != "")
            detail .= "`n" summary
        detail .= "`ncmd: " launch["cmd"]
        ; pass only on a clean PASS: DIALOG passes the script but exits 8, and a
        ; passing check row with a nonzero exit is a contradiction to the checker.
        backendStatus := status = "error" ? "error" : (verdict == "PASS" ? "pass" : "fail")
        checks.Push(Harness.CheckRow("backend", backendStatus, launch["exit"], launch["ms"], detail))

        if (runDir != "")
            checks.Push(Harness.CheckRow("evidence", "pass", 0, 0
                , runDir (DirExist(runDir) ? "" : " (not found on disk)")))
        else
            checks.Push(this.Skipped("evidence", "ahkh reported no run folder"))

        return this.Done(res, checks, findings, status, started
            , loadFailed ? "failed" : "not-parsed", this.Drift(data, runDir), verdict, runDir)
    }

    ; ahkh prints exactly one JSON document, but a line ahead of it (a wrapper
    ; banner, a runtime notice on stdout) should not cost the whole result, so
    ; a failed parse is retried from the first line that opens an object.
    static ParseOutput(text) {
        if (text = "")
            throw ValueError("stdout was empty")
        try {
            out := HarnessJson.Parse(text)
        } catch ValueError as err {
            start := RegExMatch(text, "m)^\{")
            if (start <= 1)
                throw err
            out := HarnessJson.Parse(SubStr(text, start))
        }
        if !(out is Map)
            throw ValueError("stdout JSON is not an object")
        return out
    }

    ; Case-sensitive on purpose: the verdicts are fixed upper-case constants
    ; (lib/evidence.mjs:7), and anything else is a backend this adapter does
    ; not understand.
    static StatusOf(verdict) {
        switch verdict, true {
            case "PASS", "DIALOG":
                return "pass"
            case "FAIL", "ERROR", "CRASH", "LEAK", "FOCUS-STOLEN":
                return "fail"
            case "TIMEOUT", "HUNG":
                return "timeout"
        }
        return "error"
    }

    ; VERDICT_EXIT from lib/evidence.mjs:8; "" for a verdict it does not list.
    static VerdictExit(verdict) {
        switch verdict, true {
            case "PASS", "SKIPPED":
                return 0
            case "FAIL":
                return 1
            case "ERROR":
                return 2
            case "TIMEOUT":
                return 3
            case "CRASH":
                return 4
            case "HUNG":
                return 5
            case "LEAK":
                return 6
            case "FOCUS-STOLEN":
                return 7
            case "DIALOG":
                return 8
        }
        return ""
    }

    static MapFinding(f, full) {
        kind := this.Text(f.Get("kind", ""))
        if (kind = "")
            kind := "unknown"
        line := f.Get("line", 0)
        line := IsInteger(line) ? Integer(line) : 0
        message := this.Text(f.Get("message", ""))
        origin := this.Text(f.Get("file", ""))
        if (origin != "" && !this.IsScript(origin, full))
            message .= " [file: " origin "]"
        shot := this.Text(f.Get("shot", ""))
        if (shot != "")
            message .= " [screenshot: " shot "]"
        return Harness.Finding(this.Severity(this.Text(f.Get("severity", "error")), kind)
            , kind, line, message, "live")
    }

    static Severity(severity, kind) {
        if (severity = "error") {
            for name in this.CriticalKinds {
                if (name = kind)
                    return "critical"
            }
            ; An answered dialog only reaches error with failOnDialog, and ahkh
            ; itself ranks that DIALOG verdict just above PASS
            ; (lib/evidence.mjs:7), so it stays medium wherever it appears.
            if (kind = "dialog")
                return "medium"
            return "high"
        }
        if (severity = "warn")
            return "medium"
        if (severity = "info")
            return "low"
        ; ahkh only writes error | warn | info (lib/evidence.mjs:52), and a
        ; finding with none defaults to error (lib/evidence.mjs:54).
        return "high"
    }

    ; What the run observed, so a live failure after a dry-run pass can be
    ; told apart from the target UI moving: the evidence folder, the windows
    ; ahkh saw appear, how many dialogs it answered, and the final control-tree
    ; snapshot it takes of a script still running at the end
    ; (lib/verbs/run.mjs:67). "unknown" only when no run happened at all.
    static Drift(data, runDir) {
        if (runDir = "")
            return "unknown"
        drift := JObj()
        drift.Set("evidence", runDir)
        seen := this.Windows(runDir)
        drift.Set("windows", seen["list"])
        drift.Set("dialogs", this.Count(data.Get("dialogs", 0)))
        trees := []
        artifacts := data.Get("artifacts", "")
        if (artifacts is Array) {
            for item in artifacts {
                if (item is Map && this.Text(item.Get("kind", "")) = "tree")
                    trees.Push(this.Text(item.Get("path", "")))
            }
        }
        drift.Set("trees", trees)
        if (seen["note"] != "")
            drift.Set("note", seen["note"])
        return drift
    }

    ; The --json result has no window list, but events.jsonl in the run folder
    ; logs every window that became visible on the hidden desktop as
    ; "kind":"host.win.new" with its class and title (native/Host.Watch.cs:178,
    ; lib/session.mjs:69-70). The file also logs every line the script printed,
    ; so the scan is bounded.
    static Windows(runDir) {
        seen := Map()
        seen["list"] := []
        seen["note"] := ""
        path := runDir "\events.jsonl"
        if !this.IsFile(path) {
            seen["note"] := "no events.jsonl in the evidence folder"
            return seen
        }
        try {
            handle := FileOpen(path, "r", "UTF-8")
        } catch Error as err {
            seen["note"] := "events.jsonl unreadable: " err.Message
            return seen
        }
        if !IsObject(handle) {
            seen["note"] := "events.jsonl unreadable"
            return seen
        }
        keys := Map(), scanned := 0, bad := 0
        try {
            while (!handle.AtEOF && scanned < 20000 && seen["list"].Length < 50) {
                line := handle.ReadLine()
                scanned++
                if !InStr(line, '"kind":"host.win.new"', true)
                    continue
                try {
                    event := HarnessJson.Parse(line)
                } catch Error as err {
                    bad++
                    continue
                }
                if !(event is Map)
                    continue
                cls := this.Text(event.Get("class", ""))
                title := this.Text(event.Get("title", ""))
                if keys.Has(cls "`n" title)
                    continue
                keys[cls "`n" title] := true
                win := JObj()
                win.Set("class", cls)
                win.Set("title", title)
                seen["list"].Push(win)
            }
            if (seen["list"].Length >= 50)
                seen["note"] := "first 50 distinct windows only"
            else if !handle.AtEOF
                seen["note"] := Format("window scan stopped after {} lines", scanned)
        } finally {
            handle.Close()
        }
        if bad
            seen["note"] := Trim(seen["note"] " " bad " malformed window event(s) skipped")
        return seen
    }

    static Done(res, checks, findings, status, started, parse, drift, verdict, evidence) {
        info := JObj()
        info.Set("name", "ahkh")
        info.Set("verdict", verdict)
        info.Set("evidence", evidence)
        info.Set("interpreter", A_AhkPath)
        extra := []
        ; This tier never parses the candidate itself: "failed" is
        ; AutoHotkey's own load failure as ahkh reported it.
        extra.Push(["parse", parse])
        extra.Push(["drift", drift])
        extra.Push(["backend", info])
        return Harness.Finish(res, checks, findings, status, started, extra)
    }

    static Skipped(name, why) {
        return Harness.CheckRow(name, "skipped", 0, 0, "skipped: " why)
    }

    ; An ahk-error finding's file is the dialog title, which AutoHotkey sets to
    ; the script's file name (lib/session.mjs:125), so the bare name counts.
    static IsScript(file, full) {
        return this.SamePath(file, full) || file = Harness.NameOf(full)
    }

    static SamePath(a, b) {
        return Harness.FullPath(a) = Harness.FullPath(b)
    }

    static IsFile(path) {
        attr := FileExist(path)
        return attr != "" && !InStr(attr, "D")
    }

    ; JSON null arrives as "", and a field of the wrong type is treated as
    ; absent rather than allowed to throw inside the mapping.
    static Text(value) {
        if (value is String)
            return value
        if (value is Number)
            return String(value)
        return ""
    }

    static Count(value) {
        return (IsInteger(value) && Integer(value) >= 0) ? Integer(value) : 0
    }
}
