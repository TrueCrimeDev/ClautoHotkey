#!/bin/bash
# Lean session primer for AHK v2 work.
# Fired on SessionStart (startup, resume, compact).
# Rules in the plugin's `rules/` are path-scoped references the model reads when editing matching files.
# Debugger docs load on demand via /ahk-fix or /ahk-debug-dashboard skills.

source "$(dirname "${BASH_SOURCE[0]}")/_harness-env.sh"

# Problems that leave hooks doing nothing are stated here, at the start, where both
# the user (stderr) and the model (stdout context) see them.
problems=()
if [[ -z "${HARNESS_JQ:-}" ]]; then
    problems+=("ClautoHotkey hooks inactive: install jq or Python 3. Until then edits are not validated, rules are not injected and the interpreter guard is off.")
fi
if [[ -z "${AHK_BIN_WIN:-}" ]]; then
    problems+=("No AutoHotkey v2 interpreter configured or found: set AHK_BIN_WIN in harness.env (or harness.local.env). .ahk edits are not validated until then.")
elif [[ "${AHK_BIN_MISSING:-0}" == 1 ]]; then
    problems+=("Configured AutoHotkey binary not found: $AHK_BIN_WIN. Fix AHK_BIN_WIN in harness.env or harness.local.env; .ahk edits are not validated until then.")
fi

echo -e "\x1b[1;92m┌─ HOOK ▸ ahk-session-primer ─────────────────────────────\x1b[0m" >&2
echo -e "\x1b[1;92m│\x1b[0m AHK v2 session context loaded" >&2
for p in "${problems[@]}"; do
    echo -e "\x1b[1;92m│\x1b[0m \x1b[1;91m${p}\x1b[0m" >&2
done
echo -e "\x1b[1;92m└─────────────────────────────────────────────────────────\x1b[0m" >&2

if [[ ${#problems[@]} -gt 0 ]]; then
    echo "## ClautoHotkey harness status"
    echo
    for p in "${problems[@]}"; do
        echo "- $p"
    done
    echo "Tell the user about this before relying on automatic validation."
    echo
fi

# Where the reference rules live, as this shell spells it, and where demos go.
rules_dir="$_HARNESS_INSTALL_ROOT/rules"

cat <<'CONTEXT'
## AHK v2 Session Context

### Rules that load themselves
Path-scoped notes; `inject-rules.sh` adds each one to the first edit that matches it,
once per session.
- `ahk-v2-syntax` — core syntax rules (any `.ahk` file)
- `ahk-target` — keeps generated code on the build the user has (any `.ahk` file)
- `ahk-fork-features` — +Console fork features (any `.ahk` file, fork builds only)
- `gui-work` — positioning, OnSize, dark mode (GUI files: by name, or because they call `Gui(`)
- `lib-development` — side-effect-free constraints (`Lib/` files)
- `main-script` — entry-point restart rules (`main.ahk`)
- `test-scripts` — standalone conventions (test files)
- `harness-surface` — editing the harness itself

### Rules to read when the situation comes up
No edit loads these. Each has one line here and the full text at the path given.
CONTEXT
cat <<CONTEXT
- \`ahk-interpreter\` — run AutoHotkey only through the configured interpreter (\`"\$AHK_BIN_WSL"\`, set by \`source "$_HARNESS_HOOKS/_harness-env.sh"\`); switches, exit codes and fork notes: \`$rules_dir/ahk-interpreter.md\`
- \`demo-location\` — a script written as a demo or feature showcase is saved under \`${DEMO_DIR:-Demo}\`, not beside the main script: \`$rules_dir/demo-location.md\`
- \`no-banner-comments\` — no banner comment dividers (\`; ====\`, \`; ----\`) in any language: \`$rules_dir/no-banner-comments.md\`
CONTEXT
cat <<'CONTEXT'

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
| COM automation (Excel, WMI, events) | `/ahk-com` skill |
| DllCall, Buffer, Struct, callbacks | `/ahk-dllcall` skill |
| Window messages, subclassing, DWM, WinRT | `/ahk-winapi` skill |
| Version and portability questions | `/ahk-versions` skill |
| Timers, debounce, non-blocking work, closures | `/ahk-async` skill |
| Hotkeys, hotstrings, Send, window and control automation | `/ahk-input` skill |
| Pixels, ImageSearch, monitors, DPI, screen capture | `/ahk-screen` skill |
| Files, clipboard, Run, registry, tray, elevation | `/ahk-system` skill |
| HTTP requests and downloads | `/ahk-net` skill |
| Review a script / defensive validation | `/ahk-review` skill |
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
| Track project state and object lifetimes | `ahk-context` agent |
| Generate tests | `ahk-test-generator` agent |
| Map dependencies | `ahk-dependency-graph` agent |
| Introspect a COM object | `ahk-com-explorer` agent |
| Profile performance | `ahk-profiler` agent |
| UIA automation | `ahk-uia-explorer` agent |
| Multi-script management | `ahk-orchestrator-v2` agent |
| Enforce an overlap-free GUI layout | `layout` agent |
CONTEXT
