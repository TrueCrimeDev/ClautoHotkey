# Topic: Class Static Methods in AHK v2

## Category

Class

## Overview

Static methods in AutoHotkey v2 classes belong to the class itself rather than instances of the class. They provide functionality that doesn't require access to instance-specific data and can be called directly from the class without creating an object. Static methods are essential for implementing utility functions, initialization routines, and singleton patterns.

## Key Points

- Static methods are defined using the `static` keyword before the method name
- They can be called directly from the class (e.g., `MyClass.StaticMethod()`)
- Static methods cannot access instance properties or methods using `this`
- Static methods can access other static methods and properties of the same class using `this`
- Static methods are useful for class-wide operations that don't need instance state

## Syntax and Parameters

```cpp
class MyClass {
    ; Static method declaration
    static MethodName(param1, param2 := "DefaultValue") {
        ; Method body
        return result
    }
}

; Calling a static method
result := MyClass.MethodName(arg1, arg2)
```

## Code Examples

```cpp
; Example of a utility class with static methods
class MathUtils {
    ; Static method to calculate the average of an array of numbers
    static Average(numbers) {
        sum := 0
        for num in numbers
            sum += num
        return numbers.Length ? sum / numbers.Length : 0
    }
    
    ; Static method to find the maximum value in an array
    static Max(numbers) {
        if !numbers.Length
            return 0
        
        max := numbers[1]
        for i, num in numbers
            if (i > 1 && num > max)
                max := num
        return max
    }
    
    ; Static method that uses another static method
    static Variance(numbers) {
        avg := this.Average(numbers)
        sumSqDiff := 0
        
        for num in numbers
            sumSqDiff += (num - avg) ** 2
            
        return numbers.Length ? sumSqDiff / numbers.Length : 0
    }
}

; Usage example
testArray := [4, 8, 15, 16, 23, 42]
MsgBox("Average: " MathUtils.Average(testArray))
MsgBox("Maximum: " MathUtils.Max(testArray))
MsgBox("Variance: " MathUtils.Variance(testArray))
```

## Implementation Notes

- Static methods are initialized when the class is first referenced, not when instances are created
- Static methods can be used to implement the Singleton pattern by controlling instance creation
- Unlike instance methods, static methods cannot access instance-specific data with `this`
- Avoid using global variables in static methods; pass required data as parameters
- If a static method needs to work with instance data, pass the instance as a parameter
- Static methods can be overridden in derived classes, but cannot be called polymorphically

## Related AHK Concepts

- [Class Static Properties](./class-static-properties.md)
- [Class Constructor Methods](./class-constructor-methods.md)
- [Method Binding and Context](../Concepts/method-binding-and-context.md)
- [Singleton Pattern](../Patterns/singleton-pattern.md)

## Tags

#AutoHotkey #OOP #Class #StaticMethods #v2