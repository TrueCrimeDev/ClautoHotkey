# Topic: Inter-Process Communication (IPC)

## Category

Concept

## Overview

Inter-Process Communication (IPC) allows different AutoHotkey scripts to communicate with each other. This concept is crucial for coordinating actions between multiple scripts, sharing data, and synchronizing access to resources. Various methods exist, each with different strengths and weaknesses regarding speed, reliability, and complexity.

## Key Points

- Multiple methods exist for communication between AutoHotkey scripts
- Communication methods vary in speed, reliability, and complexity
- Some methods are better for one-way communication, others for two-way exchanges
- Some methods allow sharing data, while others are primarily for synchronization
- Mutexes and semaphores can coordinate access to shared resources

## Syntax and Parameters

```cpp
; Method depends on the specific IPC technique chosen

; Example: SendMessage to communicate with another script
DetectHiddenWindows True
MsgNum := DllCall("RegisterWindowMessage", "Str", "CustomMessageName")
SendMessage(MsgNum, wParam, lParam,, targetHwnd)

; Example: Using a mutex for synchronization
mtx := Mutex("Local\MyMutex")
if (mtx.Lock() = 0)  ; Successfully locked
    ; Access shared resource here...
mtx.Release()  ; Release when done
```

## Code Examples

```cpp
; Example 1: Using SendMessage for two-way communication
; Receiver script (run first)
#Requires AutoHotkey v2.0

MsgNum := DllCall("RegisterWindowMessage", "Str", "MyCustomMessage")
OnMessage(MsgNum, MessageReceived)
Persistent()

MessageReceived(wParam, lParam, msg, hwnd) {
    ; Process received data
    return 42  ; Return a value to the sender
}

; Sender script
#Requires AutoHotkey v2.0
DetectHiddenWindows True

targetHwnd := WinExist("ReceiverScript.ahk ahk_class AutoHotkey")
MsgNum := DllCall("RegisterWindowMessage", "Str", "MyCustomMessage")
result := SendMessage(MsgNum, 123, 456,, targetHwnd)
MsgBox "Response received: " result

; Example 2: Using named shared memory for data sharing
; Writer script
#Requires AutoHotkey v2.0

mapping := FileMapping("Local\MySharedMemory")
mapping.Write("Data to be shared between scripts")
Persistent()

; Reader script
#Requires AutoHotkey v2.0

mapping := FileMapping("Local\MySharedMemory")
sharedData := mapping.Read()
MsgBox "Read from shared memory: " sharedData
```

## Implementation Notes

### Available IPC Methods:

1. **File-based** - Simple but slow; persistent across reboots
   - Writing to shared files with proper locking
   - Can use FileOpen with specific sharing modes to coordinate access

2. **Registry** - Similar to file-based but with system registry
   - Good for one-way broadcasting of information
   - No built-in locking mechanism for concurrent access

3. **Clipboard** - Easy access but unreliable
   - Can be interfered with by other applications or user actions
   - Useful for quick, non-critical data sharing

4. **PostMessage** - Fast, event-driven, one-way communication
   - Can broadcast to all windows or target specific ones
   - Limited to sending two 32/64-bit values (wParam and lParam)

5. **SendMessage** - Similar to PostMessage but with return value
   - Blocks sender until receiver processes the message
   - Use WM_COPYDATA for sending larger data structures

6. **ObjRegisterActive** - Share objects between scripts
   - Fast memory-based access
   - Needs synchronization for concurrent access (e.g., mutex)

7. **Mutex** - Used for synchronization rather than data sharing
   - Ensures only one script accesses a resource at a time
   - "Mutual exclusion" between processes

8. **Semaphore** - Like mutex but with a counter
   - Can limit resource usage to a set number of scripts
   - More flexible than mutex for managing access

9. **Named shared memory** - Fast RAM-based data sharing
   - Uses Windows file mapping objects without actual files
   - Much faster than disk-based files for data sharing

10. **Named pipes** - Good for streaming data
    - Can be used for local or network communication
    - Supports multiple clients and two-way communication

11. **Sockets** - Network communication
    - Can communicate between computers
    - Uses TCP/IP or other protocols

12. **GWLP_USERDATA** - Store data in window properties
    - Simple for small amounts of data
    - Can use atoms for string association

### Choosing an IPC Method:

- For simple one-way messaging: PostMessage
- For two-way communication: SendMessage
- For sharing larger data: WM_COPYDATA or named shared memory
- For synchronizing access to shared resources: mutex or semaphore
- For network communication: sockets or named pipes

## Related AHK Concepts

- DllCall - Used to interface with Windows API functions for many IPC methods
- OnMessage - For receiving and processing window messages
- WinExist/WinActive - For finding target script windows
- Class implementation - For creating wrapper classes like FileMapping
- Buffer objects - For working with structured memory in many IPC methods

## Tags

#AutoHotkey #IPC #InterProcessCommunication #Scripting #WindowsAPI #Mutex #Synchronization #SendMessage #SharedMemory