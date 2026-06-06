# No Banner Comments

**NEVER** write banner-style comment dividers in code. Forbidden in any language and any file.

## Forbidden patterns

```text
; ================================================================
; ----------------------------------------------------------------
; ****************************************************************
; ################################################################
// ================================================================
# ================================================================
/* ============================================================== */
```

Any line whose payload is a long run of repeated `=`, `-`, `*`, `#`, or `_` is a banner. Don't write them. This applies to AHK, Python, JS, TS, Bash, Markdown code blocks — every language.

## What to do instead

Use a single-line section comment with prose only:

```ahk
; 1. Untyped slot accepts any type
```

```python
# Coerce numeric strings; reject non-numeric.
```

If a function or block needs a header, name the function or block clearly. The structure should be obvious from indentation, function boundaries, and identifiers — not from typographic noise.

## Why

- Banner dividers add zero information beyond what a plain `; section name` line already conveys.
- They bloat the file, blow up diffs, and force horizontal scanning.
- They are a tell of AI-generated or over-decorated code; the user dislikes them strongly.

## Exceptions

- None. If you think a section needs more visual weight, you're wrong — rename or restructure instead.
- Box-drawing in *output strings* (e.g. ASCII art a script prints to a console) is fine. The rule is about source-code dividers, not runtime output.
