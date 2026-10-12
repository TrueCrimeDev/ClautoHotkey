---
name: Module_COM
description: 'Classic COM in AHK v2 — IDispatch late-binding automation (Excel, Word, WMI, Shell),
  ComObjConnect event sinks, ComValue/VARIANT typing, SafeArrays, and direct vtable ComCall.
  TRIGGER when the request involves: COM, ComObject, ComObjGet, ComCall, ComValue, ComObjArray,
  ComObjConnect, ComObjQuery, ComObjFromPtr, ComObjActive, IDispatch, IUnknown, vtable,
  "Excel automation", "Word automation", "WMI", "WQL", "winmgmts", "Shell.Application",
  "Internet Explorer", "COM event", "SafeArray", "VARIANT", "automation object", "CLSID", "ProgID",
  "QueryInterface", "zombie Excel process", "attach to running instance", "bulk Excel write".
  Not covered: raw DllCall, Buffer and Struct marshalling - see Module_DllCall.md; WinRT activation
  and the IInspectable ABI - see Module_WinAPI.md; clipboard, Run/RunWait, process and registry
  work - see Module_System.md.'
---

# Module_COM

_AHK v2.0+ (the `"Void"` ComCall return type requires v2.1-alpha.30 — upstream or the +Console fork)_

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
- alpha.30: passing a class object as a `ComCall` argument is removed — pass a `Buffer`, a
  `Struct`, or an explicit `.Ptr`.
- alpha.30 adds the `"Void"` return type for `ComCall` (as for `DllCall`/`CallbackCreate`):
  the call runs but yields blank-unset instead of a fabricated numeric return. Omitting
  `RetType` still means HRESULT, which throws on a failing HRESULT.
- An output `&var` passed to `ComCall` must already hold a value — write `"Ptr*", &p := 0`.
  On alpha.30 an unassigned VarRef throws before the call runs.

✗ / ✓ pairs:

- ✗ `xl := ComObjCreate("Excel.Application")` — no such function; use `ComObject`
- ✓ `xl := ComObject("Excel.Application")`

- ✗ ignoring a `"Ptr*"` ComCall output reference — leaks a COM ref
- ✓ wrap it (`ComValue(13, p)`) or `ObjRelease(p)` when done

- ✗ `obj.Method(ComValue(0x4000 | 3, &v))` to pass ByRef — `&v` is an AHK VarRef, not a
  memory address; VT_BYREF needs a real pointer
- ✓ `buf := Buffer(4, 0)` then `obj.Method(ComValue(0x4000 | 3, buf.Ptr))` — ByRef VT_I4;
  read the written-back value with `NumGet(buf, 0, "Int")`

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
event names**. Each handler receives the event's documented parameters **plus the COM
object itself as a trailing final parameter** — declare that extra parameter (or make the
handler variadic) or the dispatch throws when the event fires. An event parameter the host
passes ByRef (documented `ByRef`/`out`, e.g. Excel's `Cancel`) is declared `&Param` in the
sink method; writing to it is how you answer the host. Disconnect by calling
`ComObjConnect(obj)` with no sink.

Pick a host that still exists. `InternetExplorer.Application` was retired in 2023 and no
longer activates reliably, so it is not a usable automation target — Excel's `Application`
and `Workbook` sinks, or `Shell.Application`, are the live equivalents.

```ahk
; ✓ Excel workbook events routed to a sink class
class WorkbookEvents {
    __New() {
        this.xl := ComObject("Excel.Application")
        this.xl.Visible := true
        this.wb := this.xl.Workbooks.Add()
        ComObjConnect(this.wb, this)         ; methods below are the event handlers
    }
    SheetChange(sh, rng, wbObj) {            ; event params + the COM object as final param
        ToolTip("changed: " rng.Address)
    }
    BeforeClose(&Cancel, wbObj) {            ; ByRef out-param + the COM object as final param
        Cancel := true                       ; write back through the ref to veto the close
    }
    __Delete() {
        ComObjConnect(this.wb)               ; detach the sink before release
    }
}
```

## TIER 4 — Typed values and SafeArrays
> COVERED: ComValue · VT_BYREF · ComObjArray

```ahk
; ✓ Pass an explicit VT_I4 where an API expects a typed VARIANT
arg := ComValue(3, 42)                       ; VT_I4

; ✓ Receive a value ByRef: VT_BYREF | VT_I4 wants a memory ADDRESS — back it with a Buffer
buf := Buffer(4, 0)                          ; 4 bytes for the 32-bit int
ref := ComValue(0x4000 | 3, buf.Ptr)         ; pass ref where the method takes the VARIANT
; ... after the call, read what the method wrote back:
out := NumGet(buf, 0, "Int")

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
if ComCall(0, baseObj, "Ptr", riid, "Ptr*", &pNext := 0, "Int") = 0 {   ; QueryInterface
    result := ComCall(7, pNext, "Ptr*", &out := 0, "Int")         ; some method @ slot 7
    ObjRelease(pNext)                          ; you own this reference
}
```

## TIER 6 — Owned versus attached instances, and teardown
> COVERED: ComObject · ComObjActive · try/finally · Quit · reference release

Two lifecycles look alike and must not be mixed. A script that **created** the application
with `ComObject` owns it and is responsible for `Quit()`. A script that **attached** to a
running instance with `ComObjActive` borrowed the user's session: it releases its reference and
never calls `Quit()`.

Order matters for the owner. Dropping the last reference does not tell Excel to exit, so a
hidden `EXCEL.EXE` stays alive (locking files) unless `Quit()` runs first. Put the teardown in
`finally` so an exception on the way out cannot skip it, and guard each call because a COM
failure throws an ordinary catchable `Error`.

```ahk
OwnedLifecycle() {
    xl := ""
    wb := ""
    try {
        xl := ComObject("Excel.Application")
        xl.Visible := false
        wb := xl.Workbooks.Add()
        wb.ActiveSheet.Range("A1").Value := "Hello"
    } catch Error as err {
        Print("COM failed: {}", err.Message)
    } finally {
        if wb
            try wb.Close(false)
        if xl
            try xl.Quit()                    ; ask the host to exit BEFORE dropping refs
        wb := ""
        xl := ""
    }
}

AttachedLifecycle() {
    try {
        xl := ComObjActive("Excel.Application")   ; the user's running session
        xl.ActiveSheet.Range("A1").Value := "Updated"
        ; xl.Quit() here would close the user's own Excel window
    } catch Error as err {
        Print("no running Excel: {}", err.Message)
    }
}
```

Office object models also accept locale-independent numeric constants — prefer
`xl.Calculation := -4135` (`xlCalculationManual`) over a localized name string.

## TIER 7 — Bulk transfer with a 2D SafeArray
> COVERED: ComObjArray with two dimensions · Range.Value · restoring application state

Every property access on a COM object crosses a process boundary. Writing 10,000 cells one
`Cells(i, 1).Value := v` at a time is 10,000 crossings; assigning one SafeArray to
`Range.Value` is one. SafeArray indices are **0-based** here, unlike an AHK `Array`. A 2D
array read back from `Range.Value` is 1-based in each dimension — use
`arr.MinIndex(dim)` and `arr.MaxIndex(dim)` rather than assuming either.

```ahk
WriteMapToExcel(data) {
    xl := ComObject("Excel.Application")
    try {
        xl.ScreenUpdating := false
        xl.Calculation := -4135                 ; xlCalculationManual
        sheet := xl.Workbooks.Add().ActiveSheet

        block := ComObjArray(12, data.Count, 2) ; VT_VARIANT, rows x columns
        row := 0
        for key, val in data {
            block[row, 0] := key
            block[row, 1] := val
            row++
        }
        sheet.Range("A1:B" data.Count).Value := block   ; single crossing
    } finally {
        xl.Calculation := -4105                 ; xlCalculationAutomatic
        xl.ScreenUpdating := true
        xl.Visible := true                      ; hand the workbook to the user
    }
}
```

Leaving `ScreenUpdating` or `Calculation` changed after an error makes the workbook look frozen,
which is why the restore sits in `finally`.

## TIER 8 — WMI results into a Map
> COVERED: winmgmts moniker with impersonation · WQL column lists · Map.Has

Service, hardware and many process queries need the impersonation level in the moniker. Select
only the columns you read — `SELECT *` marshals every property. Copy the result into a `Map` so
later lookups are plain AHK, and test with `Has()` before indexing (a missing key throws).
Wrap the connection in `try`: WMI availability and permissions vary by machine.

```ahk
RunningServices() {
    services := Map()
    try {
        wmi := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
        for svc in wmi.ExecQuery("SELECT Name, DisplayName FROM Win32_Service WHERE State='Running'")
            services[svc.Name] := svc.DisplayName
    } catch Error as err {
        Print("WMI query failed: {}", err.Message)
    }
    return services
}

running := RunningServices()
if running.Has("Spooler")
    Print("Print spooler is running: {}", running["Spooler"])
```

Starting, stopping or reconfiguring a service is a state change that needs an elevated
process (`A_IsAdmin`); see `Module_System.md` for the guard and for process, registry and
clipboard work that is not COM.

## SEE ALSO

> This module does NOT cover: raw `DllCall`, `Buffer`, and `Struct` marshalling → see Module_DllCall.md
> This module does NOT cover: WinRT activation (`RoActivateInstance`) and the IInspectable ABI → see Module_WinAPI.md
> This module does NOT cover: clipboard, process, registry and `Run`/`RunWait` → see Module_System.md

- `Module_System.md` — clipboard, `Run`/`RunWait` exit codes, process and registry operations that need no COM; the `A_IsAdmin` guard for elevated WMI changes.
- `Module_DllCall.md` — `ComCall` shares `DllCall`'s type strings; `Buffer`/`Struct` build the IIDs and structs COM passes.
- `Module_WinAPI.md` — WinRT is COM under the hood: same `ComCall`-by-vtable pattern, plus factory activation and HSTRING marshalling.
- `Module_Errors.md` — catching COM exceptions (`Error` with HRESULT/`.Extra`) and OSError patterns.
- `Module_Objects.md` — event-sink classes and `.Bind(this)` for COM callback context.

<!-- Adapted in part from hsinming/AutoHotkey-V2-vibe-coding-tools (no license file upstream); see THIRD-PARTY.md -->
