---
name: ahk-winapi
description: >
  Windows messages, subclassing, owner-draw, DWM frame styling, and WinRT for AHK v2. Use
  when intercepting window messages, subclassing a control, applying a dark title bar / Mica /
  Acrylic / rounded corners, or calling a Windows Runtime (WinRT) API.
  TRIGGER when: user says "OnMessage", "SendMessage/PostMessage", "subclass", "WM_",
  "owner-draw", "dark title bar", "Mica/Acrylic", "rounded corners", "WinRT", "clipboard history".
  Examples: "intercept WM_NOTIFY", "dark title bar on my GUI", "Mica backdrop", "use a WinRT API"
---

# AHK v2 WinAPI, DWM & WinRT

Apply native calls to the window/message system and modern Windows APIs.

## How to use

1. Load the full reference from `Modules/Module_WinAPI.md` — messages, subclassing, owner-draw, DWM, WinRT activation.
2. Intercept messages with `OnMessage(num, cb)`; the callback is `cb(wParam, lParam, msg, hwnd)` — keep it short and re-entrancy-safe.
3. Subclass via `comctl32\SetWindowSubclass` + a `CallbackCreate` proc kept alive on a long-lived object; defer to `DefSubclassProc`.
4. Frame styling (dark title bar, Mica/Acrylic, rounded corners) is `dwmapi\DwmSetWindowAttribute`; full control theming is `Lib/DarkModeModular.ahk`.

## Quick answers

- **Bind a handler:** `OnMessage(0x4E, this.OnNotify.Bind(this))` — never an unbound method.
- **Dark title bar:** `DwmSetWindowAttribute(hwnd, 20, …, 4)` + `SetWindowTheme(hwnd, "DarkMode_Explorer", 0)`.
- **WinRT:** activate via `combase\RoGetActivationFactory`, call interfaces by vtable index with `ComCall` (0-2 IUnknown, 3-5 IInspectable).

For the DWM constants, subclass lifetime rules, and the WinRT clipboard-history example, read `Modules/Module_WinAPI.md`.
