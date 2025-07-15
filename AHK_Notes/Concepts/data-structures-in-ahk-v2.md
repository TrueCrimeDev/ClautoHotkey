# Topic: Data Structures in AHK v2

## Category

Concept

## Overview

AutoHotkey v2 provides several built-in data structures that mirror those found in modern programming languages. The primary data structures in AHK v2 are Arrays and Maps, which offer powerful ways to organize and manipulate collections of data with methods similar to JavaScript and Python collections.

## Key Points

- Arrays in AHK v2 are 1-indexed (unlike most programming languages that are 0-indexed)
- Maps provide key-value storage similar to dictionaries in Python or Maps in JavaScript
- Both Arrays and Maps offer built-in methods for common operations like insertion, deletion, and iteration
- AHK v2 uses reference counting for memory management of these data structures

## Syntax and Parameters

```cpp
; Array syntax
array := [element1, element2, element3]
element := array[index]  ; Retrieving by index (1-based)
array[index] := newValue  ; Setting by index

; Map syntax
map := Map(key1, value1, key2, value2)
value := map[key]  ; Retrieving by key
map[key] := newValue  ; Setting by key
map.Delete(key)  ; Removing a key-value pair

; Array methods
array.Length  ; Property: number of elements
array.Push(value)  ; Add to end
array.Pop()  ; Remove from end
array.InsertAt(index, value)  ; Insert at position
array.RemoveAt(index)  ; Remove at position
array.Has(index)  ; Check if index exists

; Map methods
map.Count  ; Property: number of key-value pairs
map.Has(key)  ; Check if key exists
map.Delete(key)  ; Remove key and its value
map.Clear()  ; Remove all key-value pairs
map.Clone()  ; Create a shallow copy
```

## Code Examples

```cpp
; Working with Arrays
numbers := [10, 20, 30, 40, 50]

; Accessing elements
first := numbers[1]  ; 10 (note: 1-based indexing)
last := numbers[numbers.Length]  ; 50

; Modifying arrays
numbers.Push(60)  ; Add to end: [10, 20, 30, 40, 50, 60]
poppedValue := numbers.Pop()  ; Remove from end: poppedValue = 60, array = [10, 20, 30, 40, 50]
numbers.InsertAt(2, 15)  ; Insert at position: [10, 15, 20, 30, 40, 50]
numbers.RemoveAt(3)  ; Remove at position: [10, 15, 30, 40, 50]

; Iterating through an array
for index, value in numbers
    MsgBox "Index: " index ", Value: " value

; Working with Maps
person := Map(
    "name", "John Doe",
    "age", 30,
    "city", "New York"
)

; Accessing and modifying
name := person["name"]  ; "John Doe"
person["age"] := 31  ; Update age
person["email"] := "john@example.com"  ; Add new key-value pair

; Checking if a key exists
if person.Has("phone")
    MsgBox "Phone: " person["phone"]
else
    MsgBox "No phone number available"

; Iterating through a Map
for key, value in person
    MsgBox "Key: " key ", Value: " value

; Nested data structures
users := [
    Map("id", 1, "name", "Alice", "active", true),
    Map("id", 2, "name", "Bob", "active", false),
    Map("id", 3, "name", "Charlie", "active", true)
]

; Finding active users
activeUsers := []
for user in users {
    if user["active"]
        activeUsers.Push(user["name"])
}

; Convert to comma-separated string
activeUsersList := ""
for index, name in activeUsers {
    if (index > 1)
        activeUsersList .= ", "
    activeUsersList .= name
}
MsgBox "Active users: " activeUsersList
```

## Implementation Notes

- Arrays in AHK v2 are 1-indexed, which can be confusing for developers coming from 0-indexed languages
- Both Arrays and Maps are reference types, so they are passed by reference to functions
- AHK v2's reference counting system handles memory management, but circular references can cause memory leaks
- The `.Clone()` method creates shallow copies - nested objects will still be references to the original objects
- Maps can use any value type as keys, including objects, but this is generally not recommended due to reference comparisons

## Related AHK Concepts

- Loops and Iteration
- Objects and Classes
- Reference vs. Value Types
- Variable Scope
- Garbage Collection

## Tags

#AutoHotkey #DataStructures #Arrays #Maps #Collections