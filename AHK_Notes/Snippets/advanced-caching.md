# Topic: Advanced Caching System

## Category

Snippet

## Overview

This snippet implements a flexible caching system in AutoHotkey v2, designed to improve performance by storing the results of expensive operations. The implementation includes features like automatic cache expiration, size limits, LRU (Least Recently Used) eviction, and callbacks for cache hits and misses.

## Key Points

- Implements a configurable caching system to optimize expensive operations
- Supports time-based expiration and size-based LRU eviction
- Provides cache statistics and metadata for monitoring and debugging
- Includes serialization support for persistent caching across script runs
- Customizable with callbacks for cache events (hit, miss, eviction)

## Syntax and Parameters

```cpp
; Basic usage
cache := CacheManager()
cache.Set("key", "value", 60)  ; Cache for 60 seconds
value := cache.Get("key")      ; Retrieve from cache

; Advanced usage with factory function
result := cache.GetOrCompute("key", () => ExpensiveOperation(), 300)
```

## Code Examples

```cpp
/**
 * Advanced Cache Manager for AutoHotkey v2
 * 
 * Features:
 * - Time-based expiration
 * - Size-based LRU eviction
 * - Statistics and monitoring
 * - Serialization for persistence
 * - Event callbacks
 */
class CacheManager {
    ; Cache storage
    _cache := Map()
    
    ; Cache access order for LRU implementation
    _accessOrder := []
    
    ; Cache statistics
    _stats := {
        hits: 0,
        misses: 0,
        evictions: 0,
        expirations: 0,
        sets: 0
    }
    
    ; Configuration
    _config := {
        maxSize: 100,            ; Maximum number of items in cache
        defaultTTL: 300,         ; Default time-to-live in seconds (5 minutes)
        cleanupInterval: 60,     ; Automatic cleanup interval in seconds
        persistPath: "",         ; Path to save cache for persistence
        serializeValues: false   ; Whether to serialize values (needed for complex objects)
    }
    
    ; Event callbacks
    _callbacks := {
        onHit: "",             ; Called when cache hit occurs
        onMiss: "",            ; Called when cache miss occurs
        onEvict: "",           ; Called when item is evicted
        onExpire: ""           ; Called when item expires
    }
    
    ; Timer handle for cleanup
    _cleanupTimer := ""
    
    __New(config := "") {
        ; Apply custom configuration
        if (IsObject(config)) {
            for key, value in config.OwnProps() {
                if (this._config.HasOwnProp(key))
                    this._config[key] := value
            }
        }
        
        ; Start the cleanup timer if an interval is set
        if (this._config.cleanupInterval > 0) {
            this._cleanupTimer := ObjBindMethod(this, "_CleanupExpired")
            SetTimer(this._cleanupTimer, this._config.cleanupInterval * 1000)
        }
        
        ; Load persistent cache if path is specified
        if (this._config.persistPath && FileExist(this._config.persistPath))
            this._LoadFromFile()
    }
    
    __Delete() {
        ; Stop the cleanup timer
        if (this._cleanupTimer)
            SetTimer(this._cleanupTimer, 0)
            
        ; Save persistent cache if path is specified
        if (this._config.persistPath)
            this._SaveToFile()
    }
    
    /**
     * Sets a value in the cache with optional expiration time
     * @param {String} key - The cache key
     * @param {Any} value - The value to cache
     * @param {Integer} ttl - Time to live in seconds (optional)
     * @returns {CacheManager} - Returns this for method chaining
     */
    Set(key, value, ttl := "") {
        ; Use default TTL if not specified
        if (ttl == "")
            ttl := this._config.defaultTTL
            
        ; Calculate expiration time
        expiresAt := ttl > 0 ? A_TickCount + (ttl * 1000) : 0
        
        ; Prepare value for storage
        storedValue := this._config.serializeValues ? this._Serialize(value) : value
        
        ; Create cache entry
        cacheEntry := {
            key: key,
            value: storedValue,
            expiresAt: expiresAt,
            hits: 0,
            lastAccessed: A_TickCount,
            created: A_TickCount
        }
        
        ; Check if this is an update to existing entry
        if (this._cache.Has(key)) {
            ; Remove from access order
            for i, existingKey in this._accessOrder {
                if (existingKey == key) {
                    this._accessOrder.RemoveAt(i)
                    break
                }
            }
        }
        
        ; Add to cache and update access order
        this._cache[key] := cacheEntry
        this._accessOrder.Push(key)
        
        ; Update statistics
        this._stats.sets++
        
        ; Check and enforce size limit
        this._EnforceSizeLimit()
        
        return this
    }
    
    /**
     * Retrieves a value from the cache
     * @param {String} key - The cache key
     * @param {Any} defaultValue - Value to return if key not found (optional)
     * @returns {Any} The cached value or defaultValue if not found
     */
    Get(key, defaultValue := "") {
        ; Check if key exists
        if (!this._cache.Has(key)) {
            this._stats.misses++
            
            ; Call miss callback if defined
            if (IsObject(this._callbacks.onMiss))
                this._callbacks.onMiss(key)
                
            return defaultValue
        }
        
        entry := this._cache[key]
        
        ; Check if entry has expired
        if (entry.expiresAt > 0 && entry.expiresAt < A_TickCount) {
            this._RemoveEntry(key, "expired")
            this._stats.misses++
            
            ; Call miss callback if defined
            if (IsObject(this._callbacks.onMiss))
                this._callbacks.onMiss(key)
                
            return defaultValue
        }
        
        ; Update access statistics
        entry.hits++
        entry.lastAccessed := A_TickCount
        this._stats.hits++
        
        ; Update LRU order
        for i, existingKey in this._accessOrder {
            if (existingKey == key) {
                this._accessOrder.RemoveAt(i)
                break
            }
        }
        this._accessOrder.Push(key)
        
        ; Call hit callback if defined
        if (IsObject(this._callbacks.onHit))
            this._callbacks.onHit(key, entry)
        
        ; Return the value (deserialize if needed)
        return this._config.serializeValues 
            ? this._Deserialize(entry.value) 
            : entry.value
    }
    
    /**
     * Gets a value from cache or computes it if not present
     * @param {String} key - The cache key
     * @param {Function} computeFunc - Function to compute value if not cached
     * @param {Integer} ttl - Time to live in seconds (optional)
     * @returns {Any} The cached or computed value
     */
    GetOrCompute(key, computeFunc, ttl := "") {
        ; Check if value is already cached
        if (this.Has(key))
            return this.Get(key)
            
        ; Compute the value
        value := computeFunc()
        
        ; Cache the computed value
        this.Set(key, value, ttl)
        
        return value
    }
    
    /**
     * Checks if a key exists in the cache and is not expired
     * @param {String} key - The cache key
     * @returns {Boolean} True if key exists and is not expired
     */
    Has(key) {
        if (!this._cache.Has(key))
            return false
            
        entry := this._cache[key]
        
        ; Check if entry has expired
        if (entry.expiresAt > 0 && entry.expiresAt < A_TickCount) {
            this._RemoveEntry(key, "expired")
            return false
        }
        
        return true
    }
    
    /**
     * Removes a key from the cache
     * @param {String} key - The cache key
     * @returns {Boolean} True if key was removed
     */
    Remove(key) {
        if (!this._cache.Has(key))
            return false
            
        this._RemoveEntry(key, "manual")
        return true
    }
    
    /**
     * Clears all entries from the cache
     * @returns {CacheManager} Returns this for method chaining
     */
    Clear() {
        this._cache := Map()
        this._accessOrder := []
        return this
    }
    
    /**
     * Gets the current cache size
     * @returns {Integer} Number of items in cache
     */
    Size() {
        return this._cache.Count
    }
    
    /**
     * Gets cache statistics
     * @returns {Object} Object containing cache statistics
     */
    GetStats() {
        stats := this._stats.Clone()
        stats.size := this.Size()
        stats.configured_max := this._config.maxSize
        return stats
    }
    
    /**
     * Sets an event callback
     * @param {String} event - Event name (onHit, onMiss, onEvict, onExpire)
     * @param {Function} callback - Callback function
     * @returns {CacheManager} Returns this for method chaining
     */
    SetCallback(event, callback) {
        if (this._callbacks.HasOwnProp(event))
            this._callbacks[event] := callback
        return this
    }
    
    /**
     * Updates configuration options
     * @param {Object} newConfig - Object with configuration options
     * @returns {CacheManager} Returns this for method chaining
     */
    Configure(newConfig) {
        if (IsObject(newConfig)) {
            for key, value in newConfig.OwnProps() {
                if (this._config.HasOwnProp(key))
                    this._config[key] := value
            }
            
            ; Update cleanup timer if interval changed
            if (newConfig.HasOwnProp("cleanupInterval")) {
                if (this._cleanupTimer)
                    SetTimer(this._cleanupTimer, 0)
                    
                if (this._config.cleanupInterval > 0) {
                    this._cleanupTimer := ObjBindMethod(this, "_CleanupExpired")
                    SetTimer(this._cleanupTimer, this._config.cleanupInterval * 1000)
                }
            }
        }
        return this
    }
    
    /**
     * Private: Removes an entry from the cache
     * @param {String} key - The cache key
     * @param {String} reason - Reason for removal (expired, evicted, manual)
     */
    _RemoveEntry(key, reason) {
        if (!this._cache.Has(key))
            return
            
        entry := this._cache[key]
        this._cache.Delete(key)
        
        ; Remove from access order
        for i, existingKey in this._accessOrder {
            if (existingKey == key) {
                this._accessOrder.RemoveAt(i)
                break
            }
        }
        
        ; Update statistics
        if (reason == "expired") {
            this._stats.expirations++
            if (IsObject(this._callbacks.onExpire))
                this._callbacks.onExpire(key, entry)
        } else if (reason == "evicted") {
            this._stats.evictions++
            if (IsObject(this._callbacks.onEvict))
                this._callbacks.onEvict(key, entry)
        }
    }
    
    /**
     * Private: Enforces the size limit by removing least recently used items
     */
    _EnforceSizeLimit() {
        while (this._cache.Count > this._config.maxSize && this._accessOrder.Length > 0) {
            ; Get the least recently used key
            lruKey := this._accessOrder[1]
            
            ; Remove it
            if (this._cache.Has(lruKey))
                this._RemoveEntry(lruKey, "evicted")
            else
                this._accessOrder.RemoveAt(1)
        }
    }
    
    /**
     * Private: Cleans up expired entries
     */
    _CleanupExpired() {
        currentTime := A_TickCount
        
        ; Check all entries for expiration
        for key, entry in this._cache {
            if (entry.expiresAt > 0 && entry.expiresAt < currentTime)
                this._RemoveEntry(key, "expired")
        }
    }
    
    /**
     * Private: Serialize value for storage
     * @param {Any} value - Value to serialize
     * @returns {String} Serialized value
     */
    _Serialize(value) {
        try {
            return JSON.Stringify(value)
        } catch as err {
            return value
        }
    }
    
    /**
     * Private: Deserialize stored value
     * @param {String} value - Serialized value
     * @returns {Any} Deserialized value
     */
    _Deserialize(value) {
        try {
            return JSON.Parse(value)
        } catch as err {
            return value
        }
    }
    
    /**
     * Private: Save cache to file for persistence
     */
    _SaveToFile() {
        if (!this._config.persistPath)
            return
            
        try {
            ; Create a simplified version of the cache for storage
            persistent := []
            for key, entry in this._cache {
                ; Skip entries that are already expired
                if (entry.expiresAt > 0 && entry.expiresAt < A_TickCount)
                    continue
                    
                ; Convert absolute expiration time to relative TTL
                ttl := entry.expiresAt > 0
                    ? Ceil((entry.expiresAt - A_TickCount) / 1000)
                    : 0
                    
                ; Only store non-expired entries
                if (ttl != 0 || entry.expiresAt == 0) {
                    persistent.Push({
                        key: key,
                        value: entry.value,
                        ttl: ttl,
                        hits: entry.hits
                    })
                }
            }
            
            ; Save to file
            FileDelete(this._config.persistPath)
            FileAppend(JSON.Stringify(persistent), this._config.persistPath)
        } catch as err {
            OutputDebug("Error saving cache: " err.Message)
        }
    }
    
    /**
     * Private: Load cache from file
     */
    _LoadFromFile() {
        if (!this._config.persistPath || !FileExist(this._config.persistPath))
            return
            
        try {
            ; Read and parse the file
            fileContent := FileRead(this._config.persistPath)
            persistent := JSON.Parse(fileContent)
            
            ; Restore entries
            for i, entry in persistent {
                ; Skip if key is missing
                if (!entry.HasOwnProp("key"))
                    continue
                    
                ; Convert TTL to absolute expiration time
                expiresAt := entry.HasOwnProp("ttl") && entry.ttl > 0
                    ? A_TickCount + (entry.ttl * 1000)
                    : 0
                    
                ; Create cache entry
                cacheEntry := {
                    key: entry.key,
                    value: entry.value,
                    expiresAt: expiresAt,
                    hits: entry.HasOwnProp("hits") ? entry.hits : 0,
                    lastAccessed: A_TickCount,
                    created: A_TickCount
                }
                
                ; Add to cache
                this._cache[entry.key] := cacheEntry
                this._accessOrder.Push(entry.key)
            }
        } catch as err {
            OutputDebug("Error loading cache: " err.Message)
        }
    }
}

; ======== USAGE EXAMPLES ========

; Example 1: Basic caching
cache := CacheManager()

; Cache a value for 30 seconds
cache.Set("username", "JohnDoe", 30)

; Retrieve the value
username := cache.Get("username")
MsgBox("Username: " username)

; Example 2: Caching expensive operations
ExpensiveOperation(param) {
    ; Simulate an expensive operation
    Sleep(1000)
    return "Result for " param
}

; Configure cache with custom settings
dbCache := CacheManager({
    maxSize: 50,          ; Limit to 50 items
    defaultTTL: 600,      ; Default to 10 minutes
    cleanupInterval: 120  ; Clean up every 2 minutes
})

; Set up callbacks
dbCache.SetCallback("onHit", (key, entry) => 
    OutputDebug("Cache hit for key: " key " (hits: " entry.hits ")")
)
.SetCallback("onMiss", (key) => 
    OutputDebug("Cache miss for key: " key)
)

; Get or compute pattern
result1 := dbCache.GetOrCompute("query1", () => ExpensiveOperation("query1"))
; First call computes the value (slow)

result2 := dbCache.GetOrCompute("query1", () => ExpensiveOperation("query1"))
; Second call uses cached value (fast)

; Example 3: Cache with memoization for recursive functions
Fibonacci(n, memo := "") {
    ; Initialize memoization cache on first call
    if !IsObject(memo)
        memo := CacheManager()
    
    ; Base cases
    if (n <= 1)
        return n
        
    ; Check if we've already computed this value
    if (memo.Has(n))
        return memo.Get(n)
        
    ; Compute recursively and cache the result
    result := Fibonacci(n-1, memo) + Fibonacci(n-2, memo)
    memo.Set(n, result)
    
    return result
}

; Example 4: Persistent cache
persistentCache := CacheManager({
    persistPath: A_ScriptDir "\cache.json",
    serializeValues: true  ; Enable serialization for complex objects
})

; Cache an object that will be serialized
persistentCache.Set("user", {
    name: "John",
    email: "john@example.com",
    preferences: {
        theme: "dark",
        fontSize: 14
    }
}, 86400)  ; Cache for 1 day

; When the script ends, the cache will be saved to disk
; Next time the script runs, the cache will be loaded
```

## Implementation Notes

- **Memory Management**: The cache holds references to all cached objects, preventing garbage collection. For large objects, consider using weak references or manual cleanup
- **Performance Considerations**: 
  - The LRU algorithm adds some overhead; disable if not needed by setting `maxSize` to a very large number
  - Serialization is expensive; only enable if persistence is required
  - For extremely performance-critical code, consider simplifying the implementation
- **Thread Safety**: This implementation is not thread-safe; wrap method calls in critical sections if used in multi-threaded contexts
- **Persistence Limitations**: 
  - Complex objects with circular references may not serialize properly
  - Functions and bound methods cannot be serialized
  - Consider implementing custom serialization for complex types
- **Key Considerations**: String keys are recommended; if using objects as keys, they will be converted to strings
- **TTL Precision**: Expiration times are based on `A_TickCount` which rolls over after approximately 49.7 days; for longer TTLs, consider using `A_Now` instead

## Related AHK Concepts

- [Method Binding and Context](../Concepts/method-binding-and-context.md)
- [Map Usage Best Practices](../Concepts/map-usage-best-practices.md)
- [Closures in AHK v2](../Patterns/closures-in-ahk-v2.md)
- [Object.DeepClone Method](../Methods/object-deepclone.md)

## Tags

#AutoHotkey #Caching #Performance #Optimization #LRU #Expiration #Persistence #JSON