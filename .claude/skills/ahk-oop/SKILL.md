---
name: ahk-oop
description: >
  Load AHK v2 OOP knowledge for class design, objects, arrays, and dynamic properties.
  Use when working with classes, inheritance, objects, arrays, Map, prototypes, or property descriptors.
  TRIGGER when: user mentions class, object, inheritance, extends, super, property, DefineProp, Array, Map, prototype,
  __New, __Delete, static, nested class, factory, collection, filter, reduce, sort, bind, callback, descriptor.
  Examples: "create a class", "add inheritance", "use Map for storage", "filter an array", "define a property getter"
---

# AHK v2 OOP Knowledge Skill

When this skill is invoked, load the following module files for comprehensive OOP reference:

1. **Read** `Modules/Module_Classes.md` — Class design, inheritance, constructors, destructors, static members
2. **Read** `Modules/Module_Objects.md` — Object hierarchy, property descriptors, method binding
3. **Read** `Modules/Module_Arrays.md` — 1-based indexing, Array.ahk library (Join/Filter/Map/Reduce/Sort)
4. **Read** `Modules/Module_DynamicProperties.md` — Dynamic properties via __Get/__Set, closures, computed properties
5. **Read** `Modules/Module_ClassPrototyping.md` — Prototyping workflows, runtime class creation

## Critical OOP Rules (Always Apply)

These rules are non-negotiable for ALL AHK v2 OOP code:

```
INSTANTIATION:    MyClass() — NEVER use "new MyClass()"
DATA STORAGE:     Map() for key-value data — NEVER object literals {key: value} for storage
EVENT BINDING:    .Bind(this) for ALL event handlers and callbacks
ARRAYS:           1-based indexing — arr[1] is the first element, NOT arr[0]
FAT ARROW:        => for SINGLE-LINE expressions ONLY — never multi-line blocks
ASSIGNMENT:       := always — NEVER bare = for assignment
CLEANUP:          __Delete() for destructor/cleanup logic
INHERITANCE:      super.method() to call parent — super.__New() in constructors
SCOPE:            Explicit variable declarations — use local/global as needed
MAP ITERATION:    for key, value in myMap — NOT for each
ARRAY ITERATION:  for index, value in myArray — or for , value in myArray (throwaway key)
```

## Module Routing

After reading the modules, apply knowledge based on the specific task:
- **Class hierarchy design** → Module_Classes (primary)
- **Property descriptors / DefineProp** → Module_DynamicProperties
- **Array operations / functional patterns** → Module_Arrays
- **Object inspection / HasProp / HasMethod** → Module_Objects
- **Runtime class generation** → Module_ClassPrototyping
