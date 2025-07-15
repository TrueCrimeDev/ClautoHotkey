# Topic: Event-Driven GUI Framework Snippet

## Category

Snippet

## Overview

This snippet demonstrates how to create a fully event-driven GUI framework in AutoHotkey v2 using class-based architecture. It implements a custom event system that allows components to communicate without tight coupling, making GUIs more maintainable and extensible. The framework separates UI elements, event handling, and business logic, following modern software design principles.

## Key Points

- Uses classes to encapsulate GUI components and behavior
- Implements a custom event system for loose component coupling
- Separates concerns: UI, event handling, and business logic
- Supports dynamic registration and unregistration of event listeners
- Demonstrates proper event propagation and handling
- Provides clean API for building complex user interfaces

## Syntax and Parameters

```cpp
; Event system usage
EventSystem.Subscribe("eventName", CallbackFunc)
EventSystem.Publish("eventName", param1, param2)
EventSystem.Unsubscribe("eventName", CallbackFunc)

; GUI component usage
myApp := AppGui()
myApp.AddComponent(ComponentName, params*)
myApp.Show()
```

## Code Examples

```cpp
; Event-Driven GUI Framework Example

; Event System Class
class EventSystem {
    static Subscribers := Map()
    
    ; Subscribe to an event
    static Subscribe(eventName, callback) {
        if (!this.Subscribers.Has(eventName))
            this.Subscribers[eventName] := []
            
        this.Subscribers[eventName].Push(callback)
        return true
    }
    
    ; Publish an event with optional parameters
    static Publish(eventName, params*) {
        if (!this.Subscribers.Has(eventName))
            return false
            
        for callback in this.Subscribers[eventName]
            callback(params*)
            
        return true
    }
    
    ; Unsubscribe from an event
    static Unsubscribe(eventName, callback) {
        if (!this.Subscribers.Has(eventName))
            return false
            
        index := 0
        for i, cb in this.Subscribers[eventName] {
            if (cb = callback) {
                index := i
                break
            }
        }
        
        if (index > 0) {
            this.Subscribers[eventName].RemoveAt(index)
            return true
        }
        
        return false
    }
    
    ; Clear all subscribers for an event
    static Clear(eventName := "") {
        if (eventName = "")
            this.Subscribers := Map()
        else if (this.Subscribers.Has(eventName))
            this.Subscribers.Delete(eventName)
    }
}

; Base Component Class
class Component {
    GUI := ""
    Control := ""
    Options := ""
    Name := ""
    
    __New(gui, name, options := "") {
        this.GUI := gui
        this.Name := name
        this.Options := options
    }
    
    ; Method to be overridden by specific components
    Create() {
        return this
    }
    
    ; Helper method to bind events
    BindEvent(eventName, handlerMethod) {
        callbackFn := ObjBindMethod(this, handlerMethod)
        EventSystem.Subscribe(eventName, callbackFn)
        return callbackFn
    }
}

; Text Component
class TextComponent extends Component {
    Text := ""
    
    __New(gui, name, text, options := "") {
        super.__New(gui, name, options)
        this.Text := text
    }
    
    Create() {
        this.Control := this.GUI.AddText(this.Options, this.Text)
        return this
    }
    
    SetText(text) {
        this.Text := text
        if (this.Control)
            this.Control.Text := text
        return this
    }
}

; Button Component
class ButtonComponent extends Component {
    Text := ""
    
    __New(gui, name, text, options := "") {
        super.__New(gui, name, options)
        this.Text := text
    }
    
    Create() {
        this.Control := this.GUI.AddButton(this.Options, this.Text)
        this.Control.OnEvent("Click", ObjBindMethod(this, "OnClick"))
        return this
    }
    
    OnClick(ctrl, info) {
        EventSystem.Publish("button.click", this.Name, ctrl, info)
    }
}

; Edit Component
class EditComponent extends Component {
    Text := ""
    
    __New(gui, name, text := "", options := "") {
        super.__New(gui, name, options)
        this.Text := text
    }
    
    Create() {
        this.Control := this.GUI.AddEdit(this.Options, this.Text)
        this.Control.OnEvent("Change", ObjBindMethod(this, "OnChange"))
        return this
    }
    
    OnChange(ctrl, info) {
        EventSystem.Publish("edit.change", this.Name, ctrl.Text, ctrl, info)
    }
    
    GetText() {
        return this.Control.Text
    }
    
    SetText(text) {
        this.Text := text
        if (this.Control)
            this.Control.Text := text
        return this
    }
}

; Main Application GUI
class AppGui {
    Gui := ""
    Components := Map()
    
    __New(title := "Event-Driven Application", options := "") {
        this.Gui := Gui(options, title)
        this.Gui.OnEvent("Close", ObjBindMethod(this, "OnClose"))
    }
    
    AddComponent(componentClass, name, params*) {
        component := %componentClass%(this.Gui, name, params*)
        component.Create()
        this.Components[name] := component
        return component
    }
    
    GetComponent(name) {
        return this.Components.Has(name) ? this.Components[name] : ""
    }
    
    Show(options := "") {
        this.Gui.Show(options)
    }
    
    OnClose(gui) {
        EventSystem.Publish("app.close", this)
        ExitApp
    }
}

; Example Controller class
class Controller {
    App := ""
    
    __New(app) {
        this.App := app
        
        ; Subscribe to events
        EventSystem.Subscribe("button.click", ObjBindMethod(this, "OnButtonClick"))
        EventSystem.Subscribe("edit.change", ObjBindMethod(this, "OnEditChange"))
        EventSystem.Subscribe("app.close", ObjBindMethod(this, "OnAppClose"))
    }
    
    OnButtonClick(name, ctrl, info) {
        if (name = "btnSubmit") {
            input := this.App.GetComponent("inputField").GetText()
            this.App.GetComponent("outputField").SetText("You entered: " input)
            
            ; Publish a custom event
            EventSystem.Publish("data.submitted", input)
        } else if (name = "btnClear") {
            this.App.GetComponent("inputField").SetText("")
            this.App.GetComponent("outputField").SetText("")
        }
    }
    
    OnEditChange(name, text, ctrl, info) {
        this.App.GetComponent("charCount").SetText("Characters: " StrLen(text))
    }
    
    OnAppClose(app) {
        ; Clean up resources, save state, etc.
        MsgBox("Application closing. Thanks for using!")
    }
}

; Example usage
ExampleApp() {
    ; Create main application
    app := AppGui("Event-Driven GUI Example", "+Resize")
    
    ; Add components
    app.AddComponent("TextComponent", "inputLabel", "Enter some text:", "w400")
    app.AddComponent("EditComponent", "inputField", "", "w400")
    app.AddComponent("TextComponent", "charCount", "Characters: 0", "w400")
    app.AddComponent("TextComponent", "outputLabel", "Output:", "w400 y+20")
    app.AddComponent("TextComponent", "outputField", "", "w400 h60")
    app.AddComponent("ButtonComponent", "btnSubmit", "Submit", "w200 y+20")
    app.AddComponent("ButtonComponent", "btnClear", "Clear", "w200 x+10")
    
    ; Create controller to handle business logic
    controller := Controller(app)
    
    ; Add a custom event listener just to demonstrate
    EventSystem.Subscribe("data.submitted", (data) => MsgBox("Data processed: " data))
    
    ; Show the GUI
    app.Show("w420 h300")
    
    return app
}

; Start the application
myApp := ExampleApp()
```

## Implementation Notes

- The event system uses a Map to store event subscribers, with event names as keys
- Callback functions are stored in arrays within the Map, allowing multiple subscribers per event
- Component classes inherit from a base class for consistent structure and shared functionality
- The `ObjBindMethod` function is used to create callbacks bound to object instances
- Events propagate from components to the controller, maintaining separation of concerns
- Use descriptive event names to make the code more self-documenting (e.g., 'button.click', 'edit.change')
- For complex applications, consider implementing event bubbling and capturing phases
- Memory management is important: unsubscribe from events when components are destroyed
- This framework can be extended to support more complex component hierarchies
- Add error handling for critical operations to improve robustness

## Related AHK Concepts

- [GUI Class Best Practices](../Classes/gui-class-best-practices.md)
- [Object-Oriented Programming](../Concepts/Prototype_Based_OOP.md)
- [Method Binding and Context](../Concepts/method-binding-and-context.md)
- [MVC Pattern](../Patterns/MVC_Pattern.md)
- [ObjBindMethod Function](../Methods/objbindmethod.md)

## Tags

#AutoHotkey #OOP #EventDriven #GUI #Components #Observer #MVC #v2