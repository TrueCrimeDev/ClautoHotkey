# ClautoHotkey in OpenCode

The same harness, driven by [OpenCode](https://opencode.ai) instead of Claude Code.

## From npm (no clone)

Add the package to `opencode.json` (global `~/.config/opencode/opencode.json`, or a
project's `.opencode/opencode.json`). OpenCode installs it on the next start:

```json
{ "plugin": ["opencode-clautohotkey"] }
```

That registers the agents and the `/ahk-*` commands and turns on the hooks. OpenCode
does not look inside `node_modules` for skills, so one more line gives the model its
own skill picks too:

```bash
npx opencode-clautohotkey skills            # copies them to ~/.config/opencode/skill
npx opencode-clautohotkey skills --project ~/MyScripts
```

OpenCode 1.x keeps the version it first installed; to upgrade, pin a version
(`"opencode-clautohotkey@1.4.0"`) or delete it from `~/.config/opencode/node_modules`.

## From a clone

Everything is read from the clone, so `git pull` is the whole upgrade.

```bash
./opencode/install.sh                        # every project: ~/.config/opencode
./opencode/install.sh --project ~/MyScripts  # one project: MyScripts/.opencode
./opencode/install.sh --uninstall            # either, add --project DIR for a project
```

Both routes need OpenCode **1.x** (tested on 1.1.25), bash (Git Bash on Windows, or
WSL), AutoHotkey v2, and, for the clone installer, `jq` or Python 3 to edit
`opencode.json`. The installer refuses OpenCode 2.x, whose plugin API and config keys
are different.

## What the installer writes

| Where | What |
| --- | --- |
| `opencode.json` | one `plugin` entry: `file:///…/ClautoHotkey/opencode/clautohotkey.ts` |
| `skill/<name>/` | a copy of each `skills/<name>/`, with `${CLAUDE_PLUGIN_ROOT}` replaced by the clone path and a `.clautohotkey` marker so a re-run or uninstall touches only these |
| `AGENTS.md`, `harness.env` | `--project` only, and only if absent: the project guidance (from `CLAUDE.md.template`) and the interpreter config (from `harness.env.example`) |

Nothing else is copied. Agents, commands, rules, hook scripts and modules are read from
the clone each time OpenCode starts.

## What the plugin does

`clautohotkey.ts` is a 1.x plugin. Its hooks map onto the Claude Code wiring in
`hooks/hooks.json`:

| OpenCode hook | Does | Claude Code equivalent |
| --- | --- | --- |
| `config` | `agents/*.md` → `agent.<name>` (subagents; a `tools:` list becomes an allow list). `commands/*.md` and `skills/*/SKILL.md` → `command.<name>`, so `/ahk-fix …` works as in Claude Code | agents, commands, skills |
| `experimental.chat.system.transform` | appends `hooks/ahk-session-primer.sh` output (routing table, harness status) and where the clone lives | `SessionStart` |
| `chat.message` | `hooks/detect-v1-syntax.sh`; a hit becomes a one-time note in the next system prompt | `UserPromptSubmit` |
| `tool.execute.before` on `bash` | `hooks/check-ahk-binary.sh`, `hooks/check-git-account.sh`; exit 2 throws, which blocks the command | `PreToolUse Bash` |
| `tool.execute.before` on `edit`/`write` | `hooks/inject-rules.sh`; matching rules are held and appended to that edit's result | `PreToolUse Write\|Edit` |
| `tool.execute.after` on `edit`/`write` | `hooks/ahk-post-edit.sh`; a failure is appended as `[ClautoHotkey] VALIDATION FAILED …` so the model fixes it next, a pass as one line; then `hooks/ahk-auto-reload.sh` | `PostToolUse Write\|Edit` |
| `tool.execute.after` on `bash` | `skills/ahk-mistakes/hooks/error-logger.sh`, `hooks/ahk-auto-reload.sh` | `PostToolUse Bash` |

The scripts are unchanged: the plugin builds the Claude Code hook payload they expect
(`tool_name`, `tool_input.file_path`, `session_id`, …) and runs them with bash, with
`CLAUDE_PROJECT_DIR` set to the OpenCode project and `CLAUDE_PLUGIN_ROOT` to the clone.
OpenCode cannot veto an edit after it lands, so where Claude Code blocks, OpenCode gets
the failure text in the tool result instead; the file is still fixed on the next turn.

Bash is found at `CLAUTOHOTKEY_BASH`, then Git for Windows (`Program Files\Git`), then
`bash.exe` on PATH outside `System32` (that one is the WSL launcher). Without bash the
agents and commands still register; the hooks report themselves inactive in the primer.

## Checking it

```bash
opencode debug config | grep -c '"ahk-'   # agents + commands the plugin registered (27)
opencode debug skill  | grep -c '"ahk-'   # skill copies (19)
node opencode/selftest.mjs               # runs the hooks against a scratch project, no model
```

`selftest.mjs` needs Node 22.6+ (it imports the `.ts` directly). It checks the config
hook, the primer, v1 detection, the interpreter guard, a broken edit (expects
`VALIDATION FAILED`), a good edit, rule injection once per session, and that non-`.ahk`
edits are untouched.

## Differences from the Claude Code plugin

- Skills are commands (`/ahk-gui`) and, through the skill copies, also model-pickable
  via OpenCode's skill tool. There is no `@skill` syntax in 1.x.
- Rules are not pre-loaded before an edit; they arrive with the result of the first edit
  that matches them, once per session.
- The git-identity guard, the interpreter guard and the runtime probe follow the same
  `harness.env` keys as before; a project `harness.env` wins over the clone's.
- OpenCode 2.x: not supported by this plugin. Its config uses plural keys
  (`plugins`, `agents`, `commands`) and a `Plugin.define` API; the skill copies would
  still be found at `.claude/skills`-style paths.
