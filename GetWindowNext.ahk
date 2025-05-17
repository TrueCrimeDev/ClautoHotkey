#Requires AutoHotkey v2.0.17+

$F1:: GetNextWindowOnMonitor(1)
$F2:: GetNextWindowOnMonitor(2)
$F3:: GetNextWindowOnMonitor(3)
$F4:: GetNextWindowOnMonitor(4)
$F5:: GetNextWindowOnMonitor(5)
$F6:: GetNextWindowOnMonitor(6)

GetNextWindowOnMonitor(MonitorToSwitchTo, activateFirst_ThenSwitchWindow := true) {
  if MonitorToSwitchTo > MonitorGetCount() {                                          ; if monitor to check exceeds amount of actual monitors
    return                                                                           ; exit
  }

  ids := WinGetList(, , , 'Program Manager')                                            ; store an array of all the window ids in an array called ids, except desktop
  windowFound := activateFirst_ThenSwitchWindow                                       ; used to keep track of a found window
  prevId := 0                                                                         ; saves id of window found on monitor in case it needs to be activated


  for id in ids {                                                                     ; loop through windows
    thisMonitor := MonitorFromWindow(id)                                             ; find out which monitor this window is on

    if thisMonitor = MonitorToSwitchTo {                                             ; if window is found on monitor the requested
      if activateFirst_ThenSwitchWindow {                                           ; if you want the first window found on the monitor to activate first
        if WinActive(id) {                                                         ; if window is active
          WinMoveBottom(id)                                                       ; move to bottom of stack
          continue                                                                ; finds next window to activate
        }
      }

      if not windowFound {                                                          ; first window found
        WinMoveBottom(id)                                                          ; push window to bottom of stack
        prevId := id                                                               ; saves id of window on monitor in case it's the only window on that monitor
        windowFound := true                                                        ; skip this code block next loop
        continue                                                                   ; find next window on identifier monitor
      }


      try WinActivate(id)                                                           ; activate found window
      break                                                                         ; done
    }

    if A_Index = ids.Length and windowFound {                                        ; if last window in list that wasn't found on identifier monitor and a previous window was, activate that previous window
      try WinActivate(prevId)                                                       ; i.e. if only one window on monitor is found, activate it
    }
  }


  MonitorFromWindow(id := WinExist()) {
    try monFromWin := DllCall('MonitorFromWindow', 'Ptr', WinGetID(id), 'UInt', 2)  ; get monitor handle number window is on
    catch {                                                                         ; if it fails because of something weird active like alt-tab menu,
      return MonitorGetPrimary()                                                  ; return primary monitor number as a fallback
    }
    return ConvertHandleToNumber(monFromWin)                                        ; convert handle to monitor number and return it
  }

  ConvertHandleToNumber(handle) {
    monCallback := CallbackCreate(__EnumMonitors, 'Fast', 4)                      ; fast-mode, 4 parameters
    monHandleList := ''                                                             ; initialize monitor handle number list

    if EnumerateDisplays(monCallback) {                                             ; enumerates all monitors
      loop parse, monHandleList, '`n' {                                           ; loop list of monitor handle numbers
        if A_LoopField = handle {                                               ; if the handle number matches the monitor the mouse is on
          return A_Index                                                      ; set monFromMouse to monitor number
        }
      }
    }

    __EnumMonitors(hMonitor, hDevCon, pRect, args) {                                ; callback function for enumeration DLL
      monHandleList .= hMonitor '`n'                                              ; add monitor handle number to list
      return true                                                                 ; continues enumeration
    }
  }

  EnumerateDisplays(callback) => DllCall('EnumDisplayMonitors', 'Ptr', 0, 'Ptr', 0, 'Ptr', callback, 'UInt', 0)
}