#Requires AutoHotkey v2.1-alpha.30

; DryRunShim.ahk — makes a UI script runnable without giving it the desktop.
;
; A user-defined function shadows the built-in of the same name, and the shadow
; reaches across #Include. So a generated wrapper that includes this file and
; then the candidate gets a script whose Send, Click, WinActivate and friends
; record what they were asked to do instead of doing it.
;
; What is intercepted: synthetic input, window and control manipulation, Gui
; construction (a record-only stub class, so no candidate window ever exists),
; dialogs, Run/RunWait/Reload, Hotkey()/Hotstring() registration, process
; close/priority/waits, and the write half of file, directory, ini, registry
; and download I/O.
;
; Read-only queries (FileRead, IniRead, RegRead, FileExist, ProcessExist,
; WinExist, WinGetTitle, MouseGetPos) are deliberately NOT shadowed. Faking
; them invents a desktop the script then reasons about, and the invented
; answers are wrong in ways that look like script bugs. Observing the real
; desktop changes nothing about it.
;
; Residual gaps — a candidate can still reach the world through:
;   A_Clipboard      built-in variable; no user declaration can shadow it
;   FileOpen         deliberately left real: a stub would break legitimate
;                    config reads, which costs more than the write-handle leak
;   DllCall/ComCall  arbitrary API surface
;   ComObject        COM automation (shell, FileSystemObject, Office)
;   F1:: / ::x::     hotkey and hotstring *syntax* — only the Hotkey() and
;                    Hotstring() function forms are intercepted
; A dry-run pass therefore means "no intercepted effect fired", not "proven
; side-effect free".
;
; That is what lets tier 3 fan out. Live-input runs are serial because focus and
; synthetic input are one shared resource; a dry run owns nothing, so any number
; can run at once.
;
; Configured by environment, set by GateDryRun.ahk:
;   AHK_HARNESS_LOG        file to append intent records to (required)
;   AHK_HARNESS_MAXSLEEP   longest honoured Sleep in ms (default 50; an
;                          explicit 0 means skip sleeping entirely)
;
; The deadline is deliberately not set here — see the note above OnExit.

global HARNESS_LOG := EnvGet("AHK_HARNESS_LOG")
; Not `|| 50`: that would eat an explicit 0, and 0 is meaningful — skip all
; sleeping. Only an absent or empty variable falls back to the default.
global HARNESS_ENVCAP := EnvGet("AHK_HARNESS_MAXSLEEP")
global HARNESS_MAXSLEEP := (HARNESS_ENVCAP = "") ? 50 : Integer(HARNESS_ENVCAP)
global HARNESS_COUNT := 0
global HARNESS_STARTED := A_TickCount

if (HARNESS_LOG = "")
    HARNESS_LOG := A_Temp "\ahk-harness-dryrun.log"

HarnessRecord("meta", "dry-run start", A_ScriptFullPath)

; The deadline is deliberately NOT a SetTimer here. A pending timer is itself a
; reason for AHK to stay alive, so an in-script watchdog keeps every candidate
; running to the deadline and a script that finished cleanly becomes
; indistinguishable from a persistent one. GateDryRun.ahk enforces the deadline
; from outside and probes the message loop before killing, which tells those two
; apart instead of erasing the difference.
OnExit(HarnessOnExit)

HarnessOnExit(reason, code) {
    HarnessRecord("meta", "dry-run end", reason " code=" code
        . " actions=" HARNESS_COUNT " ms=" (A_TickCount - HARNESS_STARTED))
    return 0
}

; One tab-separated record per intercepted call. Appended as it happens, so a
; script that hangs still leaves a usable trail behind it. Written with FileOpen
; because FileAppend is shadowed below and the log must reach the real disk.
HarnessRecord(kind, name, detail := "") {
    global HARNESS_COUNT, HARNESS_LOG
    if (kind != "meta")
        HARNESS_COUNT += 1
    line := Format("{}`t{}`t{}`t{}`n", A_TickCount - HARNESS_STARTED, kind, name
        , StrReplace(StrReplace(String(detail), "`r", " "), "`n", " "))
    try {
        logHandle := FileOpen(HARNESS_LOG, "a", "UTF-8")
        if IsObject(logHandle) {
            logHandle.Write(line)
            logHandle.Close()
        }
    } catch Error as err {
        OutputDebug("harness: cannot write log: " err.Message)
    }
}

HarnessJoin(params) {
    out := ""
    for value in params {
        if !IsSet(value)
            repr := "<unset>"
        else if IsObject(value)
            repr := "<" Type(value) ">"
        else
            repr := String(value)
        out .= (A_Index = 1 ? "" : ", ") repr
    }
    return out
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

WinActivate(params*) => HarnessRecord("window", "WinActivate", HarnessJoin(params))
WinActivateBottom(params*) => HarnessRecord("window", "WinActivateBottom", HarnessJoin(params))
WinClose(params*) => HarnessRecord("window", "WinClose", HarnessJoin(params))
WinKill(params*) => HarnessRecord("window", "WinKill", HarnessJoin(params))
WinMinimize(params*) => HarnessRecord("window", "WinMinimize", HarnessJoin(params))
WinMaximize(params*) => HarnessRecord("window", "WinMaximize", HarnessJoin(params))
WinRestore(params*) => HarnessRecord("window", "WinRestore", HarnessJoin(params))
WinMove(params*) => HarnessRecord("window", "WinMove", HarnessJoin(params))
WinShow(params*) => HarnessRecord("window", "WinShow", HarnessJoin(params))
WinHide(params*) => HarnessRecord("window", "WinHide", HarnessJoin(params))
WinSetTitle(params*) => HarnessRecord("window", "WinSetTitle", HarnessJoin(params))
WinSetAlwaysOnTop(params*) => HarnessRecord("window", "WinSetAlwaysOnTop", HarnessJoin(params))
WinSetTransparent(params*) => HarnessRecord("window", "WinSetTransparent", HarnessJoin(params))

ControlClick(params*) => HarnessRecord("control", "ControlClick", HarnessJoin(params))
ControlSetText(params*) => HarnessRecord("control", "ControlSetText", HarnessJoin(params))
ControlFocus(params*) => HarnessRecord("control", "ControlFocus", HarnessJoin(params))
ControlMove(params*) => HarnessRecord("control", "ControlMove", HarnessJoin(params))
ControlShow(params*) => HarnessRecord("control", "ControlShow", HarnessJoin(params))
ControlHide(params*) => HarnessRecord("control", "ControlHide", HarnessJoin(params))
ControlEnable(params*) => HarnessRecord("control", "ControlEnable", HarnessJoin(params))
ControlDisable(params*) => HarnessRecord("control", "ControlDisable", HarnessJoin(params))

; Writes to disk and registry. A grading run that actually deleted a file,
; created a directory or wrote a key would be a worse outcome than a wrong
; grade. Reads stay real — see the header.
FileDelete(pattern) => HarnessRecord("fs", "FileDelete", pattern)
FileRecycle(pattern) => HarnessRecord("fs", "FileRecycle", pattern)
FileMove(source, dest, params*) => HarnessRecord("fs", "FileMove", source " -> " dest)
FileCopy(source, dest, params*) => HarnessRecord("fs", "FileCopy", source " -> " dest)
FileAppend(text, filename := "", options := "") => HarnessRecord("fs", "FileAppend", filename)
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

; Registration, not execution: a dry-run candidate must not own real hotkeys.
; Only the function forms can be shadowed; F1:: label syntax registers for real.
Hotkey(keyName, params*) => HarnessRecord("hotkey", "Hotkey", keyName)
Hotstring(trigger, params*) => HarnessRecord("hotkey", "Hotstring", trigger)

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

; Honoured, but capped and sliced. Real waits are the single biggest reason a
; UI script takes minutes instead of seconds, and nothing here is waiting on a
; real event. Slices of at most 15 ms return control to the interpreter between
; DllCalls, so SetTimer threads still interrupt mid-sleep the way they would
; during a real Sleep — one long DllCall("Sleep") starves them. A cap of 0
; skips sleeping entirely.
Sleep(ms) {
    global HARNESS_MAXSLEEP
    if (ms > HARNESS_MAXSLEEP) {
        HarnessRecord("timing", "Sleep", ms " ms capped to " HARNESS_MAXSLEEP)
        ms := HARNESS_MAXSLEEP
    }
    remaining := ms
    while (remaining > 0) {
        slice := remaining < 15 ? remaining : 15
        DllCall("Sleep", "UInt", slice)
        remaining -= slice
    }
}

; A record-only Gui. The class declaration shadows the built-in across
; #Include, so candidate windows never exist — Show records one "gui" intent
; instead of putting a window on the desktop. Explicit members cover the
; common shapes; the catch-alls absorb everything else, including subclasses
; (`class MyGui extends Gui` resolves to this stub) whose initializers and
; property writes route through __Set. Internal state lives in a DefineProp'd
; own property so the catch-alls never recurse into themselves.
class Gui {
    __New(options := "", title := "", eventObj := "") {
        HarnessGuiInit(this)
        this.HarnessData["prop:Title"] := title
        HarnessRecord("gui", "Gui.New", options (title = "" ? "" : " `"" title "`""))
    }

    static __Get(name, params) => HarnessGuiControl

    Hwnd => 0

    Add(ctrlType, options := "", text := "") {
        HarnessRecord("gui", "Gui.Add", ctrlType (options = "" ? "" : " " options))
        return HarnessGuiControl(this, ctrlType, text)
    }

    Show(options := "") {
        HarnessRecord("gui", "Gui.Show"
            , this.HarnessData.Get("prop:Title", "") (options = "" ? "" : " " options))
    }

    OnEvent(eventName, callback, addRemove := 1) {
        HarnessRecord("gui", "Gui.OnEvent", eventName)
    }

    __Call(name, params) {
        HarnessRecord("gui", "Gui." name, HarnessJoin(params))
        if (SubStr(name, 1, 3) = "Add")
            return HarnessGuiControl(this, SubStr(name, 4), params.Has(2) ? params[2] : "")
        return ""
    }

    __Get(name, params) => HarnessGuiGet(this, name)
    __Set(name, params, value) => HarnessGuiSet(this, name, value)
}

; Shared stand-in for every control type Gui.Add hands out. Value and Text are
; readable and writable through the catch-alls; the class-level __Get makes
; `ctl is Gui.Button` (and any other Gui.<Type>) hold true for stub controls.
class HarnessGuiControl {
    __New(owner, ctrlType, text := "") {
        HarnessGuiInit(this)
        this.HarnessData["prop:Type"] := ctrlType
        this.HarnessData["prop:Text"] := text
        this.HarnessData["prop:Value"] := text
        this.HarnessData["prop:Gui"] := owner
    }

    static __Get(name, params) => ""

    Hwnd => 0

    OnEvent(eventName, callback, addRemove := 1) {
        HarnessRecord("gui", "Ctrl.OnEvent", this.HarnessData.Get("prop:Type", "") " " eventName)
    }

    __Call(name, params) {
        HarnessRecord("gui", "Ctrl." name, HarnessJoin(params))
        return ""
    }

    __Get(name, params) => HarnessGuiGet(this, name)
    __Set(name, params, value) => HarnessGuiSet(this, name, value)
}

; DefineProp, not assignment: a plain `this.x :=` in __New routes through the
; __Set catch-all on alpha.30, and pairing that with a __Get catch-all is the
; classic infinite-recursion trap. ObjHasOwnProp and DefineProp bypass both.
HarnessGuiInit(obj) {
    if !ObjHasOwnProp(obj, "HarnessData") {
        store := Map()
        store.CaseSense := "Off"
        obj.DefineProp("HarnessData", {Value: store})
    }
}

HarnessGuiGet(obj, name) {
    HarnessGuiInit(obj)
    if (name = "HarnessData")
        return obj.HarnessData
    return obj.HarnessData.Get("prop:" name, "")
}

HarnessGuiSet(obj, name, value) {
    HarnessGuiInit(obj)
    obj.HarnessData["prop:" name] := value
    return value
}
