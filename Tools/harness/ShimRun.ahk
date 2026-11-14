#Requires AutoHotkey v2.1-alpha.30

#Include %A_LineFile%\..\HarnessCore.ahk

; ShimRun.ahk — one supervised run of a script under DryRunShim.ahk.
;
; Shared by the dry-run gate, the unit-test gate and the reducer, so every
; tier that executes candidate code contains it the same way:
;
;   - the candidate runs in place (/include shim, /force), so A_ScriptDir,
;     relative includes and error line numbers are its own and nothing is
;     written next to it;
;   - Harness.Launch holds it in a kill-on-close job with a memory cap and
;     the UI limits, stdout and stderr captured to files;
;   - between wait slices a window watch catches dialogs that got past the
;     shim, and a clipboard guard protects the user's clipboard;
;   - a candidate that imports from the AHK module reaches the original
;     built-ins and walks past every shadow, and code in a module of its own
;     never sees the shadows in the first place, so a candidate that uses
;     the module system at all is refused, not run.
;
; A candidate may define one of the shadowed names itself (its own MsgBox
; wrapper, say). Two definitions of one name will not load, and the
; interpreter says exactly which name collided — so the collision is taken
; from its verdict rather than guessed from the source: the shadow is cut
; from a per-run copy of the shim and the load retried. The candidate's own
; definition already hides the built-in, so dropping the shadow loses
; nothing. A text scan would have to tell a top-level function from a
; method of the same name, and getting that wrong would silently disable a
; shadow; the interpreter cannot get it wrong.
;
; ShimRun.Run returns a Map; the caller decides what it means.

class ShimRun {
    static ShimPath := Harness.FullPath(A_LineFile "\..\DryRunShim.ahk")

    ; opts: stem (file prefix for this run's scratch files, required),
    ;       timeoutMs, maxSleep, memoryMB, args (appended to the command
    ;       line), env (Map of extra variables), noShim (run unshimmed —
    ;       still jobbed and watched)
    static Run(scriptPath, opts) {
        stem := opts["stem"]
        run := Map()
        run["stdoutFile"] := stem ".stdout.txt"
        run["stderrFile"] := stem ".stderr.txt"
        run["logFile"] := stem ".intent.tsv"
        run["sinkDir"] := stem ".sink"
        run["actions"] := []
        run["errors"] := []
        run["events"] := []
        run["dropped"] := []
        run["refused"] := ""
        run["shim"] := ""
        for stale in [run["stdoutFile"], run["stderrFile"], run["logFile"], stem ".shim.ahk"] {
            if FileExist(stale) {
                try {
                    FileDelete(stale)
                } catch Error as err {
                    OutputDebug("ShimRun: cannot clear " stale ": " err.Message)
                }
            }
        }

        scan := Harness.ScanSource(scriptPath)
        run["scan"] := scan
        noShim := opts.Get("noShim", false)
        if (scan["importsAhk"] && !noShim) {
            run["refused"] := "the candidate imports from the AHK module, which reaches the original "
                . "built-ins and bypasses every shadow — it cannot be dry-run safely"
            return run
        }
        if (scan["modules"] && !noShim) {
            run["refused"] := "the candidate uses modules (#Module or Import). The shim's shadows live in "
                . "the main module, so code in any other module calls the real built-ins — it cannot "
                . "be dry-run safely"
            return run
        }
        if !noShim {
            try {
                DirCreate(run["sinkDir"])
            } catch Error as err {
                run["note"] := "cannot create the sink directory: " err.Message
                return run
            }
        }

        SplitPath(scriptPath, &scriptName, &scriptDir)
        timeoutMs := opts.Get("timeoutMs", 20000)
        guard := HarnessClipGuard(scan["clipboard"], timeoutMs + 60000)
        watch := HarnessWindowWatch(scriptName)
        tick(state) {
            guard.Tick(state["pids"])
            watch.Tick(state["pids"], state)
        }

        env := Map()
        env["AHK_HARNESS_LOG"] := run["logFile"]
        env["AHK_HARNESS_MAXSLEEP"] := opts.Get("maxSleep", 50)
        env["AHK_HARNESS_SINK"] := run["sinkDir"]
        if opts.Has("env") {
            for name, value in opts["env"]
                env[name] := value
        }

        launchOpts := Map()
        launchOpts["cwd"] := scriptDir
        launchOpts["stdout"] := run["stdoutFile"]
        launchOpts["stderr"] := run["stderrFile"]
        launchOpts["timeoutMs"] := timeoutMs
        launchOpts["memoryMB"] := opts.Get("memoryMB", 1024)
        launchOpts["uiLimits"] := true
        launchOpts["env"] := env
        launchOpts["onTick"] := tick

        dropped := []
        loop {
            shim := ""
            if !noShim {
                try {
                    shim := this.PrepareShim(dropped, stem)
                } catch Error as err {
                    run["note"] := "cannot prepare the shim: " err.Message
                    guard.Finish([])
                    return run
                }
            }
            cmd := '"' A_AhkPath '" /ErrorStdOut=UTF-8 /force'
            if (shim != "")
                cmd .= ' /include "' shim '"'
            cmd .= ' "' scriptPath '"'
            if (opts.Get("args", "") != "")
                cmd .= " " opts["args"]
            launch := Harness.Launch(cmd, launchOpts)
            if (noShim || launch.Has("note") || launch["exit"] != 12 || dropped.Length >= 16)
                break
            name := this.ConflictName(Harness.ReadOutput(run["stderrFile"]))
            if (name = "")
                break
            for already in dropped {
                if (already = name)
                    name := ""
            }
            if (name = "")
                break
            dropped.Push(name)
        }

        try {
            guard.Finish([launch["pid"]])
        } catch Error as err {
            guard.State := "restore-failed"
            guard.Note := err.Message
        }

        for key, value in launch
            run[key] := value
        run["dropped"] := dropped
        run["shim"] := shim
        run["stdout"] := Harness.ReadOutput(run["stdoutFile"])
        run["stderr"] := Harness.ReadOutput(run["stderrFile"])
        run["guard"] := guard
        run["watch"] := watch
        run["events"] := watch.Events
        this.ReadLog(run)
        return run
    }

    ; "This function declaration conflicts with an existing Func." followed by
    ; "Specifically: <Name>" — the shape alpha.30 and alpha.31 both print.
    ; Only a shadowed name counts; a candidate that defines one of its own
    ; functions twice has a real load error, and keeps it. (\s* alone spans
    ; the line break: the engine will not backtrack \s* into a following \R,
    ; measured — "\s*\R" never matched this text.)
    static ConflictName(stderr) {
        if !RegExMatch(stderr, "i)declaration conflicts with an existing \w+\.?\s*Specifically:\s*(\w+)", &m)
            return ""
        return this.ShadowNames().Has(m[1]) ? m[1] : ""
    }

    ; The intent log: one tab-separated record per intercepted call, plus the
    ; shim's own meta records and the structured error records its OnError
    ; handler writes (fields split by the unit separator).
    static ReadLog(run) {
        text := Harness.ReadOutput(run["logFile"])
        if (text = "")
            return
        for line in StrSplit(text, "`n", "`r") {
            parts := StrSplit(line, "`t", , 4)
            if (parts.Length < 3)
                continue
            kind := parts[2]
            if (kind = "meta")
                continue
            detail := parts.Length >= 4 ? parts[4] : ""
            if (kind = "error") {
                fields := StrSplit(detail, Chr(31))
                while (fields.Length < 6)
                    fields.Push("")
                err := Map()
                err["type"] := parts[3]
                err["line"] := IsInteger(fields[1]) ? Integer(fields[1]) : 0
                err["file"] := fields[2]
                err["what"] := fields[3]
                err["message"] := fields[4]
                err["extra"] := fields[5]
                err["mode"] := fields[6]
                run["errors"].Push(err)
                continue
            }
            action := Map()
            action["kind"] := kind
            action["name"] := parts[3]
            action["detail"] := detail
            run["actions"].Push(action)
        }
    }

    ; Every name the shim defines at column 0 — the layout rule documented in
    ; the shim's header — read from the shim itself, so a new shadow needs no
    ; second list kept in step here.
    static ShadowNames() {
        static names := ""
        if (names is Map)
            return names
        names := Map()
        names.CaseSense := "Off"
        for line in StrSplit(FileRead(this.ShimPath, "UTF-8"), "`n", "`r") {
            if RegExMatch(line, "^class\s+(\w+)", &m)
                names[m[1]] := "class"
            else if RegExMatch(line, "^(\w+)\((.*)\)\s*(\{|=>)", &m)
                names[m[1]] := "function"
        }
        return names
    }

    ; The shim as it ships when nothing collides and its path is safe to hand
    ; to /include; otherwise a per-run copy with the colliding spans cut out.
    ; /include reads a paired %...% as a variable reference, so a path holding
    ; a literal % has to be copied somewhere that does not.
    static PrepareShim(dropped, stem) {
        if (!dropped.Length && !InStr(this.ShimPath, "%"))
            return this.ShimPath
        drop := Map()
        drop.CaseSense := "Off"
        for name in dropped
            drop[name] := true
        out := ""
        skipping := false
        for line in StrSplit(FileRead(this.ShimPath, "UTF-8"), "`n", "`r") {
            if skipping {
                if (line = "}")
                    skipping := false
                continue
            }
            name := "", isClass := false
            if RegExMatch(line, "^class\s+(\w+)", &m) {
                name := m[1]
                isClass := true
            } else if RegExMatch(line, "^(\w+)\((.*)\)\s*(\{|=>)", &m) {
                name := m[1]
            }
            if (name != "" && drop.Has(name)) {
                oneLine := !isClass && InStr(line, "=>")
                if !oneLine
                    skipping := true
                out .= "; dropped " name ": the candidate defines it`n"
                continue
            }
            out .= line "`n"
        }
        copy := stem ".shim.ahk"
        if InStr(copy, "%")
            copy := A_Temp "\ahk-harness-shim-" ProcessExist() "-" A_TickCount ".ahk"
        file := FileOpen(copy, "w", "UTF-8")
        if !IsObject(file)
            throw OSError("cannot write " copy)
        try {
            file.Write(out)
        } finally {
            file.Close()
        }
        return copy
    }
}
