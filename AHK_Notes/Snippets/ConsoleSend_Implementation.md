# Topic: ConsoleSend Implementation

## Category

Snippet

## Overview

This snippet provides the complete implementation of the ConsoleSend function for AutoHotkey v2. The function enables direct text input to console applications through Windows API calls rather than simulated keystrokes, making it more reliable for automation tasks.

## Key Points

- Full implementation with proper error handling using try/finally
- Utilizes Windows API functions for console interaction
- Contains improvements suggested by lexikos (AutoHotkey developer)
- Returns the console window handle for further manipulation

## Syntax and Parameters

```cpp
ConsoleSend(text, WinTitle?, WinText?, ExcludeTitle?, ExcludeText?)
```

## Code Examples

```cpp
; Sends text to a console's input stream.
ConsoleSend(text, WinTitle?, WinText?, ExcludeTitle?, ExcludeText?) {
   pid := WinGetPID(WinTitle?, WinText?, ExcludeTitle?, ExcludeText?)

   if !DllCall("AttachConsole", "uint", pid)
      throw Error("External console could not be attached to script.")

   try {
      hConIn := DllCall("CreateFile", "str", "CONIN$", "uint", 0xC0000000
               , "uint", 0x3, "ptr", 0, "uint", 0x3, "uint", 0, "ptr", 0, "ptr")
      if hConIn = -1
         throw OSError()

      ir := Buffer(24, 0)             ; ir := new INPUT_RECORD
      NumPut("ushort", 1, ir, 0)      ; ir.EventType := KEY_EVENT
      NumPut("ushort", 1, ir, 8)      ; ir.KeyEvent.wRepeatCount := 1
      ; wVirtualKeyCode, wVirtualScanCode and dwControlKeyState are not needed,
      ; so are left at the default value of zero.

      Loop Parse, text ; for each character in text
      {
         NumPut("ushort", Ord(A_LoopField), ir, 14)

         NumPut("int", True, ir, 4)  ; ir.KeyEvent.bKeyDown := true
         ConsoleSendWrite(ir)

         NumPut("int", False, ir, 4) ; ir.KeyEvent.bKeyDown := false
         ConsoleSendWrite(ir)
      }

      return DllCall("GetConsoleWindow", "ptr") ; Returns the hwnd for caller's use
   }
   catch
      throw
   finally {
      if (hConIn!=-1)
         DllCall("CloseHandle", "ptr", hConIn)
      DllCall("FreeConsole") ; Detach from WinTitle's console.
   }

   ConsoleSendWrite(ir) {
      if ! DllCall("WriteConsoleInput", "ptr", hConIn, "ptr", ir, "uint", 1, "uint*", 0)
         throw OSError()
   }
}
```

## Implementation Notes

- The `OSError()` function is used to create error objects with detailed Windows API error information
- `Buffer` is used in AHK v2 instead of `VarSetCapacity` from v1
- Resource cleanup is guaranteed through the try/finally construct
- The function returns the console window handle, allowing the caller to perform additional operations like window activation

## Related AHK Concepts

- Error handling with try/catch/finally blocks
- Windows API interaction through DllCall
- Console control functions
- Process and window management

## Tags

#AutoHotkey #Snippet #ConsoleInteraction #WindowsAPI #V2