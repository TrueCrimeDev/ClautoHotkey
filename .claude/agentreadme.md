# AutoHotkey v2 Claude Agents

This folder contains specialized Claude Code agents for AutoHotkey v2 development, each designed to handle specific aspects of AHK script development and conversion. 

## Agent Index

- ahk-version-detector — `ClautoHotkey/.claude/agents/ahk-version-detector.md`
- ahk-converter-runner — `ClautoHotkey/claude/agents/ahk-converter-runner.md`
- v1-to-v2-migrator — `ClautoHotkey/.claude/agents/v1-to-v2-migrator.md`
- gui-builder — `ClautoHotkey/.claude/agents/gui-builder.md`
- ahk-gui-layout-enforcer — `ClautoHotkey/.claude/agents/ahk-gui-layout-enforcer.md`
- layout — `ClautoHotkey/.claude/agents/layout.md`

## Agent List and Descriptions

### **ahk-version-detector** (`ClautoHotkey/.claude/agents/ahk-version-detector.md`)

**Purpose**: AutoHotkey version detection and conversion specialist  
**Use Case**: Use PROACTIVELY when analyzing ANY AHK script to determine if it's v1 or v2  
**Key Features**:

- Detects legacy v1 patterns (= assignments, %var% syntax, command syntax)
- Must be used before working with any AutoHotkey code
- Automatically triggers v2 converter when v1 code is detected
- Ensures v2 compatibility before script analysis

### **ahk-converter-runner** (`ClautoHotkey/.claude/agents/ahk-converter-runner.md`)

**Purpose**: AutoHotkey v2 converter execution specialist  
**Use Case**: Use IMMEDIATELY when v1 code is detected by ahk-version-detector  
**Key Features**:

- Executes automated conversion tools
- Locates converter tools in common locations
- Creates backups before conversion
- Handles the automated conversion process
- Works in tandem with version detection

### **v1-to-v2-migrator** (`ClautoHotkey/.claude/agents/v1-to-v2-migrator.md`)

**Purpose**: AutoHotkey v1 to v2 MANUAL migration specialist  
**Use Case**: Use when automated conversion fails or for complex migration scenarios  
**Key Features**:

- Handles complex conversions that automated tools cannot complete
- Works with other agents for comprehensive conversion
- Manages edge cases and manual fixes
- Provides detailed migration guidance for syntax differences

### **gui-builder** (`ClautoHotkey/.claude/agents/gui-builder.md`)

**Purpose**: AutoHotkey v2 GUI creation specialist  
**Use Case**: Use PROACTIVELY when creating windows, dialogs, or any UI elements  
**Key Features**:

- Creates robust, user-friendly interfaces
- Implements proper event handling
- Adds error handling and validation
- Uses proper control naming conventions
- Implements responsive layouts with control anchoring

### **ahk-gui-layout-enforcer** (`ClautoHotkey/.claude/agents/ahk-gui-layout-enforcer.md`)

**Purpose**: AutoHotkey v2 GUI layout enforcement specialist  
**Use Case**: Use PROACTIVELY for ANY GUI creation, window layout, or control positioning  
**Key Features**:

- Ensures professional, overlap-free layouts using mathematical positioning
- Enforces systematic approach with sequential Y-position tracking
- Prevents control overlaps and maintains consistent spacing
- Uses mathematical law: `New Y Position = Previous Y + Previous Height + Spacing`

### **layout** (`ClautoHotkey/.claude/agents/layout.md`)

**Purpose**: AutoHotkey v2 GUI layout enforcement specialist (focused version)  
**Use Case**: Use proactively for ANY GUI creation or refactor to guarantee overlap-free layouts  
**Key Features**:

- Audits, corrects, and generates GUI code with strict mathematical positioning
- Uses tracked coordinates (no hard-coded Y values)
- Provides consistent horizontal math for side-by-side controls
- Handles groups and nested sections properly

Each agent has specific tools and focuses on particular aspects of AutoHotkey v2 development, ensuring comprehensive coverage of common development scenarios.