# Topic: SendInputEx - Custom SendInput Implementation

## Category

Snippet

## Overview

SendInputEx is an advanced function that implements a custom version of SendInput with precise control over input flags. This snippet demonstrates how to trick AutoHotkey's keyboard hook into treating artificial keypresses as physical ones, which can be useful for advanced automation scenarios where GetKeyState("key", "P") needs to report true for sent keys.

## Key Points

- Allows sending keystrokes that appear as "physical" to GetKeyState
- Uses a special input flag (0xFFC3D44E) that affects how AutoHotkey's keyboard hook processes the input
- Works by modifying the LLKHF_INJECTED flag that normally distinguishes between physical and artificial keystrokes
- Should be used with caution as it relies on undocumented behavior

## Syntax and Parameters

```cpp
SendInputEx(KeyArray)
```

- `KeyArray`: An array of objects containing scancode and event information
  - Each object should have `{sc: scancode, event: "Down" or "Up"}`

## Code Examples

```cpp
; Example showing how to make artificial keystrokes appear as physical
InstallKeybdHook(1, 1)  ; Install keyboard hook with physical key tracking

; Create an array with one keystroke (A key down)
KeyArray := [{sc: GetKeySC("a"), event: "Down"}]

; Send the keystroke
SendInputEx(KeyArray)

; Check both logical and physical state
MsgBox "Logical state: " GetKeyState("a") "`n" 
      . "Physical state: " GetKeyState("a", "P")

; Comparison with normal SendInput
SendInput("{a down}")
MsgBox "Logical state: " GetKeyState("a") "`n" 
      . "Physical state: " GetKeyState("a", "P")

; Implementation of SendInputEx
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

- This function uses a special value (0xFFC3D44E) in the extraInfo field of the INPUT structure
- When AutoHotkey's keyboard hook sees this value, it treats the keystroke as physical even though it's artificial
- This is undocumented behavior that might change in future AutoHotkey versions
- The GetKeyState function with the "P" flag normally distinguishes between physical keystrokes and those sent via SendInput/SendEvent
- This technique circumvents that distinction, which can be useful for complex automation scenarios
- Using this approach might interact unexpectedly with other scripts that rely on accurate physical keystroke detection

## Related AHK Concepts

- SendInput - Standard input simulation function
- GetKeyState - Determines key state (logical or physical)
- InstallKeybdHook - Enables keyboard hook functionality
- DllCall - For direct Windows API access
- Buffer - Used to create memory structures for API calls

## Tags

#AutoHotkey #SendInput #KeyboardHook #GetKeyState #Advanced #WindowsAPI #InputSimulation