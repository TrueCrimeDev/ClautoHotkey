# AutoHotkey v2 Claude Agents

This folder contains specialized Claude Code agents for AutoHotkey v2 development.
Each is a fresh-context investigator — launch one when a task needs its own window.

## Agent Index

- ahk-analysis — `.claude/agents/ahk-analysis.md`
- ahk-com-explorer — `.claude/agents/ahk-com-explorer.md`
- ahk-context — `.claude/agents/ahk-context.md`
- ahk-dependency-graph — `.claude/agents/ahk-dependency-graph.md`
- ahk-orchestrator-v2 — `.claude/agents/ahk-orchestrator-v2.md`
- ahk-profiler — `.claude/agents/ahk-profiler.md`
- ahk-test-generator — `.claude/agents/ahk-test-generator.md`
- ahk-uia-explorer — `.claude/agents/ahk-uia-explorer.md`
- layout — `.claude/agents/layout.md`

## Agent List and Descriptions

### **ahk-analysis** (`.claude/agents/ahk-analysis.md`)

**Purpose**: Code-quality, performance, and pattern analysis with improvement recommendations.
**Use Case**: Slow scripts, code review, refactoring guidance, anti-pattern detection.

### **ahk-com-explorer** (`.claude/agents/ahk-com-explorer.md`)

**Purpose**: COM object and WinAPI explorer.
**Use Case**: Introspect a COM object's methods/properties, generate typed wrapper classes, and produce correct `DllCall` signatures.
**Tools**: Read, Write, Grep.

### **ahk-context** (`.claude/agents/ahk-context.md`)

**Purpose**: Project context, state, and information retrieval.
**Use Case**: Variable-scope mapping, object-lifecycle tracking, closure/scope resolution, project-state synchronization.

### **ahk-dependency-graph** (`.claude/agents/ahk-dependency-graph.md`)

**Purpose**: Dependency-graph analyzer.
**Use Case**: Parse `#Include` chains recursively to answer "what breaks if I edit X?" and "what's the full include chain?"
**Tools**: Read, Grep, Glob.

### **ahk-orchestrator-v2** (`.claude/agents/ahk-orchestrator-v2.md`)

**Purpose**: Multi-script orchestrator.
**Use Case**: Launch, stop, and restart multiple AHK scripts as one coordinated system; track running processes and dependencies.

### **ahk-profiler** (`.claude/agents/ahk-profiler.md`)

**Purpose**: Script profiler.
**Use Case**: Instrument scripts with timing around method calls, run them, and report the slowest methods and bottlenecks.
**Tools**: Read, Write, Edit, Grep.

### **ahk-test-generator** (`.claude/agents/ahk-test-generator.md`)

**Purpose**: Test generator.
**Use Case**: Read a target file, extract classes/methods, and generate Yunit-style test suites.
**Tools**: Read, Write, Edit, Grep, Glob.

### **ahk-uia-explorer** (`.claude/agents/ahk-uia-explorer.md`)

**Purpose**: UI Automation tree explorer.
**Use Case**: Dump a window's UIA control tree and generate AHK v2 code to interact with specific elements; automate third-party apps.
**Tools**: Read, Write, Grep.

### **layout** (`.claude/agents/layout.md`)

**Purpose**: GUI layout enforcement specialist.
**Use Case**: Use proactively for ANY GUI creation or refactor to guarantee overlap-free, mathematically positioned layouts with consistent spacing (tracked coordinates, no hard-coded Y values).
**Tools**: Read, MultiEdit, Write, Grep.
