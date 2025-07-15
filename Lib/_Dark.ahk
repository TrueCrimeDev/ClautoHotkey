#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

#DllLoad gdi32.dll
#DllLoad uxtheme.dll
#DllLoad dwmapi.dll

EnhancedDarkApp()

class EnhancedDarkApp {
    __New() {
        this.InitializeGui()
        this.SetupControls()
        this.gui.Show()
    }

    InitializeGui() {
        this.gui := Gui("+Resize +AlwaysOnTop", "Enhanced Dark Mode Demo")
        this.gui.SetFont("s10", "Segoe UI")
        dm := _Dark(this.gui)

        dm.AddDarkText("y15 x15 w300", "Basic Controls")
        this.darkCheckbox := dm.AddDarkCheckBox("y+10 x15 w250", "Enable feature")
        this.darkListView := dm.AddListView("y+10 x15 w300 h120", ["Item", "Value"])
        this.actionButton := dm.AddDarkButton("y+10 x15 w120", "Run Action")
        this.darkEdit := dm.AddDarkEdit("y+10 x15 w200 h24", "Sample text input")
        this.darkComboBox := dm.AddDarkComboBox("y+10 x15 w200", ["Option 1", "Option 2", "Option 3"])

        dm.AddDarkText("y+20 x15 w300", "Advanced Controls")
        this.darkGroupBox := dm.AddDarkGroupBox("y+10 x15 w300 h80 cWhite", "Group Settings")
        this.darkRadio1 := dm.AddDarkRadio("xp+15 yp+25 w250", "Option A")
        this.darkRadio2 := dm.AddDarkRadio("xp y+10 w250", "Option B")

        dm.AddDarkText("y+20 x15 w300", "Enhanced Controls")
        this.darkSlider := dm.AddDarkSlider("y+10 x15 w200 h30 Range0-100", 50)
        this.darkProgress := dm.AddDarkProgress("y+15 x15 w200 h20", 50)
        this.darkDateTime := dm.AddDarkDateTime("y+15 x15 w200")
        this.darkMonthCal := dm.AddDarkMonthCal("y+15 x15")
        this.darkTabs := dm.AddDarkTab3("y+15 x15 w300 h150", ["Tab 1", "Tab 2", "Tab 3"])

        this.gui.Tab := 1
        dm.AddDarkText("y+10 x25 w280", "Content for Tab 1")
        dm.AddDarkEdit("y+10 x25 w280 h80", "Tab 1 content area")

        this.gui.Tab := 2
        dm.AddDarkText("y+10 x25 w280", "Content for Tab 2")
        dm.AddDarkButton("y+10 x25 w100", "Tab 2 Button")

        this.gui.Tab := 3
        dm.AddDarkText("y+10 x25 w280", "Content for Tab 3")
        dm.AddDarkListBox("y+10 x25 w200 h80", ["List Item 1", "List Item 2", "List Item 3"])

        this.gui.Tab := ""

        dm.AddDarkText("y+20 x15 w300", "Theme Settings")
        this.themeSelecter := dm.AddDarkComboBox("y+10 x15 w200", ["Dark Blue", "Dark Gray", "Dark Green", "Dark Purple"])

        this.actionButton.OnEvent("Click", this.ButtonClicked.Bind(this))
        this.darkSlider.OnEvent("Change", this.SliderChanged.Bind(this))
    }

    ButtonClicked(*) {
        MsgBox("Button clicked!")
    }

    SliderChanged(*) {
        this.darkProgress.Value := this.darkSlider.Value
    }

    SetupControls() {
        this.darkListView.Add(, "Item 1", "Value 1")
        this.darkListView.Add(, "Item 2", "Value 2")
        this.darkListView.Add(, "Item 3", "Value 3")
    }
}

class _Dark {
    class RECT {
        left := 0
        top := 0
        right := 0
        bottom := 0
    }

    class NMHDR {
        hwndFrom := 0
        idFrom := 0
        code := 0
    }

    class NMCUSTOMDRAW {
        hdr := 0
        dwDrawStage := 0
        hdc := 0
        rc := 0
        dwItemSpec := 0
        uItemState := 0
        lItemlParam := 0
        __New() {
            this.hdr := _Dark.NMHDR()
            this.rc := _Dark.RECT()
        }
    }

    static StructFromPtr(StructClass, ptr) {
        obj := StructClass()
        if (StructClass.Prototype.__Class = "NMHDR") {
            obj.hwndFrom := NumGet(ptr, 0, "UPtr")
            obj.idFrom := NumGet(ptr, A_PtrSize, "UPtr")
            obj.code := NumGet(ptr, A_PtrSize * 2, "Int")
        }
        else if (StructClass.Prototype.__Class = "NMCUSTOMDRAW") {
            obj.hdr := _Dark.NMHDR()
            obj.hdr.hwndFrom := NumGet(ptr, 0, "UPtr")
            obj.hdr.idFrom := NumGet(ptr, A_PtrSize, "UPtr")
            obj.hdr.code := NumGet(ptr, A_PtrSize * 2, "Int")
            obj.dwDrawStage := NumGet(ptr, A_PtrSize * 3, "UInt")
            obj.hdc := NumGet(ptr, A_PtrSize * 3 + 4, "UPtr")
            obj.rc := _Dark.RECT()
            rectOffset := A_PtrSize * 3 + 4 + A_PtrSize
            obj.rc.left := NumGet(ptr, rectOffset, "Int")
            obj.rc.top := NumGet(ptr, rectOffset + 4, "Int")
            obj.rc.right := NumGet(ptr, rectOffset + 8, "Int")
            obj.rc.bottom := NumGet(ptr, rectOffset + 12, "Int")
            obj.dwItemSpec := NumGet(ptr, rectOffset + 16, "UPtr")
            obj.uItemState := NumGet(ptr, rectOffset + 16 + A_PtrSize, "UInt")
            obj.lItemlParam := NumGet(ptr, rectOffset + 16 + A_PtrSize + 4, "IPtr")
        }
        return obj
    }

    static DarkColors := Map("Background", 0x171717, "Controls", 0x202020, "Font", 0xFFFFFF)
    static Dark := Map("Background", 0x171717, "Controls", 0x1b1b1b, "ComboBoxBg", 0x1E1E1E, "Font", 0xE0E0E0,
        "SliderThumb", 0x3E3E3E, "SliderTrack", 0x2D2D2D, "ProgressFill", 0x0078D7)

    static Instances := Map()
    static WindowProcOldMap := Map()
    static WindowProcCallbacks := Map()
    static TextBackgroundBrush := 0
    static ControlsBackgroundBrush := 0
    static ButtonColors := Map()
    static ComboBoxes := Map()
    static ListViewHeaders := Map()
    static HeaderCallbacks := Map()
    static CheckboxTextControls := Map()
    static TextControls := Map()
    static DarkCheckboxPairs := Map()
    static GroupBoxes := Map()
    static RadioButtons := Map()
    static SliderControls := Map()
    static ProgressControls := Map()
    static DateTimeControls := Map()
    static MonthCalControls := Map()
    static TabControls := Map()
    static ListBoxControls := Map()

    static WM_CTLCOLOREDIT := 0x0133
    static WM_CTLCOLORLISTBOX := 0x0134
    static WM_CTLCOLORBTN := 0x0135
    static WM_CTLCOLORSTATIC := 0x0138
    static WM_NOTIFY := 0x004E
    static WM_PAINT := 0x000F
    static WM_ERASEBKGND := 0x0014
    static NM_CUSTOMDRAW := -12
    static HDN_FIRST := -300
    static HDN_CUSTOMDRAW := -12
    static CDDS_PREPAINT := 0x00000001
    static CDDS_ITEMPREPAINT := 0x00010001
    static CDRF_DODEFAULT := 0x0
    static CDRF_NEWFONT := 0x00000002
    static CDRF_NOTIFYITEMDRAW := 0x00000020
    static CDRF_SKIPDEFAULT := 0x00000004
    static DC_BRUSH := 18
    static GWL_WNDPROC := -4
    static GWL_STYLE := -16
    static LVM_GETHEADER := 0x101F
    static HDM_SETIMAGELIST := 0x1208
    static HDM_SETITEM := 0x120C
    static HDM_LAYOUT := 0x1200
    static GetWindowLong := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
    static SetWindowLong := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"

    static __New() {
        global _Dark_WindowProc := ObjBindMethod(_Dark, "ProcessWindowMessage")

        if (!_Dark.TextBackgroundBrush)
            _Dark.TextBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Background"], "Ptr")
        if (!_Dark.ControlsBackgroundBrush)
            _Dark.ControlsBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Controls"], "Ptr")
    }

    static HandleThemeChanged(ctrl, *) {
        return 0
    }

    static ProcessWindowMessage(hwnd, msg, wParam, lParam, *) {
        static WM_CTLCOLOREDIT := 0x0133
        static WM_CTLCOLORLISTBOX := 0x0134
        static WM_CTLCOLORBTN := 0x0135
        static WM_CTLCOLORSTATIC := 0x0138
        static WM_NOTIFY := 0x004E
        static TRANSPARENT := 1
        static NM_CUSTOMDRAW := -12
        static CDDS_PREPAINT := 0x00000001
        static CDDS_ITEMPREPAINT := 0x00010001
        static CDRF_DODEFAULT := 0x0
        static CDRF_NOTIFYITEMDRAW := 0x00000020

        if _Dark.WindowProcOldMap.Has(hwnd) {
            oldProc := _Dark.WindowProcOldMap[hwnd]
        } else {
            return DllCall("DefWindowProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
        }

        ctrlHwnd := lParam

        switch msg {
            case WM_CTLCOLOREDIT, WM_CTLCOLORLISTBOX:
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", _Dark.Dark["Font"])
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Controls"])
                return _Dark.ControlsBackgroundBrush

            case WM_CTLCOLORBTN:
                if _Dark.ButtonColors.Has(ctrlHwnd) {
                    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", _Dark.ButtonColors[ctrlHwnd]["text"])
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.ButtonColors[ctrlHwnd]["bg"])
                    DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                    return _Dark.ControlsBackgroundBrush
                }

            case WM_CTLCOLORSTATIC:
                if _Dark.TextControls.Has(ctrlHwnd) || _Dark.GroupBoxes.Has(ctrlHwnd) ||
                    _Dark.DarkCheckboxPairs.Has(ctrlHwnd) || _Dark.RadioButtons.Has(ctrlHwnd) {
                    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", _Dark.Dark["Font"])
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Background"])
                    DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                    return _Dark.TextBackgroundBrush
                }

            case WM_NOTIFY:
                ; Check if notification is from a ListView header
                hdr := _Dark.StructFromPtr(_Dark.NMHDR, lParam)
                if (hdr.code = NM_CUSTOMDRAW && _Dark.ListViewHeaders.Has(hdr.hwndFrom)) {
                    nmcd := _Dark.StructFromPtr(_Dark.NMCUSTOMDRAW, lParam)

                    if (nmcd.dwDrawStage = CDDS_PREPAINT)
                        return CDRF_NOTIFYITEMDRAW

                    if (nmcd.dwDrawStage = CDDS_ITEMPREPAINT) {
                        DllCall("gdi32\SetTextColor", "Ptr", nmcd.hdc, "UInt", 0xFFFFFF)
                        DllCall("gdi32\SetBkMode", "Ptr", nmcd.hdc, "Int", 1)  ; Transparent
                        return CDRF_DODEFAULT
                    }
                }
        }

        return DllCall("CallWindowProc", "Ptr", oldProc, "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    static SetWindowPos(hWnd, hWndInsertAfter, X := 0, Y := 0, cx := 0, cy := 0, uFlags := 0x40) {
        return DllCall("User32\SetWindowPos", "ptr", hWnd, "ptr", hWndInsertAfter, "int", X, "int", Y, "int", cx, "int", cy, "uint", uFlags, "int")
    }

    static SendMessage(msg, wParam, lParam, hwndOrControl) {
        hwnd := HasProp(hwndOrControl, "Hwnd") ? hwndOrControl.Hwnd : hwndOrControl
        return DllCall("user32\SendMessage", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    static SetTextColor(hdc, color) {
        return DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", color)
    }

    static SetBkMode(hdc, mode) {
        return DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", mode)
    }

    __New(GuiObj) {
        _Dark.__New()
        this.Gui := GuiObj
        this.darkCheckboxes := Map()
        this.Gui.BackColor := _Dark.Dark["Background"]

        if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
            DWMWA_USE_IMMERSIVE_DARK_MODE := 19
            if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
                DWMWA_USE_IMMERSIVE_DARK_MODE := 20
            uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
            SetPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
            FlushMenuThemes := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Gui.hWnd,
                "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", true, "Int", 4)
            DllCall(SetPreferredAppMode, "Int", 2)
            DllCall(FlushMenuThemes)
        }

        this.SetControlsTheme()
        this.SetupWindowProc()
        this.RedrawAllControls()
        _Dark.Instances[this.Gui.Hwnd] := this
        return this
    }

    SetupWindowProc() {
        hwnd := this.Gui.Hwnd
        if _Dark.WindowProcOldMap.Has(hwnd)
            return

        callback := CallbackCreate(_Dark_WindowProc, , 4)
        _Dark.WindowProcCallbacks[hwnd] := callback

        originalProc := DllCall(_Dark.SetWindowLong, "Ptr", hwnd, "Int", _Dark.GWL_WNDPROC, "Ptr", callback, "Ptr")
        _Dark.WindowProcOldMap[hwnd] := originalProc
    }

    SetTheme(themeMap) {
        if themeMap.Has("Background")
            _Dark.Dark["Background"] := themeMap["Background"]
        if themeMap.Has("Controls")
            _Dark.Dark["Controls"] := themeMap["Controls"]
        if themeMap.Has("Font")
            _Dark.Dark["Font"] := themeMap["Font"]

        this.Gui.BackColor := _Dark.Dark["Background"]

        if (_Dark.TextBackgroundBrush) {
            DllCall("DeleteObject", "Ptr", _Dark.TextBackgroundBrush)
            _Dark.TextBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Background"], "Ptr")
        }

        if (_Dark.ControlsBackgroundBrush) {
            DllCall("DeleteObject", "Ptr", _Dark.ControlsBackgroundBrush)
            _Dark.ControlsBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Controls"], "Ptr")
        }

        this.RedrawAllControls()
    }

    AddDarkCheckBox(Options, Text) {
        static SM_CXMENUCHECK := 71
        static SM_CYMENUCHECK := 72
        static checkBoxW := SysGet(SM_CXMENUCHECK)
        static checkBoxH := SysGet(SM_CYMENUCHECK)
        chbox := this.Gui.AddCheckBox(Options " r1.5 +0x4000000", "")
        if !InStr(Options, "right")
            txt := this.Gui.AddText("xp+" (checkBoxW + 8) " yp+2 HP-4 +0x4000200 cFFFFFF", Text)
        else
            txt := this.Gui.AddText("xp+8 yp+2 HP-4 +0x4000200 cFFFFFF", Text)
        this.darkCheckboxes[chbox.Hwnd] := txt
        chbox.DeleteProp("Text")
        chbox.DefineProp("Text", {
            Get: ObjBindMethod(txt, "GetText"),
            Set: ObjBindMethod(txt, "SetText")
        })
        _Dark.SetWindowPos(txt.Hwnd, 0, 0, 0, 0, 0, 0x43)
        DllCall("uxtheme\SetWindowTheme", "Ptr", chbox.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        pair := Map()
        pair["checkbox"] := chbox
        pair["text"] := txt
        _Dark.DarkCheckboxPairs[chbox.Hwnd] := pair
        DllCall("InvalidateRect", "Ptr", chbox.Hwnd, "Ptr", 0, "Int", true)
        DllCall("InvalidateRect", "Ptr", txt.Hwnd, "Ptr", 0, "Int", true)
        return chbox
    }

    AddListView(Options, Headers) {
        lv := this.Gui.Add("ListView", Options, Headers)

        static LVM_SETBKCOLOR := 0x1001
        static LVM_SETTEXTCOLOR := 0x1033
        static LVM_SETTEXTBKCOLOR := 0x1026
        static LVM_GETHEADER := 0x101F
        static UIS_SET := 1
        static UISF_HIDEFOCUS := 0x1
        static WM_CHANGEUISTATE := 0x0127
        static WM_NOTIFY := 0x4E
        static WM_THEMECHANGED := 0x031A

        ; Set ListView colors
        _Dark.SendMessage(LVM_SETTEXTCOLOR, 0, 0xFFFFFF, lv.hWnd)
        _Dark.SendMessage(LVM_SETBKCOLOR, 0, _Dark.Dark["Background"], lv.hWnd)
        _Dark.SendMessage(LVM_SETTEXTBKCOLOR, 0, _Dark.Dark["Background"], lv.hWnd)

        ; Enable grid lines and double buffering
        lv.Opt("+Grid +LV0x10000")

        ; Get header handle
        hHeader := _Dark.SendMessage(LVM_GETHEADER, 0, 0, lv.Hwnd)
        lv.Header := hHeader

        ; Register header in ListViewHeaders map
        _Dark.ListViewHeaders[hHeader] := true

        ; Set theme
        lv.OnMessage(WM_THEMECHANGED, ObjBindMethod(_Dark, "HandleThemeChanged"))
        _Dark.SendMessage(WM_CHANGEUISTATE, (UIS_SET << 8) | UISF_HIDEFOCUS, 0, lv.Hwnd)

        ; Apply dark theme to ListView and header
        DllCall("uxtheme\SetWindowTheme", "Ptr", hHeader, "Str", "DarkMode_ItemsView", "Ptr", 0)
        DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)

        ; Force redraw to apply changes
        DllCall("InvalidateRect", "Ptr", hHeader, "Ptr", 0, "Int", true)
        DllCall("InvalidateRect", "Ptr", lv.Hwnd, "Ptr", 0, "Int", true)

        return lv
    }

    AddDarkButton(Options, Text) {
        btn := this.Gui.AddButton(Options, Text)
        DllCall("uxtheme\SetWindowTheme", "Ptr", btn.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        buttonColorMap := Map("bg", _Dark.Dark["Controls"], "text", _Dark.Dark["Font"])
        _Dark.ButtonColors[btn.Hwnd] := buttonColorMap
        btn.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", btn.hWnd, "Ptr", 0, "Int", true)
        return btn
    }

    AddDarkEdit(Options, Text := "") {
        edit := this.Gui.AddEdit(Options, Text)
        DllCall("uxtheme\SetWindowTheme", "Ptr", edit.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        edit.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", edit.hWnd, "Ptr", 0, "Int", true)
        return edit
    }

    AddDarkComboBox(Options, Items := "") {
        combo := this.Gui.AddComboBox(Options, Items)
        DllCall("uxtheme\SetWindowTheme", "Ptr", combo.hWnd, "Str", "DarkMode_CFD", "Ptr", 0)
        _Dark.ComboBoxes[combo.Hwnd] := true
        combo.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", combo.hWnd, "Ptr", 0, "Int", true)
        return combo
    }

    AddDarkText(Options, Text := "") {
        txt := this.Gui.AddText(Options " cFFFFFF", Text)
        _Dark.TextControls[txt.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", txt.hWnd, "Ptr", 0, "Int", true)
        return txt
    }

    AddDarkGroupBox(Options, Text := "") {
        groupBox := this.Gui.AddGroupBox(Options, Text)
        DllCall("uxtheme\SetWindowTheme", "Ptr", groupBox.hWnd, "Str", "", "Ptr", 0)
        groupBox.SetFont("cFFFFFF")
        _Dark.GroupBoxes[groupBox.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", groupBox.hWnd, "Ptr", 0, "Int", true)
        return groupBox
    }

    AddDarkRadio(Options, Text := "") {
        radio := this.Gui.AddRadio(Options, Text)
        DllCall("uxtheme\SetWindowTheme", "Ptr", radio.hWnd, "Str", "", "Ptr", 0)
        buttonColorMap := Map("bg", _Dark.Dark["Background"], "text", 0xFFFFFF)
        _Dark.ButtonColors[radio.Hwnd] := buttonColorMap
        _Dark.RadioButtons[radio.Hwnd] := true
        radio.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", radio.hWnd, "Ptr", 0, "Int", true)
        return radio
    }

    AddDarkListBox(Options, Items := "") {
        listBox := this.Gui.AddListBox(Options, Items)
        DllCall("uxtheme\SetWindowTheme", "Ptr", listBox.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        _Dark.ListBoxControls[listBox.Hwnd] := true
        listBox.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", listBox.hWnd, "Ptr", 0, "Int", true)
        return listBox
    }

    AddDarkSlider(Options, StartingValue := 0) {
        slider := this.Gui.AddSlider(Options, StartingValue)
        DllCall("uxtheme\SetWindowTheme", "Ptr", slider.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        _Dark.SliderControls[slider.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", slider.hWnd, "Ptr", 0, "Int", true)
        return slider
    }

    AddDarkProgress(Options, StartingValue := 0) {
        progress := this.Gui.AddProgress(Options, StartingValue)
        DllCall("uxtheme\SetWindowTheme", "Ptr", progress.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        _Dark.ProgressControls[progress.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", progress.hWnd, "Ptr", 0, "Int", true)
        return progress
    }

    AddDarkDateTime(Options := "") {
        dateTime := this.Gui.AddDateTime(Options)
        DllCall("uxtheme\SetWindowTheme", "Ptr", dateTime.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        _Dark.DateTimeControls[dateTime.Hwnd] := true
        dateTime.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", dateTime.hWnd, "Ptr", 0, "Int", true)
        return dateTime
    }

    AddDarkMonthCal(Options := "") {
        monthCal := this.Gui.AddMonthCal(Options)
        DllCall("uxtheme\SetWindowTheme", "Ptr", monthCal.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        _Dark.MonthCalControls[monthCal.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", monthCal.hWnd, "Ptr", 0, "Int", true)
        return monthCal
    }

    AddDarkTab3(Options, Tabs) {
        tab := this.Gui.AddTab3(Options, Tabs)
        DllCall("uxtheme\SetWindowTheme", "Ptr", tab.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        _Dark.TabControls[tab.Hwnd] := true
        tab.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", tab.hWnd, "Ptr", 0, "Int", true)
        return tab
    }

    RedrawAllControls() {
        DllCall("RedrawWindow", "Ptr", this.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0285)
        for hWnd, GuiCtrlObj in this.Gui {
            DllCall("RedrawWindow", "Ptr", GuiCtrlObj.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0001)
            DllCall("InvalidateRect", "Ptr", GuiCtrlObj.Hwnd, "Ptr", 0, "Int", true)
        }
    }

    SetControlsTheme() {
        for hWnd, GuiCtrlObj in this.Gui {
            switch GuiCtrlObj.Type {
                case "Button":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    buttonColorMap := Map("bg", _Dark.Dark["Controls"], "text", _Dark.Dark["Font"])
                    _Dark.ButtonColors[GuiCtrlObj.Hwnd] := buttonColorMap
                case "CheckBox", "Radio":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "", "Ptr", 0)
                    buttonColorMap := Map("bg", _Dark.Dark["Background"], "text", 0xFFFFFF)
                    _Dark.ButtonColors[GuiCtrlObj.Hwnd] := buttonColorMap
                    if (GuiCtrlObj.Type == "Radio")
                        _Dark.RadioButtons[GuiCtrlObj.Hwnd] := true
                    GuiCtrlObj.SetFont("cFFFFFF")
                case "ComboBox", "DDL":
                    _Dark.ComboBoxes[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_CFD", "Ptr", 0)
                case "Edit":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                case "ListView":
                    _Dark.SendMessage(0x1024, 0, _Dark.Dark["Font"], GuiCtrlObj.Hwnd)
                    _Dark.SendMessage(0x1026, 0, _Dark.Dark["Background"], GuiCtrlObj.Hwnd)
                    _Dark.SendMessage(0x1001, 0, _Dark.Dark["Background"], GuiCtrlObj.Hwnd)
                    GuiCtrlObj.Header := _Dark.SendMessage(0x101F, 0, 0, GuiCtrlObj.Hwnd)
                    GuiCtrlObj.OnMessage(0x031A, ObjBindMethod(_Dark, "HandleThemeChanged"))
                    _Dark.SendMessage(0x0127, (1 << 8) | 0x1, 0, GuiCtrlObj.Hwnd)

                    ; Register header in ListViewHeaders map for custom drawing
                    _Dark.ListViewHeaders[GuiCtrlObj.Header] := true

                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.Header, "Str", "DarkMode_ItemsView", "Ptr", 0)
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    DllCall("InvalidateRect", "Ptr", GuiCtrlObj.Header, "Ptr", 0, "Int", true)
                case "ListBox", "UpDown":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                case "Text", "Link":
                    _Dark.TextControls[GuiCtrlObj.Hwnd] := true
                    GuiCtrlObj.Opt("cFFFFFF")
                case "GroupBox":
                    _Dark.GroupBoxes[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "", "Ptr", 0)
                    GuiCtrlObj.SetFont("cFFFFFF")
                case "Slider":
                    _Dark.SliderControls[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                case "Progress":
                    _Dark.ProgressControls[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                case "DateTime":
                    _Dark.DateTimeControls[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    GuiCtrlObj.SetFont("cFFFFFF")
                case "MonthCal":
                    _Dark.MonthCalControls[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                case "Tab3":
                    _Dark.TabControls[GuiCtrlObj.Hwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    GuiCtrlObj.SetFont("cFFFFFF")
            }
            DllCall("InvalidateRect", "Ptr", GuiCtrlObj.Hwnd, "Ptr", 0, "Int", true)
        }
    }
}