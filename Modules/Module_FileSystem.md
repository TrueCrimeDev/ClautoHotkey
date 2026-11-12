---
name: Module_FileSystem
description: 'Files and folders in AHK v2 — FileRead, FileAppend, FileOpen and the File object, explicit encodings, FileExist
  and DirExist attribute strings, copy, move and delete with their real failure behavior, SplitPath, Loop Files,
  Loop Read, CSV with Loop Parse, INI files, atomic writes, and binary I/O with Buffer. TRIGGER when the request involves:
  FileRead, FileAppend, FileOpen, FileExist, DirExist, FileCopy, FileMove, FileDelete, DirCreate, DirDelete, SplitPath,
  "Loop Files", "Loop Read", IniRead, IniWrite, "read file", "write file", "append to log", "check if file exists",
  "file extension", "parse CSV", "binary file", RawRead, RawWrite, "file encoding", UTF-8, BOM, "create folder",
  "list files", "recursive search". Not covered: string transformation of the content — see Module_TextProcessing.md;
  try/catch and error classes — see Module_Errors.md; HTTP downloads — see Module_NetworkAndHTTP.md;
  file-handle and attribute work through the Win32 API — see Module_DllCall.md and Module_WinAPI.md.'
---

# Module_FileSystem

## API QUICK-REFERENCE

### Whole-file functions
| Function | Signature | Notes |
|----------|-----------|-------|
| `FileRead` | `FileRead(path, options?)` | Whole file as text; options is an encoding (`"UTF-8"`, `"CP1252"`), `"RAW"` for a `Buffer`, and may carry `"m1024"` to cap the size |
| `FileAppend` | `FileAppend(text, path, options?)` | Creates the file; options is an encoding, `"*"` as path writes stdout |
| `FileExist` | `FileExist(pattern)` | Attribute string (`"A"`, `"D"`, `"RH"`...) or `""`; wildcards allowed |
| `DirExist` | `DirExist(pattern)` | Same shape, directories only |
| `FileGetSize`, `FileGetTime`, `FileGetAttrib` | `(path)` | Throw when the file is missing |
| `FileSetAttrib`, `FileSetTime` | | Modify attributes and timestamps |

### Mutation
| Function | Notes |
|----------|-------|
| `FileCopy(src, dest, overwrite := false)` | Throws `Error` ("Failed") when dest exists and overwrite is false |
| `FileMove(src, dest, overwrite := false)` | Same rule; a rename on one volume |
| `FileDelete(pattern)` | Throws `OSError` when a single named file is missing or locked |
| `DirCreate(path)` | Creates intermediate folders; an existing folder is not an error |
| `DirDelete(path, recurse := false)` | A non-empty folder needs `recurse := true` |
| `DirCopy`, `DirMove` | Whole trees; `overwrite` flag as above |
| `FileRecycle(pattern)`, `FileRecycleEmpty()` | Recycle bin instead of permanent delete |

### Paths and special folders
| Item | Notes |
|------|-------|
| `SplitPath(path, &name, &dir, &ext, &nameNoExt, &drive)` | All outputs optional; handles UNC and drive-only paths |
| `A_ScriptDir`, `A_WorkingDir`, `A_Temp`, `A_AppData`, `A_MyDocuments`, `A_Desktop` | No trailing backslash |
| `A_LoopFilePath`, `A_LoopFileName`, `A_LoopFileDir`, `A_LoopFileExt`, `A_LoopFileSize`, `A_LoopFileTimeModified` | Inside `Loop Files` |
| `A_LoopReadLine`, `A_LoopField` | Inside `Loop Read` and `Loop Parse` |

### File object (`FileOpen(path, mode, encoding?)`)
| Member | Notes |
|--------|-------|
| Modes | `"r"`, `"w"` (truncates), `"a"`, `"rw"`; add `"-rwd"` style share flags only when needed; `"h"` wraps a handle |
| `Read([chars])`, `ReadLine()`, `Write(text)`, `WriteLine(text)` | Text, in the object's `Encoding` |
| `ReadUInt()`, `ReadInt()`, `ReadUChar()`, `WriteUInt(n)` ... | Fixed-width binary values |
| `RawRead(buf [, bytes])`, `RawWrite(buf [, bytes])` | Return the byte count; `RawRead` accepts a Buffer or pointer |
| `Pos`, `Length`, `AtEOF`, `Encoding` | `Pos` and `Length` are writable; shrinking `Length` truncates |
| `Seek(offset, origin := 0)` | 0 start, 1 current, 2 end |
| `Close()` | Flushes and releases the handle |

### INI
| Function | Notes |
|----------|-------|
| `IniRead(path, section, key, default?)` | Without `default`, a missing key throws `OSError` |
| `IniWrite(value, path, section, key)` | Creates file, section and key |
| `IniDelete(path, section, key?)` | Omit key to drop the section |

## AHK V2 CONSTRAINTS

- Pass an encoding to every text `FileRead`, `FileAppend` and `FileOpen`. Without one, `FileRead` and `FileOpen` fall back to the system code page (honoring a BOM when present), so the same script reads the same file differently on another machine. Use `"UTF-8"` for new files.
- Read `FileExist` as an attribute string: `""` means absent, `"D"` among the letters means a directory. `if FileExist(p)` is true for a folder too, so use `DirExist` when a folder is meant and `!InStr(FileExist(p), "D")` when a regular file is required.
- Use `SplitPath` for path pieces. Do not split on `\` by hand and do not extract the extension with a regex.
- A `File` object closes its handle when its last reference is released, so `f := ""` or leaving the function closes it. That is not a reason to skip `Close()`: when other references exist, or a stack trace holds the object after an error, the handle stays open. Close in `finally` when an exception can occur between open and close.
- `FileOpen` never gets a `"b"` mode or text encoding for binary data. Omit the encoding; pass a `Buffer` to `RawRead` and `RawWrite`.
- Do not call `FileAppend` in a loop. Each call opens, writes and closes. Open once with `FileOpen(path, "a", "UTF-8")` and write inside the loop.
- `FileDelete` throws on a missing single file, and `FileCopy` and `FileMove` throw when the destination exists and overwrite is false. A script that expects a quiet no-op must test or catch.
- Give `DirCreate` the full path without checking first; it is idempotent and creates parents.
- `Loop Read` splits on line breaks, so a quoted CSV field that contains a newline is broken across iterations. Parse that kind of file from a single string instead.
- Anchor relative paths with `A_ScriptDir`. A relative path follows `A_WorkingDir`, which changes after `SetWorkingDir`, a file dialog, or a launch from a shortcut.
- Avoid `FileRead` on files that can be larger than a few hundred MB; stream with `Loop Read` or `RawRead`.
- There is no `FileReadLine`, `FileWrite` or `FileRead` command form in v2. For one line by number, `Loop Read` and test `A_Index`.
- A fork build can read and parse JSON files directly with `JSON.ParseFile(path)`; code that must also run on stock AHK reads the text with `FileRead(path, "UTF-8")` and calls `JSON.Parse` (see Module_NetworkAndHTTP.md).

## TIER 1 - Existence checks and simple read/write

```ahk
dir := A_Temp "\fs-demo"
DirCreate(dir)
path := dir "\config.txt"

if FileExist(path) = "" {
    FileAppend("theme=dark`n", path, "UTF-8")
}
text := FileRead(path, "UTF-8")
Print("{} chars", StrLen(text))

attr := FileExist(dir)
Print("is folder: {}", InStr(attr, "D") ? "yes" : "no")

; Replace a whole file: delete first, FileAppend does not truncate
if FileExist(path)
    FileDelete(path)
FileAppend("theme=light`n", path, "UTF-8")
```

`FileAppend` appends. To overwrite, delete first or open with mode `"w"`.

## TIER 2 - Copy, move and delete

```ahk
src := A_Temp "\fs-demo\config.txt"
backupDir := A_Temp "\fs-demo\backup"
try {
    DirCreate(backupDir)
    FileCopy(src, backupDir "\config.txt", true)
    FileMove(src, A_Temp "\fs-demo\config.old", true)
} catch as err {
    MsgBox("File operation failed: " err.Message)
}
```

Atomic replacement of a file other programs may read: write the new content to a temporary file in the same folder, then `FileMove(temp, final, true)`. A reader sees the old or the new file, never half of one.

```ahk
WriteFileAtomic(path, text, encoding := "UTF-8") {
    temp := path ".tmp"
    f := FileOpen(temp, "w", encoding)
    try
        f.Write(text)
    finally
        f.Close()
    FileMove(temp, path, true)
}

WriteFileAtomic(A_Temp "\fs-demo\settings.txt", "a=1`nb=2`n")
```

## TIER 3 - Paths and directory traversal

```ahk
SplitPath(A_Temp "\fs-demo\report.final.csv", &name, &dir, &ext, &stem, &drive)
Print("{} | {} | {} | {} | {}", name, dir, ext, stem, drive)

csvFiles := []
Loop Files, A_Temp "\fs-demo\*.csv", "R"
    csvFiles.Push(A_LoopFilePath)

; Mode letters: F files, D folders, R recurse
folders := []
Loop Files, A_Temp "\fs-demo\*", "DR"
    folders.Push(A_LoopFilePath)
```

`Loop Files` snapshots nothing: changing the folder while looping can skip or repeat entries, so collect paths first and act afterward. A `*.csv` pattern also matches names with a trailing-extension quirk on 8.3 aliases; test `A_LoopFileExt = "csv"` when exactness matters. Join path parts with a helper that trims one backslash:

```ahk
JoinPath(base, parts*) {
    path := RTrim(base, "\")
    for part in parts
        path .= "\" LTrim(part, "\")
    return path
}
```

## TIER 4 - Lines and CSV

```ahk
errors := []
Loop Read, A_Temp "\fs-demo\app.log"
{
    if InStr(A_LoopReadLine, "ERROR")
        errors.Push(A_LoopReadLine)
}

rows := []
Loop Read, A_Temp "\fs-demo\data.csv"
{
    row := []
    Loop Parse, A_LoopReadLine, "CSV"
        row.Push(A_LoopField)
    rows.Push(row)
}
```

`Loop Read` takes the encoding from a BOM or the system page. For a UTF-8 file without a BOM, read the whole text and iterate it, which also fixes the quoted-newline case:

```ahk
text := FileRead(A_Temp "\fs-demo\data.csv", "UTF-8")
rows := []
for line in StrSplit(text, "`n", "`r") {
    if line = ""
        continue
    row := []
    Loop Parse, line, "CSV"
        row.Push(A_LoopField)
    rows.Push(row)
}
```

For a CSV with embedded newlines, split records with a regex that respects quotes, or use a dedicated parser. A plain `","` delimiter in `Loop Parse` splits inside quoted fields.

## TIER 5 - INI and the File object

```ahk
ini := A_Temp "\fs-demo\app.ini"
IniWrite("Dark", ini, "UI", "Theme")
theme := IniRead(ini, "UI", "Theme", "Light")
Print("theme={}", theme)

log := FileOpen(A_Temp "\fs-demo\bulk.log", "a", "UTF-8")
try {
    Loop 1000
        log.WriteLine("entry " A_Index)
} finally {
    log.Close()
}
```

`IniRead` and `IniWrite` use the Windows profile API. They are fine for flat settings. For nested or typed data prefer JSON, and for a Windows profile file with a UTF-16 BOM be sure to create it as UTF-16 before the first `IniWrite`; the API will not convert an existing ANSI file.

A wrapper that closes deterministically and fails loudly:

```ahk
class LogWriter {
    __New(path, encoding := "UTF-8") {
        this.file := FileOpen(path, "a", encoding)
    }

    Line(text) {
        if !this.file
            throw Error("LogWriter is closed")
        this.file.WriteLine(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " text)
    }

    Close() {
        if this.file {
            this.file.Close()
            this.file := ""
        }
    }

    __Delete() => this.Close()
}

writer := LogWriter(A_Temp "\fs-demo\run.log")
writer.Line("started")
writer.Close()
```

## TIER 6 - Binary I/O

```ahk
binPath := A_Temp "\fs-demo\data.bin"
f := FileOpen(binPath, "rw")
try {
    f.WriteUInt(0x1A2B3C4D)
    f.Pos := 0
    Print("read back: {:X}", f.ReadUInt())
} finally {
    f.Close()
}

CopyBinary(srcPath, destPath, chunk := 65536) {
    src := FileOpen(srcPath, "r")
    dst := ""
    try {
        dst := FileOpen(destPath, "w")
        buf := Buffer(chunk)
        while !src.AtEOF {
            got := src.RawRead(buf)
            dst.RawWrite(buf, got)
        }
    } finally {
        src.Close()
        if dst
            dst.Close()
    }
}

CopyBinary(binPath, A_Temp "\fs-demo\copy.bin")

whole := FileRead(binPath, "RAW")
Print("{} bytes", whole.Size)
```

`FileRead(path, "RAW")` returns a `Buffer`; the text overload would decode and damage the bytes.

## Cleanup of the demo folder

```ahk
if DirExist(A_Temp "\fs-demo")
    DirDelete(A_Temp "\fs-demo", true)
```

## ANTI-PATTERNS

| Mistake | Fix |
|---------|-----|
| `FileRead(path)` / `FileAppend(text, path)` for text with no encoding | Add `"UTF-8"` |
| `FileAppend` inside a loop | One `FileOpen(..., "a", enc)` handle, `WriteLine`, `Close` in `finally` |
| `if FileExist(path)` when a regular file is required | Compare the attribute string or test `DirExist` |
| `StrSplit(path, "\")[-1]`, regex for the extension | `SplitPath` |
| `FileCopy(a, b)` assuming it silently skips an existing target | Pass `overwrite`, or catch the `Error` |
| `FileDelete(path)` on a maybe-missing file with no guard | `if FileExist(path)` first, or `try` |
| `FileOpen(path, "r", "UTF-8")` on a binary file | Omit the encoding, use `RawRead` |
| `Loop Read` for CSV with multi-line quoted fields | Read the string and parse it as a whole |
| Relative paths in a script that changes directory | `A_ScriptDir "\file"` |
| Reading a huge file with `FileRead` | `Loop Read` or chunked `RawRead` |

## SEE ALSO

- `Module_Errors.md` - OSError, try/catch/finally, error propagation.
- `Module_TextProcessing.md` - StrReplace, RegExReplace, Format and parsing the text you read.
- `Module_Arrays.md` - collecting file paths and rows.
- `Module_NetworkAndHTTP.md` - downloading to a file and JSON round trips.
- `Module_DllCall.md` - Buffer, NumGet and NumPut for binary structures.

<!-- Adapted from hsinming/AutoHotkey-V2-vibe-coding-tools (no license file upstream); see THIRD-PARTY.md -->
