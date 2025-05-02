# CodePatch Style

### Edit 1: [brief change description]

```diff
[3 lines pre-context]
- [removed code]
+ [added code]
[3 lines post-context]
```

### Edit 2: [brief change description]

```diff
[diff block]
```

## RULES
1. Each change needs an "Edit X:" label as plain text (not inside any code block)
2. Use ```diff language specifier for all code blocks
3. Include exactly 3 lines context before/after (unless impossible)
4. Start diff blocks with recognizable declarations when possible
5. Keep one blank line between edit label and diff block
6. Put two extra lines after the code block
7. Use h3 header for the code block labels
8. Don't use comments as the first line of the diff block