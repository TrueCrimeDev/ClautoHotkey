# Topic: ConsoleSend Function

## Category

Method

## Overview

ConsoleSend is a function that allows sending text directly to a console's input stream. This enables programmatic interaction with command-line interfaces and console applications without relying on window focus or simulated keystrokes, making it more reliable for automation scenarios.

## Key Points

- Sends text directly to a console's input stream using Windows API functions
- Works by attaching to a console application identified by process ID
- Simulates key press and release events for each character in the provided text
- Returns the console window handle for further manipulation

## Syntax and Parameters

```cpp
ConsoleSend(text, WinTitle?, WinText?, ExcludeTitle?, ExcludeText?)
```

- `text`: The text to send to the console
- `WinTitle?`: Window title criteria (optional)
- `WinText?`: Window text criteria (optional)
- `ExcludeTitle?`: Exclude windows with this title (optional)
- `ExcludeText?`: Exclude windows with this text (optional)

## Code Examples

```cpp
; Send a command to cmd.exe
ConsoleSend("echo Hello World", "ahk_class ConsoleWindowClass")

; Example of handling the returned window handle
hwnd := ConsoleSend("dir /b", "cmd.exe")
WinActivate(hwnd)  ; Activate the console window after sending command

; Chain commands
ConsoleSend("cd C:\Projects`ndir`n", "Command Prompt")
```

## Implementation Notes

- Requires administrator privileges if sending to an elevated console window
- Uses Windows API functions: AttachConsole, CreateFile, WriteConsoleInput, GetConsoleWindow, and FreeConsole
- Uses structured error handling with try/finally to ensure proper cleanup
- Console attachment is exclusive; a script can only be attached to one console at a time
- Characters are sent one at a time, simulating both key down and key up events
- The function properly detaches from the console and cleans up resources even if an error occurs

## Related AHK Concepts

- WinGetPID - Used to obtain the process ID for console attachment
- DllCall - Used to interact with Windows API functions
- Buffer - Used to create the INPUT_RECORD structure for console input
- Exception handling - Uses try/finally for cleanup

## Tags

#AutoHotkey #ConsoleInteraction #WindowsAPI #Automation #InputSimulation