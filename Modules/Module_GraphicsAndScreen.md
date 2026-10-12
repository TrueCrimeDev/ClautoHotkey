---
name: Module_GraphicsAndScreen
description: 'Screen coordinates, pixels, images and capture in AHK v2 - CoordMode rules and defaults, PixelGetColor,
  PixelSearch and ImageSearch (option prefixes, variation, errors, polling), the MonitorGet family,
  virtual-screen bounds and display changes, DPI awareness and per-monitor DPI, a DIB plus GDI+ ScreenGrab
  class for fast pixel reads and PNG capture, and click-through overlay windows for debugging. TRIGGER when
  the request involves: PixelGetColor, PixelSearch, ImageSearch, CoordMode, MouseGetPos coordinates,
  MonitorGet, MonitorGetWorkArea, MonitorGetCount, A_ScreenWidth, A_ScreenDPI, GetDpiForWindow, DPIScale,
  BitBlt, GDI, GDI+, GdiplusStartup, CreateDIBSection, screenshot, "screen capture", "save a PNG", "find an
  image on screen", "pixel color", "multi-monitor", "work area", "virtual screen", "DPI scaling", "high DPI",
  "transparent overlay", "click-through window", "screen resolution", "visual automation". Not covered: Gui
  construction and layout - see Module_GUI.md; raw DllCall and Buffer rules - see Module_DllCall.md; moving
  and finding windows - see Module_WindowAndControl.md; Click and Send - see Module_InputAndHotkeys.md;
  dark-mode theming belongs to the dark-mode library (Lib/_Dark.ahk in this repo), not this module.'
---

# Module_GraphicsAndScreen

Targets AutoHotkey v2.1-alpha.33+Console. Blocks that capture the screen or create windows are parser
checked only; run them yourself when you want the effect.

## Rules that decide most bugs

- `CoordMode` defaults to Client for `Mouse`, `Pixel`, `ToolTip`, `Caret` and `Menu`: coordinates are
  relative to the active window's client area. The setting is per thread and never per function, so a
  helper inherits whatever its caller's thread has. Each new thread (hotkey, timer, menu item, callback)
  starts again from the default unless you changed it during script startup, so set the modes once in the
  auto-execute section:

```ahk
#Requires AutoHotkey v2.1-alpha.30

CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")
```

  `CoordMode("Pixel")` with no second argument means `"Screen"`, and the function returns the previous
  setting, so `old := CoordMode("Pixel", "Screen")` followed by `CoordMode("Pixel", old)` restores it.
  `A_CoordModePixel` and its siblings hold the current values. `WinMove`, `WinGetPos` and `ControlClick`
  are unaffected by CoordMode.
- `A_ScreenWidth` and `A_ScreenHeight` describe the primary monitor only. Use `MonitorGet` for any other
  monitor, and `SysGet(78)` and `SysGet(79)` for the whole virtual screen.
- `PixelGetColor` returns a hex string `"0xRRGGBB"` (always RGB order, no alpha). It throws `OSError` on
  failure. Because numeric strings compare numerically, `PixelGetColor(x, y) = 0xFF0000` is true when the
  pixel is pure red; both the hex-string and the integer comparison work. Convert with `Integer()` for
  bit arithmetic.
- `PixelSearch` and `ImageSearch` return 1 or 0 and blank the output variables when nothing is found.
  There is no `ErrorLevel`. `PixelSearch` takes the colour as `0xRRGGBB` and an optional `Variation` 0-255
  per channel; it throws `OSError` when it cannot search. `ImageSearch` throws `ValueError` for a bad option
  or an image it cannot load, so a missing file is already loud.
- All three work on what is visible: a region hidden behind another window cannot be searched, and many DirectX and full-screen surfaces return black or wrong colours. For
  `PixelGetColor`, mode `"Alt"` (about 10 percent slower) or `"Slow"` (about three times slower) sometimes
  fix that.
- `ImageSearch` options are a prefix of the file string, never extra arguments: `"*20 *Trans0x000000 file.png"`.
  `*n` allows n shades of variation per channel, `*TransN` makes one image colour match anything,
  `*w100 *h-1` rescales (negative one keeps the aspect ratio), `*Icon2` picks an icon group, and
  `"HBITMAP:*" handle` searches for a bitmap you already hold. A match needs the same size on screen as
  the loaded image, which is the main DPI trap (see below).
- Search cost grows with the region area, and the scan runs in the direction implied by the order of the
  corner arguments (X1 greater than X2 scans right to left). Narrow the region, and sleep between polls.

## Pixels and images

```ahk
#Requires AutoHotkey v2.1-alpha.30

CoordMode("Pixel", "Screen")

; True when two RGB values are within `variation` shades on every channel
ColorNear(a, b, variation := 0) {
    a := Integer(a)
    b := Integer(b)
    return Abs(((a >> 16) & 0xFF) - ((b >> 16) & 0xFF)) <= variation
        && Abs(((a >> 8) & 0xFF) - ((b >> 8) & 0xFF)) <= variation
        && Abs((a & 0xFF) - (b & 0xFF)) <= variation
}

WaitForPixel(x, y, rgb, seconds := 5, variation := 8) {
    deadline := A_TickCount + seconds * 1000
    while (A_TickCount < deadline) {
        if ColorNear(PixelGetColor(x, y), rgb, variation) {
            return true
        }
        Sleep(50)
    }
    return false
}

; [x, y] of the first match, or an empty Array
FindImage(file, left, top, right, bottom, tolerance := 20) {
    if !FileExist(file) {
        throw Error("image file not found: " file)
    }
    if ImageSearch(&x, &y, left, top, right, bottom, "*" tolerance " " file) {
        return [x, y]
    }
    return []
}

; Search only inside one window, in screen coordinates
FindImageInWindow(file, hwnd, tolerance := 20) {
    WinGetPos(&wx, &wy, &ww, &wh, hwnd)
    return FindImage(file, wx, wy, wx + ww, wy + wh, tolerance)
}

WaitForImage(file, hwnd, seconds := 10, tolerance := 20) {
    deadline := A_TickCount + seconds * 1000
    while (A_TickCount < deadline) {
        hit := FindImageInWindow(file, hwnd, tolerance)
        if (hit.Length > 0) {
            return hit
        }
        Sleep(250)
    }
    return []
}

; Rescale a template that was captured at 100 percent for a 150 percent display
ScaledImageOption(file, templateWidth, dpi := 0) {
    scale := (dpi ? dpi : A_ScreenDPI) / 96
    return "*w" Round(templateWidth * scale) " *h-1 " file
}
```

- `WinGetPos` gives the outer rectangle, including the invisible resize frame on Windows 10 and 11. For a
  tight search area use `WinGetClientPos`.
- Tolerance costs time and false positives. Start at `*10`, use around `*20` for anti-aliased UI, and
  benchmark anything above `*50`.
- To click what you found, remember that `Click` and `MouseMove` follow the Mouse mode, not the Pixel
  mode; set both to `"Screen"` when you pass screen coordinates (see Module_InputAndHotkeys.md).
- Prefer a window-specific control or UI Automation (Module_UIA.md) to image matching when the target
  exposes controls; images break with theme, scale and font changes.

## Monitors, virtual screen, DPI

```ahk
#Requires AutoHotkey v2.1-alpha.30

; Array of Maps, one per monitor, rectangles as [left, top, right, bottom]
GetMonitors() {
    list := []
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        MonitorGetWorkArea(A_Index, &wl, &wt, &wr, &wb)
        info := Map()
        info["index"] := A_Index
        info["bounds"] := [l, t, r, b]
        info["work"] := [wl, wt, wr, wb]
        list.Push(info)
    }
    return list
}

MonitorAtPoint(x, y) {
    for info in GetMonitors() {
        b := info["bounds"]
        if (x >= b[1] && x < b[3] && y >= b[2] && y < b[4]) {
            return info["index"]
        }
    }
    return 0
}

; The rectangle covering every monitor
VirtualScreen(&left, &top, &width, &height) {
    left := SysGet(76)
    top := SysGet(77)
    width := SysGet(78)
    height := SysGet(79)
}

; Search each monitor with its own bounds
FindOnAnyMonitor(file, tolerance := 20) {
    CoordMode("Pixel", "Screen")
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if ImageSearch(&x, &y, l, t, r, b, "*" tolerance " " file) {
            return [x, y, A_Index]
        }
    }
    return []
}

; Centre a window in a monitor's work area (taskbar excluded)
CenterInWorkArea(hwnd, monitorN) {
    MonitorGetWorkArea(monitorN, &l, &t, &r, &b)
    WinGetPos(, , &w, &h, hwnd)
    WinMove(l + ((r - l) - w) // 2, t + ((b - t) - h) // 2, , , hwnd)
}

; Per-monitor DPI of a window; falls back to the system DPI
WindowDpi(hwnd) {
    dpi := 0
    try {
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", hwnd, "UInt")
    } catch Error {
        return A_ScreenDPI
    }
    return dpi ? dpi : A_ScreenDPI
}

; A point authored for a reference resolution, mapped onto one monitor
ScaleFromReference(refX, refY, refW := 1920, refH := 1080, monitorN := 0) {
    if !monitorN {
        monitorN := MonitorGetPrimary()
    }
    MonitorGet(monitorN, &l, &t, &r, &b)
    return [l + Round(refX * (r - l) / refW), t + Round(refY * (b - t) / refH)]
}

; A position inside a window's client area given as fractions, in screen coordinates
ClientPoint(hwnd, fracX, fracY) {
    WinGetClientPos(&x, &y, &w, &h, hwnd)
    return [x + Round(w * fracX), y + Round(h * fracY)]
}

monitorCache := GetMonitors()

RefreshMonitors(wParam, lParam, msg, hwnd) {
    global monitorCache
    monitorCache := GetMonitors()
}
OnMessage(0x007E, RefreshMonitors)
```

- Monitor layout changes at runtime (plug, unplug, resolution, taskbar moves), so a cache needs the
  `WM_DISPLAYCHANGE` refresh above; `MonitorGet` itself is cheap. Monitor numbers are not stable across
  reconfiguration.
- `MonitorGet` bounds are the full monitor; `MonitorGetWorkArea` excludes the taskbar and docked bars.
  Right and bottom are exclusive, so a point is inside when `x < right`.
- AutoHotkey v2 is DPI aware: screen, window and mouse coordinates are physical pixels, so automation
  needs no `A_ScreenDPI` conversion. DPI matters in three places: a Gui, whose sizes are logical units
  multiplied by `A_ScreenDPI / 96` unless it is created with `-DPIScale`; image templates captured at a
  different scale; and mixed-DPI setups, where `A_ScreenDPI` is the system DPI at startup and a window on
  another monitor can differ (use `GetDpiForWindow`). Module_GUI.md covers keeping Gui and `WinMove`
  units apart.
- Reference-resolution scaling is only an approximation of layout that really changes between
  resolutions. Prefer anchoring to a window or control and using fractions of its client area.

## Fast pixel reads and PNG capture

`PixelGetColor` performs a screen read per call. When you need many pixels, or a file, copy the region
once into a device-independent bitmap and read the memory. The class owns the GDI objects, has no
callbacks, so `__Delete` does run; `Dispose()` is still available for deterministic cleanup. GDI+ is
started once and left running; skipping `GdiplusShutdown` is deliberate (the repo's
`Tools/CaptureWindow.ahk` found that shutting down in a short-lived process crashes on exit, and the
process teardown reclaims it).

```ahk
#Requires AutoHotkey v2.1-alpha.30

class ScreenGrab {
    static token := 0

    static StartGdiplus() {
        if ScreenGrab.token {
            return
        }
        input := Buffer(24, 0)
        NumPut("UInt", 1, input, 0)
        token := 0
        status := DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", input, "Ptr", 0, "Int")
        if status {
            throw OSError("GdiplusStartup failed: " status)
        }
        ScreenGrab.token := token
    }

    __New(width, height) {
        ScreenGrab.StartGdiplus()
        this.w := width
        this.h := height
        header := Buffer(40, 0)
        NumPut("UInt", 40, header, 0)
        NumPut("Int", width, header, 4)
        NumPut("Int", -height, header, 8)
        NumPut("UShort", 1, header, 12)
        NumPut("UShort", 32, header, 14)
        screenDC := DllCall("GetDC", "Ptr", 0, "Ptr")
        this.dc := DllCall("CreateCompatibleDC", "Ptr", screenDC, "Ptr")
        bits := 0
        this.bmp := DllCall("CreateDIBSection", "Ptr", screenDC, "Ptr", header, "UInt", 0
            , "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", screenDC)
        if !this.bmp {
            DllCall("DeleteDC", "Ptr", this.dc)
            this.dc := 0
            throw OSError("CreateDIBSection failed")
        }
        this.bits := bits
        this.previous := DllCall("SelectObject", "Ptr", this.dc, "Ptr", this.bmp, "Ptr")
    }

    ; Copy a screen rectangle (screen coordinates, may be negative) into the bitmap.
    ; CAPTUREBLT (0x40000000) includes layered windows such as overlays.
    Grab(srcX, srcY) {
        screenDC := DllCall("GetDC", "Ptr", 0, "Ptr")
        ok := DllCall("BitBlt", "Ptr", this.dc, "Int", 0, "Int", 0, "Int", this.w, "Int", this.h
            , "Ptr", screenDC, "Int", srcX, "Int", srcY, "UInt", 0x40CC0020, "Int")
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", screenDC)
        if !ok {
            throw OSError("BitBlt failed")
        }
    }

    ; RGB of a pixel as an Integer, 0xRRGGBB; x and y are relative to the grabbed region
    Pixel(x, y) {
        if (x < 0 || y < 0 || x >= this.w || y >= this.h) {
            throw ValueError("pixel outside the grab", , x "," y)
        }
        return NumGet(this.bits, (y * this.w + x) * 4, "UInt") & 0xFFFFFF
    }

    Save(path) {
        bitmap := 0
        status := DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", this.bmp, "Ptr", 0
            , "Ptr*", &bitmap, "Int")
        if status {
            throw OSError("GdipCreateBitmapFromHBITMAP status " status)
        }
        clsid := Buffer(16, 0)
        DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)
        status := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", bitmap, "WStr", path, "Ptr", clsid
            , "Ptr", 0, "Int")
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
        if status {
            throw OSError("GdipSaveImageToFile status " status)
        }
    }

    Dispose() {
        if this.dc {
            DllCall("SelectObject", "Ptr", this.dc, "Ptr", this.previous)
            DllCall("DeleteObject", "Ptr", this.bmp)
            DllCall("DeleteDC", "Ptr", this.dc)
            this.dc := 0
            this.bmp := 0
        }
    }

    __Delete() {
        this.Dispose()
    }
}

; Whole virtual screen to a PNG, then sample a pixel without another screen read
CaptureDesktop(path) {
    left := SysGet(76)
    top := SysGet(77)
    grab := ScreenGrab(SysGet(78), SysGet(79))
    grab.Grab(left, top)
    grab.Save(path)
    return grab
}
```

- Verified on this build with a synthetic bitmap: the pixel layout is BGRA, so `NumGet(..., "UInt")` is
  `0xAARRGGBB` and `& 0xFFFFFF` yields RGB; saving through `GdipCreateBitmapFromHBITMAP` produces an
  opaque PNG even though `BitBlt` leaves the alpha bytes at zero.
- The bitmap is top-down (negative height in the header), so row 0 is the top of the region.
- GDI+ calls return a status (0 is Ok); check it, as the class does. `GdipSaveImageToFile` needs the
  encoder CLSID: PNG is `{557CF406-1A04-11D3-9A73-0000F81EF32E}`, JPEG is `{557CF401-1A04-11D3-9A73-0000F81EF32E}`.
- `BitBlt` from the screen cannot see a window that is covered or minimised. To capture a specific window
  even when occluded, use `PrintWindow` with `PW_RENDERFULLCONTENT` (2); `Tools/CaptureWindow.ahk` in this
  repository does that, crops to the visible frame, and is the reference to copy.
- Always release GDI handles you create: `DeleteObject` for bitmaps, `DeleteDC` for memory DCs,
  `ReleaseDC` for `GetDC`. A DC that still has your bitmap selected must be deselected first, as in `Dispose`.
- Raw DllCall types, Buffer lifetime and `NumGet` details: Module_DllCall.md.

## Debug overlay

A transparent, always-on-top, click-through window is the quickest way to see where a search looked and
what it found. `-DPIScale` is required: without it every coordinate you pass is multiplied by the DPI
scale, and the overlay lands in the wrong place on a scaled display. Controls inside the window are
positioned relative to the window, so subtract the window origin from screen coordinates.

```ahk
#Requires AutoHotkey v2.1-alpha.30

class ScreenOverlay {
    __New(left, top, width, height, alpha := 200) {
        this.left := left
        this.top := top
        this.alpha := alpha
        this.key := "000001"
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20")
        this.gui.BackColor := this.key
        this.gui.Show(Format("x{} y{} w{} h{} NoActivate", left, top, width, height))
        WinSetTransColor(this.key " " alpha, this.gui)
    }

    Bar(x, y, w, h, color) {
        this.gui.AddText(Format("x{} y{} w{} h{} Background{}", x - this.left, y - this.top, w, h, color))
    }

    ; Hollow rectangle in screen coordinates
    Frame(x, y, w, h, color := "FF0000", thickness := 3) {
        this.Bar(x, y, w, thickness, color)
        this.Bar(x, y + h - thickness, w, thickness, color)
        this.Bar(x, y, thickness, h, color)
        this.Bar(x + w - thickness, y, thickness, h, color)
    }

    Cross(x, y, color := "FFFF00", arm := 20) {
        this.Bar(x - arm // 2, y - 1, arm, 3, color)
        this.Bar(x - 1, y - arm // 2, 3, arm, color)
    }

    ; Remove the overlay after a delay; the one-shot timer releases its reference when it fires
    DisposeAfter(ms) {
        SetTimer(this.Dispose.Bind(this), -ms)
    }

    Dispose() {
        if this.gui {
            this.gui.Destroy()
            this.gui := ""
        }
    }
}

; Show where a scan looked, then outline a hit
MarkSearch(file, left, top, right, bottom) {
    CoordMode("Pixel", "Screen")
    overlay := ScreenOverlay(left, top, right - left, bottom - top)
    overlay.Frame(left, top, right - left, bottom - top, "00FF00", 2)
    if ImageSearch(&x, &y, left, top, right, bottom, "*20 " file) {
        overlay.Frame(x - 4, y - 4, 48, 48, "FF0000")
        overlay.Cross(x, y)
    }
    overlay.DisposeAfter(3000)
}
```

- `WinSetTransColor` makes only the key colour invisible; controls drawn in other colours stay visible.
  `WinSetTransparent` fades the entire window, controls included.
- `+E0x20` (`WS_EX_TRANSPARENT`) lets mouse input fall through. Keep the key colour out of anything you
  draw, since every pixel of that colour is both invisible and click-through.
- The GDI capture (`CAPTUREBLT`) sees layered overlays. Dispose the overlay before a `Grab` whose
  content must not include it.
- One window can span all monitors: pass the `VirtualScreen` rectangle from the monitor section.
- Theming such windows or a Gui to match dark mode is the dark-mode library's job; see Module_GUI.md.

## Mistakes seen in generated code

| Mistake | Fix |
|---------|-----|
| `if ErrorLevel = 0` after `PixelSearch` or `ImageSearch` | `if ImageSearch(&x, &y, ...)`; the return value is the result |
| Tolerance as a seventh argument to `ImageSearch` | Option prefix inside the file string: `"*20 " file` |
| Assuming `CoordMode` resets inside functions | It is per thread; set it in the auto-execute section and in code that runs in a new thread |
| Screen coordinates with the default Client mode | `CoordMode("Pixel", "Screen")` and `CoordMode("Mouse", "Screen")` |
| `A_ScreenWidth` as the right edge on monitor 2 | `MonitorGet(2, &l, &t, &r, &b)` |
| Caching `MonitorGet` for the whole run | Refresh on `WM_DISPLAYCHANGE` (0x007E) |
| Believing `PixelGetColor(...) = 0xFF0000` is always false | It compares numerically and works; use `Integer()` for arithmetic |
| Multiplying screen coordinates by `A_ScreenDPI / 96` | They are already physical pixels; only Gui units and templates scale |
| Overlay Gui without `-DPIScale` | Add it, or divide by the DPI scale yourself |
| Polling `PixelSearch` without `Sleep` | Sleep at least 50 to 250 ms and shrink the region |
| `GdiplusShutdown` in a short-lived script | Leave GDI+ started; free bitmaps and graphics objects individually |
| Many `PixelGetColor` calls per frame | One `ScreenGrab.Grab`, then `Pixel()` reads |

## See also

- Module_GUI.md - Gui construction, logical units, `OnEvent("Size")`.
- Module_WindowAndControl.md - `WinGetPos`, `WinMove`, finding the window you search inside.
- Module_InputAndHotkeys.md - `Click`, `MouseMove` and the CoordMode they follow.
- Module_DllCall.md - DllCall types, Buffer and NumGet rules used by the capture class.
- Module_UIA.md - reading controls instead of matching pixels.

<!-- Adapted from hsinming/AutoHotkey-V2-vibe-coding-tools (no license file upstream); see THIRD-PARTY.md -->
