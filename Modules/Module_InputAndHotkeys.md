---
name: Module_InputAndHotkeys
description: 'Keyboard and mouse input in AHK v2 - hotkey and hotstring syntax and options, #HotIf and HotIf()
  context rules, the Hotkey() and Hotstring() functions, Send modes (SendInput limits, SetKeyDelay, SendText,
  Blind), GetKeyState, KeyWait, A_PriorHotkey double-tap detection, InputHook text capture with OnChar and
  OnKeyDown, BlockInput, and class-managed dynamic hotkeys with a Dispose method. TRIGGER when the request
  involves: hotkey, hotstring, Hotkey(), Hotstring(), #HotIf, HotIf, HotIfWinActive, Send, SendInput,
  SendEvent, SendText, SendMode, SetKeyDelay, Click, KeyWait, GetKeyState, InputHook, BlockInput,
  A_PriorHotkey, A_ThisHotkey, "context-sensitive hotkey", "only works in this app", "double tap",
  "wait for a keypress", "capture typing", "remap a key", "text expansion", "send keys".
  Not covered: tap versus hold libraries - see Module_TapHold.md; hotkey inputs inside a Gui and control
  events - see Module_GUI.md; ControlSend to a background window - see Module_WindowAndControl.md; pixel,
  image and coordinate work - see Module_GraphicsAndScreen.md; try/catch design - see Module_Errors.md.'
---

# Module_InputAndHotkeys

Everything here targets AutoHotkey v2.1-alpha.33+Console. A script with hotkeys cannot be exercised
headless, so check blocks with the parser (`check` verb or `Check(Source)`), never by running them.

## Rules that decide most bugs

- A hotkey body of more than one statement needs braces: `^k:: { ... }`. One statement may follow the
  `::` directly. There is no bare `return` terminator as in v1.
- A hotkey or hotstring callback is called with one argument (the hotkey or hotstring name). Declare a
  parameter or `(*)` to accept and ignore it: `Hotkey("F1", (*) => Action())`. The documentation
  only promises a one-parameter callback, so do not depend on a zero-parameter function being tolerated.
- Every `#HotIf expr` stays in force for all later hotkeys until a bare `#HotIf` line resets it.
- A `#HotIf` expression is not run only when the trigger key goes down. The program may also evaluate it
  to learn whether a prefix key is a custom modifier, and input is buffered until it finishes. Keep it
  tiny: no file or network access, no Send, no clicks. Plain `WinActive("...")` and `WinExist("...")`
  expressions are optimised and cost almost nothing.
- Hotkeys cannot be deleted at runtime, only disabled with `Hotkey(name, "Off")`. The same holds for
  `HotIf(callback)` objects. See "Dynamic hotkeys in a class" for the lifetime consequence.
- Key names and option strings are quoted strings: `GetKeyState("CapsLock", "T")`, `KeyWait("Enter", "D T5")`.
- `KeyWait` returns 1 or 0 (timed out). `ErrorLevel` does not exist.
- Hotkeys are inert over windows of a higher integrity level (elevated apps) unless the script is also
  elevated; see Module_Errors.md for diagnosing that.

## Hotkeys

```ahk
#Requires AutoHotkey v2.1-alpha.30

^j::SendText("Hello World")

^k:: {
    Send("Line 1{Enter}")
    Sleep(100)
    Send("Line 2")
}

; Custom modifier: CapsLock stays a normal key on its own
CapsLock & a:: {
    SendText("chord fired")
}

; Fires on release rather than press
^!r Up:: {
    ToolTip("released")
    SetTimer(() => ToolTip(), -800)
}
```

Prefixes worth knowing:

| Prefix | Meaning |
|--------|---------|
| `~` | Native function is kept: the key press still reaches the active window |
| `$` | Use the keyboard hook so the script's own `Send` cannot trigger this hotkey |
| `*` | Fires even if extra modifiers are held |
| `<^` `>!` | Left or right modifier only |
| `Up` suffix | Fires on key release |

`~`, `*`, `Up` hotkeys and `&` combinations always use the keyboard hook; `$` adds nothing for them. A
script that only needs one hotkey inside one program should still scope it with `#HotIf`.

## Hotstrings

```ahk
#Requires AutoHotkey v2.1-alpha.30

::btw::by the way
:*:addr::12 Main Street
:C:NASA::National Aeronautics and Space Administration
:T:snip::Use {Enter} and ^c literally here
:*b0:<em>::</em>{left 5}

::/time:: {
    SendText(FormatTime(, "HH:mm"))
}

::sig::
(
Best regards,
John Doe
)
```

| Option | Effect |
|--------|--------|
| `*` | Fire immediately, no ending character needed |
| `?` | Fire even inside another word |
| `C` | Case-sensitive (without it, replacement conforms to the typed case) |
| `B0` | Do not erase the abbreviation first |
| `O` | Omit the ending character from the output |
| `T` | Send the replacement as literal text |
| `R` | Send raw, no `{Enter}` or `^c` translation |
| `X` | Treat the replacement as an expression to run (definition lines only) |
| `SE` `SI` `SP` | Send method for the replacement; the default is SendInput |
| `Z` | Reset the recognizer after each trigger |

An ordinary replacement is sent like `Send`, so `!`, `^`, `+`, `#` and `{` inside it are commands. Add `T`
(or `R`) whenever the replacement contains them. A continuation section already implies `T`.

Create hotstrings at runtime with `Hotstring()`; pass a function object rather than the `X` option:

```ahk
#Requires AutoHotkey v2.1-alpha.30

Hotstring(":*:ty2", "thank you")

Greet(hotstringName) {
    SendText("Hello from " hotstringName)
}
Hotstring("::greet", Greet)

; Add characters that end a hotstring, and drop half-typed text
Hotstring("EndChars", "-()[]{}':;`"/\,.?!`n`s`t")
Hotstring("Reset")
```

## #HotIf and HotIf()

```ahk
#Requires AutoHotkey v2.1-alpha.30

#HotIf WinActive("ahk_exe notepad.exe")
^s::SendText("saving in Notepad")
#HotIf

#HotIf !WinActive("ahk_exe Teams.exe")
^Space::SendText("launcher everywhere except Teams")
#HotIf

g_editMode := false

EditModeOn() {
    return g_editMode
}

#HotIf EditModeOn()
^Enter::SendText("run block")
#HotIf

F4:: {
    global g_editMode := !g_editMode
    ToolTip("edit mode " (g_editMode ? "on" : "off"))
    SetTimer(() => ToolTip(), -1200)
}
```

For runtime-created hotkeys use `HotIf()` with one stable function object, then reset it:

```ahk
#Requires AutoHotkey v2.1-alpha.30

InNotepad(*) => WinActive("ahk_exe notepad.exe")

HotIf(InNotepad)
Hotkey("^!n", (*) => SendText("only in Notepad"))
HotIf()

; Same criterion by window, evaluated by the program itself
HotIfWinActive("ahk_class Notepad")
Hotkey("^!m", (*) => SendText("also only in Notepad"))
HotIf()
```

Reuse the identical function object to modify a hotkey variant later; a new lambda on every call creates a
new variant each time. A function passed to `HotIf()` is never freed, so create it once. `HotIfWin...`
functions use the title-match settings from the auto-execute section.

## Send and its modes

`Send` is `SendInput` by default. What that means in practice:

- `SetKeyDelay` is ignored by SendInput (no delay is possible). It applies to SendEvent only.
- The OS caps one SendInput call at roughly 5000 characters; the rest is dropped. Chunk long text.
- While SendInput runs, the script's own keyboard hook is removed, so SendInput generally cannot trigger
  the script's own hook hotkeys or InputHooks. SendEvent can.
- If another script has a low-level keyboard hook, SendInput silently becomes SendEvent.
- SendPlay is deprecated and may do nothing on Windows 11 or under UAC; prefer SendEvent.
- Explorer ignores some SendInput navigation keys such as `!{Left}`; use `SendEvent("!{Left}")`.
- `SendMode` and `SetKeyDelay` are per thread: a new hotkey thread starts from the defaults, so a change
  made in one hotkey does not leak into the next.

```ahk
#Requires AutoHotkey v2.1-alpha.30

; Slow, hardware-paced typing for stubborn targets, with the old settings restored
SendPaced(text, delay := 30) {
    oldDelay := A_KeyDelay
    oldDuration := A_KeyDuration
    SetKeyDelay(delay, delay)
    try {
        SendEvent(text)
    } finally {
        SetKeyDelay(oldDelay, oldDuration)
    }
}

; Chunk text to stay below the SendInput cap; SendText ignores special characters
SendLong(text, size := 4000) {
    pos := 1
    len := StrLen(text)
    while (pos <= len) {
        SendText(SubStr(text, pos, size))
        pos += size
    }
}

F9:: {
    SendPaced("Action{Enter}")
}
```

| Function | Use for |
|----------|---------|
| `Send` | Key sequences with `{Enter}`, `^c`, `!f` |
| `SendText` | Literal text; nothing is interpreted. Safe for `{`, `+`, `^`, `!` |
| `SendEvent` | Needs `SetKeyDelay` pacing, or must trigger the script's own hotkeys |
| `{Blind}` prefix | Keep currently held modifiers instead of releasing them (remaps) |
| `Click "100 200"` | Click; `Click 100 200` without quotes is the number `100200` |
| `Send "+{Click 100 200}"` | Shift-click: `Click()` itself leaves held modifiers down, `Send {Click}` releases them |

Click coordinates follow `CoordMode("Mouse", ...)`; the default is relative to the active window's client
area. See Module_GraphicsAndScreen.md.

`BlockInput("On")` discards the user's real input, can fail without administrator rights, and can leave
keys stuck if keys are down when it starts. Prefer SendInput, which postpones user input rather than
discarding it. If you must, wait for modifiers to be released first and always switch it back off.

## Key state and waiting

```ahk
#Requires AutoHotkey v2.1-alpha.30

ShowPalette() {
    ToolTip("palette")
    SetTimer(() => ToolTip(), -1000)
}

; Double tap of left Ctrl within 400 ms, with no timer
~LControl:: {
    if (A_PriorHotkey = A_ThisHotkey && A_TimeSincePriorHotkey < 400) {
        ShowPalette()
    }
    KeyWait("LControl")
}

; Hold detection: KeyWait with a timeout returns 0 if the key is still down
~F8:: {
    if !KeyWait("F8", "T0.4") {
        ToolTip("long press")
        SetTimer(() => ToolTip(), -800)
        KeyWait("F8")
    }
}

; Wait for a key press instead of polling GetKeyState in a loop
WaitForEnter() {
    return KeyWait("Enter", "D T5")
}
```

- `GetKeyState(key)` is the logical state, `"P"` the physical state (reliable only when the keyboard hook
  is installed, which any hook hotkey or InputHook does), `"T"` the toggle state of CapsLock, NumLock, ScrollLock.
- `KeyWait` options: `D` wait for down, `L` logical state, `T5` timeout in seconds. Without `D` it waits
  for release. Other threads (hotkeys, timers) keep running while it waits.
- The trailing `KeyWait("LControl")` in the double-tap hotkey stops auto-repeat from re-firing while the
  key is held.
- For tap, double-tap and hold bindings across many keys, use TapHoldManager (Module_TapHold.md).

## InputHook

`InputHook(Options, EndKeys, MatchList)` collects typed text. The text is hidden from the active window
unless the `V` option is used.

| Option | Meaning |
|--------|---------|
| `L5` | Maximum length (default 1023); ends with EndReason `Max` |
| `T3` | Timeout in seconds; EndReason `Timeout` |
| `V` | Visible: keystrokes still reach the window |
| `B` | Backspace is ignored instead of undoing |
| `C` | MatchList is case-sensitive |
| `*` | MatchList entries may match anywhere in the typed text |
| `I2` | Ignore input with a send level below 2 |

EndReason is `Max`, `Timeout`, `Match`, `EndKey`, or `Stopped`; it is empty while the input is running.
`ih.EndKey` is the normalised name (`Enter`, `Escape`), `ih.Match` the matched list item, and `ih.Wait()`
returns the EndReason. End keys use Send syntax; for Ctrl, Alt and Shift name the left or right key
(`{LControl}`).

```ahk
#Requires AutoHotkey v2.1-alpha.30

; Blocking prompt: returns the typed text, or "" when cancelled or timed out
AskLine(maxChars := 40, seconds := 8) {
    ih := InputHook("L" maxChars " T" seconds, "{Enter}{Esc}")
    ih.Start()
    reason := ih.Wait()
    if (reason = "Timeout" || reason = "Stopped") {
        return ""
    }
    if (reason = "EndKey" && ih.EndKey = "Escape") {
        return ""
    }
    return ih.Input
}

^!c:: {
    word := AskLine()
    if (word != "") {
        SendText("Captured: " word)
    }
}
```

For a non-blocking watcher use the callbacks. `OnEnd` receives the InputHook, `OnChar` gets the object
and the character, `OnKeyDown` gets the object plus the virtual key and scan code. A callback only fires
for a key after `KeyOpt` enabled notification (`N`) for it. Each callback runs as a new thread with default
settings. Binding `this` into the InputHook's callbacks creates a cycle, so clear them when done:

```ahk
#Requires AutoHotkey v2.1-alpha.30

class KeyWatcher {
    __New() {
        this.pressed := 0
        this.ih := InputHook("V L0", "{Esc}")
        this.ih.KeyOpt("{All}", "N")
        this.ih.OnKeyDown := this.KeyDown.Bind(this)
        this.ih.OnEnd := this.Ended.Bind(this)
    }

    Start() => this.ih.Start()

    Stop() {
        this.ih.Stop()
    }

    KeyDown(ih, vk, sc) {
        this.pressed += 1
        OutputDebug(Format("vk{:02X} sc{:03X}", vk, sc))
    }

    Ended(ih) {
        ih.OnKeyDown := ""
        ih.OnEnd := ""
        ToolTip("saw " this.pressed " keys")
        SetTimer(() => ToolTip(), -1500)
    }
}

watcher := KeyWatcher()
F7::watcher.Start()
```

Several InputHooks can run at once; the most recently started one sees keys first and can suppress them
for the ones below. Use `KeyOpt("{Tab}", "+S")` style per-key options (`E` end key, `I` ignore text,
`N` notify, `S` suppress, `V` visible, `-` removes) to shape one hook.

## Dynamic hotkeys in a class

Because hotkeys cannot be deleted, `Hotkey(name, callback)` keeps the callback alive for the rest of the
process. A `callback` that is `this.Method.Bind(this)` therefore keeps `this` alive too, and the
object's `__Delete` will not run when you drop your last reference. Measured on this build: an object that
registers a bound method with `Hotkey()` (and likewise one that passes a bound method to
`CallbackCreate`) never reaches `__Delete` when set to `""`. Give such classes an explicit `Dispose()`
and treat the instance as long-lived.

```ahk
#Requires AutoHotkey v2.1-alpha.30

class HotkeyGroup {
    __New() {
        this.binds := Map()
    }

    Add(keyName, callback) {
        if this.binds.Has(keyName) {
            this.Remove(keyName)
        }
        Hotkey(keyName, callback, "On")
        this.binds[keyName] := callback
    }

    Remove(keyName) {
        if !this.binds.Has(keyName) {
            return
        }
        Hotkey(keyName, "Off")
        this.binds.Delete(keyName)
    }

    Dispose() {
        for keyName in this.binds {
            Hotkey(keyName, "Off")
        }
        this.binds.Clear()
    }
}

class SnippetExpander {
    __New() {
        this.items := Map()
        this.items["sig"] := "Best regards,`nJohn Doe"
        this.items["addr"] := "12 Main Street"
        this.keys := HotkeyGroup()
        this.keys.Add("F8", this.Listen.Bind(this))
    }

    Listen(*) {
        ih := InputHook("L12 T4", "{Space}{Enter}{Esc}")
        ih.Start()
        ih.Wait()
        if (ih.EndReason = "EndKey" && ih.EndKey != "Escape" && this.items.Has(ih.Input)) {
            SendText(this.items[ih.Input])
        }
    }

    Dispose() {
        this.keys.Dispose()
    }
}

expander := SnippetExpander()
```

Register through a stable name (`Add` replaces an existing binding), keep the group in a global or static
property, and call `Dispose()` from `OnExit` when you need a clean teardown.

## Mistakes seen in generated code

| Mistake | Fix |
|---------|-----|
| `^l::` then statements then `return` | Braces: `^l:: { ... }` |
| `#IfWinActive ahk_exe x` | `#HotIf WinActive("ahk_exe x")` |
| `Hotkey, ^c, MyLabel` | `Hotkey("^c", MyFunction)` |
| `Hotkey("a", this.Method)` | `Hotkey("a", this.Method.Bind(this))` |
| `GetKeyState(CapsLock, T)` | `GetKeyState("CapsLock", "T")` |
| `KeyWait("Enter")` then `if !ErrorLevel` | `if KeyWait("Enter", "D T5")` |
| `SetKeyDelay(50)` with the default Send | Use `SendEvent`; SendInput ignores it |
| `HotIf((hk) => cond)` called repeatedly | Create the function once, pass the same object |
| Slow file or network call in `#HotIf` | Update a variable from a timer; test only the variable |
| Hotstring replacement with `!` or `{` typed as text | Add the `T` option or call `SendText` |
| Relying on `__Delete` to unregister a hotkey | Explicit `Dispose()` |

## See also

- Module_TapHold.md - tap, multi-tap and hold bindings.
- Module_GUI.md - Gui events, Hotkey controls, and `.Bind(this)` for control callbacks.
- Module_WindowAndControl.md - ControlSend and ControlClick for background windows.
- Module_GraphicsAndScreen.md - CoordMode for Click and MouseMove coordinates.
- Module_Errors.md - elevation limits on hotkeys and error handling around `Hotkey()`.

<!-- Adapted from hsinming/AutoHotkey-V2-vibe-coding-tools (no license file upstream); see THIRD-PARTY.md -->
