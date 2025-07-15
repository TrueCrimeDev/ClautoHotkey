# Topic: Deep Cloning Objects

## Category

Snippet

## Overview

This snippet demonstrates practical ways to use the DeepClone method to create independent copies of complex objects. Deep cloning is essential when you need to duplicate objects without maintaining references to the original, which is particularly important when working with configuration objects, when preserving state, or when implementing undo/redo functionality.

## Key Points

- Creates fully independent copies of objects including all nested properties
- Handles circular references correctly
- Preserves object types and inheritance chains
- Offers options for handling objects with required constructor parameters
- Can limit cloning depth for performance optimization
- Essential for state management, undo/redo, and configuration templates

## Implementation

### Setup: Including Required Files

```cpp
; Include the DeepClone method and its dependency
#Include GetObjectFromString.ahk
#Include Object.Prototype.DeepClone.ahk  ; For basic deep cloning
; OR
#Include Object.Prototype.DeepCloneA.ahk ; For deep cloning with constructor parameters
```

### Basic Deep Cloning

```cpp
; Create a configuration object with nested properties
config := {
    app: {
        name: "MyApp",
        version: "1.0.0",
        settings: {
            theme: "dark",
            fontSize: 12,
            windowSize: {width: 800, height: 600}
        }
    },
    user: {
        profile: {
            name: "John Doe",
            email: "john@example.com"
        },
        preferences: Map(
            "notifications", true,
            "sounds", false,
            "autoSave", true
        )
    },
    recent: ["file1.txt", "file2.txt", "file3.txt"]
}

; Create a deep clone of the configuration
configCopy := config.DeepClone()

; Now modify the copy without affecting the original
configCopy.app.settings.theme := "light"
configCopy.app.settings.windowSize.width := 1024
configCopy.user.preferences["autoSave"] := false
configCopy.recent.Push("file4.txt")

; Original remains unchanged
MsgBox("Original theme: " config.app.settings.theme)  ; Still "dark"
MsgBox("Original width: " config.app.settings.windowSize.width)  ; Still 800
MsgBox("Original autoSave: " config.user.preferences["autoSave"])  ; Still true
MsgBox("Original recent count: " config.recent.Length)  ; Still 3
```

### Cloning Objects with Constructor Parameters

```cpp
; Define a class with required constructor parameters
class UserProfile {
    __New(name, email, role) {
        this.name := name
        this.email := email
        this.role := role
        this.createdAt := A_Now
        this.settings := {
            darkMode: true,
            language: "en",
            notifications: true
        }
    }
    
    IsAdmin() {
        return this.role = "admin"
    }
    
    GetDisplayName() {
        return this.name " (" this.role ")"
    }
}

; Create an instance of the class
admin := UserProfile("Admin User", "admin@example.com", "admin")

; Create a constructor parameter map
constructorParams := Map(
    "UserProfile", ["Cloned User", "clone@example.com", "user"]
)

; Create a deep clone with new constructor parameters
userClone := admin.DeepCloneA(constructorParams)

; The clone is a fully functional UserProfile instance with new values
MsgBox(userClone.GetDisplayName())  ; "Cloned User (user)"
MsgBox(userClone.IsAdmin())  ; false (role is now "user")

; But it keeps the settings from the original
MsgBox(userClone.settings.darkMode)  ; true
```

### Practical Example: Implementing Undo/Redo

```cpp
class UndoRedoManager {
    __New() {
        this.undoStack := []
        this.redoStack := []
        this.currentState := {}
    }
    
    ; Capture the current state
    Capture(state) {
        ; Push a deep clone of the current state to the undo stack
        this.undoStack.Push(this.currentState.DeepClone())
        ; Set the new current state
        this.currentState := state.DeepClone()
        ; Clear the redo stack since we've taken a new action
        this.redoStack := []
    }
    
    ; Undo the last action
    Undo() {
        if (this.undoStack.Length < 1)
            return false
            
        ; Save current state to redo stack
        this.redoStack.Push(this.currentState.DeepClone())
        ; Restore previous state
        this.currentState := this.undoStack.Pop()
        return true
    }
    
    ; Redo a previously undone action
    Redo() {
        if (this.redoStack.Length < 1)
            return false
            
        ; Save current state to undo stack
        this.undoStack.Push(this.currentState.DeepClone())
        ; Restore next state
        this.currentState := this.redoStack.Pop()
        return true
    }
    
    ; Get the current state
    GetState() {
        return this.currentState.DeepClone()
    }
}

; Usage example with a drawing application state
drawingApp := {
    canvas: {
        width: 800,
        height: 600,
        backgroundColor: "#FFFFFF"
    },
    shapes: [
        {type: "rectangle", x: 10, y: 10, width: 100, height: 50, color: "#FF0000"},
        {type: "circle", x: 200, y: 150, radius: 30, color: "#0000FF"}
    ],
    selectedShapeIndex: 1,
    zoom: 1.0
}

; Create an undo/redo manager
undoManager := UndoRedoManager()
undoManager.Capture(drawingApp)

; Make some changes to the drawing
drawingApp.zoom := 1.5
drawingApp.shapes.Push({type: "triangle", x: 300, y: 200, points: [[0,0], [50,0], [25,50]], color: "#00FF00"})
drawingApp.selectedShapeIndex := 2

; Capture the new state
undoManager.Capture(drawingApp)

; Make more changes
drawingApp.canvas.backgroundColor := "#F0F0F0"
drawingApp.shapes[1].color := "#FF00FF"

; Capture again
undoManager.Capture(drawingApp)

; Undo the last change
if (undoManager.Undo()) {
    ; Restore the application state
    drawingApp := undoManager.GetState()
    ; Now drawingApp has the previous state (zoom: 1.5, 3 shapes, selected: 2)
}

; Undo again
if (undoManager.Undo()) {
    ; Restore the application state
    drawingApp := undoManager.GetState()
    ; Now drawingApp has the original state (zoom: 1.0, 2 shapes, selected: 1)
}

; Redo a change
if (undoManager.Redo()) {
    ; Restore the next state
    drawingApp := undoManager.GetState()
    ; Back to (zoom: 1.5, 3 shapes, selected: 2)
}
```

### Handling Circular References

```cpp
; Create an object with circular references
nodeA := {name: "Node A", children: []}
nodeB := {name: "Node B", children: []}
nodeC := {name: "Node C", children: []}

; Create circular structure
nodeA.children.Push(nodeB, nodeC)
nodeB.children.Push(nodeA, nodeC)
nodeC.children.Push(nodeA, nodeB)
nodeA.parent := nodeA  ; Self-reference

; DeepClone handles this correctly
clonedNodeA := nodeA.DeepClone()

; The cloned structure maintains its internal references
MsgBox(clonedNodeA.name)  ; "Node A"
MsgBox(clonedNodeA.children[1].name)  ; "Node B"
MsgBox(clonedNodeA.children[1].children[1].name)  ; "Node C"
MsgBox(clonedNodeA.children[1].children[1].children[1].name)  ; "Node B" (circular)

; But doesn't reference the original objects
MsgBox(clonedNodeA.children[1] == nodeB)  ; false
```

## Implementation Notes

- For better performance, consider using a limited depth with DeepClone when dealing with very large objects
- Be cautious with memory usage when deep cloning large objects, especially when maintaining undo/redo history
- DeepClone correctly handles AHK's built-in types like Arrays, Maps, and Objects
- The DeepCloneA variant should be used when working with objects that have required constructor parameters
- DeepClone correctly copies property descriptors, including getters, setters, and callable methods
- For custom classes, ensure they can be instantiated without parameters or use DeepCloneA

## Related AHK Concepts

- Prototype-Based OOP
- Object References and Pointers
- State Management
- Configuration Handling
- Undo/Redo Patterns
- Object Serialization
- Circular References

## Tags

#AutoHotkey #Snippet #DeepClone #ObjectCopy #UndoRedo #StateManagement #CircularReferences