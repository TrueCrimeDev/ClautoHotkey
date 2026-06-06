---
name: ahk-modernize
description: >
  Modernize outdated AHK v2 patterns in a script. Finds and upgrades old syntax like
  new ClassName(), ComObjCreate(), missing #Requires, and bare = assignments.
  TRIGGER when: user says "modernize", "upgrade patterns", "update old syntax", "clean up v2 code",
  "fix old patterns", "convert to modern v2".
---

# AHK v2 Modernizer

Scan an AHK v2 script and upgrade outdated patterns to current best practices.

## Pattern Replacements

Apply these transformations in order:

### 1. Missing `#Requires`
```diff
+ #Requires AutoHotkey v2.0
  #SingleInstance Force
```
Add as first line if missing.

### 2. `new ClassName()` → `ClassName()`
```diff
- obj := new MyClass()
+ obj := MyClass()
```

### 3. `ComObjCreate()` → `ComObject()`
```diff
- xl := ComObjCreate("Excel.Application")
+ xl := ComObject("Excel.Application")
```

### 4. `Loop, Parse` → `Loop Parse`
```diff
- Loop, Parse, text, ","
+ Loop Parse, text, ","
```

### 5. Object literals for data → `Map()`
```diff
- config := {theme: "dark", fontSize: 14}
+ config := Map("theme", "dark", "fontSize", 14)
```
Only when used as key-value storage, NOT for passing options to functions.

### 6. Missing `.Bind(this)` on event handlers
```diff
- btn.OnEvent("Click", this.OnClick)
+ btn.OnEvent("Click", this.OnClick.Bind(this))
```

### 7. Multi-line fat arrow functions
```diff
- handler := (ctrl, *) => {
-     this.DoSomething()
-     this.DoMore()
- }
+ handler(ctrl, *) {
+     this.DoSomething()
+     this.DoMore()
+ }
```

### 8. Bare `=` assignment (rare in v2 but happens)
```diff
- x = value
+ x := "value"
```

## Workflow

1. **Read** the target file
2. **Scan** for each pattern above
3. **Report** findings with line numbers
4. **Show** before/after diff for each change
5. **Apply** changes after user confirmation
6. **Validate** with `check /Diag=json`

## Rules

- Never modify files without showing the diff first
- Validate after every batch of changes
- Skip patterns inside comments and strings
- Be conservative with object literal → Map conversion (only for data storage)
- Report total changes: "Modernized 8 patterns across 15 lines"
