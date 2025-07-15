# Topic: Timer-Based Window Detection

## Category

Snippet

## Overview

Timer-based window detection is a straightforward method for monitoring window creation and destruction using AutoHotkey's SetTimer function. While not as efficient as event-driven approaches, this method is simple to implement and works reliably across various Windows versions. It periodically checks for the existence of specified windows and detects changes in their state.

## Key Points

- Simple to implement with minimal code
- Works with any version of Windows and any application
- No reliance on external libraries or complex Windows API functions
- Can be adapted to monitor multiple windows and window types
- Main drawback is inefficiency due to constant polling

## Syntax and Parameters

```cpp
; Basic Timer Setup
SetTimer(CheckWindowFunction, Interval)

; Function to check window state
CheckWindowFunction() {
    static lastState := !!WinExist("WindowTitle")
    currentState := !!WinExist("WindowTitle")
    
    if (lastState != currentState) {
        ; State changed, perform actions
        lastState := currentState
    }
}
```

- `CheckWindowFunction`: Function to call periodically to check window state
- `Interval`: Time in milliseconds between checks (e.g., 250)
- `WindowTitle`: Title, class, or other criteria to identify the window

## Code Examples

```cpp
; Example 1: Basic monitoring of a single window
#Requires AutoHotkey v2

SetTimer(CheckNotepad, 250)  ; Check every 250ms
Persistent()  ; Keep script running

CheckNotepad() {
    static lastExist := !!WinExist("ahk_exe notepad.exe")
    currentExist := !!WinExist("ahk_exe notepad.exe")
    
    if (lastExist = currentExist)  ; No change
        return
        
    if (lastExist := !lastExist)  ; State toggled, update lastExist
        ToolTip("Notepad opened")
    else
        ToolTip("Notepad closed")
        
    SetTimer(() => ToolTip(), -3000)  ; Clear tooltip after 3 seconds
}

; Example 2: Monitoring multiple windows
#Requires AutoHotkey v2

SetTimer(CheckMultipleWindows, 250)
Persistent()

CheckMultipleWindows() {
    static lastNotepadExist := !!WinExist("ahk_exe notepad.exe")
    static lastCalculatorExist := !!WinExist("Calculator")
    
    currentNotepadExist := !!WinExist("ahk_exe notepad.exe")
    currentCalculatorExist := !!WinExist("Calculator")
    
    ; Check Notepad state
    if (lastNotepadExist != currentNotepadExist) {
        if (currentNotepadExist)
            ToolTip("Notepad opened")
        else
            ToolTip("Notepad closed")
            
        lastNotepadExist := currentNotepadExist
        SetTimer(() => ToolTip(), -3000)
    }
    
    ; Check Calculator state
    if (lastCalculatorExist != currentCalculatorExist) {
        if (currentCalculatorExist)
            ToolTip("Calculator opened")
        else
            ToolTip("Calculator closed")
            
        lastCalculatorExist := currentCalculatorExist
        SetTimer(() => ToolTip(), -3000)
    }
}

; Example 3: Comprehensive monitoring of all windows
#Requires AutoHotkey v2

SetTimer(TrackAllWindows, 500)
Persistent()

TrackAllWindows() {
    static lastOpenWindows := ListOpenWindows()
    currentOpenWindows := ListOpenWindows()
    
    ; Find windows that have been created or destroyed
    for hwnd in SortedArrayDiff([currentOpenWindows*], [lastOpenWindows*]) {
        if !lastOpenWindows.Has(hwnd) {
            ; New window created
            info := currentOpenWindows[hwnd]
            ToolTip("Window created: " info.title)
        } else {
            ; Window closed
            info := lastOpenWindows[hwnd]
            ToolTip("Window closed: " info.title)
        }
        SetTimer(() => ToolTip(), -3000)
    }
    
    ; Update reference list
    lastOpenWindows := currentOpenWindows
}

; Helper function to list all open windows
ListOpenWindows() {
    openWindows := Map()
    for hwnd in WinGetList() {
        try {
            openWindows[hwnd] := {
                title: WinGetTitle(hwnd), 
                class: WinGetClass(hwnd), 
                processName: WinGetProcessName(hwnd)
            }
        }
    }
    return openWindows
}

; Helper function to find differences between arrays
SortedArrayDiff(arr1, arr2) {
    i := 1, j := 1, diff := []
    n := arr1.Length, m := arr2.Length
    
    while (i <= n && j <= m) {
        if arr1[i] < arr2[j]
            diff.Push(arr1[i++])
        else if arr2[j] < arr1[i]
            diff.Push(arr2[j++])
        else
            i++, j++
    }
    
    ; Add remaining elements
    while i <= n
        diff.Push(arr1[i++])
    while j <= m
        diff.Push(arr2[j++])
        
    return diff
}
```

## Implementation Notes

### Basic Implementation Strategy

1. **State Tracking**:
   - Use static variables to remember the last known state
   - Compare current state to last known state to detect changes
   - Update the last known state after detecting a change

2. **Timer Interval Selection**:
   - Lower intervals (e.g., 100ms) provide faster detection but use more CPU
   - Higher intervals (e.g., 500ms) use less CPU but might miss brief windows
   - 250-500ms is typically a good balance for most scenarios

3. **Multiple Window Monitoring**:
   - For a few specific windows, use separate state variables
   - For comprehensive monitoring, use Maps to track all windows

### Advanced Implementation Techniques

1. **Efficient Difference Detection**:
   - Use Maps to track window handles and properties
   - Implement array difference algorithms to detect changes
   - Consider using Set objects for faster lookups with large numbers of windows

2. **Filtering Options**:
   - Filter windows by process name to monitor specific applications
   - Filter by window class to monitor specific window types
   - Filter by window title for more specific targeting

3. **Resource Management**:
   - Consider pausing the timer when not needed
   - Free resources when tracking is no longer required
   - Use adaptive intervals based on system activity

### Performance Considerations

1. **CPU Usage**:
   - Timer-based detection constantly uses CPU resources
   - Lower timer intervals increase CPU usage
   - Consider impact on battery life for laptop systems

2. **Scaling Limitations**:
   - Performance degrades when tracking many windows
   - Each check requires multiple WinGet* calls
   - Consider using more efficient event-driven methods for high-scale monitoring

3. **Optimization Strategies**:
   - Only check windows of interest rather than all windows
   - Use efficient data structures (Maps, Sets) for lookups
   - Minimize operations in the timer callback
   - Consider increasing interval when system is idle

### Comparison with Other Methods

- **Advantages over WinWait**: Non-blocking, can monitor multiple windows simultaneously
- **Advantages over hook-based methods**: Simpler implementation, no external dependencies
- **Disadvantages vs. event-driven methods**: Higher resource usage, may miss brief windows

## Related AHK Concepts

- SetTimer - For periodic function execution
- WinExist - To check if windows exist
- WinGetList - To enumerate all open windows
- WinGetTitle/WinGetClass/WinGetProcessName - To retrieve window properties
- Map - For tracking window information
- Static variables - For maintaining state between timer calls

## Tags

#AutoHotkey #WindowDetection #SetTimer #WinExist #WindowMonitoring #PollingMethod