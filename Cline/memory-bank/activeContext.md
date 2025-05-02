# Active Context: AutoHotkey v2 OOP Framework

## Current Work Focus
- Finalizing the data structure standardization module focused on Map() implementation
- Developing comprehensive error handling patterns based on AHK v2's try/catch system
- Creating robust GUI class templates with proper event binding
- Documenting string manipulation and escape sequence handling techniques
- **Implementing a theme management system with dark mode support for all GUI elements**

## Recent Changes
- Implemented strict validation against object literal usage for data storage
- Added class initialization patterns that enforce proper instantiation without "new" keyword
- Enhanced method binding documentation to require .Bind(this) for all event callbacks
- Consolidated string handling techniques into a reusable module
- Created standardized error handling patterns for common scenarios
- **Started development of ThemeManager class for handling dark/light mode transitions**

## Next Steps
1. Complete the documentation on fat arrow (=>) function usage limitations
2. Develop additional GUI pattern examples for complex interfaces
3. Create validation tools for detecting common AHK v2 syntax errors
4. Implement standardized patterns for file operations with proper error handling
5. Add comprehensive examples demonstrating Map vs. object literal usage
6. **Complete dark mode implementation for all standard controls**
7. **Develop system for detecting OS theme changes and automatically adapting**
8. **Create theme switching animation system for smooth transitions**

## Active Decisions and Considerations
- **Fat Arrow Functions**: Limiting fat arrow (=>) syntax to single-line expressions only
- **Method Binding**: Requiring explicit .Bind(this) for all event handlers to maintain proper context
- **Error Handling**: Implementing structured error recovery patterns with try/catch/finally
- **Map vs Object Literals**: Strictly enforcing Map() usage for all key-value data structures
- **GUI Event Model**: Standardizing on OnEvent pattern rather than legacy g-label approach
- **Theme Implementation**: Deciding between control-by-control styling vs. Windows DWM API approach
- **Color Management**: Creating a standardized color palette system for consistent theming

## Important Patterns and Preferences
- Class instantiation at the top of scripts: `ClassName()`
- Explicit variable declarations in all scopes
- Map() for data storage: `config := Map("key", "value")`
- Proper error handling with class-based error types
- Method binding with .Bind(this) for callbacks
- Fat arrow functions limited to simple expressions
- Proper GUI control storage in Map structures
- **Theme-aware control creation pattern: `AddThemeableControl()`**
- **Theme switching via centralized ThemeManager**

## Learnings and Project Insights
- Many developers struggle with the transition from v1's procedural approach to v2's OOP model
- The object literal syntax is particularly problematic for AHK v2 developers
- Method binding context issues are a common source of bugs
- Proper error handling significantly improves application robustness
- Standardized patterns reduce development time and improve maintainability
- **Dark mode implementation in AHK requires a mix of native Windows API calls and custom styling**
- **Theme consistency across different control types requires careful color management**