#Requires AutoHotkey v2.1-alpha.30
; An unspecified #SingleInstance means Prompt, and two gate runs may replay
; results at the same moment.
#SingleInstance Off
#NoTrayIcon

#Include %A_LineFile%\..\..\HarnessCore.ahk

; fake-ahkh.ahk — a stand-in for ahkh (github.com/owhs/AHKTestHarness), so
; GateLive.ahk can be exercised without running unvetted native code that
; creates desktops, drives windows and guards the clipboard.
;
; It accepts the command line GateLive sends — `run <script> --json` plus
; ahkh's global flags (--project, --out, --quiet; lib/cli.mjs:15-29) and the
; run verb's --for, --timeout and --label (lib/verbs/run.mjs:31-47) — and
; replays a canned result picked by the script's file name: a script named
; live-pass.ahk gets fixtures\ahkh\live-pass.json. The fixtures copy what ahkh
; prints for `run --json` field for field and in its two-space layout: the verb
; result of lib/verbs/run.mjs:79 printed by lib/cli.mjs:71, whose data is the
; run record of lib/evidence.mjs:64 extended by lib/session.mjs:398. A refused
; run is the one-line {ok, error, code} of lib/cli.mjs:67. The exit code
; follows lib/cli.mjs:65-79: the result's exitCode, else 64 for a BADARG
; refusal and 70 for any other.
;
; Anything the gate should never send is refused the way ahkh would refuse it
; (an option the stub does not know is BADARG, exit 64), so a gate that drifts
; from ahkh's real command line fails here instead of passing against a stub.
;
; Like ahkh it creates the run folder under --out before anything else
; (lib/session.mjs:32) and keeps events.jsonl there, because that is where
; GateLive reads the windows a run saw. fixtures\ahkh\<name>.events.jsonl
; supplies those lines; without one the log holds only the session bookends.
; It also writes argv.txt, the exact arguments received, so a test can check
; what the gate sent.
;
; It insists on AHKH_AHK, the interpreter pin GateLive owes every backend:
; unset, naming no file, or disagreeing with the --project file's ahk.exe is
; exit 2 with the reason on stderr. A script named live-garbage.ahk gets
; ahkh's human-readable output instead of JSON — what a wrapper that dropped
; --json would hand the gate.

if !A_Args.Length {
    Print("usage: fake-ahkh.ahk run <script.ahk> --json [--for S | --timeout S] [--label L] [--out DIR] [--project FILE]")
    ExitApp(0)
}

ExitApp(FakeAhkh.Main(A_Args))

class FakeAhkh {
    static Fixtures := A_LineFile "\..\fixtures\ahkh"

    static Main(argv) {
        ahk := EnvGet("AHKH_AHK")
        if (ahk = "")
            return this.Die("AHKH_AHK is not set: the caller must pin the interpreter ahkh runs (GateLive passes its own A_AhkPath)")
        if !this.IsFile(ahk)
            return this.Die("AHKH_AHK names no file: " ahk)

        ; Globals first, wherever they sit on the line, as lib/cli.mjs:15-29
        ; strips them before the verb sees its arguments.
        wantJson := false, project := "", outDir := "", rest := []
        i := 0
        while (++i <= argv.Length) {
            arg := argv[i]
            if (arg == "--json") {
                wantJson := true
                continue
            }
            if (arg == "--quiet" || arg == "--hub")
                continue
            if (arg == "--project" || arg == "--out" || arg == "-s" || arg == "--session") {
                if (i = argv.Length)
                    return this.Die(arg " needs a value")
                value := argv[++i]
                if (arg == "--project")
                    project := value
                else if (arg == "--out")
                    outDir := value
                continue
            }
            rest.Push(arg)
        }
        if !wantJson
            return this.Die("only --json results are canned, and the caller did not ask for --json")
        if (!rest.Length || rest[1] !== "run") {
            FileAppend('unknown verb "' (rest.Length ? rest[1] : "") '". Try: ahkh help`n', "**")
            return 64
        }

        script := "", label := ""
        i := 1
        while (++i <= rest.Length) {
            arg := rest[i]
            if (SubStr(arg, 1, 2) == "--") {
                name := SubStr(arg, 3)
                if !(name == "for" || name == "timeout" || name == "label")
                    return this.Refuse("unknown option --" name ' for "run" (see: ahkh help run)', "BADARG")
                if (i = rest.Length)
                    return this.Refuse("--" name " needs a value", "BADARG")
                value := rest[++i]
                if (name == "label")
                    label := value
                else if !IsNumber(value)
                    return this.Refuse("--" name ' expects a number, got "' value '"', "BADARG")
                continue
            }
            if (script != "")
                return this.Refuse("unexpected argument: " arg, "BADARG")
            script := arg
        }
        if (script = "")
            return this.Refuse("missing required argument: script", "BADARG")
        script := Harness.ResolveArg(script)
        if !this.IsFile(script)
            return this.Refuse("script not found: " script, "NOSCRIPT")

        ; ahkh's findAhk takes the project's ahk.exe before AHKH_AHK
        ; (lib/config.mjs:63-65), so a project file that pins anything else
        ; would quietly win over the variable.
        root := A_InitialWorkingDir
        graded := ahk
        if (project != "") {
            project := Harness.ResolveArg(project)
            try {
                pinned := this.PinnedExe(project)
            } catch Error as err {
                return this.Die(err.Message)
            }
            if (Harness.FullPath(pinned) != Harness.FullPath(ahk))
                return this.Die("--project pins " pinned " but AHKH_AHK is " ahk "; ahkh would run the project's")
            graded := pinned
            SplitPath(project, , &root)
        }

        SplitPath(script, &scriptName, &scriptDir, , &stem)
        if (label = "")
            label := stem
        try {
            runDir := this.NewRunDir(this.Under(root, outDir != "" ? outDir : ".ahkh\runs"), label)
            this.WriteArgs(runDir, argv)
        } catch Error as err {
            return this.Die("cannot create the run folder: " err.Message)
        }
        SplitPath(runDir, &runName)

        values := Map()
        values["SCRIPT"] := script
        values["SCRIPT_NAME"] := scriptName
        values["SCRIPT_DIR"] := scriptDir
        values["LABEL"] := label
        values["RUN"] := runName
        values["RUNDIR"] := runDir
        values["AHK"] := graded

        if (stem = "live-garbage") {
            try {
                this.WriteEvents(runDir, stem, values, "PASS")
            } catch Error as err {
                return this.Die("cannot write events.jsonl: " err.Message)
            }
            Print("PASS  " label "  (8.02s)  0 error(s), 0 warning(s), 0 dialog(s), 0 shot(s)")
            Print("  run: " runDir)
            return 0
        }

        fixture := Harness.FullPath(this.Fixtures "\" stem ".json")
        if !this.IsFile(fixture)
            return this.Refuse("fake-ahkh has no canned result for " scriptName " (looked for " fixture ")", "NOFIXTURE")
        ; A fixture that does not survive its own fill is a broken test, so it
        ; is reported loudly rather than handed to the gate as if ahkh sent it.
        try {
            text := this.Fill(Trim(FileRead(fixture, "UTF-8"), " `t`r`n"), values)
            result := HarnessJson.Parse(text)
            verdict := (result is Map) ? result.Get("verdict", "") : ""
            this.WriteEvents(runDir, stem, values, verdict)
        } catch Error as err {
            return this.Die("fixture " fixture " is unusable: " err.Message)
        }
        Print(text)
        return this.ExitCode(result)
    }

    static PinnedExe(project) {
        if !this.IsFile(project)
            throw ValueError("--project names no file: " project)
        try {
            config := HarnessJson.Parse(FileRead(project, "UTF-8"))
        } catch Error as err {
            throw ValueError("--project file " project " is not JSON: " err.Message)
        }
        pinned := ""
        if (config is Map && config.Get("ahk", "") is Map)
            pinned := config["ahk"].Get("exe", "")
        if (pinned = "")
            throw ValueError("--project file " project " does not pin ahk.exe, so ahkh would pick its own interpreter")
        return pinned
    }

    ; lib/cli.mjs:54 hands --out to loadConfig, which resolves it against the
    ; project root (lib/config.mjs:48).
    static Under(root, path) {
        if RegExMatch(path, "^(?:[A-Za-z]:[\\/]|[\\/]{2})")
            return Harness.FullPath(path)
        return Harness.FullPath(root "\" path)
    }

    ; <stamp>-<slug(label, 40)>, made unique with -2, -3 (lib/evidence.mjs:20-22,
    ; lib/util.mjs:25-32).
    static NewRunDir(outDir, label) {
        slug := Trim(RegExReplace(label, "[^A-Za-z0-9_.-]+", "-"), "-")
        slug := SubStr(slug, 1, 40)
        if (slug = "")
            slug := "x"
        base := outDir "\" FormatTime(, "yyyyMMdd-HHmmss") "-" slug
        dir := base, n := 1
        while DirExist(dir)
            dir := base "-" (++n)
        DirCreate(dir)
        return dir
    }

    static WriteArgs(runDir, argv) {
        listing := ""
        for arg in argv
            listing .= arg "`n"
        FileAppend(listing, runDir "\argv.txt", "UTF-8-RAW")
    }

    ; The bookends lib/session.mjs:51 and lib/evidence.mjs:70 always write,
    ; around whatever window events the case supplies.
    static WriteEvents(runDir, stem, values, verdict) {
        lines := '{"t":0,"ts":"2026-10-01T21:14:03.112Z","kind":"session.open","id":"s5e2f","label":"{{LABEL}}"}' "`n"
        extra := Harness.FullPath(this.Fixtures "\" stem ".events.jsonl")
        if this.IsFile(extra)
            lines .= Trim(FileRead(extra, "UTF-8"), "`r`n") "`n"
        lines .= '{"t":8418,"ts":"2026-10-01T21:14:11.530Z","kind":"run.end","verdict":' HarnessJson.Str(verdict) ',"durationMs":8418}' "`n"
        FileAppend(this.Fill(lines, values), runDir "\events.jsonl", "UTF-8-RAW")
    }

    ; Every placeholder sits inside a JSON string, so its value goes in
    ; JSON-escaped without the surrounding quotes.
    static Fill(text, values) {
        for key, value in values
            text := StrReplace(text, "{{" key "}}", SubStr(HarnessJson.Str(value), 2, -1))
        if (spot := InStr(text, "{{"))
            throw ValueError("unfilled placeholder near: " SubStr(text, spot, 40))
        return text
    }

    static ExitCode(result) {
        if !(result is Map)
            return 0
        if (result.Get("ok", 1) = 0 && !result.Has("verdict"))
            return result.Get("code", "") == "BADARG" ? 64 : 70
        code := result.Get("exitCode", "")
        if IsInteger(code)
            return Integer(code)
        return result.Has("verdict") ? 1 : 0
    }

    ; lib/cli.mjs:67 prints a thrown verb's failure compactly on stdout.
    static Refuse(message, code) {
        Print('{"ok":false,"error":' HarnessJson.Str(message) ',"code":' HarnessJson.Str(code) '}')
        return code == "BADARG" ? 64 : 70
    }

    static Die(message) {
        FileAppend("fake-ahkh: " message "`n", "**")
        return 2
    }

    static IsFile(path) {
        attr := FileExist(path)
        return attr != "" && !InStr(attr, "D")
    }
}
