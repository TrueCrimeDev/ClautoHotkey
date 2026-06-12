/*
DarkModeModular_Alpha.ahk — Dark mode GUI framework for AutoHotkey v2 (alpha.30 modernization)

Drop-in replacement for Lib/DarkModeModular.ahk that targets the v2.1-alpha.30+Console
fork. Win32 structs are declared with typed Struct + class-ref properties (IntPtr,
Int32, UInt32, ...), eliminating the hand-rolled offset/alignment math and the
A_PtrSize ternaries used in the alpha.27 file. Public API is unchanged.

Usage:
  #Include DarkModeModular_Alpha.ahk
  myGui := DarkGui("+Resize", "My App")
  myGui.Add("Button", "+Accent", "OK")
  myGui.Add("Edit", "w300", "text")
  myGui.Show()

Public API: DarkGui, DarkTheme, DarkTitleBar, DarkMenu, DarkMenuBar, DarkScrollbar
All controls added via DarkGui.Add() are automatically dark-styled.
Use "+Accent" on buttons for blue accent color.
*/
#Requires AutoHotkey v2.1-alpha.30

; Win32 struct catalogue. Field-by-field types; alpha.30 Struct handles
; pointer size and alignment automatically.

Struct DM_RECT {
    left:   Int32
    top:    Int32
    right:  Int32
    bottom: Int32
}

Struct DM_POINT {
    x: Int32
    y: Int32
}

Struct DM_SIZE {
    cx: Int32
    cy: Int32
}

; Three contiguous POINTs for the owner-draw arrow/chevron polygons.
Struct DM_TRIANGLE {
    p: DM_POINT[3]
}

; GdiplusStartupInput — only GdiplusVersion is set; the rest stay zero.
Struct DM_GpInput {
    GdiplusVersion:           UInt32
    DebugEventCallback:       IntPtr
    SuppressBackgroundThread: Int32
    SuppressExternalCodecs:   Int32
}

Struct DM_NMHDR {
    hwndFrom: IntPtr
    idFrom:   IntPtr
    code:     Int32
}

Struct DM_NMCUSTOMDRAW {
    hdr:         DM_NMHDR
    dwDrawStage: UInt32
    hdc:         IntPtr
    rc:          DM_RECT
    dwItemSpec:  IntPtr
    uItemState:  UInt32
    lItemlParam: IntPtr
}

Struct DM_PAINTSTRUCT {
    hdc:         IntPtr
    fErase:      Int32
    rcPaint:     DM_RECT
    fRestore:    Int32
    fIncUpdate:  Int32
    rgbReserved: Int8[32]
}

Struct DM_TRACKMOUSEEVENT {
    cbSize:      UInt32
    dwFlags:     UInt32
    hwndTrack:   IntPtr
    dwHoverTime: UInt32
}

Struct DM_SCROLLBARINFO {
    cbSize:        UInt32
    rcScrollBar:   DM_RECT
    dxyLineButton: Int32
    xyThumbTop:    Int32
    xyThumbBottom: Int32
    reserved:      Int32
    rgstate:       UInt32[6]
}

Struct DM_HDITEMW {
    mask:       UInt32
    cxy:        Int32
    pszText:    IntPtr
    hbm:        IntPtr
    cchTextMax: Int32
    fmt:        Int32
    lParam:     IntPtr
    iImage:     Int32
    iOrder:     Int32
    type:       UInt32
    pvFilter:   IntPtr
    state:      UInt32
}

Struct DM_LVITEMW {
    mask:       UInt32
    iItem:      Int32
    iSubItem:   Int32
    state:      UInt32
    stateMask:  UInt32
    pszText:    IntPtr
    cchTextMax: Int32
    iImage:     Int32
    lParam:     IntPtr
    iIndent:    Int32
    iGroupId:   Int32
    cColumns:   UInt32
    puColumns:  IntPtr
    piColFmt:   IntPtr
    iGroup:     Int32
}

Struct DM_TCITEMW {
    mask:        UInt32
    dwState:     UInt32
    dwStateMask: UInt32
    pszText:     IntPtr
    cchTextMax:  Int32
    iImage:      Int32
    lParam:      IntPtr
}

Struct DM_DRAWITEMSTRUCT {
    CtlType:    UInt32
    CtlID:      UInt32
    itemID:     UInt32
    itemAction: UInt32
    itemState:  UInt32
    hwndItem:   IntPtr
    hDC:        IntPtr
    rcItem:     DM_RECT
    itemData:   IntPtr
}

Struct DM_COMBOBOXINFO {
    cbSize:      UInt32
    rcItem:      DM_RECT
    rcButton:    DM_RECT
    stateButton: UInt32
    hwndCombo:   IntPtr
    hwndItem:    IntPtr
    hwndList:    IntPtr
}

Struct DM_MENUINFO {
    cbSize:          UInt32
    fMask:           UInt32
    dwStyle:         UInt32
    cyMax:           UInt32
    hbrBack:         IntPtr
    dwContextHelpID: UInt32
    dwMenuData:      IntPtr
}

Struct DM_TEXTMETRICW {
    tmHeight:           Int32
    tmAscent:           Int32
    tmDescent:          Int32
    tmInternalLeading:  Int32
    tmExternalLeading:  Int32
    tmAveCharWidth:     Int32
    tmMaxCharWidth:     Int32
    tmWeight:           Int32
    tmOverhang:         Int32
    tmDigitizedAspectX: Int32
    tmDigitizedAspectY: Int32
    tmFirstChar:        UInt16
    tmLastChar:         UInt16
    tmDefaultChar:      UInt16
    tmBreakChar:        UInt16
    tmItalic:           Int8
    tmUnderlined:       Int8
    tmStruckOut:        Int8
    tmPitchAndFamily:   Int8
    tmCharSet:          Int8
}

Struct DM_MCHITTESTINFO {
    cbSize:  UInt32
    pt:      DM_POINT
    uHit:    UInt32
    st:      UInt16[8]
    rc:      DM_RECT
    iOffset: Int32
    iRow:    Int32
    iCol:    Int32
}

/**
 * Central theme manager for dark mode colors and GDI brushes.
 * Provides color constants, brush caching, and utility functions.
 */
class DarkTheme {
    /** @type {Map} Color palette. Base tones plus owner-draw button state colors
     * (ButtonHover/ButtonPressed/ButtonBorder, AccentHover/AccentPressed/AccentBorder,
     * FlatPressed) so SetColor and theme switches can reach them — previously these
     * were hardcoded literals inside the button paint paths. */
    static Colors := Map(
        "Background", 0x1A1A1A,
        "Controls", 0x252525,
        "ControlsHover", 0x333333,
        "ControlsActive", 0x404040,
        "Font", 0xE8E8E8,
        "FontDim", 0xA0A0A0,
        "Accent", 0x0078D7,
        "Border", 0x404040,
        "Selection", 0x264F78,
        "GridLine", 0x2A2A2A,
        "Header", 0x2D2D2D,
        "ScrollTrack", 0x3C3C3C,
        "ScrollThumb", 0x5A5A5A,
        "ScrollThumbHover", 0x787878,
        "ButtonHover", 0x303030,
        "ButtonPressed", 0x1F1F1F,
        "ButtonBorder", 0x3A3A3A,
        "AccentHover", 0x1A8CFF,
        "AccentPressed", 0x005A9E,
        "AccentBorder", 0x0064B0,
        "FlatPressed", 0x282828,
        "DisabledBg", 0x202020,
        "DisabledText", 0x6E6E6E,
        "Link", 0x4CA0FF
    )

    /** @type {Map} Cached GDI brush handles keyed by color name */
    static Brushes := Map()
    /** @type {Map} Value-keyed pen/brush cache built on demand by paint code.
     * Keys: "b|<rgb>" (solid brush), "p|<width>|<rgb>" (pen). DarkTheme owns
     * these handles — paint code must never DeleteObject them. */
    static _GdiCache := Map()
    /** @type {Map} Registered DarkGui window handles, for live re-theming via SetColor */
    static Windows := Map()
    /** @type {Integer} Active DarkGui instance count */
    static _refCount := 0
    /** @type {Boolean} Whether OnExit safety net is registered */
    static _exitRegistered := false

    static __New() {
        for name, color in this.Colors
            this.Brushes[name] := DllCall("gdi32\CreateSolidBrush", "UInt", this.RGBtoBGR(color), "Ptr")
        if !this._exitRegistered {
            OnExit(DarkTheme._OnAppExit)
            this._exitRegistered := true
        }
    }

    ; OnExit handler: extracted to avoid void-result fat-arrow body (alpha.27+ rejects it)
    static _OnAppExit(*) {
        DarkTheme.Cleanup()
        _DarkSlider.Shutdown()
    }

    /**
     * Increments reference count. Called by {@link DarkGui#__New}.
     */
    static AddRef() => ++this._refCount

    /**
     * Decrements the active-window reference count.
     *
     * Deliberately does NOT free brushes here. The palette brushes are
     * process-shared and cheap to keep; freeing them when the count briefly
     * reaches zero breaks any {@link DarkGui} created afterward (the common
     * close-all-then-reopen pattern). Final teardown is {@link DarkTheme.Cleanup},
     * invoked from the {@link DarkTheme._OnAppExit} handler on normal exit.
     */
    static Release() {
        if --this._refCount < 0
            this._refCount := 0
    }

    /**
     * Gets a cached GDI brush handle for the specified color.
     * @param {String} name - Color name from Colors map
     * @returns {Ptr} GDI brush handle or 0 if not found
     */
    static GetBrush(name) => this.Brushes.Get(name, 0)

    /**
     * Updates a theme color and recreates its brush.
     * @param {String} name - Color name to update
     * @param {Integer} value - New RGB color value (0xRRGGBB)
     */
    static SetColor(name, value) {
        if this.Brushes.Has(name)
            DllCall("DeleteObject", "Ptr", this.Brushes[name], "Void")
        this.Colors[name] := value
        this.Brushes[name] := DllCall("gdi32\CreateSolidBrush", "UInt", this.RGBtoBGR(value), "Ptr")
        ; Value-keyed pens/brushes may encode the old color — drop them so the
        ; repaint below rebuilds against the new palette.
        this._FlushGdiCache()
        this.Redraw()
    }

    /**
     * Returns a cached solid brush for an RGB color (0xRRGGBB), created once and
     * reused. Do NOT DeleteObject the result — DarkTheme owns it. Removes the
     * per-WM_PAINT CreateSolidBrush/DeleteObject churn in owner-draw paint paths.
     * @param {Integer} rgb - Color in 0xRRGGBB.
     * @returns {Ptr} Shared GDI brush handle.
     */
    static GetSolidBrush(rgb) {
        key := "b|" rgb
        if this._GdiCache.Has(key)
            return this._GdiCache[key]
        return this._GdiCache[key] := DllCall("gdi32\CreateSolidBrush", "UInt", this.RGBtoBGR(rgb), "Ptr")
    }

    /**
     * Returns a cached solid (PS_SOLID) pen for an RGB color and width, created
     * once and reused. Do NOT DeleteObject the result — DarkTheme owns it.
     * @param {Integer} rgb - Color in 0xRRGGBB.
     * @param {Integer} [width=1] - Pen width in pixels.
     * @returns {Ptr} Shared GDI pen handle.
     */
    static GetPen(rgb, width := 1) {
        key := "p|" width "|" rgb
        if this._GdiCache.Has(key)
            return this._GdiCache[key]
        return this._GdiCache[key] := DllCall("gdi32\CreatePen", "Int", 0, "Int", width, "UInt", this.RGBtoBGR(rgb), "Ptr")
    }

    /** Deletes every value-cached pen/brush and empties the cache. */
    static _FlushGdiCache() {
        for key, h in this._GdiCache
            DllCall("DeleteObject", "Ptr", h, "Void")
        this._GdiCache.Clear()
    }

    /**
     * Forces a full repaint of every registered DarkGui window so palette/brush
     * changes from {@link DarkTheme.SetColor} take effect immediately.
     */
    static Redraw() {
        static RDW_FLAGS := 0x1 | 0x4 | 0x80 | 0x100  ; INVALIDATE | ERASE | ALLCHILDREN | UPDATENOW
        for hwnd in this.Windows {
            if DllCall("IsWindow", "Ptr", hwnd)
                DllCall("RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", RDW_FLAGS, "Void")
        }
    }

    /**
     * Scales a pixel value by the system DPI factor.
     * @param {Integer} px - Pixel value at 96 DPI
     * @returns {Integer} Scaled pixel value for current DPI
     */
    static Scale(px) => Round(px * (A_ScreenDPI / 96))

    /**
     * Converts RGB to BGR format for Win32 GDI functions.
     * @param {Integer} RGB - Color in 0xRRGGBB format
     * @returns {Integer} Color in 0xBBGGRR format
     */
    static RGBtoBGR(RGB) => ((RGB & 0xFF) << 16) | (RGB & 0xFF00) | ((RGB >> 16) & 0xFF)
    /**
     * Converts BGR to RGB format. Same operation as {@link DarkTheme.RGBtoBGR}.
     *
     * @param {Integer} BGR - Color in `0xBBGGRR` format.
     * @returns {Integer} Color in `0xRRGGBB` format.
     */
    static BGRtoRGB(BGR) => this.RGBtoBGR(BGR)

    /**
     * Removes all border styles from a control (WS_BORDER, WS_EX_CLIENTEDGE, WS_EX_STATICEDGE).
     * @param {Ptr} hwnd - Control window handle
     */
    static RemoveBorder(hwnd) {
        static GWL_STYLE := -16
        static GWL_EXSTYLE := -20
        static WS_BORDER := 0x800000
        static WS_EX_CLIENTEDGE := 0x200
        static WS_EX_STATICEDGE := 0x20000
        static SWP_FRAMECHANGED := 0x20
        static SWP_NOMOVE := 0x2
        static SWP_NOSIZE := 0x1
        static SWP_NOZORDER := 0x4

        ; AutoHotkey64.exe is 64-bit only — always the Ptr variants.
        GetWindowLong := "GetWindowLongPtr"
        SetWindowLong := "SetWindowLongPtr"

        ; Remove WS_BORDER from style
        style := DllCall(GetWindowLong, "Ptr", hwnd, "Int", GWL_STYLE, "Ptr")
        DllCall(SetWindowLong, "Ptr", hwnd, "Int", GWL_STYLE, "Ptr", style & ~WS_BORDER)

        ; Remove WS_EX_CLIENTEDGE and WS_EX_STATICEDGE from extended style
        exStyle := DllCall(GetWindowLong, "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr")
        DllCall(SetWindowLong, "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr", exStyle & ~(WS_EX_CLIENTEDGE | WS_EX_STATICEDGE))

        ; Force redraw with new frame
        DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0,
            "UInt", SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER, "Void")
    }

    /**
     * Calls undocumented AllowDarkModeForWindow (uxtheme ordinal 133).
     * Must be called BEFORE SetWindowTheme for dark mode to take effect on a control.
     * Single source of truth — _DarkTab and DarkMenuBar delegate here rather than
     * resolving ordinal 133 independently.
     * @param {Ptr} hwnd - Control or window handle
     * @param {Boolean} [allow=true] - Enable (true) or disable (false) dark mode for the window
     */
    static AllowDarkMode(hwnd, allow := true) {
        static fn := 0
        if !fn {
            uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
            if !uxtheme
                uxtheme := DllCall("LoadLibrary", "Str", "uxtheme", "Ptr")
            if uxtheme
                fn := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 133, "Ptr")
        }
        if fn
            DllCall(fn, "Ptr", hwnd, "Int", allow ? 1 : 0)
    }

    /**
     * Frees all cached GDI brush handles.
     * Called automatically by {@link DarkTheme.Release} or on application exit.
     */
    static Cleanup() {
        for name, brush in this.Brushes
            DllCall("DeleteObject", "Ptr", brush, "Void")
        this.Brushes.Clear()
        this._FlushGdiCache()
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; Prototype Extensions - Scoped inside DarkPrototypes to avoid global pollution
; ═══════════════════════════════════════════════════════════════════════════════

/**
 * Installs SetDarkMode() on Gui control prototypes using local function scope.
 * No global function names are introduced.
 */
class DarkPrototypes {
    static __New() {
        _editDark(ctrl) {
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
            ctrl.SetFont("c" Format("{:X}", DarkTheme.Colors["Font"]))
            DarkTheme.RemoveBorder(ctrl.Hwnd)
        }
        Gui.Edit.Prototype.DefineProp("SetDarkMode", { Call: _editDark })

        _checkBoxDark(ctrl) {
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        }
        Gui.CheckBox.Prototype.DefineProp("SetDarkMode", { Call: _checkBoxDark })

        _radioDark(ctrl) {
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        }
        Gui.Radio.Prototype.DefineProp("SetDarkMode", { Call: _radioDark })

        _treeViewDark(ctrl) {
            static TVM_SETBKCOLOR := 0x111D
            static TVM_SETTEXTCOLOR := 0x111E
            static TVM_SETLINECOLOR := 0x1128
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
            SendMessage(TVM_SETBKCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]), ctrl)
            SendMessage(TVM_SETTEXTCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]), ctrl)
            SendMessage(TVM_SETLINECOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Border"]), ctrl)
            DarkTheme.RemoveBorder(ctrl.Hwnd)
        }
        Gui.TreeView.Prototype.DefineProp("SetDarkMode", { Call: _treeViewDark })
    }
}

/**
 * Applies dark mode to window title bar using DWM attributes (Win10 1809+).
 * Uses `DwmSetWindowAttribute` with the immersive dark mode flag.
 */
class DarkTitleBar {
    /**
     * Enables dark title bar for a window.
     *
     * @param {Ptr} hwnd - Window handle.
     * @returns {Boolean} `true` if applied, `false` if OS too old.
     */
    static Apply(hwnd) {
        if VerCompare(A_OSVersion, "10.0.17763") < 0
            return false
        attr := VerCompare(A_OSVersion, "10.0.18985") >= 0 ? 20 : 19
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", attr, "Int*", true, "Int", 4)
        return true
    }
}

/**
 * Enables dark mode for application menus using undocumented uxtheme APIs
 * (ordinals 135 `SetPreferredAppMode` and 136 `FlushMenuThemes`).
 */
class DarkMenu {
    /**
     * Applies dark theme to all menus in the application.
     * Call once during GUI initialization; {@link DarkGui#__New} calls this automatically.
     */
    static Apply() {
        uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
        SetPreferredAppMode := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
        FlushMenuThemes := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")
        DllCall(SetPreferredAppMode, "Int", 2)
        DllCall(FlushMenuThemes)
    }
}

/**
 * Utility class for window subclassing. Provides common pattern for installing
 * and uninstalling window procedure callbacks.
 */
class Subclass {
    ; AutoHotkey64.exe is 64-bit only — always the Ptr variant.
    static SetWindowLong := "SetWindowLongPtr"

    /**
     * Installs a window procedure callback on a control.
     * @param {Ptr} hwnd - Window handle to subclass
     * @param {Func} procMethod - Bound method to use as window procedure
     * @param {Map} callbacks - Map to store callback handles
     * @param {Map} oldProcs - Map to store original window procedures
     * @returns {Boolean} true if installed, false if already subclassed
     */
    static Install(hwnd, procMethod, callbacks, oldProcs) {
        if oldProcs.Has(hwnd)
            return false
        callback := CallbackCreate(procMethod, , 4)
        callbacks[hwnd] := callback
        oldProcs[hwnd] := DllCall(this.SetWindowLong, "Ptr", hwnd, "Int", -4, "Ptr", callback, "Ptr")
        return true
    }

    /**
     * Removes subclass and restores original window procedure.
     * @param {Ptr} hwnd - Window handle to unsubclass
     * @param {Map} callbacks - Map containing callback handles
     * @param {Map} oldProcs - Map containing original window procedures
     */
    static Uninstall(hwnd, callbacks, oldProcs) {
        if !oldProcs.Has(hwnd)
            return
        DllCall(this.SetWindowLong, "Ptr", hwnd, "Int", -4, "Ptr", oldProcs[hwnd], "Ptr")
        CallbackFree(callbacks[hwnd])
        callbacks.Delete(hwnd)
        oldProcs.Delete(hwnd)
    }

    /**
     * Calls the original window procedure.
     * @param {Ptr} oldProc - Original window procedure
     * @param {Ptr} hwnd - Window handle
     * @param {Integer} msg - Message
     * @param {Ptr} wParam - wParam
     * @param {Ptr} lParam - lParam
     * @returns {Ptr} Result from CallWindowProc
     */
    static CallOriginal(oldProc, hwnd, msg, wParam, lParam) {
        return DllCall("CallWindowProc", "Ptr", oldProc, "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }
}

/**
 * Custom dark scrollbar control for ListView. Creates an owner-draw scrollbar
 * that syncs with ListView scroll position via a 100ms timer.
 *
 * Rendering uses GDI `FillRect` with rounded thumb, hover/drag states,
 * and page-up/page-down on track clicks.
 */
class DarkScrollbar {
    /** @type {Map} Active instances keyed by scrollbar hwnd */
    static Instances := Map()
    /** @type {Map} Window procedure callbacks keyed by hwnd */
    static Callbacks := Map()
    /** @type {Map} Original window procedures for restoration */
    static OldProcs := Map()
    /** @type {Integer} Scrollbar width in DPI-scaled pixels */
    static ScrollbarWidth := DarkTheme.Scale(14)

    /**
     * Creates a dark scrollbar alongside a target ListView.
     *
     * @param {DarkGui} gui - Parent GUI instance.
     * @param {Gui.ListView} targetCtrl - ListView to sync scroll position with.
     * @param {Integer} x - X position.
     * @param {Integer} y - Y position.
     * @param {Integer} h - Height.
     */
    __New(gui, targetCtrl, x, y, h) {
        this.gui := gui
        this.target := targetCtrl
        this.x := x
        this.y := y
        this.h := h
        this.w := DarkScrollbar.ScrollbarWidth

        this.trackColor := DarkTheme.Colors["Header"]
        this.thumbColor := DarkTheme.Colors["ScrollThumb"]
        this.thumbHoverColor := DarkTheme.Colors["ScrollThumbHover"]

        this.isDragging := false
        this.dragStartY := 0
        this.dragStartPos := 0
        this.isHovering := false
        ; Last painted thumb extent, so the poll timer only repaints on real change.
        this._lastThumbTop := -1
        this._lastThumbBottom := -1

        ; Create the scrollbar as a Text control (we'll custom draw it)
        this.ctrl := gui.Add("Text", "x" x " y" y " w" this.w " h" h " +0x4000000")  ; WS_CLIPSIBLINGS
        this.ctrl.Opt("+Background" Format("{:X}", this.trackColor))

        ; Store instance reference
        DarkScrollbar.Instances[this.ctrl.Hwnd] := this

        ; Subclass for custom drawing and mouse handling
        this.SubclassScrollbar()

        ; Set up scroll sync timer
        this.syncTimer := ObjBindMethod(this, "SyncFromTarget")
        SetTimer(this.syncTimer, 100)
    }

    SubclassScrollbar() {
        Subclass.Install(this.ctrl.Hwnd, ObjBindMethod(this, "ScrollbarProc"), DarkScrollbar.Callbacks, DarkScrollbar.OldProcs)
    }

    ScrollbarProc(hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F
        static WM_ERASEBKGND := 0x0014
        static WM_LBUTTONDOWN := 0x0201
        static WM_LBUTTONUP := 0x0202
        static WM_MOUSEMOVE := 0x0200
        static WM_MOUSELEAVE := 0x02A3
        static WM_CAPTURECHANGED := 0x0215

        if msg = WM_ERASEBKGND
            return 1

        if msg = WM_PAINT {
            this.Paint()
            return 0
        }

        if msg = WM_LBUTTONDOWN {
            this.OnMouseDown(lParam)
            return 0
        }

        if msg = WM_LBUTTONUP {
            this.OnMouseUp()
            return 0
        }

        if msg = WM_MOUSEMOVE {
            this.OnMouseMove(lParam)
            return 0
        }

        if msg = WM_MOUSELEAVE {
            this.isHovering := false
            DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1, "Void")
            return 0
        }

        if msg = WM_CAPTURECHANGED {
            this.isDragging := false
            return 0
        }

        return Subclass.CallOriginal(DarkScrollbar.OldProcs[this.ctrl.Hwnd], hwnd, msg, wParam, lParam)
    }

    GetScrollInfo() {
        static LVM_GETITEMCOUNT := 0x1004
        static LVM_GETCOUNTPERPAGE := 0x1028
        static LVM_GETTOPINDEX := 0x1027

        ; Get ListView scroll info from item counts
        itemCount := SendMessage(LVM_GETITEMCOUNT, 0, 0, this.target.Hwnd)
        visibleCount := SendMessage(LVM_GETCOUNTPERPAGE, 0, 0, this.target.Hwnd)
        topIndex := SendMessage(LVM_GETTOPINDEX, 0, 0, this.target.Hwnd)

        return {
            min: 0,
            max: Max(0, itemCount - 1),
            page: visibleCount,
            pos: topIndex
        }
    }

    GetThumbRect() {
        info := this.GetScrollInfo()
        range := info.max - info.min + 1

        if range <= info.page || range <= 0
            return {top: 0, bottom: this.h, height: this.h}

        thumbHeight := Max(DarkTheme.Scale(30), (info.page * this.h) // range)
        trackSpace := this.h - thumbHeight

        scrollRange := info.max - info.min - info.page + 1
        if scrollRange <= 0
            thumbTop := 0
        else
            thumbTop := (info.pos * trackSpace) // scrollRange

        return {
            top: thumbTop,
            bottom: thumbTop + thumbHeight,
            height: thumbHeight
        }
    }

    Paint() {
        ps := DM_PAINTSTRUCT()
        hdc := DllCall("BeginPaint", "Ptr", this.ctrl.Hwnd, "Ptr", ps.Ptr, "Ptr")

        ; Get client rect
        rc := DM_RECT()
        DllCall("GetClientRect", "Ptr", this.ctrl.Hwnd, "Ptr", rc)
        w := rc.right
        h := rc.bottom

        ; Draw track (cached brush — do not delete)
        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", DarkTheme.GetSolidBrush(this.trackColor), "Void")

        ; Draw thumb
        thumb := this.GetThumbRect()
        thumbColor := this.isHovering || this.isDragging ? this.thumbHoverColor : this.thumbColor

        rcThumb := DM_RECT()
        pad := DarkTheme.Scale(2)
        rcThumb.left := pad, rcThumb.top := thumb.top + pad, rcThumb.right := w - pad, rcThumb.bottom := thumb.bottom - pad
        DllCall("FillRect", "Ptr", hdc, "Ptr", rcThumb, "Ptr", DarkTheme.GetSolidBrush(thumbColor), "Void")

        DllCall("EndPaint", "Ptr", this.ctrl.Hwnd, "Ptr", ps.Ptr, "Void")
    }

    OnMouseDown(lParam) {
        mouseY := (lParam >> 16) & 0xFFFF
        if mouseY > 0x7FFF
            mouseY -= 0x10000

        thumb := this.GetThumbRect()

        if mouseY < thumb.top {
            ; Click above thumb - page up
            this.PageUp()
        } else if mouseY > thumb.bottom {
            ; Click below thumb - page down
            this.PageDown()
        } else {
            ; Start dragging thumb
            this.isDragging := true
            this.dragStartY := mouseY
            this.dragStartPos := this.GetScrollInfo().pos
            DllCall("SetCapture", "Ptr", this.ctrl.Hwnd, "Void")
        }

        DllCall("InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", 1, "Void")

        ; Track mouse for hover effects
        tme := DM_TRACKMOUSEEVENT()
        tme.cbSize    := tme.Size
        tme.dwFlags   := 2  ; TME_LEAVE
        tme.hwndTrack := this.ctrl.Hwnd
        DllCall("TrackMouseEvent", "Ptr", tme.Ptr, "Void")
    }

    OnMouseUp() {
        if this.isDragging {
            this.isDragging := false
            DllCall("ReleaseCapture", "Void")
            DllCall("InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", 1, "Void")
        }
    }

    OnMouseMove(lParam) {
        mouseY := (lParam >> 16) & 0xFFFF
        if mouseY > 0x7FFF
            mouseY -= 0x10000

        ; Track mouse for hover effects
        if !this.isHovering {
            this.isHovering := true
            tme := DM_TRACKMOUSEEVENT()
            tme.cbSize    := tme.Size
            tme.dwFlags   := 2  ; TME_LEAVE
            tme.hwndTrack := this.ctrl.Hwnd
            DllCall("TrackMouseEvent", "Ptr", tme.Ptr, "Void")
            DllCall("InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", 1, "Void")
        }

        if this.isDragging {
            info := this.GetScrollInfo()
            deltaY := mouseY - this.dragStartY

            thumb := this.GetThumbRect()
            trackSpace := this.h - thumb.height

            if trackSpace <= 0
                return

            scrollRange := info.max - info.min - info.page + 1
            if scrollRange <= 0
                return

            deltaPosFloat := (deltaY * scrollRange) / trackSpace
            newPos := this.dragStartPos + Round(deltaPosFloat)
            newPos := Max(info.min, Min(newPos, info.max - info.page + 1))

            this.SetScrollPos(newPos)
        }
    }

    PageUp() {
        info := this.GetScrollInfo()
        newPos := Max(info.min, info.pos - info.page)
        this.SetScrollPos(newPos)
    }

    PageDown() {
        info := this.GetScrollInfo()
        newPos := Min(info.max - info.page + 1, info.pos + info.page)
        this.SetScrollPos(newPos)
    }

    SetScrollPos(pos) {
        static LVM_ENSUREVISIBLE := 0x1013
        static LVM_GETITEMCOUNT := 0x1004

        ; Clamp position to valid range
        itemCount := SendMessage(LVM_GETITEMCOUNT, 0, 0, this.target.Hwnd)
        pos := Max(0, Min(pos, itemCount - 1))

        ; Scroll to make the item at position visible at the top
        SendMessage(LVM_ENSUREVISIBLE, pos, 0, this.target.Hwnd)

        DllCall("InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", 1, "Void")
    }

    SyncFromTarget() {
        ; Repaint only when the thumb actually moved. The 100ms poll previously
        ; forced a full InvalidateRect ~10x/sec even on a static list; hover-state
        ; repaints are driven separately by the mouse handlers.
        if this.isDragging
            return
        thumb := this.GetThumbRect()
        if thumb.top = this._lastThumbTop && thumb.bottom = this._lastThumbBottom
            return
        this._lastThumbTop := thumb.top
        this._lastThumbBottom := thumb.bottom
        DllCall("InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", 1, "Void")
    }

    /**
     * Moves and resizes the scrollbar control.
     *
     * @param {Integer} x - New X position.
     * @param {Integer} y - New Y position.
     * @param {Integer} h - New height.
     */
    UpdatePosition(x, y, h) {
        this.x := x
        this.y := y
        this.h := h
        this.ctrl.Move(x, y, this.w, h)
    }

    /**
     * Stops the sync timer and frees the subclass callback.
     */
    Destroy() {
        if this.syncTimer
            SetTimer(this.syncTimer, 0)
        Subclass.Uninstall(this.ctrl.Hwnd, DarkScrollbar.Callbacks, DarkScrollbar.OldProcs)
        DarkScrollbar.Instances.Delete(this.ctrl.Hwnd)
    }
}

/**
 * Dark-themed ListView with custom-drawn header, items, and arrow-less scrollbar.
 * Uses NM_CUSTOMDRAW for item/header colors and hides scrollbar arrows.
 */
class _DarkListView extends Gui.ListView {
    /** @type {Map} Window procedure callbacks keyed by hwnd */
    static Callbacks := Map()
    /** @type {Map} Original window procedures for restoration */
    static OldProcs := Map()
    /** @type {Map} Header control handles for scroll alignment */
    static HeaderHandles := Map()
    /** @type {Map} Active hover timer states */
    static HoverTimers := Map()
    /** @type {Map} Bound timer functions for hover effects */
    static HoverTimerFuncs := Map()

    static __New() {
        static LVM_GETHEADER := 0x101F
        super.Prototype.GetHeader := SendMessage.Bind(LVM_GETHEADER, 0, 0)
        super.Prototype.SetDarkMode := this.SetDarkMode.Bind(this)
    }

    static SubclassListView(hwnd) {
        Subclass.Install(hwnd, ObjBindMethod(this, "ListViewProc", hwnd), this.Callbacks, this.OldProcs)
    }

    static StopHoverTimer(hwnd) {
        if this.HoverTimers.Has(hwnd) {
            SetTimer(this.HoverTimerFuncs[hwnd], 0)
            this.HoverTimerFuncs.Delete(hwnd)
            this.HoverTimers.Delete(hwnd)
        }
    }

    /**
     * Removes subclass and frees resources for a ListView.
     * @param {Ptr} hwnd - ListView window handle
     */
    static Remove(hwnd) {
        this.StopHoverTimer(hwnd)
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
        this.HeaderHandles.Delete(hwnd)
    }

    static CreateArrowHideTimerFunc(hwnd, headerHwnd) {
        ; Create a bound function for arrow hiding timer
        return () => (_DarkListView.HideScrollbarArrows(hwnd, headerHwnd), 0)
    }

    /**
     * Temporarily sets a window region that excludes scrollbar arrow areas.
     * Used to prevent Windows from painting arrows during drag operations.
     * Call ClearArrowClipRegion() after the default proc returns.
     * @param {Ptr} hwnd - Window handle
     * @returns {Boolean} True if region was set, false if scrollbar not visible
     */
    static SetArrowClipRegion(hwnd) {
        static OBJID_VSCROLL := -5
        sbi := DM_SCROLLBARINFO()
        sbi.cbSize := sbi.Size
        if !DllCall("GetScrollBarInfo", "Ptr", hwnd, "Int", OBJID_VSCROLL, "Ptr", sbi.Ptr)
            return false
        if sbi.rgstate[1] & 0x8000  ; STATE_SYSTEM_INVISIBLE on the scrollbar itself
            return false

        sbL := sbi.rcScrollBar.left,  sbT := sbi.rcScrollBar.top
        sbR := sbi.rcScrollBar.right, sbB := sbi.rcScrollBar.bottom
        arrowH := DllCall("GetSystemMetrics", "Int", 20)

        rcWin := DM_RECT()
        DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rcWin)
        winL := rcWin.left, winT := rcWin.top
        w := rcWin.right - winL, h := rcWin.bottom - winT

        ; Window-relative arrow coords
        aL := sbL - winL, aR := sbR - winL
        aTopT := sbT - winT, aTopB := sbT + arrowH - winT
        aBotT := sbB - arrowH - winT, aBotB := sbB - winT

        ; Full window region minus arrow rects
        fullRgn := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr")
        topRgn := DllCall("CreateRectRgn", "Int", aL, "Int", aTopT, "Int", aR, "Int", aTopB, "Ptr")
        DllCall("CombineRgn", "Ptr", fullRgn, "Ptr", fullRgn, "Ptr", topRgn, "Int", 4, "Void")  ; RGN_DIFF
        DllCall("DeleteObject", "Ptr", topRgn, "Void")
        botRgn := DllCall("CreateRectRgn", "Int", aL, "Int", aBotT, "Int", aR, "Int", aBotB, "Ptr")
        DllCall("CombineRgn", "Ptr", fullRgn, "Ptr", fullRgn, "Ptr", botRgn, "Int", 4, "Void")  ; RGN_DIFF
        DllCall("DeleteObject", "Ptr", botRgn, "Void")

        ; System takes ownership of fullRgn - don't delete it
        DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", fullRgn, "Int", 0, "Void")
        return true
    }

    /**
     * Removes the arrow clip region, restoring full window painting.
     *
     * @param {Ptr} hwnd - Window handle.
     */
    static ClearArrowClipRegion(hwnd) {
        DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Void")
    }

    /**
     * Creates a WM_NCPAINT region with scrollbar arrow areas excluded.
     * Prevents Windows from painting arrows by clipping them from the paint region.
     * @param {Ptr} hwnd - Window handle
     * @param {Ptr|Integer} wParam - WM_NCPAINT wParam (1=full repaint, or HRGN)
     * @returns {Ptr} New HRGN with arrows excluded, or 0 if scrollbar hidden. Caller must DeleteObject if non-zero.
     */
    static ClipArrowRegion(hwnd, wParam) {
        static OBJID_VSCROLL := -5
        sbi := DM_SCROLLBARINFO()
        sbi.cbSize := sbi.Size
        if !DllCall("GetScrollBarInfo", "Ptr", hwnd, "Int", OBJID_VSCROLL, "Ptr", sbi.Ptr)
            return 0
        if sbi.rgstate[1] & 0x8000  ; STATE_SYSTEM_INVISIBLE
            return 0

        ; Scrollbar rect in screen coords
        sbL := sbi.rcScrollBar.left,  sbT := sbi.rcScrollBar.top
        sbR := sbi.rcScrollBar.right, sbB := sbi.rcScrollBar.bottom
        arrowH := DllCall("GetSystemMetrics", "Int", 20)  ; SM_CYVSCROLL

        ; Build base region from wParam
        if wParam = 1 {
            rcWin := DM_RECT()
            DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rcWin)
            hrgn := DllCall("CreateRectRgn",
                "Int", rcWin.left, "Int", rcWin.top,
                "Int", rcWin.right, "Int", rcWin.bottom, "Ptr")
        } else {
            ; Copy - must not modify the original region
            hrgn := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
            DllCall("CombineRgn", "Ptr", hrgn, "Ptr", wParam, "Ptr", hrgn, "Int", 5, "Void")  ; RGN_COPY
        }

        ; Subtract top arrow region (screen coords)
        topRgn := DllCall("CreateRectRgn", "Int", sbL, "Int", sbT, "Int", sbR, "Int", sbT + arrowH, "Ptr")
        DllCall("CombineRgn", "Ptr", hrgn, "Ptr", hrgn, "Ptr", topRgn, "Int", 4, "Void")  ; RGN_DIFF
        DllCall("DeleteObject", "Ptr", topRgn, "Void")

        ; Subtract bottom arrow region (screen coords)
        botRgn := DllCall("CreateRectRgn", "Int", sbL, "Int", sbB - arrowH, "Int", sbR, "Int", sbB, "Ptr")
        DllCall("CombineRgn", "Ptr", hrgn, "Ptr", hrgn, "Ptr", botRgn, "Int", 4, "Void")  ; RGN_DIFF
        DllCall("DeleteObject", "Ptr", botRgn, "Void")

        return hrgn
    }

    /**
     * Paints over scrollbar arrow areas with track color.
     * Used as fallback for non-WM_NCPAINT repaints (hover effects, scroll events).
     * @param {Ptr} hwnd - Window handle
     */
    static HideScrollbarArrows(hwnd, headerHwnd := 0) {
        static OBJID_VSCROLL := -5
        sbi := DM_SCROLLBARINFO()
        sbi.cbSize := sbi.Size
        if !DllCall("GetScrollBarInfo", "Ptr", hwnd, "Int", OBJID_VSCROLL, "Ptr", sbi.Ptr)
            return
        if sbi.rgstate[1] & 0x8000
            return

        sbLeft  := sbi.rcScrollBar.left,  sbTop    := sbi.rcScrollBar.top
        sbRight := sbi.rcScrollBar.right, sbBottom := sbi.rcScrollBar.bottom
        arrowHeight := DllCall("GetSystemMetrics", "Int", 20)

        rcWin := DM_RECT()
        DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rcWin)
        winLeft := rcWin.left, winTop := rcWin.top

        ; Convert to window-relative coords
        sbLeftW := sbLeft - winLeft, sbTopW := sbTop - winTop
        sbRightW := sbRight - winLeft, sbBottomW := sbBottom - winTop

        hdc := DllCall("GetWindowDC", "Ptr", hwnd, "Ptr")
        if !hdc
            return

        trackBrush := DarkTheme.GetBrush("ScrollTrack")  ; cached — do not delete
        rc := DM_RECT()

        rc.left := sbLeftW, rc.top := sbTopW, rc.right := sbRightW, rc.bottom := sbTopW + arrowHeight
        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", trackBrush, "Void")

        rc.left := sbLeftW, rc.top := sbBottomW - arrowHeight, rc.right := sbRightW, rc.bottom := sbBottomW
        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", trackBrush, "Void")

        DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", hdc, "Void")
    }

    static ListViewProc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_NCPAINT := 0x0085
        static WM_NCMOUSEMOVE := 0x00A0
        static WM_NCLBUTTONDOWN := 0x00A1
        static WM_NCLBUTTONUP := 0x00A2
        static WM_NCMOUSELEAVE := 0x02A2
        static WM_MOUSEWHEEL := 0x020A
        static WM_VSCROLL := 0x0115
        static WM_MOUSEMOVE := 0x0200
        static WM_LBUTTONUP := 0x0202
        static WM_CAPTURECHANGED := 0x0215
        static WM_TIMER := 0x0113
        static HTVSCROLL := 7
        static HTHSCROLL := 6

        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)

        ; Get header handle for proper alignment
        headerHwnd := this.HeaderHandles.Get(hwnd, 0)

        ; Handle NC paint - clip arrow regions BEFORE default paint
        if msg = WM_NCPAINT {
            clippedRgn := _DarkListView.ClipArrowRegion(hwnd, wParam)
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, clippedRgn || wParam, lParam)
            ; Fill excluded arrow areas with track color
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            if clippedRgn
                DllCall("DeleteObject", "Ptr", clippedRgn, "Void")
            return result
        }

        ; Handle scrollbar mouse interactions - let default handle, then hide arrows
        if msg = WM_NCMOUSEMOVE {
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)

            ; Check if over scrollbar - start continuous redraw timer
            if wParam = HTVSCROLL || wParam = HTHSCROLL {
                ; Start high-frequency timer if not already running
                if !this.HoverTimers.Has(hwnd) {
                    timerFn := _DarkListView.CreateArrowHideTimerFunc(hwnd, headerHwnd)
                    this.HoverTimerFuncs[hwnd] := timerFn
                    this.HoverTimers[hwnd] := true
                    SetTimer(timerFn, 30)  ; ~33fps — enough to mask arrow repaints at much lower churn than 16ms/60fps
                }
                _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            } else {
                ; Mouse moved to non-scrollbar NC area - stop timer
                this.StopHoverTimer(hwnd)
            }
            return result
        }

        ; Handle scrollbar click - clip arrows via SetWindowRgn before default proc
        if msg = WM_NCLBUTTONDOWN && (wParam = HTVSCROLL || wParam = HTHSCROLL) {
            _DarkListView.SetArrowClipRegion(hwnd)
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            _DarkListView.ClearArrowClipRegion(hwnd)
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            return result
        }

        if msg = WM_NCLBUTTONUP {
            _DarkListView.SetArrowClipRegion(hwnd)
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            _DarkListView.ClearArrowClipRegion(hwnd)
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            return result
        }

        if msg = WM_NCMOUSELEAVE {
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            this.StopHoverTimer(hwnd)
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            SetTimer(() => (_DarkListView.HideScrollbarArrows(hwnd, headerHwnd), 0), -50)
            SetTimer(() => (_DarkListView.HideScrollbarArrows(hwnd, headerHwnd), 0), -100)
            return result
        }

        ; Handle scroll events - clip during drag, paint-over otherwise
        if msg = WM_MOUSEWHEEL || msg = WM_VSCROLL {
            isDragging := DllCall("GetCapture", "Ptr") = hwnd
            if isDragging
                _DarkListView.SetArrowClipRegion(hwnd)
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            if isDragging
                _DarkListView.ClearArrowClipRegion(hwnd)
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            return result
        }

        ; Handle mouse move during scrollbar drag - clip arrows via SetWindowRgn
        if msg = WM_MOUSEMOVE {
            if DllCall("GetCapture", "Ptr") = hwnd {
                _DarkListView.SetArrowClipRegion(hwnd)
                result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
                _DarkListView.ClearArrowClipRegion(hwnd)
                _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
                return result
            }
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
        }

        ; Handle timer messages (Windows uses timers for scroll repeat)
        if msg = WM_TIMER {
            isDragging := DllCall("GetCapture", "Ptr") = hwnd
            if isDragging
                _DarkListView.SetArrowClipRegion(hwnd)
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            if isDragging
                _DarkListView.ClearArrowClipRegion(hwnd)
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            return result
        }

        ; Handle capture change - drag ended
        if msg = WM_CAPTURECHANGED {
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            this.StopHoverTimer(hwnd)
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            return result
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    /**
     * Applies dark mode to a ListView control.
     * Sets body/text/grid colors, custom-draws header and items via
     * `NM_CUSTOMDRAW`, applies `DarkMode_Explorer` theme for dark scrollbars,
     * and removes the default border.
     *
     * @param {Gui.ListView} lv - ListView control instance.
     * @param {String} [style = "Explorer"] - Theme style name.
     */
    static SetDarkMode(lv, style := "Explorer") {
        static LVS_EX_DOUBLEBUFFER := 0x10000
        static LVM_SETBKCOLOR := 0x1001
        static LVM_SETTEXTBKCOLOR := 0x1026
        static LVM_SETTEXTCOLOR := 0x1024
        static NM_CUSTOMDRAW := -12
        static UIS_SET := 1
        static UISF_HIDEFOCUS := 0x1
        static WM_CHANGEUISTATE := 0x0127
        static WM_NOTIFY := 0x4E
        static WM_THEMECHANGED := 0x031A

        lv.Header := lv.GetHeader()

        ; Set ListView body colors and grid line color
        static LVM_SETOUTLINECOLOR := 0x1047
        SendMessage(LVM_SETBKCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]), lv)
        SendMessage(LVM_SETTEXTBKCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]), lv)
        SendMessage(LVM_SETTEXTCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]), lv)
        SendMessage(LVM_SETOUTLINECOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["GridLine"]), lv)

        lv.OnMessage(WM_THEMECHANGED, (*) => 0)

        ; Custom draw header and ListView items
        lv.OnMessage(WM_NOTIFY, (lv, wParam, lParam, Msg) {
            static CDDS_ITEMPREPAINT := 0x10001
            static CDDS_PREPAINT := 0x1
            static CDDS_SUBITEM := 0x20000
            static CDDS_ITEMPOSTPAINT := 0x10002
            static CDRF_DODEFAULT := 0x0
            static CDRF_NOTIFYITEMDRAW := 0x20
            static CDRF_NOTIFYSUBITEMDRAW := 0x20
            static CDRF_SKIPDEFAULT := 0x4
            static CDRF_NEWFONT := 0x2
            static HDM_GETITEMCOUNT := 0x1200
            static HDM_GETITEMRECT := 0x1207
            static HDM_GETITEM := 0x120B
            static HDI_TEXT := 0x2
            static DT_CENTER := 0x1
            static DT_VCENTER := 0x4
            static DT_SINGLELINE := 0x20
            static CDIS_SELECTED := 0x1
            static CDIS_FOCUS := 0x10

            if (DM_NMHDR.At(lParam).code != NM_CUSTOMDRAW)
                return

            nmcd := DM_NMCUSTOMDRAW.At(lParam)

            ; Handle header custom draw
            if (nmcd.hdr.hwndFrom = lv.Header) {
                switch nmcd.dwDrawStage {
                    case CDDS_PREPAINT:
                        return CDRF_NOTIFYITEMDRAW
                    case CDDS_ITEMPREPAINT:
                        hdc := nmcd.hdc
                        itemIndex := nmcd.dwItemSpec

                        rc := DM_RECT()
                        SendMessage(HDM_GETITEMRECT, itemIndex, rc.Ptr, lv.Header)

                        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", DarkTheme.GetBrush("Background"), "Void")

                        textBuf := Buffer(256, 0)
                        hdItem := DM_HDITEMW()
                        hdItem.mask       := HDI_TEXT
                        hdItem.pszText    := textBuf.Ptr
                        hdItem.cchTextMax := 128
                        SendMessage(HDM_GETITEM, itemIndex, hdItem.Ptr, lv.Header)

                        DllCall("SetTextColor", "Ptr", hdc, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]), "Void")
                        DllCall("SetBkMode", "Ptr", hdc, "Int", 1, "Void")

                        left := rc.left + DarkTheme.Scale(8)
                        top := rc.top
                        right := rc.right - DarkTheme.Scale(4)
                        bottom := rc.bottom
                        rcText := DM_RECT()
                        rcText.left := left, rcText.top := top, rcText.right := right, rcText.bottom := bottom

                        DllCall("DrawTextW", "Ptr", hdc, "Ptr", textBuf.Ptr, "Int", -1, "Ptr", rcText, "UInt", DT_VCENTER | DT_SINGLELINE, "Void")

                        return CDRF_SKIPDEFAULT
                }
                return CDRF_DODEFAULT
            }

            ; Handle ListView item custom draw
            if (nmcd.hdr.hwndFrom = lv.Hwnd) {
                switch nmcd.dwDrawStage {
                    case CDDS_PREPAINT:
                        return CDRF_NOTIFYITEMDRAW
                    case CDDS_ITEMPREPAINT:
                        isSelected := nmcd.uItemState & CDIS_SELECTED

                        if isSelected {
                            ; Keep selection blue even when ListView loses focus
                            DllCall("SetTextColor", "Ptr", nmcd.hdc, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]), "Void")
                            DllCall("SetBkColor", "Ptr", nmcd.hdc, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Selection"]), "Void")
                        } else {
                            DllCall("SetTextColor", "Ptr", nmcd.hdc, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]), "Void")
                            DllCall("SetBkColor", "Ptr", nmcd.hdc, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]), "Void")
                        }
                        return CDRF_NEWFONT
                }
                return CDRF_DODEFAULT
            }

            return CDRF_DODEFAULT
        })

        lv.Opt("+LV" LVS_EX_DOUBLEBUFFER)
        SendMessage(WM_CHANGEUISTATE, (UIS_SET << 8) | UISF_HIDEFOCUS, 0, lv)

        ; Apply dark theme to header
        DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Header, "Str", "DarkMode_ItemsView", "Ptr", 0)
        DarkTheme.AllowDarkMode(lv.Hwnd)
        DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Hwnd, "Str", "Explorer", "Ptr", 0)
        DarkTheme.RemoveBorder(lv.Hwnd)

        ; Replace default checkbox ImageList with dark-themed one (only if +Checked)
        static LVS_EX_CHECKBOXES := 0x4
        exStyle := SendMessage(0x1037, 0, 0, lv)  ; LVM_GETEXTENDEDLISTVIEWSTYLE
        if exStyle & LVS_EX_CHECKBOXES
            this.SetDarkCheckboxes(lv)

        ; Store header handle
        this.HeaderHandles[lv.Hwnd] := lv.Header
    }

    /**
     * Creates a state ImageList with native dark-themed checkboxes using the Windows
     * theme engine (OpenThemeData + DrawThemeBackground with BP_CHECKBOX).
     * This renders the same checkbox visuals that standalone CheckBox controls use.
     */
    static SetDarkCheckboxes(lv) {
        static LVM_SETIMAGELIST := 0x1003
        static LVSIL_STATE := 2
        static ILC_COLOR32 := 0x20
        static BP_CHECKBOX := 3
        static CBS_UNCHECKEDNORMAL := 1
        static CBS_CHECKEDNORMAL := 5

        ; Get the theme handle from the dark-mode-enabled ListView
        hTheme := DllCall("uxtheme\OpenThemeData", "Ptr", lv.Hwnd, "Str", "BUTTON", "Ptr")
        if !hTheme
            return

        ; Query the theme for the actual checkbox glyph size
        sz := DM_SIZE()
        DllCall("uxtheme\GetThemePartSize", "Ptr", hTheme, "Ptr", 0,
            "Int", BP_CHECKBOX, "Int", CBS_CHECKEDNORMAL, "Ptr", 0, "Int", 1, "Ptr", sz.Ptr)
        glyphW := sz.cx
        glyphH := sz.cy

        ; Use glyph size with padding for the ImageList
        cxImg := glyphW + 4
        cyImg := glyphH + 4

        hIml := DllCall("comctl32\ImageList_Create", "Int", cxImg, "Int", cyImg, "UInt", ILC_COLOR32, "Int", 3, "Int", 1, "Ptr")

        ; State 0 = blank, State 1 = unchecked, State 2 = checked
        states := [0, CBS_UNCHECKEDNORMAL, CBS_CHECKEDNORMAL]

        for stateVal in states {
            hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
            hdc := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
            hBmp := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", cxImg, "Int", cyImg, "Ptr")
            hOld := DllCall("SelectObject", "Ptr", hdc, "Ptr", hBmp, "Ptr")
            DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen, "Void")

            ; Fill background with ListView body color
            rc := DM_RECT()
            rc.left := 0, rc.top := 0, rc.right := cxImg, rc.bottom := cyImg
            bgBrush := DllCall("CreateSolidBrush", "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]), "Ptr")
            DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", bgBrush, "Void")
            DllCall("DeleteObject", "Ptr", bgBrush, "Void")

            ; Draw the native themed checkbox glyph (skip for state 0 = blank)
            if stateVal > 0 {
                glyphRC := DM_RECT()
                glyphX := (cxImg - glyphW) // 2
                glyphY := (cyImg - glyphH) // 2
                glyphRC.left := glyphX, glyphRC.top := glyphY, glyphRC.right := glyphX + glyphW, glyphRC.bottom := glyphY + glyphH
                DllCall("uxtheme\DrawThemeBackground", "Ptr", hTheme, "Ptr", hdc,
                    "Int", BP_CHECKBOX, "Int", stateVal, "Ptr", glyphRC, "Ptr", 0)
            }

            DllCall("SelectObject", "Ptr", hdc, "Ptr", hOld, "Void")
            DllCall("comctl32\ImageList_Add", "Ptr", hIml, "Ptr", hBmp, "Ptr", 0)
            DllCall("DeleteObject", "Ptr", hBmp, "Void")
            DllCall("DeleteDC", "Ptr", hdc, "Void")
        }

        DllCall("uxtheme\CloseThemeData", "Ptr", hTheme)
        SendMessage(LVM_SETIMAGELIST, LVSIL_STATE, hIml, lv)

        ; Subclass the ListView to intercept item insertions and ensure
        ; new rows always get state 1 (unchecked visible box) instead of state 0 (blank)
        this.InstallCheckboxSubclass(lv)
    }

    static _CheckboxSubclassCallbacks := Map()

    static InstallCheckboxSubclass(lv) {
        hwnd := lv.Hwnd
        cb := CallbackCreate(ObjBindMethod(this, "CheckboxSubclassProc"), , 6)
        this._CheckboxSubclassCallbacks[hwnd] := cb
        DllCall("SetWindowSubclass", "Ptr", hwnd, "Ptr", cb, "Ptr", hwnd, "Ptr", 0, "Void")

        ; Fix any existing rows with state 0
        static LVM_GETITEMCOUNT := 0x1004
        static LVM_SETITEMSTATE := 0x102B
        static LVIS_STATEIMAGEMASK := 0xF000

        rowCount := SendMessage(LVM_GETITEMCOUNT, 0, 0, lv)
        loop rowCount {
            idx := A_Index - 1
            curState := SendMessage(0x102C, idx, LVIS_STATEIMAGEMASK, lv)  ; LVM_GETITEMSTATE
            if (curState & 0xF000) = 0 {
                ; LVM_SETITEMSTATE reads only state (offset 12) and stateMask (offset 16);
                ; the item index comes from wParam, so iItem/iSubItem are ignored here.
                lvItem := DM_LVITEMW()
                lvItem.state     := 0x1000
                lvItem.stateMask := LVIS_STATEIMAGEMASK
                SendMessage(LVM_SETITEMSTATE, idx, lvItem.Ptr, lv)
            }
        }
    }

    static CheckboxSubclassProc(hwnd, msg, wParam, lParam, uIdSubclass, dwRefData) {
        static LVM_INSERTITEMA := 0x1007
        static LVM_INSERTITEMW := 0x104D
        static LVM_SETITEMSTATE := 0x102B
        static LVIS_STATEIMAGEMASK := 0xF000
        static WM_DESTROY := 0x0002

        ; Intercept item insertion — if state image is 0 (blank), set to 1 (unchecked).
        ; Overlay the incoming DM_LVITEMW so the real field offsets (state=12, stateMask=16)
        ; are used; the earlier raw-offset math clobbered iItem/iSubItem instead.
        static LVIF_STATE := 0x8
        if msg = LVM_INSERTITEMA || msg = LVM_INSERTITEMW {
            if lParam {
                item := DM_LVITEMW.At(lParam)
                if ((item.state & 0xF000) >> 12) = 0 {
                    ; LVM_INSERTITEM only honors state when LVIF_STATE is in mask
                    item.mask      |= LVIF_STATE
                    item.state     |= 0x1000
                    item.stateMask |= LVIS_STATEIMAGEMASK
                }
            }
        }

        if msg = WM_DESTROY {
            if _DarkListView._CheckboxSubclassCallbacks.Has(hwnd) {
                DllCall("RemoveWindowSubclass", "Ptr", hwnd, "Ptr", _DarkListView._CheckboxSubclassCallbacks[hwnd], "Ptr", hwnd, "Void")
                CallbackFree(_DarkListView._CheckboxSubclassCallbacks[hwnd])
                _DarkListView._CheckboxSubclassCallbacks.Delete(hwnd)
            }
        }

        return DllCall("DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }
}

/**
 * Owner-draw dark button with hover/pressed states and rounded corners.
 * Supports both standard dark buttons and accent-colored (blue) buttons.
 * Use mode `"accent"` for primary action buttons.
 *
 * Uses window subclassing for complete control rendering via {@link Subclass}.
 */
class _DarkButton extends Gui.Button {
    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    /**
     * Per-button state — one object per hwnd in {@link _DarkButton.State},
     * replacing the former 14 parallel hwnd-keyed maps (one lookup and one
     * delete instead of fourteen, and impossible to forget a map on cleanup).
     */
    class BtnState {
        btn := 0             ; the Gui.Button instance
        text := ""           ; cached button caption
        mode := "default"    ; default|accent|icon|split|command|toggle|flat
        hover := false       ; mouse over the control
        pressed := false     ; mouse/space currently pressing
        focus := false       ; holds keyboard focus (drives the focus ring)
        icon := 0            ; HICON for icon/command buttons (0 = none)
        iconOwned := false   ; true if we loaded it and must DestroyIcon on Remove
        iconAlign := "left"  ; left|right|top|center
        menu := 0            ; split-button Menu shown on arrow click (0 = none)
        onDropdown := 0      ; split-button dropdown callback, alt to menu (0 = none)
        desc := ""           ; command-link description text
        toggle := false      ; latched on/off state for toggle buttons
        hoverArrow := false  ; mouse over the split dropdown-arrow region
    }

    /** @type {Map} hwnd -> {@link _DarkButton.BtnState} */
    static State := Map()
    /** @type {Map} Window procedure callbacks (shared Subclass infrastructure) */
    static Callbacks := Map()
    /** @type {Map} Original window procedures for restoration (Subclass infrastructure) */
    static OldProcs := Map()

    /** Returns the BtnState for hwnd, creating it on first use. */
    static _State(hwnd) {
        if !this.State.Has(hwnd)
            this.State[hwnd] := _DarkButton.BtnState()
        return this.State[hwnd]
    }

    /**
     * Applies owner-draw dark mode to button.
     * @param {Gui.Button} btn - Button control instance
     * @param {String} mode - "default" for dark grey, "accent" for blue highlight
     */
    static ApplyDarkMode(btn, mode := "default") {
        hwnd := btn.Hwnd
        s := this._State(hwnd)
        s.btn := btn
        ; Idempotent: factories may go gui.Add → DarkGui.Add → ApplyDarkMode("default")
        ; then re-call ApplyDarkMode("icon"|"split"|...). Only install the subclass
        ; and capture the caption once (BtnState defaults cover the rest).
        if !this.OldProcs.Has(hwnd) {
            s.text := btn.Text
            Subclass.Install(hwnd, ObjBindMethod(this, "ButtonProc", hwnd), this.Callbacks, this.OldProcs)
        }
        s.mode := mode
        DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1, "Void")
    }

    /**
     * Removes subclass and frees resources for a button.
     * @param {Ptr} hwnd - Button window handle
     */
    static Remove(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
        if this.State.Has(hwnd) {
            s := this.State[hwnd]
            if s.iconOwned && s.icon
                DllCall("DestroyIcon", "Ptr", s.icon, "Void")
            this.State.Delete(hwnd)
        }
    }

    /**
     * Adds an icon button: an image (HICON, image path, or `"file.dll,index"`) plus optional text.
     * @param {Gui} gui - Parent Gui (DarkGui registers automatic cleanup; plain Gui works too)
     * @param {String} options - Standard Gui.Add options (x/y/w/h/etc.)
     * @param {String} text - Button text (empty for icon-only)
     * @param {String|Integer} icon - HICON handle, image path, or `"file.dll,index"` string
     * @param {String} [align="left"] - "left" | "right" | "top" | "center"
     * @returns {Gui.Button}
     */
    static AddIcon(gui, options, text, icon, align := "left") {
        btn := gui.Add("Button", options, text)
        owned := false
        hicon := this._ResolveIcon(icon, &owned, DarkTheme.Scale(16))
        s := this._State(btn.Hwnd)
        s.icon := hicon, s.iconOwned := owned, s.iconAlign := align
        this._RegisterWithGui(gui, btn.Hwnd)
        this.ApplyDarkMode(btn, "icon")
        return btn
    }

    /**
     * Adds a split (dropdown) button: main face fires Click; right-edge arrow opens a menu.
     * @param {Gui} gui - Parent Gui
     * @param {String} options - Standard Gui.Add options
     * @param {String} text - Button text
     * @param {Menu|Func} menuOrCallback - A Menu shown automatically, or a Func receiving (button)
     * @returns {Gui.Button}
     */
    static AddSplit(gui, options, text, menuOrCallback) {
        btn := gui.Add("Button", options, text)
        s := this._State(btn.Hwnd)
        if menuOrCallback is Menu
            s.menu := menuOrCallback
        else if HasMethod(menuOrCallback)
            s.onDropdown := menuOrCallback
        else
            throw TypeError("AddSplit: menuOrCallback must be a Menu or callable", -1)
        this._RegisterWithGui(gui, btn.Hwnd)
        this.ApplyDarkMode(btn, "split")
        return btn
    }

    /**
     * Adds a Vista-style command-link button: large title plus small description, optional left icon.
     * @param {Gui} gui - Parent Gui
     * @param {String} options - Standard Gui.Add options (give it h>=56 for legibility)
     * @param {String} title - Primary line
     * @param {String} description - Secondary line in dim text
     * @param {String|Integer} [icon=0] - Icon spec (0 paints a default chevron)
     * @returns {Gui.Button}
     */
    static AddCommand(gui, options, title, description, icon := 0) {
        btn := gui.Add("Button", options, title)
        owned := false
        hicon := this._ResolveIcon(icon, &owned, DarkTheme.Scale(20))
        s := this._State(btn.Hwnd)
        s.icon := hicon, s.iconOwned := owned, s.desc := description
        this._RegisterWithGui(gui, btn.Hwnd)
        this.ApplyDarkMode(btn, "command")
        return btn
    }

    /**
     * Adds a sticky toggle button. Exposes an `IsToggled` property on the returned button.
     * @param {Gui} gui - Parent Gui
     * @param {String} options - Standard Gui.Add options
     * @param {String} text - Button text
     * @param {Boolean} [initialState=false] - Starting toggle value
     * @returns {Gui.Button}
     */
    static AddToggle(gui, options, text, initialState := false) {
        btn := gui.Add("Button", options, text)
        this._State(btn.Hwnd).toggle := !!initialState
        btn.DefineProp("IsToggled", {
            Get: (b) => _DarkButton._State(b.Hwnd).toggle,
            Set: (b, v) => (_DarkButton._State(b.Hwnd).toggle := !!v,
                            DllCall("InvalidateRect", "Ptr", b.Hwnd, "Ptr", 0, "Int", 1, "Void"), 0)
        })
        this._RegisterWithGui(gui, btn.Hwnd)
        this.ApplyDarkMode(btn, "toggle")
        return btn
    }

    /**
     * Adds a flat (borderless) button: no fill at idle, hover/press only.
     * @param {Gui} gui - Parent Gui
     * @param {String} options - Standard Gui.Add options
     * @param {String} text - Button text
     * @returns {Gui.Button}
     */
    static AddFlat(gui, options, text) {
        btn := gui.Add("Button", options, text)
        this._RegisterWithGui(gui, btn.Hwnd)
        this.ApplyDarkMode(btn, "flat")
        return btn
    }

    /**
     * Resolves an icon spec to an HICON handle.
     * @param {*} icon - HICON int, image path string, or `"file.dll,index"` string
     * @param {VarRef<Boolean>} owned - Set true when this call allocated the icon
     * @param {Integer} sizePx - Target size in pixels (used for LoadImage)
     * @returns {Ptr} HICON or 0
     */
    static _ResolveIcon(icon, &owned, sizePx) {
        owned := false
        if !icon
            return 0
        if IsObject(icon)
            return 0
        if icon is Integer
            return icon
        s := String(icon)
        if s = ""
            return 0
        owned := true
        if InStr(s, ",") {
            parts := StrSplit(s, ",")
            iconPath := parts[1]
            idx := Integer(parts.Get(2, 0))
            return DllCall("shell32\ExtractIconW", "Ptr", 0, "Str", iconPath, "UInt", idx, "Ptr")
        }
        static IMAGE_ICON := 1, LR_LOADFROMFILE := 0x10
        return DllCall("user32\LoadImageW", "Ptr", 0, "Str", s, "UInt", IMAGE_ICON,
                       "Int", sizePx, "Int", sizePx, "UInt", LR_LOADFROMFILE, "Ptr")
    }

    /**
     * Registers an hwnd with a DarkGui's cleanup map when applicable.
     * @param {Gui} gui
     * @param {Ptr} hwnd
     */
    static _RegisterWithGui(gui, hwnd) {
        if HasProp(gui, "_darkHwnds")
            gui._darkHwnds[hwnd] := "Button"
    }

    static ButtonProc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F
        static WM_ENABLE := 0x000A
        static WM_ERASEBKGND := 0x0014
        static WM_MOUSEMOVE := 0x0200
        static WM_MOUSELEAVE := 0x02A3
        static WM_LBUTTONDOWN := 0x0201
        static WM_LBUTTONUP := 0x0202

        if msg = WM_ERASEBKGND
            return 1

        if msg = WM_PAINT {
            this.PaintButton(targetHwnd)
            return 0
        }

        ; Every remaining handler reads/writes this button's state.
        s := this._State(targetHwnd)

        ; Repaint when the enabled state flips so the dimmed look tracks .Enabled.
        if msg = WM_ENABLE {
            DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1, "Void")
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
        }

        if msg = WM_MOUSEMOVE {
            ; Sign-extend the LOWORD/HIWORD of lParam to handle negative coords during capture
            mx := lParam & 0xFFFF
            if mx & 0x8000
                mx -= 0x10000
            inArrow := this._IsSplitButton(targetHwnd) && this._PointInArrow(targetHwnd, mx)
            ; hoverArrow defaults false on non-split buttons, so this is a no-op there.
            if s.hoverArrow != inArrow {
                s.hoverArrow := inArrow
                DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1, "Void")
            }
            if !s.hover {
                s.hover := true
                static TME_LEAVE := 0x2
                tme := DM_TRACKMOUSEEVENT()
                tme.cbSize    := tme.Size
                tme.dwFlags   := TME_LEAVE
                tme.hwndTrack := targetHwnd
                DllCall("TrackMouseEvent", "Ptr", tme.Ptr, "Void")
                DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1, "Void")
            }
            return 0
        }

        if msg = WM_MOUSELEAVE {
            s.hover := false
            s.hoverArrow := false
            DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1, "Void")
            return 0
        }

        if msg = WM_LBUTTONDOWN {
            s.pressed := true
            DllCall("SetCapture", "Ptr", targetHwnd, "Void")
            DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1, "Void")
            return 0
        }

        if msg = WM_LBUTTONUP {
            wasPressed := s.pressed
            s.pressed := false
            DllCall("ReleaseCapture", "Void")
            DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1, "Void")
            if wasPressed {
                rc := DM_RECT()
                DllCall("GetClientRect", "Ptr", targetHwnd, "Ptr", rc)
                pt := DM_POINT()
                DllCall("GetCursorPos", "Ptr", pt.Ptr)
                DllCall("ScreenToClient", "Ptr", targetHwnd, "Ptr", pt.Ptr, "Void")
                x := pt.x, y := pt.y
                w := rc.right, h := rc.bottom
                if (x >= 0 && x < w && y >= 0 && y < h) {
                    if this._IsSplitButton(targetHwnd) && this._PointInArrow(targetHwnd, x)
                        this._ShowDropdown(targetHwnd)
                    else
                        this._FireClick(targetHwnd)
                }
            }
            return 0
        }

        ; Keyboard parity with native buttons. We own WM_PAINT, so the original
        ; proc's focus rect never shows; track focus ourselves and draw a ring.
        static WM_GETDLGCODE := 0x0087
        static WM_SETFOCUS := 0x0007
        static WM_KILLFOCUS := 0x0008
        static WM_KEYDOWN := 0x0100
        static WM_KEYUP := 0x0101
        static WM_SYSKEYDOWN := 0x0104
        static BM_CLICK := 0x00F5
        static VK_SPACE := 0x20
        static VK_DOWN := 0x28
        static DLGC_BUTTON := 0x2000
        static DLGC_WANTARROWS := 0x0001

        if msg = WM_GETDLGCODE {
            ; Split buttons claim arrow keys so Down can open the dropdown.
            return this._IsSplitButton(targetHwnd) ? DLGC_BUTTON | DLGC_WANTARROWS : DLGC_BUTTON
        }

        if msg = WM_SETFOCUS || msg = WM_KILLFOCUS {
            s.focus := (msg = WM_SETFOCUS)
            DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1, "Void")
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
        }

        if msg = WM_KEYDOWN {
            ; Space presses in (visual only); fires on key-up like a real button.
            if wParam = VK_SPACE {
                if !s.pressed {
                    s.pressed := true
                    DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1, "Void")
                }
                return 0
            }
            if wParam = VK_DOWN && this._IsSplitButton(targetHwnd) {
                this._ShowDropdown(targetHwnd)
                return 0
            }
        }

        ; Alt+Down opens the split dropdown (Win32/.NET convention).
        if msg = WM_SYSKEYDOWN && wParam = VK_DOWN && this._IsSplitButton(targetHwnd) {
            this._ShowDropdown(targetHwnd)
            return 0
        }

        if msg = WM_KEYUP && wParam = VK_SPACE && s.pressed {
            s.pressed := false
            DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1, "Void")
            this._FireClick(targetHwnd)
            return 0
        }

        ; Mnemonic (Alt+letter) and programmatic clicks arrive as BM_CLICK;
        ; route them through the same path so toggle state stays consistent.
        if msg = BM_CLICK {
            this._FireClick(targetHwnd)
            return 0
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    /** Flips toggle state when applicable, then notifies the parent with BN_CLICKED
     *  so the Gui's normal Click event fires. Shared by mouse, keyboard, and mnemonic. */
    static _FireClick(hwnd) {
        s := this._State(hwnd)
        if s.mode = "toggle"
            s.toggle := !s.toggle
        parent := DllCall("GetParent", "Ptr", hwnd, "Ptr")
        ctrlId := DllCall("GetDlgCtrlID", "Ptr", hwnd, "Int")
        static BN_CLICKED := 0, WM_COMMAND := 0x0111
        DllCall("SendMessage", "Ptr", parent, "UInt", WM_COMMAND, "Ptr", (BN_CLICKED << 16) | ctrlId, "Ptr", hwnd)
    }

    /** True when this button is registered as a split (dropdown) button. */
    static _IsSplitButton(hwnd) {
        return this.State.Has(hwnd) && this.State[hwnd].mode = "split"
    }

    /** True when client-x falls inside the dropdown-arrow region. */
    static _PointInArrow(hwnd, clientX) {
        rc := DM_RECT()
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
        w := rc.right
        arrowW := DarkTheme.Scale(20)
        return clientX >= w - arrowW && clientX < w
    }

    /** Shows the configured dropdown menu (or invokes the callback) anchored under the button.
     * Calls TrackPopupMenu directly so we can speak physical pixels end-to-end — GetWindowRect
     * returns physical, TrackPopupMenu takes physical. Avoids Menu.Show's DPI auto-scaling,
     * which silently mangles coordinates on high-DPI displays. The parent gui hwnd is the
     * owner so AHK's normal WM_COMMAND dispatch still fires the menu item callbacks. */
    static _ShowDropdown(hwnd) {
        s := this._State(hwnd)
        if s.onDropdown {
            s.onDropdown(s.btn)
            return
        }
        if !s.menu || !s.btn
            return
        rc := DM_RECT()
        DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
        DllCall("TrackPopupMenu",
            "Ptr", s.menu.Handle,
            "UInt", 0,
            "Int", rc.left,
            "Int", rc.bottom,
            "Int", 0,
            "Ptr", s.btn.Gui.Hwnd,
            "Ptr", 0)
    }

    static PaintButton(hwnd) {
        ps := DM_PAINTSTRUCT()
        hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps.Ptr, "Ptr")

        rc := DM_RECT()
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
        w := rc.right
        h := rc.bottom

        s := this._State(hwnd)
        mode := s.mode
        switch mode {
            case "icon":    this._PaintIcon(hwnd, hdc, w, h)
            case "split":   this._PaintSplit(hwnd, hdc, w, h)
            case "command": this._PaintCommand(hwnd, hdc, w, h)
            case "toggle":  this._PaintToggle(hwnd, hdc, w, h)
            case "flat":    this._PaintFlat(hwnd, hdc, w, h)
            default:        this._PaintBasic(hwnd, hdc, w, h)
        }

        ; Keyboard focus ring on top of whatever the mode drew.
        if s.focus
            this._PaintFocusRing(hdc, w, h, mode = "accent" ? 0xFFFFFF : DarkTheme.Colors["Accent"])

        DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps.Ptr, "Void")
    }

    /** Draws a 1px rounded focus ring inset from the client edge (no fill). */
    static _PaintFocusRing(hdc, w, h, ringColor) {
        pen := DarkTheme.GetPen(ringColor)
        nullBrush := DllCall("GetStockObject", "Int", 5, "Ptr")
        oldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")
        oldBrush := DllCall("SelectObject", "Ptr", hdc, "Ptr", nullBrush, "Ptr")
        r := this._Radius
        DllCall("RoundRect", "Ptr", hdc, "Int", 1, "Int", 1, "Int", w - 1, "Int", h - 1, "Int", r, "Int", r, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldPen, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldBrush, "Void")
    }

    /** Selects state-appropriate bg, text, and border colors for default/accent modes.
     * Win11-style: hover is a small lift, press is *darker* than rest (button "pushes in"). */
    static _StateColors(hwnd, mode) {
        ; A disabled button ignores hover/press and dims bg + text.
        if !DllCall("IsWindowEnabled", "Ptr", hwnd)
            return [DarkTheme.Colors["DisabledBg"], DarkTheme.Colors["DisabledText"], DarkTheme.Colors["ButtonBorder"]]
        s := this.State[hwnd]
        isHover := s.hover
        isPressed := s.pressed
        if mode = "accent" {
            bgColor := isPressed ? DarkTheme.Colors["AccentPressed"]
                     : (isHover ? DarkTheme.Colors["AccentHover"] : DarkTheme.Colors["Accent"])
            textColor := 0xFFFFFF
            borderColor := DarkTheme.Colors["AccentBorder"]
        } else {
            bgColor := isPressed ? DarkTheme.Colors["ButtonPressed"]
                     : (isHover ? DarkTheme.Colors["ButtonHover"] : DarkTheme.Colors["Controls"])
            textColor := DarkTheme.Colors["Font"]
            borderColor := DarkTheme.Colors["ButtonBorder"]
        }
        return [bgColor, textColor, borderColor]
    }

    /** Win11-feel button corner radius in DPI-scaled pixels. */
    static _Radius => DarkTheme.Scale(5)

    /** Fills the entire client rect with the parent (window) color.
     * Uses the cached Background brush — never delete it. */
    static _FillParent(hdc, rc) {
        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", DarkTheme.GetBrush("Background"), "Void")
    }

    /** Paints a rounded-rectangle fill with optional border color. */
    static _RoundFill(hdc, x1, y1, x2, y2, radius, bgColor, borderColor := -1) {
        bcol := borderColor = -1 ? bgColor : borderColor
        bg := DarkTheme.GetSolidBrush(bgColor)
        pen := DarkTheme.GetPen(bcol)
        oldBrush := DllCall("SelectObject", "Ptr", hdc, "Ptr", bg, "Ptr")
        oldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")
        DllCall("RoundRect", "Ptr", hdc, "Int", x1, "Int", y1, "Int", x2, "Int", y2, "Int", radius, "Int", radius, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldBrush, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldPen, "Void")
    }

    /** Selects the button's font into the dc and returns the previous font handle (0 if none). */
    static _SelectButtonFont(hwnd, hdc) {
        hFont := DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
        return hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0
    }

    /** Draws text using DrawText with a flag set; rect is a Buffer of DM_RECT. */
    static _DrawText(hdc, text, rect, color, flags) {
        DllCall("SetBkMode", "Ptr", hdc, "Int", 1, "Void")
        DllCall("SetTextColor", "Ptr", hdc, "UInt", DarkTheme.RGBtoBGR(color), "Void")
        DllCall("DrawTextW", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", rect, "UInt", flags, "Void")
    }

    /** Draws an HICON via DrawIconEx at (x,y) sized sizePx. */
    static _DrawIcon(hdc, hicon, x, y, sizePx) {
        if !hicon
            return
        static DI_NORMAL := 0x3
        DllCall("DrawIconEx", "Ptr", hdc, "Int", x, "Int", y, "Ptr", hicon,
                "Int", sizePx, "Int", sizePx, "UInt", 0, "Ptr", 0, "UInt", DI_NORMAL, "Void")
    }

    /** Constructs a DM_RECT for use with DrawText. */
    static _MakeRect(left, top, right, bottom) {
        rc := DM_RECT()
        rc.left := left, rc.top := top, rc.right := right, rc.bottom := bottom
        return rc
    }

    /** Default + accent path: rounded fill with thin border, centered text. */
    static _PaintBasic(hwnd, hdc, w, h) {
        rc := this._MakeRect(0, 0, w, h)
        s := this.State[hwnd]
        colors := this._StateColors(hwnd, s.mode)
        this._FillParent(hdc, rc)
        this._RoundFill(hdc, 0, 0, w, h, this._Radius, colors[1], colors[3])
        oldFont := this._SelectButtonFont(hwnd, hdc)
        static DT_CENTER := 0x1, DT_VCENTER := 0x4, DT_SINGLELINE := 0x20
        this._DrawText(hdc, s.text, rc, colors[2], DT_CENTER | DT_VCENTER | DT_SINGLELINE)
        if oldFont
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont, "Void")
    }

    /** Icon + optional text. align="left"|"right"|"top"|"center". */
    static _PaintIcon(hwnd, hdc, w, h) {
        rc := this._MakeRect(0, 0, w, h)
        colors := this._StateColors(hwnd, "default")
        this._FillParent(hdc, rc)
        this._RoundFill(hdc, 0, 0, w, h, this._Radius, colors[1], colors[3])

        s := this.State[hwnd]
        btnText := s.text
        hicon := s.icon
        align := s.iconAlign
        iconSize := DarkTheme.Scale(16)
        pad := DarkTheme.Scale(8)

        static DT_CENTER := 0x1, DT_VCENTER := 0x4, DT_SINGLELINE := 0x20, DT_LEFT := 0x0, DT_RIGHT := 0x2

        if !btnText {
            ; Icon-only — centered icon, no text
            if hicon {
                ix := (w - iconSize) // 2
                iy := (h - iconSize) // 2
                this._DrawIcon(hdc, hicon, ix, iy, iconSize)
            }
            return
        }

        oldFont := this._SelectButtonFont(hwnd, hdc)

        if align = "center" && hicon {
            ; Center align: icon centered, no text drawn (text-on-icon would clash)
            ix := (w - iconSize) // 2
            iy := (h - iconSize) // 2
            this._DrawIcon(hdc, hicon, ix, iy, iconSize)
        } else if align = "top" && hicon {
            ix := (w - iconSize) // 2
            iy := pad
            this._DrawIcon(hdc, hicon, ix, iy, iconSize)
            textRc := this._MakeRect(0, iy + iconSize + 2, w, h)
            this._DrawText(hdc, btnText, textRc, colors[2], DT_CENTER | DT_SINGLELINE)
        } else if align = "right" && hicon {
            ix := w - iconSize - pad
            iy := (h - iconSize) // 2
            this._DrawIcon(hdc, hicon, ix, iy, iconSize)
            textRc := this._MakeRect(pad, 0, ix - 2, h)
            this._DrawText(hdc, btnText, textRc, colors[2], DT_LEFT | DT_VCENTER | DT_SINGLELINE)
        } else if hicon {
            ; "left" (default)
            ix := pad
            iy := (h - iconSize) // 2
            this._DrawIcon(hdc, hicon, ix, iy, iconSize)
            textRc := this._MakeRect(ix + iconSize + 4, 0, w - pad, h)
            this._DrawText(hdc, btnText, textRc, colors[2], DT_LEFT | DT_VCENTER | DT_SINGLELINE)
        } else {
            ; No icon — fall back to centered text
            this._DrawText(hdc, btnText, rc, colors[2], DT_CENTER | DT_VCENTER | DT_SINGLELINE)
        }

        if oldFont
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont, "Void")
    }

    /** Split button: main text region + dropdown-arrow region with divider. */
    static _PaintSplit(hwnd, hdc, w, h) {
        rc := this._MakeRect(0, 0, w, h)
        baseColors := this._StateColors(hwnd, "default")
        this._FillParent(hdc, rc)

        arrowW := DarkTheme.Scale(20)
        s := this.State[hwnd]
        hoverArrow := s.hoverArrow
        isHover := s.hover
        isPressed := s.pressed

        ; Win11-feel: hover lifts subtly, press goes darker than rest
        mainHover := isHover && !hoverArrow
        mainBg := isPressed && !hoverArrow ? DarkTheme.Colors["ButtonPressed"]
                : (mainHover ? DarkTheme.Colors["ButtonHover"] : DarkTheme.Colors["Controls"])
        arrowHover := isHover && hoverArrow
        arrowBg := isPressed && hoverArrow ? DarkTheme.Colors["ButtonPressed"]
                 : (arrowHover ? DarkTheme.Colors["ButtonHover"] : DarkTheme.Colors["Controls"])

        ; Single rounded backdrop with thin border, then overlay arrow region
        radius := this._Radius
        this._RoundFill(hdc, 0, 0, w, h, radius, mainBg, baseColors[3])
        if arrowBg != mainBg {
            ; Overlay arrow region using a clipping intersection of the rounded rect
            arrowRc := this._MakeRect(w - arrowW, 0, w, h)
            saved := DllCall("SaveDC", "Ptr", hdc, "Int")
            rgn := DllCall("CreateRoundRectRgn", "Int", 1, "Int", 1, "Int", w, "Int", h,
                           "Int", radius - 1, "Int", radius - 1, "Ptr")
            DllCall("SelectClipRgn", "Ptr", hdc, "Ptr", rgn, "Void")
            DllCall("FillRect", "Ptr", hdc, "Ptr", arrowRc, "Ptr", DarkTheme.GetSolidBrush(arrowBg), "Void")
            DllCall("RestoreDC", "Ptr", hdc, "Int", saved, "Void")
            DllCall("DeleteObject", "Ptr", rgn, "Void")
        }

        ; Vertical divider line between regions
        oldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", DarkTheme.GetPen(DarkTheme.Colors["Border"]), "Ptr")
        divX := w - arrowW
        DllCall("MoveToEx", "Ptr", hdc, "Int", divX, "Int", DarkTheme.Scale(4), "Ptr", 0, "Void")
        DllCall("LineTo", "Ptr", hdc, "Int", divX, "Int", h - DarkTheme.Scale(4), "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldPen, "Void")

        ; Main text (left region)
        oldFont := this._SelectButtonFont(hwnd, hdc)
        textRc := this._MakeRect(0, 0, w - arrowW, h)
        static DT_CENTER := 0x1, DT_VCENTER := 0x4, DT_SINGLELINE := 0x20
        this._DrawText(hdc, s.text, textRc, baseColors[2], DT_CENTER | DT_VCENTER | DT_SINGLELINE)
        if oldFont
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont, "Void")

        ; Down-arrow triangle in arrow region
        this._PaintDownArrow(hdc, w - arrowW + arrowW // 2, h // 2, DarkTheme.Scale(4), baseColors[2])
    }

    /** Filled triangle pointing down, centered at (cx, cy), with half-width radius. */
    static _PaintDownArrow(hdc, cx, cy, radius, color) {
        tri := DM_TRIANGLE()
        tri.p[1].x := cx - radius, tri.p[1].y := cy - radius // 2
        tri.p[2].x := cx + radius, tri.p[2].y := cy - radius // 2
        tri.p[3].x := cx,          tri.p[3].y := cy + radius
        brush := DarkTheme.GetSolidBrush(color)
        pen := DarkTheme.GetPen(color)
        oldB := DllCall("SelectObject", "Ptr", hdc, "Ptr", brush, "Ptr")
        oldP := DllCall("SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")
        DllCall("Polygon", "Ptr", hdc, "Ptr", tri.Ptr, "Int", 3, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldB, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldP, "Void")
    }

    /** Right-pointing chevron used as the default command-link icon. */
    static _PaintRightArrow(hdc, cx, cy, radius, color) {
        tri := DM_TRIANGLE()
        tri.p[1].x := cx - radius // 2, tri.p[1].y := cy - radius
        tri.p[2].x := cx - radius // 2, tri.p[2].y := cy + radius
        tri.p[3].x := cx + radius,      tri.p[3].y := cy
        brush := DarkTheme.GetSolidBrush(color)
        pen := DarkTheme.GetPen(color)
        oldB := DllCall("SelectObject", "Ptr", hdc, "Ptr", brush, "Ptr")
        oldP := DllCall("SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")
        DllCall("Polygon", "Ptr", hdc, "Ptr", tri.Ptr, "Int", 3, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldB, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldP, "Void")
    }

    /** Vista-style command link: title + description + optional left icon (default chevron). */
    static _PaintCommand(hwnd, hdc, w, h) {
        rc := this._MakeRect(0, 0, w, h)
        colors := this._StateColors(hwnd, "default")
        this._FillParent(hdc, rc)
        this._RoundFill(hdc, 0, 0, w, h, this._Radius, colors[1], colors[3])

        pad := DarkTheme.Scale(12)
        iconSize := DarkTheme.Scale(20)
        s := this.State[hwnd]
        hicon := s.icon

        iconAreaX := pad
        iconAreaY := pad
        if hicon {
            this._DrawIcon(hdc, hicon, iconAreaX, iconAreaY, iconSize)
        } else {
            this._PaintRightArrow(hdc, iconAreaX + iconSize // 2, iconAreaY + iconSize // 2,
                                  DarkTheme.Scale(7), DarkTheme.Colors["Accent"])
        }

        textLeft := iconAreaX + iconSize + pad
        oldFont := this._SelectButtonFont(hwnd, hdc)

        cmdTitle := s.text
        desc := s.desc

        static DT_LEFT := 0x0, DT_TOP := 0x0, DT_SINGLELINE := 0x20, DT_WORDBREAK := 0x10, DT_END_ELLIPSIS := 0x8000
        titleRc := this._MakeRect(textLeft, pad, w - pad, pad + DarkTheme.Scale(22))
        this._DrawText(hdc, cmdTitle, titleRc, colors[2], DT_LEFT | DT_TOP | DT_SINGLELINE | DT_END_ELLIPSIS)

        descRc := this._MakeRect(textLeft, pad + DarkTheme.Scale(22) + 2, w - pad, h - pad)
        this._DrawText(hdc, desc, descRc, DarkTheme.Colors["FontDim"], DT_LEFT | DT_TOP | DT_WORDBREAK)

        if oldFont
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont, "Void")
    }

    /** Sticky toggle button — on-state mimics an Accent button so the active state really pops.
     * Off-state matches the default-mode button so toggles look at home next to regular buttons. */
    static _PaintToggle(hwnd, hdc, w, h) {
        rc := this._MakeRect(0, 0, w, h)
        s := this.State[hwnd]
        colors := this._StateColors(hwnd, s.toggle ? "accent" : "default")
        this._FillParent(hdc, rc)
        this._RoundFill(hdc, 0, 0, w, h, this._Radius, colors[1], colors[3])
        oldFont := this._SelectButtonFont(hwnd, hdc)
        static DT_CENTER := 0x1, DT_VCENTER := 0x4, DT_SINGLELINE := 0x20
        this._DrawText(hdc, s.text, rc, colors[2], DT_CENTER | DT_VCENTER | DT_SINGLELINE)
        if oldFont
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont, "Void")
    }

    /** Borderless flat button — no fill at idle, hover/press only. */
    static _PaintFlat(hwnd, hdc, w, h) {
        rc := this._MakeRect(0, 0, w, h)
        s := this.State[hwnd]
        isEnabled := DllCall("IsWindowEnabled", "Ptr", hwnd)
        isHover := isEnabled && s.hover
        isPressed := isEnabled && s.pressed

        this._FillParent(hdc, rc)
        if isPressed
            this._RoundFill(hdc, 0, 0, w, h, this._Radius, DarkTheme.Colors["FlatPressed"])
        else if isHover
            this._RoundFill(hdc, 0, 0, w, h, this._Radius, DarkTheme.Colors["ButtonHover"])

        oldFont := this._SelectButtonFont(hwnd, hdc)
        static DT_CENTER := 0x1, DT_VCENTER := 0x4, DT_SINGLELINE := 0x20
        textColor := isEnabled ? DarkTheme.Colors["Font"] : DarkTheme.Colors["DisabledText"]
        this._DrawText(hdc, s.text, rc, textColor, DT_CENTER | DT_VCENTER | DT_SINGLELINE)
        if oldFont
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont, "Void")
    }
}

/**
 * Owner-draw ComboBox with custom-drawn main control and styled dropdown.
 * Handles WM_PAINT for stable text rendering and rounded corners.
 */
class _DarkComboBox extends Gui.ComboBox {
    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    /** @type {Map} Window procedure callbacks */
    static Callbacks := Map()
    /** @type {Map} Original window procedures */
    static OldProcs := Map()

    /**
     * Applies dark theme with owner-draw rendering.
     * @param {Gui.ComboBox} combo - ComboBox control instance
     */
    static ApplyDarkMode(combo) {
        ; Use DarkMode_CFD for dropdown appearance
        DllCall("uxtheme\SetWindowTheme", "Ptr", combo.Hwnd, "Str", "DarkMode_CFD", "Ptr", 0)
        combo.SetFont("c" Format("{:X}", DarkTheme.Colors["Font"]))

        DarkTheme.RemoveBorder(combo.Hwnd)

        ; Get and style the dropdown list (ListBox part of ComboBox)
        static CB_GETCOMBOBOXINFO := 0x0164
        cbi := DM_COMBOBOXINFO()
        cbi.cbSize := cbi.Size
        if DllCall("SendMessage", "Ptr", combo.Hwnd, "UInt", CB_GETCOMBOBOXINFO, "Ptr", 0, "Ptr", cbi.Ptr) {
            listHwnd := cbi.hwndList
            if listHwnd {
                ; Apply dark theme to dropdown list for modern scrollbar
                DllCall("uxtheme\SetWindowTheme", "Ptr", listHwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                ; Register this as a ComboBox dropdown so WM_CTLCOLORLISTBOX uses Background color
                DarkWindowProc.ComboDropdowns[listHwnd] := true
            }
        }

        ; Subclass to handle WM_NCPAINT for custom border and focus indicator
        this.SubclassCombo(combo.Hwnd)
    }

    static SubclassCombo(hwnd) {
        Subclass.Install(hwnd, ObjBindMethod(this, "ComboProc", hwnd), this.Callbacks, this.OldProcs)
    }

    /**
     * Removes subclass and frees resources for a ComboBox.
     * @param {Ptr} hwnd - ComboBox window handle
     */
    static Remove(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
    }

    static ComboProc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F

        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)

        ; Completely take over WM_PAINT - don't call original proc to prevent text jumping
        if msg = WM_PAINT {
            this.DrawComboBox(hwnd)
            return 0
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    static DrawComboBox(hwnd) {
        ps := DM_PAINTSTRUCT()
        hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps.Ptr, "Ptr")
        if !hdc {
            ; Must still pair BeginPaint with EndPaint or the update region is
            ; never validated and WM_PAINT fires in a tight loop.
            DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps.Ptr, "Void")
            return
        }

        rc := DM_RECT()
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
        w := rc.right
        h := rc.bottom

        fontColor := DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"])

        ; Cached palette brushes — do not delete them
        bgBrush := DarkTheme.GetBrush("Background")
        ctrlBrush := DarkTheme.GetBrush("Controls")

        ; Step 1: Fill entire control with parent bg color (covers all exterior artifacts)
        fillRect := DM_RECT()
        fillRect.left := 0, fillRect.top := 0, fillRect.right := w, fillRect.bottom := h
        DllCall("FillRect", "Ptr", hdc, "Ptr", fillRect, "Ptr", bgBrush, "Void")

        ; Step 2: Fill interior with control color (rounded rect, no border)
        hOldBrush := DllCall("SelectObject", "Ptr", hdc, "Ptr", ctrlBrush, "Ptr")
        nullPen := DllCall("GetStockObject", "Int", 8, "Ptr")  ; NULL_PEN
        hOldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", nullPen, "Ptr")
        comboRadius := DarkTheme.Scale(6)
        DllCall("RoundRect", "Ptr", hdc, "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", comboRadius, "Int", comboRadius, "Void")

        ; Step 3: Draw dropdown arrow (cached 2px pen — do not delete)
        arrowPen := DarkTheme.GetPen(DarkTheme.Colors["Font"], 2)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", arrowPen, "Void")

        arrowCenterX := w - DarkTheme.Scale(12)
        arrowCenterY := h // 2
        arrowHalfWidth := DarkTheme.Scale(4)
        arrowHeight := DarkTheme.Scale(3)

        DllCall("MoveToEx", "Ptr", hdc, "Int", arrowCenterX - arrowHalfWidth, "Int", arrowCenterY - arrowHeight, "Ptr", 0, "Void")
        DllCall("LineTo", "Ptr", hdc, "Int", arrowCenterX, "Int", arrowCenterY + 1, "Void")
        DllCall("MoveToEx", "Ptr", hdc, "Int", arrowCenterX, "Int", arrowCenterY + 1, "Ptr", 0, "Void")
        DllCall("LineTo", "Ptr", hdc, "Int", arrowCenterX + arrowHalfWidth, "Int", arrowCenterY - arrowHeight, "Void")

        ; Step 5: Draw text
        static WM_GETTEXT := 0x000D
        static WM_GETTEXTLENGTH := 0x000E
        static WM_GETFONT := 0x0031
        textLen := DllCall("SendMessage", "Ptr", hwnd, "UInt", WM_GETTEXTLENGTH, "Ptr", 0, "Ptr", 0, "Int")
        if textLen > 0 {
            textBuf := Buffer((textLen + 1) * 2, 0)
            DllCall("SendMessage", "Ptr", hwnd, "UInt", WM_GETTEXT, "Ptr", textLen + 1, "Ptr", textBuf)

            DllCall("SetTextColor", "Ptr", hdc, "UInt", fontColor, "Void")
            DllCall("SetBkMode", "Ptr", hdc, "Int", 1, "Void")  ; TRANSPARENT

            hFont := DllCall("SendMessage", "Ptr", hwnd, "UInt", WM_GETFONT, "Ptr", 0, "Ptr", 0, "Ptr")
            hOldFont := 0
            if hFont
                hOldFont := DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")

            rcText := DM_RECT()
            rcText.left := DarkTheme.Scale(6), rcText.top := 0, rcText.right := w - DarkTheme.Scale(24), rcText.bottom := h
            static DT_SINGLELINE := 0x20, DT_VCENTER := 0x4, DT_NOPREFIX := 0x800
            DllCall("DrawTextW", "Ptr", hdc, "Ptr", textBuf, "Int", -1, "Ptr", rcText, "UInt", DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX, "Void")

            if hOldFont
                DllCall("SelectObject", "Ptr", hdc, "Ptr", hOldFont, "Void")
        }

        ; Cleanup (bgBrush/ctrlBrush/arrowPen are cached — restore, don't delete)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", hOldPen, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", hOldBrush, "Void")
        DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps.Ptr, "Void")
    }
}

/**
 * Custom-drawn Slider with GDI+ anti-aliased thumb. Features circular knob
 * with blue accent border, double-buffered rendering to prevent artifacts.
 */
class _DarkSlider extends Gui.Slider {
    /** @type {Map} Window procedure callbacks */
    static Callbacks := Map()
    /** @type {Map} Original window procedures */
    static OldProcs := Map()
    /** @type {Map} Per-slider state data */
    static SliderData := Map()
    /** @type {Integer} GDI+ startup token (initialized once) */
    static GdipToken := 0

    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
        ; Initialize GDI+ once for anti-aliased thumb drawing
        si := DM_GpInput()
        si.GdiplusVersion := 1
        token := 0
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si.Ptr, "Ptr", 0)
        this.GdipToken := token
    }

    /**
     * Applies custom owner-draw dark mode to slider.
     * @param {Gui.Slider} slider - Slider control instance
     */
    static ApplyDarkMode(slider) {
        ; Set empty theme to disable themed drawing
        DllCall("uxtheme\SetWindowTheme", "Ptr", slider.Hwnd, "WStr", "", "WStr", "")

        ; Store slider data
        this.SliderData[slider.Hwnd] := Map("state", "normal")

        ; Subclass for custom drawing
        this.SubclassSlider(slider.Hwnd)

        DllCall("InvalidateRect", "Ptr", slider.Hwnd, "Ptr", 0, "Int", true, "Void")
    }

    static SubclassSlider(hwnd) {
        Subclass.Install(hwnd, ObjBindMethod(this, "SliderProc", hwnd), this.Callbacks, this.OldProcs)
    }

    /**
     * Removes subclass and frees resources for a Slider.
     * @param {Ptr} hwnd - Slider window handle
     */
    static Remove(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
        this.SliderData.Delete(hwnd)
    }

    /**
     * Releases our GDI+ token reference. Intentionally does NOT call
     * GdiplusShutdown: AHK shares gdiplus.dll for its own image handling and
     * keeps GDI+ initialized for the process lifetime. Calling GdiplusShutdown
     * here faults during process teardown (abnormal exit code) and — because
     * this also runs from {@link DarkTheme.Release} when the last DarkGui is
     * destroyed — would tear GDI+ out from under AHK mid-run. The OS reclaims
     * GDI+ on exit, so dropping the token is all that's needed.
     */
    static Shutdown() {
        this.GdipToken := 0
    }

    static SliderProc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F
        static WM_ERASEBKGND := 0x0014
        static WM_LBUTTONDOWN := 0x0201
        static WM_MOUSEMOVE := 0x0200
        static WM_LBUTTONUP := 0x0202
        static TBM_GETCHANNELRECT := 0x41A
        static TBM_GETTHUMBRECT := 0x0419
        static TBM_GETPOS := 0x0400
        static TBM_GETRANGEMIN := 0x0401
        static TBM_GETRANGEMAX := 0x0402

        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)

        ; Force full invalidation on mouse events that move the thumb
        if msg = WM_LBUTTONDOWN || msg = WM_MOUSEMOVE || msg = WM_LBUTTONUP {
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            ; Invalidate entire control to repaint cleanly
            DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", true, "Void")
            return result
        }

        if msg = WM_ERASEBKGND {
            ; Fill background with the cached Background brush (do not delete it)
            rc := DM_RECT()
            DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
            DllCall("FillRect", "Ptr", wParam, "Ptr", rc, "Ptr", DarkTheme.GetBrush("Background"), "Void")
            return 1
        }

        if msg = WM_PAINT {
            ps := DM_PAINTSTRUCT()
            hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps.Ptr, "Ptr")

            ; Get client rect
            rcClient := DM_RECT()
            DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rcClient)
            clientW := rcClient.right
            clientH := rcClient.bottom

            ; Use double buffering to prevent artifacts
            hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
            hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", clientW, "Int", clientH, "Ptr")
            hOldBitmap := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")

            ; Fill background (draw to memory DC) with cached brushes — do not delete them
            DllCall("FillRect", "Ptr", hdcMem, "Ptr", rcClient, "Ptr", DarkTheme.GetBrush("Background"), "Void")

            ; Get channel rect (use actual Windows position)
            rcChannel := DM_RECT()
            SendMessage(TBM_GETCHANNELRECT, 0, rcChannel.Ptr, hwnd)

            ; Draw track/channel using actual rect from Windows
            DllCall("FillRect", "Ptr", hdcMem, "Ptr", rcChannel, "Ptr", DarkTheme.GetBrush("Controls"), "Void")

            ; Get thumb rect
            rcThumb := DM_RECT()
            SendMessage(TBM_GETTHUMBRECT, 0, rcThumb.Ptr, hwnd)
            thumbLeft := rcThumb.left
            thumbTop := rcThumb.top
            thumbRight := rcThumb.right
            thumbBottom := rcThumb.bottom

            ; Calculate perfect circle (use smaller dimension as diameter + extra size)
            thumbW := thumbRight - thumbLeft
            thumbH := thumbBottom - thumbTop
            diameter := Min(thumbW, thumbH) + DarkTheme.Scale(6)  ; Make knob larger

            ; Center the circle and move up 2px
            centerX := thumbLeft + (thumbW // 2)
            centerY := thumbTop + (thumbH // 2) - DarkTheme.Scale(2)  ; Move up
            circleLeft := centerX - (diameter // 2)
            circleTop := centerY - (diameter // 2)
            circleRight := circleLeft + diameter
            circleBottom := circleTop + diameter

            ; Draw thumb as white circle with blue border using GDI+ for anti-aliasing
            fillColor := 0xFFFFFFFF  ; White fill (ARGB: fully opaque white)
            borderColor := 0xFF0078D7  ; Blue border (ARGB: fully opaque accent blue)
            borderWidth := DarkTheme.Scale(4) * 1.0

            ; Create Graphics from DC (GDI+ already initialized in __New)
            pGraphics := 0
            DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdcMem, "Ptr*", &pGraphics)

            ; Enable anti-aliasing (SmoothingModeAntiAlias = 4)
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 4)

            ; Create solid brush for fill
            pBrush := 0
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", fillColor, "Ptr*", &pBrush)

            ; Create pen for border
            pPen := 0
            DllCall("gdiplus\GdipCreatePen1", "UInt", borderColor, "Float", borderWidth, "Int", 2, "Ptr*", &pPen)

            ; Draw filled ellipse then border (adjust for pen width)
            halfPen := borderWidth / 2
            DllCall("gdiplus\GdipFillEllipse", "Ptr", pGraphics, "Ptr", pBrush,
                "Float", circleLeft + halfPen, "Float", circleTop + halfPen,
                "Float", diameter - borderWidth, "Float", diameter - borderWidth)
            DllCall("gdiplus\GdipDrawEllipse", "Ptr", pGraphics, "Ptr", pPen,
                "Float", circleLeft + halfPen, "Float", circleTop + halfPen,
                "Float", diameter - borderWidth, "Float", diameter - borderWidth)

            ; Cleanup GDI+ objects (but not the token)
            DllCall("gdiplus\GdipDeletePen", "Ptr", pPen)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", pBrush)
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)

            ; Blit from memory DC to screen DC
            DllCall("BitBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", clientW, "Int", clientH, "Ptr", hdcMem, "Int", 0, "Int", 0, "UInt", 0x00CC0020, "Void")  ; SRCCOPY

            ; Clean up memory DC
            DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOldBitmap, "Void")
            DllCall("DeleteObject", "Ptr", hBitmap, "Void")
            DllCall("DeleteDC", "Ptr", hdcMem, "Void")

            DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps.Ptr, "Void")
            return 0
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }
}

/**
 * Dark-themed Progress bar with {@link DarkTheme} accent color fill.
 * Strips the default Windows theme and applies custom background/bar colors.
 */
class _DarkProgress extends Gui.Progress {
    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    /**
     * Applies dark theme colors to the progress bar.
     *
     * @param {Gui.Progress} prog - Progress bar control instance.
     */
    static ApplyDarkMode(prog) {
        static PBM_SETBKCOLOR := 0x2001
        DllCall("uxtheme\SetWindowTheme", "Ptr", prog.Hwnd, "Str", "", "Ptr", 0)
        SendMessage(PBM_SETBKCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]), prog)
        prog.Opt("c" Format("{:X}", DarkTheme.Colors["Accent"]))
    }
}

/**
 * Dark-themed ListBox with `DarkMode_Explorer` theme for modern scrollbar
 * appearance. Removes borders and applies {@link DarkTheme} font color.
 */
class _DarkListBox extends Gui.ListBox {
    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    /**
     * Applies dark theme to the ListBox.
     *
     * @param {Gui.ListBox} lb - ListBox control instance.
     */
    static ApplyDarkMode(lb) {
        DllCall("uxtheme\SetWindowTheme", "Ptr", lb.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        lb.SetFont("c" Format("{:X}", DarkTheme.Colors["Font"]))
        DarkTheme.RemoveBorder(lb.Hwnd)
    }
}

/**
 * Applies native Windows dark mode to CheckBox controls.
 * Uses AllowDarkModeForWindow (uxtheme ordinal 133) + SetWindowTheme("Explorer")
 * to get the native dark checkbox indicators rendered by Windows itself.
 */
class _DarkCheckBox {
    static ApplyDarkMode(chk) {
        DarkTheme.AllowDarkMode(chk.Hwnd)
        DllCall("uxtheme\SetWindowTheme", "Ptr", chk.Hwnd, "Str", "Explorer", "Ptr", 0)
        chk.SetFont("c" Format("{:X}", DarkTheme.Colors["Font"]))
    }
}

/**
 * Dark-themed MonthCal (SysMonthCal32) date picker.
 *
 * The visual-styled MonthCal ignores `MCM_SETCOLOR` and always renders with the
 * light system theme. Stripping the theme (`SetWindowTheme(hwnd, "", "")`) forces
 * classic rendering, which DOES honor `MCM_SETCOLOR` — so the background, day
 * text, title bar, and trailing (adjacent-month) days all go dark. Classic
 * rendering draws light 3D prev/next nav buttons, so a `WM_PAINT` subclass
 * overpaints those two buttons dark with a flat chevron.
 */
class _DarkMonthCal {
    static Callbacks := Map()
    static OldProcs  := Map()

    static ApplyDarkMode(mc) {
        static MCM_SETCOLOR := 0x100A
        static MCSC_BACKGROUND := 0, MCSC_TEXT := 1, MCSC_TITLEBK := 2
        static MCSC_TITLETEXT := 3, MCSC_MONTHBK := 4, MCSC_TRAILINGTEXT := 5
        DllCall("uxtheme\SetWindowTheme", "Ptr", mc.Hwnd, "Str", "", "Str", "")
        SendMessage(MCM_SETCOLOR, MCSC_BACKGROUND,   DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]), mc)
        SendMessage(MCM_SETCOLOR, MCSC_MONTHBK,      DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]), mc)
        SendMessage(MCM_SETCOLOR, MCSC_TEXT,         DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]), mc)
        SendMessage(MCM_SETCOLOR, MCSC_TITLEBK,      DarkTheme.RGBtoBGR(DarkTheme.Colors["Header"]), mc)
        SendMessage(MCM_SETCOLOR, MCSC_TITLETEXT,    DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]), mc)
        SendMessage(MCM_SETCOLOR, MCSC_TRAILINGTEXT, DarkTheme.RGBtoBGR(DarkTheme.Colors["FontDim"]), mc)
        Subclass.Install(mc.Hwnd, ObjBindMethod(this, "Proc", mc.Hwnd), this.Callbacks, this.OldProcs)
        DllCall("InvalidateRect", "Ptr", mc.Hwnd, "Ptr", 0, "Int", 1, "Void")
    }

    static Remove(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
    }

    static Proc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F
        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
        if msg = WM_PAINT {
            ret := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            this._PaintNavButtons(targetHwnd)
            return ret
        }
        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    /** Overpaints the two classic 3D nav buttons with the title background and a flat chevron. */
    static _PaintNavButtons(hwnd) {
        rects := this._NavButtonRects(hwnd)
        if !rects
            return
        hdc := DllCall("GetDC", "Ptr", hwnd, "Ptr")
        if !hdc
            return
        for i, b in rects {
            ; Pad 1px so the classic 3D edge is fully covered; the title bar behind is also Header.
            rc := DM_RECT()
            rc.left := b[1] - 1, rc.top := b[2] - 1, rc.right := b[3] + 1, rc.bottom := b[4] + 1
            DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", DarkTheme.GetSolidBrush(DarkTheme.Colors["Header"]), "Void")
            this._Chevron(hdc, (b[1] + b[3]) // 2, (b[2] + b[4]) // 2, DarkTheme.Scale(4), i = 1)
        }
        DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", hdc, "Void")
    }

    /** Returns [prevRect, nextRect] (client coords) by hit-testing each nav button
     *  directly, or 0 if either hit didn't land on a button. */
    static _NavButtonRects(hwnd) {
        rcClient := DM_RECT()
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rcClient)
        cw := rcClient.right
        prev := this._HitRect(hwnd, DarkTheme.Scale(20), DarkTheme.Scale(12), cw)
        next := this._HitRect(hwnd, cw - DarkTheme.Scale(20), DarkTheme.Scale(12), cw)
        return (prev && next) ? [prev, next] : 0
    }

    /** Hit-tests (x,y) and returns the hit area's rect [L,T,R,B] when it's a small
     *  (button-sized) area, else 0. comctl6+ fills MCHITTESTINFO.rc with the area rect. */
    static _HitRect(hwnd, x, y, cw) {
        static MCM_HITTEST := 0x100E
        ht := DM_MCHITTESTINFO()
        ht.cbSize := ht.Size
        ht.pt.x := x, ht.pt.y := y
        DllCall("SendMessage", "Ptr", hwnd, "UInt", MCM_HITTEST, "Ptr", 0, "Ptr", ht.Ptr)
        w := ht.rc.right - ht.rc.left
        if w <= 0 || w >= cw // 2
            return 0
        return [ht.rc.left, ht.rc.top, ht.rc.right, ht.rc.bottom]
    }

    /** Filled flat chevron — left-pointing when prev, right-pointing otherwise. */
    static _Chevron(hdc, cx, cy, r, prev) {
        tri := DM_TRIANGLE()
        if prev {
            tri.p[1].x := cx + r, tri.p[1].y := cy - r
            tri.p[2].x := cx + r, tri.p[2].y := cy + r
            tri.p[3].x := cx - r, tri.p[3].y := cy
        } else {
            tri.p[1].x := cx - r, tri.p[1].y := cy - r
            tri.p[2].x := cx - r, tri.p[2].y := cy + r
            tri.p[3].x := cx + r, tri.p[3].y := cy
        }
        col := DarkTheme.Colors["Font"]
        oB := DllCall("SelectObject", "Ptr", hdc, "Ptr", DarkTheme.GetSolidBrush(col), "Ptr")
        oP := DllCall("SelectObject", "Ptr", hdc, "Ptr", DarkTheme.GetPen(col), "Ptr")
        DllCall("Polygon", "Ptr", hdc, "Ptr", tri.Ptr, "Int", 3, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oB, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oP, "Void")
    }
}

/**
 * Owner-draw dark status bar (msctls_statusbar32).
 *
 * The control has no text-color message, so each part is flagged SBT_OWNERDRAW and
 * painted in {@link DarkWindowProc}'s WM_DRAWITEM handler ({@link _DarkStatusBar.DrawPart}).
 * `SB_SETBKCOLOR` darkens the bar fill and the sizing-grip area. An instance `Text`
 * property is added so `sb.Text := "..."` works alongside the native `SetText`.
 */
class _DarkStatusBar {
    /** @type {Map} sbHwnd -> Map(partIndex -> text string) */
    static Texts := Map()
    static Callbacks := Map()
    static OldProcs := Map()

    static ApplyDarkMode(sb) {
        static SB_SETBKCOLOR := 0x2001
        hwnd := sb.Hwnd
        ; Strip visual styles (both strings empty) so the classic flat renderer honors
        ; SBT_NOBORDERS and our owner-draw fill. The status bar class has no dark theme,
        ; so "DarkMode_Explorer" would leave a light SP_PANE border framing each part.
        DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "", "Str", "")
        SendMessage(SB_SETBKCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]), sb)
        ; SBARS_SIZEGRIP can't be cleared after creation — COMCTL32 ignores WM_STYLECHANGED
        ; (MS KB Q177341), and AHK creates the bar internally. So subclass WM_PAINT and
        ; overpaint the light grip corner dark instead (see GripProc / _PaintGripOver).
        ; The window still resizes from its frame and the (now invisible) grip still drags.
        Subclass.Install(hwnd, ObjBindMethod(this, "GripProc", hwnd), this.Callbacks, this.OldProcs)
        this.Texts[hwnd] := Map()

        ; No SB_SETTEXTCOLOR exists — override SetText to store the string and flag the
        ; part SBT_OWNERDRAW, then paint it dark from the parent's WM_DRAWITEM.
        sb.DefineProp("SetText", { Call: ObjBindMethod(this, "_SetText") })
        ; Convenience: sb.Text := "..." routes to the owner-draw SetText (part 1).
        sb.DefineProp("Text", {
            Get: (s) => _DarkStatusBar.Texts.Get(s.Hwnd, Map()).Get(0, ""),
            Set: (s, value) => (_DarkStatusBar._SetText(s, value, 1), value)
        })
        ; Establish owner-draw mode on part 0 (Gui.StatusBar has no GetText, so the
        ; caller's creation text is re-applied by DarkGui.Add right after this).
        sb.SetText("")
    }

    static _SetText(sb, text, part := 1, *) {
        static SB_SETTEXTW := 0x40B
        static SBT_OWNERDRAW := 0x1000
        static SBT_NOBORDERS := 0x0100  ; drop the sunken 3D part border
        idx := part - 1
        if this.Texts.Has(sb.Hwnd)
            this.Texts[sb.Hwnd][idx] := text
        ; wParam = part index | type flags; lParam = app data (reuse the index)
        SendMessage(SB_SETTEXTW, idx | SBT_OWNERDRAW | SBT_NOBORDERS, idx, sb)
    }

    /** Paints one owner-drawn part. Called from DarkWindowProc on WM_DRAWITEM. */
    static DrawPart(dis) {
        static DT_SINGLELINE := 0x20, DT_VCENTER := 0x4, DT_LEFT := 0x0, DT_END_ELLIPSIS := 0x8000
        texts := this.Texts.Get(dis.hwndItem, "")
        if !texts
            return
        text := texts.Has(dis.itemID) ? texts[dis.itemID] : ""
        rc := DM_RECT()
        rc.left := dis.rcItem.left, rc.top := dis.rcItem.top
        rc.right := dis.rcItem.right, rc.bottom := dis.rcItem.bottom
        DllCall("FillRect", "Ptr", dis.hDC, "Ptr", rc, "Ptr", DarkTheme.GetBrush("Controls"), "Void")
        if text = ""
            return
        rc.left += DarkTheme.Scale(4)
        DllCall("SetBkMode", "Ptr", dis.hDC, "Int", 1, "Void")
        DllCall("SetTextColor", "Ptr", dis.hDC, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]), "Void")
        DllCall("DrawTextW", "Ptr", dis.hDC, "Str", text, "Int", -1, "Ptr", rc,
            "UInt", DT_SINGLELINE | DT_VCENTER | DT_LEFT | DT_END_ELLIPSIS, "Void")
    }

    /**
     * Status-bar subclass proc. After the control paints itself (parts owner-draw via
     * the parent's WM_DRAWITEM), overpaint the light sizing-grip corner with the dark
     * Header brush so the grip disappears into the bar.
     */
    static GripProc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F
        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
        if msg = WM_PAINT {
            ret := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            this._PaintGripOver(hwnd)
            return ret
        }
        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    /** Fills the bottom-right grip square (side = bar height) with the Controls brush. */
    static _PaintGripOver(hwnd) {
        rc := DM_RECT()
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
        grip := DM_RECT()
        grip.left := rc.right - rc.bottom, grip.top := 0
        grip.right := rc.right, grip.bottom := rc.bottom
        hdc := DllCall("GetDC", "Ptr", hwnd, "Ptr")
        DllCall("FillRect", "Ptr", hdc, "Ptr", grip, "Ptr", DarkTheme.GetBrush("Controls"), "Void")
        DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", hdc, "Void")
    }

    static Remove(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
        this.Texts.Delete(hwnd)
    }
}

/**
 * Owner-draw dark up-down (spinner) control.
 *
 * Keeps the native increment / auto-repeat logic — only WM_PAINT and WM_ERASEBKGND
 * are taken over, so clicks still reach the original proc and drive the buddy Edit.
 * Pairs with a dark numeric Edit for a NumericUpDown look.
 */
class _DarkUpDown {
    static Callbacks := Map()
    static OldProcs := Map()

    static ApplyDarkMode(ud) {
        DllCall("uxtheme\SetWindowTheme", "Ptr", ud.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        Subclass.Install(ud.Hwnd, ObjBindMethod(this, "Proc", ud.Hwnd), this.Callbacks, this.OldProcs)
        DllCall("InvalidateRect", "Ptr", ud.Hwnd, "Ptr", 0, "Int", 1, "Void")
    }

    static Remove(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
    }

    static Proc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F
        static WM_ERASEBKGND := 0x0014
        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
        if msg = WM_ERASEBKGND
            return 1
        if msg = WM_PAINT {
            this.Paint(hwnd)
            return 0
        }
        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    static Paint(hwnd) {
        ps := DM_PAINTSTRUCT()
        hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps.Ptr, "Ptr")
        rc := DM_RECT()
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
        w := rc.right, h := rc.bottom

        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", DarkTheme.GetBrush("Controls"), "Void")
        midY := h // 2

        ; Divider between the two arrow halves
        oldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", DarkTheme.GetPen(DarkTheme.Colors["ButtonBorder"]), "Ptr")
        DllCall("MoveToEx", "Ptr", hdc, "Int", 0, "Int", midY, "Ptr", 0, "Void")
        DllCall("LineTo", "Ptr", hdc, "Int", w, "Int", midY, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldPen, "Void")

        aw := Max(3, w // 4)
        cx := w // 2
        this._Arrow(hdc, cx, midY // 2, aw, true)
        this._Arrow(hdc, cx, midY + midY // 2, aw, false)

        DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps.Ptr, "Void")
    }

    /** Filled triangle pointing up (up=true) or down, centered at (cx, cy). */
    static _Arrow(hdc, cx, cy, r, up) {
        tri := DM_TRIANGLE()
        if up {
            tri.p[1].x := cx - r, tri.p[1].y := cy + r // 2
            tri.p[2].x := cx + r, tri.p[2].y := cy + r // 2
            tri.p[3].x := cx,     tri.p[3].y := cy - r // 2
        } else {
            tri.p[1].x := cx - r, tri.p[1].y := cy - r // 2
            tri.p[2].x := cx + r, tri.p[2].y := cy - r // 2
            tri.p[3].x := cx,     tri.p[3].y := cy + r // 2
        }
        oB := DllCall("SelectObject", "Ptr", hdc, "Ptr", DarkTheme.GetSolidBrush(DarkTheme.Colors["Font"]), "Ptr")
        oP := DllCall("SelectObject", "Ptr", hdc, "Ptr", DarkTheme.GetPen(DarkTheme.Colors["Font"]), "Ptr")
        DllCall("Polygon", "Ptr", hdc, "Ptr", tri.Ptr, "Int", 3, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oB, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oP, "Void")
    }
}

/**
 * Dark SysLink (hyperlink) control.
 *
 * The surrounding text and background are handled by {@link DarkWindowProc}'s
 * WM_CTLCOLORSTATIC; the clickable link segments are recolored to
 * `DarkTheme.Colors["Link"]` via NM_CUSTOMDRAW (dispatched from DarkWindowProc's
 * WM_NOTIFY), since SysLink exposes no link-color message.
 */
class _DarkLink {
    static ApplyDarkMode(link) {
        DarkTheme.AllowDarkMode(link.Hwnd)
        link.SetFont("c" Format("{:X}", DarkTheme.Colors["Font"]))
        DarkWindowProc.LinkControls[link.Hwnd] := true
    }

    /** NM_CUSTOMDRAW handler; returns the CDRF_* result for the parent window proc. */
    static OnCustomDraw(lParam) {
        static CDDS_PREPAINT := 0x1, CDDS_ITEMPREPAINT := 0x10001
        static CDRF_DODEFAULT := 0x0, CDRF_NOTIFYITEMDRAW := 0x20
        nmcd := DM_NMCUSTOMDRAW.At(lParam)
        switch nmcd.dwDrawStage {
            case CDDS_PREPAINT:
                return CDRF_NOTIFYITEMDRAW
            case CDDS_ITEMPREPAINT:
                DllCall("SetTextColor", "Ptr", nmcd.hdc, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Link"]), "Void")
                return CDRF_DODEFAULT
        }
        return CDRF_DODEFAULT
    }

    static Remove(hwnd) {
        DarkWindowProc.LinkControls.Delete(hwnd)
    }
}

/**
 * Custom-draw GroupBox: fills background, draws dim border, renders title in Font color.
 * WM_CTLCOLORBTN does not control GroupBox text color — a WM_PAINT subclass is required.
 */
class _DarkGroupBox {
    static Callbacks  := Map()
    static OldProcs   := Map()
    static GroupTexts := Map()

    /**
     * Applies dark theme to a GroupBox control.
     * Subclasses the control for custom WM_PAINT rendering.
     *
     * @param {Gui.GroupBox} ctrl - GroupBox control instance.
     */
    static ApplyDarkMode(ctrl) {
        hwnd := ctrl.Hwnd
        buf := Buffer(256, 0)
        DllCall("GetWindowText", "Ptr", hwnd, "Ptr", buf, "Int", 256)
        this.GroupTexts[hwnd] := StrGet(buf)
        Subclass.Install(hwnd, ObjBindMethod(this, "Proc", hwnd), this.Callbacks, this.OldProcs)
        DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1, "Void")
    }

    /**
     * Removes subclass and frees resources for a GroupBox.
     *
     * @param {Ptr} hwnd - GroupBox window handle.
     */
    static Remove(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
        this.GroupTexts.Delete(hwnd)
    }

    static Proc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT      := 0x000F
        static WM_ERASEBKGND := 0x0014
        if msg = WM_ERASEBKGND {
            rc := DM_RECT()
            DllCall("GetClientRect", "Ptr", targetHwnd, "Ptr", rc)
            DllCall("FillRect", "Ptr", wParam, "Ptr", rc, "Ptr", DarkTheme.GetBrush("Background"), "Void")
            return 1
        }
        if msg = WM_PAINT {
            this.Paint(targetHwnd)
            return 0
        }
        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    static Paint(hwnd) {
        ps  := DM_PAINTSTRUCT()
        hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps.Ptr, "Ptr")

        rc := DM_RECT()
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
        w := rc.right
        h := rc.bottom

        ; Fill entire background
        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", DarkTheme.GetBrush("Background"), "Void")

        ; Select control font so text metrics are accurate
        hFont   := DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
        oldFont := hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0

        ; Measure font height
        tm := DM_TEXTMETRICW()
        DllCall("GetTextMetricsW", "Ptr", hdc, "Ptr", tm.Ptr)
        tmH := tm.tmHeight

        ; Measure title text width
        groupText := this.GroupTexts.Get(hwnd, "")
        sz := DM_SIZE()
        DllCall("GetTextExtentPoint32W", "Ptr", hdc, "Str", groupText, "Int", StrLen(groupText), "Ptr", sz.Ptr)
        textW := sz.cx

        textX   := DarkTheme.Scale(9)
        borderY := tmH // 2

        ; Draw hollow border rectangle (NULL_BRUSH = stock 5, no fill).
        ; Border pen is cached by DarkTheme — do not delete it.
        hNull := DllCall("GetStockObject", "Int", 5, "Ptr")
        oPen  := DllCall("SelectObject", "Ptr", hdc, "Ptr", DarkTheme.GetPen(DarkTheme.Colors["Border"]), "Ptr")
        oBr   := DllCall("SelectObject", "Ptr", hdc, "Ptr", hNull, "Ptr")
        DllCall("RoundRect", "Ptr", hdc, "Int", 0, "Int", borderY, "Int", w, "Int", h, "Int", 8, "Int", 8, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oPen, "Void")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oBr, "Void")

        ; Punch a background-colored gap in the top border line where the title sits
        if StrLen(groupText) > 0 {
            gapRc := DM_RECT()
            gapRc.left := textX - 2,        gapRc.top := borderY - 1
            gapRc.right := textX + textW + 2, gapRc.bottom := borderY + 1
            DllCall("FillRect", "Ptr", hdc, "Ptr", gapRc, "Ptr", DarkTheme.GetBrush("Background"), "Void")
        }

        ; Draw title text in Font color (TRANSPARENT background mode)
        DllCall("SetBkMode",    "Ptr", hdc, "Int", 1, "Void")
        DllCall("SetTextColor", "Ptr", hdc, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]), "Void")
        textRc := DM_RECT()
        textRc.left := textX, textRc.top := 0, textRc.right := textX + textW + 4, textRc.bottom := tmH
        static DT_SINGLELINE := 0x20
        DllCall("DrawTextW", "Ptr", hdc, "Str", groupText, "Int", -1, "Ptr", textRc, "UInt", DT_SINGLELINE, "Void")

        if oldFont
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont, "Void")
        DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps.Ptr, "Void")
    }
}

/**
 * Dark mode for Tab3 (SysTabControl32) controls.
 *
 * Win32 layered approach (from research):
 *   1. SetWindowTheme("DarkMode_Explorer") — registers control as dark-aware;
 *      on Win11 22H2+ the OS native rendering already draws white tab text.
 *   2. AllowDarkModeForWindow (uxtheme ordinal 133) — required dark-mode flag.
 *   3. WM_THEMECHANGED suppressed — prevents OS from resetting our theme.
 *   4. WM_ERASEBKGND — suppressed (return 1, no fill); background is drawn
 *      atomically inside the WM_PAINT double-buffer, eliminating the flash
 *      that would appear if erase and paint were separate screen writes.
 *   5. WM_PAINT — double-buffered: BeginPaint DC + CreateCompatibleDC +
 *      PaintTabs (fills memory DC) + BitBlt + EndPaint. Production pattern
 *      confirmed by darkmodelib / Notepad++ dark-mode tab implementation.
 */
class _DarkTab {
    static Callbacks := Map()
    static OldProcs  := Map()

    /**
     * Applies dark theme to a Tab3 control.
     * Registers with OS dark-mode engine, removes sunken border, and
     * subclasses for double-buffered custom WM_PAINT via {@link _DarkTab.PaintTabs}.
     *
     * @param {Gui.Tab} ctrl - Tab3 control instance.
     */
    static ApplyDarkMode(ctrl) {
        hwnd := ctrl.Hwnd
        ; Register this control as dark-aware with the OS theme engine
        DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        DarkTheme.AllowDarkMode(hwnd, true)
        ; Remove sunken edge — we draw our own border (none, by design)
        DarkTheme.RemoveBorder(hwnd)
        Subclass.Install(hwnd, ObjBindMethod(this, "Proc", hwnd), this.Callbacks, this.OldProcs)
        DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1, "Void")
    }

    /**
     * Removes dark mode subclass and restores default rendering.
     *
     * @param {Ptr} hwnd - Tab3 window handle.
     */
    static Remove(hwnd) {
        DarkTheme.AllowDarkMode(hwnd, false)
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
    }

    static Proc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT        := 0x000F
        static WM_ERASEBKGND   := 0x0014
        static WM_NCPAINT      := 0x0085
        static WM_THEMECHANGED := 0x031A
        ; Suppress default background erase — WM_PAINT handles it inside the
        ; double-buffer, so no separate screen write occurs before the blit.
        if msg = WM_ERASEBKGND
            return 1
        ; Suppress non-client paint — prevents the tab control from drawing its
        ; angled content-area frame border over the custom-painted background.
        if msg = WM_NCPAINT
            return 0
        ; Suppress theme changes — prevents OS from resetting SetWindowTheme
        if msg = WM_THEMECHANGED
            return 0
        if msg = WM_PAINT {
            ; Production pattern (darkmodelib / Notepad++):
            ;   1. BeginPaint validates the update region (stops WM_PAINT loop).
            ;   2. Paint into a full-size memory DC (no clip restriction).
            ;   3. BitBlt from memory DC to BeginPaint DC atomically.
            ;   4. EndPaint releases BeginPaint state.
            ; This eliminates the flash that comes from WM_ERASEBKGND + WM_PAINT
            ; writing to the screen twice, and GetDCEx/GetDC reliability issues.
            static SRCCOPY := 0xCC0020
            ps := DM_PAINTSTRUCT()
            hdc := DllCall("BeginPaint", "Ptr", targetHwnd, "Ptr", ps.Ptr, "Ptr")
            rcBuf := DM_RECT()
            DllCall("GetClientRect", "Ptr", targetHwnd, "Ptr", rcBuf)
            w := rcBuf.right
            h := rcBuf.bottom
            hdcMem  := DllCall("CreateCompatibleDC",     "Ptr", hdc, "Ptr")
            hBmp    := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", w, "Int", h, "Ptr")
            hBmpOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBmp, "Ptr")
            this.PaintTabs(targetHwnd, hdcMem)
            DllCall("BitBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", w, "Int", h,
                "Ptr", hdcMem, "Int", 0, "Int", 0, "UInt", SRCCOPY, "Void")
            DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBmpOld, "Void")
            DllCall("DeleteObject", "Ptr", hBmp, "Void")
            DllCall("DeleteDC",     "Ptr", hdcMem, "Void")
            DllCall("EndPaint", "Ptr", targetHwnd, "Ptr", ps.Ptr, "Void")
            return 0
        }
        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    /**
     * Full owner-draw for Tab3 WM_PAINT.
     *
     * Layout:
     *   • Entire client area → Background fill (no outer border)
     *   • Unselected tabs    → transparent background, FontDim text
     *   • Selected tab       → Controls fill, rounded corners (6px), Font text
     *   • Separator line     → 1px Border color between tab strip and content
     *
     * Pattern mirrors _DarkGroupBox.Paint / _DarkButton.PaintButton.
     */
    static PaintTabs(hwnd, hdc) {
        static TCM_GETITEMCOUNT := 0x1304  ; TCM_FIRST + 4
        static TCM_GETITEMRECT  := 0x130A  ; TCM_FIRST + 10
        static TCM_GETCURSEL    := 0x130B  ; TCM_FIRST + 11
        static TCM_GETITEM      := 0x133C  ; TCM_FIRST + 60 (W)
        static TCM_ADJUSTRECT   := 0x1328  ; TCM_FIRST + 40
        static TCIF_TEXT        := 0x1
        static DT_CENTER        := 0x1
        static DT_VCENTER       := 0x4
        static DT_SINGLELINE    := 0x20
        static NULL_PEN         := 8      ; GetStockObject(8)

        ; Geometry
        clientRc := DM_RECT()
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", clientRc)
        w := clientRc.right
        h := clientRc.bottom

        ; Fill entire background — no tab-control border
        DllCall("FillRect", "Ptr", hdc, "Ptr", clientRc, "Ptr", DarkTheme.GetBrush("Background"), "Void")

        selIdx := DllCall("SendMessage", "Ptr", hwnd, "UInt", TCM_GETCURSEL,    "Ptr", 0, "Ptr", 0, "Int")
        tabCount := DllCall("SendMessage", "Ptr", hwnd, "UInt", TCM_GETITEMCOUNT, "Ptr", 0, "Ptr", 0, "Int")
        if tabCount <= 0
            return

        ; Content area top = tab strip bottom (for separator line)
        adjRc := DM_RECT()
        adjRc.left := 0, adjRc.top := 0, adjRc.right := w, adjRc.bottom := h
        DllCall("SendMessage", "Ptr", hwnd, "UInt", TCM_ADJUSTRECT, "Ptr", 0, "Ptr", adjRc)
        tabStripBottom := adjRc.top

        ; Select control font
        hFont   := DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
        oldFont := hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0
        DllCall("SetBkMode", "Ptr", hdc, "Int", 1, "Void")  ; TRANSPARENT

        hNullPen := DllCall("GetStockObject", "Int", NULL_PEN, "Ptr")

        loop tabCount {
            i := A_Index - 1
            itemRc := DM_RECT()
            DllCall("SendMessage", "Ptr", hwnd, "UInt", TCM_GETITEMRECT, "Ptr", i, "Ptr", itemRc)
            left   := itemRc.left
            top    := itemRc.top
            right  := itemRc.right
            bottom := itemRc.bottom

            if (i = selIdx) {
                ; Rounded pill: top corners round, bottom corners square.
                ; Draw full RoundRect, then overdraw bottom 6px with FillRect
                ; using same brush — squares off the bottom corner curves.
                tabBrush := DarkTheme.GetSolidBrush(DarkTheme.Colors["ControlsHover"])  ; cached — do not delete
                oPen   := DllCall("SelectObject", "Ptr", hdc, "Ptr", hNullPen, "Ptr")
                oBrush := DllCall("SelectObject", "Ptr", hdc, "Ptr", tabBrush, "Ptr")
                DllCall("RoundRect", "Ptr", hdc,
                    "Int", left+2, "Int", top, "Int", right-1, "Int", bottom+1,
                    "Int", 6, "Int", 6, "Void")
                squareRc := DM_RECT()
                squareRc.left := left+2,  squareRc.top := bottom-6
                squareRc.right := right-1, squareRc.bottom := bottom+1
                DllCall("FillRect", "Ptr", hdc, "Ptr", squareRc, "Ptr", tabBrush, "Void")
                DllCall("SelectObject", "Ptr", hdc, "Ptr", oPen, "Void")
                DllCall("SelectObject", "Ptr", hdc, "Ptr", oBrush, "Void")
                DllCall("SetTextColor", "Ptr", hdc, "UInt",
                    DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]), "Void")
            } else {
                DllCall("SetTextColor", "Ptr", hdc, "UInt",
                    DarkTheme.RGBtoBGR(DarkTheme.Colors["FontDim"]), "Void")
            }

            ; Fetch label text via TCM_GETITEMW and draw centered
            textBuf := Buffer(512, 0)
            tcItem  := DM_TCITEMW()
            tcItem.mask       := TCIF_TEXT
            tcItem.pszText    := textBuf.Ptr
            tcItem.cchTextMax := 255
            DllCall("SendMessage", "Ptr", hwnd, "UInt", TCM_GETITEM, "Ptr", i, "Ptr", tcItem.Ptr)
            tabText := StrGet(textBuf)
            DllCall("DrawTextW", "Ptr", hdc, "Str", tabText, "Int", -1, "Ptr", itemRc,
                "UInt", DT_CENTER | DT_VCENTER | DT_SINGLELINE, "Void")
        }

        ; 1px separator line between tab strip and content area
        if tabStripBottom > 0 {
            sepRc := DM_RECT()
            sepRc.left := 0, sepRc.top := tabStripBottom - 1, sepRc.right := w, sepRc.bottom := tabStripBottom
            DllCall("FillRect", "Ptr", hdc, "Ptr", sepRc, "Ptr", DarkTheme.GetBrush("Border"), "Void")
        }

        if oldFont
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont, "Void")
    }
}

/**
 * Window procedure subclass for handling WM_CTLCOLOR* messages.
 * Provides dark background brushes for Edit, ListBox, Button, and Static controls.
 */
class DarkWindowProc {
    /** @type {Map} Window procedure callbacks */
    static Callbacks := Map()
    /** @type {Map} Original window procedures */
    static OldProcs := Map()
    /** @type {Map} Radio button text control handles for WM_CTLCOLORSTATIC */
    static RadioTextControls := Map()
    /** @type {Map} Menu bar control handles that need Header background instead of Background */
    static MenuBarControls := Map()
    /** @type {Map} ComboBox dropdown list handles for WM_CTLCOLORLISTBOX */
    static ComboDropdowns := Map()
    /** @type {Map} SysLink control handles whose link segments get recolored via NM_CUSTOMDRAW */
    static LinkControls := Map()

    /**
     * Installs dark window procedure on a window.
     * @param {Ptr} hwnd - Window handle
     */
    static Install(hwnd) {
        Subclass.Install(hwnd, ObjBindMethod(this, "Proc", hwnd), this.Callbacks, this.OldProcs)
    }

    /**
     * Removes dark window procedure and restores original.
     * @param {Ptr} hwnd - Window handle
     */
    static Uninstall(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
    }

    /**
     * Handles `WM_CTLCOLOR*` messages to apply dark background brushes
     * and text colors for Edit, ListBox, Button, and Static controls.
     *
     * @param {Ptr} targetHwnd - Subclassed window handle.
     * @param {Ptr} hwnd - Message target window handle.
     * @param {Integer} msg - Windows message ID.
     * @param {Ptr} wParam - HDC of the control.
     * @param {Ptr} lParam - HWND of the control.
     * @returns {Ptr} GDI brush handle for the control background.
     */
    static Proc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_CTLCOLOREDIT := 0x0133
        static WM_CTLCOLORLISTBOX := 0x0134
        static WM_CTLCOLORBTN := 0x0135
        static WM_CTLCOLORSTATIC := 0x0138
        static WM_DRAWITEM := 0x002B
        static WM_NOTIFY := 0x004E
        static NM_CUSTOMDRAW := -12
        static TRANSPARENT := 1

        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)

        switch msg {
            case WM_CTLCOLOREDIT:
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]))
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                return DarkTheme.GetBrush("Controls")

            case WM_CTLCOLORLISTBOX:
                ; lParam = listbox hwnd - check if it's a ComboBox dropdown or standalone ListBox
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                if this.ComboDropdowns.Has(lParam) {
                    ; ComboBox dropdown - use Background color to match GUI
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]))
                    return DarkTheme.GetBrush("Background")
                } else {
                    ; Standalone ListBox - use Controls color
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]))
                    return DarkTheme.GetBrush("Controls")
                }

            case WM_CTLCOLORBTN:
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]))
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                return DarkTheme.GetBrush("Background")

            case WM_CTLCOLORSTATIC:
                ; lParam = control handle in WM_CTLCOLOR messages
                ; Menu bar controls use same background as GUI
                if this.MenuBarControls.Has(lParam) {
                    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                    DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                    return DllCall("gdi32\GetStockObject", "Int", 5, "Ptr")  ; HOLLOW_BRUSH - preserve BackgroundTrans
                }
                ; Radio text controls
                if this.RadioTextControls.Has(lParam) {
                    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]))
                    DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                    return DarkTheme.GetBrush("Background")
                }
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]))
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                return DarkTheme.GetBrush("Background")

            case WM_DRAWITEM:
                ; Owner-drawn dark status bar parts (no SB text-color message exists).
                dis := DM_DRAWITEMSTRUCT.At(lParam)
                if _DarkStatusBar.Texts.Has(dis.hwndItem) {
                    _DarkStatusBar.DrawPart(dis)
                    return 1
                }

            case WM_NOTIFY:
                ; Recolor SysLink link segments via NM_CUSTOMDRAW; clicks fall through
                ; to AHK so OnEvent("Click") still fires.
                if this.LinkControls.Count {
                    nm := DM_NMHDR.At(lParam)
                    if this.LinkControls.Has(nm.hwndFrom) && nm.code = NM_CUSTOMDRAW
                        return _DarkLink.OnCustomDraw(lParam)
                }
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }
}

/**
 * Builder returned by {@link DarkMenuBar#AddMenu}. Wraps an `HMENU` handle and
 * exposes chainable `Item` / `Sep` methods so menu construction reads top-to-bottom
 * at the call site without `Map(...)` boilerplate per entry.
 */
class _DarkMenuBuilder {
    __New(hPopup) {
        this.hPopup := hPopup
    }

    /**
     * Appends a normal menu item.
     * @param {String} text - Display text.
     * @param {Integer} id - Command id dispatched via `WM_COMMAND`.
     * @param {String} [shortcut=""] - Right-aligned hint (e.g. "Ctrl+N"); not a real accelerator.
     * @returns {_DarkMenuBuilder} this (chainable)
     */
    Item(text, id, shortcut := "") {
        itemText := shortcut ? text "`t" shortcut : text
        DllCall("AppendMenuW", "Ptr", this.hPopup, "UInt", 0x0000, "Ptr", id, "Str", itemText, "Void")
        return this
    }

    /**
     * Appends a separator line.
     * @returns {_DarkMenuBuilder} this (chainable)
     */
    Sep() {
        DllCall("AppendMenuW", "Ptr", this.hPopup, "UInt", 0x0800, "Ptr", 0, "Ptr", 0, "Void")
        return this
    }
}

/**
 * Custom dark menu bar using Win32 popup menus with dark theme.
 * Uses `SetMenuInfo` for dark popup backgrounds + uxtheme dark mode APIs.
 * `WM_COMMAND` (`0x0111`) handled externally by consumer class.
 *
 * Construct with a {@link DarkGui} parent and a `Map` of layout/color options.
 * Call {@link DarkMenuBar#AddMenu} to define menus with popup items,
 * and {@link DarkMenuBar#AddToolbarButton} for icon toolbar buttons.
 */
class DarkMenuBar {
    /**
     * Creates a dark menu bar with optional toolbar.
     *
     * @param {DarkGui} parentGui - The parent GUI instance.
     * @param {Map} options - Configuration options.
     * @param {Integer} [options.menuBarHeight = 24] - Menu bar height in pixels.
     * @param {Integer} [options.toolbarHeight = 32] - Toolbar row height.
     * @param {Integer} [options.menuItemPadding = 12] - Horizontal padding per menu label.
     * @param {Integer} [options.menuFontSize = 9] - Font size for menu labels.
     * @param {Integer} [options.toolbarIconSize = 20] - Toolbar button icon size.
     * @param {Boolean} [options.showToolbar = true] - Whether to show the toolbar row.
     * @param {Integer} [options.popupOffsetX = 0] - Popup menu X offset from label.
     * @param {Integer} [options.popupOffsetY = 0] - Popup menu Y offset from label.
     */
    __New(parentGui, options) {
        this.gui := parentGui
        this.menuItems := []
        this.toolbarBtns := []
        this.hoveredMenu := ""

        this.layout := Map(
            "menuBarHeight", options.Get("menuBarHeight", 24),
            "toolbarHeight", options.Get("toolbarHeight", 32),
            "menuItemPadding", options.Get("menuItemPadding", 12),
            "menuFontSize", options.Get("menuFontSize", 9),
            "toolbarIconSize", options.Get("toolbarIconSize", 20),
            "toolbarButtonSpacing", options.Get("toolbarButtonSpacing", 4),
            "toolbarSeparatorWidth", options.Get("toolbarSeparatorWidth", 1),
            "showToolbar", options.Get("showToolbar", true),
            "popupOffsetX", options.Get("popupOffsetX", 0),
            "popupOffsetY", options.Get("popupOffsetY", 0)
        )

        this.colors := Map(
            "menuBarBg", options.Get("menuBarBg", DarkTheme.Colors["Header"]),
            "menuBarText", options.Get("menuBarText", DarkTheme.Colors["Font"]),
            "menuBarHover", options.Get("menuBarHover", DarkTheme.Colors["ControlsActive"]),
            "menuBarActive", options.Get("menuBarActive", DarkTheme.Colors["Accent"]),
            "popupBg", options.Get("popupBg", DarkTheme.Colors["Header"]),
            "toolbarBg", options.Get("toolbarBg", DarkTheme.Colors["Header"]),
            "toolbarBorder", options.Get("toolbarBorder", DarkTheme.Colors["Border"])
        )

        this.totalHeight := this.layout["showToolbar"] ?
            (this.layout["menuBarHeight"] + this.layout["toolbarHeight"] + 1) :
            this.layout["menuBarHeight"]

        DarkMenu.Apply()
        DarkTheme.AllowDarkMode(this.gui.Hwnd, true)
        this.CreateMenuBar()
        if this.layout["showToolbar"] {
            this.CreateToolbar()
        }

        this._onMouseMove := this.OnMouseMove.Bind(this)
        OnMessage(0x200, this._onMouseMove)
        this._lastHoveredBtn := ""

        ; Menu/toolbar bars are added at a fixed width; stretch them to the
        ; client width whenever the parent (e.g. +Resize) window changes size.
        this._onParentSize := this.OnParentSize.Bind(this)
        this.gui.OnEvent("Size", this._onParentSize)
    }

    /** Stretches the menu bar, toolbar, and toolbar border to the client width. */
    OnParentSize(guiObj, minMax, width, height) {
        if minMax = -1  ; minimized
            return
        if this.HasProp("menuBar")
            this.menuBar.Move(, , width)
        if this.HasProp("toolbar") {
            this.toolbar.Move(, , width)
            this.toolbarBorder.Move(, , width)
        }
    }

    CreateMenuBar() {
        this.menuBar := this.gui.AddText("x0 y0 w800 h" . this.layout["menuBarHeight"] . " Background" . Format("{:06X}", this.colors["menuBarBg"]))

        this.popupMenus := Map()
        this.menuStructure := Map()

        x := 8
        this.menuBarStartX := x
    }

    /**
     * Adds a named menu to the menu bar with a popup of items.
     *
     * Each item in `menuItems` is a `Map` with keys:
     * - `"text"` `{String}` - Menu item label.
     * - `"id"` `{Integer}` - Command ID for `WM_COMMAND`.
     * - `"shortcut"` `{String}` - Optional keyboard shortcut hint.
     * - `"separator"` `{Boolean}` - If `true`, draws a separator line.
     *
     * @param {String} menuName - Label displayed in the menu bar.
     * @param {Array} menuItems - Array of `Map` objects defining popup items.
     * @returns {Ptr} Handle to the created popup menu (`HMENU`).
     */
    /**
     * Creates an empty popup menu and the clickable label that opens it.
     * Returns a {@link _DarkMenuBuilder} — call `.Item()` / `.Sep()` on it to
     * populate. The dark theme is applied to the popup before items are added,
     * so they inherit the dark background automatically.
     *
     * @param {String} menuName - Top-level label shown on the menu bar.
     * @returns {_DarkMenuBuilder}
     */
    AddMenu(menuName) {
        hPopup := DllCall("CreatePopupMenu", "Ptr")
        this.ApplyDarkThemeToPopup(hPopup)

        ; Center label vertically using SS_CENTERIMAGE (0x200). Create it at a
        ; placeholder width, set the font, then size to the *measured* text so
        ; the label fits any font size / non-ASCII name — the old StrLen*7 guess
        ; clipped wide glyphs and over-padded narrow ones.
        menuLabel := this.gui.AddText("x" . this.menuBarStartX . " y0 w10 h" . this.layout["menuBarHeight"] . " +0x200 Center BackgroundTrans c" . Format("{:06X}", this.colors["menuBarText"]), menuName)
        menuLabel.SetFont("s" . this.layout["menuFontSize"], "Segoe UI")
        itemWidth := this._MeasureLabelWidth(menuLabel, menuName) + this.layout["menuItemPadding"]
        menuLabel.Move(, , itemWidth)

        hitArea := this.gui.AddText("x" . this.menuBarStartX . " y0 w" . itemWidth . " h" . this.layout["menuBarHeight"] . " BackgroundTrans")
        hitArea.OnEvent("Click", this.ShowPopupMenu.Bind(this, hPopup, this.menuBarStartX))

        menuItemData := Map(
            "name", menuName,
            "label", menuLabel,
            "hitArea", hitArea,
            "popup", hPopup,
            "x", this.menuBarStartX,
            "width", itemWidth
        )

        this.menuItems.Push(menuItemData)
        this.popupMenus[menuName] := hPopup

        ; Register with DarkWindowProc so WM_CTLCOLORSTATIC returns HOLLOW_BRUSH
        ; (preserves BackgroundTrans and white text on menu bar)
        DarkWindowProc.MenuBarControls[menuLabel.Hwnd] := true
        DarkWindowProc.MenuBarControls[hitArea.Hwnd] := true

        this.menuBarStartX += itemWidth + 4

        return _DarkMenuBuilder(hPopup)
    }

    CreateToolbar() {
        toolbarY := this.layout["menuBarHeight"]

        this.toolbar := this.gui.AddText("x0 y" . toolbarY . " w800 h" . this.layout["toolbarHeight"] . " Background" . Format("{:06X}", this.colors["toolbarBg"]))
        this.toolbarBorder := this.gui.AddText("x0 y" . (toolbarY + this.layout["toolbarHeight"]) . " w800 h1 Background" . Format("{:06X}", this.colors["toolbarBorder"]))

        this.toolbarStartX := 6
        this.toolbarY := toolbarY + Integer((this.layout["toolbarHeight"] - this.layout["toolbarIconSize"]) / 2)
    }

    /**
     * Adds an icon button to the toolbar row below the menu bar.
     *
     * @param {String} icon - Single character or emoji used as button label.
     * @param {String} tooltip - Tooltip text shown on hover.
     * @param {Func} callback - Called with no arguments when clicked.
     */
    AddToolbarButton(icon, tooltip, callback) {
        btnX := this.toolbarStartX
        btnY := this.toolbarY
        btnSize := this.layout["toolbarIconSize"]

        btnBg := this.gui.AddText("x" . btnX . " y" . btnY . " w" . btnSize . " h" . btnSize . " BackgroundTrans")
        btnIcon := this.gui.AddText("x" . btnX . " y" . btnY . " w" . btnSize . " h" . btnSize . " Center BackgroundTrans c" . Format("{:06X}", this.colors["menuBarText"]), icon)
        btnIcon.SetFont("s10")

        btnHit := this.gui.AddText("x" . btnX . " y" . btnY . " w" . btnSize . " h" . btnSize . " BackgroundTrans")
        btnHit.OnEvent("Click", (*) => (callback(), 0))
        btnHit.ToolTip := tooltip

        btnData := Map(
            "bg", btnBg,
            "icon", btnIcon,
            "hit", btnHit,
            "x", btnX,
            "y", btnY,
            "tooltip", tooltip
        )

        this.toolbarBtns.Push(btnData)

        this.toolbarStartX += btnSize + this.layout["toolbarButtonSpacing"]
    }

    AddToolbarSeparator() {
        btnX := this.toolbarStartX
        btnY := this.toolbarY
        btnSize := this.layout["toolbarIconSize"]

        this.gui.AddText("x" . btnX . " y" . (btnY + 1) . " w" . this.layout["toolbarSeparatorWidth"] . " h" . (btnSize - 2) . " Background" . Format("{:06X}", this.colors["toolbarBorder"]))
        this.toolbarStartX += 6
    }

    ShowPopupMenu(hPopup, x, *) {
        popupX := 0
        popupY := 0

        for item in this.menuItems {
            if item["popup"] = hPopup {
                ctrlRect := DM_RECT()
                DllCall("GetWindowRect", "Ptr", item["hitArea"].Hwnd, "Ptr", ctrlRect)

                popupX := ctrlRect.left   ; Left
                popupY := ctrlRect.bottom  ; Bottom

                item["label"].Opt("Background" . Format("{:06X}", this.colors["menuBarActive"]))
                labelRef := item["label"]
                SetTimer(() => (labelRef.Opt("BackgroundTrans"), 0), -200)
                break
            }
        }

        popupX += this.layout["popupOffsetX"]
        popupY += this.layout["popupOffsetY"]

        DllCall("TrackPopupMenu", "Ptr", hPopup, "UInt", 0x0000, "Int", popupX, "Int", popupY, "Int", 0, "Ptr", this.gui.Hwnd, "Ptr", 0)
    }

    OnMouseMove(wParam, lParam, msg, hwnd) {
        if hwnd != this.gui.Hwnd
            return

        x := lParam & 0xFFFF
        y := (lParam >> 16) & 0xFFFF

        if this.layout["showToolbar"] && y > this.layout["menuBarHeight"] && y <= (this.layout["menuBarHeight"] + this.layout["toolbarHeight"]) {
            this.HandleToolbarHover(x, y)
            return
        }

        if y > this.layout["menuBarHeight"] {
            if this.hoveredMenu != "" {
                this.ClearHover()
            }
            return
        }

        hoveredItem := ""
        for item in this.menuItems {
            if x >= item["x"] && x <= item["x"] + item["width"] {
                hoveredItem := item["name"]
                break
            }
        }

        if hoveredItem != this.hoveredMenu {
            this.ClearHover()
            if hoveredItem != "" {
                for item in this.menuItems {
                    if item["name"] = hoveredItem {
                        item["label"].Opt("Background" . Format("{:06X}", this.colors["menuBarHover"]))
                        this.hoveredMenu := hoveredItem
                        break
                    }
                }
            }
        }
    }

    HandleToolbarHover(x, y) {
        hoveredBtn := ""
        for btn in this.toolbarBtns {
            btnSize := this.layout["toolbarIconSize"]
            if x >= btn["x"] && x <= btn["x"] + btnSize && y >= btn["y"] && y <= btn["y"] + btnSize {
                hoveredBtn := btn
                break
            }
        }

        if hoveredBtn != this._lastHoveredBtn {
            for btn in this.toolbarBtns {
                btn["bg"].Opt("BackgroundTrans")
            }

            if hoveredBtn != "" {
                hoveredBtn["bg"].Opt("Background" . Format("{:06X}", this.colors["menuBarHover"]))
            }

            this._lastHoveredBtn := hoveredBtn
        }
    }

    ClearHover() {
        for item in this.menuItems {
            item["label"].Opt("BackgroundTrans")
        }
        this.hoveredMenu := ""
    }

    /**
     * Measures a label's pixel width using the control's own selected font.
     * @param {Gui.Text} ctrl - The label control (font already applied).
     * @param {String} text - Text to measure.
     * @returns {Integer} Width in pixels.
     */
    _MeasureLabelWidth(ctrl, text) {
        hdc := DllCall("GetDC", "Ptr", ctrl.Hwnd, "Ptr")
        hFont := SendMessage(0x31, 0, 0, ctrl)  ; WM_GETFONT
        old := hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0
        sz := DM_SIZE()
        DllCall("GetTextExtentPoint32W", "Ptr", hdc, "Str", text, "Int", StrLen(text), "Ptr", sz.Ptr)
        if old
            DllCall("SelectObject", "Ptr", hdc, "Ptr", old, "Void")
        DllCall("ReleaseDC", "Ptr", ctrl.Hwnd, "Ptr", hdc, "Void")
        return sz.cx
    }

    ApplyDarkThemeToPopup(hPopup) {
        darkBrush := DllCall("CreateSolidBrush", "UInt", DarkTheme.RGBtoBGR(this.colors["popupBg"]), "Ptr")

        mi := DM_MENUINFO()
        mi.cbSize  := mi.Size
        mi.fMask   := 0x10  ; MIM_BACKGROUND
        mi.hbrBack := darkBrush
        DllCall("SetMenuInfo", "Ptr", hPopup, "Ptr", mi.Ptr, "Void")
    }

    /**
     * Unregisters the mouse move handler and destroys popup menu handles.
     * Call before disposing the parent {@link DarkGui}.
     */
    Destroy() {
        OnMessage(0x200, this._onMouseMove, 0)
        try this.gui.OnEvent("Size", this._onParentSize, 0)
        for item in this.menuItems {
            if item.Has("popup")
                DllCall("DestroyMenu", "Ptr", item["popup"], "Void")
        }
    }

    /**
     * Returns the Y offset where content should begin below the menu/toolbar.
     *
     * @returns {Integer} Pixel offset accounting for menu bar and optional toolbar.
     */
    GetContentY() {
        return this.totalHeight
    }
}

/**
 * Dark-themed Gui class. All controls added via Add() are automatically styled.
 * Use "+Accent" option for accent-colored buttons.
 * Backward compatible: `_Dark` is an alias for `DarkGui`.
 */
class DarkGui extends Gui {
    /** @type {Map} Tracks dark-styled controls: hwnd -> controlType */
    _darkHwnds := Map()
    /** @type {Integer} HWND cached at construction for safe teardown */
    _hwnd := 0

    /**
     * Creates a new dark-themed GUI window.
     * @param {String} options - Gui options
     * @param {String} title - Window title
     */
    __New(options := "", title := A_ScriptName) {
        super.__New(options, title)
        ; Cache the HWND: Gui.Prototype.Hwnd throws "Gui has no window" once the
        ; window is destroyed, which can occur before __Delete runs at app exit.
        ; Teardown bookkeeping uses this cached value instead of the getter.
        this._hwnd := this.Hwnd
        DarkTheme.AddRef()
        DarkTheme.Windows[this._hwnd] := true
        this.BackColor := DarkTheme.Colors["Background"]
        this.SetFont("s9", "Segoe UI")
        DarkTitleBar.Apply(this.Hwnd)
        DarkMenu.Apply()
        DarkWindowProc.Install(this.Hwnd)

        ; Win11: set title bar and border colors to match theme
        if VerCompare(A_OSVersion, "10.0.22000") >= 0 {
            bgBGR := DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"])
            borderBGR := DarkTheme.RGBtoBGR(DarkTheme.Colors["Border"])
            try {
                DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Hwnd, "UInt", 35, "UInt*", bgBGR, "Int", 4)
                DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Hwnd, "UInt", 36, "UInt*", 0xFFFFFF, "Int", 4)
                DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Hwnd, "UInt", 34, "UInt*", borderBGR, "Int", 4)
            }
        }
    }

    /**
     * Cleans up all dark mode resources for this GUI.
     * Removes subclasses from all tracked controls, clears stale entries from
     * {@link DarkWindowProc} tracking maps, and calls {@link DarkTheme.Release}.
     */
    __Delete() {
        ; Remove subclasses from all tracked dark controls
        for hwnd, ctrlType in this._darkHwnds {
            switch ctrlType {
                case "ListView": _DarkListView.Remove(hwnd)
                case "Button":   _DarkButton.Remove(hwnd)
                case "ComboBox": _DarkComboBox.Remove(hwnd)
                case "Slider":   _DarkSlider.Remove(hwnd)
                case "GroupBox":  _DarkGroupBox.Remove(hwnd)
                case "Tab3":      _DarkTab.Remove(hwnd)
                case "UpDown":    _DarkUpDown.Remove(hwnd)
                case "StatusBar": _DarkStatusBar.Remove(hwnd)
                case "Link":      _DarkLink.Remove(hwnd)
                case "MonthCal":  _DarkMonthCal.Remove(hwnd)
            }
        }
        this._darkHwnds.Clear()

        ; Clean stale entries from DarkWindowProc tracking maps
        for map in [DarkWindowProc.RadioTextControls, DarkWindowProc.MenuBarControls, DarkWindowProc.ComboDropdowns] {
            stale := []
            for hwnd, _ in map
                if !DllCall("IsWindow", "Ptr", hwnd)
                    stale.Push(hwnd)
            for hwnd in stale
                map.Delete(hwnd)
        }

        DarkTheme.Windows.Delete(this._hwnd)
        try DarkWindowProc.Uninstall(this._hwnd)
        DarkTheme.Release()
    }

    /**
     * Adds a control with automatic dark mode styling.
     *
     * Delegates to the appropriate `_Dark*` class based on `controlType`.
     * Use `"+Accent"` in options for accent-colored buttons via {@link _DarkButton}.
     *
     * @param {String} controlType - Control type (`"Button"`, `"Edit"`, `"ListView"`, etc.).
     * @param {String} [options = ""] - Control options. Include `"+Accent"` for blue buttons.
     * @param {*} [content] - Control content (text, items array, etc.).
     * @returns {Gui.Control} The created and dark-styled control.
     */
    Add(controlType, options := "", content?) {
        isAccent := InStr(options, "+Accent")
        if isAccent
            options := StrReplace(options, "+Accent", "")

        switch controlType, false {
            case "Text":
                ; Add font color if not specified
                if !RegExMatch(options, "i)\bc[0-9A-Fa-f]+\b")
                    options .= " c" Format("{:X}", DarkTheme.Colors["Font"])
                return super.Add(controlType, options, content?)

            case "ListView":
                ; Add cWhite for text color if not specified
                if !RegExMatch(options, "i)\bc[0-9A-Fa-f]+\b|\bcWhite\b|\bcBlack\b")
                    options .= " cWhite"
                ctrl := super.Add(controlType, options, content?)
                ctrl.SetDarkMode()
                this._darkHwnds[ctrl.Hwnd] := "ListView"
                return ctrl

            case "Radio":
                return this._AddRadio(options, content?)

            case "Button":
                ctrl := super.Add(controlType, options, content?)
                ctrl.SetDarkMode(isAccent ? "accent" : "default")
                this._darkHwnds[ctrl.Hwnd] := "Button"
                return ctrl

            case "CheckBox":
                ctrl := super.Add(controlType, options, content?)
                _DarkCheckBox.ApplyDarkMode(ctrl)
                return ctrl

            case "DropDownList", "DDL":
                ctrl := super.Add(controlType, options, content?)
                DarkTheme.AllowDarkMode(ctrl.Hwnd)
                DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_CFD", "Ptr", 0)
                ctrl.SetFont("c" Format("{:X}", DarkTheme.Colors["Font"]))
                DarkTheme.RemoveBorder(ctrl.Hwnd)
                ; Dark the dropdown list portion
                static CB_GETCOMBOBOXINFO := 0x0164
                cbi := DM_COMBOBOXINFO()
                cbi.cbSize := cbi.Size
                if DllCall("SendMessage", "Ptr", ctrl.Hwnd, "UInt", CB_GETCOMBOBOXINFO, "Ptr", 0, "Ptr", cbi.Ptr) {
                    listHwnd := cbi.hwndList
                    if listHwnd {
                        DllCall("uxtheme\SetWindowTheme", "Ptr", listHwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                        DarkWindowProc.ComboDropdowns[listHwnd] := true
                    }
                }
                return ctrl

            case "ComboBox":
                ctrl := super.Add(controlType, options, content?)
                ctrl.SetDarkMode()  ; _DarkComboBox.ApplyDarkMode already calls RemoveBorder
                this._darkHwnds[ctrl.Hwnd] := controlType
                return ctrl

            case "Edit", "Slider", "Progress", "ListBox", "TreeView":
                ctrl := super.Add(controlType, options, content?)
                ctrl.SetDarkMode()
                if controlType = "Slider"
                    this._darkHwnds[ctrl.Hwnd] := controlType
                return ctrl

            case "GroupBox":
                ctrl := super.Add(controlType, options, content?)
                _DarkGroupBox.ApplyDarkMode(ctrl)
                this._darkHwnds[ctrl.Hwnd] := "GroupBox"
                return ctrl

            case "Tab3":
                ctrl := super.Add(controlType, options, content?)
                _DarkTab.ApplyDarkMode(ctrl)
                this._darkHwnds[ctrl.Hwnd] := "Tab3"
                return ctrl

            case "UpDown":
                ctrl := super.Add(controlType, options, content?)
                _DarkUpDown.ApplyDarkMode(ctrl)
                this._darkHwnds[ctrl.Hwnd] := "UpDown"
                return ctrl

            case "StatusBar":
                ctrl := super.Add(controlType, options, content?)
                _DarkStatusBar.ApplyDarkMode(ctrl)
                ; Re-apply creation text through the owner-draw path so it renders dark
                if IsSet(content) && content != ""
                    ctrl.SetText(content)
                this._darkHwnds[ctrl.Hwnd] := "StatusBar"
                return ctrl

            case "Link":
                ; cWhite default so the surrounding (non-link) text is readable
                if !RegExMatch(options, "i)\bc[0-9A-Fa-f]+\b|\bcWhite\b|\bcBlack\b")
                    options .= " cWhite"
                ctrl := super.Add(controlType, options, content?)
                _DarkLink.ApplyDarkMode(ctrl)
                this._darkHwnds[ctrl.Hwnd] := "Link"
                return ctrl

            case "MonthCal":
                ctrl := super.Add(controlType, options, content?)
                _DarkMonthCal.ApplyDarkMode(ctrl)
                this._darkHwnds[ctrl.Hwnd] := "MonthCal"
                return ctrl

            default:
                return super.Add(controlType, options, content?)
        }
    }

    /** Manually selects a radio and unchecks all others in its group */
    static _SelectRadio(selected, group) {
        for r in group
            r.Value := (r = selected)
    }

    /** Internal: Adds Radio with separate text control for proper dark styling */
    _AddRadio(options, text?) {
        static SM_CXMENUCHECK := 71
        static radioW := DllCall("GetSystemMetrics", "Int", SM_CXMENUCHECK)

        ; Track radio groups - new group starts with +Group or first radio
        isNewGroup := RegExMatch(options, "i)\bGroup\b") || !this.HasOwnProp("_radioGroup")
        if isNewGroup
            this._radioGroup := []
        group := this._radioGroup

        radio := super.Add("Radio", options " +0x4000000", "")
        group.Push(radio)

        ; SS_NOTIFY (0x100) enables click events on the text label
        if !InStr(options, "right")
            txt := super.Add("Text", "xp+" (radioW + 8) " yp+2 HP-4 +0x4000300 cFFFFFF", text?)
        else
            txt := super.Add("Text", "xp+8 yp+2 HP-4 +0x4000300 cFFFFFF", text?)

        DarkWindowProc.RadioTextControls[txt.Hwnd] := true

        static SWP_NOSIZE := 0x1, SWP_NOMOVE := 0x2, SWP_NOACTIVATE := 0x10
        DllCall("SetWindowPos", "Ptr", txt.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0,
            "UInt", SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE | 0x40, "Void")

        DllCall("uxtheme\SetWindowTheme", "Ptr", radio.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)

        radio.TextCtrl := txt
        radio.DefineProp("Text", {
            Get: (this) => this.TextCtrl.Text,
            Set: (this, value) => this.TextCtrl.Text := value
        })

        ; Manual radio group management - text controls break native auto-grouping
        radio.OnEvent("Click", (*) => (DarkGui._SelectRadio(radio, group), 0))
        txt.OnEvent("Click", (*) => (DarkGui._SelectRadio(radio, group), 0))

        return radio
    }
}

/**
 * Backward-compatibility alias — `_Dark(...)` constructs a {@link DarkGui}.
 * Declared as an (empty) subclass rather than a `_Dark := DarkGui` global
 * assignment so that merely including this file has no auto-execute side effect.
 */
class _Dark extends DarkGui {
}

; Run standalone showcase when executed directly, skip when #Included as library.
; Held in a script-lifetime variable so the instance isn't reliant on OnMessage
; bindings to stay alive.
if A_LineFile = A_ScriptFullPath
    _darkShowcase := DarkModeShowcase()

class DarkModeShowcase {
    controls := Map()
    _altTheme := false

    static CMD_NEW := 101, CMD_OPEN := 102, CMD_SAVE := 103, CMD_EXIT := 104
    static CMD_UNDO := 201, CMD_CUT := 202, CMD_COPY := 203, CMD_PASTE := 204
    static CMD_THEME := 301, CMD_ABOUT := 302

    __New() {
        this.gui := DarkGui("+Resize", "Modular Dark Mode System")
        this.BuildMenuBar()
        this.BuildLayout()
        this.BindEvents()
        this.gui.Show("w620 h558")
    }

    BuildMenuBar() {
        this.menuBar := DarkMenuBar(this.gui, Map("showToolbar", false))
        this.menuOffset := this.menuBar.totalHeight

        fileMenu := this.menuBar.AddMenu("File")
        fileMenu.Item("New",     DarkModeShowcase.CMD_NEW,  "Ctrl+N")
        fileMenu.Item("Open...", DarkModeShowcase.CMD_OPEN, "Ctrl+O")
        fileMenu.Item("Save",    DarkModeShowcase.CMD_SAVE, "Ctrl+S")
        fileMenu.Sep()
        fileMenu.Item("Exit",    DarkModeShowcase.CMD_EXIT)

        editMenu := this.menuBar.AddMenu("Edit")
        editMenu.Item("Undo",  DarkModeShowcase.CMD_UNDO,  "Ctrl+Z")
        editMenu.Sep()
        editMenu.Item("Cut",   DarkModeShowcase.CMD_CUT,   "Ctrl+X")
        editMenu.Item("Copy",  DarkModeShowcase.CMD_COPY,  "Ctrl+C")
        editMenu.Item("Paste", DarkModeShowcase.CMD_PASTE, "Ctrl+V")

        viewMenu := this.menuBar.AddMenu("View")
        viewMenu.Item("Toggle Theme", DarkModeShowcase.CMD_THEME)
        viewMenu.Sep()
        viewMenu.Item("About...",     DarkModeShowcase.CMD_ABOUT)

        OnMessage(0x0111, this.OnMenuCommand.Bind(this))
    }

    OnMenuCommand(wParam, lParam, msg, hwnd) {
        if hwnd != this.gui.Hwnd
            return
        cmdId := wParam & 0xFFFF
        if cmdId < 100
            return
        switch cmdId {
            case DarkModeShowcase.CMD_EXIT:  ExitApp()
            case DarkModeShowcase.CMD_ABOUT: MsgBox("DarkModeModular.ahk Showcase`nAll controls dark-themed automatically.", "About")
            case DarkModeShowcase.CMD_THEME:
                ; Live re-theme: SetColor recreates the cached brush and repaints
                ; every registered DarkGui window via DarkTheme.Redraw.
                this._altTheme := !this._altTheme
                DarkTheme.SetColor("Accent", this._altTheme ? 0xA855F7 : 0x0078D7)
                if this.controls.Has("status")
                    this.controls["status"].Text := "Status: Accent → " (this._altTheme ? "Purple" : "Blue")
            default:
                if this.controls.Has("status")
                    this.controls["status"].Text := "Status: Menu command " cmdId " at " FormatTime(, "HH:mm:ss")
        }
    }

    BuildLayout() {
        y0 := this.menuOffset

        this.gui.Add("Text", "x20 y" (y0 + 15) " w200", "━ Text Input")
        this.controls["edit1"] := this.gui.Add("Edit", "x20 y" (y0 + 40) " w200 h25", "Single-line edit")
        this.controls["edit2"] := this.gui.Add("Edit", "x20 y" (y0 + 75) " w200 h68 +Multi", "Item A`nItem B`nItem C`nItem D`nItem E")

        this.gui.Add("Text", "x240 y" (y0 + 15) " w180", "━ Selection")
        this.controls["chk1"] := this.gui.Add("CheckBox", "x240 y" (y0 + 40) " w160 +Checked", "Feature enabled")
        this.controls["chk2"] := this.gui.Add("CheckBox", "x240 y" (y0 + 65) " w160", "Auto-save")
        this.controls["rad1"] := this.gui.Add("Radio", "x240 y" (y0 + 95) " w160 +Checked", "Option A")
        this.controls["rad2"] := this.gui.Add("Radio", "x240 y" (y0 + 120) " w160", "Option B")

        this.gui.Add("Text", "x420 y" (y0 + 15) " w180", "━ Actions")
        this.controls["btn1"] := this.gui.Add("Button", "x420 y" (y0 + 40) " w80 h28", "Apply")
        this.controls["btn2"] := this.gui.Add("Button", "+Accent x510 y" (y0 + 40) " w80 h28", "OK")
        this.controls["btn3"] := this.gui.Add("Button", "x420 y" (y0 + 78) " w170 h28", "Reset All")

        this.splitMenu := Menu()
        this.splitMenu.Add("First action", (*) => this.controls["status"].Text := "Status: Split menu -> First action")
        this.splitMenu.Add("Second action", (*) => this.controls["status"].Text := "Status: Split menu -> Second action")
        this.splitMenu.Add("Third action", (*) => this.controls["status"].Text := "Status: Split menu -> Third action")
        this.controls["btnToggle"] := _DarkButton.AddToggle(this.gui, "x420 y" (y0 + 116) " w80 h28", "Toggle", false)
        this.controls["btnFlat"]   := _DarkButton.AddFlat(this.gui,   "x510 y" (y0 + 116) " w80 h28", "Flat")
        this.controls["btnIcon"]   := _DarkButton.AddIcon(this.gui,   "x420 y" (y0 + 154) " w80 h28", "Browse", "shell32.dll,4")
        this.controls["btnSplit"]  := _DarkButton.AddSplit(this.gui,  "x510 y" (y0 + 154) " w80 h28", "Split", this.splitMenu)

        this.gui.Add("Text", "x20 y" (y0 + 200) " w200", "━ Dropdowns & Progress")
        this.controls["combo"] := this.gui.Add("ComboBox", "x20 y" (y0 + 225) " w95", ["Option 1", "Option 2", "Option 3"])
        this.controls["ddl"] := this.gui.Add("DropDownList", "x120 y" (y0 + 225) " w100", ["Alpha", "Beta", "Gamma"])
        this.controls["slider"] := this.gui.Add("Slider", "x20 y" (y0 + 265) " w200 Range0-100", 50)
        this.controls["sliderLabel"] := this.gui.Add("Text", "x20 y" (y0 + 295) " w200", "Value: 50")
        this.controls["progress"] := this.gui.Add("Progress", "x20 y" (y0 + 320) " w200 h20", 50)

        this.gui.Add("Text", "x240 y" (y0 + 200) " w350", "━ ListView (with checkboxes)")
        this.controls["lv"] := this.gui.Add("ListView", "x240 y" (y0 + 225) " w350 h115 +Checked", ["Name", "Type", "Size"])
        this.controls["lv"].Add("", "Document.pdf", "PDF", "1.2 MB")
        this.controls["lv"].Add("", "Script.ahk", "AHK", "5 KB")
        this.controls["lv"].Add("", "Image.png", "PNG", "234 KB")
        this.controls["lv"].Add("", "Archive.zip", "ZIP", "12 MB")
        this.controls["lv"].Add("", "Video.mp4", "MP4", "156 MB")
        this.controls["lv"].Add("", "Music.mp3", "MP3", "8.4 MB")
        this.controls["lv"].Add("", "Database.db", "DB", "45 MB")
        this.controls["lv"].ModifyCol(1, 150)
        this.controls["lv"].ModifyCol(2, 90)
        this.controls["lv"].ModifyCol(3, 85)

        this.gui.Add("Text", "x20 y" (y0 + 355) " w200", "━ ListBox")
        this.controls["listbox"] := this.gui.Add("ListBox", "x20 y" (y0 + 380) " w200 h90", ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"])

        this.gui.Add("Text", "x240 y" (y0 + 355) " w350", "━ TreeView")
        this.controls["tv"] := this.gui.Add("TreeView", "x240 y" (y0 + 380) " w350 h83")
        p1 := this.controls["tv"].Add("Documents")
        this.controls["tv"].Add("Report.pdf", p1)
        this.controls["tv"].Add("Notes.txt", p1)
        p2 := this.controls["tv"].Add("Images")
        this.controls["tv"].Add("Photo.jpg", p2)

        ; Spinner (numeric Edit + UpDown) and SysLink, then a real docked StatusBar.
        this.gui.Add("Text", "x20 y" (y0 + 482) " w40 +0x200", "Spin:")
        this.controls["spinEdit"] := this.gui.Add("Edit", "x60 y" (y0 + 478) " w52 h24 +Number", "10")
        this.controls["spin"] := this.gui.Add("UpDown", "Range0-100", 10)
        this.controls["link"] := this.gui.Add("Link", "x130 y" (y0 + 482) " w460",
            'Docs: <a href="https://www.autohotkey.com/docs/">AutoHotkey</a> · <a href="https://github.com/">GitHub</a>')

        this.controls["status"] := this.gui.Add("StatusBar", , "Status: Ready")
    }

    BindEvents() {
        this.controls["btn1"].OnEvent("Click", this.OnApply.Bind(this))
        this.controls["btn2"].OnEvent("Click", (*) => (this.gui.Hide(), 0))
        this.controls["btn3"].OnEvent("Click", this.OnReset.Bind(this))
        this.controls["slider"].OnEvent("Change", this.OnSliderChange.Bind(this))
        this.controls["btnToggle"].OnEvent("Click", (*) => this.controls["status"].Text := "Status: Toggle " (this.controls["btnToggle"].IsToggled ? "ON" : "OFF"))
        this.controls["btnFlat"].OnEvent("Click", (*) => this.controls["status"].Text := "Status: Flat clicked")
        this.controls["btnIcon"].OnEvent("Click", (*) => this.controls["status"].Text := "Status: Icon clicked")
        this.controls["btnSplit"].OnEvent("Click", (*) => this.controls["status"].Text := "Status: Split (face) clicked")
        this.controls["spin"].OnEvent("Change", (*) => this.controls["status"].Text := "Status: Spin = " this.controls["spinEdit"].Value)
        this.controls["link"].OnEvent("Click", this.OnLink.Bind(this))
        this.gui.OnEvent("Close", (*) => (ExitApp(), 0))
    }

    OnApply(*) {
        this.controls["status"].Text := "Status: Applied at " FormatTime(, "HH:mm:ss")
    }

    OnReset(*) {
        this.controls["edit1"].Value := "Single-line edit"
        this.controls["edit2"].Value := "Multi-line`nedit control"
        this.controls["chk1"].Value := 1
        this.controls["chk2"].Value := 0
        this.controls["rad1"].Value := 1
        this.controls["slider"].Value := 50
        this.controls["progress"].Value := 50
        this.controls["sliderLabel"].Text := "Value: 50"
        this.controls["status"].Text := "Status: Reset complete"
    }

    OnSliderChange(*) {
        sliderVal := this.controls["slider"].Value
        this.controls["progress"].Value := sliderVal
        this.controls["sliderLabel"].Text := "Value: " sliderVal
    }

    ; Link Click fires with (ctrl, info, href). Registering a callback suppresses
    ; AHK's automatic HREF launch, so open it ourselves.
    OnLink(ctrl, info, href := "") {
        if href
            Run(href)
        this.controls["status"].Text := "Status: Link → " href
    }
}
