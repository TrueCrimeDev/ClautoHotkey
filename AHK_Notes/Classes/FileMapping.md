# Topic: FileMapping Class for Shared Memory

## Category

Class

## Overview

The FileMapping class provides a high-performance mechanism for sharing data between AutoHotkey scripts using Windows memory-mapped files. Instead of writing to disk, data is stored in RAM, making read and write operations much faster than traditional file I/O. This class encapsulates the Windows API calls necessary to create, access, and manage shared memory regions.

## Key Points

- Provides high-speed data sharing between scripts through shared memory
- Data persists only while at least one handle to the mapping remains open
- Can store and retrieve strings or binary data via Buffer objects
- Named file mappings can be accessed by any process with appropriate permissions
- Significantly faster than file-based or registry-based data sharing

## Syntax and Parameters

```cpp
; Creating a new file mapping or accessing an existing one
mapping := FileMapping(szName?, dwDesiredAccess := 0xF001F, flProtect := 0x4, dwSize := 10000)

; Writing data to the mapping
mapping.Write(data, offset := 0)

; Reading data from the mapping
data := mapping.Read()
mapping.Read(buffer, offset := 0, size?)

; Closing the mapping explicitly
mapping.Close()
```

- `szName`: Optional. Name of the file mapping object. Using "Local\" prefix makes it session-specific.
- `dwDesiredAccess`: Access rights for the mapping, default is FILE_MAP_ALL_ACCESS (0xF001F)
- `flProtect`: Protection flags, default is PAGE_READWRITE (0x4)
- `dwSize`: Size of the mapping in bytes, default is 10,000
- `data`: String or Buffer to write to the mapping
- `offset`: Byte offset within the mapping for read/write operations
- `buffer`: Optional Buffer object to receive data when reading
- `size`: Optional size limit when reading to a buffer

## Code Examples

```cpp
; Example 1: Creating a mapping and writing data
#Requires AutoHotkey v2

; Create a new file mapping or open existing one
mapping := FileMapping("Local\AHKExampleMapping")

; Write string data to the mapping
mapping.Write("This is shared data from script #1")

; Wait for user to run the second script
MsgBox "Data has been written to shared memory.`nRun the reader script now."

; Example 2: Reading data from an existing mapping
#Requires AutoHotkey v2

; Open the existing file mapping
mapping := FileMapping("Local\AHKExampleMapping")

; Read the shared data as a string
sharedData := mapping.Read()
MsgBox "Read from shared memory: " sharedData

; Example 3: Using a buffer for binary data
#Requires AutoHotkey v2

; Create mapping
mapping := FileMapping("Local\AHKBinaryData", , , 1024)

; Create and fill a buffer with binary data
sourceBuffer := Buffer(100)
Loop 100
    NumPut("UChar", A_Index, sourceBuffer, A_Index-1)

; Write the buffer to shared memory
mapping.Write(sourceBuffer)

; In another script, read to a new buffer
destBuffer := Buffer(100)
mapping.Read(destBuffer)

; Process the binary data...
```

## Implementation Notes

- The class automatically manages Windows API calls to create, map, and unmap the shared memory
- Memory is only allocated when the first script creates the mapping
- The mapping remains available until all handles to it are closed
- Using `Close()` or letting the object be garbage collected will release resources
- When working with strings, remember that they are stored with their null terminator
- Data is shared directly in memory - no serialization/deserialization is needed
- Consider using a mutex when multiple scripts need to write to the mapping

- Error situations to handle:
  * Opening a non-existent mapping will create a new one (may not be expected)
  * If the mapping size is too small for the data, writes will be truncated
  * Improper access rights may cause operations to fail
  * Reading/writing past the end of the mapping can crash the script

- For larger data structures:
  * Binary data must be properly structured for direct memory access
  * Complex objects should be serialized (e.g., to JSON) before writing
  * Consider breaking very large data into chunks

## Related AHK Concepts

- DllCall - Used internally to access Windows memory mapping APIs
- Buffer - Used for binary data storage and exchange
- Mutex - Often used with FileMapping to synchronize access
- StrPut/StrGet - Used internally for string handling
- Memory management - Proper cleanup via __Delete method

## Tags

#AutoHotkey #SharedMemory #FileMapping #IPC #MemoryMappedFiles #WindowsAPI #Class