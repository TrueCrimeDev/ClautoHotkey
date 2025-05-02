# Tech Context: AutoHotkey v2 OOP Framework

## Technologies Used

### Core Technologies
- **AutoHotkey v2.1-alpha.17+**: The primary language and runtime environment
- **Windows OS**: Target platform for all applications
- **Windows API**: Used for advanced functionality not directly exposed by AHK
- **Windows Dark Mode APIs**: Used for detecting system theme settings and styling windows

### Development Tools
- **Visual Studio Code**: Recommended editor with AutoHotkey v2 extension
- **Git**: Version control system for code management

## Development Setup

### Required Components
1. **AutoHotkey v2.1-alpha.17+**: Latest version required for all OOP features
2. **Editor with AHK v2 syntax highlighting**: VSCode recommended
3. **AHK v2 documentation**: Local or online reference
4. **Windows 10/11**: Required for modern dark mode APIs

### Recommended VSCode Extensions
- **AutoHotkey v2 Language Support**: Syntax highlighting and intellisense

### Project Structure
```
project/
├── Lib/                 # Library files and dependencies
│   ├── All.ahk          # Common library inclusion file
│   └── ...
├── memory-bank/         # Memory bank documentation
├── src/                 # Source code
│   ├── Classes/         # Class definitions
│   ├── GUI/             # GUI implementations
│   │   └── Themes/      # Theme definitions and managers
│   └── App.ahk          # Main application file
├── tests/               # Test scripts
└── .clinerules          # Cline rules for this project
```

## Technical Constraints

### Language Limitations
- **AHK v2 Alpha Status**: Some features may change in future releases
- **Windows-only**: No cross-platform support
- **Limited Threading**: Mostly single-threaded execution model
- **Performance Considerations**: Interpreted language with some performance limitations
- **Inconsistent Dark Mode API Support**: Varies by Windows version

### Critical Syntax Rules
1. **No Object Literals for Data Storage**: Must use Map() instead
2. **Required Function Parameter Separation**: Always use commas between parameters
3. **Method Binding for Callbacks**: Always use .Bind(this) for event handlers
4. **Class Initialization**: No "new" keyword for class instantiation
5. **Fat Arrow Limitations**: Only for single-line expressions

## Dependencies

### Core Dependencies
- **AutoHotkey v2 Runtime**: Required for execution
- **Windows OS**: Windows 10 or newer recommended
- **DWM API**: Desktop Window Manager for modern window styling

### Optional Components
- **Standard Library**: Collection of common utilities and functions
- **GUI Framework**: Enhanced GUI building components
- **Network Library**: HTTP and API interaction utilities
- **JSON/INI/XML Parser**: For configuration and data interchange
- **Color Management**: For theme color generation and manipulation

## Object-Oriented Programming Principles in AHK v2

### Core OOP Concepts

#### Classes and Objects
```ahk
; Class definition
class Person {
    ; Instance properties
    name := ""
    age := 0
    
    ; Static class properties (shared across all instances)
    static Count := 0
    static DefaultAge := 30
    
    ; Constructor
    __New(name, age := "") {
        this.name := name
        this.age := age != "" ? age : Person.DefaultAge
        Person.Count++
    }
    
    ; Instance methods
    SayHello() {
        return "Hello, my name is " this.name
    }
    
    ; Property accessors with backing field
    _height := 0
    Height {
        get => this._height
        set => this._height := value
    }
    
    ; Static methods
    static GetCount() {
        return "Total persons: " Person.Count
    }
    
    ; Destructor
    __Delete() {
        Person.Count--
    }
}

; Class instantiation (without "new" keyword)
john := Person("John", 25)
```

#### Inheritance and Polymorphism
```ahk
; Base class
class Animal {
    species := ""
    
    __New(species) {
        this.species := species
    }
    
    MakeSound() {
        return "Generic animal sound"
    }
}

; Derived class with inheritance
class Dog extends Animal {
    breed := ""
    
    __New(breed) {
        ; Call parent constructor
        super.__New("Canine")
        this.breed := breed
    }
    
    ; Override base method
    MakeSound() {
        return "Woof!"
    }
    
    ; Add new method
    Fetch() {
        return "Fetching the ball!"
    }
}

; Create instances
myDog := Dog("Labrador")
```

#### Encapsulation and Data Hiding
```ahk
class BankAccount {
    ; Private fields with underscore prefix
    _balance := 0
    _transactions := []
    
    ; Public interface through property accessors
    Balance {
        get => this._balance
    }
    
    ; Constructor
    __New(initialDeposit := 0) {
        if (initialDeposit > 0)
            this.Deposit(initialDeposit)
    }
    
    ; Public methods
    Deposit(amount) {
        if (amount <= 0)
            throw ValueError("Deposit amount must be positive")
            
        this._balance += amount
        this._AddTransaction("Deposit", amount)
        return this._balance
    }
    
    Withdraw(amount) {
        if (amount <= 0)
            throw ValueError("Withdrawal amount must be positive")
        
        if (amount > this._balance)
            throw ValueError("Insufficient funds")
            
        this._balance -= amount
        this._AddTransaction("Withdrawal", amount)
        return this._balance
    }
    
    GetTransactionHistory() {
        return this._transactions.Clone()
    }
    
    ; Private method (convention)
    _AddTransaction(type, amount) {
        this._transactions.Push(Map(
            "type", type,
            "amount", amount,
            "date", A_Now,
            "balance", this._balance
        ))
    }
}
```

#### Meta-Methods for Advanced OOP
```ahk
class DynamicObject {
    ; Store properties in a Map
    _properties := Map()
    
    ; Handle undefined properties using __Get and __Set
    __Get(name, params) {
        if this._properties.Has(name)
            return this._properties[name]
            
        return ""  ; Default value
    }
    
    __Set(name, params, value) {
        this._properties[name] := value
        return value
    }
    
    ; Handle undefined methods
    __Call(name, params*) {
        MsgBox "Method '" name "' does not exist."
    }
}
```

### Design Patterns in AHK v2

#### Singleton Pattern
```ahk
class ConfigManager {
    ; Private static instance
    static _instance := ""
    
    ; Configuration data
    settings := Map()
    
    ; Private constructor
    __New() {
        if (ConfigManager._instance)
            throw Error("Singleton instance already exists")
            
        this.LoadDefaults()
    }
    
    ; Public accessor for singleton instance
    static GetInstance() {
        if !ConfigManager._instance
            ConfigManager._instance := ConfigManager()
            
        return ConfigManager._instance
    }
    
    LoadDefaults() {
        this.settings := Map(
            "theme", "dark",
            "fontSize", 12,
            "saveInterval", 300
        )
    }
    
    GetSetting(key) {
        return this.settings.Has(key) ? this.settings[key] : ""
    }
    
    SetSetting(key, value) {
        this.settings[key] := value
    }
}

; Usage
config := ConfigManager.GetInstance()
```

#### Observer Pattern
```ahk
class Subject {
    ; List of observers
    observers := []
    
    ; Add an observer
    AddObserver(observer) {
        this.observers.Push(observer)
    }
    
    ; Remove an observer
    RemoveObserver(observer) {
        for i, obs in this.observers {
            if (obs == observer) {
                this.observers.RemoveAt(i)
                break
            }
        }
    }
    
    ; Notify all observers
    NotifyObservers(data := "") {
        for _, observer in this.observers
            observer.Update(this, data)
    }
}

class Observer {
    ; Method to be called when subject changes
    Update(subject, data) {
        ; Implementation in derived classes
    }
}

; Example: Theme change notification
class ThemeManager extends Subject {
    currentTheme := "light"
    
    ToggleTheme() {
        this.currentTheme := (this.currentTheme == "light") ? "dark" : "light"
        this.NotifyObservers(this.currentTheme)
    }
}

class Window extends Observer {
    name := ""
    
    __New(name) {
        this.name := name
    }
    
    Update(subject, theme) {
        MsgBox "Window '" this.name "' updated with " theme " theme."
    }
}
```

## Tool Usage Patterns

### Code Organization for OOP
```ahk
; Initialize application at the top of the script
AppMain()

; Class definitions
class AppMain {
    ; Initialize components
    __New() {
        this.config := ConfigManager.GetInstance()
        this.mainWindow := MainWindow()
        this.dataManager := DataManager()
        
        this.SetupEventHandlers()
        this.mainWindow.Show()
    }
    
    SetupEventHandlers() {
        ; Bind class methods to events
        this.mainWindow.OnExit(this.Shutdown.Bind(this))
    }
    
    Shutdown(*) {
        this.dataManager.SaveData()
        ExitApp()
    }
}

class MainWindow {
    ; Implementation
}

class DataManager {
    ; Implementation
}

class ConfigManager {
    ; Implementation
}
```

### GUI Development with OOP and Theme Support
```ahk
MainWindow()
class MainWindow {
    ; Class properties
    gui := ""
    controls := Map()
    theme := ""
    handlers := Map()
    
    __New() {
        ; Initialize GUI
        this.gui := Gui("+Resize", "Application Title")
        this.gui.SetFont("s10")
        
        ; Setup control collections
        this.controls := Map()
        this.handlers := Map()
        
        ; Get theme
        this.theme := ThemeManager.GetInstance()
        
        ; Setup the GUI layout
        this.CreateControls()
        this.BindEvents()
        this.ApplyTheme(this.theme.GetCurrentTheme())
        
        ; Register for theme changes
        this.theme.AddObserver(this)
    }
    
    CreateControls() {
        ; Create and store controls in the Map
        this.controls["input"] := this.gui.AddEdit("w300 h100 vUserInput")
        this.controls["submitBtn"] := this.gui.AddButton("Default w100", "Submit")
        this.controls["cancelBtn"] := this.gui.AddButton("w100 x+10", "Cancel")
        this.controls["statusBar"] := this.gui.AddText("xm w410 h20 vStatus", "Ready")
    }
    
    BindEvents() {
        ; Store bound method references
        this.handlers["submit"] := this.HandleSubmit.Bind(this)
        this.handlers["cancel"] := this.HandleCancel.Bind(this)
        this.handlers["size"] := this.HandleResize.Bind(this)
        this.handlers["close"] := (*) => this.gui.Hide()
        
        ; Bind events
        this.controls["submitBtn"].OnEvent("Click", this.handlers["submit"])
        this.controls["cancelBtn"].OnEvent("Click", this.handlers["cancel"])
        this.gui.OnEvent("Size", this.handlers["size"])
        this.gui.OnEvent("Close", this.handlers["close"])
    }
    
    ApplyTheme(themeData) {
        this.gui.BackColor := themeData["background"]
        
        ; Apply colors to all controls
        for _, control in this.controls
            control.Opt("Background" themeData["controlBg"])
    }
    
    ; Observer pattern implementation
    Update(subject, themeData) {
        this.ApplyTheme(themeData)
    }
    
    HandleSubmit(*) {
        ; Get form data
        formData := this.gui.Submit(false)
        
        ; Process the input
        if (formData.UserInput) {
            this.controls["statusBar"].Value := "Processing: " formData.UserInput
            ; Additional processing logic
        }
    }
    
    HandleCancel(*) {
        this.controls["input"].Value := ""
        this.controls["statusBar"].Value := "Cancelled"
    }
    
    HandleResize(sender, minMax, width, height) {
        if (minMax == -1)  ; Window is minimized
            return
            
        ; Calculate new control positions/sizes
        inputWidth := width - 20
        buttonY := height - 60
        statusY := height - 30
        
        ; Apply new positioning
        this.controls["input"].Move(, , inputWidth)
        this.controls["submitBtn"].Move(, buttonY)
        this.controls["cancelBtn"].Move(, buttonY)
        this.controls["statusBar"].Move(, statusY, inputWidth)
    }
    
    Show() {
        this.gui.Show()
    }
    
    Hide() {
        this.gui.Hide()
    }
    
    __Delete() {
        ; Clean up resources
        if this.gui
            this.gui.Destroy()
    }
}
```

### Data Management with OOP

```ahk
class DataStore {
    ; Private data
    _data := Map()
    _filename := "data.json"
    _isModified := false
    
    ; Constructor
    __New(filename := "") {
        if (filename)
            this._filename := filename
            
        this.Load()
    }
    
    ; Accessor property
    IsModified {
        get => this._isModified
    }
    
    ; Data access methods
    GetItem(key, defaultValue := "") {
        return this._data.Has(key) ? this._data[key] : defaultValue
    }
    
    SetItem(key, value) {
        this._data[key] := value
        this._isModified := true
    }
    
    RemoveItem(key) {
        if this._data.Has(key) {
            this._data.Delete(key)
            this._isModified := true
            return true
        }
        return false
    }
    
    HasItem(key) {
        return this._data.Has(key)
    }
    
    GetAllItems() {
        ; Return a copy, not the original
        result := Map()
        for key, value in this._data
            result[key] := value
        return result
    }
    
    Clear() {
        this._data := Map()
        this._isModified := true
    }
    
    ; Data persistence
    Load() {
        try {
            if FileExist(this._filename) {
                fileContent := FileRead(this._filename)
                this._data := JSON.Parse(fileContent)
                this._isModified := false
            }
        } catch Error as e {
            MsgBox "Error loading data: " e.Message
            this._data := Map()
        }
    }
    
    Save() {
        if this._isModified {
            try {
                jsonStr := JSON.Stringify(this._data)
                FileWrite(jsonStr, this._filename)
                this._isModified := false
                return true
            } catch Error as e {
                MsgBox "Error saving data: " e.Message
                return false
            }
        }
        return true  ; No changes to save
    }
}
