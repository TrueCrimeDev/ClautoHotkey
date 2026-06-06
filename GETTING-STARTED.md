# Getting Started

Zero-to-coding with the ClautoHotkey system: a console-enabled AHK v2 engine, a
Claude Code harness that validates your edits, and the knowledge modules that
teach the AI correct AHK v2.

## 1. Get the engine

Best experience: the **+Console fork** — real stdout, `Print`, `Eval`, and JSON
diagnostics. Build it from source:

```bash
git clone -b alpha https://github.com/TrueCrimeDev/AutoHotkey.git
# build per that repo's instructions -> AutoHotkey64.exe
```

> Stock AutoHotkey v2 also works (the harness falls back to `/validate`), but you
> lose `Print`/`Eval` and JSON diagnostics.

## 2. Clone this repo

```bash
git clone https://github.com/TrueCrimeDev/ClautoHotkey.git
cd ClautoHotkey
```

## 3. Turn on the harness

```bash
cp harness.env.example harness.env
```

Edit `harness.env`:

- `AHK_BIN_WIN` — Windows path to your `AutoHotkey64.exe`.
- `AHK_DIAG_JSON=1` if you built the +Console fork (else `0`).

Then run:

```bash
./setup.sh
```

Expected: `rendered .claude/settings.json` and `setup complete.` (re-run after any
`harness.env` change). Requires WSL or Git Bash and `jq`.

## 4. Open it in Claude Code

Open this folder as the project. The harness activates on session start: every
`.ahk` edit is syntax-validated, the matching rule auto-loads, and AHK skills
(`/ahk-gui`, `/ahk-fix`, `/ahk-oop`, …) and investigation agents are available.

## 5. Point the AI at the knowledge modules

Tell your assistant to start with `Modules/Module_Instructions.md`, then pull
keyword-triggered modules (`Module_GUI.md`, `Module_Classes.md`, …) as needed.

## 6. Optional — wire the MCP docs server

Install [ahk-mcp](https://github.com/TrueCrimeDev/ahk-mcp) for live docs, code
completion, and diagnostics inside your AI client.

---

You now have: a validated edit loop, auto-loaded rules, AHK-specific skills, and a
knowledge base the AI reads — the full system. See the [README](README.md) for the
component overview.
