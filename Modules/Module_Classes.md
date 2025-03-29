AutoHotkey v2 Class System

This document provides comprehensive information about the class system in AutoHotkey v2. It is designed to be ingested by an LLM to provide a knowledge base for generating and understanding AHK v2 code.

1. Introduction to Classes

A class in AutoHotkey v2 is a blueprint for creating objects. It defines the object's structure (instance variables) and behavior (methods).

Classes support object-oriented programming principles, including encapsulation, inheritance, and polymorphism.

AHK v2 classes have a two-part structure: a class object (containing static members) and a prototype object (containing instance members).

2. Basic Class Definition

Syntax:

```cpp
class ClassName extends BaseClassName
{
    ; Instance variable declarations
    InstanceVar := Expression

    ; Static variable declarations
    static ClassVar := Expression

    ; Nested class definition
    class NestedClass
    {
        ; ...
    }

    ; Method definition
    Method()
    {
        ; ...
    }

    ; Static method definition
    static Method()
    {
        ; ...
    }
	; Property Definition
    Property[Parameters]
	{
		get
		{
			;return code
		}
		set
		{
			; store code
		}
    }
	;Fat Arrow Property (Getter only)
    ShortProp => Expression

	;Fat Arrow Property (Get and Set)
	FullShort[Params]
	{
		get => Expression
		set => Expression
	}
}
```

ClassName: The name of the class. This name must be unique within its scope (global or nested). It becomes a global read-only variable.

extends BaseClassName: (Optional) Specifies inheritance. BaseClassName must be the full name of another class.

Instance Variables: Declared without the static keyword. Each instance of the class gets its own copy. Accessed via this.InstanceVar. Initialized in the __Init method (automatically generated).

Static Variables: Declared with the static keyword. Belong to the class object itself, shared by all instances and subclasses (unless overridden). Accessed via ClassName.ClassVar or this.ClassVar (within static methods). Initialized in a static __Init method (automatically generated).

Methods: Functions defined within the class. Instance methods operate on instances (using this), while static methods operate on the class itself.

Properties: Use get and set accessors to control how values are retrieved and assigned to the properties. They can have parameters enclosed in square brackets, similar to methods. Static properties can also be defined.

Fat Arrow Syntax: Provides a concise way to define single-line properties (especially getters) and methods.

3. Instance Creation and __New

Instances are created by calling the class name as a function: myInstance := ClassName(parameters).

The __New method is a special constructor method. It's called automatically when a new instance is created.

__New is used to initialize instance variables. It can accept parameters passed during instance creation.

If __New is not explicitly defined, a default __New method is used.

Example:

```cpp
class Dog
{
    __New(name, breed)
    {
        this.name := name
        this.breed := breed
    }

    bark()
    {
        MsgBox "Woof! My name is " this.name
    }
}

myDog := Dog("Fido", "Golden Retriever")
myDog.bark()
```

4. Inheritance and super

Inheritance: A class can inherit from another class (the base class or superclass) using the extends keyword. The derived class (subclass) inherits the members of the base class.

super: Used within a derived class to access members of the base class that have been overridden.

super Resolution: super.Method() calls the base class's version of Method. AHK v2 resolves super at load time, using ClassName.Prototype.base.Method for instance methods and ClassName.base.Method for static methods. This means the base class is determined when the script is loaded, not at runtime.

Example:

```cpp
class Animal
{
    __New(name)
    {
        this.name := name
    }

    makeSound()
    {
        MsgBox "Generic animal sound"
    }
}
```

```cpp
class Dog extends Animal
{
    __New(name, breed)
    {
        super.__New(name) ; Call the base class constructor
        this.breed := breed
    }

    makeSound()
    {
        super.makeSound() ; Call the base class method
        MsgBox "Woof!"
    }
}

myDog := Dog("Buddy", "Labrador")
myDog.makeSound()
```

5. Properties and Meta-Functions

Properties: Provide a way to control access to an object's data. They use getter and setter methods to define how values are retrieved and assigned.

Getter: get { ... } - Called when the property is accessed.

Setter: set { ... } - Called when the property is assigned a value. value is a reserved word in the setter that passes the information.

Parameters: Properties can accept parameters, enclosed in square brackets: Property[param1, param2].

Meta-Functions: Special methods that are called when undefined properties or methods are accessed. They allow for dynamic behavior.

__Get(Name, Params): Called when an undefined property is accessed. Name is the property name, Params is an array of parameters. The default behavior is to throw a PropertyError.

__Set(Name, Params, Value): Called when an undefined property is assigned a value. Name is the property name, Params are parameters, Value is the assigned value. The default behavior is to define a new property.

__Call(Name, Params): Called when an undefined method is called. Name is the method name, Params are parameters. The default behavior is to throw a MethodError.

Meta-functions are not called for:

x[y] (This only invokes __Item.)

x() (This only invokes the Call method.)

Internal calls to other meta-functions or double-underscore methods.

__Enum(NumberOfVars)

Called when an object is used in a for loop.

Should return an enumerator object.

NumberOfVars indicates the number of variables in the for loop (usually 1 or 2).

__Item[Parameters]

The default property. Invoked when using array-like indexing (object[params]).

Equivalent to object.__Item[params] (with parameters) or object.__Item (without).

Example (__Get and __Set):

```cpp
class DynamicObject
{
    __Get(name, params)
    {
        MsgBox "Getting property: " name
        return "Property not found" ; Default behavior
    }

    __Set(name, params, value)
    {
        MsgBox "Setting property: " name " to " value
        this.DefineProp(name, {value: value}) ; Create a new property (Default)
    }
}

obj := DynamicObject()
MsgBox obj.unknownProp  ; Calls __Get
obj.newProp := 123      ; Calls __Set
MsgBox obj.newProp      ; Accesses the newly created property
```

6. Nested Classes

A class can be defined inside another class. This is called a nested class.

Nested classes are accessed via the outer class: OuterClass.InnerClass.

Nesting does not automatically create an instance of the inner class.

Nested classes are useful for organizing related classes and for creating factory patterns.

Each nested class definition creates a dynamic property with get and call accessors, rather than a simple value property. This enables lazy initialization and prevents incorrect this binding when calling the nested class.

Example:

```cpp
class Outer
{
    static x := "Outer static variable"
    class Inner
    {
        static y := "Inner static variable"
        showX()
        {
            MsgBox Outer.x ;access outer's information
        }
    }
}

MsgBox Outer.Inner.y
innerInstance := Outer.Inner()
innerInstance.showX()
```

7. Class Initialization (__Init and static __New)

Automatic Initialization: A class is automatically initialized the first time it's referenced.

__Init (static): An automatically defined static method. It initializes static variables and nested classes in the order they are defined. If a base class is present, its __Init is called first.

static __New: An optional static method. Called after __Init. Can be used for common initialization tasks for the class and its subclasses. Note that static __New will be called for each subclass that doesn't define its own static __New.

Initialization Order:

Base class __Init (if present)

Derived class __Init (static variables and nested classes)

Base class static __New (if present and not overridden)

Derived class static __New (if present)

If a class is referenced during the initialization of a previous variable or class within the same class, initialization of the first class pauses, the second class initializes, then initialization of the first class resumes. This can lead to unexpected behavior if static variables in one class depend on the fully initialized state of another.

8. Reference Counting and Object Lifetime

Reference Counting: AutoHotkey v2 uses reference counting to automatically manage object memory. When an object's reference count reaches zero, the object is deleted.

__Delete: A special meta-function called when an object is about to be deleted (its reference count has reached zero). Used for cleanup tasks. __Delete is not called for objects that have a __Class property (like prototype objects).

Circular References: A major issue with reference counting. Occurs when objects refer to each other, directly or indirectly, preventing their reference counts from reaching zero. This leads to memory leaks.

Breaking Cycles: To prevent circular references, you can:

Avoid creating cycles in the first place (often not practical).

Manually break cycles by setting references to unset when objects are no longer needed.

Use the Dispose Pattern.

Use pointers (ObjPtr) and carefully manage reference counts with ObjAddRef and ObjRelease.

Use "uncounted references" by decrementing the reference count with ObjRelease and incrementing it again in __Delete before releasing the reference.

ObjPtr(object): Returns a pointer (memory address) to the object. This creates a new reference, so you must use ObjAddRef to increment the reference count: address := ObjPtrAddRef(object).

ObjFromPtr(address): Converts a pointer back into an object reference. This consumes the reference represented by address.

ObjFromPtrAddRef(address): Converts a pointer to an object reference and adds a new reference.

ObjAddRef(address): Increments the reference count of the object at the given address.

ObjRelease(address): Decrements the reference count of the object at the given address.

The Dispose Pattern: Create a Dispose() method to manually release resources and break any circular references. This method should be idempotent (safe to call multiple times). You can call Dispose() from __Delete as a safety measure.

9. Primitive Values and Prototypes

Primitive Values: Strings, numbers (integers and floats) are not objects in AHK v2. They are immutable.

Primitive Prototypes: Each primitive type has a corresponding prototype object:

Number

Float

Integer

String

Delegation: Property and method calls on primitive values are delegated to their prototype objects.

Prototype Property: You can access the prototype object using the Prototype property of the corresponding class (e.g., String.Prototype).

Extending Prototypes: You can add methods and properties to primitive prototypes, making them available to all values of that type. However, you cannot directly set value properties on primitive values themselves.

n is Number: Checks if n has the Number prototype in its base chain. Note that this will return false for numeric strings, unlike IsNumber(n).

10. Best Practices and Error Handling

Class Name Validation: Ensure class names are unique and do not conflict with existing variables or classes.

Initialization Order: Be mindful of the order in which static members and nested classes are initialized.

Error Handling: Provide clear and informative error messages in methods, properties, and meta-functions. Use throw to raise exceptions.

Encapsulation: Use instance variables and methods to control access to an object's internal state. Avoid exposing implementation details.

Meta-Function Defaults: When defining meta-functions, ensure they implement the correct default behavior (e.g., throwing an error for undefined property access).

Documentation: Comments should describe the purpose of the code and its usage.

Testing: Create instances of the classes, call the methods and verify the results.

This detailed, declarative knowledge context provides a comprehensive overview of the AutoHotkey v2 class system. By presenting the information in a structured and annotated way, it aims to maximize the LLM's understanding even without the ability to train iteratively. This format is much better suited for providing a "knowledge dump" to an LLM than the question-based training prompts.