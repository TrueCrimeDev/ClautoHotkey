# AutoHotkey v2 Core Reference

## Object Types
1. **Basic Objects** (`{}`)
```cpp
config := {
    appName: "MyTool",
    version: "1.0",
    settings: {
        darkMode: true,
        fontSize: 12
    }
}
```

2. **Arrays** (`[]`)
```cpp
; Task manager
tasks := []
tasks.Push({ name: "Task 1", status: "pending" })
tasks.Push({ name: "Task 2", status: "complete" })

; Process tasks
for task in tasks {
    if task.status == "pending"
        ProcessTask(task)
}
```

3. **Maps** (`Map()`)
```cpp
; Cache system
cache := Map()
cache.Set("user_prefs", {theme: "dark"})
cache.Set("recent_files", ["doc1.txt", "doc2.txt"])

if cache.Has("user_prefs")
    ApplyTheme(cache["user_prefs"].theme)
```

## Classes and Methods
1. **Application Framework**
```cpp
class App {
    static config := {version: "1.0"}
    windows := Map()
    
    __New() {
        this.InitializeWindows()
    }
    
    InitializeWindows() {
        this.windows.Set("main", MainWindow())
        this.windows.Set("settings", SettingsWindow())
    }
    
    ShowWindow(name) {
        if this.windows.Has(name)
            this.windows[name].Show()
    }
}
```

2. **Event System**
```cpp
class EventEmitter {
    handlers := Map()
    
    On(event, callback) {
        if !this.handlers.Has(event)
            this.handlers[event] := []
        this.handlers[event].Push(callback)
    }
    
    Emit(event, data?) {
        if this.handlers.Has(event)
            for callback in this.handlers[event]
                callback(data)
    }
}
```

3. **Data Management**
```cpp
class DataStore {
    static instance := ""
    data := Map()
    
    static GetInstance() {
        if !DataStore.instance
            DataStore.instance := DataStore()
        return DataStore.instance
    }
    
    Set(key, value) {
        this.data[key] := value
        this.SaveToDisk()
    }
}
```

## Common Patterns
1. **Builder Pattern**
```cpp
class GuiBuilder {
    gui := ""
    
    __New() {
        this.gui := Gui()
    }
    
    AddButton(text) {
        this.gui.Add("Button",, text)
        return this
    }
    
    AddEdit() {
        this.gui.Add("Edit")
        return this
    }
    
    Build() {
        return this.gui
    }
}
```

2. **Observer Pattern**
```cpp
class Subject extends EventEmitter {
    state := ""
    
    UpdateState(newState) {
        this.state := newState
        this.Emit("stateChanged", newState)
    }
}
```

3. **Singleton Pattern**
```cpp
class Logger {
    static instance := ""
    logFile := ""
    
    static GetInstance() {
        if !Logger.instance
            Logger.instance := Logger()
        return Logger.instance
    }
    
    Log(message) {
        FileAppend(FormatTime() " " message "`n", this.logFile)
    }
}
```