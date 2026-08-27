---
name: Module_TextProcessing
description: 'AHK v2 string manipulation, PCRE regex, escape sequences, and string-building patterns —
  StrReplace/StrSplit/SubStr/InStr/Trim/Format, RegExMatch/RegExReplace with the leading `option)` prefix,
  backtick escapes, array-join and StringBuilder. TRIGGER when the request involves: StrReplace(),
  RegExMatch(), RegExReplace(), InStr(), SubStr(), StrSplit(), Format(), Trim(), `~=`, "string", "text",
  "escape", "backtick", "regex", "pattern", "join array", "replace text", "validate input", "split string",
  "parse text", "special character", "quote in a regex", "escape regex metacharacters", "match literal
  text", "extract all matches", "global match", "replace with a callback", "regex pattern library", "email
  pattern", "URL pattern", "IP address", "ISO date", "CSV field", "quoted text", "file path pattern",
  "HTML tag pattern", "generate AHK source". Not covered: file I/O text encoding, GUI control text content, hotstring
  trigger definitions, and clipboard operations — see Module_GUI.md for control text.'
---

# Module_TextProcessing

## API QUICK-REFERENCE

### String Functions
| Method/Property | Signature | Notes |
|-----------------|-----------|-------|
| `StrLen()` | `StrLen(str)` | Returns character count — the only way; strings have no `.Length` property (`str.Length` throws PropertyError) |
| `StrUpper()` | `StrUpper(str)` | Returns uppercase copy — does not modify the original variable |
| `StrLower()` | `StrLower(str)` | Returns lowercase copy — does not modify the original variable |
| `StrReplace()` | `StrReplace(haystack, needle, replacement?, caseSense?, &count?, limit?)` | Returns modified string; optional `&count` receives the number of replacements made |
| `StrSplit()` | `StrSplit(str, delimiters?, omitChars?, maxParts?)` | Returns an Array of substrings; delimiters may be a string or an Array of strings; `omitChars` lists characters to trim from the ends of each part |
| `InStr()` | `InStr(haystack, needle, caseSense?, startPos?, occurrence?)` | Returns 1-based position of match, or 0 if not found |
| `SubStr()` | `SubStr(str, startPos, length?)` | 1-based; negative `startPos` counts from string end; omit `length` for remainder of string |
| `Format()` | `Format(formatStr, values*)` | `{1}` `{2}` positional placeholders; `{1:.2f}` for numeric formatting; `{1:05d}` for zero-padding. Braces are the placeholder delimiters, so a literal brace needs `{{}` for `{` and `{}}` for `}` — verified on the fork: `Format("{{}x{}}", 1)` returns `{x}`. A backtick cannot escape a brace — brace escaping is Format's own, using `{{}` and `{}}`. Backtick escapes in the literal itself are resolved before Format runs, so `` "a`nb" `` still carries a real newline into the result |
| `Trim()` | `Trim(str, chars?)` | Strips both leading and trailing chars (default: whitespace and null) |
| `LTrim()` | `LTrim(str, chars?)` | Left-trim only |
| `RTrim()` | `RTrim(str, chars?)` | Right-trim only; used in array-join pattern to remove trailing separator |

### Regex Functions
| Method/Property | Signature | Notes |
|-----------------|-----------|-------|
| `RegExMatch()` | `RegExMatch(haystack, needleRegex, &matchObj?, startPos?)` | Returns 1-based match start position or 0; `&matchObj` populated ByRef |
| `RegExReplace()` | `RegExReplace(haystack, needleRegex, replacement?, &count?, limit?, startPos?)` | Returns modified string; `$1`/`$2` or `${name}` for group backreferences in replacement |
| `~=` operator | `haystack ~= needleRegex` | Same PCRE engine as `RegExMatch()`; returns the 1-based match position or 0, but takes no output var — use it when only the yes/no answer is needed |

### RegExMatch Object (matchObj)
| Property | Notes |
|----------|-------|
| `matchObj[0]` | The entire matched string |
| `matchObj[n]` | nth numbered capture group value (1-based) — **throws on alpha.30 if group `n` does not exist in the pattern**, see constraint below |
| `matchObj["name"]` | Named capture group value; group defined as `(?P<n>...)` in pattern |
| `matchObj.Count` | Number of capture groups the pattern defines — the guard for every `matchObj[n]` access |
| `matchObj.Name[n]` | Name of the nth group, or `""` if that group is unnamed |
| `matchObj.Pos[n]` | 1-based position of nth group within the haystack |
| `matchObj.Len[n]` | Character length of nth group |
| `matchObj.Mark` | Name set by the most recent `(*MARK:name)` the match passed, or `""` |

## AHK V2 CONSTRAINTS

- **Backtick (`` ` ``) is AHK v2's only escape character for string content** — never use `\n`, `\t`, or any backslash escape to encode characters in a string; `"hello\n"` is the 7-character literal `hello\n`, not a newline — use `` "`n" `` instead. Inside a *regex pattern* string, backslash sequences such as `\d`, `\s`, `\n` are PCRE escapes interpreted by the regex engine and are correct there — the rule covers string content, not regex pattern syntax.
- **Regex mode flags use the leading `option)` prefix** — `"i)pattern"` for case-insensitive, `"im)pattern"` for combinations; PCRE inline groups like `(?i)` also work. Suffix flags (`"pattern/i"`) are not flags at all — the trailing `/i` becomes two literal pattern characters, and the pattern quietly stops matching what you intended.
- **RegExMatch output var requires `&` ByRef prefix** — `RegExMatch(str, pat, &match)` not `RegExMatch(str, pat, match)`; without `&`, AHK v2 passes the variable by value, the match object is never populated, and any `match[1]` access throws UnsetError.
- **alpha.30: `match[n]` for a subpattern that does not exist THROWS** — `Parameter #1 of RegExMatchInfo.Prototype.__Item.Get is invalid`; v2.0 returned `""`. Guard with `if n <= match.Count`. A group that *exists* but did not participate in the match still returns `""` safely, so the guard is only about group count. Wrap every `(?|...)` alternative in its own capture group so the number always exists.
- **Array objects have no `.Join()` method** — join arrays with a `for` loop using a ternary separator, or append a separator in the loop then `RTrim()` the trailing delimiter; calling `.Join()` throws a MethodError.
- **Single and double quoted strings are identical in behaviour** — both interpret backtick escape sequences in the same way; choose the quote type that minimises escaping: use single quotes when the string contains double quotes, use double quotes when the string contains apostrophes.
- **`StrReplace()` returns the modified string; it does not modify in place** — always capture the return value: `str := StrReplace(str, old, new)`; discarding the return value silently produces no change.
- **Never name a variable or parameter after a built-in you also call** — identifiers shadow built-ins case-insensitively, so `format := ...` or `number := ...` turns the later `Format(...)` / `Number(...)` call into `This value of type "String" has no method named "Call"` at runtime, with no load-time warning. `format`, `number`, `string`, `array`, `map`, `gui`, `menu`, `random`, `type`, `object` and `buffer` are the common traps in text code; `Contains` is a reserved word outright.
- **`InStr()` returns a 1-based position, not a boolean** — return value of `0` means not found; using the result as a boolean works only because `0` is falsy, but an explicit `!= 0` comparison is clearer and avoids confusion between "found at position 1" and "not found".

Safe-access priority order for text processing operations:
  1. Built-in functions (`StrReplace`, `InStr`, `SubStr`, `Trim`) — single-call, no loop, no error path
  2. Ternary separator pattern — array join without a `.Join()` method call, exact separator control
  3. `RTrim()` trailing-separator pattern — simpler loop body, but `RTrim(str, ", ")` strips a CHARACTER SET (every trailing comma and space), not one separator token; use the ternary form whenever an element may end in a separator character
  4. `try/catch` on `RegExMatch`/`RegExReplace` — only when the pattern itself is user-supplied and malformed input must be caught

## TIER 1 — String Building, Concatenation, and Quote Strategy
> METHODS COVERED: RTrim · .= operator · A_Index

String concatenation in AHK v2 uses the `.=` compound operator to incrementally build a string from parts. Array joining has no built-in `.Join()` method — use either a ternary separator inside the loop (exact output) or an append-then-RTrim pattern (simpler loop body). Choose single vs double quotes to minimise escape characters rather than using `\` escapes.
```ahk
; ✓ .= is the correct v2 string-append operator — returns and reassigns in one step
result := ""
result .= "First part"
result .= " and second part"

; ✓ Array assigned to a named variable first — .Length is a property, not a method
myArr := ["apple", "banana", "orange"]
arrayJoining := ""
for item in myArr
    arrayJoining .= item (A_Index < myArr.Length ? ", " : "")

; ✓ RTrim pattern — simpler loop body, trailing separator stripped after the loop
; CAVEAT: RTrim(str, ", ") strips a CHARACTER SET — every trailing comma AND space, not
;   one separator token. "a, b," ends up "a, b". Use the ternary form above whenever an
;   element may itself end in a separator character.
alternativeJoining := ""
for item in myArr
    alternativeJoining .= item ", "
result := RTrim(alternativeJoining, ", ")

; ✓ Single quotes avoid escaping the double quotes inside the string
singleQuotes := 'He said "Hello"'

; ✓ Double quotes avoid escaping the apostrophe inside the string
doubleQuotes := "It's working"

; ✗ Array object has no .Join() method — throws MethodError
; result := myArr.Join(", ")   ; → MethodError: no method named Join
```

## TIER 2 — Escape Sequences: The Backtick System
> METHODS COVERED: (no function calls — escape sequence reference tier)

AHK v2 uses backtick (`` ` ``) as its sole escape character inside string literals. Backslash has no special meaning and produces itself literally. This tier covers the complete escape sequence inventory and context-specific escaping rules for hotstrings, GUI controls, command-line arguments, and INI files.
```ahk
; ✓ Double-backtick produces a single literal backtick character
literalBacktick := "This is a backtick: ``"

; ✓ Backtick-quote escapes a quote character inside same-type quoted string
quotesInString := "He said `"Hello`" to me"

; ✓ `n is the correct AHK v2 newline — not \n
newlineText := "First line`nSecond line"

; ✓ `t is the correct AHK v2 tab character — not \t
tabSeparated := "Name`tAge`tCity"

; ✓ `: belongs to hotstring DEFINITION LINES, not string literals — in a quoted string,
;   "`:" is simply ":". On a real hotstring line, escape a colon in the trigger:
;   ::web`:::website.com   ; trigger "web:" expands to website.com
colonInString := "key:value"   ; a colon in a string literal needs no escape

; ✓ Backtick-semicolon escapes a semicolon that would otherwise begin a comment.
;   Only a semicolon preceded by a space or tab is at risk — see Module_Escapes.md.
literalSemicolon := "Command `; parameter"

; ✓ Flush against a non-space character, a semicolon needs no escape at all
okSemicolon := "Command; parameter"

; ✗ Whitespace-preceded ; inside a string is eaten as a comment — LOAD ERROR, not a
;   silently truncated string: ==> Missing "
; bad := "Command ; parameter"

; ✓ `a produces the bell/alert character (ASCII 7)
alertSound := "Warning`a"

; ✓ `v produces a vertical tab (ASCII 11)
verticalTab := "Column1`vColumn2"

; ✓ Single-quote string avoids escaping the embedded double quotes
simpleDoubleQuotes := 'He said "Hello world"'

; ✓ Double-quote string avoids escaping the embedded apostrophe
simpleSingleQuotes := "It's a beautiful day"

; ✓ Single-quoted outer string wraps the path with embedded double quotes
pathWithSpaces := '"C:\Program Files\My App\program.exe"'

; ✗ Backslash has no special meaning in AHK strings — "\n" is literally backslash-n
; badNewline := "First line\nSecond line"   ; → literal 23-char string, not two lines
```

Essential Escape Sequences:
- ` `` ` → `` ` `` (literal backtick)
- `` `" `` → `"` (literal double quote inside double-quoted string)
- `` `' `` → `'` (literal single quote inside single-quoted string)
- `` `n `` → newline (LF, ASCII 10)
- `` `r `` → carriage return (CR, ASCII 13)
- `` `t `` → tab (ASCII 9)
- `` `s `` → space (ASCII 32)
- `` `b `` → backspace (ASCII 8)
- `` `: `` → `:` (literal colon — required in hotstring definitions)
- `` `; `` → `;` (literal semicolon — prevents comment parse)
- `` `a `` → alert/bell (ASCII 7)
- `` `v `` → vertical tab (ASCII 11)
- `` `f `` → form feed (ASCII 12)

Context-specific rules:
- **Hotstrings**: escape colons with `` `: ``
- **GUI controls**: use `` `n `` for line breaks in multi-line edit controls
- **Command-line arguments**: quote entire arguments containing spaces
- **INI files**: be careful with `=` and `[` in value strings

## TIER 3 — Built-in String Methods
> METHODS COVERED: Trim · StrUpper · StrLower · StrReplace · StrSplit · InStr · SubStr

AHK v2 provides a complete set of built-in string functions that cover nearly all common manipulation tasks. Prefer these over manual character loops — they are implemented in native code, handle Unicode correctly, and express intent more clearly. None of these functions modify the input string in place; all return a new string.
```ahk
; ✓ Trim() removes leading and trailing whitespace in one call
text := "  Hello World  "
cleaned := Trim(text)              ; "Hello World"

; ✓ StrUpper/StrLower return copies — assign back to mutate the variable
upper := StrUpper(text)            ; "  HELLO WORLD  "
lower := StrLower(text)            ; "  hello world  "

; ✓ StrReplace returns the modified string — result must be captured
replaced := StrReplace(text, "World", "Universe")  ; "  Hello Universe  "

; ✓ StrSplit returns an Array — access elements by 1-based index
split := StrSplit(text, " ")
; split[1] = "", split[2] = "", split[3] = "Hello", split[4] = "World", split[5] = "", split[6] = ""

; ✓ InStr returns 1-based position or 0 — explicit != 0 is clearer than bare truthiness
found := InStr(text, "World")      ; 9 (1-based position)
if found != 0
    MsgBox("Found at position " found)

; ✓ SubStr with 1-based index — use negative startPos to count from end
extracted := SubStr(text, 3, 5)   ; "Hello" (start at char 3, take 5 chars)

; ✗ StrReplace result discarded — original variable unchanged
; StrReplace(text, "Hello", "Hi")  ; → silent no-op, text still "  Hello World  "

; ✗ Zero-based index on Array returned by StrSplit
; first := split[0]                ; → IndexError, AHK v2 arrays are 1-based
```

## TIER 4 — Regex Fundamentals: RegExMatch and RegExReplace
> METHODS COVERED: RegExMatch · RegExReplace · ~= operator · StrLen

AHK v2 uses PCRE regex with a unique option syntax: mode flags prefix the pattern as `option)`, e.g., `"i)pattern"`. `RegExMatch()` returns the 1-based match position (0 = no match) and populates a match object via `&matchObj`. `RegExReplace()` returns the modified string and supports `$1`/`$2` or `${name}` backreferences in the replacement.
```ahk
; ✓ i) prefix enables case-insensitive matching — option before the closing paren
email := "USER@DOMAIN.COM"
if RegExMatch(email, "i)^[^@]+@[^@]+\.[^@]+$")
    MsgBox("Valid email (case-insensitive)")

; ✓ m) prefix makes ^ and $ match line boundaries, not just string start/end
multilineText := "Line 1`nLine 2`nLine 3"
if RegExMatch(multilineText, "m)^Line 2$")
    MsgBox("Found Line 2 at start of line")

; ✓ &match ByRef prefix required — without & the match object is never populated
phonePattern := "(\d{3})-(\d{3})-(\d{4})"
if RegExMatch("123-456-7890", phonePattern, &match) {
    ; NOT `number`: a variable named number shadows the built-in Number() function
    ; case-insensitively, and every later Number(...) call throws "no method named Call"
    area := match[1]         ; 123
    exchange := match[2]     ; 456
    subscriber := match[3]   ; 7890
}

; ✓ RegExReplace returns modified string — capture the return value
text := "Hello 123 World 456"
numbers := RegExReplace(text, "\D+", " ")              ; " 123 456"
cleaned := RegExReplace(text, "\d+", "")               ; "Hello  World "
swapped := RegExReplace(text, "(\w+) (\d+)", "$2 $1")  ; "123 Hello 456 World"

; ✓ i) option works the same in RegExReplace
result := RegExReplace("Hello WORLD", "i)hello", "Hi") ; "Hi WORLD"

; ✓ Named capture groups via (?P<n>...) — access by name string key
RegExMatch("Price: $25.99", "\$(?P<dollars>\d+)\.?(?P<cents>\d*)", &match)
dollars := match["dollars"]  ; "25"
cents := match["cents"]      ; "99"

; ✓ alpha.30: guard a numbered group with .Count before indexing it
if RegExMatch("abc", "(a)(z)?", &optional) {
    second := optional.Count >= 2 ? optional[2] : ""   ; "" — group exists, did not match
}

; ✗ alpha.30: indexing a group the pattern never defines THROWS (v2.0 returned "")
; third := optional[3]   ; → Parameter #1 of RegExMatchInfo.Prototype.__Item.Get is invalid

; ✓ Wrap every (?|...) alternative in its own capture group so the number always exists
if RegExMatch("k=v", "(?|(\w+)=(\w+)|(\w+):(\w+))", &kv)
    pair := kv[1] " -> " kv[2]

; ✗ Bare output var without & — match object never populated
; RegExMatch("123-456-7890", phonePattern, match)  ; → match[1] throws UnsetError

; ✗ Suffix flag syntax from Perl/JS — the trailing /i is matched as LITERAL characters
; if RegExMatch(email, "^[^@]+@[^@]+\.[^@]+$/i")   ; → "/i" after $ can never match; pattern always fails

; ✓ PCRE inline option groups work — (?i) is a valid alternative to the i) prefix
; if RegExMatch(email, "(?i)^[^@]+@[^@]+\.[^@]+$")  ; → case-insensitive, same as "i)..."

; ✓ A double quote inside a double-quoted regex literal takes the backtick escape —
;   AHK's parser consumes the backtick, so PCRE receives a bare " character
quotedText := "`"([^`"]*)`""
if RegExMatch('He said "Hello" to me', quotedText, &q)
    inner := q[1]                        ; Hello

; ✓ The same pattern in a single-quoted literal needs no escaping at all — prefer this.
;   Both spellings produce a byte-identical pattern string; verified equal on the fork.
quotedText2 := '"([^"]*)"'

; ✗ v1 doubled-quote escaping is a LOAD ERROR in v2, not an alternative spelling
; bad := """([^""]*)"""

; ✓ Backslash is not a string escape, so a path LITERAL keeps single backslashes;
;   only the PCRE pattern doubles them — one level, never four
filePath := "C:\Folder\File.txt"
regexPath := "C:\\Folder\\File\.txt"     ; \\ per literal backslash, \. for a literal dot
pathOk := RegExMatch(filePath, regexPath) != 0

; ✓ ~= is the regex-match operator — same engine, returns position or 0, no match object
isIsoDate := "2026-08-26" ~= "^\d{4}-\d{2}-\d{2}$"

; ✓ Global iteration: feed the previous match end back in as startPos.
;   The || 1 guard advances past a zero-width match instead of looping forever.
all := []
pos := 1
while pos := RegExMatch("a1 b22 c333", "\d+", &m, pos) {
    all.Push(m[0])                       ; 1, 22, 333
    pos += StrLen(m[0]) || 1
}

; ✗ An anchored validator can never match inside prose — extraction needs the same
;   pattern with ^ and $ removed
; RegExMatch("Contact support@example.com now", "^[^@\s]+@[^@\s]+\.[^@\s]+$")  ; → 0
```

Escaping a quote inside a regex pattern (a SOURCE-TEXT concern, not a regex one):
- A quote is not a PCRE metacharacter — nothing about the *pattern* needs escaping; the problem is only that the quote would end the AHK string literal early
- In a double-quoted literal write `` `" ``; in a single-quoted literal write `"` directly — both hand the engine the same pattern
- Doubled `""` is v1-only and a load error in v2 — never a fallback
- Prefer the single-quoted literal for any pattern containing quotes: `'"([^"]*)"'` reads as regex, `` "`"([^`"]*)`"" `` reads as line noise

Backslashes in a pattern string:
- The AHK string layer contributes **no** backslash escaping — `"C:\Folder"` is already a literal backslash
- Only PCRE doubles it: one `\\` per literal backslash you want matched. The four-backslash form from C#/Java/Python string literals is wrong here and matches two backslashes
- `\.` `\$` `\(` are PCRE escapes and are unaffected by AHK's backtick

Common pre-escaped patterns (single-quoted where a quote appears):
| Purpose | Pattern |
|---------|---------|
| Email (whole-string validation) | `"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"` |
| URL | `"^(?:https?://)?[\da-z][\da-z.-]*\.[a-z]{2,6}(?:[/\w.-]*)*/?$"` |
| Whole string is quoted | `'^"(.*)"$'` |
| Quoted run anywhere in text | `'"([^"]*)"'` |
| CSV field (quoted or bare) | `'(?:^\|,)(?:"([^"]*)"\|([^,]*))'` |
| IPv4 address | `"^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$"` |
| ISO date | `"^\d{4}-\d{2}-\d{2}$"` |
| Windows path (drive or UNC) | `'^(?:[a-zA-Z]:\\\|\\\\)(?:[^\\/:*?"<>\|\r\n]+\\)*[^\\/:*?"<>\|\r\n]*$'` |
| Balanced HTML tag | `"<([a-zA-Z][a-zA-Z0-9]*)[^>]*>(.*?)</\1>"` |

The `^...$` anchors on the validators above make them whole-string tests. Strip both anchors before using one for extraction — an anchored pattern scanning prose returns 0 every time. The CSV pattern deliberately omits a trailing `(?:,|$)`: consuming the delimiter makes the next iteration start past the following field's leading comma and silently skip that field.

Regex Options (leading `option)` prefix):
- `i)` → case-insensitive matching
- `m)` → multiline mode (`^` and `$` match line boundaries)
- `s)` → single-line mode (`.` matches newlines)
- `x)` → extended mode (ignore unescaped whitespace, allow `#` comments in pattern)
- Combine: `"im)pattern"` for both multiline and case-insensitive
- PCRE inline groups (`(?i)`, `(?im)`) also work; suffix flags (`/i`) do not — they become literal pattern characters

Common Character Classes:
- `\d` → digit `[0-9]` · `\D` → non-digit
- `\w` → word character `[a-zA-Z0-9_]` · `\W` → non-word
- `\s` → whitespace `[ \t\n\r\f]` · `\S` → non-whitespace

Capture Groups:
- `()` → numbered capturing group
- `(?:)` → non-capturing group
- `(?P<n>)` → named capture group
- `$1`, `$2`, `${name}` → backreferences in replacement string

## TIER 5 — String Validation Classes
> METHODS COVERED: RegExMatch · StringValidator.IsEmail · StringValidator.IsPhone · StringValidator.HasOnlyAlphanumeric · StringValidator.ValidateInput

Organise related validation logic into static-method classes that return consistent results. Regex-based validators compose well with variadic rule functions, enabling flexible multi-rule validation without conditional chains. This pattern keeps validation rules co-located and reusable across scripts.
```ahk
; ✓ Static methods return RegExMatch result directly — 0 or match position, truthy/falsy
class StringValidator {
    static IsEmail(str) {
        return RegExMatch(str, "^[^@\s]+@[^@\s]+\.[^@\s]+$")
    }

    static IsPhone(str) {
        return RegExMatch(str, "^\d{3}-\d{3}-\d{4}$")
    }

    static HasOnlyAlphanumeric(str) {
        return RegExMatch(str, "^[a-zA-Z0-9]+$")
    }

    ; ✓ Variadic rules* parameter accepts any number of callable validators
    static ValidateInput(str, rules*) {
        errors := []
        for rule in rules {
            if !rule(str)
                errors.Push("Validation failed")
        }
        return errors.Length = 0
    }
}
```

### Performance Notes

**Prefer built-in string functions over manual loops** — `StrReplace()`, `InStr()`, `SubStr()`, and `Trim()` are implemented in native code; a manual character loop for the same task runs 10–100× slower for typical string lengths.

**Regex compilation cost** — AHK v2 caches the 100 most recently compiled patterns in memory, so recompilation only occurs on a cache miss. For patterns used in tight loops, assigning the pattern to a variable and reusing the variable across calls is clearer and avoids accidental cache eviction from cache-size overflow.

**`StrReplace()` vs regex for literal substitution** — `StrReplace()` is faster than `RegExReplace()` for fixed-string replacement because no pattern compilation occurs; use `StrReplace()` whenever the needle contains no metacharacters.

**StringBuilder pattern vs inline `.=` concatenation** — for building strings from fewer than ~20 parts, inline `.=` concatenation is fast enough; the `StringBuilder` class (TIER 6) amortises allocation cost by collecting parts in an Array and joining once, which matters when building strings from hundreds of fragments in a loop.

**`StrSplit()` result size** — splitting a large text by a single character produces an Array with one element per separator occurrence; for very large inputs, process line-by-line with `FileOpen` + `.ReadLine()` rather than splitting an entire file content string into memory at once.

## TIER 6 — StringBuilder and TextSanitizer: Advanced String Construction
> METHODS COVERED: StringBuilder.Add · StringBuilder.AddLine · StringBuilder.AddFormattedLine · StringBuilder.Join · StringBuilder.ToString · TextSanitizer.ToSingleLine · TextSanitizer.EscapeForCommand · StrReplace · InStr · StrLen · Trim · Format · InputBox · RTrim

`StringBuilder` amortises repeated string allocation by collecting parts in an Array and joining once, which outperforms incremental `.=` concatenation for large fragment counts. `TextSanitizer` handles the two runtime text scenarios that actually exist: flattening real control characters for single-line display, and quoting command-line arguments containing spaces or tabs. It deliberately does *not* validate "escape sequences" in user input — backticks are a source-text concept and are already resolved before any string reaches your code.
```ahk
; ✓ Fluent interface — each method returns this for chaining
class StringBuilder {
    __New() {
        this.parts := []
    }

    Add(text) {
        this.parts.Push(text)
        return this
    }

    AddLine(text) {
        this.parts.Push(text . "`n")
        return this
    }

    ; ✓ Format() handles positional placeholders — cleaner than manual concatenation.
    ;   The parameter is `fmt`, NOT `format`: a local named `format` shadows the built-in
    ;   Format() case-insensitively, and the call throws "no method named Call" at runtime.
    AddFormattedLine(fmt, values*) {
        line := Format(fmt, values*)
        this.parts.Push(line . "`n")
        return this
    }

    ; ✓ Ternary separator in loop — no .Join() method exists on Array
    Join(separator := "") {
        result := ""
        for i, part in this.parts
            result .= part (i < this.parts.Length ? separator : "")
        return result
    }

    ; ✓ RTrim strips ANY trailing newlines — it takes a character set, not one token
    ToString() {
        return RTrim(this.Join(), "`n")
    }
}

; Backtick escaping is LEXICAL — it exists only in AHK source text and is gone by the time
; the script runs. A runtime string has no escape sequences left to validate: "a`nb" is
; already the three characters a, LF, b. Never scan user input for backticks or "malformed
; escapes" — every backtick a user types is just a backtick. A spawned process never sees
; backticks either; Windows command-line quoting uses \" for an embedded quote.
class TextSanitizer {
    ; ✓ Flattens real control characters to spaces for single-line display
    static ToSingleLine(str) {
        str := StrReplace(str, "`r`n", " ")
        str := StrReplace(str, "`n", " ")
        str := StrReplace(str, "`t", " ")
        return str
    }

    static EscapeForCommand(str) {
        if InStr(str, " ") || InStr(str, "`t") || InStr(str, '"')
            return '"' . StrReplace(str, '"', '\"') . '"'
        return str
    }
}

; ✓ Fluent chaining — each AddLine returns the StringBuilder instance
systemReport := StringBuilder()
systemReport.AddLine("System Information")
            .AddLine("==================")
            .AddLine("OS: " . A_OSVersion)
            .AddLine("User: " . A_UserName)
            .AddLine("Computer: " . A_ComputerName)

; ✓ Continuation expression — parentheses allow a multi-line expression in which the
;   variables outside the quotes are evaluated and concatenated
winWidth := 800, winHeight := 600
configFile := (
    "[Settings]`n"
    "AutoStart=true`n"
    "Theme=dark`n"
    "WindowSize=" winWidth "x" winHeight "`n"
    "LastUpdate=" A_Now
)

; ✓ Validation errors collected in Array — joined with a loop because Array has no .Join()
try {
    userInput := InputBox("Enter text:", "Input").Value
    errors := []
    if StrLen(Trim(userInput)) = 0
        errors.Push("Input is empty")
    if StrLen(userInput) > 260
        errors.Push("Input exceeds 260 characters")
    if errors.Length > 0 {
        errMsg := ""
        for e in errors
            errMsg .= e . ", "
        throw ValueError("Invalid input: " . RTrim(errMsg, ", "))
    }
    processedText := TextSanitizer.ToSingleLine(userInput)
} catch Error as e {
    MsgBox("Error: " . e.Message)
}
```

## TIER 7 — RegExEscapeUtil: Literal Escaping and Pattern Construction
> METHODS COVERED: RegExEscapeUtil.EscapeForRegEx · RegExEscapeUtil.CreatePattern · RegExEscapeUtil.EscapeForSource · RegExEscapeUtil.ExtractMatches · RegExEscapeUtil.ReplaceCallback · StrReplace · StrLen · SubStr · RegExMatch

Three regex jobs have no built-in in AHK v2: turning arbitrary runtime text into a pattern that matches it literally, collecting *every* match rather than the first, and replacing each match with a value computed per match (`RegExReplace()` accepts only a literal replacement string). `RegExEscapeUtil` covers all three plus a named pattern library. `EscapeForSource` is the one legitimate escape-generation case — emitting AHK source text — and is the opposite of `TextSanitizer` in TIER 6, which correctly refuses to "validate escapes" in runtime input.
```ahk
; ✓ static __New() fills the Map one key at a time — the Map() constructor-with-pairs
;   form is banned, and a class-body initializer routes through __Set, so the body
;   declares an empty Map() and the population happens here
class RegExEscapeUtil {
    static Patterns := Map()

    static __New() {
        p := this.Patterns
        p["email"]         := "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
        p["url"]           := "^(?:https?://)?[\da-z][\da-z.-]*\.[a-z]{2,6}(?:[/\w.-]*)*/?$"
        p["quoted_string"] := '^"(.*)"$'
        p["double_quotes"] := '"([^"]*)"'
        ; No trailing (?:,|$) — consuming the delimiter makes the next iteration skip a field
        p["csv_field"]     := '(?:^|,)(?:"([^"]*)"|([^,]*))'
        p["ip_address"]    := "^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$"
        p["date_iso"]      := "^\d{4}-\d{2}-\d{2}$"
        p["file_path"]     := '^(?:[a-zA-Z]:\\|\\\\)(?:[^\\/:*?"<>|\r\n]+\\)*[^\\/:*?"<>|\r\n]*$'
        p["html_tag"]      := "<([a-zA-Z][a-zA-Z0-9]*)[^>]*>(.*?)</\1>"
    }

    ; ✓ Neutralises every PCRE metacharacter so runtime text matches literally.
    ;   Backslash is FIRST in the set, so the escapes added by later passes are not
    ;   themselves re-escaped. Escaping ) also disarms AHK's leading `option)` prefix:
    ;   verified on the fork, "im)literal" escapes to "im\)literal" and matches
    ;   case-SENSITIVELY — the i flag is never parsed.
    static EscapeForRegEx(str) {
        specialChars := "\.^$*+?()[]{}|"
        result := str
        Loop Parse specialChars
            result := StrReplace(result, A_LoopField, "\" A_LoopField)
        return result
    }

    ; ✓ Builds a pattern from a template, escaping each interpolated value first
    static CreatePattern(template, params*) {
        pattern := template
        for i, param in params
            pattern := StrReplace(pattern, "{" i "}", this.EscapeForRegEx(param))
        return pattern
    }

    ; ✓ Renders a runtime string as the INNER TEXT of an AHK v2 double-quoted source
    ;   literal. Only for GENERATING AHK source — never for normal runtime handling;
    ;   a live string has no escape sequences left in it (TIER 6).
    static EscapeForSource(str) {
        bt := Chr(96)                    ; a lone backtick, without a run of them in source
        result := StrReplace(str, bt, bt bt)   ; escape the escape character FIRST
        result := StrReplace(result, '"', bt '"')
        result := StrReplace(result, "`n", bt "n")
        result := StrReplace(result, "`r", bt "r")
        result := StrReplace(result, "`t", bt "t")
        return result
    }

    ; ✓ Collects every match; groupNum is guarded against .Count because alpha.30
    ;   throws on a group the pattern never defines
    static ExtractMatches(str, pattern, groupNum := 0) {
        found := []
        pos := 1
        while pos := RegExMatch(str, pattern, &m, pos) {
            found.Push(groupNum = 0 || groupNum <= m.Count ? m[groupNum] : "")
            pos += StrLen(m[0]) || 1
        }
        return found
    }

    ; ✓ Per-match replacement logic — RegExReplace() takes only a literal replacement
    ;   string, so a callback needs this manual scan-and-rebuild loop
    static ReplaceCallback(str, pattern, callback) {
        out := "", lastPos := 1
        while pos := RegExMatch(str, pattern, &m, lastPos) {
            out .= SubStr(str, lastPos, pos - lastPos) callback(m)
            lastPos := pos + (StrLen(m[0]) || 1)
        }
        return out SubStr(str, lastPos)
    }
}

; ✓ Escaped literal matches as text, not as a metacharacter soup
needle := RegExEscapeUtil.EscapeForRegEx("cost (USD): $5.00")
found := RegExMatch("Line: cost (USD): $5.00 total", needle)   ; 7

; ✓ Extraction uses an UNANCHORED variant — Patterns["email"] is ^...$ anchored for
;   whole-string validation and never matches inside prose
emails := RegExEscapeUtil.ExtractMatches(
    "Contact support@example.com or sales@example.com.",
    "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")

; ✓ Fat arrow holds a single expression, so it is legal as the callback
upperQuoted := (m) => '"' StrUpper(m[1]) '"'
csv := RegExEscapeUtil.ReplaceCallback('Item1,"some text",Item3',
    RegExEscapeUtil.Patterns["double_quotes"], upperQuoted)   ; Item1,"SOME TEXT",Item3

; ✓ CreatePattern escapes the interpolated key before splicing it in
tpl := RegExEscapeUtil.CreatePattern("^{1}\s*=\s*(.+)$", "key.name")
; tpl is "^key\.name\s*=\s*(.+)$" — the dot matches a dot, not any character
```

## ANTI-PATTERNS

| Pattern | Wrong | Correct | LLM Common Cause |
|---------|-------|---------|------------------|
| Backslash escape sequences | `"\n"` `"\t"` in AHK string | `` "`n" `` `` "`t" `` | All major language training data uses `\n`; AHK v2 uses backtick — strongest source of cross-language regression |
| Legacy command-style string ops | Comma-delimited command statements with bare output variables | `StrReplace(str, old, new)` and the other v2 string functions | Legacy AutoHotkey command syntax dominates older training data |
| Bare output var in RegExMatch | `RegExMatch(str, pat, match)` | `RegExMatch(str, pat, &match)` | Legacy AutoHotkey used bare output variable names; the v2 `&` ByRef prefix is easy to overlook |
| Calling Array .Join() | `arr.Join(", ")` | Loop with ternary separator or `RTrim()` pattern | JavaScript/Python training data; both languages have a native `.join()` method |
| Suffix regex flags | `"pattern/i"` | `"i)pattern"` prefix, or PCRE inline `(?i)` | Perl/JS suffix-flag syntax is pervasive in training data; a trailing `/i` is not a flag — it becomes the literal pattern characters `/i` and the pattern stops matching |
| StrReplace result discarded | `StrReplace(str, old, new)` without capture | `str := StrReplace(str, old, new)` | Python `str.replace()` returns in-place in typical usage context; habit of ignoring return value |
| Excessive escaping instead of quote-switching | ``"It`'s fine"`` | `"It's fine"` (no escaping needed) | Unawareness of AHK v2's equivalent single/double quote strings; default to escaping instead |
| Unguarded numbered group access | `match[3]` with no check | `match.Count >= 3 ? match[3] : ""` | v2.0 and most regex APIs return `""` for a missing group; alpha.30 throws instead |
| Validating "escape sequences" in runtime input | scanning user text for stray backticks | validate the decoded characters (length, charset, `RegExMatch`) | Escapes are lexical and already resolved — a runtime string has none left to check |
| `RTrim()` used as a token trimmer | `RTrim(s, ", ")` when an element may end in `,` or a space | ternary separator inside the join loop | `RTrim` takes a character SET; it keeps eating trailing commas and spaces |
| Doubled-quote escaping in a pattern | `"""([^""]*)"""` | `` "`"([^`"]*)`"" `` or, better, `'"([^"]*)"'` | v1 and C#/VB use `""` for an embedded quote; in v2 it is a load error, not a fallback |
| Over-doubling backslashes in a pattern | `"C:\\\\Folder"` | `"C:\\Folder"` | C#/Java/Python string literals also escape `\`, so the habit is to double twice; AHK's string layer escapes nothing, so one PCRE `\\` per literal backslash is the whole job |
| Anchored validator reused for extraction | `RegExMatch(prose, "^...@...$")` | drop `^` and `$` for the extraction variant | The pattern library entry is written for whole-string validation; scanning prose with it silently returns 0 forever |
| Interpolating raw text into a pattern | `"^" userKey "=(.+)$"` | `"^" EscapeForRegEx(userKey) "=(.+)$"` | Metacharacters in the value (`.`, `(`, `+`) silently change what the pattern means, or throw on an unbalanced `(` |
| Global-match loop with no advance guard | `pos := RegExMatch(...)` without `+= StrLen(m[0])` | `pos += StrLen(m[0]) \|\| 1` | A zero-width-capable pattern re-matches at the same position forever; the `\|\| 1` forces progress |
| Manual loop where `~=` suffices | `RegExMatch(s, p, &m)` then ignoring `m` | `s ~= p` | Unfamiliarity with the `~=` operator; the output var costs an allocation for an answer never read |

## SEE ALSO

> This module does NOT cover: reading and writing text files with encoding flags → use built-in AHK v2 knowledge (no dedicated file-system module yet).
> This module does NOT cover: GUI Edit/Text control content manipulation and multi-line display → see Module_GUI.md
> This module does NOT cover: hotstring trigger definitions, colon-colon syntax, and hotstring options → use built-in AHK v2 knowledge (no dedicated input/hotkeys module yet).
> This module does NOT cover: try/catch patterns for regex errors, Error subclasses, and structured error propagation → see Module_Errors.md

- FileOpen/FileRead/FileAppend with explicit encoding flags and line-by-line text iteration — use built-in AHK v2 knowledge (no dedicated file-system module yet).
- `Module_Arrays.md` — typed Array construction, Push/Pop/InsertAt, and iteration patterns used to store StrSplit results and StringValidator error collections.
- `Module_Errors.md` — try/catch wrapping for user-supplied regex patterns, Error subclass selection, and structured error propagation from validation classes.
- `Module_GUI.md` — GUI Edit control content, multi-line text display, and how `` `n `` interacts with Edit control line endings.
- Hotstring definitions, colon escaping in `::trigger::replacement` syntax, and hotstring option flags — use built-in AHK v2 knowledge (no dedicated input/hotkeys module yet).