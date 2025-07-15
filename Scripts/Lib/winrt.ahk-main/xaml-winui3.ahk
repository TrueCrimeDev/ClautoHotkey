#include winrt.ahk
#include AppPackage.ahk


UseWindowsAppRuntime '1.6'


; This must be done exactly once for Xaml to work.
DQC := WinRT('Microsoft.UI.Dispatching.DispatcherQueueController').CreateOnCurrentThread()
; ShutdownQueue "must" be called before the current (real) thread exits.
; Details: https://learn.microsoft.com/windows/apps/develop/dispatcherqueue
OnExit (*) => DQC.ShutdownQueue()


ShowExampleGui

ShowExampleGui() {
    xg := BasicXamlGui('+Resize')
    
    ; Xaml follows the user's dark mode preference by default, but the window frame
    ; doesn't.  Unlike UWP, the WinUI 3 island is transparent by default, so we also
    ; need to set a suitable background.  An alternative is to set a background in Xaml,
    ; but that doesn't cover the margin of the root element.  This produces a dark grey
    ; without the Mica effect: Background="{ThemeResource SolidBackgroundFillColorBase}"
    ; By contrast, the color below is generally pure black for dark mode, which looks
    ; out of place (but apparently DwmExtendFrameIntoClientArea below fixes it):
    bc := WinRT('Windows.UI.ViewManagement.UISettings')().GetColorValue('Background')
    xg.BackColor := Format('{:02x}{:02x}{:02x}', bc.R, bc.G, bc.B)
    DarkModeIsActive() && SetDarkWindowFrame(xg.hwnd, true)
    ; An alternative strategy is to request the light theme for Xaml:
    ; app := WinRT('Microsoft.UI.Xaml.Application').Current
    ; app.RequestedTheme := 'Light'
    
    ; For dark mode, this apparently causes Xaml to render the window background consistent
    ; with the titlebar (and the color/effect can be changed with DwmSetWindowAttribute and
    ; DWMWA_SYSTEMBACKDROP_TYPE), although in light mode it seems the background is always
    ; white (and setting xg.BackColor := 0 gives a solid black background, whereas without
    ; Xaml it would make the backdrop visible because the alpha channel is 0).
    NumPut('int', -1, 'int', -1, 'int', -1, 'int', -1, margins := Buffer(16))
    DllCall("dwmapi\DwmExtendFrameIntoClientArea", 'ptr', xg.hwnd, 'ptr', margins, 'hresult')
    
    ; DWMWA_SYSTEMBACKDROP_TYPE := 38
    ; DWMSBT_NONE := 1
    ; DWMSBT_MAINWINDOW := 2
    ; DWMSBT_TRANSIENTWINDOW := 3
    ; DWMSBT_TABBEDWINDOW := 4
    DllCall("dwmapi\DwmSetWindowAttribute", 'ptr', xg.hwnd, 'uint', 38, 'int*', 3, 'int', 4, 'hresult')
    
    ; FIXME: this probably needs an App implementation which handles IXamlMetadataProvider
    ;  see https://github.com/sotanakamura/winui3-without-xaml
    ;  and https://github.com/microsoft/WindowsAppSDK-Samples/tree/main/Samples/Islands
    ; res := WinRT('Microsoft.UI.Xaml.Controls.XamlControlsResources')()
    ; app.Resources.MergedDictionaries.Append(res)
    
    xg.Content := stk := WinRT('Microsoft.UI.Xaml.Markup.XamlReader').Load("
    (
        <StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Margin="10" Spacing="10">
            <TextBlock Text="AutoHotkey version: ">
                <Run Name="Version" Text="" Foreground="#0080ff"/>
            </TextBlock>
            <!--TextBox Name="Box"/-->
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Spacing="10">
                <Button Name="OK" Content="OK" Width="100"/>
                <Button Name="Cancel" Content="Cancel" Width="100"/>
            </StackPanel>
        </StackPanel>
    )")
    
    ; xg['Version'] is a shortcut for xg.Content.FindName('Version'), where xg.Content = stk.
    xg['Version'].Text := A_AhkVersion
    
    ; Note that the anonymous closure below captures xg, which prevents it from being
    ; deleted while the Xaml event is still registered. This isn't a big issue for this
    ; example because closing the GUI will still cause the script to exit.
    xg['OK'].add_Click((btn, args) => (
        xg.Hide(),
        MsgBox("Okay!")
    ))
    
    xg['Cancel'].add_Click((btn, args) => (
        xg.Hide()
    ))
    
    sz := WinRT('Windows.Foundation.Size')()
    sz.Width := 600
    sz.Height := 200
    stk.Measure(sz)
    
    xg.Show("w600 h" (stk.DesiredSize.Height * A_ScreenDPI / 96))
    
    xg.NavigateFocus('First')
}

class BasicXamlGui extends Gui {
    __new(opt:='', title:=unset) {
        super.__new(opt ' -DPIScale', IsSet(title) ? title : A_ScriptName, this)
        
        static _ := (
            OnMessage(0x100, BasicXamlGui._OnKeyDown.Bind(BasicXamlGui))
            ; Don't know if this is necessary yet since TextBox isn't working:
            ; OnMessage(0x102, BasicXamlGui._OnChar.Bind(BasicXamlGui))
        )
        
        this._dwxs := dwxs := WinRT('Microsoft.UI.Xaml.Hosting.DesktopWindowXamlSource')()
        
        ; Setter crashes; Xaml implementation references a null pointer.
        ; Probably need to implement an Application "subclass" and/or use AppWindow.
        ; dwxs.SystemBackdrop := WinRT('Microsoft.UI.Xaml.Media.DesktopAcrylicBackdrop')()
        
        ; Supposed to use GetWindowIdFromWindow from winrt\Microsoft.UI.Interop.h,
        ; but we're obviously not using C++, and the actual function export is not
        ; documented (although for this one, the header uses GetProcAddress, so we
        ; can see exactly where it is loaded from).  Anyway, it doesn't make sense
        ; for the WindowId value to be anything but an actual HWND.
        wid := WinRT('Microsoft.UI.WindowId')()
        wid.Value := this.hwnd
        dwxs.Initialize(wid)
        this._xwnd := dwxs.SiteBridge.WindowId.Value
        
        ; ResizePolicy avoids the need to handle the Size event, and is apparently
        ; also sufficient for the initial sizing of the island.  If this is removed,
        ; it is necessary to manually set the size.  Unlike in UWP, the island is not
        ; initially hidden.
        dwxs.SiteBridge.ResizePolicy := 'ResizeContentToParentWindow'
    }
    
    Content {
        get => this._dwxs.Content
        set => this._dwxs.Content := value
    }
    
    __Item[name] => this._dwxs.Content.FindName(name) ; FIXME: needs WinRT() to "down-cast" from UIElement to actual class
    
    NavigateFocus(reason) =>
        this._dwxs.NavigateFocus(
            WinRT('Microsoft.UI.Xaml.Hosting.XamlSourceFocusNavigationRequest')(reason))
    
    static _OnKeyDown(wParam, lParam, nmsg, hwnd) {
        if !(wnd := GuiFromHwnd(hwnd, true)) || !(wnd is BasicXamlGui)
            return
        kmsg := Buffer(48, 0)
        NumPut('ptr', hwnd, 'ptr', nmsg, 'ptr', wParam, 'ptr', lParam
            , 'uint', A_EventInfo, kmsg)
        if DllCall("Microsoft.UI.Windowing.Core.dll\ContentPreTranslateMessage", 'ptr', kmsg)
            return 0
    }
    
    static _OnChar(wParam, lParam, nmsg, hwnd) {
        if !(wnd := GuiFromHwnd(hwnd, true)) || !(wnd is BasicXamlGui)
            return
        ; Xaml islands (tested on 10.0.22000) do not respond to WM_GETDLGCODE
        ; correctly, so WM_CHAR messages are consumed by IsDialogMessage() and
        ; not dispatched to the island unless we do it directly.
        if WinGetClass(hwnd) = 'Windows.UI.Input.InputSite.WindowClass'
            return SendMessage(nmsg, wParam, lParam, hwnd)
    }
}

DarkModeIsActive() {
    return isColorLight(WinRT('Windows.UI.ViewManagement.UISettings')().GetColorValue('Foreground'))
    ; Algorithm from https://docs.microsoft.com/en-us/windows/apps/desktop/modernize/apply-windows-themes
    isColorLight(clr) =>
        ((5 * clr.G) + (2 * clr.R) + clr.B) > (8 * 128)
}

SetDarkWindowFrame(hwnd, dark) {
    if VerCompare(A_OSVersion, "10.0.17763") >= 0 {
        attr := 19
        if VerCompare(A_OSVersion, "10.0.18985") >= 0
            attr := 20 ; DWMWA_USE_IMMERSIVE_DARK_MODE is officially defined for 10.0.22000 as 20.
        DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", attr, "int*", dark, "int", 4)
    }
}
