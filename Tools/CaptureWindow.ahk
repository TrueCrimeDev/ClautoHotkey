#Requires AutoHotkey v2.1-alpha.30
; CaptureWindow.ahk — saves a PNG of one window, identified by PID or WinTitle.
;
; Captures via PrintWindow PW_RENDERFULLCONTENT: the DWM-composited surface,
; so GetDC overpaints (dark-mode subclass painting) are included and the
; window needs neither focus nor on-screen visibility. Prints a status line
; to stdout for the calling harness.
;
; Usage:
;   AutoHotkey64.exe CaptureWindow.ahk <pid|wintitle> [outPng] [zoom] [mode]
;   mode: print  (default) — PrintWindow PW_RENDERFULLCONTENT; works occluded,
;                 but windows are asked to RE-render, so GetDC overpaints
;                 (e.g. dark MonthCal overlays) are missing from the result.
;         screen — CopyFromScreen-style blit of the window's screen rect;
;                 shows exactly what's on screen incl. overpaints, but the
;                 window must be visible (use for MonthCal/overlay controls).
;   AutoHotkey64.exe CaptureWindow.ahk 12345
;   AutoHotkey64.exe CaptureWindow.ahk "Modular Dark Mode System" C:\tmp\shot.png 2 screen

if A_Args.Length < 1 {
    ; Exit 0 so argless validation runs (the post-edit hook executes tools bare).
    Print("usage: CaptureWindow.ahk <pid|wintitle> [outPng] [zoom] [print|screen]")
    ExitApp(0)
}
crit := A_Args[1]
outPath := A_Args.Length >= 2 ? A_Args[2] : A_Temp "\capture_" A_TickCount ".png"
zoom := A_Args.Length >= 3 ? Integer(A_Args[3]) : 1
mode := A_Args.Length >= 4 ? A_Args[4] : "print"

DetectHiddenWindows true
hwnd := 0
if IsInteger(crit)
    hwnd := WinExist("ahk_pid " crit)
if !hwnd
    hwnd := WinExist(crit)
if !hwnd {
    Print("NOTFOUND '{}'", crit)
    ExitApp(1)
}
title := WinGetTitle(hwnd)
pid := WinGetPID(hwnd)

rc := Buffer(16, 0)
DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
w := NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int")
h := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
if w <= 0 || h <= 0 {
    Print("EMPTY window rect {}x{}", w, h)
    ExitApp(1)
}

; GetWindowRect includes the invisible resize frame (left/right/bottom), which
; PrintWindow leaves as unpainted black. Crop to the DWM extended frame bounds
; (the visible window) when available.
cropX := 0, cropY := 0, cropW := w, cropH := h
ext := Buffer(16, 0)
hr := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 9, "Ptr", ext, "UInt", 16)  ; DWMWA_EXTENDED_FRAME_BOUNDS
if hr = 0 {
    eX := NumGet(ext, 0, "Int") - NumGet(rc, 0, "Int")
    eY := NumGet(ext, 4, "Int") - NumGet(rc, 4, "Int")
    eW := NumGet(ext, 8, "Int") - NumGet(ext, 0, "Int")
    eH := NumGet(ext, 12, "Int") - NumGet(ext, 4, "Int")
    if eX >= 0 && eY >= 0 && eW > 0 && eH > 0 && eX + eW <= w && eY + eH <= h
        cropX := eX, cropY := eY, cropW := eW, cropH := eH
}

; Render the window into a 32bpp DIB.
hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
memDC := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
bi := Buffer(40, 0)
NumPut("UInt", 40, bi, 0), NumPut("Int", w, bi, 4), NumPut("Int", -h, bi, 8)
NumPut("UShort", 1, bi, 12), NumPut("UShort", 32, bi, 14)
bits := 0
hBmp := DllCall("CreateDIBSection", "Ptr", hdcScreen, "Ptr", bi, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen, "Void")
oldBmp := DllCall("SelectObject", "Ptr", memDC, "Ptr", hBmp, "Ptr")

if mode = "screen" {
    SRCCOPY := 0xCC0020
    hdcS := DllCall("GetDC", "Ptr", 0, "Ptr")
    DllCall("BitBlt", "Ptr", memDC, "Int", 0, "Int", 0, "Int", w, "Int", h,
        "Ptr", hdcS, "Int", NumGet(rc, 0, "Int"), "Int", NumGet(rc, 4, "Int"), "UInt", SRCCOPY, "Void")
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcS, "Void")
} else {
    PW_RENDERFULLCONTENT := 2
    ok := DllCall("user32\PrintWindow", "Ptr", hwnd, "Ptr", memDC, "UInt", PW_RENDERFULLCONTENT)
    if !ok {
        Print("PRINTWINDOW FAILED for hwnd {}", hwnd)
        ExitApp(1)
    }
}

; GDI+ save (optionally nearest-neighbor upscaled for inspection).
si := Buffer(24, 0)
NumPut("UInt", 1, si, 0)
token := 0
DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0)
pBmp := 0
DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBmp, "Ptr", 0, "Ptr*", &pBmp)
if cropX || cropY || cropW != w || cropH != h {
    pCrop := 0
    DllCall("gdiplus\GdipCloneBitmapAreaI", "Int", cropX, "Int", cropY, "Int", cropW, "Int", cropH,
        "Int", 0x26200A, "Ptr", pBmp, "Ptr*", &pCrop)
    if pCrop {
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pBmp)
        pBmp := pCrop
        w := cropW, h := cropH
    }
}
pOut := pBmp
if zoom > 1 {
    zw := w * zoom, zh := h * zoom
    pZoom := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", zw, "Int", zh, "Int", 0, "UInt", 0x26200A, "Ptr", 0, "Ptr*", &pZoom)
    pG := 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pZoom, "Ptr*", &pG)
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", pG, "Int", 5)  ; NearestNeighbor
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", pG, "Int", 2)    ; Half
    DllCall("gdiplus\GdipDrawImageRectI", "Ptr", pG, "Ptr", pBmp, "Int", 0, "Int", 0, "Int", zw, "Int", zh)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pG)
    pOut := pZoom
}
clsid := Buffer(16, 0)
DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)  ; PNG
status := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pOut, "WStr", outPath, "Ptr", clsid, "Ptr", 0)
if pOut != pBmp
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pOut)
DllCall("gdiplus\GdipDisposeImage", "Ptr", pBmp)
; No GdiplusShutdown: it access-violates here (0xC0000005) and the process
; exits immediately anyway — OS teardown reclaims the session.
DllCall("SelectObject", "Ptr", memDC, "Ptr", oldBmp, "Void")
DllCall("DeleteObject", "Ptr", hBmp, "Void")
DllCall("DeleteDC", "Ptr", memDC, "Void")

if status {
    Print("SAVE FAILED gdiplus status {}", status)
    ExitApp(1)
}
Print("SAVED {} {}x{} zoom={} mode={} pid={} hwnd={} title='{}'", outPath, w, h, zoom, mode, pid, hwnd, title)
ExitApp(0)
