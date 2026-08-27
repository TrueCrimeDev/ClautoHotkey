---
name: Module_UIA
description: >
  UI Automation (UIA-v2) for AHK v2 - element finding strategies, control patterns, cross-process
  automation, and the Chromium/Electron lazy-accessibility quirks. TRIGGER when the request
  involves: UIA, UI Automation, UIA-v2, ElementFromHandle, ElementFromChromium, FindElement,
  FindElements, WaitElement, TreeWalker, control pattern, InvokePattern, ValuePattern,
  TogglePattern, "automate another app", "click a button in another program",
  Chromium accessibility, AutomationId, "no window class". Not covered: window and control
  manipulation via the built-in Win*/Control* functions - use built-in AHK v2 knowledge.
---

# AHK v2 UI Automation (UIA-v2)

Cross-process automation of Windows applications through the UI Automation API, using the
UIA-v2 library. Covers element discovery, control patterns, synchronization, and the
Chromium-family quirks that break naive approaches.

## Headers

```ahk
#Requires AutoHotkey v2.1-alpha.30
#SingleInstance Force
#include <UIA>
```

## Critical corrections

The left column is what people write; the right column is what actually works.

| Instead of | Use | Why |
|---|---|---|
| `ElementFromHandle(chrome)` | `ElementFromChromium(chrome)` | Chromium a11y is lazy; the plain call gets an empty tree |
| `FindElement({Type: Button})` | `FindElement({Type: "Button"})` | Condition values must be quoted strings |
| `element.SetValue(text)` | `element.Value := text` | Property syntax, not a setter method |
| `checkbox.Click()` | `checkbox.Toggle()` | Use TogglePattern, not a physical click |
| `menuItem.Select()` | `menuItem.Invoke()` | Menu items use InvokePattern |
| `FindElement({Name: "Save"})` | `WaitElement({Name: "Save"}, 5000)` | Async UI needs a wait, not a one-shot lookup |
| `button.Click(), next.Click()` | wait for `next` between the two | The second element may not exist yet |
| `{key: value}` as a data store | `Map()` then `m["key"] := value` | Object literals are not data dictionaries |
| `(*) => { multi; line }` | `this.Method.Bind(this)` | `=> {` is a syntax error on every build |

## Connecting to an application

```ahk
; Standard Windows apps
windowEl := UIA.ElementFromHandle("ahk_exe notepad.exe")

; Chromium apps (Chrome, Edge, VSCode, Teams)
chromeEl := UIA.ElementFromChromium("ahk_exe chrome.exe")
vscodeEl := UIA.ElementFromChromium("ahk_exe Code.exe")

; Chromium detection
IsChromium(identifier) => InStr(WinGetClass(identifier), "Chrome_")
```

## Finding elements

```ahk
; Basic finding
button := windowEl.FindElement({Type: "Button", Name: "Save"})
editBox := windowEl.FindElement({AutomationId: "textInput1"})

; Async / reliable finding
dialog := UIA.WaitElement({Type: "Window", Name: "Save As"}, 5000)
button := parentEl.WaitElement({Type: "Button"}, 3000)

; Substring matching
addressEl := windowEl.FindElement({Name: "Address", matchmode: "Substring"})

; By position among siblings
thirdButton := windowEl.FindElement({Type: "Button", index: 3})

; Multiple elements
elements := windowEl.FindElements([{Name: "Username"}, {Name: "Password"}])
```

### RegEx matching is broken on alpha.28+

`FindElement` / `ElementExist` with `matchmode: "RegEx"` throws `No value was returned.`
on v2.1-alpha.28 and later. Filter client-side instead. Note the pattern uses a single
`\d` — a backslash is not a string escape in AHK, so it needs no doubling.

```ahk
userEl := ""
for el in windowEl.FindElements({Type: "Text"}) {
    if RegExMatch(el.Name, "^user_\d+$") {
        userEl := el
        break
    }
}
```

## Interacting

Prefer the control pattern over a physical click — patterns work when the window is
occluded, minimized, or on another virtual desktop.

```ahk
button.Invoke()                   ; Buttons
checkbox.Toggle()                 ; Checkboxes
editBox.Value := "text"           ; Text input
listItem.Select()                 ; List selections
treeItem.Expand()                 ; Tree navigation

; Property access
name := element.Name
isEnabled := element.IsEnabled
rect := element.BoundingRectangle

; Physical fallback, when no pattern is available
element.Click("left")
element.Click(200)                ; with a sleep
element.ControlClick("left", 1)
```

## Synchronization

```ahk
element := UIA.WaitElement(conditions, 5000)
element.WaitProperty("IsEnabled", true, 3000)
dialog.WaitNotExist(10000)

; Existence check - capture the element before acting on it
saveBtn := parentEl.WaitElement({Type: "Button", Name: "Save"}, 3000)
if (saveBtn) {
    saveBtn.Invoke()
}

; Common timings
static Short := 100, Medium := 500, Long := 2000, VeryLong := 10000
```

## Error handling and visual debugging

```ahk
try {
    element := parentEl.WaitElement(conditions, 5000)
    if (!element.IsEnabled)
        element.WaitProperty("IsEnabled", true, 3000)
    element.Invoke()
} catch Error as e {
    condDesc := ""
    for key, value in conditions.OwnProps()
        condDesc .= key "=" value " "
    OutputDebug("UIA Error: " e.Message " | Conditions: " RTrim(condDesc))
    return false
}

element.Highlight(2000)           ; Highlight for 2 seconds
MsgBox(element.Dump())            ; Element properties
MsgBox(parentEl.DumpAll())        ; Tree structure
```

## UIA-specific AHK v2 rules

UIA elements have **no** `OnEvent()`. Events go through the UIA event-handler API, and
every callback still binds its context with `.Bind(this)`.

```ahk
handler := UIA.CreateAutomationEventHandler(this.OnInvoked.Bind(this))
UIA.AddAutomationEventHandler(handler, element, UIA.Event.Invoke_Invoked)

focusHandler := UIA.CreateEventHandler(this.Focus.Bind(this), "FocusChanged")
UIA.AddFocusChangedEventHandler(focusHandler)
```

```ahk
; Configuration is a Map, built empty then assigned
config := Map()
config["timeout"] := 5000
config["retries"] := 3

elements := ["button1", "button2"]              ; Arrays for ordered sequences

class UIAAutomator {
    __New(appId) {                  ; no "new" keyword - call the class
        this.appId := appId
    }
    AppElement => this._element     ; expression property syntax
}

simple := (*) => element.Invoke()               ; single expression is fine
complex := this.HandleComplex.Bind(this)        ; multi-statement needs a bound method
```

## Validation checklist

- UIA inclusion: `#include <UIA>` with AutoHotkey v2.1+
- Chromium detection: `ElementFromChromium()` for Chrome / Edge / VSCode
- Async elements: `WaitElement(conditions, timeout)`, not `FindElement()`
- Quoted conditions: `{Type: "Button"}`, never `{Type: Button}`
- Pattern safety: check availability or wrap in `try`/`catch`
- Event binding: `UIA.CreateAutomationEventHandler()` + `UIA.AddAutomationEventHandler()`,
  callbacks bound with `.Bind(this)` — elements have no `.OnEvent()`
- Data storage: `Map()` built empty, then per-key assignment
- Error handling: no empty catch blocks; log the conditions that failed
- Resource cleanup: remove event handlers in `__Delete()`

## Reference implementation

```ahk
#Requires AutoHotkey v2.1-alpha.30
#include <UIA>

class UIAAutomator {
    __New(appIdentifier) {
        this.appId := appIdentifier
        this.appElement := this.Connect()
        this.config := Map()
        this.config["timeout"] := 5000
        this.config["retries"] := 3
    }

    Connect() {
        WinWait(this.appId, , 10)
        return this.IsChromium()
            ? UIA.ElementFromChromium(this.appId)
            : UIA.ElementFromHandle(this.appId)
    }

    IsChromium() => InStr(WinGetClass(this.appId), "Chrome_")

    Find(conditions, timeout := 5000) {
        try {
            return this.appElement.WaitElement(conditions, timeout)
        } catch Error as e {
            OutputDebug("Element not found: " this.DescribeConditions(conditions) " | " e.Message)
            return ""
        }
    }

    DescribeConditions(conditions) {
        desc := ""
        for key, value in conditions.OwnProps()
            desc .= key "=" value " "
        return RTrim(desc)
    }

    Safe(elementConditions, action, timeout := 5000) {
        if (element := this.Find(elementConditions, timeout)) {
            try {
                if (!element.IsEnabled)
                    element.WaitProperty("IsEnabled", true, 3000)
                action.Call(element)
                return true
            } catch Error as e {
                OutputDebug("Action failed: " e.Message)
            }
        }
        return false
    }

    FillForm(formFields) {
        success := true
        for fieldName, fieldValue in formFields {
            if (!this.Safe({AutomationId: fieldName}, (el) => el.Value := fieldValue)) {
                if (!this.Safe({Name: fieldName}, (el) => el.Value := fieldValue)) {
                    OutputDebug("Failed to fill field: " fieldName)
                    success := false
                }
            }
        }
        return success
    }

    __Delete() {
        UIA.RemoveAllEventHandlers()
        this.appElement := ""
    }
}
```

```ahk
automator := UIAAutomator("ahk_exe notepad.exe")
automator.Safe({AutomationId: "15"}, (el) => el.Value := "Hello, World!")

formData := Map()
formData["username"] := "myuser"
formData["password"] := "mypass"
automator.FillForm(formData)
```

## SEE ALSO

- `Module_Errors.md` — try/catch structure, typed errors, the no-empty-catch rule
- `Module_DynamicProperties.md` — `.Bind()` semantics and fat-arrow limits
- `Module_WinAPI.md` — when UIA is unavailable and raw messages are the only route
