# Topic: SendInput and Keyboard Hooks

## Category

Concept

## Overview

SendInput is AutoHotkey's default sending mode, offering fast and uninterruptible keystroke simulation. However, its behavior changes significantly when keyboard hooks are present. Understanding the interaction between SendInput and keyboard hooks is crucial for reliable script execution, especially when multiple scripts or applications are running.

## Key Points

- SendInput offers uninterruptible input simulation but only when no keyboard hooks are installed
- When other AutoHotkey scripts have keyboard hooks installed, SendInput automatically reverts to SendEvent with SetKeyDelay(-1, 0)
- SendInput cannot trigger hotstrings or hook-based hotkeys in the running script, while SendEvent with SendLevel > 0 can
- Keyboard hooks are installed automatically for hotstrings, custom modifiers, and other special hotkey configurations
- In v2.1+, you can detect external AutoHotkey keyboard hooks with the A_KeybdHookInstalled variable

## Syntax and Parameters

```cpp
; Default send mode is SendInput in AHK v2
Send "Text to send"  ; Uses SendInput by default

; Explicitly specify sending mode
SendMode "Input"  ; Set to use SendInput
SendMode "Event"  ; Set to use SendEvent

; Check for external keyboard hooks (v2.1+ only)
if (A_KeybdHookInstalled > 1)
    MsgBox "Another script has a keyboard hook installed"
```

## Code Examples

```cpp
; Example: SendInput vs SendEvent with hotstrings
#Requires AutoHotkey v2

; This won't trigger the hotstring (uses SendInput)
Send "abc "

; This will trigger the hotstring (uses SendEvent)
SendMode "Event"
SendLevel 1
Send "abc "

::abc::123  ; Hotstring definition

; Example: Ensuring keys don't leak when using SendInput
$z:: {
    ; Use SendEvent instead of SendInput for more reliable behavior
    SendMode "Event"
    SetKeyDelay(-1, 0)  ; Minimal delay
    
    While GetKeyState("z", "P") {
        Send "{n Down}"
        Sleep 200
        Send "{n Up}"
    }
}
```

## Implementation Notes

- A keyboard hook is automatically installed by AutoHotkey in the following cases:
  * When using hotstrings
  * When using 1:1 key remapping
  * When using hotkeys with #HotIf conditions
  * When using hotkeys with modifiers ~, * or $
  * When using hotkeys with the Up option (key release)
  * When explicitly calling InstallKeybdHook(1)
  * When setting #InputLevel over 0
  * When using the InputHook function
  * When using SetCapsLockState/SetNumLockState/SetScrollLockState functions

- Keyboard hooks from all programs form a chain, with the most recently installed hook being called first
- SendInput uninstalls and reinstalls AutoHotkey's keyboard hook during execution, which can allow keys to "leak" if pressed during this brief window
- AutoHotkey cannot detect keyboard hooks installed by non-AutoHotkey applications

- For consistent behavior, consider using SendMode "Event" with SetKeyDelay(-1, 0) when:
  * Multiple AutoHotkey scripts are running
  * Your script requires keyboard hooks (hotstrings, etc.)
  * You experience key "leakage" during SendInput operations

## Related AHK Concepts

- GetKeyState - Determines whether a key is pressed (affected by hooks)
- SetKeyDelay - Controls timing between keystrokes when using SendEvent
- SendLevel/InputLevel - Controls which hotkeys can be triggered by sent keystrokes
- InputHook - Creates a context for monitoring and responding to user keystrokes
- InstallKeybdHook - Explicitly installs the keyboard hook

## Tags

#AutoHotkey #SendInput #SendEvent #KeyboardHooks #InputSimulation #Hotkeys #Hotstrings