# JSDoc in AHK v2 OOP Scripts
## A Practical Guide Based on Nich-Cebolla's Library Style

<!-- TRIGGERS: jsdoc, document, annotate, add docs, docstring, comment style, api docs -->

---

## Overview

JSDoc is a documentation convention originally designed for JavaScript. AHK v2's OOP model
is close enough to JS that JSDoc maps onto it naturally. Nich-Cebolla's libraries
(Container, FileMapping, Xtooltip, QuickStringify) use a consistent JSDoc dialect that:

- Works with `thqby/vscode-autohotkey2-lsp` for IntelliSense hover documentation.
- Provides a self-contained human-readable API reference directly in source.
- Supports cross-linking between classes, prototype methods, properties, and external URLs.
- Uses a custom `@` terminator to close `@example` blocks (non-standard, AHK-community convention).

The style is **not** processed by `jsdoc` CLI tooling. It is primarily a documentation
convention for humans and the LSP extension. You do not need any build step.

---

## When to Apply JSDoc

**Always document:**
- Public methods (any method a caller outside the class would use)
- Factory methods and static constructors
- Properties with non-obvious behavior, side effects, or constraints
- Callback parameters — always spell out the callback's interface
- Options-bag parameters — always use dot-notation sub-params
- Class-level descriptions (the `/**` block above `class ClassName`)

**Never document:**
- Private helper methods prefixed with `_` (e.g., `_ParseInternal()`)
- Simple getters/setters that return or assign a same-named backing field with no logic
- `__Delete()` destructors that only clean up (the pattern is self-evident)
- `static __New()` prototype initializers (internal plumbing)

**On request only:**
- File headers — add when publishing or sharing a library
- Existing undocumented code — add when explicitly asked to document a file
- `@example` blocks — add for complex or non-obvious APIs, not every method

**Decision rule:** If removing the method body would leave a caller unable to understand
what the method does, how to call it, or what it returns — it needs JSDoc.

---

## Minimum JSDoc (The Floor)

Every documented method must have at minimum:

```ahk
/**
 * Short description of what this method does.
 * @param {Type} Name - Description.
 * @returns {Type}
 */
```

This means: one-line description, typed `@param` for every parameter, and `@returns`
unless the method is void. Everything else (`@example`, `@link`, metadata prefixes)
is additive.

---

## Quick Reference Card

```
/**                              Open JSDoc block (double asterisk)
 * Description text.            Free-form Markdown, rendered by LSP hover
 *
 * @description - Text.         Explicit description tag (optional)
 *
 * @example                     Begin example block
 * Code here.
 * @                            Close example block (AHK convention)
 *
 * @param {Type} Name           Required parameter
 * @param {Type} [Name]         Optional, no default
 * @param {Type} [Name = val]   Optional with default
 * @param {...Type} [Name]      Variadic (maps to Params*)
 * @param {T} [Opts.Prop = v]   Nested options property
 *
 * @returns {Type}              Return type
 * @returns {Type} - Text.      Return type with description
 *
 * @type {Type}                 Property type annotation
 *
 * {@link ClassName}            Link to a class
 * {@link Class#Member}         Link to an instance member
 * {@link Class.Prototype.M}    Link to a prototype method (explicit)
 * {@link Class.StaticMethod}   Link to a static method
 * {@link https://url Label}    External hyperlink with label
 *
 * **bold**                     Bold text in descriptions
 * `code`                       Inline code
 * - item                       Bullet list item
 * <pre>text</pre>              Preformatted output block
 *
 */                             Close JSDoc block
```

---

## Block Structure

A JSDoc block uses `/**` to open and ` */` to close. Every interior line starts with
a single ` * ` (one space, one asterisk, one space before content).

```ahk
/**
 * Short description of what this method does.
 *
 * Longer description can follow after a blank `*` line.
 *
 * @param {String} Name - The name of the thing.
 * @returns {Integer}
 */
MyMethod(Name) {
    ; ...
}
```

Rules:
- The `/**` opener is on its own line.
- Closing ` */` is on its own line with no trailing content.
- Blank lines inside the block are written as a line containing only ` *`.
- The block appears **immediately** above the function, method, or property it documents.
  No blank lines between the closing ` */` and the definition.

---

## File Header Comments

The file-level header uses a plain `/* */` block comment, not a JSDoc `/**` block.
It is purely informational metadata -- not associated with any code entity.

```ahk
/*
Github: https://github.com/YourUser/YourRepo
Author: Your Name
Version: 1.0.0
License: MIT
*/
```

This block does not use the `@` tag system and does not begin with `/**`.
Keep it at the top of the file before any `#include` directives or class definitions.

---

## The @description Tag

Use `@description` when the introductory text is long enough that a formal tag makes the
structure clearer. For short one-liners, omit the tag — just write the description
as the first content of the block.

```ahk
/**
 * @description - Creates the function object.
 *
 * - Map objects are represented as `[["key", val]]`.
 * - This does not check for reference cycles.
 * - Unset array indices are represented as the JSON null value.
 *
 * @param {Object} [Options] - An object with options as property : value pairs.
 */
__New(Options?) {
```

Notes:
- The dash after `@description` is a stylistic separator, not required syntax.
- Markdown bullet lists (`- item`) work inside descriptions and render in the LSP hover.
- Backtick inline code renders as monospace in LSP hover text.

---

## The @param Tag

### Syntax

```
@param {Type} ParamName - Description.
@param {Type} [ParamName] - Optional parameter, no default.
@param {Type} [ParamName = DefaultValue] - Optional with default.
@param {...Type} [ParamName] - Variadic parameter.
```

### Type Tokens

| Situation | Type String |
|:---|:---|
| Any AHK value | `{*}` |
| String | `{String}` |
| Integer | `{Integer}` |
| Float | `{Float}` |
| Number (int or float) | `{Number}` |
| Boolean (0/1) | `{Boolean}` |
| Object (generic) | `{Object}` |
| Your class | `{MyClass}` |
| AHK Buffer | `{Buffer}` |
| AHK Array | `{Array}` |
| AHK Map | `{Map}` |
| Union types | `{String\|Integer}` |
| Callback/Func object | `{Func}` or `{Callable}` |
| Variadic spread | `{...String}` |

### Required Parameter

```ahk
/**
 * @param {String} FilePath - Path to the file to open.
 */
```

### Optional Parameter Without Default

Square brackets indicate optional. Omit the `= value` part.

```ahk
/**
 * @param {String} [Encoding] - If omitted, uses the system default encoding.
 */
```

### Optional Parameter With Default

```ahk
/**
 * @param {Boolean} [UseExMode = false] - If true, uses extended mode.
 * @param {Integer} [Timeout = 5000] - Milliseconds to wait before giving up.
 */
```

### Variadic Parameter

AHK v2 variadic params use `Params*` syntax. Document with `{...Type}`.

```ahk
/**
 * @param {...*} [Values] - Zero or more values to instantiate the container with.
 */
static Number(Values*) {
```

### Multi-Line Parameter Descriptions

When a parameter description is long, continue it on subsequent lines indented
past the tag alignment point:

```ahk
/**
 * @param {String|Integer} [LocaleName = LOCALE_NAME_USER_DEFAULT] - Pointer to a locale name,
 *     or one of the following predefined values:
 *     - LOCALE_NAME_INVARIANT
 *     - LOCALE_NAME_SYSTEM_DEFAULT
 *     - LOCALE_NAME_USER_DEFAULT
 */
```

---

## The @returns Tag

```ahk
/**
 * @returns {Container}
 */
static Number(Values*) {

/**
 * @returns {Integer} - The index at which the value was inserted.
 */
Insert(Value) {
```

Rules:
- When the return type is obvious from context (e.g., a setter), omit `@returns`.
- Methods returning `this` for chaining: document as `@returns {ClassName}`.
- Void methods (no meaningful return): omit `@returns` entirely.

---

## The @example Block

The `@example` tag opens a code block. **Always** close it with a bare `@` on its own
line (` * @`). This is an AHK-community convention that does not exist in standard JSDoc.

```ahk
/**
 * @example
 * CallbackValue(value) {
 *     return value.timestamp
 * }
 *
 * c := Container.CbDate(CallbackValue)
 * c.InsertList([
 *     { timestamp: "20250312122930" }
 *     , { timestamp: "20250411122900" }
 * ])
 * @
 *
 * @param {...} ...
 */
```

Rules:
- Everything between `@example` and the closing `@` is treated as example code.
- The closing `@` **must** be on its own line with the `*` prefix: ` * @`.
- Example code is written in AHK v2 syntax and should be runnable or near-runnable.
- You can include multiple `@example` blocks in a single JSDoc comment if needed.

### Example with Preformatted Output

For showing expected output, use `<pre>` tags inside the description (before `@param` tags):

```ahk
/**
 * @description - Stringifies an object to JSON.
 *
 * The example code yields the following output:
 * <pre>
 * {
 *   "Name": "value",
 *   "Count": 3
 * }
 * </pre>
 *
 * @example
 * obj := { Name: "value", Count: 3 }
 * strfy := QuickStringify()
 * strfy(obj, &str)
 * OutputDebug(str "`n")
 * @
 */
```

---

## Cross-References with @link

`{@link Target}` creates a hyperlink reference inside any JSDoc tag or description.
The LSP uses these for navigation (Ctrl+click). **Always** wrap class, method, and
property names in `{@link ...}` when mentioning them in descriptions.

### Linking to a Class

```ahk
 * See {@link Container} for the full API.
```

### Linking to a Static Method

```ahk
 * Calls {@link Container.Date} to set up comparison.
```

### Linking to an Instance Method or Property (Hash Notation)

Use `#` to indicate an instance member:

```ahk
 * Sets the function to property {@link Container#CallbackValue}.
 * Calls {@link Container#Insert}.
```

### Linking to a Prototype Method (Explicit)

When referencing a method via the prototype chain explicitly:

```ahk
 * This calls {@link Container.Prototype.SetCompareDate}.
 * See {@link Container.Prototype.DatePreprocess} for details.
```

Both notations (`Class#Method` and `Class.Prototype.Method`) appear in Nich-Cebolla's code.
The `#` form is more concise; the `.Prototype.` form is more precise when the distinction
between a static and prototype method matters.

### Linking to External URLs

```ahk
 * See {@link https://www.autohotkey.com/docs/v2/lib/DateDiff.htm DateDiff} for details.
```

The text after the URL (space-separated) becomes the link label.

```ahk
 * See {@link https://learn.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-comparestringex CompareStringEx}.
```

---

## Inline Formatting

All standard Markdown inline formatting works inside JSDoc descriptions because the
LSP renders it as Markdown.

| Effect | Syntax | Example |
|:---|:---|:---|
| Bold | `**text**` | `**CallbackValue**` |
| Inline code | `` `text` `` | `` `DateDiff` `` |
| Italic | `*text*` | `*optional*` |
| Bullet list | `- item` | `- LOCALE_NAME_INVARIANT` |
| Numbered list | `1. item` | `1. First step` |
| Preformatted | `<pre>...</pre>` | Block output samples |

---

## Custom Metadata Prefixes

For methods with specific operational requirements, open the description
with one or two short metadata sentences before the explanatory text:

```ahk
/**
 * Requires a sorted container: yes.
 *
 * Allows unset indices: no.
 *
 * Inserts a value in order.
 *
 * @param {*} Value - The value.
 * @returns {Integer} - The index at which it was inserted.
 */
Insert(Value) {
```

```ahk
/**
 * Requires a sorted container: no.
 *
 * Allows unset indices: yes.
 *
 * Removes all unset indices, shifting values to the left.
 */
Condense(IndexStart := 1, IndexEnd := this.Length) {
```

Apply this pattern whenever methods have binary preconditions or behavioral constraints
that every caller needs to know upfront. Common uses:

- `Requires open handle: yes/no.`
- `Thread-safe: yes/no.`
- `Modifies caller state: yes/no.`

---

## Documenting Nested Options Objects

When a parameter is a plain object used as an options bag, document each property
as a sub-parameter using dot notation:

```ahk
/**
 * @param {Object} [Options] - An object with options as property : value pairs.
 * @param {String} [Options.Eol = "`n"] - The end-of-line character(s).
 * @param {String} [Options.IndentChar = "`s"] - The character used for indentation.
 * @param {Integer} [Options.IndentLen = 2] - Number of IndentChar per indent level.
 */
__New(Options?) {
```

Note: The `` `n `` and `` `s `` above are AHK escape sequences (newline and space).

Rules:
- The parent `Options` param is documented first as optional (`[Options]`).
- Each child is `[Options.PropertyName = Default]`.
- The sub-params appear in the same JSDoc block immediately after the parent.
- This gives the LSP enough information to show the full options surface in hover text.

---

## Documenting Callback Parameters

When a parameter is a callback, **never** just write `{Func}`. Always spell out the
callback's parameter list and return value in the description body:

```ahk
/**
 * @param {*} CallbackCompare - The callback used as a comparator. Sets
 *     {@link Container#CallbackCompare}.
 *
 *     Parameters:
 *     1. A value to be compared.
 *     2. A value to be compared.
 *
 *     Returns {Number}:
 *     - Less than zero: first parameter is less than the second.
 *     - Zero: parameters are equal.
 *     - Greater than zero: first parameter is greater than the second.
 */
static Misc(CallbackCompare, Values*) {
```

This gives callers a complete picture of what the callback must implement.

---

## Factory Methods vs. Instance Methods

**Always** open each factory method's JSDoc with a structured "state summary" block
that names the key functional properties the factory configures:

```ahk
/**
 * - **CallbackValue**: Provided by your code and returns a number.
 * - **CallbackCompare**: Not used.
 *
 * @example
 * c := Container.Number()
 * c.InsertList([ 298581, 195801, 585929 ])
 * @
 *
 * @param {...*} [Values] - Zero or more values to instantiate the container with.
 * @returns {Container}
 */
static Number(Values*) {
```

This two-line preflight summary tells the user which properties they are responsible
for providing and which the factory handles internally. Apply this pattern to any
class that has multiple factory methods that configure overlapping sets of properties.

For instance methods, the state summary is replaced by the custom metadata
prefixes described above (sorted/sparse requirements).

---

## Properties

Properties do not use `@param`. Document a property's purpose with a free-form
description and use `@type` to annotate the type:

```ahk
/**
 * The active sort type constant. Controls which comparison branch
 * {@link Container.Prototype.Compare} uses. Set by the factory methods or
 * by calling {@link Container.Prototype.SetSortType} directly.
 *
 * @type {Integer}
 */
SortType {
    Get => this._SortType
    Set => this.SetSortType(Value)
}
```

For simple computed properties defined with `=>`, place a single-line block
immediately above:

```ahk
/** @type {String} - The indent character currently in use. */
IndentChar {
    Get => this.__IndentChar
    Set => this.SetIndentChar(Value)
}
```

---

## Common Mistakes

### Missing type braces

```ahk
; WRONG — type must be wrapped in braces
 * @param String Name - Description.

; CORRECT
 * @param {String} Name - Description.
```

### Lazy callback documentation

```ahk
; WRONG — tells the caller nothing about the callback interface
 * @param {Func} Callback - A callback function.

; CORRECT — spells out what the callback receives and returns
 * @param {*} Callback - Called with (Record, Index).
 *     Parameters:
 *     1. `{Object}` Record - The current record.
 *     2. `{Integer}` Index - The 1-based index.
 *     Returns `{Integer}` - Nonzero to stop, zero to continue.
```

### Missing `@` terminator on example blocks

```ahk
; WRONG — example block never closed, swallows everything after it
 * @example
 * x := MyClass()
 * x.DoWork()
 *
 * @param {String} Name - This gets absorbed into the example.

; CORRECT — close with bare @ before continuing
 * @example
 * x := MyClass()
 * x.DoWork()
 * @
 *
 * @param {String} Name - Now correctly parsed as a param tag.
```

### JSDoc on private helpers

```ahk
; WRONG — internal plumbing does not need JSDoc
/**
 * Parses the internal buffer.
 * @param {Buffer} Buf - The buffer.
 * @returns {String}
 */
_ParseInternal(Buf) {

; CORRECT — omit JSDoc for _ prefixed internals
_ParseInternal(Buf) {
```

### Blank line between JSDoc and definition

```ahk
; WRONG — blank line disconnects the block from the method
/**
 * Inserts a record.
 */

Insert(Record) {

; CORRECT — no gap
/**
 * Inserts a record.
 */
Insert(Record) {
```

---

## Full Annotated Example

The following is a complete, standalone AHK v2 class with JSDoc applied according
to every pattern described in this guide.

```ahk
/*
Github: https://github.com/you/MyLib
Author: Your Name
Version: 1.0.0
License: MIT
*/

/**
 * A sorted collection of records that supports binary search
 * and ordered insertion by a named numeric key.
 */
class RecordSet extends Array {

    static __New() {
        this.DeleteProp("__New")
        proto := this.Prototype
        proto._KeyName := ""
        proto._Length  := 0
    }

    /**
     * - **KeyName**: The property name used to extract a numeric sort key.
     * - **CallbackFilter**: Not used.
     *
     * Creates a {@link RecordSet} sorted by a numeric property on each record.
     *
     * @example
     * rs := RecordSet.ByKey("Score")
     * rs.Insert({ Name: "Alice", Score: 92 })
     * rs.Insert({ Name: "Bob",   Score: 78 })
     * @
     *
     * @param {String} KeyName - The property name used to extract the sort key.
     *     Stored in {@link RecordSet#KeyName}.
     * @param {...*} [Records] - Zero or more initial records to push unsorted.
     * @returns {RecordSet}
     */
    static ByKey(KeyName, Records*) {
        rs := RecordSet(Records*)
        rs._KeyName := KeyName
        return rs
    }

    /**
     * Converts an existing `Array` to a {@link RecordSet}.
     * The array must already be sorted by `KeyName`.
     *
     * @param {Array} Arr - The sorted array to convert.
     * @param {String} KeyName - The property name used as the sort key.
     * @returns {RecordSet}
     */
    static FromSortedArray(Arr, KeyName) {
        ObjSetBase(Arr, RecordSet.Prototype)
        Arr._KeyName := KeyName
        return Arr
    }

    /**
     * Requires a sorted container: yes.
     *
     * Allows unset indices: no.
     *
     * Inserts `Record` in sorted order by {@link RecordSet#KeyName}.
     * Uses binary search to locate the insertion point in O(log n).
     *
     * @param {Object} Record - Must have a numeric property matching {@link RecordSet#KeyName}.
     * @returns {Integer} - The 1-based index at which the record was inserted.
     */
    Insert(Record) {
        key := Record.%this._KeyName%
        lo  := 1
        hi  := this.Length
        while lo <= hi {
            mid := (lo + hi) >> 1
            if key < this[mid].%this._KeyName% {
                hi := mid - 1
            } else {
                lo := mid + 1
            }
        }
        this.InsertAt(lo, Record)
        return lo
    }

    /**
     * Requires a sorted container: yes.
     *
     * Allows unset indices: no.
     *
     * Finds a record whose {@link RecordSet#KeyName} matches `KeyValue`.
     * Returns 0 if no match is found.
     *
     * @param {Number} KeyValue - The numeric key to search for.
     * @returns {Integer} - The 1-based index of the matching record, or 0 if absent.
     */
    Find(KeyValue) {
        lo := 1
        hi := this.Length
        while lo <= hi {
            mid := (lo + hi) >> 1
            v   := this[mid].%this._KeyName%
            if KeyValue = v {
                return mid
            } else if KeyValue < v {
                hi := mid - 1
            } else {
                lo := mid + 1
            }
        }
        return 0
    }

    /**
     * Requires a sorted container: no.
     *
     * Allows unset indices: yes.
     *
     * Calls `Callback` for each record. Stops and returns the index
     * of the first record for which `Callback` returns a truthy value.
     * Returns 0 if no record matches.
     *
     * @param {*} Callback - Called with `(Record, Index)`.
     *
     *     Parameters:
     *     1. `{Object}` Record - The current record.
     *     2. `{Integer}` Index - The 1-based index.
     *
     *     Returns `{Integer}` - Nonzero to stop, zero to continue.
     *
     * @returns {Integer} - The matching index, or 0.
     */
    FindWhere(Callback) {
        for i, rec in this {
            if Callback(rec, i) {
                return i
            }
        }
        return 0
    }

    /**
     * The property name used as the numeric sort key.
     *
     * Do not set this directly after records have been inserted.
     * Use a new {@link RecordSet} instance instead.
     *
     * @type {String}
     */
    KeyName {
        Get => this._KeyName
    }
}
```

---

## Key Takeaways

- **Always close `@example` blocks with ` * @` on its own line.** This is an AHK-community
  convention that does not exist in standard JSDoc. Forgetting it will swallow all subsequent
  tags into the example block.

- **Always wrap names in `{@link ...}`.** Any time you mention a class, method, or property
  by name in a description, use `{@link ...}`. This enables Ctrl+click navigation in VS Code.

- **Always document callback interfaces.** Never just write `{Func}`. Spell out the
  callback's parameter list and return contract in the description body.

- **Always open factory methods with a state summary.** Two-item bullet list naming the key
  properties the factory configures and which it does not.

- **Always open constrained instance methods with metadata prefixes.** "Requires sorted:
  yes/no" and similar binary constraints go before the description text.

- **Always use dot notation for nested options.** `[Options.Eol]`, `[Options.IndentChar]`
  etc. — this is how the LSP discovers the options surface.

- **Never document `_` prefixed private methods.** They are internal plumbing.

- **Never leave a blank line between `*/` and the definition.** The JSDoc block must be
  immediately above the code it documents.
