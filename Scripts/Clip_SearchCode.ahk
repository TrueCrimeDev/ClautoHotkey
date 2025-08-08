#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

VSCodeSearcher()

class VSCodeSearcher {
  static Config := Map(
    "hotkey", "!^v",
    "vsCodeExe", "Code.exe",
    "searchDelay", 50,
    "activateDelay", 100
  )

  __New() {
    this.SetupHotkey()
  }

  SetupHotkey() {
    try {
      Hotkey(VSCodeSearcher.Config["hotkey"], this.Execute.Bind(this))
    } catch Error as err {
      MsgBox("Failed to set up hotkey: " err.Message)
      ExitApp
    }
  }

  Execute(*) {
    try {
      searchText := this.GetFirstLineFromClipboard()
      if (searchText = "") {
        this.ShowTooltip("THISISNEW")
        return
      }

      if (!this.ActivateVSCode()) {
        this.ShowTooltip("VS Code window could not be found.")
        return
      }

      this.SearchInVSCode(searchText)

      this.ShowTooltip("Searching for first line from clipboard...")
    } catch Error as err {
      this.ShowTooltip("Error: " err.Message, 3000)
    }
  }

  ShowTooltip(message, duration := 2000) {
    ToolTip(message)
    clearFunc := this.ClearTooltip.Bind(this)
    SetTimer(clearFunc, -duration)
  }

  ClearTooltip(*) {
    ToolTip()
  }

  GetFirstLineFromClipboard() {
    try {
      clipContent := A_Clipboard

      if (clipContent = "")
        return ""

      pos := InStr(clipContent, "`n")
      if (pos)
        return Trim(SubStr(clipContent, 1, pos - 1))
      else
        return Trim(clipContent)
    } catch Error as err {
      throw Error("Failed to get clipboard content: " err.Message, "GetFirstLineFromClipboard")
    }
  }

  ActivateVSCode() {
    try {
      if (WinExist("ahk_exe " VSCodeSearcher.Config["vsCodeExe"])) {
        WinActivate
        Sleep VSCodeSearcher.Config["activateDelay"]
        return true
      }

      if (WinExist("ahk_class Chrome_WidgetWin_1 ahk_exe " VSCodeSearcher.Config["vsCodeExe"])) {
        WinActivate
        Sleep VSCodeSearcher.Config["activateDelay"]
        return true
      }

      if (WinExist("Visual Studio Code")) {
        WinActivate
        Sleep VSCodeSearcher.Config["activateDelay"]
        return true
      }

      return false
    } catch Error as err {
      throw Error("Failed to activate VS Code: " err.Message, "ActivateVSCode")
    }
  }

  SearchInVSCode(searchText) {
    try {
      Send "^f"
      Sleep VSCodeSearcher.Config["searchDelay"]

      Send "^a"
      Sleep VSCodeSearcher.Config["searchDelay"]

      SendText searchText
      Sleep VSCodeSearcher.Config["searchDelay"]

      Send "+{Tab 2}"
      Sleep VSCodeSearcher.Config["searchDelay"]

      Send "^+/"
      Sleep VSCodeSearcher.Config["searchDelay"]

      Send "+{Down}"
      Sleep VSCodeSearcher.Config["searchDelay"]

      Send "^v"
      Sleep VSCodeSearcher.Config["searchDelay"]

      Send "!f"
      Sleep VSCodeSearcher.Config["searchDelay"]
    } catch Error as err {
      throw Error("Failed to search in VS Code: " err.Message, "SearchInVSCode")
    }
  }
}