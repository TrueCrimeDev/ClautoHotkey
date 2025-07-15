# Topic: String Handling in AHK v2

## Category

Concept

## Overview

AutoHotkey v2 offers a unique approach to string handling and manipulation that differs from many other programming languages. It features implicit string concatenation, powerful text processing capabilities through RegExMatch/RegExReplace functions, and various string manipulation methods that make text operations straightforward and efficient.

## Key Points

- AHK v2 uses implicit string concatenation (putting strings next to each other) instead of operators or interpolation
- String variables can be included directly within quoted strings for simple concatenation
- AHK v2 provides powerful regex functions for pattern matching and text replacement
- Strings support methods for common operations like case conversion, substring extraction, and replacement

## Syntax and Parameters

```cpp
; String concatenation syntax
str1 := "Hello"
str2 := "World"
combined := str1 " " str2  ; "Hello World"

; Including variables in strings
name := "John"
greeting := "Hello " name "!"  ; "Hello John!"

; String methods
str := "Example Text"
length := StrLen(str)  ; Get string length
upper := StrUpper(str)  ; Convert to uppercase
lower := StrLower(str)  ; Convert to lowercase
pos := InStr(str, "Text")  ; Find substring position
sub := SubStr(str, 1, 7)  ; Extract substring

; Regular expression functions
RegExMatch(str, pattern, &match)
RegExReplace(str, pattern, replacement)
```

## Code Examples

```cpp
; Basic string concatenation
firstName := "John"
lastName := "Doe"
fullName := firstName " " lastName  ; "John Doe"

; Building complex strings
age := 30
message := "Name: " firstName " " lastName "`nAge: " age  ; Note the `n for newline

; String formatting example
FormatAddress(street, city, state, zip) {
    return street "`n" city ", " state " " zip
}
address := FormatAddress("123 Main St", "Anytown", "NY", "12345")

; Working with substrings
email := "user@example.com"
atPos := InStr(email, "@")
domain := SubStr(email, atPos + 1)  ; "example.com"
username := SubStr(email, 1, atPos - 1)  ; "user"

; String case manipulation
text := "Hello World"
upperText := StrUpper(text)  ; "HELLO WORLD"
lowerText := StrLower(text)  ; "hello world"
titleText := StrTitle(text)  ; "Hello World" (first letter of each word capitalized)

; String replacement
sentence := "The quick brown fox jumps over the lazy dog"
newSentence := StrReplace(sentence, "fox", "cat")  ; "The quick brown cat jumps over the lazy dog"

; Regular expression example - extracting phone numbers
text := "Contact us at (555) 123-4567 or 555-987-6543"
pattern := "\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"

; Finding all matches
pos := 1
while (pos := RegExMatch(text, pattern, &match, pos)) {
    MsgBox "Found phone number: " match[0]
    pos += StrLen(match[0])
}

; Replacing phone numbers with a masked version
masked := RegExReplace(text, "(\d{3})(\d{3})(\d{4})", "$1-XXX-XXXX")
```

## Implementation Notes

- Implicit string concatenation can lead to unexpected results if variables are accidentally placed next to string literals
- AHK v2 strings are UTF-16 encoded, which means each character can be 2 or 4 bytes
- The StrReplace function is case-sensitive by default, but has an optional parameter to make it case-insensitive
- When using regex functions, remember to escape special characters with backslash
- String operations create new strings in memory, so excessive string manipulation in tight loops can impact performance
- Use backtick escape sequences like `` `n `` for newlines and `` `t `` for tabs

## Related AHK Concepts

- Regular Expressions
- Text File Processing
- User Input Handling
- Variables and Data Types
- GUI Text Controls

## Tags

#AutoHotkey #Strings #TextProcessing #RegularExpressions #StringConcatenation