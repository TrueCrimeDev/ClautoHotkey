# Using Cline (Claude) for AutoHotkey v2 Development

This guide provides best practices for using Cline to generate high-quality AutoHotkey v2 code. Follow these recommendations to get the most effective results and avoid common issues.

## Effective Prompting Strategies

### 1. Be Specific About AHK v2

Always explicitly mention AutoHotkey v2 in your prompts. This helps ensure you receive modern v2 syntax rather than v1 code.

**Good Example:**
```
Create an AutoHotkey v2 script that shows a tooltip when pressing Ctrl+Shift+T
```

**Better Example:**
```
Create an AutoHotkey v2 script (using pure v2 syntax, not v1) that shows a tooltip when pressing Ctrl+Shift+T. Use OOP patterns with proper class initialization.
```

### 2. Ask for OOP Approaches

When appropriate, specifically request object-oriented programming patterns to get modern, maintainable code.

**Example:**
```
Write an AutoHotkey v2 script that implements a simple note-taking application using OOP principles with proper class structures and Map() for data storage.
```

### 3. Request Specific Error Handling

Specify how you want error handling implemented to ensure robust code.

**Example:**
```
Write an AutoHotkey v2 function that reads a JSON file with proper error handling using try/catch and descriptive error messages stored in a Map.
```

## Common Troubleshooting Requests

When Cline generates code that needs improvement, use targeted requests like these:

1. **Fix object literal usage:**
   ```
   The code uses object literals for data storage. Please rewrite using Map() instead of object literals as per AHK v2 best practices.
   ```

2. **Fix event binding:**
   ```
   The event handlers in this code aren't properly bound to 'this'. Please modify to use proper .Bind(this) pattern for all event handlers.
   ```

3. **Fix arrow function misuse:**
   ```
   The code uses arrow functions for complex multi-line operations. Please rewrite using traditional function syntax for any functions that require multiple lines or curly braces.
   ```

4. **Correct class initialization:**
   ```
   The code is missing proper class initialization. Please add MyClass() at the top of the script before the class definition.
   ```

## Example Prompt Templates

### Basic GUI Application

```
Create an AutoHotkey v2 script with the following specifications:

1. Create a GUI-based application with a proper class structure
2. The GUI should have:
   - A text input field
   - A dropdown with the options ["Option 1", "Option 2", "Option 3"]
   - Submit and Cancel buttons
3. When submitting, display the selected data in a MsgBox
4. Use proper event binding with .Bind(this)
5. Store any configuration in a static Map
6. Implement proper error handling
7. Ensure no object literals are used for data storage
```

### Hotkey System

```
Create an AutoHotkey v2 script that implements a hotkey management system with these requirements:

1. Use proper OOP structure with class initialization
2. Allow registering multiple hotkeys with different callbacks
3. Store hotkey configurations in Maps, not object literals
4. Include methods to enable/disable specific hotkeys
5. Implement proper error handling with descriptive messages
6. Add a tooltip feedback system when hotkeys are triggered
```

### File Operations

```
Write an AutoHotkey v2 utility class that:

1. Handles common file operations (read, write, append, copy)
2. Uses proper error handling with try/catch blocks
3. Stores error messages in a static Map
4. Uses proper parameter validation
5. Avoids using object literals for data storage
6. Follows all AHK v2 best practices
```

## Common Claude Mistakes to Verify

After receiving code from Claude, quickly check for these common issues:

1. **Object literals for data storage** - These should be replaced with Map()
2. **Missing class initialization** - Should have MyClass() at the top
3. **Missing .Bind(this) in event handlers** - All event callbacks should preserve context
4. **Complicated arrow functions** - Arrow syntax should only be used for simple one-liners
5. **v1-style command syntax** - All functions should use parentheses (e.g., MsgBox("text"))
6. **Backslash string escaping** - Should use backtick instead (e.g., `"text`")
7. **C-style comments** - Should use semicolons, not double forward slashes

## Sample Review Request

If you receive code with issues, try a prompt like this:

```
This code has some AHK v2 issues that need fixing:

1. Review and fix any object literals to use Map() instead
2. Ensure all event handlers use proper .Bind(this) syntax
3. Check that class initialization is correct (MyClass() at the top)
4. Verify that arrow functions are only used for simple one-line operations
5. Make sure error handling follows best practices
```

## Debugging Help Request

```
My AutoHotkey v2 script is giving the error "[error message]". Can you help me troubleshoot this issue? Here's my code:

[paste your code here]

Please identify the issue and suggest a fix following AHK v2 best practices.
```

## Advanced Techniques

### Ask for Alternative Implementations

```
Can you show me three different ways to implement this feature in AutoHotkey v2, explaining the pros and cons of each approach?
```

### Request for Code Analysis

```
Please analyze this AutoHotkey v2 code and suggest improvements for performance, readability, and adherence to best practices:

[paste your code here]
```

### Request for Educational Explanations

```
Create an AutoHotkey v2 script that demonstrates [feature], and explain the key concepts and techniques used in detailed comments.
```

## Conclusion

Using these techniques will help you get the most out of Cline for AutoHotkey v2 development. Remember to be specific, request modern practices, and explicitly ask for fixes when needed. For reference, see `../docs/AHKv2_Rules.md` for a comprehensive guide to AutoHotkey v2 best practices.
