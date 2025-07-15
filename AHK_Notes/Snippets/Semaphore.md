# Topic: Semaphore Class for Process Coordination

## Category

Snippet

## Overview

The Semaphore class provides a wrapper for Windows semaphore objects, which are synchronization primitives used to control access to resources. Unlike mutexes, semaphores maintain a count that can be greater than one, allowing a specified number of processes to access a resource simultaneously. This makes them ideal for limiting concurrent access to resources with fixed capacity.

## Key Points

- Controls access to limited resources shared between multiple scripts
- Allows a specified number of processes to access resources concurrently
- Maintains a count that decreases when acquired and increases when released
- Named semaphores can be accessed by different scripts
- Useful for rate limiting and managing pools of resources

## Syntax and Parameters

```cpp
; Create a new semaphore with maximum count and initial count
sem := Semaphore(initialCount, maximumCount, name, securityAttributes)

; Open an existing semaphore by name
sem := Semaphore(name, desiredAccess, inheritHandle)

; Wait to acquire the semaphore (decrease count)
result := sem.Wait(timeout)

; Release the semaphore (increase count)
prevCount := sem.Release(count)
```

- `initialCount`: Starting count for new semaphores
- `maximumCount`: Maximum possible count
- `name`: Optional semaphore name (prepend with "Local\" for session-local)
- `securityAttributes`: Optional security settings
- `desiredAccess`: Access rights for opening existing semaphore (default: SEMAPHORE_MODIFY_STATE)
- `timeout`: Time in milliseconds to wait (default: infinite)
- `count`: How much to increase the count when releasing (default: 1)
- `result`: 0=success, 0x80=abandoned, 0x120=timeout, 0xFFFFFFFF=failed
- `prevCount`: Previous semaphore count before release

## Code Examples

```cpp
; Example 1: Limiting concurrent instances of a script
#Requires AutoHotkey v2
#SingleInstance Off

; Create a semaphore with max count of 2 and initial count of 2
sem := Semaphore(2, 2, "Local\MySemaphore")

; Try to decrease the count by 1 (non-blocking)
if sem.Wait(0) = 0 {
    ; Success - semaphore acquired
    MsgBox "This instance got access (maximum 2 allowed)"
    
    ; Ensure semaphore is released when script exits
    OnExit((*) => sem.Release())
    
    Persistent()  ; Keep script running
} else {
    MsgBox "Too many instances already running"
    ExitApp
}

; Example 2: Using semaphore as a resource pool
#Requires AutoHotkey v2

; Create a pool of 3 resources
sem := Semaphore(3, 3, "Local\ResourcePool")

; Function to use a resource
UseResource(resourceName, duration) {
    sem := Semaphore("Local\ResourcePool")
    
    ; Wait up to 5 seconds to acquire a resource
    if (sem.Wait(5000) != 0) {
        MsgBox "Failed to acquire " resourceName " - timed out"
        return
    }
    
    ; Resource acquired
    MsgBox resourceName " acquired from pool"
    
    ; Simulate using the resource
    Sleep duration
    
    ; Release the resource back to the pool
    prevCount := sem.Release()
    MsgBox resourceName " released back to pool (now " prevCount+1 " available)"
}

; Start several resource users
SetTimer(() => UseResource("Resource A", 2000), -100)
SetTimer(() => UseResource("Resource B", 3000), -200)
SetTimer(() => UseResource("Resource C", 1000), -300)
SetTimer(() => UseResource("Resource D", 1500), -400)
SetTimer(() => UseResource("Resource E", 2500), -500)
```

## Implementation Notes

```cpp
class Semaphore {
    /**
     * Creates a new semaphore or opens an existing one. The semaphore is destroyed once all handles
     * to it are closed.
     * 
     * CreateSemaphore argument list:
     * @param initialCount The initial count for the semaphore object. This value must be greater 
     * than or equal to zero and less than or equal to maximumCount.
     * @param maximumCount The maximum count for the semaphore object. This value must be greater than zero.
     * @param name Optional. The name of the semaphore object.
     * @param securityAttributes Optional. A pointer to a SECURITY_ATTRIBUTES structure.
     * @returns {Object}
     * 
     * OpenSemaphore argument list:
     * @param name The name of the semaphore object.
     * @param desiredAccess Optional: The desired access right to the semaphore object. Default is
     * SEMAPHORE_MODIFY_STATE = 0x0002
     * @param inheritHandle Optional: If this value is 1, processes created by this process will inherit the handle.
     * @returns {Object}
     */
    __New(initialCount, maximumCount?, name?, securityAttributes := 0) {
        if IsSet(initialCount) && IsSet(maximumCount) && IsInteger(initialCount) && IsInteger(maximumCount) {
            if !(this.ptr := DllCall("CreateSemaphore", "ptr", securityAttributes, "int", initialCount, "int", maximumCount, "ptr", IsSet(name) ? StrPtr(name) : 0))
                throw Error("Unable to create the semaphore", -1)
        } else if IsSet(initialCount) && initialCount is String {
            if !(this.ptr := DllCall("OpenSemaphore", "int", maximumCount ?? 0x0002, "int", !!(name ?? 0), "ptr", IsSet(initialCount) ? StrPtr(initialCount) : 0))
                throw Error("Unable to open the semaphore", -1)
        } else
            throw ValueError("Invalid parameter list!", -1)
    }
    
    /**
     * Tries to decrease the semaphore count by 1 within the timeout period.
     * @param timeout The timeout period in milliseconds (default is infinite wait)
     * @returns {Integer} 0 = successful, 0x80 = abandoned, 0x120 = timeout, 0xFFFFFFFF = failed
     */
    Wait(timeout:=0xFFFFFFFF) => DllCall("WaitForSingleObject", "ptr", this, "int", timeout, "int")
    
    /**
     * Increases the count of the specified semaphore object by a specified amount.
     * @param count Optional. How much to increase the count, default is 1.
     * @param out Is set to the result of the DllCall
     * @returns {number} The previous semaphore count
     */
    Release(count := 1, &out?) => (out := DllCall("ReleaseSemaphore", "ptr", this, "int", count, "int*", &prevCount:=0), prevCount)
    
    __Delete() => DllCall("CloseHandle", "ptr", this)
}
```

Key implementation details:
- Uses Windows API functions: CreateSemaphore, OpenSemaphore, WaitForSingleObject, ReleaseSemaphore
- The class has two constructor signatures:
  1. Create a new semaphore with initial and maximum counts
  2. Open an existing semaphore by name
- Uses fat arrow syntax for concise method definitions
- Automatically closes the semaphore handle when the object is destroyed
- The class operator overloads implicit conversion to pointer for DllCall

Important considerations:
1. Initial count must be less than or equal to maximum count
2. Using a non-zero timeout prevents indefinite waiting if the resource is unavailable
3. For local-only semaphores, prefix the name with "Local\"
4. Release the semaphore when done to prevent resource exhaustion
5. The Release method increases the count by the specified amount (default 1)
6. Unlike mutexes, the thread/process that decrements a semaphore doesn't "own" it
7. For proper cleanup, ensure semaphores are released when scripts terminate

Example usage patterns:
- Limiting the number of concurrent script instances
- Managing pools of shared resources
- Rate limiting operations across multiple scripts
- Coordinating access to resources with fixed capacity

## Related AHK Concepts

- DllCall - Used to interface with Windows synchronization functions
- Mutex - Similar to semaphore but with binary state (locked/unlocked)
- OnExit - Useful for releasing semaphores when scripts terminate
- SetTimer - Often used in conjunction with semaphores for resource scheduling
- WaitForSingleObject/WaitForMultipleObjects - For waiting on multiple synchronization objects

## Tags

#AutoHotkey #Semaphore #Synchronization #IPC #WindowsAPI #ResourceManagement #ProcessCoordination