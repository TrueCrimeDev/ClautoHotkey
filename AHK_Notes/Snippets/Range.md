# Topic: Range Function for Custom Iteration

## Category

Snippet

## Overview

The Range function creates a custom iterator that generates a sequence of numbers between specified start and stop values, with an optional step increment. Similar to Python's range() function, this allows for concise numeric iteration in for-loops without creating large intermediate arrays, making it memory-efficient for large ranges.

## Key Points

- Creates a sequence generator for numeric ranges
- Supports ascending and descending ranges with custom step values
- Uses minimal memory regardless of range size
- Implements custom iterator pattern with __Enum functionality
- Can replace traditional numeric Loop constructs with more readable code

## Syntax and Parameters

```cpp
Range(Start, Stop, Step:=1)
```

- `Start`: First value in the sequence
- `Stop`: Last value in the sequence (inclusive)
- `Step`: Increment between values (default: 1, can be negative for descending ranges)

## Code Examples

```cpp
; Example 1: Basic ascending range
#Requires AutoHotkey v2

; Count from 1 to 10
For n in Range(1, 10)
    MsgBox n  ; Shows 1, 2, 3, ..., 10

; Example 2: Custom step size
; Count by 2s from 1 to 9
For n in Range(1, 9, 2)
    MsgBox n  ; Shows 1, 3, 5, 7, 9

; Example 3: Descending range
; Count down from 10 to 1
For n in Range(10, 1, -1)
    MsgBox n  ; Shows 10, 9, 8, ..., 1

; Example 4: Using with array operations
; Create an array with numbers from 1 to 5
numbers := []
For n in Range(1, 5)
    numbers.Push(n)
MsgBox JSON.Stringify(numbers)  ; Shows [1,2,3,4,5]

; Example 5: Traditional loop equivalent
; The Range function replaces code like this:
Loop 10 {
    n := A_Index
    MsgBox n
}

; Example 6: Practical application - countdown timer
For seconds in Range(10, 1, -1) {
    ToolTip "Time remaining: " seconds " seconds"
    Sleep 1000
}
ToolTip "Time's up!"
```

## Implementation Notes

```cpp
; One-line implementation of the Range function
Range(Start, Stop, Step:=1) => (&n) => (n := Start, Start += Step, Step > 0 ? n <= Stop : n >= Stop)
```

How this implementation works:

1. The `Range` function returns a closure that serves as a custom iterator
2. The closure takes a single output variable reference (`&n`)
3. Each time the closure is called during iteration:
   - It assigns the current value to the output variable (`n := Start`)
   - Increments the Start value for the next iteration (`Start += Step`)
   - Returns a boolean indicating whether to continue iteration
   - For ascending ranges (Step > 0): continue if n <= Stop
   - For descending ranges (Step < 0): continue if n >= Stop

Key aspects of the implementation:

- **State Management**: The `Start` and `Step` variables maintain state between iterations
- **Compact Syntax**: Uses fat arrow functions for concise expression
- **Lazy Evaluation**: Values are generated one at a time during iteration
- **Memory Efficiency**: No array is created to hold the range values
- **Flexible Direction**: Supports both ascending and descending ranges
- **Termination Logic**: Different comparison operators based on step direction

This implementation demonstrates the power of custom iterators in AutoHotkey v2. In just one line, it replaces what would otherwise require a class with an `__Enum` method or a more complex function structure.

### Limitations:

- Does not handle floating-point precision issues if used with floating-point values
- May cause infinite loops if Step is 0
- Does not provide index information (like A_Index in traditional loops)

## Related AHK Concepts

- For loops and iteration
- Custom iterators and __Enum implementation
- Closures and state management
- Fat arrow function syntax
- Output variable references
- Conditional expressions
- Loop alternatives

## Tags

#AutoHotkey #Range #Iterator #ForLoop #CustomIteration #FunctionalProgramming #Sequence