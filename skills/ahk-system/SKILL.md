---
name: ahk-system
description: >
  Operating-system and script-shell knowledge for AHK v2 — files and folders, clipboard, Run and exit
  codes, process and window waits, registry, environment variables, script directives, A_ path variables,
  #Include and #Import resolution, tray, OnExit, elevation, and the +Console fork launch flags.
  TRIGGER when: user says "read a file", "write a file", "append to a log", "file exists", "loop files",
  "parse CSV", "INI", "clipboard", "Run", "RunWait", "exit code", "process", "registry", "environment
  variable", "#Requires", "#SingleInstance", "#Include", "#Import", "A_ScriptDir", "working directory",
  "tray menu", "OnExit", "run as admin", "script keeps exiting", "Ahk2Exe".
  Examples: "save settings to a file", "wait for notepad to close", "read a registry value",
  "relaunch as administrator", "why does my script exit", "add a tray menu"
---

# AHK v2 System, Files and Script Environment

Load the module that matches the request. Load two when the task spans both.

## How to use

1. Files, folders, encodings, CSV, INI, atomic writes: `${CLAUDE_PLUGIN_ROOT}/Modules/Module_FileSystem.md`
2. Clipboard, Run/RunWait, processes, registry, environment, shutdown: `${CLAUDE_PLUGIN_ROOT}/Modules/Module_System.md`
3. Directives, A_ variables, #Include/#Import, tray, OnExit, elevation, Ahk2Exe, fork launch flags and exit codes: `${CLAUDE_PLUGIN_ROOT}/Modules/Module_ScriptEnvironment.md`

## Quick answers

- **Files:** pass an explicit encoding to `FileRead`, `FileAppend` and `FileOpen`. Write through a temp file and move it when a partial write would hurt.
- **Run:** `RunWait` returns the exit code directly. `ErrorLevel` does not exist in v2.
- **Waits:** give every `ProcessWait` and `WinWait` a timeout and check its return value.
- **Persistence:** a script with hotkeys, a GUI or a timer stays alive. Anything else exits at the end of the auto-execute section.
- **Headless runs on the fork:** `/Headless /ErrorStdOut`. Exit codes 10, 11, 12 and 130 are fork-only.

COM automation and WMI belong to `/ahk-com`. Raw Win32 calls belong to `/ahk-dllcall` and `/ahk-winapi`.
