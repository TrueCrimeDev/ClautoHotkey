<div align="center">
  <h1>ClautoHotkey Coding Agent</h1>
  <p>
    <strong>AutoHotkey v2 Agent Materials</strong>
  </p>
  <p>
    <a href="#features"><img src="https://img.shields.io/badge/Features-blue?style=for-the-badge" alt="Features"></a>
    <a href="#installation"><img src="https://img.shields.io/badge/Install-green?style=for-the-badge" alt="Installation"></a>
    <a href="#usage"><img src="https://img.shields.io/badge/Usage-purple?style=for-the-badge" alt="Usage"></a>
    <a href="#AutoHotkey"><img src="https://img.shields.io/badge/Develop-orange?style=for-the-badge" alt="AutoHotkey"></a>
  </p>
</div>

> [!IMPORTANT]
> UPDATED 08/07/25: Added new List Editor GUI, Agents, Claude Code commands, reformatted all prompts for more modern LLM prompting guidelines
> This readme was not created using AI, so it's worth reading lol

ClautoHotkey is a suite of prompts, modules, and scripts for AutoHotkey v2 development when using AI. There are structured instructions, debugging tools, and strict coding guidelines to help generate high-quality, maintainable, and object-oriented AHK v2 code.

## Features

- Prompt Engineering: The main instruction prompts and supplemental modules are designed with current best practices in structure and language to invoke tools and proper chain of thought methods (`Module_Instructions.md`) for guiding AI models in AHK v2 code generation.
- Structured Coding Rules: The prompts & modules also provide in-depth rules for the LLMs to adhere to that reduce AHK v2 errors significantly.
- Cline/Cursor Support: Features Clinerules files and Cursor instructions for those who use that them. I don't currently use either that often but I have set them up to test.
- Development Helper GUIs: Utilities logging (`_UltiLog.ahk`), context management (`Context_Creator.ahk`), feeding the LLM error messages (`Scripts/ClipboardHistoryCombiner.ahk`), and updating your code with changes made in an LLM's GUI (`Scripts/Clip_SearchCode.ahk`)
- AHK_Notes: This is a ton of notes taken from all kinds of different places. I have an LLM that I feel posts/comments/chats/repos in to and it feeds them into this folder.
- AHK-Server: If you see references to this, I am working on an MCP server using Typescript but would be cool with changing to Python if there's people who want to help with Python dev. The server's goal is to be able to pass in the information in `ClautoHotkey/Data` to provide the prompts and modules just like this repo but directly into a LLM. This will include LLM style linting (you can only do so much) to debug any problems in the script. Please help me lol ([ahk-server](https://github.com/TrueCrimeAudit/ahk-mcp/tree/main%29)).
- AHK v2 Support: This is only for AHK v2. I won't make anything for v1. Why? Don't wanna. Should you switch to v2? Yes. Why? It's better
-

## Getting Started

1. **Prerequisites:**
   - AutoHotkey v2.x installed.
   - If you have AutoHotkey v1 installed, uninstall. It doesn't change anything, but you can do it, just use AHK v2 fully.
2. **Setup:**
   - Clone this repository to your local machine using `git clone https://github.com/TrueCrimeAudit/ClautoHotkey.git`
   - Integrate the `System_Prompts` and `Modules` directories into your AI assistant's context or knowledge base.
   - Refer to `Cline/Using_Cline_for_AHKv2.md` for specific integration instructions if you are using the Cline environment.

### Auto-Approval in Claude Code

I use a "cc" WSL command to auto approval repetitive approval requests. You can do this by adding a "dangerous" Claude Code alias to your WSL profile (be careful, or whatever, you know the drill). Here's how:

```bash
nano ~/.bashrc    ; built-in method
code ~/.bashrc    ; if you use vscode
```

Navigate with arrows, paste in both aliases:

```bash
alias cc='$HOME/.claude/local/claude --dangerously-skip-permissions'
alias ccsafe='$HOME/.claude/local/claude'
```

Save and close:

- Nano → `CTRL+O`, `Enter`, `CTRL+X`
- VS Code → Save as normal

Reload your profile so the aliases work now:

```bash
source ~/.bashrc
```

Test:

```bash
alias cc
alias ccsafe
```

You should see `cc` mapped to `--dangerously-skip-permissions` and `ccsafe` without it.

## Components

### Prompting & Instruction System

These modules provide the core intelligence for guiding AI models to generate precise and compliant AHK v2 code.

# ClautoHotkey Index

A quick entry point to the most important prompts, modules, and agents in this repo. There's a number of supplemental modules too in the `modules/supplemental` folder. These are extra modules you can use when they are needed.

## ClautoHotkey Modules

- [Module_Instructions.md](ClautoHotkey/Modules/Module_Instructions.md) — The foundational instruction set that orchestrates and references all modules for consistent AHK v2 output.
- [Module_Arrays.md](ClautoHotkey/Modules/Module_Arrays.md) — Arrays: creation, indexing, iteration, multidimensional patterns, and safe mutation idioms.
- [Module_Classes.md](ClautoHotkey/Modules/Module_Classes.md) — OOP in AHK v2: constructors, properties, methods, static members, method binding, and clean class structure.
- [Module_DataStructures.md](ClautoHotkey/Modules/Module_DataStructures.md) — Core collections and patterns; emphasizes Map() over object literals, stack/queue idioms, and data handling best practices.
- [Module_DynamicProperties.md](ClautoHotkey/Modules/Module_DynamicProperties.md) — Property getters/setters, dynamic access patterns, meta-methods, and safe state encapsulation.
- [Module_Escapes.md](ClautoHotkey/Modules/Module_Escapes.md) — Escaping rules for quotes/backticks, regex/path strings, and common pitfalls to avoid in v2.
- [Module_GUI.md](ClautoHotkey/Modules/Module_GUI.md) — GUI standards: control APIs, event wiring with OnEvent(), anchoring/layout math, and clean close/escape behaviors.
- [Module_Objects.md](ClautoHotkey/Modules/Module_Objects.md) — Objects and Maps: strict Map() usage, prototyping basics, safe key/value handling, and method call rules.
- [Module_TextProcessing.md](ClautoHotkey/Modules/Module_TextProcessing.md) — Strings and text: formatting, parsing, regex helpers, and common transformations.

## Claude Agents (.claude)

See: [agentreadme.md](ClautoHotkey/.claude/agentreadme.md) — Overview and coordination of all agents.

- [ahk-version-detector](ClautoHotkey/.claude/agents/ahk-version-detector.md) — Detects v1 vs v2 code and triggers conversion.
- [ahk-converter-runner](ClautoHotkey/.claude/agents/ahk-converter-runner.md) — Locates and runs automated v1→v2 conversion tooling with backups.
- [v1-to-v2-migrator](ClautoHotkey/.claude/agents/v1-to-v2-migrator.md) — Manual migration for edge cases and complex conversions.
- [gui-builder](ClautoHotkey/.claude/agents/gui-builder.md) — Robust AHK v2 GUI creation with proper events and validation.
- [ahk-gui-layout-enforcer](ClautoHotkey/.claude/agents/ahk-gui-layout-enforcer.md) — Enforces mathematical, overlap-free GUI layouts.
- [layout](ClautoHotkey/.claude/agents/layout.md) — Focused layout enforcement with tracked coordinates and spacing.

## Helpful GUIs

Here are some visual examples of the helper scripts in action:

### Ultimate Logger (`_UltiLog.ahk`)

The Ultimate Logger is a robust logging and prompt management tool. It features a GUI for reviewing AI interaction logs, managing prompt templates, executing AHK code snippets, and displaying errors. This is how Ilog all of my tests for each new LLM when it comes out. There is a four catagory grading system I use to log how good the script is and any errors the LLM produced. I am going to be adding some more functionality to this soon.

![Ultimate Logger](Assets/UltimateLogger.png)

### Clipboard History Combiner (`Scripts/ClipboardHistoryCombiner.ahk`)

This script provides a GUI to view and manage your Windows clipboard history. It allows you to select multiple clipboard items, combine them into a single text, and copy them back to the clipboard. It's particularly useful for copy and pasting errors from AHK. The "copy errors" button will copy all clipboards from the first clipboard until there's a clipboard that starts with "#Requires". This is useful to me because I copy all of my errors to my clipboard after copying and pasting the new script into VsCode. It also prefixes a prompt for the LLM to thinking through the errors when it reads the debugging information. This uses the clipboardhistory.ahk script from one of the 🐐 `https://github.com/nperovic`.

![Clipboard History Combiner](Assets/ClipboardHistoryCombiner.png)

### Context Creator (`Context_Creator.ahk`)

This is a simple way to combine your modules to make them easy to copy and paste into an LLM to start testing. Some new LLM providers don't have system prompt functionality or GUIs so I combine them and paste them into the context window.

![Context Creator (Module Selector)](Assets/ModuleSelector.png)

### Clip Search Code (`Scripts/Clip_SearchCode.ahk`)

This is a script I put together to easily copy and paste sections of code in VsCode from the LLM GUIs. This helps me because it searches for the first line of the clipboard in the codebase and collapses the function/class and writes over it with the new code. This is possible by selecting the write areas in the LLM GUI by having a response style that will edit the code in chunks. Look at the response `Styles\Style_CodeArchitect.md` for an example of that.

### JSON List Manager (`__Lists.ahk`)

JSON List Editor is a dark-themed list-management tool that helps organize snippets, links, prompts, and other text-based collections inside a clean split-pane interface. On the left, a numbered **ListView** displays each item’s title and a short preview, while on the right a multi-line editor lets you modify the full content. Lists are grouped into sections selectable from a dropdown, and any first line that begins with `//` is automatically promoted to the item’s title. Fast, real-time search filtering keeps everything easy to find, and familiar shortcuts—`Ctrl+Z` / `Ctrl+Y` for undo / redo and `Ctrl+S` for an instant auto-save (with a brief “✓ Saved!” tooltip)—make editing feel natural. `Tab` and `Shift+Tab` cycle through items for rapid review, making the editor perfect for maintaining well-organized collections of frequently used text snippets, code examples, or prompt templates that need quick access and continual refinement.

![alt text](https://github.com/TrueCrimeAudit/DarkMode/raw/main/screenshot1.png)

### Also, I made this with this repo! Find out more on my DarkMode project repo.

![alt text](https://github.com/TrueCrimeAudit/DarkMode/raw/main/screenshot2.png)

## 🤝 Contributing

Contributions are not only welcome but I beg for help with [ahk-server](https://github.com/TrueCrimeAudit/ahk-mcp) lol. Pls help.

## AutoHotkey

[Learn more about the amazing world of AHK v2](https://www.autohotkey.com/docs/v2/)

Big thanks to [g.ahk](https://github.com/G33kDude), [Descolada](https://github.com/Descolada), [Panaku](https://github.com/The-CoDingman), [0w0Demonic](https://www.github.com/0w0Demonic/AquaHotkey.git) for the help and example scripts.