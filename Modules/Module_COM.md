# Module_COM.md
<!-- DOMAIN: COM automation and interop -->
<!-- SCOPE: Raw DllCall, Buffer, and Struct marshalling belong in Module_DllCall.md; WinRT activation and the IInspectable ABI belong in Module_WinAPI.md (WinRT section). This module covers classic COM: IDispatch automation, events, SafeArrays, and direct vtable ComCall. -->
<!-- TRIGGERS: COM, ComObject, ComObjGet, ComCall, ComValue, ComObjArray, ComObjConnect, ComObjQuery, ComObjFromPtr, IDispatch, IUnknown, vtable, "Excel automation", "Word automation", "WMI", "Internet Explorer", "Shell.Application", "COM event", "SafeArray", "VARIANT", "automation object", "CLSID", "ProgID", "QueryInterface" -->
<!-- CONSTRAINTS: Create objects with ComObject("ProgID") — never `ComObjCreate`. COM objects are reference-counted by AHK and Release automatically when the wrapping variable is freed; a raw interface pointer you obtain yourself (ComCall output, ComObjQuery on a Ptr) is NOT auto-managed — release it. COM calls run on AHK's single thread; a modal call into another app (a MsgBox in Excel) blocks your script. COM errors throw as exceptions — wrap fallible automation in try/catch. -->
<!-- CROSS-REF: Module_DllCall.md, Module_WinAPI.md, Module_Errors.md, Module_Objects.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

| Function | Signature | Notes |
|----------|-----------|-------|
| `ComObject()` | `ComObject(CLSID [, IID])` | Create by ProgID or CLSID; optional IID for a non-IDispatch interface |
| `ComObjGet()` | `ComObjGet(Name)` | Bind to an object by moniker — e.g. `"winmgmts:"` for WMI |
| `ComObjFromPtr()` | `ComObjFromPtr(DispPtr)` | Wrap an existing `IDispatch*` into an auto-released AHK object |
| `ComCall()` | `ComCall(Index, ComObjOrPtr, Type1, Arg1, ..., RetType)` | Call vtable slot `Index` directly — for interfaces without IDispatch |
| `ComValue()` | `ComValue(VarType, Value [, Flags])` | Wrap a value with an explicit VARENUM type; add `0x4000` for ByRef |
| `ComObjArray()` | `ComObjArray(VarType, Count1 [, Count2...])` | Create a SafeArray; `.MaxIndex()`/`.MinIndex()`/index access |
| `ComObjConnect()` | `ComObjConnect(ComObj [, SinkObjectOrPrefix])` | Wire the object's outgoing events to handler methods |
| `ComObjQuery()` | `ComObjQuery(ComObj [, SID,] IID)` | QueryInterface for another interface on the same object |
| `ComObjType()` | `ComObjType(ComObj [, "Name"/"IID"/"Class"])` | Introspect the wrapped type |
| `ComObjValue()` | `ComObjValue(ComObj)` | The raw pointer/value inside the wrapper (advanced) |

### Common VARENUM types (for ComValue / ComObjArray)
| Const | Value | Meaning |
|-------|-------|---------|
| `VT_I4` | 3 | 32-bit int |
| `VT_R8` | 5 | double |
| `VT_BSTR` | 8 | string |
| `VT_DISPATCH` | 9 | IDispatch* |
| `VT_BOOL` | 11 | -1 true / 0 false |
| `VT_VARIANT` | 12 | VARIANT (SafeArray element default) |
| `VT_UNKNOWN` | 13 | IUnknown* |
| `VT_I8` | 20 | 64-bit int |
| `VT_BYREF` | 0x4000 | OR into a type to pass by reference |

## AHK V2 CONSTRAINTS

- `ComObject("ProgID")` to create; the returned wrapper auto-`Release()`s when its
  variable goes out of scope. Don't call `ObjRelease` on a wrapper — only on a raw
  pointer you obtained yourself.
- Late binding "just works": `obj.Property`, `obj.Property := x`, `obj.Method(args)` all
  route through `IDispatch::Invoke`. You do not declare signatures.
- A raw interface pointer from a `"Ptr*"` `ComCall` output is an owned reference — wrap it
  with `ComValue(13, ptr)` / `ComObjFromPtr(ptr)` (for IDispatch) or `ObjRelease(ptr)` it.
- COM is single-threaded here: a call that shows UI in the target app blocks AHK until it
  returns. Set `obj.Visible := false` and `obj.DisplayAlerts := false` for headless work.
- Iterate COM collections with a normal `for` loop — AHK uses the collection's `_NewEnum`.
- Quit/close the application object explicitly (`obj.Quit()`) for apps like Excel that
  otherwise leave an orphaned process.

✗ / ✓ pairs:

- ✗ `xl := ComObjCreate("Excel.Application")` — no such function; use `ComObject`
- ✓ `xl := ComObject("Excel.Application")`

- ✗ ignoring a `"Ptr*"` ComCall output reference — leaks a COM ref
- ✓ wrap it (`ComValue(13, p)`) or `ObjRelease(p)` when done

- ✗ `obj.Method(0x4000, &v)` to pass ByRef — wrong layer
- ✓ `obj.Method(ComValue(0x4000 | 3, &v))` — ByRef VT_I4

## TIER 1 — Create and drive an automation object (IDispatch late binding)
> COVERED: ComObject · property/method access · headless flags · Quit

```ahk
; ✓ Excel: create, configure headless, write a cell, save, quit
xl := ComObject("Excel.Application")
xl.Visible := false
xl.DisplayAlerts := false
wb := xl.Workbooks.Add()
ws := wb.Worksheets(1)
ws.Cells(1, 1).Value := "Hello from AHK"
wb.SaveAs(A_ScriptDir "\out.xlsx")
wb.Close(false)
xl.Quit()                       ; without Quit, EXCEL.EXE lingers
```

## TIER 2 — Monikers and collections: WMI
> COVERED: ComObjGet · for-loop over a COM collection · query objects

```ahk
; ✓ WMI via the winmgmts: moniker; iterate the result collection
wmi := ComObjGet("winmgmts:")
for proc in wmi.ExecQuery("SELECT Name, ProcessId FROM Win32_Process")
    if proc.Name = "notepad.exe"
        MsgBox("Notepad PID: " proc.ProcessId)
```

## TIER 3 — COM events with ComObjConnect
> COVERED: ComObjConnect · event-named sink methods · disconnect

Connect the object's outgoing interface to a sink object whose **method names match the
event names**. Disconnect by calling `ComObjConnect(obj)` with no sink.

```ahk
; ✓ Internet Explorer navigation events routed to a sink class
class BrowserEvents {
    __New() {
        this.ie := ComObject("InternetExplorer.Application")
        this.ie.Visible := true
        ComObjConnect(this.ie, this)        ; methods below are the event handlers
        this.ie.Navigate("https://example.com")
    }
    DocumentComplete(pDisp, &url) {          ; fires when a document finishes loading
        ToolTip("loaded: " url)
    }
    __Delete() {
        ComObjConnect(this.ie)               ; detach the sink before release
    }
}
```

## TIER 4 — Typed values and SafeArrays
> COVERED: ComValue · VT_BYREF · ComObjArray

```ahk
; ✓ Pass an explicit VT_I4 where an API expects a typed VARIANT
arg := ComValue(3, 42)                       ; VT_I4

; ✓ Receive a value ByRef: VT_BYREF | VT_I4
out := 0
ref := ComValue(0x4000 | 3, &out)

; ✓ Build a SafeArray of variants and fill it
arr := ComObjArray(12, 3)                     ; VT_VARIANT, 3 elements
arr[0] := "a", arr[1] := 2, arr[2] := true
loop arr.MaxIndex() + 1
    OutputDebug(arr[A_Index - 1])
```

## TIER 5 — ComCall: driving a vtable directly
> COVERED: ComCall · vtable index · QueryInterface bridge to non-IDispatch interfaces

When an interface has no `IDispatch` (most low-level COM and all WinRT), call vtable slots
by index with `ComCall`. Slots 0-2 are `IUnknown` (`QueryInterface`, `AddRef`, `Release`);
interface methods follow in IDL order. `ComCall` is `DllCall` for COM — same type strings.

```ahk
; ✓ QueryInterface for a sibling interface, then call one of its methods by index
;   (indices come from the interface's IDL/header — see Module_WinAPI.md for WinRT)
riid := Buffer(16)                            ; fill with the target IID bytes
DllCall("ole32\IIDFromString", "Str", "{....}", "Ptr", riid)
if ComCall(0, baseObj, "Ptr", riid, "Ptr*", &pNext, "Int") = 0 {   ; QueryInterface
    result := ComCall(7, pNext, "Ptr*", &out, "Int")              ; some method @ slot 7
    ObjRelease(pNext)                          ; you own this reference
}
```

## SEE ALSO

> This module does NOT cover: raw `DllCall`, `Buffer`, and `Struct` marshalling → see Module_DllCall.md
> This module does NOT cover: WinRT activation (`RoActivateInstance`) and the IInspectable ABI → see Module_WinAPI.md

- `Module_DllCall.md` — `ComCall` shares `DllCall`'s type strings; `Buffer`/`Struct` build the IIDs and structs COM passes.
- `Module_WinAPI.md` — WinRT is COM under the hood: same `ComCall`-by-vtable pattern, plus factory activation and HSTRING marshalling.
- `Module_Errors.md` — catching COM exceptions (`Error` with HRESULT/`.Extra`) and OSError patterns.
- `Module_Objects.md` — event-sink classes and `.Bind(this)` for COM callback context.
