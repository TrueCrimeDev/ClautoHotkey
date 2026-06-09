# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## Project Overview

ClautoHotkey is an **AI-native AutoHotkey v2 development system**. The centerpiece is
a Claude Code harness (`.claude/`) that validates every `.ahk` edit, auto-loads the
right rules, and routes work to AHK-specific skills and agents — backed by a
console-enabled engine, structured knowledge modules, and an optional MCP docs server.

**AHK v2 only. No v1 support.**

## Interpreter

All AutoHotkey execution resolves the binary from `harness.env`
(`AHK_BIN_WIN` → `AHK_BIN_WSL`) — never hardcode a path. The `check-ahk-binary` hook
blocks any other `AutoHotkey*.exe` in a Bash command.

```bash
source .claude/hooks/_harness-env.sh
"$AHK_BIN_WSL" /ErrorStdOut=utf-8 "<script_path>"
```

This repo targets the **v2.1-alpha.30 +Console fork**
(<https://github.com/TrueCrimeDev/AutoHotkey>): real stdout/stderr, `Print(fmt, vals*)`,
`Eval(expr)`, JSON diagnostics (`check /Diag=json`), and structured exit codes. Stock
AutoHotkey v2 also works (set `AHK_DIAG_JSON=0`) but without `Print`/`Eval` or JSON
diagnostics. Fork details: `.claude/rules/ahk-interpreter.md` and `ahk-fork-features.md`.

## How work is routed

The harness has three layers — use them in priority order. The full tables live in
`README.md`; the essentials:

1. **Auto-loading rules** (`.claude/rules/`) activate by file path — no invocation
   needed. Editing any `.ahk` pulls in `ahk-v2-syntax`; editing under `Lib/` pulls in
   `lib-development`; editing a GUI file pulls in `gui-work`. Also: `main-script`,
   `test-scripts`, `demo-location`, `no-banner-comments`, `ahk-interpreter`,
   `ahk-fork-features`.

2. **Skills** (`.claude/skills/`) handle most routine work — invoke with `/<name>`:
   `/ahk-gui`, `/ahk-gui-gen`, `/ahk-oop`, `/ahk-text`, `/ahk-fix`, `/ahk-run`,
   `/ahk-eval`, `/ahk-convert`, `/ahk-modernize`, `/ahk-new-class`, `/ahk-docs`,
   `/ahk-ref`, `/ahk-audit-errors`, `/ahk-mistakes`, `/ahk-debug-dashboard`. Cheap,
   in-context. **Skills are the default entry point for AHK work.**

3. **Agents** (`.claude/agents/`) run in a fresh context window when a task warrants it:
   `ahk-analysis`, `ahk-context`, `ahk-dependency-graph`, `ahk-profiler`,
   `ahk-test-generator`, `ahk-com-explorer`, `ahk-uia-explorer`, `ahk-orchestrator-v2`,
   `layout`. Launch one only when the investigation justifies the boot cost.

Hooks fire automatically across the session: a session primer, v1-syntax detection,
rule injection, the post-edit validator (which **blocks** a broken edit), auto-reload
of running scripts, and an error logger that feeds `/ahk-mistakes`.

Skills and rules pull the relevant knowledge module for you. Read
`Modules/Module_Instructions.md` directly only when working **outside** a skill.

## AHK v2 coding standards

### Core requirements
- **Pure AHK v2 OOP** — instantiate classes by calling them; never `new ClassName()`.
- **Data storage** — `Map()` for runtime key-value data. Object literal `{}` is correct
  and expected for property descriptors (`DefineProp`, `{get, set, call}`) and meta-API
  calls; on the fork, a typed `Struct` fits fixed numeric records. The rule is "no `{}`
  as a data dictionary," not "no `{}` ever."
- **Event binding** — bind every callback with `.Bind(this)`.
- **Resource cleanup** — release timers/handles in `__Delete()`.
- **Variable scope** — explicit declarations; no shadowing of a global or a built-in
  class name (don't name a local `Gui`, `Menu`, `Array`).
- **Fat arrows** — single-expression bodies only; multi-line logic uses a named method.
- **Errors** — throw typed errors (`TypeError`/`ValueError`/custom) and handle them in
  `try/catch`. Never an empty catch; never swallow a failure.

### GUI standards
- Class-based construction with deterministic, mathematically positioned layout.
- Events via `OnEvent()`; input validation; clean close/escape behaviour.
- **Dark mode** — use `Lib/DarkModeModular.ahk` (`#Include ..\Lib\DarkModeModular.ahk`),
  `DarkGui()` in place of `Gui()`, controls via `DarkGui.Add("Type", ...)`, `+Accent`
  for blue buttons.

### Data handling
- Arrays are 1-based. PCRE flags `i/m/s/x` only. Backtick escaping for quotes/specials.
- alpha.30 forms: `(a?)()` not `a?.()`; class-ref typed properties (`Int32`/`UInt32`/
  `IntPtr`) not type strings (`u32`/`uptr`); parenthesize `!(a ?? b)`.

### Comments
- No banner dividers (`; ====`, `; ----`) — see the `no-banner-comments` rule.
- Plain prose section comments are fine; JSDoc/doc-comments when the user asks.

## Knowledge modules

Structured AHK v2 knowledge lives in `Modules/` (start: `Module_Instructions.md`). The
routing table there maps keywords to the modules that exist:

| Keyword | Module |
|---------|--------|
| class, inheritance, extends | `Module_Classes.md` |
| object, property, descriptor, bind | `Module_Objects.md` |
| array, list, collection | `Module_Arrays.md` |
| map, storage, settings, cache | `Module_DataStructures.md` |
| gui, window, dialog, control | `Module_GUI.md` |
| error, try, catch, debug | `Module_Errors.md` |
| string, regex, text, parse | `Module_TextProcessing.md` |
| escape, backtick, quote | `Module_Escapes.md` |
| property, DefineProp, closure, fat arrow | `Module_DynamicProperties.md` |
| prototype, runtime class, decorator | `Module_ClassPrototyping.md` |
| dllcall, buffer, struct, callbackcreate | `Module_DllCall.md` |
| com, comobject, excel, wmi, idispatch | `Module_COM.md` |
| onmessage, sendmessage, subclass, winapi, winrt | `Module_WinAPI.md` |

Domains without a dedicated module (files, hotkeys, timers, networking, screen) fall
back to built-in AHK v2 knowledge. Per-LLM system prompts that mirror these
rules for other models live in `System_Prompts/` (a shared `_Core.md` + thin wrappers).

## Directory structure

```
/Modules/      - Structured AHK v2 knowledge (start at Module_Instructions.md)
/System_Prompts/ - Per-LLM prompts (_Core.md + thin wrappers)
/AHK_Notes/    - Examples and patterns (Classes, Concepts, Methods, Patterns, Snippets)
/Scripts/      - User-facing utility applications
/Tests/        - Test scripts and validation tools
/Lib/          - Shared libraries (DarkModeModular.ahk, etc.)
/.claude/      - The harness: rules, skills, agents, hooks
```

## Important notes

- **AHK v2 only** — no v1 code or compatibility.
- **MCP is optional** — the `ahk-mcp` docs/diagnostics server is a first-class but
  optional component (see README). Don't spin up servers unprompted; fall back to the
  modules and built-in knowledge when it isn't connected.
- **Targeted reading** — read files relevant to the request; avoid broad discovery scans.
- **Skills first** — let skills/rules pull modules; don't run a multi-agent pipeline
  unless the user asks.
- **IDE configs** — `.cursor/` and `.clinerules` hold configs for other editors; they
  are not part of the Claude harness.
