# Topic: Windows Keyboard Hook Mechanics

## Category

Concept

## Overview

Windows keyboard hooks are a core mechanism that allow applications to intercept and process keyboard events system-wide. Understanding how keyboard hooks work is essential for developing robust AutoHotkey scripts, particularly when dealing with input simulation, hotkeys, and scenarios involving multiple scripts or applications that process keyboard input.

## Key Points

- Keyboard hooks are installed using the Windows SetWindowsHookEx API function
- Hooks form a chain, with the most recently installed hook processing events first
- Each hook can allow events to pass through, block them, or explicitly let them through
- AutoHotkey uses keyboard hooks for hotstrings, #HotIf conditions, and certain types of hotkeys
- Windows monitors hook performance and may remove hooks that process events too slowly

## Syntax and Parameters

```cpp
; Install keyboard hook explicitly
InstallKeybdHook(true)  ; Install with standard configuration
InstallKeybdHook(true, true)  ; Install with physical key tracking

; Check hook status (v2.1+ only)
if (A_KeybdHookInstalled)
    MsgBox "A keyboard hook is installed"

if (A_KeybdHookInstalled > 1)
    MsgBox "Multiple AHK keyboard hooks are installed"
```

## Code Examples

```cpp
; Example showing various ways to trigger keyboard hook installation
#Requires AutoHotkey v2

; Explicitly install the hook
InstallKeybdHook(true)

; Hotstring (automatically installs hook)
::btw::by the way

; Hotkey with $ modifier (force-installs hook)
$a::MsgBox "A pressed"

; Hotkey with context sensitivity (installs hook)
#HotIf WinActive("Notepad")
b::MsgBox "B pressed in Notepad"
#HotIf

; InputLevel higher than 0 (installs hook)
#InputLevel 1
c::MsgBox "C pressed with elevated input level"

; Check whether hook is installed in v2.1+
MsgBox "Hooks installed: " A_KeybdHookInstalled
```

## Implementation Notes

- When a key is pressed, Windows calls each hook in the chain, starting with the most recently installed
- Hook callback functions have three possible outcomes:
  * Block the keystroke (no further hooks called, key not processed)
  * Pass the event to the next hook in the chain
  * Explicitly let the keystroke through (no further hooks called, key processed)

- Windows can remove hooks if they timeout (processing too slow)
  * The timeout value is stored in LowLevelHooksTimeout registry key
  * Located at HKEY_CURRENT_USER\Control Panel\Desktop

- Programs cannot detect hooks installed by other applications
  * AutoHotkey v2.1+ can detect hooks from other AutoHotkey scripts
  * No way to detect hooks from non-AutoHotkey applications

- Installing/removing hooks is nearly instantaneous
- Multiple hooks from different applications compound processing time for each keystroke
- Heavy reliance on keyboard hooks can impact system performance and keystroke latency

## Related AHK Concepts

- SendInput/SendEvent - Input methods affected by hooks
- GetKeyState - Affected by hook status for physical key detection
- #HotIf directive - Requires hook for context-sensitive hotkeys
- Hotstrings - Always implemented using hooks
- InputHook - Uses a keyboard hook to monitor keystrokes

## Tags

#AutoHotkey #KeyboardHook #WindowsAPI #SystemEvents #InputProcessing #Hotkeys