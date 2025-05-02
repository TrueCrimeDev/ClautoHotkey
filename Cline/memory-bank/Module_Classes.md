# Module: AHK v2 Classes and Object-Oriented Programming

## Core Concepts

### Class Definition and Instantiation

AHK v2 uses a modern class-based syntax for object-oriented programming. Classes serve as templates (blueprints) for creating objects with similar properties and methods.

```ahk
; Basic class definition
class Example {
    ; Properties (instance variables)
    property1 := "default value"
    property2 := 0
    
    ; Constructor - called when creating a new instance
    __New(param1 := "", param2 := 0) {
        this.property1 := param1 ? param1 : this.property1
        this.property2 := param2 ? param2 : this.property2
    }
    
    ; Instance method
    Method1() {
        return "Result from Method1"
    }
    
    ; Method with parameters
    Method2(param) {
        return "Processing: " param
    }
}

; Class instantiation - CORRECT (no "new" keyword)
instance := Example("value1", 42)

; INCORRECT - Do not use "new" keyword
; instance := new Example("value1", 42)
```

### Properties and Methods

```ahk
class User {
    ; Instance properties
    name := ""
    email := ""
    
    ; Static property (shared by all instances)
    static count := 0
    
    ; Constructor
    __New(name := "", email := "") {
        this.name := name
        this.email := email
        User.count++
    }
    
    ; Instance method
    GetInfo() {
        return "Name: " this.name "`nEmail: " this.email
    }
    
    ; Static method (called on the class itself)
    static GetCount() {
        return "Total users: " User.count
    }
}

; Usage
user1 := User("John", "john@example.com")
user2 := User("Jane", "jane@example.com")

MsgBox(user1.GetInfo())
MsgBox(User.GetCount())  ; Shows "Total users: 2"
```

### Property Accessors

Property accessors provide controlled access to class properties, allowing for validation, computation, or side effects when reading or writing a property.

```ahk
class Temperature {
    ; Backing field (private by convention with underscore)
    _celsius := 0
    
    ; Constructor
    __New(celsius := 0) {
        this.Celsius := celsius  ; Uses the property setter
    }
    
    ; Property accessor for Celsius
    Celsius {
        ; Getter - called when reading the property
        get => this._celsius
        
        ; Setter - called when writing to the property
        set {
            if (value < -273.15)
                throw ValueError("Temperature cannot be below absolute zero")
            this._celsius := value
        }
    }
    
    ; Computed property - converts Celsius to Fahrenheit
    Fahrenheit {
        ; Getter - computes the value when the property is read
        get => (this._celsius * 9/5) + 32
        
        ; Setter - converts Fahrenheit to Celsius and stores it
        set => this._celsius := (value - 32) * 5/9
    }
}

; Usage
temp := Temperature(25)
MsgBox("Celsius: " temp.Celsius)      ; Shows 25
MsgBox("Fahrenheit: " temp.Fahrenheit) ; Shows 77

temp.Fahrenheit := 68                 ; Sets Celsius to 20
MsgBox("Celsius after setting F: " temp.Celsius)  ; Shows 20
```

## Advanced OOP Concepts

### Inheritance

Inheritance allows a class to inherit properties and methods from a parent class, facilitating code reuse and hierarchical relationships.

```ahk
; Base (parent) class
class Vehicle {
    make := ""
    model := ""
    year := 0
    
    __New(make := "", model := "", year := 0) {
        this.make := make
        this.model := model
        this.year := year
    }
    
    GetInfo() {
        return this.year " " this.make " " this.model
    }
    
    Start() {
        return "Vehicle started"
    }
}

; Derived (child) class
class Car extends Vehicle {
    numDoors := 4
    
    __New(make := "", model := "", year := 0, numDoors := 4) {
        ; Call parent constructor first
        super.__New(make, model, year)
        this.numDoors := numDoors
    }
    
    ; Override parent method
    GetInfo() {
        return super.GetInfo() " (" this.numDoors "-door)"
    }
    
    ; Add new method
    Honk() {
        return "Beep beep!"
    }
}

; Usage
myCar := Car("Toyota", "Corolla", 2022, 4)
MsgBox(myCar.GetInfo())  ; Shows "2022 Toyota Corolla (4-door)"
MsgBox(myCar.Start())    ; Shows "Vehicle started" (inherited)
MsgBox(myCar.Honk())     ; Shows "Beep beep!" (new method)
```

### Encapsulation and Data Hiding

Encapsulation involves bundling data and methods that operate on that data into a single unit (the class), and restricting direct access to some of that data.

```ahk
class BankAccount {
    ; Private fields (by convention with underscore)
    _balance := 0
    _accountNumber := ""
    _transactions := []
    
    ; Constructor
    __New(accountNumber, initialDeposit := 0) {
        this._accountNumber := accountNumber
        
        if (initialDeposit > 0)
            this.Deposit(initialDeposit)
    }
    
    ; Read-only property for account number
    AccountNumber {
        get => this._accountNumber
    }
    
    ; Read-only property for balance
    Balance {
        get => this._balance
    }
    
    ; Public methods for interacting with the account
    Deposit(amount) {
        if (amount <= 0)
            throw ValueError("Deposit amount must be positive")
            
        this._balance += amount
        this._RecordTransaction("Deposit", amount)
        return this._balance
    }
    
    Withdraw(amount) {
        if (amount <= 0)
            throw ValueError("Withdrawal amount must be positive")
            
        if (amount > this._balance)
            throw ValueError("Insufficient funds")
            
        this._balance -= amount
        this._RecordTransaction("Withdrawal", amount)
        return this._balance
    }
    
    GetTransactionHistory() {
        ; Return a copy, not the original
        return this._transactions.Clone()
    }
    
    ; Private method (by convention)
    _RecordTransaction(type, amount) {
        this._transactions.Push(Map(
            "type", type,
            "amount", amount,
            "timestamp", A_Now,
            "balance", this._balance
        ))
    }
}

; Usage
account := BankAccount("12345", 1000)
account.Deposit(500)
account.Withdraw(200)

MsgBox("Current balance: " account.Balance)

; Cannot directly change balance
; account.Balance := 5000  ; Error - no setter

; Cannot directly access private field
; account._balance := 5000 ; Works but violates encapsulation
```

### Polymorphism

Polymorphism allows objects of different classes to be treated as instances of a common superclass, enabling flexible and extensible code.

```ahk
; Base class
class Shape {
    ; Abstract method (to be implemented by derived classes)
    Area() {
        throw MethodError("Method must be implemented in derived class")
    }
    
    ; Common method for all shapes
    Description() {
        return "This is a shape"
    }
}

; Derived classes
class Circle extends Shape {
    radius := 0
    
    __New(radius) {
        this.radius := radius
    }
    
    ; Implement Area method
    Area() {
        return 3.14159 * this.radius * this.radius
    }
    
    ; Override Description
    Description() {
        return "This is a circle with radius " this.radius
    }
}

class Rectangle extends Shape {
    width := 0
    height := 0
    
    __New(width, height) {
        this.width := width
        this.height := height
    }
    
    ; Implement Area method
    Area() {
        return this.width * this.height
    }
    
    ; Override Description
    Description() {
        return "This is a rectangle with dimensions " this.width "×" this.height
    }
}

; Usage - polymorphic function that works with any Shape
CalculateTotalArea(shapes) {
    totalArea := 0
    
    for _, shape in shapes {
        ; We can use Area() without knowing the specific type
        totalArea += shape.Area()
    }
    
    return totalArea
}

; Create different shapes
shapes := [
    Circle(5),
    Rectangle(4, 6),
    Circle(3)
]

; Process all shapes together
for _, shape in shapes
    MsgBox(shape.Description() "`nArea: " shape.Area())

MsgBox("Total area: " CalculateTotalArea(shapes))
```

## Meta-Methods and Special Functions

### Meta-Methods for Handling Undefined Members

AHK v2 provides several meta-methods that allow classes to dynamically handle operations on undefined properties or methods.

```ahk
class DynamicObject {
    ; Internal storage
    _properties := Map()
    
    ; Called when accessing an undefined property
    __Get(name, params) {
        if this._properties.Has(name)
            return this._properties[name]
        
        return ""  ; Default value
    }
    
    ; Called when setting an undefined property
    __Set(name, params, value) {
        this._properties[name] := value
        return value
    }
    
    ; Called when invoking an undefined method
    __Call(name, params*) {
        MsgBox("Method '" name "' does not exist")
        
        ; Example: Create a method on-the-fly
        if (name = "Greet") {
            if (params.Length)
                return "Hello, " params[1] "!"
            else
                return "Hello!"
        }
    }
}

; Usage
obj := DynamicObject()

; Using __Set
obj.name := "John"
obj.age := 30

; Using __Get
MsgBox(obj.name)  ; Shows "John"
MsgBox(obj.age)   ; Shows 30
MsgBox(obj.unknown)  ; Shows "" (default value)

; Using __Call
obj.SayHello()  ; Shows "Method 'SayHello' does not exist"
MsgBox(obj.Greet("World"))  ; Shows "Hello, World!"
```

### Constructor and Destructor

The constructor `__New()` is called when creating a new instance, and the destructor `__Delete()` is called when the instance is being destroyed.

```ahk
class ResourceManager {
    _resources := []
    
    __New() {
        MsgBox("ResourceManager created")
        this.AllocateResources()
    }
    
    AllocateResources() {
        ; Simulate resource allocation
        this._resources.Push("Resource 1")
        this._resources.Push("Resource 2")
        MsgBox("Resources allocated: " this._resources.Length)
    }
    
    __Delete() {
        ; Clean up when the object is destroyed
        MsgBox("ResourceManager being destroyed, cleaning up resources...")
        this._resources := []
    }
}

; Create a scoped instance
Test() {
    ; Local instance will be automatically destroyed when the function returns
    local manager := ResourceManager()
    
    ; Use the manager
    MsgBox("Using resource manager")
    
    ; The __Delete method will be called when the function returns
    return
}

Test()
```

## Design Patterns

### Singleton Pattern

The Singleton pattern ensures a class has only one instance and provides a global point of access to it.

```ahk
class AppConfig {
    ; Private static instance
    static _instance := ""
    
    ; Configuration settings
    settings := Map()
    
    ; Private constructor
    __New() {
        if (AppConfig._instance)
            throw Error("Cannot create a new instance of Singleton")
            
        ; Default settings
        this.settings := Map(
            "theme", "light",
            "fontSize", 12,
            "debug", false
        )
    }
    
    ; Public method to get the singleton instance
    static GetInstance() {
        if (!AppConfig._instance)
            AppConfig._instance := AppConfig()
            
        return AppConfig._instance
    }
    
    ; Get a setting value
    GetSetting(key, defaultValue := "") {
        return this.settings.Has(key) ? this.settings[key] : defaultValue
    }
    
    ; Set a setting value
    SetSetting(key, value) {
        this.settings[key] := value
    }
}

; Usage
config := AppConfig.GetInstance()
config.SetSetting("theme", "dark")

; Later in code, access the same instance
anotherReference := AppConfig.GetInstance()
MsgBox(anotherReference.GetSetting("theme"))  ; Shows "dark"

; Attempting to create a new instance will throw an error
; badInstance := AppConfig()  ; Error
```

### Observer Pattern

The Observer pattern defines a one-to-many dependency between objects so that when one object changes state, all its dependents are notified and updated automatically.

```ahk
class Subject {
    _observers := []
    
    AddObserver(observer) {
        this._observers.Push(observer)
    }
    
    RemoveObserver(observer) {
        for i, obs in this._observers {
            if (obs == observer) {
                this._observers.RemoveAt(i)
                break
            }
        }
    }
    
    NotifyObservers(data := "") {
        for _, observer in this._observers
            observer.Update(this, data)
    }
}

class Observer {
    Update(subject, data) {
        ; To be implemented by concrete observers
    }
}

; Example implementation: Theme manager
class ThemeManager extends Subject {
    _currentTheme := "light"
    
    ; Constructor
    __New() {
        this._themes := Map(
            "light", Map(
                "background", "FFFFFF",
                "text", "000000",
                "accent", "0078D7"
            ),
            "dark", Map(
                "background", "202020",
                "text", "FFFFFF",
                "accent", "0095FF"
            )
        )
    }
    
    ; Get the current theme data
    GetCurrentTheme() {
        return this._themes[this._currentTheme]
    }
    
    ; Change the theme and notify observers
    SetTheme(themeName) {
        if (!this._themes.Has(themeName))
            return false
            
        if (this._currentTheme != themeName) {
            this._currentTheme := themeName
            this.NotifyObservers(this.GetCurrentTheme())
        }
        
        return true
    }
    
    ; Toggle between light and dark
    ToggleTheme() {
        this.SetTheme(this._currentTheme == "light" ? "dark" : "light")
    }
}

; Example observer: A window that updates when theme changes
class ThemeableWindow extends Observer {
    __New(title := "Window") {
        this.gui := Gui("+Resize", title)
        this.controls := Map()
        
        ; Create some controls
        this.controls["text"] := this.gui.AddText("w300", "Sample Text")
        this.controls["edit"] := this.gui.AddEdit("w300 h100", "Edit content")
        this.controls["button"] := this.gui.AddButton("w100", "OK")
    }
    
    ; Observer method - called when theme changes
    Update(subject, themeData) {
        ; Apply theme to the window
        this.gui.BackColor := themeData["background"]
        
        ; Update text color
        for _, control in this.controls {
            if (control.Type == "Text")
                control.Opt("c" themeData["text"])
        }
        
        MsgBox("Theme updated to " (themeData["background"] == "FFFFFF" ? "light" : "dark"))
    }
    
    Show() {
        this.gui.Show()
    }
}

; Usage
themeManager := ThemeManager()
window := ThemeableWindow("Themed Window")

; Register for theme notifications
themeManager.AddObserver(window)

; Show the window with initial theme
window.Update(themeManager, themeManager.GetCurrentTheme())
window.Show()

; Later, change the theme
themeManager.ToggleTheme()
```

## Best Practices

### 1. Use Maps for Data Structures

Always use `Map()` for key-value data structures, never object literals.

```ahk
; CORRECT
config := Map(
    "width", 800,
    "height", 600,
    "title", "My Application"
)

; INCORRECT - Will cause issues
; config := {width: 800, height: 600, title: "My Application"}
```

### 2. Method Binding for Callbacks

Always bind class methods using `.Bind(this)` when passing them as callbacks.

```ahk
class MyApp {
    __New() {
        this.gui := Gui()
        
        ; CORRECT - use proper binding
        this.gui.AddButton("w200", "Click Me").OnEvent("Click", this.HandleClick.Bind(this))
        
        ; INCORRECT - 'this' will not refer to the MyApp instance inside HandleClick
        ; this.gui.AddButton("w200", "Click Me").OnEvent("Click", this.HandleClick)
    }
    
    HandleClick(*) {
        MsgBox("Button clicked")
    }
}
```

### 3. Use Property Accessors Instead of Getter/Setter Methods

```ahk
class User {
    ; CORRECT - Use property accessors with backing field
    _name := ""
    
    Name {
        get => this._name
        set => this._name := value
    }
    
    ; INCORRECT - Using methods instead of properties
    ; GetName() {
    ;     return this._name
    ; }
    ; 
    ; SetName(value) {
    ;     this._name := value
    ; }
}
```

### 4. Initialize Classes at the Top of the Script

```ahk
; CORRECT - Initialize at the top
MainApp()

; Class definitions
class MainApp {
    __New() {
        ; Implementation
    }
}

; INCORRECT - Initialization after definition
; class MainApp {
;     __New() {
;         ; Implementation
;     }
; }
; 
; app := MainApp()
```

### 5. Use Static Properties for Shared Configuration

```ahk
class AppSettings {
    ; CORRECT - Static properties for shared configuration
    static Config := Map(
        "version", "1.0",
        "appName", "My App",
        "maxRetries", 3
    )
}

; Access anywhere in the code
version := AppSettings.Config["version"]

; INCORRECT - Using global variables
; global AppConfig := Map(
;     "version", "1.0",
;     "appName", "My App",
;     "maxRetries", 3
; )
```

### 6. Implement Error Handling with Try/Catch

```ahk
class FileManager {
    ReadFile(filename) {
        ; CORRECT - Proper error handling
        try {
            content := FileRead(filename)
            return content
        } catch Error as e {
            MsgBox("Error reading file: " e.Message)
            return ""
        }
        
        ; INCORRECT - No error handling
        ; return FileRead(filename)
    }
}
```

### 7. Use Proper Error Handling for Method Calls

```ahk
class DynamicHandler {
    ; CORRECT - Implement __Call for handling undefined methods
    __Call(method, args*) {
        MsgBox("Error: Method '" method "' does not exist in " this.__Class)
    }
}
```

### 8. Organize Controls in Maps

```ahk
class MyWindow {
    __New() {
        this.gui := Gui()
        
        ; CORRECT - Store controls in a Map
        this.controls := Map()
        this.controls["input"] := this.gui.AddEdit("w300")
        this.controls["submit"] := this.gui.AddButton("Default", "Submit")
        
        ; INCORRECT - Store as separate properties
        ; this.input := this.gui.AddEdit("w300")
        ; this.submit := this.gui.AddButton("Default", "Submit")
    }
}
