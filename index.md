# ClautoHotkey Index

A quick entry point to the most important prompts, modules, and agents in this repo.
Paths are relative to the repo root.

## Modules

- [Module_Instructions.md](Modules/Module_Instructions.md) — The foundational instruction set that orchestrates and references all modules. **Start here.**
- [Module_Arrays.md](Modules/Module_Arrays.md) — Arrays: creation, indexing, iteration, multidimensional patterns, and safe mutation idioms.
- [Module_Classes.md](Modules/Module_Classes.md) — OOP in AHK v2: constructors, properties, methods, static members, method binding, and clean class structure.
- [Module_ClassPrototyping.md](Modules/Module_ClassPrototyping.md) — Runtime class creation, prototype extension, and decorator patterns.
- [Module_DataStructures.md](Modules/Module_DataStructures.md) — Core collections; Map() over object literals, stack/queue idioms, nested structures, and safe access.
- [Module_DynamicProperties.md](Modules/Module_DynamicProperties.md) — Property getters/setters, dynamic access, meta-methods, and safe state encapsulation.
- [Module_Errors.md](Modules/Module_Errors.md) — Error class hierarchy, try/catch patterns, custom exceptions, and a diagnostic checklist.
- [Module_Escapes.md](Modules/Module_Escapes.md) — Escaping rules for quotes/backticks, regex/path strings, and common v2 pitfalls.
- [Module_GUI.md](Modules/Module_GUI.md) — GUI standards: control APIs, OnEvent() wiring, anchoring/layout math, and clean close/escape behaviors.
- [Module_Objects.md](Modules/Module_Objects.md) — Object hierarchy, property descriptors, method binding, and call rules.
- [Module_TextProcessing.md](Modules/Module_TextProcessing.md) — Strings and text: formatting, parsing, regex, escapes, and common transformations.

Advanced interop:

- [Module_DllCall.md](Modules/Module_DllCall.md) — DllCall, Buffer, NumGet/NumPut, StrPut/StrGet, CallbackCreate, and the alpha.30 typed `Struct`.
- [Module_COM.md](Modules/Module_COM.md) — COM automation: IDispatch, events, ComValue, SafeArrays, and direct vtable `ComCall`.
- [Module_WinAPI.md](Modules/Module_WinAPI.md) — Windows messages, subclassing, owner-draw, and the WinRT (Windows Runtime) ABI.

Additional modules in [Modules/Supplemental/](Modules/Supplemental/).

## Claude Agents (`.claude/agents/`)

Fresh-context investigators — launched when a task needs its own window.

- [ahk-analysis](.claude/agents/ahk-analysis.md) — Code-quality, performance, and pattern analysis with recommendations.
- [ahk-com-explorer](.claude/agents/ahk-com-explorer.md) — Introspect COM/WinAPI; generate typed wrappers and `DllCall` signatures.
- [ahk-context](.claude/agents/ahk-context.md) — Project state, variable scope, and object-lifecycle tracking.
- [ahk-dependency-graph](.claude/agents/ahk-dependency-graph.md) — Parse `#Include` chains into a dependency map.
- [ahk-orchestrator-v2](.claude/agents/ahk-orchestrator-v2.md) — Launch/stop/restart multiple scripts as one system.
- [ahk-profiler](.claude/agents/ahk-profiler.md) — Instrument scripts with timing; report the slowest methods.
- [ahk-test-generator](.claude/agents/ahk-test-generator.md) — Generate Yunit-style test suites for a class or script.
- [ahk-uia-explorer](.claude/agents/ahk-uia-explorer.md) — Dump a window's UIA tree and generate interaction code.
- [layout](.claude/agents/layout.md) — GUI layout enforcement: overlap-free, mathematically positioned controls.

See also: [agentreadme.md](.claude/agentreadme.md) — Overview of all agents.

## Related Context and Shared Prompts

- [Context_Claude.md](Context_Claude.md) — Claude-focused context to steer outputs toward strict AHK v2 OOP.
- [common_prompts.json](Lib/common_prompts.json) — Reusable prompt templates for frequent AHK v2 tasks.

### System Prompts

Per-LLM prompts built as a shared core + thin per-model wrappers. See
[System_Prompts/README.md](System_Prompts/README.md).

- [System_Prompts/_Core.md](System_Prompts/_Core.md) — the shared AHK v2 instruction core (edit rules here).
- Wrappers: [Context_Claude.md](System_Prompts/Context_Claude.md), [Context_Claude_Instructions.md](System_Prompts/Context_Claude_Instructions.md), [Context_Claude_COT.md](System_Prompts/Context_Claude_COT.md), [Context_Claude_MCP.md](System_Prompts/Context_Claude_MCP.md), [Context_ChatGPT.md](System_Prompts/Context_ChatGPT.md), [Context_Gemini.md](System_Prompts/Context_Gemini.md), [Context_Deepseek.md](System_Prompts/Context_Deepseek.md), [Context_Quasar.md](System_Prompts/Context_Quasar.md), [Context_Short.md](System_Prompts/Context_Short.md).

## How these work together

- Module_Instructions.md is the central hub; its routing table points to the topic modules that exist (Arrays, Classes, ClassPrototyping, DataStructures, DynamicProperties, Errors, Escapes, GUI, Objects, TextProcessing). Domains without a dedicated module fall back to built-in AHK v2 knowledge.
- Claude agents handle heavier investigation (analysis, dependency graphs, profiling, test generation, COM/UIA exploration, layout enforcement).
- Context files tailor tone/behavior for specific providers; common_prompts.json supplies ready-to-use building blocks.
