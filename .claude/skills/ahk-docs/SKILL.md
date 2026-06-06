---
name: ahk-docs
description: >
  Search AHK v2 documentation for a function, method, directive, or concept.
  Returns relevant documentation excerpts with syntax and examples.
  TRIGGER when: user says "docs for", "how does X work in AHK", "AHK docs",
  "look up", "what is the syntax for", "documentation".
---

# AHK v2 Documentation Search

Search the AutoHotkey v2 documentation and return relevant information.

## Usage

`/ahk-docs <search_term>` — searches for the term in AHK v2 docs.

## Search Strategy

1. **Check local modules first** — search `ClautoHotkey/Modules/` for the term
2. **Search online docs** — fetch from `https://www.autohotkey.com/docs/v2/`
3. **Return** the most relevant excerpt with syntax and examples

## Local Module Search Order

Search these files in `ClautoHotkey/Modules/` for the term:

| Term Category | Module File |
|--------------|-------------|
| Class, object, prototype | `Module_Classes.md`, `Module_Objects.md` |
| Array, Map, loop | `Module_Arrays.md`, `Module_Objects.md` |
| GUI, control, window | `Module_GUI.md`, `Supplemental/Module_GUI_Layout.md` |
| Error, try, catch | `Module_Errors.md`, `Supplemental/Module_ErrorHandling.md` |
| String, regex, text | `Module_TextProcessing.md`, `Module_Escapes.md` |
| Property, getter, setter | `Module_DynamicProperties.md` |
| #Include, #Requires | `Module_Instructions.md` |
| Data structure, Stack, Queue | `Module_DataStructures.md` |

## Online Documentation URLs

Build URLs from the search term:

- Functions: `https://www.autohotkey.com/docs/v2/lib/<FunctionName>.htm`
- Directives: `https://www.autohotkey.com/docs/v2/lib/_<DirectiveName>.htm`
- Concepts: `https://www.autohotkey.com/docs/v2/Concepts.htm`
- Objects: `https://www.autohotkey.com/docs/v2/ObjList.htm`

## Output Format

```
─ AHK v2 DOCS ───────────────────────────────────────────

**<FunctionName>**

Syntax: `FunctionName(param1, param2, options?)`

Description from docs...

**Example:**

```autohotkey
; usage example from docs
```

Source: <URL or module file>
```

## Rules

- Prefer local module content over online docs when available
- Always include at least one code example
- Note any v1→v2 syntax differences if relevant
- If the term is ambiguous, list all matching entries
