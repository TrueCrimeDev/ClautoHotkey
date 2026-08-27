---
name: Module_Escapes
description: 'AHK v2 escape sequences — the backtick escape character and every sequence it introduces (`n `t `r `"
  `'' `; `: `{ `s `b `v `a `f), quote-mark selection, and the fact that backslash escapes (\n) do not exist in
  AHK string literals. TRIGGER when the request involves: escape, backtick,
  literal quote, newline in a string, escaping quotes in a string or regex, hotstring colon escaping,
  key remap braces. Not covered: regex metacharacter escaping and string-building patterns — see Module_TextProcessing.md.'
---

# Module_Escapes

### Escape Sequences
The escape character ` (back-tick or grave accent) is used to indicate that the character immediately following it should be interpreted differently than it normally would. This character is at the upper left corner of most English keyboards.

In AutoHotkey the following escape sequences can be used:

| Sequence | Result |
|----------|--------|
| ``` `` ``` | `` ` `` (literal accent; i.e. two consecutive escape characters result in a single literal character) |
| `` `; `` | `;` (literal semicolon) |
| `` `: `` | `:` (literal colon). This is necessary only in a hotstring's triggering abbreviation. |
| `` `{ `` | `{` (keyboard key). This is only valid, and is required, when remapping a key to `{`. |
| `` `n `` | newline (linefeed/LF) |
| `` `r `` | carriage return (CR) |
| `` `b `` | backspace |
| `` `t `` | tab (the more typical horizontal variety) |
| `` `s `` | space |
| `` `v `` | vertical tab — corresponds to Ascii value 11. It can also be manifest in some applications by typing Ctrl+K. |
| `` `a `` | alert (bell) — corresponds to Ascii value 7. It can also be manifest in some applications by typing Ctrl+G. |
| `` `f `` | formfeed — corresponds to Ascii value 12. It can also be manifest in some applications by typing Ctrl+L. |
| `` `" `` or `` `' `` | Single-quote marks (') and double-quote marks (") function identically, except that a string enclosed in single-quote marks can contain literal double-quote marks and vice versa. Therefore, to include an actual quote mark inside a literal string, escape the quote mark or enclose the string in the opposite type of quote mark. For example: ``Var := "The color `"red`" was found."`` or `Var := 'The color "red" was found.'`. |

Note: It is not necessary to escape a semicolon which has any character other than space or tab to its immediate left, since it would not be interpreted as a comment anyway.

The first two cases below break at LOAD TIME; the third is silent — a backslash is an ordinary character and produces a wrong string with no error at all.
```ahk
#Requires AutoHotkey v2.1-alpha.30

; ✓ Escaped quote inside a same-type quoted string
quoted := "The color `"red`" was found."

; ✗ Unescaped quote ends the string early
; quoted := "The color "red" was found."   ; → load error

; ✓ A semicolon preceded by a space or tab inside a string must be escaped
literalSemicolon := "Command `; parameter"

; ✓ Flush against a non-space character it needs no escape
okSemicolon := "Command; parameter"

; ✗ Whitespace-preceded semicolon is eaten as a comment
; literalSemicolon := "Command ; parameter"   ; → load error: Missing "

; ✓ Backslash is an ordinary literal character in an AHK string — never an escape
literalBackslash := "C:\Users\Public"
notANewline := "line\nline"                  ; 10 literal characters, one line
realNewline := "line`nline"                  ; two lines
```
