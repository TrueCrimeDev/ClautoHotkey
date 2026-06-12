# AutoHotkey v2 Fat Arrows and Callbacks

A practical guide to fat-arrow functions, callback binding, and event handling in
AHK v2 — including the rules that decide when a fat arrow is safe and when a named
method is required.

## Fat-Arrow Rules

A fat arrow (`=>`) defines a function whose body is a **single expression**. The
expression's result is the function's return value. There is no block form.

```cpp
Square := x => x * x                 ; single expression, returns x * x
Add := (a, b) => a + b               ; parentheses required for multiple parameters
```

The hard rules:

1. **Single expression only.** `=> {` is a **syntax error on every v2 build**,
   including v2.1-alpha.30. A fat-arrow body cannot be a block and cannot contain
   multiple statements.

   ```cpp
   ; WRONG: load-time syntax error on all v2 builds
   handler := (a, b) => {
       total := a + b
       return total
   }
   ```

2. **v2.1's multi-statement function expression is arrowless.** Under a v2.1 pin,
   write the parameter list followed directly by a brace block — no `=>`:

   ```cpp
   handler := (a, b) {
       total := a + b
       return total
   }
   ```

3. **Use a named method + `.Bind(this)` for event handlers.** Fat arrows are for
   trivial one-expression adapters that return a value. Anything with real logic —
   or anything whose body is a call to a void function — belongs in a named method:

   ```cpp
   this.btn.OnEvent("Click", this.HandleClick.Bind(this))
   ```

4. **The v2.1 void-call gotcha.** Under a v2.1 pin, calling a function that
   returns nothing yields `unset` — and a fat-arrow body *is* its return value.
   An arrow like `(*) => gui.Hide()` therefore returns unset, and any consumer
   that touches the result throws. The examples in this guide pin
   `v2.1-alpha.30`, so handler-position arrows that wrap void calls are written
   as named methods throughout.

   ```cpp
   ; HAZARD under v2.1: Hide() is void, so the arrow returns unset
   gui.OnEvent("Escape", (*) => gui.Hide())

   ; SAFE: named handler
   gui.OnEvent("Escape", HideOnEscape)

   HideOnEscape(thisGui) {
       thisGui.Hide()
   }
   ```

Good fat-arrow use cases: sort comparators, `Map`/filter predicates, value
transforms (`x => x * 2`), and single-expression adapters that forward to a
method *and* return its value.

## Core Event Handling Concepts

```cpp
#Requires AutoHotkey v2.1-alpha.30
#SingleInstance Force

EventHandlingBasics()
class EventHandlingBasics {
    __New() {
        ; Create a basic GUI to demonstrate event handling
        this.gui := Gui("+Resize", "Event Handling Demo")
        
        ; Add controls and bind events
        this.gui.AddText(, "Click the button to trigger events:")
        this.btn := this.gui.AddButton("w200 h30", "Click Me")
        
        ; Method 1: Bind using .Bind() - recommended approach
        this.btn.OnEvent("Click", this.HandleButtonClick.Bind(this))
        
        ; Method 2: named method bound for Close - HandleClose is void, so a
        ; fat arrow here would return unset under v2.1
        this.gui.OnEvent("Close", this.HandleClose.Bind(this))
        
        ; Method 3: fat arrow forwarding extra event params (single expression)
        this.gui.OnEvent("Size", (gui, minMax, width, height) => this.HandleResize(width, height))
        
        ; Show the GUI
        this.gui.Show("w300 h200")
    }
    
    ; Event handler methods
    HandleButtonClick(sender, info) {
        MsgBox "Button clicked! Sender HWND: " sender.Hwnd
    }
    
    HandleClose(*) {
        MsgBox "GUI closing"
        ExitApp
    }
    
    HandleResize(width, height) {
        ; Update button size to match window width
        this.btn.Move(, , width - 20)
    }
}
```

## Custom Event System

```cpp
#Requires AutoHotkey v2.1-alpha.30
#SingleInstance Force

CustomEventSystem()
class CustomEventSystem {
    __New() {
        ; Initialize event handlers storage
        this.eventHandlers := Map()
        
        ; Example data
        this.count := 0
        
        ; Demo event firing
        this.StartDemo()
    }
    
    ; Subscribe to an event
    On(eventName, callback) {
        if !this.eventHandlers.Has(eventName)
            this.eventHandlers[eventName] := []
        this.eventHandlers[eventName].Push(callback)
        return this  ; Enable chaining
    }
    
    ; Trigger an event
    Trigger(eventName, params*) {
        if !this.eventHandlers.Has(eventName)
            return
        
        for callback in this.eventHandlers[eventName]
            callback(params*)
    }
    
    ; Remove event handler
    Off(eventName, callback := "") {
        if callback = "" {
            ; Remove all handlers for this event
            this.eventHandlers.Delete(eventName)
        } else if this.eventHandlers.Has(eventName) {
            ; Remove specific handler
            for i, handler in this.eventHandlers[eventName] {
                if (handler = callback) {
                    this.eventHandlers[eventName].RemoveAt(i)
                    break
                }
            }
        }
        return this  ; Enable chaining
    }
    
    ; Demo method
    StartDemo() {
        ; Subscribe to events
        this.On("countChanged", this.DisplayCount.Bind(this))
        this.On("countChanged", this.ShowCountTip.Bind(this))
        this.On("maxReached", (*) => MsgBox("Maximum count reached!"))
        
        ; Start a timer - store the bound ref once; each .Bind() call creates
        ; a NEW object, so a fresh Bind passed to SetTimer later would never
        ; match (and never stop) this timer
        this.countTick := this.IncrementCount.Bind(this)
        SetTimer(this.countTick, 1000)
    }
    
    IncrementCount() {
        this.count++
        this.Trigger("countChanged", this.count)
        
        if (this.count >= 5) {
            this.Trigger("maxReached")
            SetTimer(this.countTick, 0)  ; Stop timer (same bound object)
        }
    }
    
    DisplayCount(newCount) {
        ToolTip("Current count: " newCount)
    }
    
    ShowCountTip(*) {
        ToolTip("Count updated")
    }
}
```

## Event-Driven Architecture Pattern

```cpp
#Requires AutoHotkey v2.1-alpha.30
#SingleInstance Force

; Start the application
App()

; Main application controller
class App {
    static Models := []
    static Views := []
    
    __New() {
        ; Create data model
        this.dataModel := DataModel()
        App.Models.Push(this.dataModel)
        
        ; Create views
        this.mainView := MainView(this.dataModel)
        this.statsView := StatsView(this.dataModel)
        App.Views.Push(this.mainView, this.statsView)
        
        ; Connect controller to model events
        this.dataModel.OnEvent("dataChanged", this.UpdateAllViews.Bind(this))
        
        ; Initialize with data
        this.dataModel.AddItem("Initial task")
    }
    
    UpdateAllViews(*) {
        for view in App.Views
            view.Update()
    }
}

; Data model with events
class DataModel {
    __New() {
        this.items := []
        this.eventHandlers := Map()
    }
    
    ; Event system
    OnEvent(eventName, handler) {
        if !this.eventHandlers.Has(eventName)
            this.eventHandlers[eventName] := []
        this.eventHandlers[eventName].Push(handler)
    }
    
    TriggerEvent(eventName, params*) {
        if !this.eventHandlers.Has(eventName)
            return
        
        for handler in this.eventHandlers[eventName]
            handler(params*)
    }
    
    ; Data methods
    AddItem(item) {
        this.items.Push(item)
        this.TriggerEvent("dataChanged", this.items)
    }
    
    RemoveItem(index) {
        if (index > 0 && index <= this.items.Length) {
            this.items.RemoveAt(index)
            this.TriggerEvent("dataChanged", this.items)
        }
    }
    
    GetItems() {
        return this.items
    }
    
    GetItemCount() {
        return this.items.Length
    }
}

; Main view showing items
class MainView {
    __New(model) {
        this.model := model
        
        ; Create GUI
        this.gui := Gui("+Resize", "Task List")
        this.gui.SetFont("s10")
        
        ; Add controls
        this.gui.AddText("w400", "Current Tasks:")
        this.listBox := this.gui.AddListBox("w400 h200 vSelectedItem")
        
        this.addEdit := this.gui.AddEdit("w300 vNewTask")
        this.addBtn := this.gui.AddButton("x+10 w80", "Add")
        this.addBtn.OnEvent("Click", this.AddItem.Bind(this))
        
        this.removeBtn := this.gui.AddButton("w80", "Remove")
        this.removeBtn.OnEvent("Click", this.RemoveItem.Bind(this))
        
        ; Show GUI
        this.gui.Show()
        
        ; Initial update
        this.Update()
    }
    
    Update() {
        ; Clear and repopulate list
        this.listBox.Delete()
        for item in this.model.GetItems()
            this.listBox.Add([item])
    }
    
    AddItem(*) {
        ; gui["NewTask"] returns the control object - read and clear via .Value
        taskCtrl := this.gui["NewTask"]
        if (taskCtrl.Value != "") {
            this.model.AddItem(taskCtrl.Value)
            taskCtrl.Value := ""  ; Clear input
        }
    }
    
    RemoveItem(*) {
        ; Get selected index
        selectedIndex := this.listBox.Value
        if (selectedIndex > 0)
            this.model.RemoveItem(selectedIndex)
    }
}

; Stats view showing counts
class StatsView {
    __New(model) {
        this.model := model
        
        ; Create separate GUI
        this.gui := Gui("+AlwaysOnTop", "Statistics")
        this.gui.SetFont("s10")
        
        ; Add controls
        this.gui.AddText("w200", "Task Statistics:")
        this.statsText := this.gui.AddText("w200 h100")
        
        ; Show GUI
        this.gui.Show("w220 h150")
        
        ; Initial update
        this.Update()
    }
    
    Update() {
        count := this.model.GetItemCount()
        stats := "Total tasks: " count "`n"
        stats .= "Last updated: " FormatTime(, "HH:mm:ss")
        
        this.statsText.Value := stats
    }
}
```

## Event Handling with Hotkeys and Hotstrings

```cpp
#Requires AutoHotkey v2.1-alpha.30
#SingleInstance Force

HotkeyManager()
class HotkeyManager {
    __New() {
        ; Initialize storage for hotkeys and their callbacks
        this.hotkeyMap := Map()
        this.helpList := ""  ; created below - RegisterHotkey checks it before updating
        
        ; Set up default hotkeys
        this.RegisterHotkey("^c", this.OnCopy.Bind(this))
        this.RegisterHotkey("^v", this.OnPaste.Bind(this))
        this.RegisterHotkey("^+h", this.ToggleHelp.Bind(this))
        
        ; Create help GUI
        this.helpGui := Gui("+AlwaysOnTop", "Hotkey Help")
        this.helpGui.AddText(, "Available Hotkeys:")
        this.helpList := this.helpGui.AddListView("w300 h200", ["Hotkey", "Action"])
        
        ; Update help list
        this.UpdateHelpList()
        
        ; Tip message
        MsgBox "Hotkey system initialized. Press Ctrl+Shift+H for help."
    }
    
    RegisterHotkey(hotkeyString, callback, description := "") {
        ; Store information about this hotkey
        info := Map()
        info["callback"] := callback
        info["description"] := description != "" ? description : "Action for " hotkeyString
        info["enabled"] := true
        this.hotkeyMap[hotkeyString] := info
        
        ; Create the actual hotkey
        Hotkey(hotkeyString, callback)
        
        ; Update help if it exists
        if (this.helpList)
            this.UpdateHelpList()
    }
    
    EnableHotkey(hotkeyString, enable := true) {
        if this.hotkeyMap.Has(hotkeyString) {
            state := enable ? "On" : "Off"
            Hotkey(hotkeyString, state)
            this.hotkeyMap[hotkeyString]["enabled"] := enable
        }
    }
    
    UpdateHelpList() {
        this.helpList.Delete()
        for key, info in this.hotkeyMap {
            status := info["enabled"] ? "" : " (disabled)"
            this.helpList.Add(, key, info["description"] status)
        }
        this.helpList.ModifyCol(1, "AutoHdr")
        this.helpList.ModifyCol(2, "AutoHdr")
    }
    
    ; Hotkey handlers
    OnCopy(*) {
        clipboard_old := ClipboardAll()
        A_Clipboard := ""
        SendInput("^c")
        ClipWait(1)
        if (A_Clipboard != "")
            ToolTip("Copied: " SubStr(A_Clipboard, 1, 50) (StrLen(A_Clipboard) > 50 ? "..." : ""))
        SetTimer(ClearTip, -3000)  ; Clear tooltip after 3 seconds
    }
    
    OnPaste(*) {
        if (A_Clipboard != "")
            ToolTip("Pasting from clipboard...")
        SendInput("^v")
        SetTimer(ClearTip, -1000)
    }
    
    ToggleHelp(*) {
        if WinExist("ahk_id " this.helpGui.Hwnd)
            this.helpGui.Hide()
        else {
            this.UpdateHelpList() ; Refresh the list
            this.helpGui.Show()
        }
    }
}

ClearTip() {
    ToolTip()
}
```

## Best Practices for Event Handling

### Binding Context Properly

```cpp
#Requires AutoHotkey v2.1-alpha.30
#SingleInstance Force

BindingContextDemo()
class BindingContextDemo {
    __New() {
        this.counter := 0
        this.gui := Gui()
        
        ; GOOD: bind a named method - preserves context
        ; (assign the control first; OnEvent returns nothing, so never chain off it)
        this.btn1 := this.gui.AddButton("w200", "Good Button")
        this.btn1.OnEvent("Click", this.GoodHandler.Bind(this))
        
        ; BAD: passing the method without binding - loses 'this' context
        this.btn2 := this.gui.AddButton("w200", "Bad Button")
        this.btn2.OnEvent("Click", this.BadHandler)
        
        ; GOOD: another bound named method - CounterHandler is void, so a fat
        ; arrow like (*) => this.CounterHandler() would return unset under v2.1
        this.btn3 := this.gui.AddButton("w200", "Counter Button")
        this.btn3.OnEvent("Click", this.CounterHandler.Bind(this))
        
        this.gui.Show()
    }
    
    GoodHandler(*) {
        this.counter++
        MsgBox "Good handler called. Counter: " this.counter
    }
    
    BadHandler(*) {
        ; Will fail - 'this' is not the class instance
        try {
            this.counter++  ; Will throw an error
            MsgBox "Counter: " this.counter
        } catch as e {
            MsgBox "Error in BadHandler: " e.Message "`nThe 'this' context was lost because .Bind() wasn't used"
        }
    }
    
    CounterHandler(*) {
        this.counter++
        MsgBox "Counter handler called. Counter: " this.counter
    }
}
```

### Memory Management and Cleanup

```cpp
#Requires AutoHotkey v2.1-alpha.30
#SingleInstance Force

MemoryManagementDemo()
class MemoryManagementDemo {
    __New() {
        ; Initialize
        this.gui := Gui(, "Memory Management Demo")
        this.boundHandlers := Map()  ; Store bound handlers
        
        ; Create controls
        this.btn := this.gui.AddButton("w200", "Click Me")
        
        ; Store bound handler reference for later cleanup
        this.boundHandlers["click"] := this.HandleClick.Bind(this)
        this.btn.OnEvent("Click", this.boundHandlers["click"])
        
        ; Timer example
        this.timerCallback := this.UpdateTime.Bind(this)
        this.timeText := this.gui.AddText("w200 h20", "Time: ")
        SetTimer(this.timerCallback, 1000)
        
        ; Set up cleanup
        this.gui.OnEvent("Close", this.Cleanup.Bind(this))
        this.gui.Show()
    }
    
    HandleClick(*) {
        MsgBox "Button clicked!"
    }
    
    UpdateTime() {
        this.timeText.Value := "Time: " FormatTime(, "HH:mm:ss")
    }
    
    Cleanup(*) {
        ; Clean up timer
        SetTimer(this.timerCallback, 0)
        
        ; Remove event handlers (AddRemove 0 = remove; -1 would mean call-first)
        this.btn.OnEvent("Click", this.boundHandlers["click"], 0)
        
        ; Clear references
        this.boundHandlers := Map()
        
        ; Hide and destroy GUI
        this.gui.Destroy()
        
        MsgBox "Cleanup complete"
        ExitApp
    }
}
```

### Performance Considerations

```cpp
#Requires AutoHotkey v2.1-alpha.30
#SingleInstance Force

PerformanceDemo()
class PerformanceDemo {
    static Config := Map(
        "debounceTime", 300,
        "throttleTime", 500
    )
    
    __New() {
        this.gui := Gui(, "Performance Optimization")
        this.gui.SetFont("s10")
        
        ; Regular event handler (fires with every keystroke)
        this.gui.AddText("w200", "Regular (every keystroke):")
        this.regularEdit := this.gui.AddEdit("w300")
        this.regularEdit.OnEvent("Change", this.RegularHandler.Bind(this))
        this.regularLabel := this.gui.AddText("w300 h20", "")
        
        ; Debounced handler (waits until typing stops)
        this.gui.AddText("w200", "Debounced (after typing stops):")
        this.debouncedEdit := this.gui.AddEdit("w300")
        this.debouncedEdit.OnEvent("Change", this.DebouncedHandler.Bind(this))
        this.debouncedLabel := this.gui.AddText("w300 h20", "")
        
        ; Throttled handler (at most once per time period)
        this.gui.AddText("w200", "Throttled (max once per 500ms):")
        this.throttledEdit := this.gui.AddEdit("w300")
        this.throttledEdit.OnEvent("Change", this.ThrottledHandler.Bind(this))
        this.throttledLabel := this.gui.AddText("w300 h20", "")
        
        ; Storage for timers
        this.debounceTimer := 0
        this.lastThrottleTime := 0
        
        this.gui.Show("w400")
    }
    
    ; Regular handler - runs on every event
    RegularHandler(ctrl, *) {
        this.regularLabel.Value := "Processed at " A_TickCount " ms"
    }
    
    ; Debounced handler - runs only after events stop for a period
    DebouncedHandler(ctrl, *) {
        ; Clear previous timer if it exists
        if this.debounceTimer
            SetTimer(this.debounceTimer, 0)
        
        ; Create new timer
        this.debounceTimer := ObjBindMethod(this, "ProcessDebounced", ctrl.Value)
        SetTimer(this.debounceTimer, -PerformanceDemo.Config["debounceTime"])
    }
    
    ProcessDebounced(value) {
        this.debouncedLabel.Value := "Processed at " A_TickCount " ms: " value
    }
    
    ; Throttled handler - runs at most once per time period
    ThrottledHandler(ctrl, *) {
        if (A_TickCount - this.lastThrottleTime >= PerformanceDemo.Config["throttleTime"]) {
            this.lastThrottleTime := A_TickCount
            this.throttledLabel.Value := "Processed at " A_TickCount " ms: " ctrl.Value
        }
    }
}
```

## Shared Handler Pattern

AHK GUI events do not bubble or delegate the way DOM events do — a `Gui` object
has no "Click" event (registering one throws a ValueError), and clicks on
controls are delivered only to that control's own registered handlers. The
closest equivalent is registering one bound handler on every control and
switching on the sender.

```cpp
#Requires AutoHotkey v2.1-alpha.30
#SingleInstance Force

SharedHandlerDemo()
class SharedHandlerDemo {
    __New() {
        this.gui := Gui(, "Shared Handler Demo")
        this.gui.SetFont("s10")
        
        ; Container for buttons
        this.container := this.gui.AddGroupBox("w400 h200", "Button Container")
        
        ; Create multiple buttons that share one bound handler
        boundClick := this.HandleClick.Bind(this)
        Loop 5 {
            btn := this.gui.AddButton("xp+20 yp+30 w80 h30", "Button " A_Index)
            btn.Name := "Button" A_Index  ; Add identifier
            btn.OnEvent("Click", boundClick)
        }
        
        this.gui.Show("w450 h300")
    }
    
    HandleClick(ctrl, info) {
        ; The first parameter is the control that fired the event
        MsgBox "Clicked on " ctrl.Name " with text: " ctrl.Text
    }
}
```

## Advanced: Cross-Object Communication

```cpp
#Requires AutoHotkey v2.1-alpha.30
#SingleInstance Force

; Create the mediator and start the application
CrossObjectCommunication()

class CrossObjectCommunication {
    __New() {
        ; Create event mediator
        this.mediator := EventMediator()
        
        ; Create modules that will communicate
        this.module1 := SenderModule(this.mediator)
        this.module2 := ReceiverModule(this.mediator)
        this.module3 := LoggingModule(this.mediator)
        
        ; Show the sender module to start interaction
        this.module1.Show()
    }
}

; Central mediator that handles all events
class EventMediator {
    __New() {
        this.subscribers := Map()
    }
    
    Subscribe(eventType, callback) {
        if !this.subscribers.Has(eventType)
            this.subscribers[eventType] := []
        
        this.subscribers[eventType].Push(callback)
    }
    
    Publish(eventType, data := "") {
        ; Log all events
        this.LogEvent(eventType, data)
        
        ; Notify subscribers
        if this.subscribers.Has(eventType) {
            for callback in this.subscribers[eventType]
                callback(data)
        }
    }
    
    LogEvent(eventType, data) {
        FileAppend Format("[{1}] Event: {2}, Data: {3}`n", 
                          FormatTime(, "yyyy-MM-dd HH:mm:ss"), 
                          eventType, 
                          (IsObject(data) ? "Object" : data)), 
                   "event_log.txt"
    }
}

; Module that sends messages
class SenderModule {
    __New(mediator) {
        this.mediator := mediator
        
        ; Create GUI
        this.gui := Gui(, "Message Sender")
        this.gui.SetFont("s10")
        
        this.gui.AddText("w300", "Enter message to send:")
        this.messageEdit := this.gui.AddEdit("w300 h60")
        
        this.sendBtn := this.gui.AddButton("w150", "Send Message")
        this.sendBtn.OnEvent("Click", this.SendMessage.Bind(this))
        
        this.alertBtn := this.gui.AddButton("w150", "Send Alert")
        this.alertBtn.OnEvent("Click", this.SendAlert.Bind(this))
        
        ; Subscribe to messages from other modules
        this.mediator.Subscribe("messageReceived", this.HandleResponse.Bind(this))
    }
    
    Show() {
        this.gui.Show("w320 h180")
    }
    
    SendMessage(*) {
        message := this.messageEdit.Value
        if message != ""
            this.mediator.Publish("newMessage", message)
    }
    
    SendAlert(*) {
        this.mediator.Publish("alert", "Alert triggered at " FormatTime(, "HH:mm:ss"))
    }
    
    HandleResponse(data) {
        ToolTip("Message receipt confirmed: " data)
        SetTimer(ClearTip, -3000)
    }
}

; Module that receives messages
class ReceiverModule {
    __New(mediator) {
        this.mediator := mediator
        
        ; Create GUI
        this.gui := Gui(, "Message Receiver")
        this.gui.SetFont("s10")
        
        this.gui.AddText("w350", "Received Messages:")
        this.messagesList := this.gui.AddListBox("w350 h200")
        
        this.clearBtn := this.gui.AddButton("w150", "Clear Messages")
        this.clearBtn.OnEvent("Click", this.ClearMessages.Bind(this))
        
        ; Subscribe to events
        this.mediator.Subscribe("newMessage", this.ReceiveMessage.Bind(this))
        this.mediator.Subscribe("alert", this.HandleAlert.Bind(this))
        
        ; Show the receiver window
        this.gui.Show("w370 h300")
    }
    
    ReceiveMessage(message) {
        ; Add message to list
        this.messagesList.Add(["[" FormatTime(, "HH:mm:ss") "] " message])
        
        ; Acknowledge receipt
        this.mediator.Publish("messageReceived", "OK")
    }
    
    HandleAlert(alertData) {
        ; Display alert
        MsgBox("ALERT: " alertData, "System Alert")
        
        ; Add to list
        this.messagesList.Add(["ALERT: " alertData])
    }
    
    ClearMessages(*) {
        this.messagesList.Delete()
    }
}

; Module that just logs all events
class LoggingModule {
    __New(mediator) {
        this.mediator := mediator
        
        ; Create GUI
        this.gui := Gui(, "Event Logger")
        this.gui.SetFont("s10")
        
        this.gui.AddText("w400", "Event Log:")
        this.logBox := this.gui.AddEdit("w400 h300 ReadOnly")
        
        this.refreshBtn := this.gui.AddButton("w150", "Refresh Log")
        this.refreshBtn.OnEvent("Click", this.RefreshLog.Bind(this))
        
        ; Subscribe to all events
        this.mediator.Subscribe("newMessage", this.LogEvent.Bind(this, "newMessage"))
        this.mediator.Subscribe("messageReceived", this.LogEvent.Bind(this, "messageReceived"))
        this.mediator.Subscribe("alert", this.LogEvent.Bind(this, "alert"))
        
        ; Show the logger window
        this.gui.Show("w420 h400")
        
        ; Initial log load
        this.RefreshLog()
    }
    
    LogEvent(eventType, data) {
        ; Add to local log
        this.logBox.Value .= "[" FormatTime(, "HH:mm:ss") "] " eventType ": " data "`n"
        
        ; Auto-scroll to bottom
        SendMessage(0x115, 7, 0, this.logBox.Hwnd)  ; WM_VSCROLL, SB_BOTTOM
    }
    
    RefreshLog(*) {
        try {
            ; Read from the log file
            if FileExist("event_log.txt")
                this.logBox.Value := FileRead("event_log.txt")
            else
                this.logBox.Value := "No log file found."
        } catch as e {
            this.logBox.Value := "Error reading log: " e.Message
        }
    }
}

ClearTip() {
    ToolTip()
}
```

## Key Concepts in Event Handling

1. **Binding Context**: Always use `.Bind(this)` to preserve `this` context in callbacks. A fat arrow also captures `this`, but only use one when the single-expression body returns a value.

2. **Event Parameters**: Event handlers typically receive information about the event source and sometimes additional data.

3. **Memory Management**: Store references to bound handlers to enable proper cleanup later.

4. **Performance Optimization**: Use debouncing and throttling for frequently-triggered events.

5. **Shared Handlers**: Reuse one bound handler across similar controls to reduce overhead (AHK has no DOM-style event delegation or bubbling).

6. **Cross-Object Communication**: Use mediator or pub/sub patterns for decoupled object interactions.

7. **Cleanup**: Always remove event handlers when they're no longer needed to prevent memory leaks.

8. **Error Handling**: Wrap event handlers in try/catch blocks to prevent unhandled exceptions from crashing the application.

## Best Practices Summary

1. **Use Proper Binding**: Always preserve context with `.Bind(this)`; reserve fat arrows for single-expression bodies that return a value.

2. **Organize Code**: Keep event handling logic separate from business logic.

3. **Clean Up Resources**: Properly remove event handlers when objects are destroyed.

4. **Performance Awareness**: Optimize handlers for events that fire frequently.

5. **Error Handling**: Implement error handling to prevent application crashes.

6. **Decoupling**: Use events for communication between loosely coupled objects.

7. **Documentation**: Document the event flow in complex applications.

8. **Testing**: Test event handling in isolation from business logic.