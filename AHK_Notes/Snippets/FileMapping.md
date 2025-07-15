# Topic: FileMapping Class for Inter-Process Communication

## Category

Snippet

## Overview

The FileMapping class provides a way to share data between different AutoHotkey processes using Windows shared memory. Instead of writing to physical files, it creates memory-backed file mappings in RAM, resulting in much faster data transfer. This implementation allows scripts to easily read and write strings or structured data to a named shared memory location.

## Key Points

- Uses Windows file mapping objects for high-speed inter-process data sharing
- Allows sharing strings and Buffer objects between scripts
- Shared memory persists as long as at least one handle is open
- Much faster than disk files or registry for data transfer
- Requires coordination (mutex/semaphore) for safe concurrent access

## Syntax and Parameters

```cpp
; Create a new file mapping or open an existing one
mapping := FileMapping(szName, dwDesiredAccess, flProtect, dwSize)

; Write data to the mapping
mapping.Write(data, offset)

; Read data from the mapping
data := mapping.Read(buffer, offset, size)

; Close the mapping and release resources
mapping.Close()
```

- `szName`: Optional name for the mapping (prepend with "Local\" for session-local)
- `dwDesiredAccess`: Access rights (default: FILE_MAP_ALL_ACCESS = 0xF001F)
- `flProtect`: Protection flags (default: PAGE_READWRITE = 0x4)
- `dwSize`: Size of the mapping in bytes (default: 10000)
- `data`: String or Buffer to write
- `offset`: Byte offset into the mapping (default: 0)
- `buffer`: Optional Buffer to receive data (if omitted, returns as string)
- `size`: Maximum bytes to read (defaults to remaining buffer size)

## Code Examples

```cpp
; Example 1: Writer script creates shared memory and writes data
#Requires AutoHotkey v2

; Create named file mapping with default settings
mapping := FileMapping("Local\MySharedData")

; Write a string to the shared memory
mapping.Write("This is data shared between scripts")

; Keep the mapping open until script exits
Persistent()

; Example 2: Reader script opens the mapping and reads data
#Requires AutoHotkey v2

; Open the existing file mapping
mapping := FileMapping("Local\MySharedData")

; Read the data as a string
sharedData := mapping.Read()
MsgBox "Data read from shared memory: " sharedData

; Close the mapping when done
mapping.Close()

; Example 3: Sharing structured data using Buffer
#Requires AutoHotkey v2

; Create or open the mapping
mapping := FileMapping("Local\MyStructuredData")

; Create a buffer with structured data
buffer := Buffer(16)
NumPut("Int", 42, "Double", 3.14159, "Int", 100, buffer)

; Write the buffer to shared memory
mapping.Write(buffer)

; In another script, read the structured data
mapping := FileMapping("Local\MyStructuredData")
readBuffer := Buffer(16)
mapping.Read(readBuffer)

; Extract values from the buffer
value1 := NumGet(readBuffer, 0, "Int")
value2 := NumGet(readBuffer, 4, "Double") 
value3 := NumGet(readBuffer, 12, "Int")
```

## Implementation Notes

```cpp
Class FileMapping {
    __New(szName?, dwDesiredAccess := 0xF001F, flProtect := 0x4, dwSize := 10000) {
        static INVALID_HANDLE_VALUE := -1
        this.BUF_SIZE := dwSize, this.szName := szName ?? ""
        if !(this.hMapFile := DllCall("OpenFileMapping", "Ptr", dwDesiredAccess, "Int", 0, "Ptr", IsSet(szName) ? StrPtr(szName) : 0)) {
            ; OpenFileMapping Failed - file mapping object doesn't exist - that means we have to create it
            if !(this.hMapFile := DllCall("CreateFileMapping", "Ptr", INVALID_HANDLE_VALUE, "Ptr", 0, "Int", flProtect, "Int", 0, "Int", dwSize, "Str", szName)) ; CreateFileMapping Failed
                throw Error("Unable to create or open the file mapping", -1)
        }
        if !(this.pBuf := DllCall("MapViewOfFile", "Ptr", this.hMapFile, "Int", dwDesiredAccess, "Int", 0, "Int", 0, "Int", dwSize))	; MapViewOfFile Failed
            throw Error("Unable to map view of file")
    }

    Write(data, offset := 0) {
        if (this.pBuf) {
            if data is String
                StrPut(data, this.pBuf+offset, this.BUF_SIZE-offset)
            else if data is Buffer
                DllCall("RtlCopyMemory", "ptr", this.pBuf+offset, "ptr", data, "int", Min(data.Size, this.BUF_SIZE-offset))
            else
                throw TypeError("The data type can be a string or a Buffer object")
        } else
            throw Error("File already closed!")
    }

    Read(buffer?, offset := 0, size?) => IsSet(buffer) 
        ? DllCall("RtlCopyMemory", "ptr", buffer, "ptr", this.pBuf+offset, "int", Min(buffer.size, this.BUF_SIZE-offset, size ?? this.BUF_SIZE-offset)) 
        : StrGet(this.pBuf+offset)

    Close() {
        DllCall("UnmapViewOfFile", "Ptr", this.pBuf), DllCall("CloseHandle", "Ptr", this.hMapFile)
        this.szName := "", this.BUF_SIZE := "", this.hMapFile := "", this.pBuf := ""
    }

    __Delete() => this.Close()
}
```

Key implementation details:
- Uses `CreateFileMapping` with `INVALID_HANDLE_VALUE` to create memory-backed mapping
- Falls back to `OpenFileMapping` if the mapping already exists
- Maps the file into the process address space with `MapViewOfFile`
- Supports both string data (via `StrPut`/`StrGet`) and binary data (via `RtlCopyMemory`)
- Handles proper cleanup through `Close()` method and `__Delete()` meta-function
- Uses fat arrow syntax for concise method definitions
- Returns the read data directly for convenience or writes to provided buffer

Important considerations:
1. For concurrent access, use a mutex to prevent data corruption
2. The default size (10000 bytes) may need adjustment for larger data
3. For session-local mappings, prefix name with "Local\"
4. Keep at least one script's handle open to preserve the data
5. Buffer objects must be properly sized before reading into them

## Related AHK Concepts

- DllCall - Used to interface with Windows memory mapping functions
- Buffer - For creating and manipulating structured memory
- Mutex/Semaphore - For coordinating access to shared memory
- StrPut/StrGet - For string conversion to/from raw memory
- NumPut/NumGet - For structured data handling in buffers

## Tags

#AutoHotkey #SharedMemory #IPC #FileMapping #WindowsAPI #Buffer #InterProcessCommunication