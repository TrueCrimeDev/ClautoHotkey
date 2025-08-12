#requires AutoHotkey v2.1-alpha.10

class RECT {
    left: i32, top: i32, right: i32, bottom: i32
}

class NMHDR {
    hwndFrom: uptr
    idFrom  : uptr
    code    : i32
}

class NMCUSTOMDRAW {
    hdr        : NMHDR
    dwDrawStage: u32
    hdc        : uptr
    rc         : RECT
    dwItemSpec : uptr
    uItemState : u32
    lItemlParam: iptr
}

class _DarkListView extends Gui.ListView
{
    static __New()
    {
        static LVM_GETHEADER := 0x101F

        super.Prototype.GetHeader   := SendMessage.Bind(LVM_GETHEADER, 0, 0)
        super.Prototype.SetDarkMode := this.SetDarkMode.Bind(this)
    }
    
    static SetDarkMode(lv, style := "Explorer")
    {
        static LVS_EX_DOUBLEBUFFER := 0x10000
        static NM_CUSTOMDRAW       := -12
        static UIS_SET             := 1
        static UISF_HIDEFOCUS      := 0x1
        static WM_CHANGEUISTATE    := 0x0127
        static WM_NOTIFY           := 0x4E
        static WM_THEMECHANGED     := 0x031A

        lv.Header := lv.GetHeader()
		
        lv.OnMessage(WM_THEMECHANGED, (*) => 0)
        
		lv.OnMessage(WM_NOTIFY, (lv, wParam, lParam, Msg) {
            static CDDS_ITEMPREPAINT   := 0x10001
            static CDDS_PREPAINT       := 0x1
            static CDRF_DODEFAULT      := 0x0
            static CDRF_NOTIFYITEMDRAW := 0x20
    
			if (StructFromPtr(NMHDR, lParam).Code != NM_CUSTOMDRAW) 
				return 

			nmcd := StructFromPtr(NMCUSTOMDRAW, lParam)
            
            if (nmcd.hdr.hWndFrom != lv.Header)
                return

			switch nmcd.dwDrawStage {
			case CDDS_PREPAINT    : return CDRF_NOTIFYITEMDRAW
			case CDDS_ITEMPREPAINT: SetTextColor(nmcd.hdc,  0xFFFFFF)
			}

            return CDRF_DODEFAULT
		})

        lv.Opt("+LV" LVS_EX_DOUBLEBUFFER)
        
        SendMessage(WM_CHANGEUISTATE, (UIS_SET << 8) | UISF_HIDEFOCUS, 0, lv)

        SetWindowTheme(lv.Header, "DarkMode_ItemsView")
        SetWindowTheme(lv.Hwnd, "DarkMode_" style)

        SetTextColor(hdc, color) => DllCall("SetTextColor", "Ptr", hdc, "UInt", color)

        SetWindowTheme(hwnd, appName, subIdList?) => DllCall("uxtheme\SetWindowTheme", "ptr", hwnd, "ptr", StrPtr(appName), "ptr", subIdList ?? 0)
    }
}

; DarkGuiApp()

; class DarkGuiApp {
;     __New() {
;         this.InitializeGui()
;     }

;     InitializeGui() {
;         this.gui := Gui()
;         this.gui.BackColor := 0x202020
        
;         this.lv := this.gui.AddListView("Count100 R10 W400 cWhite", ["Select", "Number", "Description"])
        
;         this.lv.SetDarkMode()
        
;         Loop 10 {
;             this.lv.Add(, "☑", A_Index, "Sample text " A_Index)
;         }
        
;         this.gui.Show()
;     }
; }