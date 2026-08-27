# System Prompts

Per-LLM system/context prompts for AHK v2 work. Paste one into the model you're using
(Claude, ChatGPT, Gemini, etc.) and load `Modules/` into that model's project knowledge.

## Structure: one core, thin wrappers

All the AHK v2 rules — interpreter/fork notes, the required header, coding standards,
the `Map()` vs `{}` policy, alpha.30 syntax, the module map, templates, and the diagnostic
checklist — live in a single source of truth:

- **`_Core.md`** — the shared AHK v2 instruction core. **Edit AHK rules here.**

Each `Context_*.md` is a **thin wrapper**: it sets the model's persona and reasoning
style, then defers to `_Core.md`. A syntax or rule change is a one-line edit in the core,
not a hunt across every prompt.

| Wrapper | Voice / use |
|---------|-------------|
| `Context_Claude.md` | Default Claude: validator stance + strict method-call/`__Call` linting |
| `Context_Claude_Instructions.md` | Concise, checklist-driven, code-first Claude variant |
| `Context_Claude_COT.md` | Explicit chain-of-thought pass |
| `Context_Claude_MCP.md` | MCP-assisted reasoning (MCP optional, never required) |
| `Context_ChatGPT.md` | Step-by-step reasoning + task routing |
| `Context_Gemini.md` | Natural-language → AHK conversion |
| `Context_Deepseek.md` | Analysis stance + confidence/complexity ratings |
| `Context_Quasar.md` | Architect/mentor persona |
| `Context_Short.md` | Minimal wrapper |

Topic references (not per-LLM prompts), kept as-is:

- `AHKv2_Class_Instantiation.md` — how class instantiation works in v2 (no `new`).
- `AHKv2_Testing_Instructions.md` — how to run/test scripts via the configured interpreter.

`_archive/` holds files that are not per-LLM AHK prompts (a prompt-editing how-to and two
generic prompt-engineering tools), parked out of the way.

## Editing rules

- AHK rule, header, template, or module-map change → edit **`_Core.md`** only.
- New model or a different reasoning style → add a thin wrapper that defers to the core.
- Don't copy rules into a wrapper; that recreates the drift this structure removes.
