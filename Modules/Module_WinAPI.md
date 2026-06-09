---
name: Module_WinAPI
description: 'Raw DllCall/Buffer/Struct mechanics belong in Module_DllCall.md; classic IDispatch/automation
  COM belongs in Module_COM.md. This module applies those primitives to the Windows message system, window
  subclassing, custom drawing, and the WinRT (Windows Runtime) ABI. TRIGGER when the request involves:
  OnMessage, SendMessage, PostMessage, PostThreadMessage, WM_, subclass, SetWindowSubclass, DefSubclassProc,
  WNDPROC, owner-draw, WM_PAINT, WM_DRAWITEM, NM_CUSTOMDRAW, WinRT, "Windows Runtime", IInspectable, RoActivateInstance,
  RoGetActivationFactory, HSTRING, "clipboard history", "modern Windows API", "intercept a message", "custom
  paint", "dark control", DWM, DwmSetWindowAttribute, Mica, Acrylic, "rounded corners", "title bar color",
  "dark title bar", "immersive dark mode", backdrop'
---

# Module_WinAPI

_AHK v2.0+ (typed Struct in WinRT helpers requires the v2.1-alpha.30 +Console fork)_

## API QUICK-REFERENCE

### Message functions
| Function | Signature | Notes |
|----------|-----------|-------|
| `OnMessage()` | `OnMessage(MsgNumber, Callback [, AddRemove])` | `Callback(wParam, lParam, msg, hwnd)`; `AddRemove` 1 add / -1 add-first / 0 remove |
| `SendMessage()` | `SendMessage(Msg, wParam?, lParam?, Control?, WinTitle?, ...)` | Synchronous — blocks until the target handles it; returns the reply |
| `PostMessage()` | `PostMessage(Msg, wParam?, lParam?, Control?, WinTitle?, ...)` | Asynchronous — returns 0/1 for queue success |

### Subclassing (comctl32)
| Function | Signature | Notes |
|----------|-----------|-------|
| `SetWindowSubclass` | `(hWnd, pSubclassProc, uId, dwRefData)` | `pSubclassProc` from `CallbackCreate`; `uId` distinguishes subclasses |
| `DefSubclassProc` | `(hWnd, uMsg, wParam, lParam)` | Call from inside the proc for default handling |
| `RemoveWindowSubclass` | `(hWnd, pSubclassProc, uId)` | Detach before freeing the callback |

### WinRT activation (combase.dll)
| Function | Signature | Notes |
|----------|-----------|-------|
| `RoInitialize` | `RoInitialize(initType)` | `1` = multithreaded; once per thread (or use `CoInitializeEx`) |
| `RoActivateInstance` | `RoActivateInstance(HSTRING classId, IInspectable** inst)` | Default-construct a runtime class |
| `RoGetActivationFactory` | `RoGetActivationFactory(HSTRING classId, REFIID iid, void** factory)` | Get a statics/factory interface (most common entry) |
| `WindowsCreateString` | `(PCWSTR src, UInt32 len, HSTRING* out)` | Make an HSTRING; free with `WindowsDeleteString` |
| `WindowsGetStringRawBuffer` | `(HSTRING, UInt32* len)` → `PCWSTR` | Read an HSTRING's wide-char buffer |
| `WindowsDeleteString` | `(HSTRING)` | Release an HSTRING |

### Common message constants
| Const | Value | Const | Value |
|-------|-------|-------|-------|
| `WM_PAINT` | 0x000F | `WM_COMMAND` | 0x0111 |
| `WM_SIZE` | 0x0005 | `WM_NOTIFY` | 0x004E |
| `WM_NCPAINT` | 0x0085 | `WM_DRAWITEM` | 0x002B |
| `WM_SETCURSOR` | 0x0020 | `WM_CTLCOLOREDIT` | 0x0133 |
| `WM_COPYDATA` | 0x004A | `WM_GETMINMAXINFO` | 0x0024 |

## AHK V2 CONSTRAINTS

- An `OnMessage` callback is an interrupting pseudo-thread. Do the minimum, avoid blocking
  calls (no `MsgBox` in a high-frequency handler), and guard shared state — the handler can
  fire while another thread of your script is mid-statement.
- A `CallbackCreate` pointer used as a WNDPROC/subclass proc, plus any `Buffer` it reads,
  must outlive every native call. Store both on a long-lived object; never a local that
  goes out of scope while the window lives. `RemoveWindowSubclass` + `CallbackFree` in
  `__Delete`.
- Return a value from an `OnMessage` handler to set the message reply where the message
  defines one; return nothing (or don't register) to let default processing proceed.
- WinRT is COM with extra rules: every interface pointer is reference-counted — `ObjRelease`
  what you obtain from a `"Ptr*"` output; every `HSTRING` you create needs `WindowsDeleteString`.
- WinRT vtable indices: 0-2 `IUnknown` (QueryInterface/AddRef/Release), 3-5 `IInspectable`
  (GetIids/GetRuntimeClassName/GetTrustLevel), 6+ interface methods in IDL order.

✗ / ✓ pairs:

- ✗ `OnMessage(0x4E, this.OnNotify)` — unbound method loses `this`
- ✓ `OnMessage(0x4E, this.OnNotify.Bind(this))`

- ✗ subclass proc stored in a local that returns — dangling callback, crash on next message
- ✓ store the callback on the instance; remove + free in `__Delete`

- ✗ porting the old `WinRT/` projection lib by find-replace on alpha.30 — its `ptr : 16` /
  `t : u32` fields and base mutation are removed
- ✓ direct `ComCall`-by-vtable wrappers (see `Lib/ClipboardHistory.ahk`)

## TIER 1 — Intercepting messages with OnMessage
> COVERED: OnMessage · callback signature · consuming vs. passing through

```ahk
; ✓ Watch for a control notification; keep the handler tiny
OnMessage(0x004E, OnNotify)            ; WM_NOTIFY

OnNotify(wParam, lParam, msg, hwnd) {
    code := NumGet(lParam, A_PtrSize * 2, "Int")   ; NMHDR.code
    ToolTip("notify code " code)
}
```

## TIER 2 — SendMessage / PostMessage to control other windows
> COVERED: SendMessage (sync, returns) · PostMessage (async)

```ahk
; ✓ Read a control's text length synchronously (WM_GETTEXTLENGTH)
len := SendMessage(0x000E, 0, 0, "Edit1", "ahk_class Notepad")

; ✓ Fire-and-forget a click on a button (BM_CLICK), no reply needed
PostMessage(0x00F5, 0, 0, "Button2", "My App")
```

## TIER 3 — Window subclassing for custom behavior and dark controls
> COVERED: CallbackCreate · SetWindowSubclass · DefSubclassProc · lifetime

A subclass proc intercepts every message to a window before its default handler. This is
how owner-draw and dark theming hook controls. Keep the callback and any drawing buffers
alive for the window's whole life.

```ahk
; ✓ Subclass a control; handle one message, defer the rest to DefSubclassProc
class SubclassedControl {
    __New(hCtrl) {
        this.hCtrl := hCtrl
        this.proc := CallbackCreate(this.Proc.Bind(this))   ; kept alive on the instance
        DllCall("comctl32\SetWindowSubclass", "Ptr", hCtrl, "Ptr", this.proc, "Ptr", 1, "Ptr", 0)
    }
    Proc(hWnd, uMsg, wParam, lParam, uId, ref) {
        if uMsg = 0x0020                                    ; WM_SETCURSOR — example hook
            return 1
        return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }
    __Delete() {
        DllCall("comctl32\RemoveWindowSubclass", "Ptr", this.hCtrl, "Ptr", this.proc, "Ptr", 1)
        CallbackFree(this.proc)
    }
}
```

For dark-mode GUIs, do not hand-roll this — use `Lib/DarkModeModular.ahk`, which already
subclasses and owner-draws the tricky controls. Known sharp edges it (or its `_Alpha`
copy) handles: a status bar's size grip can't be removed post-creation and must be
overpainted; MonthCal nav buttons need theme-strip + `MCM_SETCOLOR` + a `WM_PAINT`
overpaint; `PrintWindow` lies, so verify dark output against a screen capture.

## TIER 4 — WinRT: the activation pattern
> COVERED: RoGetActivationFactory · HSTRING · ComCall by vtable index · cleanup

WinRT runtime classes are activated by name into a COM interface pointer, then called by
vtable index with `ComCall`. The flow: make an `HSTRING` for the class name → get a
factory/statics interface by IID → `ComCall` its methods → `Release` everything.

```ahk
; ✓ Skeleton: activate a statics interface and call one method by vtable index
RoInit() => DllCall("combase\RoInitialize", "Int", 1)

CreateHString(str) {
    DllCall("combase\WindowsCreateString", "WStr", str, "UInt", StrLen(str), "Ptr*", &h := 0)
    return h
}

IIDFromString(guid) {
    iid := Buffer(16)
    DllCall("ole32\IIDFromString", "WStr", guid, "Ptr", iid)
    return iid
}

GetActivationFactory(className, iidString) {
    hClass := CreateHString(className)
    iid := IIDFromString(iidString)
    hr := DllCall("combase\RoGetActivationFactory", "Ptr", hClass, "Ptr", iid, "Ptr*", &factory := 0, "UInt")
    DllCall("combase\WindowsDeleteString", "Ptr", hClass)
    if hr != 0
        throw OSError(hr, -1, "RoGetActivationFactory failed for " className)
    return factory                                   ; caller ObjReleases this
}
```

## TIER 5 — A real WinRT call: clipboard history
> COVERED: verified IID/vtable indices · IsHistoryEnabled · async results · the Lib reference

Activation class `"Windows.ApplicationModel.DataTransfer.Clipboard"` exposes
`IClipboardStatics2` (IID `{d2ac1b6a-d29f-554b-b303-f0452345fe02}`). Its methods (past the
IInspectable slots): 6 `GetHistoryItemsAsync`, 7 `ClearHistory`, 8 `DeleteItemFromHistory`,
9 `SetHistoryItemAsContent`, **10 `IsHistoryEnabled`**, 11 `IsRoamingEnabled`.

```ahk
; ✓ Is clipboard history turned on? (synchronous boolean getter at vtable index 10)
RoInit()
statics := GetActivationFactory(
    "Windows.ApplicationModel.DataTransfer.Clipboard",
    "{d2ac1b6a-d29f-554b-b303-f0452345fe02}")
ComCall(10, statics, "Int*", &enabled := 0)          ; IClipboardStatics2::IsHistoryEnabled
ObjRelease(statics)
MsgBox("clipboard history enabled: " enabled)
```

Async getters (e.g. `GetHistoryItemsAsync`) return an `IAsyncOperation<T>`: set a
`put_Completed` (vtable 6) delegate, or QueryInterface to `IAsyncInfo` and poll
`get_Status` (0 Started, 1 Completed, 2 Canceled, 3 Error) before `GetResults` (vtable 8).

Do not rebuild this from scratch. `Lib/ClipboardHistory.ahk` (and the fuller
`ClipboardHistory_Full.ahk`) are verified direct-`ComCall` wrappers — `IsEnabled`,
`Count`, `[index]`, `GetText`, `SetItemAsContent`, `DeleteItem`, `Clear`, and `for item in
ClipboardHistory` — that already handle HSTRING lifetime, async polling, and ref-counting.
Include only one (both define `class ClipboardHistory`).

## TIER 6 — DWM: dark title bar, Mica/Acrylic, rounded corners
> COVERED: DwmSetWindowAttribute · immersive dark mode · system backdrop · corner preference · caption colors

DWM styles the window **frame** — title bar, border, and backdrop — the part owner-draw
and `SetWindowTheme` cannot reach. Each effect is one `DwmSetWindowAttribute` call with an
attribute id and a 4-byte value, and each is version-gated. Frame styling complements, but
does not replace, control theming (`Lib/DarkModeModular.ahk`).

```ahk
class DWM {
    static USE_IMMERSIVE_DARK_MODE := 20      ; attribute was 19 before Win10 build 19041
    static WINDOW_CORNER_PREFERENCE := 33
    static BORDER_COLOR := 34
    static CAPTION_COLOR := 35
    static TEXT_COLOR := 36
    static SYSTEMBACKDROP_TYPE := 38

    static SBT_NONE := 1, SBT_MICA := 2, SBT_ACRYLIC := 3, SBT_MICA_ALT := 4
    static CORNER_DEFAULT := 0, CORNER_SHARP := 1, CORNER_ROUND := 2, CORNER_SMALL := 3

    static IsWin10 => VerCompare(A_OSVersion, "10.0.10240") >= 0
    static IsWin11 => VerCompare(A_OSVersion, "10.0.22000") >= 0

    ; Set one 32-bit DWM attribute; throw OSError on a non-zero HRESULT
    static Set(hWnd, attr, value) {
        buf := Buffer(4)
        NumPut("UInt", value, buf)
        hr := DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd, "UInt", attr, "Ptr", buf, "UInt", 4, "Int")
        if hr != 0
            throw OSError(hr, -1, Format("DwmSetWindowAttribute({}) failed", attr))
    }
}
```

Dark title bar (Win10+) — pair the frame attribute with the control theme:

```ahk
DWM.Set(myGui.Hwnd, DWM.USE_IMMERSIVE_DARK_MODE, 1)
DllCall("uxtheme\SetWindowTheme", "Ptr", myGui.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
```

Mica backdrop + rounded corners + a custom caption color (Win11+). DWM colors are
`COLORREF` (`0x00BBGGRR`), not HTML `0xRRGGBB`:

```ahk
if DWM.IsWin11 {
    DWM.Set(myGui.Hwnd, DWM.USE_IMMERSIVE_DARK_MODE, 1)
    DWM.Set(myGui.Hwnd, DWM.SYSTEMBACKDROP_TYPE, DWM.SBT_MICA)        ; SBT_ACRYLIC for blur
    DWM.Set(myGui.Hwnd, DWM.WINDOW_CORNER_PREFERENCE, DWM.CORNER_ROUND)
    DWM.Set(myGui.Hwnd, DWM.CAPTION_COLOR, 0x302D2D)                  ; 0x00BBGGRR
    myGui.BackColor := "Default"                                     ; let the backdrop show through
}
```

For Acrylic the window needs its frame extended into the client area — pass a `MARGINS`
struct of four `-1` ints (the "sheet of glass" form) before setting `SBT_ACRYLIC`:

```ahk
margins := Buffer(16, 0)
loop 4
    NumPut("Int", -1, margins, (A_Index - 1) * 4)
DllCall("dwmapi\DwmExtendFrameIntoClientArea", "Ptr", myGui.Hwnd, "Ptr", margins, "Int")
```

## SEE ALSO

> This module does NOT cover: raw `DllCall`/`Buffer`/`Struct` mechanics → see Module_DllCall.md
> This module does NOT cover: IDispatch automation, COM events, and SafeArrays → see Module_COM.md
> This module does NOT cover: standard GUI control creation and layout → see Module_GUI.md

- `Module_DllCall.md` — the `CallbackCreate`, `Buffer`, IID-building, and type-string foundation every example here relies on.
- `Module_COM.md` — WinRT shares the `ComCall`-by-vtable and reference-counting model; classic automation uses the IDispatch shortcut instead.
- `Module_GUI.md` — `Gui`/control creation and `OnEvent`; subclassing and owner-draw extend those controls. Dark theming lives in `Lib/DarkModeModular.ahk`.
- `Module_Errors.md` — `OSError(hr)` and HRESULT handling for failed activation/`ComCall`.
