---
name: Module_DllCall
description: 'COM/IDispatch automation and vtable ComCall belong in Module_COM.md; Windows messages, subclassing,
  and WinRT activation belong in Module_WinAPI.md. This module is the native-call and memory-marshalling
  foundation those two build on. TRIGGER when the request involves: DllCall, Buffer, NumPut, NumGet, StrPut,
  StrGet, CallbackCreate, CallbackFree, Struct, VarSetStrCapacity, A_LastError, "call a Windows API",
  "call a native function", "pointer", "struct", "marshal", "raw memory", "pass a struct", "output parameter",
  "winapi", "user32", "kernel32", "Ptr type"'
---

# Module_DllCall

_AHK v2.0+ (typed Struct requires v2.1-alpha.30 — upstream or the +Console fork)_

## API QUICK-REFERENCE

### DllCall
| Form | Signature | Notes |
|------|-----------|-------|
| `DllCall()` | `DllCall("Dll\Func", Type1, Arg1, ..., ReturnType)` | Dll prefix optional for `user32`/`kernel32`/`gdi32`/`comctl32`; append `"W"`/`"A"` for explicit wide/ansi |
| Calling convention | `DllCall("CDecl ...")` or `"CDecl ReturnType"` | Default is stdcall; cdecl (e.g. `msvcrt`) needs the `CDecl` prefix |
| Void return (v2.1-alpha.30) | `DllCall("...", ..., "Void")` | Call runs but yields blank-unset instead of a fabricated numeric return |

### Argument / return types
| Type | Width | Notes |
|------|-------|-------|
| `Int` / `UInt` | 32-bit | Default return type if `ReturnType` omitted |
| `Int64` | 64-bit | No `UInt64` type — use `Int64` and mask the sign |
| `Short`/`UShort`, `Char`/`UChar` | 16 / 8-bit | |
| `Float`, `Double` | 32 / 64-bit | |
| `Ptr` / `UPtr` | pointer-sized | Handles, addresses, struct pointers; pass a `Buffer` directly for a `Ptr` arg |
| `Str` / `WStr` / `AStr` | string | `Str` is native (UTF-16); pass a variable for in/out string buffers |
| `Type*` | by-address | Output scalar — pass `&var`; value lands in `var` after the call |

### Memory objects and marshalling
| Function | Signature | Notes |
|----------|-----------|-------|
| `Buffer()` | `Buffer(ByteCount, FillByte := unset)` | `.Ptr` = address, `.Size` = bytes; pass `FillByte` (e.g. `0`) to zero-init |
| `NumPut()` | `NumPut(Type, Num [, Type2, Num2, ...], Target, Offset := 0)` | Type-first; chainable; returns the address after the last write |
| `NumGet()` | `NumGet(Source, Offset := 0, Type)` | Reads one value of `Type` at `Source+Offset` |
| `StrPut()` | `StrPut(Str, Target?, Length?, Encoding := "UTF-16")` | Writes an encoded string into a Buffer; returns chars/bytes written |
| `StrGet()` | `StrGet(Source, Length?, Encoding := "UTF-16")` | Reads a string from memory; `StrGet(ptr, 0)` returns "" on the fork |
| `CallbackCreate()` | `CallbackCreate(Fn, Options?, ParamCount?)` | Returns a pointer to pass to APIs; `Options`: `F` fast, `C` cdecl, `&` address-of-params |
| `CallbackFree()` | `CallbackFree(Ptr)` | Releases a callback; required to avoid a leak |

## AHK V2 CONSTRAINTS

- `Buffer(n)` owns `n` bytes for as long as the variable holding it is alive. If an API
  stores the pointer for later (a window's `GWLP_USERDATA`, an async callback), keep the
  Buffer referenced — let it go out of scope and the pointer dangles.
- `NumPut`/`NumGet` use type **strings** (`"Int"`, `"Ptr"`). Typed `Struct` fields use
  class **references** (`Int32`, `UInt32`, `IntPtr`). Do not mix the two vocabularies.
- A `Ptr` argument accepts a `Buffer` object directly — `DllCall(..., "Ptr", buf, ...)` —
  AHK passes `buf.Ptr`. Passing `buf.Ptr` explicitly is equivalent.
- Output scalars require both the `*` type and a `&var` reference: `"Int*", &out`.
- Check `A_LastError` immediately after a call when the API sets last-error; an
  intervening AHK statement can overwrite it.
- There is no `UInt64`. Read a 64-bit unsigned value as `Int64` and correct the sign.

✗ / ✓ pairs:

- ✗ `Buffer(8)` left uninitialized, then read — contains garbage
- ✓ `Buffer(8, 0)` — zero-filled; pass `buf` for a `Ptr` arg, `buf.Ptr` for an address

- ✗ `NumPut(123, buf, 0, "UInt")` — value-first order writes garbage
- ✓ `NumPut("UInt", 123, buf, 0)` — type-first

- ✗ `Struct PT { x: i32, y: i32 }` — alpha.30 rejects type strings
- ✓ `Struct PT { x: Int32, y: Int32 }` — class-ref fields

## TIER 1 — A first DllCall and the type list
> COVERED: DllCall · return types · Dll-name shorthand · A_LastError

```ahk
; ✓ Simplest call — module shorthand (user32 implied), explicit return type
pid := DllCall("GetCurrentProcessId", "UInt")

; ✓ Multiple typed args; the trailing type is the RETURN type
result := DllCall("user32\MessageBox", "Ptr", 0, "Str", "Body", "Str", "Title", "UInt", 0, "Int")

; ✓ Inspect failures via A_LastError (read it on the very next line)
hWin := DllCall("FindWindow", "Str", "Notepad", "Ptr", 0, "Ptr")
if !hWin
    throw OSError(A_LastError, -1, "FindWindow failed")
```

## TIER 2 — Buffer, NumPut, NumGet: building and reading a struct
> COVERED: Buffer · NumPut (chained) · NumGet · struct pointers as Ptr args

A struct is just a `Buffer` with values written at known byte offsets. `POINT` is two
32-bit ints (8 bytes); `RECT` is four (16 bytes).

```ahk
; ✓ Build a POINT, let an API fill it, read it back
pt := Buffer(8, 0)
DllCall("GetCursorPos", "Ptr", pt)          ; a Buffer auto-passes as its .Ptr
x := NumGet(pt, 0, "Int")
y := NumGet(pt, 4, "Int")
MsgBox("cursor at " x ", " y)

; ✓ NumPut is chainable and type-first; it returns the address after the last write
rc := Buffer(16, 0)
NumPut("Int", 0, "Int", 0, "Int", 800, "Int", 600, rc)   ; left, top, right, bottom

; ✓ Reading the same fields back
right  := NumGet(rc, 8,  "Int")
bottom := NumGet(rc, 12, "Int")
```

## TIER 3 — Strings across the boundary: StrPut / StrGet
> COVERED: StrPut · StrGet · encodings · in/out string buffers

```ahk
; ✓ Read a UTF-16 string the API wrote into a Buffer
buf := Buffer(260 * 2, 0)                    ; MAX_PATH wide chars
len := DllCall("GetWindowText", "Ptr", hWin, "Ptr", buf, "Int", 260, "Int")
title := StrGet(buf, len, "UTF-16")

; ✓ Encode an AHK string into raw bytes for an API that wants UTF-8
utf8 := Buffer(StrPut(text, "UTF-8"))        ; size first
StrPut(text, utf8, "UTF-8")                  ; then write
```

## TIER 4 — CallbackCreate: handing AHK functions to native APIs
> COVERED: CallbackCreate · CallbackFree · EnumWindows pattern

```ahk
; ✓ Pass an AHK function pointer to EnumWindows; collect HWNDs
class WindowEnumerator {
    __New() {
        this.handles := []
        this.cb := CallbackCreate(this.OnWindow.Bind(this), "Fast")
        DllCall("EnumWindows", "Ptr", this.cb, "Ptr", 0)
    }
    OnWindow(hWnd, lParam) {
        this.handles.Push(hWnd)
        return 1                              ; non-zero continues enumeration
    }
    __Delete() {
        if this.cb
            CallbackFree(this.cb)             ; always free the callback
    }
}
```

## TIER 5 — Typed Struct (fork / alpha.30)
> COVERED: Struct · class-ref typed fields · when to prefer it over Buffer

On the +Console fork, a typed `Struct` declares fields with class references and gives
named, type-checked access — clearer than manual `NumPut`/`NumGet` offsets for fixed
records. Fields are class refs (`Int32`, `UInt32`, `Int64`, `Float64`, `IntPtr`), never
type strings and never a bare byte count.

```ahk
; ✓ Fork-native typed struct (alpha.30): named fields, no manual offsets
Struct POINT {
    x: Int32
    y: Int32
}

; A 16-byte GUID has no single 16-byte field type — compose it from typed fields
Struct GUID {
    Data1: UInt32
    Data2: UInt16
    Data3: UInt16
    Data4: Int64
}
```

On stock v2 (or for raw byte regions) fall back to `Buffer` + `NumPut`/`NumGet` from
TIER 2. Reserve raw bytes with typed fields (an `Int8` array) or a `Buffer` companion —
the typeless `Struct X { buf: 16 }` form is rejected on alpha.30.

## SEE ALSO

> This module does NOT cover: calling COM/IDispatch objects or vtable `ComCall` → see Module_COM.md
> This module does NOT cover: Windows messages, subclassing, and WinRT activation → see Module_WinAPI.md

- `Module_COM.md` — `ComCall` is `DllCall` for COM vtables; `ComValue` wraps the typed values you marshal here.
- `Module_WinAPI.md` — applies these primitives to window messages, subclassing, owner-draw, and WinRT factory activation.
- `Module_Errors.md` — `OSError`/`A_LastError` patterns and try/catch wrapping for failed native calls.
- `Module_DataStructures.md` — when a `Map()`/Array is the right container vs. a raw `Buffer`/`Struct`.
