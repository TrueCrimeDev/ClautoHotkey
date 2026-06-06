<div align="center">

  <h1>ClautoHotkey</h1>

  <p>
    <strong>An AI-native AutoHotkey v2 development system — context modules, a Claude Code harness, a console-enabled engine, and an MCP docs server</strong>
  </p>

  <p>
    <a href="https://www.autohotkey.com/docs/v2/"><img src="https://img.shields.io/badge/AutoHotkey-v2-blue?style=flat-square&logo=autohotkey&logoColor=white" alt="AHK v2"></a>
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="MIT License"></a>
    <a href="https://github.com/TrueCrimeDev/ahk-mcp"><img src="https://img.shields.io/badge/MCP_Server-ahk--mcp-purple?style=flat-square" alt="MCP Server"></a>
  </p>

  <p>
    <a href="#the-system"><img src="https://img.shields.io/badge/The_System-1F6FEB?style=for-the-badge" alt="The System"></a>
    <a href="#modules"><img src="https://img.shields.io/badge/Modules-0078D4?style=for-the-badge" alt="Modules"></a>
    <a href="#helper-scripts"><img src="https://img.shields.io/badge/Scripts-2EA043?style=for-the-badge" alt="Scripts"></a>
    <a href="#claude-code-agents"><img src="https://img.shields.io/badge/Agents-8B5CF6?style=for-the-badge" alt="Agents"></a>
    <a href="#screenshots"><img src="https://img.shields.io/badge/Screenshots-E05D44?style=for-the-badge" alt="Screenshots"></a>
    <a href="#setup"><img src="https://img.shields.io/badge/Setup-F59E42?style=for-the-badge" alt="Setup"></a>
  </p>

</div>

---

> [!IMPORTANT]
> This is only for AHK v2. No v1 support.

A collection of structured reference modules that teach AI models how to write correct AHK v2 code. Each module includes V1-to-V2 breaking changes, API tables, constraints, and anti-patterns to prevent common mistakes.

---

<div align="center">
  <h2>The System</h2>
  <p><em>An AI-native AutoHotkey v2 development system — four parts that fit together.</em></p>
</div>

```text
            ┌─────────────── ClautoHotkey (this repo) ───────────────┐
            │  Knowledge: Modules/ — structured AHK v2 instruction set │
            │  + the Claude Code harness, wired and ready             │
            └───────────────────────┬─────────────────────────────────┘
                                     │ Claude Code
   Engine                  Tooling   │            Docs server
   AutoHotkey +Console  ←  ahk-claude-harness  →  ahk-mcp
   (Print/Eval/JSON        (hooks/rules/skills/     (docs, completion,
    diagnostics)            agents validate edits)   diagnostics)
```

| Part | What it is |
|------|-----------|
| **Engine** — [AutoHotkey +Console fork](https://github.com/TrueCrimeDev/AutoHotkey) | Console-enabled AHK v2: real stdout, `Print`, `Eval`, JSON diagnostics, structured exit codes. |
| **Tooling** — [ahk-claude-harness](https://github.com/TrueCrimeDev/ahk-claude-harness) | Claude Code hooks, rules, skills, and agents that validate every `.ahk` edit and route AHK work. |
| **Knowledge** — this repo's `Modules/` | The structured AHK v2 instruction set the AI reads (start with `Module_Instructions.md`). |
| **Docs server** — [ahk-mcp](https://github.com/TrueCrimeDev/ahk-mcp) | MCP server providing docs, code completion, and diagnostics. |

**New here?** Follow **[GETTING-STARTED.md](GETTING-STARTED.md)** for the zero-to-coding path.

---

<div align="center">
  <h2>Modules</h2>
  <p><em>All modules live in <code>Modules/</code>. Start with <strong>Module_Instructions.md</strong>, then reference others by keyword.</em></p>
</div>

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

---

<div align="center">
  <h2>Helper Scripts</h2>
</div>

| Script | Purpose |
|--------|---------|
| `_UltiLog.ahk` | AI interaction logger with grading system |
| `_Lists.ahk` | Dark-themed JSON list editor |
| `_Context_Creator.ahk` | Combine modules for LLM context windows |
| `Scripts/ClipboardHistoryCombiner.ahk` | Batch clipboard errors for debugging |
| `Scripts/Clip_SearchCode.ahk` | Apply LLM code changes to VS Code |

---

<div align="center">
  <h2>Claude Code Agents</h2>
  <p><em>See <a href=".claude/agentreadme.md">agentreadme.md</a> for details.</em></p>
</div>

| Agent | Purpose |
|-------|---------|
| `ahk-version-detector` | Detects v1 vs v2 and triggers conversion |
| `ahk-converter-runner` | Automated v1-to-v2 conversion |
| `v1-to-v2-migrator` | Manual migration for edge cases |
| `gui-builder` | GUI creation with events and validation |
| `ahk-gui-layout-enforcer` | Mathematical overlap-free layouts |

---

<div align="center">
  <h2>Screenshots</h2>
</div>

<table>
  <tr>
    <td align="center"><strong>Ultimate Logger</strong></td>
    <td align="center"><strong>List Editor</strong></td>
  </tr>
  <tr>
    <td><img src="Assets/UltimateLogger.png" alt="Ultimate Logger" width="450"></td>
    <td><img src="https://github.com/TrueCrimeDev/DarkMode/raw/main/screenshot1.png" alt="List Editor" width="450"></td>
  </tr>
</table>

---

<div align="center">
  <h2>Setup</h2>
</div>

```bash
git clone https://github.com/TrueCrimeDev/ClautoHotkey.git
```

Requires AutoHotkey v2. Add `Modules/` to your AI assistant's context or knowledge base.

---

<div align="center">
  <h2>AutoHotkey Console Fork</h2>
  <p><em>The recommended interpreter — console-enabled AHK v2 for AI workflows.</em></p>
</div>

This project is built around the **[AutoHotkey v2 +Console fork](https://github.com/TrueCrimeDev/AutoHotkey)**,
a console-enabled build that makes AHK far more AI-friendly:

- **Real stdout/stderr + `Print(fmt, vals*)`** — scripts emit output an AI reads directly, no GUI round-trip.
- **`Eval(expr)`** — runtime expression evaluator for REPL-style testing (the `/ahk-eval` skill).
- **JSON diagnostics** (`check /Diag=json`) — structured syntax errors the post-edit hook parses.
- **Structured crash logs + exit codes** — `/CrashLog`, exit `130` on Ctrl+C, and more.

Build it from source (branch `alpha`), point `AHK_BIN_WIN` at it, and set `AHK_DIAG_JSON=1`.
Stock AutoHotkey v2 also works — the harness falls back to `/validate` — but without `Print`/`Eval` or JSON diagnostics.

**Command-line modes**

| Mode | Command |
|------|---------|
| Standard run | `AutoHotkey64.exe script.ahk` |
| Debugger | `AutoHotkey64.exe /Debug script.ahk` |
| Headless error output | `AutoHotkey64.exe /ErrorStdOut script.ahk` |
| Hard headless | `AutoHotkey64.exe /Headless script.ahk` |
| JSON diagnostics | `AutoHotkey64.exe /Headless /Diag=json script.ahk` |
| Colored errors | `AutoHotkey64.exe /ErrorStdOut:color script.ahk` |
| Encoding override | `AutoHotkey64.exe /ErrorStdOut=UTF-8 script.ahk` |
| Check (syntax only) | `AutoHotkey64.exe check script.ahk` (or `/Check script.ahk`) |
| Test | `AutoHotkey64.exe test script.ahk` (or `/Test script.ahk`) |

---

<div align="center">
  <h2>Claude Code Harness</h2>
  <p><em>Path-scoped rules, skills, agents, and hooks that validate every AHK v2 edit.</em></p>
</div>

`.claude/` ships a full Claude Code harness: it auto-validates each `.ahk` edit,
auto-loads the relevant rule when you touch a matching file, and routes work to
AHK-specific skills (`/ahk-gui`, `/ahk-fix`, `/ahk-oop`, …) and investigation
agents. Turn it on after cloning:

```bash
cp harness.env.example harness.env   # set AHK_BIN_WIN to your AutoHotkey64.exe path
./setup.sh                            # renders settings.json, makes hooks executable
```

Then open this folder as the project in Claude Code. Set `AHK_DIAG_JSON=1` in
`harness.env` if you run the v2.1-alpha.30+Console fork (richer diagnostics);
leave `0` for stock AHK v2. Requires WSL or Git Bash and `jq`. The harness is
also published as a standalone template:
[ahk-claude-harness](https://github.com/TrueCrimeDev/ahk-claude-harness).

---

<div align="center">
  <h2>Contributing</h2>
  <p>Contributions welcome. Also check out the <a href="https://github.com/TrueCrimeDev/ahk-mcp">AHK MCP Server</a>.</p>
</div>

---

<div align="center">
  <h2>Credits</h2>
  <p>
    <a href="https://www.autohotkey.com/docs/v2/">AHK v2 Docs</a> &bull;
    <a href="https://github.com/G33kDude">g.ahk</a> &bull;
    <a href="https://github.com/Descolada">Descolada</a> &bull;
    <a href="https://github.com/The-CoDingman">Panaku</a> &bull;
    <a href="https://github.com/0w0Demonic/AquaHotkey.git">0w0Demonic</a>
  </p>
</div>
