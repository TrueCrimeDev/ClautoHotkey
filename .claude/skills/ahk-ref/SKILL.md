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

1. **Read** `ClautoHotkey/Modules/Supplemental/Module_All.md` — Unified reference covering ALL AHK v2 domains
2. **Read** `ClautoHotkey/Modules/Module_Instructions.md` — Core instruction framework, cognitive tiers, module routing
3. **Read** `ClautoHotkey/Modules/Module_DataStructures.md` — Map usage, structured data, code organization
4. **Read** `ClautoHotkey/Modules/Supplemental/Module_Keywords.md` — Keyword reference and language constructs
5. **Read** `ClautoHotkey/Modules/Supplemental/Module_JSDOC.md` — JSDoc documentation conventions for AHK v2 (load when documenting code)

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
MAP CREATE:       m := Map("key", "value")
ARRAY CREATE:     arr := ["a", "b", "c"]
FUNCTION DEF:     MyFunc(param1, param2?) { }
FAT ARROW:        prop => this.value (SINGLE LINE ONLY)
FOR LOOP:         for key, value in collection
INCLUDE:          #Include "path/file.ahk" or #Include <LibName>
REQUIRES:         #Requires AutoHotkey v2.0
HOTKEY:           ^s:: { ... } (Ctrl+S)
HOTSTRING:        ::btw::by the way
```

## File Organization Pattern

```
#Requires AutoHotkey v2.0
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
; RIGHT: config := Map("theme", "dark")
```
