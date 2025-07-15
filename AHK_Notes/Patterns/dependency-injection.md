# Topic: Dependency Injection Pattern

## Category

Pattern

## Overview

Dependency Injection (DI) is a design pattern in AutoHotkey v2 where objects receive their dependencies rather than creating them internally. This pattern promotes loose coupling between components, making code more maintainable, testable, and flexible. By injecting dependencies through constructors, methods, or properties, DI allows components to be easily replaced or modified without affecting the overall system.

## Key Points

- Reduces coupling between components by externalizing dependencies
- Improves testability by allowing mock objects to be injected
- Increases flexibility through interchangeable implementations
- Simplifies maintenance by centralizing dependency management
- Supports the Single Responsibility Principle by separating creation from usage
- Enhances code reusability across different contexts

## Syntax and Parameters

```cpp
; Constructor Injection
class Consumer {
    Dependency := ""
    
    __New(dependency) {
        this.Dependency := dependency
    }
}

; Method Injection
class Consumer {
    UseDependency(dependency) {
        ; Use dependency here
    }
}

; Property Injection
class Consumer {
    Dependency := ""
}

; Usage
consumer := Consumer(DependencyImplementation)
```

## Code Examples

```cpp
#Requires AutoHotkey v2.0.18+

; Example showing Dependency Injection in a Logger system

; Interface-like base classes
class LoggerBase {
    Log(message) {
        throw Error("Method not implemented")
    }
}

class ConfigProviderBase {
    GetSetting(name) {
        throw Error("Method not implemented")
    }
}

; Concrete implementations
class ConsoleLogger extends LoggerBase {
    Log(message) {
        FileAppend(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") " - " message "`n", "*")
    }
}

class FileLogger extends LoggerBase {
    FilePath := ""
    
    __New(filePath) {
        this.FilePath := filePath
    }
    
    Log(message) {
        FileAppend(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") " - " message "`n", this.FilePath)
    }
}

class JsonConfigProvider extends ConfigProviderBase {
    ConfigData := ""
    
    __New(configPath) {
        try {
            configText := FileRead(configPath)
            this.ConfigData := Jxon_Load(configText)  ; Assuming Jxon_Load function is available
        } catch as err {
            throw Error("Failed to load configuration: " err.Message)
        }
    }
    
    GetSetting(name) {
        if (this.ConfigData.Has(name))
            return this.ConfigData[name]
        return ""
    }
}

class RegistryConfigProvider extends ConfigProviderBase {
    RootKey := ""
    
    __New(rootKey) {
        this.RootKey := rootKey
    }
    
    GetSetting(name) {
        try {
            return RegRead(this.RootKey, name)
        } catch {
            return ""
        }
    }
}

; Service that depends on both a logger and config provider
class UserService {
    Logger := ""
    Config := ""
    
    ; Constructor Injection
    __New(logger, config) {
        this.Logger := logger
        this.Config := config
    }
    
    CreateUser(username) {
        maxUsers := this.Config.GetSetting("MaxUsers")
        
        if (maxUsers && this.GetUserCount() >= maxUsers) {
            this.Logger.Log("Failed to create user " username ": Maximum user limit reached")
            return false
        }
        
        ; Create user logic here...
        this.Logger.Log("User created: " username)
        return true
    }
    
    GetUserCount() {
        ; Dummy implementation
        return 5
    }
}

; Example usage with different implementations
ExampleDI() {
    ; Create dependencies
    consoleLogger := ConsoleLogger()
    fileLogger := FileLogger("C:\logs\app.log")
    
    jsonConfig := JsonConfigProvider("C:\config\settings.json")
    registryConfig := RegistryConfigProvider("HKEY_CURRENT_USER\Software\MyApp")
    
    ; Create service with console logger and JSON config (Constructor Injection)
    userService1 := UserService(consoleLogger, jsonConfig)
    
    ; Create service with file logger and registry config (Constructor Injection)
    userService2 := UserService(fileLogger, registryConfig)
    
    ; Use the services
    userService1.CreateUser("john.doe")
    userService2.CreateUser("jane.smith")
    
    ; Changing dependencies at runtime
    userService1.Logger := fileLogger  ; Property Injection
}

; Basic Service Locator (simplified Dependency Injection Container)
class ServiceLocator {
    static Services := Map()
    
    static Register(name, service) {
        this.Services[name] := service
    }
    
    static Get(name) {
        if (this.Services.Has(name))
            return this.Services[name]
        throw Error("Service not registered: " name)
    }
}

; Example using Service Locator
ConfigureServices() {
    ; Register services
    ServiceLocator.Register("Logger", FileLogger("C:\logs\app.log"))
    ServiceLocator.Register("Config", JsonConfigProvider("C:\config\settings.json"))
    ServiceLocator.Register("UserService", UserService(
        ServiceLocator.Get("Logger"),
        ServiceLocator.Get("Config")
    ))
    
    ; Get and use a service
    userService := ServiceLocator.Get("UserService")
    userService.CreateUser("testuser")
}
```

## Implementation Notes

- **Constructor Injection** is generally preferred as it makes dependencies explicit and ensures they're available
- **Method Injection** is useful when the dependency is only needed for specific operations
- **Property Injection** provides flexibility for changing dependencies at runtime but doesn't guarantee they exist
- Use interface-like base classes to define clear contracts between components
- Consider implementing a Service Locator or Dependency Injection Container for centralized management in large applications
- Avoid creating service locator dependencies throughout your codebase (Service Locator anti-pattern)
- Type checking (`is` operator) can be used to verify injected dependencies are compatible
- Dependencies should be passed from the composition root (usually near the application entry point)
- When refactoring existing code to use DI, start with the most isolated classes and work outward
- For simpler applications, manual dependency injection is often sufficient without a container
- Test doubles (mocks, stubs) can easily replace real dependencies in unit tests

## Related AHK Concepts

- [Class Inheritance](../Classes/class-basics-in-ahk-v2.md)
- [Interface Pattern](./interface-pattern.md)
- [Factory Pattern](./factory-pattern.md)
- [Service Locator Pattern](./service-locator-pattern.md)
- [Single Responsibility Principle](../Concepts/single-responsibility-principle.md)

## Tags

#AutoHotkey #OOP #DependencyInjection #DI #DesignPattern #SOLID #Testing #v2