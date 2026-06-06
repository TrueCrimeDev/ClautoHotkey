---
name: ahk-debug-dashboard
description: >
  Show a compact debug state dashboard during an active debugging session.
  Queries MCP resources for connection status, breakpoints, variables, and call stack.
  TRIGGER when: user says "debug dashboard", "show debug state", "debug status",
  "what's the debugger showing", "debug overview".
---

# AHK v2 Debug Dashboard

Display a compact overview of the current debugging session state.

## Usage

`/ahk-debug-dashboard` — queries all debug state and displays a dashboard.

## Data Sources

Query these MCP tools in sequence:

1. `debug_status` — connection state and current position
2. `breakpoint_list` — all active breakpoints
3. `variables_get(context: 0)` — local scope variables
4. `variables_get(context: 1)` — global scope variables
5. `stack_trace` — current call stack
6. `watch_list` — active watch expressions

## Dashboard Template

```
─ DEBUG DASHBOARD ────────────────────────────────────────

**Status:** running | break | stopped
**Position:** script.ahk:42 — `MyClass.DoWork()`

─ CALL STACK ─────────────────────────────────────────────

  0: MyClass.DoWork()        script.ahk:42
  1: MyClass.__New()         script.ahk:15
  2: {main}                  script.ahk:98

─ BREAKPOINTS ────────────────────────────────────────────

  #1: script.ahk:42          (active)
  #2: script.ahk:67          (active, condition: x > 5)

─ LOCAL VARIABLES ────────────────────────────────────────

  this      = MyClass{gui, data}
  x         = 42
  name      = "hello"

─ WATCHES ────────────────────────────────────────────────

  this.data.Count  = 3       (changed: was 2)
  x                = 42      (unchanged)

─ GLOBAL VARIABLES ───────────────────────────────────────

  A_ScriptDir  = "<project directory>"
  A_TickCount  = 1234567
```

## Error States

- **No connection**: "Debugger not connected. Start AHK with `/Debug` flag."
- **Session ended**: "Debug session ended. Re-run script with `/Debug` to restart."
- **MCP unavailable**: "autohotkey-debug MCP server not running."

## Workflow

1. Check `debug_status` first — if not connected, show connection instructions
2. If connected and at a breakpoint, query all other tools
3. If running (not at break), show status only — variables/stack not available
4. Format into compact dashboard
5. Highlight any watched variables that changed since last step

## Rules

- Always check connection status before querying other tools
- Show locals before globals (locals are more relevant during debugging)
- Truncate long variable values to 80 characters
- For object/array variables, show type and count instead of full contents
- Use `(changed)` marker on watches that differ from previous value
