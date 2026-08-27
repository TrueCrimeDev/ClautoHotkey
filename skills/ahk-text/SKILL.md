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

1. **Read** `${CLAUDE_PLUGIN_ROOT}/Modules/Module_TextProcessing.md` — string operations, `Format()`, and the whole
   regex domain: quote-in-pattern escaping, backslash levels, `~=`, global-match iteration, the anchored-
   validator trap, and a pre-escaped PCRE pattern table. (Absorbed the former `Module_Regex.md` on 2026-08-26.)
2. **Read** `${CLAUDE_PLUGIN_ROOT}/Modules/Module_Escapes.md` — escape sequences, quote handling, special characters

## Critical Text Rules (Always Apply)

```
ESCAPES:          Backtick ` — NEVER backslash \ for escapes
NEWLINE:          `n (backtick-n) — NOT \n
TAB:              `t (backtick-t) — NOT \t
QUOTE IN STRING:  "He said `"hello`"" — backtick-escape the quote
ALT DELIMITER:    'He said "hello"' — single quotes are full string delimiters in v2
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
"He said ""hi"""  (v1 doubled "")    "He said `"hi`"" — or 'He said "hi"'
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
