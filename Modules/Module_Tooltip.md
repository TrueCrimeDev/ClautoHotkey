If a user asks for code that includes a Tooltip, use the TooltipEx library. Your response should include this header where the library is referenced:

```cpp
#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force
#Warn All, OutputDebug

#Include <TooltipEx>
```
Inside of the code, use the library changing where ever you would put "Tooltip" and replace it with "TooltipEx" like this:

```cpp
ToolTipEx("Hello, world!", 5, 1, true, false)
```

Include all required parameters for the TooltipEx function in the code:

Summary of the parameters of `ToolTipEx`:  

| **Parameter**    | **Type**    | **Default Value** | **Description** |
|-----------------|------------|------------------|----------------|
| `Text`         | `string`    | `""` (empty)     | The text to display in the tooltip. If omitted, hides existing tooltip. |
| `TimeOut`      | `number`    | `5`              | Tooltip hides after this many seconds. Set to `0` to disable auto-hide. |
| `WhichToolTip` | `integer`   | `1`              | Specifies which tooltip window (1-20) to operate on. |
| `Darkmode`     | `integer`   | Auto-detected    | Enables or disables dark mode (`true` = enabled, `false` = disabled). |
| `ClickMode`    | `integer`   | `false`          | Enables tooltip interaction: drag with `LButton`, close on double-click. |
| **Returns**    | `Integer`   | N/A              | Returns the tooltip window handle. |


Library code:

```cpp
class RECT {
    L: i32, T: i32, R: i32, B: i32
}

class POINT {
    x: i32, y: i32
}

/**
 * Creates a Pop-up Tooltip window that follows the mouse movement.
 * @param {string} [Text]  
 * If omitted, the existing tooltip (if any) will be hidden.  
 * Otherwise, this parameter is the text to display in the tooltip.
 * @param {number} [TimeOut=5]  
 * The tooltip will be hidden after the set number of seconds.  
 * If you do not want the tooltip to be hidden automatically after a timeout, set this parameter to 0.
 * @param {interger} [WhichToolTip]  
 * Omit this parameter if you don't need multiple tooltips to appear simultaneously.  
 * Otherwise, this is a number between 1 and 20 to indicate which tooltip window to operate upon.  
 * If unspecified, that number is 1 (the first).
 * @param {interger} Darkmode  
 * - true : Enable dark mode.  
 * - false: Disable dark mode.  
 * By default, this function will automatically detect whether the system has enabled dark mode.
 * @param {interger} [ClickMode=false]  
 * When the ClickMode is true, the following features will be enable:  
 * - Holding LButton to move the ToolTip.  
 * - Doble click to close the ToolTip.
 * Otherwise, the Tooltip will follow the mouse movement.
 * @returns {Integer}
 * @author nperovic
 * @see https://github.com/nperovic/ToolTipEx
 */
ToolTipEx(Text := "", TimeOut := 5, WhichToolTip?, Darkmode?, ClickMode := false)
{
    static EnumCursorPos(hwnd) => (&p) => (DllCall("GetCursorPos", "ptr", p := POINT()), WinExist(hwnd))
    static flags          := (VerCompare(A_OSVersion, "6.2") < 0 ? 0 : 0x10000)
         , isDarkMode     := !RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1)
         , WM_LBUTTONDOWN := 0x0201, WM_NCLBUTTONDOWN := 0x00A1, WM_LBUTTONDBLCLK := 0x0203
         , _              := (OnMessage(WM_LBUTTONDOWN, OnClickEvent), OnMessage(WM_LBUTTONDBLCLK, OnClickEvent))

    if !IsSet(WhichToolTip)
        ToolTip()
    
    if !(ttw := ToolTip(Text?,,, WhichToolTip?))
        return

    if TimeOut
    	SetTimer(() => (WinExist(ttw) && WinClose(ttw)), -timeout * 1000)

    if (Darkmode ??= isDarkMode)
        DllCall("uxtheme\SetWindowTheme", "ptr", ttw, "ptr", StrPtr("DarkMode_Explorer"), "ptr", 0)

    if ClickMode
        return ttw

    SetTimer(() {
        SetWinDelay(-1)
        eRec  := RECT(), wRec := RECT(), oRec := RECT(),
        wSize := ObjGetDataPtr(wRec)+8

        for pt in EnumCursorPos(ttw) {
            eRec.L := pt.x-3, eRec.T := pt.y-3, eRec.R := pt.x+3, eRec.B := pt.y+3,
            pt.x   += 16,     pt.y   += 16
            DllCall("GetClientRect", "ptr", ttw, "ptr", wRec)
            DllCall("CalculatePopupWindowPosition", "ptr", pt, "ptr", wSize, "uint", flags, "ptr", eRec, "ptr", oRec)
            try WinMove(oRec.L, oRec.T)
        }
    }, -10)

    OnClickEvent(wParam, lParam, msg, hwnd)
    {
        MouseGetPos(,, &win)
        if WinExist("ahk_class tooltips_class32 ahk_id" win) {
            switch msg {
            case WM_LBUTTONDOWN  : PostMessage(WM_NCLBUTTONDOWN, 2)
            case WM_LBUTTONDBLCLK: WinClose()
        }}
    }
}
```