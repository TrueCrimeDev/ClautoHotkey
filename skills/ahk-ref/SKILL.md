---
name: ahk-ref
description: >
  Load comprehensive AHK v2 reference covering all domains — OOP, GUI, text, errors, data structures.
  Use as a general-purpose fallback when no specific domain skill applies, or when the task spans multiple areas.
  TRIGGER when: user mentions #Include, library, import, reference, comprehensive, overview, data structures,
  Map, key-value, dictionary, storage, settings, configuration, how does AHK, general AHK question,
  jsdoc, document, annotate, add docs, docstring, comment style, api docs.
  Examples: "how do #Includes work", "AHK v2 overview", "data structure for settings", "general reference",
  "add JSDoc", "document this class", "annotate the API"
---

# AHK v2 Comprehensive Reference Skill

When this skill is invoked, load the following module files:

1. **Read** `${CLAUDE_PLUGIN_ROOT}/Modules/Module_Instructions.md` — the baseline: engineering standards, syntax
   rules, the keyword and directive reference, and the diagnostic checklist
2. **Read** `${CLAUDE_PLUGIN_ROOT}/Modules/Module_DataStructures.md` — Map usage, nested containers, structured data
3. **Read** `${CLAUDE_PLUGIN_ROOT}/Modules/Supplemental/Module_Formatting.md` — the house formatting standard
4. **Read** `${CLAUDE_PLUGIN_ROOT}/Modules/Supplemental/Module_FatArrows.md` — fat-arrow limits, callbacks, `.Bind()`
5. **Read** `${CLAUDE_PLUGIN_ROOT}/Modules/Supplemental/Module_JSDOC.md` — JSDoc conventions (load when documenting code)
6. **Read** `${CLAUDE_PLUGIN_ROOT}/Modules/Supplemental/Module_MiniExamples.md` — a corpus of official-documentation
   examples; grep it for a known-good use of a specific built-in rather than reading it whole

## Module Routing Table

When the user's request matches specific keywords, also invoke the domain-specific skill:

```
class, object, inheritance, extends    → /ahk-oop
gui, window, dialog, layout, control   → /ahk-gui
error, crash, debug, fix, broken       → /ahk-fix
string, regex, escape, text, parse     → /ahk-text
jsdoc, document, annotate, api docs    → load Module_JSDOC.md
```

## Core AHK v2 Syntax Quick Reference

```
ASSIGNMENT:       x := value
COMPARISON:       if (x = value) or if (x == value) (case-sensitive)
CONCATENATION:    str := "a" . "b"
TERNARY:          result := condition ? trueVal : falseVal
OBJECT CREATE:    obj := MyClass()
MAP CREATE:       m := Map(), m["key"] := "value"   (never constructor pairs)
ARRAY CREATE:     arr := ["a", "b", "c"]
FUNCTION DEF:     MyFunc(param1, param2?) { }
FAT ARROW:        prop => this.value (SINGLE LINE ONLY)
FOR LOOP:         for key, value in collection
INCLUDE:          #Include "path/file.ahk" or #Include <LibName>
REQUIRES:         #Requires AutoHotkey v2.1-alpha.30
HOTKEY:           ^s:: { ... } (Ctrl+S)
HOTSTRING:        ::btw::by the way
```

## File Organization Pattern

```
#Requires AutoHotkey v2.1-alpha.30
#SingleInstance Force
#Include <Array>        ; Lib folder includes

class MyApp {
    __New() { ... }
    __Delete() { ... }
}

MyApp()  ; Instantiate at top level
```

## Data Storage Patterns

```autohotkey
; Settings/config — use Map
settings := Map(
    "theme", "dark",
    "fontSize", 14,
    "autoSave", true
)

; Ordered collection — use Array
items := ["first", "second", "third"]

; NEVER use object literals for data storage
; WRONG: config := {theme: "dark"}
; RIGHT: config := Map(), config["theme"] := "dark"
```
