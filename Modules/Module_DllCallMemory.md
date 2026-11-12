---
name: Module_DllCallMemory
description: 'Struct layout, block memory, error handling and handle lifetime for native calls in AHK v2 -
  Win32-to-DllCall type mapping, x86/x64 offsets and alignment with A_PtrSize, Rtl* block operations,
  VirtualAlloc/HeapAlloc/GlobalAlloc, Str vs Buffer string marshalling, GetProcAddress call-by-address,
  A_LastError/OSError/HRESULT checks, owning HANDLEs with __Delete, and CallbackCreate hook procedures.
  TRIGGER when the request involves: "struct layout", "struct offset", "struct padding", A_PtrSize, x86,
  x64, "pointer size", RtlMoveMemory, RtlCopyMemory, RtlFillMemory, RtlZeroMemory, RtlCompareMemory,
  memcpy, memmove, VirtualAlloc, VirtualFree, HeapAlloc, HeapFree, GlobalAlloc, GlobalLock, GetProcAddress,
  LoadLibrary, CloseHandle, HANDLE, HRESULT, GetLastError, FormatMessage, WideCharToMultiByte,
  MultiByteToWideChar, SetWindowsHookEx, CallNextHookEx, "low-level hook", EnumWindows, "SIZE_T",
  "Win32 type", "DWORD", "LPARAM", "handle leak", "memory leak", "dangling pointer", "truncated handle".
  Not covered: basic DllCall/NumPut/StrPut syntax and the typed Struct - see Module_DllCall.md; COM
  vtable ComCall and IDispatch - see Module_COM.md; window messages and subclassing - see Module_WinAPI.md.'
---

# Module_DllCallMemory

_AHK v2.0+; the `"Void"` return and class-ref type arguments need v2.1-alpha.30 / alpha.33 (fork or upstream)_

## API QUICK-REFERENCE

### Win32 type to DllCall type
| C / Win32 type | DllCall type | Notes |
|----------------|--------------|-------|
| `HWND`, `HANDLE`, `HMODULE`, `HDC`, `HHOOK`, any pointer | `Ptr` | Never `Int`: 32-bit truncates 64-bit addresses |
| `WPARAM`, `UINT_PTR`, `SIZE_T`, `ULONG_PTR` | `UPtr` | Unsigned, pointer-wide |
| `LPARAM`, `LRESULT`, `INT_PTR`, `LONG_PTR` | `Ptr` | Signed, pointer-wide |
| `DWORD`, `UINT`, `ULONG`, `COLORREF` | `UInt` | |
| `LONG`, `INT`, `BOOL` | `Int` | `BOOL` is 32-bit, nonzero is true |
| `WORD`, `USHORT`, `ATOM`, `WCHAR` | `UShort` | |
| `BYTE`, `UCHAR`, `BOOLEAN` | `UChar` | |
| `LONGLONG`, `LARGE_INTEGER`, `ULONGLONG`, `QWORD` | `Int64` | There is no `UInt64` type; fix the sign yourself if the high bit can be set |
| `HRESULT` | `HRESULT` (return only) | Throws `OSError` on a failure code; plain `Int` returns the raw value |
| `LPCWSTR`, `LPWSTR` | `Str` | Input: AHK passes its own UTF-16 buffer; for output use a `Buffer` and `Ptr` |
| `LPSTR`, `LPCSTR` | `AStr` | 8-bit ANSI APIs only (e.g. the name argument of `GetProcAddress`) |

### Memory APIs
| Function | AHK types | Notes |
|----------|-----------|-------|
| `ntdll\RtlMoveMemory(dst, src, len)` | `Ptr, Ptr, UPtr` | memmove, overlap-safe, void |
| `ntdll\RtlCopyMemory(dst, src, len)` | `Ptr, Ptr, UPtr` | memcpy, non-overlapping, void |
| `ntdll\RtlFillMemory(dst, len, fill)` | `Ptr, UPtr, UChar` | memset, void. Note the argument order: length before fill |
| `ntdll\RtlZeroMemory(dst, len)` | `Ptr, UPtr` | void |
| `ntdll\RtlCompareMemory(a, b, len)` | `Ptr, Ptr, UPtr, "UPtr"` | Returns the count of matching leading bytes, not a boolean; equal only if result = `len` |
| `VirtualAlloc(addr, size, type, protect)` | `Ptr, UPtr, UInt, UInt, "Ptr"` | `0x3000` = commit+reserve; page-granular; `PAGE_READWRITE = 4` |
| `VirtualFree(addr, size, type)` | `Ptr, UPtr, UInt` | `MEM_RELEASE = 0x8000` requires size 0 |
| `GetProcessHeap()` / `HeapAlloc(h, flags, n)` / `HeapFree(h, flags, p)` | `"Ptr"` / `Ptr, UInt, UPtr, "Ptr"` / `Ptr, UInt, Ptr` | `HEAP_ZERO_MEMORY = 8`; free with the same heap |
| `GlobalAlloc(flags, n)` / `GlobalLock` / `GlobalUnlock` / `GlobalFree` | `UInt, UPtr, "Ptr"` / `Ptr, "Ptr"` / `Ptr` / `Ptr, "Ptr"` | `GMEM_MOVEABLE = 2`, `GMEM_ZEROINIT = 0x40`; the clipboard takes ownership of the block |
| `GetProcAddress(hMod, name)` | `Ptr, AStr, "Ptr"` | Result can be passed in place of the function name |
| `CloseHandle(h)` | `Ptr` | Required for every `Create*`/`Open*` handle |

## AHK V2 CONSTRAINTS

- The default return type is `Int` (32-bit). Always name the return type when the function returns a
  handle, pointer, `DWORD` or `SIZE_T`; a missing `"Ptr"` silently truncates the upper 32 bits on x64.
- Pointer-sized fields and arguments use `Ptr`/`UPtr` and `A_PtrSize`, never a hard-coded 8 or 4, so
  one script works on both the 32-bit and 64-bit interpreter.
- A struct field after a smaller one is aligned to its own size (a pointer field to `A_PtrSize`), so
  on x64 the offsets shift. Derive offsets from the documented C struct, field by field (Tier 1).
- `.Ptr` is only valid while the `Buffer` object lives. Return and store the `Buffer`, not `buf.Ptr`;
  a native API that keeps the pointer (async calls, subclass data, hook state) needs the `Buffer`
  referenced from a long-lived object.
- `Str` arguments are valid for the duration of the call only. If the API keeps the pointer,
  copy the text into a `Buffer` with `StrPut` and keep that `Buffer` alive.
- `RtlMoveMemory`, `RtlCopyMemory`, `RtlFillMemory`, `RtlZeroMemory` and `GetSystemInfo` return
  nothing. On v2.1-alpha.30+ pass `"Void"` as the return type; on v2.0 omit the return type and do
  not read the result.
- `NumPut(Type, Value, Target, Offset)` and `NumGet(Source, Offset, Type)` put the type in different
  positions. `Type` is required in `NumGet` (there is no default width).
- Read `A_LastError` on the very next statement after the failing call; any other DllCall can
  overwrite it. It is only meaningful when the API documents `GetLastError`.
- Free what you allocate with the matching call: `VirtualAlloc`/`VirtualFree`,
  `HeapAlloc`/`HeapFree`, `GlobalAlloc`/`GlobalFree`, `Create*`/`CloseHandle`,
  `CallbackCreate`/`CallbackFree`. Never `HeapFree` or `GlobalFree` a `Buffer`'s `.Ptr`.
- Never `GlobalFree` a block after `SetClipboardData` succeeds; the clipboard owns it. In practice
  assign `A_Clipboard` and skip raw clipboard memory.
- A low-level hook procedure (`WH_KEYBOARD_LL`, `WH_MOUSE_LL`) must call `CallNextHookEx` on every
  invocation, and the hooking script needs a running message loop.
- An `EnumWindows`/`EnumChildWindows` callback returns nonzero to continue; returning 0 stops.

✗ / ✓ pairs:

- ✗ `DllCall("GetModuleHandleW", "Str", name)` - `Int` return truncates the handle
- ✓ `DllCall("GetModuleHandleW", "Str", name, "Ptr")`

- ✗ `"UInt", size` for a `SIZE_T` length argument - clips above 4 GB on x64
- ✓ `"UPtr", size`

- ✗ `if !DllCall("ntdll\RtlCompareMemory", ..., "UPtr")` to test inequality - 0 only means byte 0 differs
- ✓ `DllCall("ntdll\RtlCompareMemory", "Ptr", a, "Ptr", b, "UPtr", n, "UPtr") = n` means identical

- ✗ `NumGet(buf, 0)` - the type is mandatory
- ✓ `NumGet(buf, 0, "UPtr")`

- ✗ `x := (a, b) => { stmt1; stmt2 }` handed to `CallbackCreate` - a fat arrow is one expression
- ✓ a named function or bound method, with `CallbackCreate(fn)`

- ✗ `DllCall("GetComputerNameW", "Ptr", buf, "UInt*", n)` - a bare value is not a VarRef
- ✓ `DllCall("GetComputerNameW", "Ptr", buf, "UInt*", &n := 16)`

## TIER 1 - Struct layout, A_PtrSize and alignment
> COVERED: offset arithmetic · padding · x86/x64 · SYSTEM_INFO · typed Struct form

A scalar field starts at the next multiple of its own size; a pointer-sized field starts at the next
multiple of `A_PtrSize`; the struct size rounds up to its largest member. Compute pointer-dependent
offsets from `A_PtrSize` instead of choosing a bitness. `SYSTEM_INFO` has three pointer-sized fields
in the middle, so everything after them moves between x86 and x64.

```ahk
; SYSTEM_INFO: wProcessorArchitecture@0 (UShort), dwPageSize@4 (UInt), then three pointer-sized
; fields starting at 8, so dwNumberOfProcessors is at 8 + 3*A_PtrSize (20 on x86, 32 on x64)
si := Buffer(48, 0)
DllCall("Kernel32\GetSystemInfo", "Ptr", si)
cpus  := NumGet(si, 8 + 3 * A_PtrSize, "UInt")
pages := NumGet(si, 4, "UInt")
Print("cpus={} (env says {}) page={}", cpus, EnvGet("NUMBER_OF_PROCESSORS"), pages)
```

```ahk
; typedef struct { UINT cb; LPVOID lpData; } S;   size = 2 * A_PtrSize (4 bytes of padding on x64)
S := Buffer(2 * A_PtrSize, 0)
NumPut("UInt", 7, S, 0)
NumPut("Ptr", 0x1234, S, A_PtrSize)
Print("{} {:#x}", NumGet(S, 0, "UInt"), NumGet(S, A_PtrSize, "Ptr"))
```

The chained form `NumPut("UInt", 7, "Ptr", p, S, 0)` writes the pairs back to back with no padding,
so it is wrong for a struct that needs alignment on x64; use per-field offsets whenever a pointer
follows a smaller field.

Fork form (v2.1-alpha.30+): a typed `Struct` computes the offsets for you, and from alpha.33
`NumGet`/`NumPut` accept the type class. v2.0 fallback: the string types shown in the comments.

```ahk
Struct RECT {
    left: Int32
    top: Int32
    right: Int32
    bottom: Int32
}

rc := RECT()
DllCall("User32\GetWindowRect", "Ptr", DllCall("User32\GetDesktopWindow", "Ptr"), "Ptr", rc)
Print("{}x{}", rc.right - rc.left, rc.bottom - rc.top)

b := Buffer(8, 0)
NumPut(Int32, 5, b, 0)                 ; alpha.33 form; v2.0: NumPut("Int", 5, b, 0)
Print("{}", NumGet(b, 0, Int32))       ; alpha.33 form; v2.0: NumGet(b, 0, "Int")
```

## TIER 2 - Block memory operations
> COVERED: RtlMoveMemory · RtlFillMemory · RtlZeroMemory · RtlCompareMemory · Buffer.Size

Use the `Rtl*` functions instead of a `NumPut` loop for anything larger than a few bytes. Lengths are
`UPtr`; the void ones take `"Void"` on the fork.

```ahk
src := Buffer(16, 0)
dst := Buffer(16, 0)
loop 16
    NumPut("UChar", A_Index, src, A_Index - 1)

DllCall("ntdll\RtlMoveMemory", "Ptr", dst, "Ptr", src, "UPtr", src.Size, "Void")
same := DllCall("ntdll\RtlCompareMemory", "Ptr", dst, "Ptr", src, "UPtr", 16, "UPtr")
Print("copied, matching bytes = {}", same)

; overlapping shift: copy bytes 0..11 to 4..15 (RtlMoveMemory is memmove)
DllCall("ntdll\RtlMoveMemory", "Ptr", dst.Ptr + 4, "Ptr", dst, "UPtr", 12, "Void")
Print("byte4={} (the old byte 0; it was 5 before the shift)", NumGet(dst, 4, "UChar"))

DllCall("ntdll\RtlFillMemory", "Ptr", dst, "UPtr", dst.Size, "UChar", 0xFF, "Void")
DllCall("ntdll\RtlZeroMemory", "Ptr", dst, "UPtr", dst.Size, "Void")
dst.Size := 32          ; resize keeps old bytes, the address may change, new bytes are uninitialized
Print("size={} first={}", dst.Size, NumGet(dst, 0, "UChar"))
```

v2.0 fallback: drop the trailing `"Void"` argument from the four void calls.

`VirtualAlloc` is for page-sized, protected or executable memory; `Buffer` is the default allocator for
everything else.

```ahk
addr := DllCall("Kernel32\VirtualAlloc", "Ptr", 0, "UPtr", 4096, "UInt", 0x3000, "UInt", 0x04, "Ptr")
if !addr
    throw OSError(A_LastError)
try {
    NumPut("UInt", 0xCAFEBABE, addr, 0)
    Print("{:#x}", NumGet(addr, 0, "UInt"))
} finally {
    DllCall("Kernel32\VirtualFree", "Ptr", addr, "UPtr", 0, "UInt", 0x8000)
}
```

## TIER 3 - Strings, encodings and call-by-address
> COVERED: Str vs Buffer · output text buffers · UTF-8 · AStr · GetProcAddress

| Direction | Use | Why |
|-----------|-----|-----|
| Text in, used during the call | `"Str", text` | AHK passes its own UTF-16 buffer |
| Text out into a caller buffer | `Buffer(chars * 2)` + `"Ptr", buf` + `StrGet(buf)` | Size in bytes is `chars * 2`; pass the character count to the API |
| Text the API keeps | `Buffer(StrPut(text))` + `StrPut(text, buf)`, keep `buf` alive | The `Str` copy is gone after the call |
| UTF-8 / ANSI bytes | `StrPut(text, buf, "UTF-8")` / `StrGet(ptr, n, "UTF-8")`, `"CP0"` for ANSI | Name the encoding every time |

```ahk
; Output text buffer: size in bytes = characters * 2; pass characters to the API
buf := Buffer(260 * 2, 0)
n := DllCall("Kernel32\GetWindowsDirectoryW", "Ptr", buf, "UInt", 260, "UInt")
if !n
    throw OSError(A_LastError)
Print("{}", StrGet(buf, n))

; UTF-8 round trip: StrPut with no target returns the required size (null included)
text := "caf" Chr(0xE9)
u8 := Buffer(StrPut(text, "UTF-8"))
StrPut(text, u8, "UTF-8")
Print("{} bytes -> {}", u8.Size, StrGet(u8, "UTF-8"))

; Resolve once, call by address in a hot loop; the name for GetProcAddress is ANSI
hMod := DllCall("Kernel32\GetModuleHandleW", "Str", "user32.dll", "Ptr")
pClickTime := DllCall("Kernel32\GetProcAddress", "Ptr", hMod, "AStr", "GetDoubleClickTime", "Ptr")
Print("double-click ms = {}", DllCall(pClickTime, "UInt"))
```

## TIER 4 - Error handling: return value, A_LastError, OSError, HRESULT
> COVERED: sentinel checks · OSError · HRESULT return type · ComCall status

Check the documented failure value first, then read `A_LastError`. `OSError(code)` already carries
the system's message text, so a `FormatMessageW` helper is unnecessary.

```ahk
; BOOL API: zero means failure, A_LastError says why (0x1234 is not a valid handle)
ok := DllCall("Kernel32\CloseHandle", "Ptr", 0x1234, "Int")
if !ok {
    err := OSError(A_LastError)
    Print("failed: {} (code {})", Trim(err.Message, "`r`n ."), err.Number)
}

; HRESULT return type: a failure code throws OSError, a success code is returned
try DllCall("ole32\CLSIDFromString", "Str", "not-a-guid", "Ptr", Buffer(16), "HRESULT")
catch OSError as e
    Print("HRESULT {:#x}: {}", e.Number & 0xFFFFFFFF, Trim(e.Message, "`r`n ."))
```

A function that returns a handle uses `0` (or `-1`, `INVALID_HANDLE_VALUE`, for `CreateFile`) as the
failure sentinel; read the API's documentation for which. `ComCall` raises `OSError` for a failure
`HRESULT` on its own; pass `"Void"` as its last argument for methods that return nothing (see
Module_COM.md).

## TIER 5 - Handles and cleanup
> COVERED: CloseHandle · __Delete ownership · try/finally · GlobalAlloc ownership

AHK does not close kernel handles for you. Wrap each one in an object whose `__Delete` releases it,
so every exit path (including exceptions) closes it.

```ahk
class KernelHandle {
    __New(h) {
        if !h
            throw OSError(A_LastError)
        this.h := h
    }

    __Delete() {
        if this.h {
            DllCall("Kernel32\CloseHandle", "Ptr", this.h)
            this.h := 0
        }
    }
}

mutex := KernelHandle(DllCall("Kernel32\CreateMutexW", "Ptr", 0, "Int", 0, "Str", "Demo_Mutex_Once", "Ptr"))
already := A_LastError = 183          ; ERROR_ALREADY_EXISTS, read before any other call
Print("already running: {}", already)

hold := DllCall("Kernel32\WaitForSingleObject", "Ptr", mutex.h, "UInt", 1000, "UInt")
Print("wait result {}", hold)         ; 0 = WAIT_OBJECT_0, 0x102 = WAIT_TIMEOUT
if hold = 0
    DllCall("Kernel32\ReleaseMutex", "Ptr", mutex.h)
mutex := ""                           ; drops the last reference and closes the handle
```

For a block you must hand to an API that wants an `HGLOBAL`, `GlobalAlloc` with `GMEM_MOVEABLE`,
`GlobalLock`, write, `GlobalUnlock`, and call `GlobalFree` yourself only if the API did not take
ownership.

## TIER 6 - Callbacks and hook procedures
> COVERED: CallbackCreate · Fast option · lifetime in __Delete · WH_KEYBOARD_LL · EnumWindows

Bind methods with `.Bind(this)`, keep the callback pointer on the object, and free it in `__Delete`.
The `"Fast"` option skips creating a new AHK thread and is correct for callbacks the OS calls
synchronously on the script's own thread (`EnumWindows`, hooks).

```ahk
class WindowLister {
    __New() {
        this.titles := []
        this.cb := CallbackCreate(this.OnWindow.Bind(this), "Fast", 2)
    }

    OnWindow(hwnd, lParam) {
        title := WinGetTitle(hwnd)
        if title != ""
            this.titles.Push(title)
        return 1                      ; nonzero continues the enumeration
    }

    List() {
        this.titles.Length := 0
        DllCall("User32\EnumWindows", "Ptr", this.cb, "Ptr", 0)
        return this.titles
    }

    __Delete() {
        if this.cb {
            CallbackFree(this.cb)
            this.cb := 0
        }
    }
}

lister := WindowLister()
Print("{} titled windows", lister.List().Length)
lister := ""
```

A low-level keyboard hook is the same shape plus the mandatory `CallNextHookEx`. The
`KBDLLHOOKSTRUCT` that `lParam` points at has `vkCode` (UInt) at 0, `scanCode` at 4, `flags` at 8,
`time` at 12 and `dwExtraInfo` (UPtr) at 16.

```ahk
class KeyHook {
    __New() {
        this.last := 0
        this.cb := CallbackCreate(this.Proc.Bind(this), "Fast", 3)
        this.hook := DllCall("User32\SetWindowsHookExW", "Int", 13, "Ptr", this.cb, "Ptr", 0, "UInt", 0, "Ptr")
        if !this.hook {
            CallbackFree(this.cb)
            throw OSError(A_LastError)
        }
    }

    Proc(nCode, wParam, lParam) {
        if nCode >= 0 && wParam = 0x100            ; WM_KEYDOWN
            this.last := NumGet(lParam, 0, "UInt")
        return DllCall("User32\CallNextHookEx", "Ptr", this.hook, "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    __Delete() {
        if this.hook
            DllCall("User32\UnhookWindowsHookEx", "Ptr", this.hook)
        if this.cb
            CallbackFree(this.cb)
        this.hook := this.cb := 0
    }
}

hk := KeyHook()
Sleep(50)
hk := ""
Print("hook installed and removed")
```

On the fork, `CallbackCreate` can declare a `"Void"` return for procedures that return nothing; on
v2.0 return a value or nothing and ignore it.

## SEE ALSO

> This module does NOT cover: basic `DllCall`, `Buffer`, `NumPut`/`NumGet`, `StrPut`/`StrGet` syntax, typed `Struct` → see Module_DllCall.md
> This module does NOT cover: COM vtable `ComCall`, IDispatch automation → see Module_COM.md
> This module does NOT cover: `OnMessage`, `SendMessage`, subclassing, WM_COPYDATA, DWM → see Module_WinAPI.md

- `Module_DllCall.md` - the call syntax, type strings, `Buffer` basics and typed `Struct` this module builds on.
- `Module_WinAPI.md` - window messages, subclass procedures (callback lifetime), WM_COPYDATA IPC.
- `Module_COM.md` - `ComCall` and `ComValue`; HRESULT failures surface as `OSError` there too.
- `Module_Errors.md` - try/catch/finally patterns around native failures.
- `Module_Versions.md` - which of the fork forms (`"Void"`, class-ref `NumGet`, `Struct`) exist on which build.

<!-- Adapted in part from hsinming/AutoHotkey-V2-vibe-coding-tools (no license file upstream); see THIRD-PARTY.md -->
