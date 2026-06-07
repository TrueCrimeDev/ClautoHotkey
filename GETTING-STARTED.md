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

## A worked example

1. With ClautoHotkey open as the project, ask Claude: *"Build a dark-mode settings
   GUI with a few controls."*
2. The `/ahk-gui` knowledge and the `gui-work` rule load automatically; the model
   writes the script.
3. On save, the post-edit hook validates it (`check /Diag=json` on the fork) — a
   syntax slip is caught and reported before you ever run it.
4. Ask to *"run it"* → the `/ahk-run` skill executes it headlessly and reports the
   output / exit code.
5. Hit a runtime error later? `/ahk-fix` loads the debugging knowledge, and
   `/ahk-mistakes` surfaces patterns you repeat.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `setup.sh`: `jq` not found | Install `jq` — the hooks parse JSON with it. |
| Edits aren't being validated | Open **ClautoHotkey itself** as the project (hooks resolve `$CLAUDE_PROJECT_DIR`); editing it from a parent folder uses that folder's config. |
| `WARNING: AHK binary not found` | Fix `AHK_BIN_WIN` in `harness.env`, then re-run `./setup.sh`. |
| A stock-AHK edit blocks oddly | Set `AHK_DIAG_JSON=0` — stock AHK has no `check /Diag=json`. |
| `BLOCKED: Non-canonical AutoHotkey binary` | The guard only allows the binary set in `harness.env`; use that path. |
| `harness.env` changes ignored | Re-run `./setup.sh` (it re-renders `settings.json`). |

## FAQ

**Do I need the +Console fork?** No — stock AutoHotkey v2 works (validation falls
back to `/validate`). The fork adds `Print`, `Eval`, JSON diagnostics, and the
runtime probe. Set `AHK_DIAG_JSON=1` only if you have it.

**Where do my machine-specific paths live?** In `harness.env`, which is gitignored.
Never commit it — commit `harness.env.example` instead.

**Does it need the MCP server?** No — `ahk-mcp` is optional (live docs/diagnostics).

**Can I use the harness in another project?** Yes — it's a standalone template:
[ahk-claude-harness](https://github.com/TrueCrimeDev/ahk-claude-harness).

---

You now have: a validated edit loop, auto-loaded rules, AHK-specific skills, and a
knowledge base the AI reads — the full system. See the [README](README.md) for the
component overview.
