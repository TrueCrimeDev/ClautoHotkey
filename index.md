# ClautoHotkey Index

A quick map of the harness. Paths are relative to the repo root. Work is routed three ways:
**skills** (model-invoked, the default front door) → **modules** (the knowledge a skill loads)
→ **agents** (fresh-context investigators).

## Skills (`skills/`)

Invoke with `/<name>`. Each skill triggers on its `description`. Knowledge skills load a
module and apply its rules; tool skills drive the interpreter or the repo directly.

**Knowledge skills**

| Skill | For | Loads |
|-------|-----|-------|
| `/ahk-gui` | GUIs, controls, layout, dark mode | `Module_GUI.md` |
| `/ahk-oop` | Classes, objects, Map, properties | `Module_Classes.md` + 4 more |
| `/ahk-text` | Strings, regex, escaping | `Module_TextProcessing.md`, `Module_Escapes.md` |
| `/ahk-fix` | Diagnose errors, debug | `Module_Errors.md` |
| `/ahk-ref` | Broad multi-domain reference | `Module_Instructions.md` + 5 more |
| `/ahk-com` | COM automation (Excel / WMI / events) | `Module_COM.md` |
| `/ahk-dllcall` | DllCall, Buffer, Struct, callbacks | `Module_DllCall.md` |
| `/ahk-winapi` | Messages, subclassing, DWM, WinRT | `Module_WinAPI.md` |
| `/ahk-versions` | Version / portability, fork features | `Module_Versions.md` |

**Tool skills**

| Skill | For | Skill | For |
|-------|-----|-------|-----|
| `/ahk-run` | Run headlessly, capture output | `/ahk-convert` | Convert v1 → v2 |
| `/ahk-eval` | Live REPL via the fork's `repl` subcommand | `/ahk-modernize` | Upgrade outdated v2 patterns |
| `/ahk-gui-gen` | Generate a GUI from a description | `/ahk-new-class` | Scaffold a new class |
| `/ahk-docs` | Search the AHK v2 docs | `/ahk-mistakes` | Recurring mistakes from the log |
| `/ahk-audit-errors` | Find silent failures | `/ahk-debug-dashboard` | Live debug state |

These ship as a Claude Code plugin, so they apply to your AutoHotkey scripts wherever
they live — see [Install](README.md#install). Skills load their modules through
`${CLAUDE_PLUGIN_ROOT}`, so nothing depends on where the repo sits.

## Modules (`Modules/`)

The knowledge skills load. Every module carries YAML frontmatter (`name` + a
subject-leading, trigger-rich `description`).

- [Module_Instructions.md](Modules/Module_Instructions.md) — engineering standards, syntax rules, the keyword and directive reference, diagnostic checklist. **Baseline.**
- [Module_Classes.md](Modules/Module_Classes.md) · [Module_Objects.md](Modules/Module_Objects.md) · [Module_ClassPrototyping.md](Modules/Module_ClassPrototyping.md) · [Module_DynamicProperties.md](Modules/Module_DynamicProperties.md) — OOP, descriptors, meta-functions.
- [Module_Arrays.md](Modules/Module_Arrays.md) · [Module_DataStructures.md](Modules/Module_DataStructures.md) — the Array API and functional helpers; Map usage and nested containers.
- [Module_TextProcessing.md](Modules/Module_TextProcessing.md) · [Module_Escapes.md](Modules/Module_Escapes.md) — strings, the full regex domain, escaping.
- [Module_GUI.md](Modules/Module_GUI.md) · [Module_Errors.md](Modules/Module_Errors.md) — GUI construction through form validation; the whole error and diagnostic domain.
- [Module_DllCall.md](Modules/Module_DllCall.md) · [Module_COM.md](Modules/Module_COM.md) · [Module_WinAPI.md](Modules/Module_WinAPI.md) — native interop.
- [Module_Versions.md](Modules/Module_Versions.md) — v2.0 / v2.1-alpha / +Console fork capability matrix and portable fallbacks.

### Supplemental (`Modules/Supplemental/`)

Eight specialized modules, loaded by explicit path rather than by a domain skill.

| Module | For |
|--------|-----|
| [Module_FatArrows.md](Modules/Supplemental/Module_FatArrows.md) | fat-arrow limits, callbacks, closures, `.Bind()` |
| [Module_Formatting.md](Modules/Supplemental/Module_Formatting.md) | the house formatting standard |
| [Module_JSDOC.md](Modules/Supplemental/Module_JSDOC.md) | JSDoc conventions, thqby LSP hover |
| [Module_MiniExamples.md](Modules/Supplemental/Module_MiniExamples.md) | official-documentation example corpus — grep it, don't read it whole |
| [Module_Testing.md](Modules/Supplemental/Module_Testing.md) | test framework, memory management, leak checks |
| [Module_Tooltip.md](Modules/Supplemental/Module_Tooltip.md) | TooltipEx (nperovic) library reference |
| [Module_UIA.md](Modules/Supplemental/Module_UIA.md) | UI Automation (UIA-v2), Chromium quirks |
| [Module_TapHold.md](Modules/Supplemental/Module_TapHold.md) | TapHoldManager library reference |

### Keeping the corpus honest

`./Tools/lint_modules.py` checks every module for banned patterns (Map constructor pairs,
wrong fence tags, `=> {`, banner dividers, removed alpha.30 constructs), frontmatter
validity, and dangling cross-references. It runs as a `pre-commit` hook over staged
modules; run it directly to lint the whole corpus.

## Agents (`agents/`)

Fresh-context investigators — launched when a task needs its own window.

- [ahk-analysis](agents/ahk-analysis.md) · [ahk-context](agents/ahk-context.md) · [ahk-dependency-graph](agents/ahk-dependency-graph.md) · [ahk-profiler](agents/ahk-profiler.md) · [ahk-test-generator](agents/ahk-test-generator.md) · [ahk-com-explorer](agents/ahk-com-explorer.md) · [ahk-uia-explorer](agents/ahk-uia-explorer.md) · [ahk-orchestrator-v2](agents/ahk-orchestrator-v2.md) · [layout](agents/layout.md)

See [agents/README.md](agents/README.md) for descriptions.

## How it routes

- A request matches a skill's `description` → the skill loads its module and applies the rules. No manual routing table.
- Domains without a dedicated module (files, hotkeys, timers, networking, screen) fall back to built-in AHK v2 knowledge.
- Agents handle heavier investigation (dependency graphs, profiling, test generation, COM/UIA exploration, layout enforcement).
