# Topic: EventEmitter Class

## Category

Class

## Overview

The EventEmitter class provides a robust foundation for implementing event-driven programming in AutoHotkey v2. It allows objects to emit named events that cause functions (listeners) to be called. This pattern is widely used in GUI applications, asynchronous operations, and any scenario where loose coupling between components is desired.

## Key Points

- Simplifies event handling by providing on(), once(), off(), and emit() methods
- Supports multiple listeners for the same event
- Implements one-time listeners with once()
- Can pass arbitrary arguments to event handlers
- Enables chaining of event emitter methods

## Syntax and Parameters

```cpp
class EventEmitter {
    ; Private property to store event listeners
    _events := Map()
    
    ; Add a listener for an event
    on(eventName, listener) {
        if (!this._events.Has(eventName))
            this._events[eventName] := []
        
        this._events[eventName].Push({
            callback: listener,
            once: false
        })
        
        return this  ; For method chaining
    }
    
    ; Add a one-time listener for an event
    once(eventName, listener) {
        if (!this._events.Has(eventName))
            this._events[eventName] := []
        
        this._events[eventName].Push({
            callback: listener,
            once: true
        })
        
        return this  ; For method chaining
    }
    
    ; Remove a listener for an event
    off(eventName, listener := "") {
        ; If no specific listener provided, remove all listeners for this event
        if (listener == "") {
            this._events.Delete(eventName)
            return this
        }
        
        ; If this event doesn't exist, return
        if (!this._events.Has(eventName))
            return this
        
        ; Find and remove the specific listener
        listeners := this._events[eventName]
        for i, listenerObj in listeners {
            if (listenerObj.callback == listener) {
                listeners.RemoveAt(i)
                break
            }
        }
        
        ; Clean up empty listener arrays
        if (listeners.Length == 0)
            this._events.Delete(eventName)
        
        return this  ; For method chaining
    }
    
    ; Emit an event, calling all listeners
    emit(eventName, params*) {
        ; If this event doesn't exist, return false
        if (!this._events.Has(eventName))
            return false
        
        listeners := this._events[eventName].Clone()
        toRemove := []
        
        ; Call each listener
        for i, listenerObj in listeners {
            ; Call the listener with the provided parameters
            listenerObj.callback(params*)
            
            ; If this is a once listener, mark it for removal
            if (listenerObj.once)
                toRemove.Push(i)
        }
        
        ; Remove all once listeners
        for i in toRemove {
            this._events[eventName].RemoveAt(i)
        }
        
        ; Clean up empty listener arrays
        if (this._events[eventName].Length == 0)
            this._events.Delete(eventName)
        
        return true  ; Event was handled
    }
    
    ; Get all listeners for an event
    listeners(eventName) {
        if (!this._events.Has(eventName))
            return []
        
        result := []
        for i, listenerObj in this._events[eventName]
            result.Push(listenerObj.callback)
        
        return result
    }
    
    ; Get the number of listeners for an event
    listenerCount(eventName) {
        if (!this._events.Has(eventName))
            return 0
        
        return this._events[eventName].Length
    }
    
    ; Remove all listeners
    removeAllListeners(eventName := "") {
        ; If an event name is provided, remove all listeners for that event
        if (eventName != "")
            this._events.Delete(eventName)
        else  ; Otherwise, remove all listeners for all events
            this._events := Map()
        
        return this  ; For method chaining
    }
}
```

## Code Examples

```cpp
; Example 1: Basic EventEmitter usage
myEmitter := EventEmitter()

; Add a listener for the "data" event
myEmitter.on("data", (data) => {
    MsgBox("Received data: " data)
})

; Emit a "data" event
myEmitter.emit("data", "Hello, world!")  ; Shows MsgBox with "Received data: Hello, world!"

; Example 2: File reader with events
class FileReader extends EventEmitter {
    filePath := ""
    
    __New(filePath) {
        this.filePath := filePath
    }
    
    readAsync() {
        ; Simulate asynchronous file reading with a timer
        SetTimer(() => this._processFile(), -100)  ; 100ms delay
        return this
    }
    
    _processFile() {
        try {
            ; Try to read the file
            fileContent := FileRead(this.filePath)
            
            ; Emit a "data" event with the file content
            this.emit("data", fileContent)
            
            ; Emit a "end" event when done
            this.emit("end")
        } catch as err {
            ; Emit an "error" event if there's an error
            this.emit("error", err)
        }
    }
}

; Usage
reader := FileReader("example.txt")

; Set up event handlers
reader.on("data", (content) => {
    OutputDebug("File content: " content)
})
.once("end", () => {
    OutputDebug("Done reading file")
})
.on("error", (err) => {
    OutputDebug("Error reading file: " err.Message)
})

; Start reading the file
reader.readAsync()
```

## Implementation Notes

- The EventEmitter pattern is particularly useful for asynchronous operations in AutoHotkey
- Be aware that listeners are stored as references, which can prevent garbage collection if not properly removed
- For complex applications, consider implementing a wildcard event system (e.g., "*" to listen to all events)
- The above implementation does not handle priority ordering of listeners; add an optional priority parameter if needed
- Memory management: remember to remove listeners when they are no longer needed to prevent memory leaks
- For debugging purposes, you might want to add a `listEvents()` method that returns all registered event names

## Related AHK Concepts

- [Observer Pattern](../Patterns/observer-pattern.md)
- [Closures in AHK v2](../Patterns/closures-in-ahk-v2.md)
- [Method Binding and Context](../Concepts/method-binding-and-context.md)
- [First Class Functions](../Concepts/First_Class_Functions.md)

## Tags

#AutoHotkey #OOP #Class #EventEmitter #Events #AsyncProgramming #Callbacks