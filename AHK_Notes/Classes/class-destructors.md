# Topic: Class Destructors in AHK v2

## Category

Class

## Overview

Destructors in AutoHotkey v2 are special methods that are automatically called when an object is being destroyed, typically when it goes out of scope or when all references to it are removed. They provide an essential mechanism for releasing resources, cleaning up memory, and performing finalization tasks. Understanding destructors is crucial for managing resources effectively and preventing memory leaks in AutoHotkey applications.

## Key Points

- Destructors are defined using the `__Delete()` method in a class
- They are automatically called when an object is being garbage collected
- Ideal for cleaning up resources like file handles, GUI controls, or COM objects
- Can be called manually using `ObjRelease()` to force cleanup
- Cannot have parameters and do not return a value
- Execute in an unpredictable order during script termination

## Syntax and Parameters

```cpp
class MyClass {
    __Delete() {
        ; Cleanup code here
    }
}
```

## Code Examples

```cpp
#Requires AutoHotkey v2.0.18+

; Basic example showing destructor operation
class ResourceManager {
    ResourcePath := ""
    IsOpen := false
    
    __New(resourcePath) {
        this.ResourcePath := resourcePath
        this.OpenResource()
    }
    
    OpenResource() {
        ; Simulation of resource acquisition
        this.IsOpen := true
        MsgBox("Resource opened: " this.ResourcePath)
    }
    
    CloseResource() {
        if (this.IsOpen) {
            ; Simulation of resource release
            this.IsOpen := false
            MsgBox("Resource closed: " this.ResourcePath)
        }
    }
    
    __Delete() {
        this.CloseResource()
        MsgBox("ResourceManager destroyed for: " this.ResourcePath)
    }
}

; Example with a file handle
class FileHandler {
    FilePath := ""
    FileHandle := 0
    
    __New(filePath, flags := "r") {
        this.FilePath := filePath
        
        try {
            this.FileHandle := FileOpen(filePath, flags)
            if (!this.FileHandle)
                throw Error("Failed to open file: " filePath)
        } catch as err {
            MsgBox("Error opening file: " err.Message)
            throw err
        }
    }
    
    ReadLine() {
        if (this.FileHandle)
            return this.FileHandle.ReadLine()
        return ""
    }
    
    WriteLine(text) {
        if (this.FileHandle)
            this.FileHandle.WriteLine(text)
    }
    
    __Delete() {
        if (this.FileHandle) {
            this.FileHandle.Close()
            MsgBox("File handle closed for: " this.FilePath)
        }
    }
}

; Example with COM objects
class ExcelHandler {
    Excel := ""
    Workbook := ""
    
    __New(filePath := "") {
        ; Create Excel instance
        try {
            this.Excel := ComObject("Excel.Application")
            this.Excel.Visible := true
            
            if (filePath)
                this.Workbook := this.Excel.Workbooks.Open(filePath)
            else
                this.Workbook := this.Excel.Workbooks.Add()
        } catch as err {
            MsgBox("Error initializing Excel: " err.Message)
            throw err
        }
    }
    
    WriteCell(row, col, value) {
        if (this.Excel && this.Workbook)
            this.Excel.ActiveSheet.Cells(row, col).Value := value
    }
    
    Save(filePath := "") {
        if (this.Workbook) {
            if (filePath)
                this.Workbook.SaveAs(filePath)
            else
                this.Workbook.Save()
        }
    }
    
    __Delete() {
        ; Release COM objects in reverse order of creation
        if (this.Workbook) {
            try {
                this.Workbook.Close(false)  ; Don't save changes
                ComObjRelease(this.Workbook)
                this.Workbook := ""
            } catch {
                ; Suppress errors during cleanup
            }
        }
        
        if (this.Excel) {
            try {
                this.Excel.Quit()
                ComObjRelease(this.Excel)
                this.Excel := ""
            } catch {
                ; Suppress errors during cleanup
            }
        }
        
        MsgBox("Excel resources released")
    }
}

; Test the destructors
TestDestructors() {
    ; Local scope creates and destroys objects
    LocalScopeTest()
    
    ; Explicit release
    resource := ResourceManager("ExplicitResource")
    ObjRelease(resource)  ; Force immediate destruction
    
    ; Test with file
    file := FileHandler("C:\temp\test.txt", "w")
    file.WriteLine("Test line")
    ; Let destructor handle file closing
    
    ; Clean up by clearing reference
    excel := ExcelHandler()
    excel.WriteCell(1, 1, "Hello World")
    excel := ""  ; Clear reference, triggering destructor
    
    MsgBox("Test completed")
}

LocalScopeTest() {
    ; Object will be destroyed when this function returns
    resource := ResourceManager("LocalResource")
    MsgBox("LocalScopeTest ending")
}

; Run the test
TestDestructors()
```

## Implementation Notes

- Destructors are not guaranteed to be called at a specific time, as they depend on the garbage collector
- Objects referenced in global variables may not be destroyed until script termination
- Circular references can prevent garbage collection; break them manually if needed
- Use `ObjRelease()` to force immediate destruction when necessary
- Always ensure cleanup code in destructors is error-safe using try/catch blocks
- COM objects should be released in reverse order of creation to avoid reference issues
- Resources like file handles should be checked for validity before closing them
- During script termination, the order of destructor calls is not guaranteed
- Avoid complex operations in destructors that might depend on other objects
- For critical resources, consider implementing a manual `Close()` method in addition to the destructor
- `OnExit` callbacks can be used to ensure cleanup for resources that must be released before script termination

## Related AHK Concepts

- [Class Constructors](./class-constructor-methods.md)
- [Object Lifecycle](../Concepts/object-lifecycle.md)
- [Memory Management](../Concepts/memory-management.md)
- [COM Object Handling](../Concepts/com-object-handling.md)
- [Resource Acquisition Is Initialization (RAII)](../Patterns/raii-pattern.md)

## Tags

#AutoHotkey #OOP #Class #Destructor #ResourceManagement #GarbageCollection #v2