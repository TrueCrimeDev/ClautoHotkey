# legacy/

Artifacts from before ClautoHotkey became a Claude Code harness, kept for reference.
**None of these are used by the harness** (the rules / skills / agents in `.claude/` and
the knowledge in `Modules/`). The project is now the harness, not a collection of prompts
and scripts to paste into LLMs.

- **System_Prompts/** — per-LLM system prompts (a shared `_Core.md` + thin per-model
  wrappers) for pasting AHK v2 knowledge into other models (ChatGPT, Gemini, Claude
  Projects). Superseded by the harness skills + `Modules/`, which the agent loads and
  routes natively.

  On 2026-08-26 eight prompt-era files that were still sitting in `Modules/Supplemental/`
  moved here: `Module_All.md`, `Module_Basics.md`, `Module_CustomGPT.md`,
  `Module_CustomGPT_Beta.md`, `Module_CustomGPT_Concise.md`, `Module_InstructionStyles.md`,
  `Module_Thinking.md`, `Module_GUI_Layout.md`. They are personas, cognitive-tier
  scaffolding and XML agent-steering templates rather than knowledge — and several taught
  rules this project forbids (`Module_Basics.md` banned `throw` and banned arrow functions
  outright; two mandated `#Requires AutoHotkey v2.0` and ```` ```cpp ```` fences). They are
  kept for reference only. **Do not load them as modules.**
- **Context_Claude.md** — a standalone Claude per-LLM prompt (duplicate of the
  System_Prompts one).
- **_UltiLog.ahk** — AI-interaction logger with a grading system.
- **_Lists.ahk / _Lists.json** — dark-themed JSON list editor.
- **Scripts/Clip_SearchCode.ahk** — apply LLM code changes to VS Code.
- **Scripts/ClipboardHistoryCombiner.ahk** — batch clipboard errors for debugging.

They still run, but they predate the harness and the skill-native module routing.
