---
name: ahk-input
description: >
  Hotkeys, hotstrings, sending input, and window and control automation for AHK v2 — #HotIf,
  Hotkey() and Hotstring(), InputHook, Send modes and limits, key state, WinTitle criteria, WinWait
  patterns, ControlSend and control messages, window groups, hidden windows, and WinEvent hooks.
  TRIGGER when: user says "hotkey", "hotstring", "#HotIf", "InputHook", "Send", "SendInput",
  "ControlSend", "ControlClick", "WinActivate", "WinWait", "WinMove", "ahk_exe", "ahk_class",
  "window title", "find a window", "move a window", "always on top", "window group", "key state",
  "GetKeyState", "remap a key", "press a key combination", "automate another app's controls".
  Examples: "make F1 do X only in Notepad", "type text into a background window", "wait for a dialog
  then click OK", "remap CapsLock", "tile two windows"
---

# AHK v2 Input, Hotkeys, Windows and Controls

## How to use

1. Hotkeys, hotstrings, `#HotIf`, `Send` modes, `InputHook`, key state: `${CLAUDE_PLUGIN_ROOT}/Modules/Module_InputAndHotkeys.md`
2. WinTitle criteria, waits, moving and sizing, control commands, window groups, WinEvent hooks: `${CLAUDE_PLUGIN_ROOT}/Modules/Module_WindowAndControl.md`
3. Building the GUI the hotkey opens: `/ahk-gui`. Timers and debounce: `/ahk-async`.

## Critical rules

- Give every `WinWait` a timeout and check the return value.
- Use the integer HWND directly as a WinTitle. Do not build `"ahk_id " . hwnd` strings.
- `~`, `*`, `Up` and `&` hotkeys always use the keyboard hook. `$` adds nothing for them.
- A hotkey class registers a bound callback that keeps the object alive, so `__Delete` never unregisters it. Provide an explicit `Dispose()`.
- `SendInput` truncates long strings. Chunk anything over a few thousand characters.
- `SetTitleMatchMode` is per thread and defaults to 2 (contains). `DetectHiddenWindows` is per thread and off by default.
