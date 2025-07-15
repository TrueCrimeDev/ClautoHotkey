# Topic: GetKeyState Internals and "Physical" Key Detection

## Category

Concept

## Overview

The GetKeyState function in AutoHotkey provides information about key states, distinguishing between "logical" state (what the OS believes) and "physical" state (whether the user is actually pressing the key). Understanding the internals of how this function determines physical key states is essential for advanced input handling, particularly when working with simulated keystrokes.

## Key Points

- GetKeyState can report "logical" or "physical" key states with different meanings
- "Physical" state detection is a misnomer as AHK cannot directly detect truly physical keypresses
- AHK uses keyboard hooks to track which keystrokes have the LLKHF_INJECTED flag to infer "physical" state
- When no keyboard hook is active, "physical" state is merely the current logical state as reported by GetAsyncKeyState
- Artificial keystrokes from SendInput/SendEvent are normally detected as non-physical

## Syntax and Parameters

```cpp
GetKeyState(KeyName, "P")  ; Check "physical" state
GetKeyState(KeyName)       ; Check logical state
```

- `KeyName`: The name or virtual key code of the key to check
- `"P"`: Optional parameter to check the "physical" state instead of logical state

## Code Examples

```cpp
; Basic usage example showing the difference between logical and physical state
#Requires AutoHotkey v2

; Ensure keyboard hook is installed
InstallKeybdHook(1, 1)  ; Second parameter enables physical key tracking

; Send a keypress artificially
SendInput("{a down}")

; Check both states
MsgBox "Logical state: " GetKeyState("a") "`n"
      . "Physical state: " GetKeyState("a", "P")
; Output: Logical state: 1
;         Physical state: 0

; Example of the custom SendInputEx function that can fake physical keypresses
InstallKeybdHook(1, 1)
KeyArray := [{sc: GetKeySC("a"), event: "Down"}]
SendInputEx(KeyArray)
MsgBox "Logical state: " GetKeyState("a") "`n"
      . "Physical state: " GetKeyState("a", "P")
; Output: Logical state: 1
;         Physical state: 1

; Implementation of SendInputEx function
SendInputEx(KeyArray) {
   static INPUT_KEYBOARD := 1, KEYEVENTF_KEYUP := 2, KEYEVENTF_SCANCODE := 8, InputSize := 16 + A_PtrSize*3
   INPUTS := Buffer(InputSize * KeyArray.Length, 0)
   offset := 0
   for k, v in KeyArray {
    NumPut("int", INPUT_KEYBOARD, "int", 0, "ushort", 0, "ushort", v.sc & 0xFF, "int", (v.event = "Up" ? KEYEVENTF_KEYUP : 0) | KEYEVENTF_SCANCODE | (v.sc >> 8), "int", 0, "int", 0, "int", 0xFFC3D44E, INPUTS, offset)
    offset += InputSize
   }
   DllCall("SendInput", "UInt", KeyArray.Length, "Ptr", INPUTS, "Int", InputSize)
}
```

## Implementation Notes

- When no keyboard hook is installed:
  * Logical state uses Windows GetKeyState API
  * "Physical" state uses Windows GetAsyncKeyState API
  * These usually return the same result in this scenario

- When a keyboard hook is installed:
  * AHK monitors all keystrokes passing through the hook
  * It checks for the LLKHF_INJECTED flag which indicates artificial keystrokes
  * If the flag is not set, AHK updates an internal array tracking "physical" key states
  * GetKeyState("key", "P") then checks this internal array

- Limitations:
  * If the user starts a script with a key already pressed, its "physical" state won't be detected
  * If the hook is temporarily removed, some "physical" key events might be missed
  * This system is an approximation, not true physical key detection

- Advanced usage:
  * It's possible to trick the keyboard hook by using a special flag (0xFFC3D44E)
  * This makes artificial keystrokes appear as "physical" to GetKeyState
  * This is undocumented behavior that might change in future versions

## Related AHK Concepts

- SendInput/SendEvent - Input simulation that sets the LLKHF_INJECTED flag
- InstallKeybdHook - Required for "physical" key tracking
- KeyWait - Affected by the same mechanics for physical key detection
- InputHook - Uses similar key state tracking mechanics

## Tags

#AutoHotkey #GetKeyState #KeyboardHook #InputSimulation #PhysicalKeys #WindowsAPI