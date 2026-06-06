#!/bin/bash
# Lean session primer for AHK v2 work.
# Fired on SessionStart (startup, resume, compact).
# Rules in .claude/rules/ are path-scoped references the model reads when editing matching files.
# Debugger docs load on demand via /ahk-fix or /ahk-debug-dashboard skills.

echo -e "\x1b[1;92m┌─ HOOK ▸ ahk-session-primer ─────────────────────────────\x1b[0m" >&2
echo -e "\x1b[1;92m│\x1b[0m AHK v2 session context loaded" >&2
echo -e "\x1b[1;92m└─────────────────────────────────────────────────────────\x1b[0m" >&2

cat <<'CONTEXT'
## AHK v2 Session Context

### Rules (.claude/rules/)
Path-scoped notes that auto-load when you edit a matching file (the
`inject-rules.sh` PreToolUse hook injects each matching rule once per session).
- `ahk-v2-syntax.md` — core syntax rules (any `.ahk` file)
- `gui-work.md` — positioning, OnSize, dark mode (GUI files)
- `lib-development.md` — side-effect-free constraints (`Lib/` files)
- `main-script.md` — entry-point restart rules (your `MAIN_SCRIPT`)
- `test-scripts.md` — standalone conventions (test files)

### Skill & Agent Routing

Skills are the default entry point for routine work. Reach for an agent only when the task benefits from a fresh context window.

| Task | Use |
|---|---|
| Build/fix GUI | `/ahk-gui` skill |
| Generate GUI from description | `/ahk-gui-gen` skill |
| Fix errors / debug script | `/ahk-fix` skill |
| Debug dashboard | `/ahk-debug-dashboard` skill |
| OOP / classes / objects | `/ahk-oop` skill |
| Text / regex / strings | `/ahk-text` skill |
| Run a script headlessly | `/ahk-run` skill |
| Evaluate an expression | `/ahk-eval` skill |
| Convert v1 to v2 | `/ahk-convert` skill |
| Modernize old v2 patterns | `/ahk-modernize` skill |
| Scaffold a new class | `/ahk-new-class` skill |
| Look up AHK docs | `/ahk-docs` skill |
| General AHK reference | `/ahk-ref` skill |
| Recurring mistakes from error log | `/ahk-mistakes` skill |
| Audit error handling / silent failures | `/ahk-audit-errors` skill |
| Analyze code quality | `ahk-analysis` agent |
| Generate tests | `ahk-test-generator` agent |
| Map dependencies | `ahk-dependency-graph` agent |
| COM/WinAPI exploration | `ahk-com-explorer` agent |
| Profile performance | `ahk-profiler` agent |
| UIA automation | `ahk-uia-explorer` agent |
| Multi-script management | `ahk-orchestrator-v2` agent |
CONTEXT
