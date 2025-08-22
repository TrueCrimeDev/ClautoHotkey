#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

WindowManagerApp()

class WindowManagerApp {
    static Instance := ""

    __New() {
        WindowManagerApp.Instance := this
        this.Manager := WindowManager()
        this.DPI := DPIManager()
        this.Batch := BatchWindowOperator()
        this.Monitor := MonitorManager()
        this.TestGUI := WindowManagerTestGUI(this)
        this.SetupTrayMenu()
        this.SetupHotkeys()
        this.TestGUI.Show()
        WinSetAlwaysOnTop(true, "ahk_id " . this.TestGUI.gui.Hwnd)
        DllCall("SetWindowPos", "Ptr", this.TestGUI.gui.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0003)
    }

    SetupTrayMenu() {
        A_TrayMenu.Delete()
        A_TrayMenu.Add("Open Window Manager Control", (*) => this.TestGUI.Show())
        A_TrayMenu.Add("Always On Top List", (*) => this.ShowAlwaysOnTopList())
        A_TrayMenu.Add()
        A_TrayMenu.Add("Window Info", (*) => this.ShowWindowInfo())
        A_TrayMenu.Add("Window Groups", (*) => this.ShowWindowGroups())
        A_TrayMenu.Add()
        A_TrayMenu.Add("Exit", (*) => ExitApp())
        A_TrayMenu.Default := "Open Window Manager Control"
        A_TrayMenu.ClickCount := 1
    }

    SetupHotkeys() {
        HotKey("#a", (*) => this.ShowAlwaysOnTopList())
        HotKey("#q", (*) => this.Manager.SmartClose())
        HotKey("#m", (*) => this.Manager.SmartMinimize())
        HotKey("#r", (*) => this.Manager.RestoreLast())
        HotKey("#x", (*) => this.Manager.Maximize())
        HotKey("#c", (*) => this.Manager.CenterWindow())
        HotKey("#Left", (*) => this.Manager.SnapLeft())
        HotKey("#Right", (*) => this.Manager.SnapRight())
        HotKey("#+Left", (*) => this.Manager.SnapLeftMultiMonitor())
        HotKey("#+Right", (*) => this.Manager.SnapRightMultiMonitor())
        HotKey("#Tab", (*) => this.Manager.CycleSameApp())
        HotKey("#t", (*) => this.Manager.ToggleTransparency())
        HotKey("#g", (*) => this.ShowWindowGroups())
        HotKey("#i", (*) => this.ShowWindowInfo())
        HotKey("#+d", (*) => this.Manager.DockWindow())
        HotKey("#F12", (*) => this.TestGUI.Toggle())
    }

    ShowWindowGroups() {
        groups := this.Manager.GetWindowGroups()
        if groups.Length = 0 {
            this.ShowTooltip("No window groups available")
            return
        }

        groupList := ""
        for group in groups {
            groupList .= group["name"] . " (" . group["windows"].Length . " windows)`n"
        }

        this.ShowTooltip("Window Groups:`n" . groupList, 3000)
    }

    ShowWindowInfo() {
        info := this.Manager.GetWindowInfo()
        if !info.Has("title") {
            this.ShowTooltip("No active window")
            return
        }

        infoText := "Window Information:`n"
        infoText .= "Title: " . info["title"] . "`n"
        infoText .= "Process: " . info["process"] . "`n"
        infoText .= "Position: " . info["x"] . ", " . info["y"] . "`n"
        infoText .= "Size: " . info["width"] . " x " . info["height"] . "`n"
        infoText .= "DPI: " . info["dpi"] . "`n"
        infoText .= "Monitor: " . info["monitor"] . "`n"
        infoText .= "Always on Top: " . (info["alwaysOnTop"] ? "Yes" : "No") . "`n"
        infoText .= "Transparency: " . info["transparency"] . "%"

        this.ShowTooltip(infoText, 5000)
    }

    ShowTooltip(text, duration := 2000) {
        ToolTip(text)
        SetTimer(() => ToolTip(), -duration)
    }

    ShowAlwaysOnTopList() {
        windows := this.Manager.GetWindowsWithStatus()

        if windows.Length = 0 {
            this.ShowTooltip("No visible windows found", 2000)
            return
        }

        listGui := Gui("+Resize +AlwaysOnTop", "Always On Top Status")
        listGui.MarginX := 8
        listGui.MarginY := 8
        
        darkTheme := _Dark(listGui)
        
        lv := darkTheme.AddListView("w450 h200", ["", "Title", "Process"])
        
        lv.windowData := Map()

        for index, win in windows {
            status := win["alwaysOnTop"] ? "📌" : ""
            row := lv.Add("", status, win["title"], win["process"])
            lv.windowData[row] := win["id"]
        }

        lv.ModifyCol(1, 25)
        lv.ModifyCol(2, 295)
        lv.ModifyCol(3, 130)

        lv.listGui := listGui
        lv.app := this
        lv.darkTheme := darkTheme

        lv.OnEvent("DoubleClick", ToggleOnTopHandler)

        listGui.Show()
        WinSetAlwaysOnTop(true, "ahk_id " . listGui.Hwnd)

        ToggleOnTopHandler(lv, row) {
            if row = 0
                return

            if lv.windowData.Has(row) {
                winId := lv.windowData[row]
                lv.app.Manager.ToggleAlwaysOnTop("ahk_id " . winId)

                exStyle := WinGetExStyle("ahk_id " . winId)
                isOnTop := (exStyle & 0x8) != 0

                lv.Modify(row, "Col1", isOnTop ? "📌" : "")
            }
        }
    }
}
class WindowManager {
    __New() {
        this.MinimizedWindows := []
        this.WindowGroups := Map()
        this.DockedWindows := Map()
        this.TransparencyStates := Map()
        this.AlwaysOnTopWindows := Map()
        this.DPI := DPIManager()
        this.Monitor := MonitorManager()
        this.Batch := BatchWindowOperator()
    }

    GetWindowsWithStatus() {
        windows := []
        winList := WinGetList()

        for winId in winList {
            try {
                title := WinGetTitle("ahk_id " . winId)

                if title = "" || title = "Program Manager"
                    continue

                style := WinGetStyle("ahk_id " . winId)
                if !(style & 0x10000000)
                    continue

                exStyle := WinGetExStyle("ahk_id " . winId)
                isAlwaysOnTop := (exStyle & 0x8) != 0

                winMap := Map()
                winMap["id"] := winId
                winMap["title"] := title
                winMap["class"] := WinGetClass("ahk_id " . winId)
                winMap["process"] := WinGetProcessName("ahk_id " . winId)
                winMap["alwaysOnTop"] := isAlwaysOnTop

                windows.Push(winMap)
            }
        }

        sortedWindows := []

        for win in windows {
            if win["alwaysOnTop"]
                sortedWindows.Push(win)
        }

        for win in windows {
            if !win["alwaysOnTop"]
                sortedWindows.Push(win)
        }

        return sortedWindows
    }

    SmartMinimize(winTitle := "A") {
        hwnd := WinExist(winTitle)
        if !hwnd
            return false

        winId := "ahk_id " . hwnd

        if WinGetMinMax(winId) != -1 {
            winInfo := Map()
            winInfo["id"] := hwnd
            winInfo["title"] := WinGetTitle(winId)
            winInfo["position"] := this.GetWindowPosition(hwnd)
            winInfo["monitor"] := this.Monitor.GetWindowMonitor(hwnd)
            winInfo["timestamp"] := A_TickCount

            this.MinimizedWindows.Push(winInfo)

            PostMessage(0x0112, 0xF020, 0, , winId)
            return true
        }
        return false
    }

    RestoreLast() {
        while this.MinimizedWindows.Length > 0 {
            winInfo := this.MinimizedWindows.Pop()

            if WinExist("ahk_id " . winInfo["id"]) {
                PostMessage(0x0112, 0xF120, 0, , "ahk_id " . winInfo["id"])

                if winInfo.Has("position") {
                    SetTimer(() => this.RestorePosition(winInfo["id"], winInfo["position"]), -100)
                }
                return true
            }
        }
        return false
    }

    RestorePosition(hwnd, position) {
        if WinExist("ahk_id " . hwnd) {
            WinMove(position["x"], position["y"], position["width"], position["height"], "ahk_id " . hwnd)
        }
    }

    GetWindowPosition(hwnd) {
        WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
        pos := Map()
        pos["x"] := x
        pos["y"] := y
        pos["width"] := w
        pos["height"] := h
        return pos
    }

    DockWindow(winTitle := "A") {
        hwnd := WinExist(winTitle)
        if !hwnd
            return false

        monitor := this.Monitor.GetWindowMonitor(hwnd)
        MonitorGetWorkArea(monitor, &left, &top, &right, &bottom)

        screenWidth := right - left
        screenHeight := bottom - top

        dockWidth := screenWidth // 3
        dockHeight := screenHeight

        if this.DockedWindows.Has(hwnd) {
            pos := this.DockedWindows[hwnd]["original"]
            WinMove(pos["x"], pos["y"], pos["width"], pos["height"], "ahk_id " . hwnd)
            this.DockedWindows.Delete(hwnd)
            this.ShowStatus(WinGetTitle("ahk_id " . hwnd), "Undocked")
        } else {
            WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)

            originalPos := Map()
            originalPos["x"] := x
            originalPos["y"] := y
            originalPos["width"] := w
            originalPos["height"] := h

            dockInfo := Map()
            dockInfo["original"] := originalPos
            dockInfo["docked"] := true

            this.DockedWindows[hwnd] := dockInfo

            WinMove(right - dockWidth, top, dockWidth, dockHeight, "ahk_id " . hwnd)
            this.ShowStatus(WinGetTitle("ahk_id " . hwnd), "Docked to Right")
        }
        return true
    }

    GetWindowGroups() {
        groups := []
        for name, windows in this.WindowGroups {
            groupMap := Map()
            groupMap["name"] := name
            groupMap["windows"] := windows
            groups.Push(groupMap)
        }
        return groups
    }

    ListWindows() {
        windows := []
        winList := WinGetList()

        for winId in winList {
            try {
                title := WinGetTitle("ahk_id " . winId)
                if title != "" && title != "Program Manager" {
                    winMap := Map()
                    winMap["id"] := winId
                    winMap["title"] := title
                    winMap["class"] := WinGetClass("ahk_id " . winId)
                    winMap["process"] := WinGetProcessName("ahk_id " . winId)
                    windows.Push(winMap)
                }
            }
        }

        return windows
    }

    ToggleAlwaysOnTop(winTitle := "A") {
        hwnd := WinExist(winTitle)
        if !hwnd
            return false

        try {
            WinSetAlwaysOnTop(-1, "ahk_id " . hwnd)
            exStyle := WinGetExStyle("ahk_id " . hwnd)
            isOnTop := (exStyle & 0x8) != 0

            if isOnTop {
                this.AlwaysOnTopWindows[hwnd] := true
            } else {
                if this.AlwaysOnTopWindows.Has(hwnd)
                    this.AlwaysOnTopWindows.Delete(hwnd)
            }

            this.ShowStatus(WinGetTitle("ahk_id " . hwnd),
                isOnTop ? "Always on Top: ON" : "Always on Top: OFF")
            return true
        }
        return false
    }

    Maximize(winTitle := "A") {
        hwnd := WinExist(winTitle)
        if !hwnd
            return false

        try {
            currentState := WinGetMinMax("ahk_id " . hwnd)

            if currentState = 1 {
                WinRestore("ahk_id " . hwnd)
            } else {
                WinMaximize("ahk_id " . hwnd)
            }
            return true
        }
        return false
    }

    CenterWindow(winTitle := "A") {
        hwnd := WinExist(winTitle)
        if !hwnd
            return false

        monitor := this.Monitor.GetWindowMonitor(hwnd)
        MonitorGet(monitor, &left, &top, &right, &bottom)
        MonitorGetWorkArea(monitor, &workLeft, &workTop, &workRight, &workBottom)

        WinGetPos(, , &winW, &winH, "ahk_id " . hwnd)

        newX := workLeft + ((workRight - workLeft - winW) / 2)
        newY := workTop + ((workBottom - workTop - winH) / 2)

        WinMove(newX, newY, , , "ahk_id " . hwnd)
        this.ShowStatus(WinGetTitle("ahk_id " . hwnd), "Window Centered")
        return true
    }

    SnapLeft() {
        Send("{LWin Down}{Left}{LWin Up}")
    }

    SnapRight() {
        Send("{LWin Down}{Right}{LWin Up}")
    }

    SnapLeftMultiMonitor() {
        Send("{LShift Down}{LWin Down}{Left}{LWin Up}{LShift Up}")
    }

    SnapRightMultiMonitor() {
        Send("{LWin Down}{LShift Down}{Right}{LWin Up}{LShift Up}")
    }

    SmartClose(winTitle := "A") {
        hwnd := WinExist(winTitle)
        if !hwnd
            return false

        process := WinGetProcessName("ahk_id " . hwnd)

        if process = "chrome.exe" || process = "firefox.exe" || process = "msedge.exe" {
            Send("^w")
        } else if process = "explorer.exe" {
            Send("!{F4}")
        } else {
            WinClose("ahk_id " . hwnd)
        }
        return true
    }

    CycleSameApp() {
        hwnd := WinActive("A")
        if !hwnd
            return false

        winClass := WinGetClass("ahk_id " . hwnd)
        activeProcess := WinGetProcessName("ahk_id " . hwnd)

        winList := (activeProcess = "explorer.exe")
            ? WinGetList("ahk_exe " . activeProcess . " ahk_class " . winClass)
            : WinGetList("ahk_exe " . activeProcess)

        if winList && winList.Length > 1 {
            nextId := winList[winList.Length]
            WinMoveTop("ahk_id " . nextId)
            WinActivate("ahk_id " . nextId)

            this.ShowStatus(WinGetTitle("ahk_id " . nextId), "Switched to next window")
        }
        return true
    }

    ToggleTransparency(winTitle := "A") {
        hwnd := WinExist(winTitle)
        if !hwnd
            return false

        currentTrans := WinGetTransparent("ahk_id " . hwnd)

        if currentTrans = "" || currentTrans = 255 {
            WinSetTransparent(200, "ahk_id " . hwnd)
            this.TransparencyStates[hwnd] := 200
            this.ShowStatus(WinGetTitle("ahk_id " . hwnd), "Transparency: 80%")
        } else if currentTrans >= 200 {
            WinSetTransparent(150, "ahk_id " . hwnd)
            this.TransparencyStates[hwnd] := 150
            this.ShowStatus(WinGetTitle("ahk_id " . hwnd), "Transparency: 60%")
        } else {
            WinSetTransparent("Off", "ahk_id " . hwnd)
            this.TransparencyStates.Delete(hwnd)
            this.ShowStatus(WinGetTitle("ahk_id " . hwnd), "Transparency: OFF")
        }
        return true
    }

    GetWindowInfo(winTitle := "A") {
        info := Map()

        try {
            hwnd := WinExist(winTitle)
            if !hwnd
                return info

            info["hwnd"] := hwnd
            info["title"] := WinGetTitle("ahk_id " . hwnd)
            info["class"] := WinGetClass("ahk_id " . hwnd)
            info["process"] := WinGetProcessName("ahk_id " . hwnd)
            info["pid"] := WinGetPID("ahk_id " . hwnd)

            WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
            info["x"] := x
            info["y"] := y
            info["width"] := w
            info["height"] := h

            info["minMax"] := WinGetMinMax("ahk_id " . hwnd)
            info["exStyle"] := WinGetExStyle("ahk_id " . hwnd)
            info["alwaysOnTop"] := (info["exStyle"] & 0x8) != 0

            info["dpi"] := this.DPI.GetWindowDPI(hwnd)
            info["monitor"] := this.Monitor.GetWindowMonitor(hwnd)

            trans := WinGetTransparent("ahk_id " . hwnd)
            info["transparency"] := trans = "" ? 100 : Round((trans / 255) * 100)
        }

        return info
    }

    ShowStatus(title, message) {
        ToolTip(title . "`n" . message)
        SetTimer(() => ToolTip(), -2000)
    }
}
class MonitorManager {
    __New() {
        this.MonitorCount := MonitorGetCount()
        this.UpdateMonitorInfo()
    }

    UpdateMonitorInfo() {
        this.Monitors := []
        Loop this.MonitorCount {
            MonitorGet(A_Index, &left, &top, &right, &bottom)
            MonitorGetWorkArea(A_Index, &workLeft, &workTop, &workRight, &workBottom)

            monInfo := Map()
            monInfo["index"] := A_Index
            monInfo["bounds"] := Map("left", left, "top", top, "right", right, "bottom", bottom)
            monInfo["workArea"] := Map("left", workLeft, "top", workTop, "right", workRight, "bottom", workBottom)
            monInfo["width"] := right - left
            monInfo["height"] := bottom - top
            monInfo["primary"] := MonitorGetPrimary() = A_Index

            this.Monitors.Push(monInfo)
        }
    }

    GetWindowMonitor(hwnd) {
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
        centerX := winX + (winW / 2)
        centerY := winY + (winH / 2)

        Loop this.MonitorCount {
            MonitorGet(A_Index, &left, &top, &right, &bottom)
            if centerX >= left && centerX <= right && centerY >= top && centerY <= bottom
                return A_Index
        }
        return 1
    }

    MoveToMonitor(hwnd, monitorIndex) {
        if monitorIndex < 1 || monitorIndex > this.MonitorCount
            return false

        monitor := this.Monitors[monitorIndex]
        WinGetPos(, , &winW, &winH, "ahk_id " . hwnd)

        workArea := monitor["workArea"]
        newX := workArea["left"] + ((workArea["right"] - workArea["left"] - winW) / 2)
        newY := workArea["top"] + ((workArea["bottom"] - workArea["top"] - winH) / 2)

        WinMove(newX, newY, , , "ahk_id " . hwnd)
        return true
    }
}

class BatchWindowOperator {
    __New() {
        this.Operations := []
    }

    Begin(count := 2) {
        this.hDwp := DllCall("BeginDeferWindowPos", "int", count, "ptr")
        this.Operations := []
        return this
    }

    Add(hwnd, x, y, w, h, flags := 0x0004) {
        if !this.hDwp
            return this

        opMap := Map()
        opMap["hwnd"] := hwnd
        opMap["x"] := x
        opMap["y"] := y
        opMap["w"] := w
        opMap["h"] := h
        opMap["flags"] := flags

        this.Operations.Push(opMap)

        this.hDwp := DllCall("DeferWindowPos",
            "ptr", this.hDwp,
            "ptr", hwnd,
            "ptr", 0,
            "int", x,
            "int", y,
            "int", w,
            "int", h,
            "uint", flags,
            "ptr")

        return this
    }

    Execute() {
        if !this.hDwp
            return false

        result := DllCall("EndDeferWindowPos", "ptr", this.hDwp, "int")
        this.hDwp := 0
        this.Operations := []
        return result
    }

    ArrangeWindows(windows, layout := "tile") {
        if windows.Length = 0
            return false

        MonitorGetWorkArea(1, &left, &top, &right, &bottom)
        areaWidth := right - left
        areaHeight := bottom - top

        this.Begin(windows.Length)

        switch layout {
            case "tile":
                cols := Ceil(Sqrt(windows.Length))
                rows := Ceil(windows.Length / cols)

                winWidth := areaWidth // cols
                winHeight := areaHeight // rows

                for index, hwnd in windows {
                    col := Mod(index - 1, cols)
                    row := (index - 1) // cols

                    x := left + (col * winWidth)
                    y := top + (row * winHeight)

                    this.Add(hwnd, x, y, winWidth, winHeight)
                }

            case "cascade":
                offset := 30
                winWidth := areaWidth * 0.7
                winHeight := areaHeight * 0.7

                for index, hwnd in windows {
                    x := left + (offset * (index - 1))
                    y := top + (offset * (index - 1))

                    this.Add(hwnd, x, y, winWidth, winHeight)
                }

            case "stack":
                for hwnd in windows {
                    this.Add(hwnd, left, top, areaWidth, areaHeight)
                }
        }

        return this.Execute()
    }
}

class DPIManager {
    __New() {
        this.SystemDPI := A_ScreenDPI
    }

    GetWindowDPI(hwnd) {
        return DllCall("GetDpiForWindow", "ptr", hwnd, "int")
    }

    GetMonitorDPI(x, y) {
        hMonitor := DllCall("MonitorFromPoint", "int", x, "int", y, "uint", 2, "ptr")
        dpiX := 0
        dpiY := 0
        DllCall("Shcore.dll\GetDpiForMonitor", "ptr", hMonitor, "int", 0, "uint*", &dpiX, "uint*", &dpiY)
        return dpiX
    }

    ScaleForDPI(value, targetDPI) {
        return Round(value * targetDPI / 96)
    }

    MoveWindowScaled(hwnd, x, y, w, h) {
        currentDPI := this.GetWindowDPI(hwnd)
        targetDPI := this.GetMonitorDPI(x, y)

        if currentDPI != targetDPI {
            ratio := targetDPI / currentDPI
            w := Round(w * ratio)
            h := Round(h * ratio)
        }

        WinMove(x, y, w, h, "ahk_id " . hwnd)
    }
}
class WindowManagerTestGUI {
    __New(app) {
        this.app := app
        this.controls := Map()
        this.targetWindow := ""
        this.alwaysOnTopTimer := ""
        this.CreateGUI()
    }

    CreateGUI() {
        this.gui := Gui("", "Window Manager Control")
        this.gui.BackColor := "0x1e1e1e"
        this.gui.SetFont("s9 cWhite", "Segoe UI")
        this.gui.MarginX := 10
        this.gui.MarginY := 10

        DllCall("uxtheme\SetWindowTheme", "ptr", this.gui.Hwnd, "str", "DarkMode_Explorer", "ptr", 0)

        this.gui.AddText("xm Section w280 Center", "🪟 WINDOW MANAGER CONTROL PANEL").SetFont("s11 Bold")
        this.gui.AddText("xm w280 h1 0x7 Background0x333333")

        this.gui.AddText("xm Section", "▸ Window Controls").SetFont("s10 Bold")

        this.controls["btnAlwaysOnTop"] := this.CreateDarkButton("xm w130 h30", "🔝 Always On Top")
        this.controls["btnAlwaysOnTop"].OnEvent("Click", (*) => this.ExecuteCommand("AlwaysOnTop"))

        this.controls["btnCenter"] := this.CreateDarkButton("x+10 w130 h30", "⊞ Center Window")
        this.controls["btnCenter"].OnEvent("Click", (*) => this.ExecuteCommand("Center"))

        this.controls["btnMinimize"] := this.CreateDarkButton("xm w130 h30", "➖ Smart Minimize")
        this.controls["btnMinimize"].OnEvent("Click", (*) => this.ExecuteCommand("Minimize"))

        this.controls["btnRestore"] := this.CreateDarkButton("x+10 w130 h30", "🔄 Restore Last")
        this.controls["btnRestore"].OnEvent("Click", (*) => this.ExecuteCommand("Restore"))

        this.controls["btnMaximize"] := this.CreateDarkButton("xm w130 h30", "⬜ Maximize/Restore")
        this.controls["btnMaximize"].OnEvent("Click", (*) => this.ExecuteCommand("Maximize"))

        this.controls["btnClose"] := this.CreateDarkButton("x+10 w130 h30", "❌ Smart Close")
        this.controls["btnClose"].OnEvent("Click", (*) => this.ExecuteCommand("Close"))

        this.gui.AddText("xm w280 h1 0x7 Background0x333333")
        this.gui.AddText("xm Section", "▸ Window Snapping").SetFont("s10 Bold")

        this.controls["btnSnapLeft"] := this.CreateDarkButton("xm w85 h30", "⬅ Left")
        this.controls["btnSnapLeft"].OnEvent("Click", (*) => this.ExecuteCommand("SnapLeft"))

        this.controls["btnSnapRight"] := this.CreateDarkButton("x+5 w85 h30", "➡ Right")
        this.controls["btnSnapRight"].OnEvent("Click", (*) => this.ExecuteCommand("SnapRight"))

        this.controls["btnDock"] := this.CreateDarkButton("x+5 w85 h30", "📌 Dock")
        this.controls["btnDock"].OnEvent("Click", (*) => this.ExecuteCommand("Dock"))

        this.controls["btnSnapLeftMulti"] := this.CreateDarkButton("xm w130 h30", "⬅🖥 Multi-Mon Left")
        this.controls["btnSnapLeftMulti"].OnEvent("Click", (*) => this.ExecuteCommand("SnapLeftMulti"))

        this.controls["btnSnapRightMulti"] := this.CreateDarkButton("x+10 w130 h30", "🖥➡ Multi-Mon Right")
        this.controls["btnSnapRightMulti"].OnEvent("Click", (*) => this.ExecuteCommand("SnapRightMulti"))

        this.gui.AddText("xm w280 h1 0x7 Background0x333333")
        this.gui.AddText("xm Section", "▸ Window Effects").SetFont("s10 Bold")

        this.controls["btnTransparency"] := this.CreateDarkButton("xm w130 h30", "👻 Toggle Transparency")
        this.controls["btnTransparency"].OnEvent("Click", (*) => this.ExecuteCommand("Transparency"))

        this.controls["btnCycle"] := this.CreateDarkButton("x+10 w130 h30", "🔄 Cycle Same App")
        this.controls["btnCycle"].OnEvent("Click", (*) => this.ExecuteCommand("CycleSame"))

        this.gui.AddText("xm w280 h1 0x7 Background0x333333")
        this.gui.AddText("xm Section", "▸ Information").SetFont("s10 Bold")

        this.controls["btnWindowInfo"] := this.CreateDarkButton("xm w130 h30", "ℹ Window Info")
        this.controls["btnWindowInfo"].OnEvent("Click", (*) => this.ExecuteCommand("WindowInfo"))

        this.controls["btnListWindows"] := this.CreateDarkButton("x+10 w130 h30", "📋 List All Windows")
        this.controls["btnListWindows"].OnEvent("Click", (*) => this.ExecuteCommand("ListWindows"))

        this.controls["btnMonitorInfo"] := this.CreateDarkButton("xm w130 h30", "🖥 Monitor Info")
        this.controls["btnMonitorInfo"].OnEvent("Click", (*) => this.ExecuteCommand("MonitorInfo"))

        this.controls["btnTestWindow"] := this.CreateDarkButton("x+10 w130 h30", "🧪 Create Test Window")
        this.controls["btnTestWindow"].OnEvent("Click", (*) => this.CreateTestWindow())

        this.gui.AddText("xm w280 h1 0x7 Background0x333333")
        this.gui.AddText("xm Section", "▸ Batch Operations").SetFont("s10 Bold")

        this.controls["btnTileWindows"] := this.CreateDarkButton("xm w85 h30", "⊞ Tile")
        this.controls["btnTileWindows"].OnEvent("Click", (*) => this.ExecuteCommand("TileWindows"))

        this.controls["btnCascadeWindows"] := this.CreateDarkButton("x+5 w85 h30", "🗂 Cascade")
        this.controls["btnCascadeWindows"].OnEvent("Click", (*) => this.ExecuteCommand("CascadeWindows"))

        this.controls["btnStackWindows"] := this.CreateDarkButton("x+5 w85 h30", "📚 Stack")
        this.controls["btnStackWindows"].OnEvent("Click", (*) => this.ExecuteCommand("StackWindows"))

        this.gui.AddText("xm w280 h1 0x7 Background0x333333")

        this.controls["statusText"] := this.gui.AddText("xm w280 Center", "Ready")
        this.controls["statusText"].SetFont("s8 Italic")

        this.gui.AddText("xm w280 Center", "Win+F12: Toggle Panel | Win+A: List All Windows").SetFont("s8")

        this.gui.OnEvent("Close", (*) => this.Hide())
        this.gui.OnEvent("Escape", (*) => this.Hide())
    }

    CreateDarkButton(options, text) {
        btn := this.gui.AddText(options . " Center 0x201 Background0x2d2d2d Border", text)
        btn.SetFont("s9 cWhite", "Segoe UI")

        btn.OnEvent("Click", this.ButtonClick.Bind(this, btn))

        return btn
    }

    ButtonClick(btn, *) {
        btn.Opt("Background0x404040")
        SetTimer(() => btn.Opt("Background0x2d2d2d"), -100)
    }

    ExecuteCommand(command) {
        this.EnsureTargetWindow()

        if !this.targetWindow {
            this.UpdateStatus("No Notepad window found")
            return
        }

        this.UpdateStatus("Executing: " . command)

        prevWindow := WinExist("A")
        WinActivate(this.targetWindow)

        switch command {
            case "AlwaysOnTop":
                this.app.Manager.ToggleAlwaysOnTop(this.targetWindow)
            case "Center":
                this.app.Manager.CenterWindow(this.targetWindow)
            case "Minimize":
                this.app.Manager.SmartMinimize(this.targetWindow)
            case "Restore":
                this.app.Manager.RestoreLast()
            case "Maximize":
                this.app.Manager.Maximize(this.targetWindow)
            case "Close":
                this.app.Manager.SmartClose(this.targetWindow)
            case "SnapLeft":
                this.app.Manager.SnapLeft()
            case "SnapRight":
                this.app.Manager.SnapRight()
            case "SnapLeftMulti":
                this.app.Manager.SnapLeftMultiMonitor()
            case "SnapRightMulti":
                this.app.Manager.SnapRightMultiMonitor()
            case "Dock":
                this.app.Manager.DockWindow(this.targetWindow)
            case "Transparency":
                this.app.Manager.ToggleTransparency(this.targetWindow)
            case "CycleSame":
                this.app.Manager.CycleSameApp()
            case "WindowInfo":
                this.ShowWindowInfo()
            case "ListWindows":
                this.ShowWindowList()
            case "MonitorInfo":
                this.ShowMonitorInfo()
            case "TestWindow":
                this.CreateTestWindow()
            case "TileWindows":
                this.ArrangeWindows("tile")
            case "CascadeWindows":
                this.ArrangeWindows("cascade")
            case "StackWindows":
                this.ArrangeWindows("stack")
        }

        if WinExist("ahk_id " prevWindow)
            WinActivate("ahk_id " prevWindow)

        SetTimer(() => this.UpdateStatus("Ready"), -2000)
    }

    EnsureTargetWindow() {
        hwnd := WinGetID("A")
        if hwnd && hwnd != this.gui.Hwnd {
            this.targetWindow := "ahk_id " . hwnd
            return true
        }

        if WinExist("ahk_exe notepad.exe") {
            this.targetWindow := "ahk_exe notepad.exe"
            return true
        }

        this.CreateTestWindow()
        return (this.targetWindow != "")
    }

    CreateTestWindow() {
        static testWindowCount := 0
        testWindowCount++

        testGui := Gui("+Resize", "Test Window " . testWindowCount)
        testGui.BackColor := Format("{:06X}", Random(0x000000, 0xFFFFFF))
        testGui.SetFont("s14", "Segoe UI")
        testGui.AddText("Center w300 h200 +0x200", "Test Window #" . testWindowCount . "`n`nUse this window to test`nWindow Manager functions")
        testGui.Show("w400 h300")

        this.targetWindow := "ahk_id " . testGui.Hwnd
        this.UpdateStatus("Created Test Window #" . testWindowCount)
    }

    ShowWindowInfo() {
        this.EnsureTargetWindow()
        if !this.targetWindow {
            this.UpdateStatus("No Notepad window")
            return
        }

        info := this.app.Manager.GetWindowInfo(this.targetWindow)
        if !info.Has("title") {
            this.UpdateStatus("Cannot get window info")
            return
        }

        infoGui := Gui("+ToolWindow", "Window Information")
        infoGui.SetFont("s9", "Consolas")

        text := "Title: " . info["title"] . "`n"
        text .= "Process: " . info["process"] . "`n"
        text .= "PID: " . info["pid"] . "`n"
        text .= "Class: " . info["class"] . "`n"
        text .= "Position: " . info["x"] . ", " . info["y"] . "`n"
        text .= "Size: " . info["width"] . " x " . info["height"] . "`n"
        text .= "DPI: " . info["dpi"] . "`n"
        text .= "Monitor: " . info["monitor"] . "`n"
        text .= "Always on Top: " . (info["alwaysOnTop"] ? "Yes" : "No") . "`n"
        text .= "Transparency: " . info["transparency"] . "%"

        infoGui.AddEdit("w400 h200 ReadOnly", text)
        infoGui.AddButton("w100", "Close").OnEvent("Click", (*) => infoGui.Destroy())
        infoGui.Show()
    }

    ShowWindowList() {
        windows := this.app.Manager.ListWindows()

        listGui := Gui("+Resize", "Active Windows")
        listGui.SetFont("s9")

        lv := listGui.AddListView("w600 h400", ["Title", "Process", "Class"])

        for win in windows {
            lv.Add("", win["title"], win["process"], win["class"])
        }

        lv.ModifyCol()

        listGui.AddButton("w100", "Close").OnEvent("Click", (*) => listGui.Destroy())
        listGui.Show()
    }

    ShowMonitorInfo() {
        monCount := MonitorGetCount()
        primary := MonitorGetPrimary()

        text := "Monitor Configuration:`n`n"
        text .= "Total Monitors: " . monCount . "`n"
        text .= "Primary Monitor: " . primary . "`n`n"

        Loop monCount {
            MonitorGet(A_Index, &left, &top, &right, &bottom)
            MonitorGetWorkArea(A_Index, &wLeft, &wTop, &wRight, &wBottom)

            text .= "Monitor " . A_Index . ":`n"
            text .= "  Position: " . left . ", " . top . "`n"
            text .= "  Size: " . (right - left) . " x " . (bottom - top) . "`n"
            text .= "  Work Area: " . (wRight - wLeft) . " x " . (wBottom - wTop) . "`n"
            text .= "  DPI: " . this.app.DPI.GetMonitorDPI(left, top) . "`n`n"
        }

        monGui := Gui("+ToolWindow", "Monitor Information")
        monGui.SetFont("s9", "Consolas")
        monGui.AddEdit("w400 h300 ReadOnly", text)
        monGui.AddButton("w100", "Close").OnEvent("Click", (*) => monGui.Destroy())
        monGui.Show()
    }

    ArrangeWindows(layout) {
        windows := []
        winList := WinGetList()

        for hwnd in winList {
            title := WinGetTitle("ahk_id " . hwnd)
            if title != "" && title != "Window Manager" && title != "Program Manager" {
                style := WinGetStyle("ahk_id " . hwnd)
                if (style & 0x10000000) {
                    windows.Push(hwnd)
                    if windows.Length >= 4
                        break
                }
            }
        }

        if windows.Length < 2 {
            this.UpdateStatus("Need at least 2 windows to arrange")
            return
        }

        this.app.Batch.ArrangeWindows(windows, layout)
        this.UpdateStatus("Arranged " . windows.Length . " windows: " . layout)
    }

    UpdateStatus(text) {
        this.controls["statusText"].Text := "► " . text
    }

    Show() {
        this.gui.Show("w300")
        WinSetAlwaysOnTop(true, "ahk_id " . this.gui.Hwnd)
        DllCall("SetWindowPos", "Ptr", this.gui.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0003)
        this.alwaysOnTopTimer := this.EnforceAlwaysOnTop.Bind(this)
        SetTimer(this.alwaysOnTopTimer, 1000)
        this.UpdateStatus("Ready")
    }

    EnforceAlwaysOnTop() {
        if WinExist("ahk_id " . this.gui.Hwnd) {
            exStyle := WinGetExStyle("ahk_id " . this.gui.Hwnd)
            if !(exStyle & 0x8) {
                WinSetAlwaysOnTop(true, "ahk_id " . this.gui.Hwnd)
                DllCall("SetWindowPos", "Ptr", this.gui.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0003)
            }
        }
    }

    Hide() {
        if this.alwaysOnTopTimer {
            SetTimer(this.alwaysOnTopTimer, 0)
            this.alwaysOnTopTimer := ""
        }
        this.gui.Hide()
    }

    Toggle() {
        if WinExist("ahk_id " . this.gui.Hwnd)
            this.Hide()
        else
            this.Show()
    }
}

class _Dark {
    static Dark := Map(
        "Background", 0x171717,
        "Controls", 0x1b1b1b,
        "Font", 0xE0E0E0,
        "Accent", 0x0078D7
    )

    static SystemData := Map(
        "Instances", Map(),
        "WindowProcOldMap", Map(),
        "WindowProcCallbacks", Map(),
        "TextBackgroundBrush", 0,
        "ControlsBackgroundBrush", 0
    )

    static ControlMaps := Map(
        "ButtonColors", Map(),
        "ComboBoxes", Map(),
        "TextControls", Map(),
        "GroupBoxes", Map(),
        "HeaderColors", Map(),
        "ControlCallbacks", Map(),
        "EditBorderData", Map(),
        "ComboBoxMonitors", Map(),
        "MonitorTimers", Map()
    )

    static Constants := Map(
        "WM_CTLCOLOREDIT", 0x0133,
        "WM_CTLCOLORLISTBOX", 0x0134,
        "WM_CTLCOLORBTN", 0x0135,
        "WM_CTLCOLORSTATIC", 0x0138,
        "WM_COMMAND", 0x0111,
        "WM_NOTIFY", 0x004E,
        "GWL_WNDPROC", -4
    )

    static GetWindowLong := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
    static SetWindowLong := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"

    static __New() {
        global _Dark_WindowProc := ObjBindMethod(_Dark, "ProcessWindowMessage")
        if !_Dark.SystemData["TextBackgroundBrush"]
            _Dark.SystemData["TextBackgroundBrush"] := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Background"], "Ptr")
        if !_Dark.SystemData["ControlsBackgroundBrush"]
            _Dark.SystemData["ControlsBackgroundBrush"] := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Controls"], "Ptr")
    }

    __New(GuiObj) {
        _Dark.__New()
        this.Gui := GuiObj
        this.Gui.BackColor := _Dark.Dark["Background"]
        this.IsDestroyed := false

        if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
            attr := 19
            if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
                attr := 20
            try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Gui.hWnd, "Int", attr, "Int*", true, "Int", 4)
            try _Dark.TryEnableAppDarkMode()
        }

        this.SetControlsTheme()
        this.SetupWindowProc()
        this.RedrawAllControls()
        _Dark.SystemData["Instances"][this.Gui.Hwnd] := this
        return this
    }

    static TryEnableAppDarkMode() {
        try {
            hUx := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
            pSetPref := DllCall("kernel32\GetProcAddress", "Ptr", hUx, "Ptr", 135, "Ptr")
            pFlush := DllCall("kernel32\GetProcAddress", "Ptr", hUx, "Ptr", 136, "Ptr")
            if (pSetPref)
                DllCall(pSetPref, "Int", 2)
            if (pFlush)
                DllCall(pFlush)
        }
    }

    SetupWindowProc() {
        hwnd := this.Gui.Hwnd
        if _Dark.SystemData["WindowProcOldMap"].Has(hwnd)
            return
        cb := CallbackCreate(_Dark_WindowProc, , 4)
        _Dark.SystemData["WindowProcCallbacks"][hwnd] := cb
        orig := DllCall(_Dark.SetWindowLong, "Ptr", hwnd, "Int", _Dark.Constants["GWL_WNDPROC"], "Ptr", cb, "Ptr")
        _Dark.SystemData["WindowProcOldMap"][hwnd] := orig
    }

    static ProcessWindowMessage(hwnd, msg, wParam, lParam, *) {
        if !_Dark.SystemData["WindowProcOldMap"].Has(hwnd)
            return DllCall("DefWindowProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")

        oldProc := _Dark.SystemData["WindowProcOldMap"][hwnd]

        switch msg {
            case _Dark.Constants["WM_COMMAND"]:
                code := (wParam >> 16) & 0xFFFF
                if (code = 7) {
                    combo := lParam
                    if _Dark.ControlMaps["ComboBoxes"].Has(combo)
                        _Dark.RefreshComboBoxTheme(combo)
                }
            case _Dark.Constants["WM_CTLCOLOREDIT"]:
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Controls"])
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
                return _Dark.SystemData["ControlsBackgroundBrush"]
            case _Dark.Constants["WM_CTLCOLORLISTBOX"]:
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Controls"])
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
                return _Dark.SystemData["ControlsBackgroundBrush"]
            case _Dark.Constants["WM_CTLCOLORBTN"]:
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Controls"])
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
                return _Dark.SystemData["ControlsBackgroundBrush"]
            case _Dark.Constants["WM_CTLCOLORSTATIC"]:
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Background"])
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
                return _Dark.SystemData["TextBackgroundBrush"]
        }
        return DllCall("CallWindowProc", "Ptr", oldProc, "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    static RegisterComboBoxForMonitoring(control) {
        if !control || !control.HasOwnProp("Hwnd")
            return false

        controlHwnd := control.Hwnd
        _Dark.ControlMaps["ComboBoxMonitors"][controlHwnd] := control

        monitorCallback := _Dark.MonitorComboBoxDropdown.Bind(controlHwnd)
        _Dark.ControlMaps["MonitorTimers"][controlHwnd] := monitorCallback
        SetTimer(monitorCallback, 50)

        control.OnEvent("Focus", (*) => _Dark.RefreshComboTheme(control))
        return true
    }

    static UnregisterComboBoxMonitoring(controlHwnd) {
        if _Dark.ControlMaps["MonitorTimers"].Has(controlHwnd) {
            SetTimer(_Dark.ControlMaps["MonitorTimers"][controlHwnd], 0)
            _Dark.ControlMaps["MonitorTimers"].Delete(controlHwnd)
        }
        if _Dark.ControlMaps["ComboBoxMonitors"].Has(controlHwnd) {
            _Dark.ControlMaps["ComboBoxMonitors"].Delete(controlHwnd)
        }
    }

    static RefreshComboTheme(control) {
        if !_Dark.ValidateControl(control)
            return

        SetTimer(_Dark.DelayedComboThemeRefresh.Bind(control), -10)
    }

    static DelayedComboThemeRefresh(control) {
        if !_Dark.ValidateControl(control)
            return

        static CB_GETCOMBOBOXINFO := 0x164

        try {
            comboInfo := Buffer(60, 0)
            NumPut("UInt", 60, comboInfo, 0)
            controlHwnd := control.hWnd

            if !controlHwnd || controlHwnd = ""
                return

            if DllCall("user32\GetComboBoxInfo", "Ptr", controlHwnd, "Ptr", comboInfo) {
                editHwnd := NumGet(comboInfo, A_PtrSize + 4, "Ptr")
                listHwnd := NumGet(comboInfo, A_PtrSize + 8, "Ptr")
                buttonHwnd := NumGet(comboInfo, A_PtrSize + 12, "Ptr")

                if editHwnd {
                    DllCall("uxtheme\SetWindowTheme", "Ptr", editHwnd, "Str", "DarkMode_CFD", "Ptr", 0)
                }

                if buttonHwnd {
                    DllCall("uxtheme\SetWindowTheme", "Ptr", buttonHwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                }

                if listHwnd {
                    _Dark.ControlMaps["ComboBoxes"][listHwnd] := true
                    DllCall("uxtheme\SetWindowTheme", "Ptr", listHwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    DllCall("InvalidateRect", "Ptr", listHwnd, "Ptr", 0, "Int", true)
                }
            }
        } catch {
            return
        }
    }

    static MonitorComboBoxDropdown(controlHwnd) {
        if !_Dark.ControlMaps["ComboBoxMonitors"].Has(controlHwnd)
            return

        control := _Dark.ControlMaps["ComboBoxMonitors"][controlHwnd]
        if !_Dark.ValidateControl(control)
            return

        static CB_GETCOMBOBOXINFO := 0x164
        static CB_GETDROPPEDSTATE := 0x0157

        try {
            if !controlHwnd || controlHwnd = ""
                return

            isDropped := DllCall("user32\SendMessage", "Ptr", controlHwnd, "UInt", CB_GETDROPPEDSTATE, "Ptr", 0, "Ptr", 0)

            if isDropped {
                comboInfo := Buffer(60, 0)
                NumPut("UInt", 60, comboInfo, 0)
                if DllCall("user32\GetComboBoxInfo", "Ptr", controlHwnd, "Ptr", comboInfo) {
                    listHwnd := NumGet(comboInfo, A_PtrSize + 8, "Ptr")
                    if listHwnd && !_Dark.ControlMaps["ComboBoxes"].Has(listHwnd) {
                        _Dark.ControlMaps["ComboBoxes"][listHwnd] := true
                        DllCall("uxtheme\SetWindowTheme", "Ptr", listHwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                        DllCall("InvalidateRect", "Ptr", listHwnd, "Ptr", 0, "Int", true)
                    }
                }
            }
        } catch {
            return
        }
    }

    static ValidateControl(control) {
        if !control
            return false

        try {
            hwnd := control.hWnd
            return hwnd && hwnd != ""
        } catch {
            return false
        }
    }

    static ColorEditBorder(control, color) {
        static WM_NCPAINT := 0x0085

        if _Dark.ControlMaps["EditBorderData"].Has(control.Hwnd)
            return control

        prevProc := DllCall("GetWindowLongPtr", "Ptr", control.Hwnd, "Int", -4, "Ptr")
        if !prevProc
            return control

        borderData := Map(
            "color", color,
            "prevProc", prevProc
        )
        _Dark.ControlMaps["EditBorderData"][control.Hwnd] := borderData

        EditProc(hwnd, uMsg, wParam, lParam) {
            if !_Dark.ControlMaps["EditBorderData"].Has(hwnd)
                return DllCall("DefWindowProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")

            if (uMsg = WM_NCPAINT) {
                hdc := DllCall("GetWindowDC", "Ptr", hwnd, "Ptr")
                if (hdc) {
                    rect := Buffer(16, 0)
                    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect)
                    w := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")
                    h := NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")

                    data := _Dark.ControlMaps["EditBorderData"][hwnd]
                    pen := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", data["color"], "Ptr")
                    old := DllCall("SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")

                    DllCall("MoveToEx", "Ptr", hdc, "Int", 0, "Int", 0, "Ptr", 0)
                    DllCall("LineTo", "Ptr", hdc, "Int", w - 1, "Int", 0)
                    DllCall("LineTo", "Ptr", hdc, "Int", w - 1, "Int", h - 1)
                    DllCall("LineTo", "Ptr", hdc, "Int", 0, "Int", h - 1)
                    DllCall("LineTo", "Ptr", hdc, "Int", 0, "Int", 0)

                    DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
                    DllCall("DeleteObject", "Ptr", pen)
                    DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
                    return 0
                }
            }

            data := _Dark.ControlMaps["EditBorderData"][hwnd]
            return DllCall("CallWindowProc", "Ptr", data["prevProc"], "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
        }

        cb := CallbackCreate(EditProc, , 4)
        if cb {
            if DllCall("SetWindowLongPtr", "Ptr", control.Hwnd, "Int", -4, "Ptr", cb, "Ptr") {
                borderData["callback"] := cb
                DllCall("SendMessage", "Ptr", control.Hwnd, "UInt", WM_NCPAINT, "Ptr", 1, "Ptr", 0)
            } else {
                CallbackFree(cb)
                _Dark.ControlMaps["EditBorderData"].Delete(control.Hwnd)
            }
        }
        return control
    }

    AddListView(opts, headers) {
        lv := this.Gui.Add("ListView", opts, headers)

        static ListViewConstants := Map(
            "LVM_SETBKCOLOR", 0x1001,
            "LVM_SETTEXTCOLOR", 0x1033,
            "LVM_SETTEXTBKCOLOR", 0x1026,
            "LVM_SETOUTLINECOLOR", 0x10B1,
            "LVM_SETEXTENDEDLISTVIEWSTYLE", 0x1036,
            "LVS_EX_DOUBLEBUFFER", 0x10000,
            "LVS_EX_GRIDLINES", 0x0001,
            "LVS_EX_FULLROWSELECT", 0x00000020,
            "WM_CHANGEUISTATE", 0x0127,
            "UIS_SET", 1,
            "UISF_HIDEFOCUS", 0x1,
            "LVM_GETHEADER", 0x101F
        )

        bg := _Dark.Dark["Background"]
        fg := 0xFFFFFF
        grid := 0x202020

        _Dark.SendMessage(ListViewConstants["LVM_SETBKCOLOR"], 0, bg, lv.Hwnd)
        _Dark.SendMessage(ListViewConstants["LVM_SETTEXTCOLOR"], 0, fg, lv.Hwnd)
        _Dark.SendMessage(ListViewConstants["LVM_SETTEXTBKCOLOR"], 0, bg, lv.Hwnd)
        _Dark.SendMessage(ListViewConstants["LVM_SETEXTENDEDLISTVIEWSTYLE"],
            ListViewConstants["LVS_EX_DOUBLEBUFFER"] | ListViewConstants["LVS_EX_GRIDLINES"] | ListViewConstants["LVS_EX_FULLROWSELECT"],
            ListViewConstants["LVS_EX_DOUBLEBUFFER"] | ListViewConstants["LVS_EX_GRIDLINES"] | ListViewConstants["LVS_EX_FULLROWSELECT"], lv.Hwnd)
        _Dark.SendMessage(ListViewConstants["LVM_SETOUTLINECOLOR"], 0, grid, lv.Hwnd)

        DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        lv.SetFont("cFFFFFF")

        headerHwnd := _Dark.SendMessage(ListViewConstants["LVM_GETHEADER"], 0, 0, lv.Hwnd)
        if headerHwnd {
            DllCall("uxtheme\SetWindowTheme", "Ptr", headerHwnd, "Str", "", "Ptr", 0)

            static HDM_LAYOUT := 0x1205
            _Dark.SendMessage(HDM_LAYOUT, 0, 0, headerHwnd)
        }

        _Dark.SetListViewHeaderColors(lv, 0x1b1b1b, 0xFFFFFF)
        _Dark.SendMessage(ListViewConstants["WM_CHANGEUISTATE"],
            (ListViewConstants["UIS_SET"] << 8) | ListViewConstants["UISF_HIDEFOCUS"], 0, lv.Hwnd)

        DllCall("InvalidateRect", "Ptr", lv.Hwnd, "Ptr", 0, "Int", true)
        if headerHwnd {
            DllCall("InvalidateRect", "Ptr", headerHwnd, "Ptr", 0, "Int", true)
            DllCall("UpdateWindow", "Ptr", headerHwnd)
        }
        return lv
    }

    static SetListViewHeaderColors(ListViewCtrl, BackgroundColor?, TextColor?) {
        HHDR := _Dark.SendMessage(0x101F, 0, 0, ListViewCtrl.Hwnd)
        if !(IsSet(BackgroundColor) || IsSet(TextColor)) && (_Dark.ControlMaps["HeaderColors"].Has(HHDR)) {
            return (_Dark.ControlMaps["HeaderColors"].Delete(HHDR), DllCall("RedrawWindow", "Ptr", ListViewCtrl.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0001))
        } else if (IsSet(BackgroundColor) && IsSet(TextColor)) {
            if !(_Dark.ControlMaps["HeaderColors"].Has(HHDR)) {
                _Dark.SubclassControl(ListViewCtrl, _DarkHeaderCustomDrawCallback)
            }
            BackgroundColor := _Dark.RGBtoBGR(BackgroundColor)
            TextColor := TextColor = 0xFFFFFF ? 0xFFFFFF : _Dark.RGBtoBGR(TextColor)
            _Dark.ControlMaps["HeaderColors"][HHDR] := Map("Txt", TextColor, "Bkg", BackgroundColor)
        }
        DllCall("RedrawWindow", "Ptr", ListViewCtrl.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0001)
    }

    static SubclassControl(ctrl, func6, data := 0) {
        hwnd := HasProp(ctrl, "Hwnd") ? ctrl.Hwnd : ctrl

        if _Dark.ControlMaps["ControlCallbacks"].Has(hwnd) {
            DllCall("RemoveWindowSubclass", "Ptr", hwnd, "Ptr", _Dark.ControlMaps["ControlCallbacks"][hwnd], "Ptr", hwnd)
            CallbackFree(_Dark.ControlMaps["ControlCallbacks"][hwnd])
            _Dark.ControlMaps["ControlCallbacks"].Delete(hwnd)
        }
        if !(func6 is Func && func6.MaxParams = 6)
            return false
        cb := CallbackCreate(func6, "F", 6)
        if !cb
            return false
        if !DllCall("SetWindowSubclass", "Ptr", hwnd, "Ptr", cb, "Ptr", hwnd, "Ptr", data) {
            CallbackFree(cb)
            return false
        }
        _Dark.ControlMaps["ControlCallbacks"][hwnd] := cb
        return true
    }

    static SendMessage(msg, wParam, lParam, hwndOrCtrl) {
        hwnd := HasProp(hwndOrCtrl, "Hwnd") ? hwndOrCtrl.Hwnd : hwndOrCtrl
        return DllCall("user32\SendMessage", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    static RGBtoBGR(rgb) {
        if (!IsNumber(rgb))
            rgb := Integer("0x" . rgb)
        if (rgb = 0xFFFFFF)
            return 0xFFFFFF
        return ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb & 0xFF0000) >> 16)
    }

    static RefreshComboBoxTheme(comboHwnd) {
        static CB_GETCOMBOBOXINFO := 0x164
        info := Buffer(60, 0)
        NumPut("UInt", 60, info, 0)
        if DllCall("user32\GetComboBoxInfo", "Ptr", comboHwnd, "Ptr", info) {
            listH := NumGet(info, A_PtrSize + 8, "Ptr")
            if listH {
                _Dark.ControlMaps["ComboBoxes"][listH] := true
                DllCall("uxtheme\SetWindowTheme", "Ptr", listH, "Str", "DarkMode_Explorer", "Ptr", 0)
                DllCall("InvalidateRect", "Ptr", listH, "Ptr", 0, "Int", true)
            }
        }
    }

    SetControlsTheme() {
        for _, c in this.Gui {
            switch c.Type {
                case "Edit":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", c.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    c.SetFont("cFFFFFF")
                case "ComboBox", "DDL":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", c.Hwnd, "Str", "DarkMode_CFD", "Ptr", 0)
                    _Dark.ControlMaps["ComboBoxes"][c.Hwnd] := true
                    c.SetFont("cFFFFFF")
                    _Dark.RegisterComboBoxForMonitoring(c)
                case "Button", "CheckBox", "Radio", "DateTime", "Tab3", "TreeView", "ListBox", "UpDown", "GroupBox":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", c.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                    c.SetFont("cFFFFFF")
                case "Text", "Link":
                    c.Opt("cFFFFFF")
            }
            DllCall("InvalidateRect", "Ptr", c.Hwnd, "Ptr", 0, "Int", true)
        }
    }

    RedrawAllControls() {
        DllCall("RedrawWindow", "Ptr", this.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0285)
        for _, c in this.Gui {
            DllCall("InvalidateRect", "Ptr", c.Hwnd, "Ptr", 0, "Int", true)
        }
    }

    Destroy() {
        this.IsDestroyed := true

        for controlHwnd in _Dark.ControlMaps["ComboBoxMonitors"].Clone() {
            _Dark.UnregisterComboBoxMonitoring(controlHwnd)
        }

        Sleep(20)
        if _Dark.SystemData["Instances"].Has(this.Gui.Hwnd) {
            _Dark.SystemData["Instances"].Delete(this.Gui.Hwnd)
        }
    }
}
_DarkHeaderCustomDrawCallback(hWnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) {
    static HDM_GETITEM := 0x120B
    static NM_CUSTOMDRAW := -12
    static CDRF_DODEFAULT := 0x00000000
    static CDRF_SKIPDEFAULT := 0x00000004
    static CDRF_NOTIFYITEMDRAW := 0x00000020
    static CDDS_PREPAINT := 0x00000001
    static CDDS_ITEMPREPAINT := 0x00010001
    static DC_BRUSH := 18
    static OHWND := 0
    static OMsg := (2 * A_PtrSize)
    static ODrawStage := OMsg + A_PtrSize
    static OHDC := ODrawStage + A_PtrSize
    static ORect := OHDC + A_PtrSize
    static OItemSpec := OHDC + 16 + A_PtrSize
    static LM := 4
    static TM := 6
    static TRANSPARENT := 1

    if (uMsg = 0x4E) {
        HWND := NumGet(lParam + OHWND, "UPtr")
        if _Dark.ControlMaps["HeaderColors"].Has(HWND) && HC := _Dark.ControlMaps["HeaderColors"][HWND] {
            Code := NumGet(lParam + OMsg, "Int")
            if (Code = NM_CUSTOMDRAW) {
                DrawStage := NumGet(lParam + ODrawStage, "UInt")
                if (DrawStage = CDDS_ITEMPREPAINT) {
                    Item := NumGet(lParam + OItemSpec, "Ptr")
                    HDITEM := Buffer(24 + (6 * A_PtrSize), 0)
                    ItemTxt := Buffer(520, 0)
                    NumPut("UInt", 0x86, HDITEM, 0)
                    NumPut("ptr", ItemTxt.Ptr, HDITEM, 8)
                    NumPut("int", 260, HDITEM, 8 + (2 * A_PtrSize))
                    DllCall("SendMessage", "Ptr", HWND, "UInt", HDM_GETITEM, "Ptr", Item, "Ptr", HDITEM)
                    Fmt := NumGet(HDITEM, 12 + (2 * A_PtrSize), "UInt") & 3
                    Order := NumGet(HDITEM, 20 + (3 * A_PtrSize), "Int")
                    HDC := NumGet(lParam + OHDC, "Ptr")
                    if (Item = 0) && (Order = 0)
                        NumPut("Int", NumGet(lParam, ORect, "Int") + LM, lParam + ORect)
                    dcBrush := DllCall("GetStockObject", "UInt", DC_BRUSH, "ptr")
                    DllCall("SetDCBrushColor", "Ptr", HDC, "UInt", HC["Bkg"])
                    DllCall("FillRect", "Ptr", HDC, "Ptr", lParam + ORect, "Ptr", dcBrush)
                    if (Item = 0) && (Order = 0)
                        NumPut("Int", NumGet(lParam, ORect, "Int") - LM, lParam, ORect)
                    DllCall("SetBkMode", "Ptr", HDC, "UInt", TRANSPARENT)
                    DllCall("SetTextColor", "Ptr", HDC, "UInt", 0xFFFFFF)
                    DllCall("InflateRect", "Ptr", lParam + ORect, "Int", -TM, "Int", 0)
                    DT_ALIGN := 0x0224 + ((Fmt & 1) ? 2 : (Fmt & 2) ? 1 : 0)
                    DllCall("DrawText", "Ptr", HDC, "Ptr", ItemTxt, "Int", -1, "Ptr", lParam + ORect, "UInt", DT_ALIGN)
                    return CDRF_SKIPDEFAULT
                }
                return (DrawStage = CDDS_PREPAINT) ? CDRF_NOTIFYITEMDRAW : CDRF_DODEFAULT
            }
        }
    } else if (uMsg = 0x02) {
        if _Dark.ControlMaps["ControlCallbacks"].Has(hWnd) {
            callback := _Dark.ControlMaps["ControlCallbacks"][hWnd]
            DllCall("RemoveWindowSubclass", "Ptr", hWnd, "Ptr", callback, "Ptr", hWnd)
            CallbackFree(callback)
            _Dark.ControlMaps["ControlCallbacks"].Delete(hWnd)
        }
    }
    return DllCall("DefSubclassProc", "Ptr", hWnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}
