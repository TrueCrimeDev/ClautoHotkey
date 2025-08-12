# ClautoHotkey Index

A quick entry point to the most important prompts, modules, and agents in this repo.

## ClautoHotkey Modules

- [Module_Arrays.md](ClautoHotkey/Modules/Module_Arrays.md) — Arrays: creation, indexing, iteration, multidimensional patterns, and safe mutation idioms.
- [Module_Classes.md](ClautoHotkey/Modules/Module_Classes.md) — OOP in AHK v2: constructors, properties, methods, static members, method binding, and clean class structure.
- [Module_DataStructures.md](ClautoHotkey/Modules/Module_DataStructures.md) — Core collections and patterns; emphasizes Map() over object literals, stack/queue idioms, and data handling best practices.
- [Module_DynamicProperties.md](ClautoHotkey/Modules/Module_DynamicProperties.md) — Property getters/setters, dynamic access patterns, meta-methods, and safe state encapsulation.
- [Module_Escapes.md](ClautoHotkey/Modules/Module_Escapes.md) — Escaping rules for quotes/backticks, regex/path strings, and common pitfalls to avoid in v2.
- [Module_GUI.md](ClautoHotkey/Modules/Module_GUI.md) — GUI standards: control APIs, event wiring with OnEvent(), anchoring/layout math, and clean close/escape behaviors.
- [Module_Instructions.md](ClautoHotkey/Modules/Module_Instructions.md) — The foundational instruction set that orchestrates and references all modules for consistent AHK v2 output.
- [Module_Objects.md](ClautoHotkey/Modules/Module_Objects.md) — Objects and Maps: strict Map() usage, prototyping basics, safe key/value handling, and method call rules.
- [Module_TextProcessing.md](ClautoHotkey/Modules/Module_TextProcessing.md) — Strings and text: formatting, parsing, regex helpers, and common transformations.

## Claude Agents (.claude)

- [ahk-version-detector](ClautoHotkey/.claude/agents/ahk-version-detector.md) — Detects v1 vs v2 code and triggers conversion.
- [ahk-converter-runner](ClautoHotkey/.claude/agents/ahk-converter-runner.md) — Locates and runs automated v1→v2 conversion tooling with backups.
- [v1-to-v2-migrator](ClautoHotkey/.claude/agents/v1-to-v2-migrator.md) — Manual migration for edge cases and complex conversions.
- [gui-builder](ClautoHotkey/.claude/agents/gui-builder.md) — Robust AHK v2 GUI creation with proper events and validation.
- [ahk-gui-layout-enforcer](ClautoHotkey/.claude/agents/ahk-gui-layout-enforcer.md) — Enforces mathematical, overlap-free GUI layouts.
- [layout](ClautoHotkey/.claude/agents/layout.md) — Focused layout enforcement with tracked coordinates and spacing.

See also: [agentreadme.md](ClautoHotkey/.claude/agentreadme.md) — Overview and coordination of all agents.

## Related Context and Shared Prompts

- [Context_Claude.md](ClautoHotkey/Context_Claude.md) — Claude-focused context to steer outputs toward strict AHK v2 OOP and affirmative phrasing.
- [common_prompts.json](ClautoHotkey/Lib/common_prompts.json) — Reusable prompt templates for frequent AHK v2 tasks (clipboard tools, FS watchers, snippet managers, etc.).
- [AHKv2_Rules.md](ClautoHotkey/docs/AHKv2_Rules.md) — High-level AHK v2 rules and standards.
- [AHKv2_Rules_README.md](ClautoHotkey/docs/AHKv2_Rules_README.md) — Companion notes for the rules file.

### System Prompts

- [System_Prompts/AHKv2_Class_Instantiation.md](ClautoHotkey/System_Prompts/AHKv2_Class_Instantiation.md)
- [System_Prompts/AHKv2_Testing_Instructions.md](ClautoHotkey/System_Prompts/AHKv2_Testing_Instructions.md)
- [System_Prompts/Context_ChatGPT.md](ClautoHotkey/System_Prompts/Context_ChatGPT.md)
- [System_Prompts/Context_Claude.md](ClautoHotkey/System_Prompts/Context_Claude.md)
- [System_Prompts/Context_Claude_COT.md](ClautoHotkey/System_Prompts/Context_Claude_COT.md)
- [System_Prompts/Context_Claude_Instructions.md](ClautoHotkey/System_Prompts/Context_Claude_Instructions.md)
- [System_Prompts/Context_Claude_MCP.md](ClautoHotkey/System_Prompts/Context_Claude_MCP.md)
- [System_Prompts/Context_COT_BU.md](ClautoHotkey/System_Prompts/Context_COT_BU.md)
- [System_Prompts/Context_Gemini.md](ClautoHotkey/System_Prompts/Context_Gemini.md)
- [System_Prompts/Context_PromptMaker.md](ClautoHotkey/System_Prompts/Context_PromptMaker.md)
- [System_Prompts/Context_Quasar.md](ClautoHotkey/System_Prompts/Context_Quasar.md)
- [System_Prompts/Prompt_Simple.md](ClautoHotkey/System_Prompts/Prompt_Simple.md)

(Note: Some context names may have provider-specific variants.)

## How these work together

- Module_Instructions.md is the central hub that references the topic modules to keep outputs consistent with your AHK v2 standards.
- Topic modules (Arrays, Classes, Objects, GUI, Text, Escapes, DynamicProperties, DataStructures) provide composable guidance that the instructions pull from.
- Claude agents automate detection, conversion, and GUI layout enforcement to keep codebases modern and maintainable.
- Context files tailor tone/behavior for specific providers and scenarios; common_prompts.json supplies ready-to-use building blocks.
