#Requires AutoHotkey v2.1-alpha.30

; Parallel agents run this same file at once. Without this the interpreter's
; default (Prompt) asks whether to replace the running copy — a dialog on the
; desktop, or a killed run — measured in the fork's CheckPriorInstance.
#SingleInstance Off

#Include %A_LineFile%\..\ShimRun.ahk

; SelfTest.ahk — proves the harness works on this machine, end to end.
;
; Every gate is run for real against canary scripts whose correct verdicts
; are known, and every verdict is checked: statuses, residency, findings,
; intent, the guard, and that the canaries' attempted side effects never
; reached the sandbox, the registry or the user's clipboard. The shim's
; coverage is checked by reading its source, so the most dangerous shadows
; (Shutdown above all) are proven present without ever being exercised.
; Python-side tools are tested when a working Python exists.
;
; A gate that silently stopped protecting the machine would still produce
; well-formed NDJSON; only checks like these tell the difference.
;
;   AutoHotkey64.exe SelfTest.ahk --run [--only static,dryrun,pure,live,reduce,python]
;                                       [--with-desktop] [--keep] [--quiet]
;
;     --run            required: without it this prints usage and exits, so a
;                      bare launch (the post-edit hook runs every saved file)
;                      does nothing
;     --only <list>    run only these sections
;     --with-desktop   also run the dialog canary, which briefly opens a real
;                      Windows dialog for the window watch to catch and close
;     --keep           keep the scratch directory
;
; Output is TAP: "ok N - ...", "not ok N - ... # detail", skips marked
; "# SKIP reason" — a skipped check is reported, never silently counted.
; Exit: number of failed checks (capped at 99), 0 when all pass; 2 on usage.

if !A_Args.Length {
    Print("usage: SelfTest.ahk --run [--only static,dryrun,pure,live,reduce,python] [--with-desktop] [--keep] [--quiet]")
    ExitApp(0)
}

SelfTest.Main(A_Args)

class SelfTest {
    static Count := 0
    static Passed := 0
    static Failed := 0
    static Skipped := 0
    static HarnessDir := Harness.FullPath(A_LineFile "\..")
    static Canaries := Harness.FullPath(A_LineFile "\..\selftest\canaries")

    static Main(args) {
        run := false, keep := false, desktop := false, only := ""
        i := 0
        while (++i <= args.Length) {
            arg := args[i]
            if (arg = "--run")
                run := true
            else if (arg = "--keep")
                keep := true
            else if (arg = "--with-desktop")
                desktop := true
            else if (arg = "--quiet")
                continue
            else if (arg = "--only" && i < args.Length)
                only := args[++i]
            else {
                Print("unknown option: " arg)
                ExitApp(2)
            }
        }
        if !run {
            Print("pass --run to execute the selftest")
            ExitApp(2)
        }

        this.Scratch := A_Temp "\ahk-harness-selftest\" A_Now "-" ProcessExist()
        this.Sandbox := this.Scratch "\sandbox"
        DirCreate(this.Sandbox)
        ; Inherited by every gate and, through them, by every canary: the
        ; canaries refuse to do anything without it.
        EnvSet("AHK_HARNESS_SELFTEST", "1")
        EnvSet("AHK_HARNESS_SELFTEST_SANDBOX", this.Sandbox)
        this.Desktop := desktop

        Print("TAP version 13")
        Print("# interpreter " A_AhkPath " (" A_AhkVersion ")")
        Print("# scratch " this.Scratch)
        sections := ["shim", "static", "dryrun", "pure", "live", "reduce", "python"]
        for section in sections {
            if (only != "" && !InStr("," only ",", "," section ","))
                continue
            Print("# " section)
            try {
                this.%section%()
            } catch Error as err {
                this.Ok(false, section " section completed", err.Message " at line " err.Line)
            }
        }
        Print("1.." this.Count)
        Print(Format("# selftest: {} passed, {} failed, {} skipped", this.Passed, this.Failed, this.Skipped))
        if !keep {
            try {
                DirDelete(this.Scratch, true)
            } catch Error as err {
                Print("# could not remove scratch: " err.Message)
            }
        }
        ExitApp(Min(this.Failed, 99))
    }

    static Ok(cond, description, detail := "") {
        this.Count += 1
        if cond {
            this.Passed += 1
            Print("ok " this.Count " - " description)
            return true
        }
        this.Failed += 1
        Print("not ok " this.Count " - " description (detail = "" ? "" : " # " StrReplace(StrReplace(detail, "`r", " "), "`n", " ")))
        return false
    }

    static Skip(description, reason) {
        this.Count += 1
        this.Skipped += 1
        Print("ok " this.Count " - " description " # SKIP " reason)
    }

    ; The shim's coverage, read from its source: a shadow that went missing
    ; would let a canary's attempt through, and some of these must never be
    ; attempted for real just to prove they are covered.
    static Shim() {
        names := ShimRun.ShadowNames()
        required := ["Shutdown", "Send", "SendInput", "SendEvent", "SendPlay", "SendText", "ControlSend"
            , "Click", "MouseMove", "MouseClick", "MouseClickDrag", "BlockInput", "KeyWait", "InputHook"
            , "WinActivate", "WinClose", "WinKill", "WinMove", "WinSetStyle", "WinMinimizeAll"
            , "ControlClick", "ControlSetText", "PostMessage", "SendMessage"
            , "Run", "RunWait", "Reload", "ProcessClose", "ProcessSetPriority"
            , "FileDelete", "FileRecycle", "FileRecycleEmpty", "FileMove", "FileCopy", "FileAppend", "FileOpen"
            , "DirCreate", "DirDelete", "DirMove", "DirCopy", "IniWrite", "IniDelete"
            , "RegWrite", "RegDelete", "RegDeleteKey", "RegCreateKey", "Download"
            , "Hotkey", "Hotstring", "Suspend", "MsgBox", "InputBox", "FileSelect", "DirSelect"
            , "Gui", "DllCall", "ComObject", "ComObjActive", "ComObjGet"
            , "SoundSetVolume", "SoundSetMute", "SoundBeep", "SoundPlay", "DriveEject"
            , "Edit", "ListVars", "ListLines", "ListHotkeys", "KeyHistory", "Sleep"]
        missing := ""
        for name in required {
            if !names.Has(name)
                missing .= " " name
        }
        this.Ok(missing = "", "the shim shadows every required built-in (" required.Length " checked)", "missing:" missing)
        text := FileRead(ShimRun.ShimPath, "UTF-8")
        for api in ["SendInput", "keybd_event", "mouse_event", "ExitWindowsEx", "InitiateSystemShutdown"
            , "ShellExecute", "CreateProcess", "DeleteFile", "RegSetValueEx", "URLDownloadToFile"
            , "SetWindowsHookEx", "MessageBox"]
            this.Ok(InStr(text, '"' api '"'), "the DllCall deny-list names " api)
        this.Ok(InStr(text, "HarnessReal_Suspend(true)"), "the shim suspends label hotkeys at boot")
        this.Ok(InStr(text, "OnError(HarnessOnError, -1)"), "the shim records errors ahead of the candidate's handlers")
    }

    static Static() {
        dir := this.Canaries "\static"
        rows := this.Gate("GateStatic.ahk"
            , this.Quote([dir "\clean.ahk", dir "\parse-error.ahk", dir "\v1-clipboard.ahk", dir "\empty-catch.ahk", dir "\missing.ahk"])
            , "static")
        if !rows
            return
        this.Expect(rows, "clean.ahk", "pass", Map("parse", "clean"))
        this.Expect(rows, "parse-error.ahk", "fail", Map("parse", "failed"), ["parse"])
        this.Expect(rows, "v1-clipboard.ahk", "pass", Map(), ["v1-clipboard"])
        this.Expect(rows, "empty-catch.ahk", "pass", Map(), ["empty-catch"])
        this.Expect(rows, "missing.ahk", "fail", Map("parse", "not-parsed"), ["missing-file"])
        ; The relative-path bug: a gate resolved relative arguments against its
        ; own folder because AutoHotkey starts scripts there.
        rel := this.Launch('"' this.HarnessDir "\GateStatic.ahk" '" static\clean.ahk --quiet --run selftest', "relative", this.Canaries)
        relRows := this.Rows(rel["stdout"])
        this.Ok(relRows.Length = 1 && relRows[1]["status"] = "pass"
            , "a relative script path resolves against the caller's directory"
            , relRows.Length ? relRows[1]["script"] : "no row")
    }

    static DryRun() {
        dir := this.Canaries "\dryrun"
        FileAppend("keep me", this.Sandbox "\sentinel.txt", "UTF-8-RAW")
        names := ["clean", "runtime-error", "hang", "idle", "hotkeys", "stdout", "clipboard", "gui"
            , "gui-geometry", "collision", "suppressed-error", "hidden-crash", "memory", "shim-bypass"
            , "import-from", "import-statement", "module", "include-import", "side-effects"]
        paths := []
        for name in names
            paths.Push(dir "\" name ".ahk")

        userClip := ClipboardAll()
        marker := "selftest-user-" A_TickCount
        A_Clipboard := marker
        try {
            rows := this.Gate("GateDryRun.ahk", this.Quote(paths) " --timeout 4 --memory 256", "dryrun")
            this.Ok(A_Clipboard == marker, "the user's clipboard survived a candidate that wrote it", "now: " SubStr(A_Clipboard, 1, 60))
        } finally {
            A_Clipboard := userClip
        }
        if !rows
            return

        this.Expect(rows, "clean.ahk", "pass", Map("residency", "exited"))
        this.Expect(rows, "runtime-error.ahk", "fail", Map("residency", "exited"), ["runtime"])
        this.Expect(rows, "hang.ahk", "timeout", Map("residency", "wedged"), ["hung"])
        this.Expect(rows, "idle.ahk", "pass", Map("residency", "idle"))
        this.Expect(rows, "hotkeys.ahk", "pass", Map("residency", "idle"))
        this.Ok(InStr(this.CheckDetail(rows, "hotkeys.ahk", "stdout"), "suspended=1")
            , "label hotkeys are suspended before the candidate runs")
        this.Expect(rows, "stdout.ahk", "pass", Map("residency", "exited"))
        out := this.CheckDetail(rows, "stdout.ahk", "stdout")
        this.Ok(InStr(out, "canary-print") && InStr(out, "canary-append")
            , "Print and FileAppend(*) reach the stdout row, not the NDJSON stream", out)
        this.Expect(rows, "clipboard.ahk", "pass", Map(), , Map("clipboard", 1))
        this.Ok(this.Guard(rows, "clipboard.ahk", "clipboard") = "restored", "the guard restored the clipboard after the candidate wrote it")
        this.Ok(InStr(this.CheckDetail(rows, "clipboard.ahk", "stdout"), "read back: canary-clipboard")
            , "the candidate read back its own clipboard write")
        this.Expect(rows, "gui.ahk", "pass", Map("residency", "exited"), , Map("gui", 3))
        this.Expect(rows, "gui-geometry.ahk", "pass", Map("residency", "exited"), , Map("gui", 4))
        geometry := this.CheckDetail(rows, "gui-geometry.ahk", "stdout")
        this.Ok(InStr(geometry, "window 640x480 client 640x480 button 80x24 moved 120x30 margin 550")
            , "the Gui stand-in answers GetPos and GetClientPos through their ByRef parameters", geometry)
        this.Expect(rows, "collision.ahk", "pass")
        this.Ok(InStr(this.CheckDetail(rows, "collision.ahk", "shim"), "MsgBox")
            && InStr(this.CheckDetail(rows, "collision.ahk", "stdout"), "own msgbox")
            , "a candidate's own MsgBox replaces the shadow instead of failing the load")
        this.Expect(rows, "suppressed-error.ahk", "pass", Map("residency", "idle"), ["error-suppressed"])
        this.Expect(rows, "hidden-crash.ahk", "fail", Map(), ["runtime"])
        this.Expect(rows, "memory.ahk", "fail", Map(), ["runtime"])
        this.Expect(rows, "shim-bypass.ahk", "error", Map("residency", "unknown"), ["shim-bypass"])
        ; Every other way past the shim is refused the same way: the names-first
        ; and statement spellings of an import from AHK, code in a module of
        ; its own, and an import one #Include away.
        for bypass in ["import-from", "import-statement", "module", "include-import"]
            this.Expect(rows, bypass ".ahk", "error", Map("residency", "unknown"), ["shim-bypass"])
        this.Expect(rows, "side-effects.ahk", "pass", Map("residency", "exited")
            , , Map("fs", 3, "registry", 1, "process", 1, "dll", 1, "com", 1))
        this.Ok(FileExist(this.Sandbox "\sentinel.txt"), "FileDelete never reached the sandbox")
        this.Ok(!FileExist(this.Sandbox "\created.txt"), "FileOpen for writing was redirected to the sink")
        this.Ok(!FileExist(this.Sandbox "\settings.ini"), "IniWrite never reached the sandbox")
        regLeak := true
        try {
            RegRead("HKCU\Software\AhkHarnessSelftest", "value")
        } catch OSError as err {
            regLeak := false
        }
        this.Ok(!regLeak, "RegWrite never reached the registry")
        if regLeak {
            try {
                RegDeleteKey("HKCU\Software\AhkHarnessSelftest")
            } catch OSError as err {
                Print("# could not remove the leaked key: " err.Message)
            }
        }

        if !this.Desktop {
            this.Skip("the window watch catches and closes a dialog that got past the shim", "needs --with-desktop")
            return
        }
        drows := this.Gate("GateDryRun.ahk", this.Quote([dir "\dialog.ahk"]) " --timeout 8", "dialog")
        if drows {
            this.Expect(drows, "dialog.ahk", "pass", Map("residency", "exited"), ["dialog"])
            this.Ok(this.Guard(drows, "dialog.ahk", "dialogs") = 1, "the window watch counted the dialog")
        }
    }

    static Pure() {
        if !FileExist(this.HarnessDir "\GatePure.ahk") {
            this.Skip("tier 2 (GatePure.ahk)", "not installed")
            return
        }
        dir := this.Canaries "\pure"
        rows := this.Gate("GatePure.ahk", this.Quote([dir "\calc.ahk", dir "\brokencalc.ahk", dir "\nocoverage.ahk"]), "pure")
        if !rows
            return
        this.Expect(rows, "calc.ahk", "pass")
        calc := this.Row(rows, "calc.ahk")
        if calc
            this.Ok(calc["tests"] >= 1 && calc["assertions"]["failed"] = 0 && calc["assertions"]["passed"] > 0
                , "calc.ahk ran its tests and every assertion passed")
        this.Expect(rows, "brokencalc.ahk", "fail", , ["assert"])
        broken := this.Row(rows, "brokencalc.ahk")
        if broken {
            line := 0
            for f in broken["findings"] {
                if (f["rule"] = "assert")
                    line := f["line"]
            }
            this.Ok(broken["assertions"]["failed"] = 1 && line > 0
                , "the failing assertion is counted once and carries its line", "line " line)
        }
        this.Expect(rows, "nocoverage.ahk", "pass")
        none := this.Row(rows, "nocoverage.ahk")
        if none
            this.Ok(none["tests"] = 0, "a script with no tests reports tests: 0 instead of a silent pass")
    }

    static Live() {
        if !FileExist(this.HarnessDir "\GateLive.ahk") || !FileExist(this.HarnessDir "\selftest\fake-ahkh.ahk") {
            this.Skip("tier 4 (GateLive.ahk with the ahkh stub)", "not installed")
            return
        }
        dir := this.Scratch "\live"
        DirCreate(dir)
        cases := Map("live-pass", "pass", "live-error", "fail", "live-dialog", "pass"
            , "live-hung", "timeout", "live-focus", "fail", "live-garbage", "error")
        paths := []
        for name in cases {
            FileAppend("#Requires AutoHotkey v2.1-alpha.30`n", dir "\" name ".ahk", "UTF-8-RAW")
            paths.Push(dir "\" name ".ahk")
        }
        stub := '"' A_AhkPath '" "' this.HarnessDir "\selftest\fake-ahkh.ahk" '"'
        rows := this.Gate("GateLive.ahk", this.Quote(paths) ' --ahkh-cmd ' this.ArgQuote(stub), "live")
        if !rows
            return
        for name, status in cases {
            row := this.Row(rows, name ".ahk")
            this.Ok(row && row["status"] = status, name " maps to status " status, row ? "got " row["status"] : "no row")
            if (row && row["status"] != "error")
                this.Ok(row.Has("drift") && row.Has("backend") && row["backend"]["name"] = "ahkh"
                    , name " carries drift and backend")
        }
        focus := this.Row(rows, "live-focus.ahk")
        if focus
            this.Ok(this.HasRule(focus, "focus-stolen"), "a focus-stealing live run is a critical finding")

        missing := this.Launch('"' this.HarnessDir "\GateLive.ahk" '" ' this.Quote([paths[1]]) ' --ahkh "' this.Scratch '\no-such-ahkh" --quiet', "live-missing")
        mrows := this.Rows(missing["stdout"])
        this.Ok(mrows.Length = 1 && mrows[1]["status"] = "error", "a missing ahkh backend is a tool error, never a pass"
            , mrows.Length ? mrows[1]["status"] : "no row")
    }

    static Reduce() {
        if !FileExist(this.HarnessDir "\Reduce.ahk") {
            this.Skip("Reduce.ahk", "not installed")
            return
        }
        target := this.Canaries "\reduce-target.ahk"
        before := this.DirListing(this.Canaries)
        result := this.Launch('"' this.HarnessDir "\Reduce.ahk" '" "' target '" --isolated --budget 60 --quiet --out "' this.Scratch '\reduced.ahk"', "reduce")
        summary := ""
        for line in StrSplit(result["stdout"], "`n", "`r") {
            if (SubStr(line, 1, 1) = "{")
                summary := line
        }
        if !this.Ok(summary != "", "Reduce.ahk prints a JSON summary", Harness.Clip(result["stdout"], 200))
            return
        info := HarnessJson.Parse(summary)
        this.Ok(info["reduced_lines"] < info["original_lines"], "the failing script was reduced"
            , info["original_lines"] " -> " info["reduced_lines"] " lines")
        check := Harness.RunTool('check "' this.Scratch '\reduced.ahk"', this.Scratch "\reduced.check.txt", 20000)
        this.Ok(check["exit"] != 0, "the reduced script still fails the same parse check", "check exit " check["exit"])
        this.Ok(this.DirListing(this.Canaries) = before, "no trial files were left next to the original")

        runtime := this.Canaries "\reduce-runtime.ahk"
        if !FileExist(runtime) {
            this.Skip("Reduce.ahk --tier dryrun", "reduce-runtime.ahk canary not installed")
            return
        }
        result := this.Launch('"' this.HarnessDir "\Reduce.ahk" '" "' runtime '" --tier dryrun --isolated --budget 120 --quiet --out "' this.Scratch '\reduced-runtime.ahk"', "reduce-dryrun")
        summary := ""
        for line in StrSplit(result["stdout"], "`n", "`r") {
            if (SubStr(line, 1, 1) = "{")
                summary := line
        }
        if !this.Ok(summary != "", "Reduce.ahk --tier dryrun prints a JSON summary", Harness.Clip(result["stdout"] " " result["stderr"], 200))
            return
        info := HarnessJson.Parse(summary)
        this.Ok(info["reduced_lines"] < info["original_lines"] && info["tier"] = "dryrun"
            , "a runtime failure was reduced under the shim", info["original_lines"] " -> " info["reduced_lines"] " lines")
        this.Ok(this.DirListing(this.Canaries) = before, "the dry-run reduction left no trial files either")
    }

    static Python() {
        python := this.Python3()
        if (python = "") {
            this.Skip("CheckResults.py / Report.py / Python tests", "no working Python interpreter")
            return
        }
        Print("# python: " python)
        tests := this.HarnessDir "\selftest\test_tools.py"
        if FileExist(tests) {
            res := this.Launch(python ' "' tests '"', "python-tests", , false)
            this.Ok(res["exit"] = 0, "selftest/test_tools.py passes", Harness.Clip(res["stderr"], 300))
        } else {
            this.Skip("selftest/test_tools.py", "not installed")
        }
        ndjson := []
        loop files this.Scratch "\*.ndjson"
            ndjson.Push(A_LoopFileFullPath)
        if !ndjson.Length {
            this.Skip("CheckResults.py over this run's results", "no NDJSON from earlier sections")
            return
        }
        res := this.Launch(python ' "' this.HarnessDir '\CheckResults.py" ' this.Quote(ndjson) ' --json --out "' this.Scratch '\clean.ndjson.txt"', "checker", , false)
        this.Ok(res["exit"] = 0 || res["exit"] = 1, "CheckResults.py reads every result this run produced", "exit " res["exit"] " " Harness.Clip(res["stderr"], 300))
        ; Some canaries end in a timeout (hang) or a tool error (a refused
        ; bypass, a missing backend) on purpose, and the checker withholds
        ; exactly those by design. Anything else it flags means a gate wrote a
        ; malformed or self-contradictory row.
        try {
            report := HarnessJson.Parse(res["stdout"])
            unexpected := "", timeouts := 0
            for item in report["flagged"] {
                for reason in item["reasons"] {
                    if InStr(reason, "timed out") = 1
                        timeouts += 1
                    else if (InStr(reason, "tool error in:") != 1)
                        unexpected .= (unexpected = "" ? "" : "; ") Harness.NameOf(item["script"]) ": " reason
                }
            }
            this.Ok(unexpected = "", "the checker found no malformed or contradictory row", unexpected)
            this.Ok(timeouts >= 1, "the checker withholds timed-out results instead of counting them clean"
                , timeouts " timeout flag(s)")
        } catch Error as err {
            this.Ok(false, "CheckResults.py --json output parses", err.Message)
        }
        if !FileExist(this.HarnessDir "\Report.py") {
            this.Skip("Report.py", "not installed")
            return
        }
        sarif := this.Launch(python ' "' this.HarnessDir '\Report.py" "' this.Scratch '\clean.ndjson.txt" --format sarif --fail-on none --out "' this.Scratch '\results.sarif"', "sarif", , false)
        ok := sarif["exit"] = 0 && FileExist(this.Scratch "\results.sarif")
        if ok {
            try {
                doc := HarnessJson.Parse(FileRead(this.Scratch "\results.sarif", "UTF-8"))
                ok := doc["version"] = "2.1.0" && doc["runs"].Length = 1
            } catch Error as err {
                ok := false
            }
        }
        this.Ok(ok, "Report.py writes SARIF 2.1.0", "exit " sarif["exit"] " " Harness.Clip(sarif["stderr"], 200))
        junit := this.Launch(python ' "' this.HarnessDir '\Report.py" "' this.Scratch '\clean.ndjson.txt" --format junit --fail-on none --out "' this.Scratch '\results.xml"', "junit", , false)
        this.Ok(junit["exit"] = 0 && InStr(FileRead(this.Scratch "\results.xml", "UTF-8"), "<testsuites")
            , "Report.py writes JUnit XML")
    }

    ; The first interpreter that actually runs. python3 on a stock Windows
    ; PATH is often the Microsoft Store stub, which exits 9009 having done
    ; nothing — so each candidate is executed, not just located.
    static Python3() {
        for candidate in ["python", "py -3", "python3"] {
            res := this.Launch(candidate ' -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)"', "python-probe", , false)
            if (res["exit"] = 0 && !res.Has("note"))
                return candidate
        }
        return ""
    }

    static Gate(gate, args, label) {
        ; One run id per section: the sections are independent experiments on
        ; different canaries, and under one id the checker would rightly ask
        ; why the dry-run canaries have no static rows.
        res := this.Launch('"' this.HarnessDir "\" gate '" ' args ' --run selftest-' label ' --label ' label ' --out "' this.Scratch "\" label '" --quiet', label)
        if res.Has("note") {
            this.Ok(false, gate " launched", res["note"])
            return ""
        }
        rows := this.Rows(res["stdout"])
        FileAppend(res["stdout"] "`n", this.Scratch "\" label ".ndjson", "UTF-8-RAW")
        allParse := true
        for line in StrSplit(Trim(res["stdout"], "`r`n"), "`n", "`r") {
            if (line = "")
                continue
            try {
                HarnessJson.Parse(line)
            } catch Error as err {
                allParse := false
            }
        }
        this.Ok(allParse && rows.Length, gate " emitted well-formed NDJSON (" rows.Length " rows)", Harness.Clip(res["stderr"], 300))
        return rows.Length ? rows : ""
    }

    static Launch(cmd, label, cwd := "", ahk := true) {
        opts := Map()
        opts["stdout"] := this.Scratch "\" label ".out"
        opts["stderr"] := this.Scratch "\" label ".err"
        opts["timeoutMs"] := 600000
        opts["probe"] := false
        if (cwd != "")
            opts["cwd"] := cwd
        res := Harness.Launch(ahk ? '"' A_AhkPath '" /ErrorStdOut ' cmd : cmd, opts)
        res["stdout"] := Harness.ReadOutput(opts["stdout"])
        res["stderr"] := Harness.ReadOutput(opts["stderr"])
        return res
    }

    static Rows(text) {
        rows := []
        for line in StrSplit(text, "`n", "`r") {
            if (SubStr(line, 1, 1) != "{")
                continue
            try {
                rows.Push(HarnessJson.Parse(line))
            } catch Error as err {
                OutputDebug("selftest: unparseable row: " err.Message)
            }
        }
        return rows
    }

    static Row(rows, name) {
        for row in rows {
            if (row["name"] = name)
                return row
        }
        return ""
    }

    static HasRule(row, rule) {
        for f in row["findings"] {
            if (f["rule"] = rule)
                return true
        }
        return false
    }

    static CheckDetail(rows, name, check) {
        row := this.Row(rows, name)
        if !row
            return ""
        for c in row["checks"] {
            if (c["name"] = check)
                return c["detail"]
        }
        return ""
    }

    static Guard(rows, name, key) {
        row := this.Row(rows, name)
        return (row && row.Has("guard")) ? row["guard"][key] : ""
    }

    ; One check per expectation, so a failure names exactly what was wrong.
    static Expect(rows, name, status, fields := "", rules := "", intent := "") {
        row := this.Row(rows, name)
        if !this.Ok(row != "", name " has a result row")
            return
        this.Ok(row["status"] = status, name " status is " status, "got " row["status"] " — " this.Summary(row))
        if (fields is Map) {
            for key, want in fields
                this.Ok(row.Has(key) && row[key] = want, name " " key " is " want, "got " (row.Has(key) ? row[key] : "<absent>"))
        }
        if (rules is Array) {
            for rule in rules
                this.Ok(this.HasRule(row, rule), name " reports " rule, this.Summary(row))
        }
        if (intent is Map) {
            for kind, least in intent {
                got := row["intent"].Has(kind) ? row["intent"][kind] : 0
                this.Ok(got >= least, name " recorded at least " least " " kind " intent", "got " got)
            }
        }
    }

    static Summary(row) {
        out := ""
        for f in row["findings"]
            out .= (A_Index = 1 ? "" : "; ") f["severity"] "/" f["rule"] "@" f["line"] " " SubStr(f["message"], 1, 80)
        return out
    }

    static Quote(paths) {
        out := ""
        for path in paths
            out .= (A_Index = 1 ? "" : " ") '"' path '"'
        return out
    }

    ; One argument holding quotes of its own, escaped the way the C runtime's
    ; argument splitter (which fills A_Args) expects.
    static ArgQuote(text) {
        return '"' StrReplace(text, '"', '\"') '"'
    }

    static DirListing(dir) {
        names := ""
        loop files dir "\*", "FD"
            names .= A_LoopFileName "|"
        return names
    }
}
