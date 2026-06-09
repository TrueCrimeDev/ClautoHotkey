# AHKv2 Testing Instructions

These instructions define how to handle AutoHotkey v2 code generation, file management, and execution.

## File Location Rules

1. **All AutoHotkey v2 code files should be saved exclusively in the ClautoHotkey folder.**
   - Base path: the cloned `ClautoHotkey/` repo root (wherever you cloned it).
   - Any new AHK v2 scripts should be created in this folder or appropriate subfolders
   - Never create AHK v2 files outside this directory structure
   
2. **Organizing files within ClautoHotkey:**
   - Main scripts should be in the root of ClautoHotkey
   - Supporting modules in the Modules/ subfolder
   - Test scripts in the Tests/ subfolder
   - Output files in the Output/ subfolder

## Execution Command

When executing AutoHotkey v2 scripts for testing, resolve the interpreter from
`harness.env` (`AHK_BIN_WIN` → `AHK_BIN_WSL`) — never hardcode a path:

```bash
source .claude/hooks/_harness-env.sh
"$AHK_BIN_WSL" /ErrorStdOut=utf-8 "<script_path>"
```

Key features of this command:
1. Uses the repo's configured AHK v2 interpreter (the +Console fork by default)
2. Redirects error output to standard output with UTF-8 encoding
3. Stays consistent with the harness hooks, which resolve the same binary

## Testing Workflow

1. Create the AHK v2 script in the ClautoHotkey folder
2. Execute it using the command above
3. Verify the output and behavior
4. Make any necessary adjustments based on results

This ensures consistency with the VS Code development environment which uses the same execution method.
