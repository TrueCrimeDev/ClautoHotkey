---
name: ahk-dllcall
description: >
  Native calls and raw memory for AHK v2 — DllCall to Windows/native APIs, Buffer +
  NumGet/NumPut for structs, StrPut/StrGet, CallbackCreate, and the alpha.30 typed Struct.
  Use when calling a DLL/WinAPI function, building or reading a struct, or passing a callback
  to native code.
  TRIGGER when: user says "DllCall", "call a Windows API", "Buffer", "NumPut/NumGet",
  "struct", "pointer", "CallbackCreate", "StrGet/StrPut", "marshal", "user32/kernel32".
  Examples: "call GetCursorPos", "build a RECT struct", "pass a callback to EnumWindows"
---

# AHK v2 DllCall & Memory

The native-call and memory-marshalling foundation.

## How to use

1. Load the full reference from `Modules/Module_DllCall.md` — type list, Buffer/NumPut/NumGet, StrPut/StrGet, CallbackCreate, typed Struct.
2. Always specify parameter and return types explicitly: `DllCall("user32\Func", "Ptr", h, "Int")`.
3. Allocate with `Buffer(bytes, 0)` (zero-init); pass a Buffer directly for a `Ptr` arg; read fields with `NumGet(buf, offset, "Type")`.
4. Free every `CallbackCreate` pointer with `CallbackFree`; keep a Buffer alive as long as an API holds its pointer.

## Quick answers

- **Output scalar:** `DllCall("...", "Int*", &out)`. **Struct in/out:** pass a `Buffer`.
- **Strings across the boundary:** `StrGet(buf, len, "UTF-16")` / `StrPut(s, buf, "UTF-8")`.
- **Typed Struct (fork / alpha.30):** `Struct POINT { x: Int32, y: Int32 }`; v2.0 fallback is `Buffer` + `NumPut`/`NumGet`.

For the full type table and the CallbackCreate pattern, read `Modules/Module_DllCall.md`.
