# Changelog

All notable changes to the ClautoHotkey project will be documented in this file.

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
