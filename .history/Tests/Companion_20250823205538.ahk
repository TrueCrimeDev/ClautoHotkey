#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

AHKCompanionSystem()
class AHKCompanionSystem {
    static MemoryPath := A_ScriptDir "\memory_docs\"
    static ProjectPath := A_ScriptDir "\projects\"
    static TemplatesPath := A_ScriptDir "\templates\"
    static Config := Map(
        "version", "1.0",
        "mode", "FULL",
        "editor", "notepad.exe"
    )

    __New() {
        this.EnsureFolders()
        this.LoadConfiguration()
        this.CreateGUI()
    }

    EnsureFolders() {
        for _, path in [AHKCompanionSystem.MemoryPath,
            AHKCompanionSystem.ProjectPath,
            AHKCompanionSystem.TemplatesPath]
            if !DirExist(path)
                DirCreate(path)
    }

    LoadConfiguration() {
        configFile := AHKCompanionSystem.MemoryPath "system_config.md"
        if FileExist(configFile) {
            try {
                content := FileRead(configFile)
                if InStr(content, "Mode: LITE")
                    AHKCompanionSystem.Config["mode"] := "LITE"
            }
        } else {
            this.CreateDefaultConfig()
        }
    }

    CreateDefaultConfig() {
        content := "# AHK Companion System Configuration`n`n"
            . "Mode: " AHKCompanionSystem.Config["mode"] "`n"
            . "Version: " AHKCompanionSystem.Config["version"] "`n"
            . "Editor: " AHKCompanionSystem.Config["editor"]

        FileOpen(AHKCompanionSystem.MemoryPath "system_config.md", "w").Write(content).Close()
    }

    CreateGUI() {
        this.gui := Gui("+Resize", "AHK v2 Coding Companion")
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())

        this.gui.SetFont("s10")
        this.gui.AddText("w400 Center", "AutoHotkey v2 Coding Companion System")
        this.gui.AddText("w400 Center", "Mode: " AHKCompanionSystem.Config["mode"])

        this.gui.AddButton("w200 h30", "New Project")
            .OnEvent("Click", this.CreateNewProject.Bind(this))

        this.gui.AddButton("w200 h30", "Open Project")
            .OnEvent("Click", this.OpenProject.Bind(this))

        this.gui.AddButton("w200 h30", "Memory Bank")
            .OnEvent("Click", this.OpenMemoryBank.Bind(this))

        this.gui.AddButton("w200 h30", "Settings")
            .OnEvent("Click", this.OpenSettings.Bind(this))

        this.gui.Show()
    }

    CreateNewProject(*) {
        projectName := InputBox("Enter project name:", "New Project").Value
        if !projectName
            return

        projectFolder := AHKCompanionSystem.ProjectPath projectName
        if DirExist(projectFolder) {
            MsgBox("Project already exists.", "Error", "Icon!")
            return
        }

        DirCreate(projectFolder)

        template := FileRead(AHKCompanionSystem.TemplatesPath "basic_script.ahk")
        FileOpen(projectFolder "\" projectName ".ahk", "w").Write(template).Close()

        this.CreateProjectMemory(projectName)
        Run(AHKCompanionSystem.Config["editor"] " " projectFolder "\" projectName ".ahk")
    }

    CreateProjectMemory(projectName) {
        memoryFolder := AHKCompanionSystem.MemoryPath projectName
        DirCreate(memoryFolder)

        defaultFiles := Map(
            "projectbrief.md", "# " projectName " - Project Brief`n`n## Purpose`n`n## Requirements`n`n## Features",
            "activeContext.md", "# " projectName " - Active Context`n`n## Current Focus`n`n## Recent Changes`n`n## Next Steps",
            "progress.md", "# " projectName " - Progress`n`n## Completed`n`n## In Progress`n`n## Pending`n`n## Issues"
        )

        if AHKCompanionSystem.Config["mode"] = "FULL" {
            defaultFiles["syntaxPatterns.md"] := "# " projectName " - Syntax Patterns`n`n## Class Structure`n`n## Event Handling`n`n## Data Management"
            defaultFiles["ahkContext.md"] := "# " projectName " - AHK Context`n`n## Version Requirements`n`n## Dependencies`n`n## Environment Setup"
            defaultFiles["productContext.md"] := "# " projectName " - Product Context`n`n## User Needs`n`n## Workflow Integration`n`n## User Experience"
            defaultFiles["scriptStructure.md"] := "# " projectName " - Script Structure`n`n## File Organization`n`n## Class Hierarchy`n`n## Function Map"
        }

        for filename, content in defaultFiles
            FileOpen(memoryFolder "\" filename, "w").Write(content).Close()
    }

    OpenProject(*) {
        projects := []
        Loop Files, AHKCompanionSystem.ProjectPath "*", "D"
            projects.Push(A_LoopFileName)

        if !projects.Length {
            MsgBox("No projects found.", "Information")
            return
        }

        projectGui := Gui(, "Select Project")
        projectList := projectGui.AddListBox("w300 h400 Choose1", projects)
        projectGui.AddButton("w300", "Open")
            .OnEvent("Click", (*) => (Run(AHKCompanionSystem.Config["editor"] " "
                AHKCompanionSystem.ProjectPath projectList.Text "\" projectList.Text ".ahk"),
                projectGui.Destroy()))

        projectGui.Show()
    }

    OpenMemoryBank(*) {
        projects := []
        Loop Files, AHKCompanionSystem.MemoryPath "*", "D"
            projects.Push(A_LoopFileName)

        if !projects.Length {
            MsgBox("No memory banks found.", "Information")
            return
        }

        memoryGui := Gui(, "Select Memory Bank")
        projectList := memoryGui.AddListBox("w300 h400 Choose1", projects)
        memoryGui.AddButton("w300", "Open")
            .OnEvent("Click", (*) => (Run("explorer "
                AHKCompanionSystem.MemoryPath projectList.Text),
                memoryGui.Destroy()))

        memoryGui.Show()
    }

    OpenSettings(*) {
        settingsGui := Gui(, "Settings")
        settingsGui.AddText("w300", "System Mode:")

        modeDropdown := settingsGui.AddDropDownList("w300 Choose"
            (AHKCompanionSystem.Config["mode"] = "FULL" ? "1" : "2"), ["FULL", "LITE"])

        settingsGui.AddText("w300", "Editor:")
        editorInput := settingsGui.AddEdit("w300", AHKCompanionSystem.Config["editor"])

        settingsGui.AddButton("w300", "Save")
            .OnEvent("Click", (*) => (
                AHKCompanionSystem.Config["mode"] := modeDropdown.Text,
                AHKCompanionSystem.Config["editor"] := editorInput.Text,
                this.SaveConfiguration(),
                settingsGui.Destroy(),
                MsgBox("Settings saved. Restart the application for changes to take effect.")
            ))

        settingsGui.Show()
    }

    SaveConfiguration() {
        content := "# AHK Companion System Configuration`n`n"
            . "Mode: " AHKCompanionSystem.Config["mode"] "`n"
            . "Version: " AHKCompanionSystem.Config["version"] "`n"
            . "Editor: " AHKCompanionSystem.Config["editor"]

        FileOpen(AHKCompanionSystem.MemoryPath "system_config.md", "w").Write(content).Close()
    }
}