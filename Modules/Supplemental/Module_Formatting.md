---
name: Module_Formatting
description: >
  The house formatting standard for AHK v2 source in this project - indentation, spacing, brace placement,
  line breaks, naming, comment style, and code register. These are mandates, not suggestions. TRIGGER when
  the request involves: formatting, style, indentation, spacing, brace, naming convention, comment style,
  "clean up this code", "format this", "house style", readability, line length, banner comments. Not
  covered: syntax and semantics - see Module_Instructions.md.
---

# AutoHotkey v2 Formatting Standard

House formatting rules for AHK v2 source in this project. These are mandates, not
suggestions — every line is a decision already made, so there is nothing to
"recommend." Scope is layout and punctuation; syntax and semantics live in the
other modules, and code *register* (flat over clever) is summarized at the end.

## Whitespace

- 4 spaces per indent level. Never tabs. Never mixed within a file.
- No trailing whitespace on any line.
- One blank line between methods and between logical blocks. Never two or more in a row.
- CRLF line endings for `.ahk` files (Windows-native target).
- One statement per line. Comma-chained statements (`a := 1, b := 2`) only for tightly
  related initialisation, never to pack unrelated logic onto one line.

## Naming

- PascalCase for classes, methods, and properties.
- camelCase for locals and parameters.
- Pick a descriptive name over a short one; no single-letter names except loop counters.

## Braces and blocks

- OTB: `{` on the header line, never on its own line.
- `}` aligned with the statement that opened the block.
- Continuation keywords share the closing brace's line: `} else {`, `} catch Error as e {`.
- Brace every block body. A bare one-line body is allowed **only** for a standalone
  `if` with no `else`/`else if` following it — an unbraced body before an `else` silently
  swallows the branch.

```ahk
; WRONG — unbraced Loop body eats the else, validates clean, skips the branch
if ready
    Loop 3
        Work()
else
    Idle()

; RIGHT
if ready {
    Loop 3
        Work()
} else {
    Idle()
}
```

## Comments

- One space after `;`. At least one space or tab before an inline `;`.
- No banner dividers — `; ====`, `; ----`, `; ****`, or any run of repeated punctuation.
  A section break is a single `; prose label` line. This is a hard rule, no exceptions.
- `/* */` for multi-line comments; `/** */` JSDoc for public class/method docs.
- Comments say *why*, not *what*. Keep them minimal; delete any that restate the code.

## Expressions and line breaks

- Spaces around `:=` and binary operators; space after commas, none before.
- Do not pad `:=` with alignment spaces — column alignment rots on the next edit.
- Keep lines around 100–120 columns. Wrap rather than scroll.
- Break a long chain, `DllCall`, or `Format` one element per line, leading dot or comma,
  continuation indented one level.

```ahk
result := obj.Where(x => x.Active)
             .Select(x => x.Name)
             .ToArray()
```

## Data construction

- `:=` for assignment. Never bare `=`.
- Empty `Map()` then assign keys individually. Never pass pairs to the constructor.

```ahk
m := Map()
m["host"] := "localhost"
m["port"] := 8080
```

## Code register

Formatting governs how code is punctuated; register governs how it is built. The two
fail in opposite directions, so this section stays short — fuller guidance lives in
`Module_Instructions.md`.

- Prefer the flattest construct that does the job. Clever is not better.
- No gratuitous fluent chains or embedded string DSLs in host-side scripts — flat
  classic callbacks, one function per concern, `if`/`switch` inside.
- Don't reach for a framework or a flagship library to do what a plain function does.
  Reserve the heavy libs for the demos that exist to showcase them.
