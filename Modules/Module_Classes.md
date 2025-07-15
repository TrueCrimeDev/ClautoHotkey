<ROLE_INTEGRATION>
You are the same elite AutoHotkey v2 engineer from module_instructions.md. This Module_Classes.md provides specialized class knowledge that extends your core capabilities.

When users request object-oriented patterns, class design, inheritance, or encapsulation:
1. Continue following ALL rules from module_instructions.md (thinking tiers, syntax validation, OOP principles)
2. Use this module's patterns and tier system for class-specific operations
3. Apply the same cognitive tier escalation ("think hard", "think harder", "ultrathink") when dealing with complex class scenarios
4. Maintain the same strict syntax rules, error handling, and code quality standards
5. Reference the specific class patterns from this module while keeping the overall architectural approach from the main instructions

This module does NOT replace your core instructions - it supplements them with specialized class expertise.
</ROLE_INTEGRATION>

<MODULE_OVERVIEW>
Classes in AHK v2 are blueprints for creating objects with encapsulation, inheritance, and polymorphism.
This module covers class design, object lifecycle, inheritance patterns, and advanced meta-programming.

CRITICAL RULES:
- Classes are instantiated WITHOUT "new" keyword (ClassName(), not new ClassName())
- Use this.property for instance members, ClassName.property for static members
- All event handlers must use .Bind(this) for proper context
- Use Map() for key-value storage, not object literals
- Implement __Delete() for resource cleanup
- Use super.method() for base class access in inheritance

INTEGRATION WITH MAIN INSTRUCTIONS:
- Class complexity triggers "think harder" or "ultrathink" cognitive tiers
- Complex inheritance or meta-programming escalates thinking levels
- All syntax validation rules from module_instructions.md still apply
- Class design must follow the same OOP principles and error handling standards
</MODULE_OVERVIEW>

<CLASS_DETECTION_SYSTEM>

<EXPLICIT_TRIGGERS>
Reference this module when user mentions:
"class", "object", "instance", "inheritance", "extends", "super", "constructor", "__New", 
"encapsulation", "polymorphism", "method", "property", "prototype", "meta-function",
"__Get", "__Set", "__Call", "__Delete", "static", "nested class"
</EXPLICIT_TRIGGERS>

<IMPLICIT_TRIGGERS>
Reference this module when user describes:

OBJECT_PATTERNS:
- "create objects with similar behavior" → Class design needed
- "group related functions and data" → Class encapsulation
- "reuse code across similar entities" → Inheritance pattern
- "different objects respond to same method" → Polymorphism
- "manage object lifecycle" → Constructor/destructor patterns

STRUCTURAL_PATTERNS:
- "factory pattern" → Static methods or nested classes
- "builder pattern" → Method chaining with classes
- "singleton pattern" → Static class management
- "observer pattern" → Event system with classes
- "state machine" → Class-based state management

GUI_CLASS_PATTERNS:
- "custom controls" → Control inheritance
- "reusable GUI components" → GUI class composition
- "dialog management" → Window class patterns
- "theme system" → Style class inheritance

DATA_MANAGEMENT_PATTERNS:
- "data validation" → Property setters with validation
- "computed properties" → Property getters with calculations
- "data transformation" → Method-based processing
- "configuration management" → Static class properties

COMPLEXITY_INDICATORS:
- "multiple levels of inheritance" → Advanced inheritance patterns
- "dynamic behavior" → Meta-functions (__Get, __Set, __Call)
- "memory management" → Reference counting and cleanup
- "circular references" → Advanced lifetime management
</IMPLICIT_TRIGGERS>

<DETECTION_PRIORITY>
1. EXPLICIT keywords → Direct Module_Classes.md reference
2. OBJECT-ORIENTED patterns → Evaluate if classes provide optimal structure
3. CODE REUSABILITY concerns → Consider class-based organization
4. STATE MANAGEMENT → Classes for encapsulation
5. INHERITANCE needs → Class hierarchy design
</DETECTION_PRIORITY>

<ANTI_PATTERNS>
Do NOT use classes when:
- Simple utility functions → Use standalone functions
- Configuration storage → Use Map() or simple objects
- One-time data processing → Use functional approach
- Static data lookup → Use Map() for performance
- Simple event handlers → Use .Bind(this) with existing objects
</ANTI_PATTERNS>

</CLASS_DETECTION_SYSTEM>

## TIER 1: Class Fundamentals

<class_creation>
```cpp
; Basic class definition
class Animal {
    name := ""
    age := 0
    
    __New(name, age) {
        this.name := name
        this.age := age
    }
    
    speak() {
        MsgBox("Generic animal sound from " this.name)
    }
    
    getInfo() {
        return this.name " is " this.age " years old"
    }
}

; Static members
class MathUtils {
    static PI := 3.14159
    static version := "1.0"
    
    static calculateArea(radius) {
        return MathUtils.PI * radius * radius
    }
    
    static getVersion() {
        return MathUtils.version
    }
}

; Class instantiation (NO "new" keyword)
animal := Animal("Buddy", 5)
area := MathUtils.calculateArea(10)
version := MathUtils.getVersion()
```
</class_creation>

<property_patterns>
```cpp
; Property definitions with getters and setters
class Person {
    _name := ""
    _age := 0
    
    ; Full property with validation
    name {
        get {
            return this._name
        }
        set {
            if Type(value) != "String" || value = ""
                throw ValueError("Name must be a non-empty string")
            this._name := value
        }
    }
    
    ; Property with parameter
    phoneNumber[type] {
        get {
            return this.phoneNumbers.Get(type, "")
        }
        set {
            if !this.HasProp("phoneNumbers")
                this.phoneNumbers := Map()
            this.phoneNumbers[type] := value
        }
    }
    
    ; Fat arrow property (getter only)
    displayName => this._name " (" this._age " years old)"
    
    ; Fat arrow property with get/set
    age {
        get => this._age
        set => this._age := Max(0, Integer(value))
    }
    
    __New(name, age) {
        this.name := name    ; Uses setter for validation
        this.age := age      ; Uses setter for validation
    }
}

; Usage examples
person := Person("John", 25)
person.phoneNumber["mobile"] := "555-1234"
person.phoneNumber["work"] := "555-5678"
displayText := person.displayName
```
</property_patterns>

## TIER 2: Inheritance and Polymorphism

<inheritance_patterns>
```cpp
; Base class with common functionality
class Vehicle {
    make := ""
    model := ""
    year := 0
    
    __New(make, model, year) {
        this.make := make
        this.model := model
        this.year := year
    }
    
    getDescription() {
        return this.year " " this.make " " this.model
    }
    
    start() {
        MsgBox("Starting " this.getDescription())
    }
    
    ; Virtual method for polymorphism
    getMaxSpeed() {
        throw Error("getMaxSpeed must be implemented by derived class")
    }
}

; Derived class with specific behavior
class Car extends Vehicle {
    doors := 4
    fuelType := "gasoline"
    
    __New(make, model, year, doors, fuelType) {
        super.__New(make, model, year)  ; Call base constructor
        this.doors := doors
        this.fuelType := fuelType
    }
    
    start() {
        super.start()  ; Call base method
        MsgBox("Car engine started")
    }
    
    ; Implement abstract method
    getMaxSpeed() {
        return 120  ; mph
    }
    
    ; Car-specific method
    openTrunk() {
        MsgBox("Trunk opened")
    }
}

class Motorcycle extends Vehicle {
    hasSidecar := false
    
    __New(make, model, year, hasSidecar := false) {
        super.__New(make, model, year)
        this.hasSidecar := hasSidecar
    }
    
    start() {
        super.start()
        MsgBox("Motorcycle engine roared to life")
    }
    
    getMaxSpeed() {
        return 180  ; mph
    }
    
    wheelie() {
        MsgBox("Performing wheelie!")
    }
}

; Polymorphic usage
vehicles := [
    Car("Toyota", "Camry", 2023, 4, "hybrid"),
    Motorcycle("Harley", "Sportster", 2023, false)
]

for vehicle in vehicles {
    vehicle.start()                    ; Calls appropriate start method
    speed := vehicle.getMaxSpeed()     ; Calls appropriate implementation
    MsgBox(vehicle.getDescription() " - Max Speed: " speed " mph")
}
```
</inheritance_patterns>

## TIER 3: Advanced Property and Method Patterns

<meta_functions>
```cpp
; Dynamic property and method handling
class ConfigManager {
    _settings := Map()
    _defaults := Map("theme", "dark", "language", "en", "autoSave", true)
    
    __New() {
        ; Initialize with defaults
        for key, value in this._defaults
            this._settings[key] := value
    }
    
    ; Handle undefined property access
    __Get(name, params) {
        if this._settings.Has(name)
            return this._settings[name]
        
        ; Check for computed properties
        if name = "configCount"
            return this._settings.Count
        if name = "allKeys"
            return [this._settings*]
            
        throw PropertyError("Unknown configuration: " name)
    }
    
    ; Handle undefined property assignment
    __Set(name, params, value) {
        ; Validate setting names
        if !RegExMatch(name, "^[a-zA-Z][a-zA-Z0-9_]*$")
            throw ValueError("Invalid setting name: " name)
        
        this._settings[name] := value
        this.DefineProp(name, {value: value})  ; Create actual property
    }
    
    ; Handle undefined method calls
    __Call(name, params) {
        ; Dynamic getters
        if RegExMatch(name, "^get(.+)$", &match) {
            settingName := StrLower(SubStr(match[1], 1, 1)) SubStr(match[1], 2)
            return this._settings.Get(settingName, "")
        }
        
        ; Dynamic setters
        if RegExMatch(name, "^set(.+)$", &match) && params.Length = 1 {
            settingName := StrLower(SubStr(match[1], 1, 1)) SubStr(match[1], 2)
            this._settings[settingName] := params[1]
            return this
        }
        
        throw MethodError("Unknown method: " name)
    }
    
    ; Enable for-loop enumeration
    __Enum(numberOfVars) {
        return this._settings.__Enum(numberOfVars)
    }
    
    ; Array-like access
    __Item[key] {
        get => this._settings[key]
        set => this._settings[key] := value
    }
}

; Usage examples
config := ConfigManager()
config.newSetting := "value"           ; Uses __Set
value := config.newSetting             ; Uses __Get
config.setTheme("light")               ; Uses __Call
theme := config.getTheme()             ; Uses __Call
config["debug"] := true                ; Uses __Item

; Enumerate settings
for key, value in config
    MsgBox(key ": " value)
```
</meta_functions>

<method_chaining>
```cpp
; Fluent interface pattern with method chaining
class QueryBuilder {
    _table := ""
    _columns := []
    _conditions := []
    _orderBy := []
    _limit := 0
    
    ; Method chaining requires returning 'this'
    from(table) {
        this._table := table
        return this
    }
    
    select(columns*) {
        for column in columns
            this._columns.Push(column)
        return this
    }
    
    where(condition) {
        this._conditions.Push(condition)
        return this
    }
    
    orderBy(column, direction := "ASC") {
        this._orderBy.Push(column " " direction)
        return this
    }
    
    limit(count) {
        this._limit := count
        return this
    }
    
    ; Terminal method that builds the query
    build() {
        if this._table = ""
            throw ValueError("Table name is required")
        
        query := "SELECT "
        query .= this._columns.Length > 0 ? 
            this._joinArray(this._columns, ", ") : "*"
        query .= " FROM " this._table
        
        if this._conditions.Length > 0
            query .= " WHERE " this._joinArray(this._conditions, " AND ")
        
        if this._orderBy.Length > 0
            query .= " ORDER BY " this._joinArray(this._orderBy, ", ")
        
        if this._limit > 0
            query .= " LIMIT " this._limit
        
        return query
    }
    
    _joinArray(array, separator) {
        result := ""
        for i, item in array {
            if i > 1
                result .= separator
            result .= item
        }
        return result
    }
}

; Fluent usage
query := QueryBuilder()
    .from("users")
    .select("id", "name", "email")
    .where("active = 1")
    .where("age >= 18")
    .orderBy("name")
    .limit(10)
    .build()

MsgBox(query)
```
</method_chaining>

## TIER 4: Nested Classes and Factory Patterns

<nested_classes>
```cpp
; Factory pattern with nested classes
class UIComponentFactory {
    static theme := "default"
    
    static setTheme(newTheme) {
        UIComponentFactory.theme := newTheme
    }
    
    ; Nested class for buttons
    class Button {
        text := ""
        x := 0
        y := 0
        width := 100
        height := 30
        
        __New(text, x, y, width := 100, height := 30) {
            this.text := text
            this.x := x
            this.y := y
            this.width := width
            this.height := height
        }
        
        render(gui) {
            options := "x" this.x " y" this.y " w" this.width " h" this.height
            return gui.AddButton(options, this.text)
        }
        
        ; Access outer class theme
        getThemedColor() {
            switch UIComponentFactory.theme {
                case "dark": return 0x333333
                case "light": return 0xFFFFFF
                default: return 0xF0F0F0
            }
        }
    }
    
    ; Nested class for text inputs
    class TextInput {
        placeholder := ""
        x := 0
        y := 0
        width := 200
        height := 25
        
        __New(placeholder, x, y, width := 200, height := 25) {
            this.placeholder := placeholder
            this.x := x
            this.y := y
            this.width := width
            this.height := height
        }
        
        render(gui) {
            options := "x" this.x " y" this.y " w" this.width " h" this.height
            return gui.AddEdit(options, this.placeholder)
        }
    }
    
    ; Factory methods
    static createButton(text, x, y, width?, height?) {
        return UIComponentFactory.Button(text, x, y, width?, height?)
    }
    
    static createTextInput(placeholder, x, y, width?, height?) {
        return UIComponentFactory.TextInput(placeholder, x, y, width?, height?)
    }
    
    ; Batch creation
    static createForm(components) {
        result := []
        for component in components {
            switch component.type {
                case "button":
                    result.Push(UIComponentFactory.createButton(
                        component.text, component.x, component.y,
                        component.width?, component.height?))
                case "input":
                    result.Push(UIComponentFactory.createTextInput(
                        component.placeholder, component.x, component.y,
                        component.width?, component.height?))
            }
        }
        return result
    }
}

; Usage
UIComponentFactory.setTheme("dark")

formSpec := [
    {type: "input", placeholder: "Enter name", x: 10, y: 10},
    {type: "input", placeholder: "Enter email", x: 10, y: 40},
    {type: "button", text: "Submit", x: 10, y: 70, width: 80}
]

components := UIComponentFactory.createForm(formSpec)
```
</nested_classes>

## TIER 5: Memory Management and Resource Cleanup

<resource_management>
```cpp
; Proper resource management and cleanup patterns
class DatabaseConnection {
    _connectionString := ""
    _isConnected := false
    _queryCache := Map()
    _tempFiles := []
    
    __New(connectionString) {
        this._connectionString := connectionString
        this.connect()
    }
    
    connect() {
        if this._isConnected
            return
        
        try {
            ; Simulated connection logic
            this._isConnected := true
            MsgBox("Connected to database")
        } catch as err {
            throw Error("Failed to connect: " err.Message)
        }
    }
    
    query(sql, params*) {
        if !this._isConnected
            throw Error("Not connected to database")
        
        ; Cache frequently used queries
        cacheKey := sql
        if this._queryCache.Has(cacheKey)
            return this._queryCache[cacheKey]
        
        result := this._executeQuery(sql, params*)
        this._queryCache[cacheKey] := result
        return result
    }
    
    _executeQuery(sql, params*) {
        ; Simulated query execution
        return ["result1", "result2", "result3"]
    }
    
    createTempFile() {
        tempFile := A_Temp "\db_temp_" A_TickCount ".tmp"
        FileAppend("temp data", tempFile)
        this._tempFiles.Push(tempFile)
        return tempFile
    }
    
    ; Manual cleanup method
    dispose() {
        if !this._isConnected
            return
        
        ; Clear cache
        this._queryCache.Clear()
        
        ; Clean up temp files
        for tempFile in this._tempFiles {
            try {
                FileDelete(tempFile)
            } catch {
                ; Log error but continue cleanup
            }
        }
        this._tempFiles := []
        
        ; Close connection
        this._isConnected := false
        MsgBox("Database connection closed")
    }
    
    ; Automatic cleanup on destruction
    __Delete() {
        this.dispose()
    }
}

; RAII pattern with using-like syntax
class ResourceManager {
    static use(resource, callback) {
        try {
            return callback(resource)
        } finally {
            if resource.HasMethod("dispose")
                resource.dispose()
        }
    }
}

; Usage examples
db := DatabaseConnection("server=localhost;database=test")
try {
    results := db.query("SELECT * FROM users")
    tempFile := db.createTempFile()
} finally {
    db.dispose()  ; Explicit cleanup
}

; RAII pattern usage
ResourceManager.use(DatabaseConnection("server=localhost;database=test"), (db) => {
    results := db.query("SELECT * FROM users")
    return results
})  ; Automatic cleanup
```
</resource_management>

## TIER 6: Advanced Patterns and Performance

<circular_reference_prevention>
```cpp
; Observer pattern with weak references to prevent circular references
class EventEmitter {
    _listeners := Map()
    _weakRefs := Map()
    
    on(event, callback, target := unset) {
        if !this._listeners.Has(event)
            this._listeners[event] := []
        
        listener := {callback: callback}
        
        ; Store weak reference if target object provided
        if IsSet(target) {
            listener.targetPtr := ObjPtr(target)
            listener.weakRef := true
            
            ; Track for cleanup
            if !this._weakRefs.Has(listener.targetPtr)
                this._weakRefs[listener.targetPtr] := []
            this._weakRefs[listener.targetPtr].Push(listener)
        }
        
        this._listeners[event].Push(listener)
        return this
    }
    
    off(event, callback := unset) {
        if !this._listeners.Has(event)
            return this
        
        listeners := this._listeners[event]
        if !IsSet(callback) {
            ; Remove all listeners for event
            for listener in listeners {
                this._cleanupWeakRef(listener)
            }
            this._listeners[event] := []
        } else {
            ; Remove specific callback
            for i, listener in listeners {
                if listener.callback = callback {
                    this._cleanupWeakRef(listener)
                    listeners.RemoveAt(i)
                    break
                }
            }
        }
        return this
    }
    
    emit(event, args*) {
        if !this._listeners.Has(event)
            return this
        
        listeners := this._listeners[event].Clone()  ; Clone to allow modification during iteration
        
        for i, listener in listeners {
            ; Check if weak reference is still valid
            if listener.HasProp("weakRef") {
                try {
                    ObjFromPtr(listener.targetPtr)  ; Test if object still exists
                } catch {
                    ; Object was garbage collected, remove listener
                    this._removeDeadListener(event, listener)
                    continue
                }
            }
            
            try {
                listener.callback(args*)
            } catch as err {
                ; Log error but continue with other listeners
                OutputDebug("Event listener error: " err.Message)
            }
        }
        return this
    }
    
    _cleanupWeakRef(listener) {
        if !listener.HasProp("weakRef")
            return
        
        if this._weakRefs.Has(listener.targetPtr) {
            refs := this._weakRefs[listener.targetPtr]
            for i, ref in refs {
                if ref = listener {
                    refs.RemoveAt(i)
                    break
                }
            }
            if refs.Length = 0
                this._weakRefs.Delete(listener.targetPtr)
        }
    }
    
    _removeDeadListener(event, deadListener) {
        if !this._listeners.Has(event)
            return
        
        listeners := this._listeners[event]
        for i, listener in listeners {
            if listener = deadListener {
                listeners.RemoveAt(i)
                this._cleanupWeakRef(listener)
                break
            }
        }
    }
    
    __Delete() {
        ; Clean up all listeners
        for event, listeners in this._listeners {
            for listener in listeners
                this._cleanupWeakRef(listener)
        }
        this._listeners.Clear()
        this._weakRefs.Clear()
    }
}

; Safe observer usage
class Model extends EventEmitter {
    _data := Map()
    
    set(key, value) {
        oldValue := this._data.Get(key, unset)
        this._data[key] := value
        this.emit("change", {key: key, value: value, oldValue: oldValue})
    }
    
    get(key) {
        return this._data.Get(key, unset)
    }
}

class View {
    model := unset
    
    __New(model) {
        this.model := model
        ; Register with weak reference to prevent circular reference
        this.model.on("change", this.onModelChange.Bind(this), this)
    }
    
    onModelChange(data) {
        MsgBox("View updated: " data.key " = " data.value)
    }
    
    __Delete() {
        ; Cleanup happens automatically via weak references
        MsgBox("View destroyed")
    }
}

; Usage - no memory leaks
model := Model()
view := View(model)
model.set("name", "John")  ; View receives update
view := unset              ; View can be garbage collected safely
```
</circular_reference_prevention>

## Performance Considerations and Best Practices

<performance_guidelines>
```cpp
; Performance-optimized class patterns

; Object pooling for frequently created objects
class ObjectPool {
    static _pools := Map()
    
    static getPool(className) {
        if !ObjectPool._pools.Has(className)
            ObjectPool._pools[className] := []
        return ObjectPool._pools[className]
    }
    
    static acquire(className, initParams*) {
        pool := ObjectPool.getPool(className)
        
        if pool.Length > 0 {
            obj := pool.Pop()
            if obj.HasMethod("reset")
                obj.reset(initParams*)
            return obj
        }
        
        ; Create new instance if pool is empty
        return %className%(initParams*)
    }
    
    static release(obj) {
        className := obj.__Class.__Name
        pool := ObjectPool.getPool(className)
        
        if obj.HasMethod("cleanup")
            obj.cleanup()
        
        pool.Push(obj)
    }
}

; Pooled object example
class PooledWorker {
    data := unset
    isActive := false
    
    __New() {
        ; Minimal initialization
    }
    
    reset(newData) {
        this.data := newData
        this.isActive := true
    }
    
    process() {
        if !this.isActive
            throw Error("Worker not active")
        
        ; Simulate work
        result := "Processed: " this.data
        return result
    }
    
    cleanup() {
        this.data := unset
        this.isActive := false
    }
}

; Lazy initialization pattern
class ExpensiveResource {
    _initialized := false
    _cache := unset
    
    ; Property with lazy initialization
    expensiveData {
        get {
            if !this._initialized {
                this._cache := this._computeExpensiveData()
                this._initialized := true
            }
            return this._cache
        }
    }
    
    _computeExpensiveData() {
        ; Simulate expensive computation
        Sleep(100)
        return "Expensive computed result"
    }
    
    ; Invalidate cache when needed
    invalidate() {
        this._initialized := false
        this._cache := unset
    }
}

; Copy-on-write pattern for large data
class CopyOnWriteArray {
    _data := []
    _isShared := false
    
    __New(initialData := []) {
        this._data := initialData
    }
    
    ; Share reference until modification
    clone() {
        newInstance := CopyOnWriteArray()
        newInstance._data := this._data
        newInstance._isShared := true
        this._isShared := true
        return newInstance
    }
    
    get(index) {
        return this._data[index]
    }
    
    set(index, value) {
        this._ensureUnique()
        this._data[index] := value
    }
    
    push(value) {
        this._ensureUnique()
        this._data.Push(value)
    }
    
    _ensureUnique() {
        if this._isShared {
            this._data := this._data.Clone()
            this._isShared := false
        }
    }
    
    get length => this._data.Length
}

; Usage examples
worker := ObjectPool.acquire("PooledWorker", "some data")
result := worker.process()
ObjectPool.release(worker)  ; Return to pool

resource := ExpensiveResource()
data := resource.expensiveData  ; Computed only once

array1 := CopyOnWriteArray([1, 2, 3])
array2 := array1.clone()        ; Shares data
array2.push(4)                  ; Triggers copy, array1 unchanged
```
</performance_guidelines>

<CLASS_INSTRUCTION_META>

<MODULE_PURPOSE>
This module provides comprehensive class design patterns for AHK v2, organized by complexity tiers.
LLMs should reference this module when users request object-oriented solutions, inheritance patterns, or encapsulation.
</MODULE_PURPOSE>

<TIER_SYSTEM>
TIER 1: Basic class creation (constructors, properties, methods)
TIER 2: Inheritance and polymorphism (extends, super, virtual methods)
TIER 3: Advanced properties and meta-functions (__Get, __Set, __Call)
TIER 4: Nested classes and factory patterns (composition, creation patterns)
TIER 5: Memory management and resource cleanup (disposal, references)
TIER 6: Advanced patterns and performance (observers, pooling, lazy loading)
</TIER_SYSTEM>

<CRITICAL_PATTERNS>
- Always instantiate without "new" keyword (ClassName(), not new ClassName())
- Use this.property for instance access, ClassName.property for static access
- Implement __Delete() for resource cleanup and reference management
- Use super.method() for base class access in inheritance hierarchies
- Bind event handlers with .Bind(this) to maintain proper context
- Prevent circular references with weak reference patterns or disposal methods
</CRITICAL_PATTERNS>

<LLM_GUIDANCE>
When user requests class-based solutions:
1. FIRST: Apply the <THINKING> process from module_instructions.md
2. THEN: Identify the class complexity tier (1-6) from this module
3. ESCALATE cognitive tier if:
   - Complex inheritance hierarchies or multiple levels (think harder)
   - Meta-programming or dynamic behavior requirements (think harder)
   - Memory management, circular references, or performance optimization (ultrathink)
   - Integration with GUI systems and event handling (ultrathink)
4. Use appropriate OOP principles: encapsulation, inheritance, polymorphism
5. Implement proper error handling and resource cleanup patterns
6. Apply ALL syntax validation rules from module_instructions.md
7. Include comprehensive documentation for class interfaces
8. Run <CODE_VALIDATOR> process on all class implementations
</LLM_GUIDANCE>

<COMMON_SCENARIOS>
"create reusable components" → Class encapsulation with proper interfaces
"inherit behavior" → Inheritance with super() patterns
"dynamic properties" → Meta-functions (__Get, __Set, __Call)
"factory pattern" → Static methods or nested classes
"resource management" → Constructor/destructor with __Delete()
"event system" → Observer pattern with weak references
"performance optimization" → Object pooling or lazy initialization
"state management" → Class-based state machines
</COMMON_SCENARIOS>

<ERROR_PATTERNS_TO_AVOID>
- Using "new" keyword for instantiation (wrong: new Class(), correct: Class())
- Object literals for complex data (wrong: {}, correct: Map() or class)
- Circular references without cleanup (implement disposal patterns)
- Missing __Delete() for resource cleanup
- Incorrect super() usage in inheritance
- Event handlers without .Bind(this)
- Static method access via instance (use ClassName.method)
</ERROR_PATTERNS_TO_AVOID>

</CLASS_INSTRUCTION_META>