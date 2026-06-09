---
name: ahk-text
description: >
  Load AHK v2 text processing, string operations, regex, and escape knowledge.
  Use when working with strings, regex, escaping, concatenation, or text manipulation.
  TRIGGER when: user mentions string, regex, escape, backtick, quote, concatenation, RegExMatch,
  RegExReplace, StrReplace, SubStr, InStr, StrLen, StrLower, StrUpper, Format, pattern, match,
  replace, split, join, text, parse, CSV, TSV, newline.
  Examples: "regex to match emails", "escape quotes in string", "split text by newline", "string concatenation"
---

# AHK v2 Text Processing Skill

When this skill is invoked, load the following module files:

1. **Read** `Modules/Module_TextProcessing.md` — String operations, concatenation, text manipulation
2. **Read** `Modules/Module_Escapes.md` — Escape sequences, quote handling, special characters
3. **Read** `Modules/Supplemental/Module_Regex.md` — PCRE regex patterns for AHK v2
4. **Read** `Modules/Supplemental/Module_Strings.md` — String method reference

## Critical Text Rules (Always Apply)

```
ESCAPES:          Backtick ` — NEVER backslash \ for escapes
NEWLINE:          `n (backtick-n) — NOT \n
TAB:              `t (backtick-t) — NOT \t
QUOTE IN STRING:  "He said ""hello""" — double the quote inside
CONCATENATION:    result := "hello " . "world" — dot operator with spaces
APPEND:           result .= "more text" — dot-equals for append
REGEX ENGINE:     PCRE (Perl Compatible Regular Expressions)
REGEX MATCH:      RegExMatch(haystack, pattern, &match) — & for output var
REGEX REPLACE:    result := RegExReplace(haystack, pattern, replacement)
SPLIT:            arr := StrSplit(text, delimiter)
JOIN:             result := arr.Join(delimiter) — requires #Include <Array>
FORMAT:           result := Format("{1} is {2}", var1, var2) — 1-based placeholders
MULTILINE:        Use continuation sections with ( and )
```

## Common Pitfalls

```
WRONG                                RIGHT
─────────────────────────────────────────────────
"line1\nline2"                       "line1`nline2"
str += "text"                        str .= "text"
RegExMatch(str, pat, match)          RegExMatch(str, pat, &match)
'string' (single quotes)            "string" (double quotes — single quotes are literals in v2)
```

## Continuation Sections (Multiline Strings)

```autohotkey
text := "
(
    Line one
    Line two
    Line three
)"
```

Options: `Join`, `LTrim`, `RTrim`, `Comments` can be specified after `(`.
