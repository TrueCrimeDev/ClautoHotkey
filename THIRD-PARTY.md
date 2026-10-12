# Third-Party Notices

ClautoHotkey itself is MIT (see `LICENSE`). It bundles and documents work by others,
listed here with attribution. Each remains under its own author's terms — check upstream
before redistributing.

## Bundled in `Lib/`

| File | Author / Upstream | Notes |
|---|---|---|
| `cJSON.ahk` | G33kDude, with contributions from the AHK community | JSON parse/serialize |
| `XHotstring.ahk` | Descolada | Hotstring engine |
| `DarkListView.ahk` | derived from community dark-mode ListView work | |
| `tree-sitter-ahk.dll` | compiled from the tree-sitter AHK grammar (tree-sitter is MIT) | Binary artifact; rebuild from source if you need to audit it |
| `_Dark.ahk`, `DarkModeModular_Alpha.ahk`, `TreeSitter.ahk`, `Lint.ahk`, `CodeIntel.ahk` | this project | MIT with the rest of the repo |

## Documented, not bundled

These modules are reference material for libraries you install separately. The module
describes the library; it does not ship it.

| Module | Library | Author |
|---|---|---|
| `Modules/Supplemental/Module_UIA.md` | UIA-v2 | Descolada |
| `Modules/Supplemental/Module_Tooltip.md` | TooltipEx | nperovic |
| `Modules/Supplemental/Module_TapHold.md` | TapHoldManager | evilC |
| `Modules/Supplemental/Module_JSDOC.md` | JSDoc dialect + LSP hover behaviour | Nich-Cebolla (dialect), thqby (ahk2-lsp) |

## Adapted from other repositories

These modules were adapted from <https://github.com/hsinming/AutoHotkey-V2-vibe-coding-tools>
(author hsinming). That repository carries no license file, so its text was not copied as-is: each
module was rewritten, corrected against the +Console fork and checked with the real parser. Each file
ends with an attribution comment. The upstream repository is itself derived from earlier ClautoHotkey
modules; only its additional modules are listed.

| Module | Notes |
|---|---|
| `Modules/Module_AsyncAndTimers.md`, `Module_Functions.md` | timer lifecycle, scope and closures |
| `Modules/Module_Validation.md`, `Module_CodeReview.md` | guard clauses; review method |
| `Modules/Module_DllCallMemory.md` | struct layout and handle ownership (partly merged into `Module_DllCall.md`, `Module_WinAPI.md`) |
| `Modules/Module_System.md`, `Module_ScriptEnvironment.md` | OS integration and script shell (partly merged into `Module_COM.md`) |
| `Modules/Module_FileSystem.md`, `Module_NetworkAndHTTP.md` | files and HTTP |
| `Modules/Module_InputAndHotkeys.md`, `Module_WindowAndControl.md`, `Module_GraphicsAndScreen.md` | input, windows, screen |

## Interpreter

The `+Console` fork referenced throughout `Module_Versions.md` and the `ahk-interpreter`
rule lives at <https://github.com/TrueCrimeDev/AutoHotkey>, a fork of AutoHotkey by
Lexikos. AutoHotkey is GPL-2.0. The fork is a separate program — this repo neither
bundles nor links it, only calls whichever interpreter you configure.

## Reporting

If your work is listed incorrectly, or you want attribution changed or content removed,
open an issue at <https://github.com/TrueCrimeDev/ClautoHotkey/issues>.
