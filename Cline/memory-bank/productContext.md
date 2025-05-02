# Product Context: AutoHotkey v2 OOP Framework

## Why This Project Exists
AutoHotkey v2 introduced significant improvements over v1, including robust object-oriented programming capabilities. However, many developers struggle with:
- Understanding the proper implementation of OOP principles in AHK v2
- Avoiding anti-patterns and syntax errors unique to AHK v2
- Creating maintainable code as applications grow in complexity
- Following consistent patterns for GUI development, error handling, and data storage
- **Implementing modern UI features like dark mode across their applications**

This framework exists to address these challenges and provide a solid foundation for modern AHK v2 development.

## Problems It Solves
1. **Inconsistent Coding Practices**: Establishes standardized patterns for class structure, method binding, and data management
2. **Object Literal Misuse**: Prevents the common error of using object literals for data storage instead of Map()
3. **Event Binding Errors**: Ensures proper method binding with .Bind(this) for event handlers
4. **GUI Development Complexity**: Simplifies GUI creation and management with consistent patterns
5. **Error Handling Inconsistencies**: Standardizes error handling approaches across applications
6. **V1 to V2 Migration Challenges**: Helps developers transition from procedural v1 code to OOP v2 code
7. **Dark Mode Implementation Difficulty**: Provides a consistent, cross-application approach to implementing dark mode for all GUI controls and windows

## How It Should Work
The framework provides:
1. Base classes and templates for common application patterns
2. Validation tools to catch syntax errors and anti-patterns
3. Standardized approaches for:
   - Class initialization and property management
   - GUI creation and event handling
   - Data storage using Maps instead of object literals
   - Error handling and recovery
   - String manipulation and escape sequence management
   - **Theme management with automatic dark/light mode switching**

Developers implement their applications by extending the framework's base classes and following the established patterns, resulting in more maintainable, error-resistant code.

## User Experience Goals
- **Simplified Development**: Reduce the cognitive load of writing proper AHK v2 code
- **Error Prevention**: Catch common errors before they cause runtime issues
- **Consistency**: Provide uniform patterns across different aspects of development
- **Scalability**: Enable the development of complex applications without sacrificing code quality
- **Documentation**: Provide clear explanations and examples for all framework components
- **Modern UI Experience**: Deliver applications with professional-looking interfaces that support user preferences for dark/light mode