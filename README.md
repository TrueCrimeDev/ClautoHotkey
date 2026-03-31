# ClautoHotkey

AutoHotkey v2 context modules, agents, and helper scripts for AI-assisted development.

## What This Is

A collection of structured reference modules that teach AI models how to write correct AHK v2 code. Each module includes V1-to-V2 breaking changes, API tables, constraints, and anti-patterns to prevent common mistakes.

## Modules

All modules live in `Modules/`. Start with **Module_Instructions.md**, then reference others by keyword:

| Keyword | Module | Covers |
|---------|--------|--------|
| class, inheritance | `Module_Classes.md` | OOP, meta-functions, factory/observer patterns |
| object, HasProp | `Module_Objects.md` | Object hierarchy, descriptors, method binding |
| array, collection | `Module_Arrays.md` | 1-based indexing, functional patterns, sorting |
| gui, window, dialog | `Module_GUI.md` | GUI construction, ListView/TreeView, resize |
| error, try, catch | `Module_Errors.md` | Error hierarchy, diagnostics, custom exceptions |
| map, data, storage | `Module_DataStructures.md` | Array vs Map, nested structures, safe access |
| string, regex | `Module_TextProcessing.md` | String ops, regex, escapes, continuations |
| property, DefineProp | `Module_DynamicProperties.md` | Descriptors, closures, computed properties |
| prototype, ObjSetBase | `Module_ClassPrototyping.md` | Runtime class creation, decorators |
| escape, backtick | `Module_Escapes.md` | Quote/regex/path escaping rules |

Additional modules in `Modules/Supplemental/`.

## Helper Scripts

| Script | Purpose |
|--------|---------|
| `_UltiLog.ahk` | AI interaction logger with grading system |
| `_Lists.ahk` | Dark-themed JSON list editor |
| `_Context_Creator.ahk` | Combine modules for LLM context windows |
| `Scripts/ClipboardHistoryCombiner.ahk` | Batch clipboard errors for debugging |
| `Scripts/Clip_SearchCode.ahk` | Apply LLM code changes to VS Code |

## Claude Code Agents

See [agentreadme.md](.claude/agentreadme.md) for details.

- `ahk-version-detector` — Detects v1 vs v2 and triggers conversion
- `ahk-converter-runner` — Automated v1-to-v2 conversion
- `v1-to-v2-migrator` — Manual migration for edge cases
- `gui-builder` — GUI creation with events and validation
- `ahk-gui-layout-enforcer` — Mathematical overlap-free layouts

## Setup

```bash
git clone https://github.com/TrueCrimeDev/ClautoHotkey.git
```

Requires AutoHotkey v2. Add `Modules/` to your AI assistant's context or knowledge base.

## Screenshots

![Ultimate Logger](Assets/UltimateLogger.png)
![List Editor](https://github.com/TrueCrimeAudit/DarkMode/raw/main/screenshot1.png)

## Contributing

Contributions welcome. Also check out the [AHK MCP Server](https://github.com/TrueCrimeAudit/ahk-mcp).

## Credits

[AHK v2 Docs](https://www.autohotkey.com/docs/v2/) | Thanks to [g.ahk](https://github.com/G33kDude), [Descolada](https://github.com/Descolada), [Panaku](https://github.com/The-CoDingman), [0w0Demonic](https://github.com/0w0Demonic/AquaHotkey.git)
