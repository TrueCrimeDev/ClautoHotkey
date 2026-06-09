# ClautoHotkey Index

A quick map of the harness. Paths are relative to the repo root. Work is routed three ways:
**skills** (model-invoked, the default front door) → **modules** (the knowledge a skill loads)
→ **agents** (fresh-context investigators).

## Skills (`.claude/skills/`)

Invoke with `/<name>`. Each skill triggers on its `description` and loads the matching module.

| Skill | For | Skill | For |
|-------|-----|-------|-----|
| `/ahk-gui` | GUIs, controls, dark mode | `/ahk-com` | COM automation (Excel/WMI/events) |
| `/ahk-gui-gen` | Generate a GUI from a description | `/ahk-dllcall` | DllCall, Buffer, Struct, callbacks |
| `/ahk-oop` | Classes, objects, Map, properties | `/ahk-winapi` | Messages, subclassing, DWM, WinRT |
| `/ahk-text` | Strings, regex, escaping | `/ahk-versions` | Version/portability, fork features |
| `/ahk-fix` | Diagnose errors, debug | `/ahk-convert` | Convert v1 → v2 |
| `/ahk-run` | Run headlessly, capture output | `/ahk-modernize` | Upgrade outdated v2 patterns |
| `/ahk-eval` | Live REPL via the fork's `Eval()` | `/ahk-new-class` | Scaffold a new class |
| `/ahk-docs` | Search the AHK v2 docs | `/ahk-ref` | Broad multi-domain reference |
| `/ahk-audit-errors` | Find silent failures | `/ahk-mistakes` | Recurring mistakes from the log |
| `/ahk-debug-dashboard` | Live debug state | | |

## Modules (`Modules/`)

The knowledge skills load. Each carries YAML frontmatter (`name` + a trigger-rich `description`).

- [Module_Instructions.md](Modules/Module_Instructions.md) — Foundational standards, OOP principles, syntax rules, diagnostic checklist. **Baseline.**
- [Module_Arrays.md](Modules/Module_Arrays.md) · [Module_Classes.md](Modules/Module_Classes.md) · [Module_ClassPrototyping.md](Modules/Module_ClassPrototyping.md) · [Module_Objects.md](Modules/Module_Objects.md) · [Module_DynamicProperties.md](Modules/Module_DynamicProperties.md) — OOP and data.
- [Module_DataStructures.md](Modules/Module_DataStructures.md) · [Module_TextProcessing.md](Modules/Module_TextProcessing.md) · [Module_Escapes.md](Modules/Module_Escapes.md) — collections, strings, escaping.
- [Module_GUI.md](Modules/Module_GUI.md) · [Module_Errors.md](Modules/Module_Errors.md) — GUI and error handling.
- [Module_DllCall.md](Modules/Module_DllCall.md) · [Module_COM.md](Modules/Module_COM.md) · [Module_WinAPI.md](Modules/Module_WinAPI.md) — advanced interop (native calls, COM, messages/DWM/WinRT).
- [Module_Versions.md](Modules/Module_Versions.md) — v2.0 / v2.1-alpha / +Console fork capability matrix and portable fallbacks.

Additional material in [Modules/Supplemental/](Modules/Supplemental/).

## Agents (`.claude/agents/`)

Fresh-context investigators — launched when a task needs its own window.

- [ahk-analysis](.claude/agents/ahk-analysis.md) · [ahk-context](.claude/agents/ahk-context.md) · [ahk-dependency-graph](.claude/agents/ahk-dependency-graph.md) · [ahk-profiler](.claude/agents/ahk-profiler.md) · [ahk-test-generator](.claude/agents/ahk-test-generator.md) · [ahk-com-explorer](.claude/agents/ahk-com-explorer.md) · [ahk-uia-explorer](.claude/agents/ahk-uia-explorer.md) · [ahk-orchestrator-v2](.claude/agents/ahk-orchestrator-v2.md) · [layout](.claude/agents/layout.md)

See [agentreadme.md](.claude/agentreadme.md) for descriptions.

## Legacy (`legacy/`)

Pre-harness artifacts kept for reference, not used by the harness: the per-LLM
`System_Prompts/`, `_Context_Creator.ahk`, and the older helper scripts. See
[legacy/README.md](legacy/README.md).

## How it routes

- A request matches a skill's `description` → the skill loads its module and applies the rules. No manual routing table.
- Domains without a dedicated module (files, hotkeys, timers, networking, screen) fall back to built-in AHK v2 knowledge.
- Agents handle heavier investigation (dependency graphs, profiling, test generation, COM/UIA exploration, layout enforcement).
