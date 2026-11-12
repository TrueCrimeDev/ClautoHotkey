#Requires AutoHotkey v2.1-alpha.30

; DryRunShim.ahk — makes a script runnable without giving it the desktop.
;
; The dry-run gate starts the candidate in place with this file injected
; ahead of it:
;   AutoHotkey64.exe /ErrorStdOut=UTF-8 /force /include DryRunShim.ahk candidate.ahk
; A user-defined function shadows the built-in of the same name across the
; whole script, so the candidate's Send, Click, WinActivate, FileDelete and
; friends record what they were asked to do instead of doing it. The
; candidate runs from its real path — A_ScriptDir, relative includes and
; error line numbers are its own — and nothing is written next to it. /force
; keeps a candidate's #SingleInstance Force from replacing a copy of the same
; script the user already has running (measured: without it, it did).
;
; The originals stay reachable through the built-in AHK module, which is what
; lets the shim intercept selectively instead of wholesale: FileOpen passes
; reads through and redirects writes into a sink, DllCall forwards everything
; except a deny-list of input, window, process, file, registry, sound and
; shutdown APIs, ComObject forwards everything except automation objects
; with effects (shell, Office, HTTP, speech), and FileAppend still reaches
; stdout and stderr.
;
; What is intercepted: synthetic input and input capture (KeyWait,
; InputHook), window and control manipulation, window messages, Gui
; construction (a record-only stub class, so no candidate window ever
; exists), Menu.Show, dialogs and the Edit/List*/KeyHistory windows,
; Run/RunWait/Reload, process close/priority/waits, Shutdown, sound and
; volume, drive control, Hotkey()/Hotstring() registration, and the write
; half of file, directory, ini, registry and download I/O. Hotkeys and
; hotstrings written with label syntax (F1::, ::btw::) are suspended before
; the candidate's auto-execute section starts, and Suspend() is shadowed so
; they stay suspended — a dry run never owns the keyboard.
;
; Read-only queries (FileRead, IniRead, RegRead, FileExist, ProcessExist,
; WinExist, WinGetTitle, MouseGetPos) are deliberately NOT shadowed. Faking
; them invents a desktop the script then reasons about, and the invented
; answers are wrong in ways that look like script bugs. Observing the real
; desktop changes nothing about it.
;
; Residual gaps — a candidate can still reach the world through:
;   A_Clipboard   a built-in variable; no declaration can shadow it. The gate
;                 detects writes, serialises clipboard users and restores it
;   modules       an import from the AHK module reaches the originals
;                 directly, and code under #Module or in an imported module
;                 file never sees these shadows (they are declarations in the
;                 main module). The gate refuses to run a candidate that uses
;                 #Import, #Module or an Import statement
;   DllCall       APIs outside the deny-list (CreateFile for writing, raw COM
;                 vtables, anything exotic)
;   ComObject     objects outside the deny-list keep their full surface
; A dry-run pass therefore means "no intercepted effect fired", not "proven
; side-effect free". Underneath, the gate runs every candidate in a job
; object: kill-on-close, a memory cap, and no system-parameter, display,
; desktop or log-off changes.
;
; Layout rule the gate depends on: every shadow starts at column 0, a
; one-line shadow uses =>, and a multi-line function or class ends with a
; closing brace alone at column 0. Two definitions of one name will not load,
; so when a candidate defines one of these names itself the gate cuts exactly
; that span out of a per-run copy — the candidate's own definition already
; hides the built-in, so nothing is lost.
;
; Configured by environment, set by the gate:
;   AHK_HARNESS_LOG        file to append intent records to
;   AHK_HARNESS_MAXSLEEP   longest honoured Sleep in ms (default 50; an
;                          explicit 0 means skip sleeping entirely)
;   AHK_HARNESS_SINK       directory that receives redirected FileOpen writes

#Import AHK {FileOpen as HarnessReal_FileOpen, FileAppend as HarnessReal_FileAppend}
#Import AHK {FileCopy as HarnessReal_FileCopy, DllCall as HarnessReal_DllCall}
#Import AHK {ComObject as HarnessReal_ComObject, ComObjGet as HarnessReal_ComObjGet}
#Import AHK {SendMessage as HarnessReal_SendMessage, Suspend as HarnessReal_Suspend}
#Import AHK {ListLines as HarnessReal_ListLines, KeyHistory as HarnessReal_KeyHistory}

global HARNESS_LOG := EnvGet("AHK_HARNESS_LOG")
global HARNESS_SINK := EnvGet("AHK_HARNESS_SINK")
; Not `|| 50`: that would eat an explicit 0, and 0 is meaningful — skip all
; sleeping. Only an absent or empty variable falls back to the default.
global HARNESS_ENVCAP := EnvGet("AHK_HARNESS_MAXSLEEP")
global HARNESS_MAXSLEEP := (HARNESS_ENVCAP = "") ? 50 : Integer(HARNESS_ENVCAP)
global HARNESS_COUNT := 0
global HARNESS_SINKSEQ := 0
global HARNESS_STARTED := A_TickCount

if (HARNESS_LOG = "")
    HARNESS_LOG := A_Temp "\ahk-harness-dryrun.log"
if (HARNESS_SINK = "")
    HARNESS_SINK := A_Temp

HarnessBoot()

; Runs ahead of the candidate's auto-execute section. The deadline is
; deliberately not a SetTimer: a pending timer is itself a reason for AHK to
; stay alive, which would make a script that finished cleanly look like a
; persistent one. The gate enforces the deadline from outside and probes the
; message loop before killing, which tells those two apart.
HarnessBoot() {
    HarnessReal_Suspend(true)
    ; -1 puts this ahead of any handler the candidate registers, so every
    ; error is recorded with its real line before anything can swallow it.
    OnError(HarnessOnError, -1)
    OnExit(HarnessOnExit)
    try {
        Menu.Prototype.DefineProp("Show", {Call: HarnessMenuShow})
    } catch Error as err {
        HarnessRecord("meta", "menu wrap failed", err.Message)
    }
    HarnessRecord("meta", "dry-run start", A_ScriptFullPath)
}

HarnessOnExit(reason, code) {
    HarnessRecord("meta", "dry-run end", reason " code=" code
        . " actions=" HARNESS_COUNT " ms=" (A_TickCount - HARNESS_STARTED))
    return 0
}

; A structured copy of every error the candidate raises: line, file, what,
; message, extra and mode, separated by the unit separator so the gate can
; split them without a JSON parser. Returning 0 leaves normal handling
; alone — /ErrorStdOut still prints the error and the thread still ends — so
; the gate can tell an error the candidate let through from one its own
; handler suppressed.
HarnessOnError(thrown, mode) {
    sep := Chr(31)
    try {
        if (thrown is Error)
            detail := HarnessFlat(thrown.Line) sep HarnessFlat(thrown.File) sep HarnessFlat(thrown.What)
                . sep HarnessFlat(thrown.Message) sep HarnessFlat(thrown.Extra) sep mode
        else
            detail := "0" sep sep sep HarnessFlat(thrown) sep sep mode
        HarnessRecord("error", Type(thrown), detail)
    } catch Error as err {
        OutputDebug("harness: cannot record an error: " err.Message)
    }
    return 0
}

; One tab-separated record per intercepted call. Appended as it happens, so a
; script that hangs still leaves a usable trail behind it. Written through the
; original FileOpen, since the one this script sees is a shadow.
HarnessRecord(kind, name, detail := "") {
    global HARNESS_COUNT
    if (kind != "meta" && kind != "error")
        HARNESS_COUNT += 1
    try {
        line := A_TickCount - HARNESS_STARTED "`t" kind "`t" HarnessFlat(name) "`t" HarnessFlat(detail) "`n"
        logHandle := HarnessReal_FileOpen(HARNESS_LOG, "a", "UTF-8")
        logHandle.Write(line)
        logHandle.Close()
    } catch Error as err {
        OutputDebug("harness: cannot write the intent log: " err.Message)
    }
    ; Every one-line shadow returns this. On alpha.30 a function that returns
    ; nothing throws "No value was returned" the moment a caller uses the
    ; result — `tt := ToolTip("x")` would die on the shadow, not the script.
    return ""
}

HarnessFlat(value) {
    try {
        text := IsObject(value) ? "<" Type(value) ">" : String(value)
    } catch Error as err {
        text := "<unprintable " Type(value) ">"
    }
    return StrReplace(StrReplace(StrReplace(text, "`t", " "), "`r", " "), "`n", " ")
}

HarnessJoin(params) {
    out := ""
    for value in params {
        if !IsSet(value)
            repr := "<unset>"
        else
            repr := HarnessFlat(value)
        out .= (A_Index = 1 ? "" : ", ") repr
    }
    return out
}

HarnessHex(value) {
    try {
        return Format("0x{:X}", value)
    } catch Error as err {
        return HarnessFlat(value)
    }
}

Send(keys, params*) => HarnessRecord("input", "Send", keys)
SendText(keys, params*) => HarnessRecord("input", "SendText", keys)
SendInput(keys, params*) => HarnessRecord("input", "SendInput", keys)
SendPlay(keys, params*) => HarnessRecord("input", "SendPlay", keys)
SendEvent(keys, params*) => HarnessRecord("input", "SendEvent", keys)
ControlSend(keys, params*) => HarnessRecord("input", "ControlSend", keys)
ControlSendText(keys, params*) => HarnessRecord("input", "ControlSendText", keys)

Click(params*) => HarnessRecord("input", "Click", HarnessJoin(params))
MouseMove(params*) => HarnessRecord("input", "MouseMove", HarnessJoin(params))
MouseClick(params*) => HarnessRecord("input", "MouseClick", HarnessJoin(params))
MouseClickDrag(params*) => HarnessRecord("input", "MouseClickDrag", HarnessJoin(params))
BlockInput(params*) => HarnessRecord("input", "BlockInput", HarnessJoin(params))
SetCapsLockState(params*) => HarnessRecord("input", "SetCapsLockState", HarnessJoin(params))
SetNumLockState(params*) => HarnessRecord("input", "SetNumLockState", HarnessJoin(params))
SetScrollLockState(params*) => HarnessRecord("input", "SetScrollLockState", HarnessJoin(params))

; Waiting on a real key would sit to the deadline; answering "released"
; keeps the candidate moving down its normal path.
KeyWait(keyName, params*) {
    HarnessRecord("input", "KeyWait", keyName " " HarnessJoin(params))
    return 1
}

; A real InputHook captures — and by default blocks — the user's typing while
; it runs. The stand-in records the request and reports a stopped hook with
; no input, the answer a hook that was never fed would give.
class InputHook {
    __New(options := "", endKeys := "", matchList := "") {
        HarnessStubInit(this)
        this.HarnessData["prop:EndReason"] := "Stopped"
        this.HarnessData["prop:InProgress"] := 0
        HarnessRecord("input", "InputHook", options)
    }

    Start() {
        HarnessRecord("input", "InputHook.Start", "")
    }

    Wait(maxTime := "") {
        HarnessRecord("input", "InputHook.Wait", maxTime)
        return "Stopped"
    }

    Stop() {
        HarnessRecord("input", "InputHook.Stop", "")
    }

    __Call(name, params) {
        HarnessRecord("input", "InputHook." name, HarnessJoin(params))
        return ""
    }

    __Get(name, params) => HarnessStubGet(this, name)
    __Set(name, params, value) => HarnessStubSet(this, name, value)
}

WinActivate(params*) => HarnessRecord("window", "WinActivate", HarnessJoin(params))
WinActivateBottom(params*) => HarnessRecord("window", "WinActivateBottom", HarnessJoin(params))
WinClose(params*) => HarnessRecord("window", "WinClose", HarnessJoin(params))
WinKill(params*) => HarnessRecord("window", "WinKill", HarnessJoin(params))
WinMinimize(params*) => HarnessRecord("window", "WinMinimize", HarnessJoin(params))
WinMaximize(params*) => HarnessRecord("window", "WinMaximize", HarnessJoin(params))
WinRestore(params*) => HarnessRecord("window", "WinRestore", HarnessJoin(params))
WinMove(params*) => HarnessRecord("window", "WinMove", HarnessJoin(params))
WinMoveBottom(params*) => HarnessRecord("window", "WinMoveBottom", HarnessJoin(params))
WinMoveTop(params*) => HarnessRecord("window", "WinMoveTop", HarnessJoin(params))
WinShow(params*) => HarnessRecord("window", "WinShow", HarnessJoin(params))
WinHide(params*) => HarnessRecord("window", "WinHide", HarnessJoin(params))
WinRedraw(params*) => HarnessRecord("window", "WinRedraw", HarnessJoin(params))
WinMinimizeAll(params*) => HarnessRecord("window", "WinMinimizeAll", HarnessJoin(params))
WinMinimizeAllUndo(params*) => HarnessRecord("window", "WinMinimizeAllUndo", HarnessJoin(params))
WinSetTitle(params*) => HarnessRecord("window", "WinSetTitle", HarnessJoin(params))
WinSetAlwaysOnTop(params*) => HarnessRecord("window", "WinSetAlwaysOnTop", HarnessJoin(params))
WinSetTransparent(params*) => HarnessRecord("window", "WinSetTransparent", HarnessJoin(params))
WinSetTransColor(params*) => HarnessRecord("window", "WinSetTransColor", HarnessJoin(params))
WinSetStyle(params*) => HarnessRecord("window", "WinSetStyle", HarnessJoin(params))
WinSetExStyle(params*) => HarnessRecord("window", "WinSetExStyle", HarnessJoin(params))
WinSetRegion(params*) => HarnessRecord("window", "WinSetRegion", HarnessJoin(params))
WinSetEnabled(params*) => HarnessRecord("window", "WinSetEnabled", HarnessJoin(params))
GroupClose(params*) => HarnessRecord("window", "GroupClose", HarnessJoin(params))
GroupDeactivate(params*) => HarnessRecord("window", "GroupDeactivate", HarnessJoin(params))

; Returns the window it activated; none was.
GroupActivate(params*) {
    HarnessRecord("window", "GroupActivate", HarnessJoin(params))
    return 0
}

ControlClick(params*) => HarnessRecord("control", "ControlClick", HarnessJoin(params))
ControlSetText(params*) => HarnessRecord("control", "ControlSetText", HarnessJoin(params))
ControlFocus(params*) => HarnessRecord("control", "ControlFocus", HarnessJoin(params))
ControlMove(params*) => HarnessRecord("control", "ControlMove", HarnessJoin(params))
ControlShow(params*) => HarnessRecord("control", "ControlShow", HarnessJoin(params))
ControlHide(params*) => HarnessRecord("control", "ControlHide", HarnessJoin(params))
ControlSetEnabled(params*) => HarnessRecord("control", "ControlSetEnabled", HarnessJoin(params))
ControlSetChecked(params*) => HarnessRecord("control", "ControlSetChecked", HarnessJoin(params))
ControlSetStyle(params*) => HarnessRecord("control", "ControlSetStyle", HarnessJoin(params))
ControlSetExStyle(params*) => HarnessRecord("control", "ControlSetExStyle", HarnessJoin(params))
ControlShowDropDown(params*) => HarnessRecord("control", "ControlShowDropDown", HarnessJoin(params))
ControlHideDropDown(params*) => HarnessRecord("control", "ControlHideDropDown", HarnessJoin(params))
ControlDeleteItem(params*) => HarnessRecord("control", "ControlDeleteItem", HarnessJoin(params))
ControlChooseIndex(params*) => HarnessRecord("control", "ControlChooseIndex", HarnessJoin(params))
EditPaste(params*) => HarnessRecord("control", "EditPaste", HarnessJoin(params))
MenuSelect(params*) => HarnessRecord("control", "MenuSelect", HarnessJoin(params))

; Both answer with the item's position; the first is the plausible one.
ControlAddItem(params*) {
    HarnessRecord("control", "ControlAddItem", HarnessJoin(params))
    return 1
}

ControlChooseString(params*) {
    HarnessRecord("control", "ControlChooseString", HarnessJoin(params))
    return 1
}

; A posted message can close, move or drive another application's window, so
; every one is recorded instead of sent.
PostMessage(msg, params*) => HarnessRecord("message", "PostMessage", HarnessHex(msg) " " HarnessJoin(params))

; The script's own hidden main window is the one target that reaches nothing
; else, so a message to it still goes through; anything else is recorded and
; answered with 0.
SendMessage(msg, wParam := 0, lParam := 0, control?, winTitle?, winText?, excludeTitle?, excludeText?, timeout?) {
    if (!IsSet(control) && IsSet(winTitle) && (winTitle = A_ScriptHwnd || winTitle = "ahk_id " A_ScriptHwnd))
        return HarnessReal_SendMessage(msg, wParam, lParam, , winTitle, winText?, excludeTitle?, excludeText?, timeout?)
    HarnessRecord("message", "SendMessage", HarnessHex(msg) " " HarnessJoin([control?, winTitle?]))
    return 0
}

; Writes to disk and registry. A grading run that actually deleted a file,
; created a directory or wrote a key would be a worse outcome than a wrong
; grade. Reads stay real — see the header.
FileDelete(pattern) => HarnessRecord("fs", "FileDelete", pattern)
FileRecycle(pattern) => HarnessRecord("fs", "FileRecycle", pattern)
FileRecycleEmpty(params*) => HarnessRecord("fs", "FileRecycleEmpty", HarnessJoin(params))
FileMove(source, dest, params*) => HarnessRecord("fs", "FileMove", source " -> " dest)
FileCopy(source, dest, params*) => HarnessRecord("fs", "FileCopy", source " -> " dest)
FileSetAttrib(attrs, params*) => HarnessRecord("fs", "FileSetAttrib", attrs " " HarnessJoin(params))
FileSetTime(params*) => HarnessRecord("fs", "FileSetTime", HarnessJoin(params))
FileCreateShortcut(target, linkFile, params*) => HarnessRecord("fs", "FileCreateShortcut", target " -> " linkFile)
FileInstall(source, dest, params*) => HarnessRecord("fs", "FileInstall", source " -> " dest)
DirCreate(path) => HarnessRecord("fs", "DirCreate", path)
DirDelete(path, params*) => HarnessRecord("fs", "DirDelete", path)
DirMove(source, dest, params*) => HarnessRecord("fs", "DirMove", source " -> " dest)
DirCopy(source, dest, params*) => HarnessRecord("fs", "DirCopy", source " -> " dest)
IniWrite(value, filename, section, key := "") => HarnessRecord("fs", "IniWrite", filename " [" section "] " key)
IniDelete(filename, section, key := "") => HarnessRecord("fs", "IniDelete", filename " [" section "] " key)
RegWrite(params*) => HarnessRecord("registry", "RegWrite", HarnessJoin(params))
RegDelete(params*) => HarnessRecord("registry", "RegDelete", HarnessJoin(params))
RegDeleteKey(params*) => HarnessRecord("registry", "RegDeleteKey", HarnessJoin(params))
RegCreateKey(keyName := "") => HarnessRecord("registry", "RegCreateKey", keyName)
Download(url, filename) => HarnessRecord("net", "Download", url " -> " filename)

; The console streams are output, not side effects — and a test that reports
; through them needs them. Every other target is recorded and dropped.
FileAppend(text, fileName := "", options := "") {
    if (fileName = "*" || fileName = "**") {
        HarnessReal_FileAppend(text, fileName, options)
        return ""
    }
    return HarnessRecord("fs", "FileAppend", fileName)
}

; Reads pass through untouched, so config loading keeps working. A write,
; append or read-write open is redirected to a sink file in the run's scratch
; folder and recorded: opening for write truncates on the spot, so the
; redirect has to happen before the open, never after. Append and read-write
; sinks are seeded with the file's current content, so a candidate that
; appends or reads back what it wrote sees what it would have seen.
FileOpen(fileName, flags, encoding?) {
    access := HarnessOpenAccess(fileName, flags)
    if (access = "read" || access = "passthrough")
        return IsSet(encoding) ? HarnessReal_FileOpen(fileName, flags, encoding) : HarnessReal_FileOpen(fileName, flags)
    sink := HarnessSinkFor(fileName)
    HarnessRecord("fs", "FileOpen", access " " fileName " -> " sink)
    if (access != "write") {
        try {
            if (FileExist(fileName) && !InStr(FileExist(fileName), "D"))
                HarnessReal_FileCopy(fileName, sink, 1)
        } catch Error as err {
            HarnessRecord("meta", "sink seed failed", err.Message)
        }
    }
    return IsSet(encoding) ? HarnessReal_FileOpen(sink, flags, encoding) : HarnessReal_FileOpen(sink, flags)
}

HarnessOpenAccess(fileName, flags) {
    if (fileName is Integer)
        return "passthrough"
    if (fileName = "*" || fileName = "**" || fileName = "CONOUT$" || fileName = "CONIN$")
        return "passthrough"
    if (flags is Integer) {
        access := flags & 0x3
        if (access = 0)
            return "read"
        if (access = 1)
            return "write"
        if (access = 2)
            return "append"
        return "readwrite"
    }
    mode := String(flags)
    if (SubStr(mode, 1, 2) = "rw")
        return "readwrite"
    first := SubStr(mode, 1, 1)
    if (first = "w")
        return "write"
    if (first = "a")
        return "append"
    if (first = "h")
        return "passthrough"
    return "read"
}

HarnessSinkFor(fileName) {
    global HARNESS_SINKSEQ
    HARNESS_SINKSEQ += 1
    SplitPath(String(fileName), &name)
    return HARNESS_SINK "\" Format("{:03}", HARNESS_SINKSEQ) "-" RegExReplace(name, "[^\w.-]", "_") ".sink"
}

; Registration, not execution: a dry-run candidate must not own real hotkeys.
; Label syntax (F1::) is covered by the suspension in HarnessBoot.
Hotkey(keyName, params*) => HarnessRecord("hotkey", "Hotkey", keyName)
Hotstring(trigger, params*) => HarnessRecord("hotkey", "Hotstring", trigger)
Suspend(newState := -1) => HarnessRecord("hotkey", "Suspend", newState)

Reload() => HarnessRecord("process", "Reload", "suppressed")

; Run and RunWait accept &OutputVarPID. The variadic tail keeps every call
; shape working, and any VarRef among the trailing args gets this process's
; own PID — a live one, so a candidate's ProcessExist(pid) check succeeds.
; That is safe because ProcessClose and the process waits are shadows too.
Run(target, params*) {
    HarnessRecord("process", "Run", target)
    for value in params {
        if (IsSet(value) && value is VarRef)
            %value% := ProcessExist()
    }
}

RunWait(target, params*) {
    HarnessRecord("process", "RunWait", target)
    for value in params {
        if (IsSet(value) && value is VarRef)
            %value% := ProcessExist()
    }
    return 0
}

ProcessClose(target) {
    HarnessRecord("process", "ProcessClose", target)
    return ProcessExist()
}

ProcessSetPriority(level, params*) => HarnessRecord("process", "ProcessSetPriority", level " " HarnessJoin(params))

; The waits record and return immediately with a plausible answer: the real
; PID when the process exists, otherwise our own PID for ProcessWait (found)
; and 0 for ProcessWaitClose (closed). Blocking here would only run out the
; gate's deadline waiting on processes the Run shadow never started.
ProcessWait(target, params*) {
    HarnessRecord("process", "ProcessWait", target)
    found := ProcessExist(target) ?? 0
    return found ? found : ProcessExist()
}

ProcessWaitClose(target, params*) {
    HarnessRecord("process", "ProcessWaitClose", target)
    return 0
}

; The job object's UI limit already refuses a log-off, but a dry run should
; never get that far: this is the first line, that is the backstop.
Shutdown(flag) => HarnessRecord("system", "Shutdown", flag)
SoundSetVolume(setting, params*) => HarnessRecord("system", "SoundSetVolume", setting " " HarnessJoin(params))
SoundSetMute(setting, params*) => HarnessRecord("system", "SoundSetMute", setting " " HarnessJoin(params))
DriveEject(params*) => HarnessRecord("system", "DriveEject", HarnessJoin(params))
DriveLock(drive) => HarnessRecord("system", "DriveLock", drive)
DriveUnlock(drive) => HarnessRecord("system", "DriveUnlock", drive)
DriveSetLabel(drive, params*) => HarnessRecord("system", "DriveSetLabel", drive " " HarnessJoin(params))

; Returning a plausible value matters more than logging here: a script that
; branches on the answer has to keep going, or the dry run only ever exercises
; the path up to the first prompt. MsgBox answers with the affirmative button
; of whichever button set the options ask for, so the "user said yes" branch
; is the one that gets graded.
MsgBox(text := "", title := "", options := "") {
    answer := HarnessMsgBoxAnswer(options)
    HarnessRecord("dialog", "MsgBox", answer " <- " text)
    return answer
}

HarnessMsgBoxAnswer(options) {
    set := 0
    if IsNumber(options)
        set := Integer(options) & 0x7
    else {
        opts := String(options)
        if RegExMatch(opts, "i)\b(YesNoCancel|Y/?N/?C)\b")
            set := 3
        else if RegExMatch(opts, "i)\b(YesNo|Y/?N)\b")
            set := 4
        else if RegExMatch(opts, "i)\b(OKCancel|O/?C)\b")
            set := 1
        else if RegExMatch(opts, "i)\b(AbortRetryIgnore|A/?R/?I)\b")
            set := 2
        else if RegExMatch(opts, "i)\b(RetryCancel|R/?C)\b")
            set := 5
        else if RegExMatch(opts, "i)\b(CancelTryAgainContinue|C/?T/?C)\b")
            set := 6
        else if RegExMatch(opts, "\b(\d+)\b", &m)
            set := Integer(m[1]) & 0x7
    }
    answers := Map()
    answers[0] := "OK"
    answers[1] := "OK"
    answers[2] := "Retry"
    answers[3] := "Yes"
    answers[4] := "Yes"
    answers[5] := "Retry"
    answers[6] := "Continue"
    return answers.Get(set, "OK")
}

InputBox(prompt := "", title := "", options := "", default := "") {
    HarnessRecord("dialog", "InputBox", prompt)
    return { Value: default, Result: "OK" }
}

FileSelect(options := "", root := "", title := "", filter := "") {
    HarnessRecord("dialog", "FileSelect", title)
    return ""
}

DirSelect(root := "", options := "", prompt := "") {
    HarnessRecord("dialog", "DirSelect", prompt)
    return ""
}

ToolTip(text := "", params*) => HarnessRecord("ui", "ToolTip", text)
TrayTip(text := "", params*) => HarnessRecord("ui", "TrayTip", text)
SoundBeep(params*) => HarnessRecord("ui", "SoundBeep", HarnessJoin(params))
SoundPlay(fileName, params*) => HarnessRecord("ui", "SoundPlay", fileName)
Edit() => HarnessRecord("ui", "Edit", A_ScriptFullPath)
ListVars() => HarnessRecord("ui", "ListVars", "")
ListHotkeys() => HarnessRecord("ui", "ListHotkeys", "")

; With an argument these only change an in-process setting; without one they
; open the main window, which is the part a dry run must not do.
ListLines(mode?) {
    if IsSet(mode)
        return HarnessReal_ListLines(mode)
    return HarnessRecord("ui", "ListLines", "")
}

KeyHistory(maxEvents?) {
    if IsSet(maxEvents) {
        HarnessReal_KeyHistory(maxEvents)
        return ""
    }
    return HarnessRecord("ui", "KeyHistory", "")
}

HarnessMenuShow(menuObj, params*) => HarnessRecord("ui", "Menu.Show", HarnessJoin(params))

; Honoured, but capped and sliced. Real waits are the single biggest reason a
; UI script takes minutes instead of seconds, and nothing here is waiting on a
; real event. Slices of at most 15 ms return control to the interpreter between
; DllCalls, so SetTimer threads still interrupt mid-sleep the way they would
; during a real Sleep — one long DllCall("Sleep") starves them. A cap of 0
; skips sleeping entirely.
Sleep(ms) {
    if (ms > HARNESS_MAXSLEEP) {
        HarnessRecord("timing", "Sleep", ms " ms capped to " HARNESS_MAXSLEEP)
        ms := HARNESS_MAXSLEEP
    }
    remaining := ms
    while (remaining > 0) {
        slice := remaining < 15 ? remaining : 15
        HarnessReal_DllCall("Sleep", "UInt", slice)
        remaining -= slice
    }
}

; Everything not on the deny-list is forwarded untouched, output VarRefs
; included. A denied call is recorded and answered with what success looks
; like, so the candidate stays on the path it would take for real.
; A call declared with the alpha.30 "Void" return type yields no value, and
; returning that through this wrapper would throw UnsetError ("No value was
; returned") where the candidate's own call would not, so it is forwarded
; without a return.
DllCall(fn, args*) {
    if (fn is String) {
        name := HarnessDllDenied(fn)
        if (name != "") {
            HarnessRecord("dll", name, HarnessJoin(args))
            return HarnessDllAnswer(name, args)
        }
    }
    if (HarnessDllIsVoid(args)) {
        HarnessReal_DllCall(fn, args*)
        return
    }
    return HarnessReal_DllCall(fn, args*)
}

; The return type is the odd trailing argument; "Void" (optionally
; "Cdecl Void") is the alpha.30 form that produces no value.
HarnessDllIsVoid(args) {
    if !(args.Length & 1)
        return false
    last := args[args.Length]
    if !(last is String)
        return false
    return RegExMatch(last, "i)^\s*(cdecl\s+)?void\s*$") > 0
}

HarnessDllDenied(fn) {
    static deny := ""
    if !(deny is Map) {
        deny := Map()
        deny.CaseSense := "Off"
        for name in ["SendInput", "keybd_event", "mouse_event", "SetCursorPos", "BlockInput"
            , "SetForegroundWindow", "BringWindowToTop", "SwitchToThisWindow", "SetWindowPos"
            , "MoveWindow", "ShowWindow", "CloseWindow", "EndTask", "DestroyWindow", "EnableWindow"
            , "SetWindowLong", "SetWindowLongPtr", "SetParent", "SetWindowText", "SetWindowPlacement"
            , "SetLayeredWindowAttributes"
            , "PostMessage", "SendMessage", "SendMessageTimeout", "SendNotifyMessage", "PostThreadMessage"
            , "MessageBox", "MessageBoxEx", "MessageBoxIndirect", "MessageBoxTimeout", "ShellMessageBox"
            , "ShellExecute", "ShellExecuteEx", "WinExec", "CreateProcess", "CreateProcessAsUser"
            , "CreateProcessWithLogon", "CreateProcessWithToken", "TerminateProcess"
            , "ExitWindowsEx", "InitiateSystemShutdown", "InitiateSystemShutdownEx", "InitiateShutdown"
            , "LockWorkStation", "SetSuspendState"
            , "DeleteFile", "MoveFile", "MoveFileEx", "CopyFile", "CopyFileEx", "RemoveDirectory"
            , "CreateDirectory", "CreateDirectoryEx", "SHCreateDirectoryEx", "SHFileOperation"
            , "SHEmptyRecycleBin", "ReplaceFile", "CreateHardLink", "CreateSymbolicLink", "SetFileAttributes"
            , "RegSetValue", "RegSetValueEx", "RegSetKeyValue", "RegDeleteValue", "RegDeleteKey"
            , "RegDeleteKeyEx", "RegDeleteTree", "RegCreateKey", "RegCreateKeyEx"
            , "SHSetValue", "SHDeleteKey", "SHDeleteValue"
            , "URLDownloadToFile", "URLDownloadToCacheFile", "SetWindowsHookEx", "UnhookWindowsHookEx"
            , "Beep", "MessageBeep", "PlaySound", "sndPlaySound", "waveOutSetVolume"
            , "ChangeDisplaySettings", "ChangeDisplaySettingsEx", "SwitchDesktop"]
            deny[name] := name
    }
    name := RegExReplace(fn, "^.*\\")
    if deny.Has(name)
        return deny[name]
    if (RegExMatch(name, "^(.+)[AWaw]$", &m) && deny.Has(m[1]))
        return deny[m[1]]
    return ""
}

HarnessDllAnswer(name, args) {
    if (name = "SendInput")
        return (args.Has(2) && IsInteger(args[2])) ? args[2] : 0
    if (name = "ShellExecute" || name = "WinExec")
        return 33
    ; Success is 0 (ERROR_SUCCESS / S_OK) for these; CreateProcess answers
    ; failure instead, since a fake success would hand back no real handles.
    if RegExMatch(name, "i)^(CreateProcess|InitiateShutdown|SHFileOperation|SHEmptyRecycleBin|SHCreateDirectory"
        . "|SHSetValue|SHDelete|URLDownload|Reg)")
        return 0
    return 1
}

; COM automation with effects — the shell, the file system, other users'
; applications, HTTP, speech, the scheduler, the firewall — gets a recording
; stand-in. Everything else (RegExp, Dictionary, XML parsing, WMI) is real.
class ComObject extends HarnessReal_ComObject {
    static Call(clsid, iid?) {
        id := HarnessFlat(clsid)
        if HarnessComDenied(id) {
            HarnessRecord("com", "ComObject", id " (stubbed)")
            return HarnessStubObject("com", id)
        }
        HarnessRecord("com", "ComObject", id)
        return IsSet(iid) ? HarnessReal_ComObject(clsid, iid) : HarnessReal_ComObject(clsid)
    }
}

; Attaching to a running instance means driving the user's own open
; documents, so it is always a stand-in.
ComObjActive(clsid) {
    HarnessRecord("com", "ComObjActive", HarnessFlat(clsid) " (stubbed)")
    return HarnessStubObject("com", HarnessFlat(clsid))
}

; WMI monikers are queries far more often than not and stay real; any other
; moniker binds a file or object the shim cannot see into.
ComObjGet(name) {
    if RegExMatch(name, "i)^winmgmts:") {
        HarnessRecord("com", "ComObjGet", name)
        return HarnessReal_ComObjGet(name)
    }
    HarnessRecord("com", "ComObjGet", name " (stubbed)")
    return HarnessStubObject("com", name)
}

HarnessComDenied(id) {
    return RegExMatch(id, "i)^(WScript\.(Shell|Network)|Shell\.Application|Scripting\.FileSystemObject|Schedule\.Service"
        . "|SAPI\.SpVoice|HNetCfg\.|WinHttp\.WinHttpRequest|MSXML2\.(Server)?XMLHTTP|Microsoft\.XMLHTTP|MAPI\."
        . "|InternetExplorer\.|\w+\.Application)(\.|$)")
}

; A recording stand-in for objects the shim refuses to create. Method calls
; and property reads are recorded and answered with another stand-in, so a
; chain such as shell.Exec(cmd).StdOut keeps going; enumeration is empty and
; the string form is blank.
class HarnessStubObject {
    __New(kind, label) {
        HarnessStubInit(this)
        this.HarnessData["kind"] := kind
        this.HarnessData["label"] := label
    }

    __Call(name, params) {
        label := this.HarnessData["label"] "." name
        HarnessRecord(this.HarnessData["kind"], label, HarnessJoin(params))
        return HarnessStubObject(this.HarnessData["kind"], label)
    }

    __Get(name, params) {
        if this.HarnessData.Has("prop:" name)
            return this.HarnessData["prop:" name]
        return HarnessStubObject(this.HarnessData["kind"], this.HarnessData["label"] "." name)
    }

    __Set(name, params, value) {
        HarnessRecord(this.HarnessData["kind"], this.HarnessData["label"] "." name " :=", HarnessFlat(value))
        this.HarnessData["prop:" name] := value
        return value
    }

    __Enum(numberOfVars) => HarnessEmptyEnum
    ToString() => ""
}

HarnessEmptyEnum(params*) => false

; A record-only Gui. The class declaration shadows the built-in across the
; script, so candidate windows never exist — Show records one "gui" intent
; instead of putting a window on the desktop. Explicit members cover the
; common shapes; the catch-alls absorb everything else, including subclasses
; (`class MyGui extends Gui` resolves to this stub) whose initializers and
; property writes route through __Set. Internal state lives in a DefineProp'd
; own property so the catch-alls never recurse into themselves.
;
; The stand-in keeps a position and size, because layout code asks for them:
; GetPos and GetClientPos answer through ByRef parameters, and a stand-in that
; left those unset made `gui.GetClientPos(,, &w, &h)` followed by `w - 20`
; throw in the stub, not in the script. The numbers come from the x/y/w/h
; options the candidate itself passed to Show, Add or Move, with a plain
; default where it passed none.
class Gui {
    __New(options := "", title := "", eventObj := "") {
        HarnessStubInit(this)
        this.HarnessData["prop:Title"] := title
        HarnessRecord("gui", "Gui.New", options (title = "" ? "" : " `"" title "`""))
    }

    static __Get(name, params) => HarnessGuiControl

    Hwnd => 0

    Add(ctrlType, options := "", text := "") {
        HarnessRecord("gui", "Gui.Add", ctrlType (options = "" ? "" : " " options))
        return HarnessGuiControl(this, ctrlType, text, options)
    }

    Show(options := "") {
        HarnessGeometryFromOptions(this, options)
        HarnessRecord("gui", "Gui.Show"
            , this.HarnessData.Get("prop:Title", "") (options = "" ? "" : " " options))
    }

    OnEvent(eventName, callback, addRemove := 1) {
        HarnessRecord("gui", "Gui.OnEvent", eventName)
    }

    __Call(name, params) {
        HarnessRecord("gui", "Gui." name, HarnessJoin(params))
        if (SubStr(name, 1, 3) = "Add")
            return HarnessGuiControl(this, SubStr(name, 4), params.Has(2) ? params[2] : ""
                , params.Has(1) ? params[1] : "")
        HarnessGeometryCall(this, name, params)
        return ""
    }

    __Get(name, params) => HarnessStubGet(this, name)
    __Set(name, params, value) => HarnessStubSet(this, name, value)
}

; Shared stand-in for every control type Gui.Add hands out. Value and Text are
; readable and writable through the catch-alls; the class-level __Get makes
; `ctl is Gui.Button` (and any other Gui.<Type>) hold true for stub controls.
class HarnessGuiControl {
    __New(owner, ctrlType, text := "", options := "") {
        HarnessStubInit(this)
        this.HarnessData["prop:Type"] := ctrlType
        this.HarnessData["prop:Text"] := text
        this.HarnessData["prop:Value"] := text
        this.HarnessData["prop:Gui"] := owner
        HarnessGeometryFromOptions(this, options)
    }

    static __Get(name, params) => ""

    Hwnd => 0

    OnEvent(eventName, callback, addRemove := 1) {
        HarnessRecord("gui", "Ctrl.OnEvent", this.HarnessData.Get("prop:Type", "") " " eventName)
    }

    __Call(name, params) {
        HarnessRecord("gui", "Ctrl." name, HarnessJoin(params))
        HarnessGeometryCall(this, name, params)
        return ""
    }

    __Get(name, params) => HarnessStubGet(this, name)
    __Set(name, params, value) => HarnessStubSet(this, name, value)
}

; A stub's stored [x, y, w, h], created on first use. Not set in __New: a
; subclass whose own __New never calls super.__New still gets asked for it.
HarnessGeometry(obj) {
    HarnessStubInit(obj)
    if !obj.HarnessData.Has("geometry")
        obj.HarnessData["geometry"] := (obj is HarnessGuiControl) ? [0, 0, 100, 24] : [0, 0, 800, 600]
    return obj.HarnessData["geometry"]
}

; Reads x, y, w and h out of an options string ("x10 y5 w300 h200 Center")
; into a stub's stored geometry. Only plain numbers count: xm, x+10, wp and
; the like are relative to things the stand-in does not model, and leave the
; stored value alone.
HarnessGeometryFromOptions(obj, options) {
    if !(options is String)
        return
    if (options = "")
        return
    geometry := HarnessGeometry(obj)
    for index, letter in ["x", "y", "w", "h"] {
        if RegExMatch(options, "i)(?:^|\s)" letter "(\d+)(?=\s|$)", &m)
            geometry[index] := Integer(m[1])
    }
}

; The geometry half of a stub's __Call. GetPos and GetClientPos hand back the
; stored x, y, w, h through whichever ByRef parameters the caller passed; Move
; stores the numbers it was given. A ByRef parameter on any other method gets
; 0, for the same reason: a variable the built-in would have set must not
; reach the candidate unset.
HarnessGeometryCall(obj, name, params) {
    geometry := HarnessGeometry(obj)
    if (name = "Move") {
        for index, value in params {
            if (index <= 4 && IsSet(value) && !IsObject(value) && IsNumber(value))
                geometry[index] := Integer(value)
        }
        return
    }
    known := (name = "GetPos" || name = "GetClientPos")
    for index, value in params {
        if (IsSet(value) && value is VarRef)
            %value% := (known && index <= 4) ? geometry[index] : 0
    }
}

; DefineProp, not assignment: a plain `this.x :=` in __New routes through the
; __Set catch-all on alpha.30, and pairing that with a __Get catch-all is the
; classic infinite-recursion trap. ObjHasOwnProp and DefineProp bypass both.
HarnessStubInit(obj) {
    if !ObjHasOwnProp(obj, "HarnessData") {
        store := Map()
        store.CaseSense := "Off"
        obj.DefineProp("HarnessData", {Value: store})
    }
}

HarnessStubGet(obj, name) {
    HarnessStubInit(obj)
    if (name = "HarnessData")
        return obj.HarnessData
    return obj.HarnessData.Get("prop:" name, "")
}

HarnessStubSet(obj, name, value) {
    HarnessStubInit(obj)
    obj.HarnessData["prop:" name] := value
    return value
}
