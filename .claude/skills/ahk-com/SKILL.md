---
name: ahk-com
description: >
  COM automation and interop for AHK v2 — driving Excel / Word / WMI / Internet Explorer via
  IDispatch, COM events, ComValue / SafeArrays, and direct vtable ComCall. Use when automating
  another application, wiring COM events, or calling a COM interface.
  TRIGGER when: user says "automate Excel/Word", "COM object", "ComObject", "ComCall",
  "WMI query", "COM event", "IDispatch", "SafeArray", "ComValue", "VARIANT".
  Examples: "automate Excel from AHK", "query WMI for processes", "hook IE navigation events"
---

# AHK v2 COM Automation

Drive another application's object model from AHK.

## How to use

1. Load the full reference from `Modules/Module_COM.md` — creation, events, ComValue, SafeArrays, vtable ComCall.
2. Create with `ComObject("ProgID")` (never the removed `ComObjCreate`); the wrapper auto-releases on scope exit.
3. For headless work set `obj.Visible := false` / `obj.DisplayAlerts := false`, and `obj.Quit()` apps like Excel.
4. For COM events, `ComObjConnect(obj, sink)` where the sink's method names match the event names.

## Quick answers

- **Create:** `xl := ComObject("Excel.Application")`; moniker bind: `ComObjGet("winmgmts:")`.
- **Typed value / ByRef:** `ComValue(3, n)` (VT_I4); `ComValue(0x4000 | 3, &out)` (ByRef).
- **No IDispatch (low-level / WinRT):** call vtable slots with `ComCall(index, obj, ...)` — see `Module_WinAPI.md` for WinRT.

For events, SafeArrays, the VARENUM table, and cleanup rules, read `Modules/Module_COM.md`.
