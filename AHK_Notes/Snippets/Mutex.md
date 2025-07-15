# Topic: Mutex Class for Synchronization

## Category

Snippet

## Overview

The Mutex class provides a wrapper for Windows mutex objects, which are used for synchronization between different processes. Mutexes (mutual exclusion objects) ensure that only one process can access a resource at a time, preventing race conditions and coordinating access to shared resources like files, shared memory, or global state.

## Key Points

- Synchronizes access to shared resources between different scripts
- Ensures that only one script can access a protected resource at a time 
- Can block script execution until a resource becomes available
- Named mutexes are accessible across different scripts
- Proper release of mutexes is crucial to prevent deadlocks

## Syntax and Parameters

```cpp
; Create or open a mutex
mtx := Mutex(name, initialOwner, securityAttributes)

; Try to lock the mutex (wait for access)
result := mtx.Lock(timeout)

; Release the mutex when done
mtx.Release()
```

- `name`: Optional name for the mutex (prepend with "Local\" for session-local)
- `initialOwner`: Whether calling thread should own mutex initially (default: false)
- `securityAttributes`: Optional security settings (default: 0)
- `timeout`: Time in milliseconds to wait for lock (default: infinite)
- `result`: 0=success, 0x80=abandoned, 0x120=timeout, 0xFFFFFFFF=failed

## Code Examples

```cpp
; Example 1: Basic mutex usage to protect a critical section
#Requires AutoHotkey v2.0

; Create or open a named mutex
mtx := Mutex("Local\MyAppMutex")

; Try to acquire the mutex with a 5-second timeout
if (mtx.Lock(5000) = 0) {
    ; Successfully locked, access protected resource
    MsgBox "Mutex acquired, accessing shared resource..."
    
    ; Simulate work with the resource
    Sleep 2000
    
    ; Release the mutex when done
    mtx.Release()
    MsgBox "Mutex released"
} else {
    MsgBox "Could not acquire mutex within timeout period"
}

; Example 2: Coordinating access between scripts
; Script 1: Blocks access to a resource
#Requires AutoHotkey v2.0

mtx := Mutex("Local\SharedResourceMutex")
if (mtx.Lock() = 0) {
    MsgBox "Resource locked. Close this dialog to release."
} else {
    MsgBox "Failed to lock resource"
}
mtx.Release()

; Script 2: Waits for resource to be available
#Requires AutoHotkey v2.0

mtx := Mutex("Local\SharedResourceMutex")
MsgBox "Waiting for resource to be available..."
if (mtx.Lock() = 0) {
    mtx.Release()
    MsgBox "Resource is now available!"
}
```

## Implementation Notes

```cpp
class Mutex {
    /**
     * Creates a new Mutex, or opens an existing one. The mutex is destroyed once all handles to
     * it are closed.
     * @param name Optional. The name can start with "Local\" to be session-local, or "Global\" to be 
     * available system-wide.
     * @param initialOwner Optional. If this value is TRUE and the caller created the mutex, the 
     * calling thread obtains initial ownership of the mutex object.
     * @param securityAttributes Optional. A pointer to a SECURITY_ATTRIBUTES structure.
     */
    __New(name?, initialOwner := 0, securityAttributes := 0) {
        if !(this.ptr := DllCall("CreateMutex", "ptr", securityAttributes, "int", !!initialOwner, "ptr", IsSet(name) ? StrPtr(name) : 0))
            throw Error("Unable to create or open the mutex", -1)
    }
    
    /**
     * Tries to lock (or signal) the mutex within the timeout period.
     * @param timeout The timeout period in milliseconds (default is infinite wait)
     * @returns {Integer} 0 = successful, 0x80 = abandoned, 0x120 = timeout, 0xFFFFFFFF = failed
     */
    Lock(timeout:=0xFFFFFFFF) => DllCall("WaitForSingleObject", "ptr", this, "int", timeout, "int")
    
    ; Releases the mutex (resets it back to the unsignaled state)
    Release() => DllCall("ReleaseMutex", "ptr", this)
    
    __Delete() => DllCall("CloseHandle", "ptr", this)
}
```

Key implementation details:
- Uses Windows API functions: CreateMutex, WaitForSingleObject, ReleaseMutex
- The class operator overloads implicit conversion to pointer for DllCall
- Uses fat arrow syntax for concise method definitions
- Automatically closes the mutex handle when the object is destroyed

Important considerations:
1. Mutexes are binary (locked/unlocked) - for counting, use semaphores instead
2. Always release a mutex after use to prevent deadlocks
3. Set a reasonable timeout to prevent infinite waiting
4. Use descriptive mutex names to avoid conflicts with other applications
5. Prefix mutex names with "Local\" for session-local scope or "Global\" for system-wide scope
6. Be careful with mutex abandonment (process termination while holding a mutex)
7. Since AHK is single-threaded, mutexes only synchronize between scripts, not within the same script

Example usage patterns:
- Protecting access to shared files or registry keys
- Synchronizing access to named shared memory
- Ensuring only one instance of a script runs a specific operation
- Coordinating concurrent operations between multiple scripts

## Related AHK Concepts

- DllCall - Used to interface with Windows synchronization functions
- Semaphore - Similar to mutex but with counting capability
- Named shared memory - Often protected by mutexes for concurrent access
- FileOpen with sharing flags - Alternative for file-specific locking
- WaitForSingleObject/WaitForMultipleObjects - For waiting on multiple synchronization objects

## Tags

#AutoHotkey #Mutex #Synchronization #IPC #WindowsAPI #CriticalSection #ProcessCoordination