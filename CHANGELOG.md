# Changelog

All notable changes to the ClautoHotkey project will be documented in this file.

## [Unreleased]

### Added
- **Twelve knowledge modules and six skills** adapted from
  hsinming/AutoHotkey-V2-vibe-coding-tools (attribution in `THIRD-PARTY.md`):
  async and timers, functions, validation, code review, DllCall memory, system,
  script environment, file system, network and HTTP, input and hotkeys, windows and
  controls, graphics and screen. New skills `/ahk-async`, `/ahk-input`, `/ahk-screen`,
  `/ahk-system`, `/ahk-net`, `/ahk-review`; `Module_COM`, `Module_DllCall` and
  `Module_WinAPI` gained sections from the same pass. Plugin version 1.4.0.
- **OpenCode install** (`opencode/`): `install.sh` writes one `plugin` entry into
  `opencode.json` (global, or `--project DIR` with an `AGENTS.md` and `harness.env`)
  and copies the skills where OpenCode's skill tool reads them. The plugin,
  `clautohotkey.ts`, is loaded from the clone: it registers the agents, every
  skill and command as a `/<name>` command, puts the session primer in the
  system prompt, and bridges the existing hook scripts (post-edit validation
  appended to the tool result, path-scoped rules, interpreter and git-identity
  guards, v1-syntax detection, auto-reload, error log). `selftest.mjs` drives
  the hooks under Node without a model. OpenCode 1.x API, tested on 1.1.25.
- **npm package** `opencode-clautohotkey`: the same plugin installable with
  `"plugin": ["opencode-clautohotkey"]` and no clone; `npx opencode-clautohotkey
  skills` copies the skills for OpenCode's skill tool. Root `package.json` whitelists
  what ships (813 kB packed). Plugin version 1.3.0.
- **Lesson library** (`lessons/`, `Tools/lessons.py`): what recorded mistakes
  taught about the harness, one entry per lesson with cue, lesson, evidence and
  confidence; an entry missing any of them is refused. `propose` turns the error
  log into candidate rows that no lesson covers yet. Seeded with six entries
  from the 2026 log.
- **Harness lint** (`Tools/lint_harness.py`, also run by `verify.sh`): validates
  the tree the way a proposal would be validated before it runs: skill and agent
  wiring, hook scripts that exist, rule paths, references to missing files,
  lesson fields, the counts the docs quote, and the always-on budget.
- `rules/harness-surface.md`: loads when the harness itself is edited; states the
  cost order for new instruction (hook, script, skill, agent, then always-on
  text) and the lint that must pass.
- `Tools/harness/ADAPT.md`: the propose, probe, compose loop over the runway
  benchmark, after Google Research's Harness² (design only, see THIRD-PARTY.md).
- `/ahk-mistakes` now ends in a reflection: one row per edit with a verdict, then
  at most one lesson, written through `lessons.py add`.
- `rules/ahk-v2-syntax.md`: a fat arrow's expression must yield a value (void
  bodies throw `No value was returned` on the fork); a field cannot share a
  method's name.
- `/ahk-fix` opens by collecting the facts: the verbatim error, repro steps in
  the user's words, the build, and whether the log or a lesson already names
  the cause.
- `ahk-post-edit.sh`: a module that another script includes is probed through
  that script (`runtime(via app.ahk)`) instead of on its own, where every
  sibling class read as a never-assigned variable; a file deleted before the
  hook ran is ignored; the fallback launch passes `/force` (`#SingleInstance
  Off`) like the shim launch; log records carry the session id. Three smoke
  cases cover the new paths.

- `Tools/tests/hooks_smoke.sh` now covers every hook that answers the model or
  writes a log (rule injection on LF and CRLF rule files, the error logger, the
  v1 detector, the compaction restore, the debug-MCP hints, the session log, bare
  interpreter names), and `Tools/tests/reload_logic.sh` runs the reload's
  PowerShell against recorded processes on any platform.
- Rule frontmatter: `contains:` (strings looked for in the `.ahk` file being
  edited, on disk or in the text the edit writes) and `build: fork` (keep the rule
  off stock AutoHotkey). `gui-work` uses the first, `ahk-fork-features` the second.
- `CheckResults.py --expect-tiers` and `--expect-count`: a script that passed
  every tier it reached but stops short of the last requested one, or that never
  got a row, is reported and makes the exit code 1. `harness-grade.js` passes both
  and lists the gaps under "skipped", so a script dropped between tiers no longer
  vanishes from the denominator.
- `lessons.py where`, and a per-machine lesson folder: run from outside the
  harness checkout, `add` writes to `$CLAUDE_PLUGIN_DATA/lessons` or the project's
  `.claude/lessons` instead of the install folder an update replaces. `propose`
  reports how many of a lesson's rows are dated after the lesson was recorded.
- Selftest canaries for the names-first and statement spellings of an import
  from AHK, a `#Module` section, an import one `#Include` away, and Gui geometry.
  `hooks_smoke.sh` asks the interpreter whether it parses each spelling: a
  parsed file must skip the probe, a rejected one must be blocked as a syntax
  error (alpha.38 accepts only `#Import AHK ...`).

### Changed
- **Scripts that use the module system are refused by tiers 2 and 3, not run.**
  The preflight used to match only `#Import AHK ...`. It now matches `#Import` in
  any spelling, the `Import` statement and `#Module`: the shim's shadows are
  declarations in the main module, so code in any other module calls the real
  built-ins. Such a script comes back `error` with a `shim-bypass` finding; a unit
  test that needs modules runs with `GatePure.ahk --no-shim`. The post-edit probe
  applies the same test, and follows `#Include` as the gate does.
- `hooks/hooks.json`: the error logger is wired to `PostToolUseFailure`, the
  compaction restore to `SessionStart` (matcher `compact`), and the reload is no
  longer a hook of its own on Write|Edit: `ahk-post-edit.sh` calls it once the edit
  has passed. A clone install picks the new wiring up by re-running `./setup.sh`,
  which renders `.claude/settings.json` from that file.
- `ahk-auto-reload.sh` on Bash: a script is restarted only when the command
  modified it and the file is newer than the process running it. Naming a script
  (`cat`, `git diff`, a gate run) no longer bounces a copy the user has running.
- `check-ahk-binary.sh` also blocks a bare `AutoHotkey*.exe` in command position
  when PATH resolves it to something other than the configured binary.
- `gui-work` matches GUI files by generic name globs and by content instead of
  one project's folder names; path globs ignore case.
- The session primer lists every self-loading rule, carries a line and a path for
  the three reference rules, and routes all 25 skills and 9 agents;
  `lint_harness.py` now requires both.
- `_harness-env.sh` exports `AHK_EXE` and defines `harness_log_file`; `/ahk-run`,
  `/ahk-eval` and `/ahk-fix` open with the two setup lines their snippets need.

### Fixed
- `DryRunShim.ahk`: a candidate's `DllCall(..., "Void")` no longer fails the
  dry-run tier with `No value was returned`; the wrapper forwards a void call
  without returning it.
- `DryRunShim.ahk`: the Gui stand-in answers `GetPos` and `GetClientPos` through
  their ByRef parameters (from the x/y/w/h the script passed to `Show`, `Add` and
  `Move`) instead of leaving them unset, which failed layout code inside the stub.
- Hooks that did nothing under Claude Code, which starts the hooks matched to one
  event together, sends a tool's result as `tool_response`, reports failed calls
  through `PostToolUseFailure`, and reads context only from `hookSpecificOutput`
  or, for prompt and session-start hooks, plain stdout:
  - `ahk-auto-reload.sh` read the validator's verdict before there was one, so a
    broken edit could be reloaded and the fix after it skipped;
  - `error-logger.sh` waited on `PostToolUse` for an exit code and an error field
    that event never carries;
  - `detect-v1-syntax.sh` warned on stderr with exit 0, where nobody reads it;
  - `post-compact-state.sh` was wired to `PreCompact`, which cannot add context;
  - `check-ahk-connection.sh` and `post-capture-guidance.sh` answered with a
    top-level `additionalContext`, and the latter read `tool_output`;
  - `session-event-logger.sh` read `subagent_type` and `notification`.
- `inject-rules.sh`: rule files with CRLF endings (a `core.autocrlf=true`
  checkout) matched nothing; frontmatter is now read with the carriage return
  stripped and `.gitattributes` pins `rules/*.md` to LF. The marker that stops a
  rule loading twice is cleared after compaction, when the rule text is gone.
- `ahk-auto-reload.sh`: the restarted script's path is quoted by hand, so a
  script under a folder with a space in its name comes back instead of being
  stopped and lost; the running script is matched by full path, not by a name
  fragment.
- Error and session logs are written when the project has no `.claude/` folder
  yet (it is created), as in any project a plugin install first touches.
- `package.json`: the `files` list ends in negated patterns. npm 9 and later
  ignore the root `.npmignore` when `files` is present, so `__pycache__`, logs,
  `settings.ini` and `harness.env` inside the listed folders would have shipped.
- Removed `Lib/ClipboardHistory`, a submodule entry with no `.gitmodules`, which
  made `git submodule status` and recursive clones fail.
- `opencode/install.sh`: a commented `opencode.jsonc` holding a URL (the usual
  `$schema` line) no longer aborts the install; `opencode/selftest.mjs` no longer
  dies with EPIPE when a hook exits without reading its input.
- `ahk-post-edit.sh`: a main-script failure on stock AutoHotkey is parsed like any
  other, and a file name with regex characters still finds its includer.
- Docs: the rule count and hook table in the README, the `AHK_DIAG_JSON` default
  and fork-reference path in the interpreter rule, the orchestrator agent's entry
  points (one project's scripts, now `MAIN_SCRIPT`), and two files the notices
  listed that are not in the repo.

## [1.2.0] - 2026-10-01

### Added
- **All four grading tiers.** `GatePure.ahk` (tier 2) runs a script's unit tests
  under the shim with the new `TestKit.ahk` assertion library (`Assert.ahk`
  alias, compatible with the fork's `qa/Assert.ahk` names); `GateLive.ahk`
  (tier 4) is an adapter over [ahkh](https://github.com/owhs/AHKTestHarness)'s
  hidden desktop, pinned to the gate's own interpreter and serialised by a
  session lock.
- **Containment for every child process** (`Harness.Launch`): suspended start,
  kill-on-close job object, memory cap, UI limits (no system-parameter,
  display, desktop or log-off changes), file-backed stdio, a sliced deadline
  with a per-tick watcher.
- **Window watch:** dialogs and windows that get past the shim are classified
  by structure (AutoHotkey's error dialog by its fixed button ids), recorded,
  and dismissed; an error dialog ends the run instead of passing as idle.
- **Clipboard guard:** snapshots the user's clipboard, attributes writes by
  owner process, restores after the candidate exits, and serialises clipboard
  users across agents.
- `Report.py`: SARIF 2.1.0, JUnit XML, GitHub annotations and Markdown, with
  baselines whose fingerprints survive line shifts.
- `Reduce.ahk`: delta-debugging to the smallest script that still fails the
  same way.
- `SelfTest.ahk --run` and `selftest/`: canaries with known verdicts for every
  tier, checks that their side effects never landed, and a 90+ case Python
  suite for the checker and reporter.
- `HarnessJson.Parse`, so the harness no longer needs the fork's native `JSON`
  class (absent from some alpha.30 builds).
- `.claude/workflows/harness-grade.js`: resolves the interpreter, tools,
  scratch dir and a working Python at run time instead of hard-coding them,
  and covers the pure and live tiers.

### Changed
- Result contract `ahk-harness/result@2`: `pure` rows carry `tests` and
  `assertions`, `dryrun` rows carry `guard`, `live` rows carry `drift` and
  `backend`; the checker enforces them and reports uncovered scripts.
- The dry run injects the shim with `/include` and runs the candidate **in
  place** with `/force` — no wrapper file written next to the candidate, real
  line numbers, and a candidate's `#SingleInstance Force` can no longer replace
  a copy the user has running.
- The shim now covers `Shutdown`, `FileOpen` writes (redirected to a sink),
  `DllCall` and `ComObject` deny-lists, `PostMessage`/`SendMessage`,
  `KeyWait`/`InputHook`, the `WinSet*`/`Control*` families, `Menu.Show`, sound,
  volume and drive control, and the `Edit`/`List*` windows; label hotkeys are
  suspended; `FileAppend` and `Print` reach stdout; structured `OnError`
  records give exact error lines. Shadows a candidate defines itself are
  dropped per run instead of failing the load; candidates that `#Import AHK`
  are refused.
- Relative script paths resolve against the caller's directory (AutoHotkey
  starts scripts in `A_ScriptDir`, so gates used to look in their own folder).

### Fixed
- Hooks no longer depend on WSL and `jq`: they run under Git Bash, WSL or
  Cygwin, fall back to a bundled jq subset (`hooks/_jqlite.py`) when jq is
  missing, and say so instead of exiting 0 having done nothing.
- `harness.env` paths are machine-independent (`${WIN_HOME}`), with
  `harness.local.env` for per-machine overrides.
- `check-ahk-binary` matches paths case-insensitively and literally (a
  `Program Files (x86)` path no longer breaks its regex).
- A `harness.env` saved with Windows line endings gave every value a trailing
  carriage return, so `AHK_DIAG_JSON=1` never equalled `1` and the git
  identity guard was silently off; the loader strips the CRs.
- The post-edit runtime probe runs the edited script under the dry-run shim, so
  saving a script that deletes files or writes the registry no longer does it.
- Every gate and tool declares `#SingleInstance Off`: the interpreter's default
  (Prompt) put a "replace the running instance?" dialog in front of parallel
  agents running the same gate.
- `Tools/verify.sh` no longer trusts the Microsoft Store `python3` stub, and its
  "Hooks are live" section proves the validator blocks a broken edit.
- The test generator targets TestKit; the Yunit it referenced was never shipped.

## [1.1.0] - 2025-08-12

### Added
- Migrated to modern Cursor Project Rules under `.cursor/rules/*.mdc` with modular, scoped rules
- Always-on linter rule leveraging `@Linter Errors`: `.cursor/rules/00-always-linter.mdc`
- Task playbooks: `.cursor/rules/playbook-gui.mdc`, `.cursor/rules/playbook-text.mdc`
- `default.mdc` index router and `docs/best-practices-*.mdc` guides
- `.cursorignore` to trim noisy context

### Changed
- Moved runtime/config files to `Lib/` and updated references:
  - `settings.ini` → `Lib/settings.ini`
  - `system.log` → `Lib/system.log`
  - `test_log.json` → `Lib/test_log.json`
  - `__Lists.json` → `Lib/__Lists.json`
- `common_prompts.json` moved to `Lib/common_prompts.json`; references updated in `_UltiLog.ahk`, `Other/_Dark2.ahk`, and `index.md`
- Replaced legacy `.cursorrules` approach with Project Rules and updated internal doc links to `.cursor/rules/`

### Removed
- Legacy `.cursorrules.md` aggregator (superseded by `.cursor/rules/*.mdc`)

### Notes
- README unchanged per request.

## [1.0.0] - 2025-03-29

### Added
- Initial release with comprehensive Cline rules system
- `.clinerules` - JSON rules file for AHK v2 syntax validation and guidance
- `.clinerules.md` - Documentation for the rules system
- Comprehensive example scripts demonstrating proper AHK v2 patterns:
  - `AHKv2_Example.ahk` - Complete application example with GUI and proper OOP structure
  - `AHKv2_Code_Examples.ahk` - Additional pattern examples 
  - `Simple_AHKv2_Examples.ahk` - Beginner-friendly examples
- Documentation files:
  - `docs/AHKv2_Rules.md` - Detailed coding standards documentation
  - `docs/AHKv2_Rules_README.md` - Guide to the rules system
  - `Using_Cline_for_AHKv2.md` - Guide for effective prompting
- Updated project structure with clear organization
- Improved README with detailed setup and usage instructions
- Added comprehensive `.gitignore` file for AutoHotkey projects

### Changed
- Entirely restructured from previous prompts system to use `.clinerules` file format
- Optimized examples to demonstrate current AHK v2 best practices
- Reorganized documentation for better clarity and usability

### Fixed
- Corrected syntax examples to properly follow AHK v2 standards
- Consolidated conflicting guidance from earlier versions
- Improved Class initialization examples to match current recommended patterns
- Fixed Map/Object usage examples to prevent common errors
