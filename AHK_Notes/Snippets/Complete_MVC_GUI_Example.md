# Topic: Complete MVC GUI Example

## Category

Snippet

## Overview

This snippet demonstrates a complete, working example of a Task Management application using the Model-View-Controller (MVC) pattern in AutoHotkey v2. The application manages a list of tasks with priority levels, demonstrating proper separation of concerns, event handling, and state management.

## Key Points

- Clear separation between data (Model), presentation (View), and logic (Controller)
- Proper event binding using `.OnEvent()` and `.Bind(this)`
- State management using Map() for data storage
- Organized code structure with distinct component responsibilities
- Complete application flow from initialization to user interaction

## Syntax and Parameters

```cpp
; Application entry point
TaskApp := TaskManagementApp()

; Main application class
class TaskManagementApp {
    __New() {
        this.model := TaskModel()
        this.view := TaskView()
        this.controller := TaskController(this.model, this.view)
        this.view.Show()
    }
}
```

## Code Examples

```cpp
; -------------------------------------------
; Task Management Application Using MVC Pattern
; -------------------------------------------

; Create and run the application
TaskApp := TaskManagementApp()

; Main application container
class TaskManagementApp {
    __New() {
        ; Create the components
        this.model := TaskModel()
        this.view := TaskView()
        this.controller := TaskController(this.model, this.view)
        
        ; Initialize with sample data
        this.model.AddTask("Complete project documentation", "High")
        this.model.AddTask("Schedule team meeting", "Medium")
        this.model.AddTask("Review pull requests", "Low")
        
        ; Update view with initial data
        this.controller.RefreshTaskList()
        
        ; Display the GUI
        this.view.Show()
    }
}

; -------------------------------------------
; Model - Handles data and business logic
; -------------------------------------------
class TaskModel {
    __New() {
        ; Initialize task storage
        this.tasks := Map()
        this.nextId := 1
        this.priorityLevels := ["High", "Medium", "Low"]
    }
    
    ; Add a new task
    AddTask(description, priority) {
        if (!description)
            return false
        
        ; Validate priority
        if (!this.priorityLevels.Has(priority))
            priority := "Medium"  ; Default to medium if invalid
            
        ; Create task object
        taskId := this.nextId++
        this.tasks[taskId] := Map(
            "id", taskId,
            "description", description,
            "priority", priority,
            "completed", false,
            "dateCreated", A_Now
        )
        
        return taskId
    }
    
    ; Update existing task
    UpdateTask(id, description, priority) {
        if (!this.tasks.Has(id))
            return false
            
        if (description)
            this.tasks[id]["description"] := description
            
        if (this.priorityLevels.Has(priority))
            this.tasks[id]["priority"] := priority
            
        return true
    }
    
    ; Toggle task completion status
    ToggleTaskCompletion(id) {
        if (!this.tasks.Has(id))
            return false
            
        this.tasks[id]["completed"] := !this.tasks[id]["completed"]
        return true
    }
    
    ; Delete a task
    DeleteTask(id) {
        if (!this.tasks.Has(id))
            return false
            
        this.tasks.Delete(id)
        return true
    }
    
    ; Get all tasks
    GetAllTasks() {
        return this.tasks
    }
    
    ; Get priority levels
    GetPriorityLevels() {
        return this.priorityLevels
    }
}

; -------------------------------------------
; View - Handles the user interface
; -------------------------------------------
class TaskView {
    __New() {
        ; Create the GUI
        this.gui := Gui("+Resize", "Task Management")
        this.gui.SetFont("s10")
        this.controls := Map()
        
        ; Task entry section
        this.gui.AddText("x10 y10 w100", "Description:")
        this.controls["description"] := this.gui.AddEdit("x110 y10 w300", "")
        
        this.gui.AddText("x10 y40 w100", "Priority:")
        this.controls["priority"] := this.gui.AddDropDownList("x110 y40 w150 Choose2", ["High", "Medium", "Low"])
        
        this.controls["addButton"] := this.gui.AddButton("x420 y10 w100", "Add Task")
        this.controls["updateButton"] := this.gui.AddButton("x420 y40 w100 Disabled", "Update")
        
        ; Task list
        this.gui.AddText("x10 y70 w510 h1 0x10")  ; Horizontal line
        this.controls["taskList"] := this.gui.AddListView("x10 y80 w510 h300 Grid", ["ID", "Description", "Priority", "Status"])
        this.controls["taskList"].ModifyCol(1, 40)  ; ID column
        this.controls["taskList"].ModifyCol(2, 250)  ; Description column
        this.controls["taskList"].ModifyCol(3, 100)  ; Priority column
        this.controls["taskList"].ModifyCol(4, 80)  ; Status column
        
        ; Action buttons
        this.controls["completeButton"] := this.gui.AddButton("x10 y390 w100 Disabled", "Toggle Complete")
        this.controls["editButton"] := this.gui.AddButton("x120 y390 w100 Disabled", "Edit")
        this.controls["deleteButton"] := this.gui.AddButton("x230 y390 w100 Disabled", "Delete")
        
        ; Status bar
        this.gui.AddText("x10 y420 w510 h1 0x10")  ; Horizontal line
        this.controls["statusBar"] := this.gui.AddText("x10 y430 w510", "Ready")
        
        ; Set event handlers to be bound by the controller
        this.onAddTask := ""
        this.onUpdateTask := ""
        this.onToggleComplete := ""
        this.onEditTask := ""
        this.onDeleteTask := ""
        this.onSelectTask := ""
        this.onGuiClose := ""
    }
    
    ; Bind events to controller methods
    SetEventHandlers(handlers) {
        ; Store handlers
        this.onAddTask := handlers.onAddTask
        this.onUpdateTask := handlers.onUpdateTask
        this.onToggleComplete := handlers.onToggleComplete
        this.onEditTask := handlers.onEditTask
        this.onDeleteTask := handlers.onDeleteTask
        this.onSelectTask := handlers.onSelectTask
        this.onGuiClose := handlers.onGuiClose
        
        ; Connect to GUI events
        this.controls["addButton"].OnEvent("Click", this.onAddTask)
        this.controls["updateButton"].OnEvent("Click", this.onUpdateTask)
        this.controls["completeButton"].OnEvent("Click", this.onToggleComplete)
        this.controls["editButton"].OnEvent("Click", this.onEditTask)
        this.controls["deleteButton"].OnEvent("Click", this.onDeleteTask)
        this.controls["taskList"].OnEvent("ItemSelect", this.onSelectTask)
        this.gui.OnEvent("Close", this.onGuiClose)
    }
    
    ; Update the task list display
    UpdateTaskList(tasks) {
        ; Clear existing items
        this.controls["taskList"].Delete()
        
        ; Add current tasks
        for id, task in tasks {
            status := task["completed"] ? "Completed" : "Pending"
            this.controls["taskList"].Add(, task["id"], task["description"], task["priority"], status)
        }
        
        ; Update status
        this.SetStatus("Task list updated. Total tasks: " tasks.Count)
    }
    
    ; Set description and priority fields
    SetTaskDetails(description, priority) {
        this.controls["description"].Value := description
        
        ; Find and set the priority index
        for i, value in ["High", "Medium", "Low"] {
            if (value == priority) {
                this.controls["priority"].Value := i
                break
            }
        }
    }
    
    ; Show the GUI
    Show() {
        this.gui.Show("w530 h460")
    }
    
    ; Set status message
    SetStatus(message) {
        this.controls["statusBar"].Value := message
    }
    
    ; Enable/disable action buttons
    SetActionButtonState(enabled) {
        for _, button in ["completeButton", "editButton", "deleteButton", "updateButton"] {
            this.controls[button].Enabled := enabled
        }
        
        ; Toggle add/update buttons visibility
        this.controls["addButton"].Enabled := !enabled
    }
    
    ; Clear input fields
    ClearInputs() {
        this.controls["description"].Value := ""
        this.controls["priority"].Value := 2  ; Default to Medium
        this.SetActionButtonState(false)
    }
}

; -------------------------------------------
; Controller - Handles user interaction and connects Model with View
; -------------------------------------------
class TaskController {
    __New(model, view) {
        this.model := model
        this.view := view
        this.selectedTaskId := 0
        
        ; Create handler functions with the correct context
        handlers := Map(
            "onAddTask", this.AddTask.Bind(this),
            "onUpdateTask", this.UpdateTask.Bind(this),
            "onToggleComplete", this.ToggleComplete.Bind(this),
            "onEditTask", this.EditTask.Bind(this),
            "onDeleteTask", this.DeleteTask.Bind(this),
            "onSelectTask", this.SelectTask.Bind(this),
            "onGuiClose", this.GuiClose.Bind(this)
        )
        
        ; Set up event handlers in the view
        this.view.SetEventHandlers(handlers)
    }
    
    ; Refresh the task list
    RefreshTaskList() {
        this.view.UpdateTaskList(this.model.GetAllTasks())
    }
    
    ; Add a new task
    AddTask(ctrl, *) {
        description := this.view.controls["description"].Value
        priorityIndex := this.view.controls["priority"].Value
        priority := ["High", "Medium", "Low"][priorityIndex]
        
        if (description) {
            this.model.AddTask(description, priority)
            this.RefreshTaskList()
            this.view.ClearInputs()
            this.view.SetStatus("Task added successfully.")
        } else {
            this.view.SetStatus("Error: Task description cannot be empty.")
        }
    }
    
    ; Update an existing task
    UpdateTask(ctrl, *) {
        if (!this.selectedTaskId) {
            this.view.SetStatus("Error: No task selected.")
            return
        }
        
        description := this.view.controls["description"].Value
        priorityIndex := this.view.controls["priority"].Value
        priority := ["High", "Medium", "Low"][priorityIndex]
        
        if (description) {
            if (this.model.UpdateTask(this.selectedTaskId, description, priority)) {
                this.RefreshTaskList()
                this.view.ClearInputs()
                this.selectedTaskId := 0
                this.view.SetStatus("Task updated successfully.")
            } else {
                this.view.SetStatus("Error: Failed to update task.")
            }
        } else {
            this.view.SetStatus("Error: Task description cannot be empty.")
        }
    }
    
    ; Toggle task completion
    ToggleComplete(ctrl, *) {
        if (!this.selectedTaskId) {
            this.view.SetStatus("Error: No task selected.")
            return
        }
        
        if (this.model.ToggleTaskCompletion(this.selectedTaskId)) {
            this.RefreshTaskList()
            this.view.SetStatus("Task status toggled successfully.")
        } else {
            this.view.SetStatus("Error: Failed to toggle task status.")
        }
    }
    
    ; Edit the selected task
    EditTask(ctrl, *) {
        if (!this.selectedTaskId) {
            this.view.SetStatus("Error: No task selected.")
            return
        }
        
        task := this.model.GetAllTasks()[this.selectedTaskId]
        if (task) {
            this.view.SetTaskDetails(task["description"], task["priority"])
            this.view.SetActionButtonState(true)
            this.view.SetStatus("Editing task #" task["id"])
        }
    }
    
    ; Delete the selected task
    DeleteTask(ctrl, *) {
        if (!this.selectedTaskId) {
            this.view.SetStatus("Error: No task selected.")
            return
        }
        
        taskId := this.selectedTaskId
        if (this.model.DeleteTask(taskId)) {
            this.selectedTaskId := 0
            this.RefreshTaskList()
            this.view.ClearInputs()
            this.view.SetStatus("Task #" taskId " deleted successfully.")
        } else {
            this.view.SetStatus("Error: Failed to delete task.")
        }
    }
    
    ; Handle task selection
    SelectTask(ctrl, *) {
        if (rowNumber := this.view.controls["taskList"].GetNext()) {
            this.selectedTaskId := this.view.controls["taskList"].GetText(rowNumber, 1)
            this.view.SetActionButtonState(true)
            this.view.SetStatus("Selected task #" this.selectedTaskId)
        } else {
            this.selectedTaskId := 0
            this.view.SetActionButtonState(false)
            this.view.SetStatus("Ready")
        }
    }
    
    ; Handle GUI close
    GuiClose(ctrl, *) {
        ExitApp()
    }
}
```

## Implementation Notes

- The application follows a strict MVC pattern where the Model is responsible for data management and business rules, the View handles the user interface, and the Controller manages the interaction between them.
- The `.Bind(this)` method is crucial for maintaining the proper `this` context in event handlers, ensuring that controller methods can access all controller properties.
- Error handling is implemented throughout the code to prevent operations on invalid task IDs.
- The View never directly accesses the Model - all data flow is mediated by the Controller.
- The `Map()` data structure is used for efficient task storage and retrieval by ID.
- The status bar provides useful feedback to users about the success or failure of operations.
- Task management respects CRUD (Create, Read, Update, Delete) operations, with proper validation at each step.
- Action buttons are dynamically enabled/disabled based on the current application state.

## Related AHK Concepts

- Event Handling with `.OnEvent()` and `.Bind()`
- GUI Creation and Management
- Object-Oriented Programming in AutoHotkey v2
- Map and Array Data Structures
- Event-Driven Programming
- Data Binding and State Management

## Tags

#AutoHotkey #OOP #MVC #GUI #TaskManagement #DataBinding #EventHandling