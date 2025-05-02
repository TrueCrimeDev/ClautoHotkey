# System Patterns: Enhanced Coding Companion System

## System Architecture
The Enhanced Coding Companion System follows a modular, object-oriented architecture with the following core components:

1. **Memory Bank Manager**: Central component responsible for managing memory bank files, including creation, reading, updating, and organization of knowledge documents.

2. **Function Map Engine**: Component that manages the function map XML structure, providing access to function definitions, workflows, and implementation methodologies.

3. **Task Log System**: Component for creating, tracking, and updating task logs that document implementation details and progress.

4. **UI Framework**: Dark-themed GUI system that provides access to all components through a tabbed interface with consistent styling.

5. **Configuration Manager**: Component for managing system configuration, including mode selection and environment settings.

These components interact through well-defined interfaces, with the main CodingCompanionSystem class serving as the coordination point for system operations.

## Key Technical Decisions

### Memory Bank Structure
- **Decision**: Use markdown files for memory bank content
- **Rationale**: Markdown provides a balance of human readability and structured content, allowing easy editing in any text editor while maintaining consistent formatting.
- **Implementation**: Files are stored in a memory_docs directory with standardized naming and structure.

### Function Map Format
- **Decision**: Use XML format for function map definitions
- **Rationale**: XML provides a hierarchical structure that naturally maps to the organization of functions into categories and phases.
- **Implementation**: Functions are defined with IDs, descriptions, and organized into structured phases and categories.

### UI Framework
- **Decision**: Implement dark mode throughout using Windows DWM API
- **Rationale**: Dark mode reduces eye strain for developers and provides a modern aesthetic in line with current design trends.
- **Implementation**: Consistent styling using DWM attributes and theme settings with fallbacks for older Windows versions.

### Data Storage
- **Decision**: Use Map objects for in-memory data storage
- **Rationale**: Maps provide structured key-value storage with better performance and clearer semantics than object literals.
- **Implementation**: All in-memory collections use Map() with clear key conventions.

### Task Logging
- **Decision**: Use structured markdown files with defined fields
- **Rationale**: Structured format provides consistent information while remaining human-readable and editable.
- **Implementation**: Task logs are stored in a .cursor/task-logs directory with timestamp-based naming.

### Mode Selection
- **Decision**: Provide LITE and FULL modes with different feature sets
- **Rationale**: Different projects have different complexity levels, requiring different levels of documentation and structure.
- **Implementation**: System behavior adapts based on the selected mode, showing and requiring different memory bank files.

## Design Patterns in Use

### Singleton Pattern
- **Usage**: Core system is implemented as a singleton instance
- **Purpose**: Ensures only one copy of the system is running and provides a global access point
- **Example**: The CodingCompanionSystem class is instantiated once at startup

### Observer Pattern
- **Usage**: GUI components observe system state changes
- **Purpose**: Allows UI to update reactively based on system state changes
- **Example**: Status bar updates based on operations, list views refresh when underlying data changes

### Factory Method Pattern
- **Usage**: Creation of memory bank file templates
- **Purpose**: Standardizes file creation while allowing for type-specific variations
- **Example**: GetBasicTemplate method creates different templates based on file type

### Command Pattern
- **Usage**: UI button actions
- **Purpose**: Encapsulates actions as objects, allowing for easier extension and modification
- **Example**: Button click handlers invoke specific commands that can be changed or extended

### Strategy Pattern
- **Usage**: Different file processing strategies based on file type
- **Purpose**: Allows for specialized handling of different file types with a consistent interface
- **Example**: File reading and writing operations adapt based on the file type

### Template Method Pattern
- **Usage**: Workflow phase implementations
- **Purpose**: Defines the skeleton of algorithms in base methods while allowing subclasses to override specific steps
- **Example**: Function execution follows a common template with phase-specific implementations

## Component Relationships

The system components relate to each other in the following ways:

1. **CodingCompanionSystem** is the central coordinator that initializes and manages all other components.

2. **Memory Bank Manager** interacts with the file system to manage memory bank files and provides content to the UI.

3. **Function Map Engine** parses and interprets functionmap.xml, providing structured function definitions to the system.

4. **Task Log System** coordinates with both the Memory Bank Manager (for content context) and the file system (for storage).

5. **UI Framework** provides the user interface for interacting with all other components, displaying memory bank content, function maps, and task logs.

6. **Configuration Manager** influences how all other components behave based on selected settings.

This architecture provides a modular, extensible framework that can grow with additional components while maintaining a consistent interaction model.
