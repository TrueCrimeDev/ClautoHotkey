# Topic: Custom Enumerators and Iterators

## Category

Concept

## Overview

Custom enumerators and iterators allow for specialized control over how AutoHotkey's for-loops process collections of data. Through the implementation of the `__Enum` method, objects can define custom iteration behavior, enabling functional programming patterns like lazy evaluation, filtering, mapping, and chaining of operations without creating intermediate collections.

## Key Points

- Custom iterators are implemented through the `__Enum` meta-function
- The `__Enum` method must return a closure that will be called repeatedly during iteration
- This closure should return 0 to stop iteration or non-zero to continue
- The arity parameter to `__Enum` determines how many output variables the for-loop uses
- Iterators can be chained for functional programming patterns like map, filter, reduce

## Syntax and Parameters

```cpp
; Basic __Enum implementation
__Enum(arity) {
    ; Initialize iteration state
    index := 0, array := this.internalArray
    
    ; Return a closure function that will be called for each iteration
    return (outputVars*) => {
        ; Check for end condition
        if (++index > array.Length)
            return 0  ; Return 0 to stop iteration
            
        ; Assign values to output variables
        outputVars[1] := index
        outputVars[2] := array[index]
        
        return 1  ; Return non-zero to continue iteration
    }
}

; Using a custom iterator
for index, value in customObject {
    ; Process each item
}
```

## Code Examples

```cpp
; Example 1: Range iterator (similar to Python's range)
Range(Start, Stop, Step:=1) => (&n) => (n := Start, Start += Step, Step > 0 ? n <= Stop : n >= Stop)

; Usage
For n in Range(1, 10)      ; 1, 2, 3, ... 10
    MsgBox n

For n in Range(10, 1, -1)  ; 10, 9, 8, ... 1
    MsgBox n

; Example 2: Grouped iterator (group array elements)
class GroupedArray {
    __New(array, groupSize) {
        this.array := array
        this.groupSize := groupSize
    }
    
    __Enum(arity) {
        i := 0
        array := this.array
        groupSize := this.groupSize
        totalGroups := Ceil(array.Length / groupSize)
        
        return (vars*) => {
            if (++i > totalGroups)
                return 0
                
            group := []
            startIdx := (i-1) * groupSize + 1
            endIdx := Min(startIdx + groupSize - 1, array.Length)
            
            Loop (endIdx - startIdx + 1)
                group.Push(array[startIdx + A_Index - 1])
                
            vars[1] := i
            vars[2] := group
            return 1
        }
    }
}

; Usage
numbers := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
for groupNum, group in GroupedArray(numbers, 3)
    MsgBox "Group " groupNum ": " JSON.Stringify(group)
    ; Group 1: [1,2,3], Group 2: [4,5,6], Group 3: [7,8,9], Group 4: [10]

; Example 3: Chainable iterator with map/filter/take operations
class Iterator {
    __New(enumerable) {
        this.enumerable := enumerable
    }
    
    map(transformFn) {
        return new MappingIterator(this, transformFn)
    }
    
    filter(predicateFn) {
        return new FilterIterator(this, predicateFn)
    }
    
    take(count) {
        return new TakeIterator(this, count)
    }
    
    __Enum(arity) {
        return this.enumerable.__Enum(arity)
    }
}

class MappingIterator extends Iterator {
    __New(source, transformFn) {
        this.source := source
        this.transformFn := transformFn
    }
    
    __Enum(arity) {
        enumerator := this.source.__Enum(arity)
        transform := this.transformFn
        
        return (vars*) => {
            if (!enumerator(vars*))
                return 0
                
            if (arity > 1)
                vars[2] := transform(vars[2])
            else
                vars[1] := transform(vars[1])
                
            return 1
        }
    }
}

; Usage for chainable operations
numbers := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
iter := Iterator(numbers)

; Chain operations: take only numbers > 3, multiply by 10, but only first 3 of them
for num in iter.filter(x => x > 3).map(x => x * 10).take(3)
    MsgBox num  ; Shows 40, 50, 60
```

## Implementation Notes

### Key Concepts for Custom Iterators:

1. **The `__Enum` method**:
   - Takes an `arity` parameter (number of output variables)
   - Returns a closure function for iteration
   - Closure receives references to the output variables
   - Closure assigns values to the output variables
   - Closure returns 0 to stop or non-zero to continue

2. **Iteration state**:
   - Usually stored in closure variables
   - Preserved between iterator calls
   - Modified during iteration to track progress

3. **Varargs and arity handling**:
   - Arity (1, 2, or more) determines number of loop variables
   - Common patterns: `for v in obj` (arity=1) and `for k, v in obj` (arity=2)
   - Output variable handling adapts to the arity

4. **Chainable iterators**:
   - Like functional programming pipelines
   - Each operation returns a new iterator
   - Source data only processed during actual iteration
   - Lazy evaluation - items are processed one at a time, not all at once

### Common Iterator Operations:

1. **Map**: Transform each element
2. **Filter**: Include only elements that match a condition
3. **Take/Drop**: Limit number of elements or skip elements
4. **Reduce**: Combine elements into a single result
5. **Zip**: Combine elements from multiple iterators
6. **Flatten**: Convert nested collections into a single sequence

### Best Practices:

- Implement lazy evaluation where possible to avoid unnecessary processing
- Use descriptive iterator names that reflect their operation
- Chain operations in a logical order (filter early to reduce work)
- Consider performance implications for large collections
- Use appropriate error handling for boundary conditions
- Properly document expected arity and behavior

### Performance Considerations:

- Custom iterators add overhead compared to simple array loops
- For small collections, the overhead may outweigh benefits
- For large collections, lazy evaluation can improve performance
- Complex chains of iterators may be harder to debug
- Consider providing optimized paths for common operations

## Related AHK Concepts

- For loops - The foundation that uses iterators
- Array methods - Built-in alternatives for some iterator operations
- Function objects - Used for callbacks in iterator operations
- Closures - Store iteration state between calls
- Variadic functions - Handle different arities in output vars
- Fat arrow functions - Concise syntax for iterator implementations

## Tags

#AutoHotkey #Iterator #Enumerator #FunctionalProgramming #ForLoop #LazyEvaluation #CustomObject