#Requires AutoHotkey v2.1-alpha.17 64-bit
#SingleInstance Force

#Include ..\Lib\cJson.ahk
#Include ..\Lib\DarkListView.ahk

if !Gui.ListView.Prototype.HasMethod("SetDarkMode") {
    _DarkListView.__New()
}

Lg()

class Lg {
    static PADDING := 10
    static LABEL_WIDTH := 80
    static INPUT_WIDTH := 460
    static INPUT_HEIGHT := 24
    static TEXTAREA_HEIGHT := 100
    static CODE_HEIGHT := 200
    static BUTTON_WIDTH := 130
    static BUTTON_HEIGHT := 30

    __New() {
        this.logFile := A_ScriptDir "\Lib\test_log.json"
        this.entries := []

        this.LoadData()
        this.InitGui()
        this.RefreshList()
        this.gui.Show()
    }

    InitGui() {
        this.gui := Gui("+Resize", "LLM Test Logger")
        this.gui.SetFont("s10")
        this.gui.BackColor := 0x1E1E1E

        DarkTheme.Apply(this.gui)

        this.CreateFormControls()
        this.CreateListView()
        this.CreateButtons()

        this.gui.OnEvent("Close", (*) => ExitApp())
    }

    CreateFormControls() {
        this.gui.AddText(
            GuiFormat(
                Lg.PADDING,
                Lg.PADDING,
                Lg.LABEL_WIDTH,
                Lg.INPUT_HEIGHT,
                "cFFFFFF"
            ),
            "Company:"
        )

        this.editCompany := DarkTheme.AddDarkEdit(
            this.gui,
            GuiFormat(
                Lg.PADDING + Lg.LABEL_WIDTH + Lg.PADDING,
                Lg.PADDING,
                Lg.INPUT_WIDTH,
                Lg.INPUT_HEIGHT
            )
        )

        this.gui.AddText(
            GuiFormat(
                Lg.PADDING,
                Lg.PADDING * 2 + Lg.INPUT_HEIGHT,
                Lg.LABEL_WIDTH,
                Lg.INPUT_HEIGHT,
                "cFFFFFF"
            ),
            "Model:"
        )

        this.editModel := DarkTheme.AddDarkEdit(
            this.gui,
            GuiFormat(
                Lg.PADDING + Lg.LABEL_WIDTH + Lg.PADDING,
                Lg.PADDING * 2 + Lg.INPUT_HEIGHT,
                Lg.INPUT_WIDTH,
                Lg.INPUT_HEIGHT
            )
        )

        this.gui.AddText(
            GuiFormat(
                Lg.PADDING,
                Lg.PADDING * 3 + Lg.INPUT_HEIGHT * 2,
                Lg.LABEL_WIDTH,
                Lg.INPUT_HEIGHT,
                "cFFFFFF"
            ),
            "Prompt:"
        )

        this.editPrompt := DarkTheme.AddDarkEdit(
            this.gui,
            GuiFormat(
                Lg.PADDING + Lg.LABEL_WIDTH + Lg.PADDING,
                Lg.PADDING * 3 + Lg.INPUT_HEIGHT * 2,
                Lg.INPUT_WIDTH,
                Lg.TEXTAREA_HEIGHT,
                "Multi VScroll"
            )
        )

        this.gui.AddText(
            GuiFormat(
                Lg.PADDING,
                Lg.PADDING * 4 + Lg.INPUT_HEIGHT * 2 + Lg.TEXTAREA_HEIGHT,
                Lg.LABEL_WIDTH,
                Lg.INPUT_HEIGHT,
                "cFFFFFF"
            ),
            "CODE:"
        )

        this.editCode := DarkTheme.AddDarkEdit(
            this.gui,
            GuiFormat(
                Lg.PADDING + Lg.LABEL_WIDTH + Lg.PADDING,
                Lg.PADDING * 4 + Lg.INPUT_HEIGHT * 2 + Lg.TEXTAREA_HEIGHT,
                Lg.INPUT_WIDTH,
                Lg.CODE_HEIGHT,
                "Multi VScroll"
            )
        )

        this.gui.AddText(
            GuiFormat(
                Lg.PADDING,
                Lg.PADDING * 5 + Lg.INPUT_HEIGHT * 2 + Lg.TEXTAREA_HEIGHT + Lg.CODE_HEIGHT,
                Lg.LABEL_WIDTH,
                Lg.INPUT_HEIGHT,
                "cFFFFFF"
            ),
            "Errors:"
        )

        this.editErrors := DarkTheme.AddDarkEdit(
            this.gui,
            GuiFormat(
                Lg.PADDING + Lg.LABEL_WIDTH + Lg.PADDING,
                Lg.PADDING * 5 + Lg.INPUT_HEIGHT * 2 + Lg.TEXTAREA_HEIGHT + Lg.CODE_HEIGHT,
                Lg.INPUT_WIDTH,
                Lg.TEXTAREA_HEIGHT,
                "Multi VScroll"
            )
        )
    }

    CreateListView() {
        static LVM_SETTEXTCOLOR := 0x1024
        static LVM_SETTEXTBKCOLOR := 0x1026
        static LVM_SETBKCOLOR := 0x1001

        formBottom := Lg.PADDING * 6 + Lg.INPUT_HEIGHT * 2 + Lg.TEXTAREA_HEIGHT * 2 + Lg.CODE_HEIGHT

        this.listView := this.gui.AddListView(
            GuiFormat(
                Lg.PADDING,
                formBottom + Lg.PADDING,
                Lg.LABEL_WIDTH + Lg.PADDING + Lg.INPUT_WIDTH,
                200,
                "Grid cWhite"
            ),
            ["Company", "Model", "Timestamp"]
        )

        this.listView.Opt("-Redraw")

        SendMessage(LVM_SETTEXTCOLOR, 0, 0xFFFFFF, this.listView.Hwnd)
        SendMessage(LVM_SETTEXTBKCOLOR, 0, 0x202020, this.listView.Hwnd)
        SendMessage(LVM_SETBKCOLOR, 0, 0x202020, this.listView.Hwnd)

        this.listView.Opt("+Redraw")
        this.listView.SetDarkMode()
        
        this.listView.ModifyCol(1, 250)
        this.listView.ModifyCol(2, 250)
        this.listView.ModifyCol(3, 270)
    }

    CreateButtons() {
        formBottom := Lg.PADDING * 6 + Lg.INPUT_HEIGHT * 2 + Lg.TEXTAREA_HEIGHT * 2 + Lg.CODE_HEIGHT
        listViewBottom := formBottom + Lg.PADDING + 200
        buttonY := listViewBottom + Lg.PADDING

        this.btnSave := this.gui.AddButton(
            GuiFormat(
                Lg.PADDING,
                buttonY,
                Lg.BUTTON_WIDTH,
                Lg.BUTTON_HEIGHT,
                "Background303030 cFFFFFF"
            ),
            "Save Entry"
        )
        this.btnSave.OnEvent("Click", this.SaveEntry.Bind(this))
        ApplyDarkModeToButton(this.btnSave)

        this.btnLoad := this.gui.AddButton(
            GuiFormat(
                Lg.PADDING * 2 + Lg.BUTTON_WIDTH,
                buttonY,
                Lg.BUTTON_WIDTH,
                Lg.BUTTON_HEIGHT,
                "Background303030 cFFFFFF"
            ),
            "Load Entry"
        )
        this.btnLoad.OnEvent("Click", this.LoadEntry.Bind(this))
        ApplyDarkModeToButton(this.btnLoad)

        this.btnDelete := this.gui.AddButton(
            GuiFormat(
                Lg.PADDING * 3 + Lg.BUTTON_WIDTH * 2,
                buttonY,
                Lg.BUTTON_WIDTH,
                Lg.BUTTON_HEIGHT,
                "Background303030 cFFFFFF"
            ),
            "Delete Entry"
        )
        this.btnDelete.OnEvent("Click", this.DeleteEntry.Bind(this))
        ApplyDarkModeToButton(this.btnDelete)

        this.btnClear := this.gui.AddButton(
            GuiFormat(
                Lg.PADDING * 4 + Lg.BUTTON_WIDTH * 3,
                buttonY,
                Lg.BUTTON_WIDTH,
                Lg.BUTTON_HEIGHT,
                "Background303030 cFFFFFF"
            ),
            "Clear Form"
        )
        this.btnClear.OnEvent("Click", this.ClearForm.Bind(this))
        ApplyDarkModeToButton(this.btnClear)
    }

    LoadData() {
        if FileExist(this.logFile) {
            try {
                jsonText := FileRead(this.logFile)
                if (jsonText = "" || RegExMatch(jsonText, "^\s*$")) {
                    this.entries := []
                    return
                }

                this.entries := JSON.Load(jsonText)

                if (!IsObject(this.entries) || !HasMethod(this.entries, "Push")) {
                    this.entries := []
                }
            } catch Error as err {
                MsgBox("Error loading data: " err.Message, "Error", "Icon!")
                this.entries := []
            }
        } else {
            try {
                FileAppend("[]", this.logFile)
                this.entries := []
            } catch Error as err {
                MsgBox("Error creating log file: " err.Message, "Error", "Icon!")
                this.entries := []
            }
        }
    }

    SaveData() {
        try {
            if (!IsObject(this.entries) || !HasMethod(this.entries, "Push")) {
                this.entries := []
            }

            jsonText := JSON.Dump(this.entries, 1)

            FileDelete(this.logFile)
            FileAppend(jsonText, this.logFile)
        } catch Error as err {
            MsgBox("Error saving data: " err.Message, "Error", "Icon!")
        }
    }

    RefreshList() {
        this.listView.Delete()

        for entry in this.entries {
            this.listView.Add(, entry.Company, entry.Model, entry.Timestamp)
        }
    }

    SaveEntry(*) {
        company := this.editCompany.Value
        model := this.editModel.Value
        prompt := this.editPrompt.Value
        code := this.editCode.Value
        errors := this.editErrors.Value

        if (company = "" || model = "") {
            MsgBox("Company and Model are required.", "Validation Error", "Icon!")
            return
        }

        formatted := Format("{1:yyyy-MM-dd HH:mm:ss}", A_Now)
        entry := Map(
            "Company", company,
            "Model", model,
            "Prompt", prompt,
            "Code", code,
            "Errors", errors,
            "Timestamp", formatted
        )

        this.entries.Push(entry)

        this.SaveData()
        this.RefreshList()
        this.ClearForm()
    }

    LoadEntry(*) {
        row := this.listView.GetNext()
        if (!row) {
            MsgBox("Please select an entry to load.", "Information", "Icon!")
            return
        }

        timestamp := this.listView.GetText(row, 3)
        for entry in this.entries {
            if (entry.Timestamp = timestamp) {
                this.editCompany.Value := entry.Company
                this.editModel.Value := entry.Model
                this.editPrompt.Value := entry.Prompt

                this.editCode.Value := entry.HasOwnProp("Code") ? entry.Code : ""

                this.editErrors.Value := entry.Errors
                return
            }
        }
    }

    DeleteEntry(*) {
        row := this.listView.GetNext()
        if (!row) {
            MsgBox("Please select an entry to delete.", "Information", "Icon!")
            return
        }

        timestamp := this.listView.GetText(row, 3)
        for index, entry in this.entries {
            if (entry.Timestamp = timestamp) {
                this.entries.RemoveAt(index)
                break
            }
        }

        this.SaveData()
        this.RefreshList()
        this.ClearForm()
    }

    ClearForm(*) {
        this.editCompany.Value := ""
        this.editModel.Value := ""
        this.editPrompt.Value := ""
        this.editCode.Value := ""
        this.editErrors.Value := ""
    }
}

class DarkTheme {
    static Colors := Map(
        "Background", 0x202020,
        "Controls", 0x303030,
        "Font", 0xFFFFFF
    )

    static WM_CTLCOLOREDIT := 0x0133
    static WM_CTLCOLORLISTBOX := 0x0134
    static WM_CTLCOLORBTN := 0x0135
    static WM_CTLCOLORSTATIC := 0x0138
    static DC_BRUSH := 18

    static GWL_WNDPROC := -4
    static GWL_STYLE := -16
    static ES_MULTILINE := 0x0004

    static LVM_GETTEXTCOLOR := 0x1023
    static LVM_SETTEXTCOLOR := 0x1024
    static LVM_GETTEXTBKCOLOR := 0x1025
    static LVM_SETTEXTBKCOLOR := 0x1026
    static LVM_GETBKCOLOR := 0x1000
    static LVM_SETBKCOLOR := 0x1001
    static LVM_GETHEADER := 0x101F

    static AddDarkEdit(gui, Options, Text := "") {
        edit := gui.AddEdit(Options, Text)
        DllCall("uxtheme\SetWindowTheme", "Ptr", edit.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        edit.SetFont("cFFFFFF")
        DllCall("InvalidateRect", "Ptr", edit.hWnd, "Ptr", 0, "Int", true)
        return edit
    }

    static Apply(gui) {
        static textBgBrush := 0, controlsBrush := 0, procNew := 0, procOld := 0, guiHwnd := 0

        if (!textBgBrush) {
            textBgBrush := DllCall("gdi32\CreateSolidBrush", "UInt", DarkTheme.Colors["Background"], "Ptr")
            controlsBrush := DllCall("gdi32\CreateSolidBrush", "UInt", DarkTheme.Colors["Controls"], "Ptr")

            if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
                DWMWA_USE_IMMERSIVE_DARK_MODE := 19
                if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
                    DWMWA_USE_IMMERSIVE_DARK_MODE := 20

                uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
                SetPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
                FlushMenuThemes := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")

                DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", gui.hWnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", true, "Int", 4)
                DllCall(SetPreferredAppMode, "Int", 2)
                DllCall(FlushMenuThemes)
            }

            gui.BackColor := DarkTheme.Colors["Background"]
            guiHwnd := gui.hWnd

            for hWnd, GuiCtrlObj in gui {
                if (GuiCtrlObj.Type != "ListView")
                    DarkTheme.ThemeControl(GuiCtrlObj)
            }

            WinProc := DarkTheme_WindowProc
            procNew := CallbackCreate(WinProc)
            procOld := DllCall("user32\" (A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"),
                "Ptr", gui.Hwnd, "Int", DarkTheme.GWL_WNDPROC, "Ptr", procNew, "Ptr")
        }

        DarkTheme_WindowProc(hwnd, uMsg, wParam, lParam) {
            if (hwnd = guiHwnd) {
                switch uMsg {
                    case DarkTheme.WM_CTLCOLOREDIT, DarkTheme.WM_CTLCOLORLISTBOX:
                        DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Font"])
                        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Controls"])
                        DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Controls"], "UInt")
                        return controlsBrush

                    case DarkTheme.WM_CTLCOLORBTN:
                        DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Font"])
                        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Controls"])
                        DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Controls"], "UInt")
                        return controlsBrush

                    case DarkTheme.WM_CTLCOLORSTATIC:
                        DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Font"])
                        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.Colors["Background"])
                        return textBgBrush
                }
            }

            return DllCall("user32\CallWindowProc", "Ptr", procOld, "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam)
        }
    }

    static ThemeControl(ctrl) {
        explorerMode := "DarkMode_Explorer"
        cfdMode := "DarkMode_CFD"
        itemsViewMode := "DarkMode_ItemsView"

        switch ctrl.Type {
            case "Button", "CheckBox", "ListBox", "UpDown":
                DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", explorerMode, "Ptr", 0)

            case "ComboBox", "DDL":
                DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", cfdMode, "Ptr", 0)

            case "Edit":
                isMultiLine := DllCall("user32\" (A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"),
                    "Ptr", ctrl.hWnd, "Int", DarkTheme.GWL_STYLE) & DarkTheme.ES_MULTILINE

                themeMode := isMultiLine ? explorerMode : cfdMode
                DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.hWnd, "Str", themeMode, "Ptr", 0)
        }
    }
}

GuiFormat(x, y, w, h, extraParams := "") {
    return GuiFormatBuilder().Position(x, y).Size(w, h).ExtraParams(extraParams).Build()
}

GuiFormatBuilder()
class GuiFormatBuilder {
    _x := 0
    _y := 0
    _w := 0
    _h := 0
    _extraParams := ""

    Position(x, y) {
        this._x := x
        this._y := y
        return this
    }

    Size(w, h) {
        this._w := w
        this._h := h
        return this
    }

    ExtraParams(value) {
        this._extraParams := value
        return this
    }

    Build() {
        params := Format("x{} y{} w{} h{}", this._x, this._y, this._w, this._h)
        if this._extraParams
            params .= " " this._extraParams
        return params
    }
}


ApplyDarkModeToButton(button) {
    DllCall("uxtheme\SetWindowTheme", "Ptr", button.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
    button.Opt("Background303030 cFFFFFF")
    return button
}