#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

/*
 * Enhanced Coding Companion System for Advanced Coding Agent
 * Combines functionality from AHK_Notes and ClautoHotkey to create a comprehensive
 * coding companion system with memory bank, function map, and workflow management.
*/

; Initialize the system
CodingCompanionSystem()

class CodingCompanionSystem {
    static VERSION := "1.0.0"
    static MEMORY_DOCS_PATH := A_ScriptDir "\memory_docs"
    static MEMORY_BANK_PATH := A_ScriptDir "\memory-bank"
    static TASK_LOGS_PATH := A_ScriptDir "\.cursor\task-logs"

    ; System state
    systemConfig := Map()
    isInitialized := false

    __New() {
        this.Initialize()
        this.ShowSystemUI()
    }

    Initialize() {
        try {
            ; Create required directories if they don't exist
            this.EnsureDirectoryExists(CodingCompanionSystem.MEMORY_DOCS_PATH)
            this.EnsureDirectoryExists(CodingCompanionSystem.TASK_LOGS_PATH)

            ; Check if system_config exists, if not create it with mode selection dialog
            if (!FileExist(CodingCompanionSystem.MEMORY_DOCS_PATH "\system_config.md")) {
                this.SelectSystemMode()
            } else {
                ; Load existing system config
                this.LoadSystemConfig()
            }

            ; Verify all required memory bank files exist based on mode
            this.VerifyMemoryBankFiles()

            ; Read and load all memory bank content
            this.ReadMemoryBank()

            this.isInitialized := true
            this.Log("System initialized successfully in " this.systemConfig["mode"] " mode")
        } catch as err {
            MsgBox("Error initializing system: " err.Message, "Enhanced Coding Companion", "Icon!")
        }
    }

    SelectSystemMode() {
        prompt := "Would you prefer to use the LITE version (streamlined for smaller projects) "
        prompt .= "or the FULL version (comprehensive for complex projects) of the coding companion system?"
        prompt .= "`n`nYes = LITE mode`nNo = FULL mode"

        result := MsgBox(prompt, "Enhanced Coding Companion", "YesNo Icon?")
        mode := result = "Yes" ? "LITE" : "FULL"

        ; Save the selection to system_config
        this.systemConfig["mode"] := mode
        content := "# System Configuration`n`n"
        content .= "## Mode`n`n"
        content .= mode "`n`n"
        content .= "## Custom Function Map Extensions`n`n"
        content .= "None yet configured.`n`n"
        content .= "## Configuration Preferences`n`n"
        content .= "- Default mode: " mode "`n"
        content .= "- Created: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n`n"
        content .= "## Performance Settings`n`n"
        content .= "Default settings applied."

        try {
            FileAppend(content, CodingCompanionSystem.MEMORY_DOCS_PATH "\system_config.md")
        } catch as err {
            MsgBox("Error saving system configuration: " err.Message, "Enhanced Coding Companion", "Icon!")
        }
    }

    LoadSystemConfig() {
        try {
            content := FileRead(CodingCompanionSystem.MEMORY_DOCS_PATH "\system_config.md")
            ; Extract mode from content
            if (RegExMatch(content, "i)## Mode\R+\R+(\w+)", &match)) {
                this.systemConfig["mode"] := Trim(match[1])
            } else {
                ; Default to FULL if not found
                this.systemConfig["mode"] := "FULL"
            }
        } catch as err {
            this.Log("Error loading system config: " err.Message)
            ; Default to FULL mode if there's an error
            this.systemConfig["mode"] := "FULL"
        }
    }

    VerifyMemoryBankFiles() {
        requiredFiles := this.GetRequiredFiles()

        for _, fileName in requiredFiles {
            filePath := CodingCompanionSystem.MEMORY_DOCS_PATH "\" fileName
            if (!FileExist(filePath)) {
                ; Create missing file with template content
                this.CreateMemoryBankFile(fileName)
            }
        }
    }

    GetRequiredFiles() {
        ; Returns array of required files based on mode
        if (this.systemConfig["mode"] = "LITE") {
            return ["projectbrief.md", "activeContext.md", "progress.md", "system_config.md", "fileTree.md"]
        } else {
            return ["projectbrief.md", "productContext.md", "systemPatterns.md", "techContext.md",
                "activeContext.md", "progress.md", "fileTree.md", "system_config.md"]
        }
    }

    CreateMemoryBankFile(fileName) {
        try {
            ; Copy from existing memory-bank if available, otherwise create template
            if (FileExist(CodingCompanionSystem.MEMORY_BANK_PATH "\" fileName)) {
                FileCopy(CodingCompanionSystem.MEMORY_BANK_PATH "\" fileName, CodingCompanionSystem.MEMORY_DOCS_PATH "\" fileName)
            } else {
                template := this.GetBasicTemplate(fileName)
                FileAppend(template, CodingCompanionSystem.MEMORY_DOCS_PATH "\" fileName)
            }
            this.Log("Created " fileName)
        } catch as err {
            this.Log("Error creating " fileName ": " err.Message)
        }
    }

    GetBasicTemplate(fileName) {
        ; Basic templates for memory bank files
        basicTemplates := Map(
            "projectbrief.md", "# Project Brief`n`n## Overview`n`n## Core Requirements`n`n## Goals`n`n## Target Audience`n`n## Success Criteria`n",
            "activeContext.md", "# Active Context`n`n## Current Work Focus`n`n## Recent Changes`n`n## Next Steps`n`n## Active Decisions`n",
            "progress.md", "# Progress`n`n## What Works`n`n## What's Left to Build`n`n## Current Status`n`n## Known Issues`n",
            "productContext.md", "# Product Context`n`n## Why This Project Exists`n`n## Problems It Solves`n`n## User Experience Goals`n",
            "systemPatterns.md", "# System Patterns`n`n## System Architecture`n`n## Key Technical Decisions`n`n## Design Patterns`n",
            "techContext.md", "# Technical Context`n`n## Technologies Used`n`n## Development Setup`n`n## Dependencies`n",
            "fileTree.md", "# File Tree`n`n## Project Structure`n`n## Component Relationships`n"
        )

        if (basicTemplates.Has(fileName)) {
            return basicTemplates[fileName]
        } else {
            return "# " RegExReplace(fileName, "\.md$", "") "`n`nTemplate content for " fileName
        }
    }

    ReadMemoryBank() {
        ; Read all memory bank files to establish context
        this.Log("Reading memory bank files...")
        this.memoryBank := Map()
        requiredFiles := this.GetRequiredFiles()

        for _, fileName in requiredFiles {
            filePath := CodingCompanionSystem.MEMORY_DOCS_PATH "\" fileName
            if (FileExist(filePath)) {
                try {
                    this.memoryBank[fileName] := FileRead(filePath)
                } catch as err {
                    this.Log("Error reading " fileName ": " err.Message)
                }
            }
        }
    }

    CreateTaskLog(goal) {
        timestamp := FormatTime(, "yyyy-MM-dd-HH-mm")
        descriptor := this.SanitizeFilename(SubStr(goal, 1, 30))
        fileName := "task-log_" timestamp "_" descriptor ".md"
        filePath := CodingCompanionSystem.TASK_LOGS_PATH "\" fileName

        content := "GOAL: " goal "`n"
        content .= "IMPLEMENTATION: In progress`n"
        content .= "STARTED: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n"
        content .= "COMPLETED: `n"
        content .= "PERFORMANCE: `n"
        content .= "ERROR_HANDLING: `n"
        content .= "TESTS: `n"
        content .= "NEXT_STEPS: `n"

        try {
            this.EnsureDirectoryExists(CodingCompanionSystem.TASK_LOGS_PATH)
            FileAppend(content, filePath)
            this.Log("Created task log: " fileName)
            return filePath
        } catch as err {
            this.Log("Error creating task log: " err.Message)
            return ""
        }
    }

    ShowSystemUI() {
        ; Create GUI for system management
        try {
            this.gui := Gui("+Resize", "Enhanced Coding Companion System v" CodingCompanionSystem.VERSION)
            this.gui.SetFont("s10")
            this.gui.BackColor := 0x202020

            ; Apply dark mode
            if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
                DWMWA_USE_IMMERSIVE_DARK_MODE := 19
                if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
                    DWMWA_USE_IMMERSIVE_DARK_MODE := 20
                DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.hWnd,
                    "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", true, "Int", 4)
            }

            ; Mode indicator
            this.gui.AddText("xm w500 cFFFFFF", "Current Mode: " this.systemConfig["mode"])

            ; File tabs
            this.tabs := this.gui.AddTab3("xm w500 h400", ["Memory Bank", "Task Logs", "Function Map"])

            ; Memory Bank tab
            this.tabs.UseTab(1)
            this.memoryBankListView := this.gui.AddListView("r10 w480 h320", ["File", "Status"])
            this.ApplyDarkListView(this.memoryBankListView)

            editBtn := this.CreateDarkButton("xm w100", "Edit Selected")
            refreshBtn := this.CreateDarkButton("x+10 w100", "Refresh")
            createBtn := this.CreateDarkButton("x+10 w120", "Create New File")

            editBtn.OnEvent("Click", this.EditSelectedFile.Bind(this))
            refreshBtn.OnEvent("Click", this.RefreshMemoryBank.Bind(this))
            createBtn.OnEvent("Click", this.CreateNewFile.Bind(this))

            ; Task Logs tab
            this.tabs.UseTab(2)
            this.taskLogsListView := this.gui.AddListView("r10 w480 h320", ["Date", "Task", "Status"])
            this.ApplyDarkListView(this.taskLogsListView)

            viewTaskBtn := this.CreateDarkButton("xm w100", "View Task")
            newTaskBtn := this.CreateDarkButton("x+10 w100", "New Task")

            viewTaskBtn.OnEvent("Click", this.ViewSelectedTask.Bind(this))
            newTaskBtn.OnEvent("Click", this.CreateNewTask.Bind(this))

            ; Function Map tab
            this.tabs.UseTab(3)
            this.gui.AddText("xm w480 cFFFFFF", "Function Map Overview:")
            mapSummary := this.GetFunctionMapSummary()
            this.functionMapEdit := this.gui.AddEdit("xm r15 w480 ReadOnly", mapSummary)
            this.functionMapEdit.SetFont("s9 cEEEEEE", "Consolas")
            this.functionMapEdit.Opt("+Background101010")

            viewMapBtn := this.CreateDarkButton("xm w180", "View Complete Function Map")
            extendMapBtn := this.CreateDarkButton("x+10 w180", "Extend Function Map")

            viewMapBtn.OnEvent("Click", this.ViewFunctionMap.Bind(this))
            extendMapBtn.OnEvent("Click", this.ExtendFunctionMap.Bind(this))

            ; Reset to default tab state
            this.tabs.UseTab()

            ; Status bar
            this.statusBar := this.gui.AddText("xm w500 h20 cFFFFFF", "Ready - System initialized in " this.systemConfig["mode"] " mode")

            ; Set up events
            this.gui.OnEvent("Close", (*) => this.gui.Hide())
            this.gui.OnEvent("Escape", (*) => this.gui.Hide())

            ; Populate lists
            this.RefreshMemoryBank()
            this.RefreshTaskLogs()

            this.gui.Show()
        } catch as err {
            MsgBox("Error creating system UI: " err.Message, "Enhanced Coding Companion", "Icon!")
        }
    }

    ApplyDarkListView(lv) {
        static LVM_SETTEXTCOLOR := 0x1024
        static LVM_SETTEXTBKCOLOR := 0x1026
        static LVM_SETBKCOLOR := 0x1001
        SendMessage(LVM_SETTEXTCOLOR, 0, 0xFFFFFF, lv)
        SendMessage(LVM_SETTEXTBKCOLOR, 0, 0x202020, lv)
        SendMessage(LVM_SETBKCOLOR, 0, 0x202020, lv)
        lv.Opt("+Grid +LV0x10000")
        DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        lv.ModifyCol(1, 150)
        lv.ModifyCol(2, 330)
        return lv
    }

    CreateDarkButton(options, text) {
        btn := this.gui.AddButton(options, text)
        btn.Opt("+Background202020")
        btn.SetFont("cFFFFFF")
        DllCall("uxtheme\SetWindowTheme", "Ptr", btn.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        return btn
    }

    RefreshMemoryBank(*) {
        this.memoryBankListView.Delete()
        requiredFiles := this.GetRequiredFiles()

        for _, fileName in requiredFiles {
            filePath := CodingCompanionSystem.MEMORY_DOCS_PATH "\" fileName
            status := FileExist(filePath) ? "Available" : "Missing"
            this.memoryBankListView.Add(, fileName, status)
        }

        this.UpdateStatus("Memory bank refreshed")
    }

    RefreshTaskLogs(*) {
        this.taskLogsListView.Delete()

        try {
            Loop Files, CodingCompanionSystem.TASK_LOGS_PATH "\*.md" {
                ; Extract date and task from filename
                if (RegExMatch(A_LoopFileName, "task-log_(.+?)_(.+)\.md", &matches)) {
                    date := matches[1]
                    task := RegExReplace(matches[2], "-", " ")

                    ; Determine status
                    this.taskLogsListView.Add(, date, task, "In Progress")
                }
            }
        } catch as err {
            this.Log("Error refreshing task logs: " err.Message)
        }

        this.UpdateStatus("Task logs refreshed")
    }

    EditSelectedFile(*) {
        if (row := this.memoryBankListView.GetNext()) {
            fileName := this.memoryBankListView.GetText(row, 1)
            filePath := CodingCompanionSystem.MEMORY_DOCS_PATH "\" fileName

            if (FileExist(filePath)) {
                Run("notepad.exe " filePath)
                this.UpdateStatus("Opened " fileName " for editing")
            } else {
                this.UpdateStatus("File does not exist: " fileName)
            }
        } else {
            this.UpdateStatus("No file selected")
        }
    }

    CreateNewFile(*) {
        ; Future implementation for creating a new memory bank file
        this.UpdateStatus("Create new file functionality not implemented yet")
    }

    ViewSelectedTask(*) {
        if (row := this.taskLogsListView.GetNext()) {
            date := this.taskLogsListView.GetText(row, 1)
            task := this.taskLogsListView.GetText(row, 2)

            ; Find the task log file
            fileName := "task-log_" date "_" RegExReplace(task, "\s+", "-") ".md"
            filePath := CodingCompanionSystem.TASK_LOGS_PATH "\" fileName

            if (FileExist(filePath)) {
                Run("notepad.exe " filePath)
                this.UpdateStatus("Opened task log: " fileName)
            } else {
                this.UpdateStatus("Task log not found: " fileName)
            }
        } else {
            this.UpdateStatus("No task selected")
        }
    }

    CreateNewTask(*) {
        result := InputBox("Enter the task goal:", "Create New Task", "w400 h100", "")

        if (!result.HasOwnProperty("Result") || result.Result = "Cancel") {
            return
        }

        taskGoal := result.Value
        if (taskGoal != "") {
            taskLogPath := this.CreateTaskLog(taskGoal)
            if (taskLogPath) {
                this.RefreshTaskLogs()
                this.UpdateStatus("Created new task log: " taskGoal)
            }
        }
    }

    ViewFunctionMap(*) {
        ; Show the function map in a new window
        functionMapText := this.GetFullFunctionMap()

        viewGui := Gui("+Resize", "Function Map")
        viewGui.SetFont("s10")
        viewGui.BackColor := 0x202020

        ; Apply dark mode
        if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
            DWMWA_USE_IMMERSIVE_DARK_MODE := 19
            if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
                DWMWA_USE_IMMERSIVE_DARK_MODE := 20
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", viewGui.hWnd,
                "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", true, "Int", 4)
        }

        edit := viewGui.AddEdit("xm r30 w800 vMapEdit ReadOnly", functionMapText)
        edit.SetFont("s9 cEEEEEE", "Consolas")
        edit.Opt("+Background101010")

        closeBtn := viewGui.AddButton("xm w100 Default", "Close")
        closeBtn.Opt("+Background202020")
        closeBtn.SetFont("cFFFFFF")
        closeBtn.OnEvent("Click", (*) => viewGui.Hide())

        viewGui.OnEvent("Close", (*) => viewGui.Hide())
        viewGui.OnEvent("Escape", (*) => viewGui.Hide())

        viewGui.Show("w800 h600")
    }

    ExtendFunctionMap(*) {
        ; Future implementation for extending the function map
        this.UpdateStatus("Extend function map functionality not implemented yet")
    }

    GetFunctionMapSummary() {
        summary := "Function Map contains the following sections:`n`n"
        summary .= "- StructureFunctions: 8 functions`n"
        summary .= "- WorkflowFunctions: 41 functions`n"
        summary .= "  - Initialization: 6 functions`n"
        summary .= "  - Planning: 10 functions`n"
        summary .= "  - Implementation: 9 functions`n"
        summary .= "  - Testing: 5 functions`n"
        summary .= "  - Documentation: 7 functions`n"
        summary .= "  - Evaluation: 8 functions`n"
        summary .= "  - ErrorHandling: 6 functions`n"
        summary .= "- TaskLogFunctions: 5 functions`n"
        summary .= "- MapManagementFunctions: 4 functions`n"
        summary .= "`nUse the 'View Complete Function Map' button to see details."

        return summary
    }

    GetFullFunctionMap() {
        ; Return the full function map XML
        if (FileExist(A_ScriptDir "\functionmap.xml")) {
            return FileRead(A_ScriptDir "\functionmap.xml")
        } else {
            return "Function map file not found. Please create functionmap.xml in " A_ScriptDir
        }
    }

    UpdateStatus(message) {
        try {
            this.statusBar.Value := message
            this.Log(message)
        } catch as err {
            ; In case statusBar is not available
            this.Log(message)
        }
    }

    EnsureDirectoryExists(path) {
        if (!DirExist(path)) {
            try {
                DirCreate(path)
                return true
            } catch as err {
                this.Log("Error creating directory: " path ": " err.Message)
                return false
            }
        }
        return true
    }

    SanitizeFilename(filename) {
        ; Replace invalid characters with dashes
        sanitized := RegExReplace(filename, "[\\/:*?`"<>|]", "-")
        ; Replace multiple spaces/dashes with a single dash
        sanitized := RegExReplace(sanitized, "[\s-]+", "-")
        ; Trim dashes from start and end
        return Trim(sanitized, "-")
    }

    Log(message) {
        try {
            FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " - " message "`n", A_ScriptDir "\Lib\system.log")
        } catch {
            ; Silent fail for logging
        }
    }
}