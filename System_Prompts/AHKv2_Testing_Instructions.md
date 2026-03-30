# AHKv2 Testing Instructions

These instructions define how to handle AutoHotkey v2 code generation, file management, and execution.

## File Location Rules

1. **All AutoHotkey v2 code files should be saved exclusively in the ClautoHotkey folder.**
   - Base path: `c:/Users/uphol/Documents/Design/Coding/AHK/!Running/ClautoHotkey`
   - Any new AHK v2 scripts should be created in this folder or appropriate subfolders
   - Never create AHK v2 files outside this directory structure
   
2. **Organizing files within ClautoHotkey:**
   - Main scripts should be in the root of ClautoHotkey
   - Supporting modules in the Modules/ subfolder
   - Test scripts in the Tests/ subfolder
   - Output files in the Output/ subfolder

## Execution Command

When executing AutoHotkey v2 scripts for testing, use the following command format:

```powershell
& "c:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 "<script_path>"
```

Example:
```powershell
& "c:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=utf-8 "c:\Users\uphol\Documents\Design\Coding\AHK\!Running\ClautoHotkey\TestScript.ahk"
```

Key features of this command:
1. Uses the official AutoHotkey v2 interpreter
2. Redirects error output to standard output with UTF-8 encoding
3. Matches the command format used by the VS Code AutoHotkey extension

## Testing Workflow

1. Create the AHK v2 script in the ClautoHotkey folder
2. Execute it using the command above
3. Verify the output and behavior
4. Make any necessary adjustments based on results

This ensures consistency with the VS Code development environment which uses the same execution method.
